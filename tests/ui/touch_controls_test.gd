extends GdUnitTestSuite
## When the touch buttons exist (issue #86, spec table) and how they are laid out.

const AUTO: StringName = LaunchOptions.TOUCH_AUTO
const ON: StringName = LaunchOptions.TOUCH_ON
const OFF: StringName = LaunchOptions.TOUCH_OFF
const TOLERANCE: Vector2 = Vector2(0.01, 0.01)


func test_built_at_start_when_forced_on_or_on_a_touch_device(
		touch: StringName, touchscreen: bool, expected: bool,
		test_parameters: Array = [
			[OFF, false, false], [OFF, true, false],
			[ON, false, true], [ON, true, true],
			[AUTO, false, false], [AUTO, true, true],
		]) -> void:
	assert_bool(TouchControls.builds_at_start(touch, touchscreen)).is_equal(expected)


func test_only_auto_follows_touches_and_keys() -> void:
	assert_bool(TouchControls.builds_on_touch(AUTO)).is_true()
	assert_bool(TouchControls.builds_on_touch(ON)).is_false()
	assert_bool(TouchControls.builds_on_touch(OFF)).is_false()
	assert_bool(TouchControls.hides_on_key(AUTO)).is_true()
	assert_bool(TouchControls.hides_on_key(ON)).is_false()


func test_buttons_sit_inside_the_viewport_and_scale_with_its_height() -> void:
	var config: TouchConfig = load("res://config/touch.tres") as TouchConfig
	var controls: TouchControls = auto_free(TouchControls.new())
	add_child(controls)
	controls.setup(config, func(_event: InputEvent) -> void: pass)
	var viewport_size: Vector2 = controls.get_viewport().get_visible_rect().size
	var ui_scale: float = viewport_size.y / config.reference_height_px
	for i: int in controls.buttons.size():
		var button: TouchButton = controls.buttons[i]
		assert_vector(button.size).is_equal_approx(config.buttons[i].size * ui_scale, TOLERANCE)
		assert_vector(button.position).is_equal_approx(
				config.buttons[i].anchor * viewport_size + config.buttons[i].offset * ui_scale, TOLERANCE)
	assert_int(controls.layer).is_greater(1)


func test_hiding_lets_go_of_held_buttons() -> void:
	var events: Array[InputEventAction] = []
	var controls: TouchControls = auto_free(TouchControls.new())
	add_child(controls)
	controls.setup(load("res://config/touch.tres") as TouchConfig,
			func(event: InputEvent) -> void: events.append(event as InputEventAction))
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	controls.button_for(&"accelerate")._gui_input(touch)
	controls.set_shown(false)
	assert_bool(controls.button_for(&"accelerate").is_held()).is_false()
	assert_int(events.size()).is_equal(2)
	assert_bool(events[1].pressed).is_false()
