extends GdUnitTestSuite
## The key-bindings preview's source (issue #44, requirements §6): the game's Input Map
## actions, not Godot's built-in ones, with the keys bound to each, every one named in
## Polish.


## The actions `project.godot` defines.
func _project_actions() -> Array[StringName]:
	var actions: Array[StringName] = []
	for property: Dictionary in ProjectSettings.get_property_list():
		var setting: String = property["name"]
		if setting.begins_with("input/") and not setting.begins_with("input/ui_"):
			actions.append(StringName(setting.trim_prefix("input/")))
	return actions


func test_the_actions_are_the_games_own_in_project_order() -> void:
	var actions: Array[StringName] = KeyBindings.actions()
	assert_array(actions).contains_exactly_in_any_order(_project_actions())
	for action: StringName in actions:
		assert_bool(String(action).begins_with("ui_")).is_false()
	assert_str(actions[0]).is_equal(&"accelerate")


func test_every_action_has_a_key() -> void:
	for action: StringName in KeyBindings.actions():
		assert_array(Array(KeyBindings.key_names(action))).is_not_empty()


func test_key_names_follow_the_input_map() -> void:
	assert_array(Array(KeyBindings.key_names(&"accelerate"))).contains_exactly(["W", "Up"])
	assert_array(Array(KeyBindings.key_names(&"signal_right"))).contains_exactly(["E", "Period"])


func test_every_action_and_key_has_a_polish_name() -> void:
	for action: StringName in KeyBindings.actions():
		var action_key: StringName = KeyBindings.action_label_key(action)
		assert_str(TranslationServer.translate(action_key)).is_not_equal(String(action_key))
		for key_name: String in KeyBindings.key_names(action):
			# Single letters stay as they are; longer names need a translation.
			if key_name.length() > 1:
				var name_key: StringName = KeyBindings.key_label_key(key_name)
				assert_str(TranslationServer.translate(name_key)).is_not_equal(String(name_key))
