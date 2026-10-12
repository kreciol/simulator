extends GdUnitTestSuite
## Learn-mode hints (requirements §11.2, spec Phase 8 step 1; issue #37): preventive
## hints before a penalty, event messages after a lane change, live numbers, rate
## limits per type and on screen.

const DT: float = ScoringTestHelper.DT
const LEFT: VehicleState.Dir = VehicleState.Dir.LEFT
const RIGHT: VehicleState.Dir = VehicleState.Dir.RIGHT

var _feedback: FeedbackConfig
var _world: ScoringTestHelper
var _engine: HintEngine
## Every hint shown so far, in order.
var _shown: Array[Hint] = []


func before_test() -> void:
	_feedback = load("res://config/feedback.tres") as FeedbackConfig
	_shown = []


## A world with the player on `lane` at `speed_kmh` and an engine observing it.
func _setup(lane: int, speed_kmh: float, feedback: FeedbackConfig = null,
		scoring_config: ScoringConfig = null) -> void:
	_world = ScoringTestHelper.new(lane, speed_kmh, scoring_config)
	_engine = HintEngine.new(_world.sim, _world.scoring, feedback if feedback != null else _feedback)
	_engine.hint_shown.connect(func(hint: Hint) -> void: _shown.append(hint))


## Steps sim, scoring and hints as `SessionManager` does, for `seconds`.
func _drive(seconds: float, commands: PlayerCommands = null) -> void:
	for i: int in roundi(seconds / DT):
		_world.sim.step(DT, commands if i == 0 else null)
		_engine.observe(_world.scoring.observe(DT))


func _signal(dir: VehicleState.Dir, held_s: float) -> void:
	var commands: PlayerCommands = PlayerCommands.new()
	commands.signal_toggle = dir
	_drive(held_s, commands)


func _start_lane_change(dir: VehicleState.Dir) -> void:
	var commands: PlayerCommands = PlayerCommands.new()
	commands.lane_change = dir
	_drive(DT, commands)


func _keys_on_screen() -> Array[StringName]:
	var keys: Array[StringName] = []
	for hint: Hint in _engine.hints:
		keys.append(hint.line.key)
	return keys


func _shown_of_type(type: StringName) -> Array[Hint]:
	var found: Array[Hint] = []
	for hint: Hint in _shown:
		if hint.type == type:
			found.append(hint)
	return found


static func _text(line: FeedbackLine) -> String:
	return TranslationServer.translate(line.key).format(line.args)


func _feedback_copy() -> FeedbackConfig:
	return _feedback.duplicate() as FeedbackConfig


func test_keep_right_hint_shows_as_the_grace_starts_before_any_penalty() -> void:
	_setup(1, 120.0)
	_drive(DT)
	assert_array(_keys_on_screen()).contains([HintEngine.KEEP_RIGHT])
	assert_float(_world.scoring.keep_right_rule.grace_remaining_s()).is_greater(0.0)
	assert_float(_world.total_of_type(KeepRightRule.TYPE)).is_equal(0.0)
	assert_str(_text(_engine.hints[0].line)).is_equal("Prawy pas jest wolny, wróć na prawo.")


func test_gap_hint_states_speed_minimum_and_actual_gap() -> void:
	_setup(0, 120.0)
	_world.add_car_ahead(0, 35.4, 120.0)
	_drive(DT)
	var hints: Array[Hint] = _shown_of_type(HintEngine.TYPE_GAP_TOO_SMALL)
	assert_int(hints.size()).is_equal(1)
	assert_dict(hints[0].line.args).is_equal({"speed": 120, "min_gap": 60, "gap": 35})
	assert_str(_text(hints[0].line)).is_equal("Za blisko. Przy 120 km/h minimum to 60 m, masz 35 m.")
	assert_bool(hints[0].positive).is_false()


