class_name SummaryIcon
extends Control
## The icon beside a summary category (spec UI/UX: messages never rely on colour
## alone): a green disc with a tick when it went well, an amber triangle with "!" when
## it needs work. The shapes differ as well as the colours.

const SIZE: float = 30.0
const GOOD_COLOR: Color = Color(0.2, 0.72, 0.3)
const IMPROVE_COLOR: Color = Color(1.0, 0.76, 0.1)
const MARK_COLOR: Color = Color.WHITE
const WARNING_MARK_COLOR: Color = Color(0.15, 0.1, 0.0)
const STROKE_WIDTH: float = 3.5

var rating: Summary.Rating = Summary.Rating.GOOD:
	set(value):
		rating = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s: float = SIZE
	if rating == Summary.Rating.GOOD:
		draw_circle(Vector2(s, s) / 2.0, s / 2.0, GOOD_COLOR)
		draw_polyline(PackedVector2Array([
				Vector2(0.27, 0.52) * s, Vector2(0.44, 0.69) * s, Vector2(0.74, 0.34) * s]),
				MARK_COLOR, STROKE_WIDTH, true)
	else:
		draw_colored_polygon(PackedVector2Array([
				Vector2(0.5, 0.04) * s, Vector2(0.98, 0.94) * s, Vector2(0.02, 0.94) * s]), IMPROVE_COLOR)
		draw_line(Vector2(0.5, 0.36) * s, Vector2(0.5, 0.64) * s, WARNING_MARK_COLOR, STROKE_WIDTH, true)
		draw_circle(Vector2(0.5, 0.79) * s, STROKE_WIDTH / 2.0 + 0.5, WARNING_MARK_COLOR)
