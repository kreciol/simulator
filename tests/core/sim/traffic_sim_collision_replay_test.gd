extends GdUnitTestSuite
## Collisions, seeded RNG and input replay (issue #5, spec Phase 2 step 4).

const DT: float = 1.0 / 60.0
const LEFT: VehicleState.Dir = VehicleState.Dir.LEFT
const ACCELERATE: VehicleState.Longitudinal = VehicleState.Longitudinal.ACCELERATE
const BRAKE: VehicleState.Longitudinal = VehicleState.Longitudinal.BRAKE
const NO_INPUT: VehicleState.Longitudinal = VehicleState.Longitudinal.NONE
## Words that tie a script to scenes, nodes or rendering.
const PURITY_PATTERN: String = "\\b(Node\\w*|SceneTree|get_tree|PackedScene|RenderingServer|Viewport|SubViewport|Camera\\w*|Mesh\\w*|CanvasItem|Control|Sprite\\w*)\\b|\\.tscn|\\.scn"

var _sim: TrafficSim
var _collisions: Array[Vector2i] = []


func before_test() -> void:
	_sim = _new_sim(0)
	_collisions.clear()
	_sim.collision.connect(func(vehicle_id: int, other_id: int) -> void:
		_collisions.append(Vector2i(vehicle_id, other_id)))


func _new_sim(seed_value: int) -> TrafficSim:
	return TrafficSim.new(
			load("res://config/road_profiles/motorway.tres") as RoadProfile,
			load("res://config/sim_config.tres") as SimConfig,
			seed_value)


func _steps(count: int) -> void:
	for i: int in count:
		_sim.step(DT)


func _change_steps() -> int:
	return roundi(_sim.config.lane_change_duration_s / DT)


func test_rear_end_on_the_same_lane_is_reported_once() -> void:
	var follower: VehicleState = _sim.add_vehicle(0.0, 0, 30.0)
	var stopped: VehicleState = _sim.add_vehicle(20.0, 0, 0.0)
	_steps(40)
	assert_array(_collisions).contains_exactly([Vector2i(follower.id, stopped.id)])
	assert_bool(_sim.vehicles_overlap(follower, stopped)).is_true()


func test_vehicles_alongside_on_adjacent_lanes_do_not_collide() -> void:
	_sim.add_vehicle(0.0, 0, 30.0)
	_sim.add_vehicle(0.0, 1, 30.0)
	_steps(120)
	assert_array(_collisions).is_empty()


func test_lane_change_into_a_vehicle_alongside_collides_mid_change() -> void:
	var changer: VehicleState = _sim.add_vehicle(0.0, 0, 30.0)
	var alongside: VehicleState = _sim.add_vehicle(0.0, 1, 30.0)
	_sim.request_lane_change(changer, LEFT)
	var collided_mid_change: bool = false
	for i: int in _change_steps():
		_sim.step(DT)
		if not _collisions.is_empty():
			collided_mid_change = changer.lane_change_active
			break
	assert_array(_collisions).contains_exactly([Vector2i(changer.id, alongside.id)])
	assert_bool(collided_mid_change).is_true()
	assert_float(changer.lane_change_progress).is_less(1.0)


func test_lane_change_behind_a_vehicle_with_clearance_does_not_collide() -> void:
	var changer: VehicleState = _sim.add_vehicle(0.0, 0, 30.0)
	_sim.add_vehicle(10.0, 1, 30.0)
	_sim.request_lane_change(changer, LEFT)
	_steps(_change_steps() + 30)
	assert_int(changer.lane).is_equal(1)
	assert_array(_collisions).is_empty()


