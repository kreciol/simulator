extends GdUnitTestSuite
## Session event log with continuous segments (requirements §8.6; spec Phase 6 step 1;
## issue #28).

var _log: EventLog


func before_test() -> void:
	_log = EventLog.new()


func test_segment_opens_extends_and_closes_with_sum_and_extreme() -> void:
	var opened: ScoreEvent = _log.open_segment(&"k1", 2.0, &"gap_too_small", &"gap", 0.8)
	assert_bool(_log.is_open(&"k1")).is_true()
	_log.extend_segment(&"k1", 2.5, -1.0)
	opened.extreme = minf(opened.extreme, 0.4)
	_log.extend_segment(&"k1", 3.0, -2.5)

	var closed: ScoreEvent = _log.close_segment(&"k1")
	assert_object(closed).is_same(opened)
	assert_bool(_log.is_open(&"k1")).is_false()
	assert_bool(closed.is_segment).is_true()
	assert_float(closed.timestamp_s).is_equal(2.0)
	assert_float(closed.segment_end_s).is_equal(3.0)
	assert_float(closed.duration_s()).is_equal(1.0)
	assert_float(closed.points).is_equal(-3.5)
	assert_float(closed.extreme).is_equal(0.4)
	assert_int(_log.events.size()).is_equal(1)


func test_opening_an_open_segment_keeps_the_first_one() -> void:
	var first: ScoreEvent = _log.open_segment(&"k2", 1.0, &"left_lane_unjustified", &"lane", 0.0)
	var again: ScoreEvent = _log.open_segment(&"k2", 5.0, &"left_lane_unjustified", &"lane", 0.0)
	assert_object(again).is_same(first)
	assert_float(again.timestamp_s).is_equal(1.0)
	assert_int(_log.events.size()).is_equal(1)


func test_a_closed_key_starts_a_new_segment() -> void:
	_log.open_segment(&"k1", 1.0, &"gap_too_small", &"gap", 0.5)
	_log.close_segment(&"k1")
	_log.open_segment(&"k1", 4.0, &"gap_too_small", &"gap", 0.9)
	assert_int(_log.events_of_type(&"gap_too_small").size()).is_equal(2)


func test_extending_or_closing_without_an_open_segment_does_nothing() -> void:
	_log.extend_segment(&"k1", 1.0, -5.0)
	assert_object(_log.close_segment(&"k1")).is_null()
	assert_array(_log.events).is_empty()


func test_instant_events_have_no_duration() -> void:
	var event: ScoreEvent = _log.add_instant(7.0, &"no_signal", &"signal", -10.0, {"lane_from": 0})
	assert_bool(event.is_segment).is_false()
	assert_float(event.duration_s()).is_equal(0.0)
	assert_int(event.context["lane_from"] as int).is_equal(0)


func test_totals_by_category_include_open_segments() -> void:
	_log.add_instant(1.0, &"no_signal", &"signal", -10.0)
	_log.add_instant(2.0, &"late_signal", &"signal", -5.0)
	_log.open_segment(&"k1", 3.0, &"gap_too_small", &"gap", 0.5)
	_log.extend_segment(&"k1", 4.0, -2.0)
	assert_float(_log.total_for(&"signal")).is_equal(-15.0)
	assert_float(_log.total_for(&"gap")).is_equal(-2.0)
	assert_float(_log.total_for(&"lane")).is_equal(0.0)
	assert_float(_log.total()).is_equal(-17.0)


func test_close_all_closes_every_open_segment() -> void:
	_log.open_segment(&"k1", 1.0, &"gap_too_small", &"gap", 0.5)
	_log.open_segment(&"k2", 1.0, &"left_lane_unjustified", &"lane", 0.0)
	assert_int(_log.close_all().size()).is_equal(2)
	assert_bool(_log.is_open(&"k1")).is_false()
	assert_bool(_log.is_open(&"k2")).is_false()
