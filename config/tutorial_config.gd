class_name TutorialConfig
extends Resource
## The tutorial (requirements §12, spec Phase 10 step 2). Values live in
## res://config/tutorial.tres; nothing is defaulted here.

## How far above (accelerate) or below (slow down) the speed a step started at the
## player has to get for the step to count as done, km/h [PARAM].
@export var speed_change_kmh: float
## How long the mirror step points at the mirrors before it counts as done, seconds of
## driving [PARAM].
@export var mirror_check_s: float
