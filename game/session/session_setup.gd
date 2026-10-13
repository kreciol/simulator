class_name SessionSetup
extends RefCounted
## The rules behind the new-session setup (requirements §9.1, spec Phase 10 step 1):
## learn mode is the default, the exam is suggested once enough learn sessions were
## completed, the recommended level is highlighted (Q14: every level is selectable),
## and a chosen mode · road profile · level becomes the `LaunchOptions` of a session.


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


## The options of a session with the chosen mode, road profile and level; quality,
## mirrors and the probe take the launcher's defaults until the settings screen
## (E11-S02). Built through `DevLauncher.resolve`, so an unknown value falls back the
## same way a URL param does.
static func options_for(mode: StringName, profile: StringName, level: int,
		launcher: DevLauncherConfig, random_seed: int) -> LaunchOptions:
	var params: Dictionary = {
		DevLauncher.KEY_MODE: String(mode),
		DevLauncher.KEY_PROFILE: String(profile),
		DevLauncher.KEY_LEVEL: str(level),
	}
	return DevLauncher.resolve(params, launcher, random_seed)
