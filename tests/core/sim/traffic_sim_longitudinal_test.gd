extends GdUnitTestSuite
## Fixed-step longitudinal motion of TrafficSim (issue #4, spec Phase 2 step 1).

const DT: float = 1.0 / 60.0

var _config: SimConfig


func before_test() -> void:
	_config = load("res://config/sim_config.tres") as SimConfig


func _new_sim() -> TrafficSim:
	return TrafficSim.new(load("res://config/road_profiles/motorway.tres") as RoadProfile, _config)


func _drive(sim: TrafficSim, vehicle: VehicleState, input: VehicleState.Longitudinal, steps: int) -> void:
	sim.apply_commands(vehicle, PlayerCommands.create(input))
	for i: int in steps:
		sim.step(DT)


func test_sim_config_loads_from_tres() -> void:
	assert_float(_config.lane_change_duration_s).is_equal(1.75)
	assert_float(_config.max_speed_kmh).is_greater(140.0)
	assert_float(_config.acceleration_mps2).is_greater(0.0)
	assert_float(_config.braking_mps2).is_greater(0.0)


func test_accelerating_raises_speed_by_configured_rate() -> void:
	var sim: TrafficSim = _new_sim()
	var car: VehicleState = sim.add_vehicle(0.0, 0, 20.0)
	_drive(sim, car, VehicleState.Longitudinal.ACCELERATE, 60)
	assert_float(car.speed_mps).is_equal_approx(20.0 + _config.acceleration_mps2, 1e-6)
	assert_float(sim.time_s).is_equal_approx(1.0, 1e-9)


func test_no_input_holds_speed_and_advances_position() -> void:
	var sim: TrafficSim = _new_sim()
	var car: VehicleState = sim.add_vehicle(100.0, 0, 30.0)
	_drive(sim, car, VehicleState.Longitudinal.NONE, 120)
	assert_float(car.speed_mps).is_equal(30.0)
	assert_float(car.s).is_equal_approx(160.0, 1e-6)


func test_speed_never_exceeds_max_speed() -> void:
	var sim: TrafficSim = _new_sim()
	var car: VehicleState = sim.add_vehicle(0.0, 0, sim.max_speed_mps() - 1.0)
	_drive(sim, car, VehicleState.Longitudinal.ACCELERATE, 600)
	assert_float(car.speed_mps).is_equal(sim.max_speed_mps())


func test_braking_never_goes_below_zero() -> void:
	var sim: TrafficSim = _new_sim()
	var car: VehicleState = sim.add_vehicle(50.0, 0, 5.0)
	_drive(sim, car, VehicleState.Longitudinal.BRAKE, 600)
	assert_float(car.speed_mps).is_equal(0.0)
	var stopped_at: float = car.s
	sim.step(DT)
	assert_float(car.s).is_equal(stopped_at)


func test_spawn_speed_is_clamped() -> void:
	var sim: TrafficSim = _new_sim()
	assert_float(sim.add_vehicle(0.0, 0, -3.0).speed_mps).is_equal(0.0)
	assert_float(sim.add_vehicle(0.0, 1, 1000.0).speed_mps).is_equal(sim.max_speed_mps())


func test_same_inputs_give_identical_results() -> void:
	var first: VehicleState = _run_scripted_drive()
	var second: VehicleState = _run_scripted_drive()
	assert_float(second.s).is_equal(first.s)
	assert_float(second.speed_mps).is_equal(first.speed_mps)


func _run_scripted_drive() -> VehicleState:
	var sim: TrafficSim = _new_sim()
	var car: VehicleState = sim.add_vehicle(0.0, 0, 25.0)
	_drive(sim, car, VehicleState.Longitudinal.ACCELERATE, 437)
	_drive(sim, car, VehicleState.Longitudinal.NONE, 91)
	_drive(sim, car, VehicleState.Longitudinal.BRAKE, 173)
	return car
