extends GdUnitTestSuite
## Every numeric [PARAM] of the requirements is written in its `.tres`, not left to a
## default in the resource script — so tuning one (spec Phase 11, issue #47) changes
## only a config file, never code (requirements §0, §14 Konfigurowalność).

## `.tres` path → the [PARAM]s it must set, each with the requirements section naming it.
const PARAMS: Dictionary[String, Dictionary] = {
	"res://config/road_profiles/motorway.tres": {
		"speed_limit_kmh": "§4.1", "lane_count": "§4.1", "lane_width_m": "§4.1", "shoulder_width_m": "§4.1",
	},
	"res://config/road_profiles/expressway.tres": {
		"speed_limit_kmh": "§4.1", "lane_count": "§4.1", "lane_width_m": "§4.1", "shoulder_width_m": "§4.1",
	},
	"res://config/road_profiles/motorway_3lane.tres": {
		"speed_limit_kmh": "§4.1", "lane_count": "§4.1", "lane_width_m": "§4.1", "shoulder_width_m": "§4.1",
	},
	"res://config/view_config.tres": {
		"segment_length_m": "§4.3", "segment_count": "§4.3",
	},
	"res://config/sim_config.tres": {
		"acceleration_mps2": "§5.4", "braking_mps2": "§5.4", "max_speed_kmh": "§5.4",
		"lane_change_duration_s": "§6.4", "signal_min_on_s": "§6.5",
		"ai_car_speed_offset_kmh": "§7.2", "truck_speed_min_kmh": "§7.2", "truck_speed_max_kmh": "§7.2",
		"despawn_margin_m": "§7.3", "respawn_speed_kmh": "§9.2",
		"session_length_s": "§9.3", "start_speed_kmh": "§9.3",
	},
	"res://config/scoring.tres": {
		"k1_base_per_s": "§8.2 K1", "k1_exponent": "§8.2 K1",
		"k2_grace_s": "§8.2 K2", "k2_penalty_per_s": "§8.2 K2",
		"k3_penalty": "§8.2 K3", "k4_penalty": "§8.2 K4",
		"n1_reward": "§8.3 N1", "n1_cooldown_s": "§8.3 N1", "n1_clear_ahead_m": "§8.3 N1", "n1_clear_behind_m": "§8.3 N1",
		"n2_reward_per_s": "§8.3 N2", "n3_reward_per_s": "§8.3 N3", "n3_range_m": "§8.3 N3",
		"k2_min_look_ahead_m": "§8.4", "k2_return_horizon_s": "§8.4", "k2_look_behind_m": "§8.4",
		"overtake_look_ahead_m": "§8.4",
		"speed_rule_enabled": "§8.5", "speed_tolerance_kmh": "§8.5",
	},
	"res://config/menu.tres": {
		"exam_suggested_after_learn_sessions": "§9.1",
	},
	"res://config/feedback.tres": {
		"hint_cooldown_s": "§11.2", "hint_max_on_screen": "§11.2",
	},
	"res://config/persistence.tres": {
		"history_limit": "§13",
	},
}

## The per-level [PARAM]s (§10, Q9, Q13), set in every level's `.tres`.
const LEVEL_PARAMS: Array[String] = ["density_per_km_per_lane", "ai_speed_spread_kmh", "exam_pass_score"]


func _set_in(path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var eq: int = line.find(" = ")
		if eq > 0:
			found.append(line.substr(0, eq))
	return found


func test_every_requirements_param_is_written_in_its_tres() -> void:
	for path: String in PARAMS:
		var set_keys: PackedStringArray = _set_in(path)
		for param: String in PARAMS[path]:
			assert_bool(set_keys.has(param)) \
					.override_failure_message("%s (requirements %s) is not set in %s" % [param, PARAMS[path][param], path]) \
					.is_true()


func test_every_level_sets_its_own_params() -> void:
	for level_id: int in range(1, 5):
		var path: String = "res://config/difficulty_levels/level_%d.tres" % level_id
		var set_keys: PackedStringArray = _set_in(path)
		for param: String in LEVEL_PARAMS:
			assert_bool(set_keys.has(param)).override_failure_message("%s is not set in %s" % [param, path]).is_true()


## The table names real resource properties, so a renamed one cannot slip past.
func test_every_listed_param_is_a_resource_property() -> void:
	for path: String in PARAMS:
		var resource: Resource = load(path)
		for param: String in PARAMS[path]:
			assert_bool(param in resource).override_failure_message("%s has no %s" % [path, param]).is_true()
	var level: Resource = load("res://config/difficulty_levels/level_1.tres")
	for param: String in LEVEL_PARAMS:
		assert_bool(param in level).override_failure_message("DifficultyLevel has no %s" % param).is_true()
