class_name TouchButton
extends Control
## One on-screen touch button (issue #86): while held it presses its Input Map action,
## as an `InputEventAction` handed to `sink` (by default `Input.parse_input_event`), so
## the action reaches `main.gd` exactly like a key. Godot's GUI hands each touch index
## to the control it started on, its release and cancel too, so several buttons are
## held at once by several fingers (the accelerator while signalling). A real left
## mouse button holds it as well (the `touch=1` desktop QA path); the mouse click Godot
## emulates from a touch is swallowed, so it never reaches a HUD button beneath. The
## action stays held until the last finger on it lifts, even one that slid off.

## Pointer id of the real mouse; touch indices are 0 and up.
const MOUSE_POINTER: int = -1

var action: StringName
var icon: StringName
var label_key: StringName
var config: TouchConfig
## Actual viewport size over the reference size, set by the layout.
var ui_scale: float = 1.0
## Receives the action events; tests replace it to watch instead.
var sink: Callable = func(event: InputEvent) -> void: Input.parse_input_event(event)

## Pointers holding the button down.
var _pointers: Dictionary[int, bool] = {}
var _box: StyleBoxFlat = StyleBoxFlat.new()


## A button for `spec`, drawn as `config` says.
static func create(spec: TouchButtonSpec, touch_config: TouchConfig) -> TouchButton:
	var button: TouchButton = TouchButton.new()
	button.name = "Touch_%s" % spec.action
	button.action = spec.action
	button.icon = spec.icon
	button.label_key = spec.label_key
	button.config = touch_config
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	return button


func is_held() -> bool:
	return not _pointers.is_empty()


func _gui_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		accept_event()
		if touch.pressed and not touch.canceled:
			_hold(touch.index)
		else:
			_let_go(touch.index)
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null:
		# Swallowed either way: the emulated copy of a touch must not click beneath.
		accept_event()
		if mouse.device == InputEvent.DEVICE_ID_EMULATION or mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			_hold(MOUSE_POINTER)
		else:
			_let_go(MOUSE_POINTER)


## Lets go of every pointer, e.g. when the window loses focus or the buttons hide and
## their releases would go unseen.
func release_all() -> void:
	if _pointers.is_empty():
		return
	_pointers.clear()
	_emit(false)


func _hold(pointer: int) -> void:
	var was_held: bool = is_held()
	_pointers[pointer] = true
	if not was_held:
		_emit(true)


func _let_go(pointer: int) -> void:
	if not _pointers.erase(pointer):
		return
	if not is_held():
		_emit(false)


func _emit(pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	sink.call(event)
	queue_redraw()


func _draw() -> void:
	_box.bg_color = Color(config.background_color, config.pressed_alpha if is_held() else config.idle_alpha)
	_box.set_corner_radius_all(int(config.corner_radius_px * ui_scale))
	_box.border_color = Color(config.icon_color, _box.bg_color.a)
	_box.set_border_width_all(maxi(1, int(config.border_width_px * ui_scale)))
	draw_style_box(_box, Rect2(Vector2.ZERO, size))
	var icon_alpha: float = 1.0 if is_held() else config.idle_icon_alpha
	var side: float = minf(size.x, size.y) * config.icon_fraction
	var font: Font = get_theme_default_font()
	var text: String = tr(label_key)
	var font_size: int = _fitting_font_size(font, text)
	var centre: Vector2 = Vector2(size.x / 2.0, (size.y - font_size) / 2.0)
	TouchIcon.draw_icon(self, icon, Rect2(centre - Vector2(side, side) / 2.0, Vector2(side, side)),
			Color(config.icon_color, icon_alpha))
	var baseline: Vector2 = Vector2(0.0, size.y - font_size * 0.6)
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, config.label_outline_px, Color(Color.BLACK, icon_alpha))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color(config.icon_color, icon_alpha))


## The label's size: `TouchConfig.label_font_size` scaled, shrunk until the text fits
## the button's width, so a long translation is never cut off.
func _fitting_font_size(font: Font, text: String) -> int:
	var font_size: int = maxi(1, int(config.label_font_size * ui_scale))
	var room: float = size.x - 2.0 * config.label_outline_px * ui_scale
	while font_size > 1 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
		font_size -= 1
	return font_size

