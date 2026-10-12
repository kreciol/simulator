extends GdUnitTestSuite
## The main scene drives the sim from the keyboard and renders it from the cockpit
## (issue #7 acceptance criteria, spec Phase 3 steps 1–2) once the session's
## countdown is over (issue #8, step 3).

const DT: float = 1.0 / 60.0
## Sessions finished here are saved to this file, never to the player's real history.
const TEST_HISTORY: String = "user://test_main_scene/history.json"

var _runner: GdUnitSceneRunner
var _main: Node3D
var _real_store: HistoryStore


func before_test() -> void:
	_real_store = SaveManager.store
	_clear_test_history()
	SaveManager.store = HistoryStore.new(TEST_HISTORY, 5)
	SaveManager.store.userfs_persistent = true
	SaveManager.store.load_history()
	_runner = scene_runner("res://game/main.tscn")
	_main = _runner.scene() as Node3D
	_finish_countdown()


func after_test() -> void:
	SaveManager.store = _real_store
	_clear_test_history()


func _clear_test_history() -> void:
	var dir: String = TEST_HISTORY.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		return
	for file_name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file_name))
	DirAccess.remove_absolute(dir)


func _finish_countdown() -> void:
	while _main.session.state == SessionManager.State.INTRO:
		_main._physics_process(DT)


## Steps the sim deterministically, as `_physics_process` does, then refreshes the views.
func _drive(steps: int) -> void:
	for i: int in steps:
		_main._physics_process(DT)
	_main._process(DT)


func _player() -> VehicleState:
	return _main.player as VehicleState


func _road_view() -> RoadView:
	return _main.get_node("RoadView") as RoadView


func _player_view() -> PlayerView:
	return _main.get_node("PlayerView") as PlayerView


func test_scene_shows_road_and_cockpit_camera() -> void:
	assert_int(_road_view().segments().size()).is_greater(0)
	var camera: Camera3D = _player_view().camera
	assert_bool(camera.is_current()).is_true()
	assert_object(_player_view().dashboard).is_not_null()
	assert_object(_player_view().bonnet).is_not_null()
	assert_int(_player().lane).is_equal(0)


func test_player_starts_on_the_right_lane_at_the_start_speed() -> void:
	assert_int(_player().lane).is_equal(0)
	assert_float(_player().speed_mps * TrafficSim.KMH_PER_MPS).is_equal_approx(_main.sim_config.start_speed_kmh, 1e-6)


func test_countdown_runs_first_and_holds_the_car() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://game/main.tscn")
	var main: Node3D = runner.scene() as Node3D
	var session: SessionManager = main.session
	assert_int(session.state).is_equal(SessionManager.State.INTRO)
	var hud: Hud = main.get_node("Hud") as Hud
	assert_bool(hud.countdown_label.visible).is_true()
	assert_str(hud.time_label.text).is_equal("1:30")
	runner.simulate_key_press(KEY_A)
	runner.simulate_key_release(KEY_A)
	await runner.await_input_processed()
	var s_before: float = main.player.s
	while session.state == SessionManager.State.INTRO:
		main._physics_process(DT)
	# Frozen through the countdown: no movement, the lane change press was dropped.
	assert_float(main.player.s).is_equal(s_before)
	main._physics_process(DT)
	assert_float(main.player.s).is_greater(s_before)
	assert_bool(main.player.lane_change_active).is_false()


func test_holding_w_accelerates_smoothly_and_moves_the_road() -> void:
	var segment: MeshInstance3D = _road_view().segments()[0]
	var z_before: float = segment.position.z
	_runner.simulate_key_press(KEY_W)
	await _runner.await_input_processed()
	var previous_speed: float = _player().speed_mps
	var max_step_change: float = 0.0
	for i: int in 120:
		_drive(1)
		max_step_change = maxf(max_step_change, _player().speed_mps - previous_speed)
		assert_float(_player().speed_mps).is_greater(previous_speed)
		previous_speed = _player().speed_mps
	# Smooth: no step changes speed by more than the configured acceleration allows.
	assert_float(max_step_change).is_less_equal(_main.sim_config.acceleration_mps2 * DT + 1e-9)
	assert_float(segment.position.z).is_not_equal(z_before)

	_runner.simulate_key_release(KEY_W)
	_runner.simulate_key_press(KEY_S)
	await _runner.await_input_processed()
	var cruising: float = _player().speed_mps
	_drive(30)
	assert_float(_player().speed_mps).is_less(cruising)
	_runner.simulate_key_release(KEY_S)
	await _runner.await_input_processed()


