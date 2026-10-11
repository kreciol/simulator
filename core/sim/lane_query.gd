class_name LaneQuery
extends RefCounted
## Shared lane logic (requirements §8.4): the one definition of free lanes, gaps,
## overtaking and signal validity used by AI, scoring and hints alike. Static and
## pure; callers own the look-ahead/behind windows, which are [PARAM]s of their rules.

enum SignalResult { OK, LATE, NONE, WRONG }

## Legal minimum following distance: metres per km/h of speed (art. 19 ust. 3 pkt 2
## Prawo o ruchu drogowym, requirements §8.2 K1).
const MIN_GAP_M_PER_KMH: float = 0.5
## Absorbs float drift in sim time summed over fixed steps, so a signal held for
## exactly the minimum is not rated LATE.
const TIME_EPSILON: float = 1e-6


static func min_gap(speed_kmh: float) -> float:
	return speed_kmh * MIN_GAP_M_PER_KMH


## A vehicle occupies its lane and, while changing lanes, its target lane too.
static func occupies_lane(vehicle: VehicleState, lane: int) -> bool:
	return vehicle.lane == lane or (vehicle.lane_change_active and vehicle.lane_change_to == lane)


## Whether no vehicle body reaches into `[s - look_behind_m, s + look_ahead_m]` on
## `lane`. `ignore` (typically the querying vehicle) is skipped.
static func is_lane_free(
		vehicles: Array[VehicleState],
		lane: int,
		s: float,
		look_ahead_m: float,
		look_behind_m: float,
		ignore: VehicleState = null) -> bool:
	for other: VehicleState in vehicles:
		if other == ignore or not occupies_lane(other, lane):
			continue
		if other.rear_s() <= s + look_ahead_m and other.front_s() >= s - look_behind_m:
			return false
	return true


## Distance from `vehicle`'s front to the rear of the nearest vehicle ahead in its
## lane (`vehicle.lane`, the origin lane while changing); INF when there is none.
static func gap_to_leader(vehicle: VehicleState, vehicles: Array[VehicleState]) -> float:
	var leader: VehicleState = leader_in_lane(vehicles, vehicle.lane, vehicle.s, vehicle)
	if leader == null:
		return INF
	return leader.rear_s() - vehicle.front_s()


## The vehicle on `lane` whose centre is ahead of `s` and whose rear is nearest;
## null when there is none. `ignore` (typically the querying vehicle) is skipped.
static func leader_in_lane(
		vehicles: Array[VehicleState],
		lane: int,
		s: float,
		ignore: VehicleState = null) -> VehicleState:
	var leader: VehicleState = null
	for other: VehicleState in vehicles:
		if other == ignore or other.s <= s or not occupies_lane(other, lane):
			continue
		if leader == null or other.rear_s() < leader.rear_s():
			leader = other
	return leader


## The vehicle on `lane` whose centre is behind `s` and whose front is nearest;
## null when there is none. `ignore` (typically the querying vehicle) is skipped.
static func follower_in_lane(
		vehicles: Array[VehicleState],
		lane: int,
		s: float,
		ignore: VehicleState = null) -> VehicleState:
	var follower: VehicleState = null
	for other: VehicleState in vehicles:
		if other == ignore or other.s >= s or not occupies_lane(other, lane):
			continue
		if follower == null or other.front_s() > follower.front_s():
			follower = other
	return follower


## Whether `vehicle` is overtaking: changing lanes to the left, or left of the
## rightmost lane with a slower vehicle on the lane to its right that is alongside or
## at most `look_ahead_m` ahead of its front.
static func is_overtaking(vehicle: VehicleState, vehicles: Array[VehicleState], look_ahead_m: float) -> bool:
	if vehicle.lane_change_dir() == VehicleState.Dir.LEFT:
		return true
	if vehicle.lane <= 0:
		return false
	var right_lane: int = vehicle.lane - 1
	for other: VehicleState in vehicles:
		if other == vehicle or not occupies_lane(other, right_lane):
			continue
		if other.speed_mps >= vehicle.speed_mps:
			continue
		if other.front_s() >= vehicle.rear_s() and other.rear_s() <= vehicle.front_s() + look_ahead_m:
			return true
	return false


## Rates the signal at the start of a lane change in `change_dir` (requirements §6.5,
## §8.2 K3): NONE when off, WRONG when on the other side, LATE when on for less than
## `min_on_s`, otherwise OK.
static func signal_valid(
		change_dir: VehicleState.Dir,
		signal_dir: VehicleState.Dir,
		signal_on_s: float,
		min_on_s: float) -> SignalResult:
	if signal_dir == VehicleState.Dir.NONE:
		return SignalResult.NONE
	if signal_dir != change_dir:
		return SignalResult.WRONG
	if signal_on_s + TIME_EPSILON < min_on_s:
		return SignalResult.LATE
	return SignalResult.OK
