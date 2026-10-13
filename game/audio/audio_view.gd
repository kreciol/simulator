class_name AudioView
extends Node
## Sound effects (issue #72, spec `2026-10-13-sound-effects.md`): an engine note whose
## pitch and loudness follow the player's speed. Like the other views it only reads
## the session and the sim, once per rendered frame (`update`). Engine sounds only
## while driving or respawning: never in the countdown, while paused or on the end
## screen; a pause holds every sound where it is, to resume with the session. During a
## respawn the engine fades with the screen. Nothing sounds before the first key,
## click or touch (`unlock`, browser autoplay policy); `toggle_mute` silences
## everything. Both act on the `Master` bus.

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
## Set until the player's first key, click or touch.
var locked: bool = true
## The player's choice (`toggle_mute`); starts as `AudioConfig.muted_by_default`.
var user_muted: bool = false
var engine_player: AudioStreamPlayer

var _players: Array[AudioStreamPlayer] = []


func setup(session_manager: SessionManager, view_config: ViewConfig, audio_config: AudioConfig,
		top_speed: float) -> void:
	session = session_manager
	view = view_config
	config = audio_config
	top_speed_kmh = top_speed
	user_muted = config.muted_by_default
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MASTER_BUS), config.master_volume_db)
	var rate: int = config.synth_mix_rate
	engine_player = _player("Engine", AudioSynth.engine(rate, config.engine_base_hz), ENGINE_BUS)
	_apply_mute()


## Follows the session for one rendered frame.
func update() -> void:
	for player: AudioStreamPlayer in _players:
		player.stream_paused = session.paused
	if session.paused:
		return
	_update_engine()


## The player's first key, click or touch: sound may start (browser autoplay policy).
func unlock() -> void:
	if not locked:
		return
	locked = false
	_apply_mute()


func toggle_mute() -> void:
	user_muted = not user_muted
	_apply_mute()


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


static func _speed_share(speed_kmh: float, top_kmh: float) -> float:
	return clampf(speed_kmh / top_kmh, 0.0, 1.0) if top_kmh > 0.0 else 1.0


func _update_engine() -> void:
	if not is_sounding():
		engine_player.stop()
		return
	var speed_kmh: float = session.player.speed_mps * TrafficSim.KMH_PER_MPS
	engine_player.pitch_scale = engine_pitch(config, speed_kmh, top_speed_kmh)
	var fade_gain: float = maxf(1.0 - session.fade_amount(), MIN_FADE_GAIN)
	engine_player.volume_db = engine_volume_db(config, speed_kmh, top_speed_kmh) + linear_to_db(fade_gain)
	if not engine_player.playing:
		engine_player.play()


func _apply_mute() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MASTER_BUS), is_silenced())


func _player(node_name: String, stream: AudioStream, bus: StringName) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = node_name
	player.stream = stream
	player.bus = bus
	add_child(player)
	_players.append(player)
	return player
