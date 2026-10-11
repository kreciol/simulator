class_name LaneIndex
extends RefCounted
## The vehicles on each lane, sorted by `s` ascending, so `LaneQuery` finds neighbours
## with a binary search and a short local scan instead of visiting every vehicle. A
## vehicle is listed on each lane it occupies (`LaneQuery.occupies_lane`): its lane
## and, while changing lanes, its target lane. `TrafficSim` keeps its index current;
## `from_vehicles` builds one from any vehicle list.

## Lanes kept beyond each edge of the carriageway, where off-road lane changes end.
const OFF_ROAD_LANES: int = 1

## Longest body ever listed; bounds how far from a position a body can reach.
var max_length_m: float = 0.0

## One `Array[VehicleState]` per lane, from lane `-OFF_ROAD_LANES` upwards.
var _lanes: Array = []
## Returned for lanes outside the index; never written.
var _no_vehicles: Array[VehicleState] = []


func _init(lane_count: int) -> void:
	for i: int in lane_count + 2 * OFF_ROAD_LANES:
		var vehicles_on_lane: Array[VehicleState] = []
		_lanes.append(vehicles_on_lane)


## An index of `vehicles` on a road with `lane_count` lanes.
static func from_vehicles(vehicles: Array[VehicleState], lane_count: int) -> LaneIndex:
	var index: LaneIndex = LaneIndex.new(lane_count)
	for vehicle: VehicleState in vehicles:
		index.add(vehicle)
	return index


## Index of the first vehicle in `sorted` whose `s` is at least `s` (`sorted.size()`
## when there is none).
static func lower_bound(sorted: Array[VehicleState], s: float) -> int:
	var low: int = 0
	var high: int = sorted.size()
	while low < high:
		var middle: int = (low + high) >> 1
		if sorted[middle].s < s:
			low = middle + 1
		else:
			high = middle
	return low


## Index of the first vehicle in `sorted` whose `s` is greater than `s`.
static func upper_bound(sorted: Array[VehicleState], s: float) -> int:
	var low: int = 0
	var high: int = sorted.size()
	while low < high:
		var middle: int = (low + high) >> 1
		if sorted[middle].s <= s:
			low = middle + 1
		else:
			high = middle
	return low


## The lowest lane the index lists (off the road on the right).
func first_lane() -> int:
	return -OFF_ROAD_LANES


## One past the highest lane the index lists.
func end_lane() -> int:
	return _lanes.size() - OFF_ROAD_LANES


## Vehicles occupying `lane`, sorted by `s` ascending. Read-only for callers.
func on_lane(lane: int) -> Array[VehicleState]:
	var slot: int = lane + OFF_ROAD_LANES
	if slot < 0 or slot >= _lanes.size():
		return _no_vehicles
	return _lanes[slot]


## Lists `vehicle` on every lane it occupies.
func add(vehicle: VehicleState) -> void:
	insert(vehicle, vehicle.lane)
	if vehicle.lane_change_active and vehicle.lane_change_to != vehicle.lane:
		insert(vehicle, vehicle.lane_change_to)


## Removes `vehicle` from every lane it occupies.
func remove(vehicle: VehicleState) -> void:
	erase(vehicle, vehicle.lane)
	if vehicle.lane_change_active:
		erase(vehicle, vehicle.lane_change_to)


## Lists `vehicle` on `lane` at its sorted position.
func insert(vehicle: VehicleState, lane: int) -> void:
	if lane < first_lane() or lane >= end_lane():
		push_error("LaneIndex: lane %d is outside the index" % lane)
		return
	var vehicles_on_lane: Array[VehicleState] = on_lane(lane)
	vehicles_on_lane.insert(upper_bound(vehicles_on_lane, vehicle.s), vehicle)
	max_length_m = maxf(max_length_m, vehicle.length_m)


func erase(vehicle: VehicleState, lane: int) -> void:
	on_lane(lane).erase(vehicle)


## Restores the order after vehicles moved. Insertion sort in place: the lists are
## nearly sorted between steps, so this is linear and allocates nothing.
func sort() -> void:
	for slot: int in _lanes.size():
		var vehicles_on_lane: Array[VehicleState] = _lanes[slot]
		for i: int in range(1, vehicles_on_lane.size()):
			var moving: VehicleState = vehicles_on_lane[i]
			var j: int = i - 1
			while j >= 0 and vehicles_on_lane[j].s > moving.s:
				vehicles_on_lane[j + 1] = vehicles_on_lane[j]
				j -= 1
			vehicles_on_lane[j + 1] = moving
