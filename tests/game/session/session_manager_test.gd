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


## Drops a stopped car just ahead of the player and drives until the player hits it.
func _crash_into_a_stopped_car() -> VehicleState:
	var player: VehicleState = _session.player
	var wreck: VehicleState = _session.sim.add_vehicle(player.s + player.length_m + 1.0, 0, 0.0)
	var steps: int = 0
	while _session.state == SessionManager.State.DRIVING and steps < 120:
		_step(1)
		steps += 1
	return wreck


func _leave_the_road() -> void:
	var right: PlayerCommands = PlayerCommands.new()
	right.lane_change = VehicleState.Dir.RIGHT
	_step(1, right)
	_step(_steps_for(_config.lane_change_duration_s))


func _start_learn_with_scoring() -> Array[int]:
	_session.setup(load("res://config/road_profiles/motorway.tres") as RoadProfile, _config, 0,
			LaunchOptions.MODE_LEARN, _scoring_config())
	return _start_driving()


func _scoring_config() -> ScoringConfig:
	return load("res://config/scoring.tres") as ScoringConfig


func _k4_events() -> Array[ScoreEvent]:
	var events: Array[ScoreEvent] = []
	for event: ScoreEvent in _session.scoring.event_log.events:
		if event.category == CollisionRule.CATEGORY:
			events.append(event)
	return events


func test_a_learn_collision_charges_k4_and_starts_a_respawn() -> void:
	var ended: Array[int] = _start_learn_with_scoring()
	_step(30)
	var wreck: VehicleState = _crash_into_a_stopped_car()
	assert_int(_session.state).is_equal(SessionManager.State.RESPAWNING)
	assert_int(_session.respawn_cause).is_equal(SessionManager.EndReason.COLLISION)
	assert_bool(_session.sim.vehicles_overlap(_session.player, wreck)).is_true()
	var k4: Array[ScoreEvent] = _k4_events()
	assert_array(k4).has_size(1)
	assert_str(k4[0].type).is_equal(CollisionRule.TYPE_COLLISION)
	assert_float(k4[0].points).is_equal(-_scoring_config().k4_penalty)
	assert_int(ended[0]).is_equal(0)
	assert_int(_session.end_reason).is_equal(SessionManager.EndReason.NONE)


func test_a_learn_respawn_puts_the_player_on_a_free_right_lane_at_the_respawn_speed() -> void:
	_start_learn_with_scoring()
	_step(30)
	var respawned: Array[int] = [0]
	_session.player_respawned.connect(func() -> void: respawned[0] += 1)
	var wreck: VehicleState = _crash_into_a_stopped_car()
	var fade_steps: int = _steps_for(_config.respawn_fade_s)
	# Frozen and faded out until the midpoint; input is dropped.
	_step(fade_steps / 2 - 1, _accelerate())
	assert_int(respawned[0]).is_equal(0)
	assert_float(_session.fade_amount()).is_greater(0.9)
	_step(1, _accelerate())
	assert_int(respawned[0]).is_equal(1)
	var player: VehicleState = _session.player
	assert_int(player.lane).is_equal(0)
	assert_bool(player.off_road).is_false()
	assert_float(player.speed_mps * TrafficSim.KMH_PER_MPS).is_equal_approx(_config.respawn_speed_kmh, 1e-6)
	assert_bool(Respawn.is_window_free(_session.sim, player.s)).is_true()
	assert_bool(_session.sim.vehicles_overlap(player, wreck)).is_false()
	_step(fade_steps - fade_steps / 2)
	assert_int(_session.state).is_equal(SessionManager.State.DRIVING)
	assert_float(_session.fade_amount()).is_equal(0.0)
	assert_int(_session.respawn_count).is_equal(1)
	# Drives on, and a new collision would be charged again.
	var s_before: float = player.s
	_step(60)
	assert_float(player.s).is_greater(s_before)
	assert_array(_k4_events()).has_size(1)


