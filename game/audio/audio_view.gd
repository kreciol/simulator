class_name AudioView
extends Node
## Sound effects (issue #72, spec `2026-10-13-sound-effects.md`): an electric motor's
## whine and the road's roar, whose pitch and loudness follow the player's speed, the indicator's tick-tock in step with
## the blinking arrow (`SignalBlink`), a whoosh when a vehicle passes close by on a
## neighbouring lane (`PassDetector`), and one sound per crash or exit from the road.
## Like the other views it only reads the session and the sim, once per rendered frame
## (`update`), plus the sim's `collision` and `offroad` signals. The engine, the
## indicator and passes sound only while driving or respawning: never in the countdown, while
## paused or on the end screen; a pause holds every sound where it is, to resume with
## the session. During a respawn the engine fades with the screen. A crash or an exit
## sounds at once — before the learn-mode fade, and on into the exam's end screen. Nothing sounds before the first key,
## click or touch (`unlock`, browser autoplay policy); `toggle_mute` silences
## everything. Both act on the `Master` bus. Both also outlast the scene: a session
## started from the menu or with "again" (issue #43) keeps the run's unlock and the
## player's mute choice.

const MASTER_BUS: StringName = &"Master"
const ENGINE_BUS: StringName = &"Engine"
const EFFECTS_BUS: StringName = &"Effects"
## Floor of the respawn fade, so the engine's volume stays a finite number of dB.
const MIN_FADE_GAIN: float = 0.001

var config: AudioConfig
var session: SessionManager
var view: ViewConfig
## Speed at which the engine reaches its top pitch and loudness, km/h.
var top_speed_kmh: float
## Whether this run already had a key, click or touch (the start screen's included).
static var run_unlocked: bool = false
## Whether the player chose to mute or unmute in this run, and what.
static var run_mute_chosen: bool = false
static var run_muted: bool = false

## Set until the player's first key, click or touch in this run.
var locked: bool = true
## The player's choice (`toggle_mute`); starts as the run's choice, else
## `AudioConfig.muted_by_default`.
var user_muted: bool = false
var engine_player: AudioStreamPlayer
var road_player: AudioStreamPlayer
var tick_player: AudioStreamPlayer
var tock_player: AudioStreamPlayer
var collision_player: AudioStreamPlayer
var offroad_player: AudioStreamPlayer
## Whooshes that can sound at once; the next pass takes the oldest.
var pass_players: Array[AudioStreamPlayer] = []
## Sounds started so far, per kind: what tests check, since a player's `playing`
## depends on the audio driver's timing.
var tick_count: int = 0
var tock_count: int = 0
var collision_count: int = 0
var offroad_count: int = 0
var pass_count: int = 0
## Times the pause was written to the players.
var pause_writes: int = 0

var _players: Array[AudioStreamPlayer] = []
## The pause last applied to the players: set only on a change, since every call pauses
## or resumes the browser's sample playback, which makes it stutter.
var _paused: bool = false
## Whether the indicator was lit at the last update, to click on each change.
var _was_lit: bool = false
var _pass_detector: PassDetector
var _next_pass_player: int = 0


func setup(session_manager: SessionManager, view_config: ViewConfig, audio_config: AudioConfig,
		top_speed: float) -> void:
	session = session_manager
	view = view_config
	config = audio_config
	top_speed_kmh = top_speed
	user_muted = run_muted if run_mute_chosen else config.muted_by_default
	locked = not run_unlocked
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MASTER_BUS), config.master_volume_db)
	var rate: int = config.synth_mix_rate
	engine_player = _player("Engine", AudioSynth.engine(rate, config.engine_base_hz), ENGINE_BUS)
	road_player = _player("Road", AudioSynth.road(rate), ENGINE_BUS)
	tick_player = _player("Tick", AudioSynth.tick(rate), EFFECTS_BUS, config.indicator_volume_db)
	tock_player = _player("Tock", AudioSynth.tock(rate), EFFECTS_BUS, config.indicator_volume_db)
	collision_player = _player("Collision", AudioSynth.impact(rate), EFFECTS_BUS, config.collision_volume_db)
	offroad_player = _player("Offroad", AudioSynth.rumble(rate), EFFECTS_BUS, config.offroad_volume_db)
	var whoosh: AudioStreamWAV = AudioSynth.whoosh(rate)
	for i: int in maxi(1, config.pass_voices):
		pass_players.append(_player("Pass%d" % i, whoosh, EFFECTS_BUS))
	_pass_detector = PassDetector.new(config)
	session.player_respawned.connect(_on_player_respawned)
	session.sim.collision.connect(_on_collision)
	session.sim.offroad.connect(_on_offroad)
	_apply_mute()


## Follows the session for one rendered frame.
func update() -> void:
	if session.paused != _paused:
		_paused = session.paused
		pause_writes += 1
		for player: AudioStreamPlayer in _players:
			player.stream_paused = _paused
	if session.paused:
		return
	_update_engine()
	_update_indicator()
	if is_sounding():
		for loudness: float in _pass_detector.update(session.sim):
			_play_pass(loudness)


