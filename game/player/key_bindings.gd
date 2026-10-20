class_name KeyBindings
extends RefCounted
## The controls as the settings screen previews them (requirements §6, §9.4, issue
## #44): the game's own Input Map actions — not Godot's built-in `ui_*` ones — with the
## keys bound to each, in the order the project defines them. Read-only: keys are
## never remapped here.

const BUILT_IN_PREFIX: String = "ui_"
## Translation key of an action's name: `ACTION_` + the action in upper case.
const ACTION_KEY_PREFIX: String = "ACTION_"
## Translation key of a key's name, when it has a Polish one: `KEY_NAME_` + the key's
## English name in upper case, spaces as underscores (`KEY_NAME_UP`).
const KEY_NAME_PREFIX: String = "KEY_NAME_"


## The game's actions, as the Input Map holds them.
static func actions() -> Array[StringName]:
	var game_actions: Array[StringName] = []
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with(BUILT_IN_PREFIX):
			game_actions.append(action)
	return game_actions


## The English names of the keys bound to `action` (`W`, `Up`), physical keys first as
## the Input Map stores them; events other than keys are left out.
static func key_names(action: StringName) -> PackedStringArray:
	var names: PackedStringArray = []
	for event: InputEvent in InputMap.action_get_events(action):
		var key: InputEventKey = event as InputEventKey
		if key == null:
			continue
		var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		names.append(OS.get_keycode_string(code))
	return names


## Translation key of the action's name.
static func action_label_key(action: StringName) -> StringName:
	return StringName(ACTION_KEY_PREFIX + String(action).to_upper())


## Translation key of a key's name.
static func key_label_key(key_name: String) -> StringName:
	return StringName(KEY_NAME_PREFIX + key_name.to_upper().replace(" ", "_"))
