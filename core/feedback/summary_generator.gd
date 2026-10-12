class_name SummaryGenerator
extends RefCounted
## Turns a finished session's `EventLog` and `SessionRecord` into its `Summary`
## (requirements §11.3, spec Phase 8 step 2): rule and template based, no external
## service. Pure: reads the log and the record, never changes them, and picks
## translation keys rather than text, so every sentence is gender-neutral Polish from
## i18n/strings.csv (Q3).
##
## Selection by category penalty (the points a category lost):
## - the strength is the category that lost least (ties: the higher sub-score, then
##   `SessionRecord.SCORED_CATEGORIES` order);
## - areas to improve are the other categories that lost at least
##   `FeedbackConfig.improve_penalty_threshold`, largest loss first, at most
##   `MAX_IMPROVEMENTS`.
## The description is the strength, then each area with its numbers, then why an
## aborted session ended — or, when nothing needs work and nothing went wrong, a
## sentence saying so: always `MIN_SENTENCES`–`MAX_SENTENCES`. The tip is the habit
## for the top area, else for the abort cause, else a general next step.

## Requirements §11.3: one strength and one or two areas, in 2–4 sentences.
const MAX_IMPROVEMENTS: int = 2
const MIN_SENTENCES: int = 2
const MAX_SENTENCES: int = 4

const STATUS_COMPLETED: StringName = &"SUMMARY_STATUS_COMPLETED"
const STATUS_ABORTED: StringName = &"SUMMARY_STATUS_ABORTED"
const STATUS_EXAM_PASSED: StringName = &"SUMMARY_STATUS_EXAM_PASSED"
const STATUS_EXAM_FAILED: StringName = &"EXAM_FAILED"
const ALL_GOOD: StringName = &"SUMMARY_ALL_GOOD"
const TIP_GENERAL: StringName = &"TIP_GENERAL"

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


func _init(feedback_config: FeedbackConfig) -> void:
	config = feedback_config


func generate(event_log: EventLog, record: SessionRecord) -> Summary:
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
		result.rating = Summary.Rating.IMPROVE \
				if result.penalty >= config.improve_penalty_threshold else Summary.Rating.GOOD
		summary.categories.append(result)

	summary.strength = _strength(summary.categories)
	summary.improvements = _improvements(summary.categories, summary.strength)

	summary.sentences.append(FeedbackLine.create(STRENGTHS[summary.strength]))
	for category: StringName in summary.improvements:
		summary.sentences.append(FeedbackLine.create(IMPROVEMENTS[category],
				_improvement_args(category, event_log, record)))
	var abort_sentence: StringName = ABORT_SENTENCES.get(record.status, &"")
	if abort_sentence != &"":
		summary.sentences.append(FeedbackLine.create(abort_sentence))
	if summary.sentences.size() < MIN_SENTENCES:
		summary.sentences.append(FeedbackLine.create(ALL_GOOD))

	if not summary.improvements.is_empty():
		summary.tip = FeedbackLine.create(TIPS[summary.improvements[0]])
	else:
		summary.tip = FeedbackLine.create(ABORT_TIPS.get(record.status, TIP_GENERAL))
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


func _strength(categories: Array[Summary.CategoryResult]) -> StringName:
	var best: Summary.CategoryResult = categories[0]
	for result: Summary.CategoryResult in categories:
		if result.penalty < best.penalty \
				or (is_equal_approx(result.penalty, best.penalty) and result.points > best.points):
			best = result
	return best.category


func _improvements(categories: Array[Summary.CategoryResult], strength: StringName) -> Array[StringName]:
	var candidates: Array[Summary.CategoryResult] = []
	for result: Summary.CategoryResult in categories:
		if result.category != strength and result.rating == Summary.Rating.IMPROVE:
			candidates.append(result)
	# Stable for equal losses: `sort_custom` is not, so order by index on ties.
	candidates.sort_custom(func(a: Summary.CategoryResult, b: Summary.CategoryResult) -> bool:
		if not is_equal_approx(a.penalty, b.penalty):
			return a.penalty > b.penalty
		return categories.find(a) < categories.find(b))
	var picked: Array[StringName] = []
	for result: Summary.CategoryResult in candidates.slice(0, MAX_IMPROVEMENTS):
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
