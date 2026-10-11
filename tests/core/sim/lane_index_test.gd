extends GdUnitTestSuite
## Per-lane sorted vehicle lists behind `LaneQuery` neighbour lookups (issue #12,
## follow-up of the #20 review: lookups no longer scan every vehicle).

const DT: float = 1.0 / 60.0
const KMH: float = 1.0 / TrafficSim.KMH_PER_MPS
const LEFT: VehicleState.Dir = VehicleState.Dir.LEFT
const RIGHT: VehicleState.Dir = VehicleState.Dir.RIGHT


func _new_sim(seed_value: int = 0) -> TrafficSim:
	return TrafficSim.new(
			load("res://config/road_profiles/motorway.tres") as RoadProfile,
			load("res://config/sim_config.tres") as SimConfig,
			seed_value)


func _ids(vehicles: Array[VehicleState]) -> Array[int]:
	var ids: Array[int] = []
	for vehicle: VehicleState in vehicles:
		ids.append(vehicle.id)
	return ids


## Every lane list holds exactly the vehicles occupying that lane, sorted by `s`.
func _assert_index_consistent(sim: TrafficSim) -> void:
	for lane: int in range(sim.lanes.first_lane(), sim.lanes.end_lane()):
		var listed: Array[VehicleState] = sim.lanes.on_lane(lane)
		var expected: Array[int] = []
		for vehicle: VehicleState in sim.vehicles:
			if LaneQuery.occupies_lane(vehicle, lane):
				expected.append(vehicle.id)
		assert_array(_ids(listed)).override_failure_message("lane %d membership" % lane).contains_exactly_in_any_order(expected)
		for i: int in range(1, listed.size()):
			assert_float(listed[i].s).override_failure_message("lane %d order" % lane).is_greater_equal(listed[i - 1].s)


func test_bounds_find_positions_in_a_sorted_list() -> void:
	var sim: TrafficSim = _new_sim()
	for s: float in [10.0, 20.0, 20.0, 30.0]:
		sim.add_vehicle(s, 0, 0.0)
	var listed: Array[VehicleState] = sim.lanes.on_lane(0)
	assert_int(LaneIndex.lower_bound(listed, 20.0)).is_equal(1)
	assert_int(LaneIndex.upper_bound(listed, 20.0)).is_equal(3)
	assert_int(LaneIndex.lower_bound(listed, 5.0)).is_equal(0)
	assert_int(LaneIndex.upper_bound(listed, 30.0)).is_equal(4)


func test_vehicles_are_listed_by_lane_in_order_of_s() -> void:
	var sim: TrafficSim = _new_sim()
	var far: VehicleState = sim.add_vehicle(300.0, 0, 0.0)
	var near: VehicleState = sim.add_vehicle(100.0, 0, 0.0)
	var left: VehicleState = sim.add_vehicle(200.0, 1, 0.0)
	assert_array(_ids(sim.lanes.on_lane(0))).contains_exactly([near.id, far.id])
	assert_array(_ids(sim.lanes.on_lane(1))).contains_exactly([left.id])
	assert_array(sim.lanes.on_lane(7)).is_empty()


func test_a_lane_change_lists_the_vehicle_on_both_lanes_until_it_completes() -> void:
	var sim: TrafficSim = _new_sim()
	var car: VehicleState = sim.add_vehicle(0.0, 0, 30.0)
	sim.request_lane_change(car, LEFT)
	assert_array(_ids(sim.lanes.on_lane(1))).contains_exactly([car.id])
	assert_array(_ids(sim.lanes.on_lane(0))).contains_exactly([car.id])
	for i: int in roundi(sim.config.lane_change_duration_s / DT):
		sim.step(DT)
	assert_array(sim.lanes.on_lane(0)).is_empty()
	assert_array(_ids(sim.lanes.on_lane(1))).contains_exactly([car.id])


func test_an_off_road_change_is_listed_beyond_the_edge() -> void:
	var sim: TrafficSim = _new_sim()
	var car: VehicleState = sim.add_vehicle(0.0, 0, 30.0)
	sim.request_lane_change(car, RIGHT)
	for i: int in roundi(sim.config.lane_change_duration_s / DT):
		sim.step(DT)
	assert_bool(car.off_road).is_true()
	assert_array(_ids(sim.lanes.on_lane(-1))).contains_exactly([car.id])


func test_overtaking_reorders_the_lane() -> void:
	var sim: TrafficSim = _new_sim()
	var slow: VehicleState = sim.add_vehicle(20.0, 0, 10.0)
	var fast: VehicleState = sim.add_vehicle(0.0, 0, 30.0)
	sim.request_lane_change(fast, LEFT)
	for i: int in 120:
		sim.step(DT)
	assert_array(_ids(sim.lanes.on_lane(1))).contains_exactly([fast.id])
	assert_float(fast.s).is_greater(slow.s)
	_assert_index_consistent(sim)


