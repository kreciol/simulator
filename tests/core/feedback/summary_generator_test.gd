extends GdUnitTestSuite
## The session summary is generated from the event log and the record: status, four
## categories, one strength, one or two areas to improve in 2–4 sentences and one tip
## (requirements §11.3, spec Phase 8 step 2; issue #38).

var _scoring: ScoringConfig
var _feedback: FeedbackConfig
var _generator: SummaryGenerator


func before_test() -> void:
	_scoring = load("res://config/scoring.tres") as ScoringConfig
	_feedback = load("res://config/feedback.tres") as FeedbackConfig
	_generator = SummaryGenerator.new(_feedback)


## Penalties for a log, by category: K1 `gap` seconds at -2/s, K2 `lane` seconds past
## a 4 s grace at -2/s, `late` late signals and `unsignalled` changes without a signal
## (plus two good ones), S1 `speed` seconds at -2/s; and steady N2 / N3 rewards.
func _log(gap_s: float = 0.0, lane_s: float = 0.0, late: int = 0, unsignalled: int = 0,
		speed_s: float = 0.0, collision: bool = false) -> EventLog:
	var event_log: EventLog = EventLog.new()
	event_log.open_segment(RightLaneRule.KEY, 0.0, RightLaneRule.TYPE, RightLaneRule.CATEGORY, 0.0)
	event_log.extend_segment(RightLaneRule.KEY, 60.0, 30.0)
	event_log.open_segment(GapKeptRule.KEY_FOLLOWING, 0.0, GapKeptRule.TYPE_FOLLOWING, GapKeptRule.CATEGORY, 1.2)
	event_log.extend_segment(GapKeptRule.KEY_FOLLOWING, 60.0, 30.0)
	if gap_s > 0.0:
		event_log.open_segment(GapRule.KEY, 10.0, GapRule.TYPE, GapRule.CATEGORY, 0.5)
		event_log.extend_segment(GapRule.KEY, 10.0 + gap_s, -2.0 * gap_s)
	if lane_s > 0.0:
		event_log.open_segment(KeepRightRule.KEY, 20.0, KeepRightRule.TYPE, KeepRightRule.CATEGORY, 0.0)
		event_log.extend_segment(KeepRightRule.KEY, 24.0 + lane_s, -2.0 * lane_s)
	event_log.add_instant(30.0, SignalRule.TYPE_OK, SignalRule.CATEGORY, 0.0)
	event_log.add_instant(31.0, SignalRule.TYPE_OK, SignalRule.CATEGORY, 0.0)
	for i: int in late:
		event_log.add_instant(32.0 + i, SignalRule.TYPE_LATE, SignalRule.CATEGORY, -5.0)
	for i: int in unsignalled:
		event_log.add_instant(40.0 + i, SignalRule.TYPE_NONE, SignalRule.CATEGORY, -10.0)
	if speed_s > 0.0:
		event_log.open_segment(SpeedRule.KEY, 50.0, SpeedRule.TYPE, SpeedRule.CATEGORY, 0.0)
		event_log.extend_segment(SpeedRule.KEY, 50.0 + speed_s, -2.0 * speed_s)
	if collision:
		event_log.add_instant(59.0, CollisionRule.TYPE_COLLISION, CollisionRule.CATEGORY, -50.0)
	event_log.close_all()
	return event_log


func _record(event_log: EventLog, mode: StringName = SessionRecord.MODE_LEARN,
		status: StringName = SessionRecord.STATUS_COMPLETED, exam_pass_score: float = 20.0) -> SessionRecord:
	var builder: SessionRecordBuilder = SessionRecordBuilder.new(_scoring)
	builder.mode = mode
	builder.road_profile = &"motorway"
	builder.difficulty = 2
	builder.duration_s = 60.0
	builder.status = status
	builder.exam_pass_score = exam_pass_score
	return builder.build(event_log)


func _generate(event_log: EventLog, mode: StringName = SessionRecord.MODE_LEARN,
		status: StringName = SessionRecord.STATUS_COMPLETED, exam_pass_score: float = 20.0) -> Summary:
	return _generator.generate(event_log, _record(event_log, mode, status, exam_pass_score))


func _keys(lines: Array[FeedbackLine]) -> Array[StringName]:
	var keys: Array[StringName] = []
	for line: FeedbackLine in lines:
		keys.append(line.key)
	return keys


# Status

