extends GdUnitTestSuite
## The drive on a phone (issue #87 acceptance criteria): held upright a touch device
## shows the rotate notice and the session pauses until the player resumes it in
## landscape; with touch buttons the tutorial names them and completes on them; the HUD
## is laid out around the buttons inside the safe area; a desktop keeps its keys.

const DT: float = 1.0 / 60.0
const MAIN_SCENE: String = "res://game/main.tscn"
const SEED: int = 1
const PORTRAIT: Vector2 = Vector2(1280.0, 2767.0)
const LANDSCAPE: Vector2 = Vector2(1558.0, 720.0)
## Bounds a wait for the tutorial's next step.
const MAX_STEPS: int = 600
const ACTIONS: Array[StringName] = [&"accelerate", &"brake", &"lane_left", &"lane_right",
		&"signal_left", &"signal_right", &"pause"]

var _real_settings: SettingsStore


func before_test() -> void:
	_real_settings = SaveManager.settings
	SaveManager.settings = SettingsStore.new("", load("res://config/dev_launcher.tres") as DevLauncherConfig)


func after_test() -> void:
	SaveManager.settings = _real_settings
	TouchControls.run_shown = false
	# The buttons go through the real `Input`: never leave an action held for the next test.
	for action: StringName in ACTIONS:
		Input.action_release(action)


func _main(query: String, touchscreen: bool = false) -> DriveScene:
	var launcher: DevLauncherConfig = load("res://config/dev_launcher.tres") as DevLauncherConfig
	var main: DriveScene = (load(MAIN_SCENE) as PackedScene).instantiate() as DriveScene
	main.launch_options = DevLauncher.resolve(DevLauncher.parse_query(query), launcher, SEED)
	main.touchscreen_available = func() -> bool: return touchscreen
	main.change_scene = func(_path: String) -> void: pass
	main.start_session = func(_options: LaunchOptions) -> void: pass
	add_child(auto_free(main))
	return main


func _hud(main: DriveScene) -> Hud:
	return main.get_node("Hud") as Hud


func _finish_countdown(main: DriveScene) -> void:
	while main.session.state == SessionManager.State.INTRO:
		main.session.step(DT, PlayerCommands.new())


func _drive(main: DriveScene, steps: int) -> void:
	for i: int in steps:
		main._physics_process(DT)


## Turns the device: the canvas becomes `screen` and the notice checks it.
func _turn(main: DriveScene, screen: Vector2) -> void:
	main.rotate_notice.screen_size = func() -> Vector2: return screen
	main.rotate_notice.refresh()


func _finger(main: DriveScene, action: StringName, pressed: bool) -> void:
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = pressed
	main.touch_controls.button_for(action)._gui_input(touch)
	Input.flush_buffered_events()


func _tap(main: DriveScene, action: StringName) -> void:
	_finger(main, action, true)
	_finger(main, action, false)


## Drives until the tutorial leaves `step`; returns whether it did.
func _drive_past(main: DriveScene, step: Tutorial.Step) -> bool:
	for i: int in MAX_STEPS:
		if main.session.tutorial.step != step:
			return true
		_drive(main, 1)
	return false


func test_held_upright_a_running_session_pauses_behind_the_rotate_notice() -> void:
	var main: DriveScene = _main("?touch=1")
	_finish_countdown(main)
	assert_bool(main.rotate_notice.visible).is_false()
	_turn(main, PORTRAIT)
	assert_bool(main.rotate_notice.visible).is_true()
	assert_bool(main.session.paused).is_true()
	# Nothing resumes it behind the notice, not even the pause key.
	main.session.toggle_pause()
	main._process(DT)
	assert_bool(main.session.paused).is_true()
	# Back in landscape the notice goes and the player resumes on purpose.
	_turn(main, LANDSCAPE)
	assert_bool(main.rotate_notice.visible).is_false()
	assert_bool(main.session.paused).is_true()
	_tap(main, &"pause")
	assert_bool(main.session.paused).is_false()
	assert_int(main.session.state).is_equal(SessionManager.State.DRIVING)


func test_the_rotate_notice_says_why_with_an_icon_and_text() -> void:
	var main: DriveScene = _main("", true)
	_turn(main, PORTRAIT)
	assert_bool(main.rotate_notice.visible).is_true()
	assert_str(main.rotate_notice.title_label.text).is_equal(tr(&"ROTATE_DEVICE"))
	assert_str(main.rotate_notice.title_label.text).is_not_equal("ROTATE_DEVICE")
	assert_str(main.rotate_notice.hint_label.text).is_equal(tr(&"ROTATE_DEVICE_HINT"))
	assert_object(main.rotate_notice.backdrop.find_child("Icon", true, false)).is_not_null()
	# It takes every touch, so no touch button beneath is pressed by accident.
	assert_int(main.rotate_notice.layer).is_greater(main.touch_controls.layer)
	assert_int(main.rotate_notice.backdrop.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)


