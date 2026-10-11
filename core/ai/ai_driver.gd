class_name AiDriver
extends RefCounted
## Decisions of one AI car (requirements §7): IDM car-following each step and
## simplified MOBIL lane changes in the asymmetric keep-right variant (spec Research):
## overtake on the left, return right, signal `ai_signal_lead_s` before changing. The
## car itself is a `VehicleState` like the player's; `TrafficSim` asks its driver to
## decide before integrating. AI does not treat the player specially (§7.1).

## Lane change candidates, right first so a tie keeps right; a constant so deciding
## allocates nothing per step.
const LANE_CHANGE_DIRS: Array[VehicleState.Dir] = [VehicleState.Dir.RIGHT, VehicleState.Dir.LEFT]

## Speed the driver cruises at on a free road.
var desired_speed_mps: float
## 1 = model driver (legal gap, keep-right); lower values drive less by the book (Q13).
var discipline: float
## Acceleration chosen for the coming step.
var accel_mps2: float = 0.0


func _init(desired_speed: float, driver_discipline: float) -> void:
	desired_speed_mps = desired_speed
	discipline = clampf(driver_discipline, 0.0, 1.0)


## Chooses this step's acceleration for `vehicle`, which this driver controls, and
## signals, starts or abandons a lane change.
func decide(sim: TrafficSim, vehicle: VehicleState) -> void:
	accel_mps2 = _following_acceleration(sim, vehicle)
	if vehicle.lane_change_active or vehicle.off_road:
		return
	if vehicle.signal_dir == VehicleState.Dir.NONE:
		_consider_lane_change(sim, vehicle)
	else:
		_continue_signalled_change(sim, vehicle)


## MOBIL incentive of moving `vehicle` one lane in `dir`, in m/s², in the asymmetric
## keep-right variant: a move left counts only the driver's own acceleration gain
## minus the keep-right bias, so a slow car never pulls left just to let a faster one
## by; a move right adds the bias and the politeness-weighted gains of the old and new
## followers, and never gains speed over the left lane's leader, so the AI does not
## pass on the right (Q5). The bias is `mobil_keep_right_bias_mps2` scaled by
## discipline. -INF when the change is unsafe: the target lane is off the road or not
## free within the clearance (`LaneQuery.is_lane_free`), or the new follower would
## have to brake harder than `mobil_safe_decel_mps2`. The own gain is measured against
## `accel_mps2`, so call this after `decide` has run for the current step.
func lane_change_incentive(sim: TrafficSim, vehicle: VehicleState, dir: VehicleState.Dir) -> float:
	var config: SimConfig = sim.config
	var target: int = vehicle.lane + dir
	if not sim.road.is_lane_on_road(target):
		return -INF
	var reach: float = vehicle.length_m / 2.0 + config.ai_lane_change_clearance_m
	if not LaneQuery.is_lane_free(sim.vehicles, target, vehicle.s, reach, reach, vehicle):
		return -INF
	var new_leader: VehicleState = LaneQuery.leader_in_lane(sim.vehicles, target, vehicle.s, vehicle)
	var new_follower: VehicleState = LaneQuery.follower_in_lane(sim.vehicles, target, vehicle.s, vehicle)
	var new_follower_gain: float = 0.0
	if new_follower != null:
		var new_follower_after: float = acceleration_behind(sim, new_follower, vehicle)
		if new_follower_after < -config.mobil_safe_decel_mps2:
			return -INF
		new_follower_gain = new_follower_after - acceleration_behind(sim, new_follower, new_leader)

	var own_after: float = acceleration_behind(sim, vehicle, new_leader)
	var bias: float = config.mobil_keep_right_bias_mps2 * discipline
	if dir == VehicleState.Dir.LEFT:
		return own_after - accel_mps2 - bias
	var old_leader: VehicleState = LaneQuery.leader_in_lane(sim.vehicles, vehicle.lane, vehicle.s, vehicle)
	var old_follower: VehicleState = LaneQuery.follower_in_lane(sim.vehicles, vehicle.lane, vehicle.s, vehicle)
	var old_follower_gain: float = 0.0
	if old_follower != null:
		old_follower_gain = acceleration_behind(sim, old_follower, old_leader) - acceleration_behind(sim, old_follower, vehicle)
	own_after = minf(own_after, acceleration_behind(sim, vehicle, old_leader))
	return own_after - accel_mps2 + config.mobil_politeness * (new_follower_gain + old_follower_gain) + bias


## IDM acceleration of `follower` behind `leader` (null: free road). Vehicles without a
## driver (the player, scripted cars) are modelled as model drivers wanting top speed.
static func acceleration_behind(sim: TrafficSim, follower: VehicleState, leader: VehicleState) -> float:
	var desired_speed: float = sim.max_speed_mps()
	var follower_discipline: float = 1.0
	if follower.ai != null:
		desired_speed = follower.ai.desired_speed_mps
		follower_discipline = follower.ai.discipline
	var gap: float = INF
	var leader_speed: float = 0.0
	if leader != null:
		gap = leader.rear_s() - follower.front_s()
		leader_speed = leader.speed_mps
	return Idm.acceleration(
			follower.speed_mps,
			desired_speed,
			gap,
			leader_speed,
			Idm.time_headway(follower_discipline, sim.config),
			sim.config)


## Follows the leader on the current lane and, while changing lanes, also the one on
## the target lane.
func _following_acceleration(sim: TrafficSim, vehicle: VehicleState) -> float:
	var accel: float = acceleration_behind(sim, vehicle, LaneQuery.leader_in_lane(sim.vehicles, vehicle.lane, vehicle.s, vehicle))
	if vehicle.lane_change_active:
		var target_leader: VehicleState = LaneQuery.leader_in_lane(sim.vehicles, vehicle.lane_change_to, vehicle.s, vehicle)
		accel = minf(accel, acceleration_behind(sim, vehicle, target_leader))
	return accel


## Signals towards the better lane when its incentive beats `mobil_threshold_mps2`.
func _consider_lane_change(sim: TrafficSim, vehicle: VehicleState) -> void:
	var best_dir: VehicleState.Dir = VehicleState.Dir.NONE
	var best_incentive: float = sim.config.mobil_threshold_mps2
	for dir: VehicleState.Dir in LANE_CHANGE_DIRS:
		var incentive: float = lane_change_incentive(sim, vehicle, dir)
		if incentive > best_incentive:
			best_dir = dir
			best_incentive = incentive
	if best_dir != VehicleState.Dir.NONE:
		sim.toggle_signal(vehicle, best_dir)


## While signalling: starts the change once the signal has been on for the lead time,
## or switches the signal off when the change is no longer safe or worthwhile. Keeping
## a signalled change only needs a positive incentive, so the signal does not flicker
## around the threshold.
func _continue_signalled_change(sim: TrafficSim, vehicle: VehicleState) -> void:
	var dir: VehicleState.Dir = vehicle.signal_dir
	if lane_change_incentive(sim, vehicle, dir) <= 0.0:
		sim.toggle_signal(vehicle, dir)
		return
	if sim.time_s - vehicle.signal_on_since_s + LaneQuery.TIME_EPSILON >= sim.config.ai_signal_lead_s:
		sim.request_lane_change(vehicle, dir)
