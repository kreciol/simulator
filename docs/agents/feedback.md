# Feedback texts and session summary

**Read first:** requirements §11; `core/feedback/`, `FeedbackConfig` + `config/feedback.tres`, `ui/summary_panel.gd`; strings in `i18n/strings.csv`.

- Rule/template based, no external API.
- Supportive tone; explain the rule ("why"), not just the error.
- Core picks translation keys with format arguments (`FeedbackLine`), never text; the UI translates (Polish first).
- Gender-neutral wording only (Q3) — a test lints every Polish string for gendered verb forms.
- Strength and areas to improve come from category penalties.
- Every description sentence is one template line, 2–4 per summary.
- The comparison with the previous and best result of the same mode × profile × level reads the history **before** the finished session is saved.
- Only a completed session can claim a new best (the `HistoryStore` rule).
