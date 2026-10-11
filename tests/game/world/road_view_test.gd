extends GdUnitTestSuite
## Endless road from recycled segments around a floating origin (issue #7,
## spec Phase 3 step 1: "after driving 10 km of sim time no segment gap").

const DT: float = 1.0 / 60.0
const DRIVE_M: float = 10000.0
## Segment positions are float32; joints may differ by this much.
const JOINT_EPS: float = 1e-3

var _road: RoadProfile
var _view: ViewConfig
var _road_view: RoadView


func before_test() -> void:
	_road = load("res://config/road_profiles/motorway.tres") as RoadProfile
	_view = load("res://config/view_config.tres") as ViewConfig
	_road_view = auto_free(RoadView.new()) as RoadView
	_road_view.setup(_road, _view)


## Start distances of the stretches the segments show, ascending, read back from
## where the segments are placed (z = -(start - player_s)).
func _segment_starts(player_s: float) -> Array[float]:
	var starts: Array[float] = []
	for segment: MeshInstance3D in _road_view.segments():
		starts.append(player_s - segment.position.z)
	starts.sort()
	return starts


## Empty when the segments form one continuous road covering the configured window.
func _coverage_error(player_s: float) -> String:
	var starts: Array[float] = _segment_starts(player_s)
	var length: float = _view.segment_length_m
	for i: int in range(1, starts.size()):
		if absf(starts[i] - starts[i - 1] - length) > JOINT_EPS:
			return "joint %d at s=%.3f: %.3f m apart, expected %.3f" % [i, player_s, starts[i] - starts[i - 1], length]
	if starts[0] > player_s - _view.covered_behind_m() + JOINT_EPS:
		return "road starts %.3f m behind at s=%.3f" % [player_s - starts[0], player_s]
	var end: float = starts[-1] + length
	if end < player_s + _view.covered_ahead_m() - JOINT_EPS:
		return "road ends %.3f m ahead at s=%.3f" % [end - player_s, player_s]
	return ""


func test_driving_10_km_keeps_the_road_continuous() -> void:
	var sim: TrafficSim = TrafficSim.new(_road, load("res://config/sim_config.tres") as SimConfig)
	var player: VehicleState = sim.add_vehicle(0.0, 0, _road.speed_limit_kmh / TrafficSim.KMH_PER_MPS)
	var pooled: Array[MeshInstance3D] = _road_view.segments().duplicate()
	var first_error: String = ""
	while player.s < DRIVE_M and first_error.is_empty():
		sim.step(DT)
		_road_view.update(player.s)
		first_error = _coverage_error(player.s)
	assert_str(first_error).is_empty()
	assert_float(player.s).is_greater_equal(DRIVE_M)
	# Recycled, never created or freed.
	assert_int(_road_view.get_child_count()).is_equal(_view.segment_count)
	assert_array(_road_view.segments()).contains_exactly(pooled)


func test_player_stays_at_the_floating_origin() -> void:
	_road_view.update(DRIVE_M)
	for segment: MeshInstance3D in _road_view.segments():
		assert_float(absf(segment.position.z)).is_less_equal(_view.segment_count * _view.segment_length_m)


func test_segments_appear_only_beyond_the_covered_distance_ahead() -> void:
	var length: float = _view.segment_length_m
	var player_s: float = 0.0
	_road_view.update(player_s)
	var previous: Dictionary[MeshInstance3D, float] = {}
	for segment: MeshInstance3D in _road_view.segments():
		previous[segment] = segment.position.z
	while player_s < 5.0 * length:
		player_s += 0.37
		_road_view.update(player_s)
		for segment: MeshInstance3D in _road_view.segments():
			var start: float = player_s - segment.position.z
			var moved_by: float = segment.position.z - previous[segment]
			if absf(moved_by - 0.37) > JOINT_EPS:
				# Recycled this update: it must start out of the camera's reach.
				assert_float(start - player_s).is_greater_equal(_view.draw_distance_m() - JOINT_EPS)
			previous[segment] = segment.position.z


func test_jump_far_ahead_rebuilds_a_continuous_window() -> void:
	_road_view.update(0.0)
	_road_view.update(123456.7)
	assert_str(_coverage_error(123456.7)).is_empty()
	_road_view.update(17.0)
	assert_str(_coverage_error(17.0)).is_empty()


func test_draw_distance_shows_seconds_of_road_ahead() -> void:
	# At the motorway limit the camera must see well over the legal gap ahead.
	var limit_mps: float = _road.speed_limit_kmh / TrafficSim.KMH_PER_MPS
	assert_float(_view.draw_distance_m() / limit_mps).is_greater(10.0)
	assert_float(_view.draw_distance_m()).is_less(_view.covered_ahead_m())
