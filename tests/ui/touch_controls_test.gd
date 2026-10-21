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


func test_the_layout_scales_with_the_relatively_smaller_side() -> void:
	var config: TouchConfig = load("res://config/touch.tres") as TouchConfig
	var reference: Vector2 = Vector2(config.reference_width_px, config.reference_height_px)
	assert_float(TouchControls.scale_for(reference, config)).is_equal_approx(1.0, 0.0001)
	assert_float(TouchControls.scale_for(reference * 2.0, config)).is_equal_approx(2.0, 0.0001)
	# Portrait: tall but narrow — the width decides, so no button leaves the screen.
	assert_float(TouchControls.scale_for(Vector2(1280.0, 2767.0), config)).is_equal_approx(1.0, 0.0001)


func test_every_button_fits_a_portrait_screen() -> void:
	var config: TouchConfig = load("res://config/touch.tres") as TouchConfig
	var viewport_size: Vector2 = Vector2(1280.0, 2767.0)
	var ui_scale: float = TouchControls.scale_for(viewport_size, config)
	var screen: Rect2 = Rect2(Vector2.ZERO, viewport_size)
	for spec: TouchButtonSpec in config.buttons:
		var rect: Rect2 = Rect2(spec.anchor * viewport_size + spec.offset * ui_scale, spec.size * ui_scale)
		assert_bool(screen.encloses(rect)).override_failure_message(String(spec.action)).is_true()


func test_buttons_sit_inside_the_viewport_and_scale_with_it() -> void:
	var config: TouchConfig = load("res://config/touch.tres") as TouchConfig
	var controls: TouchControls = auto_free(TouchControls.new())
	add_child(controls)
	controls.setup(config, func(_event: InputEvent) -> void: pass)
	var viewport_size: Vector2 = controls.get_viewport().get_visible_rect().size
	var ui_scale: float = TouchControls.scale_for(viewport_size, config)
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


func test_hidden_buttons_take_no_touches() -> void:
	var events: Array[InputEventAction] = []
	var viewport: SubViewport = auto_free(SubViewport.new())
	viewport.size = Vector2i(1280, 720)
	add_child(viewport)
	var controls: TouchControls = TouchControls.new()
	viewport.add_child(controls)
	controls.setup(load("res://config/touch.tres") as TouchConfig,
			func(event: InputEvent) -> void: events.append(event as InputEventAction))
	controls.set_shown(false)
	await get_tree().process_frame
	var gas: TouchButton = controls.button_for(&"accelerate")
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = gas.position + gas.size / 2.0
	viewport.push_input(touch)
	assert_bool(gas.is_held()).is_false()
	assert_array(events).is_empty()
	controls.set_shown(true)
	viewport.push_input(touch)
	assert_bool(gas.is_held()).is_true()


func test_every_label_is_translated_and_fits_its_button() -> void:
	var config: TouchConfig = load("res://config/touch.tres") as TouchConfig
	var controls: TouchControls = auto_free(TouchControls.new())
	add_child(controls)
	controls.setup(config, func(_event: InputEvent) -> void: pass)
	for button: TouchButton in controls.buttons:
		var text: String = tr(button.label_key)
		assert_str(text).override_failure_message(String(button.label_key)).is_not_equal(String(button.label_key))
		var font: Font = button.get_theme_default_font()
		var font_size: int = button._fitting_font_size(font, text)
		var room: float = button.size.x - 2.0 * config.label_outline_px * button.ui_scale
		assert_float(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) \
				.is_less_equal(room)
		# Fitted by a little, never shrunk to something unreadable.
		assert_int(font_size).override_failure_message(text) \
				.is_greater_equal(int(config.label_font_size * button.ui_scale * 0.6))


func test_no_button_covers_a_mirror_on_any_screen_shape(
		screen: Vector2,
		test_parameters: Array = [
			[Vector2(1280.0, 720.0)], [Vector2(1280.0, 960.0)], [Vector2(1560.0, 720.0)],
			[Vector2(1280.0, 2770.0)],
		]) -> void:
	# The mirrors are what the player checks before every lane change. The project
	# stretches with `expand`, so the visible rect only ever grows from 1280×720.
	var config: TouchConfig = load("res://config/touch.tres") as TouchConfig
	var view: ViewConfig = load("res://config/view_config.tres") as ViewConfig
	var ui_scale: float = TouchControls.scale_for(screen, config)
	var mirrors: Array[Rect2] = [view.rear_mirror_rect, view.left_mirror_rect, view.right_mirror_rect()]
	for spec: TouchButtonSpec in config.buttons:
		var rect: Rect2 = Rect2(spec.anchor * screen + spec.offset * ui_scale, spec.size * ui_scale)
		for mirror: Rect2 in mirrors:
			var on_screen: Rect2 = Rect2(mirror.position * screen, mirror.size * screen)
			assert_bool(rect.intersects(on_screen)).override_failure_message(String(spec.action)).is_false()
