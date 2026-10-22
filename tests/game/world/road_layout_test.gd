extends GdUnitTestSuite
## Cross-section and segment mesh of the dual carriageway (issue #7, spec Phase 3 step 1).

const EPS: float = 1e-6

var _road: RoadProfile
var _view: ViewConfig
var _layout: RoadLayout


func before_test() -> void:
	_road = load("res://config/road_profiles/motorway.tres") as RoadProfile
	_view = load("res://config/view_config.tres") as ViewConfig
	_layout = RoadLayout.new(_road, _view)


func _strip_at(surface: RoadLayout.Surface, u: float) -> RoadLayout.Strip:
	for strip: RoadLayout.Strip in _layout.strips_of(surface):
		if strip.u_min - EPS <= u and u <= strip.u_max + EPS:
			return strip
	return null


func test_carriageway_covers_all_lanes() -> void:
	var width: float = _road.lane_count * _road.lane_width_m
	var asphalt: Array[RoadLayout.Strip] = _layout.strips_of(RoadLayout.Surface.ASPHALT)
	assert_int(asphalt.size()).is_equal(2)
	assert_float(asphalt[0].u_min).is_equal_approx(0.0, EPS)
	assert_float(asphalt[0].u_max).is_equal_approx(width, EPS)
	for lane: int in _road.lane_count:
		assert_object(_strip_at(RoadLayout.Surface.ASPHALT, _road.lane_center(lane))).is_same(asphalt[0])


func test_lane_lines_are_dashed_and_edge_lines_solid() -> void:
	var width: float = _layout.carriageway_width()
	for lane: int in range(1, _road.lane_count):
		var line: RoadLayout.Strip = _strip_at(RoadLayout.Surface.PAINT, lane * _road.lane_width_m)
		assert_object(line).is_not_null()
		assert_bool(line.dashed).is_true()
		assert_float(line.u_max - line.u_min).is_equal_approx(_view.lane_line_width_m, EPS)
	var right_edge: RoadLayout.Strip = _strip_at(RoadLayout.Surface.PAINT, -_view.edge_line_width_m / 2.0)
	var left_edge: RoadLayout.Strip = _strip_at(RoadLayout.Surface.PAINT, width + _view.edge_line_width_m / 2.0)
	for edge: RoadLayout.Strip in [right_edge, left_edge]:
		assert_object(edge).is_not_null()
		assert_bool(edge.dashed).is_false()
	# Player side: one line per lane boundary plus two edge lines; the opposite side mirrors it.
	assert_int(_layout.strips_of(RoadLayout.Surface.PAINT).size()).is_equal(2 * (_road.lane_count - 1 + 2))


## Issue #96: three lanes, two dashed lines between them, the shoulder and barrier on
## the right and the opposite carriageway beyond a median as wide as on two lanes.
func test_the_3_lane_motorway_draws_three_lanes_and_keeps_the_sides_in_place() -> void:
	var road: RoadProfile = load("res://config/road_profiles/motorway_3lane.tres") as RoadProfile
	var two_lanes: RoadLayout = _layout
	_layout = RoadLayout.new(road, _view)
	var width: float = 3.0 * road.lane_width_m
	assert_float(_layout.carriageway_width()).is_equal_approx(width, EPS)
	var asphalt: RoadLayout.Strip = _layout.strips_of(RoadLayout.Surface.ASPHALT)[0]
	assert_float(asphalt.u_max).is_equal_approx(width, EPS)
	for lane: int in 3:
		assert_object(_strip_at(RoadLayout.Surface.ASPHALT, road.lane_center(lane))).is_same(asphalt)
	for boundary: int in [1, 2]:
		var line: RoadLayout.Strip = _strip_at(RoadLayout.Surface.PAINT, boundary * road.lane_width_m)
		assert_object(line).is_not_null()
		assert_bool(line.dashed).is_true()
	var left_edge: RoadLayout.Strip = _strip_at(RoadLayout.Surface.PAINT, width + _view.edge_line_width_m / 2.0)
	assert_object(left_edge).is_not_null()
	assert_bool(left_edge.dashed).is_false()
	assert_int(_layout.strips_of(RoadLayout.Surface.PAINT).size()).is_equal(2 * (2 + 2))
	# The right side does not move; the median and the opposite carriageway move left by one lane.
	assert_float(_layout.outer_barrier_u()).is_equal_approx(two_lanes.outer_barrier_u(), EPS)
	assert_float(_layout.hectometre_post_u()).is_equal_approx(two_lanes.hectometre_post_u(), EPS)
	assert_float(_layout.median_center_u() - two_lanes.median_center_u()).is_equal_approx(road.lane_width_m, EPS)
	var opposite: RoadLayout.Strip = _layout.strips_of(RoadLayout.Surface.ASPHALT)[1]
	assert_float(opposite.u_min - width).is_equal_approx(2.0 * _view.inner_strip_width_m + _view.median_width_m, EPS)
	assert_float(opposite.u_max - opposite.u_min).is_equal_approx(width, EPS)
	assert_int(_layout.strips_of(RoadLayout.Surface.BARRIER).size()).is_equal(3)


