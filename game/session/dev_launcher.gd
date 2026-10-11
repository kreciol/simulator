class_name DevLauncher
extends RefCounted
## Dev launcher (spec Phasing, Phase 3 step 4): until the Phase 10 menus exist, a
## session's mode, road profile, level and seed come from URL query params on web
## (`?mode=exam&profile=expressway&level=3&seed=42`) or from user args on desktop
## (`godot -- --profile=expressway --seed=42`). A missing or invalid value falls back
## to its default from `DevLauncherConfig`; a missing seed is drawn at random.

const KEY_MODE: String = "mode"
const KEY_PROFILE: String = "profile"
const KEY_LEVEL: String = "level"
const KEY_SEED: String = "seed"


## Launch options from this platform's params: the page URL on web, user args elsewhere.
static func from_environment(config: DevLauncherConfig) -> LaunchOptions:
	return resolve(read_platform_params(), config, randi())


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
		if level.is_valid_int() and level.to_int() >= 1 and level.to_int() <= config.level_count:
			options.level = level.to_int()
		else:
			_warn_invalid(KEY_LEVEL, level)

	options.seed_value = random_seed
	options.seed_given = false
	if params.has(KEY_SEED):
		var seed_text: String = params[KEY_SEED]
		if seed_text.is_valid_int() and seed_text.to_int() >= 0:
			options.seed_value = seed_text.to_int()
			options.seed_given = true
		else:
			_warn_invalid(KEY_SEED, seed_text)

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
