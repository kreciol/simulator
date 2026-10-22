extends GdUnitTestSuite
## The ideal-driver bot and the exam pass marks measured with it (spec Q9, Phase 6
## step 4; issue #30).

const PROFILE_PATHS: Array[String] = [
	"res://config/road_profiles/motorway.tres",
	"res://config/road_profiles/expressway.tres",
	"res://config/road_profiles/motorway_3lane.tres",
]
## Longest the bot may spend below the legal gap in a session, all of it after cut-ins.
const MAX_CUT_IN_S: float = 2.0

var _sim_config: SimConfig
var _scoring_config: ScoringConfig


func before_test() -> void:
	_sim_config = load("res://config/sim_config.tres") as SimConfig
	_scoring_config = load("res://config/scoring.tres") as ScoringConfig


func _level(level_id: int) -> DifficultyLevel:
	return load("res://config/difficulty_levels/level_%d.tres" % level_id) as DifficultyLevel


func _roads() -> Array[RoadProfile]:
	var roads: Array[RoadProfile] = []
	for path: String in PROFILE_PATHS:
		roads.append(load(path) as RoadProfile)
	return roads


func test_the_bot_scores_the_same_twice_on_the_same_seed() -> void:
	var road: RoadProfile = _roads()[0]
	var first: Dictionary = ExamCalibration.run_session(road, _level(3), _sim_config, _scoring_config, 5).to_dict()
	var second: Dictionary = ExamCalibration.run_session(road, _level(3), _sim_config, _scoring_config, 5).to_dict()
	assert_dict(second).is_equal(first)
	var other_seed: Dictionary = ExamCalibration.run_session(road, _level(3), _sim_config, _scoring_config, 6).to_dict()
	assert_float(other_seed["score_total"]).is_not_equal(first["score_total"])


func test_the_bot_drives_a_whole_session_by_the_book(
		level_id: int,
		test_parameters: Array = [[1], [2], [3], [4]]) -> void:
	var lane_changes: int = 0
	for road: RoadProfile in _roads():
		var record: SessionRecord = ExamCalibration.run_session(road, _level(level_id), _sim_config, _scoring_config)
		var label: String = "%s level %d: %s" % [road.id, level_id, JSON.stringify(record.to_dict())]
		assert_str(String(record.status)).override_failure_message(label).is_equal("completed")
		assert_float(record.duration_s).is_equal_approx(_sim_config.session_length_s, 1e-6)
		assert_float(record.score_by_category[&"speed"]).override_failure_message(label).is_equal(0.0)
		assert_float(record.score_by_category[&"signal"]).override_failure_message(label).is_equal(0.0)
		assert_int(record.lane_changes_signaled).is_equal(record.lane_changes)
		# Below the legal gap only when a less disciplined AI car cuts in (levels 3–4),
		# and only until braking restores it.
		assert_float(record.time_gap_below_min_s).override_failure_message(label).is_less_equal(MAX_CUT_IN_S)
		assert_float(record.score_total).override_failure_message(label).is_greater(0.0)
		lane_changes += record.lane_changes
	# The teachable-moment truck gives something to overtake (spec Research); dense
	# traffic may leave no safe gap on one profile, never on both.
	assert_int(lane_changes).is_greater_equal(2)


func test_each_level_s_pass_mark_is_60_percent_of_the_bot_s_score(
		level_id: int,
		test_parameters: Array = [[1], [2], [3], [4]]) -> void:
	var level: DifficultyLevel = _level(level_id)
	var measured: float = ExamCalibration.pass_score(level, _roads(), _sim_config, _scoring_config)
	print("level %d: exam_pass_score = %.0f" % [level_id, measured])
	assert_float(level.exam_pass_score) \
			.override_failure_message("level_%d.tres exam_pass_score is %.0f; re-measured %.0f — write the new value" % [level_id, level.exam_pass_score, measured]) \
			.is_equal(measured)
	assert_float(level.exam_pass_score).is_greater(0.0)
