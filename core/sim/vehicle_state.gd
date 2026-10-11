class_name VehicleState
extends RefCounted
## State of one vehicle in logical coordinates (spec Architecture: Coordinates).
## The player and AI cars share this type; only the source of decisions differs.

## Lateral direction, valued as the lane index delta (lane 0 is the rightmost).
enum Dir { RIGHT = -1, NONE = 0, LEFT = 1 }
enum Longitudinal { NONE, ACCELERATE, BRAKE }

var id: int
## Distance along the road, metres.
var s: float
var lane: int
var speed_mps: float
## Current throttle/brake decision, held until the next command.
var longitudinal: Longitudinal = Longitudinal.NONE
