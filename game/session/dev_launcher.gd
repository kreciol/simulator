class_name DevLauncher
extends RefCounted
## Dev launcher (spec Phasing, Phase 3 step 4): until the Phase 10 menus exist, a
## session's mode, road profile, level and seed come from URL query params on web
## (`?mode=exam&profile=expressway&level=3&seed=42`) or from user args on desktop
## (`godot -- --profile=expressway --seed=42`), and so do the graphics quality and
## the mirrors (`&quality=low&mirrors=0`, issue #25), and the FPS probe (`&perf=1`,
## issue #26). `screen=history` opens the history screen instead of a session (issue
## #41) and `screen=tutorial` the tutorial, always in learn mode (issue #45). A missing
## or invalid value falls back to its default from `DevLauncherConfig` (`high` quality,
## mirrors on, probe off) or, for the screen, to a session; a missing seed is drawn at
## random. Since the start screen (issue #43) the params are a debug
## shortcut: any of them skips the menus.

const KEY_MODE: String = "mode"
const KEY_PROFILE: String = "profile"
const KEY_LEVEL: String = "level"
const KEY_SEED: String = "seed"
const KEY_QUALITY: String = "quality"
const KEY_MIRRORS: String = "mirrors"
const KEY_PERF: String = "perf"
const KEY_SCREEN: String = "screen"
const KEYS: Array[String] = [KEY_MODE, KEY_PROFILE, KEY_LEVEL, KEY_SEED, KEY_QUALITY,
		KEY_MIRRORS, KEY_PERF, KEY_SCREEN]

## Whether this run's platform params were already taken: they launch once per run, so
## coming back to the menu later does not bounce into the same launch (issue #43).
static var params_taken: bool = false


## Launch options from this platform's params: the page URL on web, user args elsewhere;
## the defaults once the params were taken.
static func from_environment(config: DevLauncherConfig) -> LaunchOptions:
	return resolve(take_platform_params(), config, randi())


## This platform's params the first time in a run, then none.
static func take_platform_params() -> Dictionary:
	if params_taken:
		return {}
	params_taken = true
	return read_platform_params()


## Whether `params` name anything the launcher reads: then the start screen is skipped
## and they start the session (or `screen`) directly, as before the menus (issue #43).
## Unknown keys alone do not.
static func has_launch_params(params: Dictionary) -> bool:
	for key: String in KEYS:
		if params.has(key):
			return true
	return false


static func read_platform_params() -> Dictionary:
	if OS.has_feature("web"):
		var search: Variant = JavaScriptBridge.eval("window.location.search", true)
		return parse_query(search if search is String else "")
	return parse_user_args(OS.get_cmdline_user_args())


## `?key=value&key=value` → `{key: value}`. Keys are lower-cased, values URL-decoded;
## pairs without `=` are ignored and a repeated key keeps its last value.
static func parse_query(query: String) -> Dictionary:
	var params: Dictionary = {}
	var text: String = query.strip_edges().trim_prefix("?")
	for pair: String in text.split("&", false):
		_add_pair(params, pair, true)
	return params


## `--key=value` (or `key=value`) user args → the same map `parse_query` builds.
static func parse_user_args(args: PackedStringArray) -> Dictionary:
	var params: Dictionary = {}
	for arg: String in args:
		_add_pair(params, arg.strip_edges().lstrip("-"), false)
	return params


## Validates `params` against `config`; each missing or invalid value takes its
## default, and the seed falls back to `random_seed`.
static func resolve(params: Dictionary, config: DevLauncherConfig, random_seed: int) -> LaunchOptions:
	var options: LaunchOptions = LaunchOptions.new()

	options.mode = config.default_mode
	if params.has(KEY_MODE):
		var mode: StringName = StringName(String(params[KEY_MODE]).to_lower())
		if mode in LaunchOptions.MODES:
			options.mode = mode
		else:
			_warn_invalid(KEY_MODE, params[KEY_MODE])

	options.profile = config.find_profile(config.default_profile)
	if params.has(KEY_PROFILE):
		var profile: RoadProfile = config.find_profile(StringName(String(params[KEY_PROFILE]).to_lower()))
		if profile != null:
			options.profile = profile
		else:
			_warn_invalid(KEY_PROFILE, params[KEY_PROFILE])

	options.level = config.default_level
	if params.has(KEY_LEVEL):
		var level: String = params[KEY_LEVEL]
		if level.is_valid_int() and config.find_level(level.to_int()) != null:
			options.level = level.to_int()
		else:
			_warn_invalid(KEY_LEVEL, level)
	options.difficulty = config.find_level(options.level)

	options.seed_value = random_seed
	options.seed_given = false
	if params.has(KEY_SEED):
		var seed_text: String = params[KEY_SEED]
		if seed_text.is_valid_int() and seed_text.to_int() >= 0:
			options.seed_value = seed_text.to_int()
			options.seed_given = true
		else:
			_warn_invalid(KEY_SEED, seed_text)

	options.quality = config.find_quality(config.default_quality)
	if params.has(KEY_QUALITY):
		var quality: QualityPreset = config.find_quality(StringName(String(params[KEY_QUALITY]).to_lower()))
		if quality != null:
			options.quality = quality
		else:
			_warn_invalid(KEY_QUALITY, params[KEY_QUALITY])

	options.mirrors = config.default_mirrors
	if params.has(KEY_MIRRORS):
		var mirrors: String = params[KEY_MIRRORS]
		if mirrors == "0" or mirrors == "1":
			options.mirrors = mirrors == "1"
		else:
			_warn_invalid(KEY_MIRRORS, mirrors)

	options.perf = config.default_perf
	if params.has(KEY_PERF):
		var perf: String = params[KEY_PERF]
		if perf == "0" or perf == "1":
			options.perf = perf == "1"
		else:
			_warn_invalid(KEY_PERF, perf)

	options.screen = LaunchOptions.SCREEN_DRIVE
	if params.has(KEY_SCREEN):
		var screen: StringName = StringName(String(params[KEY_SCREEN]).to_lower())
		if screen in LaunchOptions.SCREENS:
			options.screen = screen
		else:
			_warn_invalid(KEY_SCREEN, params[KEY_SCREEN])
	# The tutorial teaches; it is never an exam.
	if options.is_tutorial():
		options.mode = LaunchOptions.MODE_LEARN

	return options


static func _add_pair(params: Dictionary, pair: String, url_encoded: bool) -> void:
	var split_at: int = pair.find("=")
	if split_at <= 0:
		return
	var key: String = pair.left(split_at)
	var value: String = pair.substr(split_at + 1)
	if url_encoded:
		key = key.replace("+", " ").uri_decode()
		value = value.replace("+", " ").uri_decode()
	params[key.strip_edges().to_lower()] = value.strip_edges()


static func _warn_invalid(key: String, value: String) -> void:
	push_warning("Dev launcher: invalid %s '%s', using the default." % [key, value])
