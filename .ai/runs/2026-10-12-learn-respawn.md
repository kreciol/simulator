# Execution plan — in learn mode a collision or leaving the road puts the player back on the road (E08-S02)

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Issue: #33

## Goal

In learn mode a mistake teaches instead of ending the session: a player collision or leaving the road charges K4, shows a message and a short fade, and puts the player back on the right lane at a free gap at the configured speed while the session timer keeps running (requirements §9.2, spec Phase 7 step 2, respawn part).

## Scope

- `SessionManager` owns a `ScoringSystem` (from a `ScoringConfig` passed to `start` / `setup`; `main.tscn` passes `config/scoring.tres`), observed after every sim step and finished at the end, so K4 is charged in the session.
- New state `RESPAWNING` (learn only): entered after the step with the player's collision or off-road; the sim is frozen and input dropped for `respawn_fade_s`; the player is put back at the fade's midpoint; the timer keeps running and time-up still ends the session.
- `Respawn` (`core/sim/respawn.gd`): the nearest position on the right lane, within `respawn_search_range_m` of the incident, whose window (`respawn_clear_ahead_m` / `respawn_clear_behind_m` beyond the body) is free via `LaneQuery.is_lane_free`; when none is, the vehicles in the window at the incident are despawned first.
- `TrafficSim.place_vehicle`: moves a vehicle to a lane and `s` at a speed, clearing lane change, signal and off-road, re-indexing lanes and forgetting its contacts.
- `ScoringSystem.restart_after_respawn`: closes open segments and resets `LaneChangeRule`'s overtake memory (issue #33 comment from the #50 review).
- HUD: a fade overlay and a message naming what happened while respawning; strings in `i18n/strings.csv`.
- `SimConfig` [PARAM]s: `respawn_speed_kmh`, `respawn_fade_s`, `respawn_clear_ahead_m`, `respawn_clear_behind_m`, `respawn_search_step_m`, `respawn_search_range_m`.
- AI–AI collisions are already despawned silently by `Spawner`; a session-level test proves nothing is charged to the player.
- AGENTS.md status and routing rows.

## Non-goals

- Pause and auto-pause on focus loss (E08-S03).
- Learn-only live score and blind-spot icons (E08-S04), hints (E09).
- Wiring the session record into the end of the session.

## Implementation Plan

### Phase 1 — Respawn in the simulation core
1. `TrafficSim.place_vehicle`, `Respawn` and the `SimConfig` params. *Tests:* the chosen position is free ahead and behind; nearest free gap wins; blockers despawned when no gap is free; the player's lane change, signal and off-road are cleared.
2. `ScoringSystem.restart_after_respawn`. *Tests:* open segments closed; an overtake interrupted by a respawn does not make a later right change count as a return.

### Phase 2 — Session and HUD
1. `SessionManager` scoring wiring and the `RESPAWNING` state. *Tests:* learn collision and off-road charge K4 and respawn on the right lane at the respawn speed; the timer is neither reset nor paused; exam still ends; AI–AI collision despawns both, nothing charged.
2. HUD fade and message, strings, main scene scoring config. *Tests:* message and fade shown while respawning and hidden after; translations.

### Phase 3 — Docs
1. AGENTS.md status and routing rows.

## Risks

- Seed + `InputLog` replays the sim alone; a respawn is a session-level move, so a sim-only replay diverges after one (a session-level replay with the same commands still reproduces it).

## Progress

PR: #60

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Respawn in the simulation core

- [x] 1.1 TrafficSim.place_vehicle, Respawn and SimConfig params — fd69785
- [x] 1.2 ScoringSystem.restart_after_respawn — 34c6b24

### Phase 2: Session and HUD

- [x] 2.1 SessionManager scoring wiring and RESPAWNING state — f005470
- [x] 2.2 HUD fade and message, strings, main scene scoring config — 22e7358

### Phase 3: Docs

- [x] 3.1 AGENTS.md status and routing rows — efdae08
