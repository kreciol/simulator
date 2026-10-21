class_name RotateNotice
extends CanvasLayer
## "Rotate the device" (issue #87): on a touch device held upright the game covers
## itself with an icon and a line asking to turn it to landscape, the only way it is
## played. A browser locks the orientation only in fullscreen and iOS not at all, so
## nothing relies on a lock. The scene it sits in decides what else happens — the drive
## pauses itself (`shown_changed`). Above everything and taking every touch, so no
## button beneath is pressed by accident.

signal shown_changed(shown: bool)

## Above the HUD (1) and the touch buttons (2).
const LAYER: int = 10
const BACKDROP: Color = Color(0.05, 0.06, 0.08)
const TITLE_FONT_SIZE: int = 72
const HINT_FONT_SIZE: int = 44
const OUTLINE_SIZE: int = 8
const SEPARATION: int = 32
## Wrap width of the hint; the upright canvas is the base width wide.
const TEXT_WIDTH: float = 1100.0
const ICON_SIZE: Vector2 = Vector2(320.0, 320.0)

## Whether the notice can show at all: on a touch device. A desktop window narrower
## than tall keeps the game as it is.
var applies: bool = false
## The canvas size now; tests replace it.
var screen_size: Callable = func() -> Vector2: return get_viewport().get_visible_rect().size

var backdrop: ColorRect
var title_label: Label
var hint_label: Label


func setup(touch_device: bool) -> void:
	applies = touch_device
	layer = LAYER
	name = "RotateNotice"
	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = BACKDROP
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Box"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", SEPARATION)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(box)
	var icon: RotateIcon = RotateIcon.new()
	icon.name = "Icon"
	icon.custom_minimum_size = ICON_SIZE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	title_label = _label("Title", TITLE_FONT_SIZE, &"ROTATE_DEVICE")
	box.add_child(title_label)
	hint_label = _label("Hint", HINT_FONT_SIZE, &"ROTATE_DEVICE_HINT")
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size = Vector2(TEXT_WIDTH, 0.0)
	hint_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(hint_label)
	visible = false
	get_viewport().size_changed.connect(refresh)
	refresh()


## Shows the notice while a touch device is held upright, hides it in landscape.
func refresh() -> void:
	var shown: bool = applies and ScreenFit.is_portrait(screen_size.call())
	if shown == visible:
		return
	visible = shown
	shown_changed.emit(shown)


func _label(node_name: String, font_size: int, key: StringName) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = tr(key)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label


## A phone upright, the same phone on its side and a curved arrow from one to the
## other — drawn, so every browser shows it.
class RotateIcon:
	extends Control

	const COLOR: Color = Color.WHITE
	const DIM: Color = Color(1.0, 1.0, 1.0, 0.45)
	const LINE: float = 8.0

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		draw_rect(Rect2(w * 0.08, h * 0.05, w * 0.3, h * 0.55), COLOR, false, LINE)
		draw_rect(Rect2(w * 0.4, h * 0.62, w * 0.55, h * 0.3), DIM, false, LINE)
		var centre: Vector2 = Vector2(w * 0.38, h * 0.62)
		var radius: float = w * 0.42
		draw_arc(centre, radius, -PI * 0.42, -PI * 0.05, 24, COLOR, LINE)
		var tip: Vector2 = centre + Vector2(cos(-PI * 0.05), sin(-PI * 0.05)) * radius
		draw_colored_polygon(PackedVector2Array([tip + Vector2(-w * 0.07, -h * 0.03),
				tip + Vector2(w * 0.07, -h * 0.03), tip + Vector2(0.0, h * 0.08)]), COLOR)
