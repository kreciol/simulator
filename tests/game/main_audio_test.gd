extends GdUnitTestSuite
## The main scene plays the sound effects: silent until the first key, click or touch,
## and `M` mutes them with an icon and text on the HUD (issue #72 acceptance criteria,
## spec `2026-10-13-sound-effects.md` Phase 1 step 4).

const DT: float = 1.0 / 60.0
const MAIN_SCENE: String = "res://game/main.tscn"


func before_test() -> void:
	AudioView.reset_run()


func after_test() -> void:
	AudioView.reset_run()
	AudioServer.set_bus_mute(AudioServer.get_bus_index(AudioView.MASTER_BUS), false)


func _main() -> Node3D:
	var launcher: DevLauncherConfig = load("res://config/dev_launcher.tres") as DevLauncherConfig
	var main: Node3D = (load(MAIN_SCENE) as PackedScene).instantiate() as Node3D
	main.launch_options = DevLauncher.resolve(DevLauncher.parse_query("?mode=learn"), launcher, 1)
	add_child(auto_free(main))
	return main


func _audio(main: Node3D) -> AudioView:
	return main.get_node("AudioView") as AudioView


func _hud(main: Node3D) -> Hud:
	return main.get_node("Hud") as Hud


func _press(main: Node3D, event: InputEvent) -> void:
	main._unhandled_input(event)


func _key(key: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	return event


func _master_muted() -> bool:
	return AudioServer.is_bus_mute(AudioServer.get_bus_index(AudioView.MASTER_BUS))


func test_the_scene_uses_the_audio_config() -> void:
	var main: Node3D = _main()
	assert_object(main.audio_config).is_not_null()
	assert_object(_audio(main).config).is_same(main.audio_config)


func test_engine_top_speed_is_the_limit_plus_the_s1_tolerance() -> void:
	var main: Node3D = _main()
	var scoring: ScoringConfig = main.session.scoring_config
	assert_float(_audio(main).top_speed_kmh).is_equal(
			main.road_profile.speed_limit_kmh + scoring.speed_tolerance_kmh)


func test_silent_until_the_first_key() -> void:
	var main: Node3D = _main()
	assert_bool(_master_muted()).is_true()
	# A key release is no gesture.
	var release: InputEventKey = _key(KEY_W)
	release.pressed = false
	_press(main, release)
	assert_bool(_audio(main).locked).is_true()
	_press(main, _key(KEY_W))
	assert_bool(_audio(main).locked).is_false()
	assert_bool(_master_muted()).is_false()


func test_a_click_or_touch_also_unlocks() -> void:
	var main: Node3D = _main()
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_press(main, click)
	assert_bool(_audio(main).locked).is_false()
	var other: Node3D = _main()
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	_press(other, touch)
	assert_bool(_audio(other).locked).is_false()


func test_m_mutes_and_unmutes_with_the_hud_indicator() -> void:
	var main: Node3D = _main()
	var hud: Hud = _hud(main)
	main._process(DT)
	assert_bool(hud.muted_indicator.visible).is_false()
	_press(main, _key(KEY_M))
	main._process(DT)
	assert_bool(_audio(main).user_muted).is_true()
	assert_bool(_master_muted()).is_true()
	assert_bool(hud.muted_indicator.visible).is_true()
	_press(main, _key(KEY_M))
	main._process(DT)
	assert_bool(_audio(main).user_muted).is_false()
	assert_bool(_master_muted()).is_false()
	assert_bool(hud.muted_indicator.visible).is_false()


func test_m_is_not_a_driving_command() -> void:
	var main: Node3D = _main()
	while main.session.state == SessionManager.State.INTRO:
		main._physics_process(DT)
	var player: VehicleState = main.player as VehicleState
	_press(main, _key(KEY_M))
	main._physics_process(DT)
	assert_int(player.signal_dir).is_equal(VehicleState.Dir.NONE)
	assert_bool(player.lane_change_active).is_false()
	assert_int(player.longitudinal).is_equal(VehicleState.Longitudinal.NONE)


func test_mute_and_unlock_carry_over_to_the_next_session() -> void:
	# Issue #43: "again" or the menu start a new scene; the player's mute stays.
	var first: Node3D = _main()
	_press(first, _key(KEY_W))
	_press(first, _key(KEY_M))
	var next: Node3D = _main()
	assert_bool(_audio(next).locked).is_false()
	assert_bool(_audio(next).user_muted).is_true()
	_press(next, _key(KEY_M))
	var third: Node3D = _main()
	assert_bool(_audio(third).user_muted).is_false()
