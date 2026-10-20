extends GdUnitTestSuite
## The drive by touch (issue #86 acceptance criteria): on-screen buttons fire the Input
## Map actions through `Input`, like keys; they exist on a touch device or with
## `touch=1`, never on a desktop without touch, and in `auto` appear on the first touch
## and hide on a key press.

const DT: float = 1.0 / 60.0
const MAIN_SCENE: String = "res://game/main.tscn"
const SEED: int = 1
const TEST_HISTORY: String = "user://test_main_touch/history.json"

var _real_store: HistoryStore


func before_test() -> void:
	_real_store = SaveManager.store
	SaveManager.store = HistoryStore.new(TEST_HISTORY, 5)
	SaveManager.store.userfs_persistent = true


func after_test() -> void:
	SaveManager.store = _real_store
	# The buttons go through the real `Input`: never leave an action held for the next test.
	for action: StringName in [&"accelerate", &"brake", &"lane_left", &"lane_right",
			&"signal_left", &"signal_right", &"pause"]:
		Input.action_release(action)
	var dir: String = TEST_HISTORY.get_base_dir()
	if DirAccess.dir_exists_absolute(dir):
		for file_name: String in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file_name))
		DirAccess.remove_absolute(dir)


func _main(query: String, touchscreen: bool = false) -> DriveScene:
	var launcher: DevLauncherConfig = load("res://config/dev_launcher.tres") as DevLauncherConfig
	var main: DriveScene = (load(MAIN_SCENE) as PackedScene).instantiate() as DriveScene
	main.launch_options = DevLauncher.resolve(DevLauncher.parse_query(query), launcher, SEED)
	main.touchscreen_available = func() -> bool: return touchscreen
	add_child(auto_free(main))
	return main


func _finish_countdown(main: DriveScene) -> void:
	while main.session.state == SessionManager.State.INTRO:
		main.session.step(DT, PlayerCommands.new())


func _drive(main: DriveScene, steps: int) -> void:
	for i: int in steps:
		main._physics_process(DT)


func _button(main: DriveScene, action: StringName) -> TouchButton:
	return main.touch_controls.button_for(action)


## A finger (or the mouse, `index` -1) on `action`'s button, delivered through `Input`
## to the scene as on a device.
func _finger(main: DriveScene, action: StringName, pressed: bool, index: int = 0) -> void:
	var button: TouchButton = _button(main, action)
	if index == TouchButton.MOUSE_POINTER:
		var mouse: InputEventMouseButton = InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = pressed
		button._gui_input(mouse)
	else:
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.index = index
		touch.pressed = pressed
		button._gui_input(touch)
	Input.flush_buffered_events()


func _tap(main: DriveScene, action: StringName, index: int = 0) -> void:
	_finger(main, action, true, index)
	_finger(main, action, false, index)


