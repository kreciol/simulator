class_name Tutorial
extends RefCounted
## The tutorial's prompts (requirements §12, spec Phase 10 step 2): accelerate → slow
## down → signal → change lane → return right → check mirrors, each advancing once the
## player has done it, then the recap of the three rules. Reads the player after every
## sim step and never changes the sim; there is no scoring. `skip` ends it at once.

enum Step { ACCELERATE, SLOW_DOWN, SIGNAL, CHANGE_LANE, RETURN_RIGHT, CHECK_MIRRORS, DONE }

## The steps the player is prompted through, in order; `DONE` follows the last.
const STEPS: Array[Step] = [Step.ACCELERATE, Step.SLOW_DOWN, Step.SIGNAL, Step.CHANGE_LANE,
		Step.RETURN_RIGHT, Step.CHECK_MIRRORS]
## Translation key of each step's prompt.
const PROMPT_KEYS: Dictionary[Step, StringName] = {
	Step.ACCELERATE: &"TUTORIAL_ACCELERATE",
	Step.SLOW_DOWN: &"TUTORIAL_SLOW_DOWN",
	Step.SIGNAL: &"TUTORIAL_SIGNAL",
	Step.CHANGE_LANE: &"TUTORIAL_CHANGE_LANE",
	Step.RETURN_RIGHT: &"TUTORIAL_RETURN_RIGHT",
	Step.CHECK_MIRRORS: &"TUTORIAL_CHECK_MIRRORS",
}
## The right lane, where the player starts and returns to.
const RIGHT_LANE: int = 0
## Absorbs float drift when fixed steps should sum to exactly a configured duration.
const TIME_EPSILON: float = 1e-6

var config: TutorialConfig
var player: VehicleState
var step: Step = Step.ACCELERATE
## True once `skip` ended the tutorial before its last step was done.
var skipped: bool = false

## The player's speed when the current step started, km/h.
var _step_start_speed_kmh: float
## Driving time in the current step, seconds.
var _step_elapsed_s: float = 0.0


func _init(tutorial_config: TutorialConfig, tutorial_player: VehicleState) -> void:
	config = tutorial_config
	player = tutorial_player
	_begin_step(Step.ACCELERATE)


## Checks the current step after a sim step of `dt`; returns whether it was done and
## the next one began. At most one step advances per call.
func observe(dt: float) -> bool:
	if is_finished():
		return false
	_step_elapsed_s += dt
	if not _step_done():
		return false
	_begin_step(STEPS[STEPS.find(step) + 1] if step != STEPS.back() else Step.DONE)
	return true


## Ends the tutorial at once, whatever step it is on.
func skip() -> void:
	if is_finished():
		return
	skipped = true
	step = Step.DONE


func is_finished() -> bool:
	return step == Step.DONE


## The current step's place, 1-based; `step_count()` once finished.
func step_number() -> int:
	return STEPS.size() if is_finished() else STEPS.find(step) + 1


func step_count() -> int:
	return STEPS.size()


## The current step's prompt; empty once finished.
func prompt_key() -> StringName:
	return PROMPT_KEYS.get(step, &"")


func _begin_step(next: Step) -> void:
	step = next
	_step_start_speed_kmh = _speed_kmh()
	_step_elapsed_s = 0.0


func _step_done() -> bool:
	match step:
		Step.ACCELERATE:
			return _speed_kmh() >= _step_start_speed_kmh + config.speed_change_kmh
		Step.SLOW_DOWN:
			return _speed_kmh() <= maxf(0.0, _step_start_speed_kmh - config.speed_change_kmh)
		Step.SIGNAL:
			# The player is on the right lane, so the change to come is to the left.
			return player.signal_dir == VehicleState.Dir.LEFT
		Step.CHANGE_LANE:
			return not player.lane_change_active and player.lane > RIGHT_LANE
		Step.RETURN_RIGHT:
			return not player.lane_change_active and player.lane == RIGHT_LANE
		Step.CHECK_MIRRORS:
			# TODO(open): the mirrors have no input of their own, so the step points at
			# them for a while; a look-in-the-mirror input would complete it instead.
			return _step_elapsed_s >= config.mirror_check_s - TIME_EPSILON
	return false


func _speed_kmh() -> float:
	return player.speed_mps * TrafficSim.KMH_PER_MPS
