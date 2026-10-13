class_name PassDetector
extends RefCounted
## Finds vehicles passing the player close by on a neighbouring lane (issue #72, spec
## `2026-10-13-sound-effects.md`): a vehicle on lane `player.lane ± 1` whose centre
## crosses the player's `s` — overtaking or being overtaken — passes once. Only reads
## the sim's lane index; remembers, per vehicle, which side of the player it was on at
## the last `update`.

var _config: AudioConfig
## Vehicle id → whether its centre was ahead of the player's at the last update.
var _ahead: Dictionary[int, bool] = {}


func _init(audio_config: AudioConfig) -> void:
	_config = audio_config


## Forgets every vehicle, so a player moved by a respawn is not taken for a pass.
func reset() -> void:
	_ahead.clear()


## The passes since the last update, as loudness from 0 to 1: louder for a closer and
## faster pass. Vehicles out of reach are forgotten.
func update(sim: TrafficSim) -> PackedFloat32Array:
	var player: VehicleState = sim.player
	var passes: PackedFloat32Array = PackedFloat32Array()
	var seen: Dictionary[int, bool] = {}
	for lane: int in [player.lane - 1, player.lane + 1]:
		var on_lane: Array[VehicleState] = sim.lanes.on_lane(lane)
		var first: int = LaneIndex.lower_bound(on_lane, player.s - _config.pass_scan_window_m)
		var end: int = LaneIndex.upper_bound(on_lane, player.s + _config.pass_scan_window_m)
		for i: int in range(first, end):
			var vehicle: VehicleState = on_lane[i]
			# A vehicle changing lanes is listed on both of its lanes.
			if vehicle == player or seen.has(vehicle.id):
				continue
			var ahead: bool = vehicle.s > player.s
			seen[vehicle.id] = ahead
			if _ahead.has(vehicle.id) and _ahead[vehicle.id] != ahead:
				var loudness: float = pass_loudness(_config,
						absf(sim.lateral_position(vehicle) - sim.lateral_position(player)),
						absf(vehicle.speed_mps - player.speed_mps) * TrafficSim.KMH_PER_MPS)
				if loudness > 0.0:
					passes.append(loudness)
	_ahead = seen
	return passes


## Loudness of a pass `lateral_m` apart at `relative_kmh`: 0 (no sound) beyond
## `pass_sound_range_m` or below `pass_min_relative_speed_kmh`; otherwise growing with
## closeness (to `pass_edge_loudness` at the range's edge) and with the relative speed (full
## from `pass_full_speed_kmh`).
static func pass_loudness(audio: AudioConfig, lateral_m: float, relative_kmh: float) -> float:
	if lateral_m > audio.pass_sound_range_m or relative_kmh < audio.pass_min_relative_speed_kmh:
		return 0.0
	var proximity: float = lerpf(1.0, audio.pass_edge_loudness, lateral_m / audio.pass_sound_range_m)
	var speed: float = clampf(relative_kmh / audio.pass_full_speed_kmh, 0.0, 1.0)
	return proximity * speed
