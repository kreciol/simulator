class_name DevLauncherConfig
extends Resource
## What the dev launcher (spec Phasing, Phase 3 step 4) may start and what it falls
## back to. Values live in res://config/dev_launcher.tres; nothing is defaulted here.

## Road profiles selectable by their `id`.
@export var profiles: Array[RoadProfile]
## Profile used when the `profile` param is missing or unknown.
@export var default_profile: StringName
## Mode used when the `mode` param is missing or unknown (`learn` or `exam`).
@export var default_mode: StringName
## Difficulty levels selectable by their `id`, 1..levels.size().
@export var levels: Array[DifficultyLevel]
## Level used when the `level` param is missing or out of range.
@export var default_level: int


## The profile with this id, or null when there is none.
func find_profile(id: StringName) -> RoadProfile:
	for profile: RoadProfile in profiles:
		if profile.id == id:
			return profile
	return null


## The level with this id, or null when there is none.
func find_level(id: int) -> DifficultyLevel:
	for level: DifficultyLevel in levels:
		if level.id == id:
			return level
	return null
