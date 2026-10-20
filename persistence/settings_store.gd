class_name SettingsStore
extends RefCounted
## The player's settings file (requirements §9.4, spec Data Model: Persisted, issues #44,
## #45): the graphics quality, whether the mirrors are shown and whether the tutorial was
## seen, in `user://settings.cfg` (a `ConfigFile`). Owned by the `SaveManager` autoload
## and read by the start screen and the new-session setup. A missing file, or a missing
## or unknown value in it, takes the launcher's default (the tutorial: not seen). Each
## change writes only its own keys over what the file already holds, so the graphics and
## the tutorial never erase each other, and keys it does not know survive. Saving never
## blocks play: a failed write — or `user://` that does not survive a restart (IndexedDB
## blocked on web, where the write itself still succeeds in memory) — just reports false
## and the settings stay as chosen until the page closes. A store without a path is never
## saved, and a file that exists but cannot be read is never written over. Key bindings
## are not stored: the settings screen only previews them.

const SECTION: String = "graphics"
const KEY_QUALITY: String = "quality"
const KEY_MIRRORS: String = "mirrors"
const TUTORIAL_SECTION: String = "settings"
const KEY_TUTORIAL_SEEN: String = "tutorial_seen"

var path: String
## The launcher's quality presets and defaults, which the values are checked against.
var launcher: DevLauncherConfig
## Whether `user://` survives a restart; false on web when IndexedDB is unavailable.
## Tests set it.
var userfs_persistent: bool = OS.is_userfs_persistent()

## Id of the chosen `QualityPreset` (`low`, `high`).
var quality: StringName
var mirrors: bool
## The tutorial was finished or skipped once; the start screen stops suggesting it.
var tutorial_seen: bool = false

## What the file held when it was read, written back with each change.
var _file: ConfigFile = ConfigFile.new()
## The file exists but could not be read: writing would lose what is in it.
var _unreadable: bool = false


func _init(settings_path: String, launcher_config: DevLauncherConfig) -> void:
	path = settings_path
	launcher = launcher_config
	reset()


## The launcher's defaults: `high` quality, mirrors on, tutorial not seen.
func reset() -> void:
	quality = launcher.default_quality
	mirrors = launcher.default_mirrors
	tutorial_seen = false
	_file = ConfigFile.new()
	_unreadable = false


## Reads the settings file; each value it lacks, or holds in an unknown form, keeps
## its default.
func load_settings() -> void:
	reset()
	if path == "" or not FileAccess.file_exists(path):
		return
	if _file.load(path) != OK:
		push_warning("Settings: %s cannot be read, using the defaults and not writing to it." % path)
		_file = ConfigFile.new()
		_unreadable = true
		return
	var saved_quality: Variant = _file.get_value(SECTION, KEY_QUALITY, "")
	if (saved_quality is String or saved_quality is StringName) \
			and launcher.find_quality(StringName(saved_quality)) != null:
		quality = StringName(saved_quality)
	# `get_value` with a null default reports an error for a missing key, so ask first.
	if _file.has_section_key(SECTION, KEY_MIRRORS):
		var saved_mirrors: Variant = _file.get_value(SECTION, KEY_MIRRORS)
		if saved_mirrors is bool:
			mirrors = saved_mirrors
	# Anything but a bool (a hand edit, a later format) reads as not seen.
	var seen: Variant = _file.get_value(TUTORIAL_SECTION, KEY_TUTORIAL_SEEN, false)
	tutorial_seen = seen is bool and seen


## Whether a save can last: there is a file to write, it was readable, and `user://`
## survives a restart.
func can_save() -> bool:
	return path != "" and userfs_persistent and not _unreadable


## Writes the graphics settings; false when they will not be there next time: no path,
## storage that does not persist, an unreadable file, or a write that failed.
func save_settings() -> bool:
	_file.set_value(SECTION, KEY_QUALITY, String(quality))
	_file.set_value(SECTION, KEY_MIRRORS, mirrors)
	return _write()


## Chooses a quality preset by id; an unknown id is ignored. Returns whether the
## settings were saved.
func set_quality(id: StringName) -> bool:
	if launcher.find_quality(id) == null:
		push_warning("Settings: unknown quality '%s' ignored." % id)
		return false
	quality = id
	return save_settings()


## Shows or hides the mirrors. Returns whether the settings were saved.
func set_mirrors(shown: bool) -> bool:
	mirrors = shown
	return save_settings()


## Remembers that the tutorial was seen; false when it could not be saved (it still
## counts for this run).
func mark_tutorial_seen() -> bool:
	tutorial_seen = true
	_file.set_value(TUTORIAL_SECTION, KEY_TUTORIAL_SEEN, true)
	return _write()


func _write() -> bool:
	if not can_save():
		return false
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	return _file.save(path) == OK
