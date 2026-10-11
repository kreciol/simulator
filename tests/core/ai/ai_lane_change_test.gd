extends GdUnitTestSuite
## MOBIL keep-right lane changes with signalling (issue #11, spec Phase 4 step 2).

const DT: float = 1.0 / 60.0
const KMH: float = 1.0 / TrafficSim.KMH_PER_MPS
const LEFT: VehicleState.Dir = VehicleState.Dir.LEFT
const RIGHT: VehicleState.Dir = VehicleState.Dir.RIGHT
const NO_DIR: VehicleState.Dir = VehicleState.Dir.NONE

var _sim: TrafficSim
var _collisions: Array[Vector2i] = []
## One entry per lane change start: {id, from, to, signal_dir, signal_on_s, time_s}.
var _changes: Array[Dictionary] = []


func before_test() -> void:
	_sim = TrafficSim.new(
			load("res://config/road_profiles/motorway.tres") as RoadProfile,
			load("res://config/sim_config.tres") as SimConfig)
	_collisions.clear()
	_changes.clear()
	_sim.collision.connect(func(vehicle_id: int, other_id: int) -> void:
		_collisions.append(Vector2i(vehicle_id, other_id)))
	_sim.lane_change_started.connect(func(vehicle_id: int, from_lane: int, to_lane: int) -> void:
		var vehicle: VehicleState = _vehicle(vehicle_id)
		_changes.append({
			"id": vehicle_id,
			"from": from_lane,
			"to": to_lane,
			"signal_dir": vehicle.signal_dir,
			"signal_on_s": _sim.time_s - vehicle.signal_on_since_s,
			"time_s": _sim.time_s,
		}))


func _vehicle(id: int) -> VehicleState:
	for vehicle: VehicleState in _sim.vehicles:
		if vehicle.id == id:
			return vehicle
	return null


