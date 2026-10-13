extends GdUnitTestSuite
## Hectometre posts along the roadside (issue #68, spec 2026-10-13-hectometre-posts
## Phase 1 step 2): fixed in road coordinates, floating origin, pooled and recycled.

const DT: float = 1.0 / 60.0
const DRIVE_M: float = 10000.0
## Post positions are float32; allow this much.
const POS_EPS: float = 1e-3

var _road: RoadProfile
var _view: ViewConfig
var _posts_view: HectometrePostsView


func before_test() -> void:
	_road = load("res://config/road_profiles/motorway.tres") as RoadProfile
	_view = load("res://config/view_config.tres") as ViewConfig
	_posts_view = _new_view(_road, _view)


func _new_view(road: RoadProfile, view: ViewConfig) -> HectometrePostsView:
	var posts_view: HectometrePostsView = auto_free(HectometrePostsView.new()) as HectometrePostsView
	posts_view.setup(road, view)
	return posts_view


## Distances along the road of the visible posts, ascending, read back from where
## they are placed (z = -(s - player_s)).
func _visible_s(posts_view: HectometrePostsView, player_s: float) -> Array[float]:
	var found: Array[float] = []
	for post: MeshInstance3D in posts_view.posts():
		if post.visible:
			found.append(player_s - post.position.z)
	found.sort()
	return found


## The road window RoadView keeps around `player_s`: [start, end).
func _road_window(view: ViewConfig, player_s: float) -> Vector2:
	var first: int = floori(player_s / view.segment_length_m) - view.segments_behind
	return Vector2(first * view.segment_length_m, (first + view.segment_count) * view.segment_length_m)


## Empty when the visible posts are exactly the multiples of the spacing in the road
## window, which covers everything from the mirrors' range behind to the draw distance.
func _coverage_error(posts_view: HectometrePostsView, view: ViewConfig, player_s: float) -> String:
	var spacing: float = view.hectometre_post_spacing_m
	var window: Vector2 = _road_window(view, player_s)
	var expected: Array[float] = []
	for k: int in range(ceili(window.x / spacing), ceili(window.y / spacing)):
		expected.append(k * spacing)
	var shown: Array[float] = _visible_s(posts_view, player_s)
	if shown.size() != expected.size():
		return "s=%.3f: %d posts shown, expected %d" % [player_s, shown.size(), expected.size()]
	for i: int in shown.size():
		if absf(shown[i] - expected[i]) > POS_EPS:
			return "s=%.3f: post at %.3f, expected %.3f" % [player_s, shown[i], expected[i]]
	if not expected.is_empty():
		if expected[0] > player_s - view.covered_behind_m() + spacing:
			return "s=%.3f: no post within the mirrors' range behind" % player_s
		if expected[-1] < player_s + view.draw_distance_m() - spacing:
			return "s=%.3f: no post near the draw distance" % player_s
	return ""


func test_posts_stand_at_multiples_of_the_spacing_beside_the_right_shoulder() -> void:
	var player_s: float = 1234.5
	_posts_view.update(player_s)
	var x: float = RoadLayout.x_of(_posts_view.layout.hectometre_post_u())
	var visible: int = 0
	for post: MeshInstance3D in _posts_view.posts():
		if not post.visible:
			continue
		visible += 1
		var s: float = player_s - post.position.z
		var k: float = s / _view.hectometre_post_spacing_m
		assert_float(absf(k - roundf(k)) * _view.hectometre_post_spacing_m).is_less(POS_EPS)
		assert_float(post.position.x).is_equal_approx(x, POS_EPS)
		assert_float(post.position.y).is_equal_approx(0.0, POS_EPS)
	assert_int(visible).is_greater(0)
	assert_str(_coverage_error(_posts_view, _view, player_s)).is_empty()


func test_posts_are_fixed_in_road_coordinates_not_relative_to_the_player() -> void:
	_posts_view.update(500.0)
	var at_500: Array[float] = _visible_s(_posts_view, 500.0)
	_posts_view.update(512.0)
	var at_512: Array[float] = _visible_s(_posts_view, 512.0)
	# Same window (no segment boundary crossed): the same posts at the same road positions.
	assert_array(at_512).is_equal(at_500)
	assert_bool(at_500.has(500.0)).is_true()


