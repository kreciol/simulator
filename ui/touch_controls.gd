class_name TouchControls
extends CanvasLayer
## The on-screen touch buttons over the HUD (issue #86, spec
## `2026-10-20-touch-controls.md`): one `TouchButton` per `TouchConfig` entry, placed
## from its viewport anchor and scaled with the viewport (its height, or its width when
## that is relatively smaller). Whether they exist
## and show is the launch's `touch` mode (`builds_at_start`, `builds_on_touch`,
## `hides_on_key`); `main.gd` decides, this layer only draws and lays them out. Hiding
## lets go of every held button, so nothing stays pressed behind a hidden control.
## They are laid out inside `safe_area` (issue #87), clear of a notch or rounded corners.

## Above the HUD and the mirrors (both on the default layer 1).
const LAYER: int = 2

## Whether touch buttons were shown this run, so the menus fit a finger afterwards too
## (`ScreenFit.touch_device`). For the run, not one scene; tests reset it.
static var run_shown: bool = false

var config: TouchConfig
var buttons: Array[TouchButton] = []
## Where the buttons may sit, in canvas units; empty means the whole viewport.
var safe_area: Rect2 = Rect2()


## Whether the buttons are built as the session starts: forced on, or on a touch device.
static func builds_at_start(touch: StringName, touchscreen: bool) -> bool:
	return touch == LaunchOptions.TOUCH_ON or (touch == LaunchOptions.TOUCH_AUTO and touchscreen)


## Whether a touch builds and shows them: only when the device decides (`auto`).
static func builds_on_touch(touch: StringName) -> bool:
	return touch == LaunchOptions.TOUCH_AUTO


## Whether a key press hides them, as on a touch laptop whose player went to the
## keyboard: only when the device decides; forced on they stay.
static func hides_on_key(touch: StringName) -> bool:
	return touch == LaunchOptions.TOUCH_AUTO


## Builds the buttons; `sink` replaces where their action events go (tests).
func setup(touch_config: TouchConfig, sink: Callable = Callable()) -> void:
	config = touch_config
	layer = LAYER
	var root: Control = Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	for spec: TouchButtonSpec in config.buttons:
		var button: TouchButton = TouchButton.create(spec, config)
		if sink.is_valid():
			button.sink = sink
		root.add_child(button)
		buttons.append(button)
	get_viewport().size_changed.connect(layout)
	layout()


## How much the reference layout grows or shrinks to fit `viewport_size`.
static func scale_for(viewport_size: Vector2, touch_config: TouchConfig) -> float:
	return minf(viewport_size.y / touch_config.reference_height_px,
			viewport_size.x / touch_config.reference_width_px)


## Where the button of `spec` sits when the buttons are laid out in `area`.
static func button_rect(spec: TouchButtonSpec, area: Rect2, touch_config: TouchConfig) -> Rect2:
	var ui_scale: float = TouchControls.scale_for(area.size, touch_config)
	return Rect2(area.position + spec.anchor * area.size + spec.offset * ui_scale, spec.size * ui_scale)


## Every button's rect in `area`, in `touch_config`'s order.
static func button_rects(area: Rect2, touch_config: TouchConfig) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for spec: TouchButtonSpec in touch_config.buttons:
		rects.append(TouchControls.button_rect(spec, area, touch_config))
	return rects


## The area the buttons are laid out in now.
func layout_area() -> Rect2:
	return safe_area if safe_area.has_area() else get_viewport().get_visible_rect()


## Places every button for the current viewport size.
func layout() -> void:
	var area: Rect2 = layout_area()
	var ui_scale: float = TouchControls.scale_for(area.size, config)
	for i: int in buttons.size():
		var button: TouchButton = buttons[i]
		var rect: Rect2 = TouchControls.button_rect(config.buttons[i], area, config)
		button.ui_scale = ui_scale
		button.position = rect.position
		button.size = rect.size
		button.queue_redraw()


func set_shown(shown: bool) -> void:
	if visible == shown:
		return
	visible = shown
	if not shown:
		release_all()


## Lets go of every button, e.g. when the window loses focus.
func release_all() -> void:
	for button: TouchButton in buttons:
		button.release_all()


func button_for(action: StringName) -> TouchButton:
	for button: TouchButton in buttons:
		if button.action == action:
			return button
	return null