func test_status_of_each_ending(mode: StringName, status: StringName, collision: bool,
		status_key: StringName, cause_key: StringName, test_parameters: Array = [
		[SessionRecord.MODE_LEARN, SessionRecord.STATUS_COMPLETED, false, &"SUMMARY_STATUS_COMPLETED", &""],
		[SessionRecord.MODE_LEARN, SessionRecord.STATUS_ABORTED_COLLISION, true, &"SUMMARY_STATUS_ABORTED", &"END_CAUSE_COLLISION"],
		[SessionRecord.MODE_LEARN, SessionRecord.STATUS_ABORTED_OFFROAD, false, &"SUMMARY_STATUS_ABORTED", &"END_CAUSE_OFFROAD"],
		[SessionRecord.MODE_EXAM, SessionRecord.STATUS_COMPLETED, false, &"SUMMARY_STATUS_EXAM_PASSED", &""],
		[SessionRecord.MODE_EXAM, SessionRecord.STATUS_ABORTED_COLLISION, true, &"EXAM_FAILED", &"END_CAUSE_COLLISION"],
		[SessionRecord.MODE_EXAM, SessionRecord.STATUS_ABORTED_OFFROAD, false, &"EXAM_FAILED", &"END_CAUSE_OFFROAD"],
		]) -> void:
	var summary: Summary = _generate(_log(0.0, 0.0, 0, 0, 0.0, collision), mode, status)
	assert_str(summary.status_key).is_equal(status_key)
	assert_str(summary.cause_key).is_equal(cause_key)


func test_exam_below_the_pass_score_fails_without_a_cause() -> void:
	var event_log: EventLog = _log()
	var summary: Summary = _generator.generate(event_log,
			_record(event_log, SessionRecord.MODE_EXAM, SessionRecord.STATUS_COMPLETED, 1000.0), 1000.0)
	assert_str(summary.status_key).is_equal(&"EXAM_FAILED")
	assert_str(summary.cause_key).is_empty()
	assert_bool(summary.exam_passed).is_false()


func test_exam_failed_on_points_says_how_many_were_missing_not_that_all_went_well() -> void:
	# 60 points against a 100.4 pass mark, nothing lost anywhere.
	var event_log: EventLog = _log()
	var summary: Summary = _generator.generate(event_log,
			_record(event_log, SessionRecord.MODE_EXAM, SessionRecord.STATUS_COMPLETED, 100.4), 100.4)
	assert_array(_keys(summary.sentences)).is_equal([&"SUMMARY_STRENGTH_GAP", &"SUMMARY_EXAM_BELOW_PASS"])
	assert_dict(summary.sentences[1].args).is_equal({"missing": 41, "pass": 100})
	assert_str(summary.tip.key).is_equal(&"TIP_EXAM_POINTS")


func test_exam_failed_on_points_still_names_the_top_loss() -> void:
	var event_log: EventLog = _log(6.0)
	var summary: Summary = _generator.generate(event_log,
			_record(event_log, SessionRecord.MODE_EXAM, SessionRecord.STATUS_COMPLETED, 1000.0), 1000.0)
	assert_array(_keys(summary.sentences)).is_equal(
			[&"SUMMARY_STRENGTH_LANE", &"SUMMARY_IMPROVE_GAP", &"SUMMARY_EXAM_BELOW_PASS"])
	assert_str(summary.tip.key).is_equal(&"TIP_GAP")


func test_a_clean_exam_pass_suggests_no_exam_mode() -> void:
	var summary: Summary = _generate(_log(), SessionRecord.MODE_EXAM)
	assert_str(summary.status_key).is_equal(&"SUMMARY_STATUS_EXAM_PASSED")
	assert_array(_keys(summary.sentences)).is_equal([&"SUMMARY_STRENGTH_GAP", &"SUMMARY_ALL_GOOD"])
	assert_str(summary.tip.key).is_equal(&"TIP_GENERAL_EXAM")


func test_exam_above_the_pass_score_with_a_collision_fails() -> void:
	# 60 points of rewards minus the 50-point K4: 10 is above a 5-point pass mark.
	var event_log: EventLog = _log(0.0, 0.0, 0, 0, 0.0, true)
	var record: SessionRecord = _record(event_log, SessionRecord.MODE_EXAM, SessionRecord.STATUS_COMPLETED, 5.0)
	assert_float(record.score_total).is_greater(5.0)
	var summary: Summary = _generator.generate(event_log, record)
	assert_str(summary.status_key).is_equal(&"EXAM_FAILED")
	assert_bool(summary.exam_passed).is_false()


func test_learn_mode_has_no_exam_verdict() -> void:
	assert_object(_generate(_log()).exam_passed).is_null()


# Categories

