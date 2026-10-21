extends GdUnitTestSuite
## The HUD around the touch buttons on a phone (issue #87 acceptance criteria): at every
## size of the screen-size matrix — each phone also with the browser bars shown — no
## button covers the mirrors, the hints, the score, the tutorial panel or a centred
## heading; every button meets the minimum touch target; the countdown and the end
## screen's buttons stay on screen; with a notch nothing leaves the safe area; and a
## desktop without touch keeps its layout and texts.

const DT: float = 1.0 / 60.0
## A notch and rounded corners in landscape, CSS px: left, top, right, bottom.
const NOTCH_INSETS: Array[float] = [47.0, 0.0, 47.0, 21.0]
const PIXEL_RATIO: float = 3.0
## Room for float rounding at the edge of a rect.
const EPSILON: float = 0.5

var _view: ViewConfig
var _touch: TouchConfig
var _feedback: FeedbackConfig
var _controls: TouchControls
## A scored session that ran to its end, for the end screen.
var _ended: SessionManager


func before() -> void:
	_view = load("res://config/view_config.tres") as ViewConfig
	_touch = load("res://config/touch.tres") as TouchConfig
	_feedback = load("res://config/feedback.tres") as FeedbackConfig
	_ended = auto_free(SessionManager.new()) as SessionManager
	_ended.scoring_config = load("res://config/scoring.tres") as ScoringConfig
	_ended.feedback_config = _feedback
	_ended.setup(load("res://config/road_profiles/motorway.tres") as RoadProfile,
			load("res://config/sim_config.tres") as SimConfig, 0, LaunchOptions.MODE_LEARN)
	while _ended.state != SessionManager.State.ENDED:
		_ended.step(DT)


## A HUD and the touch buttons on a canvas of `canvas` units, laid out in `area` (empty:
## the whole canvas) with the touch target for `css_scale`; null `touch` for a keyboard.
func _hud(canvas: Vector2, css_scale: float, touch: TouchConfig, area: Rect2 = Rect2()) -> Hud:
	var viewport: SubViewport = auto_free(SubViewport.new()) as SubViewport
	viewport.size = Vector2i(canvas)
	add_child(viewport)
	var hud: Hud = Hud.new()
	viewport.add_child(hud)
	hud.setup(_view)
	_controls = null
	if touch != null:
		_controls = TouchControls.new()
		viewport.add_child(_controls)
		_controls.setup(touch, func(_event: InputEvent) -> void: pass)
		_controls.safe_area = area
		_controls.layout()
		hud.set_layout(area, touch, ScreenFit.min_target(touch, css_scale))
	else:
		hud.set_layout(area, null, 0.0)
	return hud


## Every driving element at once, with its longest text: states never show them all
## together, but each must stay clear of the buttons in its own.
func _fill_driving(hud: Hud) -> void:
	hud.score_panel.visible = true
	hud.score_label.text = "100"
	hud.muted_indicator.visible = true
	hud.blind_spot_left.visible = true
	hud.blind_spot_right.visible = true
	hud.hint_list.visible = true
	hud.hint_list.setup(_feedback.hint_max_on_screen)
	var hints: Array[Hint] = []
	for key: StringName in _longest_keys("HINT_", _feedback.hint_max_on_screen):
		var hint: Hint = Hint.new()
		hint.line = FeedbackLine.create(key, {"speed": 140, "min_gap": 70, "gap": 12, "limit": 140, "seconds": 2})
		hints.append(hint)
	hud.hint_list.show_hints(hints)
	hud.tutorial_panel.visible = true
	hud.tutorial_step_label.text = tr(&"TUTORIAL_STEP").format({"number": 5, "count": 6})
	hud.tutorial_prompt_label.text = tr(_longest_touch_prompt())
	hud._show_tutorial_icons([&"signal_right", &"lane_right"] as Array[StringName])
	hud.countdown_label.visible = true
	hud.countdown_label.text = "3"
	hud.paused_screen.visible = true
	hud.respawn_notice.visible = true
	hud.respawn_label.text = tr(&"RESPAWN_COLLISION")
	hud.respawn_hint_label.text = tr(&"RESPAWN_BACK_ON_ROAD")


