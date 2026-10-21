extends GdUnitTestSuite
## How the screens fit a phone (issue #87): portrait, CSS scale, the safe area in canvas
## units, the minimum touch target, growing buttons for a finger, the rotate notice.


func after_test() -> void:
	TouchControls.run_shown = false


func test_only_a_screen_taller_than_wide_is_portrait() -> void:
	assert_bool(ScreenFit.is_portrait(Vector2(390.0, 844.0))).is_true()
	assert_bool(ScreenFit.is_portrait(Vector2(844.0, 390.0))).is_false()
	assert_bool(ScreenFit.is_portrait(Vector2(800.0, 800.0))).is_false()


func test_the_css_scale_matches_the_screen_matrix() -> void:
	for css: Vector2 in ScreenMatrix.touch_sizes() + ScreenMatrix.DESKTOPS:
		var canvas: Vector2 = css / ScreenMatrix.css_scale(css)
		assert_float(ScreenFit.css_scale(css * 3.0, 3.0, canvas)).override_failure_message(ScreenMatrix.describe(css)) \
				.is_equal_approx(ScreenMatrix.css_scale(css), 0.0001)
	# Nothing to measure yet: one to one.
	assert_float(ScreenFit.css_scale(Vector2.ZERO, 1.0, Vector2(1280.0, 720.0))).is_equal(1.0)


func test_the_minimum_target_grows_as_the_screen_shrinks() -> void:
	var config: TouchConfig = load("res://config/touch.tres") as TouchConfig
	assert_float(config.min_touch_target_px).is_greater(0.0)
	assert_float(ScreenFit.min_target(config, 1.0)).is_equal(config.min_touch_target_px)
	assert_float(ScreenFit.min_target(config, 0.5)).is_equal(2.0 * config.min_touch_target_px)


func test_the_safe_area_in_canvas_units() -> void:
	var canvas: Vector2 = Vector2(1558.0, 720.0)
	var window: Rect2 = Rect2(0.0, 0.0, 2532.0, 1170.0)
	# A notch on the left, rounded corners at the bottom.
	var safe: Rect2 = Rect2(141.0, 0.0, 2532.0 - 282.0, 1170.0 - 63.0)
	var area: Rect2 = ScreenFit.safe_rect(canvas, window, safe)
	var units_per_px: float = canvas.x / window.size.x
	assert_vector(area.position).is_equal_approx(Vector2(141.0 * units_per_px, 0.0), Vector2(0.01, 0.01))
	assert_vector(area.end).is_equal_approx(canvas - Vector2(141.0, 63.0) * units_per_px, Vector2(0.5, 0.5))


func test_without_a_safe_area_the_whole_canvas_is_safe() -> void:
	var canvas: Vector2 = Vector2(1280.0, 720.0)
	var full: Rect2 = Rect2(Vector2.ZERO, canvas)
	assert_object(ScreenFit.safe_rect(canvas, Rect2(0.0, 0.0, 1280.0, 720.0), Rect2())).is_equal(full)
	assert_object(ScreenFit.safe_rect(canvas, Rect2(), Rect2(0.0, 0.0, 10.0, 10.0))).is_equal(full)
	# A safe area beyond the window (a desktop's usable rect) does not shrink it.
	assert_object(ScreenFit.safe_rect(canvas, Rect2(100.0, 100.0, 1280.0, 720.0), Rect2(0.0, 0.0, 3840.0, 2160.0))) \
			.is_equal(full)


func test_buttons_grow_for_a_finger_and_go_back() -> void:
	var root: Control = auto_free(Control.new()) as Control
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(220.0, 40.0)
	root.add_child(button)
	ScreenFit.fit_buttons(root, 55.0)
	assert_vector(button.custom_minimum_size).is_equal(Vector2(220.0, 55.0))
	ScreenFit.fit_buttons(root, 0.0)
	assert_vector(button.custom_minimum_size).is_equal(Vector2(220.0, 40.0))


func test_touch_buttons_shown_this_run_count_as_a_touch_device() -> void:
	TouchControls.run_shown = true
	assert_bool(ScreenFit.touch_device()).is_true()


func test_the_rotate_notice_shows_only_upright_on_a_touch_device() -> void:
	var shown: Array[bool] = []
	var screen: Array[Vector2] = [Vector2(1558.0, 720.0)]
	var notice: RotateNotice = auto_free(RotateNotice.new()) as RotateNotice
	notice.screen_size = func() -> Vector2: return screen[0]
	notice.shown_changed.connect(func(value: bool) -> void: shown.append(value))
	add_child(notice)
	notice.setup(true)
	assert_bool(notice.visible).is_false()
	screen[0] = Vector2(1280.0, 2767.0)
	notice.refresh()
	assert_bool(notice.visible).is_true()
	screen[0] = Vector2(1558.0, 720.0)
	notice.refresh()
	assert_bool(notice.visible).is_false()
	assert_array(shown).contains_exactly([true, false])
	# Not a touch device: never.
	notice.applies = false
	screen[0] = Vector2(1280.0, 2767.0)
	notice.refresh()
	assert_bool(notice.visible).is_false()
