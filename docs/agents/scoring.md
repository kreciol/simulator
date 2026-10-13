# Scoring, event log and session record

**Read first:** requirements §8, §13, §16 (Ocenianie); `core/scoring/` (rules in `core/scoring/rules/`), `core/ai/ideal_driver_bot.gd`, `ScoringConfig` + `config/scoring.tres`, `DifficultyLevel.exam_pass_score`.

- Scoring **observes** the simulation, never mutates it: `ScoringSystem.observe(dt)` runs after each `TrafficSim.step(dt)`.
- Rules read the sim and write only to the `EventLog`.
- Rules use `LaneQuery` for every gap / free-lane / overtaking / signal check.
- Every rule K1–K4 / N1–N3 has unit tests mirroring the acceptance criteria.
- Continuous events are aggregated into segments, not logged per frame.
- Rules hold the sim, config and log — never the `ScoringSystem` (no reference cycles).
- Changing weights, traffic or AI moves the bot's score: re-measure `exam_pass_score` (the calibration test prints the new values).