## The end screen at its fullest: the summary, the comparison and the save status.
func _fill_ended(hud: Hud) -> void:
	hud.update(_ended)
	hud.show_comparison([FeedbackLine.create(&"COMPARE_PREVIOUS_DOWN", {"points": 100, "change": 12}),
			FeedbackLine.create(&"COMPARE_NEW_BEST", {"points": 100})] as Array[FeedbackLine])
	var store: HistoryStore = HistoryStore.new("user://test_hud_phone_layout/none.json", 5)
	store.notice = HistoryStore.Notice.CORRUPT_RECOVERED
	hud.show_save_status(true, store)


## The `count` translation keys starting with `prefix` whose Polish text is longest.
func _longest_keys(prefix: String, count: int) -> Array[StringName]:
	var keys: Array[StringName] = []
	var csv: FileAccess = FileAccess.open("res://i18n/strings.csv", FileAccess.READ)
	while not csv.eof_reached():
		var row: PackedStringArray = csv.get_csv_line()
		if row.size() > 0 and row[0].begins_with(prefix):
			keys.append(StringName(row[0]))
	keys.sort_custom(func(a: StringName, b: StringName) -> bool: return tr(a).length() > tr(b).length())
	return keys.slice(0, count)


func _longest_touch_prompt() -> StringName:
	var longest: StringName = &""
	for key: StringName in Tutorial.TOUCH_PROMPT_KEYS.values():
		if tr(key).length() > tr(longest).length():
			longest = key
	return longest


## The rect a one-line label's text takes, centred as the label draws it.
func _text_rect(label: Label) -> Rect2:
	var rect: Rect2 = label.get_global_rect()
	var font: Font = label.get_theme_font(&"font")
	var font_size: int = label.get_theme_font_size(&"font_size")
	var text: Vector2 = Vector2(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x,
			font.get_height(font_size))
	var top: float = rect.position.y
	if label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		top += (rect.size.y - text.y) / 2.0
	return Rect2(rect.position.x + (rect.size.x - text.x) / 2.0, top, text.x, text.y)


## What the buttons must never cover, by name, on a canvas of `canvas` units.
func _kept_clear(hud: Hud, canvas: Vector2) -> Dictionary[String, Rect2]:
	var rects: Dictionary[String, Rect2] = {}
	var mirrors: Dictionary[String, Rect2] = {"rear mirror": _view.rear_mirror_rect,
			"left mirror": _view.left_mirror_rect, "right mirror": _view.right_mirror_rect()}
	for mirror: String in mirrors:
		rects[mirror] = Rect2(mirrors[mirror].position * canvas, mirrors[mirror].size * canvas)
	for row: PanelContainer in hud.hint_list.rows:
		if row.visible:
			rects["hint " + row.name] = row.get_global_rect()
	rects["score"] = hud.score_panel.get_global_rect()
	rects["tutorial panel"] = hud.tutorial_panel.get_global_rect()
	rects["muted"] = hud.muted_indicator.get_global_rect()
	rects["blind spot left"] = hud.blind_spot_left.get_global_rect()
	rects["blind spot right"] = hud.blind_spot_right.get_global_rect()
	for label: Label in [hud.countdown_label, hud.paused_label, hud.paused_hint_label, hud.respawn_label,
			hud.respawn_hint_label]:
		rects["heading " + label.name] = _text_rect(label)
	return rects


func _assert_meets_target(control: Control, css_scale: float, what: String) -> void:
	var side_px: float = minf(control.size.x, control.size.y) * css_scale
	assert_float(side_px + EPSILON / 10.0).override_failure_message("%s is %.1f CSS px" % [what, side_px]) \
			.is_greater_equal(_touch.min_touch_target_px)


