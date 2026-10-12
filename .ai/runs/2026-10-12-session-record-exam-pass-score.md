# Execution plan — Session record and per-level exam pass marks (E07-S03)

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Issue: #30

## Goal

Every session ends with one record of its score, category sub-scores and stats, and each difficulty level carries an exam pass mark (spec Phase 6 step 4, Q9).

## Scope

- **`SessionRecord`** (`core/scoring/`): the §13 record plus the spec's additions (`seed`, `exam_passed`, `score_by_category.speed`, `app_version`), with `to_dict()` producing the §13 JSON shape and `schema_version` 1.
- **`SessionRecordBuilder`** (`core/scoring/`, pure): takes the session state (mode, road profile id, level id, seed, duration, status, exam pass score, identity fields) and an `EventLog`, and returns a `SessionRecord`.
  - `score_total`: the sum of all points, never below `ScoringConfig.score_floor` (Q6).
  - `score_by_category`: gap, lane, signal and speed, unclamped.
  - `stats`:
    - `lane_changes`: number of K3-rated changes (one per player lane change).
    - `lane_changes_signaled`: number of changes signalled correctly (`signal_ok`).
    - `time_left_lane_unjustified_s`: the sum of K2 segment durations, grace included.
    - `time_gap_below_min_s`: the sum of K1 segment durations.
    - `min_gap_ratio`: the lowest K1 extreme, or 1.0 when there are none.
  - `exam_passed`: null in learn mode. In an exam it is true only when the status is `completed`, the log holds no collision or off-road event, and `score_total` is at least `exam_pass_score`.
- **`DifficultyLevel.exam_pass_score`:** a [PARAM] in each `level_N.tres`.
- **`IdealDriverBot`** (`core/ai/`): drives the player by the book through `PlayerCommands`.
  - It holds the limit and keeps a gap above the legal minimum.
  - It overtakes a slower vehicle with a signal held for `signal_min_on_s`, and returns right once the right lane is free.
  - It reuses `LaneQuery`, `ScoringSystem.overtake_justified` and `KeepRightRule.right_lane_free`.
- **`ExamCalibration`** (`core/scoring/`): runs one seeded 90 s bot session per level, with the spawner and scoring attached, and returns the score. A headless tool script prints 60% of each level's score; those values are written into the `.tres` files.
- gdUnit4 tests that mirror every acceptance criterion of #30.

## Non-goals

- Saving the record and generating `id`, `started_at` or `app_version` (E10, `SaveManager`). The builder takes them as given.
- Wiring the builder into `SessionManager`, exam abort and learn respawn (E08 / Phase 7).
- Retuning weights or pass marks (E12).

## Implementation Plan

### Phase 1 — Session record
1. `SessionRecord`, `SessionRecordBuilder`, and `DifficultyLevel.exam_pass_score`. *Tests:* a recorded event log gives the expected totals, categories and stats. An exam with a collision or off-road is not passed regardless of score. A learn session has `exam_passed` null. The total is clamped while categories stay negative. `to_dict` has the §13 keys.

### Phase 2 — Ideal-driver bot and pass marks
1. `IdealDriverBot` and `ExamCalibration`. *Tests:* the same seed gives the same score twice. The bot drives a whole session without collision, K1, K3 or speeding, and overtakes.
2. Calibration tool script; `exam_pass_score` written to `level_1..4.tres`; AGENTS.md status. *Tests:* each level's `exam_pass_score` is 60% of the bot's measured score.

## Risks

- **Bot scores move whenever weights, traffic or AI change.** The 60% check would then fail, which is intended: it forces the pass marks to be re-measured with the tool, as E12 retuning requires.
- **Calibration runtime.** Four headless 90 s sessions run inside the test suite. That takes a few seconds, the same scale as the existing traffic session tests.

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Session record

- [ ] 1.1 SessionRecord, SessionRecordBuilder and exam_pass_score field

### Phase 2: Ideal-driver bot and pass marks

- [ ] 2.1 IdealDriverBot and ExamCalibration
- [ ] 2.2 Calibration tool and per-level exam_pass_score values
