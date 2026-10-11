class_name InputLog
extends RefCounted
## The player's commands for every fixed step, in order. Together with the sim's
## seed it makes a session replayable (requirements §14). Kept in memory only.
## Each step packs into one int so recording allocates no objects per step.

## Marks a step without commands.
const NO_COMMANDS: int = -1
## Number of values a `VehicleState.Dir` takes (RIGHT, NONE, LEFT).
const DIR_VALUES: int = 3

var _entries: PackedInt32Array = PackedInt32Array()


## Records the values of `commands` (null for a step without commands), so later
## changes to the object do not rewrite history.
func append(commands: PlayerCommands) -> void:
	if commands == null:
		_entries.append(NO_COMMANDS)
		return
	_entries.append(
			(commands.longitudinal * DIR_VALUES + _dir_code(commands.lane_change)) * DIR_VALUES
			+ _dir_code(commands.signal_toggle))


func size() -> int:
	return _entries.size()


## A fresh copy of the commands recorded for `step_index`; null when there were none.
func at(step_index: int) -> PlayerCommands:
	var code: int = _entries[step_index]
	if code == NO_COMMANDS:
		return null
	var signal_toggle: VehicleState.Dir = _dir_from_code(code % DIR_VALUES)
	code = floori(code / float(DIR_VALUES))
	var lane_change: VehicleState.Dir = _dir_from_code(code % DIR_VALUES)
	var longitudinal: VehicleState.Longitudinal = floori(code / float(DIR_VALUES)) as VehicleState.Longitudinal
	return PlayerCommands.create(longitudinal, lane_change, signal_toggle)


static func _dir_code(dir: VehicleState.Dir) -> int:
	return dir - VehicleState.Dir.RIGHT


static func _dir_from_code(code: int) -> VehicleState.Dir:
	return (code + VehicleState.Dir.RIGHT) as VehicleState.Dir