func _key(main: DriveScene, key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	main._input(event)
	main._unhandled_input(event)


func test_no_touch_controls_on_a_desktop_without_touch() -> void:
	var main: DriveScene = _main("")
	assert_object(main.touch_controls).is_null()
	assert_object(main.find_child("TouchControls", true, false)).is_null()


func test_touch_0_builds_none_even_on_a_touch_device() -> void:
	var main: DriveScene = _main("?touch=0", true)
	assert_object(main.touch_controls).is_null()
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	main._input(touch)
	assert_object(main.touch_controls).is_null()


func test_a_touch_device_shows_them_at_start() -> void:
	var main: DriveScene = _main("", true)
	assert_object(main.touch_controls).is_not_null()
	assert_bool(main.touch_controls.visible).is_true()
	assert_int(main.touch_controls.buttons.size()).is_equal(main.touch_config.buttons.size())


func test_touch_1_shows_them_and_the_mouse_accelerates_like_the_key() -> void:
	var by_touch: DriveScene = _main("?touch=1")
	assert_bool(by_touch.touch_controls.visible).is_true()
	_finish_countdown(by_touch)
	_finger(by_touch, &"accelerate", true, TouchButton.MOUSE_POINTER)
	_drive(by_touch, 60)
	var touch_speed: float = by_touch.player.speed_mps
	# Released, it stops accelerating.
	_finger(by_touch, &"accelerate", false, TouchButton.MOUSE_POINTER)
	assert_int(by_touch._player_input.consume().longitudinal).is_equal(VehicleState.Longitudinal.NONE)
	remove_child(by_touch)
	var by_key: DriveScene = _main("?touch=0")
	_finish_countdown(by_key)
	_key(by_key, KEY_W, true)
	_drive(by_key, 60)
	_key(by_key, KEY_W, false)
	assert_float(touch_speed).is_greater(0.0)
	assert_float(touch_speed).is_equal(by_key.player.speed_mps)


func test_signal_and_lane_change_while_the_accelerator_is_held() -> void:
	var main: DriveScene = _main("?touch=1")
	_finish_countdown(main)
	var lane: int = main.player.lane
	_finger(main, &"accelerate", true, 0)
	_tap(main, &"signal_left", 1)
	_drive(main, 1)
	assert_int(main.player.signal_dir).is_equal(VehicleState.Dir.LEFT)
	_tap(main, &"lane_left", 2)
	_drive(main, 1)
	assert_bool(main.player.lane_change_active).is_true()
	assert_int(main.player.lane_change_to).is_equal(lane + 1)
	assert_bool(_button(main, &"accelerate").is_held()).is_true()
	assert_int(main._player_input.consume().longitudinal).is_equal(VehicleState.Longitudinal.ACCELERATE)
	_finger(main, &"accelerate", false, 0)


func test_a_lane_tap_requests_one_lane_change() -> void:
	var main: DriveScene = _main("?touch=1")
	_finish_countdown(main)
	_finger(main, &"lane_left", true)
	assert_int(main._player_input.consume().lane_change).is_equal(VehicleState.Dir.LEFT)
	assert_int(main._player_input.consume().lane_change).is_equal(VehicleState.Dir.NONE)
	_finger(main, &"lane_left", false)
	assert_int(main._player_input.consume().lane_change).is_equal(VehicleState.Dir.NONE)


func test_the_pause_button_pauses_and_resumes() -> void:
	var main: DriveScene = _main("?touch=1")
	_finish_countdown(main)
	_tap(main, &"pause")
	assert_bool(main.session.paused).is_true()
	assert_bool(main.touch_controls.visible).is_true()
	_tap(main, &"pause")
	assert_bool(main.session.paused).is_false()


func test_touches_in_the_countdown_are_dropped() -> void:
	var main: DriveScene = _main("?touch=1")
	var lane: int = main.player.lane
	_tap(main, &"lane_left")
	_tap(main, &"signal_left")
	# Stepped as the scene steps itself, so the countdown consumes (and drops) the taps.
	while main.session.state == SessionManager.State.INTRO:
		main._physics_process(DT)
	_drive(main, 1)
	assert_int(main.player.lane).is_equal(lane)
	assert_bool(main.player.lane_change_active).is_false()
	assert_int(main.player.signal_dir).is_equal(VehicleState.Dir.NONE)


func test_focus_loss_leaves_nothing_held() -> void:
	var main: DriveScene = _main("?touch=1")
	_finish_countdown(main)
	_finger(main, &"accelerate", true)
	main._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	Input.flush_buffered_events()
	assert_bool(_button(main, &"accelerate").is_held()).is_false()
	main.session.resume()
	assert_int(main._player_input.consume().longitudinal).is_equal(VehicleState.Longitudinal.NONE)


func test_auto_shows_on_the_first_touch_and_hides_on_a_key() -> void:
	var main: DriveScene = _main("")
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	main._input(touch)
	assert_object(main.touch_controls).is_not_null()
	assert_bool(main.touch_controls.visible).is_true()
	_finger(main, &"accelerate", true)
	_key(main, KEY_W, true)
	assert_bool(main.touch_controls.visible).is_false()
	# Hiding let go of the button; the key still holds the action.
	assert_bool(_button(main, &"accelerate").is_held()).is_false()
	Input.flush_buffered_events()
	assert_int(main._player_input.consume().longitudinal).is_equal(VehicleState.Longitudinal.ACCELERATE)
	_key(main, KEY_W, false)
	main._input(touch)
	assert_bool(main.touch_controls.visible).is_true()


func test_forced_on_they_stay_on_a_key_press() -> void:
	var main: DriveScene = _main("?touch=1")
	_key(main, KEY_W, true)
	assert_bool(main.touch_controls.visible).is_true()
	_key(main, KEY_W, false)


func test_the_end_screen_hides_them() -> void:
	var main: DriveScene = _main("?touch=1")
	_finish_countdown(main)
	while main.session.state != SessionManager.State.ENDED:
		main.session.step(1.0)
	main._process(DT)
	assert_bool(main.touch_controls.visible).is_false()


func test_a_seeded_replay_reproduces_a_touch_driven_session() -> void:
	var driven: DriveScene = _main("?touch=1&mode=exam")
	_finish_countdown(driven)
	var commands: Array[PlayerCommands] = []
	var script: Dictionary[int, Array] = {
		0: [&"accelerate", true], 30: [&"signal_left", true], 31: [&"signal_left", false],
		60: [&"lane_left", true], 61: [&"lane_left", false], 200: [&"brake", true],
		240: [&"brake", false],
	}
	for step: int in 300:
		if script.has(step):
			_finger(driven, script[step][0], script[step][1], 1 if script[step][0] != &"accelerate" else 0)
		var step_commands: PlayerCommands = driven._player_input.consume()
		commands.append(step_commands)
		driven.session.step(DT, step_commands)
	_finger(driven, &"accelerate", false)
	var replayed: DriveScene = _main("?touch=0&mode=exam")
	_finish_countdown(replayed)
	for step_commands: PlayerCommands in commands:
		replayed.session.step(DT, step_commands)
	assert_dict(replayed.sim.snapshot()).is_equal(driven.sim.snapshot())
	assert_float(driven.player.speed_mps).is_greater(0.0)
