extends GdUnitTestSuite
## The settings page of the start screen (issue #44 acceptance criteria, requirements
## §9.4, spec Phase 10 step 1): quality and mirrors are saved and used by the next
## session, they come back after a reload, the key bindings are only previewed, and
## the page fits 1280×720 with fullscreen switchable.

const DIR: String = "user://test_settings_page"
const PATH: String = DIR + "/settings.cfg"

var _launcher: DevLauncherConfig
var _started: Array[LaunchOptions] = []
var _fullscreen_calls: Array[bool] = []
var _fullscreen: bool = false


func before_test() -> void:
	_clear_dir()
	DirAccess.make_dir_recursive_absolute(DIR)
	_launcher = load("res://config/dev_launcher.tres") as DevLauncherConfig
	_started.clear()
	_fullscreen_calls.clear()
	_fullscreen = false


func after_test() -> void:
	_clear_dir()


func _clear_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for file_name: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))
	DirAccess.remove_absolute(DIR)


func _settings(path: String = PATH) -> SettingsStore:
	var settings: SettingsStore = SettingsStore.new(path, _launcher)
	settings.userfs_persistent = true
	settings.load_settings()
	return settings


func _make(settings: SettingsStore = _settings()) -> StartScreen:
	var screen: StartScreen = auto_free(StartScreen.new()) as StartScreen
	screen.launcher_config = _launcher
	screen.menu_config = load("res://config/menu.tres") as MenuConfig
	screen.settings = settings
	screen.open_scene = func(_path: String) -> void: pass
	screen.start_session = func(options: LaunchOptions) -> void: _started.append(options)
	screen.is_fullscreen = func() -> bool: return _fullscreen
	screen.set_fullscreen = func(fullscreen: bool) -> void: _fullscreen_calls.append(fullscreen)
	add_child(screen)
	return screen


## Starts a session from the setup with its defaults; returns its options.
func _start_session(screen: StartScreen) -> LaunchOptions:
	screen.show_setup()
	screen.start_button.pressed.emit()
	return _started.back()


func test_settings_open_from_the_menu_with_the_saved_choices() -> void:
	var saved: SettingsStore = _settings()
	saved.set_quality(&"low")
	saved.set_mirrors(false)
	var screen: StartScreen = _make()
	screen.settings_button.pressed.emit()
	assert_bool(screen.settings_page.visible).is_true()
	assert_bool(screen.menu_page.visible).is_false()
	assert_bool(screen.setup_page.visible).is_false()
	assert_bool(screen.quality_buttons[&"low"].button_pressed).is_true()
	assert_bool(screen.quality_buttons[&"high"].button_pressed).is_false()
	assert_bool(screen.mirrors_buttons[false].button_pressed).is_true()
	assert_bool(screen.mirrors_buttons[true].button_pressed).is_false()
	assert_bool(screen.display_buttons[false].button_pressed).is_true()


func test_without_saved_settings_high_quality_and_mirrors_on_are_shown() -> void:
	var screen: StartScreen = _make()
	screen.show_settings()
	assert_bool(screen.quality_buttons[&"high"].button_pressed).is_true()
	assert_bool(screen.mirrors_buttons[true].button_pressed).is_true()


func test_the_choices_are_written_out_in_polish() -> void:
	var screen: StartScreen = _make()
	assert_str(screen.quality_buttons[&"low"].text).is_equal("Niska")
	assert_str(screen.quality_buttons[&"high"].text).is_equal("Wysoka")
	assert_str(screen.mirrors_buttons[true].text).is_equal("Włączone")
	assert_str(screen.mirrors_buttons[false].text).is_equal("Wyłączone")
	assert_str(screen.display_buttons[true].text).is_equal("Pełny ekran")
	assert_str(screen.display_buttons[false].text).is_equal("Okno")


func test_changed_quality_and_mirrors_are_used_by_the_next_session() -> void:
	var screen: StartScreen = _make()
	screen.show_settings()
	screen.quality_buttons[&"low"].pressed.emit()
	screen.mirrors_buttons[false].pressed.emit()
	screen.settings_back_button.pressed.emit()
	var options: LaunchOptions = _start_session(screen)
	assert_str(options.quality.id).is_equal(&"low")
	assert_bool(options.mirrors).is_false()
	screen.show_settings()
	screen.quality_buttons[&"high"].pressed.emit()
	screen.mirrors_buttons[true].pressed.emit()
	options = _start_session(screen)
	assert_str(options.quality.id).is_equal(&"high")
	assert_bool(options.mirrors).is_true()


func test_changed_settings_are_restored_after_a_reload() -> void:
	var screen: StartScreen = _make()
	screen.show_settings()
	screen.quality_buttons[&"low"].pressed.emit()
	screen.mirrors_buttons[false].pressed.emit()
	# A reload: a fresh store reads the file, a fresh screen shows and uses it.
	var reloaded: StartScreen = _make(_settings())
	reloaded.show_settings()
	assert_bool(reloaded.quality_buttons[&"low"].button_pressed).is_true()
	assert_bool(reloaded.mirrors_buttons[false].button_pressed).is_true()
	var options: LaunchOptions = _start_session(reloaded)
	assert_str(options.quality.id).is_equal(&"low")
	assert_bool(options.mirrors).is_false()


func test_a_failed_save_is_explained_and_the_choice_still_applies() -> void:
	var blocked: String = DIR + "/blocked.cfg"
	DirAccess.make_dir_recursive_absolute(blocked)
	var screen: StartScreen = _make(_settings(blocked))
	screen.show_settings()
	assert_bool(screen.settings_save_failed_label.visible).is_false()
	screen.mirrors_buttons[false].pressed.emit()
	assert_bool(screen.settings_save_failed_label.visible).is_true()
	assert_str(screen.settings_save_failed_label.text).contains("nie zapisaliśmy")
	assert_bool(_start_session(screen).mirrors).is_false()
	DirAccess.remove_absolute(blocked)