## Seeded AI traffic with lane changes: the index matches the vehicles' lanes at
## every step, and each neighbour query answers as a scan over all vehicles would.
func test_queries_match_a_full_scan_in_busy_traffic() -> void:
	var sim: TrafficSim = _new_sim(5)
	for i: int in 40:
		var desired_kmh: float = sim.rng.randf_range(80.0, 150.0)
		sim.add_ai_vehicle(i * 35.0, i % 2, desired_kmh * KMH, desired_kmh * KMH, sim.rng.randf_range(0.3, 1.0))
	var lane_changes: Array[int] = [0]
	sim.lane_change_started.connect(func(_id: int, _from: int, _to: int) -> void: lane_changes[0] += 1)
	for i: int in 1800:
		sim.step(DT)
		if i % 60 != 0:
			continue
		_assert_index_consistent(sim)
		for vehicle: VehicleState in sim.vehicles:
			for lane: int in [0, 1]:
				assert_object(LaneQuery.leader_in_lane(sim.lanes, lane, vehicle.s, vehicle)) \
						.is_same(_scan_leader(sim.vehicles, lane, vehicle.s, vehicle))
				assert_object(LaneQuery.follower_in_lane(sim.lanes, lane, vehicle.s, vehicle)) \
						.is_same(_scan_follower(sim.vehicles, lane, vehicle.s, vehicle))
				assert_bool(LaneQuery.is_lane_free(sim.lanes, lane, vehicle.s, 40.0, 25.0, vehicle)) \
						.is_equal(_scan_free(sim.vehicles, lane, vehicle.s, 40.0, 25.0, vehicle))
			assert_bool(LaneQuery.is_overtaking(vehicle, sim.lanes, 50.0)) \
					.is_equal(_scan_overtaking(vehicle, sim.vehicles, 50.0))
	assert_int(lane_changes[0]).is_greater(0)


func test_mixed_body_lengths_find_the_nearest_rear_and_front() -> void:
	var sim: TrafficSim = _new_sim()
	var car_ahead: VehicleState = sim.add_vehicle(30.0, 0, 0.0)
	var long_body: VehicleState = sim.add_vehicle(10.0, 0, 0.0)
	long_body.length_m = 18.0
	sim.lanes.remove(long_body)
	sim.lanes.add(long_body)
	assert_object(LaneQuery.leader_in_lane(sim.lanes, 0, 0.0)).is_same(long_body)
	assert_object(LaneQuery.follower_in_lane(sim.lanes, 0, 40.0)).is_same(car_ahead)
	assert_bool(LaneQuery.is_lane_free(sim.lanes, 0, -5.0, 6.0, 0.0)).is_false()


# Reference definitions: plain scans over every vehicle, as LaneQuery worked before
# the index.

func _scan_leader(vehicles: Array[VehicleState], lane: int, s: float, ignore: VehicleState) -> VehicleState:
	var leader: VehicleState = null
	for other: VehicleState in vehicles:
		if other == ignore or other.s <= s or not LaneQuery.occupies_lane(other, lane):
			continue
		if leader == null or other.rear_s() < leader.rear_s():
			leader = other
	return leader


func _scan_follower(vehicles: Array[VehicleState], lane: int, s: float, ignore: VehicleState) -> VehicleState:
	var follower: VehicleState = null
	for other: VehicleState in vehicles:
		if other == ignore or other.s >= s or not LaneQuery.occupies_lane(other, lane):
			continue
		if follower == null or other.front_s() > follower.front_s():
			follower = other
	return follower


func _scan_free(vehicles: Array[VehicleState], lane: int, s: float, ahead: float, behind: float, ignore: VehicleState) -> bool:
	for other: VehicleState in vehicles:
		if other == ignore or not LaneQuery.occupies_lane(other, lane):
			continue
		if other.rear_s() <= s + ahead and other.front_s() >= s - behind:
			return false
	return true


func _scan_overtaking(vehicle: VehicleState, vehicles: Array[VehicleState], look_ahead_m: float) -> bool:
	if vehicle.lane_change_dir() == LEFT:
		return true
	if vehicle.lane <= 0:
		return false
	for other: VehicleState in vehicles:
		if other == vehicle or not LaneQuery.occupies_lane(other, vehicle.lane - 1):
			continue
		if other.speed_mps >= vehicle.speed_mps:
			continue
		if other.front_s() >= vehicle.rear_s() and other.rear_s() <= vehicle.front_s() + look_ahead_m:
			return true
	return false
