extends GdUnitTestSuite
## K1 — following too closely (requirements §8.2, §16 Ocenianie; Q7; issue #28).


func _k1_after_one_second(gap_m: float, speed_kmh: float = 140.0) -> float:
	var world: ScoringTestHelper = ScoringTestHelper.new(0, speed_kmh)
	world.add_car_ahead(0, gap_m, speed_kmh)
	world.drive(1.0)
	return world.total_of_type(GapRule.TYPE)


func test_at_140_kmh_a_50_m_gap_is_penalised() -> void:
	assert_float(_k1_after_one_second(50.0)).is_less(0.0)


func test_at_140_kmh_a_75_m_gap_is_not_penalised() -> void:
	assert_float(_k1_after_one_second(75.0)).is_equal(0.0)


func test_a_20_m_gap_costs_more_than_50_m_at_the_same_speed() -> void:
	assert_float(_k1_after_one_second(20.0)).is_less(_k1_after_one_second(50.0))


func test_penalty_follows_the_non_linear_curve() -> void:
	var config: ScoringConfig = load("res://config/scoring.tres") as ScoringConfig
	var expected: float = -config.k1_base_per_s * pow(1.0 - 50.0 / 70.0, config.k1_exponent)
	assert_float(_k1_after_one_second(50.0)).is_equal_approx(expected, 1e-3)


func test_no_k1_while_overtaking() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(1, 140.0)
	world.add_car_ahead(1, 50.0, 140.0)
	# A slower car ahead on the right lane: the player is overtaking it.
	world.add_car_ahead(0, 10.0, 120.0)
	world.drive(1.0)
	assert_bool(LaneQuery.is_overtaking(world.player, world.sim.lanes, world.scoring.config.overtake_look_ahead_m)).is_true()
	assert_float(world.total_of_type(GapRule.TYPE)).is_equal(0.0)


func test_no_leader_means_no_k1() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(0, 140.0)
	world.add_car_ahead(1, 10.0, 140.0)
	world.drive(1.0)
	assert_array(world.scoring.event_log.events_of_type(GapRule.TYPE)).is_empty()


func test_one_segment_per_stretch_with_lowest_ratio_and_its_numbers() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(0, 140.0)
	var leader: VehicleState = world.add_car_ahead(0, 50.0, 140.0)
	world.drive(1.0)
	# The leader pulls away; the segment closes once the gap is legal again.
	leader.speed_mps = ScoringTestHelper.kmh(180.0)
	var completed: Array[ScoreEvent] = world.drive(3.0)

	var segments: Array[ScoreEvent] = world.scoring.event_log.events_of_type(GapRule.TYPE)
	assert_int(segments.size()).is_equal(1)
	var segment: ScoreEvent = segments[0]
	assert_array(completed).contains_exactly([segment])
	assert_bool(segment.is_segment).is_true()
	assert_float(segment.timestamp_s).is_equal_approx(0.0, 1e-9)
	assert_float(segment.duration_s()).is_between(1.0, 3.0)
	assert_float(segment.extreme).is_equal_approx(50.0 / 70.0, 1e-3)
	assert_float(segment.context["gap_m"] as float).is_equal_approx(50.0, 1e-3)
	assert_float(segment.context["min_gap_m"] as float).is_equal_approx(70.0, 1e-3)
	assert_float(segment.context["speed_kmh"] as float).is_equal_approx(140.0, 1e-3)
