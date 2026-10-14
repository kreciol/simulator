class_name SessionManager
extends Node
## Session flow (requirements §9.3, spec Architecture: Session): a 3-2-1 intro, then
## `SimConfig.session_length_s` of driving, then the end. Owns the sim and is the only
## node that drives it; views and the HUD only read its state. In the exam the player
## colliding or leaving the road ends the session at once as aborted, with the cause;
## in learn mode it starts a respawn instead (requirements §9.2): K4 is charged, the
## sim freezes and input is dropped for `SimConfig.respawn_fade_s`, the player is put
## back on the right lane at the fade's midpoint (`Respawn`), and the timer keeps
## running throughout. The countdown, the drive and a respawn can be paused (spec Edge
## Cases): everything stands still until resumed, and losing window focus pauses on its
## own. With a `scoring_config` it also scores the drive and, at the end, builds the
## session's `SessionRecord` for `SaveManager` and — with a `feedback_config` — its
## `Summary`; with both configs, learn mode also coaches the drive through a
## `HintEngine` (requirements §11.2), which the exam never has. The tutorial (spec
## Phase 10 step 2) is a learn session on an empty road with no scoring, hints or time
## limit: its `Tutorial` prompts the steps and the session ends once they are done or
## the player skips them.

signal session_started
signal session_ended
signal session_paused
signal session_resumed
## The player was put back on the right lane after `respawn_cause` (learn mode).
signal player_respawned

enum State { INTRO, DRIVING, RESPAWNING, ENDED }
## Why the session ended; NONE until it has. `TUTORIAL_OVER`: the tutorial was finished
## or skipped (`Tutorial.skipped` says which).
enum EndReason { NONE, TIME_UP, COLLISION, OFF_ROAD, TUTORIAL_OVER }

## Absorbs float drift when fixed steps should sum to exactly a configured duration.
const TIME_EPSILON: float = 1e-6
## Share of the respawn fade after which the player is put back: when it is darkest.
const RESPAWN_MIDPOINT: float = 0.5

## Scores the session when set; without it there is no scoring, record or summary.
@export var scoring_config: ScoringConfig
## Writes the end-of-session summary when set along with `scoring_config`.
@export var feedback_config: FeedbackConfig
## The tutorial's tunables; needed to start a tutorial.
@export var tutorial_config: TutorialConfig

var sim: TrafficSim
var player: VehicleState
## What the session was started with; null when set up directly through `setup`.
var options: LaunchOptions
## `LaunchOptions.MODE_LEARN` or `MODE_EXAM`.
var mode: StringName = LaunchOptions.MODE_LEARN
var state: State = State.INTRO
var end_reason: EndReason = EndReason.NONE
## Time spent in the intro countdown, seconds.
var intro_elapsed_s: float = 0.0
## Session time driven so far; the timer starts when the intro ends and keeps
## running through respawns.
var elapsed_s: float = 0.0
## What the respawn in progress, or the last one, follows (`COLLISION` / `OFF_ROAD`);
## NONE before the first.
var respawn_cause: EndReason = EndReason.NONE
## Time spent in the respawn in progress, seconds.
var respawn_elapsed_s: float = 0.0
## Respawns so far this session.
var respawn_count: int = 0
## Observes the sim after every step; null without a `scoring_config`.
var scoring: ScoringSystem
## When driving started, ISO-8601 UTC.
var started_at: String = ""
## The finished session's record; null until the end, or without scoring.
var record: SessionRecord
## While set, `step` does nothing: the sim, its lane-change animation and signals, the
## countdown and the session timer stand still and commands are dropped. A flag rather
## than a state because both the intro and the drive can be paused; `state` says
## which one resumes.
var paused: bool = false
## The ended session's summary; null until the end, or without both configs.
var summary: Summary
## Learn-mode hints, fed after every scored step and cleared on a respawn; null in the
## exam, or without both configs.
var hint_engine: HintEngine
## The tutorial's prompts, fed after every driving step; null outside the tutorial.
var tutorial: Tutorial

## The player's collision or off-road seen during the current sim step; the session
## ends once the step is over.
var _player_end_reason: EndReason = EndReason.NONE


