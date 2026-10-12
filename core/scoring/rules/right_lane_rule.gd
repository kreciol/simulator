class_name RightLaneRule
extends RefCounted
## N2 — keeping the rightmost lane when there is no need to overtake (requirements
## §8.3): `n2_reward_per_s` while on the rightmost lane, not changing lanes, and not
## stuck behind a slower vehicle that justifies overtaking it. One segment per stretch.

const KEY: StringName = &"n2"
const TYPE: StringName = &"right_lane_kept"
const CATEGORY: StringName = &"lane"

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
	var segment: ScoreEvent = _event_log.open_segment(KEY, time_s - dt, TYPE, CATEGORY, 0.0)
	segment.extreme = time_s - segment.timestamp_s
	_event_log.extend_segment(KEY, time_s, _config.n2_reward_per_s * dt)


func applies(player: VehicleState) -> bool:
	if player == null or player.lane != 0 or player.lane_change_active:
		return false
	return not ScoringSystem.overtake_justified(player, _sim, _config)
