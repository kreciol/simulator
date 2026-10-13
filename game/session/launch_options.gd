class_name LaunchOptions
extends RefCounted
## What one session is started with: mode, road profile, difficulty level, seed, and
## until the settings screen the graphics quality and whether mirrors are shown.
## Built by `DevLauncher` until the Phase 10 menus exist.

const MODE_LEARN: StringName = SessionRecord.MODE_LEARN
const MODE_EXAM: StringName = SessionRecord.MODE_EXAM
const MODES: Array[StringName] = [MODE_LEARN, MODE_EXAM]
## What the launch opens: a session, or the history screen (issue #41).
const SCREEN_DRIVE: StringName = &"drive"
const SCREEN_HISTORY: StringName = &"history"
const SCREENS: Array[StringName] = [SCREEN_DRIVE, SCREEN_HISTORY]

var mode: StringName
var profile: RoadProfile
## Difficulty level, 1-based, and its resource.
var level: int
var difficulty: DifficultyLevel
var seed_value: int
## False when the seed was missing or invalid and a random one was drawn instead.
var seed_given: bool
var quality: QualityPreset
var mirrors: bool
## Whether the FPS probe samples the session and prints its result (spec Phase 5 step 2).
var perf: bool
## `SCREEN_HISTORY` opens the history screen instead of a session, until the Phase 10
## menus reach it.
var screen: StringName = SCREEN_DRIVE


func describe() -> String:
	return "mode=%s profile=%s level=%d seed=%d quality=%s mirrors=%d perf=%d" % [
			mode, profile.id, level, seed_value, quality.id, int(mirrors), int(perf)]