func test_a_desktop_window_taller_than_wide_keeps_playing() -> void:
	var main: DriveScene = _main("")
	_finish_countdown(main)
	_turn(main, PORTRAIT)
	main._process(DT)
	assert_bool(main.rotate_notice.visible).is_false()
	assert_bool(main.session.paused).is_false()


func test_the_first_touch_lets_the_notice_show_upright() -> void:
	var main: DriveScene = _main("")
	_turn(main, PORTRAIT)
	assert_bool(main.rotate_notice.visible).is_false()
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	main._input(touch)
	assert_bool(main.rotate_notice.visible).is_true()


func test_by_touch_the_tutorial_names_each_button_and_completes_on_it() -> void:
	var main: DriveScene = _main("?screen=tutorial&touch=1")
	var hud: Hud = _hud(main)
	var tutorial: Tutorial = main.session.tutorial
	_finish_countdown(main)
	var labels: Dictionary[StringName, String] = {}
	for spec: TouchButtonSpec in main.touch_config.buttons:
		labels[spec.action] = tr(spec.label_key)
	for step: Tutorial.Step in Tutorial.STEPS:
		tutorial._begin_step(step)
		hud.update(main.session)
		assert_str(hud.tutorial_prompt_label.text).is_equal(tr(Tutorial.TOUCH_PROMPT_KEYS[step]))
		for action: StringName in tutorial.actions():
			assert_str(hud.tutorial_prompt_label.text).contains(labels[action])
		assert_int(hud.tutorial_icons.get_child_count()).is_equal(tutorial.actions().size())
		assert_bool(hud.tutorial_icons.visible).is_true()

	tutorial._begin_step(Tutorial.Step.ACCELERATE)
	_finger(main, &"accelerate", true)
	assert_bool(_drive_past(main, Tutorial.Step.ACCELERATE)).is_true()
	_finger(main, &"accelerate", false)
	_finger(main, &"brake", true)
	assert_bool(_drive_past(main, Tutorial.Step.SLOW_DOWN)).is_true()
	_finger(main, &"brake", false)
	_tap(main, &"signal_left")
	assert_bool(_drive_past(main, Tutorial.Step.SIGNAL)).is_true()
	_tap(main, &"lane_left")
	assert_bool(_drive_past(main, Tutorial.Step.CHANGE_LANE)).is_true()
	_tap(main, &"signal_right")
	_tap(main, &"lane_right")
	assert_bool(_drive_past(main, Tutorial.Step.RETURN_RIGHT)).is_true()
	assert_int(tutorial.step).is_equal(Tutorial.Step.CHECK_MIRRORS)


func test_by_keyboard_the_tutorial_keeps_naming_keys() -> void:
	var main: DriveScene = _main("?screen=tutorial")
	var hud: Hud = _hud(main)
	_finish_countdown(main)
	hud.update(main.session)
	assert_str(hud.tutorial_prompt_label.text).is_equal(tr(&"TUTORIAL_ACCELERATE"))
	assert_bool(hud.tutorial_icons.visible).is_false()
	assert_str(hud.paused_hint_label.text).is_equal(tr(&"SESSION_PAUSED_HINT"))


func test_the_hud_is_laid_out_around_the_buttons_and_for_a_finger() -> void:
	var main: DriveScene = _main("?touch=1")
	main.css_scale = func() -> float: return 0.5
	main.layout_screen()
	var hud: Hud = _hud(main)
	assert_object(hud.touch_config).is_same(main.touch_config)
	assert_float(hud.touch_target).is_equal_approx(main.touch_config.min_touch_target_px / 0.5, 0.001)
	assert_float(hud.again_button.custom_minimum_size.y).is_greater_equal(hud.touch_target)


func test_a_key_in_auto_puts_the_keyboard_layout_back() -> void:
	var main: DriveScene = _main("", true)
	assert_object(_hud(main).touch_config).is_not_null()
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	main._input(key)
	assert_object(_hud(main).touch_config).is_null()
	assert_vector(_hud(main).again_button.custom_minimum_size).is_equal(Hud.END_BUTTON_SIZE)


func test_buttons_and_hud_stay_inside_the_safe_area() -> void:
	var main: DriveScene = _main("?touch=1")
	var screen: Vector2 = main.get_viewport().get_visible_rect().size
	var area: Rect2 = Rect2(Vector2(60.0, 0.0), screen - Vector2(120.0, 30.0))
	main.safe_area = func() -> Rect2: return area
	main.layout_screen()
	await await_idle_frame()
	for button: TouchButton in main.touch_controls.buttons:
		assert_bool(area.grow(0.5).encloses(button.get_global_rect())).override_failure_message(button.name).is_true()
	var hud: Hud = _hud(main)
	assert_bool(area.grow(0.5).encloses(hud.score_panel.get_global_rect())).is_true()
	assert_bool(area.grow(0.5).encloses(hud.muted_indicator.get_global_rect())).is_true()
