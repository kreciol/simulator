extends GdUnitTestSuite
## Shared lane logic (issue #5, spec Phase 2 step 3, requirements §8.4).

const LEFT: VehicleState.Dir = VehicleState.Dir.LEFT
const RIGHT: VehicleState.Dir = VehicleState.Dir.RIGHT
const NO_DIR: VehicleState.Dir = VehicleState.Dir.NONE
## Round numbers keep the expected gaps readable: bodies span s ± 2 m.
const LENGTH: float = 4.0
const AHEAD: float = 50.0
const BEHIND: float = 30.0
const LANE_COUNT: int = 2


func _vehicle(s: float, lane: int, speed_mps: float = 30.0, change_to: int = -99) -> VehicleState:
	var vehicle: VehicleState = VehicleState.new()
	vehicle.s = s
	vehicle.lane = lane
	vehicle.speed_mps = speed_mps
	vehicle.length_m = LENGTH
	vehicle.width_m = 1.8
	if change_to != -99:
		vehicle.lane_change_active = true
		vehicle.lane_change_from = lane
		vehicle.lane_change_to = change_to
		vehicle.lane_change_progress = 0.5
	return vehicle


func _lanes(vehicles: Array[VehicleState]) -> LaneIndex:
	return LaneIndex.from_vehicles(vehicles, LANE_COUNT)


func _vehicles(entries: Array) -> Array[VehicleState]:
	var result: Array[VehicleState] = []
	for entry: Array in entries:
		result.append(_vehicle(entry[0], entry[1], 30.0, entry[2] if entry.size() > 2 else -99))
	return result


func test_min_gap_is_half_the_speed(
		speed_kmh: float,
		expected_m: float,
		test_parameters: Array = [[140.0, 70.0], [120.0, 60.0], [90.0, 45.0], [0.0, 0.0]]) -> void:
	assert_float(LaneQuery.min_gap(speed_kmh)).is_equal_approx(expected_m, 1e-9)


## Querying lane 1 around s = 100 with a 50 m look-ahead and 30 m look-behind.
## Entries are [s, lane] or [s, lane, lane_change_to].
func test_is_lane_free(
		case_name: String,
		entries: Array,
		expected: bool,
		test_parameters: Array = [
			["empty road", [], true],
			["leader inside look-ahead", [[140.0, 1]], false],
			["leader rear exactly at the window edge", [[152.0, 1]], false],
			["leader beyond look-ahead", [[160.0, 1]], true],
			["follower inside look-behind", [[75.0, 1]], false],
			["follower beyond look-behind", [[60.0, 1]], true],
			["vehicle alongside", [[100.0, 1]], false],
			["vehicle on another lane", [[100.0, 0]], true],
			["vehicle changing into the lane", [[100.0, 0, 1]], false],
			["vehicle changing out of the lane", [[100.0, 1, 0]], false],
		]) -> void:
	var vehicles: Array[VehicleState] = _vehicles(entries)
	assert_bool(LaneQuery.is_lane_free(_lanes(vehicles), 1, 100.0, AHEAD, BEHIND)).override_failure_message(case_name).is_equal(expected)


func test_is_lane_free_ignores_the_querying_vehicle() -> void:
	var me: VehicleState = _vehicle(100.0, 1)
	var vehicles: Array[VehicleState] = [me]
	assert_bool(LaneQuery.is_lane_free(_lanes(vehicles), 1, 100.0, AHEAD, BEHIND, me)).is_true()
	assert_bool(LaneQuery.is_lane_free(_lanes(vehicles), 1, 100.0, AHEAD, BEHIND)).is_false()


## The ego vehicle is at s = 0 on lane 0; gaps are bumper to bumper.
func test_gap_to_leader(
		case_name: String,
		entries: Array,
		expected: float,
		test_parameters: Array = [
			["empty road", [], INF],
			["leader on the same lane", [[50.0, 0]], 46.0],
			["nearest of two leaders", [[80.0, 0], [30.0, 0]], 26.0],
			["leader on another lane", [[50.0, 1]], INF],
			["vehicle behind", [[-20.0, 0]], INF],
			["leader changing into the lane", [[30.0, 1, 0]], 26.0],
		]) -> void:
	var me: VehicleState = _vehicle(0.0, 0)
	var vehicles: Array[VehicleState] = _vehicles(entries)
	vehicles.append(me)
	assert_float(LaneQuery.gap_to_leader(me, _lanes(vehicles))).override_failure_message(case_name).is_equal(expected)


