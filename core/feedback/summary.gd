class_name Summary
extends RefCounted
## What the end-of-session screen shows (requirements §11.3, spec UI/UX: Summary).
## Built by `SummaryGenerator`; every text is a `FeedbackLine` for the UI to translate.

enum Rating { GOOD, IMPROVE }


## One category row: its sub-score and whether it went well.
class CategoryResult:
	extends RefCounted
	## &"gap", &"lane", &"signal" or &"speed".
	var category: StringName
	## The category sub-score, unclamped (Q6).
	var points: float
	## Penalty points lost in the category, as a positive number.
	var penalty: float
	var rating: Rating


## Translation key of the status line: completed, aborted, exam passed or failed.
var status_key: StringName
## Translation key of the cause of an aborted session; empty otherwise.
var cause_key: StringName
## Exam verdict (Q9); null in learn mode.
var exam_passed: Variant = null
## Session total, already clamped at the floor.
var score_total: float
## One row per `SessionRecord.SCORED_CATEGORIES`, in that order.
var categories: Array[CategoryResult] = []
## The category that went best.
var strength: StringName
## One or two categories to work on, largest penalty first; may be empty.
var improvements: Array[StringName] = []
## The 2–4 sentence description.
var sentences: Array[FeedbackLine] = []
## One concrete habit for next time.
var tip: FeedbackLine