func test_no_touch_button_covers_the_hud() -> void:
	for css: Vector2 in ScreenMatrix.touch_sizes():
		await _check_covers(css)


func _check_covers(css: Vector2) -> void:
	var canvas: Vector2 = ScreenMatrix.canvas_size(css)
	var hud: Hud = _hud(canvas, ScreenMatrix.css_scale(css), _touch)
	_fill_driving(hud)
	await await_idle_frame()
	await await_idle_frame()
	var kept_clear: Dictionary[String, Rect2] = _kept_clear(hud, canvas)
	# Checked at their fullest: every hint row and both icons of the longest step.
	assert_int(hud.hint_list.rows.filter(func(row: PanelContainer) -> bool: return row.visible).size()) \
			.is_equal(_feedback.hint_max_on_screen)
	assert_int(hud.tutorial_icons.get_child_count()).is_equal(2)
	for button: TouchButton in _controls.buttons:
		var rect: Rect2 = button.get_global_rect()
		for what: String in kept_clear:
			assert_bool(rect.intersects(kept_clear[what])).override_failure_message(
					"%s: %s covers the %s (%s vs %s)" % [ScreenMatrix.describe(css), button.name, what, rect,
					kept_clear[what]]).is_false()


func test_every_touch_button_is_on_screen_and_big_enough() -> void:
	for css: Vector2 in ScreenMatrix.touch_sizes():
		await _check_on_screen(css)


func _check_on_screen(css: Vector2) -> void:
	var canvas: Vector2 = ScreenMatrix.canvas_size(css)
	var hud: Hud = _hud(canvas, ScreenMatrix.css_scale(css), _touch)
	_fill_driving(hud)
	await await_idle_frame()
	var screen: Rect2 = Rect2(Vector2.ZERO, canvas).grow(EPSILON)
	for button: TouchButton in _controls.buttons:
		var what: String = "%s %s" % [ScreenMatrix.describe(css), button.name]
		assert_bool(screen.encloses(button.get_global_rect())).override_failure_message(what).is_true()
		_assert_meets_target(button, ScreenMatrix.css_scale(css), what)
	# The tutorial's skip button is pressed by a finger too.
	_assert_meets_target(hud.tutorial_skip_button, ScreenMatrix.css_scale(css),
			"%s tutorial skip" % ScreenMatrix.describe(css))
	# The countdown stays on screen, browser bars or not.
	assert_bool(screen.encloses(_text_rect(hud.countdown_label))) \
			.override_failure_message("%s countdown" % ScreenMatrix.describe(css)).is_true()


func test_the_end_screen_buttons_stay_on_screen_and_big_enough() -> void:
	for css: Vector2 in ScreenMatrix.touch_sizes():
		await _check_end_screen(css)


func _check_end_screen(css: Vector2) -> void:
	var canvas: Vector2 = ScreenMatrix.canvas_size(css)
	var hud: Hud = _hud(canvas, ScreenMatrix.css_scale(css), _touch)
	_fill_ended(hud)
	await await_idle_frame()
	await await_idle_frame()
	var screen: Rect2 = Rect2(Vector2.ZERO, canvas).grow(EPSILON)
	assert_bool(hud.summary_panel.is_visible_in_tree()).is_true()
	for button: Button in [hud.again_button, hud.history_button, hud.menu_button]:
		var what: String = "%s %s" % [ScreenMatrix.describe(css), button.name]
		assert_bool(screen.encloses(button.get_global_rect())).override_failure_message(what).is_true()
		_assert_meets_target(button, ScreenMatrix.css_scale(css), what)


