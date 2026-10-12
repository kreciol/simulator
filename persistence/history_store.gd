class_name HistoryStore
extends RefCounted
## The session history file (requirements §13, spec Data Model: Persisted):
## `{ "schema_version": 1, "sessions": [SessionRecord…], "best": { "<mode>|<profile>|<level>": session_id } }`,
## oldest session first, capped at `limit`. Owned by the `SaveManager` autoload.
##
## Edge cases (spec Edge Cases): a file that cannot be read as history is renamed to
## `history.corrupt-<ts>.json` and a fresh one started (`notice`); a file from a newer
## `schema_version` is read but never overwritten (`read_only`); when `user://` does not
## persist (IndexedDB blocked on web) or cannot be written, saving is disabled
## (`storage_available`) and play goes on.

const SCHEMA_VERSION: int = SessionRecord.SCHEMA_VERSION

## What the player should be told about the last `load_history`.
enum Notice { NONE, CORRUPT_RECOVERED }

var path: String
var limit: int
## Whether `user://` survives a restart; false on web when IndexedDB is unavailable.
## Tests set it before `load_history`.
var userfs_persistent: bool = OS.is_userfs_persistent()

## Saved sessions as their §13 dictionaries, oldest first.
var sessions: Array[Dictionary] = []
## Best completed session per mode × profile × level: combination key → session id.
var best: Dictionary[String, String] = {}
var storage_available: bool = false
## The file was written by a newer version: shown, never overwritten.
var read_only: bool = false
## `schema_version` of the file last loaded; `SCHEMA_VERSION` when there was none.
var file_version: int = SCHEMA_VERSION
var notice: Notice = Notice.NONE
## Where a corrupt file was moved to, when `notice` is CORRUPT_RECOVERED.
var corrupt_backup_path: String = ""


func _init(history_path: String, history_limit: int) -> void:
	path = history_path
	limit = history_limit


## Key of a mode × road profile × level combination in `best`.
static func combination_key(mode: StringName, road_profile: StringName, level: int) -> String:
	return "%s|%s|%d" % [mode, road_profile, level]


## Whether `save_record` can write: storage works and the file is not from a newer version.
func can_save() -> bool:
	return storage_available and not read_only


## Reads the history file, recovering from a corrupt one. A missing file is an empty history.
func load_history() -> void:
	sessions.clear()
	best.clear()
	read_only = false
	file_version = SCHEMA_VERSION
	notice = Notice.NONE
	corrupt_backup_path = ""
	storage_available = userfs_persistent and _probe_writable()
	if not FileAccess.file_exists(path):
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		# Present but unreadable: never risk overwriting it.
		storage_available = false
		return
	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var data: Variant = json.data if json.parse(text) == OK else null
	var version: int = _schema_version(data)
	if version < 1:
		_recover_corrupt()
		return
	file_version = version
	if version > SCHEMA_VERSION:
		# Unknown format: show what can be read, keep the file as it is.
		read_only = true
		_read_sessions((data as Dictionary).get("sessions"))
		return
	var history: Dictionary = _migrate(data as Dictionary, version)
	if not _is_valid(history):
		_recover_corrupt()
		return
	_read_sessions(history["sessions"])
	for key: Variant in (history["best"] as Dictionary):
		best[str(key)] = str((history["best"] as Dictionary)[key])
	_prune_best()


## Appends a finished session, drops the oldest beyond `limit`, updates the best of its
## combination and writes the file. False when saving is disabled or the write failed.
func save_record(record: SessionRecord) -> bool:
	if not can_save():
		return false
	var entry: Dictionary = record.to_dict()
	sessions.append(entry)
	while sessions.size() > limit:
		sessions.pop_front()
	_offer_best(entry)
	_prune_best()
	if not _write():
		storage_available = false
		return false
	return true


## The best session of a combination, or an empty dictionary when there is none.
func best_for(mode: StringName, road_profile: StringName, level: int) -> Dictionary:
	var id: String = best.get(combination_key(mode, road_profile, level), "")
	return _find(id)


## The last saved session, or an empty dictionary.
func last_session() -> Dictionary:
	return sessions.back() if not sessions.is_empty() else {}


