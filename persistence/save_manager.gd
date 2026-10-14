extends Node
## Global session-history service, the `SaveManager` autoload (spec Architecture,
## Phase 9 step 1). Loads the history once at start-up and saves finished sessions to
## it; the history file itself is `HistoryStore`. Saving never blocks play: when it is
## disabled, `save_record` just reports false and the screens explain why. It also
## holds the player's settings (`SettingsStore`), loaded at start-up the same way.

const CONFIG_PATH: String = "res://config/persistence.tres"

var config: PersistenceConfig
var store: HistoryStore
var settings: SettingsStore


func _ready() -> void:
	config = load(CONFIG_PATH) as PersistenceConfig
	store = HistoryStore.new(config.history_path, config.history_limit)
	store.load_history()
	settings = SettingsStore.new(config.settings_path)
	settings.load_settings()


## Saves a finished session; false when saving is disabled or the write failed.
func save_record(record: SessionRecord) -> bool:
	return store.save_record(record)
