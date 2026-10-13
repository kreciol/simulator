extends GdUnitTestSuite
## Guards the project-level settings the requirements fix (§3.3 renderer, §6.3 Input Map,
## §9.3 no fast-forward after a hidden tab).


func test_renderer_is_compatibility() -> void:
	assert_str(ProjectSettings.get_setting("rendering/renderer/rendering_method")).is_equal("gl_compatibility")
	assert_str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile")).is_equal("gl_compatibility")


func test_physics_steps_per_frame_are_capped() -> void:
	# A long frame (a tab coming back) catches up at most a few fixed steps instead of
	# fast-forwarding the sim (spec Architecture: Fixed step). Four still keeps full
	# speed down to 15 FPS at 60 ticks per second.
	assert_int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second")).is_equal(60)
	assert_int(ProjectSettings.get_setting("physics/common/max_physics_steps_per_frame")).is_equal(4)


func test_input_actions_have_primary_and_alternative_keys(
		action: StringName,
		primary: Key,
		alternative: Key,
		test_parameters: Array = [
			[&"accelerate", KEY_W, KEY_UP],
			[&"brake", KEY_S, KEY_DOWN],
			[&"lane_left", KEY_A, KEY_LEFT],
			[&"lane_right", KEY_D, KEY_RIGHT],
			[&"signal_left", KEY_Q, KEY_COMMA],
			[&"signal_right", KEY_E, KEY_PERIOD],
			[&"pause", KEY_ESCAPE, KEY_P],
		]) -> void:
	assert_bool(InputMap.has_action(action)).is_true()
	var keys: Array[Key] = []
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null:
			keys.append(key_event.physical_keycode)
	assert_array(keys).contains_exactly([primary, alternative])


func test_the_game_opens_on_the_start_screen() -> void:
	# Spec UI/UX flow (issue #43); dev-launcher params skip it to a session.
	assert_str(ProjectSettings.get_setting("application/run/main_scene")).is_equal(AppFlow.START_SCENE)
