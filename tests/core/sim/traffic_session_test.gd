extends GdUnitTestSuite
## A 90 s session per level × road profile at the game's physics rate: density after
## the warm-up, where vehicles appear, and something to overtake (issue #12, spec
## Phase 4 step 3, requirements §7.3, §10). The player is a model-driver bot keeping
## to the limit.

const DT: float = 1.0 / 60.0
const KMH: float = 1.0 / TrafficSim.KMH_PER_MPS
const SESSION_S: float = 90.0
const WARM_UP_S: float = 30.0
## Allowed deviation of the mean density from the level's target.
const DENSITY_TOLERANCE: float = 0.2

var _sim: TrafficSim
## Every vehicle the spawner added, as seen when it appeared (pooled objects are
## reused later, so nothing is read back from them).
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
	_sim.vehicle_added.connect(func(vehicle_id: int) -> void:
		var vehicle: VehicleState = _sim.find_vehicle(vehicle_id)
		_spawns.append({
			"at_start": _sim.time_s == 0.0,
			"offset": vehicle.s - _sim.player.s,
			"half": vehicle.length_m / 2.0,
			"lane": vehicle.lane,
			"slow": Spawner.is_slow(_sim, vehicle.ai.desired_speed_mps),
		}))
	spawner.attach(_sim)

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

	# No vehicle is ever placed within the player's safety margin. After the start,
	# vehicles appear only beyond the camera's far plane or the hidden distance behind.
	var opportunities: int = 0
	var runtime_spawns: int = 0
	for spawn: Dictionary in _spawns:
		var offset: float = spawn["offset"]
		var half: float = spawn["half"]
		assert_float(absf(offset) - (half + _sim.player.length_m / 2.0)).is_greater_equal(config.spawn_player_clearance_m)
		if spawn["lane"] == 0 and offset > 0.0 and spawn["slow"]:
			opportunities += 1
		if spawn["at_start"]:
			continue
		runtime_spawns += 1
		var out_of_view: bool = offset - half >= view.draw_distance_m() \
				or offset + half <= -config.spawn_hidden_behind_m
		assert_bool(out_of_view).override_failure_message("spawned %.1f m from the player" % offset).is_true()
	assert_int(runtime_spawns).is_greater(0)

	# Something to overtake: slow vehicles ahead in the right lane (teachable moments).
	assert_int(opportunities).is_greater_equal(config.min_overtake_opportunities)
	assert_int(spawner.overtake_opportunities).is_equal(opportunities)
	assert_bool(_sim.player.off_road).is_false()


## The guarantee itself, on the calmest level where random traffic is sparsest: the
## first slow vehicle comes right at the start, the next once its interval is up. A
## placement waits for a safe slot, so each gets `SLACK_S` to find one.
func test_slow_vehicles_are_due_on_schedule() -> void:
	const SLACK_S: float = 1.0
	var config: SimConfig = load("res://config/sim_config.tres") as SimConfig
	var road: RoadProfile = load("res://config/road_profiles/motorway.tres") as RoadProfile
	_sim = TrafficSim.new(road, config, 5)
	_sim.player = _sim.add_ai_vehicle(0.0, 0, config.start_speed_kmh * KMH, road.speed_limit_kmh * KMH, 1.0)
	var spawner: Spawner = Spawner.new(load("res://config/difficulty_levels/level_1.tres") as DifficultyLevel)
	spawner.attach(_sim)
	var counts: Dictionary[float, int] = {}
	var checkpoints: Array[float] = [SLACK_S, config.overtake_opportunity_interval_s + SLACK_S]
	for i: int in roundi(checkpoints.back() / DT) + 1:
		_sim.step(DT)
		for checkpoint: float in checkpoints:
			if not counts.has(checkpoint) and _sim.time_s >= checkpoint:
				counts[checkpoint] = spawner.overtake_opportunities
	assert_int(counts[checkpoints[0]]).is_greater_equal(1)
	assert_int(counts[checkpoints[1]]).is_greater_equal(mini(2, config.min_overtake_opportunities))


