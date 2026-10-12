class_name ScoringSystem
extends RefCounted
## Scores the player's driving (requirements §8, spec Architecture: Scoring). Observes a
## `TrafficSim` and never mutates it: call `observe(dt)` after every `sim.step(dt)`.
## Each rule is a small object writing to one shared `EventLog`; categories are &"gap"
## (K1, N3), &"lane" (K2, N1, N2), &"signal" (K3), &"speed" (S1) and &"collision" (K4).

## Emitted for every event completed during `observe` or `finish`: instant events and
## closed segments, in completion order.
signal score_event_emitted(event: ScoreEvent)

var sim: TrafficSim
var config: ScoringConfig
var event_log: EventLog = EventLog.new()

var gap_rule: GapRule
var keep_right_rule: KeepRightRule
var signal_rule: SignalRule
var right_lane_rule: RightLaneRule
var gap_kept_rule: GapKeptRule
var lane_change_rule: LaneChangeRule
var speed_rule: SpeedRule
var collision_rule: CollisionRule


func _init(observed_sim: TrafficSim, scoring_config: ScoringConfig) -> void:
	sim = observed_sim
	config = scoring_config
	gap_rule = GapRule.new(sim, config, event_log)
	keep_right_rule = KeepRightRule.new(sim, config, event_log)
	signal_rule = SignalRule.new(sim, config, event_log)
	right_lane_rule = RightLaneRule.new(sim, config, event_log)
	gap_kept_rule = GapKeptRule.new(sim, config, event_log)
	lane_change_rule = LaneChangeRule.new(sim, config, event_log)
	speed_rule = SpeedRule.new(sim, config, event_log)
	collision_rule = CollisionRule.new(sim, config, event_log)


## Scores the step of length `dt` that `sim` just finished and returns the events it
## completed. Continuous segments are extended to `sim.time_s`.
func observe(dt: float) -> Array[ScoreEvent]:
	var completed: Array[ScoreEvent] = _take_instant_events()
	var player: VehicleState = sim.player
	var active: bool = player != null and not player.off_road
	gap_rule.observe(player if active else null, dt, completed)
	keep_right_rule.observe(player if active else null, dt, completed)
	right_lane_rule.observe(player if active else null, dt, completed)
	gap_kept_rule.observe(player if active else null, dt, completed)
	speed_rule.observe(player if active else null, dt, completed)
	for event: ScoreEvent in completed:
		score_event_emitted.emit(event)
	return completed


## Closes every open segment at the end of a session and returns the completed events.
func finish() -> Array[ScoreEvent]:
	var completed: Array[ScoreEvent] = _take_instant_events()
	completed.append_array(event_log.close_all())
	for event: ScoreEvent in completed:
		score_event_emitted.emit(event)
	return completed


## The session total: every point so far, never below `score_floor` (Q6).
func total_score() -> float:
	return maxf(config.score_floor, event_log.total())


## One category's sub-score, unclamped: it may be negative (Q6; feedback uses it).
func category_score(category: StringName) -> float:
	return event_log.total_for(category)


## Instant events the signal-driven rules logged since the last call.
func _take_instant_events() -> Array[ScoreEvent]:
	var events: Array[ScoreEvent] = signal_rule.take_events()
	events.append_array(lane_change_rule.take_events())
	events.append_array(collision_rule.take_events())
	return events


static func speed_kmh(vehicle: VehicleState) -> float:
	return vehicle.speed_mps * TrafficSim.KMH_PER_MPS


## Whether a slower vehicle ahead on `player`'s lane, within `n1_overtake_reason_m`,
## makes overtaking it the right call (requirements §8.3 N1): it is slower than the
## player, or at least `n1_slow_vehicle_margin_kmh` below the limit (the player may
## already have slowed down behind it).
static func overtake_justified(player: VehicleState, observed_sim: TrafficSim, scoring_config: ScoringConfig) -> bool:
	var leader: VehicleState = LaneQuery.leader_in_lane(observed_sim.lanes, player.lane, player.s, player)
	if leader == null or leader.rear_s() - player.front_s() > scoring_config.n1_overtake_reason_m:
		return false
	var slow_kmh: float = observed_sim.road.speed_limit_kmh - scoring_config.n1_slow_vehicle_margin_kmh
	return leader.speed_mps < player.speed_mps or speed_kmh(leader) <= slow_kmh
