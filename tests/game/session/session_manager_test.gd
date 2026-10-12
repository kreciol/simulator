extends GdUnitTestSuite
## Session flow: 3-2-1 intro, then a timed drive that ends after the configured
## session length (issue #8 acceptance criteria, spec Phase 3 step 3).

const DT: float = 1.0 / 60.0

var _config: SimConfig
var _session: SessionManager


func before_test() -> void:
	_config = load("res://config/sim_config.tres") as SimConfig
	_session = auto_free(SessionManager.new()) as SessionManager
	_session.setup(load("res://config/road_profiles/motorway.tres") as RoadProfile, _config)


func _steps_for(duration_s: float) -> int:
	return roundi(duration_s / DT)


func _step(steps: int, commands: PlayerCommands = null) -> void:
	for i: int in steps:
		_session.step(DT, commands)


func _accelerate() -> PlayerCommands:
	var commands: PlayerCommands = PlayerCommands.new()
	commands.longitudinal = VehicleState.Longitudinal.ACCELERATE
	return commands


func test_session_length_is_ninety_seconds_after_a_three_second_countdown() -> void:
	assert_float(_config.session_length_s).is_equal(90.0)
	assert_float(_config.countdown_s).is_equal(3.0)


func test_player_starts_on_the_right_lane_at_the_start_speed() -> void:
	assert_int(_session.state).is_equal(SessionManager.State.INTRO)
	assert_object(_session.sim.player).is_same(_session.player)
	assert_int(_session.player.lane).is_equal(0)
	assert_float(_session.player.speed_mps * TrafficSim.KMH_PER_MPS).is_equal_approx(_config.start_speed_kmh, 1e-6)


func test_countdown_runs_before_the_session_timer_starts() -> void:
	var started: Array[bool] = [false]
	_session.session_started.connect(func() -> void: started[0] = true)
	assert_float(_session.countdown_left_s()).is_equal(_config.countdown_s)
	_step(_steps_for(_config.countdown_s) - 1, _accelerate())
	# Still counting down: the timer has not started, the car is frozen, input dropped.
	assert_int(_session.state).is_equal(SessionManager.State.INTRO)
	assert_bool(started[0]).is_false()
	assert_float(_session.countdown_left_s()).is_greater(0.0)
	assert_float(_session.elapsed_s).is_equal(0.0)
	assert_float(_session.time_left_s()).is_equal(_config.session_length_s)
	assert_float(_session.sim.time_s).is_equal(0.0)
	assert_float(_session.player.s).is_equal(0.0)
	assert_float(_session.player.speed_mps * TrafficSim.KMH_PER_MPS).is_equal_approx(_config.start_speed_kmh, 1e-6)
	assert_int(_session.sim.input_log.size()).is_equal(0)

	_step(1)
	assert_int(_session.state).is_equal(SessionManager.State.DRIVING)
	assert_bool(started[0]).is_true()
	assert_float(_session.countdown_left_s()).is_equal(0.0)


func test_driving_steps_the_sim_and_runs_the_timer() -> void:
	_step(_steps_for(_config.countdown_s))
	_step(60, _accelerate())
	assert_float(_session.elapsed_s).is_equal_approx(1.0, 1e-9)
	assert_float(_session.time_left_s()).is_equal_approx(_config.session_length_s - 1.0, 1e-9)
	assert_float(_session.sim.time_s).is_equal_approx(1.0, 1e-9)
	assert_float(_session.player.s).is_greater(0.0)
	assert_float(_session.player.speed_mps * TrafficSim.KMH_PER_MPS).is_greater(_config.start_speed_kmh)


func test_session_ends_after_ninety_seconds_of_simulated_time() -> void:
	var ended: Array[int] = [0]
	_session.session_ended.connect(func() -> void: ended[0] += 1)
	_step(_steps_for(_config.countdown_s))
	_step(_steps_for(_config.session_length_s) - 1)
	assert_int(_session.state).is_equal(SessionManager.State.DRIVING)
	assert_int(ended[0]).is_equal(0)

	_step(1)
	assert_int(_session.state).is_equal(SessionManager.State.ENDED)
	assert_int(ended[0]).is_equal(1)
	assert_float(_session.sim.time_s).is_equal_approx(_config.session_length_s, 1e-6)
	assert_float(_session.time_left_s()).is_equal(0.0)


func test_nothing_advances_after_the_end() -> void:
	var ended: Array[int] = [0]
	_session.session_ended.connect(func() -> void: ended[0] += 1)
	_step(_steps_for(_config.countdown_s + _config.session_length_s))
	var s_at_end: float = _session.player.s
	var time_at_end: float = _session.sim.time_s
	_step(120, _accelerate())
	assert_int(_session.state).is_equal(SessionManager.State.ENDED)
	assert_int(ended[0]).is_equal(1)
	assert_float(_session.player.s).is_equal(s_at_end)
	assert_float(_session.sim.time_s).is_equal(time_at_end)
	assert_float(_session.time_left_s()).is_equal(0.0)


func test_start_uses_the_launch_options_profile_and_seed() -> void:
	var launcher: DevLauncherConfig = load("res://config/dev_launcher.tres") as DevLauncherConfig
	var options: LaunchOptions = DevLauncher.resolve(
			DevLauncher.parse_query("?mode=exam&profile=expressway&level=2&seed=42"), launcher, 0)
	var session: SessionManager = auto_free(SessionManager.new()) as SessionManager
	session.start(options, _config)
	assert_object(session.options).is_same(options)
	assert_str(session.options.mode).is_equal(LaunchOptions.MODE_EXAM)
	assert_int(session.options.level).is_equal(2)
	assert_str(session.sim.road.id).is_equal(&"expressway")
	assert_int(session.sim.rng_seed).is_equal(42)
	assert_int(session.state).is_equal(SessionManager.State.INTRO)
	assert_int(session.player.lane).is_equal(0)


func test_start_brings_traffic_at_the_launch_options_level() -> void:
	var launcher: DevLauncherConfig = load("res://config/dev_launcher.tres") as DevLauncherConfig
	var options: LaunchOptions = DevLauncher.resolve(DevLauncher.parse_query("?level=3&seed=5"), launcher, 0)
	var session: SessionManager = auto_free(SessionManager.new()) as SessionManager
	session.start(options, _config)
	var spawner: Spawner = session.sim.spawner
	assert_object(spawner).is_not_null()
	assert_object(spawner.level).is_same(options.difficulty)
	assert_int(spawner.level.id).is_equal(3)
	# The window is filled before the countdown, so traffic is there from the first frame.
	assert_int(spawner.count_in_window(session.sim)).is_greater(0)
	assert_int(session.sim.vehicles.size()).is_equal(spawner.count_in_window(session.sim) + 1)


func test_setup_alone_leaves_the_road_empty() -> void:
	assert_object(_session.sim.spawner).is_null()
	assert_int(_session.sim.vehicles.size()).is_equal(1)
