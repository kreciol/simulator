extends GdUnitTestSuite
## Animated lane changes, off-road and turn signals (issue #4, spec Phase 2 step 2).

const DT: float = 1.0 / 60.0
const LEFT: VehicleState.Dir = VehicleState.Dir.LEFT
const RIGHT: VehicleState.Dir = VehicleState.Dir.RIGHT

var _sim: TrafficSim
var _car: VehicleState
## Steps a lane change takes at DT with the configured duration.
var _change_steps: int


func before_test() -> void:
	_start_on_lane(0)
	_change_steps = roundi(_sim.config.lane_change_duration_s / DT)


## A fresh sim with the car alone on `lane` of the `road_path` profile.
func _start_on_lane(lane: int, road_path: String = "res://config/road_profiles/motorway.tres") -> void:
	var config: SimConfig = load("res://config/sim_config.tres") as SimConfig
	_sim = TrafficSim.new(load(road_path) as RoadProfile, config)
	_car = _sim.add_vehicle(0.0, lane, 30.0)


func _steps(count: int) -> void:
	for i: int in count:
		_sim.step(DT)


func test_lateral_position_follows_progress_and_lane_updates_on_completion() -> void:
	var start: float = _sim.road.lane_center(0)
	var target: float = _sim.road.lane_center(1)
	assert_float(_sim.lateral_position(_car)).is_equal(start)
	assert_bool(_sim.request_lane_change(_car, LEFT)).is_true()

	var half_steps: int = floori(_change_steps / 2.0)
	_steps(half_steps)
	var half_progress: float = float(half_steps) / float(_change_steps)
	assert_float(_car.lane_change_progress).is_equal_approx(half_progress, 1e-6)
	var expected: float = lerpf(start, target, smoothstep(0.0, 1.0, half_progress))
	assert_float(_sim.lateral_position(_car)).is_equal_approx(expected, 1e-6)
	assert_float(_sim.lateral_position(_car)).is_between(start, target)
	assert_int(_car.lane).is_equal(0)

	_steps(_change_steps - half_steps - 1)
	assert_bool(_car.lane_change_active).is_true()
	assert_int(_car.lane).is_equal(0)

	_steps(1)
	assert_bool(_car.lane_change_active).is_false()
	assert_int(_car.lane).is_equal(1)
	assert_float(_sim.lateral_position(_car)).is_equal(target)
	assert_bool(_car.off_road).is_false()


func test_lateral_position_is_monotonic_during_change() -> void:
	_sim.request_lane_change(_car, LEFT)
	var previous: float = _sim.lateral_position(_car)
	for i: int in _change_steps:
		_sim.step(DT)
		var current: float = _sim.lateral_position(_car)
		assert_float(current).is_greater_equal(previous)
		previous = current


func test_request_during_active_change_is_ignored() -> void:
	_start_on_lane(1)
	_sim.request_lane_change(_car, RIGHT)
	_steps(10)
	assert_bool(_sim.request_lane_change(_car, LEFT)).is_false()
	assert_bool(_sim.request_lane_change(_car, RIGHT)).is_false()
	assert_int(_car.lane_change_to).is_equal(0)
	_steps(_change_steps)
	assert_int(_car.lane).is_equal(0)
	assert_bool(_car.lane_change_active).is_false()


func test_change_beyond_outermost_lane_ends_off_road(
		road_path: String,
		start_lane: int,
		dir: VehicleState.Dir,
		end_lane: int,
		test_parameters: Array = [
			["res://config/road_profiles/motorway.tres", 0, VehicleState.Dir.RIGHT, -1],
			["res://config/road_profiles/motorway.tres", 1, VehicleState.Dir.LEFT, 2],
			["res://config/road_profiles/motorway_3lane.tres", 0, VehicleState.Dir.RIGHT, -1],
			["res://config/road_profiles/motorway_3lane.tres", 2, VehicleState.Dir.LEFT, 3],
		]) -> void:
	_start_on_lane(start_lane, road_path)
	var offroad_ids: Array[int] = []
	_sim.offroad.connect(func(vehicle_id: int) -> void: offroad_ids.append(vehicle_id))
	assert_bool(_sim.request_lane_change(_car, dir)).is_true()
	_steps(_change_steps - 1)
	assert_bool(_car.off_road).is_false()
	_steps(1)
	assert_bool(_car.off_road).is_true()
	assert_int(_car.lane).is_equal(end_lane)
	assert_array(offroad_ids).contains_exactly([_car.id])
	assert_bool(_sim.request_lane_change(_car, RIGHT if dir == LEFT else LEFT)).is_false()


