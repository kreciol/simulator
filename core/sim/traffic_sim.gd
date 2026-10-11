class_name TrafficSim
extends RefCounted
## Headless simulation of all vehicles on one carriageway. Pure logic: no scene or
## rendering dependencies. Driven by fixed steps (`step(dt)`); readers never mutate it.

signal lane_change_started(vehicle_id: int, from_lane: int, to_lane: int)
signal lane_change_finished(vehicle_id: int, lane: int)
signal offroad(vehicle_id: int)
## Emitted once when two bodies start to overlap; again only after they separate.
signal collision(vehicle_id: int, other_id: int)
signal vehicle_added(vehicle_id: int)
## Emitted after the vehicle left `vehicles`; its object goes back to the pool.
signal vehicle_removed(vehicle_id: int)

const KMH_PER_MPS: float = 3.6
## Absorbs float drift when per-step progress increments should sum to exactly 1.
const PROGRESS_EPSILON: float = 1e-6
## Spreads AI cars' first lane decisions over the decision interval by id (golden-ratio
## fractions, so consecutive ids land far apart and decisions do not bunch in a step).
const DECISION_PHASE_STEP: float = 0.618034

var road: RoadProfile
var config: SimConfig
## Simulated time since the start, seconds.
var time_s: float = 0.0
var vehicles: Array[VehicleState] = []
## `vehicles` by lane, sorted by `s`, for `LaneQuery` neighbour lookups. Current
## whenever vehicles change lanes through the sim; re-sorted every step.
var lanes: LaneIndex
## Seed of `rng`; with `input_log` it reproduces a session exactly.
var rng_seed: int
## The sim's only source of randomness; nothing else may draw random numbers.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## The vehicle driven by `PlayerCommands` passed to `step`; null without a player.
var player: VehicleState
## Commands passed to `step` for the player, one entry per step.
var input_log: InputLog = InputLog.new()
## Keeps traffic at the level's density at the end of every step; null for no
## managed traffic. Set by `Spawner.attach`.
var spawner: Spawner = null

var _next_id: int = 0
## Removed vehicles and drivers, reused by later adds (no create/free churn).
var _vehicle_pool: Array[VehicleState] = []
var _driver_pool: Array[AiDriver] = []
## Pairs currently in contact, keyed by Vector2i(lower id, higher id).
var _contacts: Dictionary[Vector2i, bool] = {}
## Scratch buffer swapped with `_contacts` each step, so detection does not allocate.
var _next_contacts: Dictionary[Vector2i, bool] = {}


func _init(road_profile: RoadProfile, sim_config: SimConfig, seed_value: int = 0) -> void:
	road = road_profile
	config = sim_config
	lanes = LaneIndex.new(road.lane_count)
	rng_seed = seed_value
	rng.seed = seed_value


func add_vehicle(s: float, lane: int, speed_mps: float, kind: VehicleState.Kind = VehicleState.Kind.CAR) -> VehicleState:
	return _add(s, lane, speed_mps, kind, null)


## Adds a vehicle driven by an `AiDriver` that cruises at `desired_speed_mps` with
## `discipline` in [0, 1] (requirements §7.2).
func add_ai_vehicle(
		s: float,
		lane: int,
		speed_mps: float,
		desired_speed_mps: float,
		discipline: float,
		kind: VehicleState.Kind = VehicleState.Kind.CAR) -> VehicleState:
	var driver: AiDriver = AiDriver.new() if _driver_pool.is_empty() else _driver_pool.pop_back()
	var phase: float = fposmod(_next_id * DECISION_PHASE_STEP, 1.0)
	driver.setup(desired_speed_mps, discipline, time_s + phase * config.ai_lane_decision_interval_s)
	return _add(s, lane, speed_mps, kind, driver)


