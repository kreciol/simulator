class_name PlayerCommands
extends RefCounted
## One step's worth of decisions for a vehicle, produced from input for the player.

var longitudinal: VehicleState.Longitudinal = VehicleState.Longitudinal.NONE


static func create(longitudinal_input: VehicleState.Longitudinal) -> PlayerCommands:
	var commands: PlayerCommands = PlayerCommands.new()
	commands.longitudinal = longitudinal_input
	return commands
