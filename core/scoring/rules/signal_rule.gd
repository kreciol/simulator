class_name SignalRule
extends RefCounted
## K3 — lane change without a valid signal (requirements §8.2, §6.5). Each player lane
## change is rated by `LaneQuery.signal_valid` the moment it starts: no signal or the
## wrong direction costs `k3_penalty`, a late signal `k3_penalty * k3_late_factor`, a
## correct one nothing (logged with 0 points, for feedback and the session stats).

const CATEGORY: StringName = &"signal"
const TYPE_OK: StringName = &"signal_ok"
const TYPE_LATE: StringName = &"late_signal"
const TYPE_NONE: StringName = &"no_signal"
const TYPE_WRONG: StringName = &"wrong_signal"

var _sim: TrafficSim
var _config: ScoringConfig
var _event_log: EventLog
## Events logged since the last `take_events`.
var _pending: Array[ScoreEvent] = []


func _init(sim: TrafficSim, config: ScoringConfig, event_log: EventLog) -> void:
	_sim = sim
	_config = config
	_event_log = event_log
	_sim.lane_change_started.connect(_on_lane_change_started)


## Hands over the events logged since the last call.
func take_events() -> Array[ScoreEvent]:
	var events: Array[ScoreEvent] = _pending
	_pending = []
	return events


## Runs inside `TrafficSim.step` while it applies commands, so `_sim.time_s` is the
## time the change starts and the player's signal is as the change found it.
func _on_lane_change_started(vehicle_id: int, from_lane: int, to_lane: int) -> void:
	var player: VehicleState = _sim.player
	if player == null or vehicle_id != player.id:
		return
	var signal_on_s: float = _sim.time_s - player.signal_on_since_s
	var result: LaneQuery.SignalResult = LaneQuery.signal_valid(
			player.lane_change_dir(), player.signal_dir, signal_on_s, _sim.config.signal_min_on_s)
	var type: StringName = TYPE_OK
	var points: float = 0.0
	match result:
		LaneQuery.SignalResult.LATE:
			type = TYPE_LATE
			points = -_config.k3_penalty * _config.k3_late_factor
		LaneQuery.SignalResult.NONE:
			type = TYPE_NONE
			points = -_config.k3_penalty
		LaneQuery.SignalResult.WRONG:
			type = TYPE_WRONG
			points = -_config.k3_penalty
	var context: Dictionary = {
		"lane_from": from_lane,
		"lane_to": to_lane,
		"speed_kmh": ScoringSystem.speed_kmh(player),
		"signal_on_s": signal_on_s if player.signal_dir != VehicleState.Dir.NONE else 0.0,
	}
	_pending.append(_event_log.add_instant(_sim.time_s, type, CATEGORY, points, context))
