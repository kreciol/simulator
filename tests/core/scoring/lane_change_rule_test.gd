extends GdUnitTestSuite
## N1 — correct lane changes and anti-farming (requirements §8.3, §16 Ocenianie;
## issue #29).

const LEFT: VehicleState.Dir = VehicleState.Dir.LEFT
const RIGHT: VehicleState.Dir = VehicleState.Dir.RIGHT

var _config: ScoringConfig
var _world: ScoringTestHelper


func before_test() -> void:
	_config = load("res://config/scoring.tres") as ScoringConfig


func _signal(dir: VehicleState.Dir, held_s: float) -> void:
	var commands: PlayerCommands = PlayerCommands.new()
	commands.signal_toggle = dir
	_world.drive(held_s, commands)


func _change_lane(dir: VehicleState.Dir, then_drive_s: float = 3.0) -> void:
	var commands: PlayerCommands = PlayerCommands.new()
	commands.lane_change = dir
	_world.drive(then_drive_s, commands)


func _n1_events() -> Array[ScoreEvent]:
	return _world.scoring.event_log.events_of_type(LaneChangeRule.TYPE)


## Player at 120 km/h on the right lane, a slow truck-speed car 100 m ahead.
func _behind_slow_car(scoring_config: ScoringConfig = null) -> void:
	_world = ScoringTestHelper.new(0, 120.0, scoring_config)
	_world.add_car_ahead(0, 100.0, 80.0)


func _overtake_and_return() -> void:
	_signal(LEFT, 1.5)
	_change_lane(LEFT)
	_world.drive(10.0)
	_signal(RIGHT, 1.5)
	_change_lane(RIGHT)


func test_a_signalled_overtake_and_return_are_each_rewarded_once() -> void:
	_behind_slow_car()
	_overtake_and_return()
	var events: Array[ScoreEvent] = _n1_events()
	assert_array(events).has_size(2)
	assert_str(events[0].context["reason"] as StringName).is_equal(LaneChangeRule.REASON_OVERTAKE)
	assert_str(events[1].context["reason"] as StringName).is_equal(LaneChangeRule.REASON_RETURN)
	for event: ScoreEvent in events:
		assert_float(event.points).is_equal(_config.n1_reward)
		assert_str(event.category).is_equal(LaneChangeRule.CATEGORY)


func test_the_reward_comes_when_the_change_completes() -> void:
	_behind_slow_car()
	_signal(LEFT, 1.5)
	var commands: PlayerCommands = PlayerCommands.new()
	commands.lane_change = LEFT
	_world.drive(1.0, commands)
	assert_array(_n1_events()).is_empty()
	_world.drive(1.0)
	assert_array(_n1_events()).has_size(1)
	assert_int(_world.player.lane).is_equal(1)


## Requirements §16: a signal on for at least the minimum (1 s) earns N1 — the same
## boundary at which K3 stops (issue #47).
func test_a_signal_held_for_exactly_the_minimum_earns_the_reward() -> void:
	_behind_slow_car()
	_signal(LEFT, _world.sim.config.signal_min_on_s)
	_change_lane(LEFT)
	assert_array(_n1_events()).has_size(1)


func test_a_late_signal_earns_no_reward() -> void:
	_behind_slow_car()
	_signal(LEFT, 0.5)
	_change_lane(LEFT)
	assert_array(_n1_events()).is_empty()


func test_no_reward_into_an_occupied_lane() -> void:
	_behind_slow_car()
	# A car on the left lane just behind the player, inside the clearance.
	_world.sim.add_vehicle(_world.player.s - 8.0, 1, _world.player.speed_mps)
	_signal(LEFT, 1.5)
	_change_lane(LEFT)
	assert_array(_n1_events()).is_empty()


func test_no_reward_inside_the_cooldown() -> void:
	var config: ScoringConfig = ScoringTestHelper.scoring_config_copy()
	config.n1_cooldown_s = 60.0
	_behind_slow_car(config)
	_overtake_and_return()
	var events: Array[ScoreEvent] = _n1_events()
	assert_array(events).has_size(1)
	assert_str(events[0].context["reason"] as StringName).is_equal(LaneChangeRule.REASON_OVERTAKE)


func test_an_aimless_change_left_and_back_earns_nothing() -> void:
	_world = ScoringTestHelper.new(0, 120.0)
	_signal(LEFT, 1.5)
	_change_lane(LEFT)
	_world.drive(_config.n1_cooldown_s)
	_signal(RIGHT, 1.5)
	_change_lane(RIGHT)
	assert_array(_n1_events()).is_empty()
	assert_array(_world.scoring.event_log.events_of_type(SignalRule.TYPE_OK)).has_size(2)


func test_no_reward_for_a_change_off_the_road() -> void:
	_world = ScoringTestHelper.new(1, 120.0)
	_world.add_car_ahead(1, 100.0, 80.0)
	_signal(LEFT, 1.5)
	_change_lane(LEFT)
	assert_bool(_world.player.off_road).is_true()
	assert_array(_n1_events()).is_empty()


func test_repeated_pointless_lane_changes_do_not_raise_the_score() -> void:
	_world = ScoringTestHelper.new(0, 120.0)
	for cycle: int in 10:
		_signal(LEFT, 1.5)
		_change_lane(LEFT, 2.0)
		_world.drive(1.0)
		_signal(RIGHT, 1.5)
		_change_lane(RIGHT, 2.0)
		_world.drive(1.0)
	_world.scoring.finish()
	var steady: ScoringTestHelper = ScoringTestHelper.new(0, 120.0)
	steady.drive(_world.sim.time_s)
	steady.scoring.finish()

	assert_float(_world.total_of_type(LaneChangeRule.TYPE)).is_equal(0.0)
	assert_float(_world.scoring.event_log.total()).is_less(steady.scoring.event_log.total())


## Overtakes the slow car, then the player is put back on the right lane with the car
## gone; an aimless change left and back follows.
func _overtake_respawn_and_swing(restart: bool) -> void:
	_behind_slow_car()
	var slow_car: VehicleState = _world.sim.vehicles[1]
	_signal(LEFT, 1.5)
	_change_lane(LEFT)
	_world.sim.remove_vehicle(slow_car)
	Respawn.respawn_player(_world.sim)
	if restart:
		_world.scoring.restart_after_respawn()
	_world.drive(_config.n1_cooldown_s)
	_signal(LEFT, 1.5)
	_change_lane(LEFT)
	_world.drive(_config.n1_cooldown_s)
	_signal(RIGHT, 1.5)
	_change_lane(RIGHT)


func test_a_respawn_forgets_the_overtake_so_a_later_right_change_is_no_return() -> void:
	_overtake_respawn_and_swing(true)
	var events: Array[ScoreEvent] = _n1_events()
	assert_array(events).has_size(1)
	assert_str(events[0].context["reason"] as StringName).is_equal(LaneChangeRule.REASON_OVERTAKE)


func test_without_the_reset_the_interrupted_overtake_would_reward_the_swing() -> void:
	_overtake_respawn_and_swing(false)
	assert_array(_n1_events()).has_size(2)
