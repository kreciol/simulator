class_name ViewConfig
extends Resource
## Rendering tunables for the road and the cockpit (spec Architecture: floating origin,
## segment recycling). Values live in res://config/view_config.tres; nothing is
## defaulted here.

## Length of one recycled road segment. The dash period must divide it, so every
## segment is the same mesh and dashes line up across segment joints.
@export var segment_length_m: float
## Segments in the pool; together with `segments_behind` it sets the draw distance.
## A session takes it from its quality preset (`for_quality`); this value serves views
## built without one.
@export var segment_count: int
## Whole segments kept behind the player's segment (for the rear view and mirrors).
@export var segments_behind: int

## Dashed lane line: painted length and gap length.
@export var dash_length_m: float
@export var dash_gap_m: float
@export var lane_line_width_m: float
@export var edge_line_width_m: float
## Paved strip between the left edge line and the median.
@export var inner_strip_width_m: float
## Unpaved separation between the inner strips of the two carriageways.
@export var median_width_m: float
## Gap between the outer edge of the shoulder and the roadside barrier.
@export var barrier_offset_m: float
@export var barrier_width_m: float
@export var barrier_height_m: float
## Flat terrain extending beyond each roadside barrier.
@export var terrain_width_m: float

## Driver's eye above the road and left of the car's centreline.
@export var eye_height_m: float
@export var eye_offset_left_m: float
## Vertical field of view of the cockpit camera.
@export var camera_fov_deg: float
## Downward tilt of the cockpit camera.
@export var camera_pitch_down_deg: float
## Turn signal lamp blink frequency on the dashboard.
@export var signal_blink_hz: float

## Traffic views (requirements §7.1, spec Phase 4 step 4). Body colours AI vehicles
## are painted in; each vehicle's colour is picked from its id.
@export var vehicle_colors: PackedColorArray
## Share of cars drawn as vans/SUVs; they share the car's footprint in the sim.
@export_range(0.0, 1.0) var van_share: float
## Brake lights light while a vehicle decelerates harder than this.
@export var brake_light_decel_mps2: float

## Mirrors (requirements §5.2, spec Phase 5 step 1). Where each mirror sits on screen,
## as shares of the screen (position and size); the right side mirror is the left one
## reflected across the screen's vertical centreline.
@export var rear_mirror_rect: Rect2
@export var left_mirror_rect: Rect2
## Mirror camera positions relative to the player's rig (car centreline at x = 0, road
## at y = 0, forward is -z); the right side mirror is the left one reflected (x → -x).
@export var rear_mirror_position: Vector3
@export var left_mirror_position: Vector3
## Vertical fields of view of the rear-view and the side mirror cameras.
@export var rear_mirror_fov_deg: float
@export var side_mirror_fov_deg: float
## Side mirrors turn outwards by this much, to show the neighbouring lane.
@export var side_mirror_outward_deg: float
## Downward tilt of every mirror camera.
@export var mirror_pitch_down_deg: float
## Fog in the mirrors starts at this share of their range, so the road's end behind
## the player fades out instead of showing.
@export_range(0.0, 1.0) var mirror_fog_begin_share: float

## Learn-mode blind-spot icons (spec Phase 7 step 3, Q10): a vehicle on the lane beside
## the player within this zone, measured from the player's centre, lights the icon by
## that side's mirror (`LaneQuery.blind_spot_occupied`).
@export var blind_spot_ahead_m: float
@export var blind_spot_behind_m: float


## A copy with `quality`'s draw distance; the shared resource stays untouched.
func for_quality(quality: QualityPreset) -> ViewConfig:
	var copy: ViewConfig = duplicate() as ViewConfig
	copy.segment_count = quality.road_segment_count
	return copy


func dash_period_m() -> float:
	return dash_length_m + dash_gap_m


## Distance ahead of the player always covered by road.
func covered_ahead_m() -> float:
	return float(segment_count - segments_behind - 1) * segment_length_m


## Camera far plane. A segment recycled to the front always starts beyond it, so the
## camera never sees a segment appear (no popping).
func draw_distance_m() -> float:
	return covered_ahead_m() - segment_length_m


## Distance behind the player always covered by road.
func covered_behind_m() -> float:
	return float(segments_behind) * segment_length_m


## Where the right side mirror sits on screen: the left one reflected across the
## screen's vertical centreline.
func right_mirror_rect() -> Rect2:
	var rect: Rect2 = left_mirror_rect
	rect.position.x = 1.0 - left_mirror_rect.end.x
	return rect


## How far the mirrors see: exactly the road always kept behind, so they never show
## where it ends.
func mirror_range_m() -> float:
	return covered_behind_m()
