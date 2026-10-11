extends GdUnitTestSuite
## Guards the project-level settings the requirements fix (§3.3 renderer, §6.3 Input Map).


func test_renderer_is_compatibility() -> void:
	assert_str(ProjectSettings.get_setting("rendering/renderer/rendering_method")).is_equal("gl_compatibility")
	assert_str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile")).is_equal("gl_compatibility")


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
