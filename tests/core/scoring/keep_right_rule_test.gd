extends GdUnitTestSuite
## K2 — staying left while the right lane is free (requirements §8.2, §16 Ocenianie;
## issue #28).

var _config: ScoringConfig


func before_test() -> void:
	_config = load("res://config/scoring.tres") as ScoringConfig


func test_no_penalty_inside_the_grace_period() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(1, 120.0)
	world.drive(_config.k2_grace_s - 0.5)
	assert_float(world.total_of_type(KeepRightRule.TYPE)).is_equal(0.0)
	assert_bool(world.scoring.event_log.is_open(KeepRightRule.KEY)).is_true()
	assert_float(world.scoring.keep_right_rule.grace_remaining_s()).is_equal_approx(0.5, 1e-6)


func test_penalty_accrues_per_second_after_the_grace_period() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(1, 120.0)
	world.drive(_config.k2_grace_s + 2.0)
	assert_float(world.total_of_type(KeepRightRule.TYPE)).is_equal_approx(-2.0 * _config.k2_penalty_per_s, 1e-6)
	assert_float(world.scoring.keep_right_rule.grace_remaining_s()).is_less(0.0)


func test_the_segment_spans_the_grace_period_and_closes_on_return() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(1, 120.0)
	world.drive(_config.k2_grace_s + 1.0)
	var commands: PlayerCommands = PlayerCommands.new()
	commands.lane_change = VehicleState.Dir.RIGHT
	var completed: Array[ScoreEvent] = world.drive(3.0, commands)

	var segments: Array[ScoreEvent] = world.scoring.event_log.events_of_type(KeepRightRule.TYPE)
	assert_int(segments.size()).is_equal(1)
	assert_array(completed).contains([segments[0]])
	assert_float(segments[0].timestamp_s).is_equal_approx(0.0, 1e-9)
	# Penalty stops once the return starts; the segment covers grace + 1 s.
	assert_float(segments[0].duration_s()).is_equal_approx(_config.k2_grace_s + 1.0, 1e-6)
	assert_float(segments[0].extreme).is_equal_approx(_config.k2_grace_s + 1.0, 1e-6)
	assert_float(world.total_of_type(KeepRightRule.TYPE)).is_equal_approx(-_config.k2_penalty_per_s, 1e-6)
	assert_float(world.scoring.keep_right_rule.grace_remaining_s()).is_equal(INF)


func test_no_k2_on_the_rightmost_lane() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(0, 120.0)
	world.drive(_config.k2_grace_s + 2.0)
	assert_array(world.scoring.event_log.events_of_type(KeepRightRule.TYPE)).is_empty()


func test_no_k2_while_overtaking() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(1, 140.0)
	# A slightly slower car just ahead on the right: the player is passing it
	# throughout (closing 5 km/h).
	world.add_car_ahead(0, 5.0, 135.0)
	world.drive(_config.k2_grace_s + 2.0)
	assert_bool(LaneQuery.is_overtaking(world.player, world.sim.lanes, world.scoring.config.overtake_look_ahead_m)).is_true()
	assert_float(world.total_of_type(KeepRightRule.TYPE)).is_equal(0.0)


func test_no_k2_when_a_slower_car_ahead_on_the_right_would_soon_force_another_overtake() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(1, 140.0)
	# 100 m ahead and 40 km/h slower: returning would catch it within the horizon.
	world.add_car_ahead(0, 100.0, 100.0)
	world.drive(1.0)
	assert_bool(world.scoring.keep_right_rule.is_right_lane_free(world.player)).is_false()
	assert_array(world.scoring.event_log.events_of_type(KeepRightRule.TYPE)).is_empty()


func test_a_distant_slow_car_on_the_right_does_not_excuse_staying_left() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(1, 140.0)
	# 600 m ahead and 20 km/h slower: far beyond the return horizon.
	world.add_car_ahead(0, 600.0, 120.0)
	assert_bool(world.scoring.keep_right_rule.is_right_lane_free(world.player)).is_true()


func test_no_k2_when_a_car_is_beside_on_the_right() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(1, 120.0)
	# Same speed, alongside: not overtaking it, but the right lane is not free.
	world.sim.add_vehicle(world.player.s - 3.0, 0, world.player.speed_mps)
	world.drive(_config.k2_grace_s + 2.0)
	assert_float(world.total_of_type(KeepRightRule.TYPE)).is_equal(0.0)


## Issue #96: on three lanes K2 asks for one lane right whenever it is free, so the
## middle lane is "left" while the rightmost lane is free.
func test_k2_in_the_middle_lane_of_three_while_the_right_lane_is_free() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(1, 120.0, null, ScoringTestHelper.MOTORWAY_3LANE)
	world.drive(_config.k2_grace_s + 2.0)
	assert_float(world.total_of_type(KeepRightRule.TYPE)).is_equal_approx(-2.0 * _config.k2_penalty_per_s, 1e-6)
	assert_dict(world.scoring.event_log.events_of_type(KeepRightRule.TYPE)[0].context).contains_key_value("lane", 1)


func test_k2_in_the_leftmost_lane_of_three_while_the_middle_lane_is_free() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(2, 120.0, null, ScoringTestHelper.MOTORWAY_3LANE)
	# The rightmost lane is busy alongside; only the middle one counts.
	world.sim.add_vehicle(world.player.s, 0, world.player.speed_mps)
	world.drive(_config.k2_grace_s + 2.0)
	assert_float(world.total_of_type(KeepRightRule.TYPE)).is_equal_approx(-2.0 * _config.k2_penalty_per_s, 1e-6)


func test_no_k2_in_the_middle_lane_of_three_while_a_car_is_beside_on_the_right() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(1, 120.0, null, ScoringTestHelper.MOTORWAY_3LANE)
	world.sim.add_vehicle(world.player.s - 3.0, 0, world.player.speed_mps)
	world.drive(_config.k2_grace_s + 2.0)
	assert_array(world.scoring.event_log.events_of_type(KeepRightRule.TYPE)).is_empty()


func test_no_k2_overtaking_from_lane_2_a_car_on_lane_1() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(2, 140.0, null, ScoringTestHelper.MOTORWAY_3LANE)
	world.add_car_ahead(1, 5.0, 135.0)
	world.drive(_config.k2_grace_s + 2.0)
	assert_bool(LaneQuery.is_overtaking(world.player, world.sim.lanes, world.scoring.config.overtake_look_ahead_m)).is_true()
	assert_float(world.total_of_type(KeepRightRule.TYPE)).is_equal(0.0)
