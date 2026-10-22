extends GdUnitTestSuite
## Dev launcher: mode, profile, level and seed from URL params or user args, with
## defaults for missing or invalid values (issue #9 acceptance criteria, spec Phase 3
## step 4); quality and mirrors the same way (issue #25), and the FPS probe (issue #26).

const RANDOM_SEED: int = 777

var _config: DevLauncherConfig


func before_test() -> void:
	_config = load("res://config/dev_launcher.tres") as DevLauncherConfig


func _from_query(query: String) -> LaunchOptions:
	return DevLauncher.resolve(DevLauncher.parse_query(query), _config, RANDOM_SEED)


func _assert_defaults(options: LaunchOptions) -> void:
	assert_str(options.mode).is_equal(_config.default_mode)
	assert_str(options.profile.id).is_equal(_config.default_profile)
	assert_int(options.level).is_equal(_config.default_level)
	assert_int(options.difficulty.id).is_equal(_config.default_level)
	assert_int(options.seed_value).is_equal(RANDOM_SEED)
	assert_bool(options.seed_given).is_false()
	assert_str(options.quality.id).is_equal(_config.default_quality)
	assert_bool(options.mirrors).is_equal(_config.default_mirrors)
	assert_bool(options.perf).is_equal(_config.default_perf)
	assert_str(options.screen).is_equal(LaunchOptions.SCREEN_DRIVE)
	assert_str(options.touch).is_equal(_config.default_touch)


func test_config_offers_three_profiles_and_four_levels() -> void:
	assert_object(_config.find_profile(&"motorway")).is_not_null()
	assert_object(_config.find_profile(&"expressway")).is_not_null()
	assert_object(_config.find_profile(&"motorway_3lane")).is_not_null()
	assert_str(_config.default_profile).is_equal(&"motorway")
	assert_object(_config.find_profile(&"country_road")).is_null()
	assert_int(_config.levels.size()).is_equal(4)
	assert_bool(_config.default_mode in LaunchOptions.MODES).is_true()
	assert_object(_config.find_profile(_config.default_profile)).is_not_null()
	assert_int(_config.default_level).is_between(1, _config.levels.size())
	assert_object(_config.find_quality(&"low")).is_not_null()
	assert_object(_config.find_quality(&"high")).is_not_null()
	assert_object(_config.find_quality(&"ultra")).is_null()


func test_documented_defaults_are_high_quality_with_mirrors() -> void:
	# README "Dev launcher": no quality param → high, no mirrors param → mirrors on.
	var options: LaunchOptions = _from_query("")
	assert_str(options.quality.id).is_equal(&"high")
	assert_bool(options.mirrors).is_true()


func test_the_fps_probe_is_off_unless_asked_for() -> void:
	# README "Dev launcher": no perf param → no probe.
	assert_bool(_from_query("").perf).is_false()
	assert_bool(_from_query("?perf=1").perf).is_true()
	assert_bool(_from_query("?perf=0").perf).is_false()
	assert_str(_from_query("?perf=1&level=4&seed=1").describe()).contains("perf=1")


func test_touch_buttons_follow_the_device_unless_forced() -> void:
	# Issue #86: no touch param → built on a touch device; 1 / 0 force them on / off.
	assert_str(_config.default_touch).is_equal(LaunchOptions.TOUCH_AUTO)
	assert_str(_from_query("").touch).is_equal(LaunchOptions.TOUCH_AUTO)
	assert_str(_from_query("?touch=1").touch).is_equal(LaunchOptions.TOUCH_ON)
	assert_str(_from_query("?touch=0").touch).is_equal(LaunchOptions.TOUCH_OFF)
	assert_str(_from_query("?touch=yes").touch).is_equal(_config.default_touch)
	assert_str(_from_query("?touch=1&seed=1").describe()).contains("touch=on")


func test_the_touch_param_skips_the_menus() -> void:
	assert_bool(DevLauncher.has_launch_params(DevLauncher.parse_query("?touch=1"))).is_true()


func test_again_keeps_the_touch_choice() -> void:
	assert_str(_from_query("?touch=1").again(3).touch).is_equal(LaunchOptions.TOUCH_ON)


func test_screen_history_opens_the_history_screen() -> void:
	# README "Dev launcher": no screen param → a session (issue #41).
	assert_str(_from_query("").screen).is_equal(LaunchOptions.SCREEN_DRIVE)
	assert_str(_from_query("?screen=history").screen).is_equal(LaunchOptions.SCREEN_HISTORY)
	assert_str(_from_query("?SCREEN=History").screen).is_equal(LaunchOptions.SCREEN_HISTORY)
	assert_str(_from_query("?screen=drive").screen).is_equal(LaunchOptions.SCREEN_DRIVE)
	var from_args: Dictionary = DevLauncher.parse_user_args(PackedStringArray(["--screen=history"]))
	assert_str(DevLauncher.resolve(from_args, _config, RANDOM_SEED).screen).is_equal(LaunchOptions.SCREEN_HISTORY)


