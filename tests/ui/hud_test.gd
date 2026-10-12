extends GdUnitTestSuite
## Driving HUD: speed, limit, blinking signal arrows, time left, countdown and the
## end notice (issue #8 acceptance criteria, spec Phase 3 step 3).

const DT: float = 1.0 / 60.0

var _view: ViewConfig
var _session: SessionManager
var _hud: Hud


func before_test() -> void:
	_view = load("res://config/view_config.tres") as ViewConfig
	_session = _new_session("res://config/road_profiles/motorway.tres")
	_hud = auto_free(Hud.new()) as Hud
	add_child(_hud)
	_hud.setup(_view)
	_hud.update(_session)


func _new_session(profile_path: String) -> SessionManager:
	var session: SessionManager = auto_free(SessionManager.new()) as SessionManager
	session.setup(load(profile_path) as RoadProfile, load("res://config/sim_config.tres") as SimConfig)
	return session


func _step(duration_s: float, commands: PlayerCommands = null) -> void:
	for i: int in roundi(duration_s / DT):
		_session.step(DT, commands)
	_hud.update(_session)


func _finish_countdown() -> void:
	_step(_session.sim.config.countdown_s)


func test_speed_is_shown_in_kmh() -> void:
	assert_str(_hud.speed_label.text).is_equal("100")
	assert_str(_hud.unit_label.text).is_equal("km/h")
	_finish_countdown()
	_step(1.0, PlayerCommands.create(VehicleState.Longitudinal.ACCELERATE, VehicleState.Dir.NONE, VehicleState.Dir.NONE))
	var kmh: int = roundi(_session.player.speed_mps * TrafficSim.KMH_PER_MPS)
	assert_int(kmh).is_greater(100)
	assert_str(_hud.speed_label.text).is_equal(str(kmh))


func test_limit_is_the_road_profiles(profile_path: String, limit: String, test_parameters: Array = [
		["res://config/road_profiles/motorway.tres", "140"],
		["res://config/road_profiles/expressway.tres", "120"],
		]) -> void:
	_hud.update(_new_session(profile_path))
	assert_str(_hud.limit_label.text).is_equal(limit)


func test_expressway_from_the_url_shows_a_120_limit() -> void:
	var launcher: DevLauncherConfig = load("res://config/dev_launcher.tres") as DevLauncherConfig
	var options: LaunchOptions = DevLauncher.resolve(DevLauncher.parse_query("?profile=expressway"), launcher, 0)
	var session: SessionManager = auto_free(SessionManager.new()) as SessionManager
	session.start(options, load("res://config/sim_config.tres") as SimConfig)
	_hud.update(session)
	assert_str(_hud.limit_label.text).is_equal("120")

func test_signal_arrow_blinks_on_its_side_only() -> void:
	_finish_countdown()
	assert_object(_hud.signal_left.color).is_equal(Hud.ARROW_OFF)
	assert_object(_hud.signal_right.color).is_equal(Hud.ARROW_OFF)

	_session.sim.toggle_signal(_session.player, VehicleState.Dir.LEFT)
	_hud.update(_session)
	assert_object(_hud.signal_left.color).is_equal(Hud.ARROW_ON)
	assert_object(_hud.signal_right.color).is_equal(Hud.ARROW_OFF)
	# Dark in the second half of the blink period, lit again in the next one.
	var half_period: float = 0.5 / _view.signal_blink_hz
	_step(half_period * 1.5)
	assert_object(_hud.signal_left.color).is_equal(Hud.ARROW_OFF)
	_step(half_period)
	assert_object(_hud.signal_left.color).is_equal(Hud.ARROW_ON)
	assert_object(_hud.signal_right.color).is_equal(Hud.ARROW_OFF)

	_session.sim.toggle_signal(_session.player, VehicleState.Dir.RIGHT)
	_hud.update(_session)
	assert_object(_hud.signal_left.color).is_equal(Hud.ARROW_OFF)
	assert_object(_hud.signal_right.color).is_equal(Hud.ARROW_ON)


func test_time_left_counts_down_from_the_session_length() -> void:
	assert_str(_hud.time_label.text).is_equal("1:30")
	# The countdown does not touch the session timer.
	_finish_countdown()
	assert_str(_hud.time_label.text).is_equal("1:30")
	_step(1.0)
	assert_str(_hud.time_label.text).is_equal("1:29")
	_step(59.5)
	assert_str(_hud.time_label.text).is_equal("0:30")
	_step(29.5)
	assert_str(_hud.time_label.text).is_equal("0:00")
	assert_int(_session.state).is_equal(SessionManager.State.ENDED)


