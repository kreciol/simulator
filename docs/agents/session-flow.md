# Session flow

**Read first:** requirements §9.3; `game/session/`; `SimConfig.countdown_s` / `session_length_s` / `respawn_*`; `core/sim/respawn.gd`; `config/dev_launcher.tres`.

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

## Dev launcher
- Until the Phase 10 menus, `DevLauncher` turns URL params (web) or user args (desktop) into `LaunchOptions`.
- Params: `mode`, `profile`, `level` (and its `DifficultyLevel`), `seed`, `quality` (`QualityPreset`), `mirrors` on/off, `perf` (FPS probe) on/off, `screen`.
- `screen=history` makes `main.gd` open `ui/history_screen.tscn` instead of starting a session.
- Invalid or missing values take the config default (`high`, mirrors on, probe off, a session).
