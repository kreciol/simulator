# Execution plan — Session results saved in the browser (E10-S01)

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Issue: #40

## Goal

Every finished session is saved to `user://history.json` (IndexedDB on web) and survives a page reload, with a capped history, bests per mode × profile × level, and safe handling of corrupt, future-version and unavailable storage (spec Phase 9 step 1).

## Scope

- **`PersistenceConfig`** (`config/`) + `config/persistence.tres`: `history_limit` [PARAM] 200, the history file path.
- **`SessionRecord.from_dict`**: reads a §13 dictionary back (JSON numbers come back as floats), so a saved record round-trips.
- **`HistoryStore`** (`persistence/`): the `history.json` file — shape `{ "schema_version": 1, "sessions": [...], "best": { "<mode>|<profile>|<level>": id } }`.
  - `load()`: missing file → empty history; unparsable or wrongly shaped → renamed to `history.corrupt-<ts>.json`, fresh history, `notice = CORRUPT_RECOVERED`; `schema_version` above 1 → sessions readable, `read_only`, never overwritten; older versions pass through a migration hook (none yet).
  - `save_record(record)`: appends, drops the oldest beyond the cap, updates the best of its combination when the score beats it (the best is recomputed if its session was dropped), writes the file.
  - Storage availability: `OS.is_userfs_persistent()` plus a write probe; unavailable → saving disabled, `save_record` refuses.
- **`SaveManager` autoload** (`persistence/save_manager.gd`): owns one `HistoryStore` on `PersistenceConfig`, loads at start-up, exposes save + state.
- **Session wiring**: `SessionManager` runs a `ScoringSystem` (observe after each sim step, finish at the end) when given a `ScoringConfig`, and builds the `SessionRecord` at the end (status from the end reason, exam pass mark from the level). `main.gd` hands the record to `SaveManager`; the end screen says whether it was saved, or why not (storage unavailable, read-only newer file, corrupt file recovered). Polish strings in `i18n/strings.csv`.
- gdUnit4 tests mirroring every automatable acceptance criterion of #40.

## Non-goals

- History screen, bests list, trend chart, comparison on the summary (E10-S02).
- Summary screen and feedback text (E09-S02), exam abort / learn respawn (E08).
- Any migration beyond v1 (none exists yet).

## Decisions / defaults

- Bests count only `completed` sessions; ties keep the earlier best. `# TODO(open):` neither document says whether aborted sessions may set a best.
- The user is informed of a recovered corrupt file on the end-of-session screen (the only results screen until E09/E10-S02).

## Implementation Plan

### Phase 1 — History file
1. `PersistenceConfig`, `SessionRecord.from_dict`, `HistoryStore`. *Tests:* round-trip with `schema_version: 1`, cap drops the oldest, best updated / unchanged on a worse result, corrupt file renamed and fresh file started, future version read-only and never overwritten, storage unavailable disables saving.
2. `SaveManager` autoload registered in `project.godot`. *Tests:* the autoload exists and loads its config.

### Phase 2 — Saving finished sessions
1. `SessionManager` scoring + record at session end. *Tests:* a session that runs out of time ends with a completed record; a crash gives `aborted_collision`; exam verdict present in exam mode.
2. `main.gd` saves via `SaveManager`; end screen save status in Polish. *Tests:* HUD shows the saved / unavailable / read-only / corrupt messages.
3. AGENTS.md status and routing for persistence.

## Risks

- **Durable data contract.** The file format is what users keep; `schema_version` and the read-only rule for newer files guard it. A future change needs a migrator in `HistoryStore`.
- **Web persistence.** Godot syncs `user://` to IndexedDB on file close; the reload check is manual on the deployed build.

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: History file

- [x] 1.1 PersistenceConfig, SessionRecord.from_dict and HistoryStore — ffa6cd6
- [x] 1.2 SaveManager autoload — 3e6d887

### Phase 2: Saving finished sessions

- [x] 2.1 SessionManager scoring and record at session end — 1b4db2b
- [x] 2.2 Save on session end and end-screen save status — 4b22f39
- [x] 2.3 AGENTS.md status and routing — 8ad341c
