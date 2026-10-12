class_name SessionRecord
extends RefCounted
## The record of one finished session (requirements §13, spec Data Model: Persisted):
## the §13 fields plus `seed`, `exam_passed`, `score_by_category.speed` and
## `app_version`. Built by `SessionRecordBuilder`; saved by `SaveManager` (E10).

const SCHEMA_VERSION: int = 1

## Session modes; `LaunchOptions` reuses them (core does not depend on the game layer).
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


## Reads back a `to_dict` shape, e.g. parsed from JSON, where every number is a float.
## Missing fields keep their defaults.
static func from_dict(data: Dictionary) -> SessionRecord:
	var record: SessionRecord = SessionRecord.new()
	record.id = str(data.get("id", ""))
	record.started_at = str(data.get("started_at", ""))
	record.app_version = str(data.get("app_version", ""))
	record.mode = StringName(str(data.get("mode", "")))
	record.road_profile = StringName(str(data.get("road_profile", "")))
	record.difficulty = int(data.get("difficulty", 0))
	record.seed_value = int(data.get("seed", 0))
	record.duration_s = float(data.get("duration_s", 0.0))
	record.status = StringName(str(data.get("status", STATUS_COMPLETED)))
	record.score_total = float(data.get("score_total", 0.0))
	var categories: Variant = data.get("score_by_category", {})
	if categories is Dictionary:
		for category: StringName in SCORED_CATEGORIES:
			record.score_by_category[category] = float((categories as Dictionary).get(String(category), 0.0))
	var stats: Variant = data.get("stats", {})
	if stats is Dictionary:
		var values: Dictionary = stats as Dictionary
		record.lane_changes = int(values.get("lane_changes", 0))
		record.lane_changes_signaled = int(values.get("lane_changes_signaled", 0))
		record.time_left_lane_unjustified_s = float(values.get("time_left_lane_unjustified_s", 0.0))
		record.time_gap_below_min_s = float(values.get("time_gap_below_min_s", 0.0))
		record.min_gap_ratio = float(values.get("min_gap_ratio", 1.0))
	var passed: Variant = data.get("exam_passed")
	record.exam_passed = bool(passed) if passed is bool else null
	return record
