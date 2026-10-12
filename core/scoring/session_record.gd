class_name SessionRecord
extends RefCounted
## The record of one finished session (requirements §13, spec Data Model: Persisted):
## the §13 fields plus `seed`, `exam_passed`, `score_by_category.speed` and
## `app_version`. Built by `SessionRecordBuilder`; saved by `SaveManager` (E10).

const SCHEMA_VERSION: int = 1

## The same values as `LaunchOptions.MODES`; core does not depend on the game layer.
const MODE_LEARN: StringName = &"learn"
const MODE_EXAM: StringName = &"exam"

const STATUS_COMPLETED: StringName = &"completed"
const STATUS_ABORTED_COLLISION: StringName = &"aborted_collision"
const STATUS_ABORTED_OFFROAD: StringName = &"aborted_offroad"

## Categories shown as score bars; K4 (&"collision") shows in `status` instead.
const SCORED_CATEGORIES: Array[StringName] = [&"gap", &"lane", &"signal", &"speed"]

var id: String = ""
## ISO-8601.
var started_at: String = ""
var app_version: String = ""
## &"learn" or &"exam".
var mode: StringName
## `RoadProfile.id`.
var road_profile: StringName
## `DifficultyLevel.id`, 1–4.
var difficulty: int
var seed_value: int
var duration_s: float
var status: StringName = STATUS_COMPLETED
## Session total, never below `ScoringConfig.score_floor` (Q6).
var score_total: float
## Category sub-scores by name, unclamped (may be negative).
var score_by_category: Dictionary[StringName, float] = {}
## Number of lane changes, each rated by K3.
var lane_changes: int
## Lane changes signalled in time and in their direction.
var lane_changes_signaled: int
## Time in a left lane while the right one was free, K2 grace included.
var time_left_lane_unjustified_s: float
## Time following closer than the legal minimum (K1).
var time_gap_below_min_s: float
## Lowest gap over the legal minimum while K1 applied; 1.0 when it never did.
var min_gap_ratio: float = 1.0
## Exam verdict (Q9); null in learn mode.
var exam_passed: Variant = null


## The §13 JSON shape.
func to_dict() -> Dictionary:
	var categories: Dictionary = {}
	for category: StringName in SCORED_CATEGORIES:
		categories[String(category)] = score_by_category.get(category, 0.0)
	return {
		"schema_version": SCHEMA_VERSION,
		"id": id,
		"started_at": started_at,
		"app_version": app_version,
		"mode": String(mode),
		"road_profile": String(road_profile),
		"difficulty": difficulty,
		"seed": seed_value,
		"duration_s": duration_s,
		"status": String(status),
		"score_total": score_total,
		"score_by_category": categories,
		"stats": {
			"lane_changes": lane_changes,
			"lane_changes_signaled": lane_changes_signaled,
			"time_left_lane_unjustified_s": time_left_lane_unjustified_s,
			"time_gap_below_min_s": time_gap_below_min_s,
			"min_gap_ratio": min_gap_ratio,
		},
		"exam_passed": exam_passed,
	}
