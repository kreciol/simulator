class_name SummaryGenerator
extends RefCounted
## Turns a finished session's `EventLog` and `SessionRecord` into its `Summary`
## (requirements §11.3, spec Phase 8 step 2): rule and template based, no external
## service. Pure: reads the log and the record, never changes them, and picks
## translation keys rather than text, so every sentence is gender-neutral Polish from
## i18n/strings.csv (Q3).
##
## Selection by category penalty (the points a category lost), among the judged
## categories (speed only while S1 is on):
## - the strength is the category that lost least (ties: the higher sub-score, then
##   `SessionRecord.SCORED_CATEGORIES` order); when even it lost enough to be rated
##   "to improve", it is worded as the relatively best one;
## - the first area to improve is the other category that lost most, whenever any
##   lost points; a second one joins when it lost at least
##   `FeedbackConfig.improve_penalty_threshold` (§11.3: one or two areas).
## The description is the strength, then each area with its numbers, then why the
## session fell short — an abort cause or the points missing for an exam pass — or,
## when there is nothing of that, a sentence saying the rest went well: always
## `MIN_SENTENCES`–`MAX_SENTENCES`. The tip is the habit for the top area, else for
## the abort cause, else a next step that fits the mode.

## Requirements §11.3: one strength and one or two areas, in 2–4 sentences.
const MAX_IMPROVEMENTS: int = 2
const MIN_SENTENCES: int = 2
const MAX_SENTENCES: int = 4

const STATUS_COMPLETED: StringName = &"SUMMARY_STATUS_COMPLETED"
const STATUS_ABORTED: StringName = &"SUMMARY_STATUS_ABORTED"
const STATUS_EXAM_PASSED: StringName = &"SUMMARY_STATUS_EXAM_PASSED"
const STATUS_EXAM_FAILED: StringName = &"EXAM_FAILED"
const ALL_GOOD: StringName = &"SUMMARY_ALL_GOOD"
const EXAM_BELOW_PASS: StringName = &"SUMMARY_EXAM_BELOW_PASS"
const TIP_GENERAL: StringName = &"TIP_GENERAL"
const TIP_GENERAL_EXAM: StringName = &"TIP_GENERAL_EXAM"
const TIP_EXAM_POINTS: StringName = &"TIP_EXAM_POINTS"
## S1 is the only rule that can be switched off (Q4).
const SPEED: StringName = &"speed"

const CAUSES: Dictionary[StringName, StringName] = {
	SessionRecord.STATUS_ABORTED_COLLISION: &"END_CAUSE_COLLISION",
	SessionRecord.STATUS_ABORTED_OFFROAD: &"END_CAUSE_OFFROAD",
}
const ABORT_SENTENCES: Dictionary[StringName, StringName] = {
	SessionRecord.STATUS_ABORTED_COLLISION: &"SUMMARY_ABORTED_COLLISION",
	SessionRecord.STATUS_ABORTED_OFFROAD: &"SUMMARY_ABORTED_OFFROAD",
}
const ABORT_TIPS: Dictionary[StringName, StringName] = {
	SessionRecord.STATUS_ABORTED_COLLISION: &"TIP_COLLISION",
	SessionRecord.STATUS_ABORTED_OFFROAD: &"TIP_OFFROAD",
}
const CATEGORY_NAMES: Dictionary[StringName, StringName] = {
	&"gap": &"SUMMARY_CATEGORY_GAP",
	&"lane": &"SUMMARY_CATEGORY_LANE",
	&"signal": &"SUMMARY_CATEGORY_SIGNAL",
	&"speed": &"SUMMARY_CATEGORY_SPEED",
}
const STRENGTHS: Dictionary[StringName, StringName] = {
	&"gap": &"SUMMARY_STRENGTH_GAP",
	&"lane": &"SUMMARY_STRENGTH_LANE",
	&"signal": &"SUMMARY_STRENGTH_SIGNAL",
	&"speed": &"SUMMARY_STRENGTH_SPEED",
}
## The strength when it, too, needs work.
const RELATIVE_STRENGTHS: Dictionary[StringName, StringName] = {
	&"gap": &"SUMMARY_STRENGTH_RELATIVE_GAP",
	&"lane": &"SUMMARY_STRENGTH_RELATIVE_LANE",
	&"signal": &"SUMMARY_STRENGTH_RELATIVE_SIGNAL",
	&"speed": &"SUMMARY_STRENGTH_RELATIVE_SPEED",
}
const IMPROVEMENTS: Dictionary[StringName, StringName] = {
	&"gap": &"SUMMARY_IMPROVE_GAP",
	&"lane": &"SUMMARY_IMPROVE_LANE",
	&"signal": &"SUMMARY_IMPROVE_SIGNAL",
	&"speed": &"SUMMARY_IMPROVE_SPEED",
}
const TIPS: Dictionary[StringName, StringName] = {
	&"gap": &"TIP_GAP",
	&"lane": &"TIP_LANE",
	&"signal": &"TIP_SIGNAL",
	&"speed": &"TIP_SPEED",
}

var config: FeedbackConfig
## Whether speeding was judged this session (`ScoringConfig.speed_rule_enabled`).
var speed_judged: bool = true


## `scoring_config` tells whether S1 was on; without it speed counts as judged.
func _init(feedback_config: FeedbackConfig, scoring_config: ScoringConfig = null) -> void:
	config = feedback_config
	if scoring_config != null:
		speed_judged = scoring_config.speed_rule_enabled


