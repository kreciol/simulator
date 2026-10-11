# Execution plan — AI car-following and keep-right lane changes (E04-S01)

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Issue: #11

## Goal

AI cars drive like disciplined motorway drivers: IDM car-following that keeps at least the legal gap (speed/2 m), and simplified MOBIL keep-right lane changes — signal ≥ 1.5 s, overtake on the left, return right — all through the shared `LaneQuery`. Spec Phase 4, steps 1–2.

## Scope

- `SimConfig` / `sim_config.tres`: IDM params (`a`, `b`, `T`, `s0`, exponent, max decel) and MOBIL params (politeness, threshold, safe decel, keep-right bias), AI signal lead time and lane-change clearance — every number a [PARAM] in the `.tres` (spec *Research* defaults).
- `LaneQuery`: `leader_in_lane` / `follower_in_lane`, so AI finds neighbours through the shared lane logic; `gap_to_leader` is re-expressed through `leader_in_lane` (same results).
- `core/ai/idm.gd` (`Idm`): pure IDM acceleration; legal-gap-aware `T_eff = lerp(T, max(T, legal_gap / v), discipline)`.
- `core/ai/ai_driver.gd` (`AiDriver`): per-vehicle desired speed, discipline, commanded acceleration; each step picks IDM acceleration (against both lanes during a change) and MOBIL keep-right lane decisions gated by `LaneQuery.is_lane_free`, signalling `ai_signal_lead_s` before changing.
- `TrafficSim`: `add_ai_vehicle(...)`; `step` lets AI drivers decide before integration; AI vehicles integrate their commanded acceleration. Player and plain vehicles unchanged.
- gdUnit4 tests for every acceptance criterion of #11.

## Non-goals

- Spawner, density, difficulty levels, discipline distributions (E04-S02, #12); vehicle views, brake lights (E04-S03, #13).
- Reacting to the player (yielding, cutting in) — requirements §7.1.
- Scoring rules (Phase 6); the scan only proves `core/ai` uses `LaneQuery` and does not redefine its functions.

## Implementation Plan

### Phase 1 — IDM car-following
1. IDM/MOBIL/AI params in `SimConfig` + `sim_config.tres`; `LaneQuery.leader_in_lane` / `follower_in_lane` with tests.
2. `Idm`, `AiDriver` longitudinal control and `TrafficSim.add_ai_vehicle` integration. *Tests:* free-road acceleration to `v0`; approach-and-follow settles at ≥ legal gap; no overlap with a stopped leader; lower discipline follows closer.

### Phase 2 — MOBIL keep-right
1. MOBIL keep-right lane decisions with signal lead and cancel, IDM against both lanes during a change. *Tests:* overtake-then-return with ≥ 1.5 s signals; no change into an unsafe gap (alongside and fast-approaching); undisciplined drivers lack the keep-right bias.
2. `core/ai` uses `LaneQuery` (scan test) and a seeded multi-car run with zero AI–AI collisions.

## Risks

- MOBIL tuning: the spec defaults may cause signal flicker or late returns; decisions use a hysteresis (start above threshold, keep while still beneficial) and the tests assert behaviour, not exact timings.
- Sequential per-vehicle decisions within a step: deterministic (vehicle order), and a started change immediately occupies the target lane for later vehicles' checks.
- Neighbour lookups are linear scans, about 10 per AI car per step (O(n²)): fine at test scale; at the spec's ~80 vehicles revisit with lane-sorted lookups or a decision interval when the spawner lands (#12) — review finding, deferred.
- No passing on the right is enforced only in the lane decision (moving right never gains speed over the left-lane leader); car-following on the right lane does not look left, so a car already on the right may still pass a slower left-lane car. Rare while AI keeps right; revisit with scoring (Q5) if it shows up.

## Progress

PR: #20

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: IDM car-following

- [x] 1.1 IDM/MOBIL params and LaneQuery neighbours — 654cc72
- [x] 1.2 Idm, AiDriver longitudinal control and sim integration — 33bb15b

### Phase 2: MOBIL keep-right

- [x] 2.1 MOBIL keep-right lane decisions with signalling — 42445df
- [x] 2.2 LaneQuery usage scan and seeded no-collision run — 19bfb20
