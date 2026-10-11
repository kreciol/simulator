class_name ViewConfig
extends Resource
## Rendering tunables for the road and the cockpit (spec Architecture: floating origin,
## segment recycling). Values live in res://config/view_config.tres; nothing is
## defaulted here.

## Length of one recycled road segment. The dash period must divide it, so every
## segment is the same mesh and dashes line up across segment joints.
@export var segment_length_m: float
## Segments in the pool; together with `segments_behind` it sets the draw distance.
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
