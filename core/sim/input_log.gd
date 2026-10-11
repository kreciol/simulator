class_name InputLog
extends RefCounted
## The player's commands for every fixed step, in order. Together with the sim's
## seed it makes a session replayable (requirements §14). Kept in memory only.

## One entry per step; null for a step without commands.
var _entries: Array[PlayerCommands] = []


## Records a copy, so later changes to `commands` do not rewrite history.
func append(commands: PlayerCommands) -> void:
	if commands == null:
		_entries.append(null)
		return
	_entries.append(PlayerCommands.create(commands.longitudinal, commands.lane_change, commands.signal_toggle))


func size() -> int:
	return _entries.size()


func at(step_index: int) -> PlayerCommands:
	return _entries[step_index]
