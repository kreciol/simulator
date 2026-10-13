# Session flow

**Read first:** requirements §9.3, §9.4; `game/session/`; `ui/start_screen.gd`, `MenuConfig` + `config/menu.tres`; `SimConfig.countdown_s` / `session_length_s` / `respawn_*`; `core/sim/respawn.gd`; `config/dev_launcher.tres`.

## States
- `SessionManager` owns the sim and is the only node that steps it.
- States: `INTRO` (countdown, sim frozen, input dropped) → `DRIVING` ⇄ `RESPAWNING` (learn only) → `ENDED`.
- `end_reason` is `TIME_UP`, `COLLISION` or `OFF_ROAD`; its §13 `status()` is `completed` / `aborted_collision` / `aborted_offroad`.
- Views and the HUD only read its state.

## Pause
- `paused` is orthogonal to `INTRO` / `DRIVING` / `RESPAWNING` (`pause` / `resume` / `toggle_pause`).
- While paused `step` does nothing.
- `NOTIFICATION_APPLICATION_FOCUS_OUT` or `NOTIFICATION_WM_WINDOW_FOCUS_OUT` pauses; focus returning does not resume.
- `physics/common/max_physics_steps_per_frame` caps catch-up.

## Modes, collisions and respawn
- The session carries the launch `mode`.
- Exam: a player collision or leaving the road ends the session at once as aborted, and the HUD names the cause (§9.2).
- Learn: a player collision or leaving the road starts a respawn instead — K4 is charged, the sim freezes and input is dropped for `respawn_fade_s` while the HUD fades and names what happened.
- The player is put back at the fade's midpoint through `Respawn`: the nearest free window on the right lane via `LaneQuery.is_lane_free` with no slower vehicle just beyond it, else the vehicles in the window are despawned; then `TrafficSim.place_vehicle` and `ScoringSystem.restart_after_respawn`.
- The timer runs on during a respawn — time-up still ends the session.
- A respawn moves the player outside `TrafficSim.step`, so a learn session with a respawn replays through `SessionManager` (seed + the commands fed while `DRIVING`), not `TrafficSim.replay` alone.

## Wiring
- `start` attaches a `Spawner` for the launch options' `DifficultyLevel`.
- With a `scoring_config` (set in `game/main.tscn`) it runs a `ScoringSystem` after every sim step and builds the `SessionRecord` at the end; `main.gd` saves it through `SaveManager`.
- With a `feedback_config` (also set in `game/main.tscn`) it also builds the `summary` the HUD's end screen shows.

## Menus and navigation
- The game opens on `StartScreen` (`ui/start_screen.tscn`, the main scene).
- The new-session setup turns mode · profile · level into `LaunchOptions` through `SessionSetup.options_for`, which reuses `DevLauncher.resolve` — one validation path for menus and URL.
- Learn mode is selected when the setup opens; a suggested exam is marked, never pre-selected.
- The exam is suggested after `MenuConfig.exam_suggested_after_learn_sessions` completed learn sessions (`SessionSetup.suggests_exam`).
- Every switch between screens goes through `AppFlow`; `AppFlow.start_session` hands the options to a fresh `game/main.tscn` before it enters the tree.
- Screens hold `AppFlow` calls as Callables, so tests watch instead of switching scenes.
- "Again" on the end screen keeps the choice with a new seed (`LaunchOptions.again`).

## Dev launcher
- `DevLauncher` turns URL params (web) or user args (desktop) into `LaunchOptions`; any known param (`DevLauncher.has_launch_params`) skips the menus.
- Platform params are taken once per run (`DevLauncher.take_platform_params`), so returning to the menu never bounces back into the same launch.
- Params: `mode`, `profile`, `level` (and its `DifficultyLevel`), `seed`, `quality` (`QualityPreset`), `mirrors` on/off, `perf` (FPS probe) on/off, `screen`.
- `screen=history` makes `main.gd` open `ui/history_screen.tscn` instead of starting a session.
- Invalid or missing values take the config default (`high`, mirrors on, probe off, a session).
