class_name Respawn
extends RefCounted
## Learn-mode respawn (requirements §9.2, spec Edge Cases): after a collision or
## leaving the road the player is put back on the right lane at `respawn_speed_kmh`,
## at the nearest position to the incident whose window — `respawn_clear_ahead_m`
## ahead of and `respawn_clear_behind_m` behind the body — is free (`LaneQuery.is_lane_free`).
## Candidates lie every `respawn_search_step_m` up to `respawn_search_range_m` either
## way, ahead first at equal distance. When none is free, the vehicles in the window
## at the incident are despawned and the player goes there.

const LANE: int = 0


## Puts `sim.player` back on the road and returns the `s` it was placed at.
static func respawn_player(sim: TrafficSim) -> float:
	var player: VehicleState = sim.player
	var s: float = find_free_s(sim, player.s)
	if is_nan(s):
		s = player.s
		despawn_window(sim, s)
	sim.place_vehicle(player, s, LANE, sim.config.respawn_speed_kmh / TrafficSim.KMH_PER_MPS)
	return s


## The nearest `s` to `around_s` on the right lane whose respawn window is free of
## everything but the player; NAN when there is none within the search range.
static func find_free_s(sim: TrafficSim, around_s: float) -> float:
	var config: SimConfig = sim.config
	var steps: int = floori(config.respawn_search_range_m / config.respawn_search_step_m)
	for i: int in steps + 1:
		for direction: float in [1.0, -1.0]:
			if i == 0 and direction < 0.0:
				continue
			var s: float = around_s + direction * i * config.respawn_search_step_m
			if is_window_free(sim, s):
				return s
	return NAN


## Whether the respawn window around `s` on the right lane is free of other vehicles.
static func is_window_free(sim: TrafficSim, s: float) -> bool:
	var half_length_m: float = sim.player.length_m / 2.0
	return LaneQuery.is_lane_free(sim.lanes, LANE, s, half_length_m + sim.config.respawn_clear_ahead_m,
			half_length_m + sim.config.respawn_clear_behind_m, sim.player)


## Despawns every vehicle but the player whose body reaches into the respawn window
## around `s` on the right lane.
static func despawn_window(sim: TrafficSim, s: float) -> void:
	var half_length_m: float = sim.player.length_m / 2.0
	var window_front: float = s + half_length_m + sim.config.respawn_clear_ahead_m
	var window_rear: float = s - half_length_m - sim.config.respawn_clear_behind_m
	for vehicle: VehicleState in sim.lanes.on_lane(LANE).duplicate():
		if vehicle != sim.player and vehicle.rear_s() <= window_front and vehicle.front_s() >= window_rear:
			sim.remove_vehicle(vehicle)