func test_with_a_notch_nothing_leaves_the_safe_area() -> void:
	for css: Vector2 in ScreenMatrix.PHONES:
		var canvas: Vector2 = ScreenMatrix.canvas_size(css)
		var window: Rect2 = Rect2(Vector2.ZERO, css * PIXEL_RATIO)
		var safe_px: Rect2 = Rect2(Vector2(NOTCH_INSETS[0], NOTCH_INSETS[1]) * PIXEL_RATIO,
				(css - Vector2(NOTCH_INSETS[0] + NOTCH_INSETS[2], NOTCH_INSETS[1] + NOTCH_INSETS[3])) * PIXEL_RATIO)
		var area: Rect2 = ScreenFit.safe_rect(canvas, window, safe_px)
		var hud: Hud = _hud(canvas, ScreenMatrix.css_scale(css), _touch, area)
		_fill_driving(hud)
		await await_idle_frame()
		await await_idle_frame()
		var inside: Rect2 = area.grow(EPSILON)
		var elements: Dictionary[String, Rect2] = _kept_clear(hud, canvas)
		for mirror: String in ["rear mirror", "left mirror", "right mirror"]:
			# The mirrors are part of the 3D view behind the HUD.
			elements.erase(mirror)
		for widget: Control in hud._driving_widgets:
			elements[widget.name] = widget.get_global_rect()
		for button: TouchButton in _controls.buttons:
			elements[button.name] = button.get_global_rect()
		for what: String in elements:
			assert_bool(inside.encloses(elements[what])).override_failure_message(
					"%s: %s %s outside %s" % [ScreenMatrix.describe(css), what, elements[what], area]).is_true()
		# The dimming backdrops still cover the whole screen.
		assert_vector(hud.paused_screen.get_global_rect().size).is_equal_approx(canvas, Vector2.ONE)


func test_a_desktop_without_touch_keeps_its_layout_and_texts() -> void:
	for css: Vector2 in ScreenMatrix.DESKTOPS:
		var canvas: Vector2 = ScreenMatrix.canvas_size(css)
		var hud: Hud = _hud(canvas, ScreenMatrix.css_scale(css), null)
		_fill_driving(hud)
		await await_idle_frame()
		assert_str(hud.paused_hint_label.text).is_equal(tr(&"SESSION_PAUSED_HINT"))
		assert_str(hud.tutorial_skip_button.text).is_equal(tr(&"TUTORIAL_SKIP"))
		assert_bool(hud.tutorial_icons.visible).is_false()
		# The skip button keeps its own row under the prompt.
		assert_object(hud.tutorial_skip_button.get_parent()).is_not_equal(hud.tutorial_icons.get_parent())
		assert_vector(hud.again_button.custom_minimum_size).is_equal(Hud.END_BUTTON_SIZE)
		assert_vector(hud.headings.get_global_rect().size).is_equal_approx(canvas, Vector2.ONE)
		# The muted sign stays in the bottom-right corner.
		var muted: Rect2 = hud.muted_indicator.get_global_rect()
		assert_float(muted.end.x).is_equal_approx(canvas.x - Hud.MARGIN, 1.0)
		assert_float(muted.end.y).is_equal_approx(canvas.y - Hud.MARGIN, 1.0)


func test_touch_names_the_pause_button_and_drops_the_skip_key() -> void:
	var hud: Hud = _hud(ScreenMatrix.BASE, 1.0, _touch)
	assert_str(hud.paused_hint_label.text).is_equal(tr(&"SESSION_PAUSED_HINT_TOUCH"))
	assert_str(hud.paused_hint_label.text).contains(tr(&"TOUCH_PAUSE"))
	assert_str(hud.tutorial_skip_button.text).is_equal(tr(&"TUTORIAL_SKIP_TOUCH"))
	assert_str(hud.tutorial_skip_button.text).not_contains("Tab")
	# Back to the keys when the player goes to the keyboard.
	hud.set_layout(Rect2(), null, 0.0)
	assert_str(hud.paused_hint_label.text).is_equal(tr(&"SESSION_PAUSED_HINT"))
	assert_vector(hud.again_button.custom_minimum_size).is_equal(Hud.END_BUTTON_SIZE)
