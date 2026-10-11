class_name RoadProfile
extends Resource
## One road type (requirements §4.1). Instances live in res://config/road_profiles/;
## no value is defaulted here, so a profile is fully defined by its .tres file.

@export var id: StringName
## Translation key of the player-facing name.
@export var display_name_key: String
@export var speed_limit_kmh: float
@export var lane_count: int
@export var lane_width_m: float
@export var shoulder_width_m: float


## Lateral offset of a lane's centre, in metres left of the carriageway's right edge.
## Lane 0 is the rightmost; indices outside [0, lane_count) are off the carriageway.
func lane_center(lane: int) -> float:
	return (float(lane) + 0.5) * lane_width_m


func is_lane_on_road(lane: int) -> bool:
	return lane >= 0 and lane < lane_count
