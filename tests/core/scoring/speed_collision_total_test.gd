extends GdUnitTestSuite
## S1 speeding (Q4), the K4 collision hook and the clamped total (Q6) — issue #29.

var _config: ScoringConfig


func before_test() -> void:
	_config = load("res://config/scoring.tres") as ScoringConfig


func test_s1_accrues_above_the_limit_plus_tolerance() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(0, 155.0)
	world.drive(2.0)
	assert_float(world.scoring.category_score(SpeedRule.CATEGORY)).is_equal_approx(-2.0 * _config.s1_penalty_per_s, 1e-6)
	var segments: Array[ScoreEvent] = world.scoring.event_log.events_of_type(SpeedRule.TYPE)
	assert_array(segments).has_size(1)
	assert_float(segments[0].extreme).is_equal_approx(155.0, 1e-3)
	assert_float(segments[0].context["limit_kmh"] as float).is_equal(140.0)


func test_no_s1_within_the_tolerance() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(0, 140.0 + _config.speed_tolerance_kmh - 1.0)
	world.drive(2.0)
	assert_array(world.scoring.event_log.events_of_type(SpeedRule.TYPE)).is_empty()


func test_no_s1_when_the_rule_is_disabled() -> void:
	var config: ScoringConfig = ScoringTestHelper.scoring_config_copy()
	config.speed_rule_enabled = false
	var world: ScoringTestHelper = ScoringTestHelper.new(0, 170.0, config)
	world.drive(2.0)
	assert_float(world.scoring.category_score(SpeedRule.CATEGORY)).is_equal(0.0)
	assert_array(world.scoring.event_log.events_of_type(SpeedRule.TYPE)).is_empty()


func test_a_collision_logs_k4_once_in_category_collision() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(0, 120.0)
	world.add_car_ahead(0, 5.0, 60.0)
	var completed: Array[ScoreEvent] = world.drive(2.0)
	var events: Array[ScoreEvent] = world.scoring.event_log.events_of_type(CollisionRule.TYPE_COLLISION)
	assert_array(events).has_size(1)
	assert_str(events[0].category).is_equal(CollisionRule.CATEGORY)
	assert_float(events[0].points).is_equal(-_config.k4_penalty)
	assert_array(completed).contains([events[0]])


func test_other_vehicles_colliding_is_not_charged_to_the_player() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(0, 120.0)
	world.add_car_ahead(1, 300.0, 60.0)
	world.add_car_ahead(1, 280.0, 120.0)
	world.drive(3.0)
	assert_array(world.scoring.event_log.events_of_type(CollisionRule.TYPE_COLLISION)).is_empty()


func test_leaving_the_road_logs_k4() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(0, 120.0)
	var commands: PlayerCommands = PlayerCommands.new()
	commands.lane_change = VehicleState.Dir.RIGHT
	world.drive(3.0, commands)
	assert_bool(world.player.off_road).is_true()
	var events: Array[ScoreEvent] = world.scoring.event_log.events_of_type(CollisionRule.TYPE_OFFROAD)
	assert_array(events).has_size(1)
	assert_float(events[0].points).is_equal(-_config.k4_penalty)


func test_the_total_never_goes_below_zero_but_categories_may() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(0, 120.0)
	world.add_car_ahead(0, 5.0, 60.0)
	world.drive(2.0)
	assert_float(world.scoring.event_log.total()).is_less(0.0)
	assert_float(world.scoring.total_score()).is_equal(0.0)
	assert_float(world.scoring.category_score(CollisionRule.CATEGORY)).is_equal(-_config.k4_penalty)


func test_a_positive_total_is_not_clamped() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(0, 120.0)
	world.drive(5.0)
	assert_float(world.scoring.total_score()).is_greater(0.0)
	assert_float(world.scoring.total_score()).is_equal(world.scoring.event_log.total())