func test_a_changes_lane_with_animation_and_moves_the_camera_left() -> void:
	_runner.simulate_key_press(KEY_D)
	_runner.simulate_key_release(KEY_D)
	_runner.simulate_key_press(KEY_A)
	_runner.simulate_key_release(KEY_A)
	await _runner.await_input_processed()
	var x_start: float = _player_view().position.x
	_drive(1)
	# The later press in the step wins: a left change, animated rather than instant.
	assert_bool(_player().lane_change_active).is_true()
	assert_int(_player().lane_change_to).is_equal(1)
	assert_float(_player_view().position.x).is_less(x_start)
	assert_float(_player_view().position.x).is_greater(RoadLayout.x_of(_main.road_profile.lane_center(1)))
	_drive(roundi(_main.sim_config.lane_change_duration_s / DT))
	assert_int(_player().lane).is_equal(1)
	assert_float(_player_view().position.x).is_equal_approx(RoadLayout.x_of(_main.road_profile.lane_center(1)), 1e-5)


func test_q_and_e_toggle_the_signal() -> void:
	_runner.simulate_key_press(KEY_Q)
	_runner.simulate_key_release(KEY_Q)
	await _runner.await_input_processed()
	_drive(1)
	assert_int(_player().signal_dir).is_equal(VehicleState.Dir.LEFT)
	assert_bool(_player_view().signal_left.visible).is_true()
	_runner.simulate_key_press(KEY_E)
	_runner.simulate_key_release(KEY_E)
	await _runner.await_input_processed()
	_drive(1)
	assert_int(_player().signal_dir).is_equal(VehicleState.Dir.RIGHT)
	_runner.simulate_key_press(KEY_E)
	_runner.simulate_key_release(KEY_E)
	await _runner.await_input_processed()
	_drive(1)
	assert_int(_player().signal_dir).is_equal(VehicleState.Dir.NONE)


func test_unmapped_key_does_nothing_to_the_vehicle() -> void:
	var speed: float = _player().speed_mps
	_runner.simulate_key_press(KEY_X)
	_runner.simulate_key_release(KEY_X)
	_runner.simulate_key_press(KEY_SPACE)
	await _runner.await_input_processed()
	_drive(30)
	# The car just cruises on: same speed, lane and signal state.
	assert_int(_player().longitudinal).is_equal(VehicleState.Longitudinal.NONE)
	assert_float(_player().speed_mps).is_equal(speed)
	assert_int(_player().lane).is_equal(0)
	assert_bool(_player().lane_change_active).is_false()
	assert_int(_player().signal_dir).is_equal(VehicleState.Dir.NONE)
	_runner.simulate_key_release(KEY_SPACE)
	await _runner.await_input_processed()


func test_scene_starts_from_the_dev_launcher_defaults_without_params() -> void:
	# The headless test run passes no user args, so every launch option is a default.
	var launcher: DevLauncherConfig = _main.launcher_config
	var options: LaunchOptions = _main.session.options
	assert_object(options).is_same(_main.launch_options)
	assert_str(options.mode).is_equal(launcher.default_mode)
	assert_int(options.level).is_equal(launcher.default_level)
	assert_object(_main.road_profile).is_same(launcher.find_profile(launcher.default_profile))
	assert_object(_main.sim.road).is_same(_main.road_profile)
	assert_int(_main.sim.rng_seed).is_equal(options.seed_value)


func _traffic_view() -> TrafficView:
	return _main.get_node("TrafficView") as TrafficView


func test_scene_shows_traffic_at_the_launch_level() -> void:
	var sim: TrafficSim = _main.sim
	assert_object(sim.spawner).is_not_null()
	assert_int(sim.spawner.level.id).is_equal(_main.launch_options.level)
	assert_int(sim.vehicles.size()).is_greater(1)
	_drive(60)
	assert_int(_traffic_view().live_count()).is_equal(sim.vehicles.size() - 1)


func test_hitting_a_car_in_learn_mode_charges_k4_fades_and_drives_on() -> void:
	var hud: Hud = _main.get_node("Hud") as Hud
	var session: SessionManager = _main.session
	assert_bool(session.is_exam()).is_false()
	assert_object(session.scoring).is_not_null()
	# A stopped car right ahead of the player.
	var wreck: VehicleState = _main.sim.add_vehicle(_player().s + _player().length_m + 1.0, 0, 0.0)
	assert_object(_traffic_view().view_of(wreck.id)).is_not_null()
	var steps: int = 0
	while session.state == SessionManager.State.DRIVING and steps < 120:
		_drive(1)
		steps += 1
	assert_int(session.state).is_equal(SessionManager.State.RESPAWNING)
	assert_float(session.scoring.category_score(CollisionRule.CATEGORY)).is_equal(-session.scoring.config.k4_penalty)
	assert_bool(hud.respawn_notice.visible).is_true()
	assert_bool(hud.ended_screen.visible).is_false()
	_drive(roundi(_main.sim_config.respawn_fade_s / DT))
	assert_int(session.state).is_equal(SessionManager.State.DRIVING)
	assert_int(_player().lane).is_equal(0)
	assert_bool(hud.respawn_notice.visible).is_false()
	assert_bool(hud.fade_screen.visible).is_false()
	assert_bool(_main.sim.vehicles_overlap(_player(), wreck)).is_false()


