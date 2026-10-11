class_name TrafficSim
extends RefCounted
## Headless simulation of all vehicles on one carriageway. Pure logic: no scene or
## rendering dependencies. Driven by fixed steps (`step(dt)`); readers never mutate it.

signal lane_change_started(vehicle_id: int, from_lane: int, to_lane: int)
signal lane_change_finished(vehicle_id: int, lane: int)
signal offroad(vehicle_id: int)

const KMH_PER_MPS: float = 3.6
## Absorbs float drift when per-step progress increments should sum to exactly 1.
const PROGRESS_EPSILON: float = 1e-6

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
	vehicle.length_m = config.vehicle_length_m
	vehicle.width_m = config.vehicle_width_m
	vehicles.append(vehicle)
	return vehicle


func max_speed_mps() -> float:
	return config.max_speed_kmh / KMH_PER_MPS


## Applies a vehicle's decisions for the coming step. A signal toggled in the same
## step as a lane change request counts as switched on before the change starts.
func apply_commands(vehicle: VehicleState, commands: PlayerCommands) -> void:
	vehicle.longitudinal = commands.longitudinal
	if commands.signal_toggle != VehicleState.Dir.NONE:
		toggle_signal(vehicle, commands.signal_toggle)
	if commands.lane_change != VehicleState.Dir.NONE:
		request_lane_change(vehicle, commands.lane_change)


## Toggles the signal in `dir`: off when already on in that direction, otherwise on
## (switching sides restarts `signal_on_since_s`).
func toggle_signal(vehicle: VehicleState, dir: VehicleState.Dir) -> void:
	if dir == VehicleState.Dir.NONE:
		return
	if vehicle.signal_dir == dir:
		vehicle.signal_dir = VehicleState.Dir.NONE
	else:
		vehicle.signal_dir = dir
		vehicle.signal_on_since_s = time_s


## Starts an animated change to the adjacent lane. Ignored while a change is in
## progress or after leaving the road. A change beyond the outermost lane still
## runs and ends off-road (requirements §6.4, §9.2). Returns whether it started.
func request_lane_change(vehicle: VehicleState, dir: VehicleState.Dir) -> bool:
	if dir == VehicleState.Dir.NONE or vehicle.lane_change_active or vehicle.off_road:
		return false
	vehicle.lane_change_active = true
	vehicle.lane_change_from = vehicle.lane
	vehicle.lane_change_to = vehicle.lane + dir
	vehicle.lane_change_progress = 0.0
	lane_change_started.emit(vehicle.id, vehicle.lane_change_from, vehicle.lane_change_to)
	return true


## Lateral offset in metres left of the carriageway's right edge, eased between the
## origin and target lane centres while a lane change runs.
func lateral_position(vehicle: VehicleState) -> float:
	if not vehicle.lane_change_active:
		return road.lane_center(vehicle.lane)
	var weight: float = smoothstep(0.0, 1.0, vehicle.lane_change_progress)
	return lerpf(road.lane_center(vehicle.lane_change_from), road.lane_center(vehicle.lane_change_to), weight)


func step(dt: float) -> void:
	time_s += dt
	for vehicle: VehicleState in vehicles:
		_integrate_longitudinal(vehicle, dt)
		_advance_lane_change(vehicle, dt)


func _integrate_longitudinal(vehicle: VehicleState, dt: float) -> void:
	var accel: float = 0.0
	match vehicle.longitudinal:
		VehicleState.Longitudinal.ACCELERATE:
			accel = config.acceleration_mps2
		VehicleState.Longitudinal.BRAKE:
			accel = -config.braking_mps2
	vehicle.speed_mps = clampf(vehicle.speed_mps + accel * dt, 0.0, max_speed_mps())
	vehicle.s += vehicle.speed_mps * dt


func _advance_lane_change(vehicle: VehicleState, dt: float) -> void:
	if not vehicle.lane_change_active:
		return
	vehicle.lane_change_progress += dt / config.lane_change_duration_s
	if vehicle.lane_change_progress < 1.0 - PROGRESS_EPSILON:
		return
	var dir: VehicleState.Dir = vehicle.lane_change_dir()
	vehicle.lane_change_progress = 1.0
	vehicle.lane_change_active = false
	vehicle.lane = vehicle.lane_change_to
	# Self-cancelling signal, like a steering-column return (requirements §6.5).
	if vehicle.signal_dir == dir:
		vehicle.signal_dir = VehicleState.Dir.NONE
	lane_change_finished.emit(vehicle.id, vehicle.lane)
	if not road.is_lane_on_road(vehicle.lane):
		vehicle.off_road = true
		offroad.emit(vehicle.id)
