extends GdUnitTestSuite
## IDM car-following with a legal-gap-aware headway (issue #11, spec Phase 4 step 1).

const DT: float = 1.0 / 60.0
const KMH: float = 1.0 / TrafficSim.KMH_PER_MPS

var _config: SimConfig
var _collisions: Array[Vector2i] = []


func before_test() -> void:
	_config = load("res://config/sim_config.tres") as SimConfig
	_collisions.clear()


## A one-lane road isolates following from overtaking.
func _new_sim(lane_count: int = 1) -> TrafficSim:
	var road: RoadProfile = (load("res://config/road_profiles/motorway.tres") as RoadProfile).duplicate() as RoadProfile
	road.lane_count = lane_count
	var sim: TrafficSim = TrafficSim.new(road, _config)
	sim.collision.connect(func(vehicle_id: int, other_id: int) -> void:
		_collisions.append(Vector2i(vehicle_id, other_id)))
	return sim


func _run(sim: TrafficSim, seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		sim.step(DT)


## Settled following gap of an AI car with `discipline` behind a scripted leader
## holding 80 km/h; also checks the convoy settled and never touched.
func _settled_gap(discipline: float) -> float:
	var sim: TrafficSim = _new_sim()
	var leader: VehicleState = sim.add_vehicle(150.0, 0, 80.0 * KMH)
	var follower: VehicleState = sim.add_ai_vehicle(0.0, 0, 130.0 * KMH, 130.0 * KMH, discipline)
	_run(sim, 150.0)
	assert_float(follower.speed_mps).is_equal_approx(leader.speed_mps, 0.5 * KMH)
	assert_array(_collisions).is_empty()
	return LaneQuery.gap_to_leader(follower, sim.vehicles)


func test_time_headway_reaches_the_legal_gap_for_model_drivers(
		discipline: float,
		expected_s: float,
		test_parameters: Array = [[1.0, 1.8], [0.0, 1.5], [0.5, 1.65], [2.0, 1.8], [-1.0, 1.5]]) -> void:
	assert_float(_config.idm_time_headway_s).is_equal(1.5)
	assert_float(Idm.time_headway(discipline, _config)).is_equal_approx(expected_s, 1e-9)


func test_idm_is_neutral_at_desired_speed_on_a_free_road() -> void:
	assert_float(Idm.acceleration(30.0, 30.0, INF, 0.0, 1.8, _config)).is_equal_approx(0.0, 1e-9)
	assert_float(Idm.acceleration(0.0, 30.0, INF, 0.0, 1.8, _config)).is_equal_approx(_config.idm_max_accel_mps2, 1e-9)


func test_idm_braking_is_capped() -> void:
	assert_float(Idm.acceleration(30.0, 30.0, 1.0, 0.0, 1.8, _config)).is_equal(-_config.ai_max_decel_mps2)
	assert_float(Idm.acceleration(30.0, 30.0, 0.0, 0.0, 1.8, _config)).is_equal(-_config.ai_max_decel_mps2)


func test_free_road_accelerates_to_desired_speed() -> void:
	var sim: TrafficSim = _new_sim()
	var car: VehicleState = sim.add_ai_vehicle(0.0, 0, 60.0 * KMH, 110.0 * KMH, 1.0)
	var previous_speed: float = car.speed_mps
	for i: int in roundi(90.0 / DT):
		sim.step(DT)
		assert_float(car.speed_mps).is_greater_equal(previous_speed)
		previous_speed = car.speed_mps
	assert_float(car.speed_mps).is_equal_approx(110.0 * KMH, 1.0 * KMH)
	assert_float(car.speed_mps).is_less_equal(110.0 * KMH)


func test_disciplined_driver_settles_at_or_beyond_the_legal_gap() -> void:
	var gap: float = _settled_gap(1.0)
	assert_float(gap).is_greater_equal(LaneQuery.min_gap(80.0))


func test_disciplined_driver_never_dips_below_the_legal_gap_once_following() -> void:
	var sim: TrafficSim = _new_sim()
	sim.add_vehicle(150.0, 0, 80.0 * KMH)
	var follower: VehicleState = sim.add_ai_vehicle(0.0, 0, 130.0 * KMH, 130.0 * KMH, 1.0)
	_run(sim, 60.0)
	for i: int in roundi(60.0 / DT):
		sim.step(DT)
		var min_gap: float = LaneQuery.min_gap(follower.speed_mps * TrafficSim.KMH_PER_MPS)
		assert_float(LaneQuery.gap_to_leader(follower, sim.vehicles)).is_greater_equal(min_gap)


func test_lower_discipline_follows_closer() -> void:
	var model_gap: float = _settled_gap(1.0)
	var sloppy_gap: float = _settled_gap(0.0)
	assert_float(sloppy_gap).is_less(model_gap)
	assert_float(sloppy_gap).is_greater(_config.idm_min_spacing_m)


func test_stops_behind_a_stopped_leader_without_overlap() -> void:
	var sim: TrafficSim = _new_sim()
	var stopped: VehicleState = sim.add_vehicle(250.0, 0, 0.0)
	var car: VehicleState = sim.add_ai_vehicle(0.0, 0, 110.0 * KMH, 110.0 * KMH, 1.0)
	for i: int in roundi(60.0 / DT):
		sim.step(DT)
		assert_bool(sim.vehicles_overlap(car, stopped)).is_false()
	assert_float(car.speed_mps).is_equal_approx(0.0, 0.1)
	var gap: float = LaneQuery.gap_to_leader(car, sim.vehicles)
	assert_float(gap).is_between(0.0, 2.0 * _config.idm_min_spacing_m)
	assert_array(_collisions).is_empty()


func test_scripted_vehicles_keep_following_their_commands() -> void:
	var sim: TrafficSim = _new_sim()
	var scripted: VehicleState = sim.add_vehicle(0.0, 0, 20.0)
	sim.add_ai_vehicle(-200.0, 0, 20.0, 30.0, 1.0)
	_run(sim, 1.0)
	assert_object(scripted.ai).is_null()
	assert_float(scripted.speed_mps).is_equal(20.0)