## `exam_pass_score` is the level's `DifficultyLevel.exam_pass_score`; it is only read
## to say how many points an exam that completed but failed was short of.
func generate(event_log: EventLog, record: SessionRecord, exam_pass_score: float = 0.0) -> Summary:
	var summary: Summary = Summary.new()
	summary.score_total = record.score_total
	summary.exam_passed = record.exam_passed
	summary.cause_key = CAUSES.get(record.status, &"")
	summary.status_key = _status_key(record)

	for category: StringName in SessionRecord.SCORED_CATEGORIES:
		var result: Summary.CategoryResult = Summary.CategoryResult.new()
		result.category = category
		result.points = record.score_by_category.get(category, 0.0)
		result.penalty = penalty(event_log, category)
		if category == SPEED and not speed_judged:
			result.rating = Summary.Rating.NOT_JUDGED
		elif result.penalty >= config.improve_penalty_threshold:
			result.rating = Summary.Rating.IMPROVE
		else:
			result.rating = Summary.Rating.GOOD
		summary.categories.append(result)

	var strength: Summary.CategoryResult = _strength(summary.categories)
	summary.strength = strength.category
	summary.improvements = _improvements(summary.categories, strength)

	var strengths: Dictionary[StringName, StringName] = \
			RELATIVE_STRENGTHS if strength.rating == Summary.Rating.IMPROVE else STRENGTHS
	summary.sentences.append(FeedbackLine.create(strengths[strength.category]))
	for category: StringName in summary.improvements:
		summary.sentences.append(FeedbackLine.create(IMPROVEMENTS[category],
				_improvement_args(category, event_log, record)))
	var failed_on_points: bool = record.mode == SessionRecord.MODE_EXAM \
			and record.status == SessionRecord.STATUS_COMPLETED and record.exam_passed != true
	if failed_on_points:
		summary.sentences.append(FeedbackLine.create(EXAM_BELOW_PASS, {
			"missing": maxi(1, ceili(exam_pass_score - record.score_total)),
			"pass": roundi(exam_pass_score),
		}))
	var abort_sentence: StringName = ABORT_SENTENCES.get(record.status, &"")
	if abort_sentence != &"":
		summary.sentences.append(FeedbackLine.create(abort_sentence))
	if summary.sentences.size() < MIN_SENTENCES:
		summary.sentences.append(FeedbackLine.create(ALL_GOOD))

	if not summary.improvements.is_empty():
		summary.tip = FeedbackLine.create(TIPS[summary.improvements[0]])
	elif abort_sentence != &"":
		summary.tip = FeedbackLine.create(ABORT_TIPS[record.status])
	elif failed_on_points:
		summary.tip = FeedbackLine.create(TIP_EXAM_POINTS)
	else:
		summary.tip = FeedbackLine.create(
				TIP_GENERAL_EXAM if record.mode == SessionRecord.MODE_EXAM else TIP_GENERAL)
	return summary


## Points `category` lost in the session, as a positive number; rewards do not offset it.
static func penalty(event_log: EventLog, category: StringName) -> float:
	var lost: float = 0.0
	for event: ScoreEvent in event_log.events:
		if event.category == category and event.points < 0.0:
			lost -= event.points
	return lost


## Whole seconds for a sentence; a penalised stretch never reads as 0 s.
static func whole_seconds(seconds: float) -> int:
	return maxi(1, roundi(seconds))


func _status_key(record: SessionRecord) -> StringName:
	if record.mode == SessionRecord.MODE_EXAM:
		# Q9: the builder fails an exam with a collision or off-road whatever the score.
		return STATUS_EXAM_PASSED if record.exam_passed == true else STATUS_EXAM_FAILED
	return STATUS_COMPLETED if record.status == SessionRecord.STATUS_COMPLETED else STATUS_ABORTED


func _strength(categories: Array[Summary.CategoryResult]) -> Summary.CategoryResult:
	var best: Summary.CategoryResult = null
	for result: Summary.CategoryResult in categories:
		if result.rating == Summary.Rating.NOT_JUDGED:
			continue
		if best == null or result.penalty < best.penalty \
				or (is_equal_approx(result.penalty, best.penalty) and result.points > best.points):
			best = result
	return best


func _improvements(categories: Array[Summary.CategoryResult],
		strength: Summary.CategoryResult) -> Array[StringName]:
	var candidates: Array[Summary.CategoryResult] = []
	for result: Summary.CategoryResult in categories:
		if result != strength and result.rating != Summary.Rating.NOT_JUDGED and result.penalty > 0.0:
			candidates.append(result)
	# Stable for equal losses: `sort_custom` is not, so order by index on ties.
	candidates.sort_custom(func(a: Summary.CategoryResult, b: Summary.CategoryResult) -> bool:
		if not is_equal_approx(a.penalty, b.penalty):
			return a.penalty > b.penalty
		return categories.find(a) < categories.find(b))
	var picked: Array[StringName] = []
	for result: Summary.CategoryResult in candidates:
		# The top loss is always worth a sentence; a second only when it is a real one.
		if picked.size() == MAX_IMPROVEMENTS \
				or (not picked.is_empty() and result.rating != Summary.Rating.IMPROVE):
			break
		picked.append(result.category)
	return picked


func _improvement_args(category: StringName, event_log: EventLog, record: SessionRecord) -> Dictionary:
	match category:
		&"gap":
			return {"seconds": whole_seconds(record.time_gap_below_min_s)}
		&"lane":
			return {"seconds": whole_seconds(record.time_left_lane_unjustified_s)}
		&"signal":
			return {"missed": record.lane_changes - record.lane_changes_signaled,
					"total": record.lane_changes}
		&"speed":
			var speeding_s: float = 0.0
			for event: ScoreEvent in event_log.events_of_type(SpeedRule.TYPE):
				speeding_s += event.duration_s()
			return {"seconds": whole_seconds(speeding_s)}
	return {}
