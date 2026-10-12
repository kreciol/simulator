extends GdUnitTestSuite
## Rear-view and side mirrors: three `SubViewport`s sharing the main world, sized and
## updated by the quality preset, showing traffic behind in its correct lanes; none
## built when mirrors are off (issue #25, requirements §5.2, spec Phase 5 step 1).

const BODY_HEIGHT_M: float = 0.8

var _view: ViewConfig
var _low: QualityPreset
var _high: QualityPreset
var _environment: Environment
var _road: RoadProfile


func before_test() -> void:
	_view = load("res://config/view_config.tres") as ViewConfig
	_low = load("res://config/quality_presets/low.tres") as QualityPreset
	_high = load("res://config/quality_presets/high.tres") as QualityPreset
	_environment = Environment.new()
	_environment.fog_enabled = true
	_road = load("res://config/road_profiles/motorway.tres") as RoadProfile


func _mirrors(quality: QualityPreset, enabled: bool = true) -> MirrorsView:
	var mirrors: MirrorsView = auto_free(MirrorsView.new()) as MirrorsView
	add_child(mirrors)
	mirrors.setup(_view, quality, enabled, _environment)
	return mirrors


## The rig of a player driving in `lane`, as `PlayerView` places it.
func _rig(lane: int) -> Vector3:
	return Vector3(RoadLayout.x_of(_road.lane_center(lane)), 0.0, 0.0)


## A vehicle body `behind_m` behind the player in `lane` (floating origin: +z is behind).
func _car(lane: int, behind_m: float) -> Vector3:
	return Vector3(RoadLayout.x_of(_road.lane_center(lane)), BODY_HEIGHT_M, behind_m)


func _sees(mirror: Mirror, point: Vector3) -> bool:
	return mirror.camera.is_position_in_frustum(point)


func test_three_mirrors_share_the_main_world() -> void:
	var mirrors: MirrorsView = _mirrors(_high)
	assert_bool(mirrors.visible).is_true()
	assert_int(mirrors.mirrors().size()).is_equal(3)
	for mirror: Mirror in mirrors.mirrors():
		assert_bool(mirror.viewport.own_world_3d).is_false()
		assert_object(mirror.viewport.find_world_3d()).is_same(get_viewport().find_world_3d())
		assert_bool(mirror.camera.is_current()).is_true()
		# Shown flipped, as a mirror shows the world.
		assert_bool(mirror.image.flip_h).is_true()
		assert_object(mirror.image.texture).is_same(mirror.viewport.get_texture())


func test_render_size_follows_the_preset() -> void:
	var low: MirrorsView = _mirrors(_low)
	var high: MirrorsView = _mirrors(_high)
	for i: int in 3:
		var low_mirror: Mirror = low.mirrors()[i]
		var high_mirror: Mirror = high.mirrors()[i]
		var shown: Vector2 = high_mirror.size - Vector2(2.0 * Mirror.FRAME_PX, 2.0 * Mirror.FRAME_PX)
		assert_float(shown.x).is_greater(0.0)
		assert_int(high_mirror.viewport.size.x).is_equal(roundi(shown.x * 0.5))
		assert_int(low_mirror.viewport.size.x).is_equal(roundi(shown.x * 0.25))
		assert_int(low_mirror.viewport.size.y).is_less(high_mirror.viewport.size.y)


func test_high_renders_every_frame_and_low_every_second() -> void:
	var high: Mirror = _mirrors(_high).rear
	var low: Mirror = _mirrors(_low).rear
	var low_modes: Array[int] = []
	for frame: int in 4:
		assert_int(high.viewport.render_target_update_mode).is_equal(SubViewport.UPDATE_ALWAYS)
		low_modes.append(low.viewport.render_target_update_mode)
		high.update(Vector3.ZERO)
		low.update(Vector3.ZERO)
	assert_array(low_modes).is_equal([SubViewport.UPDATE_ONCE, SubViewport.UPDATE_DISABLED,
			SubViewport.UPDATE_ONCE, SubViewport.UPDATE_DISABLED])


func test_car_behind_in_the_left_lane_shows_on_the_left() -> void:
	var mirrors: MirrorsView = _mirrors(_high)
	mirrors.update(_rig(0))
	var car: Vector3 = _car(1, 30.0)
	assert_bool(_sees(mirrors.rear, car)).is_true()
	assert_float(mirrors.rear.mirrored_x(car)).is_less(mirrors.rear.viewport.size.x / 2.0)
	# Close behind in the next lane: in the left side mirror, not the right one.
	var close: Vector3 = _car(1, 10.0)
	assert_bool(_sees(mirrors.left, close)).is_true()
	assert_bool(_sees(mirrors.right, close)).is_false()


func test_car_behind_in_the_right_lane_shows_on_the_right() -> void:
	var mirrors: MirrorsView = _mirrors(_high)
	mirrors.update(_rig(1))
	var car: Vector3 = _car(0, 30.0)
	assert_bool(_sees(mirrors.rear, car)).is_true()
	assert_float(mirrors.rear.mirrored_x(car)).is_greater(mirrors.rear.viewport.size.x / 2.0)
	var close: Vector3 = _car(0, 10.0)
	assert_bool(_sees(mirrors.right, close)).is_true()
	assert_bool(_sees(mirrors.left, close)).is_false()


func test_car_right_behind_shows_in_the_middle_of_the_rear_view() -> void:
	var mirrors: MirrorsView = _mirrors(_high)
	mirrors.update(_rig(0))
	var car: Vector3 = _car(0, 30.0)
	var width: float = mirrors.rear.viewport.size.x
	# The rear-view mirror hangs on the car's centreline, the driver sits off it.
	assert_float(mirrors.rear.mirrored_x(car)).is_equal_approx(width / 2.0, width * 0.05)


func test_mirrors_follow_the_rig_and_never_look_ahead() -> void:
	var mirrors: MirrorsView = _mirrors(_high)
	mirrors.update(_rig(1))
	for mirror: Mirror in mirrors.mirrors():
		assert_float(mirror.camera.position.x - _rig(1).x).is_equal_approx(mirror.mount.origin.x, 1e-5)
		assert_bool(_sees(mirror, _car(1, -30.0))).is_false()


func test_mirror_range_stays_inside_the_road_behind_and_the_hidden_spawn_zone() -> void:
	var sim: SimConfig = load("res://config/sim_config.tres") as SimConfig
	var mirrors: MirrorsView = _mirrors(_high)
	assert_float(_view.mirror_range_m()).is_less_equal(_view.covered_behind_m())
	# Vehicles spawned behind during a session appear beyond what the mirrors show.
	assert_float(_view.mirror_range_m()).is_less_equal(sim.spawn_hidden_behind_m)
	for mirror: Mirror in mirrors.mirrors():
		assert_float(mirror.camera.far).is_equal(_view.mirror_range_m())
		assert_float(mirror.camera.environment.fog_depth_end).is_equal(_view.mirror_range_m())
	# The scene's own environment keeps its fog.
	assert_object(mirrors.rear.camera.environment).is_not_same(_environment)


func test_mirrors_off_builds_nothing() -> void:
	var mirrors: MirrorsView = _mirrors(_high, false)
	assert_bool(mirrors.visible).is_false()
	assert_array(mirrors.mirrors()).is_empty()
	assert_int(mirrors.get_child_count()).is_equal(0)
	mirrors.update(_rig(0))
