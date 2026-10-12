extends GdUnitTestSuite
## AI vehicle views: cars, vans/SUVs and trucks in several colours, brake lights when
## braking, indicators blinking before lane changes (issue #13, spec Phase 4 step 4).

const DT: float = 1.0 / 60.0

var _view: ViewConfig
var _config: SimConfig
var _sim: TrafficSim


func before_test() -> void:
	_view = load("res://config/view_config.tres") as ViewConfig
	_config = load("res://config/sim_config.tres") as SimConfig
	_sim = TrafficSim.new(load("res://config/road_profiles/motorway.tres") as RoadProfile, _config)


func _view_for(vehicle: VehicleState) -> VehicleView:
	var view: VehicleView = auto_free(VehicleView.new()) as VehicleView
	view.build(VehicleLook.look_of(vehicle, _view), vehicle.length_m, vehicle.width_m, _view)
	view.bind(vehicle)
	return view


func _update(view: VehicleView, player_s: float = 0.0) -> void:
	view.update(player_s, _sim.lateral_position(view.vehicle), _sim.time_s)


func _height(view: VehicleView) -> float:
	var top: float = 0.0
	for child: Node in view.get_children():
		var part: MeshInstance3D = child as MeshInstance3D
		top = maxf(top, part.position.y + (part.mesh as BoxMesh).size.y / 2.0)
	return top


func test_view_params_live_in_the_config() -> void:
	assert_int(_view.vehicle_colors.size()).is_greater_equal(4)
	assert_float(_view.van_share).is_between(0.0, 1.0)
	assert_float(_view.brake_light_decel_mps2).is_greater(0.0)


func test_three_looks_appear_across_traffic() -> void:
	var looks: Dictionary[VehicleLook.Look, bool] = {}
	for i: int in 20:
		looks[VehicleLook.look_of(_sim.add_vehicle(float(i) * 30.0, 0, 20.0), _view)] = true
	looks[VehicleLook.look_of(_sim.add_vehicle(700.0, 0, 20.0, VehicleState.Kind.TRUCK), _view)] = true
	assert_bool(looks.has(VehicleLook.Look.CAR)).is_true()
	assert_bool(looks.has(VehicleLook.Look.VAN)).is_true()
	assert_bool(looks.has(VehicleLook.Look.TRUCK)).is_true()


func test_trucks_always_look_like_trucks() -> void:
	for i: int in 10:
		var truck: VehicleState = _sim.add_vehicle(float(i) * 30.0, 0, 20.0, VehicleState.Kind.TRUCK)
		assert_int(VehicleLook.look_of(truck, _view)).is_equal(VehicleLook.Look.TRUCK)


func test_vehicles_come_in_several_colours() -> void:
	var colors: Dictionary[Color, bool] = {}
	for i: int in _view.vehicle_colors.size():
		var view: VehicleView = _view_for(_sim.add_vehicle(float(i) * 30.0, 0, 20.0))
		colors[view.paint_color] = true
		assert_object(view.painted[0].material_override).is_not_null()
		assert_object((view.painted[0].material_override as StandardMaterial3D).albedo_color).is_equal(view.paint_color)
	assert_int(colors.size()).is_equal(_view.vehicle_colors.size())


func test_look_and_colour_follow_the_id_not_the_rng() -> void:
	var car: VehicleState = _sim.add_vehicle(0.0, 0, 20.0)
	var rng_state: int = _sim.rng.state
	var look: VehicleLook.Look = VehicleLook.look_of(car, _view)
	assert_int(VehicleLook.look_of(car, _view)).is_equal(look)
	assert_object(VehicleLook.color_of(car, _view)).is_equal(VehicleLook.color_of(car, _view))
	assert_int(_sim.rng.state).is_equal(rng_state)


func test_bodies_match_the_look() -> void:
	var car: VehicleState = _sim.add_vehicle(0.0, 0, 20.0)
	var truck: VehicleState = _sim.add_vehicle(100.0, 0, 20.0, VehicleState.Kind.TRUCK)
	var car_view: VehicleView = auto_free(VehicleView.new()) as VehicleView
	car_view.build(VehicleLook.Look.CAR, car.length_m, car.width_m, _view)
	var van_view: VehicleView = auto_free(VehicleView.new()) as VehicleView
	van_view.build(VehicleLook.Look.VAN, car.length_m, car.width_m, _view)
	var truck_view: VehicleView = _view_for(truck)
	# Same footprint in the sim, but a van stands taller than a car; a truck taller still.
	assert_float(_height(van_view)).is_greater(_height(car_view))
	assert_float(_height(truck_view)).is_greater(_height(van_view))
	# Lamps sit at the body's ends.
	assert_float(truck_view.brake_lights[0].position.z).is_greater(truck.length_m / 2.0)
	assert_float(car_view.indicators_left[0].position.z).is_less(-car.length_m / 2.0)


