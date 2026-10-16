# Input

**Read first:** requirements §6; `game/player/player_input.gd`, `game/main.gd`.

- Actions are defined in the Godot **Input Map**, never hard-coded keys.
- `PlayerInput` turns action events into one `PlayerCommands` per physics step.
- The `pause` action is handled by `main.gd` (`SessionManager.toggle_pause`), not as a driving command.
- The `mute` action is handled by `main.gd` (`AudioView.toggle_mute`), not as a driving command.
- The `tutorial_skip` action is handled by `main.gd` (`SessionManager.skip_tutorial`), only in the tutorial.
