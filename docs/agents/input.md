# Input

**Read first:** requirements §6; `game/player/player_input.gd`, `game/main.gd`; touch: `.ai/specs/2026-10-20-touch-controls.md`, `game/player/touch_button.gd`, `ui/touch_controls.gd`, `TouchConfig` + `config/touch.tres`.

- Actions are defined in the Godot **Input Map**, never hard-coded keys.
- `PlayerInput` turns action events into one `PlayerCommands` per physics step.
- The `pause` action is handled by `main.gd` (`SessionManager.toggle_pause`), not as a driving command.
- The settings screen previews the game's Input Map actions through `KeyBindings`, read-only — keys are not remapped.
- A new action needs `ACTION_<NAME>` in `i18n/strings.csv` (and `KEY_NAME_<KEY>` for a key named by more than one letter).
- The `mute` action is handled by `main.gd` (`AudioView.toggle_mute`), not as a driving command.
- The `tutorial_skip` action is handled by `main.gd` (`SessionManager.skip_tutorial`), only in the tutorial.
- Touch buttons fire Input Map actions as `InputEventAction` through `Input.parse_input_event`, never a command or a key of their own.
- `PlayerInput` holds accelerate/brake per source (a key, a touch button), so releasing one keeps the action held by another.
- A touch button tracks touches by index (multitouch) and swallows the mouse click Godot emulates from a touch.
- Touch buttons exist on a touch device, after the first touch or with `touch=1` — never on a desktop without touch and no param.
- Hiding the touch buttons or losing focus releases every held button.
- Button positions and sizes live in `config/touch.tres`.
- With touch buttons shown, texts name the buttons (`TOUCH_*` labels), never keys: the tutorial's `TOUCH_PROMPT_KEYS`, the pause hint, the settings' touch preview.
