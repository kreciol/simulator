class_name Hint
extends RefCounted
## One learn-mode message on screen (requirements §11.2): what it says as a
## `FeedbackLine`, whether it confirms something done well or warns, and when it shows.

## The kind of hint, for rate limiting, e.g. &"keep_right", &"no_signal".
var type: StringName
var line: FeedbackLine
## True for a confirmation (tick icon), false for a warning (triangle icon).
var positive: bool = false
## Sim time it was shown at and leaves the screen at, seconds.
var shown_at_s: float
var expires_at_s: float
