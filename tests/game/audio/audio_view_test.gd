extends GdUnitTestSuite
## Sound effects follow the session without changing it: the engine's pitch follows the
## speed, nothing sounds in the countdown, while paused or on the end screen, and
## nothing before the first gesture or while muted (issue #72 acceptance criteria, spec
## `2026-10-13-sound-effects.md` Phase 1).

const DT: float = 1.0 / 60.0
const TOP_KMH: float = 150.0

var _sim_config: SimConfig
var _audio_config: AudioConfig
var _session: SessionManager
var _audio: AudioView


func before_test() -> void:
	_sim_config = load("res://config/sim_config.tres") as SimConfig
	_audio_config = load("res://config/audio_config.tres") as AudioConfig
	_start(LaunchOptions.MODE_LEARN)


func _start(mode: StringName) -> void:
	_session = auto_free(SessionManager.new()) as SessionManager
	_session.setup(load("res://config/road_profiles/motorway.tres") as RoadProfile, _sim_config, 0, mode)
	_audio = AudioView.new()
	add_child(auto_free(_audio))
	_audio.setup(_session, _view(), _audio_config, TOP_KMH)


func _view() -> ViewConfig:
	return load("res://config/view_config.tres") as ViewConfig


func after_test() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(AudioView.MASTER_BUS), false)


func _step(steps: int, commands: PlayerCommands = null) -> void:
	for i: int in steps:
		_session.step(DT, commands)
		_audio.update()


func _drive() -> void:
	_step(roundi(_sim_config.countdown_s / DT) + 1)
	assert_int(_session.state).is_equal(SessionManager.State.DRIVING)


func _master_muted() -> bool:
	return AudioServer.is_bus_mute(AudioServer.get_bus_index(AudioView.MASTER_BUS))


func test_engine_pitch_follows_the_speed_smoothly() -> void:
	assert_float(AudioView.engine_pitch(_audio_config, 0.0, TOP_KMH)).is_equal_approx(_audio_config.engine_pitch_min, 1e-5)
	assert_float(AudioView.engine_pitch(_audio_config, TOP_KMH, TOP_KMH)).is_equal_approx(_audio_config.engine_pitch_max, 1e-5)
	assert_float(AudioView.engine_pitch(_audio_config, TOP_KMH + 30.0, TOP_KMH)).is_equal_approx(_audio_config.engine_pitch_max, 1e-5)
	# No steps: every km/h moves the pitch by the same small amount.
	var previous: float = AudioView.engine_pitch(_audio_config, 0.0, TOP_KMH)
	var per_kmh: float = (_audio_config.engine_pitch_max - _audio_config.engine_pitch_min) / TOP_KMH
	for kmh: int in range(1, int(TOP_KMH) + 1):
		var pitch: float = AudioView.engine_pitch(_audio_config, kmh, TOP_KMH)
		assert_float(pitch - previous).is_equal_approx(per_kmh, 1e-5)
		previous = pitch


func test_engine_gets_louder_with_speed() -> void:
	assert_float(AudioView.engine_volume_db(_audio_config, 0.0, TOP_KMH)).is_equal_approx(_audio_config.engine_volume_min_db, 1e-4)
	assert_float(AudioView.engine_volume_db(_audio_config, TOP_KMH, TOP_KMH)).is_equal_approx(_audio_config.engine_volume_max_db, 1e-4)


func test_engine_is_silent_in_the_countdown_and_plays_while_driving() -> void:
	_step(1)
	assert_int(_session.state).is_equal(SessionManager.State.INTRO)
	assert_bool(_audio.is_sounding()).is_false()
	assert_bool(_audio.engine_player.playing).is_false()
	_drive()
	assert_bool(_audio.is_sounding()).is_true()
	assert_bool(_audio.engine_player.playing).is_true()
	var speed_kmh: float = _session.player.speed_mps * TrafficSim.KMH_PER_MPS
	assert_float(_audio.engine_player.pitch_scale).is_equal_approx(
			AudioView.engine_pitch(_audio_config, speed_kmh, TOP_KMH), 1e-5)
	assert_str(_audio.engine_player.bus).is_equal(AudioView.ENGINE_BUS)


func test_pause_holds_the_sound_and_resume_releases_it() -> void:
	_drive()
	_session.pause()
	_audio.update()
	assert_bool(_audio.is_sounding()).is_false()
	assert_bool(_audio.engine_player.stream_paused).is_true()
	_session.resume()
	_step(1)
	assert_bool(_audio.engine_player.stream_paused).is_false()
	assert_bool(_audio.engine_player.playing).is_true()


