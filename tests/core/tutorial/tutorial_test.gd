extends GdUnitTestSuite
## The tutorial's prompts state machine (issue #45, requirements §12, spec Phase 10
## step 2): accelerate → slow down → signal → change lane → return right → check
## mirrors, each advancing only once done; skipping ends it at once.

const DT: float = 1.0 / 60.0

var _config: TutorialConfig
var _player: VehicleState


func before_test() -> void:
	_config = load("res://config/tutorial.tres") as TutorialConfig
	_player = VehicleState.new()
	_player.lane = Tutorial.RIGHT_LANE
	_set_speed_kmh(100.0)


func _set_speed_kmh(kmh: float) -> void:
	_player.speed_mps = kmh / TrafficSim.KMH_PER_MPS


func test_the_config_loads() -> void:
	assert_float(_config.speed_change_kmh).is_greater(0.0)
	assert_float(_config.mirror_check_s).is_greater(0.0)


func test_it_prompts_the_six_steps_of_section_12_in_order() -> void:
	assert_array(Tutorial.STEPS).contains_exactly([Tutorial.Step.ACCELERATE, Tutorial.Step.SLOW_DOWN,
			Tutorial.Step.SIGNAL, Tutorial.Step.CHANGE_LANE, Tutorial.Step.RETURN_RIGHT,
			Tutorial.Step.CHECK_MIRRORS])
	for step: Tutorial.Step in Tutorial.STEPS:
		assert_bool(Tutorial.PROMPT_KEYS.has(step)).is_true()


func test_it_starts_on_accelerate() -> void:
	var tutorial: Tutorial = Tutorial.new(_config, _player)
	assert_int(tutorial.step).is_equal(Tutorial.Step.ACCELERATE)
	assert_int(tutorial.step_number()).is_equal(1)
	assert_int(tutorial.step_count()).is_equal(6)
	assert_str(tutorial.prompt_key()).is_equal("TUTORIAL_ACCELERATE")
	assert_bool(tutorial.is_finished()).is_false()


func test_each_step_advances_only_once_done() -> void:
	var tutorial: Tutorial = Tutorial.new(_config, _player)

	# Accelerate: not yet just below the target, done at it.
	_set_speed_kmh(100.0 + _config.speed_change_kmh - 1.0)
	assert_bool(tutorial.observe(DT)).is_false()
	_set_speed_kmh(100.0 + _config.speed_change_kmh)
	assert_bool(tutorial.observe(DT)).is_true()
	assert_int(tutorial.step).is_equal(Tutorial.Step.SLOW_DOWN)

	# Slow down: measured from the speed the step started at.
	var reached: float = 100.0 + _config.speed_change_kmh
	_set_speed_kmh(reached - _config.speed_change_kmh + 1.0)
	assert_bool(tutorial.observe(DT)).is_false()
	_set_speed_kmh(reached - _config.speed_change_kmh)
	assert_bool(tutorial.observe(DT)).is_true()
	assert_int(tutorial.step).is_equal(Tutorial.Step.SIGNAL)

	# Signal: the right one does not count, the left one does.
	_player.signal_dir = VehicleState.Dir.RIGHT
	assert_bool(tutorial.observe(DT)).is_false()
	_player.signal_dir = VehicleState.Dir.LEFT
	assert_bool(tutorial.observe(DT)).is_true()
	assert_int(tutorial.step).is_equal(Tutorial.Step.CHANGE_LANE)

	# Change lane: done once the change to the left has finished.
	_player.lane_change_active = true
	_player.lane_change_from = 0
	_player.lane_change_to = 1
	assert_bool(tutorial.observe(DT)).is_false()
	_player.lane_change_active = false
	_player.lane = 1
	_player.signal_dir = VehicleState.Dir.NONE
	assert_bool(tutorial.observe(DT)).is_true()
	assert_int(tutorial.step).is_equal(Tutorial.Step.RETURN_RIGHT)

	# Return right: done once back on the right lane.
	assert_bool(tutorial.observe(DT)).is_false()
	_player.lane_change_active = true
	_player.lane_change_from = 1
	_player.lane_change_to = 0
	assert_bool(tutorial.observe(DT)).is_false()
	_player.lane_change_active = false
	_player.lane = 0
	assert_bool(tutorial.observe(DT)).is_true()
	assert_int(tutorial.step).is_equal(Tutorial.Step.CHECK_MIRRORS)

	# Check mirrors: done after the configured time.
	var steps: int = 0
	while not tutorial.observe(DT):
		steps += 1
		assert_int(steps).is_less(10000)
	assert_int(steps + 1).is_equal(roundi(_config.mirror_check_s / DT))
	assert_bool(tutorial.is_finished()).is_true()
	assert_bool(tutorial.skipped).is_false()
	assert_str(tutorial.prompt_key()).is_empty()


