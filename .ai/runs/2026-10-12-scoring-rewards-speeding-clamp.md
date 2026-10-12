# Execution plan — Scoring rewards N1–N3, speeding S1, the K4 hook and the total clamp (E07-S02)

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Issue: #29

## Goal

Every penalty gets its mirrored reward, and the score is complete (spec Phase 6 step 3). The rules are:

- **N1:** a correct lane change is rewarded. It must be justified, signalled, safe and outside the cooldown.
- **N2:** driving in the right lane earns points continuously.
- **N3:** keeping a legal gap earns points continuously, reduced on an empty road (Q8).
- **S1:** speeding above the limit plus a tolerance costs points (Q4), behind a config toggle.
- **K4:** collisions and leaving the road are logged in category `collision`.
- **Total:** the session total is clamped at 0, while category sub-scores stay unclamped (Q6).

Scoring stays a pure observer of `TrafficSim`.

## Scope

- **`ScoringConfig` / `scoring.tres`:** N1 reward, cooldown, overtake-reason range, slow-vehicle margin and target-lane clearances; N2 and N3 rates; N3 range and `n3_empty_road_factor`; `speed_rule_enabled`, `speed_tolerance_kmh`, S1 rate; K4 penalty; `score_floor`.
- **`LaneChangeRule` (N1):**
  - A lane change is evaluated when it starts: signal OK via `LaneQuery.signal_valid`, target lane free via `LaneQuery.is_lane_free`, cooldown elapsed, and justified.
    - A left change is justified when there is a slower vehicle ahead in the origin lane within range.
    - A right change is justified only when it returns from a justified left change and the right lane is free, using the K2 definition. This is the anti-farming rule: an aimless left-and-back earns nothing.
  - The reward is granted when the change completes on the road.
- **`RightLaneRule` (N2):** a continuous reward on the rightmost lane, except when a slower vehicle ahead makes overtaking the right call.
- **`GapKeptRule` (N3):** a continuous reward while the gap is at least the legal minimum, with a leader within range. With no leader in range, the reward is multiplied by the empty-road factor. The two cases are separate segment types.
- **`SpeedRule` (S1):** continuous, category `speed`, off when `speed_rule_enabled` is false.
- **`CollisionRule` (K4):** the sim's `collision` (player involved) and `offroad` (player) signals produce instant events in category `collision`.
- **`ScoringSystem.total_score()`:** clamped at `score_floor`; `category_score()` unclamped.
- gdUnit4 tests that mirror every acceptance criterion of #29 and the §16 reward criteria; existing scoring tests adapted where they asserted an empty log.

## Non-goals

- `SessionRecordBuilder`, the ideal-driver bot and `exam_pass_score` (E07-S03, #30).
- Mode-specific collision handling: exam abort and learn respawn (E08). K4 here only logs the event.
- Wiring scoring into the session or HUD (E08/E09). Passing on the right (Q5).

## Implementation Plan

### Phase 1 — Continuous rewards
1. Config fields; N2 `RightLaneRule` and N3 `GapKeptRule`. *Tests:* right-lane driving with a legal gap raises the score steadily; an empty road gives N3 × 0.5; no N3 below the minimum gap; no N2 off the rightmost lane or behind a slow vehicle.

### Phase 2 — Lane-change reward
1. N1 `LaneChangeRule` with justification, safety, cooldown and anti-farming. *Tests:* a signalled overtake and a signalled return are each rewarded once on completion; no reward for a late signal, an unsafe target lane, inside the cooldown, or an aimless change; repeated pointless changes over 90 s do not raise the total and earn no N1.

### Phase 3 — Speeding, collisions, total
1. S1 `SpeedRule`, K4 `CollisionRule`, clamped `total_score`; AGENTS.md status. *Tests:* S1 above limit + tolerance only when enabled; a collision and an off-road each log K4 in `collision`; penalties beyond rewards clamp the total at 0 while categories stay negative.

## Risks

- **Weights are first guesses.** Every one is a [PARAM] in `scoring.tres`, and the tests assert ordering and criteria rather than absolute balance (spec Risks). Values are retuned in E12.
- **"Justified" judgement.** A left change counts as justified for a slower vehicle ahead within range. A right change is justified only after a justified left change. Both thresholds are [PARAM]s.

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Continuous rewards

- [ ] 1.1 Reward config, N2 right-lane and N3 gap-kept rules

### Phase 2: Lane-change reward

- [ ] 2.1 N1 lane-change rule with anti-farming

### Phase 3: Speeding, collisions, total

- [ ] 3.1 S1 speeding, K4 collision hook, clamped total, docs