func test_engine_stops_on_the_end_screen() -> void:
	_drive()
	_step(roundi(_sim_config.session_length_s / DT) + 1)
	assert_int(_session.state).is_equal(SessionManager.State.ENDED)
	assert_bool(_audio.is_sounding()).is_false()
	assert_bool(_audio.engine_player.playing).is_false()


func test_nothing_sounds_before_the_first_gesture() -> void:
	assert_bool(_audio.locked).is_true()
	assert_bool(_master_muted()).is_true()
	_audio.unlock()
	assert_bool(_audio.is_silenced()).is_false()
	assert_bool(_master_muted()).is_false()


func test_mute_toggles_the_master_bus_and_survives_the_unlock() -> void:
	_audio.toggle_mute()
	assert_bool(_audio.user_muted).is_true()
	_audio.unlock()
	# Unlocking does not undo the player's mute.
	assert_bool(_master_muted()).is_true()
	_audio.toggle_mute()
	assert_bool(_master_muted()).is_false()


func test_master_volume_comes_from_the_config() -> void:
	assert_float(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(AudioView.MASTER_BUS))).is_equal_approx(
			_audio_config.master_volume_db, 1e-4)


func test_audio_does_not_change_the_simulation() -> void:
	var plain: SessionManager = auto_free(SessionManager.new()) as SessionManager
	plain.setup(load("res://config/road_profiles/motorway.tres") as RoadProfile, _sim_config)
	var commands: PlayerCommands = PlayerCommands.new()
	commands.longitudinal = VehicleState.Longitudinal.ACCELERATE
	for i: int in 600:
		plain.step(DT, commands)
	_step(600, commands)
	assert_dict(_session.sim.snapshot()).is_equal(plain.sim.snapshot())


func _signal(dir: VehicleState.Dir) -> PlayerCommands:
	var commands: PlayerCommands = PlayerCommands.new()
	commands.signal_toggle = dir
	return commands


## Drives `steps` steps, counting the blinking arrow's switches on and off as the HUD
## sees them; returns [ons, offs].
func _count_blinks(steps: int) -> Array[int]:
	var counts: Array[int] = [0, 0]
	var lit: bool = SignalBlink.is_lit(_session.player, _session.sim.time_s, _view().signal_blink_hz)
	for i: int in steps:
		_step(1)
		var now: bool = SignalBlink.is_lit(_session.player, _session.sim.time_s, _view().signal_blink_hz)
		if now and not lit:
			counts[0] += 1
		elif lit and not now:
			counts[1] += 1
		lit = now
	return counts


func test_indicator_ticks_in_step_with_the_blinking_arrow() -> void:
	_drive()
	_step(1, _signal(VehicleState.Dir.LEFT))
	# Each blink starts lit: the first tick comes with the switch.
	assert_int(_audio.tick_count).is_equal(1)
	var blinks: Array[int] = _count_blinks(180)
	assert_int(blinks[0]).is_greater(0)
	assert_int(_audio.tick_count).is_equal(1 + blinks[0])
	assert_int(_audio.tock_count).is_equal(blinks[1])
	assert_str(_audio.tick_player.bus).is_equal(AudioView.EFFECTS_BUS)


func test_indicator_stops_as_soon_as_the_signal_is_off() -> void:
	_drive()
	_step(1, _signal(VehicleState.Dir.RIGHT))
	_step(30)
	_step(1, _signal(VehicleState.Dir.RIGHT))
	var ticks: int = _audio.tick_count
	var tocks: int = _audio.tock_count
	_step(180)
	assert_int(_audio.tick_count).is_equal(ticks)
	# At most the one closing click when the lamp goes dark with the switch.
	assert_int(_audio.tock_count).is_less_equal(tocks + 1)
	var after: int = _audio.tock_count
	_step(180)
	assert_int(_audio.tock_count).is_equal(after)


func test_indicator_is_silent_while_paused() -> void:
	_drive()
	_step(1, _signal(VehicleState.Dir.LEFT))
	_session.pause()
	var ticks: int = _audio.tick_count + _audio.tock_count
	_step(180)
	assert_int(_audio.tick_count + _audio.tock_count).is_equal(ticks)


## Drops a stopped car just ahead of the player and drives until the player hits it.
func _crash() -> void:
	var player: VehicleState = _session.player
	_session.sim.add_vehicle(player.s + player.length_m + 1.0, 0, 0.0)
	var steps: int = 0
	while _session.state == SessionManager.State.DRIVING and steps < 120:
		_step(1)
		steps += 1


