class_name TrafficSim
extends RefCounted
## Headless simulation of all vehicles on one carriageway. Pure logic: no scene or
## rendering dependencies. Driven by fixed steps (`step(dt)`); readers never mutate it.

const KMH_PER_MPS: float = 3.6

var road: RoadProfile
var config: SimConfig
## Simulated time since the start, seconds.
var time_s: float = 0.0
var vehicles: Array[VehicleState] = []

var _next_id: int = 0


func _init(road_profile: RoadProfile, sim_config: SimConfig) -> void:
	road = road_profile
	config = sim_config


func add_vehicle(s: float, lane: int, speed_mps: float) -> VehicleState:
	var vehicle: VehicleState = VehicleState.new()
	vehicle.id = _next_id
	_next_id += 1
	vehicle.s = s
	vehicle.lane = lane
	vehicle.speed_mps = clampf(speed_mps, 0.0, max_speed_mps())
	vehicles.append(vehicle)
	return vehicle


func max_speed_mps() -> float:
	return config.max_speed_kmh / KMH_PER_MPS


## Applies a vehicle's decisions for the coming step.
func apply_commands(vehicle: VehicleState, commands: PlayerCommands) -> void:
	vehicle.longitudinal = commands.longitudinal


func step(dt: float) -> void:
	time_s += dt
	for vehicle: VehicleState in vehicles:
		_integrate_longitudinal(vehicle, dt)


func _integrate_longitudinal(vehicle: VehicleState, dt: float) -> void:
	var accel: float = 0.0
	match vehicle.longitudinal:
		VehicleState.Longitudinal.ACCELERATE:
			accel = config.acceleration_mps2
		VehicleState.Longitudinal.BRAKE:
			accel = -config.braking_mps2
	vehicle.speed_mps = clampf(vehicle.speed_mps + accel * dt, 0.0, max_speed_mps())
	vehicle.s += vehicle.speed_mps * dt
