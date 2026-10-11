# Execution plan — Traffic density by level, safe spawning, teachable moments (E04-S02)

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Issue: #12

## Goal

Traffic around the player follows the chosen difficulty level: the spawner keeps each level's density inside a window around the player and places vehicles only outside the player's view and only where the lane is safely free. It skips a spawn rather than force one, despawns vehicles that leave the window, and reuses pooled vehicles. Every session gets at least `min_overtake_opportunities` slow vehicles ahead in the right lane. Higher levels widen the AI speed spread and lower AI discipline. Spec Phase 4 step 3. The step also delivers the deferred #20 review finding: neighbour lookups scan every vehicle (O(n²) per step), which measured 38.8 ms per step with 80 AI cars.

## Scope

- `LaneIndex` (core/sim): per-lane lists of the vehicles occupying each lane, kept sorted by `s` and maintained by `TrafficSim`. Membership changes only on events (add/remove, lane change start/finish); the lists are re-sorted with an in-place insertion sort each step, so a steady step allocates nothing.
- `LaneQuery` neighbour functions (`is_lane_free`, `gap_to_leader`, `leader_in_lane`, `follower_in_lane`, `is_overtaking`) take the `LaneIndex` instead of a raw vehicle array. They do a binary search and a bounded local scan, with semantics unchanged. AI and the future scoring code keep sharing these exact functions.
- `TrafficSim`: collision detection over lane neighbours instead of all pairs; vehicle pooling (`remove_vehicle`, reuse on add); vehicle kinds (car/truck, with truck body size from `SimConfig`); `vehicle_added` / `vehicle_removed` signals for the coming views (#13); an optional `spawner` stepped at the end of `step`, so seed + input log still replays.
- `DifficultyLevel` resource plus `config/difficulty_levels/level_1..4.tres`: density, truck share, AI speed spread, discipline range, `recommended`.
- `Spawner` (core/sim): `populate()` fills the window at session start (outside the player clearance). `update()` tops up to the target count only inside the hidden zones beyond view, after a safety check: `LaneQuery.is_lane_free` with a margin, legal gaps, and IDM braking limits for the new vehicle and its follower. It also despawns beyond the window and removes AI–AI colliders (spec edge case). Teachable-moment guarantee: if not enough slow vehicles have appeared ahead in the right lane by each due time, a truck is spawned there.
- `SimConfig` [PARAM]s: spawn window, hidden zones, clearances, spawn interval, truck size and speeds, car speed offset, the teachable-moment params, and the AI lane-decision interval if needed for performance.
- gdUnit4 tests for every acceptance criterion of #12, plus `LaneIndex` and regression tests.

## Non-goals

- Vehicle views, brake lights and indicators, view pooling, wiring traffic into `game/main.tscn` (E04-S03, #13). Spawned traffic stays headless until views exist.
- `exam_pass_score` on `DifficultyLevel`: its values are measured in Phase 6 (Q9), so the field lands with Phase 6.
- Level selection UI and unlocking (Q14, Phase 10); the dev launcher's `level` param (Phase 3 step 4).

## Implementation Plan

### Phase 1 — Lane index and pooled vehicles
1. `LaneIndex` and `LaneQuery` over sorted per-lane lists; `TrafficSim` maintains it and detects collisions among lane neighbours; existing tests migrate to the new signatures. *Tests:* `LaneIndex` ordering and membership through lane changes; all existing `LaneQuery` cases; per-step cost with 80 AI cars.
2. Vehicle pooling, kinds (car/truck) and add/remove signals. *Tests:* a removed vehicle is reused with fresh state and a new id; truck size comes from config; removal clears it from lane lists.

### Phase 2 — Difficulty levels and spawner
1. `DifficultyLevel` + four `.tres`, spawner `SimConfig` params. *Tests:* levels 1–4 load, density increases, speed spread widens and discipline drops with the level; hidden-ahead distance ≥ `ViewConfig.draw_distance_m()`.
2. `Spawner`: populate, top-up in hidden zones, safe placement, skip when no slot, despawn, AI–AI collision removal, pooling. *Tests:* density ±20% after 30 s warm-up per level; no spawn within the player clearance or in view; dense level with no safe slot skips; despawn beyond window reuses pooled vehicles; spawned speed/discipline distributions follow the level.
3. Teachable-moment guarantee. *Tests:* every level × profile session of 90 s gets ≥ `min_overtake_opportunities` slow vehicles ahead in the right lane.
4. Long seeded run per level × profile (10 min each, suite ≤ 60 s CI wall time); docs (AGENTS.md routing/status). *Tests:* zero AI–AI collisions, no off-road AI.

## Risks

- CI wall time: 8 × 10 min at 60 Hz is 288k steps. The sim step must average about 100 µs, so the lane index is required. If it is not enough, a staggered AI lane-decision interval ([PARAM]) cuts the cost of MOBIL evaluation.
- Density at level 4 is bounded by legal gaps (about 15 vehicles/km/lane at 120 km/h for disciplined drivers), so densities are chosen below that. Spawns into a saturated lane are skipped, which keeps the ±20% band reachable.
- The `LaneQuery` signature change touches every caller. Today those are only the AI and tests; scoring (Phase 6) will be built on the new form.

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Lane index and pooled vehicles

- [ ] 1.1 LaneIndex and LaneQuery over sorted lane lists
- [ ] 1.2 Vehicle pooling, kinds and add/remove signals

### Phase 2: Difficulty levels and spawner

- [ ] 2.1 DifficultyLevel resources and spawner params
- [ ] 2.2 Spawner with safe placement, despawn and pooling
- [ ] 2.3 Teachable-moment guarantee
- [ ] 2.4 Long seeded run per level and profile, docs