func test_the_key_preview_lists_every_input_map_action_with_its_keys() -> void:
	var screen: StartScreen = _make()
	assert_array(screen.key_labels.keys()).contains_exactly(KeyBindings.actions())
	for action: StringName in KeyBindings.actions():
		assert_str(screen.key_labels[action].text).is_not_empty()
	assert_str(screen.key_labels[&"accelerate"].text).is_equal("W lub Strzałka w górę")
	assert_str(screen.key_labels[&"signal_left"].text).is_equal("Q lub Przecinek (,)")
	assert_str(screen.key_labels[&"pause"].text).is_equal("Esc lub P")
	var bindings: Node = screen.settings_page.find_child("Bindings", true, false)
	var accelerate_name: Label = bindings.get_node("Action_accelerate") as Label
	assert_str(accelerate_name.text).is_equal("Przyspieszanie")


func test_keys_cannot_be_changed_in_the_preview() -> void:
	var screen: StartScreen = _make()
	var bindings: Node = screen.settings_page.find_child("Bindings", true, false)
	assert_object(bindings).is_not_null()
	for child: Node in bindings.get_children():
		assert_bool(child is Label).is_true()
		assert_int((child as Control).focus_mode).is_equal(Control.FOCUS_NONE)
	assert_str(screen.settings_page.find_child("KeysHint", true, false).get("text")).contains("nie da się")
	# Nothing about keys is stored either.
	var store: SettingsStore = _settings()
	store.set_mirrors(true)
	var file: ConfigFile = ConfigFile.new()
	file.load(PATH)
	assert_array(file.get_section_keys(SettingsStore.SECTION)).not_contains(["keys", "bindings"])


func test_fullscreen_can_be_toggled() -> void:
	var screen: StartScreen = _make()
	screen.show_settings()
	screen.display_buttons[true].pressed.emit()
	screen.display_buttons[false].pressed.emit()
	assert_array(_fullscreen_calls).contains_exactly([true, false])
	_fullscreen = true
	screen.show_settings()
	assert_bool(screen.display_buttons[true].button_pressed).is_true()


func test_back_and_esc_return_to_the_menu() -> void:
	var screen: StartScreen = _make()
	screen.show_settings()
	screen.settings_back_button.pressed.emit()
	assert_bool(screen.menu_page.visible).is_true()
	assert_bool(screen.settings_page.visible).is_false()
	screen.show_settings()
	var esc: InputEventKey = InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	screen._unhandled_input(esc)
	assert_bool(screen.menu_page.visible).is_true()
	assert_bool(screen.settings_page.visible).is_false()
	assert_array(_started).is_empty()


func test_the_page_fits_1280_by_720() -> void:
	var screen: StartScreen = _make()
	screen.size = Vector2(1280.0, 720.0)
	screen.show_settings()
	screen.settings_save_failed_label.visible = true
	await await_idle_frame()
	await await_idle_frame()
	var page: Control = screen.settings_page
	assert_float(page.get_combined_minimum_size().x).is_less_equal(1280.0 - 2.0 * StartScreen.MARGIN)
	assert_float(page.get_combined_minimum_size().y).is_less_equal(720.0 - 2.0 * StartScreen.MARGIN)
	for node: Node in page.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label.visible and label.text != "":
			assert_int(label.get_theme_font_size("font_size")).is_greater_equal(StartScreen.NOTE_FONT_SIZE)


func test_storage_that_does_not_persist_is_explained() -> void:
	var settings: SettingsStore = _settings()
	settings.userfs_persistent = false
	var screen: StartScreen = _make(settings)
	screen.show_settings()
	# Said when the page opens, before any change.
	assert_bool(screen.settings_save_failed_label.visible).is_true()
	screen.quality_buttons[&"low"].pressed.emit()
	assert_bool(screen.settings_save_failed_label.visible).is_true()
	assert_str(_start_session(screen).quality.id).is_equal(&"low")


func test_the_fullscreen_choice_follows_the_window() -> void:
	# Leaving fullscreen with the browser's Esc or F11 resizes the viewport.
	var screen: StartScreen = _make()
	_fullscreen = true
	screen.show_settings()
	_fullscreen = false
	screen.get_viewport().size_changed.emit()
	assert_bool(screen.display_buttons[false].button_pressed).is_true()


func test_every_quality_preset_has_a_polish_name() -> void:
	var screen: StartScreen = _make()
	for preset: QualityPreset in _launcher.quality_presets:
		var key: StringName = StartScreen.quality_label_key(preset.id)
		assert_str(screen.quality_buttons[preset.id].text).is_not_equal(String(key))


func test_each_heading_names_the_choice_not_shade_alone() -> void:
	var screen: StartScreen = _make()
	screen.show_settings()
	var quality: Label = screen.settings_page.find_child("QualityHeading", true, false) as Label
	var mirrors: Label = screen.settings_page.find_child("MirrorsHeading", true, false) as Label
	var display: Label = screen.settings_page.find_child("DisplayHeading", true, false) as Label
	assert_str(quality.text).is_equal("Jakość grafiki: Wysoka")
	assert_str(mirrors.text).is_equal("Lusterka: Włączone")
	assert_str(display.text).is_equal("Ekran: Okno")
	screen.quality_buttons[&"low"].pressed.emit()
	screen.mirrors_buttons[false].pressed.emit()
	screen.display_buttons[true].pressed.emit()
	assert_str(quality.text).is_equal("Jakość grafiki: Niska")
	assert_str(mirrors.text).is_equal("Lusterka: Wyłączone")
	assert_str(display.text).is_equal("Ekran: Pełny ekran")
