class_name PlayerInput
extends RefCounted
## Turns Input Map action events (requirements §6.3) into one `PlayerCommands` per
## physics step. Keys are never hard-coded: only action names are matched.
## Accelerate/brake act while held; lane change and signal fire once per press.

## Physical keys currently holding an action down, keyed by physical keycode, so
## releasing one of two keys bound to the same action keeps it held.
var _held: Dictionary[Key, StringName] = {}
var _lane_change: VehicleState.Dir = VehicleState.Dir.NONE
var _signal_toggle: VehicleState.Dir = VehicleState.Dir.NONE


## Records `event`; returns whether it matched a driving action.
func handle_event(event: InputEvent) -> bool:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or key_event.is_echo():
		return false
	for action: StringName in [&"accelerate", &"brake"]:
		if event.is_action(action):
			if event.is_pressed():
				_held[key_event.physical_keycode] = action
			else:
				_held.erase(key_event.physical_keycode)
			return true
	if not event.is_pressed():
		return event.is_action(&"lane_left") or event.is_action(&"lane_right") \
				or event.is_action(&"signal_left") or event.is_action(&"signal_right")
	if event.is_action(&"lane_left"):
		_lane_change = VehicleState.Dir.LEFT
	elif event.is_action(&"lane_right"):
		_lane_change = VehicleState.Dir.RIGHT
	elif event.is_action(&"signal_left"):
		_signal_toggle = VehicleState.Dir.LEFT
	elif event.is_action(&"signal_right"):
		_signal_toggle = VehicleState.Dir.RIGHT
	else:
		return false
	return true


## Commands for the coming step. One-shot requests are cleared; held keys persist.
## Braking wins when both accelerate and brake are held.
func consume() -> PlayerCommands:
	var longitudinal: VehicleState.Longitudinal = VehicleState.Longitudinal.NONE
	if _held.values().has(&"brake"):
		longitudinal = VehicleState.Longitudinal.BRAKE
	elif _held.values().has(&"accelerate"):
		longitudinal = VehicleState.Longitudinal.ACCELERATE
	var commands: PlayerCommands = PlayerCommands.create(longitudinal, _lane_change, _signal_toggle)
	_lane_change = VehicleState.Dir.NONE
	_signal_toggle = VehicleState.Dir.NONE
	return commands


## Forgets all input, e.g. when the window loses focus and key releases go unseen.
func reset() -> void:
	_held.clear()
	_lane_change = VehicleState.Dir.NONE
	_signal_toggle = VehicleState.Dir.NONE
