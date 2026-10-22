extends GdUnitTestSuite
## AI shares lane logic with scoring and keeps a mixed convoy collision-free
## (issue #11, spec Phase 4 steps 1–2, requirements §7.2).

const DT: float = 1.0 / 60.0
const KMH: float = 1.0 / TrafficSim.KMH_PER_MPS
## Lane-logic functions owned by `LaneQuery`; nothing else in core/ may define them.
const LANE_FUNCTIONS: String = "min_gap|occupies_lane|is_lane_free|gap_to_leader|leader_in_lane|follower_in_lane|is_overtaking|signal_valid"
const LANE_QUERY_PATH: String = "res://core/sim/lane_query.gd"
const AI_DRIVER_PATH: String = "res://core/ai/ai_driver.gd"
const IDM_PATH: String = "res://core/ai/idm.gd"
const CARS: int = 12
const RUN_S: float = 120.0

## Held by the suite so signal lambdas need not capture the sim (a reference cycle).
var _sim: TrafficSim


func after_test() -> void:
	_sim = null


func test_ai_uses_lane_query_for_lane_logic() -> void:
	var driver: String = FileAccess.get_file_as_string(AI_DRIVER_PATH)
	for call: String in ["LaneQuery.is_lane_free(", "LaneQuery.leader_in_lane(", "LaneQuery.follower_in_lane("]:
		assert_str(driver).contains(call)
	assert_str(FileAccess.get_file_as_string(IDM_PATH)).contains("LaneQuery.min_gap(")


func test_lane_logic_is_defined_only_in_lane_query() -> void:
	var definition: RegEx = RegEx.create_from_string("func\\s+(%s)\\s*\\(" % LANE_FUNCTIONS)
	var offenders: Array[String] = []
	for script_path: String in _scripts_under("res://core"):
		if script_path == LANE_QUERY_PATH:
			continue
		for found: RegExMatch in definition.search_all(FileAccess.get_file_as_string(script_path)):
			offenders.append("%s: %s" % [script_path, found.get_string()])
	assert_array(offenders).is_empty()


func test_seeded_mixed_traffic_never_collides(
		profile_path: String,
		seed_value: int,
		test_parameters: Array = [
			["res://config/road_profiles/motorway.tres", 1],
			["res://config/road_profiles/expressway.tres", 2],
			["res://config/road_profiles/motorway_3lane.tres", 3],
		]) -> void:
	_sim = _populated_sim(profile_path, seed_value)
	var collisions: Array[Vector2i] = []
	var lane_changes: Dictionary[int, int] = {}
	var late_signals: Array[int] = []
	_sim.collision.connect(func(vehicle_id: int, other_id: int) -> void:
		collisions.append(Vector2i(vehicle_id, other_id)))
	_sim.lane_change_started.connect(func(vehicle_id: int, from_lane: int, to_lane: int) -> void:
		var vehicle: VehicleState = _sim.vehicles[vehicle_id]
		var dir: int = to_lane - from_lane
		lane_changes[dir] = lane_changes.get(dir, 0) + 1
		var on_s: float = _sim.time_s - vehicle.signal_on_since_s
		if LaneQuery.signal_valid(dir as VehicleState.Dir, vehicle.signal_dir, on_s, _sim.config.ai_signal_lead_s) != LaneQuery.SignalResult.OK:
			late_signals.append(vehicle_id))
	for i: int in roundi(RUN_S / DT):
		_sim.step(DT)
	assert_array(collisions).is_empty()
	assert_array(late_signals).is_empty()
	# The run exercises overtaking and returning, not just following.
	assert_int(lane_changes.get(VehicleState.Dir.LEFT, 0)).is_greater(0)
	assert_int(lane_changes.get(VehicleState.Dir.RIGHT, 0)).is_greater(0)
	for vehicle: VehicleState in _sim.vehicles:
		assert_bool(vehicle.off_road).is_false()


func test_ai_traffic_is_deterministic_per_seed() -> void:
	var first: TrafficSim = _populated_sim("res://config/road_profiles/motorway.tres", 9)
	var second: TrafficSim = _populated_sim("res://config/road_profiles/motorway.tres", 9)
	for i: int in roundi(30.0 / DT):
		first.step(DT)
		second.step(DT)
	assert_dict(second.snapshot()).is_equal(first.snapshot())


## Cars every 60 m on alternating lanes with desired speeds and discipline drawn from
## the sim's RNG; every fourth is a truck. Vehicle ids equal their index.
func _populated_sim(profile_path: String, seed_value: int) -> TrafficSim:
	var sim: TrafficSim = TrafficSim.new(
			load(profile_path) as RoadProfile,
			load("res://config/sim_config.tres") as SimConfig,
			seed_value)
	for i: int in CARS:
		var desired_kmh: float = sim.rng.randf_range(80.0, 90.0) if i % 4 == 0 else sim.rng.randf_range(100.0, 150.0)
		var discipline: float = sim.rng.randf_range(0.5, 1.0)
		sim.add_ai_vehicle(i * 60.0, i % sim.road.lane_count, desired_kmh * KMH, desired_kmh * KMH, discipline)
	return sim


func _scripts_under(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(".gd"):
			found.append(dir_path.path_join(file_name))
	for sub_dir: String in DirAccess.get_directories_at(dir_path):
		found.append_array(_scripts_under(dir_path.path_join(sub_dir)))
	return found
