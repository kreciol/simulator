# Execution plan — settings: quality, mirrors, key-bindings preview, remembered (E11-S02)

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Issue: #44

## Goal

A player sets the graphics quality and the mirrors on a settings screen reached from the start screen, sees the key bindings (read-only), can toggle fullscreen, and the next session uses the settings — which survive a page reload through `user://settings.cfg` (requirements §9.4; spec Phase 10 step 1, settings part; Data Model: Persisted).

## Scope

- `PersistenceConfig.settings_path` (`user://settings.cfg`) in `config/persistence.tres`.
- `SettingsStore` (`persistence/`): quality id and mirrors in a `ConfigFile`; missing or invalid values take the launcher's defaults (`DevLauncherConfig.default_quality` / `default_mirrors`); saving never blocks play (a failed save just reports false). `SaveManager` loads it at start-up next to the history.
- `SessionSetup.options_for` takes the saved quality and mirrors and still builds the options through `DevLauncher.resolve` (one validation path).
- `KeyBindings` (`game/player/`): the game's Input Map actions (not the built-in `ui_*` ones) with the keys bound to each, for display only.
- `StartScreen`: the Settings entry is enabled and opens a settings page — quality low/high, mirrors on/off, fullscreen on/off, the key-bindings preview (labels only, nothing to press), Back (and Esc) to the menu. Every change is saved at once; a failed save is explained.
- Polish gender-neutral strings (settings, action names, key names).
- Docs: the persistence and session-flow rules for the settings file; README.

## Non-goals

- Remapping keys (issue: preview only).
- `tutorial_seen` and `sessions_completed_learn` in `settings.cfg` (tutorial is E11-S03; the completed-learn count is already read from the history).
- Changing what the URL params do: a dev-launcher launch keeps its own defaults (debug shortcut).
- UI theme beyond the existing placeholder styling.

## Decisions taken autonomously

- Fullscreen is not remembered: browsers allow entering fullscreen only from a player's gesture, so restoring it on load would fail on web; the toggle shows the window's current state instead.
- Settings apply to the next session started from the menu (the issue's "next session uses them"); "again" keeps the options of the session just played, as before.
- The key names shown are the physical keys from the Input Map (`OS.get_keycode_string`), with Polish names for the arrows and the few non-letter keys.

## Implementation Plan

### Phase 1 — Settings file and session options
1. `PersistenceConfig.settings_path`, `SettingsStore`, `SaveManager.settings`. *Tests:* round-trip through a `user://test_*` file, defaults when missing, invalid values fall back, failed save reports false.
2. `SessionSetup.options_for` with the saved quality and mirrors. *Tests:* the options carry them; unknown values fall back.

### Phase 2 — Settings screen
1. `KeyBindings` and the settings page on the start screen (quality, mirrors, fullscreen, key preview, back). *Tests:* page opens from the menu, choices saved and used by the next session's options, preview lists every game action with its keys and holds no buttons, Esc/Back return, Polish strings.

### Phase 3 — Docs
1. Agent docs (persistence, session flow), README.

## Risks

- Readability at 1280×720 is checked by layout (two columns) and recorded manually on the web build.

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Settings file and session options

- [ ] 1.1 SettingsStore in settings.cfg and SaveManager wiring
- [ ] 1.2 New-session options use the saved settings

### Phase 2: Settings screen

- [ ] 2.1 Settings page with quality, mirrors, fullscreen and the key-bindings preview

### Phase 3: Docs

- [ ] 3.1 Agent docs and README
