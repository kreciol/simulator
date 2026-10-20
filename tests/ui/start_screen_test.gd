extends GdUnitTestSuite
## The start screen and the new-session setup (issue #43 acceptance criteria,
## requirements §9.1, §9.4, Q14): the menu's entries and the educational note, learn
## mode and the recommended level by default, every level selectable, the exam
## suggested only after 3 completed learn sessions, and Start beginning the session.

var _screen: StartScreen
var _opened: Array[String] = []
var _started: Array[LaunchOptions] = []


func before_test() -> void:
	_opened.clear()
	_started.clear()


func _make(completed_learn: int = 0, tutorial_seen: bool = false) -> StartScreen:
	_screen = auto_free(StartScreen.new()) as StartScreen
	_screen.launcher_config = load("res://config/dev_launcher.tres") as DevLauncherConfig
	_screen.menu_config = load("res://config/menu.tres") as MenuConfig
	_screen.completed_learn = completed_learn
	_screen.tutorial_seen = tutorial_seen
	_screen.open_scene = func(path: String) -> void: _opened.append(path)
	_screen.start_session = func(options: LaunchOptions) -> void: _started.append(options)
	add_child(_screen)
	return _screen


func test_the_menu_offers_every_entry_and_the_educational_note() -> void:
	var screen: StartScreen = _make()
	assert_bool(screen.menu_page.visible).is_true()
	assert_bool(screen.setup_page.visible).is_false()
	assert_str(screen.new_session_button.text).is_equal("Nowa sesja")
	assert_str(screen.history_button.text).is_equal("Historia wyników")
	assert_str(screen.settings_button.text).starts_with("Ustawienia")
	assert_str(screen.tutorial_button.text).starts_with("Samouczek")
	assert_bool(screen.legal_note_label.visible).is_true()
	assert_str(screen.legal_note_label.text).contains("narzędzie edukacyjne")
	assert_str(screen.legal_note_label.text).contains("nie porada prawna")


func test_settings_and_the_tutorial_are_available() -> void:
	var screen: StartScreen = _make()
	for button: Button in [screen.new_session_button, screen.history_button, screen.settings_button,
			screen.tutorial_button]:
		assert_bool(button.visible).is_true()
		assert_bool(button.disabled).is_false()
	assert_str(screen.settings_button.text).is_equal("Ustawienia")
	assert_str(screen.settings_button.text).not_contains("wkrótce")
	assert_str(screen.tutorial_button.text).not_contains("wkrótce")


func test_history_opens_the_history_screen() -> void:
	var screen: StartScreen = _make()
	screen.history_button.pressed.emit()
	assert_array(_opened).contains_exactly([AppFlow.HISTORY_SCENE])
	assert_array(_started).is_empty()


func test_new_session_opens_the_setup_with_learn_mode_and_the_recommended_level() -> void:
	var screen: StartScreen = _make()
	screen.new_session_button.pressed.emit()
	assert_bool(screen.setup_page.visible).is_true()
	assert_bool(screen.menu_page.visible).is_false()
	assert_str(screen.selected_mode).is_equal(LaunchOptions.MODE_LEARN)
	assert_bool(screen.mode_buttons[LaunchOptions.MODE_LEARN].button_pressed).is_true()
	assert_bool(screen.mode_buttons[LaunchOptions.MODE_EXAM].button_pressed).is_false()
	assert_str(screen.selected_profile).is_equal(&"motorway")
	assert_int(screen.selected_level).is_equal(1)
	assert_bool(screen.level_buttons[1].button_pressed).is_true()


func test_the_recommended_level_is_highlighted_in_words() -> void:
	var screen: StartScreen = _make()
	screen.show_setup()
	assert_str(screen.level_buttons[1].text).is_equal("1. Spokojny ruch (polecany)")
	for level: int in [2, 3, 4]:
		assert_str(screen.level_buttons[level].text).not_contains("polecany")


func test_all_four_levels_are_selectable() -> void:
	var screen: StartScreen = _make()
	screen.show_setup()
	assert_array(screen.level_buttons.keys()).contains_exactly([1, 2, 3, 4])
	for level: int in [1, 2, 3, 4]:
		var button: Button = screen.level_buttons[level]
		assert_bool(button.disabled).is_false()
		button.pressed.emit()
		assert_int(screen.selected_level).is_equal(level)


