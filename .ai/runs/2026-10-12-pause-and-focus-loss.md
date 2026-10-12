# Execution plan — pause with Esc or P, auto-pause on focus loss (E08-S03)

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Issue: #34

## Goal

The player can stop mid-session with Esc or P and carry on with the same key; the game pauses itself when the window or tab loses focus, and a tab coming back after a long time does not fast-forward. Spec Phase 7 step 2 (pause part), Edge Cases "Pause during lane change / countdown" and "Browser tab hidden".

## Scope

- `SessionManager`: `pause()` / `resume()` / `toggle_pause()`, `paused` flag and `session_paused` / `session_resumed` signals. While paused `step` does nothing: the sim (lane-change animation, signals, AI, spawner), the session timer and the countdown all freeze and commands are dropped. Grace periods live in the scoring rules and advance only with `sim.step`, so they freeze too once scoring is wired in. Pausing is possible during the countdown and while driving, not after the end.
- `SessionManager._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)` pauses the session. Resuming is left to the player (no auto-resume on focus in).
- `project.godot`: `physics/common/max_physics_steps_per_frame` set explicitly so a long frame catches up only a few steps instead of fast-forwarding.
- `game/main.gd`: the `pause` Input Map action toggles the pause; driving input is reset on pause.
- `Hud`: a dimmed pause screen with a "Pauza" title and the resume hint; strings in `i18n/strings.csv`.
- AGENTS.md status/routing update.

## Decision

The spec draws `DRIVING ⇄ PAUSED`, but the issue and the spec's Edge Cases also pause the countdown. Pause is therefore modelled as a flag orthogonal to `INTRO` / `DRIVING` rather than a fourth `State`: `state` keeps saying which phase to resume into, and `countdown_left_s` / `time_left_s` stay correct while paused without a "state before pause" field.

## Non-goals

- A pause menu with settings (E11), respawn and the rest of Phase 7.
- Auto-resume when focus returns.

## Implementation Plan

### Phase 1 — Session pause
1. `SessionManager` pause, resume and focus-loss auto-pause. *Tests:* paused driving session does not advance (sim time, player s, lane-change progress, timer, input log); paused countdown does not advance; resume continues from the same point; focus-out notification pauses; pause after the end is ignored; signals emitted once.
2. Capped physics steps per frame. *Tests:* project setting is set and small.

### Phase 2 — Pause in the game
1. Esc / P toggle the pause in the main scene; HUD pause screen. *Tests:* pressing Esc pauses and P resumes in the scene; held keys pressed while paused do not move the car; HUD shows the pause screen only while paused; Polish strings exist.

### Phase 3 — Docs
1. AGENTS.md status and routing.

## Risks

- Parallel branches (#32 exam abort cause) also touch `SessionManager`; the change is additive to keep conflicts small.
- Web focus events: Godot's web platform sends `NOTIFICATION_APPLICATION_FOCUS_OUT` on window blur; the step cap covers the case where it does not.

## Progress

PR: #56

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Session pause

- [x] 1.1 SessionManager pause, resume and focus-loss auto-pause — 8667795
- [x] 1.2 Capped physics steps per frame — 6b9c2ee

### Phase 2: Pause in the game

- [x] 2.1 Esc and P toggle the pause in the main scene; HUD pause screen — 631c526

### Phase 3: Docs

- [x] 3.1 AGENTS.md status and routing — d270ad5
