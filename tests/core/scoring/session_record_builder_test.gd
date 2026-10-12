extends GdUnitTestSuite
## The session record is built from a recorded event log and the session state
## (requirements §13, spec Data Model and Phase 6 step 4; issue #30).

var _config: ScoringConfig


func before_test() -> void:
	_config = load("res://config/scoring.tres") as ScoringConfig


## A log with every kind of event the record reads, totals worked out by hand.
func _recorded_log() -> EventLog:
	var event_log: EventLog = EventLog.new()
	# K1: two stretches below the minimum gap, 2.5 s and 1.5 s; lowest ratio 0.6.
	event_log.open_segment(GapRule.KEY, 5.0, GapRule.TYPE, GapRule.CATEGORY, 0.8)
	event_log.extend_segment(GapRule.KEY, 7.5, -3.0)
	event_log.close_segment(GapRule.KEY)
	event_log.open_segment(GapRule.KEY, 20.0, GapRule.TYPE, GapRule.CATEGORY, 0.6)
	event_log.extend_segment(GapRule.KEY, 21.5, -4.0)
	event_log.close_segment(GapRule.KEY)
	# K2: 6 s in the left lane, 2 s past the grace.
	event_log.open_segment(KeepRightRule.KEY, 30.0, KeepRightRule.TYPE, KeepRightRule.CATEGORY, 0.0)
	event_log.extend_segment(KeepRightRule.KEY, 36.0, -4.0)
	event_log.close_segment(KeepRightRule.KEY)
	# Four lane changes: two signalled correctly, one late, one without a signal.
	event_log.add_instant(10.0, SignalRule.TYPE_OK, SignalRule.CATEGORY, 0.0)
	event_log.add_instant(14.0, SignalRule.TYPE_OK, SignalRule.CATEGORY, 0.0)
	event_log.add_instant(28.0, SignalRule.TYPE_LATE, SignalRule.CATEGORY, -5.0)
	event_log.add_instant(29.0, SignalRule.TYPE_NONE, SignalRule.CATEGORY, -10.0)
	# Rewards: one N1, N2 and N3 segments.
	event_log.add_instant(11.75, LaneChangeRule.TYPE, LaneChangeRule.CATEGORY, 10.0)
	event_log.open_segment(RightLaneRule.KEY, 40.0, RightLaneRule.TYPE, RightLaneRule.CATEGORY, 0.0)
	event_log.extend_segment(RightLaneRule.KEY, 90.0, 25.0)
	event_log.open_segment(GapKeptRule.KEY_FOLLOWING, 40.0, GapKeptRule.TYPE_FOLLOWING, GapKeptRule.CATEGORY, 1.2)
	event_log.extend_segment(GapKeptRule.KEY_FOLLOWING, 90.0, 25.0)
	# S1: 3 s of speeding.
	event_log.open_segment(SpeedRule.KEY, 50.0, SpeedRule.TYPE, SpeedRule.CATEGORY, 155.0)
	event_log.extend_segment(SpeedRule.KEY, 53.0, -6.0)
	event_log.close_all()
	return event_log


func _builder(mode: StringName = SessionRecord.MODE_EXAM) -> SessionRecordBuilder:
	var builder: SessionRecordBuilder = SessionRecordBuilder.new(_config)
	builder.id = "a1"
	builder.started_at = "2026-10-12T10:00:00Z"
	builder.app_version = "0.1.0"
	builder.mode = mode
	builder.road_profile = &"motorway"
	builder.difficulty = 2
	builder.seed_value = 42
	builder.duration_s = 90.0
	builder.exam_pass_score = 20.0
	return builder


func test_totals_categories_and_stats_match_the_recorded_log() -> void:
	var record: SessionRecord = _builder().build(_recorded_log())
	# gap: -3 - 4 + 25 = 18; lane: -4 + 10 + 25 = 31; signal: -15; speed: -6.
	assert_float(record.score_by_category[&"gap"]).is_equal_approx(18.0, 1e-6)
	assert_float(record.score_by_category[&"lane"]).is_equal_approx(31.0, 1e-6)
	assert_float(record.score_by_category[&"signal"]).is_equal_approx(-15.0, 1e-6)
	assert_float(record.score_by_category[&"speed"]).is_equal_approx(-6.0, 1e-6)
	assert_float(record.score_total).is_equal_approx(28.0, 1e-6)
	assert_int(record.lane_changes).is_equal(4)
	assert_int(record.lane_changes_signaled).is_equal(2)
	assert_float(record.time_left_lane_unjustified_s).is_equal_approx(6.0, 1e-6)
	assert_float(record.time_gap_below_min_s).is_equal_approx(4.0, 1e-6)
	assert_float(record.min_gap_ratio).is_equal_approx(0.6, 1e-6)
	assert_bool(record.exam_passed).is_true()


