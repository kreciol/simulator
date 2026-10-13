# Execution plan — start screen, new-session setup and the menu flow (E11-S01)

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Issue: #43

## Goal

A player starts the game from a start screen and picks mode, road profile and level without editing the URL (requirements §9.1, §9.4; spec Phase 10 step 1, flow part; UI/UX flow): Start → New session (mode · profile · level, recommended level highlighted) → 3-2-1 → Drive → Summary → History / again. The dev launcher's URL params still start a session directly.

## Scope

- `MenuConfig` + `config/menu.tres`: the exam is suggested after [PARAM] 3 completed learn sessions (requirements §9.1).
- `SessionSetup` (pure, `game/session/`): counts completed learn sessions in the saved history, decides whether the exam is suggested, picks the recommended level (`DifficultyLevel.recommended`, Q14), and builds the `LaunchOptions` of a chosen mode · profile · level through `DevLauncher.resolve` (one validation path).
- `AppFlow` (`game/session/`): the scene paths and the switch into a session with given `LaunchOptions` (the main scene instance gets them before it enters the tree).
- `DevLauncher.has_launch_params`: any recognised param means "start directly", as before the menus.
- `ui/StartScreen` + `ui/start_screen.tscn`, the new main scene: the menu (New session, History, Settings, Tutorial — the last two shown but disabled until E11-S02 / E11-S03 — and the "educational tool, not legal advice" note), and the setup page (mode, profile, all four levels with the recommended one highlighted, learn selected for a new player, exam marked as suggested after 3 completed learn sessions; Start and Back). With launch params in the URL / user args it skips straight to the session (or `screen=history`).
- End screen: "Again" (same mode · profile · level, a new seed), "History" and "Menu" buttons under the summary (`Hud` + `main.gd`).
- History screen: a "Back to menu" button.
- Polish gender-neutral strings, including the missing level names (`LEVEL_*`).
- AGENTS.md status and routing, README.

## Non-goals

- Settings screen (E11-S02) and tutorial (E11-S03): their menu entries are visible but disabled.
- UI theme beyond the existing placeholder styling.
- Changing the session flow, scoring or the save format.

## Decisions taken autonomously

- When the exam is suggested, learn stays selected; the exam option is marked "suggested" with a line explaining why. "Learn is the default for a new player" (§9.1) and a suggestion is not a switch — the player chooses.
- "Again" keeps mode, profile, level, quality and mirrors and draws a new seed, so the traffic differs between attempts.

## Implementation Plan

### Phase 1 — Rules and flow plumbing
1. `MenuConfig` + `config/menu.tres`; `SessionSetup` (completed learn count, exam suggestion, recommended level, options for a choice). *Tests:* 0–2 vs ≥ 3 completed learn sessions, aborted and exam sessions not counted, recommended level, built options.
2. `DevLauncher.has_launch_params`, `LaunchOptions.again`, `AppFlow`. *Tests:* params detection, again keeps the choice with a new seed.

### Phase 2 — Screens
1. `StartScreen` (menu + setup) and `ui/start_screen.tscn` as the main scene; launch params skip it. *Tests:* menu entries and note, setup defaults, all levels selectable, recommended highlighted, exam suggestion, Start builds options, params start a session directly.
2. End-screen buttons (again / history / menu) and the history screen's back button. *Tests:* buttons shown only once ended; each navigates where it should.

### Phase 3 — Docs
1. AGENTS.md status and routing, README.

## Risks

- Changing the main scene: CI export and the web build open the start screen now; the dev-launcher params keep the direct start.
- Manual flow check on the web build (spec Phase 10 step 1 *Tests: manual flow*) recorded in the PR.

## Progress

PR: #69

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Rules and flow plumbing

- [x] 1.1 MenuConfig and SessionSetup with the exam-suggestion rule — dee3df2
- [x] 1.2 Launch-params detection, again options and AppFlow — 2973d49

### Phase 2: Screens

- [x] 2.1 Start screen with menu and new-session setup as the main scene — 0c4a191, 3b45af6
- [x] 2.2 End-screen and history-screen navigation — 0c68a90

### Phase 3: Docs

- [x] 3.1 AGENTS.md status and routing, README — be8e49c