func test_format_time(seconds: float, text: String, test_parameters: Array = [
		[90.0, "1:30"],
		[89.99, "1:30"],
		[61.0, "1:01"],
		[60.5, "1:01"],
		[9.0, "0:09"],
		[0.01, "0:01"],
		[0.0, "0:00"],
		]) -> void:
	assert_str(Hud.format_time(seconds)).is_equal(text)


func test_countdown_shows_three_two_one_then_hides() -> void:
	assert_bool(_hud.countdown_label.visible).is_true()
	assert_str(_hud.countdown_label.text).is_equal("3")
	_step(1.0)
	assert_str(_hud.countdown_label.text).is_equal("2")
	_step(1.0)
	assert_str(_hud.countdown_label.text).is_equal("1")
	assert_bool(_hud.ended_label.visible).is_false()
	_step(1.0)
	assert_int(_session.state).is_equal(SessionManager.State.DRIVING)
	assert_bool(_hud.countdown_label.visible).is_false()


func test_end_notice_shows_only_after_the_session_ends() -> void:
	_finish_countdown()
	_step(_session.sim.config.session_length_s - 1.0)
	assert_bool(_hud.ended_label.visible).is_false()
	assert_bool(_hud.ended_screen.visible).is_false()
	_step(1.0)
	assert_bool(_hud.ended_label.visible).is_true()
	assert_bool(_hud.ended_screen.visible).is_true()
	assert_bool(_hud.ended_label.is_visible_in_tree()).is_true()
	assert_str(_hud.ended_label.text).is_equal("Koniec sesji")
	assert_bool(_hud.countdown_label.visible).is_false()
	assert_bool(_hud.ended_cause_label.visible).is_false()


func _new_exam() -> void:
	_session = auto_free(SessionManager.new()) as SessionManager
	_session.setup(load("res://config/road_profiles/motorway.tres") as RoadProfile,
			load("res://config/sim_config.tres") as SimConfig, 0, LaunchOptions.MODE_EXAM)
	_finish_countdown()


func _leave_the_road() -> void:
	_step(DT, PlayerCommands.create(VehicleState.Longitudinal.NONE, VehicleState.Dir.RIGHT, VehicleState.Dir.NONE))
	_step(_session.sim.config.lane_change_duration_s)


func test_exam_collision_names_the_cause() -> void:
	_new_exam()
	var player: VehicleState = _session.player
	_session.sim.add_vehicle(player.s + player.length_m + 1.0, 0, 0.0)
	_step(2.0)
	assert_int(_session.state).is_equal(SessionManager.State.ENDED)
	assert_bool(_hud.ended_screen.visible).is_true()
	assert_str(_hud.ended_label.text).is_equal("Egzamin niezaliczony")
	assert_bool(_hud.ended_cause_label.is_visible_in_tree()).is_true()
	assert_str(_hud.ended_cause_label.text).is_equal("Przyczyna: kolizja z innym pojazdem")


func test_exam_leaving_the_road_names_the_cause() -> void:
	_new_exam()
	_leave_the_road()
	assert_int(_session.state).is_equal(SessionManager.State.ENDED)
	assert_str(_hud.ended_label.text).is_equal("Egzamin niezaliczony")
	assert_bool(_hud.ended_cause_label.visible).is_true()
	assert_str(_hud.ended_cause_label.text).is_equal("Przyczyna: zjechanie z drogi")


func test_exam_completed_without_an_incident_shows_no_cause() -> void:
	_new_exam()
	_step(_session.sim.config.session_length_s)
	assert_int(_session.state).is_equal(SessionManager.State.ENDED)
	assert_str(_hud.ended_label.text).is_equal("Koniec sesji")
	assert_bool(_hud.ended_cause_label.visible).is_false()


func test_learn_session_ended_off_road_is_not_an_exam_failure() -> void:
	_finish_countdown()
	_leave_the_road()
	assert_int(_session.state).is_equal(SessionManager.State.ENDED)
	assert_str(_hud.ended_label.text).is_equal("Koniec sesji")
	assert_str(_hud.ended_cause_label.text).is_equal("Przyczyna: zjechanie z drogi")