## Sets the session up on the launch options' profile and seed with traffic at the
## options' difficulty level, keeping the options (mode, level) for the rules that
## depend on them. The tutorial gets an empty road and no scoring instead.
func start(launch_options: LaunchOptions, sim_config: SimConfig) -> void:
	setup(launch_options.profile, sim_config, launch_options.seed_value, launch_options.mode)
	options = launch_options
	if launch_options.is_tutorial():
		# Scoring during the tutorial is out of scope (issue #45): nothing to observe.
		scoring = null
		hint_engine = null
		tutorial = Tutorial.new(tutorial_config, player)
	elif launch_options.difficulty != null:
		Spawner.new(launch_options.difficulty).attach(sim)


func setup(road_profile: RoadProfile, sim_config: SimConfig, seed_value: int = 0,
		session_mode: StringName = LaunchOptions.MODE_LEARN) -> void:
	options = null
	mode = session_mode
	sim = TrafficSim.new(road_profile, sim_config, seed_value)
	# Right lane at the start speed (requirements §9.3).
	player = sim.add_vehicle(0.0, 0, sim_config.start_speed_kmh / TrafficSim.KMH_PER_MPS)
	sim.player = player
	sim.collision.connect(_on_collision)
	sim.offroad.connect(_on_offroad)
	scoring = ScoringSystem.new(sim, scoring_config) if scoring_config != null else null
	hint_engine = null
	tutorial = null
	if scoring != null and feedback_config != null and not is_exam():
		hint_engine = HintEngine.new(sim, scoring, feedback_config)
	started_at = ""
	record = null
	summary = null
	state = State.INTRO
	end_reason = EndReason.NONE
	_player_end_reason = EndReason.NONE
	paused = false
	intro_elapsed_s = 0.0
	elapsed_s = 0.0
	respawn_cause = EndReason.NONE
	respawn_elapsed_s = 0.0
	respawn_count = 0


## Advances the session by one fixed step. The sim only runs while driving: during
## the intro, a respawn, while paused and after the end it is frozen and `commands`
## are dropped.
func step(dt: float, commands: PlayerCommands = null) -> void:
	if paused:
		return
	match state:
		State.INTRO:
			intro_elapsed_s += dt
			if intro_elapsed_s >= sim.config.countdown_s - TIME_EPSILON:
				state = State.DRIVING
				started_at = Time.get_datetime_string_from_system(true) + "Z"
				session_started.emit()
		State.DRIVING:
			sim.step(dt, commands)
			if scoring != null:
				var events: Array[ScoreEvent] = scoring.observe(dt)
				if hint_engine != null:
					hint_engine.observe(events)
			if tutorial != null:
				tutorial.observe(dt)
			elapsed_s += dt
			var incident: EndReason = _player_end_reason
			_player_end_reason = EndReason.NONE
			if tutorial != null and tutorial.is_finished():
				_end(EndReason.TUTORIAL_OVER)
			elif incident != EndReason.NONE and is_exam():
				_end(incident)
			elif _time_up():
				_end(EndReason.TIME_UP)
			elif incident != EndReason.NONE:
				_start_respawn(incident)
		State.RESPAWNING:
			elapsed_s += dt
			var before_midpoint: bool = respawn_progress() < RESPAWN_MIDPOINT - TIME_EPSILON
			respawn_elapsed_s += dt
			if before_midpoint and respawn_progress() >= RESPAWN_MIDPOINT - TIME_EPSILON:
				_respawn()
			if _time_up():
				_end(EndReason.TIME_UP)
			elif respawn_elapsed_s >= sim.config.respawn_fade_s - TIME_EPSILON:
				state = State.DRIVING


## Pauses the countdown or the drive; does nothing once the session has ended.
func pause() -> void:
	if paused or state == State.ENDED:
		return
	paused = true
	session_paused.emit()


func resume() -> void:
	if not paused:
		return
	paused = false
	session_resumed.emit()


## Ends the tutorial at once, from any state but the end — paused too (requirements
## §12: skippable). Does nothing outside the tutorial.
func skip_tutorial() -> void:
	if tutorial == null or state == State.ENDED:
		return
	tutorial.skip()
	paused = false
	_end(EndReason.TUTORIAL_OVER)


func is_tutorial() -> bool:
	return tutorial != null