func test_session_state_is_carried_into_the_record() -> void:
	var record: SessionRecord = _builder().build(_recorded_log())
	assert_str(record.id).is_equal("a1")
	assert_str(String(record.mode)).is_equal("exam")
	assert_str(String(record.road_profile)).is_equal("motorway")
	assert_int(record.difficulty).is_equal(2)
	assert_int(record.seed_value).is_equal(42)
	assert_float(record.duration_s).is_equal(90.0)
	assert_str(String(record.status)).is_equal("completed")


func test_a_clean_empty_log_has_neutral_stats() -> void:
	var record: SessionRecord = _builder(SessionRecord.MODE_LEARN).build(EventLog.new())
	assert_float(record.score_total).is_equal(0.0)
	assert_int(record.lane_changes).is_equal(0)
	assert_float(record.time_gap_below_min_s).is_equal(0.0)
	assert_float(record.min_gap_ratio).is_equal(1.0)


func test_learn_sessions_have_no_exam_verdict() -> void:
	var record: SessionRecord = _builder(SessionRecord.MODE_LEARN).build(_recorded_log())
	assert_that(record.exam_passed).is_null()
	assert_that(record.to_dict()["exam_passed"]).is_null()


func test_an_exam_below_the_pass_mark_is_not_passed() -> void:
	var builder: SessionRecordBuilder = _builder()
	builder.exam_pass_score = 28.5
	assert_bool(builder.build(_recorded_log()).exam_passed).is_false()
	builder.exam_pass_score = 28.0
	assert_bool(builder.build(_recorded_log()).exam_passed).is_true()


func test_an_exam_with_a_collision_or_off_road_is_not_passed_regardless_of_score(
		type: StringName,
		status: StringName,
		test_parameters: Array = [
			[CollisionRule.TYPE_COLLISION, SessionRecord.STATUS_ABORTED_COLLISION],
			[CollisionRule.TYPE_OFFROAD, SessionRecord.STATUS_ABORTED_OFFROAD],
			# A K4 event fails the exam even if the session status says completed.
			[CollisionRule.TYPE_COLLISION, SessionRecord.STATUS_COMPLETED],
			[CollisionRule.TYPE_OFFROAD, SessionRecord.STATUS_COMPLETED],
		]) -> void:
	var event_log: EventLog = _recorded_log()
	# Far more points than the K4 penalty takes away.
	event_log.add_instant(60.0, LaneChangeRule.TYPE, LaneChangeRule.CATEGORY, 1000.0)
	event_log.add_instant(70.0, type, CollisionRule.CATEGORY, -_config.k4_penalty)
	var builder: SessionRecordBuilder = _builder()
	builder.status = status
	var record: SessionRecord = builder.build(event_log)
	assert_float(record.score_total).is_greater(builder.exam_pass_score)
	assert_bool(record.exam_passed).is_false()


func test_an_aborted_exam_is_not_passed_even_without_a_k4_event() -> void:
	var builder: SessionRecordBuilder = _builder()
	builder.status = SessionRecord.STATUS_ABORTED_OFFROAD
	assert_bool(builder.build(_recorded_log()).exam_passed).is_false()


func test_the_total_is_clamped_while_categories_stay_negative() -> void:
	var event_log: EventLog = EventLog.new()
	event_log.add_instant(1.0, SignalRule.TYPE_NONE, SignalRule.CATEGORY, -10.0)
	event_log.add_instant(2.0, LaneChangeRule.TYPE, LaneChangeRule.CATEGORY, 4.0)
	var record: SessionRecord = _builder().build(event_log)
	assert_float(record.score_total).is_equal(_config.score_floor)
	assert_float(record.score_by_category[&"signal"]).is_equal(-10.0)
	assert_float(record.score_by_category[&"gap"]).is_equal(0.0)


func test_building_leaves_the_log_unchanged() -> void:
	var event_log: EventLog = _recorded_log()
	var total: float = event_log.total()
	var count: int = event_log.events.size()
	_builder().build(event_log)
	assert_float(event_log.total()).is_equal(total)
	assert_int(event_log.events.size()).is_equal(count)


func test_to_dict_has_the_section_13_shape() -> void:
	var record: Dictionary = _builder().build(_recorded_log()).to_dict()
	assert_int(record["schema_version"]).is_equal(SessionRecord.SCHEMA_VERSION)
	assert_array(record.keys()).contains([
		"schema_version", "id", "started_at", "app_version", "mode", "road_profile",
		"difficulty", "seed", "duration_s", "status", "score_total", "score_by_category",
		"stats", "exam_passed"])
	assert_array((record["score_by_category"] as Dictionary).keys()).contains_exactly(["gap", "lane", "signal", "speed"])
	assert_array((record["stats"] as Dictionary).keys()).contains_exactly([
		"lane_changes", "lane_changes_signaled", "time_left_lane_unjustified_s",
		"time_gap_below_min_s", "min_gap_ratio"])
	assert_str(record["mode"]).is_equal("exam")
	# Survives a JSON round trip (history.json, E10).
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(record))
	assert_float(parsed["stats"]["min_gap_ratio"]).is_equal_approx(0.6, 1e-6)
	assert_bool(parsed["exam_passed"]).is_true()
