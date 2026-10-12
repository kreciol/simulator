class_name SpeedRule
extends RefCounted
## S1 — speeding (Q4): `s1_penalty_per_s` per second while the player drives faster
## than the road's limit plus `speed_tolerance_kmh`. Off when `speed_rule_enabled` is
## false. One segment per stretch; its extreme is the top speed in km/h.

const KEY: StringName = &"s1"
const TYPE: StringName = &"speeding"
const CATEGORY: StringName = &"speed"

var _sim: TrafficSim
var _config: ScoringConfig
var _event_log: EventLog


func _init(sim: TrafficSim, config: ScoringConfig, event_log: EventLog) -> void:
	_sim = sim
	_config = config
	_event_log = event_log


## `player` is null when there is nothing to score (no player, or off the road).
func observe(player: VehicleState, dt: float, completed: Array[ScoreEvent]) -> void:
	if not applies(player):
		if _event_log.is_open(KEY):
			completed.append(_event_log.close_segment(KEY))
		return
	var time_s: float = _sim.time_s
	var context: Dictionary = {"limit_kmh": _sim.road.speed_limit_kmh}
	var segment: ScoreEvent = _event_log.open_segment(KEY, time_s - dt, TYPE, CATEGORY, 0.0, context)
	segment.extreme = maxf(segment.extreme, ScoringSystem.speed_kmh(player))
	_event_log.extend_segment(KEY, time_s, -_config.s1_penalty_per_s * dt)


func applies(player: VehicleState) -> bool:
	if player == null or not _config.speed_rule_enabled:
		return false
	return ScoringSystem.speed_kmh(player) > _sim.road.speed_limit_kmh + _config.speed_tolerance_kmh
