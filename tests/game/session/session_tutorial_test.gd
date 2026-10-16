extends GdUnitTestSuite
## The tutorial session (issue #45, requirements §12, spec Phase 10 step 2): an empty
## road with no scoring, hints or time limit, ending once the steps are done or at once
## when skipped.

const DT: float = 1.0 / 60.0

var _config: SimConfig
var _launcher: DevLauncherConfig
var _session: SessionManager
var _ended: Array[int] = [0]


func before_test() -> void:
	_config = load("res://config/sim_config.tres") as SimConfig
	_launcher = load("res://config/dev_launcher.tres") as DevLauncherConfig
	_ended = [0]
	_session = auto_free(SessionManager.new()) as SessionManager
	# As in the main scene: scoring and feedback configured, which the tutorial ignores.
	_session.scoring_config = load("res://config/scoring.tres") as ScoringConfig
	_session.feedback_config = load("res://config/feedback.tres") as FeedbackConfig
	_session.tutorial_config = load("res://config/tutorial.tres") as TutorialConfig
	_session.start(SessionSetup.tutorial_options(_launcher, 3), _config)
	_session.session_ended.connect(func() -> void: _ended[0] += 1)


func _step(steps: int, commands: PlayerCommands = null) -> void:
	for i: int in steps:
		_session.step(DT, commands)


func _past_countdown() -> void:
	_step(roundi(_config.countdown_s / DT))
	assert_int(_session.state).is_equal(SessionManager.State.DRIVING)


func test_the_tutorial_is_a_learn_session_on_an_empty_road_with_no_scoring() -> void:
	assert_bool(_session.is_tutorial()).is_true()
	assert_object(_session.tutorial).is_not_null()
	assert_bool(_session.is_exam()).is_false()
	assert_object(_session.sim.spawner).is_null()
	assert_int(_session.sim.vehicles.size()).is_equal(1)
	assert_object(_session.scoring).is_null()
	assert_object(_session.hint_engine).is_null()
	_past_countdown()
	_step(600)
	assert_int(_session.sim.vehicles.size()).is_equal(1)


func test_a_normal_session_is_not_a_tutorial() -> void:
	var session: SessionManager = auto_free(SessionManager.new()) as SessionManager
	session.tutorial_config = load("res://config/tutorial.tres") as TutorialConfig
	session.start(DevLauncher.resolve({}, _launcher, 1), _config)
	assert_bool(session.is_tutorial()).is_false()
	assert_object(session.tutorial).is_null()
	assert_object(session.sim.spawner).is_not_null()


func test_the_prompts_advance_while_driving_only() -> void:
	var accelerate: PlayerCommands = PlayerCommands.create(VehicleState.Longitudinal.ACCELERATE)
	# Frozen through the countdown: nothing to advance.
	_step(roundi(_config.countdown_s / DT) - 1, accelerate)
	assert_int(_session.tutorial.step).is_equal(Tutorial.Step.ACCELERATE)
	_step(1)
	_step(roundi(10.0 / DT), accelerate)
	assert_int(_session.tutorial.step).is_equal(Tutorial.Step.SLOW_DOWN)


func test_the_tutorial_has_no_time_limit() -> void:
	_past_countdown()
	_step(roundi((_config.session_length_s + 5.0) / DT))
	assert_int(_session.state).is_equal(SessionManager.State.DRIVING)
	assert_int(_ended[0]).is_equal(0)


func test_it_ends_once_the_last_step_is_done() -> void:
	_past_countdown()
	_session.tutorial._begin_step(Tutorial.Step.CHECK_MIRRORS)
	var config: TutorialConfig = _session.tutorial_config
	_step(roundi(config.mirror_check_s / DT) - 1)
	assert_int(_session.state).is_equal(SessionManager.State.DRIVING)
	_step(1)
	assert_int(_session.state).is_equal(SessionManager.State.ENDED)
	assert_int(_session.end_reason).is_equal(SessionManager.EndReason.TUTORIAL_OVER)
	assert_bool(_session.tutorial.skipped).is_false()
	assert_int(_ended[0]).is_equal(1)
	# Nothing is scored or recorded.
	assert_object(_session.record).is_null()
	assert_object(_session.summary).is_null()


func test_skipping_ends_it_at_once_from_any_state() -> void:
	# During the countdown.
	_session.skip_tutorial()
	assert_int(_session.state).is_equal(SessionManager.State.ENDED)
	assert_int(_session.end_reason).is_equal(SessionManager.EndReason.TUTORIAL_OVER)
	assert_bool(_session.tutorial.skipped).is_true()
	assert_int(_ended[0]).is_equal(1)
	# Once ended, skipping again does nothing.
	_session.skip_tutorial()
	assert_int(_ended[0]).is_equal(1)


func test_skipping_while_paused_ends_it_too() -> void:
	_past_countdown()
	_session.pause()
	_session.skip_tutorial()
	assert_int(_session.state).is_equal(SessionManager.State.ENDED)
	assert_bool(_session.paused).is_false()
	assert_bool(_session.tutorial.skipped).is_true()


func test_skipping_outside_the_tutorial_does_nothing() -> void:
	var session: SessionManager = auto_free(SessionManager.new()) as SessionManager
	session.setup(load("res://config/road_profiles/motorway.tres") as RoadProfile, _config)
	session.skip_tutorial()
	assert_int(session.state).is_equal(SessionManager.State.INTRO)


func test_leaving_the_road_puts_the_player_back_and_the_tutorial_goes_on() -> void:
	_past_countdown()
	# Off the right edge: a learn respawn, not the end.
	_session.step(DT, PlayerCommands.create(VehicleState.Longitudinal.NONE, VehicleState.Dir.RIGHT))
	_step(roundi((_config.lane_change_duration_s + _config.respawn_fade_s) / DT) + 2)
	assert_int(_session.respawn_count).is_equal(1)
	assert_int(_session.state).is_equal(SessionManager.State.DRIVING)
	assert_int(_ended[0]).is_equal(0)
	assert_int(_session.player.lane).is_equal(0)
