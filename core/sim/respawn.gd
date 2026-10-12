class_name Respawn
extends RefCounted
## Learn-mode respawn (requirements §9.2, spec Edge Cases): after a collision or
## leaving the road the player is put back on the right lane at `respawn_speed_kmh`,
## at the nearest position to the incident that is safe: its window — `respawn_clear_ahead_m`
## ahead of and `respawn_clear_behind_m` behind the body — is free (`LaneQuery.is_lane_free`)
## and no slower vehicle waits just beyond it (`slower_leader`), so the player is not
## put back on course to hit the vehicle it just ran into. Candidates lie every
## `respawn_search_step_m` up to `respawn_search_range_m` either way, ahead first at
## equal distance. When none is safe, the vehicles in the window at the incident are
## despawned, the player goes there, and a slower leader left beyond the window caps
## the respawn speed at its own.

const LANE: int = 0


## Puts `sim.player` back on the road and returns the `s` it was placed at.
static func respawn_player(sim: TrafficSim) -> float:
	var player: VehicleState = sim.player
	var speed_mps: float = respawn_speed_mps(sim)
	var s: float = find_free_s(sim, player.s)
	if is_nan(s):
		s = player.s
		despawn_window(sim, s)
		var leader: VehicleState = slower_leader(sim, s)
		if leader != null:
			speed_mps = leader.speed_mps
	sim.place_vehicle(player, s, LANE, speed_mps)
	return s


static func respawn_speed_mps(sim: TrafficSim) -> float:
	return sim.config.respawn_speed_kmh / TrafficSim.KMH_PER_MPS


## The nearest vehicle ahead of `s` on the right lane when it is slower than the
## respawn speed and its rear lies within the window plus the legal gap at that
## speed; null otherwise.
static func slower_leader(sim: TrafficSim, s: float) -> VehicleState:
	var leader: VehicleState = LaneQuery.leader_in_lane(sim.lanes, LANE, s, sim.player)
	if leader == null or leader.speed_mps >= respawn_speed_mps(sim):
		return null
	var reach_m: float = sim.player.length_m / 2.0 + sim.config.respawn_clear_ahead_m \
			+ LaneQuery.min_gap(sim.config.respawn_speed_kmh)
	return leader if leader.rear_s() - s <= reach_m else null


## The nearest `s` to `around_s` on the right lane that is safe to respawn at; NAN
## when there is none within the search range.
static func find_free_s(sim: TrafficSim, around_s: float) -> float:
	var config: SimConfig = sim.config
	if config.respawn_search_step_m <= 0.0:
		return around_s if is_safe(sim, around_s) else NAN
	var steps: int = floori(config.respawn_search_range_m / config.respawn_search_step_m)
	for i: int in steps + 1:
		for direction: float in [1.0, -1.0]:
			if i == 0 and direction < 0.0:
				continue
			var s: float = around_s + direction * i * config.respawn_search_step_m
			if is_safe(sim, s):
				return s
	return NAN


## Whether the respawn window around `s` on the right lane is free of other vehicles.
static func is_window_free(sim: TrafficSim, s: float) -> bool:
	var half_length_m: float = sim.player.length_m / 2.0
	return LaneQuery.is_lane_free(sim.lanes, LANE, s, half_length_m + sim.config.respawn_clear_ahead_m,
			half_length_m + sim.config.respawn_clear_behind_m, sim.player)


## A free window with no slower vehicle waiting just beyond it.
static func is_safe(sim: TrafficSim, s: float) -> bool:
	return is_window_free(sim, s) and slower_leader(sim, s) == null


## Despawns every vehicle but the player whose body reaches into the respawn window
## around `s` on the right lane.
static func despawn_window(sim: TrafficSim, s: float) -> void:
	var half_length_m: float = sim.player.length_m / 2.0
	var window_front: float = s + half_length_m + sim.config.respawn_clear_ahead_m
	var window_rear: float = s - half_length_m - sim.config.respawn_clear_behind_m
	for vehicle: VehicleState in sim.lanes.on_lane(LANE).duplicate():
		if vehicle != sim.player and vehicle.rear_s() <= window_front and vehicle.front_s() >= window_rear:
			sim.remove_vehicle(vehicle)
