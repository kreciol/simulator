extends GdUnitTestSuite
## Vehicle kinds, pooled vehicles and add/remove notifications (issue #12, spec
## Architecture: Spawner uses an object pool).

const DT: float = 1.0 / 60.0
const KMH: float = 1.0 / TrafficSim.KMH_PER_MPS
const LEFT: VehicleState.Dir = VehicleState.Dir.LEFT
const TRUCK: VehicleState.Kind = VehicleState.Kind.TRUCK

var _sim: TrafficSim
var _added: Array[int] = []
var _removed: Array[int] = []


func before_test() -> void:
	_sim = TrafficSim.new(
			load("res://config/road_profiles/motorway.tres") as RoadProfile,
			load("res://config/sim_config.tres") as SimConfig)
	_added.clear()
	_removed.clear()
	_sim.vehicle_added.connect(func(vehicle_id: int) -> void: _added.append(vehicle_id))
	_sim.vehicle_removed.connect(func(vehicle_id: int) -> void: _removed.append(vehicle_id))


func test_a_truck_takes_its_size_from_config() -> void:
	var truck: VehicleState = _sim.add_vehicle(0.0, 0, 20.0, TRUCK)
	var car: VehicleState = _sim.add_vehicle(100.0, 0, 20.0)
	assert_int(truck.kind).is_equal(TRUCK)
	assert_float(truck.length_m).is_equal(_sim.config.truck_length_m)
	assert_float(truck.width_m).is_equal(_sim.config.truck_width_m)
	assert_int(car.kind).is_equal(VehicleState.Kind.CAR)
	assert_float(car.length_m).is_equal(_sim.config.vehicle_length_m)
	# Lanes stay wider than any body, which collision detection relies on.
	assert_float(_sim.config.truck_width_m).is_less(_sim.road.lane_width_m)


func test_adding_and_removing_notify_with_the_id() -> void:
	var car: VehicleState = _sim.add_vehicle(0.0, 0, 20.0)
	_sim.remove_vehicle(car)
	assert_array(_added).contains_exactly([car.id])
	assert_array(_removed).contains_exactly([car.id])
	assert_array(_sim.vehicles).is_empty()
	assert_object(_sim.find_vehicle(car.id)).is_null()


func test_a_removed_vehicle_is_reused_with_fresh_state_and_a_new_id() -> void:
	var old: VehicleState = _sim.add_ai_vehicle(0.0, 0, 30.0, 30.0, 0.5)
	var old_driver: AiDriver = old.ai
	_sim.toggle_signal(old, LEFT)
	_sim.request_lane_change(old, LEFT)
	_sim.step(DT)
	var old_id: int = old.id
	_sim.remove_vehicle(old)
	assert_array(_sim.lanes.on_lane(0)).is_empty()
	assert_array(_sim.lanes.on_lane(1)).is_empty()

	var reused: VehicleState = _sim.add_ai_vehicle(500.0, 1, 20.0, 25.0, 0.9, TRUCK)
	assert_object(reused).is_same(old)
	assert_object(reused.ai).is_same(old_driver)
	assert_int(reused.id).is_not_equal(old_id)
	assert_int(reused.lane).is_equal(1)
	assert_bool(reused.lane_change_active).is_false()
	assert_float(reused.lane_change_progress).is_equal(0.0)
	assert_int(reused.signal_dir).is_equal(VehicleState.Dir.NONE)
	assert_float(reused.ai.desired_speed_mps).is_equal(25.0)
	assert_float(reused.ai.discipline).is_equal(0.9)
	assert_float(reused.length_m).is_equal(_sim.config.truck_length_m)
	assert_object(_sim.find_vehicle(reused.id)).is_same(reused)


func test_a_pooled_ai_vehicle_added_as_a_plain_vehicle_has_no_driver() -> void:
	var old: VehicleState = _sim.add_ai_vehicle(0.0, 0, 30.0, 30.0, 1.0)
	_sim.remove_vehicle(old)
	var plain: VehicleState = _sim.add_vehicle(0.0, 0, 30.0)
	assert_object(plain).is_same(old)
	assert_object(plain.ai).is_null()


func test_the_player_cannot_be_removed() -> void:
	var player: VehicleState = _sim.add_vehicle(0.0, 0, 30.0)
	_sim.player = player
	await assert_error(func() -> void: _sim.remove_vehicle(player)) \
			.is_push_error("TrafficSim: the player cannot be removed")
	assert_array(_sim.vehicles).contains([player])
	assert_array(_removed).is_empty()


func test_lane_decisions_are_spread_over_the_interval() -> void:
	var interval: float = _sim.config.ai_lane_decision_interval_s
	var phases: Array[float] = []
	for i: int in 8:
		var car: VehicleState = _sim.add_ai_vehicle(i * 100.0, 0, 30.0, 30.0, 1.0)
		phases.append(car.ai.next_lane_decision_s)
		assert_float(car.ai.next_lane_decision_s).is_between(0.0, interval)
	phases.sort()
	# Consecutive ids do not share a decision step.
	for i: int in range(1, phases.size()):
		assert_float(phases[i] - phases[i - 1]).is_greater(DT)


func test_a_car_weighs_lane_changes_once_per_interval() -> void:
	var car: VehicleState = _sim.add_ai_vehicle(0.0, 0, 30.0, 30.0, 1.0)
	var interval: float = _sim.config.ai_lane_decision_interval_s
	var decisions: Array[float] = []
	var last_next: float = car.ai.next_lane_decision_s
	for i: int in roundi(3.0 * interval / DT):
		_sim.step(DT)
		if car.ai.next_lane_decision_s != last_next:
			decisions.append(_sim.time_s)
			last_next = car.ai.next_lane_decision_s
	assert_int(decisions.size()).is_between(2, 3)
	for i: int in range(1, decisions.size()):
		assert_float(decisions[i] - decisions[i - 1]).is_equal_approx(interval, DT)


func test_a_slow_leader_triggers_a_signal_within_one_interval() -> void:
	_sim.add_ai_vehicle(60.0, 0, 20.0, 20.0, 1.0)
	var car: VehicleState = _sim.add_ai_vehicle(0.0, 0, 30.0, 36.0, 1.0)
	var steps: int = 0
	while car.signal_dir == VehicleState.Dir.NONE and steps < 600:
		_sim.step(DT)
		steps += 1
	assert_int(car.signal_dir).is_equal(LEFT)
	assert_float(steps * DT).is_less_equal(_sim.config.ai_lane_decision_interval_s + DT)
