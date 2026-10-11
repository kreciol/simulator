class_name PlayerCommands
extends RefCounted
## One step's worth of decisions for a vehicle, produced from input for the player.

var longitudinal: VehicleState.Longitudinal = VehicleState.Longitudinal.NONE
## Requested lane change direction; NONE when no change was requested this step.
var lane_change: VehicleState.Dir = VehicleState.Dir.NONE
## Signal toggled this step; NONE when no signal key was pressed.
var signal_toggle: VehicleState.Dir = VehicleState.Dir.NONE


static func create(
		longitudinal_input: VehicleState.Longitudinal,
		lane_change_input: VehicleState.Dir = VehicleState.Dir.NONE,
		signal_input: VehicleState.Dir = VehicleState.Dir.NONE) -> PlayerCommands:
	var commands: PlayerCommands = PlayerCommands.new()
	commands.longitudinal = longitudinal_input
	commands.lane_change = lane_change_input
	commands.signal_toggle = signal_input
	return commands
