# Execution plan — history screen, bests, trend and the summary comparison (E10-S02)

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Issue: #41

## Goal

Saved results show the player their progress (requirements §11.3, §13; spec Phase 9 step 2, UI/UX "History" and "Summary"): a history screen with the recent sessions, the best per mode × profile × level and a simple score trend, with its empty, storage-unavailable and data-is-local states; and the end-of-session summary compares the result with the previous one and the best for the same combination.

## Scope

- `HistoryStore` read queries: recent sessions newest first, the bests per combination in a stable order, the previous session of a combination, the scores for the trend. Counts shown on the screen are [PARAM]s in `PersistenceConfig` / `config/persistence.tres`.
- `core/feedback/ResultComparison`: from the finished `SessionRecord` and the previous / best results of its combination (read **before** the record is saved) it picks translation keys with arguments — previous score and the change, the best and whether this one beats it, or that it is the first result of the combination. Pure core, no persistence dependency (it takes plain dictionaries).
- End screen: `main.gd` reads previous / best from `SaveManager.store`, saves, and the HUD shows the comparison under the summary.
- `ui/HistoryScreen` (+ `ScoreTrendChart`): title, the local-data notice (always), storage-unavailable / read-only / recovered-corrupt notices, the empty state ("Brak zapisanych przejazdów…"), the recent list (date, mode, profile, level, status, score), the bests per combination, and the trend chart of the latest scores with its min / max labelled in text. `ui/history_screen.tscn` reads `SaveManager.store`.
- Dev launcher `screen=history` (URL param / user arg) opens the history screen instead of a session until the Phase 10 menus exist.
- Polish strings (gender-neutral) for the screen, the comparison, modes, road profiles and levels.
- AGENTS.md status and routing; README dev-launcher params.

## Non-goals

- Start-screen navigation to history (E11-S01), "again" / menu buttons, settings.
- Changing the save format, the best rule (completed sessions only) or the cap.

## Implementation Plan

### Phase 1 — Queries and comparison
1. `HistoryStore.recent`, `bests`, `previous_for`, `trend_scores`; `PersistenceConfig.history_recent_count` / `history_trend_count`. *Tests:* order, counts, combination filtering, a best only from completed sessions, empty history.
2. `ResultComparison` with its Polish strings. *Tests:* first result; better / worse / equal than previous; new best; below best; aborted session never claims a best; previous of another combination ignored.

### Phase 2 — Screens
1. Comparison on the end-of-session summary (`main.gd` + `Hud`). *Tests:* the HUD shows the comparison lines; main reads previous / best before saving.
2. `HistoryScreen` + `ScoreTrendChart` + `ui/history_screen.tscn`. *Tests:* lists recent, bests and trend; empty state; storage-unavailable state; local-data notice always shown; read-only notice.
3. Dev launcher `screen=history` opens the history screen. *Tests:* param parsing and fallback; main does not start a session and requests the history scene.

### Phase 3 — Docs
1. AGENTS.md status and routing, README dev-launcher params.

## Risks

- "Survives a page reload on the web build" is a manual check (spec Phase 9 step 2): recorded in the PR.
- The trend chart is drawn with `_draw` placeholder styling until the Phase 10 theme.

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Queries and comparison

- [x] 1.1 HistoryStore queries for recent, bests, previous and trend — 35f147b
- [x] 1.2 ResultComparison with its Polish strings — 5fa5f85

### Phase 2: Screens

- [ ] 2.1 Comparison on the end-of-session summary
- [ ] 2.2 History screen with list, bests, trend and its states
- [ ] 2.3 Dev launcher screen=history opens the history screen

### Phase 3: Docs

- [ ] 3.1 AGENTS.md status and routing, README params
