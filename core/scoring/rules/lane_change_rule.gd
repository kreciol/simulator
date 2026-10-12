class_name LaneChangeRule
extends RefCounted
## N1 — correct lane change (requirements §8.3). A player lane change is judged when it
## starts and rewarded with `n1_reward` when it completes on the road, if it was:
## - signalled in time and in its direction (`LaneQuery.signal_valid` is OK);
## - into a free lane (`LaneQuery.is_lane_free` with `n1_clear_ahead_m` /
##   `n1_clear_behind_m` beyond the body), so nobody is forced to brake;
## - justified: left to overtake a slower vehicle ahead
##   (`ScoringSystem.overtake_justified`), or right to return to a free right lane
##   (the K2 definition) after such an overtake;
## - at least `n1_cooldown_s` after the previous N1.
## Anti-farming (§8.3): an aimless change left earns nothing, and neither does the
## return from it, so swinging left and back never adds points.

const TYPE: StringName = &"lane_change_ok"
const CATEGORY: StringName = &"lane"
const REASON_OVERTAKE: StringName = &"overtake"
const REASON_RETURN: StringName = &"return_right"

var _sim: TrafficSim
var _config: ScoringConfig
var _event_log: EventLog
## Events logged since the last `take_events`.
var _pending: Array[ScoreEvent] = []
## Reason of the change in progress when it qualifies for N1; empty otherwise.
var _qualified_reason: StringName = &""
## Set by a justified change left; a later return right is justified only after one.
var _overtake_started: bool = false
var _last_reward_s: float = -INF


func _init(sim: TrafficSim, config: ScoringConfig, event_log: EventLog) -> void:
	_sim = sim
	_config = config
	_event_log = event_log
	_sim.lane_change_started.connect(_on_lane_change_started)
	_sim.lane_change_finished.connect(_on_lane_change_finished)


## Hands over the events logged since the last call.
func take_events() -> Array[ScoreEvent]:
	var events: Array[ScoreEvent] = _pending
	_pending = []
	return events


## Runs inside `TrafficSim.step` as the change starts: `player.lane` is still the origin.
func _on_lane_change_started(vehicle_id: int, _from_lane: int, to_lane: int) -> void:
	var player: VehicleState = _sim.player
	if player == null or vehicle_id != player.id:
		return
	var dir: VehicleState.Dir = player.lane_change_dir()
	var reason: StringName = &""
	if dir == VehicleState.Dir.LEFT and ScoringSystem.overtake_justified(player, _sim, _config):
		reason = REASON_OVERTAKE
	elif dir == VehicleState.Dir.RIGHT and _overtake_started and KeepRightRule.right_lane_free(player, _sim, _config):
		reason = REASON_RETURN
	_overtake_started = reason == REASON_OVERTAKE or (_overtake_started and dir == VehicleState.Dir.LEFT)
	_qualified_reason = reason if _qualifies(player, to_lane) else &""


## Runs inside `TrafficSim.step` before off-road is flagged, so the target lane is
## checked directly.
func _on_lane_change_finished(vehicle_id: int, lane: int) -> void:
	var player: VehicleState = _sim.player
	if player == null or vehicle_id != player.id:
		return
	var reason: StringName = _qualified_reason
	_qualified_reason = &""
	if reason.is_empty() or not _sim.road.is_lane_on_road(lane):
		return
	_last_reward_s = _sim.time_s
	var context: Dictionary = {"reason": reason, "lane_to": lane, "speed_kmh": ScoringSystem.speed_kmh(player)}
	_pending.append(_event_log.add_instant(_sim.time_s, TYPE, CATEGORY, _config.n1_reward, context))


## Signal, safety and cooldown conditions, judged as the change starts.
func _qualifies(player: VehicleState, to_lane: int) -> bool:
	if _sim.time_s - _last_reward_s < _config.n1_cooldown_s:
		return false
	if not _sim.road.is_lane_on_road(to_lane):
		return false
	var signal_result: LaneQuery.SignalResult = LaneQuery.signal_valid(
			player.lane_change_dir(), player.signal_dir, _sim.time_s - player.signal_on_since_s,
			_sim.config.signal_min_on_s)
	if signal_result != LaneQuery.SignalResult.OK:
		return false
	var half_length_m: float = player.length_m / 2.0
	return LaneQuery.is_lane_free(_sim.lanes, to_lane, player.s,
			half_length_m + _config.n1_clear_ahead_m, half_length_m + _config.n1_clear_behind_m, player)
