extends GdUnitTestSuite
## The tutorial in the drivable scene (issue #45, requirements §12): the HUD prompts the
## current step with a skip button and no time left; Tab or the button skips it straight
## back to the start screen; a finished tutorial recaps the three rules and offers it
## again or the menu.

const MAIN_SCENE: String = "res://game/main.tscn"
const DT: float = 1.0 / 60.0

var _opened: Array[String] = []
var _started: Array[LaunchOptions] = []


func before_test() -> void:
	_opened.clear()
	_started.clear()


func _main(query: String = "?screen=tutorial") -> DriveScene:
	var main: DriveScene = (load(MAIN_SCENE) as PackedScene).instantiate() as DriveScene
	var launcher: DevLauncherConfig = load("res://config/dev_launcher.tres") as DevLauncherConfig
	main.launch_options = DevLauncher.resolve(DevLauncher.parse_query(query), launcher, 1)
	main.change_scene = func(path: String) -> void: _opened.append(path)
	main.start_session = func(options: LaunchOptions) -> void: _started.append(options)
	add_child(auto_free(main))
	return main


func _hud(main: DriveScene) -> Hud:
	return main.get_node("Hud") as Hud


func _finish(main: DriveScene) -> void:
	var session: SessionManager = main.session
	for i: int in roundi(session.sim.config.countdown_s / DT):
		session.step(DT)
	session.tutorial._begin_step(Tutorial.Step.CHECK_MIRRORS)
	while session.state != SessionManager.State.ENDED:
		session.step(DT)
	_hud(main).update(session)


func test_the_tutorial_starts_on_an_empty_road_with_its_first_prompt() -> void:
	var main: DriveScene = _main()
	await get_tree().process_frame
	assert_bool(main.session.is_tutorial()).is_true()
	assert_int(main.session.sim.vehicles.size()).is_equal(1)
	var hud: Hud = _hud(main)
	hud.update(main.session)
	assert_bool(hud.tutorial_panel.visible).is_true()
	assert_str(hud.tutorial_step_label.text).is_equal("Krok 1 z 6")
	assert_str(hud.tutorial_prompt_label.text).is_equal(tr(&"TUTORIAL_ACCELERATE"))
	assert_str(hud.tutorial_prompt_label.text).is_not_equal("TUTORIAL_ACCELERATE")
	assert_bool(hud.tutorial_skip_button.visible).is_true()
	assert_int(hud.tutorial_skip_button.focus_mode).is_equal(Control.FOCUS_NONE)
	# No time limit, no score.
	assert_bool(hud.time_label.visible).is_false()
	assert_bool(hud.score_panel.visible).is_false()


func test_a_normal_session_shows_no_tutorial() -> void:
	var main: DriveScene = _main("")
	await get_tree().process_frame
	var hud: Hud = _hud(main)
	hud.update(main.session)
	assert_bool(hud.tutorial_panel.visible).is_false()
	assert_bool(hud.time_label.visible).is_true()


func test_the_prompt_follows_the_step() -> void:
	var main: DriveScene = _main()
	await get_tree().process_frame
	main.session.tutorial._begin_step(Tutorial.Step.SIGNAL)
	var hud: Hud = _hud(main)
	hud.update(main.session)
	assert_str(hud.tutorial_step_label.text).is_equal("Krok 3 z 6")
	assert_str(hud.tutorial_prompt_label.text).is_equal(tr(&"TUTORIAL_SIGNAL"))


func test_the_skip_button_goes_back_to_the_menu_at_once() -> void:
	var main: DriveScene = _main()
	await get_tree().process_frame
	_hud(main).tutorial_skip_button.pressed.emit()
	assert_int(main.session.state).is_equal(SessionManager.State.ENDED)
	assert_bool(main.session.tutorial.skipped).is_true()
	assert_array(_opened).contains_exactly([AppFlow.START_SCENE])
	# No end screen in between.
	var hud: Hud = _hud(main)
	hud.update(main.session)
	assert_bool(hud.ended_screen.visible).is_false()


func test_tab_skips_the_tutorial() -> void:
	var main: DriveScene = _main()
	await get_tree().process_frame
	var event: InputEventAction = InputEventAction.new()
	event.action = &"tutorial_skip"
	event.pressed = true
	main._unhandled_input(event)
	assert_bool(main.session.tutorial.skipped).is_true()
	assert_array(_opened).contains_exactly([AppFlow.START_SCENE])


func test_tab_does_nothing_in_a_normal_session() -> void:
	var main: DriveScene = _main("")
	await get_tree().process_frame
	var event: InputEventAction = InputEventAction.new()
	event.action = &"tutorial_skip"
	event.pressed = true
	main._unhandled_input(event)
	assert_int(main.session.state).is_equal(SessionManager.State.INTRO)
	assert_array(_opened).is_empty()


func test_a_finished_tutorial_recaps_the_three_rules() -> void:
	var main: DriveScene = _main()
	await get_tree().process_frame
	_finish(main)
	var hud: Hud = _hud(main)
	assert_array(_opened).is_empty()
	assert_bool(hud.ended_screen.visible).is_true()
	assert_str(hud.ended_label.text).is_equal(tr(&"TUTORIAL_DONE"))
	assert_bool(hud.ended_cause_label.visible).is_false()
	assert_bool(hud.summary_panel.visible).is_false()
	assert_bool(hud.tutorial_panel.visible).is_false()
	assert_bool(hud.tutorial_recap.visible).is_true()
	var recap: String = ""
	for child: Node in hud.tutorial_recap.get_children():
		recap += (child as Label).text + "\n"
	assert_str(recap).contains("prawym pasem")
	assert_str(recap).contains("Kierunkowskaz")
	assert_str(recap).contains("połowa prędkości")
	# Again or the menu; there is no result for the history.
	assert_bool(hud.again_button.visible).is_true()
	assert_bool(hud.menu_button.visible).is_true()
	assert_bool(hud.history_button.visible).is_false()


func test_again_after_the_tutorial_runs_it_again() -> void:
	var main: DriveScene = _main()
	await get_tree().process_frame
	_finish(main)
	_hud(main).again_requested.emit()
	assert_int(_started.size()).is_equal(1)
	assert_bool(_started[0].is_tutorial()).is_true()


func test_menu_after_the_tutorial_opens_the_start_screen() -> void:
	var main: DriveScene = _main()
	await get_tree().process_frame
	_finish(main)
	_hud(main).menu_requested.emit()
	assert_array(_opened).contains_exactly([AppFlow.START_SCENE])
