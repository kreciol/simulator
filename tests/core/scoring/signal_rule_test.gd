extends GdUnitTestSuite
## K3 — lane changes without a valid signal (requirements §8.2, §6.5, §16 Ocenianie;
## issue #28).

const LEFT: VehicleState.Dir = VehicleState.Dir.LEFT
const RIGHT: VehicleState.Dir = VehicleState.Dir.RIGHT

var _config: ScoringConfig
var _world: ScoringTestHelper


func before_test() -> void:
	_config = load("res://config/scoring.tres") as ScoringConfig
	_world = ScoringTestHelper.new(0, 120.0)


func _signal(dir: VehicleState.Dir, held_s: float) -> void:
	var commands: PlayerCommands = PlayerCommands.new()
	commands.signal_toggle = dir
	_world.drive(held_s, commands)


## Starts a lane change in `dir` and drives until well after it completes.
func _change_lane(dir: VehicleState.Dir) -> Array[ScoreEvent]:
	var commands: PlayerCommands = PlayerCommands.new()
	commands.lane_change = dir
	return _world.drive(3.0, commands)


func _signal_events() -> Array[ScoreEvent]:
	var found: Array[ScoreEvent] = []
	for event: ScoreEvent in _world.scoring.event_log.events:
		if event.category == SignalRule.CATEGORY:
			found.append(event)
	return found


func test_no_signal_costs_the_full_penalty_once() -> void:
	var completed: Array[ScoreEvent] = _change_lane(LEFT)
	var events: Array[ScoreEvent] = _signal_events()
	assert_int(events.size()).is_equal(1)
	assert_str(events[0].type).is_equal(SignalRule.TYPE_NONE)
	assert_float(events[0].points).is_equal(-_config.k3_penalty)
	assert_bool(events[0].is_segment).is_false()
	assert_array(completed).contains([events[0]])
	assert_int(events[0].context["lane_from"] as int).is_equal(0)
	assert_int(events[0].context["lane_to"] as int).is_equal(1)


func test_a_late_signal_costs_half() -> void:
	_signal(LEFT, 0.5)
	_change_lane(LEFT)
	var events: Array[ScoreEvent] = _signal_events()
	assert_int(events.size()).is_equal(1)
	assert_str(events[0].type).is_equal(SignalRule.TYPE_LATE)
	assert_float(events[0].points).is_equal(-_config.k3_penalty * _config.k3_late_factor)
	assert_float(events[0].context["signal_on_s"] as float).is_equal_approx(0.5, 1e-6)


func test_a_signal_in_the_wrong_direction_costs_the_full_penalty() -> void:
	_signal(RIGHT, 2.0)
	_change_lane(LEFT)
	var events: Array[ScoreEvent] = _signal_events()
	assert_int(events.size()).is_equal(1)
	assert_str(events[0].type).is_equal(SignalRule.TYPE_WRONG)
	assert_float(events[0].points).is_equal(-_config.k3_penalty)


func test_a_signal_held_for_the_minimum_costs_nothing() -> void:
	_signal(LEFT, _world.sim.config.signal_min_on_s)
	_change_lane(LEFT)
	var events: Array[ScoreEvent] = _signal_events()
	assert_int(events.size()).is_equal(1)
	assert_str(events[0].type).is_equal(SignalRule.TYPE_OK)
	assert_float(events[0].points).is_equal(0.0)
	assert_float(_world.total_for(SignalRule.CATEGORY)).is_equal(0.0)


func test_every_lane_change_is_rated_on_its_own() -> void:
	_change_lane(LEFT)
	_signal(RIGHT, 1.5)
	_change_lane(RIGHT)
	var events: Array[ScoreEvent] = _signal_events()
	assert_int(events.size()).is_equal(2)
	assert_str(events[0].type).is_equal(SignalRule.TYPE_NONE)
	assert_str(events[1].type).is_equal(SignalRule.TYPE_OK)


func test_other_vehicles_lane_changes_are_not_scored() -> void:
	var other: VehicleState = _world.add_car_ahead(0, 200.0, 120.0)
	_world.sim.request_lane_change(other, LEFT)
	_world.drive(3.0)
	assert_array(_signal_events()).is_empty()
