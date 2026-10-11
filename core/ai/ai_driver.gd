class_name AiDriver
extends RefCounted
## Decisions of one AI car (requirements §7): IDM car-following each step. The car
## itself is a `VehicleState` like the player's; `TrafficSim` asks its driver to
## decide before integrating. AI does not treat the player specially (§7.1).

## Speed the driver cruises at on a free road.
var desired_speed_mps: float
## 1 = model driver (legal gap, keep-right); lower values drive less by the book (Q13).
var discipline: float
## Acceleration chosen for the coming step.
var accel_mps2: float = 0.0


func _init(desired_speed: float, driver_discipline: float) -> void:
	desired_speed_mps = desired_speed
	discipline = clampf(driver_discipline, 0.0, 1.0)


## Chooses this step's acceleration for `vehicle`, which this driver controls.
func decide(sim: TrafficSim, vehicle: VehicleState) -> void:
	accel_mps2 = _following_acceleration(sim, vehicle)


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
