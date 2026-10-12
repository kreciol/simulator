class_name KeepRightRule
extends RefCounted
## K2 — staying in a left lane while the lane to the right is free (requirements §8.2).
## The player first gets `k2_grace_s` to return right (learn mode hints during it,
## §11.2), then loses `k2_penalty_per_s` per second. Not charged while overtaking or
## while already returning right. One segment per stretch, grace included (the session
## record sums it as unjustified left-lane time); its extreme is the stretch's length.

const KEY: StringName = &"k2"
const TYPE: StringName = &"left_lane_unjustified"
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
	var segment: ScoreEvent = _event_log.open_segment(KEY, time_s - dt, TYPE, CATEGORY, 0.0, {"lane": player.lane})
	var elapsed_s: float = time_s - segment.timestamp_s
	var penalised_s: float = clampf(elapsed_s - _config.k2_grace_s, 0.0, dt)
	segment.extreme = elapsed_s
	_event_log.extend_segment(KEY, time_s, -_config.k2_penalty_per_s * penalised_s)


## Seconds left to return right before K2 is charged; negative once the penalty runs,
## INF when K2 does not apply. For preventive hints (§11.2).
func grace_remaining_s() -> float:
	var segment: ScoreEvent = _event_log.open_segment_for(KEY)
	if segment == null:
		return INF
	return _config.k2_grace_s - segment.duration_s()


## Whether K2 applies to `player` now: on a lane left of the rightmost one, not
## returning right, not overtaking, and the lane to the right is free.
func applies(player: VehicleState) -> bool:
	if player == null or player.lane <= 0 or not _sim.road.is_lane_on_road(player.lane):
		return false
	if player.lane_change_dir() == VehicleState.Dir.RIGHT or LaneQuery.is_overtaking(player, _sim.lanes, _config.overtake_look_ahead_m):
		return false
	return is_right_lane_free(player)


## The lane to the right is free when returning there would not soon force another
## overtake (requirements §8.4): nothing alongside or `k2_look_behind_m` behind, and
## nothing within the distance the player would close on the right-lane leader in
## `k2_return_horizon_s` (at least `k2_min_look_ahead_m`).
func is_right_lane_free(player: VehicleState) -> bool:
	return right_lane_free(player, _sim, _config)


## `is_right_lane_free` for any sim and config; N1 uses the same definition to tell a
## justified return right.
static func right_lane_free(player: VehicleState, sim: TrafficSim, config: ScoringConfig) -> bool:
	var lanes: LaneIndex = sim.lanes
	var right_lane: int = player.lane - 1
	var leader: VehicleState = LaneQuery.leader_in_lane(lanes, right_lane, player.s, player)
	var closing_mps: float = 0.0 if leader == null else player.speed_mps - leader.speed_mps
	var half_length_m: float = player.length_m / 2.0
	var look_ahead_m: float = half_length_m + maxf(config.k2_min_look_ahead_m, closing_mps * config.k2_return_horizon_s)
	var look_behind_m: float = half_length_m + config.k2_look_behind_m
	return LaneQuery.is_lane_free(lanes, right_lane, player.s, look_ahead_m, look_behind_m, player)
