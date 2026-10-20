class_name StartScreen
extends Control
## The start screen, the new-session setup and the settings (requirements §9.1, §9.4,
## spec Phase 10 step 1 and UI/UX flow, issues #43, #44, #45). The menu offers a new
## session, the history, the settings and the tutorial, with the "educational tool, not
## legal advice" note (spec Risks: teaching correctness). Until the tutorial was finished
## or skipped once it is suggested: marked, with the focus and a line saying why; it can
## be run again from here any time. The setup picks mode · road profile · level: learn
## mode is selected, the recommended level is highlighted and every level is selectable
## (Q14), and after enough completed learn sessions the exam is marked as suggested
## (`SessionSetup`). Start begins the session with the 3-2-1 countdown, using the
## quality and mirrors from the settings. The settings page sets those two (saved at once
## in `settings.cfg`, `SettingsStore`), toggles fullscreen (not remembered: a browser
## enters it only on a player's gesture) and previews the key bindings, read-only.
## Dev-launcher params in the URL (user args on desktop) skip the menus and start the
## session (or the history screen) directly, once per run, so returning to the menu
## later does not bounce back into the same launch.
## Placeholder styling until the UI theme lands (Phase 10).

const MARGIN: int = 48
const SEPARATION: int = 12
const ROW_SEPARATION: int = 12
## Between the key-binding rows: tight, so every Input Map action fits at 1280×720.
const KEY_ROW_SEPARATION: int = 0
const OUTLINE_SIZE: int = 6
const TITLE_FONT_SIZE: int = 56
const HEADING_FONT_SIZE: int = 28
const TEXT_FONT_SIZE: int = 20
const NOTE_FONT_SIZE: int = 16
const BUTTON_FONT_SIZE: int = 24
const MENU_BUTTON_SIZE: Vector2 = Vector2(420.0, 56.0)
const OPTION_BUTTON_SIZE: Vector2 = Vector2(250.0, 52.0)
## Wrap width of the longer lines; fits the 1280×720 minimum window.
const TEXT_WIDTH: float = 1080.0
const BACKGROUND: Color = Color(0.08, 0.1, 0.13)
const SUGGESTION_COLOR: Color = Color(1.0, 0.82, 0.4)

## Columns of the settings page: the choices, and the key-bindings preview.
const SETTINGS_COLUMN_WIDTH: float = 540.0
const KEY_ACTION_WIDTH: float = 260.0
const WARNING_COLOR: Color = Color(1.0, 0.6, 0.45)

## Translation key of a quality preset's name: this + its id in upper case.
const QUALITY_KEY_PREFIX: String = "SETTINGS_QUALITY_"

const MODE_KEYS: Dictionary[StringName, StringName] = {
	LaunchOptions.MODE_LEARN: &"MODE_LEARN",
	LaunchOptions.MODE_EXAM: &"MODE_EXAM",
}
const MODE_HINT_KEYS: Dictionary[StringName, StringName] = {
	LaunchOptions.MODE_LEARN: &"SETUP_MODE_LEARN_HINT",
	LaunchOptions.MODE_EXAM: &"SETUP_MODE_EXAM_HINT",
}

@export var launcher_config: DevLauncherConfig
@export var menu_config: MenuConfig
## Follows the launch params and reads `SaveManager`'s history and settings once in the
## tree (the scene sets it); tests set `completed_learn`, `tutorial_seen` and `settings`
## themselves.
@export var use_platform_state: bool = false

## The player's settings; when nothing set them, the launcher's defaults in a store
## without a file, whose saves report a failure.
var settings: SettingsStore
## Completed learn sessions in the saved history; decides the exam suggestion.
var completed_learn: int = 0
## Whether the tutorial was finished or skipped once; until then it is suggested.
var tutorial_seen: bool = false
## Switches to another scene by path; tests replace it to watch instead.
var open_scene: Callable = func(path: String) -> void: AppFlow.open_scene(get_tree(), path)
## Starts a session with the given options; tests replace it to watch instead.
var start_session: Callable = func(options: LaunchOptions) -> void: AppFlow.start_session(get_tree(), options)
## Whether the window is fullscreen, and switching it; tests replace both.
var is_fullscreen: Callable = func() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,
			DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
