class_name Idm
extends RefCounted
## Intelligent Driver Model car-following (spec Research: Treiber & Kesting), with a
## time headway stretched to the legal gap for disciplined drivers (requirements §7.2).
## Static and pure; parameters come from `SimConfig`.

## Keeps the interaction term finite when bodies touch or overlap.
const GAP_EPSILON_M: float = 0.01


## Acceleration of a driver at `speed_mps` wanting `desired_speed_mps`, `gap_m` behind
## a leader at `leader_speed_mps` (bumper to bumper; INF on a free road). Never brakes
## harder than `ai_max_decel_mps2`.
static func acceleration(
		speed_mps: float,
		desired_speed_mps: float,
		gap_m: float,
		leader_speed_mps: float,
		time_headway_s: float,
		config: SimConfig) -> float:
	var free_road: float = 1.0 - pow(speed_mps / maxf(desired_speed_mps, GAP_EPSILON_M), config.idm_accel_exponent)
	var interaction: float = 0.0
	if gap_m < INF:
		var approach_mps: float = speed_mps - leader_speed_mps
		var dynamic_gap: float = speed_mps * time_headway_s \
				+ speed_mps * approach_mps / (2.0 * sqrt(config.idm_max_accel_mps2 * config.idm_comfort_decel_mps2))
		var desired_gap: float = config.idm_min_spacing_m + maxf(0.0, dynamic_gap)
		interaction = pow(desired_gap / maxf(gap_m, GAP_EPSILON_M), 2.0)
	return maxf(config.idm_max_accel_mps2 * (free_road - interaction), -config.ai_max_decel_mps2)


## Desired time headway for `discipline` in [0, 1]: IDM's `T` at 0; at 1 the larger of
## `T` and the legal gap divided by speed (`T_eff`, spec Research), so a model driver
## settles at or beyond the legal minimum.
static func time_headway(discipline: float, config: SimConfig) -> float:
	# The legal gap grows linearly with speed: the gap at 1 m/s is the headway in seconds.
	var legal_headway_s: float = LaneQuery.min_gap(TrafficSim.KMH_PER_MPS)
	return lerpf(config.idm_time_headway_s, maxf(config.idm_time_headway_s, legal_headway_s), clampf(discipline, 0.0, 1.0))
