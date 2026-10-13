# Feedback texts, live hints and session summary

**Read first:** requirements §11; `core/feedback/`, `FeedbackConfig` + `config/feedback.tres`, `ui/summary_panel.gd`, `ui/hint_list.gd`; strings in `i18n/strings.csv`.

- Rule/template based, no external API.
- Supportive tone; explain the rule ("why"), not just the error.
- Core picks translation keys with format arguments (`FeedbackLine`), never text; the UI translates (Polish first).
- Gender-neutral wording only (Q3) — a test lints every Polish string for gendered verb forms.
- Strength and areas to improve come from category penalties.
- Every description sentence is one template line, 2–4 per summary.
- The comparison with the previous and best result of the same mode × profile × level reads the history **before** the finished session is saved.
- Only a completed session can claim a new best (the `HistoryStore` rule).
- `HintEngine` exists in learn mode only (`SessionManager.hint_engine`, null in the exam).
- `HintEngine` reads the sim and `ScoringSystem` after each scored step (`observe(events)`) and never changes them.
- Hints check gaps, free lanes and overtaking through the scoring rules and `LaneQuery`, never re-implemented.
- Hint cooldown, on-screen cap, minimum display time and duration live in `feedback.tres` and run on sim time.
- A hint never replaces one that has not been up `hint_min_display_s`; a held-back hint keeps its cooldown.
- The lane-change message waits for room on screen rather than being dropped.
- Every hint pairs its text with an icon.
