extends GdUnitTestSuite
## Scoring weights come from data, not code (requirements §8, §14 Konfigurowalność;
## spec Data Model; issue #28).

const NUMERIC_FIELDS: Array[StringName] = [
	&"k1_base_per_s", &"k1_exponent", &"k2_grace_s", &"k2_penalty_per_s",
	&"k2_return_horizon_s", &"k2_min_look_ahead_m", &"k2_look_behind_m",
	&"k3_penalty", &"k3_late_factor", &"overtake_look_ahead_m",
	&"n1_reward", &"n1_cooldown_s", &"n1_overtake_reason_m", &"n1_slow_vehicle_margin_kmh",
	&"n1_clear_ahead_m", &"n1_clear_behind_m", &"n2_reward_per_s", &"n3_reward_per_s",
	&"n3_range_m", &"n3_empty_road_factor", &"speed_tolerance_kmh", &"s1_penalty_per_s",
	&"k4_penalty",
]


func test_every_weight_is_defined_in_scoring_tres() -> void:
	var config: ScoringConfig = load("res://config/scoring.tres") as ScoringConfig
	assert_object(config).is_not_null()
	for field: StringName in NUMERIC_FIELDS:
		assert_float(config.get(field) as float).override_failure_message("%s is not set" % field).is_greater(0.0)


func test_k1_curve_is_non_linear_and_late_signal_costs_half() -> void:
	var config: ScoringConfig = load("res://config/scoring.tres") as ScoringConfig
	assert_float(config.k1_exponent).is_equal(2.0)
	assert_float(config.k3_late_factor).is_equal(0.5)


func test_speeding_is_scored_and_the_total_floor_is_zero() -> void:
	var config: ScoringConfig = load("res://config/scoring.tres") as ScoringConfig
	assert_bool(config.speed_rule_enabled).is_true()
	assert_float(config.speed_tolerance_kmh).is_equal(10.0)
	assert_float(config.score_floor).is_equal(0.0)
	assert_float(config.n3_empty_road_factor).is_equal(0.5)