## Takes a vehicle from the pool, sets it up completely, then announces it.
func _add(s: float, lane: int, speed_mps: float, kind: VehicleState.Kind, driver: AiDriver) -> VehicleState:
	var vehicle: VehicleState = VehicleState.new() if _vehicle_pool.is_empty() else _vehicle_pool.pop_back()
	vehicle.reset()
	vehicle.id = _next_id
	_next_id += 1
	vehicle.kind = kind
	vehicle.s = s
	vehicle.lane = lane
	vehicle.speed_mps = clampf(speed_mps, 0.0, max_speed_mps())
	if kind == VehicleState.Kind.TRUCK:
		vehicle.length_m = config.truck_length_m
		vehicle.width_m = config.truck_width_m
	else:
		vehicle.length_m = config.vehicle_length_m
		vehicle.width_m = config.vehicle_width_m
	vehicle.ai = driver
	vehicles.append(vehicle)
	lanes.add(vehicle)
	vehicle_added.emit(vehicle.id)
	return vehicle


## Takes `vehicle` off the road and keeps it, with its driver, for reuse. The player
## cannot be removed.
func remove_vehicle(vehicle: VehicleState) -> void:
	if vehicle == player:
		push_error("TrafficSim: the player cannot be removed")
		return
	var index: int = vehicles.find(vehicle)
	if index < 0:
		return
	vehicles.remove_at(index)
	lanes.remove(vehicle)
	if vehicle.ai != null:
		_driver_pool.append(vehicle.ai)
		vehicle.ai = null
	_vehicle_pool.append(vehicle)
	vehicle_removed.emit(vehicle.id)


## The vehicle on the road with `vehicle_id`, or null.
func find_vehicle(vehicle_id: int) -> VehicleState:
	for vehicle: VehicleState in vehicles:
		if vehicle.id == vehicle_id:
			return vehicle
	return null


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
	lanes.insert(vehicle, vehicle.lane_change_to)
	lane_change_started.emit(vehicle.id, vehicle.lane_change_from, vehicle.lane_change_to)
	return true


## Lateral offset in metres left of the carriageway's right edge, eased between the
## origin and target lane centres while a lane change runs.
func lateral_position(vehicle: VehicleState) -> float:
	if not vehicle.lane_change_active:
		return road.lane_center(vehicle.lane)
	var weight: float = smoothstep(0.0, 1.0, vehicle.lane_change_progress)
	return lerpf(road.lane_center(vehicle.lane_change_from), road.lane_center(vehicle.lane_change_to), weight)


## Advances the sim by one fixed step. With a player set, `player_commands` (null
## for none) is recorded in `input_log` and applied before integration. AI drivers
## then decide in vehicle order; a lane change one of them starts is visible to the
## next. Last, the spawner (if any) despawns and tops up traffic.
func step(dt: float, player_commands: PlayerCommands = null) -> void:
	# Callers may have moved vehicles since the last step.
	lanes.sort()
	if player != null:
		input_log.append(player_commands)
		if player_commands != null:
			apply_commands(player, player_commands)
	for vehicle: VehicleState in vehicles:
		if vehicle.ai != null:
			vehicle.ai.decide(self, vehicle)
	time_s += dt
	for vehicle: VehicleState in vehicles:
		_integrate_longitudinal(vehicle, dt)
		_advance_lane_change(vehicle, dt)
	lanes.sort()
	_detect_collisions()
	if spawner != null:
		spawner.update(self)


## Re-runs `recorded` step by step; on a sim built with the same seed and vehicles as the
## recorded one, this reproduces its final state.
func replay(recorded: InputLog, dt: float) -> void:
	for i: int in recorded.size():
		step(dt, recorded.at(i))


## Whether the bodies of `a` and `b` overlap as axis-aligned boxes in
## (s, lateral) space; touching edges do not count.
func vehicles_overlap(a: VehicleState, b: VehicleState) -> bool:
	var longitudinal_reach: float = (a.length_m + b.length_m) / 2.0
	var lateral_reach: float = (a.width_m + b.width_m) / 2.0
	return absf(a.s - b.s) < longitudinal_reach 			and absf(lateral_position(a) - lateral_position(b)) < lateral_reach


