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
- `settings.cfg` (`ConfigFile`, `PersistenceConfig.settings_path`) is read and written only through `SettingsStore` (`SaveManager.settings`).
- `SettingsStore` keeps keys it does not know when it writes, and never writes over a file it cannot parse.
- Tests swap `SaveManager.settings` for a `user://test_*` store, never the real settings.

## History screen
- It only reads `HistoryStore` (`recent`, `bests`, `previous_for`, `trend_scores`; counts `history_recent_count` / `history_trend_count`).
- It always shows the data-is-local notice.
- It shows the storage-unavailable state instead of the empty one when storage is off.