## Neighbours of s = 0 on lane 1, as indices into `entries`; -1 means none.
func test_leader_and_follower_in_lane(
		case_name: String,
		entries: Array,
		expected_leader: int,
		expected_follower: int,
		test_parameters: Array = [
			["empty road", [], -1, -1],
			["one ahead, one behind", [[40.0, 1], [-25.0, 1]], 0, 1],
			["nearest of each", [[90.0, 1], [40.0, 1], [-60.0, 1], [-25.0, 1]], 1, 3],
			["other lane ignored", [[40.0, 0], [-25.0, 0]], -1, -1],
			["changing into the lane counts", [[30.0, 0, 1], [-20.0, 2, 1]], 0, 1],
			["alongside is neither", [[0.0, 1]], -1, -1],
		]) -> void:
	var vehicles: Array[VehicleState] = _vehicles(entries)
	var lanes: LaneIndex = _lanes(vehicles)
	var leader: VehicleState = LaneQuery.leader_in_lane(lanes, 1, 0.0)
	var follower: VehicleState = LaneQuery.follower_in_lane(lanes, 1, 0.0)
	assert_int(vehicles.find(leader)).override_failure_message(case_name + ": leader").is_equal(expected_leader)
	assert_int(vehicles.find(follower)).override_failure_message(case_name + ": follower").is_equal(expected_follower)


func test_neighbour_queries_skip_the_ignored_vehicle() -> void:
	var me: VehicleState = _vehicle(10.0, 1)
	var vehicles: Array[VehicleState] = [me]
	var lanes: LaneIndex = _lanes(vehicles)
	assert_object(LaneQuery.leader_in_lane(lanes, 1, 0.0, me)).is_null()
	assert_object(LaneQuery.follower_in_lane(lanes, 1, 20.0, me)).is_null()
	assert_object(LaneQuery.leader_in_lane(lanes, 1, 0.0)).is_same(me)


## The ego vehicle is at s = 0 on `my_lane`; the zone reaches 1 m ahead of and 8 m
## behind its centre. Entries are [s, lane] or [s, lane, lane_change_to].
func test_blind_spot_occupied(
		case_name: String,
		my_lane: int,
		dir: VehicleState.Dir,
		entries: Array,
		expected: bool,
		test_parameters: Array = [
			["empty road", 0, LEFT, [], false],
			["left: just behind", 0, LEFT, [[-5.0, 1]], true],
			["left: alongside", 0, LEFT, [[0.0, 1]], true],
			["left: front reaches the zone's back edge", 0, LEFT, [[-10.0, 1]], true],
			["left: further back", 0, LEFT, [[-11.0, 1]], false],
			["left: rear reaches the zone's front edge", 0, LEFT, [[3.0, 1]], true],
			["left: ahead of the zone", 0, LEFT, [[4.0, 1]], false],
			["left: vehicle on the right lane", 1, LEFT, [[-5.0, 0]], false],
			["left: vehicle changing into the left lane", 0, LEFT, [[-5.0, 0, 1]], true],
			["right: just behind", 1, RIGHT, [[-5.0, 0]], true],
			["right: further back", 1, RIGHT, [[-11.0, 0]], false],
			["right: ahead of the zone", 1, RIGHT, [[4.0, 0]], false],
			["right: vehicle on the left lane", 0, RIGHT, [[-5.0, 1]], false],
			["right: beyond the road edge", 0, RIGHT, [], false],
			["own lane is never a blind spot", 0, LEFT, [[-5.0, 0]], false],
			["no side", 0, NO_DIR, [[-5.0, 1]], false],
		]) -> void:
	var me: VehicleState = _vehicle(0.0, my_lane)
	var vehicles: Array[VehicleState] = _vehicles(entries)
	vehicles.append(me)
	assert_bool(LaneQuery.blind_spot_occupied(_lanes(vehicles), me, dir, 1.0, 8.0)) \
			.override_failure_message(case_name).is_equal(expected)


