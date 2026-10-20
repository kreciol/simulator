class_name LaunchOptions
extends RefCounted
## What one session is started with: mode, road profile, difficulty level, seed, the
## graphics quality and whether mirrors are shown. Built by the new-session setup
## (`SessionSetup`, quality and mirrors from the player's settings) or, from URL params,
## `DevLauncher`.

const MODE_LEARN: StringName = SessionRecord.MODE_LEARN
const MODE_EXAM: StringName = SessionRecord.MODE_EXAM
const MODES: Array[StringName] = [MODE_LEARN, MODE_EXAM]
## What the launch opens: a session, the history screen (issue #41) or the tutorial, a
## learn session on an empty road with no scoring (issue #45).
const SCREEN_DRIVE: StringName = &"drive"
const SCREEN_HISTORY: StringName = &"history"
const SCREEN_TUTORIAL: StringName = &"tutorial"
const SCREENS: Array[StringName] = [SCREEN_DRIVE, SCREEN_HISTORY, SCREEN_TUTORIAL]

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


## The same session once more (the end screen's "again", issue #43): mode, road
## profile, level, quality, mirrors, probe and whether it is the tutorial kept, with
## `random_seed` so the traffic differs from the last attempt.
func again(random_seed: int) -> LaunchOptions:
	var options: LaunchOptions = LaunchOptions.new()
	options.mode = mode
	options.profile = profile
	options.level = level
	options.difficulty = difficulty
	options.seed_value = random_seed
	options.seed_given = false
	options.quality = quality
	options.mirrors = mirrors
	options.perf = perf
	options.screen = SCREEN_TUTORIAL if is_tutorial() else SCREEN_DRIVE
	return options


func is_tutorial() -> bool:
	return screen == SCREEN_TUTORIAL


func describe() -> String:
	return "mode=%s profile=%s level=%d seed=%d quality=%s mirrors=%d perf=%d screen=%s" % [
			mode, profile.id, level, seed_value, quality.id, int(mirrors), int(perf), screen]