func test_both_road_profiles_are_offered() -> void:
	var screen: StartScreen = _make()
	screen.show_setup()
	assert_array(screen.profile_buttons.keys()).contains_exactly([&"motorway", &"expressway"])
	assert_str(screen.profile_buttons[&"expressway"].text).is_equal("Droga ekspresowa")


func test_the_exam_is_not_suggested_before_three_learn_sessions(completed: int,
		test_parameters: Array = [[0], [1], [2]]) -> void:
	var screen: StartScreen = _make(completed)
	screen.show_setup()
	assert_bool(screen.exam_suggestion_label.visible).is_false()
	assert_str(screen.mode_buttons[LaunchOptions.MODE_EXAM].text).is_equal("Egzamin")


func test_the_exam_is_suggested_from_three_learn_sessions_but_learn_stays_selected() -> void:
	var screen: StartScreen = _make(3)
	screen.show_setup()
	assert_bool(screen.exam_suggestion_label.visible).is_true()
	assert_str(screen.exam_suggestion_label.text).contains("3")
	assert_str(screen.mode_buttons[LaunchOptions.MODE_EXAM].text).is_equal("Egzamin (polecany)")
	assert_str(screen.selected_mode).is_equal(LaunchOptions.MODE_LEARN)


func test_choosing_a_mode_explains_it() -> void:
	var screen: StartScreen = _make()
	screen.show_setup()
	assert_str(screen.mode_hint_label.text).starts_with("Nauka:")
	screen.mode_buttons[LaunchOptions.MODE_EXAM].pressed.emit()
	assert_str(screen.selected_mode).is_equal(LaunchOptions.MODE_EXAM)
	assert_str(screen.mode_hint_label.text).starts_with("Egzamin:")


func test_start_begins_the_chosen_session() -> void:
	var screen: StartScreen = _make()
	screen.show_setup()
	screen.mode_buttons[LaunchOptions.MODE_EXAM].pressed.emit()
	screen.profile_buttons[&"expressway"].pressed.emit()
	screen.level_buttons[3].pressed.emit()
	screen.start_button.pressed.emit()
	assert_int(_started.size()).is_equal(1)
	var options: LaunchOptions = _started[0]
	assert_str(options.mode).is_equal(LaunchOptions.MODE_EXAM)
	assert_str(options.profile.id).is_equal(&"expressway")
	assert_int(options.level).is_equal(3)
	assert_int(options.difficulty.id).is_equal(3)
	assert_str(options.screen).is_equal(LaunchOptions.SCREEN_DRIVE)


func test_back_returns_to_the_menu() -> void:
	var screen: StartScreen = _make()
	screen.show_setup()
	screen.back_button.pressed.emit()
	assert_bool(screen.menu_page.visible).is_true()
	assert_bool(screen.setup_page.visible).is_false()
	assert_array(_started).is_empty()


func test_reopening_the_setup_resets_the_defaults() -> void:
	var screen: StartScreen = _make()
	screen.show_setup()
	screen.mode_buttons[LaunchOptions.MODE_EXAM].pressed.emit()
	screen.level_buttons[4].pressed.emit()
	screen.show_menu()
	screen.show_setup()
	assert_str(screen.selected_mode).is_equal(LaunchOptions.MODE_LEARN)
	assert_int(screen.selected_level).is_equal(1)


func test_launch_params_start_a_session_directly() -> void:
	var screen: StartScreen = _make()
	var options: LaunchOptions = DevLauncher.resolve(DevLauncher.parse_query("?mode=exam&level=2&seed=9"),
			screen.launcher_config, 1)
	screen._launch(options)
	assert_array(_started).contains_exactly([options])
	assert_array(_opened).is_empty()


func test_launch_param_screen_history_opens_the_history_screen() -> void:
	var screen: StartScreen = _make()
	screen._launch(DevLauncher.resolve(DevLauncher.parse_query("?screen=history"), screen.launcher_config, 1))
	assert_array(_opened).contains_exactly([AppFlow.HISTORY_SCENE])
	assert_array(_started).is_empty()


func test_the_scene_reads_the_platform_state() -> void:
	var scene: StartScreen = (load(AppFlow.START_SCENE) as PackedScene).instantiate() as StartScreen
	assert_bool(scene.use_platform_state).is_true()
	assert_object(scene.launcher_config).is_not_null()
	assert_object(scene.menu_config).is_not_null()
	scene.free()