## Full state as plain data, for comparing runs.
func snapshot() -> Dictionary:
	var vehicle_states: Array[Dictionary] = []
	for vehicle: VehicleState in vehicles:
		vehicle_states.append({
			"id": vehicle.id,
			"s": vehicle.s,
			"lane": vehicle.lane,
			"speed_mps": vehicle.speed_mps,
			"longitudinal": vehicle.longitudinal,
			"lane_change_active": vehicle.lane_change_active,
			"lane_change_from": vehicle.lane_change_from,
			"lane_change_to": vehicle.lane_change_to,
			"lane_change_progress": vehicle.lane_change_progress,
			"signal_dir": vehicle.signal_dir,
			"signal_on_since_s": vehicle.signal_on_since_s,
			"off_road": vehicle.off_road,
		})
	return {
		"time_s": time_s,
		"rng_state": rng.state,
		"contacts": _contacts.keys(),
		"vehicles": vehicle_states,
	}


func _integrate_longitudinal(vehicle: VehicleState, dt: float) -> void:
	var accel: float = vehicle.ai.accel_mps2 if vehicle.ai != null else _command_acceleration(vehicle)
	vehicle.speed_mps = clampf(vehicle.speed_mps + accel * dt, 0.0, max_speed_mps())
	vehicle.s += vehicle.speed_mps * dt


func _command_acceleration(vehicle: VehicleState) -> float:
	var accel: float = 0.0
	match vehicle.longitudinal:
		VehicleState.Longitudinal.ACCELERATE:
			accel = config.acceleration_mps2
		VehicleState.Longitudinal.BRAKE:
			accel = -config.braking_mps2
	return accel


func _advance_lane_change(vehicle: VehicleState, dt: float) -> void:
	if not vehicle.lane_change_active:
		return
	vehicle.lane_change_progress += dt / config.lane_change_duration_s
	if vehicle.lane_change_progress < 1.0 - PROGRESS_EPSILON:
		return
	var dir: VehicleState.Dir = vehicle.lane_change_dir()
	vehicle.lane_change_progress = 1.0
	vehicle.lane_change_active = false
	lanes.erase(vehicle, vehicle.lane_change_from)
	vehicle.lane = vehicle.lane_change_to
	# Self-cancelling signal, like a steering-column return (requirements §6.5).
	if vehicle.signal_dir == dir:
		vehicle.signal_dir = VehicleState.Dir.NONE
	lane_change_finished.emit(vehicle.id, vehicle.lane)
	if not road.is_lane_on_road(vehicle.lane):
		vehicle.off_road = true
		offroad.emit(vehicle.id)


## Overlapping bodies always share a lane in `lanes`: a body lies laterally between
## the centres of the lanes it occupies, and lanes are wider than any body. So only
## neighbours along each lane, close enough in `s` to touch, are compared.
func _detect_collisions() -> void:
	_next_contacts.clear()
	for lane: int in range(lanes.first_lane(), lanes.end_lane()):
		var on_lane: Array[VehicleState] = lanes.on_lane(lane)
		for i: int in on_lane.size():
			var a: VehicleState = on_lane[i]
			var reach: float = (a.length_m + lanes.max_length_m) / 2.0
			for j: int in range(i + 1, on_lane.size()):
				var b: VehicleState = on_lane[j]
				if b.s - a.s >= reach:
					break
				if not vehicles_overlap(a, b):
					continue
				var key: Vector2i = Vector2i(mini(a.id, b.id), maxi(a.id, b.id))
				# Two vehicles changing lanes can meet on both lanes.
				if _next_contacts.has(key):
					continue
				_next_contacts[key] = true
				if not _contacts.has(key):
					collision.emit(key.x, key.y)
	var previous: Dictionary[Vector2i, bool] = _contacts
	_contacts = _next_contacts
	_next_contacts = previous
