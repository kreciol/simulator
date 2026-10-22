extends GdUnitTestSuite
## Ten minutes of spawned traffic per level × road profile without a single AI–AI
## collision (issue #12, spec Phase 4 step 3, spec Architecture: Collisions).
##
## Budget: the whole suite must stay within 60 s of CI wall time (spec). It steps at
## 30 Hz, half the game's physics rate: coarser steps integrate less precisely and
## react later, so this is the stricter check of the AI's gap keeping. The 90 s
## sessions in traffic_session_test run at the game's rate. Longer soak runs are a
## manual task: raise RUN_S locally.

const DT: float = 1.0 / 30.0
const KMH: float = 1.0 / TrafficSim.KMH_PER_MPS
const RUN_S: float = 600.0

var _sim: TrafficSim


func after_test() -> void:
	_sim = null


func test_ten_minutes_of_traffic_without_collisions(
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
			["res://config/road_profiles/motorway_3lane.tres", 1],
			["res://config/road_profiles/motorway_3lane.tres", 2],
			["res://config/road_profiles/motorway_3lane.tres", 3],
			["res://config/road_profiles/motorway_3lane.tres", 4],
		]) -> void:
	var config: SimConfig = load("res://config/sim_config.tres") as SimConfig
	var road: RoadProfile = load(profile_path) as RoadProfile
	_sim = TrafficSim.new(road, config, 1000 + level_id)
	# The player is a model-driver bot, so every vehicle on the road is AI driven.
	_sim.player = _sim.add_ai_vehicle(0.0, 0, config.start_speed_kmh * KMH, road.speed_limit_kmh * KMH, 1.0)
	Spawner.new(load("res://config/difficulty_levels/level_%d.tres" % level_id) as DifficultyLevel).attach(_sim)
	var collisions: Array[Vector2i] = []
	var offroad_ids: Array[int] = []
	var lane_changes: Array[int] = [0]
	_sim.collision.connect(func(vehicle_id: int, other_id: int) -> void:
		collisions.append(Vector2i(vehicle_id, other_id)))
	_sim.offroad.connect(func(vehicle_id: int) -> void: offroad_ids.append(vehicle_id))
	_sim.lane_change_started.connect(func(_vehicle_id: int, _from: int, _to: int) -> void:
		lane_changes[0] += 1)

	for i: int in roundi(RUN_S / DT):
		_sim.step(DT)

	assert_array(collisions).is_empty()
	assert_array(offroad_ids).is_empty()
	# The run exercised overtaking, not just following.
	assert_int(lane_changes[0]).is_greater(0)
