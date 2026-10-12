# Execution plan — learn-only HUD: live score and blind-spot icons (issue #35)

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md (Phase 7 step 3; Decisions Q10, Q11)
Issue: #35 (E08-S04)

## Goal

In learn mode the player sees the live score and, by each side mirror, an icon with a text label whenever a vehicle sits in that side's blind spot; the exam HUD shows neither.

## Scope

- `core/sim/lane_query.gd` — `LaneQuery.blind_spot_occupied`: the one blind-spot check, built on `is_lane_free` for the lane beside the vehicle.
- `config/view_config.gd` + `view_config.tres` — blind-spot zone [PARAM]s (`blind_spot_ahead_m`, `blind_spot_behind_m`), measured from the vehicle's centre.
- `game/session/session_manager.gd` — owns a `ScoringSystem` when given a `ScoringConfig`: observes after every sim step, finishes at the end. `game/main.gd` / `main.tscn` pass `config/scoring.tres`.
- `ui/hud.gd` — learn-only score box (top right) and blind-spot icons (warning triangle + "Martwe pole" text) placed under each side mirror's screen rect; hidden in exam. Strings in `i18n/strings.csv`.

## Non-goals

- Hint messages (E09-S01), summary screen (E09-S02), learn respawn / K4 handling (E08-S02), pause (E08-S03).
- Persisting the record or wiring `SessionRecordBuilder` into the session.

## Implementation Plan

### Phase 1: Blind-spot query

1. `LaneQuery.blind_spot_occupied(lanes, vehicle, dir, ahead_m, behind_m)` and the zone [PARAM]s in `ViewConfig`. *Tests:* vehicles inside / outside the zone on each side, the vehicle's own lane, beyond the road edge.

### Phase 2: Live score in the session

1. `SessionManager` builds a `ScoringSystem` from an optional `ScoringConfig`, observes it after each driving step and finishes it when the session ends; `Main` passes `scoring.tres`. *Tests:* score grows while driving correctly; frozen during the intro; no scoring without a config.

### Phase 3: Learn-only HUD

1. HUD score box and blind-spot icons by the side mirrors, learn mode only, translated strings. *Tests:* scene tests — learn shows the score and the icon on the occupied side only; exam shows neither.

## Risks

- Wiring scoring into `SessionManager` touches the file open PRs (#56 pause) also edit — conflicts are resolved against the latest base in review.
- Zone defaults (1 m ahead, 8 m behind the centre) are a first guess, tunable in Phase 11.

## Progress

PR: #59

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Blind-spot query

- [x] 1.1 Blind-spot query and zone params — ceb28e3

### Phase 2: Live score in the session

- [x] 2.1 Session owns the scoring system — 87e1908 (superseded on merge by main's #54, which wires the same scoring into `SessionManager`)

### Phase 3: Learn-only HUD

- [x] 3.1 Score box and blind-spot icons in learn mode only — b1b1e64
