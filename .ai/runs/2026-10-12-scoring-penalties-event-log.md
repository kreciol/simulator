# Execution plan — Scoring penalties K1–K3 and the session event log (E07-S01)

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Issue: #28

## Goal

The three core motorway habits are judged: following too closely (K1), staying in a left lane while the right one is free (K2) and changing lanes without a valid signal (K3) cost points exactly as requirements §8.2 says. Every scored event lands in a session `EventLog`; continuous rules are stored as segments. This is spec Phase 6, steps 1–2. Scoring is headless: it observes `TrafficSim` and never mutates it.

## Scope

- `ScoringConfig` resource (`config/scoring_config.gd`) and `config/scoring.tres` with the K1–K3 weights and windows: K1 base and exponent (Q7: `EXP = 2`), K2 grace and rate, the K2 return window, the overtaking look-ahead, K3 penalty and late factor. N1–N3/S1 fields join in E07-S02.
- `ScoreEvent` (requirements §8.6 shape, plus `segment_end_s` and `extreme` per the spec Data Model) and `EventLog`. The log holds instant events and continuous segments, keeping start, end, point sum and extreme value. It also gives totals overall and per category.
- `ScoringSystem` (`core/scoring/`): `observe(sim, dt)` runs after each `TrafficSim.step` and returns the events completed in that step. The rules are small objects:
  - `GapRule` (K1): `penalty_per_s = K1_BASE * (1 - gap/min_gap)^EXP`, not charged while `LaneQuery.is_overtaking`.
  - `KeepRightRule` (K2): applies on a non-rightmost lane when the lane to the right is free per `LaneQuery.is_lane_free`. The look-ahead window comes from the closing speed on the slower right-lane leader (requirements §8.4). There is a grace period, then a continuous penalty. It does not apply while overtaking or while returning right. The segment includes the grace time, because `time_left_lane_unjustified_s` sums it.
  - `SignalRule` (K3): the signal is rated with `LaneQuery.signal_valid` when a player lane change starts. NONE costs the full penalty, LATE half, WRONG full; OK costs nothing.
- gdUnit4 tests that mirror every acceptance criterion of #28 and the §16 scoring criteria for K1–K3.

## Non-goals

- N1–N3 rewards, S1 speeding, the K4 hook, the total clamp at 0 (E07-S02, #29).
- `SessionRecordBuilder` and `exam_pass_score` (E07-S03, #30).
- Wiring scoring into `SessionManager`, the HUD or hints (E08/E09).
- Passing on the right (Q5, not in MVP).

## Implementation Plan

### Phase 1 — Event log and scoring config
1. `ScoringConfig` + `scoring.tres`, `ScoreEvent`, `EventLog` with segment aggregation and totals. *Tests:* segments open, extend and close with the correct sum and extreme; instant events; totals by category; config loads with every value defined.

### Phase 2 — Penalty rules
1. `ScoringSystem` and K1 `GapRule`. *Tests:* at 140 km/h a 50 m gap is penalised and 75 m is not; 20 m costs more than 50 m; no K1 while overtaking; no leader means no K1.
2. K2 `KeepRightRule`. *Tests:* no penalty inside the grace period, a per-second penalty after it; the segment spans the grace period; no K2 while overtaking or returning right; no K2 when the right lane is occupied.
3. K3 `SignalRule`, plus scoring as a pure observer. *Tests:* NONE / LATE / WRONG cost full / half / full once per lane change, and OK costs nothing; a sim with scoring attached ends in the same state as one without it; AGENTS.md routing/status.

## Risks

- **K2 "free right lane" window.** It is a judgement call (requirements §8.4 gives only a shape). Every window value is a [PARAM] in `scoring.tres`, so it can be retuned in E12 without code changes.
- **K3 timing.** K3 reads the signal through `TrafficSim.lane_change_started`, emitted while the step applies commands, so the signal age is measured at the moment the change starts. A signal switched on in the same step as the request is LATE, which matches §6.5.

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Event log and scoring config

- [ ] 1.1 ScoringConfig, ScoreEvent and EventLog with segments

### Phase 2: Penalty rules

- [ ] 2.1 ScoringSystem and K1 gap rule
- [ ] 2.2 K2 keep-right rule with grace period
- [ ] 2.3 K3 signal rule, observer-only check, docs
