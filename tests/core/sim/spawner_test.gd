extends GdUnitTestSuite
## Spawner: safe placement, skipping, despawn and pooling, per-level traffic
## (issue #12, spec Phase 4 step 3, requirements §7.3, §10, Q13).

const DT: float = 1.0 / 60.0
const KMH: float = 1.0 / TrafficSim.KMH_PER_MPS
const MOTORWAY: String = "res://config/road_profiles/motorway.tres"
const LEVEL_PATH: String = "res://config/difficulty_levels/level_%d.tres"

var _sim: TrafficSim
var _spawner: Spawner
var _added: Array[VehicleState] = []
var _removed: Array[int] = []


func after_test() -> void:
	_sim = null
	_spawner = null
	_added.clear()
	_removed.clear()


## A sim with a model-driver bot as the player in the right lane at the start speed,
## and `_added` / `_removed` recording traffic changes from now on.
func _new_sim(profile_path: String = MOTORWAY, seed_value: int = 1) -> TrafficSim:
	var config: SimConfig = load("res://config/sim_config.tres") as SimConfig
	var road: RoadProfile = load(profile_path) as RoadProfile
	_sim = TrafficSim.new(road, config, seed_value)
	_sim.player = _sim.add_ai_vehicle(0.0, 0, config.start_speed_kmh * KMH, road.speed_limit_kmh * KMH, 1.0)
	_sim.vehicle_added.connect(func(vehicle_id: int) -> void: _added.append(_sim.find_vehicle(vehicle_id)))
	_sim.vehicle_removed.connect(func(vehicle_id: int) -> void: _removed.append(vehicle_id))
	return _sim


func _level(level_id: int) -> DifficultyLevel:
	return load(LEVEL_PATH % level_id) as DifficultyLevel


func _attach(level_id: int) -> void:
	_spawner = Spawner.new(_level(level_id))
	_spawner.attach(_sim)


func _steps(count: int) -> void:
	for i: int in count:
		_sim.step(DT)


func _body_gap(a: VehicleState, b: VehicleState) -> float:
	return absf(a.s - b.s) - (a.length_m + b.length_m) / 2.0


func test_attach_fills_the_window_to_density_outside_the_player_margin(
		level_id: int,
		test_parameters: Array = [[1], [2], [3], [4]]) -> void:
	_new_sim()
	_attach(level_id)
	var target: int = _spawner.target_count(_sim)
	var config: SimConfig = _sim.config
	var window_km: float = (config.spawn_window_ahead_m + config.spawn_window_behind_m) / 1000.0
	assert_int(target).is_equal(roundi(_level(level_id).density_per_km_per_lane * window_km * _sim.road.lane_count))
	# Random placement with legal gaps on both sides cannot pack the densest levels at
	# once; top-ups fill them during the warm-up (see traffic_session_test).
	assert_int(_spawner.count_in_window(_sim)).is_between(roundi(target * 0.6), target)
	for vehicle: VehicleState in _added:
		assert_float(_body_gap(vehicle, _sim.player)).is_greater_equal(config.spawn_player_clearance_m)
		assert_object(vehicle.ai).is_not_null()


func test_attach_needs_a_player() -> void:
	var sim: TrafficSim = TrafficSim.new(
			load(MOTORWAY) as RoadProfile,
			load("res://config/sim_config.tres") as SimConfig)
	var spawner: Spawner = Spawner.new(_level(1))
	assert_error(func() -> void: spawner.attach(sim)) \
			.is_push_error("Spawner: the sim needs a player to place traffic around")
	assert_object(sim.spawner).is_null()
	assert_array(sim.vehicles).is_empty()


func test_attaching_twice_changes_nothing() -> void:
	_new_sim()
	_attach(2)
	var count: int = _sim.vehicles.size()
	_spawner.attach(_sim)
	assert_int(_sim.vehicles.size()).is_equal(count)
	assert_int(_sim.collision.get_connections().size()).is_equal(1)


func test_placed_vehicles_keep_legal_gaps() -> void:
	_new_sim()
	_attach(4)
	for lane: int in _sim.road.lane_count:
		var on_lane: Array[VehicleState] = _sim.lanes.on_lane(lane)
		for i: int in range(1, on_lane.size()):
			var follower: VehicleState = on_lane[i - 1]
			var gap: float = on_lane[i].rear_s() - follower.front_s()
			assert_float(gap).is_greater_equal(LaneQuery.min_gap(follower.speed_mps * TrafficSim.KMH_PER_MPS))


## Dense level on a road packed with slow vehicles 20 m apart: every slot is unsafe,
## so nothing is spawned, at the start or later.
func test_a_dense_level_with_no_safe_slot_skips_spawns() -> void:
	var config: SimConfig = load("res://config/sim_config.tres") as SimConfig
	_sim = TrafficSim.new(load(MOTORWAY) as RoadProfile, config, 3)
	_sim.player = _sim.add_vehicle(0.0, 0, 20.0)
	for lane: int in _sim.road.lane_count:
		var s: float = -config.spawn_window_behind_m
		while s <= config.spawn_window_ahead_m:
			if lane != 0 or absf(s) > 10.0:
				_sim.add_vehicle(s, lane, 20.0)
			s += 20.0
	var vehicles_before: int = _sim.vehicles.size()
	var dense: DifficultyLevel = _level(4).duplicate() as DifficultyLevel
	dense.density_per_km_per_lane = 100.0
	_spawner = Spawner.new(dense)
	_spawner.attach(_sim)
	assert_int(_spawner.count_in_window(_sim)).is_less(_spawner.target_count(_sim))
	_steps(roundi(5.0 / DT))
	assert_int(_sim.vehicles.size()).is_equal(vehicles_before)
	for vehicle: VehicleState in _sim.vehicles:
		assert_object(vehicle.ai).is_null()


