# Execution plan — learn-mode hints (issue #37)

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Issue: #37 (E09-S01)

## Goal

In learn mode, short Polish hints warn before a penalty and explain events with live numbers, rate-limited per type and capped on screen; the exam shows none (requirements §11.2, spec Phase 8 step 1).

## Scope

- `core/feedback/`: `Hint` (one on-screen message: type, `FeedbackLine`, tone, times) and `HintEngine` — pure, reads the sim and the `ScoringSystem` after each step and the events it returned, never mutates either.
  - Preventive: K2 grace running → "Prawy pas jest wolny, wróć na prawo"; gap closing in on the legal minimum; gap below the minimum with the numbers ("Przy 120 km/h minimum to 60 m, masz 35 m"); speeding above the S1 threshold with the limit.
  - Event: when a player lane change completes, confirm a correct signal or name the missing / late / wrong one (from the K3 event of that change).
  - Rate limit: the same type no more often than `hint_cooldown_s`; at most `hint_max_on_screen` (default 2) shown, the oldest giving way; each shown for `hint_duration_s`.
- `FeedbackConfig` + `config/feedback.tres`: the hint [PARAM]s.
- `SessionManager`: builds a `HintEngine` in learn mode only (with scoring and feedback configs), feeds it after every scored step, clears it on a respawn.
- `ui/`: a hint list in the HUD — icon (`SummaryIcon`: tick for a confirmation, triangle for a warning) + text, under the rear-view mirror; shown only while driving in learn mode.
- `i18n/strings.csv`: gender-neutral hint strings (Q3).

## Non-goals

- Exam hints (none by design), audio (Q15), summary changes (Phase 8 step 2 shipped), tutorial prompts (Phase 10).
- No change to scoring rules or their numbers.

## Risks

- Hint wording and thresholds are first guesses; all thresholds live in `feedback.tres` for Phase 11 tuning.
- Review (independent pass) found that a new hint could push out one shown in the same step; fixed with `hint_min_display_s` and a priority order (4c3c9b5, 5335437). Desktop capture found a wrapped unit in the gap hint; fixed in 8f3a325.

## Implementation Plan

### Phase 1: Core hint engine

1. Hint tunables in `FeedbackConfig` / `feedback.tres`.
2. `Hint` and `HintEngine`: preventive hints, lane-change signal messages, cooldown and on-screen cap; Polish strings.
3. Unit tests: message per event, numbers in the gap hint, K2 hint before any penalty, cooldown per type, max on screen, strings translated and gender-neutral.

### Phase 2: Session and HUD

1. `SessionManager` runs the engine in learn mode only, cleared on respawn.
2. HUD hint list with icon + text, hidden in the exam, while paused, respawning and at the end.
3. Session, HUD and docs (AGENTS.md) updates with tests.

## Progress

PR: #65

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Core hint engine

- [x] 1.1 Hint tunables in `FeedbackConfig` / `feedback.tres` — a77d8ab
- [x] 1.2 `Hint` and `HintEngine` with Polish strings — bd936b8
- [x] 1.3 Hint engine unit tests — 06ec763

### Phase 2: Session and HUD

- [x] 2.1 `SessionManager` runs the engine in learn mode only — be99924
- [x] 2.2 HUD hint list with icon + text — 57968f4
- [x] 2.3 Session, HUD and docs updates with tests — 0e5154c