func test_shoulder_and_outer_barrier_are_right_of_the_carriageway() -> void:
	var shoulder: RoadLayout.Strip = _strip_at(RoadLayout.Surface.SHOULDER, -_road.shoulder_width_m / 2.0)
	assert_object(shoulder).is_not_null()
	assert_float(shoulder.u_min).is_equal_approx(-_road.shoulder_width_m, EPS)
	assert_float(shoulder.u_max).is_equal_approx(0.0, EPS)
	var barrier: RoadLayout.Strip = _strip_at(RoadLayout.Surface.BARRIER, _layout.outer_barrier_u())
	assert_object(barrier).is_not_null()
	assert_float(barrier.u_max).is_less(-_road.shoulder_width_m)
	assert_float(barrier.top_y).is_equal(_view.barrier_height_m)


## Issue #68: posts stand beside the right shoulder, offset from its edge, so the
## position follows each profile's shoulder width.
func test_hectometre_post_offset_follows_each_profile_shoulder() -> void:
	for profile_path: String in ["res://config/road_profiles/motorway.tres", "res://config/road_profiles/expressway.tres"]:
		var road: RoadProfile = load(profile_path) as RoadProfile
		var layout: RoadLayout = RoadLayout.new(road, _view)
		assert_float(layout.hectometre_post_u()) \
				.is_equal_approx(-(road.shoulder_width_m + _view.hectometre_post_offset_m), EPS)
	var motorway: RoadLayout = RoadLayout.new(load("res://config/road_profiles/motorway.tres") as RoadProfile, _view)
	var expressway: RoadLayout = RoadLayout.new(load("res://config/road_profiles/expressway.tres") as RoadProfile, _view)
	# The motorway's wider shoulder puts its posts further right (more negative u).
	assert_float(motorway.hectometre_post_u()).is_less(expressway.hectometre_post_u())


## Issue #68: the post's footprint fits between the shoulder edge and the barrier's
## inner face for both profiles, so it stands neither on the shoulder nor in the barrier.
func test_hectometre_post_fits_between_shoulder_and_barrier() -> void:
	var half_post: float = _view.hectometre_post_width_m / 2.0
	for profile_path: String in ["res://config/road_profiles/motorway.tres", "res://config/road_profiles/expressway.tres"]:
		var road: RoadProfile = load(profile_path) as RoadProfile
		var layout: RoadLayout = RoadLayout.new(road, _view)
		var barrier_inner_face: float = layout.outer_barrier_u() + _view.barrier_width_m / 2.0
		assert_float(layout.hectometre_post_u() + half_post).is_less(-road.shoulder_width_m)
		assert_float(layout.hectometre_post_u() - half_post).is_greater(barrier_inner_face)
		assert_float(_view.hectometre_post_height_m).is_greater(_view.hectometre_post_band_height_m)


func test_opposite_carriageway_is_mirrored_beyond_a_median_barrier() -> void:
	var mirror: float = _layout.median_center_u()
	var width: float = _layout.carriageway_width()
	assert_float(mirror).is_greater(width + _view.inner_strip_width_m)
	var median_barrier: RoadLayout.Strip = _strip_at(RoadLayout.Surface.BARRIER, mirror)
	assert_object(median_barrier).is_not_null()
	var opposite: RoadLayout.Strip = _layout.strips_of(RoadLayout.Surface.ASPHALT)[1]
	assert_float(opposite.u_min).is_equal_approx(2.0 * mirror - width, EPS)
	assert_float(opposite.u_max).is_equal_approx(2.0 * mirror, EPS)
	# Separated: unpaved median between the two carriageways' inner strips.
	assert_float(opposite.u_min - width).is_equal_approx(2.0 * _view.inner_strip_width_m + _view.median_width_m, EPS)
	assert_int(_layout.strips_of(RoadLayout.Surface.BARRIER).size()).is_equal(3)


