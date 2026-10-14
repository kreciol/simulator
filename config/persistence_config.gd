class_name PersistenceConfig
extends Resource
## Where and how much session history is kept (requirements §13, spec Data Model:
## Persisted). Values live in res://config/persistence.tres; nothing is defaulted here.

## Sessions kept in the history; the oldest are dropped beyond it [PARAM].
@export var history_limit: int
## The history file, under `user://` (IndexedDB on web).
@export var history_path: String
## The player's settings file (`ConfigFile`), under `user://` (issue #44).
@export var settings_path: String
## Sessions listed on the history screen, newest first [PARAM].
@export var history_recent_count: int
## Latest sessions plotted on the history screen's score trend [PARAM].
@export var history_trend_count: int
