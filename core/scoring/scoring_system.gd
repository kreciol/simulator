class_name ScoringSystem
extends RefCounted
## Scores the player's driving (requirements §8, spec Architecture: Scoring). Observes a
## `TrafficSim` and never mutates it: call `observe(dt)` after every `sim.step(dt)`.
## Each rule is a small object writing to one shared `EventLog`; categories are &"gap"
## (K1), &"lane" (K2) and &"signal" (K3).

## Emitted for every event completed during `observe` or `finish`: instant events and
## closed segments, in completion order.
signal score_event_emitted(event: ScoreEvent)

var sim: TrafficSim
var config: ScoringConfig
var event_log: EventLog = EventLog.new()

var gap_rule: GapRule


func _init(observed_sim: TrafficSim, scoring_config: ScoringConfig) -> void:
	sim = observed_sim
	config = scoring_config
	gap_rule = GapRule.new(self)


## Scores the step of length `dt` that `sim` just finished and returns the events it
## completed. Continuous segments are extended to `sim.time_s`.
func observe(dt: float) -> Array[ScoreEvent]:
	var completed: Array[ScoreEvent] = []
	var player: VehicleState = sim.player
	var active: bool = player != null and not player.off_road
	gap_rule.observe(player if active else null, dt, completed)
	for event: ScoreEvent in completed:
		score_event_emitted.emit(event)
	return completed


## Closes every open segment at the end of a session and returns the completed events.
func finish() -> Array[ScoreEvent]:
	var completed: Array[ScoreEvent] = []
	completed.append_array(event_log.close_all())
	for event: ScoreEvent in completed:
		score_event_emitted.emit(event)
	return completed


## Whether `vehicle` is overtaking under the scoring look-ahead (§8.4); K1 and K2 are
## not charged while it is.
func is_overtaking(vehicle: VehicleState) -> bool:
	return LaneQuery.is_overtaking(vehicle, sim.lanes, config.overtake_look_ahead_m)


static func speed_kmh(vehicle: VehicleState) -> float:
	return vehicle.speed_mps * TrafficSim.KMH_PER_MPS
