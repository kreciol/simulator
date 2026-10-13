extends GdUnitTestSuite
## The main scene applies the launch's quality preset (draw distance, shadows,
## mirror resolution and pace) and shows the mirrors unless they are off (issue #25
## acceptance criteria, spec Phase 5 step 1).

const DT: float = 1.0 / 60.0
const MAIN_SCENE: String = "res://game/main.tscn"

var _launcher: DevLauncherConfig


func before_test() -> void:
	_launcher = load("res://config/dev_launcher.tres") as DevLauncherConfig


## The main scene started as the dev launcher would start it with `query`.
func _main(query: String) -> Node3D:
	var main: Node3D = (load(MAIN_SCENE) as PackedScene).instantiate() as Node3D
	main.launch_options = DevLauncher.resolve(DevLauncher.parse_query(query), _launcher, 1)
	add_child(auto_free(main))
	return main


func _sub_viewports(main: Node) -> Array[Node]:
	return main.find_children("*", "SubViewport", true, false)


func _mirrors(main: Node3D) -> MirrorsView:
	return main.get_node("MirrorsView") as MirrorsView


func test_without_quality_param_the_default_preset_is_used() -> void:
	var main: Node3D = _main("")
	var high: QualityPreset = _launcher.find_quality(_launcher.default_quality)
	assert_object(main.quality).is_same(high)
	var camera: Camera3D = (main.get_node("PlayerView") as PlayerView).camera
	assert_float(camera.far).is_equal(main.view_config.draw_distance_m())
	assert_int(main.view_config.segment_count).is_equal(high.road_segment_count)
	assert_bool((main.get_node("Sun") as DirectionalLight3D).shadow_enabled).is_equal(high.shadows_enabled)
	# Mirrors are on by default: three of them, rendering.
	assert_bool(_mirrors(main).visible).is_true()
	assert_int(_sub_viewports(main).size()).is_equal(3)
	for viewport: Node in _sub_viewports(main):
		assert_int((viewport as SubViewport).render_target_update_mode).is_equal(SubViewport.UPDATE_ALWAYS)


func test_low_and_high_differ_as_their_presets_say() -> void:
	var low: Node3D = _main("?quality=low")
	var high: Node3D = _main("?quality=high")
	var low_preset: QualityPreset = _launcher.find_quality(&"low")
	assert_int((low.get_node("RoadView") as RoadView).segments().size()).is_equal(low_preset.road_segment_count)
	var low_far: float = (low.get_node("PlayerView") as PlayerView).camera.far
	var high_far: float = (high.get_node("PlayerView") as PlayerView).camera.far
	assert_float(low_far).is_less(high_far)
	var low_env: Environment = (low.get_node("WorldEnvironment") as WorldEnvironment).environment
	assert_float(low_env.fog_depth_end).is_equal(low_far)
	assert_bool((low.get_node("Sun") as DirectionalLight3D).shadow_enabled).is_false()
	assert_bool((high.get_node("Sun") as DirectionalLight3D).shadow_enabled).is_true()
	var low_rear: Mirror = _mirrors(low).rear
	var high_rear: Mirror = _mirrors(high).rear
	assert_int(low_rear.viewport.size.x).is_less(high_rear.viewport.size.x)
	assert_float(low_rear.quality.mirror_resolution_scale).is_equal(low_preset.mirror_resolution_scale)
	# Low re-renders the mirrors every second frame only.
	var modes: Array[int] = []
	for i: int in 2:
		low._process(DT)
		modes.append(low_rear.viewport.render_target_update_mode)
	assert_bool(SubViewport.UPDATE_DISABLED in modes).is_true()
	assert_bool(SubViewport.UPDATE_ONCE in modes).is_true()
	# The shared view config is not changed by a session's preset.
	assert_int((load("res://config/view_config.tres") as ViewConfig).segment_count).is_not_equal(low_preset.road_segment_count)


func test_mirrors_off_shows_no_mirror_and_renders_none() -> void:
	var main: Node3D = _main("?mirrors=0")
	assert_bool(_mirrors(main).visible).is_false()
	assert_array(_mirrors(main).mirrors()).is_empty()
	assert_array(_sub_viewports(main)).is_empty()
	# Driving on still works without them.
	while main.session.state == SessionManager.State.INTRO:
		main._physics_process(DT)
	main._physics_process(DT)
	main._process(DT)
	assert_array(_sub_viewports(main)).is_empty()


func test_mirrors_follow_the_player_through_a_lane_change() -> void:
	var main: Node3D = _main("?seed=3")
	var mirrors: MirrorsView = _mirrors(main)
	var player_view: PlayerView = main.get_node("PlayerView") as PlayerView
	while main.session.state == SessionManager.State.INTRO:
		main._physics_process(DT)
	main.sim.request_lane_change(main.player, VehicleState.Dir.LEFT)
	for i: int in roundi(main.sim_config.lane_change_duration_s / DT) + 1:
		main._physics_process(DT)
	main._process(DT)
	assert_float(player_view.position.x).is_less(0.0)
	assert_float(mirrors.rear.camera.position.x).is_equal_approx(player_view.position.x, 1e-5)


## Ends the session as time running out would, without keeping it in any history.
func _end_session(main: Node3D) -> void:
	var real_store: HistoryStore = SaveManager.store
	# Never loaded, so its storage is unavailable and nothing is written.
	SaveManager.store = HistoryStore.new("user://test_main_quality_mirrors/history.json", 5)
	main.session._end(SessionManager.EndReason.TIME_UP)
	SaveManager.store = real_store


func test_mirrors_hide_and_stop_rendering_once_the_session_ends() -> void:
	var main: Node3D = _main("?seed=1&quality=low")
	var mirrors: MirrorsView = _mirrors(main)
	while main.session.state == SessionManager.State.INTRO:
		main._physics_process(DT)
	main._physics_process(DT)
	main._process(DT)
	assert_bool(mirrors.visible).is_true()

	_end_session(main)
	var rear_before: Vector3 = mirrors.rear.camera.position
	for i: int in 3:
		main._process(DT)
	# The end screen dims the scene; the mirrors must not stay bright above it (#58).
	assert_bool(mirrors.visible).is_false()
	assert_vector(mirrors.rear.camera.position).is_equal(rear_before)
	for viewport: Node in _sub_viewports(main):
		assert_int((viewport as SubViewport).render_target_update_mode).is_equal(SubViewport.UPDATE_DISABLED)


func test_with_mirrors_off_the_end_screen_shows_none() -> void:
	var main: Node3D = _main("?mirrors=0")
	_end_session(main)
	main._process(DT)
	assert_bool(_mirrors(main).visible).is_false()
	assert_array(_sub_viewports(main)).is_empty()
