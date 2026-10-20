class_name SessionSetup
extends RefCounted
## The rules behind the new-session setup (requirements §9.1, spec Phase 10 step 1):
## learn mode is the default, the exam is suggested once enough learn sessions were
## completed, the recommended level is highlighted (Q14: every level is selectable),
## and a chosen mode · road profile · level becomes the `LaunchOptions` of a session.
## The tutorial (spec Phase 10 step 2) is suggested until it has been seen.


## Saved sessions (`HistoryStore.sessions`) completed in learn mode; a learn session
## never aborts, but an entry that did is not counted either.
static func completed_learn_sessions(sessions: Array[Dictionary]) -> int:
	var count: int = 0
	for entry: Dictionary in sessions:
		if str(entry.get("mode", "")) == String(SessionRecord.MODE_LEARN) \
				and str(entry.get("status", "")) == String(SessionRecord.STATUS_COMPLETED):
			count += 1
	return count


## Whether the setup suggests the exam: after `config`'s number of completed learn
## sessions, not before.
static func suggests_exam(completed_learn: int, config: MenuConfig) -> bool:
	return completed_learn >= config.exam_suggested_after_learn_sessions


## The mode selected when the setup opens: learn for everyone (§9.1) — a suggested
## exam is marked, never pre-selected, so the player chooses it.
static func default_mode() -> StringName:
	return LaunchOptions.MODE_LEARN


## The id of the level to highlight: the first one marked `recommended`, else the
## launcher's default.
static func recommended_level(launcher: DevLauncherConfig) -> int:
	for level: DifficultyLevel in launcher.levels:
		if level.recommended:
			return level.id
	return launcher.default_level


## The options of a session with the chosen mode, road profile and level, and the
## quality and mirrors of the player's `settings` (issue #44; the launcher's defaults
## without them); the probe takes the launcher's default. Built through
## `DevLauncher.resolve`, so an unknown value falls back the same way a URL param does.
static func options_for(mode: StringName, profile: StringName, level: int,
		launcher: DevLauncherConfig, random_seed: int, settings: SettingsStore = null) -> LaunchOptions:
	var params: Dictionary = {
		DevLauncher.KEY_MODE: String(mode),
		DevLauncher.KEY_PROFILE: String(profile),
		DevLauncher.KEY_LEVEL: str(level),
	}
	if settings != null:
		params[DevLauncher.KEY_QUALITY] = String(settings.quality)
		params[DevLauncher.KEY_MIRRORS] = "1" if settings.mirrors else "0"
	return DevLauncher.resolve(params, launcher, random_seed)


## Whether the start screen suggests the tutorial: until it was finished or skipped
## once (spec UI/UX flow: suggested on first run).
static func suggests_tutorial(tutorial_seen: bool) -> bool:
	return not tutorial_seen


## The options of the tutorial: learn mode on the launcher's default road; it has no
## traffic and no scoring whatever the level (`SessionManager`).
static func tutorial_options(launcher: DevLauncherConfig, random_seed: int,
		settings: SettingsStore = null) -> LaunchOptions:
	var params: Dictionary = {DevLauncher.KEY_SCREEN: String(LaunchOptions.SCREEN_TUTORIAL)}
	if settings != null:
		params[DevLauncher.KEY_QUALITY] = String(settings.quality)
		params[DevLauncher.KEY_MIRRORS] = "1" if settings.mirrors else "0"
	return DevLauncher.resolve(params, launcher, random_seed)
