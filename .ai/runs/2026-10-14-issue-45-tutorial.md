# Execution plan — a short, skippable tutorial on an empty road (E11-S03)

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Issue: #45

## Goal

A first-time player is offered a short tutorial (requirements §12; spec Phase 10 step 2): on an empty road with no scoring, prompts lead through accelerate → slow down → signal → change lane → return right → check mirrors, each advancing when done; the end recaps the three rules (right lane, signal, gap = half the speed); it can be skipped at once and re-run from the menu.

## Scope

- `TutorialConfig` + `config/tutorial.tres`: the speed change that completes the accelerate / slow-down steps and how long the mirror step lasts [PARAM].
- `Tutorial` (pure, `core/tutorial/`): the prompts state machine. It observes the player's `VehicleState` after every sim step and advances when the current step is done; `skip()` ends it at once.
- `LaunchOptions.tutorial`; `SessionSetup.tutorial_options` (learn mode, the launcher's default profile, no traffic).
- `SessionManager`: a tutorial session has no spawner, no scoring, no hints and no time limit; it ends when the tutorial is finished or skipped. Leaving the road still puts the player back (learn respawn).
- `Hud`: the step prompt ("Krok n z 6"), a skip button, the time left hidden; the end screen shows the three-rule recap with "again" and "menu".
- `main.gd`: the `tutorial_skip` Input Map action (Tab) and the skip button skip the tutorial; a skipped tutorial returns to the start screen at once. A finished or skipped tutorial is marked as seen.
- `SettingsStore` (`persistence/`, `user://settings.cfg`, `ConfigFile`): `tutorial_seen`, owned by `SaveManager`.
- `StartScreen`: the tutorial entry is enabled; until the tutorial has been seen it is marked suggested, takes the focus and a line says why.
- Polish gender-neutral strings; docs/agents rules for the tutorial.

## Non-goals

- Scoring during the tutorial (issue #45 out of scope).
- The settings screen (E11-S02) and the other `settings.cfg` keys (quality, sessions_completed_learn).
- Saving a tutorial to the history.

## Decisions taken autonomously

- "Check mirrors" has no input of its own (the mirrors are always on screen): the step points at the mirrors and completes after `TutorialConfig.mirror_check_s` of driving. `# TODO(open):` if a head-turn / mirror-look input is added later.
- Accelerate / slow down complete once the speed is `speed_change_kmh` above / below the speed the step started at, so they work at any start speed.
- Signal means the left signal (the player starts on the right lane, so the only change is to the left); return right completes once back on the right lane after the change.
- The tutorial is marked seen when it is finished or skipped, not when it is opened, so a closed tab suggests it again.
- Skipping returns to the start screen at once; the recap is shown only at the end of a finished tutorial.

## Implementation Plan

### Phase 1 — Tutorial state machine
1. `TutorialConfig` + `config/tutorial.tres`. *Tests:* values load.
2. `Tutorial` state machine in `core/tutorial/`. *Tests:* step progression in order, each step only advancing when done, skip ends at once, finished state.

### Phase 2 — Session and HUD
1. `LaunchOptions.tutorial`, `SessionSetup.tutorial_options`, `SessionManager` tutorial sessions (no traffic, scoring, hints or time limit; ends on finish or skip). *Tests:* headless session tests.
2. HUD prompt, skip button and recap end screen; `main.gd` skip action and button, back to the menu after a skip. *Tests:* HUD visibility, skip goes to the menu, finished shows the recap.

### Phase 3 — Seen flag and start screen
1. `SettingsStore` + `SaveManager.settings`; `main.gd` marks the tutorial seen. *Tests:* round-trip through `settings.cfg`, missing file means unseen.
2. Start screen: the tutorial entry enabled, suggested until seen. *Tests:* suggestion on first launch, none once seen, the button starts a tutorial.

### Phase 4 — Strings and docs
1. Polish strings and the translation test.
2. docs/agents rules (session flow, input, persistence).

## Risks

- `settings.cfg` will also hold E11-S02's settings: `SettingsStore` keeps unknown keys when it writes.
- Manual check of the tutorial on the web build, recorded in the PR.

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Tutorial state machine

- [ ] 1.1 TutorialConfig and its resource
- [ ] 1.2 Tutorial prompts state machine

### Phase 2: Session and HUD

- [ ] 2.1 Tutorial sessions in SessionManager
- [ ] 2.2 HUD prompt, skip and recap

### Phase 3: Seen flag and start screen

- [ ] 3.1 SettingsStore with tutorial_seen
- [ ] 3.2 Start screen suggests and starts the tutorial

### Phase 4: Strings and docs

- [ ] 4.1 Polish strings
- [ ] 4.2 Agent docs