func toggle_pause() -> void:
	if paused:
		resume()
	else:
		pause()


func countdown_left_s() -> float:
	if state != State.INTRO:
		return 0.0
	return maxf(0.0, sim.config.countdown_s - intro_elapsed_s)


func time_left_s() -> float:
	if state == State.ENDED:
		return 0.0
	return maxf(0.0, sim.config.session_length_s - elapsed_s)


func _notification(what: int) -> void:
	# A hidden tab or a window in the background must not run the clock (§9.3). The
	# player resumes on purpose rather than on focus returning. Platforms report focus
	# loss as either notification (the web build through the window), so both pause.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		pause()


## 0 when the respawn starts, 1 when the player drives on; 0 outside a respawn.
func respawn_progress() -> float:
	if state != State.RESPAWNING:
		return 0.0
	return clampf(respawn_elapsed_s / sim.config.respawn_fade_s, 0.0, 1.0)


## How dark the respawn fade is: out to black by the midpoint, where the player is
## put back, then in again. 0 outside a respawn.
func fade_amount() -> float:
	if state != State.RESPAWNING:
		return 0.0
	var progress: float = respawn_progress()
	if progress < RESPAWN_MIDPOINT:
		return progress / RESPAWN_MIDPOINT
	return (1.0 - progress) / (1.0 - RESPAWN_MIDPOINT)


func is_exam() -> bool:
	return mode == LaunchOptions.MODE_EXAM


## The §13 record status of an ended session; empty until it has ended.
func status() -> StringName:
	match end_reason:
		EndReason.TIME_UP:
			return SessionRecord.STATUS_COMPLETED
		EndReason.COLLISION:
			return SessionRecord.STATUS_ABORTED_COLLISION
		EndReason.OFF_ROAD:
			return SessionRecord.STATUS_ABORTED_OFFROAD
	return &""


func _time_up() -> bool:
	return tutorial == null and elapsed_s >= sim.config.session_length_s - TIME_EPSILON


func _start_respawn(cause: EndReason) -> void:
	respawn_cause = cause
	respawn_elapsed_s = 0.0
	if sim.config.respawn_fade_s <= 0.0:
		# No fade configured: straight back on the road.
		_respawn()
		return
	state = State.RESPAWNING


func _respawn() -> void:
	Respawn.respawn_player(sim)
	if scoring != null:
		scoring.restart_after_respawn()
	if hint_engine != null:
		hint_engine.clear()
	respawn_count += 1
	player_respawned.emit()


func _end(reason: EndReason) -> void:
	state = State.ENDED
	end_reason = reason
	if scoring != null:
		scoring.finish()
		record = _build_record()
		if feedback_config != null:
			summary = SummaryGenerator.new(feedback_config, scoring_config).generate(
					scoring.event_log, record, _exam_pass_score())
	session_ended.emit()


func _build_record() -> SessionRecord:
	var builder: SessionRecordBuilder = SessionRecordBuilder.new(scoring_config)
	builder.id = _new_id()
	builder.started_at = started_at
	builder.app_version = str(ProjectSettings.get_setting("application/config/version", ""))
	builder.road_profile = sim.road.id
	builder.seed_value = sim.rng_seed
	builder.duration_s = elapsed_s
	builder.status = status()
	builder.mode = mode
	builder.exam_pass_score = _exam_pass_score()
	if options != null:
		builder.difficulty = options.level
	return builder.build(scoring.event_log)


## The launch level's exam pass mark; 0 when set up without a level.
func _exam_pass_score() -> float:
	if options == null or options.difficulty == null:
		return 0.0
	return options.difficulty.exam_pass_score


## A random UUID (version 4), as §13 asks for the record's `id`. Not drawn from the
## sim's RNG, so it never disturbs a seeded replay.
static func _new_id() -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex: String = bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4),
			hex.substr(16, 4), hex.substr(20, 12)]


func _on_collision(vehicle_id: int, other_id: int) -> void:
	if vehicle_id == player.id or other_id == player.id:
		_player_end_reason = EndReason.COLLISION


func _on_offroad(vehicle_id: int) -> void:
	if vehicle_id == player.id and _player_end_reason == EndReason.NONE:
		_player_end_reason = EndReason.OFF_ROAD