func test_leaving_the_road_in_learn_mode_charges_k4_and_respawns() -> void:
	var ended: Array[int] = _start_learn_with_scoring()
	_leave_the_road()
	assert_int(_session.state).is_equal(SessionManager.State.RESPAWNING)
	assert_int(_session.respawn_cause).is_equal(SessionManager.EndReason.OFF_ROAD)
	var k4: Array[ScoreEvent] = _k4_events()
	assert_array(k4).has_size(1)
	assert_str(k4[0].type).is_equal(CollisionRule.TYPE_OFFROAD)
	_step(_steps_for(_config.respawn_fade_s))
	assert_int(_session.state).is_equal(SessionManager.State.DRIVING)
	assert_bool(_session.player.off_road).is_false()
	assert_int(_session.player.lane).is_equal(0)
	assert_int(ended[0]).is_equal(0)


func test_the_timer_is_neither_reset_nor_paused_by_a_respawn() -> void:
	var ended: Array[int] = _start_learn_with_scoring()
	_step(30)
	_session.sim.remove_vehicle(_crash_into_a_stopped_car())
	var elapsed_at_crash: float = _session.elapsed_s
	var fade_steps: int = _steps_for(_config.respawn_fade_s)
	_step(fade_steps)
	assert_float(_session.elapsed_s).is_equal_approx(elapsed_at_crash + fade_steps * DT, 1e-9)
	assert_float(_session.time_left_s()).is_equal_approx(_config.session_length_s - _session.elapsed_s, 1e-9)
	# The session still ends 90 s after the countdown, respawn included.
	var steps_left: int = roundi((_config.session_length_s - _session.elapsed_s) / DT)
	_step(steps_left - 1)
	assert_int(_session.state).is_not_equal(SessionManager.State.ENDED)
	_step(1)
	assert_int(_session.state).is_equal(SessionManager.State.ENDED)
	assert_int(_session.end_reason).is_equal(SessionManager.EndReason.TIME_UP)
	assert_str(_session.status()).is_equal(SessionRecord.STATUS_COMPLETED)
	assert_int(ended[0]).is_equal(1)


func test_time_running_out_during_a_respawn_ends_the_session() -> void:
	var ended: Array[int] = _start_learn_with_scoring()
	var change_steps: int = _steps_for(_config.lane_change_duration_s)
	var quarter_fade_steps: int = _steps_for(_config.respawn_fade_s / 4.0)
	_step(_steps_for(_config.session_length_s) - change_steps - 1 - quarter_fade_steps)
	_leave_the_road()
	assert_int(_session.state).is_equal(SessionManager.State.RESPAWNING)
	_step(quarter_fade_steps)
	assert_int(_session.state).is_equal(SessionManager.State.ENDED)
	assert_int(_session.end_reason).is_equal(SessionManager.EndReason.TIME_UP)
	assert_int(ended[0]).is_equal(1)


func test_a_respawn_resets_the_overtake_memory() -> void:
	_start_learn_with_scoring()
	var rule: LaneChangeRule = _session.scoring.lane_change_rule
	rule._overtake_started = true
	_leave_the_road()
	_step(_steps_for(_config.respawn_fade_s))
	assert_bool(rule._overtake_started).is_false()


func test_ai_cars_touching_each_other_do_not_end_the_session() -> void:
	_start_driving()
	var sim: TrafficSim = _session.sim
	# Two scripted cars far ahead of the player, overlapping.
	sim.add_vehicle(_session.player.s + 300.0, 1, 0.0)
	sim.add_vehicle(_session.player.s + 301.0, 1, 0.0)
	_step(10)
	assert_int(_session.state).is_equal(SessionManager.State.DRIVING)
	assert_int(_session.end_reason).is_equal(SessionManager.EndReason.NONE)


