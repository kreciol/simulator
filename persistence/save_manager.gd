extends Node
## Global session-history service, the `SaveManager` autoload (spec Architecture,
## Phase 9 step 1). Loads the history once at start-up and saves finished sessions to
## it; the history file itself is `HistoryStore`. Saving never blocks play: when it is
## disabled, `save_record` just reports false and the screens explain why.

const CONFIG_PATH: String = "res://config/persistence.tres"

var config: PersistenceConfig
var store: HistoryStore


func _ready() -> void:
	config = load(CONFIG_PATH) as PersistenceConfig
	store = HistoryStore.new(config.history_path, config.history_limit)
	store.load_history()


## Saves a finished session; false when saving is disabled or the write failed.
func save_record(record: SessionRecord) -> bool:
	return store.save_record(record)