func test_total_and_four_categories_in_order() -> void:
	var summary: Summary = _generate(_log(3.0, 0.0, 0, 1))
	assert_float(summary.score_total).is_equal_approx(60.0 - 6.0 - 10.0, 1e-6)
	var categories: Array[StringName] = []
	for result: Summary.CategoryResult in summary.categories:
		categories.append(result.category)
	assert_array(categories).is_equal([&"gap", &"lane", &"signal", &"speed"])
	# gap: 30 reward, 6 penalty; signal: one unsignalled change.
	assert_float(summary.categories[0].points).is_equal_approx(24.0, 1e-6)
	assert_float(summary.categories[0].penalty).is_equal_approx(6.0, 1e-6)
	assert_float(summary.categories[2].points).is_equal_approx(-10.0, 1e-6)


func test_rating_flags_categories_from_the_threshold() -> void:
	# gap loses 2 (below the threshold), signal 5 (a late signal, above it).
	var summary: Summary = _generate(_log(1.0, 0.0, 1))
	var ratings: Array = summary.categories.map(func(r: Summary.CategoryResult) -> Summary.Rating: return r.rating)
	assert_array(ratings).is_equal([Summary.Rating.GOOD, Summary.Rating.GOOD, Summary.Rating.IMPROVE, Summary.Rating.GOOD])


# Strength and areas to improve

func test_strength_and_improvements_follow_the_category_penalties() -> void:
	# Penalties: gap 12, lane 6, signal 10, speed 0.
	var summary: Summary = _generate(_log(6.0, 3.0, 0, 1))
	assert_str(summary.strength).is_equal(&"speed")
	assert_array(summary.improvements).is_equal([&"gap", &"signal"])


func test_at_most_two_areas_to_improve() -> void:
	# Penalties: gap 20, lane 8, signal 15, speed 6; the least-penalised is the strength.
	var summary: Summary = _generate(_log(10.0, 4.0, 1, 1, 3.0))
	assert_str(summary.strength).is_equal(&"speed")
	assert_array(summary.improvements).is_equal([&"gap", &"signal"])


func test_strength_tie_goes_to_the_higher_score() -> void:
	# Nothing lost anywhere: gap and lane both earned 30, gap comes first.
	var summary: Summary = _generate(_log())
	assert_str(summary.strength).is_equal(&"gap")
	assert_array(summary.improvements).is_empty()


func test_the_top_loss_is_named_even_below_the_threshold() -> void:
	# gap loses 2, under the 4-point threshold: still one area (§11.3: one or two).
	var summary: Summary = _generate(_log(1.0))
	assert_array(summary.improvements).is_equal([&"gap"])
	assert_int(summary.categories[0].rating).is_equal(Summary.Rating.GOOD)


func test_a_second_area_needs_the_threshold() -> void:
	# gap loses 2 and speed 2, both small: only the first is named.
	assert_array(_generate(_log(1.0, 0.0, 0, 0, 1.0)).improvements).is_equal([&"gap"])
	# gap 2, signal 5: the larger one first; the small one stays out.
	assert_array(_generate(_log(1.0, 0.0, 1)).improvements).is_equal([&"signal"])


func test_strength_needing_work_is_worded_as_the_relatively_best() -> void:
	# Every category loses at least 4: gap 6, lane 6, signal 5, speed 6.
	var summary: Summary = _generate(_log(3.0, 3.0, 1, 0, 3.0))
	assert_str(summary.strength).is_equal(&"signal")
	assert_str(summary.sentences[0].key).is_equal(&"SUMMARY_STRENGTH_RELATIVE_SIGNAL")


func test_speed_is_not_judged_when_the_speed_rule_is_off() -> void:
	var scoring: ScoringConfig = (load("res://config/scoring.tres") as ScoringConfig).duplicate() as ScoringConfig
	scoring.speed_rule_enabled = false
	var generator: SummaryGenerator = SummaryGenerator.new(_feedback, scoring)
	# gap 2, lane 2, signal 5; speed lost nothing because nothing checked it.
	var event_log: EventLog = _log(1.0, 1.0, 1)
	var summary: Summary = generator.generate(event_log, _record(event_log))
	assert_int(summary.categories[3].rating).is_equal(Summary.Rating.NOT_JUDGED)
	assert_str(summary.strength).is_equal(&"gap")
	assert_array(summary.improvements).is_equal([&"signal"])
	assert_array(_keys(summary.sentences)).not_contains([&"SUMMARY_STRENGTH_SPEED"])


# Description