var set_fullscreen: Callable = func(fullscreen: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
			else DisplayServer.WINDOW_MODE_WINDOWED)

var menu_page: VBoxContainer
var new_session_button: Button
var history_button: Button
var settings_button: Button
var tutorial_button: Button
## Shown while the tutorial is suggested; says why.
var tutorial_suggestion_label: Label
var legal_note_label: Label

var setup_page: VBoxContainer
var mode_buttons: Dictionary[StringName, Button] = {}
var mode_hint_label: Label
## Shown once the exam is suggested; says why.
var exam_suggestion_label: Label
var profile_buttons: Dictionary[StringName, Button] = {}
var level_buttons: Dictionary[int, Button] = {}
## The current choice in words, so it never shows by shade alone.
var choice_label: Label
var start_button: Button
var back_button: Button

var settings_page: VBoxContainer
var quality_buttons: Dictionary[StringName, Button] = {}
## Mirrors on (true) and off (false).
var mirrors_buttons: Dictionary[bool, Button] = {}
## Fullscreen (true) and a window (false).
var display_buttons: Dictionary[bool, Button] = {}
## Shown once a change could not be saved; says why.
var settings_save_failed_label: Label
## The keys of each game action, as previewed.
var key_labels: Dictionary[StringName, Label] = {}
var settings_back_button: Button
## Each setting's heading and the group of its options; the heading names the choice.
var setting_headings: Dictionary[Label, ButtonGroup] = {}
var heading_keys: Dictionary[Label, StringName] = {}

var selected_mode: StringName = LaunchOptions.MODE_LEARN
var selected_profile: StringName
var selected_level: int
var recommended_level: int


func _ready() -> void:
	if use_platform_state:
		# Only the first screen of a run follows them (`DevLauncher.take_platform_params`).
		var params: Dictionary = DevLauncher.take_platform_params()
		if DevLauncher.has_launch_params(params):
			_launch(DevLauncher.resolve(params, launcher_config, randi()))
			return
		completed_learn = SessionSetup.completed_learn_sessions(SaveManager.store.sessions)
		tutorial_seen = SaveManager.settings.tutorial_seen
		settings = SaveManager.settings
	if settings == null:
		settings = SettingsStore.new("", launcher_config)
	_build()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	show_menu()


func _unhandled_input(event: InputEvent) -> void:
	# Esc on the setup or the settings goes back to the menu, as on the history screen.
	if setup_page != null and (setup_page.visible or settings_page.visible) \
			and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		show_menu()


## What the dev-launcher params ask for: the history screen, or a session.
func _launch(options: LaunchOptions) -> void:
	if options.screen == LaunchOptions.SCREEN_HISTORY:
		open_scene.call(AppFlow.HISTORY_SCENE)
	else:
		start_session.call(options)


func show_menu() -> void:
	menu_page.visible = true
	setup_page.visible = false
	settings_page.visible = false
	var suggested: bool = tutorial_suggested()
	tutorial_button.text = _option_text(tr(&"START_TUTORIAL"), suggested)
	tutorial_suggestion_label.visible = suggested
	_focus(tutorial_button if suggested else new_session_button)


func tutorial_suggested() -> bool:
	return SessionSetup.suggests_tutorial(tutorial_seen)


## Starts the tutorial: an empty road, no scoring, the steps prompted one by one, with
## the quality and mirrors from the settings. Like Start, pressing it is the player's
## gesture for sound.
func start_tutorial() -> void:
	AudioView.run_unlocked = true
	start_session.call(SessionSetup.tutorial_options(launcher_config, randi(), settings))


## Opens the setup with its defaults: learn mode (§9.1), the launcher's road profile and
## the recommended level; the exam is marked as suggested when it is due.
func show_setup() -> void:
	recommended_level = SessionSetup.recommended_level(launcher_config)
	select_mode(SessionSetup.default_mode())
	select_profile(launcher_config.default_profile)
	select_level(recommended_level)
	var suggested: bool = exam_suggested()
	mode_buttons[LaunchOptions.MODE_EXAM].text = _option_text(tr(MODE_KEYS[LaunchOptions.MODE_EXAM]), suggested)
	exam_suggestion_label.text = tr(&"SETUP_EXAM_SUGGESTED").format({"count": completed_learn})
	exam_suggestion_label.visible = suggested
	menu_page.visible = false
	setup_page.visible = true
	settings_page.visible = false
	_focus(start_button)


