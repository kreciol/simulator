class_name TouchConfig
extends Resource
## The on-screen touch buttons (issue #86, spec `2026-10-20-touch-controls.md`): which
## there are, where they sit and how they look. Values live in res://config/touch.tres;
## nothing is defaulted here.

## Every button, in drawing order.
@export var buttons: Array[TouchButtonSpec]
## Viewport height at which offsets and sizes apply 1:1; they scale with the actual
## height [PARAM].
@export var reference_height_px: float
## Button opacity at rest, so the road stays visible behind it [PARAM].
@export_range(0.0, 1.0) var idle_alpha: float
## Button opacity while held, so the player sees what is held [PARAM].
@export_range(0.0, 1.0) var pressed_alpha: float
## Size of the action's name under the icon, in reference pixels [PARAM].
@export var label_font_size: int
## Share of the button's shorter side the icon takes [PARAM].
@export_range(0.0, 1.0) var icon_fraction: float
## Rounding of the button's corners, in reference pixels [PARAM].
@export var corner_radius_px: float