func test_at_most_one_step_advances_per_observation() -> void:
	var tutorial: Tutorial = Tutorial.new(_config, _player)
	# Fast enough for accelerate and already signalling: only accelerate is done now.
	_set_speed_kmh(100.0 + 2.0 * _config.speed_change_kmh)
	_player.signal_dir = VehicleState.Dir.LEFT
	tutorial.observe(DT)
	assert_int(tutorial.step).is_equal(Tutorial.Step.SLOW_DOWN)


func test_slowing_down_never_asks_for_a_speed_below_zero() -> void:
	var tutorial: Tutorial = Tutorial.new(_config, _player)
	# The slow-down step starts slower than the change it asks for.
	_set_speed_kmh(_config.speed_change_kmh / 2.0)
	tutorial._begin_step(Tutorial.Step.SLOW_DOWN)
	assert_bool(tutorial.observe(DT)).is_false()
	_set_speed_kmh(0.0)
	assert_bool(tutorial.observe(DT)).is_true()


func test_skipping_ends_it_at_once() -> void:
	var tutorial: Tutorial = Tutorial.new(_config, _player)
	tutorial.skip()
	assert_bool(tutorial.is_finished()).is_true()
	assert_bool(tutorial.skipped).is_true()
	assert_bool(tutorial.observe(DT)).is_false()
	assert_int(tutorial.step_number()).is_equal(tutorial.step_count())


func test_skipping_a_finished_tutorial_keeps_it_finished_not_skipped() -> void:
	var tutorial: Tutorial = Tutorial.new(_config, _player)
	tutorial.step = Tutorial.Step.DONE
	tutorial.skip()
	assert_bool(tutorial.skipped).is_false()


func test_driving_the_steps_through_the_sim_finishes_it() -> void:
	# The real sim on an empty road, driven by commands as the player would.
	var sim_config: SimConfig = load("res://config/sim_config.tres") as SimConfig
	var road: RoadProfile = load("res://config/road_profiles/motorway.tres") as RoadProfile
	var sim: TrafficSim = TrafficSim.new(road, sim_config, 1)
	var player: VehicleState = sim.add_vehicle(0.0, 0, sim_config.start_speed_kmh / TrafficSim.KMH_PER_MPS)
	sim.player = player
	var tutorial: Tutorial = Tutorial.new(_config, player)
	var steps: int = 0
	while not tutorial.is_finished():
		steps += 1
		assert_int(steps).is_less(60 * 120)
		sim.step(DT, _commands_for(tutorial.step, player))
		tutorial.observe(DT)
	assert_bool(tutorial.skipped).is_false()
	assert_int(player.lane).is_equal(Tutorial.RIGHT_LANE)
	assert_bool(player.off_road).is_false()


## What a player following the prompt presses this step.
func _commands_for(step: Tutorial.Step, player: VehicleState) -> PlayerCommands:
	match step:
		Tutorial.Step.ACCELERATE:
			return PlayerCommands.create(VehicleState.Longitudinal.ACCELERATE)
		Tutorial.Step.SLOW_DOWN:
			return PlayerCommands.create(VehicleState.Longitudinal.BRAKE)
		Tutorial.Step.SIGNAL:
			return PlayerCommands.create(VehicleState.Longitudinal.NONE, VehicleState.Dir.NONE,
					VehicleState.Dir.LEFT if player.signal_dir != VehicleState.Dir.LEFT else VehicleState.Dir.NONE)
		Tutorial.Step.CHANGE_LANE:
			if not player.lane_change_active and player.lane == Tutorial.RIGHT_LANE:
				return PlayerCommands.create(VehicleState.Longitudinal.NONE, VehicleState.Dir.LEFT)
		Tutorial.Step.RETURN_RIGHT:
			if not player.lane_change_active and player.lane > Tutorial.RIGHT_LANE:
				var toggle: VehicleState.Dir = VehicleState.Dir.RIGHT \
						if player.signal_dir != VehicleState.Dir.RIGHT else VehicleState.Dir.NONE
				return PlayerCommands.create(VehicleState.Longitudinal.NONE, VehicleState.Dir.RIGHT, toggle)
	return PlayerCommands.create(VehicleState.Longitudinal.NONE)