func test_all_params_are_used() -> void:
	var options: LaunchOptions = _from_query("?mode=exam&profile=expressway&level=3&seed=42&quality=low&mirrors=0")
	assert_str(options.quality.id).is_equal(&"low")
	assert_bool(options.mirrors).is_false()
	assert_str(options.mode).is_equal(LaunchOptions.MODE_EXAM)
	assert_str(options.profile.id).is_equal(&"expressway")
	assert_float(options.profile.speed_limit_kmh).is_equal(120.0)
	assert_int(options.level).is_equal(3)
	assert_int(options.seed_value).is_equal(42)
	assert_bool(options.seed_given).is_true()


## Issue #96.
func test_the_3_lane_motorway_starts_from_the_url() -> void:
	var options: LaunchOptions = _from_query("?profile=motorway_3lane")
	assert_str(options.profile.id).is_equal(&"motorway_3lane")
	assert_int(options.profile.lane_count).is_equal(3)


func test_missing_params_use_defaults() -> void:
	_assert_defaults(_from_query(""))
	_assert_defaults(_from_query("?"))
	var options: LaunchOptions = _from_query("?profile=expressway")
	assert_str(options.profile.id).is_equal(&"expressway")
	assert_str(options.mode).is_equal(_config.default_mode)
	assert_int(options.level).is_equal(_config.default_level)
	assert_bool(options.seed_given).is_false()


func test_invalid_values_fall_back_to_defaults(query: String, test_parameters: Array = [
		["?level=9"],
		["?level=0"],
		["?level=-1"],
		["?level=2.5"],
		["?level=two"],
		["?mode=race"],
		["?profile=country_road"],
		["?seed=abc"],
		["?seed=-5"],
		["?seed="],
		["?quality=ultra"],
		["?quality="],
		["?mirrors=2"],
		["?mirrors=yes"],
		["?mirrors="],
		["?perf=2"],
		["?perf=yes"],
		["?perf="],
		["?screen=menu"],
		["?screen="],
		["?mode=race&profile=autobahn&level=9&seed=x"],
		["?level&seed&=3&&=&profile"],
		]) -> void:
	_assert_defaults(_from_query(query))


func test_one_invalid_value_leaves_the_others_alone() -> void:
	var options: LaunchOptions = _from_query("?mode=exam&profile=expressway&level=9&seed=7")
	assert_str(options.mode).is_equal(LaunchOptions.MODE_EXAM)
	assert_str(options.profile.id).is_equal(&"expressway")
	assert_int(options.level).is_equal(_config.default_level)
	assert_int(options.difficulty.id).is_equal(_config.default_level)
	assert_int(options.seed_value).is_equal(7)


func test_every_level_in_range_is_accepted() -> void:
	for level: int in range(1, _config.levels.size() + 1):
		var options: LaunchOptions = _from_query("?level=%d" % level)
		assert_int(options.level).is_equal(level)
		# The level's resource comes with it, for the spawner.
		assert_int(options.difficulty.id).is_equal(level)


func test_keys_and_values_are_case_insensitive_and_url_decoded() -> void:
	var options: LaunchOptions = _from_query("?MODE=Exam&Profile=%45xpressway&seed=%2042")
	assert_str(options.mode).is_equal(LaunchOptions.MODE_EXAM)
	assert_str(options.profile.id).is_equal(&"expressway")
	assert_int(options.seed_value).is_equal(42)


func test_unknown_keys_are_ignored_and_a_repeated_key_keeps_its_last_value() -> void:
	var options: LaunchOptions = _from_query("?turbo=1&level=2&level=4")
	assert_int(options.level).is_equal(4)


func test_quality_and_mirrors_each_switch_alone() -> void:
	var low: LaunchOptions = _from_query("?QUALITY=Low")
	assert_str(low.quality.id).is_equal(&"low")
	assert_bool(low.mirrors).is_equal(_config.default_mirrors)
	var no_mirrors: LaunchOptions = _from_query("?mirrors=0")
	assert_bool(no_mirrors.mirrors).is_false()
	assert_str(no_mirrors.quality.id).is_equal(_config.default_quality)
	assert_bool(_from_query("?mirrors=1").mirrors).is_true()
	assert_str(_from_query("?quality=high").quality.id).is_equal(&"high")


