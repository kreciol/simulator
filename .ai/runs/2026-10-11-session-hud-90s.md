# Execution plan — basic HUD and the 90 s session (E03-S02)

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Issue: #8

## Goal

Give every drive a bounded session and basic driving information: a 3-2-1 countdown, then 90 s of driving on the right lane from the configured start speed, after which the session ends; a HUD shows speed (km/h), the road profile's limit, blinking signal arrows and the time left. This is spec Phase 3, step 3.

## Scope

- `config/sim_config.gd` + `config/sim_config.tres`: `countdown_s` (3 s) and `session_length_s` (90 s) [PARAM]s (spec Data Model: session length lives on `SimConfig`).
- `game/session/session_manager.gd` (`SessionManager`, Node): owns the sim and the player vehicle; state machine `INTRO → DRIVING → ENDED`; signals `session_started` and `session_ended`. During INTRO the sim is frozen and input is discarded, so the session timer has not started; DRIVING steps the sim and counts session time; ENDED freezes the sim again.
- `game/main.gd` + `game/main.tscn`: drive the session instead of the sim directly; add the HUD.
- `game/player/signal_blink.gd` (`SignalBlink`): the shared blink phase, so dashboard lamps and HUD arrows blink together.
- `ui/hud.gd` (`Hud`, CanvasLayer): speedometer, limit sign, signal arrows, time left (m:ss), countdown digits, "session ended" overlay. Only reads session state.
- `i18n/strings.csv`: Polish translations of the HUD's text (`km/h`, "Koniec sesji"); Polish set as the fallback locale in `project.godot`.

## Non-goals

- Score display, hints, mode-specific HUD, blind-spot icons (Phases 6–8).
- Pause and auto-pause on focus loss (Phase 7); dev launcher and profile selection (Phase 3 step 4).
- Summary screen; a collision or off-road ending the session (Phase 4 step 4 / Phase 7).

## Implementation Plan

### Phase 1 — Session flow
1. Session [PARAM]s and `SessionManager` state machine. *Tests:* the player starts on the right lane at the start speed; a countdown runs for `countdown_s` with the timer not started, the sim frozen and input ignored; the session ends after exactly `session_length_s` of stepped sim time (headless), emitting `session_ended` once; nothing advances after the end.
2. Main scene drives the session. *Tests:* scene test — the countdown runs first, then W accelerates the car; existing main-scene tests pass the countdown first.

### Phase 2 — HUD
1. Translations and the shared signal blink. *Tests:* `tr()` returns the Polish strings; `SignalBlink` phase matches the previous lamp behaviour.
2. `Hud` with speed, limit, signal arrows, time left, countdown and end overlay. *Tests:* speed text follows the player's speed in km/h; limit text is the profile's limit (140 motorway, 120 expressway); the arrow on the signalled side blinks, the other stays dark; time left counts down from 1:30 and reads 0:00 at the end; countdown digits 3-2-1 show only during INTRO; the end overlay shows only after the end.

## Risks

- Translation files: Godot generates `strings.pl.translation` on import; it is committed alongside the CSV so the project loads before the first import. The gate runs `--import` first either way.
- Session end uses accumulated fixed steps; a small epsilon absorbs float drift so 5400 steps of 1/60 s end the session exactly at 90 s.
- HUD layout is a first pass in code (no theme yet); Phase 10/11 restyles it.

## Progress

PR: #21

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Session flow

- [x] 1.1 Session params and SessionManager state machine — 7084a97
- [x] 1.2 Main scene drives the session — 417ada6

### Phase 2: HUD

- [x] 2.1 Translations and shared signal blink — c964824
- [x] 2.2 HUD speed, limit, signals, time, countdown and end overlay — 43c5caa
