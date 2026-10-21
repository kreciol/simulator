extends GdUnitTestSuite
## The menus on a phone (issue #87 acceptance criteria): at every size of the
## screen-size matrix every button of the menu, the setup, the settings and the history
## meets the minimum touch target and stays on screen; with touch the settings preview
## the on-screen buttons rather than presenting keys as the only way to play; a desktop
## without touch keeps its sizes and the keys.

const EPSILON: float = 0.5

var _touch: TouchConfig


func before() -> void:
	_touch = load("res://config/touch.tres") as TouchConfig


func _viewport(canvas: Vector2) -> SubViewport:
	var viewport: SubViewport = auto_free(SubViewport.new()) as SubViewport
	viewport.size = Vector2i(canvas)
	add_child(viewport)
	return viewport


func _start_screen(viewport: Node, touch: bool) -> StartScreen:
	var screen: StartScreen = StartScreen.new()
	screen.launcher_config = load("res://config/dev_launcher.tres") as DevLauncherConfig
	screen.menu_config = load("res://config/menu.tres") as MenuConfig
	screen.touch_config = _touch
	screen.touch = touch
	screen.settings = SettingsStore.new("", screen.launcher_config)
	screen.open_scene = func(_path: String) -> void: pass
	screen.start_session = func(_options: LaunchOptions) -> void: pass
	screen.is_fullscreen = func() -> bool: return false
	screen.set_fullscreen = func(_fullscreen: bool) -> void: pass
	viewport.add_child(screen)
	return screen


## Every visible button under `root` is on a `canvas` screen and, at `css_scale`, at
## least the minimum touch target each way.
func _assert_buttons_fit(root: Node, canvas: Vector2, css_scale: float, what: String) -> void:
	var screen: Rect2 = Rect2(Vector2.ZERO, canvas).grow(EPSILON)
	var checked: int = 0
	for node: Node in root.find_children("*", "BaseButton", true, false):
		var button: Control = node as Control
		if not button.is_visible_in_tree():
			continue
		checked += 1
		var label: String = "%s %s" % [what, button.name]
		assert_bool(screen.encloses(button.get_global_rect())).override_failure_message(
				"%s at %s is off screen" % [label, button.get_global_rect()]).is_true()
		var side_px: float = minf(button.size.x, button.size.y) * css_scale
		assert_float(side_px + 0.01).override_failure_message("%s is %.1f CSS px" % [label, side_px]) \
				.is_greater_equal(_touch.min_touch_target_px)
	assert_int(checked).override_failure_message(what).is_greater(0)


func test_every_menu_button_fits_a_finger_at_every_size() -> void:
	for css: Vector2 in ScreenMatrix.touch_sizes():
		var canvas: Vector2 = ScreenMatrix.canvas_size(css)
		var scale: float = ScreenMatrix.css_scale(css)
		var screen: StartScreen = _start_screen(_viewport(canvas), true)
		screen.fit_for_touch(scale)
		var pages: Dictionary[String, Callable] = {"menu": screen.show_menu, "setup": screen.show_setup,
				"settings": screen.show_settings}
		for page: String in pages:
			pages[page].call()
			await await_idle_frame()
			await await_idle_frame()
			_assert_buttons_fit(screen, canvas, scale, "%s %s" % [ScreenMatrix.describe(css), page])


func test_the_history_back_button_fits_a_finger_at_every_size() -> void:
	for css: Vector2 in ScreenMatrix.touch_sizes():
		var canvas: Vector2 = ScreenMatrix.canvas_size(css)
		var history: HistoryScreen = HistoryScreen.new()
		history.touch_config = _touch
		_viewport(canvas).add_child(history)
		history.fit_for_touch(ScreenMatrix.css_scale(css))
		await await_idle_frame()
		_assert_buttons_fit(history, canvas, ScreenMatrix.css_scale(css), "%s history" % ScreenMatrix.describe(css))


func test_by_touch_the_settings_preview_the_on_screen_buttons() -> void:
	var screen: StartScreen = _start_screen(_viewport(ScreenMatrix.BASE), true)
	screen.fit_for_touch(1.0)
	screen.show_settings()
	assert_bool(screen.touch_preview.is_visible_in_tree()).is_true()
	assert_bool(screen.key_preview.is_visible_in_tree()).is_false()
	var texts: PackedStringArray = []
	for label: Node in screen.touch_preview.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	for spec: TouchButtonSpec in _touch.buttons:
		assert_array(Array(texts)).contains([tr(spec.label_key), tr(KeyBindings.action_label_key(spec.action))])
	assert_array(Array(texts)).contains([tr(&"SETTINGS_TOUCH_KEYBOARD")])
	# Each button pairs its name with the icon it carries.
	assert_int(screen.touch_preview.find_children("*", "TouchIcon", true, false).size()).is_equal(_touch.buttons.size())


func test_a_desktop_without_touch_keeps_the_keys_and_its_sizes() -> void:
	for css: Vector2 in ScreenMatrix.DESKTOPS:
		var screen: StartScreen = _start_screen(_viewport(ScreenMatrix.canvas_size(css)), false)
		screen.fit_for_touch(ScreenMatrix.css_scale(css))
		screen.show_settings()
		assert_bool(screen.key_preview.is_visible_in_tree()).is_true()
		assert_bool(screen.touch_preview.is_visible_in_tree()).is_false()
		assert_vector(screen.settings_back_button.custom_minimum_size).is_equal(StartScreen.OPTION_BUTTON_SIZE)
		assert_vector(screen.new_session_button.custom_minimum_size).is_equal(StartScreen.MENU_BUTTON_SIZE)