## Brings an older file up to `SCHEMA_VERSION`. Version 1 is the first format, so there
## is nothing to migrate yet; a format change bumps the version and adds a step here.
func _migrate(data: Dictionary, _from_version: int) -> Dictionary:
	return data


## The file's `schema_version`, or 0 when it is not a history file at all.
func _schema_version(data: Variant) -> int:
	if not data is Dictionary:
		return 0
	var version: Variant = (data as Dictionary).get("schema_version")
	if not (version is float or version is int) or float(version) != floorf(float(version)):
		return 0
	return int(version)


func _is_valid(history: Dictionary) -> bool:
	if not history.get("sessions") is Array or not history.get("best") is Dictionary:
		return false
	for entry: Variant in (history["sessions"] as Array):
		if not entry is Dictionary:
			return false
	for id: Variant in (history["best"] as Dictionary).values():
		if not id is String:
			return false
	return true


func _read_sessions(entries: Variant) -> void:
	if not entries is Array:
		return
	for entry: Variant in (entries as Array):
		if entry is Dictionary:
			sessions.append(entry as Dictionary)


## Makes `entry` its combination's best when it beats the current one. Only completed
## sessions count, and a tie keeps the earlier best.
## TODO(open): neither the requirements nor the spec say whether an aborted session may set a best.
func _offer_best(entry: Dictionary) -> void:
	if not _counts_for_best(entry):
		return
	var key: String = _key_of(entry)
	var current: Dictionary = _find(best.get(key, ""))
	if current.is_empty() or float(entry["score_total"]) > float(current["score_total"]):
		best[key] = str(entry["id"])


## Re-picks a best whose session is no longer in the history (dropped by the cap, or
## missing from a hand-edited file) from the sessions that remain.
func _prune_best() -> void:
	for key: String in best.keys():
		if _find(best[key]).is_empty():
			best.erase(key)
	for entry: Dictionary in sessions:
		_offer_best(entry)


func _counts_for_best(entry: Dictionary) -> bool:
	return str(entry.get("status", "")) == String(SessionRecord.STATUS_COMPLETED) \
			and (entry.get("score_total") is float or entry.get("score_total") is int)


func _key_of(entry: Dictionary) -> String:
	return combination_key(StringName(str(entry.get("mode", ""))),
			StringName(str(entry.get("road_profile", ""))), int(entry.get("difficulty", 0)))


func _find(id: String) -> Dictionary:
	if id.is_empty():
		return {}
	for entry: Dictionary in sessions:
		if str(entry.get("id", "")) == id:
			return entry
	return {}


## Moves the unreadable file aside and starts a fresh history.
func _recover_corrupt() -> void:
	notice = Notice.CORRUPT_RECOVERED
	corrupt_backup_path = _corrupt_backup_path()
	if DirAccess.rename_absolute(path, corrupt_backup_path) != OK:
		# The file could not be moved aside: writing would destroy it.
		corrupt_backup_path = ""
		read_only = true
		return
	if storage_available and not _write():
		storage_available = false


## `history.corrupt-<ts>.json` next to the history file, unique within the directory.
func _corrupt_backup_path() -> String:
	var stamp: String = Time.get_datetime_string_from_system(true).replace("-", "").replace(":", "")
	var stem: String = path.get_basename() + ".corrupt-" + stamp
	var extension: String = "." + path.get_extension() if not path.get_extension().is_empty() else ""
	var candidate: String = stem + extension
	var n: int = 1
	while FileAccess.file_exists(candidate):
		n += 1
		candidate = "%s-%d%s" % [stem, n, extension]
	return candidate


## Writes the whole history to a temporary file, then moves it over the old one, so an
## interrupted write never leaves a half-written history behind.
func _write() -> bool:
	var data: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"sessions": sessions,
		"best": best,
	}
	var temp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	var written: bool = file.store_string(JSON.stringify(data))
	file.close()
	if not written:
		DirAccess.remove_absolute(temp_path)
		return false
	return DirAccess.rename_absolute(temp_path, path) == OK


## Whether a file can be created next to the history file.
func _probe_writable() -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var probe_path: String = path + ".probe"
	var file: FileAccess = FileAccess.open(probe_path, FileAccess.WRITE)
	if file == null:
		return false
	file.close()
	DirAccess.remove_absolute(probe_path)
	return true
