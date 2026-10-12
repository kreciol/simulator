class_name ScoreEvent
extends RefCounted
## One scored event of a session (requirements §8.6, spec Data Model). Instant rules
## (K3) record a single moment; continuous rules (K1, K2) record a segment from
## `timestamp_s` to `segment_end_s` with the sum of its points and its extreme value.

## Seconds since the start of the session.
var timestamp_s: float
## What happened, e.g. &"gap_too_small", &"no_signal".
var type: StringName
## &"gap", &"lane", &"signal", &"speed" or &"collision".
var category: StringName
## Positive for rewards, negative for penalties; for a segment, the sum over it.
var points: float = 0.0
## Rule-specific numbers for feedback, e.g. {speed_kmh, gap_m, min_gap_m}.
var context: Dictionary = {}
## Whether this is a continuous segment rather than an instant event.
var is_segment: bool = false
## End of the segment; equals `timestamp_s` while it is open and for instant events.
var segment_end_s: float
## The segment's extreme value as defined by its rule (K1: lowest gap ratio).
var extreme: float = 0.0


func duration_s() -> float:
	return segment_end_s - timestamp_s
