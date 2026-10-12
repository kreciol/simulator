extends GdUnitTestSuite
## Dev launcher: mode, profile, level and seed from URL params or user args, with
## defaults for missing or invalid values (issue #9 acceptance criteria, spec Phase 3
## step 4).

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


func test_config_offers_both_profiles_and_four_levels() -> void:
	assert_object(_config.find_profile(&"motorway")).is_not_null()
	assert_object(_config.find_profile(&"expressway")).is_not_null()
	assert_object(_config.find_profile(&"country_road")).is_null()
	assert_int(_config.levels.size()).is_equal(4)
	assert_bool(_config.default_mode in LaunchOptions.MODES).is_true()
	assert_object(_config.find_profile(_config.default_profile)).is_not_null()
	assert_int(_config.default_level).is_between(1, _config.levels.size())


func test_all_params_are_used() -> void:
	var options: LaunchOptions = _from_query("?mode=exam&profile=expressway&level=3&seed=42")
	assert_str(options.mode).is_equal(LaunchOptions.MODE_EXAM)
	assert_str(options.profile.id).is_equal(&"expressway")
	assert_float(options.profile.speed_limit_kmh).is_equal(120.0)
	assert_int(options.level).is_equal(3)
	assert_int(options.seed_value).is_equal(42)
	assert_bool(options.seed_given).is_true()


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
	var options: LaunchOptions = _from_query("?perf=1&level=2&level=4")
	assert_int(options.level).is_equal(4)


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
