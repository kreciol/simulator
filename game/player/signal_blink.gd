class_name SignalBlink
extends RefCounted
## Blink phase of a turn signal, shared by the dashboard lamps and the HUD arrows so
## they flash together. Each blink starts lit when the signal is switched on.


## Whether the signal of `vehicle` is in the lit half of its blink at sim time `time_s`.
static func is_lit(vehicle: VehicleState, time_s: float, blink_hz: float) -> bool:
	if vehicle.signal_dir == VehicleState.Dir.NONE:
		return false
	return fmod((time_s - vehicle.signal_on_since_s) * blink_hz, 1.0) < 0.5
