extends GdUnitTestSuite
## Input Map → PlayerCommands (issue #7, spec Phase 3 step 2; requirements §6.3).
## Events go through the project's real Input Map, so a rebinding breaks these tests.

const LEFT: VehicleState.Dir = VehicleState.Dir.LEFT
const RIGHT: VehicleState.Dir = VehicleState.Dir.RIGHT
const NO_DIR: VehicleState.Dir = VehicleState.Dir.NONE

var _input: PlayerInput


func before_test() -> void:
	_input = PlayerInput.new()


func _key(key: Key, pressed: bool, echo: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	event.echo = echo
	return event


func _press(key: Key) -> bool:
	return _input.handle_event(_key(key, true))


func _release(key: Key) -> bool:
	return _input.handle_event(_key(key, false))


func test_held_key_controls_speed_until_released(
		key: Key,
		expected: VehicleState.Longitudinal,
		test_parameters: Array = [
			[KEY_W, VehicleState.Longitudinal.ACCELERATE],
			[KEY_UP, VehicleState.Longitudinal.ACCELERATE],
			[KEY_S, VehicleState.Longitudinal.BRAKE],
			[KEY_DOWN, VehicleState.Longitudinal.BRAKE],
		]) -> void:
	assert_bool(_press(key)).is_true()
	assert_int(_input.consume().longitudinal).is_equal(expected)
	assert_int(_input.consume().longitudinal).is_equal(expected)
	assert_bool(_release(key)).is_true()
	assert_int(_input.consume().longitudinal).is_equal(VehicleState.Longitudinal.NONE)


func test_lane_change_fires_once_per_press(
		key: Key,
		expected: VehicleState.Dir,
		test_parameters: Array = [
			[KEY_A, VehicleState.Dir.LEFT],
			[KEY_LEFT, VehicleState.Dir.LEFT],
			[KEY_D, VehicleState.Dir.RIGHT],
			[KEY_RIGHT, VehicleState.Dir.RIGHT],
		]) -> void:
	assert_bool(_press(key)).is_true()
	var commands: PlayerCommands = _input.consume()
	assert_int(commands.lane_change).is_equal(expected)
	assert_int(commands.signal_toggle).is_equal(NO_DIR)
	# Still held, and key repeat while held, request nothing more.
	_input.handle_event(_key(key, true, true))
	assert_int(_input.consume().lane_change).is_equal(NO_DIR)
	assert_bool(_release(key)).is_true()
	assert_int(_input.consume().lane_change).is_equal(NO_DIR)


func test_signal_toggles_once_per_press(
		key: Key,
		expected: VehicleState.Dir,
		test_parameters: Array = [
			[KEY_Q, VehicleState.Dir.LEFT],
			[KEY_COMMA, VehicleState.Dir.LEFT],
			[KEY_E, VehicleState.Dir.RIGHT],
			[KEY_PERIOD, VehicleState.Dir.RIGHT],
		]) -> void:
	assert_bool(_press(key)).is_true()
	var commands: PlayerCommands = _input.consume()
	assert_int(commands.signal_toggle).is_equal(expected)
	assert_int(commands.lane_change).is_equal(NO_DIR)
	assert_int(_input.consume().signal_toggle).is_equal(NO_DIR)


func test_unmapped_key_does_nothing(
		key: Key,
		test_parameters: Array = [[KEY_X], [KEY_SPACE], [KEY_ENTER], [KEY_1], [KEY_F]]) -> void:
	assert_bool(_press(key)).is_false()
	assert_bool(_release(key)).is_false()
	var commands: PlayerCommands = _input.consume()
	assert_int(commands.longitudinal).is_equal(VehicleState.Longitudinal.NONE)
	assert_int(commands.lane_change).is_equal(NO_DIR)
	assert_int(commands.signal_toggle).is_equal(NO_DIR)


func test_unmapped_key_leaves_a_sim_vehicle_unchanged() -> void:
	var sim: TrafficSim = TrafficSim.new(
			load("res://config/road_profiles/motorway.tres") as RoadProfile,
			load("res://config/sim_config.tres") as SimConfig)
	sim.player = sim.add_vehicle(0.0, 0, 25.0)
	var reference: TrafficSim = TrafficSim.new(sim.road, sim.config)
	reference.player = reference.add_vehicle(0.0, 0, 25.0)
	_press(KEY_X)
	for i: int in 60:
		sim.step(1.0 / 60.0, _input.consume())
		reference.step(1.0 / 60.0, PlayerCommands.new())
	assert_dict(sim.snapshot()).is_equal(reference.snapshot())


func test_releasing_one_of_two_keys_keeps_the_action_held() -> void:
	_press(KEY_W)
	_press(KEY_UP)
	_release(KEY_W)
	assert_int(_input.consume().longitudinal).is_equal(VehicleState.Longitudinal.ACCELERATE)
	_release(KEY_UP)
	assert_int(_input.consume().longitudinal).is_equal(VehicleState.Longitudinal.NONE)


func test_brake_wins_over_accelerate() -> void:
	_press(KEY_W)
	_press(KEY_S)
	assert_int(_input.consume().longitudinal).is_equal(VehicleState.Longitudinal.BRAKE)


func test_lane_change_and_signal_in_one_step_are_both_kept() -> void:
	_press(KEY_Q)
	_press(KEY_A)
	var commands: PlayerCommands = _input.consume()
	assert_int(commands.signal_toggle).is_equal(LEFT)
	assert_int(commands.lane_change).is_equal(LEFT)


func test_later_press_in_the_same_step_wins() -> void:
	_press(KEY_A)
	_press(KEY_D)
	assert_int(_input.consume().lane_change).is_equal(RIGHT)


func test_reset_releases_everything() -> void:
	_press(KEY_W)
	_press(KEY_A)
	_press(KEY_E)
	_input.reset()
	var commands: PlayerCommands = _input.consume()
	assert_int(commands.longitudinal).is_equal(VehicleState.Longitudinal.NONE)
	assert_int(commands.lane_change).is_equal(NO_DIR)
	assert_int(commands.signal_toggle).is_equal(NO_DIR)
