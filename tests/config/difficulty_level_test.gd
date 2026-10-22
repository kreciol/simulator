extends GdUnitTestSuite
## Difficulty levels and spawner parameters come from data (requirements §10, §7.3;
## spec Data Model, Q13–Q14; issue #12).

const LEVEL_PATHS: Array[String] = [
	"res://config/difficulty_levels/level_1.tres",
	"res://config/difficulty_levels/level_2.tres",
	"res://config/difficulty_levels/level_3.tres",
	"res://config/difficulty_levels/level_4.tres",
]


func _levels() -> Array[DifficultyLevel]:
	var levels: Array[DifficultyLevel] = []
	for path: String in LEVEL_PATHS:
		levels.append(load(path) as DifficultyLevel)
	return levels


func test_four_levels_load_in_order() -> void:
	var levels: Array[DifficultyLevel] = _levels()
	var recommended: int = 0
	for i: int in levels.size():
		var level: DifficultyLevel = levels[i]
		assert_object(level).is_not_null()
		assert_int(level.id).is_equal(i + 1)
		assert_str(level.display_name_key).is_not_empty()
		assert_float(level.truck_share).is_between(0.0, 1.0)
		assert_float(level.ai_discipline_min).is_between(0.0, level.ai_discipline_max)
		assert_float(level.ai_discipline_max).is_less_equal(1.0)
		if level.recommended:
			recommended += 1
	# All levels are open; one is suggested (Q14).
	assert_int(recommended).is_equal(1)


func test_higher_levels_are_denser_with_wider_speed_spread_and_lower_discipline() -> void:
	var levels: Array[DifficultyLevel] = _levels()
	for i: int in range(1, levels.size()):
		var lower: DifficultyLevel = levels[i - 1]
		var higher: DifficultyLevel = levels[i]
		assert_float(higher.density_per_km_per_lane).is_greater(lower.density_per_km_per_lane)
		assert_float(higher.ai_speed_spread_kmh).is_greater(lower.ai_speed_spread_kmh)
		assert_float(higher.ai_discipline_min).is_less(lower.ai_discipline_min)
		assert_float(higher.ai_discipline_max).is_less_equal(lower.ai_discipline_max)
	# The calmest level drives by the book (requirements §10: "AI wzorowe").
	assert_float(levels[0].ai_discipline_min).is_greater_equal(0.9)


func test_spawn_zones_are_out_of_view_and_inside_the_window() -> void:
	var config: SimConfig = load("res://config/sim_config.tres") as SimConfig
	var view: ViewConfig = load("res://config/view_config.tres") as ViewConfig
	# Nothing appears inside the camera's far plane.
	assert_float(config.spawn_hidden_ahead_m).is_greater_equal(view.draw_distance_m())
	# Room for a whole truck between each hidden edge and the window edge.
	assert_float(config.spawn_window_ahead_m - config.spawn_hidden_ahead_m).is_greater(config.truck_length_m)
	assert_float(config.spawn_window_behind_m - config.spawn_hidden_behind_m).is_greater(config.truck_length_m)
	# The player's safety margin lies inside the view, so it also holds for runtime spawns.
	assert_float(config.spawn_player_clearance_m).is_less(config.spawn_hidden_behind_m)
	assert_float(config.spawn_interval_s).is_greater(0.0)
	assert_int(config.spawn_attempts_per_update).is_greater(0)


func test_trucks_always_count_as_slow_vehicles_to_overtake(
		profile_path: String,
		test_parameters: Array = [
			["res://config/road_profiles/motorway.tres"],
			["res://config/road_profiles/expressway.tres"],
			["res://config/road_profiles/motorway_3lane.tres"],
		]) -> void:
	var config: SimConfig = load("res://config/sim_config.tres") as SimConfig
	var road: RoadProfile = load(profile_path) as RoadProfile
	assert_float(config.truck_speed_min_kmh).is_less_equal(config.truck_speed_max_kmh)
	assert_float(config.truck_speed_max_kmh).is_less_equal(road.speed_limit_kmh - config.overtake_opportunity_margin_kmh)
	assert_int(config.min_overtake_opportunities).is_greater_equal(1)
