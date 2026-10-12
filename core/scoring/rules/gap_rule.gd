class_name GapRule
extends RefCounted
## K1 — following too closely (requirements §8.2; art. 19 ust. 3 pkt 2 Prawo o ruchu
## drogowym: on motorways and expressways at least half the speed in km/h, in metres).
## While the gap to the leader on the player's lane is below `LaneQuery.min_gap`,
## `k1_base_per_s * (1 - gap / min_gap)^k1_exponent` points are lost per second. Not
## charged while overtaking: the rule does not apply to overtaking. One segment per
## stretch below the minimum; its extreme is the lowest gap ratio.

const KEY: StringName = &"k1"
const TYPE: StringName = &"gap_too_small"
const CATEGORY: StringName = &"gap"

var _system: ScoringSystem


func _init(system: ScoringSystem) -> void:
	_system = system


## `player` is null when there is nothing to score (no player, or off the road).
func observe(player: VehicleState, dt: float, completed: Array[ScoreEvent]) -> void:
	var event_log: EventLog = _system.event_log
	var ratio: float = gap_ratio(player)
	if ratio >= 1.0:
		if event_log.is_open(KEY):
			completed.append(event_log.close_segment(KEY))
		return
	var config: ScoringConfig = _system.config
	var time_s: float = _system.sim.time_s
	var segment: ScoreEvent = event_log.open_segment(KEY, time_s - dt, TYPE, CATEGORY, INF)
	if ratio <= segment.extreme:
		var speed_kmh: float = ScoringSystem.speed_kmh(player)
		segment.extreme = ratio
		segment.context = {
			"speed_kmh": speed_kmh,
			"gap_m": LaneQuery.gap_to_leader(player, _system.sim.lanes),
			"min_gap_m": LaneQuery.min_gap(speed_kmh),
		}
	event_log.extend_segment(KEY, time_s, -config.k1_base_per_s * pow(1.0 - ratio, config.k1_exponent) * dt)


## Gap to the leader over the legal minimum, clamped to [0, 1]; 1 when K1 does not
## apply (no player, no leader, standing still, or overtaking).
func gap_ratio(player: VehicleState) -> float:
	if player == null:
		return 1.0
	var min_gap: float = LaneQuery.min_gap(ScoringSystem.speed_kmh(player))
	if min_gap <= 0.0:
		return 1.0
	var gap: float = LaneQuery.gap_to_leader(player, _system.sim.lanes)
	if gap >= min_gap or _system.is_overtaking(player):
		return 1.0
	return clampf(gap / min_gap, 0.0, 1.0)
