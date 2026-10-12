extends GdUnitTestSuite
## Traffic view: one pooled view per AI vehicle, no create/free per spawn (issue #13
## acceptance criteria, spec Phase 4 step 4).

const DT: float = 1.0 / 60.0

var _view: ViewConfig
var _config: SimConfig
var _sim: TrafficSim
var _traffic_view: TrafficView


func before_test() -> void:
	_view = load("res://config/view_config.tres") as ViewConfig
	_config = load("res://config/sim_config.tres") as SimConfig


func _start(level_id: int, seed_value: int) -> void:
	_sim = TrafficSim.new(load("res://config/road_profiles/motorway.tres") as RoadProfile, _config, seed_value)
	_sim.player = _sim.add_vehicle(0.0, 0, _config.start_speed_kmh / TrafficSim.KMH_PER_MPS)
	Spawner.new(load("res://config/difficulty_levels/level_%d.tres" % level_id) as DifficultyLevel).attach(_sim)
	_traffic_view = auto_free(TrafficView.new()) as TrafficView
	_traffic_view.setup(_sim, _view)


## Every AI vehicle on the road has exactly one visible view showing it.
func _assert_views_match_the_sim() -> void:
	assert_int(_traffic_view.live_count()).is_equal(_sim.vehicles.size() - 1)
	var visible_views: int = 0
	for child: Node in _traffic_view.get_children():
		if (child as VehicleView).visible:
			visible_views += 1
	assert_int(visible_views).is_equal(_traffic_view.live_count())
	for vehicle: VehicleState in _sim.vehicles:
		var vehicle_view: VehicleView = _traffic_view.view_of(vehicle.id)
		if vehicle == _sim.player:
			assert_object(vehicle_view).is_null()
		else:
			assert_object(vehicle_view.vehicle).is_same(vehicle)


func test_views_match_the_traffic_already_on_the_road() -> void:
	_start(3, 11)
	assert_int(_sim.vehicles.size()).is_greater(1)
	_assert_views_match_the_sim()


func test_view_count_follows_spawns_and_despawns_from_a_pool() -> void:
	_start(4, 7)
	# The player cruises at the start speed, slower than most cars: traffic overtakes,
	# leaves the window behind and is replaced ahead, so vehicles churn.
	var added: Array[int] = [0]
	var removed: Array[int] = [0]
	_sim.vehicle_added.connect(func(_id: int) -> void: added[0] += 1)
	_sim.vehicle_removed.connect(func(_id: int) -> void: removed[0] += 1)
	for i: int in roundi(45.0 / DT):
		_sim.step(DT)
		if i % 60 == 0:
			_assert_views_match_the_sim()
	_assert_views_match_the_sim()
	assert_int(removed[0]).is_greater(0)
	var built_after_warm_up: int = _traffic_view.built_count
	var added_after_warm_up: int = added[0]
	for i: int in roundi(45.0 / DT):
		_sim.step(DT)
	_assert_views_match_the_sim()
	assert_int(added[0]).is_greater(added_after_warm_up)
	# Pooling: views of despawned vehicles are reused, so far fewer views are ever
	# built than vehicles spawned, and every built view is either live or idle.
	assert_int(_traffic_view.built_count).is_less(added[0] + _traffic_view.live_count())
	assert_int(_traffic_view.get_child_count()).is_equal(_traffic_view.built_count)
	assert_int(_traffic_view.built_count).is_less_equal(built_after_warm_up + _traffic_view.live_count())


func test_a_reused_view_shows_its_new_vehicle() -> void:
	_start(1, 3)
	var car: VehicleState = _sim.add_vehicle(_sim.player.s + 300.0, 1, 30.0)
	var first: VehicleView = _traffic_view.view_of(car.id)
	var look: VehicleLook.Look = first.look
	_sim.remove_vehicle(car)
	assert_object(_traffic_view.view_of(car.id)).is_null()
	assert_bool(first.visible).is_false()
	# Add cars until one with the same look takes the idle view.
	var reused: bool = false
	for i: int in 20:
		var next: VehicleState = _sim.add_vehicle(_sim.player.s + 320.0 + float(i) * 20.0, 1, 30.0)
		if VehicleLook.look_of(next, _view) == look:
			assert_object(_traffic_view.view_of(next.id)).is_same(first)
			assert_object(first.vehicle).is_same(next)
			assert_bool(first.visible).is_true()
			reused = true
			break
	assert_bool(reused).is_true()


func test_views_sit_where_their_vehicles_are() -> void:
	_start(2, 5)
	for i: int in 120:
		_sim.step(DT)
	_traffic_view.update()
	for vehicle: VehicleState in _sim.vehicles:
		if vehicle == _sim.player:
			continue
		var vehicle_view: VehicleView = _traffic_view.view_of(vehicle.id)
		assert_float(vehicle_view.position.z).is_equal_approx(-(vehicle.s - _sim.player.s), 1e-3)
		assert_float(vehicle_view.position.x).is_equal_approx(RoadLayout.x_of(_sim.lateral_position(vehicle)), 1e-3)
