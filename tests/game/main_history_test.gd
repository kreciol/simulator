extends GdUnitTestSuite
## `screen=history` opens the history screen instead of a session (issue #41), and the
## end screen leads to the same session again, the history or the menu (issue #43).

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


var _started: Array[LaunchOptions] = []


## The main scene of a session launched with `query`, with the next session recorded
## rather than started.
func _session_main(query: String) -> Node3D:
	_started.clear()
	var main: Node3D = _main(query)
	main.start_session = func(options: LaunchOptions) -> void: _started.append(options)
	return main


func test_again_starts_the_same_choice_with_a_new_seed() -> void:
	var main: Node3D = _session_main("?mode=exam&profile=expressway&level=3&seed=42")
	await get_tree().process_frame
	(main.get_node("Hud") as Hud).again_requested.emit()
	assert_int(_started.size()).is_equal(1)
	var again: LaunchOptions = _started[0]
	assert_str(again.mode).is_equal(LaunchOptions.MODE_EXAM)
	assert_str(again.profile.id).is_equal(&"expressway")
	assert_int(again.level).is_equal(3)
	assert_bool(again.seed_given).is_false()
	assert_array(_opened).is_empty()


func test_history_and_menu_on_the_end_screen_open_their_screens() -> void:
	var main: Node3D = _session_main("")
	await get_tree().process_frame
	var hud: Hud = main.get_node("Hud") as Hud
	hud.history_requested.emit()
	hud.menu_requested.emit()
	assert_array(_opened).contains_exactly([AppFlow.HISTORY_SCENE, AppFlow.START_SCENE])
	assert_array(_started).is_empty()


func test_the_session_scene_starts_with_the_given_options_not_the_url() -> void:
	var launcher: DevLauncherConfig = load("res://config/dev_launcher.tres") as DevLauncherConfig
	var options: LaunchOptions = SessionSetup.options_for(
			LaunchOptions.MODE_EXAM, &"expressway", 4, launcher, 5)
	var main: Node3D = AppFlow.session_scene(options) as Node3D
	main.change_scene = func(path: String) -> void: _opened.append(path)
	add_child(auto_free(main))
	await get_tree().process_frame
	assert_object(main.launch_options).is_same(options)
	assert_bool(main.session.is_exam()).is_true()
	# It opens with the 3-2-1 countdown.
	assert_int(main.session.state).is_equal(SessionManager.State.INTRO)
