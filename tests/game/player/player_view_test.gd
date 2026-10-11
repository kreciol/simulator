extends GdUnitTestSuite
## Cockpit rig: driver-seat view with dashboard/bonnet, lateral motion following the
## sim's lane change progress, signal lamps (issue #7, spec Phase 3 step 2).

const DT: float = 1.0 / 60.0

var _view: ViewConfig
var _player_view: PlayerView
var _sim: TrafficSim
var _car: VehicleState


func before_test() -> void:
	_view = load("res://config/view_config.tres") as ViewConfig
	_player_view = auto_free(PlayerView.new()) as PlayerView
	_player_view.setup(_view)
	_sim = TrafficSim.new(
			load("res://config/road_profiles/motorway.tres") as RoadProfile,
			load("res://config/sim_config.tres") as SimConfig)
	_car = _sim.add_vehicle(0.0, 0, 30.0)


func _update() -> void:
	_player_view.update(_car, _sim.lateral_position(_car), _sim.time_s)


## Degrees below the camera's optical axis at which `point` (rig space) appears.
func _degrees_below_axis(point: Vector3) -> float:
	var in_camera: Vector3 = _player_view.camera.transform.affine_inverse() * point
	return rad_to_deg(atan2(-in_camera.y, -in_camera.z))


func test_camera_sits_at_the_drivers_eye() -> void:
	var camera: Camera3D = _player_view.camera
	assert_float(camera.position.y).is_equal_approx(_view.eye_height_m, 1e-6)
	# Driver sits left of the centreline: left is -x.
	assert_float(camera.position.x).is_less(0.0)
	assert_float(camera.fov).is_equal(_view.camera_fov_deg)
	assert_float(camera.far).is_equal(_view.draw_distance_m())


func test_dashboard_and_bonnet_are_in_the_lower_part_of_the_view() -> void:
	var half_fov: float = _view.camera_fov_deg / 2.0
	var dashboard_top: float = _view.eye_height_m - PlayerView.DASHBOARD_TOP_BELOW_EYE_M
	var bonnet_top: float = _view.eye_height_m - PlayerView.BONNET_TOP_BELOW_EYE_M
	var dash_far: Vector3 = Vector3(_player_view.camera.position.x, dashboard_top, _player_view.dashboard_near_far_z().y)
	var bonnet_far: Vector3 = Vector3(_player_view.camera.position.x, bonnet_top,
			_player_view.bonnet.position.z - PlayerView.BONNET_SIZE.z / 2.0)
	var dash_angle: float = _degrees_below_axis(dash_far)
	var bonnet_angle: float = _degrees_below_axis(bonnet_far)
	assert_float(dash_angle).is_between(0.0, half_fov)
	# The bonnet's far edge shows above the dashboard, below the horizon.
	assert_float(bonnet_angle).is_between(0.0, dash_angle)
	assert_float(_player_view.dashboard.position.z).is_less(0.0)


func test_road_ahead_stays_visible_above_the_bonnet() -> void:
	var bonnet_top: float = _view.eye_height_m - PlayerView.BONNET_TOP_BELOW_EYE_M
	var bonnet_far: Vector3 = Vector3(_player_view.camera.position.x, bonnet_top,
			_player_view.bonnet.position.z - PlayerView.BONNET_SIZE.z / 2.0)
	# Road 70 m ahead (the legal gap at 140 km/h) is above the bonnet's edge.
	var road_ahead: Vector3 = Vector3(_player_view.camera.position.x, 0.0, -70.0)
	assert_float(_degrees_below_axis(road_ahead)).is_less(_degrees_below_axis(bonnet_far))


func test_lateral_position_follows_lane_change_progress() -> void:
	_update()
	assert_float(_player_view.position.x).is_equal_approx(RoadLayout.x_of(_sim.road.lane_center(0)), 1e-6)
	_sim.request_lane_change(_car, VehicleState.Dir.LEFT)
	var previous_x: float = _player_view.position.x
	var steps: int = roundi(_sim.config.lane_change_duration_s / DT)
	for i: int in steps:
		_sim.step(DT)
		_update()
		assert_float(_player_view.position.x).is_equal_approx(RoadLayout.x_of(_sim.lateral_position(_car)), 1e-5)
		assert_float(_player_view.position.x).is_less_equal(previous_x)
		previous_x = _player_view.position.x
	assert_int(_car.lane).is_equal(1)
	assert_float(_player_view.position.x).is_equal_approx(RoadLayout.x_of(_sim.road.lane_center(1)), 1e-5)
	assert_float(_player_view.position.z).is_equal(0.0)


func test_signal_lamp_blinks_on_its_side_only() -> void:
	_update()
	assert_bool(_player_view.signal_left.visible).is_false()
	assert_bool(_player_view.signal_right.visible).is_false()

	_sim.toggle_signal(_car, VehicleState.Dir.LEFT)
	_update()
	assert_bool(_player_view.signal_left.visible).is_true()
	assert_bool(_player_view.signal_right.visible).is_false()

	var half_period: float = 0.5 / _view.signal_blink_hz
	_player_view.update(_car, _sim.lateral_position(_car), _sim.time_s + half_period * 1.5)
	assert_bool(_player_view.signal_left.visible).is_false()
	_player_view.update(_car, _sim.lateral_position(_car), _sim.time_s + half_period * 2.5)
	assert_bool(_player_view.signal_left.visible).is_true()

	_sim.toggle_signal(_car, VehicleState.Dir.LEFT)
	_update()
	assert_bool(_player_view.signal_left.visible).is_false()
