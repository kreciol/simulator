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


func _start_driving() -> Array[int]:
	var ended: Array[int] = [0]
	_session.session_ended.connect(func() -> void: ended[0] += 1)
	_step(_steps_for(_config.countdown_s))
	return ended


func test_session_ends_with_time_up_after_a_clean_drive() -> void:
	var ended: Array[int] = _start_driving()
	assert_int(_session.end_reason).is_equal(SessionManager.EndReason.NONE)
	_step(_steps_for(_config.session_length_s))
	assert_int(_session.state).is_equal(SessionManager.State.ENDED)
	assert_int(_session.end_reason).is_equal(SessionManager.EndReason.TIME_UP)
	assert_int(ended[0]).is_equal(1)


func test_a_forced_collision_ends_the_session_once() -> void:
	var ended: Array[int] = _start_driving()
	_step(30)
	# A stopped car dropped just ahead: the player runs into it within a few steps.
	var player: VehicleState = _session.player
	var wreck: VehicleState = _session.sim.add_vehicle(player.s + player.length_m + 1.0, 0, 0.0)
	var steps: int = 0
	while _session.state == SessionManager.State.DRIVING and steps < 120:
		_step(1)
		steps += 1
	assert_int(_session.state).is_equal(SessionManager.State.ENDED)
	assert_int(_session.end_reason).is_equal(SessionManager.EndReason.COLLISION)
	assert_int(ended[0]).is_equal(1)
	assert_bool(_session.sim.vehicles_overlap(player, wreck)).is_true()
	# Ended early, and frozen from then on.
	assert_float(_session.elapsed_s).is_less(_config.session_length_s)
	var time_at_end: float = _session.sim.time_s
	_step(60, _accelerate())
	assert_float(_session.sim.time_s).is_equal(time_at_end)
	assert_int(ended[0]).is_equal(1)


func test_leaving_the_road_ends_the_session() -> void:
	var ended: Array[int] = _start_driving()
	var right: PlayerCommands = PlayerCommands.new()
	right.lane_change = VehicleState.Dir.RIGHT
	_step(1, right)
	_step(_steps_for(_config.lane_change_duration_s) - 2)
	assert_int(_session.state).is_equal(SessionManager.State.DRIVING)
	_step(2)
	assert_bool(_session.player.off_road).is_true()
	assert_int(_session.state).is_equal(SessionManager.State.ENDED)
	assert_int(_session.end_reason).is_equal(SessionManager.EndReason.OFF_ROAD)
	assert_int(ended[0]).is_equal(1)


func test_ai_cars_touching_each_other_do_not_end_the_session() -> void:
	_start_driving()
	var sim: TrafficSim = _session.sim
	# Two scripted cars far ahead of the player, overlapping.
	sim.add_vehicle(_session.player.s + 300.0, 1, 0.0)
	sim.add_vehicle(_session.player.s + 301.0, 1, 0.0)
	_step(10)
	assert_int(_session.state).is_equal(SessionManager.State.DRIVING)
	assert_int(_session.end_reason).is_equal(SessionManager.EndReason.NONE)


func _scored_session(query: String) -> SessionManager:
	var launcher: DevLauncherConfig = load("res://config/dev_launcher.tres") as DevLauncherConfig
	var session: SessionManager = auto_free(SessionManager.new()) as SessionManager
	session.scoring_config = load("res://config/scoring.tres") as ScoringConfig
	var options: LaunchOptions = DevLauncher.resolve(DevLauncher.parse_query(query), launcher, 0)
	# Started on an empty road (no level, no spawner) so the hands-off player drives the
	# whole session clean; the level and its pass mark are only read at the end.
	var level: DifficultyLevel = options.difficulty
	options.difficulty = null
	session.start(options, _config)
	options.difficulty = level
	return session


func test_without_a_scoring_config_there_is_no_record() -> void:
	_step(_steps_for(_config.countdown_s + _config.session_length_s))
	assert_int(_session.state).is_equal(SessionManager.State.ENDED)
	assert_object(_session.scoring).is_null()
	assert_object(_session.record).is_null()


