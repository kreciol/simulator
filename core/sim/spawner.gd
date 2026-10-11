class_name Spawner
extends RefCounted
## Keeps AI traffic around the player at the level's density (requirements §7.3, §10;
## spec Architecture: Spawner). The window spans `spawn_window_behind_m` behind to
## `spawn_window_ahead_m` ahead of the player. At the start `attach` fills the whole
## window, keeping the player's safety margin clear. Then every `spawn_interval_s`
## vehicles that left the window are despawned and the count is topped up. Top-up
## vehicles appear only in the hidden zones beyond view, and only where the lane is
## free with legal gaps and no hard braking for anyone; otherwise the spawn is skipped,
## never forced. Vehicles come from the sim's pool. All randomness is the sim's RNG,
## so seed + input log still replays a session.

## Pairs of AI cars that collided since the last update (spec Edge Cases: despawned
## silently, never charged to the player).
var _crashed: Array[Vector2i] = []
var _next_update_s: float = 0.0
## Stand-in for a vehicle about to be placed, so safety checks reuse the IDM of
## `AiDriver` without adding it to the road first.
var _probe: VehicleState = VehicleState.new()
var _probe_driver: AiDriver = AiDriver.new()

var level: DifficultyLevel


func _init(difficulty: DifficultyLevel) -> void:
	level = difficulty
	_probe.ai = _probe_driver


## Starts managing traffic around `sim.player` (which must be set): fills the window
## now, then keeps it at density on every `sim.step`.
func attach(sim: TrafficSim) -> void:
	if sim.player == null:
		push_error("Spawner: the sim needs a player to place traffic around")
		return
	sim.spawner = self
	# The sim only holds this spawner; the connection does not keep the sim alive.
	sim.collision.connect(_on_collision)
	_populate(sim)
	_next_update_s = sim.time_s + sim.config.spawn_interval_s


## Number of vehicles the window holds at the level's density.
func target_count(sim: TrafficSim) -> int:
	var window_km: float = (sim.config.spawn_window_ahead_m + sim.config.spawn_window_behind_m) / 1000.0
	return roundi(level.density_per_km_per_lane * window_km * sim.road.lane_count)


## Vehicles other than the player whose centre is inside the window.
func count_in_window(sim: TrafficSim) -> int:
	var count: int = 0
	var player_s: float = sim.player.s
	for vehicle: VehicleState in sim.vehicles:
		if vehicle != sim.player and _in_window(sim, vehicle.s - player_s, 0.0):
			count += 1
	return count


## Called by `TrafficSim.step` after integration and collision detection.
func update(sim: TrafficSim) -> void:
	_remove_crashed(sim)
	if sim.time_s + LaneQuery.TIME_EPSILON < _next_update_s:
		return
	_next_update_s = sim.time_s + sim.config.spawn_interval_s
	_despawn_outside_window(sim)
	var missing: int = target_count(sim) - count_in_window(sim)
	for i: int in mini(missing, sim.config.spawn_attempts_per_update):
		_try_spawn_hidden(sim)


func _populate(sim: TrafficSim) -> void:
	var config: SimConfig = sim.config
	var player: VehicleState = sim.player
	var missing: int = target_count(sim) - count_in_window(sim)
	# Bounded, so a level denser than the road can carry still finishes.
	for i: int in missing * config.spawn_attempts_per_update:
		if missing <= 0:
			break
		_draw_vehicle(sim)
		var s: float = player.s + sim.rng.randf_range(-config.spawn_window_behind_m, config.spawn_window_ahead_m)
		var body_gap: float = absf(s - player.s) - (_probe.length_m + player.length_m) / 2.0
		if body_gap < config.spawn_player_clearance_m:
			continue
		if _place(sim, s):
			missing -= 1


## One top-up attempt in the hidden zones: faster vehicles than the player come from
## behind, slower ones from ahead, as they would enter the window.
func _try_spawn_hidden(sim: TrafficSim) -> void:
	var config: SimConfig = sim.config
	var player: VehicleState = sim.player
	_draw_vehicle(sim)
	var half_length: float = _probe.length_m / 2.0
	var s: float
	if _probe_driver.desired_speed_mps > player.speed_mps:
		s = player.s - sim.rng.randf_range(config.spawn_hidden_behind_m + half_length, config.spawn_window_behind_m)
	else:
		s = player.s + sim.rng.randf_range(config.spawn_hidden_ahead_m + half_length, config.spawn_window_ahead_m)
	_place(sim, s)


