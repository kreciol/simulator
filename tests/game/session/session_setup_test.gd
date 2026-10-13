extends GdUnitTestSuite
## The new-session setup's rules: learn mode by default, the exam suggested only after
## 3 completed learn sessions, the recommended level highlighted, and a choice turned
## into launch options (issue #43 acceptance criteria, requirements §9.1, Q14).

const RANDOM_SEED: int = 4242

var _launcher: DevLauncherConfig
var _menu: MenuConfig


func before_test() -> void:
	_launcher = load("res://config/dev_launcher.tres") as DevLauncherConfig
	_menu = load("res://config/menu.tres") as MenuConfig


func _entry(mode: StringName, status: StringName = SessionRecord.STATUS_COMPLETED) -> Dictionary:
	return {"mode": String(mode), "status": String(status)}


func _learn_sessions(count: int) -> Array[Dictionary]:
	var sessions: Array[Dictionary] = []
	for i: int in count:
		sessions.append(_entry(SessionRecord.MODE_LEARN))
	return sessions


func test_the_exam_is_suggested_after_three_learn_sessions() -> void:
	assert_int(_menu.exam_suggested_after_learn_sessions).is_equal(3)


func test_the_exam_is_not_suggested_before_three_completed_learn_sessions(count: int,
		test_parameters: Array = [[0], [1], [2]]) -> void:
	var completed: int = SessionSetup.completed_learn_sessions(_learn_sessions(count))
	assert_int(completed).is_equal(count)
	assert_bool(SessionSetup.suggests_exam(completed, _menu)).is_false()


func test_the_exam_is_suggested_from_three_completed_learn_sessions(count: int,
		test_parameters: Array = [[3], [4], [12]]) -> void:
	var completed: int = SessionSetup.completed_learn_sessions(_learn_sessions(count))
	assert_bool(SessionSetup.suggests_exam(completed, _menu)).is_true()


func test_exam_and_aborted_sessions_do_not_count() -> void:
	var sessions: Array[Dictionary] = _learn_sessions(2)
	sessions.append(_entry(SessionRecord.MODE_EXAM))
	sessions.append(_entry(SessionRecord.MODE_EXAM))
	sessions.append(_entry(SessionRecord.MODE_LEARN, SessionRecord.STATUS_ABORTED_COLLISION))
	sessions.append({})
	var completed: int = SessionSetup.completed_learn_sessions(sessions)
	assert_int(completed).is_equal(2)
	assert_bool(SessionSetup.suggests_exam(completed, _menu)).is_false()


func test_learn_mode_is_selected_by_default() -> void:
	assert_str(SessionSetup.default_mode()).is_equal(LaunchOptions.MODE_LEARN)


func test_the_recommended_level_is_the_one_marked_recommended() -> void:
	assert_int(SessionSetup.recommended_level(_launcher)).is_equal(1)
	assert_bool(_launcher.find_level(1).recommended).is_true()


func test_without_a_recommended_level_the_default_is_highlighted() -> void:
	var launcher: DevLauncherConfig = _launcher.duplicate() as DevLauncherConfig
	var levels: Array[DifficultyLevel] = []
	for level: DifficultyLevel in _launcher.levels:
		var copy: DifficultyLevel = level.duplicate() as DifficultyLevel
		copy.recommended = false
		levels.append(copy)
	launcher.levels = levels
	launcher.default_level = 2
	assert_int(SessionSetup.recommended_level(launcher)).is_equal(2)


func test_every_level_can_be_chosen(level: int, test_parameters: Array = [[1], [2], [3], [4]]) -> void:
	var options: LaunchOptions = SessionSetup.options_for(
			LaunchOptions.MODE_EXAM, &"expressway", level, _launcher, RANDOM_SEED)
	assert_str(options.mode).is_equal(LaunchOptions.MODE_EXAM)
	assert_str(options.profile.id).is_equal(&"expressway")
	assert_int(options.level).is_equal(level)
	assert_int(options.difficulty.id).is_equal(level)
	assert_int(options.seed_value).is_equal(RANDOM_SEED)
	assert_bool(options.seed_given).is_false()
	assert_str(options.screen).is_equal(LaunchOptions.SCREEN_DRIVE)


func test_a_choice_keeps_the_default_quality_and_mirrors() -> void:
	var options: LaunchOptions = SessionSetup.options_for(
			LaunchOptions.MODE_LEARN, &"motorway", 2, _launcher, RANDOM_SEED)
	assert_str(options.quality.id).is_equal(_launcher.default_quality)
	assert_bool(options.mirrors).is_equal(_launcher.default_mirrors)
	assert_bool(options.perf).is_equal(_launcher.default_perf)
