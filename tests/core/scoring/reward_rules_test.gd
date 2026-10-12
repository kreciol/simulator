extends GdUnitTestSuite
## N2 keeping right and N3 keeping the legal gap (requirements §8.3, §16 Ocenianie; Q8;
## issue #29).

var _config: ScoringConfig


func before_test() -> void:
	_config = load("res://config/scoring.tres") as ScoringConfig


func test_right_lane_driving_with_a_legal_gap_raises_the_score_steadily() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(0, 120.0)
	world.add_car_ahead(0, 80.0, 120.0)
	var previous: float = 0.0
	for second: int in 10:
		world.drive(1.0)
		var total: float = world.scoring.event_log.total()
		assert_float(total).is_greater(previous)
		previous = total
	assert_float(world.total_of_type(RightLaneRule.TYPE)).is_equal_approx(10.0 * _config.n2_reward_per_s, 1e-6)
	assert_float(world.total_of_type(GapKeptRule.TYPE_FOLLOWING)).is_equal_approx(10.0 * _config.n3_reward_per_s, 1e-6)


func test_an_empty_road_reduces_n3_by_the_factor() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(0, 120.0)
	world.drive(4.0)
	assert_float(_config.n3_empty_road_factor).is_equal(0.5)
	assert_float(world.total_of_type(GapKeptRule.TYPE_EMPTY)).is_equal_approx(
			4.0 * _config.n3_reward_per_s * _config.n3_empty_road_factor, 1e-6)
	assert_float(world.total_of_type(GapKeptRule.TYPE_FOLLOWING)).is_equal(0.0)


func test_a_leader_beyond_range_counts_as_an_empty_road() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(0, 120.0)
	world.add_car_ahead(0, _config.n3_range_m + 50.0, 120.0)
	world.drive(1.0)
	assert_array(world.scoring.event_log.events_of_type(GapKeptRule.TYPE_EMPTY)).has_size(1)
	assert_array(world.scoring.event_log.events_of_type(GapKeptRule.TYPE_FOLLOWING)).is_empty()


func test_no_n3_below_the_legal_gap() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(0, 120.0)
	world.add_car_ahead(0, 40.0, 120.0)
	world.drive(2.0)
	assert_float(world.total_for(GapKeptRule.CATEGORY)).is_less(0.0)
	assert_float(world.total_of_type(GapKeptRule.TYPE_FOLLOWING)).is_equal(0.0)
	assert_float(world.total_of_type(GapKeptRule.TYPE_EMPTY)).is_equal(0.0)


func test_n3_segment_switches_type_when_a_leader_comes_into_range() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(0, 120.0)
	world.add_car_ahead(0, _config.n3_range_m + 30.0, 90.0)
	world.drive(8.0)
	var empty: Array[ScoreEvent] = world.scoring.event_log.events_of_type(GapKeptRule.TYPE_EMPTY)
	var following: Array[ScoreEvent] = world.scoring.event_log.events_of_type(GapKeptRule.TYPE_FOLLOWING)
	assert_array(empty).has_size(1)
	assert_array(following).has_size(1)
	assert_float(following[0].timestamp_s).is_equal_approx(empty[0].segment_end_s, 1e-6)
	assert_float(following[0].extreme).is_greater_equal(1.0)


func test_no_n2_off_the_rightmost_lane() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(1, 120.0)
	world.drive(2.0)
	assert_array(world.scoring.event_log.events_of_type(RightLaneRule.TYPE)).is_empty()


func test_no_n2_while_stuck_behind_a_slow_vehicle() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(0, 85.0)
	# A truck-speed car ahead: overtaking it is the right call, so keeping right behind
	# it earns no N2 (N3 still rewards the gap).
	world.add_car_ahead(0, 60.0, 85.0)
	world.drive(2.0)
	assert_array(world.scoring.event_log.events_of_type(RightLaneRule.TYPE)).is_empty()
	assert_float(world.total_of_type(GapKeptRule.TYPE_FOLLOWING)).is_greater(0.0)


func test_no_n2_during_a_lane_change() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(0, 120.0)
	var commands: PlayerCommands = PlayerCommands.new()
	commands.lane_change = VehicleState.Dir.LEFT
	world.drive(world.sim.config.lane_change_duration_s, commands)
	assert_array(world.scoring.event_log.events_of_type(RightLaneRule.TYPE)).is_empty()
