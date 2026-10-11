# Execution plan — dev launcher: mode, profile, level and seed from the URL (E03-S03)

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Issue: #9

## Goal

Until the Phase 10 menus exist, a tester can start any mode, road profile, difficulty level and seed on the deployed build: `?mode=learn|exam&profile=motorway|expressway&level=1-4&seed=N` (read via `JavaScriptBridge` on web, command-line user args on desktop) becomes the session's launch options, with defaults for missing or invalid values. Spec Phase 3, step 4.

## Scope

- `config/dev_launcher_config.gd` (`DevLauncherConfig`) + `config/dev_launcher.tres`: the selectable road profiles, the default mode / profile / level, and the level count — every value a [PARAM] in the `.tres`.
- `game/session/launch_options.gd` (`LaunchOptions`): the resolved mode, profile, level and seed of one session.
- `game/session/dev_launcher.gd` (`DevLauncher`): pure static parsing of a URL query string and of user args into the same key/value map, validation against the config with per-key defaults, and the platform read (`JavaScriptBridge` on web, `OS.get_cmdline_user_args()` elsewhere). A missing or invalid seed falls back to a random one; the resolved seed is printed so a session can be replayed.
- `SessionManager.start(options, sim_config)`: sets the session up from launch options and keeps them for later phases (mode: Phase 7, level: the spawner).
- `game/main.gd` / `game/main.tscn`: the scene starts from the launcher instead of a fixed `road_profile`.
- README: how to use the launcher (web and desktop).
- gdUnit4 tests for every acceptance criterion of #9.

## Non-goals

- Real menus (Phase 10); mode-dependent behaviour (Phase 7).
- Driving the spawner from `level` — `DifficultyLevel` and the spawner land with E04-S02 (#12, PR #22); this run only carries the validated level on the session.
- The `perf=1` FPS probe flag (Phase 5).

## Implementation Plan

### Phase 1 — Parse and validate
1. `DevLauncherConfig` + `.tres`, `LaunchOptions`, `DevLauncher` query/user-arg parsing and validation. *Tests:* valid params; missing params → defaults; invalid values (`level=9`, unknown profile/mode, non-numeric/negative seed, malformed pairs) → defaults, no crash; user args parse the same as the query; case-insensitive values; unknown keys ignored.

### Phase 2 — Wire into the session
1. `SessionManager.start`, `main` starts from the launcher, README usage. *Tests:* `?profile=expressway` → session on the expressway profile and HUD limit 120; launch options and seed reach the session; main scene still starts on the default profile without params.

## Risks

- `JavaScriptBridge` is only exercised on the web export: the read is a one-line `window.location.search` eval behind `OS.has_feature("web")`; the parser it feeds is unit-tested. Manual check on the Pages build after merge.
- PR #22 (spawner, difficulty levels) is in flight and also touches `AGENTS.md`; this run edits only the session-flow routing row to keep the merge trivial.

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Parse and validate

- [ ] 1.1 DevLauncher parsing and validation with defaults

### Phase 2: Wire into the session

- [ ] 2.1 Session and main scene start from launch options
