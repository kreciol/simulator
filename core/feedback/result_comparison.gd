class_name ResultComparison
extends RefCounted
## Compares a finished session with the earlier results of its mode × road profile ×
## level (requirements §11.3, spec UI/UX: Summary): the previous session and the best
## one, both read from the history before this session is saved. Pure: takes the saved
## sessions as their §13 dictionaries and picks translation keys, never text.
##
## Points are rounded down, as the summary's total is, so the numbers agree with it.
## A new best follows the history's rule: only a completed session that beats the best
## so far (a tie keeps the earlier one).

const FIRST: StringName = &"COMPARE_FIRST"
const PREVIOUS_UP: StringName = &"COMPARE_PREVIOUS_UP"
const PREVIOUS_DOWN: StringName = &"COMPARE_PREVIOUS_DOWN"
const PREVIOUS_SAME: StringName = &"COMPARE_PREVIOUS_SAME"
const NEW_BEST: StringName = &"COMPARE_NEW_BEST"
const FIRST_BEST: StringName = &"COMPARE_FIRST_BEST"
const BEST: StringName = &"COMPARE_BEST"
const KEYS: Array[StringName] = [FIRST, PREVIOUS_UP, PREVIOUS_DOWN, PREVIOUS_SAME, NEW_BEST, FIRST_BEST, BEST]


## The comparison lines for `record`: how it went against the previous session of its
## combination (`previous`), then against the best (`best`); one line when the
## combination has no earlier session. Empty dictionaries mean "none".
static func compare(record: SessionRecord, previous: Dictionary, best: Dictionary) -> Array[FeedbackLine]:
	if previous.is_empty():
		return [FeedbackLine.create(FIRST)]
	var lines: Array[FeedbackLine] = []
	var points: int = floori(record.score_total)
	var previous_points: int = _points(previous)
	var change: int = points - previous_points
	if change > 0:
		lines.append(FeedbackLine.create(PREVIOUS_UP, {"points": previous_points, "change": change}))
	elif change < 0:
		lines.append(FeedbackLine.create(PREVIOUS_DOWN, {"points": previous_points, "change": -change}))
	else:
		lines.append(FeedbackLine.create(PREVIOUS_SAME, {"points": previous_points}))

	var completed: bool = record.status == SessionRecord.STATUS_COMPLETED
	if best.is_empty():
		if completed:
			lines.append(FeedbackLine.create(FIRST_BEST))
	elif completed and record.score_total > float(best.get("score_total", 0.0)):
		lines.append(FeedbackLine.create(NEW_BEST, {"points": _points(best)}))
	else:
		lines.append(FeedbackLine.create(BEST, {"points": _points(best)}))
	return lines


static func _points(entry: Dictionary) -> int:
	return floori(float(entry.get("score_total", 0.0)))