func test_lane_change_emits_started_and_finished() -> void:
	var events: Array = []
	_sim.lane_change_started.connect(
			func(vehicle_id: int, from_lane: int, to_lane: int) -> void:
				events.append(["started", vehicle_id, from_lane, to_lane]))
	_sim.lane_change_finished.connect(
			func(vehicle_id: int, lane: int) -> void: events.append(["finished", vehicle_id, lane]))
	_sim.request_lane_change(_car, LEFT)
	_steps(_change_steps)
	assert_array(events).is_equal([["started", _car.id, 0, 1], ["finished", _car.id, 1]])


func test_signal_records_on_since_and_switches_off_after_change() -> void:
	_steps(30)
	_sim.apply_commands(_car, PlayerCommands.create(VehicleState.Longitudinal.NONE, VehicleState.Dir.NONE, LEFT))
	assert_int(_car.signal_dir).is_equal(LEFT)
	assert_float(_car.signal_on_since_s).is_equal_approx(0.5, 1e-9)

	_steps(60)
	_sim.apply_commands(_car, PlayerCommands.create(VehicleState.Longitudinal.NONE, LEFT))
	assert_bool(_car.lane_change_active).is_true()
	_steps(_change_steps - 1)
	assert_int(_car.signal_dir).is_equal(LEFT)
	_steps(1)
	assert_int(_car.signal_dir).is_equal(VehicleState.Dir.NONE)
	assert_int(_car.lane).is_equal(1)


func test_signal_in_other_direction_stays_on_after_change() -> void:
	_sim.toggle_signal(_car, RIGHT)
	_sim.request_lane_change(_car, LEFT)
	_steps(_change_steps)
	assert_int(_car.lane).is_equal(1)
	assert_int(_car.signal_dir).is_equal(RIGHT)


func test_signal_toggle_and_side_switch() -> void:
	_sim.toggle_signal(_car, LEFT)
	_steps(12)
	_sim.toggle_signal(_car, RIGHT)
	assert_int(_car.signal_dir).is_equal(RIGHT)
	assert_float(_car.signal_on_since_s).is_equal_approx(0.2, 1e-9)
	_sim.toggle_signal(_car, RIGHT)
	assert_int(_car.signal_dir).is_equal(VehicleState.Dir.NONE)


func test_signal_toggled_with_lane_change_counts_as_on_first() -> void:
	_sim.apply_commands(_car, PlayerCommands.create(VehicleState.Longitudinal.NONE, LEFT, LEFT))
	assert_int(_car.signal_dir).is_equal(LEFT)
	assert_bool(_car.lane_change_active).is_true()
	_steps(_change_steps)
	assert_int(_car.signal_dir).is_equal(VehicleState.Dir.NONE)


## Issue #96: on three lanes the middle lane is a lane like any other, either way.
func test_from_the_middle_of_three_lanes_both_changes_stay_on_the_road(dir: VehicleState.Dir, end_lane: int,
		test_parameters: Array = [[VehicleState.Dir.LEFT, 2], [VehicleState.Dir.RIGHT, 0]]) -> void:
	_start_on_lane(1, "res://config/road_profiles/motorway_3lane.tres")
	assert_bool(_sim.request_lane_change(_car, dir)).is_true()
	_steps(_change_steps)
	assert_bool(_car.off_road).is_false()
	assert_int(_car.lane).is_equal(end_lane)
	assert_float(_sim.lateral_position(_car)).is_equal(_sim.road.lane_center(end_lane))