func test_description_has_two_to_four_sentences(gap_s: float, lane_s: float, late: int,
		unsignalled: int, speed_s: float, status: StringName, expected: int, test_parameters: Array = [
		[0.0, 0.0, 0, 0, 0.0, SessionRecord.STATUS_COMPLETED, 2],
		[0.0, 0.0, 0, 0, 0.0, SessionRecord.STATUS_ABORTED_COLLISION, 2],
		[6.0, 0.0, 0, 0, 0.0, SessionRecord.STATUS_COMPLETED, 2],
		[1.0, 0.0, 0, 0, 0.0, SessionRecord.STATUS_ABORTED_COLLISION, 3],
		[6.0, 3.0, 0, 1, 0.0, SessionRecord.STATUS_COMPLETED, 3],
		[10.0, 4.0, 1, 1, 3.0, SessionRecord.STATUS_COMPLETED, 3],
		[10.0, 4.0, 1, 1, 3.0, SessionRecord.STATUS_ABORTED_OFFROAD, 4],
		]) -> void:
	var summary: Summary = _generate(_log(gap_s, lane_s, late, unsignalled, speed_s), SessionRecord.MODE_LEARN, status)
	assert_int(summary.sentences.size()).is_equal(expected)
	assert_int(summary.sentences.size()).is_between(SummaryGenerator.MIN_SENTENCES, SummaryGenerator.MAX_SENTENCES)


func test_description_opens_with_the_strength_then_the_areas() -> void:
	var summary: Summary = _generate(_log(6.0, 3.0, 0, 1))
	assert_array(_keys(summary.sentences)).is_equal(
			[&"SUMMARY_STRENGTH_SPEED", &"SUMMARY_IMPROVE_GAP", &"SUMMARY_IMPROVE_SIGNAL"])


func test_clean_drive_says_the_rules_were_kept() -> void:
	assert_array(_keys(_generate(_log()).sentences)).is_equal([&"SUMMARY_STRENGTH_GAP", &"SUMMARY_ALL_GOOD"])


func test_aborted_drive_explains_how_it_ended() -> void:
	var summary: Summary = _generate(_log(0.0, 0.0, 0, 0, 0.0, true), SessionRecord.MODE_LEARN,
			SessionRecord.STATUS_ABORTED_COLLISION)
	assert_array(_keys(summary.sentences)).is_equal([&"SUMMARY_STRENGTH_GAP", &"SUMMARY_ABORTED_COLLISION"])


func test_area_sentences_carry_the_numbers() -> void:
	# 6 s below the gap, 4 s grace + 3 s penalised on the left, 2 of 4 changes late or
	# unsignalled, 2.6 s speeding.
	var summary: Summary = _generate(_log(6.0, 3.0, 1, 1, 2.6))
	var args: Dictionary = {}
	for line: FeedbackLine in summary.sentences:
		args[line.key] = line.args
	assert_dict(args[&"SUMMARY_IMPROVE_GAP"]).is_equal({"seconds": 6})
	assert_dict(args[&"SUMMARY_IMPROVE_SIGNAL"]).is_equal({"missed": 2, "total": 4})
	var lane_summary: Summary = _generate(_log(0.0, 3.0, 0, 0, 2.6))
	var lane_args: Dictionary = {}
	for line: FeedbackLine in lane_summary.sentences:
		lane_args[line.key] = line.args
	assert_dict(lane_args[&"SUMMARY_IMPROVE_LANE"]).is_equal({"seconds": 7})
	assert_dict(lane_args[&"SUMMARY_IMPROVE_SPEED"]).is_equal({"seconds": 3})


# Tip

func test_tip_targets_the_top_area_then_the_cause_then_a_next_step(gap_s: float, unsignalled: int,
		status: StringName, tip: StringName, test_parameters: Array = [
		[6.0, 1, SessionRecord.STATUS_COMPLETED, &"TIP_GAP"],
		[0.0, 1, SessionRecord.STATUS_ABORTED_COLLISION, &"TIP_SIGNAL"],
		[0.0, 0, SessionRecord.STATUS_ABORTED_COLLISION, &"TIP_COLLISION"],
		[0.0, 0, SessionRecord.STATUS_ABORTED_OFFROAD, &"TIP_OFFROAD"],
		[0.0, 0, SessionRecord.STATUS_COMPLETED, &"TIP_GENERAL"],
		]) -> void:
	var summary: Summary = _generate(_log(gap_s, 0.0, 0, unsignalled), SessionRecord.MODE_LEARN, status)
	assert_str(summary.tip.key).is_equal(tip)


# Purity

func test_generating_leaves_the_log_and_record_unchanged() -> void:
	var event_log: EventLog = _log(6.0, 3.0, 0, 1)
	var record: SessionRecord = _record(event_log)
	var before_record: Dictionary = record.to_dict()
	var before_events: int = event_log.events.size()
	var before_total: float = event_log.total()
	_generator.generate(event_log, record)
	assert_dict(record.to_dict()).is_equal(before_record)
	assert_int(event_log.events.size()).is_equal(before_events)
	assert_float(event_log.total()).is_equal(before_total)
