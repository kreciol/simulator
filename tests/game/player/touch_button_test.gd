extends GdUnitTestSuite
## One on-screen touch button (issue #86): pointers held by touch index or the real
## mouse press its action once and release it after the last one; the emulated mouse
## copy of a touch is swallowed; a cancelled touch lets go.

var _config: TouchConfig
var _events: Array[InputEventAction] = []


func before_test() -> void:
	_config = load("res://config/touch.tres") as TouchConfig
	_events.clear()


func _button(action: StringName = &"accelerate") -> TouchButton:
	var spec: TouchButtonSpec = TouchButtonSpec.new()
	spec.action = action
	spec.icon = &"up"
	spec.size = Vector2(100.0, 100.0)
	var button: TouchButton = auto_free(TouchButton.create(spec, _config))
	button.size = spec.size
	button.sink = func(event: InputEvent) -> void: _events.append(event as InputEventAction)
	return button


func _touch(index: int, pressed: bool, canceled: bool = false) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.canceled = canceled
	event.position = Vector2(50.0, 50.0)
	return event


func _mouse(pressed: bool, device: int = 0) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.device = device
	event.position = Vector2(50.0, 50.0)
	return event


func _pressed_log() -> Array[bool]:
	var pressed: Array[bool] = []
	for event: InputEventAction in _events:
		pressed.append(event.pressed)
	return pressed


func test_a_touch_presses_the_action_until_lifted() -> void:
	var button: TouchButton = _button()
	button._gui_input(_touch(0, true))
	assert_bool(button.is_held()).is_true()
	assert_int(_events.size()).is_equal(1)
	assert_str(_events[0].action).is_equal(&"accelerate")
	assert_bool(_events[0].pressed).is_true()
	button._gui_input(_touch(0, false))
	assert_bool(button.is_held()).is_false()
	assert_array(_pressed_log()).is_equal([true, false])


func test_two_fingers_release_only_after_the_last() -> void:
	var button: TouchButton = _button()
	button._gui_input(_touch(0, true))
	button._gui_input(_touch(1, true))
	button._gui_input(_touch(0, false))
	assert_bool(button.is_held()).is_true()
	assert_array(_pressed_log()).is_equal([true])
	button._gui_input(_touch(1, false))
	assert_array(_pressed_log()).is_equal([true, false])


func test_a_cancelled_touch_lets_go() -> void:
	var button: TouchButton = _button()
	button._gui_input(_touch(0, true))
	button._gui_input(_touch(0, false, true))
	assert_bool(button.is_held()).is_false()
	assert_array(_pressed_log()).is_equal([true, false])


func test_a_release_without_a_press_is_ignored() -> void:
	var button: TouchButton = _button()
	button._gui_input(_touch(3, false))
	assert_array(_events).is_empty()


func test_the_real_mouse_holds_it() -> void:
	var button: TouchButton = _button()
	button._gui_input(_mouse(true))
	assert_bool(button.is_held()).is_true()
	button._gui_input(_mouse(false))
	assert_array(_pressed_log()).is_equal([true, false])


func test_the_mouse_emulated_from_a_touch_is_ignored() -> void:
	var button: TouchButton = _button()
	button._gui_input(_touch(0, true))
	button._gui_input(_mouse(true, InputEvent.DEVICE_ID_EMULATION))
	button._gui_input(_mouse(false, InputEvent.DEVICE_ID_EMULATION))
	assert_bool(button.is_held()).is_true()
	assert_array(_pressed_log()).is_equal([true])


func test_release_all_lets_go_once() -> void:
	var button: TouchButton = _button()
	button._gui_input(_touch(0, true))
	button._gui_input(_mouse(true))
	button.release_all()
	button.release_all()
	assert_bool(button.is_held()).is_false()
	assert_array(_pressed_log()).is_equal([true, false])


func test_the_gui_routes_each_touch_index_to_its_button() -> void:
	# Engine behaviour the overlay relies on: a second finger reaches another control
	# while the first keeps holding its own. A viewport of its own, so nothing of the
	# test runner's sits over the buttons.
	var viewport: SubViewport = auto_free(SubViewport.new())
	viewport.size = Vector2i(400, 200)
	add_child(viewport)
	var gas: TouchButton = _button(&"accelerate")
	var signal_left: TouchButton = _button(&"signal_left")
	signal_left.position = Vector2(200.0, 0.0)
	viewport.add_child(gas)
	viewport.add_child(signal_left)
	await get_tree().process_frame
	viewport.push_input(_touch(0, true))
	var second: InputEventScreenTouch = _touch(1, true)
	second.position = Vector2(250.0, 50.0)
	viewport.push_input(second)
	assert_bool(gas.is_held()).is_true()
	assert_bool(signal_left.is_held()).is_true()
	var second_up: InputEventScreenTouch = _touch(1, false)
	second_up.position = Vector2(250.0, 50.0)
	viewport.push_input(second_up)
	assert_bool(gas.is_held()).is_true()
	assert_bool(signal_left.is_held()).is_false()


func test_config_has_one_sized_button_per_driving_action_and_pause() -> void:
	var actions: Array[StringName] = []
	for spec: TouchButtonSpec in _config.buttons:
		actions.append(spec.action)
		assert_bool(InputMap.has_action(spec.action)).is_true()
		assert_float(spec.size.x).is_greater(0.0)
		assert_float(spec.size.y).is_greater(0.0)
	assert_array(actions).contains_exactly_in_any_order([&"accelerate", &"brake", &"lane_left",
			&"lane_right", &"signal_left", &"signal_right", &"pause"])
	assert_float(_config.reference_height_px).is_greater(0.0)
