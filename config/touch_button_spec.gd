class_name TouchButtonSpec
extends Resource
## One on-screen touch button (issue #86): the Input Map action it fires, its icon and
## where it sits. Values live in res://config/touch.tres; nothing is defaulted here.

## Input Map action the button presses while held (`accelerate`, `brake`, `lane_left`,
## `lane_right`, `signal_left`, `signal_right`, `pause`).
@export var action: StringName
## Drawn icon: `up`, `down`, `left`, `right`, `signal_left`, `signal_right` or `pause`.
@export var icon: StringName
## Point of the viewport the button is placed from, 0–1 of its width and height.
@export var anchor: Vector2
## The button's top-left corner relative to the anchor point, in reference pixels
## (`TouchConfig.reference_height_px`) [PARAM].
@export var offset: Vector2
## The button's size in reference pixels [PARAM].
@export var size: Vector2
