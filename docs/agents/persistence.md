# Persistence and history

**Read first:** requirements §13; spec *Data Model: Persisted*, *Edge Cases*; `persistence/` (`save_manager.gd` = the `SaveManager` autoload), `PersistenceConfig` + `config/persistence.tres`; the history screen in `ui/history_screen.gd`.

## Save file
- `user://` (IndexedDB on web).
- File shape `{ schema_version, sessions, best }`, capped at `history_limit`.
- Every saved record carries `schema_version`; changing the format bumps it and adds a step to `HistoryStore._migrate`.
- Never overwrite a file it cannot read: corrupt → moved to `history.corrupt-<ts>.json`; newer `schema_version` → read-only.
- Saving must never block play — when storage is unavailable it is disabled and the UI explains why.
- Tests use their own `user://test_*` paths, never the real history.

## Settings file
- `user://settings.cfg` (`SettingsStore`, a `ConfigFile`, loaded by `SaveManager`) holds the quality and mirrors.
- A missing or unknown value in it takes the `DevLauncherConfig` default.
- A save that will not last (failed write, or `user://` not persistent) keeps the choice for the run, and the settings screen says why.
- Key bindings are never stored.

## History screen
- It only reads `HistoryStore` (`recent`, `bests`, `previous_for`, `trend_scores`; counts `history_recent_count` / `history_trend_count`).
- It always shows the data-is-local notice.
- It shows the storage-unavailable state instead of the empty one when storage is off.
