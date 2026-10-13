class_name ScoreTrendChart
extends Control
## The history screen's simple score trend (requirements §13): the latest totals,
## oldest on the left, as a line with a dot per session between the lowest and the
## highest of them. The numbers themselves are in the caption beside it, so the chart
## is never the only way to read them. Placeholder styling until the Phase 10 theme.

const SIZE: Vector2 = Vector2(440.0, 170.0)
## Space kept free inside the frame so the dots at the edges are whole.
const PADDING: float = 12.0
const FRAME_COLOR: Color = Color(1.0, 1.0, 1.0, 0.35)
const LINE_COLOR: Color = Color(0.35, 0.75, 1.0)
const LINE_WIDTH: float = 3.0
const DOT_RADIUS: float = 5.0

## Totals to plot, oldest first.
var scores: Array[float] = []:
	set(value):
		scores = value
		queue_redraw()


func _init() -> void:
	name = "TrendChart"
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Where each score sits inside a chart of `chart_size`: evenly spread left to right,
## the highest at the top and the lowest at the bottom; all in the middle when they
## are equal, and a single score in the centre.
static func points_for(values: Array[float], chart_size: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = []
	if values.is_empty():
		return points
	var area: Rect2 = Rect2(Vector2(PADDING, PADDING), chart_size - 2.0 * Vector2(PADDING, PADDING))
	var low: float = values.min()
	var high: float = values.max()
	for i: int in values.size():
		var x: float = area.position.x + (area.size.x * i / (values.size() - 1) if values.size() > 1 else area.size.x / 2.0)
		var height: float = (values[i] - low) / (high - low) if high > low else 0.5
		points.append(Vector2(x, area.end.y - height * area.size.y))
	return points


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), FRAME_COLOR, false, 1.0)
	var points: PackedVector2Array = points_for(scores, size)
	if points.size() > 1:
		draw_polyline(points, LINE_COLOR, LINE_WIDTH, true)
	for point: Vector2 in points:
		draw_circle(point, DOT_RADIUS, LINE_COLOR)
