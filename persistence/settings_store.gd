class_name SettingsStore
extends RefCounted
## The player's settings in `user://settings.cfg`, a `ConfigFile` (spec Data Model:
## Persisted). For now only whether the tutorial was seen (issue #45); keys it does not
## know are kept when it writes. Like the history it never blocks play: when `user://`
## is not persistent, or the file exists but cannot be read, nothing is written and the
## settings last for the run only.

const SECTION: String = "settings"
const KEY_TUTORIAL_SEEN: String = "tutorial_seen"

var path: String
## Whether `user://` survives a restart; false on web when IndexedDB is unavailable.
var userfs_persistent: bool = OS.is_userfs_persistent()
## False when writing would lose what is there or would not last.
var can_save: bool = false
## The tutorial was finished or skipped once; the start screen stops suggesting it.
var tutorial_seen: bool = false

var _file: ConfigFile = ConfigFile.new()


func _init(settings_path: String) -> void:
	path = settings_path


## Reads the file; a missing one means the defaults. An unreadable one is left as it is.
func load_settings() -> void:
	_file = ConfigFile.new()
	can_save = userfs_persistent
	if FileAccess.file_exists(path):
		var error: Error = _file.load(path)
		if error != OK:
			push_warning("SettingsStore: cannot read %s (error %d); not writing to it." % [path, error])
			_file = ConfigFile.new()
			can_save = false
	tutorial_seen = bool(_file.get_value(SECTION, KEY_TUTORIAL_SEEN, false))


## Remembers that the tutorial was seen; false when it could not be saved (it still
## counts for this run).
func mark_tutorial_seen() -> bool:
	tutorial_seen = true
	_file.set_value(SECTION, KEY_TUTORIAL_SEEN, true)
	return _save()


func _save() -> bool:
	if not can_save:
		return false
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if _file.save(path) != OK:
		can_save = false
		return false
	return true
