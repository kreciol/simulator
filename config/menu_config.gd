class_name MenuConfig
extends Resource
## The start screen and the new-session setup (requirements §9.1, §9.4, spec Phase 10
## step 1). Values live in res://config/menu.tres; nothing is defaulted here.

## Completed learn sessions after which the setup suggests the exam [PARAM].
@export var exam_suggested_after_learn_sessions: int