func test_driving_10_km_shows_every_post_with_the_same_pooled_nodes() -> void:
	var sim: TrafficSim = TrafficSim.new(_road, load("res://config/sim_config.tres") as SimConfig)
	var player: VehicleState = sim.add_vehicle(0.0, 0, _road.speed_limit_kmh / TrafficSim.KMH_PER_MPS)
	var pooled: Array[MeshInstance3D] = _posts_view.posts().duplicate()
	var first_error: String = ""
	while player.s < DRIVE_M and first_error.is_empty():
		sim.step(DT)
		_posts_view.update(player.s)
		first_error = _coverage_error(_posts_view, _view, player.s)
	assert_str(first_error).is_empty()
	assert_float(player.s).is_greater_equal(DRIVE_M)
	# Recycled, never created or freed.
	assert_int(_posts_view.get_child_count()).is_equal(_view.hectometre_post_count())
	assert_array(_posts_view.posts()).contains_exactly(pooled)


func test_no_post_outside_the_road_window() -> void:
	for player_s: float in [0.0, 37.0, 480.0, 999.9, 5000.0]:
		_posts_view.update(player_s)
		var window: Vector2 = _road_window(_view, player_s)
		for s: float in _visible_s(_posts_view, player_s):
			assert_float(s).is_greater_equal(window.x - POS_EPS)
			assert_float(s).is_less(window.y)


## The pool never runs short: a window whose both ends fall on multiples of the
## spacing, and the player exactly on a segment boundary.
func test_pool_covers_windows_with_posts_on_both_edges() -> void:
	var view: ViewConfig = _view.duplicate() as ViewConfig
	view.segment_length_m = 50.0
	view.segment_count = 4
	view.segments_behind = 1
	view.hectometre_post_spacing_m = 100.0
	var posts_view: HectometrePostsView = _new_view(_road, view)
	assert_int(posts_view.posts().size()).is_equal(2)
	# Window [100, 300): posts at 100 and 200; the one at 300 lies just past the end.
	posts_view.update(150.0)
	assert_str(_coverage_error(posts_view, view, 150.0)).is_empty()
	assert_array(_visible_s(posts_view, 150.0)).is_equal([100.0, 200.0])
	# Odd segment count: window [0, 150) holds two posts, window [50, 200) one.
	view.segment_count = 3
	view.segments_behind = 0
	posts_view = _new_view(_road, view)
	assert_int(posts_view.posts().size()).is_equal(2)
	for player_s: float in [0.0, 50.0, 100.0, 149.0, 150.0]:
		posts_view.update(player_s)
		assert_str(_coverage_error(posts_view, view, player_s)).is_empty()


func test_lateral_position_follows_the_road_profile() -> void:
	var expressway: RoadProfile = load("res://config/road_profiles/expressway.tres") as RoadProfile
	var other: HectometrePostsView = _new_view(expressway, _view)
	_posts_view.update(300.0)
	other.update(300.0)
	var motorway_x: float = _posts_view.posts().filter(func(p: MeshInstance3D) -> bool: return p.visible)[0].position.x
	var expressway_x: float = other.posts().filter(func(p: MeshInstance3D) -> bool: return p.visible)[0].position.x
	assert_float(motorway_x).is_equal_approx(_road.shoulder_width_m + _view.hectometre_post_offset_m, POS_EPS)
	assert_float(expressway_x).is_equal_approx(expressway.shoulder_width_m + _view.hectometre_post_offset_m, POS_EPS)


func test_post_mesh_is_a_body_and_a_band_standing_on_the_road() -> void:
	var mesh: ArrayMesh = HectometrePostsView.build_mesh(_view)
	assert_int(mesh.get_surface_count()).is_equal(2)
	var bounds: AABB = mesh.get_aabb()
	assert_float(bounds.position.y).is_equal_approx(0.0, POS_EPS)
	assert_float(bounds.end.y).is_less_equal(_view.hectometre_post_height_m + POS_EPS)
	assert_float(bounds.end.y).is_greater_equal(_view.hectometre_post_height_m - POS_EPS)
	var body: StandardMaterial3D = mesh.surface_get_material(0) as StandardMaterial3D
	var band: StandardMaterial3D = mesh.surface_get_material(1) as StandardMaterial3D
	assert_object(body.albedo_color).is_equal(_view.hectometre_post_color)
	assert_object(band.albedo_color).is_equal(_view.hectometre_post_band_color)