## The ego vehicle drives 30 m/s; `right` is the vehicle on the lane to its right.
func test_is_overtaking(
		case_name: String,
		my_lane: int,
		my_change_to: int,
		right_s: float,
		right_speed_mps: float,
		expected: bool,
		test_parameters: Array = [
			["slower vehicle ahead on the right", 1, -99, 20.0, 22.0, true],
			["slower vehicle alongside on the right", 1, -99, 0.0, 22.0, true],
			["slower vehicle beyond the window", 1, -99, 80.0, 22.0, false],
			["slower vehicle already passed", 1, -99, -10.0, 22.0, false],
			["faster vehicle on the right", 1, -99, 20.0, 35.0, false],
			["on the rightmost lane", 0, -99, 20.0, 22.0, false],
			["changing lanes to the left", 0, 1, 500.0, 22.0, true],
			["changing lanes to the right", 1, 0, 500.0, 22.0, false],
		]) -> void:
	var me: VehicleState = _vehicle(0.0, my_lane, 30.0, my_change_to)
	var right: VehicleState = _vehicle(right_s, maxi(my_lane - 1, 0), right_speed_mps)
	var vehicles: Array[VehicleState] = [me, right]
	assert_bool(LaneQuery.is_overtaking(me, _lanes(vehicles), AHEAD)).override_failure_message(case_name).is_equal(expected)


func test_signal_valid(
		change_dir: VehicleState.Dir,
		signal_dir: VehicleState.Dir,
		signal_on_s: float,
		expected: LaneQuery.SignalResult,
		test_parameters: Array = [
			[LEFT, NO_DIR, 0.0, LaneQuery.SignalResult.NONE],
			[LEFT, RIGHT, 2.0, LaneQuery.SignalResult.WRONG],
			[RIGHT, LEFT, 2.0, LaneQuery.SignalResult.WRONG],
			[LEFT, LEFT, 0.5, LaneQuery.SignalResult.LATE],
			[LEFT, LEFT, 1.0, LaneQuery.SignalResult.OK],
			[RIGHT, RIGHT, 3.0, LaneQuery.SignalResult.OK],
		]) -> void:
	var min_on_s: float = (load("res://config/sim_config.tres") as SimConfig).signal_min_on_s
	assert_float(min_on_s).is_equal(1.0)
	assert_int(LaneQuery.signal_valid(change_dir, signal_dir, signal_on_s, min_on_s)).is_equal(expected)


func test_signal_valid_with_signal_timed_by_the_sim() -> void:
	var config: SimConfig = load("res://config/sim_config.tres") as SimConfig
	var sim: TrafficSim = TrafficSim.new(load("res://config/road_profiles/motorway.tres") as RoadProfile, config)
	var car: VehicleState = sim.add_vehicle(0.0, 0, 30.0)
	sim.toggle_signal(car, LEFT)
	for i: int in 30:
		sim.step(1.0 / 60.0)
	var on_s: float = sim.time_s - car.signal_on_since_s
	assert_int(LaneQuery.signal_valid(LEFT, car.signal_dir, on_s, config.signal_min_on_s)).is_equal(LaneQuery.SignalResult.LATE)
	for i: int in 30:
		sim.step(1.0 / 60.0)
	# Exactly the minimum, reached by summing fixed steps.
	on_s = sim.time_s - car.signal_on_since_s
	assert_int(LaneQuery.signal_valid(LEFT, car.signal_dir, on_s, config.signal_min_on_s)).is_equal(LaneQuery.SignalResult.OK)


func test_spawned_vehicles_take_their_size_from_config() -> void:
	var config: SimConfig = load("res://config/sim_config.tres") as SimConfig
	var sim: TrafficSim = TrafficSim.new(load("res://config/road_profiles/motorway.tres") as RoadProfile, config)
	var car: VehicleState = sim.add_vehicle(10.0, 0, 30.0)
	assert_float(car.length_m).is_equal(config.vehicle_length_m)
	assert_float(car.width_m).is_equal(config.vehicle_width_m)
	assert_float(car.front_s() - car.rear_s()).is_equal_approx(config.vehicle_length_m, 1e-9)
