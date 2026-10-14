extends GdUnitTestSuite
## The player's settings in `settings.cfg` (spec Data Model: Persisted, issue #45):
## whether the tutorial was seen round-trips, a missing file means unseen, other keys
## survive a write, and an unreadable file is never overwritten.

const DIR: String = "user://test_settings_store"
const PATH: String = DIR + "/settings.cfg"
## `ConfigFile` cannot parse it: the section header is never closed.
const UNREADABLE: String = "[settings\nquality = (\n"


func before_test() -> void:
	_clear_dir()
	DirAccess.make_dir_recursive_absolute(DIR)


func after_test() -> void:
	_clear_dir()


func _clear_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for file_name: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file_name))
	DirAccess.remove_absolute(DIR)


func _new_store() -> SettingsStore:
	var store: SettingsStore = SettingsStore.new(PATH)
	store.userfs_persistent = true
	store.load_settings()
	return store


func _write_file(text: String) -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_the_config_names_the_settings_file() -> void:
	var config: PersistenceConfig = load("res://config/persistence.tres") as PersistenceConfig
	assert_str(config.settings_path).is_equal("user://settings.cfg")


func test_a_missing_file_means_the_tutorial_was_not_seen() -> void:
	var store: SettingsStore = _new_store()
	assert_bool(store.tutorial_seen).is_false()
	assert_bool(store.can_save).is_true()


func test_the_tutorial_seen_flag_round_trips() -> void:
	assert_bool(_new_store().mark_tutorial_seen()).is_true()
	assert_bool(FileAccess.file_exists(PATH)).is_true()
	assert_bool(_new_store().tutorial_seen).is_true()


func test_other_keys_survive_a_write() -> void:
	_write_file("[settings]\nquality=\"low\"\n")
	_new_store().mark_tutorial_seen()
	var file: ConfigFile = ConfigFile.new()
	assert_int(file.load(PATH)).is_equal(OK)
	assert_str(file.get_value("settings", "quality", "")).is_equal("low")
	assert_bool(file.get_value("settings", "tutorial_seen", false)).is_true()


func test_an_unreadable_file_is_never_overwritten() -> void:
	_write_file(UNREADABLE)
	var store: SettingsStore = _new_store()
	assert_bool(store.tutorial_seen).is_false()
	assert_bool(store.can_save).is_false()
	# Still counts for the run, but the file is left as it was.
	assert_bool(store.mark_tutorial_seen()).is_false()
	assert_bool(store.tutorial_seen).is_true()
	assert_str(FileAccess.get_file_as_string(PATH)).is_equal(UNREADABLE)


func test_without_persistent_storage_nothing_is_written() -> void:
	var store: SettingsStore = SettingsStore.new(PATH)
	store.userfs_persistent = false
	store.load_settings()
	assert_bool(store.mark_tutorial_seen()).is_false()
	assert_bool(store.tutorial_seen).is_true()
	assert_bool(FileAccess.file_exists(PATH)).is_false()


func test_save_manager_loads_the_settings() -> void:
	assert_object(SaveManager.settings).is_not_null()
	assert_str(SaveManager.settings.path).is_equal("user://settings.cfg")