func test_terrain_spans_beyond_both_outer_barriers() -> void:
	var terrain: Array[RoadLayout.Strip] = _layout.strips_of(RoadLayout.Surface.TERRAIN)
	assert_int(terrain.size()).is_equal(1)
	var outer: float = _layout.outer_barrier_u()
	assert_float(terrain[0].u_min).is_less(outer)
	assert_float(terrain[0].u_max).is_greater(2.0 * _layout.median_center_u() - outer)
	assert_float(terrain[0].top_y).is_less(0.0)


func test_world_x_puts_left_at_negative_x() -> void:
	assert_float(RoadLayout.x_of(_road.lane_center(1))).is_less(RoadLayout.x_of(_road.lane_center(0)))


func test_dash_period_divides_segment_length() -> void:
	var dashes: float = _view.segment_length_m / _view.dash_period_m()
	assert_float(dashes).is_equal_approx(roundf(dashes), EPS)
	assert_float(dashes).is_greater_equal(1.0)


func test_segment_mesh_spans_exactly_one_segment() -> void:
	var mesh: ArrayMesh = RoadSegmentMesh.build(_layout)
	var bounds: AABB = mesh.get_aabb()
	assert_float(bounds.position.z).is_equal_approx(-_view.segment_length_m, 1e-4)
	assert_float(bounds.end.z).is_equal_approx(0.0, 1e-4)
	assert_int(mesh.get_surface_count()).is_equal(RoadSegmentMesh.COLORS.size())
	for surface: int in mesh.get_surface_count():
		assert_object(mesh.surface_get_material(surface)).is_not_null()


func test_every_triangle_faces_its_normal() -> void:
	# Godot culls counter-clockwise triangles; a reversed one (as mirroring produces)
	# would be invisible from its lit side.
	var mesh: ArrayMesh = RoadSegmentMesh.build(_layout)
	var reversed: int = 0
	for surface: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count: int = indices.size() if not indices.is_empty() else vertices.size()
		for i: int in range(0, count, 3):
			var ids: Array[int] = [i, i + 1, i + 2]
			if not indices.is_empty():
				ids = [indices[i], indices[i + 1], indices[i + 2]]
			var geometric: Vector3 = (vertices[ids[1]] - vertices[ids[0]]).cross(vertices[ids[2]] - vertices[ids[0]])
			# Clockwise as seen from the normal's side: the cross product points against it.
			if geometric.dot(normals[ids[0]]) >= 0.0:
				reversed += 1
	assert_int(reversed).is_equal(0)


func test_dashes_repeat_with_the_configured_period() -> void:
	var mesh: ArrayMesh = RoadSegmentMesh.build(_layout)
	var paint: int = RoadSegmentMesh.COLORS.keys().find(RoadLayout.Surface.PAINT)
	var vertices: PackedVector3Array = mesh.surface_get_arrays(paint)[Mesh.ARRAY_VERTEX]
	var line_x: float = RoadLayout.x_of(_road.lane_width_m)
	var dash_starts: Array[float] = []
	for vertex: Vector3 in vertices:
		var start_s: float = -vertex.z
		if absf(vertex.x - line_x) < _view.lane_line_width_m and not dash_starts.has(start_s):
			dash_starts.append(start_s)
	dash_starts.sort()
	var period: float = _view.dash_period_m()
	var dash_count: int = roundi(_view.segment_length_m / period)
	# Each dash contributes its start and end distance.
	assert_int(dash_starts.size()).is_equal(2 * dash_count)
	for dash: int in dash_count:
		assert_float(dash_starts[2 * dash]).is_equal_approx(dash * period, 1e-4)
		assert_float(dash_starts[2 * dash + 1]).is_equal_approx(dash * period + _view.dash_length_m, 1e-4)
