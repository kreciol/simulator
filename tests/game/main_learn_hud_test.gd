extends GdUnitTestSuite
## The main scene's HUD shows the live score and blind-spot warnings in learn mode and
## neither in the exam (issue #35 acceptance criteria, spec Phase 7 step 3, Q10, Q11).

const DT: float = 1.0 / 60.0
const MAIN_SCENE: String = "res://game/main.tscn"


## The main scene started as the dev launcher would start it with `query`, driving.
func _main(query: String) -> Node3D:
	var launcher: DevLauncherConfig = load("res://config/dev_launcher.tres") as DevLauncherConfig
	var main: Node3D = (load(MAIN_SCENE) as PackedScene).instantiate() as Node3D
	main.launch_options = DevLauncher.resolve(DevLauncher.parse_query(query), launcher, 1)
	add_child(auto_free(main))
	while main.session.state == SessionManager.State.INTRO:
		main._physics_process(DT)
	return main


func _drive(main: Node3D, steps: int) -> void:
	for i: int in steps:
		main._physics_process(DT)
	main._process(DT)


## Puts a vehicle just behind the player on the lane to its left, at its speed.
func _fill_left_blind_spot(main: Node3D) -> void:
	var player: VehicleState = main.player as VehicleState
	main.sim.add_vehicle(player.s - 5.0, player.lane + 1, player.speed_mps)


func _hud(main: Node3D) -> Hud:
	return main.get_node("Hud") as Hud


func test_learn_shows_the_live_score_and_the_blind_spot_warning() -> void:
	var main: Node3D = _main("?mode=learn")
	_drive(main, 60)
	var hud: Hud = _hud(main)
	var session: SessionManager = main.session
	assert_object(session.scoring).is_not_null()
	assert_bool(hud.score_panel.is_visible_in_tree()).is_true()
	assert_str(hud.score_label.text).is_equal(str(roundi(session.scoring.total_score())))

	_fill_left_blind_spot(main)
	_drive(main, 1)
	assert_bool(hud.blind_spot_left.is_visible_in_tree()).is_true()
	assert_bool(hud.blind_spot_right.visible).is_false()


func test_exam_shows_neither_the_score_nor_a_blind_spot_warning() -> void:
	var main: Node3D = _main("?mode=exam")
	_drive(main, 60)
	var hud: Hud = _hud(main)
	# The exam is still scored, for the summary; the HUD just does not show it.
	assert_object(main.session.scoring).is_not_null()
	assert_bool(hud.score_panel.visible).is_false()

	_fill_left_blind_spot(main)
	_drive(main, 1)
	assert_bool(hud.blind_spot_left.visible).is_false()
	assert_bool(hud.blind_spot_right.visible).is_false()
