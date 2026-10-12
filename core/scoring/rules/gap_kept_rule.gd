class_name GapKeptRule
extends RefCounted
## N3 — keeping at least the legal gap (requirements §8.3): `n3_reward_per_s` while the
## gap to a leader within `n3_range_m` is at least `LaneQuery.min_gap`; with no leader in
## range only `n3_empty_road_factor` of it (Q8: full reward for actively keeping the
## gap, less on an empty road). The two cases are separate segment types; a segment's
## extreme is its lowest gap ratio (INF on an empty road).

const KEY_FOLLOWING: StringName = &"n3"
const KEY_EMPTY: StringName = &"n3_empty"
const TYPE_FOLLOWING: StringName = &"gap_kept"
const TYPE_EMPTY: StringName = &"gap_kept_empty_road"
const CATEGORY: StringName = &"gap"

var _sim: TrafficSim
var _config: ScoringConfig
var _event_log: EventLog


func _init(sim: TrafficSim, config: ScoringConfig, event_log: EventLog) -> void:
	_sim = sim
	_config = config
	_event_log = event_log


## `player` is null when there is nothing to score (no player, or off the road).
func observe(player: VehicleState, dt: float, completed: Array[ScoreEvent]) -> void:
	var key: StringName = &""
	var ratio: float = INF
	if player != null:
		var min_gap: float = LaneQuery.min_gap(ScoringSystem.speed_kmh(player))
		var gap: float = LaneQuery.gap_to_leader(player, _sim.lanes)
		if min_gap > 0.0 and gap >= min_gap:
			if gap <= _config.n3_range_m:
				key = KEY_FOLLOWING
				ratio = gap / min_gap
			else:
				key = KEY_EMPTY
	for open_key: StringName in [KEY_FOLLOWING, KEY_EMPTY]:
		if open_key != key and _event_log.is_open(open_key):
			completed.append(_event_log.close_segment(open_key))
	if key.is_empty():
		return
	var time_s: float = _sim.time_s
	var type: StringName = TYPE_FOLLOWING if key == KEY_FOLLOWING else TYPE_EMPTY
	var segment: ScoreEvent = _event_log.open_segment(key, time_s - dt, type, CATEGORY, INF)
	segment.extreme = minf(segment.extreme, ratio)
	var factor: float = 1.0 if key == KEY_FOLLOWING else _config.n3_empty_road_factor
	_event_log.extend_segment(key, time_s, _config.n3_reward_per_s * factor * dt)