func test_view_sits_at_its_distance_ahead_and_its_lane() -> void:
	var car: VehicleState = _sim.add_vehicle(250.0, 1, 30.0)
	var view: VehicleView = _view_for(car)
	_update(view, 100.0)
	assert_float(view.position.z).is_equal_approx(-150.0, 1e-6)
	assert_float(view.position.x).is_equal_approx(RoadLayout.x_of(_sim.road.lane_center(1)), 1e-6)


func test_brake_lights_light_when_braking() -> void:
	var car: VehicleState = _sim.add_vehicle(0.0, 0, 30.0)
	var view: VehicleView = _view_for(car)
	_update(view)
	assert_bool(view.brake_lit).is_false()
	car.longitudinal = VehicleState.Longitudinal.BRAKE
	_update(view)
	assert_bool(view.brake_lit).is_true()
	var material: StandardMaterial3D = view.brake_lights[0].material_override as StandardMaterial3D
	assert_int(material.shading_mode).is_equal(BaseMaterial3D.SHADING_MODE_UNSHADED)
	car.longitudinal = VehicleState.Longitudinal.ACCELERATE
	_update(view)
	assert_bool(view.brake_lit).is_false()


func test_ai_brake_lights_follow_the_drivers_deceleration() -> void:
	var speed: float = 30.0
	var follower: VehicleState = _sim.add_ai_vehicle(0.0, 0, speed, speed, 1.0)
	var view: VehicleView = _view_for(follower)
	# Cruising on a free road: no brake lights.
	_sim.step(DT)
	_update(view)
	assert_float(follower.ai.accel_mps2).is_greater_equal(-_view.brake_light_decel_mps2)
	assert_bool(view.brake_lit).is_false()
	# A stopped car close ahead: the driver brakes hard, the lights come on.
	_sim.add_vehicle(follower.s + 40.0, 0, 0.0)
	_sim.step(DT)
	_update(view)
	assert_float(follower.ai.accel_mps2).is_less(-_view.brake_light_decel_mps2)
	assert_bool(view.brake_lit).is_true()


func test_indicators_blink_on_the_signalled_side_only() -> void:
	var car: VehicleState = _sim.add_vehicle(0.0, 0, 30.0)
	var view: VehicleView = _view_for(car)
	_sim.toggle_signal(car, VehicleState.Dir.LEFT)
	_update(view)
	assert_bool(view.left_lit).is_true()
	assert_bool(view.right_lit).is_false()
	assert_int((view.indicators_left[1].material_override as StandardMaterial3D).shading_mode) \
			.is_equal(BaseMaterial3D.SHADING_MODE_UNSHADED)
	# Off for the second half of a blink period, on again after a full one.
	var period_steps: int = roundi(1.0 / _view.signal_blink_hz / DT)
	for i: int in floori(period_steps / 2.0) + 1:
		_sim.step(DT)
	_update(view)
	assert_bool(view.left_lit).is_false()
	for i: int in floori(period_steps / 2.0):
		_sim.step(DT)
	_update(view)
	assert_bool(view.left_lit).is_true()
	_sim.toggle_signal(car, VehicleState.Dir.LEFT)
	_update(view)
	assert_bool(view.left_lit).is_false()
	assert_bool(view.right_lit).is_false()


func test_ai_indicators_blink_before_the_lane_change_starts() -> void:
	# A fast car closing on a slow truck: it signals left, then pulls out.
	_sim.add_ai_vehicle(60.0, 0, 22.0, 22.0, 1.0, VehicleState.Kind.TRUCK)
	var car: VehicleState = _sim.add_ai_vehicle(0.0, 0, 36.0, 36.0, 1.0)
	var view: VehicleView = _view_for(car)
	var lit_before_change: bool = false
	for i: int in 600:
		_sim.step(DT)
		_update(view)
		if car.lane_change_active:
			break
		lit_before_change = lit_before_change or view.left_lit
	assert_bool(car.lane_change_active).is_true()
	assert_bool(lit_before_change).is_true()


func test_unbind_hides_the_view_for_the_pool() -> void:
	var view: VehicleView = _view_for(_sim.add_vehicle(0.0, 0, 30.0))
	assert_bool(view.visible).is_true()
	view.unbind()
	assert_bool(view.visible).is_false()
	assert_object(view.vehicle).is_null()
