# Execution plan — lane queries, collisions and replay (E02-S02)

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Issue: #5
Stacked on: #16 (E02-S01, branch `feat/sim-vehicle-lane-change`)

## Goal

Give AI, scoring and hints one shared definition of free lanes, gaps and signal validity (`LaneQuery`), detect collisions in `(s, lateral)` space, and make sessions reproducible from a seed plus an `InputLog` — spec Phase 2, steps 3–4.

## Scope

- `core/sim/lane_query.gd` (`LaneQuery`): static, pure `min_gap`, `is_lane_free`, `gap_to_leader`, `is_overtaking`, `signal_valid` (requirements §8.4). Look-ahead/behind windows are arguments; the callers (AI, scoring) own those [PARAM]s.
- `VehicleState` gains `length_m` / `width_m` (spec *Coordinates*); `s` is defined as the vehicle's centre. Defaults come from `SimConfig` (`vehicle_length_m`, `vehicle_width_m`), plus `signal_min_on_s` (requirements §6.5, default 1.0 s).
- `TrafficSim`: axis-aligned box collision check after each step with a `collision(vehicle_id, other_id)` signal (once per contact); a seeded `RandomNumberGenerator` owned by the sim; an `InputLog` recording the player's `PlayerCommands` per step; `snapshot()` for state comparison.
- `core/sim/input_log.gd` (`InputLog`).
- gdUnit4 tests for every acceptance criterion of #5, including a scan proving `core/` has no scene/node/rendering references.

## Non-goals

- AI decisions, spawner, scoring rules, hints, rendering, session handling.
- A `ScoringConfig` resource (Phase 6); the signal minimum lives in `SimConfig` until then.

## Implementation Plan

### Phase 1 — LaneQuery
1. Vehicle dimensions and signal minimum in `SimConfig`; `LaneQuery` with table-driven tests (min gap at 140 km/h = 70 m, free lane / gap cases, overtaking, every `signal_valid` outcome).

### Phase 2 — Collisions, RNG and replay
1. Box collision detection in `TrafficSim` (incl. mid-lane-change), seeded RNG, `InputLog`, `snapshot()`. *Tests:* overlap/no-overlap incl. mid-lane-change, one signal per contact, same seed + same input log → identical final state, `core/` purity scan.

## Risks

- Stacked on unmerged #16: if #16 changes in review, this branch is rebased onto it; once #16 merges, the PR base retargets to `main`.
- O(n²) pair check: fine for the planned vehicle counts (tens); revisit if the spawner raises them.

## Progress

PR: #17

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: LaneQuery

- [x] 1.1 Vehicle dimensions, signal minimum and LaneQuery — 253e49e

### Phase 2: Collisions, RNG and replay

- [x] 2.1 Collision detection, seeded RNG, InputLog and snapshot — 688e5ee