func test_without_launch_params_the_scene_shows_the_menu() -> void:
	# The headless test run passes no user args.
	var was_read: bool = DevLauncher.params_taken
	DevLauncher.params_taken = false
	var scene: StartScreen = (load(AppFlow.START_SCENE) as PackedScene).instantiate() as StartScreen
	scene.open_scene = func(path: String) -> void: _opened.append(path)
	scene.start_session = func(options: LaunchOptions) -> void: _started.append(options)
	add_child(auto_free(scene))
	assert_bool(DevLauncher.params_taken).is_true()
	assert_bool(scene.menu_page.visible).is_true()
	assert_int(scene.completed_learn).is_equal(
			SessionSetup.completed_learn_sessions(SaveManager.store.sessions))
	assert_array(_started).is_empty()
	assert_array(_opened).is_empty()
	DevLauncher.params_taken = was_read


func test_launch_params_are_followed_once_per_run() -> void:
	# Coming back to the menu must not bounce into the URL's session again.
	var was_read: bool = DevLauncher.params_taken
	DevLauncher.params_taken = true
	var scene: StartScreen = (load(AppFlow.START_SCENE) as PackedScene).instantiate() as StartScreen
	scene.start_session = func(options: LaunchOptions) -> void: _started.append(options)
	add_child(auto_free(scene))
	assert_bool(scene.menu_page.visible).is_true()
	assert_array(_started).is_empty()
	DevLauncher.params_taken = was_read


func test_the_choice_is_written_out_not_shown_by_shade_alone() -> void:
	var screen: StartScreen = _make()
	screen.show_setup()
	assert_str(screen.choice_label.text).is_equal("Wybrano: Nauka · Autostrada · poziom 1")
	screen.mode_buttons[LaunchOptions.MODE_EXAM].pressed.emit()
	screen.profile_buttons[&"expressway"].pressed.emit()
	screen.level_buttons[4].pressed.emit()
	assert_str(screen.choice_label.text).is_equal("Wybrano: Egzamin · Droga ekspresowa · poziom 4")


func test_esc_on_the_setup_returns_to_the_menu() -> void:
	var screen: StartScreen = _make()
	screen.show_setup()
	var esc: InputEventKey = InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	screen._unhandled_input(esc)
	assert_bool(screen.menu_page.visible).is_true()
	assert_array(_started).is_empty()


func test_start_counts_as_the_gesture_that_lets_sound_play() -> void:
	AudioView.reset_run()
	var screen: StartScreen = _make()
	screen.show_setup()
	screen.start_button.pressed.emit()
	assert_bool(AudioView.run_unlocked).is_true()
	AudioView.reset_run()


func test_on_first_launch_the_tutorial_is_suggested() -> void:
	# Issue #45: the tutorial is suggested when the start screen first opens.
	var screen: StartScreen = _make()
	assert_bool(screen.tutorial_suggested()).is_true()
	assert_str(screen.tutorial_button.text).is_equal("Samouczek (polecany)")
	assert_bool(screen.tutorial_suggestion_label.visible).is_true()
	assert_str(screen.tutorial_suggestion_label.text).contains("samouczka")
	await get_tree().process_frame
	assert_bool(screen.tutorial_button.has_focus()).is_true()


func test_once_seen_the_tutorial_is_no_longer_suggested() -> void:
	var screen: StartScreen = _make(0, true)
	assert_bool(screen.tutorial_suggested()).is_false()
	assert_str(screen.tutorial_button.text).is_equal("Samouczek")
	assert_bool(screen.tutorial_suggestion_label.visible).is_false()
	assert_bool(screen.tutorial_button.disabled).is_false()
	await get_tree().process_frame
	assert_bool(screen.new_session_button.has_focus()).is_true()


func test_the_tutorial_entry_starts_the_tutorial_and_can_be_rerun() -> void:
	# Issue #45: it can be (re-)run from the menu, seen or not.
	for seen: bool in [false, true]:
		_started.clear()
		var screen: StartScreen = _make(0, seen)
		screen.tutorial_button.pressed.emit()
		assert_int(_started.size()).is_equal(1)
		assert_bool(_started[0].is_tutorial()).is_true()
		assert_str(_started[0].mode).is_equal(LaunchOptions.MODE_LEARN)
		assert_array(_opened).is_empty()
