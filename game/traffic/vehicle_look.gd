class_name VehicleLook
extends RefCounted
## How an AI vehicle is drawn (requirements §7.1): its body type and paint. Picked
## from the vehicle's id, not drawn from an RNG, so the sim's RNG stays the only one
## and a replayed session looks the same. Vans/SUVs are a look of the sim's cars.

enum Look { CAR, VAN, TRUCK }

## Spreads consecutive ids over [0, 1) (golden-ratio fractions), so vans do not bunch.
const ID_SPREAD: float = 0.618034


static func look_of(vehicle: VehicleState, view: ViewConfig) -> Look:
	if vehicle.kind == VehicleState.Kind.TRUCK:
		return Look.TRUCK
	return Look.VAN if fposmod(vehicle.id * ID_SPREAD, 1.0) < view.van_share else Look.CAR


static func color_of(vehicle: VehicleState, view: ViewConfig) -> Color:
	return view.vehicle_colors[posmod(vehicle.id, view.vehicle_colors.size())]