## Draws kind, desired speed and discipline of the next vehicle into the probe.
func _draw_vehicle(sim: TrafficSim) -> void:
	var config: SimConfig = sim.config
	var kind: VehicleState.Kind = VehicleState.Kind.TRUCK if sim.rng.randf() < level.truck_share else VehicleState.Kind.CAR
	var desired_kmh: float
	if kind == VehicleState.Kind.TRUCK:
		desired_kmh = sim.rng.randf_range(config.truck_speed_min_kmh, config.truck_speed_max_kmh)
	else:
		var cruise_kmh: float = sim.road.speed_limit_kmh + config.ai_car_speed_offset_kmh
		desired_kmh = cruise_kmh + sim.rng.randf_range(-level.ai_speed_spread_kmh, level.ai_speed_spread_kmh)
	var discipline: float = sim.rng.randf_range(level.ai_discipline_min, level.ai_discipline_max)
	_set_probe(sim, kind, minf(desired_kmh, config.max_speed_kmh) / TrafficSim.KMH_PER_MPS, discipline)


## Places the drawn vehicle at `s` on the rightmost lane that is safe (keep right).
## Returns whether it was placed; when no lane is safe the spawn is skipped.
func _place(sim: TrafficSim, s: float) -> bool:
	for lane: int in sim.road.lane_count:
		var speed_mps: float = _safe_speed(sim, lane, s)
		if speed_mps < 0.0:
			continue
		sim.add_ai_vehicle(s, lane, speed_mps, _probe_driver.desired_speed_mps, _probe_driver.discipline, _probe.kind)
		return true
	return false


## Start speed for the probe at (`lane`, `s`), or -1 when the slot is unsafe. Safe
## means: `LaneQuery.is_lane_free` with legal gaps plus `spawn_clearance_m` to the
## leader and from the follower, and neither the new vehicle nor its follower would
## have to brake harder than `mobil_safe_decel_mps2`. A vehicle closing on a slower
## leader starts at the leader's speed.
func _safe_speed(sim: TrafficSim, lane: int, s: float) -> float:
	var config: SimConfig = sim.config
	_probe.s = s
	_probe.lane = lane
	_probe.speed_mps = _probe_driver.desired_speed_mps
	var leader: VehicleState = LaneQuery.leader_in_lane(sim.lanes, lane, s)
	var follower: VehicleState = LaneQuery.follower_in_lane(sim.lanes, lane, s)
	if leader != null and AiDriver.acceleration_behind(sim, _probe, leader) < -config.mobil_safe_decel_mps2:
		_probe.speed_mps = minf(_probe.speed_mps, leader.speed_mps)
	var half_length: float = _probe.length_m / 2.0
	var ahead: float = half_length + LaneQuery.min_gap(_probe.speed_mps * TrafficSim.KMH_PER_MPS) + config.spawn_clearance_m
	var behind: float = half_length + config.spawn_clearance_m
	if follower != null:
		behind += LaneQuery.min_gap(follower.speed_mps * TrafficSim.KMH_PER_MPS)
	if not LaneQuery.is_lane_free(sim.lanes, lane, s, ahead, behind):
		return -1.0
	if leader != null and AiDriver.acceleration_behind(sim, _probe, leader) < -config.mobil_safe_decel_mps2:
		return -1.0
	if follower != null and AiDriver.acceleration_behind(sim, follower, _probe) < -config.mobil_safe_decel_mps2:
		return -1.0
	return _probe.speed_mps


func _set_probe(sim: TrafficSim, kind: VehicleState.Kind, desired_speed_mps: float, discipline: float) -> void:
	_probe.kind = kind
	if kind == VehicleState.Kind.TRUCK:
		_probe.length_m = sim.config.truck_length_m
		_probe.width_m = sim.config.truck_width_m
	else:
		_probe.length_m = sim.config.vehicle_length_m
		_probe.width_m = sim.config.vehicle_width_m
	_probe_driver.setup(desired_speed_mps, discipline, 0.0)


## Whether a body centred `offset_m` from the player lies within the window widened
## by `margin_m` on both sides.
func _in_window(sim: TrafficSim, offset_m: float, margin_m: float) -> bool:
	return offset_m >= -sim.config.spawn_window_behind_m - margin_m \
			and offset_m <= sim.config.spawn_window_ahead_m + margin_m


func _despawn_outside_window(sim: TrafficSim) -> void:
	var player_s: float = sim.player.s
	for i: int in range(sim.vehicles.size() - 1, -1, -1):
		var vehicle: VehicleState = sim.vehicles[i]
		if vehicle != sim.player and not _in_window(sim, vehicle.s - player_s, sim.config.despawn_margin_m):
			sim.remove_vehicle(vehicle)


func _on_collision(vehicle_id: int, other_id: int) -> void:
	_crashed.append(Vector2i(vehicle_id, other_id))


func _remove_crashed(sim: TrafficSim) -> void:
	if _crashed.is_empty():
		return
	for pair: Vector2i in _crashed:
		var a: VehicleState = sim.find_vehicle(pair.x)
		var b: VehicleState = sim.find_vehicle(pair.y)
		if a == null or b == null or a.ai == null or b.ai == null or a == sim.player or b == sim.player:
			continue
		sim.remove_vehicle(a)
		sim.remove_vehicle(b)
	_crashed.clear()