func exam_suggested() -> bool:
	return SessionSetup.suggests_exam(completed_learn, menu_config)


func select_mode(mode: StringName) -> void:
	selected_mode = mode
	mode_buttons[mode].button_pressed = true
	mode_hint_label.text = tr(MODE_HINT_KEYS[mode])
	_show_choice()


func select_profile(profile: StringName) -> void:
	selected_profile = profile
	profile_buttons[profile].button_pressed = true
	_show_choice()


func select_level(level: int) -> void:
	selected_level = level
	level_buttons[level].button_pressed = true
	_show_choice()


## "Wybrano: Nauka · Autostrada · poziom 1"; empty until all three are chosen.
func _show_choice() -> void:
	var profile: RoadProfile = launcher_config.find_profile(selected_profile)
	if profile == null or launcher_config.find_level(selected_level) == null:
		choice_label.text = ""
		return
	choice_label.text = tr(&"SETUP_CHOICE").format({"choice": tr(&"HISTORY_COMBINATION").format({
		"mode": tr(MODE_KEYS[selected_mode]),
		"profile": tr(profile.display_name_key),
		"level": selected_level,
	})})


## Opens the settings showing the saved quality and mirrors and the window's mode.
func show_settings() -> void:
	quality_buttons[settings.quality].button_pressed = true
	mirrors_buttons[settings.mirrors].button_pressed = true
	_show_window_mode()
	# Said up front when nothing could last, not only after a change.
	settings_save_failed_label.visible = not settings.can_save()
	menu_page.visible = false
	setup_page.visible = false
	settings_page.visible = true
	_focus(settings_back_button)


## Chooses the graphics quality for the next sessions and saves it.
func select_quality(id: StringName) -> void:
	quality_buttons[id].button_pressed = true
	_show_saved(settings.set_quality(id))
	_show_setting_choices()


## Shows or hides the mirrors in the next sessions and saves it.
func select_mirrors(shown: bool) -> void:
	mirrors_buttons[shown].button_pressed = true
	_show_saved(settings.set_mirrors(shown))
	_show_setting_choices()


## Switches between fullscreen and a window, now.
func select_fullscreen(fullscreen: bool) -> void:
	display_buttons[fullscreen].button_pressed = true
	set_fullscreen.call(fullscreen)
	_show_setting_choices()


## The keys of `action` in words: "W lub Strzałka w górę".
func key_text(action: StringName) -> String:
	var names: PackedStringArray = []
	for key_name: String in KeyBindings.key_names(action):
		var label_key: StringName = KeyBindings.key_label_key(key_name)
		var translated: String = tr(label_key)
		names.append(key_name if translated == String(label_key) else translated)
	return tr(&"SETTINGS_KEY_SEPARATOR").join(names)


## Translation key of the quality preset's name (`SETTINGS_QUALITY_LOW`).
static func quality_label_key(id: StringName) -> StringName:
	return StringName(QUALITY_KEY_PREFIX + String(id).to_upper())


## Selects fullscreen or window as the window is now — it also changes outside the page
## (the browser's Esc, F11), which resizes the viewport.
func _show_window_mode() -> void:
	display_buttons[is_fullscreen.call()].button_pressed = true
	_show_setting_choices()


## Each setting's heading names its current choice ("Jakość grafiki: Niska"), so the
## selection never shows by shade alone.
func _show_setting_choices() -> void:
	for heading: Label in setting_headings:
		var group: ButtonGroup = setting_headings[heading]
		var pressed: BaseButton = group.get_pressed_button()
		heading.text = tr(heading_keys[heading]) if pressed == null else tr(&"SETTINGS_CURRENT").format({
			"setting": tr(heading_keys[heading]),
			"choice": (pressed as Button).text,
		})


