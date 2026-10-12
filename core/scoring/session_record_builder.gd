class_name SessionRecordBuilder
extends RefCounted
## Builds the `SessionRecord` of a finished session from its `EventLog` and session
## state (spec Data Model: Persisted, Phase 6 step 4). Pure: reads the log, never
## changes it. Set the session fields, then call `build`.
##
## Stats come from the log's events: one K3 event per lane change; K2 segments
## (grace included) for unjustified left-lane time; K1 segments for time below the
## legal gap and their extremes for the lowest gap ratio.
##
## Exam verdict (Q9): passed when the session completed, the log holds no collision or
## off-road (K4), and `score_total` is at least `exam_pass_score`.

var scoring_config: ScoringConfig

var id: String = ""
var started_at: String = ""
var app_version: String = ""
var mode: StringName = SessionRecord.MODE_LEARN
var road_profile: StringName
var difficulty: int
var seed_value: int
var duration_s: float
var status: StringName = SessionRecord.STATUS_COMPLETED
## The level's `DifficultyLevel.exam_pass_score`; only read in exam mode.
var exam_pass_score: float


func _init(config: ScoringConfig) -> void:
	scoring_config = config


func build(event_log: EventLog) -> SessionRecord:
	var record: SessionRecord = SessionRecord.new()
	record.id = id
	record.started_at = started_at
	record.app_version = app_version
	record.mode = mode
	record.road_profile = road_profile
	record.difficulty = difficulty
	record.seed_value = seed_value
	record.duration_s = duration_s
	record.status = status
	record.score_total = maxf(scoring_config.score_floor, event_log.total())
	for category: StringName in SessionRecord.SCORED_CATEGORIES:
		record.score_by_category[category] = event_log.total_for(category)

	var collided: bool = false
	for event: ScoreEvent in event_log.events:
		match event.type:
			GapRule.TYPE:
				record.time_gap_below_min_s += event.duration_s()
				record.min_gap_ratio = minf(record.min_gap_ratio, event.extreme)
			KeepRightRule.TYPE:
				record.time_left_lane_unjustified_s += event.duration_s()
			SignalRule.TYPE_OK:
				record.lane_changes += 1
				record.lane_changes_signaled += 1
			SignalRule.TYPE_LATE, SignalRule.TYPE_NONE, SignalRule.TYPE_WRONG:
				record.lane_changes += 1
			CollisionRule.TYPE_COLLISION, CollisionRule.TYPE_OFFROAD:
				collided = true

	if mode == SessionRecord.MODE_EXAM:
		record.exam_passed = status == SessionRecord.STATUS_COMPLETED \
				and not collided \
				and record.score_total >= exam_pass_score
	return record