func test_overlap_is_strict_in_both_axes(
		case_name: String,
		ds: float,
		other_lane: int,
		expected: bool,
		test_parameters: Array = [
			["same spot", 0.0, 0, true],
			["just inside the length", 4.49, 0, true],
			["bumpers touching", 4.5, 0, false],
			["clear gap", 10.0, 0, false],
			["adjacent lane alongside", 0.0, 1, false],
		]) -> void:
	assert_float(_sim.config.vehicle_length_m).is_equal(4.5)
	var a: VehicleState = _sim.add_vehicle(100.0, 0, 30.0)
	var b: VehicleState = _sim.add_vehicle(100.0 + ds, other_lane, 30.0)
	assert_bool(_sim.vehicles_overlap(a, b)).override_failure_message(case_name).is_equal(expected)


func test_new_contact_after_separation_is_reported_again() -> void:
	var a: VehicleState = _sim.add_vehicle(0.0, 0, 0.0)
	var b: VehicleState = _sim.add_vehicle(0.0, 0, 0.0)
	_steps(3)
	assert_int(_collisions.size()).is_equal(1)
	b.s = 50.0
	_steps(1)
	b.s = 0.0
	_steps(1)
	assert_array(_collisions).contains_exactly([Vector2i(a.id, b.id), Vector2i(a.id, b.id)])


func test_sim_owns_a_seeded_rng() -> void:
	var first: TrafficSim = _new_sim(42)
	var second: TrafficSim = _new_sim(42)
	var other: TrafficSim = _new_sim(7)
	assert_int(first.rng_seed).is_equal(42)
	var first_draws: Array[int] = []
	var second_draws: Array[int] = []
	var other_draws: Array[int] = []
	for i: int in 5:
		first_draws.append(first.rng.randi())
		second_draws.append(second.rng.randi())
		other_draws.append(other.rng.randi())
	assert_array(second_draws).is_equal(first_draws)
	assert_array(other_draws).is_not_equal(first_draws)


func test_input_log_records_a_copy_per_step_including_empty_steps() -> void:
	var player: VehicleState = _sim.add_vehicle(0.0, 0, 30.0)
	_sim.player = player
	var commands: PlayerCommands = PlayerCommands.create(ACCELERATE, LEFT, LEFT)
	_sim.step(DT, commands)
	commands.longitudinal = BRAKE
	_sim.step(DT)
	assert_int(_sim.input_log.size()).is_equal(2)
	assert_int(_sim.input_log.at(0).longitudinal).is_equal(ACCELERATE)
	assert_int(_sim.input_log.at(0).lane_change).is_equal(LEFT)
	assert_int(_sim.input_log.at(0).signal_toggle).is_equal(LEFT)
	assert_object(_sim.input_log.at(1)).is_null()
	assert_bool(player.lane_change_active).is_true()


func test_input_log_round_trips_every_command_combination() -> void:
	var input_log: InputLog = InputLog.new()
	var expected: Array[Array] = []
	for longitudinal: int in [NO_INPUT, ACCELERATE, BRAKE]:
		for lane_change: int in [VehicleState.Dir.RIGHT, VehicleState.Dir.NONE, VehicleState.Dir.LEFT]:
			for signal_toggle: int in [VehicleState.Dir.RIGHT, VehicleState.Dir.NONE, VehicleState.Dir.LEFT]:
				input_log.append(PlayerCommands.create(
						longitudinal as VehicleState.Longitudinal,
						lane_change as VehicleState.Dir,
						signal_toggle as VehicleState.Dir))
				expected.append([longitudinal, lane_change, signal_toggle])
	assert_int(input_log.size()).is_equal(27)
	for i: int in expected.size():
		var commands: PlayerCommands = input_log.at(i)
		assert_array([commands.longitudinal, commands.lane_change, commands.signal_toggle]).is_equal(expected[i])


func test_without_a_player_nothing_is_logged() -> void:
	_sim.add_vehicle(0.0, 0, 30.0)
	_steps(10)
	assert_int(_sim.input_log.size()).is_equal(0)


