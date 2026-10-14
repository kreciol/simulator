class_name SettingsStore
extends RefCounted
## The player's settings file (requirements §9.4, spec Data Model: Persisted, issue #44):
## the graphics quality and whether the mirrors are shown, in `user://settings.cfg` (a
## `ConfigFile`). Owned by the `SaveManager` autoload and read by the new-session setup.
## A missing file, or a missing or unknown value in it, takes the launcher's default; the
## file is only written when the player changes a setting. Saving never blocks play: a
## failed write — or `user://` that does not survive a restart (IndexedDB blocked on
## web, where the write itself still succeeds in memory) — just reports false and the
## settings stay as chosen until the page closes. A store without a path is never saved.
## Key bindings are not stored: the settings screen only previews them.

const SECTION: String = "graphics"
const KEY_QUALITY: String = "quality"
const KEY_MIRRORS: String = "mirrors"

var path: String
## The launcher's quality presets and defaults, which the values are checked against.
var launcher: DevLauncherConfig
## Whether `user://` survives a restart; false on web when IndexedDB is unavailable.
## Tests set it.
var userfs_persistent: bool = OS.is_userfs_persistent()

## Id of the chosen `QualityPreset` (`low`, `high`).
var quality: StringName
var mirrors: bool


func _init(settings_path: String, launcher_config: DevLauncherConfig) -> void:
	path = settings_path
	launcher = launcher_config
	reset()


## The launcher's defaults: `high` quality, mirrors on.
func reset() -> void:
	quality = launcher.default_quality
	mirrors = launcher.default_mirrors


## Reads the settings file; each value it lacks, or holds in an unknown form, keeps
## its default.
func load_settings() -> void:
	reset()
	if not FileAccess.file_exists(path):
		return
	var file: ConfigFile = ConfigFile.new()
	if file.load(path) != OK:
		push_warning("Settings: %s cannot be read, using the defaults." % path)
		return
	var saved_quality: Variant = file.get_value(SECTION, KEY_QUALITY, "")
	if (saved_quality is String or saved_quality is StringName) \
			and launcher.find_quality(StringName(saved_quality)) != null:
		quality = StringName(saved_quality)
	var saved_mirrors: Variant = file.get_value(SECTION, KEY_MIRRORS, null)
	if saved_mirrors is bool:
		mirrors = saved_mirrors


## Writes the settings; false when they will not be there next time: no path, storage
## that does not persist, or a write that failed.
func save_settings() -> bool:
	if path == "" or not userfs_persistent:
		return false
	var file: ConfigFile = ConfigFile.new()
	file.set_value(SECTION, KEY_QUALITY, String(quality))
	file.set_value(SECTION, KEY_MIRRORS, mirrors)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	return file.save(path) == OK


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