func test_gap_closing_on_a_slower_leader_warns_before_the_minimum() -> void:
	_setup(0, 120.0)
	_world.add_car_ahead(0, 65.0, 100.0)
	_drive(DT)
	assert_array(_keys_on_screen()).contains([HintEngine.GAP_CLOSING])
	assert_array(_keys_on_screen()).not_contains([HintEngine.GAP_TOO_SMALL])
	assert_float(_world.total_of_type(GapRule.TYPE)).is_equal(0.0)


func test_no_gap_hint_when_the_leader_is_far_or_not_slower() -> void:
	_setup(0, 120.0)
	_world.add_car_ahead(0, 65.0, 130.0)
	_world.add_car_ahead(1, 30.0, 120.0)
	_drive(1.0)
	assert_array(_shown_of_type(HintEngine.TYPE_GAP_CLOSING)).is_empty()
	assert_array(_shown_of_type(HintEngine.TYPE_GAP_TOO_SMALL)).is_empty()


func test_speeding_hint_names_the_limit_while_s1_is_on() -> void:
	_setup(0, 150.0)
	_drive(DT)
	var hints: Array[Hint] = _shown_of_type(HintEngine.TYPE_SPEEDING)
	assert_int(hints.size()).is_equal(1)
	assert_dict(hints[0].line.args).is_equal({"limit": 140, "speed": 150})


func test_no_speeding_hint_with_s1_off() -> void:
	var scoring_config: ScoringConfig = ScoringTestHelper.scoring_config_copy()
	scoring_config.speed_rule_enabled = false
	_setup(0, 150.0, null, scoring_config)
	_drive(1.0)
	assert_array(_shown_of_type(HintEngine.TYPE_SPEEDING)).is_empty()


func test_correct_signal_is_confirmed_when_the_lane_change_completes() -> void:
	_setup(0, 120.0)
	_signal(LEFT, 1.5)
	_start_lane_change(LEFT)
	_drive(1.0)
	assert_array(_shown_of_type(SignalRule.TYPE_OK)).is_empty()
	_drive(1.5)
	var hints: Array[Hint] = _shown_of_type(SignalRule.TYPE_OK)
	assert_int(hints.size()).is_equal(1)
	assert_object(hints[0].line.key).is_equal(HintEngine.SIGNAL_OK)
	assert_bool(hints[0].positive).is_true()


func test_missing_signal_is_named_when_the_lane_change_completes() -> void:
	_setup(0, 120.0)
	_start_lane_change(LEFT)
	_drive(2.5)
	var hints: Array[Hint] = _shown_of_type(SignalRule.TYPE_NONE)
	assert_int(hints.size()).is_equal(1)
	assert_str(_text(hints[0].line)).is_equal(
			"Zmiana pasa w lewo bez kierunkowskazu — włącz lewy kierunkowskaz przed manewrem.")


func test_message_names_the_side_of_a_late_or_wrong_signal(
		signal_dir: VehicleState.Dir, held_s: float, expected: StringName, test_parameters: Array = [
			[RIGHT, 0.3, &"HINT_SIGNAL_LATE_RIGHT"],
			[LEFT, 1.5, &"HINT_SIGNAL_WRONG_RIGHT"],
		]) -> void:
	_setup(1, 120.0)
	_signal(signal_dir, held_s)
	_start_lane_change(RIGHT)
	_drive(2.5)
	var keys: Array[StringName] = []
	for hint: Hint in _shown:
		keys.append(hint.line.key)
	assert_array(keys).contains([expected])


func test_late_signal_message_states_the_minimum_time() -> void:
	_setup(0, 120.0)
	_signal(LEFT, 0.3)
	_start_lane_change(LEFT)
	_drive(2.5)
	var hints: Array[Hint] = _shown_of_type(SignalRule.TYPE_LATE)
	assert_int(hints.size()).is_equal(1)
	assert_str(_text(hints[0].line)).is_equal(
			"Lewy kierunkowskaz włączony za późno — włącz go co najmniej 1 s przed zmianą pasa.")


