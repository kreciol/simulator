extends GdUnitTestSuite
## The main scene drives the sim from the keyboard and renders it from the cockpit
## (issue #7 acceptance criteria, spec Phase 3 steps 1–2).

const DT: float = 1.0 / 60.0

var _runner: GdUnitSceneRunner
var _main: Node3D


func before_test() -> void:
	_runner = scene_runner("res://game/main.tscn")
	_main = _runner.scene() as Node3D


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
	_drive(1)
	var before: Dictionary = _main.sim.snapshot()
	_runner.simulate_key_press(KEY_X)
	_runner.simulate_key_release(KEY_X)
	_runner.simulate_key_press(KEY_SPACE)
	await _runner.await_input_processed()
	_drive(1)
	var after: Dictionary = _main.sim.snapshot()
	var vehicle_before: Dictionary = (before["vehicles"] as Array)[0]
	var vehicle_after: Dictionary = (after["vehicles"] as Array)[0]
	assert_dict(vehicle_after).is_equal(vehicle_before)
	_runner.simulate_key_release(KEY_SPACE)
	await _runner.await_input_processed()
