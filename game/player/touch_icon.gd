class_name TouchIcon
extends Control
## A touch button's icon on its own (issue #87): the tutorial and the settings show the
## button they name with the same picture the button carries. `draw_icon` is the one
## drawing both use — polygons, not a font glyph, so every browser shows it.

## Opaque and the colour of the touch buttons' icons.
const COLOR: Color = Color.WHITE

## `up`, `down`, `left`, `right`, `signal_left`, `signal_right` or `pause`
## (`TouchButtonSpec.icon`).
var icon: StringName:
	set(value):
		icon = value
		queue_redraw()


## An icon of `side` canvas units.
static func create(icon_name: StringName, side: float) -> TouchIcon:
	var view: TouchIcon = TouchIcon.new()
	view.name = "Icon_%s" % icon_name
	view.icon = icon_name
	view.custom_minimum_size = Vector2(side, side)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return view


func _draw() -> void:
	var side: float = minf(size.x, size.y)
	TouchIcon.draw_icon(self, icon, Rect2((size - Vector2(side, side)) / 2.0, Vector2(side, side)), COLOR)


## Draws `icon_name` on `canvas` inside `rect`: triangles for speed and lanes, a double
## arrow for a signal, two bars for pause.
static func draw_icon(canvas: CanvasItem, icon_name: StringName, rect: Rect2, color: Color) -> void:
	var p: Vector2 = rect.position
	var w: float = rect.size.x
	var h: float = rect.size.y
	match icon_name:
		&"up":
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(w / 2.0, 0.0), p + Vector2(w, h), p + Vector2(0.0, h)]), color)
		&"down":
			canvas.draw_colored_polygon(PackedVector2Array([p, p + Vector2(w, 0.0), p + Vector2(w / 2.0, h)]), color)
		&"left":
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(0.0, h / 2.0), p + Vector2(w, 0.0), p + Vector2(w, h)]), color)
		&"right":
			canvas.draw_colored_polygon(PackedVector2Array([p, p + Vector2(w, h / 2.0), p + Vector2(0.0, h)]), color)
		&"signal_left", &"signal_right":
			var tip_x: float = 0.0 if icon_name == &"signal_left" else w
			var back_x: float = w - tip_x
			var mid_x: float = (tip_x + back_x) / 2.0
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(tip_x, h / 2.0), p + Vector2(mid_x, 0.0),
					p + Vector2(mid_x, h)]), color)
			canvas.draw_rect(Rect2(p + Vector2(minf(mid_x, back_x), h * 0.3), Vector2(w / 2.0, h * 0.4)), color)
		&"pause":
			canvas.draw_rect(Rect2(p + Vector2(w * 0.15, 0.0), Vector2(w * 0.25, h)), color)
			canvas.draw_rect(Rect2(p + Vector2(w * 0.6, 0.0), Vector2(w * 0.25, h)), color)
