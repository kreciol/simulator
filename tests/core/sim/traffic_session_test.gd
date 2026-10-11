extends GdUnitTestSuite
## A 90 s session per level × road profile at the game's physics rate: density after
## the warm-up and where vehicles appear (issue #12, spec Phase 4 step 3, requirements
## §7.3, §10). The player is a model-driver bot keeping to the limit.

const DT: float = 1.0 / 60.0
const KMH: float = 1.0 / TrafficSim.KMH_PER_MPS
const SESSION_S: float = 90.0
const WARM_UP_S: float = 30.0
## Allowed deviation of the mean density from the level's target.
const DENSITY_TOLERANCE: float = 0.2

var _sim: TrafficSim
## Every vehicle added after `attach`, with its offset from the player at that moment.
var _spawns: Array[Dictionary] = []


func after_test() -> void:
	_sim = null
	_spawns.clear()


func test_session_traffic(
		profile_path: String,
		level_id: int,
		test_parameters: Array = [
			["res://config/road_profiles/motorway.tres", 1],
			["res://config/road_profiles/motorway.tres", 2],
			["res://config/road_profiles/motorway.tres", 3],
			["res://config/road_profiles/motorway.tres", 4],
			["res://config/road_profiles/expressway.tres", 1],
			["res://config/road_profiles/expressway.tres", 2],
			["res://config/road_profiles/expressway.tres", 3],
			["res://config/road_profiles/expressway.tres", 4],
		]) -> void:
	var config: SimConfig = load("res://config/sim_config.tres") as SimConfig
	var road: RoadProfile = load(profile_path) as RoadProfile
	var view: ViewConfig = load("res://config/view_config.tres") as ViewConfig
	_sim = TrafficSim.new(road, config, level_id * 31)
	_sim.player = _sim.add_ai_vehicle(0.0, 0, config.start_speed_kmh * KMH, road.speed_limit_kmh * KMH, 1.0)
	var spawner: Spawner = Spawner.new(load("res://config/difficulty_levels/level_%d.tres" % level_id) as DifficultyLevel)
	spawner.attach(_sim)
	_sim.vehicle_added.connect(func(vehicle_id: int) -> void:
		var vehicle: VehicleState = _sim.find_vehicle(vehicle_id)
		_spawns.append({"offset": vehicle.s - _sim.player.s, "half": vehicle.length_m / 2.0}))

	var samples: int = 0
	var total: int = 0
	for i: int in roundi(SESSION_S / DT):
		_sim.step(DT)
		if _sim.time_s >= WARM_UP_S and i % 60 == 0:
			samples += 1
			total += spawner.count_in_window(_sim)

	# Density within ±20% of the level's target after the warm-up.
	var target: int = spawner.target_count(_sim)
	var mean: float = float(total) / samples
	assert_float(mean).override_failure_message("mean %.1f vs target %d" % [mean, target]) \
			.is_between(target * (1.0 - DENSITY_TOLERANCE), target * (1.0 + DENSITY_TOLERANCE))

	# During the session, vehicles appear only beyond the camera's far plane or the
	# hidden distance behind, so never within the player's safety margin either.
	assert_array(_spawns).is_not_empty()
	for spawn: Dictionary in _spawns:
		# Recorded at spawn time: pooled objects are reused later.
		var offset: float = spawn["offset"]
		var half: float = spawn["half"]
		var out_of_view: bool = offset - half >= view.draw_distance_m() \
				or offset + half <= -config.spawn_hidden_behind_m
		assert_bool(out_of_view).override_failure_message("spawned %.1f m from the player" % offset).is_true()
		assert_float(absf(offset) - (half + _sim.player.length_m / 2.0)).is_greater_equal(config.spawn_player_clearance_m)
	assert_bool(_sim.player.off_road).is_false()
