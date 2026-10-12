class_name SessionManager
extends Node
## Session flow (requirements §9.3, spec Architecture: Session): a 3-2-1 intro, then
## `SimConfig.session_length_s` of driving, then the end. Owns the sim and is the only
## node that drives it; views and the HUD only read its state. In the exam the player
## colliding or leaving the road ends the session at once as aborted, with the cause
## (requirements §9.2). Given a `ScoringConfig`, it also scores the drive: its
## `ScoringSystem` observes every driving step and is finished when the session ends.

signal session_started
signal session_ended

enum State { INTRO, DRIVING, ENDED }
## Why the session ended; NONE until it has.
enum EndReason { NONE, TIME_UP, COLLISION, OFF_ROAD }

## Absorbs float drift when fixed steps should sum to exactly a configured duration.
const TIME_EPSILON: float = 1e-6

var sim: TrafficSim
var player: VehicleState
## Scores the player's driving; null when set up without a `ScoringConfig`.
var scoring: ScoringSystem
## What the session was started with; null when set up directly through `setup`.
var options: LaunchOptions
## `LaunchOptions.MODE_LEARN` or `MODE_EXAM`.
var mode: StringName = LaunchOptions.MODE_LEARN
var state: State = State.INTRO
var end_reason: EndReason = EndReason.NONE
## Time spent in the intro countdown, seconds.
var intro_elapsed_s: float = 0.0
## Session time driven so far; the timer starts when the intro ends.
var elapsed_s: float = 0.0

## The player's collision or off-road seen during the current sim step; the session
## ends once the step is over.
var _player_end_reason: EndReason = EndReason.NONE


## Sets the session up on the launch options' profile and seed with traffic at the
## options' difficulty level, keeping the options (mode, level) for the rules that
## depend on them, and scored with `scoring_config` when given.
func start(launch_options: LaunchOptions, sim_config: SimConfig,
		scoring_config: ScoringConfig = null) -> void:
	setup(launch_options.profile, sim_config, launch_options.seed_value, launch_options.mode,
			scoring_config)
	options = launch_options
	if launch_options.difficulty != null:
		Spawner.new(launch_options.difficulty).attach(sim)


func setup(road_profile: RoadProfile, sim_config: SimConfig, seed_value: int = 0,
		session_mode: StringName = LaunchOptions.MODE_LEARN,
		scoring_config: ScoringConfig = null) -> void:
	options = null
	mode = session_mode
	sim = TrafficSim.new(road_profile, sim_config, seed_value)
	# Right lane at the start speed (requirements §9.3).
	player = sim.add_vehicle(0.0, 0, sim_config.start_speed_kmh / TrafficSim.KMH_PER_MPS)
	sim.player = player
	sim.collision.connect(_on_collision)
	sim.offroad.connect(_on_offroad)
	scoring = ScoringSystem.new(sim, scoring_config) if scoring_config != null else null
	state = State.INTRO
	end_reason = EndReason.NONE
	_player_end_reason = EndReason.NONE
	intro_elapsed_s = 0.0
	elapsed_s = 0.0


## Advances the session by one fixed step. The sim only runs while driving: during
## the intro and after the end it is frozen and `commands` are dropped.
func step(dt: float, commands: PlayerCommands = null) -> void:
	match state:
		State.INTRO:
			intro_elapsed_s += dt
			if intro_elapsed_s >= sim.config.countdown_s - TIME_EPSILON:
				state = State.DRIVING
				session_started.emit()
		State.DRIVING:
			sim.step(dt, commands)
			if scoring != null:
				scoring.observe(dt)
			elapsed_s += dt
			# TODO(E08-S02): in learn mode, K4 and a respawn instead of ending the session.
			if _player_end_reason != EndReason.NONE:
				_end(_player_end_reason)
			elif elapsed_s >= sim.config.session_length_s - TIME_EPSILON:
				_end(EndReason.TIME_UP)


func countdown_left_s() -> float:
	if state != State.INTRO:
		return 0.0
	return maxf(0.0, sim.config.countdown_s - intro_elapsed_s)


func time_left_s() -> float:
	if state == State.ENDED:
		return 0.0
	return maxf(0.0, sim.config.session_length_s - elapsed_s)


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


func _end(reason: EndReason) -> void:
	state = State.ENDED
	end_reason = reason
	if scoring != null:
		scoring.finish()
	session_ended.emit()


func _on_collision(vehicle_id: int, other_id: int) -> void:
	if vehicle_id == player.id or other_id == player.id:
		_player_end_reason = EndReason.COLLISION


func _on_offroad(vehicle_id: int) -> void:
	if vehicle_id == player.id and _player_end_reason == EndReason.NONE:
		_player_end_reason = EndReason.OFF_ROAD
