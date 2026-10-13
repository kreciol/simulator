class_name FeedbackConfig
extends Resource
## Feedback tunables: the learn-mode hints (requirements §11.2) and the session summary
## (§11.3), spec Phase 8. Values live in res://config/feedback.tres; nothing is
## defaulted here.

## Penalty points a category must lose in a session to be named an area to improve
## and shown as "to improve". Below it, a slip is too small to dwell on.
@export var improve_penalty_threshold: float

## Hints (§11.2): a hint of one type is not shown again sooner than this after the
## last one, in seconds of driving.
@export var hint_cooldown_s: float
## At most this many hints on screen at once; a new one replaces the oldest...
@export var hint_max_on_screen: int
## ...only once that has been up this long, so none vanishes before it can be read.
## Even at 0 a hint is never replaced in the step that showed it.
@export var hint_min_display_s: float
## How long a hint stays on screen, in seconds of driving.
@export var hint_duration_s: float
## The gap counts as closing in on the legal minimum — a preventive hint before K1 —
## below this multiple of the minimum while the leader is slower.
@export var hint_gap_warning_factor: float
