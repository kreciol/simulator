class_name TouchConfig
extends Resource
## The on-screen touch buttons (issue #86, spec `2026-10-20-touch-controls.md`): which
## there are, where they sit and how they look. Values live in res://config/touch.tres;
## nothing is defaulted here.

## Every button, in drawing order.
@export var buttons: Array[TouchButtonSpec]
## Viewport size at which offsets and sizes apply 1:1; they scale with the actual
## height, or the width when that is relatively smaller, so no button leaves the
## screen [PARAM].
@export var reference_height_px: float
@export var reference_width_px: float
## Button opacity at rest, so the road stays visible behind it [PARAM].
@export_range(0.0, 1.0) var idle_alpha: float
## Button opacity while held, so the player sees what is held [PARAM].
@export_range(0.0, 1.0) var pressed_alpha: float
## Opacity of the icon and the action's name at rest; held, they are opaque [PARAM].
@export_range(0.0, 1.0) var idle_icon_alpha: float
## Button fill, its opacity from `idle_alpha` / `pressed_alpha` [PARAM].
@export var background_color: Color
## Icon, text and border colour [PARAM].
@export var icon_color: Color
## Border width, in reference pixels [PARAM].
@export var border_width_px: float
## Dark outline around the action's name, in reference pixels [PARAM].
@export var label_outline_px: int
## Size of the action's name under the icon, in reference pixels [PARAM].
@export var label_font_size: int
## Share of the button's shorter side the icon takes [PARAM].
@export_range(0.0, 1.0) var icon_fraction: float
## Rounding of the button's corners, in reference pixels [PARAM].
@export var corner_radius_px: float
## Smallest side of anything a finger presses on a touch device — the touch buttons,
## the menus' and the end screen's buttons — in CSS pixels as the browser reports them
## (issue #87; WCAG 2.2 target size minimum) [PARAM].
@export var min_touch_target_px: float
