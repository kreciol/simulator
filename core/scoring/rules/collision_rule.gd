class_name CollisionRule
extends RefCounted
## K4 — collision or leaving the road (requirements §8.2, §9.2): `k4_penalty` once per
## player collision (the sim reports each contact once) and once when the player ends
## off the road. Category &"collision": counted in the total, shown in the session
## status rather than as a score bar (spec Architecture: Scoring). What the session
## does next depends on the mode (learn respawn / exam end, E08).

const CATEGORY: StringName = &"collision"
const TYPE_COLLISION: StringName = &"collision"
const TYPE_OFFROAD: StringName = &"offroad"

var _sim: TrafficSim
var _config: ScoringConfig
var _event_log: EventLog
## Events logged since the last `take_events`.
var _pending: Array[ScoreEvent] = []


func _init(sim: TrafficSim, config: ScoringConfig, event_log: EventLog) -> void:
	_sim = sim
	_config = config
	_event_log = event_log
	_sim.collision.connect(_on_collision)
	_sim.offroad.connect(_on_offroad)


## Hands over the events logged since the last call.
func take_events() -> Array[ScoreEvent]:
	var events: Array[ScoreEvent] = _pending
	_pending = []
	return events


func _on_collision(vehicle_id: int, other_id: int) -> void:
	var player: VehicleState = _sim.player
	if player == null or (vehicle_id != player.id and other_id != player.id):
		return
	var other: int = other_id if vehicle_id == player.id else vehicle_id
	_log(TYPE_COLLISION, {"other_id": other, "speed_kmh": ScoringSystem.speed_kmh(player)})


func _on_offroad(vehicle_id: int) -> void:
	var player: VehicleState = _sim.player
	if player == null or vehicle_id != player.id:
		return
	_log(TYPE_OFFROAD, {"speed_kmh": ScoringSystem.speed_kmh(player)})


func _log(type: StringName, context: Dictionary) -> void:
	_pending.append(_event_log.add_instant(_sim.time_s, type, CATEGORY, -_config.k4_penalty, context))
