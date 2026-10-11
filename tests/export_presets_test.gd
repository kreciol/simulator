extends GdUnitTestSuite
## Guards the web export preset the requirements fix (§3.3: single-threaded, no COOP/COEP).

const PRESETS_PATH: String = "res://export_presets.cfg"


func _web_preset_section(presets: ConfigFile) -> String:
	for section: String in presets.get_sections():
		if section.ends_with(".options"):
			continue
		if presets.get_value(section, "platform", "") == "Web":
			return section
	return ""


func test_web_preset_exists() -> void:
	var presets: ConfigFile = ConfigFile.new()
	assert_int(presets.load(PRESETS_PATH)).is_equal(OK)
	var section: String = _web_preset_section(presets)
	assert_str(section).is_not_empty()
	assert_str(presets.get_value(section, "name", "")).is_equal("Web")


func test_web_preset_is_single_threaded() -> void:
	var presets: ConfigFile = ConfigFile.new()
	assert_int(presets.load(PRESETS_PATH)).is_equal(OK)
	var options: String = _web_preset_section(presets) + ".options"
	assert_bool(presets.get_value(options, "variant/thread_support", true)).is_false()
	assert_bool(presets.get_value(options, "progressive_web_app/ensure_cross_origin_isolation_headers", true)).is_false()