func test_a_session_that_runs_out_of_time_ends_with_a_completed_record() -> void:
	var session: SessionManager = _scored_session("?mode=learn&profile=expressway&level=2&seed=42")
	for i: int in _steps_for(_config.countdown_s + _config.session_length_s):
		session.step(DT)
	assert_int(session.end_reason).is_equal(SessionManager.EndReason.TIME_UP)
	var record: SessionRecord = session.record
	assert_object(record).is_not_null()
	assert_str(record.status).is_equal(SessionRecord.STATUS_COMPLETED)
	assert_str(record.mode).is_equal(SessionRecord.MODE_LEARN)
	assert_str(record.road_profile).is_equal(&"expressway")
	assert_int(record.difficulty).is_equal(2)
	assert_int(record.seed_value).is_equal(42)
	assert_float(record.duration_s).is_equal_approx(_config.session_length_s, 1e-6)
	assert_float(record.score_total).is_equal(session.scoring.total_score())
	assert_that(record.exam_passed).is_null()
	assert_str(record.app_version).is_equal(str(ProjectSettings.get_setting("application/config/version")))
	assert_str(record.started_at).ends_with("Z")
	assert_bool(Time.get_unix_time_from_datetime_string(record.started_at.trim_suffix("Z")) > 0).is_true()
	# A version-4 UUID.
	assert_int(record.id.length()).is_equal(36)
	assert_str(record.id.substr(14, 1)).is_equal("4")


func test_every_session_gets_its_own_id() -> void:
	var first: SessionManager = _scored_session("?seed=1")
	var second: SessionManager = _scored_session("?seed=1")
	for session: SessionManager in [first, second]:
		for i: int in _steps_for(_config.countdown_s + _config.session_length_s):
			session.step(DT)
	assert_str(first.record.id).is_not_equal(second.record.id)


func test_an_exam_record_carries_the_verdict_against_the_level_pass_mark() -> void:
	var session: SessionManager = _scored_session("?mode=exam&level=1&seed=7")
	for i: int in _steps_for(_config.countdown_s + _config.session_length_s):
		session.step(DT)
	var record: SessionRecord = session.record
	assert_str(record.mode).is_equal(SessionRecord.MODE_EXAM)
	assert_that(record.exam_passed).is_equal(record.score_total >= session.options.difficulty.exam_pass_score)


func test_a_crash_gives_an_aborted_record() -> void:
	var session: SessionManager = _scored_session("?mode=exam&level=1&seed=7")
	for i: int in _steps_for(_config.countdown_s) + 30:
		session.step(DT)
	var player: VehicleState = session.player
	session.sim.add_vehicle(player.s + player.length_m + 1.0, 0, 0.0)
	var steps: int = 0
	while session.state == SessionManager.State.DRIVING and steps < 120:
		session.step(DT)
		steps += 1
	assert_int(session.end_reason).is_equal(SessionManager.EndReason.COLLISION)
	assert_str(session.record.status).is_equal(SessionRecord.STATUS_ABORTED_COLLISION)
	assert_float(session.record.duration_s).is_less(_config.session_length_s)
	assert_that(session.record.exam_passed).is_equal(false)


func test_leaving_the_road_gives_an_aborted_offroad_record() -> void:
	var session: SessionManager = _scored_session("?seed=3")
	for i: int in _steps_for(_config.countdown_s):
		session.step(DT)
	var right: PlayerCommands = PlayerCommands.new()
	right.lane_change = VehicleState.Dir.RIGHT
	session.step(DT, right)
	for i: int in _steps_for(_config.lane_change_duration_s):
		session.step(DT)
	assert_int(session.end_reason).is_equal(SessionManager.EndReason.OFF_ROAD)
	assert_str(session.record.status).is_equal(SessionRecord.STATUS_ABORTED_OFFROAD)
