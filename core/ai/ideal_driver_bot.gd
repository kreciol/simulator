class_name IdealDriverBot
extends RefCounted
## Drives the player by the book through `PlayerCommands`, as the yardstick for exam
## pass marks (spec Q9, Phase 6 step 4; `ExamCalibration`). It holds the speed limit,
## keeps more than the legal gap, overtakes a slower vehicle on the left after
## signalling for `SimConfig.signal_min_on_s`, and returns right as soon as the right
## lane is free. Every judgement uses the same definitions as scoring: `LaneQuery`,
## `ScoringSystem.overtake_justified` and `KeepRightRule.right_lane_free`.
##
## The margins below are the bot's driving style, not game tunables: they only shape
## the measured score that pass marks are derived from.

## Gap kept to the leader, as a multiple of the legal minimum.
const GAP_MARGIN: float = 1.3
## Speed band around the limit the bot coasts in, km/h.
const SPEED_BAND_KMH: float = 0.5
## Share of `SimConfig.braking_mps2` assumed when judging whether a closing gap can
## still be matched gently.
const COMFORT_BRAKING_SHARE: float = 0.5
## Extra signal time beyond the legal minimum before the bot changes lanes, seconds.
const SIGNAL_MARGIN_S: float = 0.1

var sim: TrafficSim
var scoring_config: ScoringConfig


func _init(observed_sim: TrafficSim, config: ScoringConfig) -> void:
	sim = observed_sim
	scoring_config = config


## The player's commands for the coming step.
func commands() -> PlayerCommands:
	var player: VehicleState = sim.player
	var result: PlayerCommands = PlayerCommands.new()
	var wanted: VehicleState.Dir = VehicleState.Dir.NONE
	if not player.lane_change_active and not player.off_road:
		wanted = _wanted_lane_change(player)
	result.longitudinal = _longitudinal(player, wanted)
	if player.lane_change_active or player.off_road:
		return result
	# Signal as soon as a change is wanted and keep signalling while waiting for a safe
	# moment, like a driver waiting for a gap.
	if wanted == VehicleState.Dir.NONE:
		# Toggling the signal's own direction switches it off.
		result.signal_toggle = player.signal_dir
	elif player.signal_dir != wanted:
		result.signal_toggle = wanted
	elif sim.time_s - player.signal_on_since_s >= sim.config.signal_min_on_s + SIGNAL_MARGIN_S \
			and _safe_to_enter(player, player.lane + wanted):
		result.lane_change = wanted
	return result


## Brakes when the gap to any leader on the lanes it occupies would end up below the
## margin, otherwise holds the limit. While waiting to return right it also keeps the
## gap to the right lane's leader, dropping back behind it to slot in.
func _longitudinal(player: VehicleState, wanted: VehicleState.Dir) -> VehicleState.Longitudinal:
	var speed_kmh: float = ScoringSystem.speed_kmh(player)
	var limit_kmh: float = sim.road.speed_limit_kmh
	var may_accelerate: bool = speed_kmh < limit_kmh - SPEED_BAND_KMH
	var brake: bool = speed_kmh > limit_kmh + SPEED_BAND_KMH
	var lanes_to_watch: Array[int] = [player.lane]
	if player.lane_change_active:
		lanes_to_watch.append(player.lane_change_to)
	elif wanted == VehicleState.Dir.RIGHT:
		lanes_to_watch.append(player.lane - 1)
	for lane: int in lanes_to_watch:
		var leader: VehicleState = LaneQuery.leader_in_lane(sim.lanes, lane, player.s, player)
		if leader == null:
			continue
		var margin_m: float = _gap_left_after_matching(player, leader) - _wanted_gap(maxf(player.speed_mps, leader.speed_mps))
		if margin_m < 0.0:
			brake = true
		elif margin_m < LaneQuery.min_gap(speed_kmh) * (GAP_MARGIN - 1.0):
			may_accelerate = false
	if brake:
		return VehicleState.Longitudinal.BRAKE
	if may_accelerate:
		return VehicleState.Longitudinal.ACCELERATE
	return VehicleState.Longitudinal.NONE


## The gap to `leader` once the player has braked gently to its speed.
func _gap_left_after_matching(player: VehicleState, leader: VehicleState) -> float:
	var closing_mps: float = maxf(0.0, player.speed_mps - leader.speed_mps)
	var comfort_mps2: float = sim.config.braking_mps2 * COMFORT_BRAKING_SHARE
	return leader.rear_s() - player.front_s() - closing_mps * closing_mps / (2.0 * comfort_mps2)


func _wanted_gap(speed_mps: float) -> float:
	return LaneQuery.min_gap(speed_mps * TrafficSim.KMH_PER_MPS) * GAP_MARGIN


## Right as soon as the right lane is free (the K2 definition), left to overtake a
## vehicle that justifies it (N1); NONE when neither applies. Whether the target lane
## is safe to enter right now is checked separately.
func _wanted_lane_change(player: VehicleState) -> VehicleState.Dir:
	if player.lane > 0 and KeepRightRule.right_lane_free(player, sim, scoring_config):
		return VehicleState.Dir.RIGHT
	if sim.road.is_lane_on_road(player.lane + 1) and ScoringSystem.overtake_justified(player, sim, scoring_config):
		return VehicleState.Dir.LEFT
	return VehicleState.Dir.NONE


## Whether moving onto `lane` clears N1's target-lane window, still leaves the legal gap
## ahead once matched to the leader there, and forces the follower there into no
## harder braking than an AI lane change may (`mobil_safe_decel_mps2`).
func _safe_to_enter(player: VehicleState, lane: int) -> bool:
	var half_length_m: float = player.length_m / 2.0
	if not LaneQuery.is_lane_free(sim.lanes, lane, player.s,
			half_length_m + scoring_config.n1_clear_ahead_m, half_length_m + scoring_config.n1_clear_behind_m, player):
		return false
	var leader: VehicleState = LaneQuery.leader_in_lane(sim.lanes, lane, player.s, player)
	if leader != null:
		# A faster leader pulls away while the change runs.
		var opening_m: float = maxf(0.0, leader.speed_mps - player.speed_mps) * sim.config.lane_change_duration_s
		if _gap_left_after_matching(player, leader) + opening_m < LaneQuery.min_gap(ScoringSystem.speed_kmh(player)):
			return false
	var follower: VehicleState = LaneQuery.follower_in_lane(sim.lanes, lane, player.s, player)
	return follower == null \
			or AiDriver.acceleration_behind(sim, follower, player) >= -sim.config.mobil_safe_decel_mps2
