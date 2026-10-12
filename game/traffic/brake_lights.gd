class_name BrakeLights
extends RefCounted
## When a vehicle's brake lights are on, so the player can read that the car ahead is
## slowing (requirements §7.1). AI cars light them while their driver decelerates
## harder than `threshold_mps2`; vehicles without a driver while braking.


static func is_lit(vehicle: VehicleState, threshold_mps2: float) -> bool:
	if vehicle.ai != null:
		return vehicle.ai.accel_mps2 < -threshold_mps2
	return vehicle.longitudinal == VehicleState.Longitudinal.BRAKE
