class_name RoadLayout
extends RefCounted
## Cross-section of the dual carriageway (requirements §4.2) as strips running along
## the road. Lateral positions `u` use the sim's convention: metres left of the right
## edge of the player's carriageway. The opposite carriageway mirrors the player's
## across the median centre and is purely decorative.

enum Surface { TERRAIN, ASPHALT, SHOULDER, PAINT, BARRIER }

## Height of painted lines above the asphalt, against z-fighting.
const PAINT_LIFT_M: float = 0.01
## Height of the terrain below the asphalt, against z-fighting.
const TERRAIN_DROP_M: float = 0.02


## One strip along the road between `u_min` and `u_max`, with its top at `top_y`.
## Dashed strips are painted only for the dash length of every dash period.
class Strip:
	var surface: Surface
	var u_min: float
	var u_max: float
	var top_y: float
	var dashed: bool

	func _init(strip_surface: Surface, from_u: float, to_u: float, y: float, is_dashed: bool = false) -> void:
		surface = strip_surface
		u_min = minf(from_u, to_u)
		u_max = maxf(from_u, to_u)
		top_y = y
		dashed = is_dashed

	func center_u() -> float:
		return (u_min + u_max) / 2.0


var road: RoadProfile
var view: ViewConfig
var strips: Array[Strip] = []


func _init(road_profile: RoadProfile, view_config: ViewConfig) -> void:
	road = road_profile
	view = view_config
	_build()


## World x of a lateral position: the camera looks down -z, so "left" is -x.
static func x_of(u: float) -> float:
	return -u


func carriageway_width() -> float:
	return float(road.lane_count) * road.lane_width_m


## Lateral position of the median centre, the mirror axis of the opposite carriageway.
func median_center_u() -> float:
	return carriageway_width() + view.inner_strip_width_m + view.median_width_m / 2.0


## Lateral position of the outer roadside barrier's centre on the player's side.
func outer_barrier_u() -> float:
	return -(road.shoulder_width_m + view.barrier_offset_m + view.barrier_width_m / 2.0)


## Strips of one kind, in build order (player side first, then the mirrored side).
func strips_of(surface: Surface) -> Array[Strip]:
	var found: Array[Strip] = []
	for strip: Strip in strips:
		if strip.surface == surface:
			found.append(strip)
	return found


func _build() -> void:
	var width: float = carriageway_width()
	var mirror: float = median_center_u()
	var half_barrier: float = view.barrier_width_m / 2.0
	var player_side: Array[Strip] = [
		Strip.new(Surface.SHOULDER, -road.shoulder_width_m, 0.0, 0.0),
		Strip.new(Surface.ASPHALT, 0.0, width, 0.0),
		Strip.new(Surface.SHOULDER, width, width + view.inner_strip_width_m, 0.0),
		Strip.new(Surface.PAINT, -view.edge_line_width_m, 0.0, PAINT_LIFT_M),
		Strip.new(Surface.PAINT, width, width + view.edge_line_width_m, PAINT_LIFT_M),
		Strip.new(Surface.BARRIER, outer_barrier_u() - half_barrier, outer_barrier_u() + half_barrier,
				view.barrier_height_m),
	]
	var half_line: float = view.lane_line_width_m / 2.0
	for lane: int in range(1, road.lane_count):
		var boundary: float = float(lane) * road.lane_width_m
		player_side.append(Strip.new(Surface.PAINT, boundary - half_line, boundary + half_line, PAINT_LIFT_M, true))

	var outer_edge: float = outer_barrier_u() - half_barrier
	strips.append(Strip.new(Surface.TERRAIN, outer_edge - view.terrain_width_m,
			2.0 * mirror - outer_edge + view.terrain_width_m, -TERRAIN_DROP_M))
	strips.append_array(player_side)
	for strip: Strip in player_side:
		strips.append(Strip.new(strip.surface, 2.0 * mirror - strip.u_max, 2.0 * mirror - strip.u_min,
				strip.top_y, strip.dashed))
	strips.append(Strip.new(Surface.BARRIER, mirror - half_barrier, mirror + half_barrier, view.barrier_height_m))