func test_same_seed_and_input_log_reproduce_the_final_state() -> void:
	var recorded: TrafficSim = _new_sim(1234)
	_populate(recorded)
	var script_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	script_rng.seed = 99
	for i: int in 600:
		_drive_ai(recorded)
		recorded.step(DT, _random_commands(script_rng))

	var replayed: TrafficSim = _new_sim(1234)
	_populate(replayed)
	for i: int in recorded.input_log.size():
		_drive_ai(replayed)
		replayed.step(DT, recorded.input_log.at(i))

	assert_int(replayed.input_log.size()).is_equal(600)
	assert_dict(replayed.snapshot()).is_equal(recorded.snapshot())

	var other_seed: TrafficSim = _new_sim(4321)
	_populate(other_seed)
	for i: int in recorded.input_log.size():
		_drive_ai(other_seed)
		other_seed.step(DT, recorded.input_log.at(i))
	assert_dict(other_seed.snapshot()).is_not_equal(recorded.snapshot())


func test_replay_without_extra_drivers_matches() -> void:
	var recorded: TrafficSim = _new_sim(5)
	_populate(recorded)
	var script_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	script_rng.seed = 3
	for i: int in 300:
		recorded.step(DT, _random_commands(script_rng))
	var replayed: TrafficSim = _new_sim(5)
	_populate(replayed)
	replayed.replay(recorded.input_log, DT)
	assert_dict(replayed.snapshot()).is_equal(recorded.snapshot())


func test_core_has_no_scene_node_or_rendering_references() -> void:
	var regex: RegEx = RegEx.create_from_string(PURITY_PATTERN)
	var offenders: Array[String] = []
	for script_path: String in _scripts_under("res://core"):
		var source: String = FileAccess.get_file_as_string(script_path)
		for found: RegExMatch in regex.search_all(source):
			offenders.append("%s: %s" % [script_path, found.get_string()])
	assert_array(_scripts_under("res://core")).is_not_empty()
	assert_array(offenders).is_empty()
	assert_array(_files_with_extension("res://core", [".tscn", ".scn"])).is_empty()


func _populate(sim: TrafficSim) -> void:
	sim.player = sim.add_vehicle(0.0, 0, 25.0)
	sim.add_vehicle(80.0, 0, 22.0)
	sim.add_vehicle(-40.0, 1, 33.0)


## Stand-in for future AI: decisions drawn from the sim's own RNG.
func _drive_ai(sim: TrafficSim) -> void:
	for vehicle: VehicleState in sim.vehicles:
		if vehicle == sim.player:
			continue
		vehicle.longitudinal = sim.rng.randi_range(NO_INPUT, BRAKE) as VehicleState.Longitudinal


func _random_commands(script_rng: RandomNumberGenerator) -> PlayerCommands:
	if script_rng.randf() < 0.3:
		return null
	var longitudinal: VehicleState.Longitudinal = script_rng.randi_range(NO_INPUT, BRAKE) as VehicleState.Longitudinal
	var lane_change: VehicleState.Dir = VehicleState.Dir.NONE
	var signal_toggle: VehicleState.Dir = VehicleState.Dir.NONE
	if script_rng.randf() < 0.02:
		lane_change = (VehicleState.Dir.LEFT if script_rng.randf() < 0.5 else VehicleState.Dir.RIGHT)
	if script_rng.randf() < 0.02:
		signal_toggle = (VehicleState.Dir.LEFT if script_rng.randf() < 0.5 else VehicleState.Dir.RIGHT)
	return PlayerCommands.create(longitudinal, lane_change, signal_toggle)


func _scripts_under(dir_path: String) -> Array[String]:
	return _files_with_extension(dir_path, [".gd"])


func _files_with_extension(dir_path: String, extensions: Array[String]) -> Array[String]:
	var found: Array[String] = []
	for file_name: String in DirAccess.get_files_at(dir_path):
		for extension: String in extensions:
			if file_name.ends_with(extension):
				found.append(dir_path.path_join(file_name))
	for sub_dir: String in DirAccess.get_directories_at(dir_path):
		found.append_array(_files_with_extension(dir_path.path_join(sub_dir), extensions))
	return found
