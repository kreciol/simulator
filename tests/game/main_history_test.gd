extends GdUnitTestSuite
## `screen=history` opens the history screen instead of a session, until the Phase 10
## menus reach it (issue #41).

const MAIN_SCENE: String = "res://game/main.tscn"

var _opened: Array[String] = []


## The main scene started as the dev launcher would start it with `query`, with scene
## changes recorded rather than made.
func _main(query: String) -> Node3D:
	var main: Node3D = (load(MAIN_SCENE) as PackedScene).instantiate() as Node3D
	var launcher: DevLauncherConfig = load("res://config/dev_launcher.tres") as DevLauncherConfig
	main.launch_options = DevLauncher.resolve(DevLauncher.parse_query(query), launcher, 1)
	main.change_scene = func(path: String) -> void: _opened.append(path)
	add_child(auto_free(main))
	return main


func before_test() -> void:
	_opened.clear()


func test_screen_history_opens_the_history_scene_without_a_session() -> void:
	var main: Node3D = _main("?screen=history")
	await get_tree().process_frame
	assert_array(_opened).contains_exactly(["res://ui/history_screen.tscn"])
	assert_object(main.session.sim).is_null()
	assert_bool(main.is_processing()).is_false()
	assert_bool(main.is_physics_processing()).is_false()
	assert_bool(main.is_processing_unhandled_input()).is_false()
	assert_bool(ResourceLoader.exists(main.HISTORY_SCENE)).is_true()


func test_without_the_param_a_session_starts() -> void:
	var main: Node3D = _main("")
	await get_tree().process_frame
	assert_array(_opened).is_empty()
	assert_object(main.session.sim).is_not_null()