func test_repeated_events_of_one_type_are_not_repeated_within_the_cooldown() -> void:
	_setup(0, 120.0)
	_start_lane_change(LEFT)
	_drive(2.5)
	_start_lane_change(RIGHT)
	_drive(2.5)
	assert_float(_world.sim.time_s).is_less(_feedback.hint_cooldown_s)
	assert_int(_world.scoring.event_log.events_of_type(SignalRule.TYPE_NONE).size()).is_equal(2)
	assert_int(_shown_of_type(SignalRule.TYPE_NONE).size()).is_equal(1)


func test_a_lasting_condition_is_hinted_again_only_after_the_cooldown() -> void:
	_setup(1, 120.0)
	_drive(_feedback.hint_duration_s + 0.5)
	assert_array(_engine.hints).is_empty()
	assert_int(_shown_of_type(HintEngine.TYPE_KEEP_RIGHT).size()).is_equal(1)
	_drive(_feedback.hint_cooldown_s - _feedback.hint_duration_s)
	assert_int(_shown_of_type(HintEngine.TYPE_KEEP_RIGHT).size()).is_equal(2)


func test_no_more_than_the_maximum_on_screen() -> void:
	assert_int(_feedback.hint_max_on_screen).is_equal(2)
	# Left lane with the right one free (K2), a car close ahead (K1) and above the limit.
	_setup(1, 150.0)
	_world.add_car_ahead(1, 30.0, 150.0)
	_drive(DT)
	assert_int(_shown.size()).is_equal(3)
	assert_int(_engine.hints.size()).is_equal(2)
	# The oldest gave way to the newest.
	assert_array(_keys_on_screen()).is_equal([HintEngine.GAP_TOO_SMALL, HintEngine.SPEEDING])


func test_the_maximum_on_screen_comes_from_the_config() -> void:
	var feedback: FeedbackConfig = _feedback_copy()
	feedback.hint_max_on_screen = 1
	_setup(1, 150.0, feedback)
	_world.add_car_ahead(1, 30.0, 150.0)
	_drive(DT)
	assert_int(_engine.hints.size()).is_equal(1)


func test_clear_takes_every_hint_off_the_screen() -> void:
	_setup(1, 150.0)
	_drive(DT)
	assert_array(_engine.hints).is_not_empty()
	_engine.clear()
	assert_array(_engine.hints).is_empty()


func test_hints_never_change_the_score() -> void:
	var plain: ScoringTestHelper = ScoringTestHelper.new(1, 150.0)
	plain.add_car_ahead(1, 30.0, 150.0)
	plain.drive(3.0)
	_setup(1, 150.0)
	_world.add_car_ahead(1, 30.0, 150.0)
	_drive(3.0)
	assert_float(_world.scoring.event_log.total()).is_equal_approx(plain.scoring.event_log.total(), 1e-9)


func test_every_hint_text_is_translated_and_gender_neutral() -> void:
	var keys: Array[StringName] = [HintEngine.KEEP_RIGHT, HintEngine.GAP_TOO_SMALL,
			HintEngine.GAP_CLOSING, HintEngine.SPEEDING, HintEngine.SIGNAL_OK]
	for by_dir: Dictionary in HintEngine.SIGNAL_MESSAGES.values():
		for key: StringName in by_dir.values():
			keys.append(key)
	var gendered: RegEx = RegEx.create_from_string(
			"\\p{L}(łem|łam|łeś|łaś|łbym|łabym|łbyś|łabyś)(?!\\p{L})")
	for key: StringName in keys:
		var text: String = TranslationServer.translate(key)
		assert_str(text).override_failure_message("untranslated: %s" % key).is_not_equal(String(key))
		assert_object(gendered.search(text)).override_failure_message("%s: %s" % [key, text]).is_null()
		assert_bool(text.contains("!")).override_failure_message("%s: %s" % [key, text]).is_false()


func test_seconds_read_as_polish_numbers() -> void:
	assert_str(HintEngine.seconds_text(1.0)).is_equal("1")
	assert_str(HintEngine.seconds_text(1.5)).is_equal("1,5")
	assert_str(HintEngine.seconds_text(2.04)).is_equal("2")
