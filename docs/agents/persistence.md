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
- `user://settings.cfg` (`SettingsStore`, a `ConfigFile`, loaded by `SaveManager`) holds the quality, the mirrors and whether the tutorial was seen.
- `settings.cfg` (`PersistenceConfig.settings_path`) is read and written only through `SettingsStore` (`SaveManager.settings`).
- A missing or unknown value in it takes the `DevLauncherConfig` default (the tutorial: not seen).
- Each change writes only its own keys over what the file holds; keys it does not know survive.
- `SettingsStore` never writes over a file it cannot parse.
- A save that will not last (failed write, unreadable file, or `user://` not persistent) keeps the choice for the run, and the settings screen says why.
- Key bindings are never stored.
- Tests swap `SaveManager.settings` for a `user://test_*` store, never the real settings.

## History screen
- It only reads `HistoryStore` (`recent`, `bests`, `previous_for`, `trend_scores`; counts `history_recent_count` / `history_trend_count`).
- It always shows the data-is-local notice.
- It shows the storage-unavailable state instead of the empty one when storage is off.