func test_an_ai_collision_despawns_both_silently_and_charges_nothing(mode: StringName, test_parameters: Array = [
		[LaunchOptions.MODE_LEARN],
		[LaunchOptions.MODE_EXAM],
		]) -> void:
	_session.setup(load("res://config/road_profiles/motorway.tres") as RoadProfile, _config, 0, mode, _scoring_config())
	Spawner.new(load("res://config/difficulty_levels/level_1.tres") as DifficultyLevel).attach(_session.sim)
	_start_driving()
	var sim: TrafficSim = _session.sim
	var removed: Array[int] = []
	sim.vehicle_removed.connect(func(vehicle_id: int) -> void: removed.append(vehicle_id))
	# Two AI cars overlapping on the left lane well ahead of the player.
	var a: VehicleState = sim.add_ai_vehicle(_session.player.s + 300.0, 1, 0.0, 0.0, 1.0)
	var b: VehicleState = sim.add_ai_vehicle(_session.player.s + 301.0, 1, 0.0, 0.0, 1.0)
	_step(1)
	assert_array(removed).contains([a.id, b.id])
	assert_object(sim.find_vehicle(a.id)).is_null()
	assert_object(sim.find_vehicle(b.id)).is_null()
	assert_array(_k4_events()).is_empty()
	assert_int(_session.state).is_equal(SessionManager.State.DRIVING)
	assert_int(_session.respawn_count).is_equal(0)


func test_the_mode_from_the_url_is_active(query: String, mode: StringName, exam: bool, test_parameters: Array = [
		["?mode=learn", LaunchOptions.MODE_LEARN, false],
		["?mode=exam", LaunchOptions.MODE_EXAM, true],
		]) -> void:
	var launcher: DevLauncherConfig = load("res://config/dev_launcher.tres") as DevLauncherConfig
	var options: LaunchOptions = DevLauncher.resolve(DevLauncher.parse_query(query), launcher, 0)
	var session: SessionManager = auto_free(SessionManager.new()) as SessionManager
	session.start(options, _config)
	assert_str(session.mode).is_equal(mode)
	assert_bool(session.is_exam()).is_equal(exam)


func test_setup_alone_is_a_learn_session() -> void:
	assert_str(_session.mode).is_equal(LaunchOptions.MODE_LEARN)
	assert_bool(_session.is_exam()).is_false()
	assert_str(_session.status()).is_empty()


func _start_exam() -> Array[int]:
	_session.setup(load("res://config/road_profiles/motorway.tres") as RoadProfile, _config, 0,
			LaunchOptions.MODE_EXAM)
	return _start_driving()


func test_exam_collision_ends_the_session_as_aborted_collision() -> void:
	var ended: Array[int] = _start_exam()
	_step(30)
	var player: VehicleState = _session.player
	_session.sim.add_vehicle(player.s + player.length_m + 1.0, 0, 0.0)
	var steps: int = 0
	while _session.state == SessionManager.State.DRIVING and steps < 120:
		_step(1)
		steps += 1
	assert_int(_session.state).is_equal(SessionManager.State.ENDED)
	assert_int(_session.end_reason).is_equal(SessionManager.EndReason.COLLISION)
	assert_str(_session.status()).is_equal(SessionRecord.STATUS_ABORTED_COLLISION)
	assert_float(_session.elapsed_s).is_less(_config.session_length_s)
	assert_int(ended[0]).is_equal(1)


func test_exam_leaving_the_road_ends_the_session_as_aborted_offroad() -> void:
	var ended: Array[int] = _start_exam()
	var right: PlayerCommands = PlayerCommands.new()
	right.lane_change = VehicleState.Dir.RIGHT
	_step(1, right)
	_step(_steps_for(_config.lane_change_duration_s))
	assert_bool(_session.player.off_road).is_true()
	assert_int(_session.state).is_equal(SessionManager.State.ENDED)
	assert_str(_session.status()).is_equal(SessionRecord.STATUS_ABORTED_OFFROAD)
	assert_int(ended[0]).is_equal(1)


func test_exam_without_an_incident_completes_after_ninety_seconds() -> void:
	var ended: Array[int] = _start_exam()
	_step(_steps_for(_config.session_length_s) - 1)
	assert_int(_session.state).is_equal(SessionManager.State.DRIVING)
	assert_str(_session.status()).is_empty()
	_step(1)
	assert_int(_session.state).is_equal(SessionManager.State.ENDED)
	assert_str(_session.status()).is_equal(SessionRecord.STATUS_COMPLETED)
	assert_int(ended[0]).is_equal(1)
