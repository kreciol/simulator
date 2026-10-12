class_name FeedbackConfig
extends Resource
## Session summary tunables (requirements §11.3, spec Phase 8). Values live in
## res://config/feedback.tres; nothing is defaulted here.

## Penalty points a category must lose in a session to be named an area to improve
## and shown as "to improve". Below it, a slip is too small to dwell on.
@export var improve_penalty_threshold: float
