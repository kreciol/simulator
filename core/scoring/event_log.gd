class_name EventLog
extends RefCounted
## Every scored event of one session, in the order they started (requirements §8.6).
## Continuous rules are aggregated into segments rather than logged per step: a rule
## opens a segment, extends it each step it applies, and closes it when it stops.

var events: Array[ScoreEvent] = []

## Open segments by key (one per continuous rule).
var _open: Dictionary[StringName, ScoreEvent] = {}


## Records an instant event at `time_s` and returns it.
func add_instant(
		time_s: float,
		type: StringName,
		category: StringName,
		points: float,
		context: Dictionary = {}) -> ScoreEvent:
	var event: ScoreEvent = ScoreEvent.new()
	event.timestamp_s = time_s
	event.segment_end_s = time_s
	event.type = type
	event.category = category
	event.points = points
	event.context = context
	events.append(event)
	return event


## Opens a segment under `key` starting at `start_s`, with `extreme` as its first
## extreme value. Does nothing when one is already open under `key`; returns the
## open segment either way.
func open_segment(
		key: StringName,
		start_s: float,
		type: StringName,
		category: StringName,
		extreme: float,
		context: Dictionary = {}) -> ScoreEvent:
	if _open.has(key):
		return _open[key]
	var event: ScoreEvent = add_instant(start_s, type, category, 0.0, context)
	event.is_segment = true
	event.extreme = extreme
	_open[key] = event
	return event


func is_open(key: StringName) -> bool:
	return _open.has(key)


## The segment open under `key`, or null.
func open_segment_for(key: StringName) -> ScoreEvent:
	return _open.get(key, null)


## Adds `points` to the segment open under `key` and moves its end to `end_s`.
func extend_segment(key: StringName, end_s: float, points: float) -> void:
	var event: ScoreEvent = _open.get(key, null)
	if event == null:
		return
	event.points += points
	event.segment_end_s = end_s


## Closes the segment open under `key` and returns it; null when none is open.
func close_segment(key: StringName) -> ScoreEvent:
	var event: ScoreEvent = _open.get(key, null)
	if event != null:
		_open.erase(key)
	return event


## Closes every open segment (at the end of a session) and returns them.
func close_all() -> Array[ScoreEvent]:
	var closed: Array[ScoreEvent] = []
	for key: StringName in _open.keys():
		closed.append(close_segment(key))
	return closed


## Sum of all points, open segments included. Not clamped (the floor at 0 is applied
## to the session total, spec Q6).
func total() -> float:
	var sum: float = 0.0
	for event: ScoreEvent in events:
		sum += event.points
	return sum


func total_for(category: StringName) -> float:
	var sum: float = 0.0
	for event: ScoreEvent in events:
		if event.category == category:
			sum += event.points
	return sum


func events_of_type(type: StringName) -> Array[ScoreEvent]:
	var found: Array[ScoreEvent] = []
	for event: ScoreEvent in events:
		if event.type == type:
			found.append(event)
	return found