## Requirements §16: AI never causes a collision with the player. The player here just
## holds its lane and speed, so an AI that fails to brake behind it or cuts into it
## shows up — a self-driving player bot would hide both (issue #47). The player may
## still run into a slower car ahead itself; that is its own fault and not counted.
func test_ai_never_runs_into_a_player_that_holds_its_speed(
		level_id: int,
		lane: int,
		test_parameters: Array = [[1, 0], [2, 0], [3, 0], [4, 0], [1, 1], [2, 1], [3, 1], [4, 1]]) -> void:
	var config: SimConfig = load("res://config/sim_config.tres") as SimConfig
	var road: RoadProfile = load("res://config/road_profiles/motorway.tres") as RoadProfile
	_sim = TrafficSim.new(road, config, level_id * 31 + lane)
	_sim.player = _sim.add_vehicle(0.0, lane, config.start_speed_kmh * KMH)
	Spawner.new(load("res://config/difficulty_levels/level_%d.tres" % level_id) as DifficultyLevel).attach(_sim)
	var caused_by_ai: Array[String] = []
	_sim.collision.connect(func(vehicle_id: int, other_id: int) -> void:
		var player: VehicleState = _sim.player
		if vehicle_id != player.id and other_id != player.id:
			return
		var other: VehicleState = _sim.find_vehicle(other_id if vehicle_id == player.id else vehicle_id)
		if other.s < player.s or other.lane_change_active:
			caused_by_ai.append("t=%.1f s: vehicle %d %s" % [_sim.time_s, other.id,
					"cut in" if other.lane_change_active else "ran into the back"]))
	# The run must actually test something: AI closing in right behind the player, on
	# its lane or the one it could cut in from.
	const CLOSE_BEHIND_M: float = 40.0
	var close_behind_steps: int = 0
	for i: int in roundi(SESSION_S / DT):
		_sim.step(DT)
		for on_lane: int in road.lane_count:
			var behind: VehicleState = LaneQuery.follower_in_lane(_sim.lanes, on_lane, _sim.player.s, _sim.player)
			if behind != null and _sim.player.s - behind.s < CLOSE_BEHIND_M:
				close_behind_steps += 1
	assert_int(close_behind_steps).is_greater(0)
	assert_array(caused_by_ai).override_failure_message("AI collisions with the player: %s" % [caused_by_ai]).is_empty()


## Requirements §16: a higher level brings noticeably more traffic — measured, not just
## configured: each level's mean count is well above the level below (issue #47).
func test_higher_levels_bring_noticeably_more_traffic() -> void:
	const MIN_STEP_RATIO: float = 1.2
	var config: SimConfig = load("res://config/sim_config.tres") as SimConfig
	var road: RoadProfile = load("res://config/road_profiles/motorway.tres") as RoadProfile
	var means: Array[float] = []
	for level_id: int in range(1, 5):
		_sim = TrafficSim.new(road, config, level_id * 31)
		_sim.player = _sim.add_ai_vehicle(0.0, 0, config.start_speed_kmh * KMH, road.speed_limit_kmh * KMH, 1.0)
		var spawner: Spawner = Spawner.new(load("res://config/difficulty_levels/level_%d.tres" % level_id) as DifficultyLevel)
		spawner.attach(_sim)
		var samples: int = 0
		var total: int = 0
		for i: int in roundi(SESSION_S / DT):
			_sim.step(DT)
			if _sim.time_s >= WARM_UP_S and i % 60 == 0:
				samples += 1
				total += spawner.count_in_window(_sim)
		means.append(float(total) / samples)
	for i: int in range(1, means.size()):
		assert_float(means[i]).override_failure_message("level means %s" % [means]) \
				.is_greater_equal(means[i - 1] * MIN_STEP_RATIO)
	assert_float(means[3]).is_greater_equal(2.0 * means[0])