func test_vehicles_leaving_the_window_are_despawned_and_their_objects_reused() -> void:
	_new_sim()
	_attach(1)
	var config: SimConfig = _sim.config
	# Within the despawn margin a vehicle stays.
	var in_margin: VehicleState = _sim.add_ai_vehicle(
			_sim.player.s + config.spawn_window_ahead_m + config.despawn_margin_m / 2.0, 1, 30.0, 30.0, 1.0)
	_steps(roundi(config.spawn_interval_s / DT) + 1)
	assert_array(_removed).not_contains([in_margin.id])
	# Beyond it, it goes.
	var leaving: VehicleState = _sim.lanes.on_lane(0).back()
	var leaving_id: int = leaving.id
	leaving.s = _sim.player.s + config.spawn_window_ahead_m + config.despawn_margin_m + 10.0
	_added.clear()
	_steps(roundi(config.spawn_interval_s / DT) + 1)
	assert_array(_removed).contains([leaving_id])
	assert_object(_sim.find_vehicle(leaving_id)).is_null()
	# The top-up that replaces it reuses the pooled object.
	_steps(roundi(5.0 / DT))
	assert_array(_added).is_not_empty()
	assert_object(_added[0]).is_same(leaving)
	assert_int(_added[0].id).is_not_equal(leaving_id)


func test_ai_cars_that_collide_are_removed_but_not_the_player() -> void:
	_new_sim()
	_attach(1)
	var a: VehicleState = _sim.add_ai_vehicle(300.0, 1, 0.0, 0.0, 1.0)
	var b: VehicleState = _sim.add_ai_vehicle(300.0, 1, 0.0, 0.0, 1.0)
	var hitting_player: VehicleState = _sim.add_ai_vehicle(_sim.player.s, 0, _sim.player.speed_mps, _sim.player.speed_mps, 1.0)
	var removed_ids: Array[int] = [a.id, b.id]
	_steps(1)
	assert_array(_removed).contains(removed_ids)
	assert_object(_sim.find_vehicle(hitting_player.id)).is_same(hitting_player)
	assert_object(_sim.find_vehicle(_sim.player.id)).is_same(_sim.player)


## Q13: spawned cars spread wider in speed and drive less by the book on higher levels;
## every draw stays inside the level's ranges.
func test_spawned_traffic_follows_the_level() -> void:
	var stats: Array[Dictionary] = []
	for level_id: int in [1, 4]:
		var level: DifficultyLevel = _level(level_id)
		var speeds: Array[float] = []
		var disciplines: Array[float] = []
		for seed_value: int in 6:
			_added.clear()
			_new_sim(MOTORWAY, seed_value)
			_attach(level_id)
			var cruise_kmh: float = _sim.road.speed_limit_kmh + _sim.config.ai_car_speed_offset_kmh
			for vehicle: VehicleState in _added:
				var desired_kmh: float = vehicle.ai.desired_speed_mps * TrafficSim.KMH_PER_MPS
				assert_float(vehicle.ai.discipline).is_between(level.ai_discipline_min, level.ai_discipline_max)
				disciplines.append(vehicle.ai.discipline)
				if vehicle.kind == VehicleState.Kind.TRUCK:
					assert_float(desired_kmh).is_between(_sim.config.truck_speed_min_kmh - 1e-3, _sim.config.truck_speed_max_kmh + 1e-3)
					continue
				assert_float(absf(desired_kmh - cruise_kmh)).is_less_equal(level.ai_speed_spread_kmh + 1e-3)
				speeds.append(desired_kmh)
		stats.append({"speed_sd": _std_dev(speeds), "discipline": _mean(disciplines)})
	assert_float(stats[1]["speed_sd"]).is_greater(stats[0]["speed_sd"])
	assert_float(stats[1]["discipline"]).is_less(stats[0]["discipline"])


func test_traffic_is_deterministic_per_seed() -> void:
	var first: TrafficSim = _new_sim(MOTORWAY, 11)
	Spawner.new(_level(3)).attach(first)
	var second: TrafficSim = _new_sim(MOTORWAY, 11)
	Spawner.new(_level(3)).attach(second)
	for i: int in roundi(20.0 / DT):
		first.step(DT)
		second.step(DT)
	assert_dict(second.snapshot()).is_equal(first.snapshot())


func _mean(values: Array[float]) -> float:
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / values.size()


func _std_dev(values: Array[float]) -> float:
	var mean: float = _mean(values)
	var total: float = 0.0
	for value: float in values:
		total += (value - mean) * (value - mean)
	return sqrt(total / values.size())
