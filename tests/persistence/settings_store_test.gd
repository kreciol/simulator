extends GdUnitTestSuite
## The settings file (issue #44 acceptance criteria, spec Phase 10 step 1: "settings
## round-trip through settings.cfg"): what the player chose survives a reload, and a
## missing, unreadable or unknown value takes the launcher's default.

const DIR: String = "user://test_settings_store"
const PATH: String = DIR + "/settings.cfg"

var _launcher: DevLauncherConfig


func before_test() -> void:
	_clear_dir()
	DirAccess.make_dir_recursive_absolute(DIR)
	_launcher = load("res://config/dev_launcher.tres") as DevLauncherConfig


func after_test() -> void:
	_clear_dir()


func _clear_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for file_name: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))
	DirAccess.remove_absolute(DIR)


func _loaded() -> SettingsStore:
	var store: SettingsStore = SettingsStore.new(PATH, _launcher)
	store.userfs_persistent = true
	store.load_settings()
	return store


func _write(text: String) -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_without_a_file_the_launcher_defaults_apply() -> void:
	var store: SettingsStore = _loaded()
	assert_str(store.quality).is_equal(_launcher.default_quality)
	assert_bool(store.mirrors).is_equal(_launcher.default_mirrors)
	assert_bool(FileAccess.file_exists(PATH)).is_false()


func test_changed_settings_are_restored_after_a_reload() -> void:
	var store: SettingsStore = _loaded()
	assert_bool(store.set_quality(&"low")).is_true()
	assert_bool(store.set_mirrors(false)).is_true()
	var reloaded: SettingsStore = _loaded()
	assert_str(reloaded.quality).is_equal(&"low")
	assert_bool(reloaded.mirrors).is_false()
	reloaded.set_quality(&"high")
	reloaded.set_mirrors(true)
	var again: SettingsStore = _loaded()
	assert_str(again.quality).is_equal(&"high")
	assert_bool(again.mirrors).is_true()


func test_the_file_holds_only_quality_and_mirrors() -> void:
	_loaded().set_quality(&"low")
	var file: ConfigFile = ConfigFile.new()
	assert_int(file.load(PATH)).is_equal(OK)
	assert_array(file.get_sections()).contains_exactly([SettingsStore.SECTION])
	assert_array(file.get_section_keys(SettingsStore.SECTION)).contains_exactly_in_any_order(
			[SettingsStore.KEY_QUALITY, SettingsStore.KEY_MIRRORS])


func test_an_unknown_quality_is_ignored() -> void:
	var store: SettingsStore = _loaded()
	assert_bool(store.set_quality(&"ultra")).is_false()
	assert_str(store.quality).is_equal(_launcher.default_quality)
	assert_bool(FileAccess.file_exists(PATH)).is_false()


func test_unknown_values_in_the_file_take_the_defaults() -> void:
	_write("[graphics]\nquality=\"ultra\"\nmirrors=\"yes\"\n")
	var store: SettingsStore = _loaded()
	assert_str(store.quality).is_equal(_launcher.default_quality)
	assert_bool(store.mirrors).is_equal(_launcher.default_mirrors)


func test_values_missing_from_the_file_take_the_defaults() -> void:
	_write("[graphics]\nmirrors=false\n")
	var store: SettingsStore = _loaded()
	assert_str(store.quality).is_equal(_launcher.default_quality)
	assert_bool(store.mirrors).is_false()


func test_an_unreadable_file_takes_the_defaults() -> void:
	_write("this is [ not a config file")
	var store: SettingsStore = _loaded()
	assert_str(store.quality).is_equal(_launcher.default_quality)
	assert_bool(store.mirrors).is_equal(_launcher.default_mirrors)


func test_a_failed_save_reports_false_and_keeps_the_choice() -> void:
	# A directory where the file should be: the write fails, play goes on.
	var blocked: String = DIR + "/blocked.cfg"
	DirAccess.make_dir_recursive_absolute(blocked)
	var store: SettingsStore = SettingsStore.new(blocked, _launcher)
	store.userfs_persistent = true
	store.load_settings()
	assert_bool(store.set_mirrors(false)).is_false()
	assert_bool(store.mirrors).is_false()
	DirAccess.remove_absolute(blocked)


func test_the_settings_file_lives_in_user_storage() -> void:
	var config: PersistenceConfig = load("res://config/persistence.tres") as PersistenceConfig
	assert_str(config.settings_path).is_equal("user://settings.cfg")


func test_storage_that_does_not_persist_reports_a_failed_save() -> void:
	# On web with IndexedDB blocked the write succeeds in memory and is lost on reload.
	var store: SettingsStore = SettingsStore.new(PATH, _launcher)
	store.userfs_persistent = false
	store.load_settings()
	assert_bool(store.set_quality(&"low")).is_false()
	assert_str(store.quality).is_equal(&"low")
	assert_bool(FileAccess.file_exists(PATH)).is_false()


func test_a_store_without_a_path_is_never_saved() -> void:
	var store: SettingsStore = SettingsStore.new("", _launcher)
	store.userfs_persistent = true
	assert_bool(store.set_mirrors(false)).is_false()
	assert_bool(store.mirrors).is_false()
