class_name SessionManager
extends Node
## Session flow (requirements §9.3, spec Architecture: Session): a 3-2-1 intro, then
## `SimConfig.session_length_s` of driving, then the end. Owns the sim and is the only
## node that drives it; views and the HUD only read its state.

signal session_started
signal session_ended

enum State { INTRO, DRIVING, ENDED }

## Absorbs float drift when fixed steps should sum to exactly a configured duration.
const TIME_EPSILON: float = 1e-6

var sim: TrafficSim
var player: VehicleState
## What the session was started with; null when set up directly through `setup`.
var options: LaunchOptions
var state: State = State.INTRO
## Time spent in the intro countdown, seconds.
var intro_elapsed_s: float = 0.0
## Session time driven so far; the timer starts when the intro ends.
var elapsed_s: float = 0.0


## Sets the session up on the launch options' profile and seed with traffic at the
## options' difficulty level, keeping the options (mode, level) for the rules that
## depend on them.
func start(launch_options: LaunchOptions, sim_config: SimConfig) -> void:
	setup(launch_options.profile, sim_config, launch_options.seed_value)
	options = launch_options
	if launch_options.difficulty != null:
		Spawner.new(launch_options.difficulty).attach(sim)


func setup(road_profile: RoadProfile, sim_config: SimConfig, seed_value: int = 0) -> void:
	options = null
	sim = TrafficSim.new(road_profile, sim_config, seed_value)
	# Right lane at the start speed (requirements §9.3).
	player = sim.add_vehicle(0.0, 0, sim_config.start_speed_kmh / TrafficSim.KMH_PER_MPS)
	sim.player = player
	state = State.INTRO
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
			elapsed_s += dt
			if elapsed_s >= sim.config.session_length_s - TIME_EPSILON:
				state = State.ENDED
				session_ended.emit()


func countdown_left_s() -> float:
	if state != State.INTRO:
		return 0.0
	return maxf(0.0, sim.config.countdown_s - intro_elapsed_s)


func time_left_s() -> float:
	if state == State.ENDED:
		return 0.0
	return maxf(0.0, sim.config.session_length_s - elapsed_s)