func _leave_the_road() -> void:
	var right: PlayerCommands = PlayerCommands.new()
	right.lane_change = VehicleState.Dir.RIGHT
	_step(1, right)
	_step(roundi(_sim_config.lane_change_duration_s / DT))


func test_one_impact_per_crash_before_the_learn_fade() -> void:
	_drive()
	_crash()
	assert_int(_session.state).is_equal(SessionManager.State.RESPAWNING)
	assert_int(_audio.collision_count).is_equal(1)
	assert_float(_session.fade_amount()).is_less(0.1)
	_step(roundi(_sim_config.respawn_fade_s / DT) + 1)
	assert_int(_audio.collision_count).is_equal(1)


func test_one_impact_per_crash_in_the_exam() -> void:
	_start(LaunchOptions.MODE_EXAM)
	_drive()
	_crash()
	assert_int(_session.state).is_equal(SessionManager.State.ENDED)
	assert_int(_audio.collision_count).is_equal(1)
	assert_int(_audio.offroad_count).is_equal(0)


func test_one_rumble_per_exit_from_the_road(mode: StringName, test_parameters: Array = [
		[LaunchOptions.MODE_LEARN],
		[LaunchOptions.MODE_EXAM],
		]) -> void:
	_start(mode)
	_drive()
	_leave_the_road()
	assert_bool(_session.state != SessionManager.State.DRIVING).is_true()
	assert_int(_audio.offroad_count).is_equal(1)
	assert_int(_audio.collision_count).is_equal(0)


func test_an_ai_collision_makes_no_sound() -> void:
	_drive()
	var sim: TrafficSim = _session.sim
	var collisions: Array[int] = [0]
	sim.collision.connect(func(_a: int, _b: int) -> void: collisions[0] += 1)
	sim.add_vehicle(_session.player.s + 300.0, 1, 0.0)
	sim.add_vehicle(_session.player.s + 301.0, 1, 0.0)
	_step(1)
	assert_int(collisions[0]).is_equal(1)
	assert_int(_audio.collision_count).is_equal(0)


func test_each_pass_plays_one_whoosh_and_steals_the_oldest_voice() -> void:
	_drive()
	var player: VehicleState = _session.player
	var voices: int = _audio_config.pass_voices
	# More close, fast vehicles than voices, all overtaking on the left at once.
	for i: int in voices + 1:
		_session.sim.add_vehicle(player.s - 12.0 - 8.0 * i, 1, player.speed_mps + 50.0 / TrafficSim.KMH_PER_MPS)
	_step(240)
	assert_int(_audio.pass_count).is_equal(voices + 1)
	assert_int(_audio.pass_players.size()).is_equal(voices)
	for voice: AudioStreamPlayer in _audio.pass_players:
		assert_str(voice.bus).is_equal(AudioView.EFFECTS_BUS)
		assert_float(voice.volume_db).is_between(_audio_config.pass_volume_min_db, _audio_config.pass_volume_max_db)


func test_a_paused_session_hears_no_pass() -> void:
	_drive()
	var player: VehicleState = _session.player
	_session.sim.add_vehicle(player.s - 12.0, 1, player.speed_mps + 50.0 / TrafficSim.KMH_PER_MPS)
	_session.pause()
	_step(120)
	assert_int(_audio.pass_count).is_equal(0)
	_session.resume()
	_step(120)
	assert_int(_audio.pass_count).is_equal(1)


func test_no_click_when_a_respawn_switches_the_indicator_off() -> void:
	_drive()
	_step(1, _signal(VehicleState.Dir.LEFT))
	assert_bool(SignalBlink.is_lit(_session.player, _session.sim.time_s, _view().signal_blink_hz)).is_true()
	var tocks: int = _audio.tock_count
	_crash()
	_step(roundi(_sim_config.respawn_fade_s / DT) + 1)
	assert_int(_session.respawn_count).is_equal(1)
	assert_int(_session.player.signal_dir).is_equal(VehicleState.Dir.NONE)
	assert_int(_audio.tock_count).is_equal(tocks)


func test_leaving_restores_the_master_bus() -> void:
	_audio.toggle_mute()
	_audio.free()
	var master: int = AudioServer.get_bus_index(AudioView.MASTER_BUS)
	assert_bool(AudioServer.is_bus_mute(master)).is_false()
	assert_float(AudioServer.get_bus_volume_db(master)).is_equal(0.0)