func _run(seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		_sim.step(DT)


## Steps for `seconds`; whether `vehicle` had a signal on after any step.
func _signalled_within(vehicle: VehicleState, seconds: float) -> bool:
	var signalled: bool = false
	for i: int in roundi(seconds / DT):
		_sim.step(DT)
		signalled = signalled or vehicle.signal_dir != NO_DIR
	return signalled


func _changes_of(vehicle: VehicleState) -> Array[Dictionary]:
	return _changes.filter(func(change: Dictionary) -> bool: return change["id"] == vehicle.id)


func _assert_signalled(change: Dictionary, dir: VehicleState.Dir) -> void:
	assert_int(change["signal_dir"]).is_equal(dir)
	assert_float(change["signal_on_s"]).is_greater_equal(_sim.config.ai_signal_lead_s - LaneQuery.TIME_EPSILON)
	assert_float(_sim.config.ai_signal_lead_s).is_greater_equal(1.5)
	assert_int(LaneQuery.signal_valid(dir, change["signal_dir"], change["signal_on_s"], _sim.config.signal_min_on_s)) \
			.is_equal(LaneQuery.SignalResult.OK)


func test_fast_car_overtakes_a_slow_truck_and_returns_right_signalling() -> void:
	var truck: VehicleState = _sim.add_ai_vehicle(120.0, 0, 80.0 * KMH, 80.0 * KMH, 1.0)
	var car: VehicleState = _sim.add_ai_vehicle(0.0, 0, 120.0 * KMH, 130.0 * KMH, 1.0)
	_run(60.0)
	var changes: Array[Dictionary] = _changes_of(car)
	assert_int(changes.size()).is_equal(2)
	if changes.size() != 2:
		return
	assert_array([changes[0]["from"], changes[0]["to"]]).is_equal([0, 1])
	_assert_signalled(changes[0], LEFT)
	assert_array([changes[1]["from"], changes[1]["to"]]).is_equal([1, 0])
	_assert_signalled(changes[1], RIGHT)
	assert_int(car.lane).is_equal(0)
	assert_int(car.signal_dir).is_equal(NO_DIR)
	assert_float(car.rear_s()).is_greater(truck.front_s())
	assert_float(car.speed_mps).is_equal_approx(130.0 * KMH, 1.0 * KMH)
	assert_array(_changes_of(truck)).is_empty()
	assert_array(_collisions).is_empty()


func test_no_lane_change_into_a_vehicle_alongside() -> void:
	_sim.add_vehicle(40.0, 0, 80.0 * KMH)
	var car: VehicleState = _sim.add_ai_vehicle(0.0, 0, 80.0 * KMH, 130.0 * KMH, 1.0)
	_sim.add_vehicle(-3.0, 1, 80.0 * KMH)
	assert_bool(_signalled_within(car, 20.0)).is_false()
	assert_array(_changes).is_empty()
	assert_int(car.lane).is_equal(0)
	assert_array(_collisions).is_empty()


func test_no_lane_change_ahead_of_a_fast_approaching_car() -> void:
	_sim.add_vehicle(40.0, 0, 80.0 * KMH)
	var car: VehicleState = _sim.add_ai_vehicle(0.0, 0, 80.0 * KMH, 130.0 * KMH, 1.0)
	var fast: VehicleState = _sim.add_vehicle(-60.0, 1, 160.0 * KMH)
	var passed_at_s: float = -1.0
	for i: int in roundi(30.0 / DT):
		_sim.step(DT)
		if passed_at_s < 0.0 and fast.rear_s() > car.front_s():
			passed_at_s = _sim.time_s
	var changes: Array[Dictionary] = _changes_of(car)
	assert_float(passed_at_s).is_greater(0.0)
	assert_int(changes.size()).is_greater_equal(1)
	if changes.is_empty():
		return
	# The overtake only starts once the fast car has gone by.
	assert_float(changes[0]["time_s"]).is_greater(passed_at_s)
	assert_array(_collisions).is_empty()


func test_signalled_change_is_abandoned_when_the_gap_closes() -> void:
	_sim.add_vehicle(40.0, 0, 80.0 * KMH)
	var car: VehicleState = _sim.add_ai_vehicle(0.0, 0, 80.0 * KMH, 130.0 * KMH, 1.0)
	# The first lane decision comes within one decision interval.
	for i: int in roundi(_sim.config.ai_lane_decision_interval_s / DT) + 1:
		if car.signal_dir != NO_DIR:
			break
		_sim.step(DT)
	assert_int(car.signal_dir).is_equal(LEFT)
	_sim.add_vehicle(car.s - 50.0, 1, 160.0 * KMH)
	_sim.step(DT)
	assert_int(car.signal_dir).is_equal(NO_DIR)
	assert_bool(car.lane_change_active).is_false()
	assert_array(_changes).is_empty()


func test_model_driver_returns_right_on_a_free_road() -> void:
	var car: VehicleState = _sim.add_ai_vehicle(0.0, 1, 110.0 * KMH, 110.0 * KMH, 1.0)
	_run(10.0)
	assert_int(car.lane).is_equal(0)
	var changes: Array[Dictionary] = _changes_of(car)
	assert_int(changes.size()).is_equal(1)
	if changes.size() != 1:
		return
	_assert_signalled(changes[0], RIGHT)


func test_undisciplined_driver_has_no_keep_right_bias() -> void:
	var car: VehicleState = _sim.add_ai_vehicle(0.0, 1, 110.0 * KMH, 110.0 * KMH, 0.0)
	assert_bool(_signalled_within(car, 20.0)).is_false()
	assert_int(car.lane).is_equal(1)


func test_never_leaves_the_road() -> void:
	var right_lane: VehicleState = _sim.add_ai_vehicle(0.0, 0, 110.0 * KMH, 110.0 * KMH, 1.0)
	var left_lane: VehicleState = _sim.add_ai_vehicle(500.0, 1, 110.0 * KMH, 110.0 * KMH, 0.0)
	assert_float(right_lane.ai.lane_change_incentive(_sim, right_lane, RIGHT)).is_equal(-INF)
	assert_float(left_lane.ai.lane_change_incentive(_sim, left_lane, LEFT)).is_equal(-INF)
	_run(10.0)
	assert_array(_changes).is_empty()
	assert_bool(right_lane.off_road or left_lane.off_road).is_false()


func test_moving_right_gains_no_speed_over_the_left_lane_leader() -> void:
	# Stuck behind a slower car on the left lane, the right lane promises no speed of
	# its own; without a keep-right bias (discipline 0) there is no reason to move.
	_sim.add_vehicle(40.0, 1, 90.0 * KMH)
	var car: VehicleState = _sim.add_ai_vehicle(0.0, 1, 90.0 * KMH, 130.0 * KMH, 0.0)
	_sim.step(DT)
	assert_float(car.ai.lane_change_incentive(_sim, car, RIGHT)).is_less_equal(_sim.config.mobil_threshold_mps2)
	_run(10.0)
	assert_int(car.lane).is_equal(1)
	assert_array(_changes).is_empty()
