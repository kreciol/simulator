extends GdUnitTestSuite
## Learn-mode respawn position: right lane, free ahead and behind, nearest to the
## incident, blockers despawned when no gap is free (issue #33, requirements §9.2).

const DT: float = 1.0 / 60.0

var _sim: TrafficSim
var _config: SimConfig
var _player: VehicleState


func before_test() -> void:
	_config = load("res://config/sim_config.tres") as SimConfig
	_sim = TrafficSim.new(load("res://config/road_profiles/motorway.tres") as RoadProfile, _config)
	_player = _sim.add_vehicle(1000.0, 1, 30.0)
	_sim.player = _player


func _assert_window_free(s: float) -> void:
	var half_length_m: float = _player.length_m / 2.0
	for vehicle: VehicleState in _sim.vehicles:
		if vehicle == _player or not LaneQuery.occupies_lane(vehicle, Respawn.LANE):
			continue
		var clear: bool = vehicle.rear_s() > s + half_length_m + _config.respawn_clear_ahead_m \
				or vehicle.front_s() < s - half_length_m - _config.respawn_clear_behind_m
		assert_bool(clear).override_failure_message("vehicle %d in the respawn window" % vehicle.id).is_true()


func test_the_respawn_window_is_configured() -> void:
	assert_float(_config.respawn_fade_s).is_greater(0.0)
	assert_float(_config.respawn_speed_kmh).is_greater(0.0)
	assert_float(_config.respawn_clear_ahead_m).is_greater(0.0)
	assert_float(_config.respawn_clear_behind_m).is_greater(0.0)
	assert_float(_config.respawn_search_range_m).is_greater_equal(_config.respawn_search_step_m)


func test_an_empty_right_lane_takes_the_player_back_where_it_was() -> void:
	var s: float = Respawn.respawn_player(_sim)
	assert_float(s).is_equal(1000.0)
	assert_float(_player.s).is_equal(1000.0)
	assert_int(_player.lane).is_equal(Respawn.LANE)
	assert_float(_player.speed_mps * TrafficSim.KMH_PER_MPS).is_equal_approx(_config.respawn_speed_kmh, 1e-6)
	assert_array(_sim.lanes.on_lane(Respawn.LANE)).contains_exactly([_player])
	assert_array(_sim.lanes.on_lane(1)).is_empty()


func _respawn_speed_mps() -> float:
	return _config.respawn_speed_kmh / TrafficSim.KMH_PER_MPS


func test_the_nearest_free_gap_wins_and_is_free_ahead_and_behind() -> void:
	# A car at the respawn speed on the right lane level with the incident blocks it.
	var blocker: VehicleState = _sim.add_vehicle(1000.0, 0, _respawn_speed_mps())
	var s: float = Respawn.respawn_player(_sim)
	assert_float(s).is_not_equal(1000.0)
	_assert_window_free(s)
	assert_object(_sim.find_vehicle(blocker.id)).is_same(blocker)
	# Every candidate nearer than the one chosen is blocked.
	var step: float = _config.respawn_search_step_m
	var offset: float = step
	while offset < absf(s - 1000.0):
		assert_bool(Respawn.is_safe(_sim, 1000.0 + offset)).is_false()
		assert_bool(Respawn.is_safe(_sim, 1000.0 - offset)).is_false()
		offset += step
	# The window reaches further behind than ahead, so the nearest gap is behind it.
	assert_float(s).is_less(1000.0)
	assert_float(_player.speed_mps).is_equal_approx(_respawn_speed_mps(), 1e-6)


func test_ahead_wins_at_equal_distance() -> void:
	_sim.add_vehicle(1000.0, 0, _respawn_speed_mps())
	var config: SimConfig = _config.duplicate() as SimConfig
	config.respawn_clear_behind_m = config.respawn_clear_ahead_m
	_sim.config = config
	assert_float(Respawn.find_free_s(_sim, 1000.0)).is_greater(1000.0)


func test_a_stopped_vehicle_hit_puts_the_player_ahead_of_it_not_behind() -> void:
	# Right behind a slower vehicle the player would run straight into it again.
	var wreck: VehicleState = _sim.add_vehicle(1000.0, 0, 0.0)
	var s: float = Respawn.respawn_player(_sim)
	assert_float(s).is_greater(wreck.front_s())
	_assert_window_free(s)
	assert_object(Respawn.slower_leader(_sim, s)).is_null()
	assert_float(_player.speed_mps).is_equal_approx(_respawn_speed_mps(), 1e-6)
	# Free but too close behind it is not safe.
	var behind_s: float = wreck.rear_s() - _player.length_m / 2.0 - _config.respawn_clear_ahead_m - 1.0
	assert_bool(Respawn.is_window_free(_sim, behind_s)).is_true()
	assert_bool(Respawn.is_safe(_sim, behind_s)).is_false()


