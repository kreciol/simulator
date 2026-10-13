class_name StartScreen
extends Control
## The start screen and the new-session setup (requirements §9.1, §9.4, spec Phase 10
## step 1 and UI/UX flow, issue #43). The menu offers a new session, the history,
## settings and the tutorial — the last two shown but disabled until they exist
## (E11-S02, E11-S03) — with the "educational tool, not legal advice" note (spec Risks:
## teaching correctness). The setup picks mode · road profile · level: learn mode is
## selected, the recommended level is highlighted and every level is selectable (Q14),
## and after enough completed learn sessions the exam is marked as suggested
## (`SessionSetup`). Start begins the session with the 3-2-1 countdown.
## Dev-launcher params in the URL (user args on desktop) skip the menus and start the
## session (or the history screen) directly, once per run, so returning to the menu
## later does not bounce back into the same launch.
## Placeholder styling until the UI theme lands (Phase 10).

const MARGIN: int = 48
const SEPARATION: int = 12
const ROW_SEPARATION: int = 12
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
## Follows the launch params and reads `SaveManager`'s history once in the tree (the
## scene sets it); tests set `completed_learn` themselves.
@export var use_platform_state: bool = false

## Completed learn sessions in the saved history; decides the exam suggestion.
var completed_learn: int = 0
## Switches to another scene by path; tests replace it to watch instead.
var open_scene: Callable = func(path: String) -> void: AppFlow.open_scene(get_tree(), path)
## Starts a session with the given options; tests replace it to watch instead.
var start_session: Callable = func(options: LaunchOptions) -> void: AppFlow.start_session(get_tree(), options)

var menu_page: VBoxContainer
var new_session_button: Button
var history_button: Button
var settings_button: Button
var tutorial_button: Button
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
	_build()
	show_menu()


func _unhandled_input(event: InputEvent) -> void:
	# Esc on the setup goes back to the menu, as on the history screen.
	if setup_page != null and setup_page.visible and event.is_action_pressed(&"ui_cancel"):
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
	_focus(new_session_button)


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


## Starts the chosen session; the drive opens with the 3-2-1 countdown. Pressing Start
## is the player's gesture, so sound may play from the countdown on.
func start() -> void:
	AudioView.run_unlocked = true
	start_session.call(SessionSetup.options_for(
			selected_mode, selected_profile, selected_level, launcher_config, randi()))


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
	# Enabled once the settings screen (E11-S02) and the tutorial (E11-S03) exist.
	settings_button = _coming_soon("Settings", &"START_SETTINGS")
	buttons.add_child(settings_button)
	tutorial_button = _coming_soon("Tutorial", &"START_TUTORIAL")
	buttons.add_child(tutorial_button)
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