## One key press delivered to the scene exactly once. The scene runner hands each
## simulated event to the scene twice (through `Input` and directly), which a toggle
## like pause cannot tell apart from two presses.
func _tap(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		event.pressed = pressed
		_main._unhandled_input(event)


func test_esc_pauses_and_p_resumes_the_drive() -> void:
	# Issue #34: Esc or P freezes the drive until pressed again.
	var hud: Hud = _main.get_node("Hud") as Hud
	_tap(KEY_ESCAPE)
	assert_bool(_main.session.paused).is_true()
	_runner.simulate_key_press(KEY_W)
	_runner.simulate_key_press(KEY_A)
	_runner.simulate_key_release(KEY_A)
	await _runner.await_input_processed()
	var s_before: float = _player().s
	var time_left: float = _main.session.time_left_s()
	_drive(60)
	assert_float(_player().s).is_equal(s_before)
	assert_float(_main.session.time_left_s()).is_equal(time_left)
	assert_bool(_player().lane_change_active).is_false()
	assert_bool(hud.paused_screen.visible).is_true()

	_tap(KEY_P)
	assert_bool(_main.session.paused).is_false()
	_drive(1)
	assert_float(_player().s).is_greater(s_before)
	assert_bool(hud.paused_screen.visible).is_false()
	_runner.simulate_key_release(KEY_W)
	await _runner.await_input_processed()


func test_losing_focus_pauses_the_drive() -> void:
	_main.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_bool(_main.session.paused).is_true()
	var s_before: float = _player().s
	_drive(60)
	assert_float(_player().s).is_equal(s_before)


## Drives until the session ends; in learn mode a crash respawns, so only time ends it.
func _drive_to_the_end() -> void:
	var steps: int = 0
	var limit: int = roundi((_main.sim_config.session_length_s + _main.sim_config.countdown_s) / DT) + 10
	while _main.session.state != SessionManager.State.ENDED and steps < limit:
		_main._physics_process(DT)
		steps += 1
	_main._process(DT)


func test_a_finished_session_is_saved_and_survives_a_reload() -> void:
	var hud: Hud = _main.get_node("Hud") as Hud
	_drive_to_the_end()
	assert_int(_main.session.state).is_equal(SessionManager.State.ENDED)
	assert_str(hud.save_status_label.text).is_equal("Wynik zapisany w tej przeglądarce.")
	# The scene scores the drive, so the end screen is its summary (issue #38).
	assert_str(hud.ended_label.text).is_equal("Sesja ukończona")
	assert_bool(hud.ended_cause_label.visible).is_false()
	assert_bool(hud.summary_panel.is_visible_in_tree()).is_true()
	assert_str(hud.summary_panel.total_label.text).starts_with("Wynik: ")
	assert_str(hud.summary_panel.tip_label.text).starts_with("Wskazówka na następny raz
")

	# A reload reads the file afresh.
	var reloaded: HistoryStore = HistoryStore.new(TEST_HISTORY, 5)
	reloaded.userfs_persistent = true
	reloaded.load_history()
	assert_int(reloaded.sessions.size()).is_equal(1)
	var record: SessionRecord = SessionRecord.from_dict(reloaded.last_session())
	assert_str(record.id).is_equal(_main.session.record.id)
	assert_str(record.status).is_equal(SessionRecord.STATUS_COMPLETED)
	assert_int(record.seed_value).is_equal(_main.launch_options.seed_value)


func test_with_storage_unavailable_the_session_still_ends_and_explains_why() -> void:
	SaveManager.store.userfs_persistent = false
	SaveManager.store.load_history()
	var hud: Hud = _main.get_node("Hud") as Hud
	_drive_to_the_end()
	assert_int(_main.session.state).is_equal(SessionManager.State.ENDED)
	assert_bool(hud.ended_screen.visible).is_true()
	assert_str(hud.save_status_label.text).starts_with("Tym razem wyniku nie zapisaliśmy")
	assert_bool(FileAccess.file_exists(TEST_HISTORY)).is_false()