func test_user_args_parse_the_same_as_the_query() -> void:
	var args: PackedStringArray = PackedStringArray(["--mode=exam", "--profile=expressway", "level=3", "--seed=42", "--verbose"])
	var from_args: Dictionary = DevLauncher.parse_user_args(args)
	assert_dict(from_args).is_equal(DevLauncher.parse_query("?mode=exam&profile=expressway&level=3&seed=42"))
	var options: LaunchOptions = DevLauncher.resolve(from_args, _config, RANDOM_SEED)
	assert_str(options.mode).is_equal(LaunchOptions.MODE_EXAM)
	assert_str(options.profile.id).is_equal(&"expressway")
	assert_int(options.level).is_equal(3)
	assert_int(options.seed_value).is_equal(42)


func test_no_user_args_use_defaults() -> void:
	_assert_defaults(DevLauncher.resolve(DevLauncher.parse_user_args(PackedStringArray()), _config, RANDOM_SEED))
	_assert_defaults(DevLauncher.resolve(DevLauncher.parse_user_args(PackedStringArray(["--level=9"])), _config, RANDOM_SEED))


func test_test_runner_args_are_not_launch_params() -> void:
	# The headless test run passes no user args, so the platform read sees none.
	var options: LaunchOptions = DevLauncher.from_environment(_config)
	assert_str(options.profile.id).is_equal(_config.default_profile)
	assert_bool(options.seed_given).is_false()


func test_any_known_param_skips_the_start_screen(query: String, test_parameters: Array = [
		["?mode=exam"], ["?profile=expressway"], ["?level=2"], ["?seed=1"], ["?quality=low"],
		["?mirrors=0"], ["?perf=1"], ["?screen=history"], ["?MODE=learn&utm=x"],
		# An invalid value is still a debug launch: it starts with the defaults.
		["?level=9"]]) -> void:
	assert_bool(DevLauncher.has_launch_params(DevLauncher.parse_query(query))).is_true()


func test_no_or_only_unknown_params_open_the_start_screen(query: String, test_parameters: Array = [
		[""], ["?"], ["?utm_source=mail"], ["?mode"]]) -> void:
	assert_bool(DevLauncher.has_launch_params(DevLauncher.parse_query(query))).is_false()


func test_user_args_skip_the_start_screen_the_same_way() -> void:
	assert_bool(DevLauncher.has_launch_params(DevLauncher.parse_user_args(PackedStringArray(["--seed=3"])))).is_true()
	assert_bool(DevLauncher.has_launch_params(DevLauncher.parse_user_args(PackedStringArray()))).is_false()


func test_again_keeps_the_choice_with_a_new_seed() -> void:
	var first: LaunchOptions = _from_query("?mode=exam&profile=expressway&level=3&seed=42&quality=low&mirrors=0&perf=1")
	var again: LaunchOptions = first.again(7)
	assert_str(again.mode).is_equal(LaunchOptions.MODE_EXAM)
	assert_object(again.profile).is_same(first.profile)
	assert_int(again.level).is_equal(3)
	assert_object(again.difficulty).is_same(first.difficulty)
	assert_object(again.quality).is_same(first.quality)
	assert_bool(again.mirrors).is_false()
	assert_bool(again.perf).is_true()
	assert_int(again.seed_value).is_equal(7)
	assert_bool(again.seed_given).is_false()
	assert_str(again.screen).is_equal(LaunchOptions.SCREEN_DRIVE)
	# The first attempt is left as it was.
	assert_int(first.seed_value).is_equal(42)


func test_platform_params_are_taken_once_per_run() -> void:
	# Coming back to the menu must not bounce into the same launch (issue #43).
	var was_taken: bool = DevLauncher.params_taken
	DevLauncher.params_taken = false
	DevLauncher.take_platform_params()
	assert_bool(DevLauncher.params_taken).is_true()
	assert_dict(DevLauncher.take_platform_params()).is_empty()
	DevLauncher.params_taken = false
	DevLauncher.from_environment(_config)
	assert_bool(DevLauncher.params_taken).is_true()
	DevLauncher.params_taken = was_taken


func test_screen_tutorial_starts_the_tutorial_in_learn_mode() -> void:
	var tutorial: LaunchOptions = _from_query("?screen=tutorial")
	assert_str(tutorial.screen).is_equal(LaunchOptions.SCREEN_TUTORIAL)
	assert_bool(tutorial.is_tutorial()).is_true()
	assert_str(tutorial.mode).is_equal(LaunchOptions.MODE_LEARN)
	# Never an exam, even when asked for.
	assert_str(_from_query("?screen=tutorial&mode=exam").mode).is_equal(LaunchOptions.MODE_LEARN)
	assert_bool(_from_query("").is_tutorial()).is_false()
	assert_str(tutorial.describe()).contains("screen=tutorial")


func test_again_after_the_tutorial_is_the_tutorial_again() -> void:
	var again: LaunchOptions = _from_query("?screen=tutorial&seed=5").again(9)
	assert_bool(again.is_tutorial()).is_true()
	assert_int(again.seed_value).is_equal(9)
