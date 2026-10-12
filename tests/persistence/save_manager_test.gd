extends GdUnitTestSuite
## The `SaveManager` autoload (AGENTS.md: autoloads only for global services; spec
## Phase 9 step 1) is registered and reads its settings from config.

const SCRIPT_PATH: String = "res://persistence/save_manager.gd"


func test_save_manager_is_an_autoload() -> void:
	assert_str(ProjectSettings.get_setting("autoload/SaveManager", "")).is_equal("*" + SCRIPT_PATH)


func test_save_manager_reads_the_persistence_config() -> void:
	var script: GDScript = load(SCRIPT_PATH) as GDScript
	var config_path: String = script.get_script_constant_map()["CONFIG_PATH"]
	assert_object(load(config_path) as PersistenceConfig).is_not_null()