func test_a_faster_leader_just_ahead_is_safe() -> void:
	_sim.add_vehicle(1000.0 + _player.length_m + _config.respawn_clear_ahead_m + 5.0, 0, _respawn_speed_mps() + 5.0)
	assert_bool(Respawn.is_safe(_sim, 1000.0)).is_true()


func test_a_full_lane_has_its_blockers_at_the_incident_despawned() -> void:
	# Right lane packed every 20 m over the whole search range.
	var packed: Array[VehicleState] = []
	var reach: float = _config.respawn_search_range_m + _config.respawn_clear_ahead_m + _config.respawn_clear_behind_m
	var s: float = 1000.0 - reach
	while s <= 1000.0 + reach:
		packed.append(_sim.add_vehicle(s, 0, 0.0))
		s += 20.0
	assert_bool(is_nan(Respawn.find_free_s(_sim, 1000.0))).is_true()
	var removed: Array[int] = []
	_sim.vehicle_removed.connect(func(vehicle_id: int) -> void: removed.append(vehicle_id))
	var placed_s: float = Respawn.respawn_player(_sim)
	assert_float(placed_s).is_equal(1000.0)
	assert_array(removed).is_not_empty()
	_assert_window_free(placed_s)
	# The stopped queue beyond the window caps the speed: the player joins it.
	assert_float(_player.speed_mps).is_equal(0.0)
	# Only the vehicles in the window went; the rest of the lane stays.
	assert_int(_sim.vehicles.size()).is_equal(packed.size() - removed.size() + 1)
	var half_length_m: float = _player.length_m / 2.0
	var window_front: float = placed_s + half_length_m + _config.respawn_clear_ahead_m
	var window_rear: float = placed_s - half_length_m - _config.respawn_clear_behind_m
	for vehicle: VehicleState in packed:
		var in_window: bool = vehicle.rear_s() <= window_front and vehicle.front_s() >= window_rear
		assert_bool(removed.has(vehicle.id)).override_failure_message(
				"vehicle at %.0f m: in window %s" % [vehicle.s, in_window]).is_equal(in_window)


func test_a_vehicle_changing_into_the_right_lane_blocks_it() -> void:
	var merging: VehicleState = _sim.add_vehicle(1000.0, 1, 0.0)
	_sim.request_lane_change(merging, VehicleState.Dir.RIGHT)
	assert_bool(Respawn.is_window_free(_sim, 1000.0)).is_false()


func test_placing_clears_lane_change_signal_and_off_road() -> void:
	_sim.toggle_signal(_player, VehicleState.Dir.LEFT)
	_sim.request_lane_change(_player, VehicleState.Dir.LEFT)
	_player.longitudinal = VehicleState.Longitudinal.ACCELERATE
	_player.off_road = true
	_sim.place_vehicle(_player, 500.0, 0, 20.0)
	assert_bool(_player.lane_change_active).is_false()
	assert_int(_player.signal_dir).is_equal(VehicleState.Dir.NONE)
	assert_int(_player.longitudinal).is_equal(VehicleState.Longitudinal.NONE)
	assert_bool(_player.off_road).is_false()
	assert_float(_player.s).is_equal(500.0)
	assert_float(_player.speed_mps).is_equal(20.0)
	assert_array(_sim.lanes.on_lane(1)).is_empty()
	assert_array(_sim.lanes.on_lane(2)).is_empty()
	assert_array(_sim.lanes.on_lane(0)).contains_exactly([_player])


func test_a_placed_vehicle_touching_again_is_a_new_collision() -> void:
	var collisions: Array[Vector2i] = []
	_sim.collision.connect(func(a: int, b: int) -> void: collisions.append(Vector2i(a, b)))
	var other: VehicleState = _sim.add_vehicle(1001.0, 1, 30.0)
	_sim.step(DT)
	assert_int(collisions.size()).is_equal(1)
	# Moved away and straight back into contact: reported again, not remembered.
	_sim.place_vehicle(_player, other.s, 1, other.speed_mps)
	_sim.step(DT)
	assert_int(collisions.size()).is_equal(2)
