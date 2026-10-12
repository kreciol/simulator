# Execution plan — session summary with score, categories, status, description and a tip (E09-S02)

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Issue: #38

## Goal

After every session, in both modes, the end screen shows how the drive went: the total, the four categories (gap, lane, signal, speed) each with an icon and text, the status (completed / aborted with cause / exam passed / exam failed), a 2–4 sentence supportive description naming one strength and one or two areas to improve, and one concrete tip (requirements §11.3, spec Phase 8 step 2, UI/UX "Summary").

## Scope

- `core/feedback/`: `SummaryGenerator.generate(log, record) -> Summary` (spec API Contracts). Pure core: it returns translation keys with format arguments (`FeedbackLine`), never translated text, so `core/` stays free of engine services; the UI translates.
  - Category penalty = sum of the negative points the category's events carry in the `EventLog`.
  - Strength: the category with the smallest penalty (ties: higher category score, then the fixed order gap, lane, signal, speed).
  - Areas to improve: categories other than the strength whose penalty reaches `FeedbackConfig.improve_penalty_threshold` [PARAM], largest first, at most two (§11.3).
  - Sentences: strength, then each area with its numbers from the record/log, plus one sentence explaining an aborted session; when nothing needs work, an "all rules kept" sentence. Always 2–4.
  - Tip: the habit for the top area; else for the abort cause; else a general next step.
  - Status: exam → passed / failed from `record.exam_passed` (Q9: a collision fails even above `exam_pass_score`); learn → completed / aborted, with the cause.
- `config/feedback_config.gd` + `config/feedback.tres` for the threshold.
- `SessionManager` wiring: given a `ScoringConfig` it runs `ScoringSystem.observe` after each driving step, finishes it at the end, builds the `SessionRecord` (`SessionRecordBuilder`) and, given a `FeedbackConfig`, the `Summary`. `main.tscn` sets both configs. Field names follow open PR #54 (`scoring_config`, `scoring`, `record`) to keep the merge small.
- UI: `SummaryPanel` (total, four category rows with a drawn icon + text, description, tip) inside the HUD's end screen, replacing the placeholder "Koniec sesji" notice; `SummaryIcon` draws a check (good) or a warning triangle (to improve) so meaning never relies on colour.
- Polish gender-neutral strings in `i18n/strings.csv` (Q3) and a lint test over every Polish string for gendered verb forms.
- AGENTS.md status and routing.

## Non-goals

- Comparison with the previous and best result (E10-S02), saving the record (E10-S01 / PR #54), session id / timestamps in the record.
- Live hints (Phase 8 step 1), learn-mode respawn (E08-S02), "again" / menu buttons (Phase 10).

## Implementation Plan

### Phase 1 — Summary generator
1. `FeedbackConfig`, `FeedbackLine`, `Summary`, `SummaryGenerator` with status, categories, strength / improvement selection, sentences and tip. *Tests:* recorded logs → expected strength and improvements; sentence count 2–4 across clean, poor, aborted and mixed sessions; tip choice; status for completed, both aborts, exam passed, exam failed, exam above the pass mark with a collision → failed.
2. Polish templates in `i18n/strings.csv`. *Tests:* every key the generator can emit is translated; no gendered verb form in any Polish string.

### Phase 2 — Session and screen
1. `SessionManager` scores the drive and builds the record and summary at the end; `main.tscn` passes the configs. *Tests:* a scored session ends with a record and summary; the exam collision case ends failed; no scoring config → no record.
2. `SummaryPanel` + `SummaryIcon` in the HUD end screen. *Tests:* panel shows total, four rows each with icon and text, description and tip; HUD shows it once the session ends; main scene shows the summary after a crash.

### Phase 3 — Docs
1. AGENTS.md status and routing.

## Risks

- Open PRs #54 (history) and #59 (learn HUD) also wire `ScoringSystem` into `SessionManager`; whichever lands later resolves a small conflict. Names follow #54.
- Template wording is a first draft for playtests (Phase 11).

## Progress

PR: #61

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Summary generator

- [x] 1.1 SummaryGenerator with status, categories, strength, improvements, sentences and tip — 4ebb18a
- [x] 1.2 Polish gender-neutral templates and the gendered-form lint test — c2ee029

### Phase 2: Session and screen

- [x] 2.1 SessionManager scores the drive and builds the record and summary — 47c426f
- [x] 2.2 Summary panel in the HUD end screen — 7b094a0, 7def209

### Phase 3: Docs

- [x] 3.1 AGENTS.md status and routing — 6cc8d3e
