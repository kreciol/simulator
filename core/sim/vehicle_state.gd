class_name VehicleState
extends RefCounted
## State of one vehicle in logical coordinates (spec Architecture: Coordinates).
## The player and AI cars share this type; only the source of decisions differs.

## Lateral direction, valued as the lane index delta (lane 0 is the rightmost).
enum Dir { RIGHT = -1, NONE = 0, LEFT = 1 }
enum Longitudinal { NONE, ACCELERATE, BRAKE }

var id: int
## Distance along the road to the centre of the body, metres.
var s: float
var lane: int
var speed_mps: float
## Body size; set from `SimConfig` on spawn.
var length_m: float
var width_m: float
## Current throttle/brake decision, held until the next command.
var longitudinal: Longitudinal = Longitudinal.NONE

## Lane change in progress: `lane` keeps the origin lane until the change completes.
var lane_change_active: bool = false
var lane_change_from: int
var lane_change_to: int
## 0 at the start of the change, 1 when it completes.
var lane_change_progress: float = 0.0

var signal_dir: Dir = Dir.NONE
## Sim time the current signal was turned on; meaningful while `signal_dir` is set.
var signal_on_since_s: float = 0.0

## Set when a lane change ended beyond the outermost lane (requirements §9.2).
var off_road: bool = false

## Decision source of an AI car; null for the player and scripted vehicles, which
## follow `longitudinal`.
var ai: AiDriver = null


func lane_change_dir() -> Dir:
	if not lane_change_active:
		return Dir.NONE
	return Dir.LEFT if lane_change_to > lane_change_from else Dir.RIGHT


func front_s() -> float:
	return s + length_m / 2.0


func rear_s() -> float:
	return s - length_m / 2.0