func _on_viewport_size_changed() -> void:
	if settings_page.visible:
		_show_window_mode()


func _show_saved(saved: bool) -> void:
	settings_save_failed_label.visible = not saved


## Starts the chosen session with the quality and mirrors from the settings; the drive
## opens with the 3-2-1 countdown. Pressing Start is the player's gesture, so sound may
## play from the countdown on.
func start() -> void:
	AudioView.run_unlocked = true
	start_session.call(SessionSetup.options_for(
			selected_mode, selected_profile, selected_level, launcher_config, randi(), settings))


func _build() -> void:
	name = "StartScreen"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background: ColorRect = ColorRect.new()
	background.name = "Background"
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margins: MarginContainer = MarginContainer.new()
	margins.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(margins)
	var pages: Control = Control.new()
	pages.name = "Pages"
	margins.add_child(pages)
	menu_page = _page("Menu")
	pages.add_child(menu_page)
	_build_menu()
	setup_page = _page("Setup")
	pages.add_child(setup_page)
	_build_setup()
	settings_page = _page("Settings")
	pages.add_child(settings_page)
	_build_settings()


func _build_menu() -> void:
	menu_page.alignment = BoxContainer.ALIGNMENT_CENTER
	var title: Label = _label("Title", TITLE_FONT_SIZE, &"START_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_page.add_child(title)
	var subtitle: Label = _wrapped("Subtitle", TEXT_FONT_SIZE, &"START_SUBTITLE")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_page.add_child(subtitle)
	var buttons: VBoxContainer = VBoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override("separation", ROW_SEPARATION)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_page.add_child(buttons)
	new_session_button = _button("NewSession", tr(&"START_NEW_SESSION"), MENU_BUTTON_SIZE)
	new_session_button.pressed.connect(show_setup)
	buttons.add_child(new_session_button)
	history_button = _button("History", tr(&"START_HISTORY"), MENU_BUTTON_SIZE)
	history_button.pressed.connect(func() -> void: open_scene.call(AppFlow.HISTORY_SCENE))
	buttons.add_child(history_button)
	settings_button = _button("Settings", tr(&"START_SETTINGS"), MENU_BUTTON_SIZE)
	settings_button.pressed.connect(show_settings)
	buttons.add_child(settings_button)
	tutorial_button = _button("Tutorial", tr(&"START_TUTORIAL"), MENU_BUTTON_SIZE)
	tutorial_button.pressed.connect(start_tutorial)
	buttons.add_child(tutorial_button)
	tutorial_suggestion_label = _wrapped("TutorialSuggestion", TEXT_FONT_SIZE, &"START_TUTORIAL_SUGGESTED")
	tutorial_suggestion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_suggestion_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tutorial_suggestion_label.add_theme_color_override("font_color", SUGGESTION_COLOR)
	tutorial_suggestion_label.visible = false
	menu_page.add_child(tutorial_suggestion_label)
	legal_note_label = _wrapped("LegalNote", NOTE_FONT_SIZE, &"START_LEGAL_NOTE")
	legal_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legal_note_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_page.add_child(legal_note_label)


func _build_setup() -> void:
	setup_page.add_child(_label("Title", TITLE_FONT_SIZE, &"SETUP_TITLE"))

	setup_page.add_child(_label("ModeHeading", HEADING_FONT_SIZE, &"SETUP_MODE"))
	var modes: HBoxContainer = _row("Modes")
	setup_page.add_child(modes)
	var mode_group: ButtonGroup = ButtonGroup.new()
	for mode: StringName in LaunchOptions.MODES:
		var button: Button = _option("Mode_" + mode, tr(MODE_KEYS[mode]), mode_group)
		button.pressed.connect(select_mode.bind(mode))
		modes.add_child(button)
		mode_buttons[mode] = button
	mode_hint_label = _wrapped("ModeHint", TEXT_FONT_SIZE, &"")
	setup_page.add_child(mode_hint_label)
	exam_suggestion_label = _wrapped("ExamSuggestion", TEXT_FONT_SIZE, &"")
	exam_suggestion_label.add_theme_color_override("font_color", SUGGESTION_COLOR)
	exam_suggestion_label.visible = false
	setup_page.add_child(exam_suggestion_label)

	setup_page.add_child(_label("RoadHeading", HEADING_FONT_SIZE, &"SETUP_ROAD"))
	var profiles: HBoxContainer = _row("Profiles")
	setup_page.add_child(profiles)
	var profile_group: ButtonGroup = ButtonGroup.new()
	for profile: RoadProfile in launcher_config.profiles:
		var button: Button = _option("Profile_" + profile.id, tr(profile.display_name_key), profile_group)
		button.pressed.connect(select_profile.bind(profile.id))
		profiles.add_child(button)
		profile_buttons[profile.id] = button

	setup_page.add_child(_label("LevelHeading", HEADING_FONT_SIZE, &"SETUP_LEVEL"))
	var levels: HBoxContainer = _row("Levels")
	setup_page.add_child(levels)
	var level_group: ButtonGroup = ButtonGroup.new()
	var recommended: int = SessionSetup.recommended_level(launcher_config)
	for level: DifficultyLevel in launcher_config.levels:
		var entry: String = tr(&"SETUP_LEVEL_ENTRY").format({"level": level.id, "name": tr(level.display_name_key)})
		# Highlighted in words, not by colour alone.
		var button: Button = _option("Level_%d" % level.id, _option_text(entry, level.id == recommended), level_group)
		button.pressed.connect(select_level.bind(level.id))
		levels.add_child(button)
		level_buttons[level.id] = button

	choice_label = _label("Choice", HEADING_FONT_SIZE, &"")
	setup_page.add_child(choice_label)
	var actions: HBoxContainer = _row("Actions")
	setup_page.add_child(actions)
	back_button = _button("Back", tr(&"SETUP_BACK"), OPTION_BUTTON_SIZE)
	back_button.pressed.connect(show_menu)
	actions.add_child(back_button)
	start_button = _button("Start", tr(&"SETUP_START"), OPTION_BUTTON_SIZE)
	start_button.pressed.connect(start)
	actions.add_child(start_button)


## Two columns: quality, mirrors and the notes on the left, the key bindings and the
## window on the right — at 1280×720 everything fits without scrolling.
func _build_settings() -> void:
	settings_page.add_child(_label("Title", TITLE_FONT_SIZE, &"SETTINGS_TITLE"))
	var columns: HBoxContainer = _row("Columns")
	columns.add_theme_constant_override("separation", MARGIN)
	settings_page.add_child(columns)

	var choices: VBoxContainer = _column("Choices")
	columns.add_child(choices)
	var quality_group: ButtonGroup = ButtonGroup.new()
	_setting_heading(choices, "QualityHeading", &"SETTINGS_QUALITY", quality_group)
	var qualities: HBoxContainer = _row("Qualities")
	choices.add_child(qualities)
	for preset: QualityPreset in launcher_config.quality_presets:
		var button: Button = _option("Quality_" + preset.id, tr(quality_label_key(preset.id)), quality_group)
		button.pressed.connect(select_quality.bind(preset.id))
		qualities.add_child(button)
		quality_buttons[preset.id] = button
	choices.add_child(_note("QualityHint", &"SETTINGS_QUALITY_HINT"))
	_switch(choices, "Mirrors", &"SETTINGS_MIRRORS", mirrors_buttons, &"SETTINGS_ON", &"SETTINGS_OFF", select_mirrors)
	choices.add_child(_note("NextSession", &"SETTINGS_NEXT_SESSION"))
	settings_save_failed_label = _note("SaveFailed", &"SETTINGS_SAVE_FAILED")
	settings_save_failed_label.add_theme_color_override("font_color", WARNING_COLOR)
	settings_save_failed_label.visible = false
	choices.add_child(settings_save_failed_label)

	var keys: VBoxContainer = _column("Keys")
	columns.add_child(keys)
	keys.add_child(_label("KeysHeading", HEADING_FONT_SIZE, &"SETTINGS_KEYS"))
	keys.add_child(_note("KeysHint", &"SETTINGS_KEYS_HINT"))
	# Labels only: the preview has nothing to press, so no key can be changed here.
	var grid: GridContainer = GridContainer.new()
	grid.name = "Bindings"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", ROW_SEPARATION)
	grid.add_theme_constant_override("v_separation", KEY_ROW_SEPARATION)
	keys.add_child(grid)
	for action: StringName in KeyBindings.actions():
		var name_label: Label = _label("Action_" + action, TEXT_FONT_SIZE, KeyBindings.action_label_key(action))
		name_label.custom_minimum_size = Vector2(KEY_ACTION_WIDTH, 0.0)
		grid.add_child(name_label)
		var keys_label: Label = _label("Keys_" + action, TEXT_FONT_SIZE, &"")
		keys_label.text = key_text(action)
		grid.add_child(keys_label)
		key_labels[action] = keys_label
	_switch(keys, "Display", &"SETTINGS_DISPLAY", display_buttons, &"SETTINGS_FULLSCREEN",
			&"SETTINGS_WINDOWED", select_fullscreen)

	settings_back_button = _button("Back", tr(&"SETUP_BACK"), OPTION_BUTTON_SIZE)
	settings_back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	settings_back_button.pressed.connect(show_menu)
	settings_page.add_child(settings_back_button)


## A yes/no setting under `parent`: its heading, then its two options, the `true` one
## first; fills `buttons` by value.
func _switch(parent: Container, node_name: String, heading_key: StringName,
		buttons: Dictionary[bool, Button], on_key: StringName, off_key: StringName,
		select: Callable) -> void:
	var group: ButtonGroup = ButtonGroup.new()
	_setting_heading(parent, node_name + "Heading", heading_key, group)
	var row: HBoxContainer = _row(node_name)
	parent.add_child(row)
	for value: bool in [true, false]:
		var button: Button = _option(node_name + ("_On" if value else "_Off"),
				tr(on_key if value else off_key), group)
		button.pressed.connect(select.bind(value))
		row.add_child(button)
		buttons[value] = button


## A setting's heading under `parent`; it names the choice pressed in `group`.
func _setting_heading(parent: Container, node_name: String, key: StringName, group: ButtonGroup) -> void:
	var heading: Label = _label(node_name, HEADING_FONT_SIZE, key)
	parent.add_child(heading)
	setting_headings[heading] = group
	heading_keys[heading] = key


func _column(node_name: String) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = node_name
	column.add_theme_constant_override("separation", SEPARATION)
	column.custom_minimum_size = Vector2(SETTINGS_COLUMN_WIDTH, 0.0)
	return column


## A wrapped note of a settings column.
func _note(node_name: String, key: StringName) -> Label:
	var label: Label = _label(node_name, NOTE_FONT_SIZE, key)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(SETTINGS_COLUMN_WIDTH, 0.0)
	return label


## `text` with the "(polecany)" mark when `suggested`.
func _option_text(text: String, suggested: bool) -> String:
	return tr(&"SETUP_SUGGESTED").format({"name": text}) if suggested else text


func _focus(button: Button) -> void:
	if button.is_inside_tree() and button.is_visible_in_tree():
		button.grab_focus()


func _page(node_name: String) -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.name = node_name
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", SEPARATION)
	return page


func _row(node_name: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = node_name
	row.add_theme_constant_override("separation", ROW_SEPARATION)
	return row


## A menu entry that does not work yet: visible, disabled and saying so.
func _coming_soon(node_name: String, key: StringName) -> Button:
	var button: Button = _button(node_name, tr(&"START_COMING_SOON").format({"entry": tr(key)}), MENU_BUTTON_SIZE)
	button.disabled = true
	return button


## One choice of a group; the pressed one is the selection.
func _option(node_name: String, text: String, group: ButtonGroup) -> Button:
	var button: Button = _button(node_name, text, OPTION_BUTTON_SIZE)
	button.toggle_mode = true
	button.button_group = group
	return button


func _button(node_name: String, text: String, min_size: Vector2) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	return button


func _wrapped(node_name: String, font_size: int, key: StringName) -> Label:
	var label: Label = _label(node_name, font_size, key)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(TEXT_WIDTH, 0.0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return label


func _label(node_name: String, font_size: int, key: StringName) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = tr(key) if key != &"" else ""
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label