## The player's first key, click or touch: sound may start (browser autoplay policy).
func unlock() -> void:
	run_unlocked = true
	if not locked:
		return
	locked = false
	_apply_mute()


func toggle_mute() -> void:
	user_muted = not user_muted
	run_mute_chosen = true
	run_muted = user_muted
	_apply_mute()


## Forgets the run's unlock and mute choice, as at page load (tests).
static func reset_run() -> void:
	run_unlocked = false
	run_mute_chosen = false
	run_muted = false


## Whether nothing can be heard: before the first gesture or muted by the player.
func is_silenced() -> bool:
	return locked or user_muted


## Whether the session is in a state the engine, the indicator and passes sound in.
func is_sounding() -> bool:
	return not session.paused and (session.state == SessionManager.State.DRIVING
			or session.state == SessionManager.State.RESPAWNING)


## Engine pitch at `speed_kmh`: from `engine_pitch_min` at a standstill to
## `engine_pitch_max` at `top_kmh`, flat above it.
static func engine_pitch(audio: AudioConfig, speed_kmh: float, top_kmh: float) -> float:
	return lerpf(audio.engine_pitch_min, audio.engine_pitch_max, _speed_share(speed_kmh, top_kmh))


## Engine loudness at `speed_kmh`, rising with the speed like its pitch.
static func engine_volume_db(audio: AudioConfig, speed_kmh: float, top_kmh: float) -> float:
	return lerpf(audio.engine_volume_min_db, audio.engine_volume_max_db, _speed_share(speed_kmh, top_kmh))


## Road-noise pitch at `speed_kmh`, like the engine's.
static func road_pitch(audio: AudioConfig, speed_kmh: float, top_kmh: float) -> float:
	return lerpf(audio.road_pitch_min, audio.road_pitch_max, _speed_share(speed_kmh, top_kmh))


## Road-noise loudness at `speed_kmh`: the roar that carries at motorway speed.
static func road_volume_db(audio: AudioConfig, speed_kmh: float, top_kmh: float) -> float:
	return lerpf(audio.road_volume_min_db, audio.road_volume_max_db, _speed_share(speed_kmh, top_kmh))


static func _speed_share(speed_kmh: float, top_kmh: float) -> float:
	return clampf(speed_kmh / top_kmh, 0.0, 1.0) if top_kmh > 0.0 else 1.0


func _update_engine() -> void:
	if not is_sounding():
		engine_player.stop()
		road_player.stop()
		return
	var speed_kmh: float = session.player.speed_mps * TrafficSim.KMH_PER_MPS
	var fade_db: float = linear_to_db(maxf(1.0 - session.fade_amount(), MIN_FADE_GAIN))
	engine_player.pitch_scale = engine_pitch(config, speed_kmh, top_speed_kmh)
	engine_player.volume_db = engine_volume_db(config, speed_kmh, top_speed_kmh) + fade_db
	road_player.pitch_scale = road_pitch(config, speed_kmh, top_speed_kmh)
	road_player.volume_db = road_volume_db(config, speed_kmh, top_speed_kmh) + fade_db
	if not engine_player.playing:
		engine_player.play()
	if not road_player.playing:
		road_player.play()


## Tick when the arrow lights up, tock when it goes dark. The blink runs on sim time,
## which stands still whenever the sim does, so a frozen session never clicks.
func _update_indicator() -> void:
	var lit: bool = SignalBlink.is_lit(session.player, session.sim.time_s, view.signal_blink_hz)
	if lit == _was_lit:
		return
	_was_lit = lit
	if not is_sounding():
		return
	if lit:
		tick_player.play()
		tick_count += 1
	else:
		tock_player.play()
		tock_count += 1


func _play_pass(loudness: float) -> void:
	var player: AudioStreamPlayer = pass_players[_next_pass_player]
	_next_pass_player = (_next_pass_player + 1) % pass_players.size()
	player.volume_db = lerpf(config.pass_volume_min_db, config.pass_volume_max_db, loudness)
	player.play()
	pass_count += 1


## The player is back on the road with the indicator off: neither the move nor the
## switched-off lamp is a pass or a click.
func _on_player_respawned() -> void:
	_pass_detector.reset()
	_was_lit = false


func _on_collision(vehicle_id: int, other_id: int) -> void:
	if vehicle_id == session.player.id or other_id == session.player.id:
		collision_player.play()
		collision_count += 1


func _on_offroad(vehicle_id: int) -> void:
	if vehicle_id == session.player.id:
		offroad_player.play()
		offroad_count += 1


func _exit_tree() -> void:
	# The buses outlive the session: leave them as the project defines them.
	var master: int = AudioServer.get_bus_index(MASTER_BUS)
	AudioServer.set_bus_mute(master, false)
	AudioServer.set_bus_volume_db(master, 0.0)


func _apply_mute() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MASTER_BUS), is_silenced())


func _player(node_name: String, stream: AudioStream, bus: StringName,
		volume_db: float = 0.0) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = node_name
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	add_child(player)
	_players.append(player)
	return player
