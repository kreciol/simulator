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


func test_learn_leaving_the_road_shows_the_respawn_message_and_fade() -> void:
	_finish_countdown()
	_leave_the_road()
	assert_int(_session.state).is_equal(SessionManager.State.RESPAWNING)
	assert_bool(_hud.ended_screen.visible).is_false()
	assert_bool(_hud.respawn_notice.is_visible_in_tree()).is_true()
	assert_str(_hud.respawn_label.text).is_equal("Zjechanie z drogi")
	assert_str(_hud.respawn_hint_label.text).is_equal("Wracasz na prawy pas. Czas sesji biegnie dalej.")
	assert_bool(_hud.fade_screen.visible).is_true()
	# Darkest at the midpoint, where the player is put back.
	_step(_session.sim.config.respawn_fade_s / 2.0)
	assert_float(_hud.fade_screen.color.a).is_equal_approx(1.0, 0.05)
	_step(_session.sim.config.respawn_fade_s / 2.0)
	assert_int(_session.state).is_equal(SessionManager.State.DRIVING)
	assert_bool(_hud.respawn_notice.visible).is_false()
	assert_bool(_hud.fade_screen.visible).is_false()
	assert_bool(_hud.ended_screen.visible).is_false()


func test_learn_collision_names_it_while_respawning() -> void:
	_finish_countdown()
	var player: VehicleState = _session.player
	_session.sim.add_vehicle(player.s + player.length_m + 1.0, 0, 0.0)
	for i: int in 120:
		if _session.state != SessionManager.State.DRIVING:
			break
		_session.step(DT)
	_hud.update(_session)
	assert_int(_session.state).is_equal(SessionManager.State.RESPAWNING)
	assert_str(_hud.respawn_label.text).is_equal("Kolizja z innym pojazdem")
	assert_bool(_hud.respawn_notice.visible).is_true()


func test_pausing_a_respawn_shows_the_pause_screen_over_the_fade() -> void:
	_finish_countdown()
	_leave_the_road()
	_session.pause()
	_hud.update(_session)
	assert_bool(_hud.paused_screen.visible).is_true()
	assert_bool(_hud.fade_screen.visible).is_true()
	assert_bool(_hud.respawn_notice.visible).is_false()
	_session.resume()
	_hud.update(_session)
	assert_bool(_hud.respawn_notice.visible).is_true()


func test_no_respawn_notice_while_driving() -> void:
	_finish_countdown()
	_step(1.0)
	assert_bool(_hud.respawn_notice.visible).is_false()
	assert_bool(_hud.fade_screen.visible).is_false()


func test_pause_screen_shows_only_while_paused() -> void:
	assert_bool(_hud.paused_screen.visible).is_false()
	_session.pause()
	_hud.update(_session)
	# Paused during the countdown: the pause screen replaces the 3-2-1.
	assert_bool(_hud.paused_screen.is_visible_in_tree()).is_true()
	assert_bool(_hud.countdown_label.visible).is_false()
	assert_str(_hud.paused_label.text).is_equal("Pauza")
	assert_str(_hud.paused_hint_label.text).is_equal("Naciśnij Esc lub P, aby jechać dalej")
	_session.resume()
	_finish_countdown()
	assert_bool(_hud.paused_screen.visible).is_false()
	_session.pause()
	_step(5.0)
	assert_bool(_hud.paused_screen.visible).is_true()
	assert_str(_hud.time_label.text).is_equal("1:30")
	assert_bool(_hud.ended_screen.visible).is_false()
	_session.resume()
	_hud.update(_session)
	assert_bool(_hud.paused_screen.visible).is_false()


func _history(read_only: bool, corrupt: bool) -> HistoryStore:
	var history: HistoryStore = HistoryStore.new("user://unused/history.json", 1)
	history.read_only = read_only
	history.notice = HistoryStore.Notice.CORRUPT_RECOVERED if corrupt else HistoryStore.Notice.NONE
	return history


func test_save_status_explains_the_outcome(saved: bool, read_only: bool, corrupt: bool,
		keys: Array, test_parameters: Array = [
			[true, false, false, [&"SAVE_DONE"]],
			[false, false, false, [&"SAVE_UNAVAILABLE"]],
			[false, true, false, [&"SAVE_READ_ONLY"]],
			[true, false, true, [&"HISTORY_CORRUPT_RECOVERED", &"SAVE_DONE"]],
			[false, false, true, [&"HISTORY_CORRUPT_RECOVERED", &"SAVE_UNAVAILABLE"]],
		]) -> void:
	assert_array(Hud.save_status_keys(saved, _history(read_only, corrupt))).contains_exactly(keys)


func test_save_status_is_shown_in_polish_on_the_end_screen() -> void:
	assert_str(_hud.save_status_label.text).is_empty()
	assert_bool(_hud.save_status_label.visible).is_false()
	_hud.show_save_status(true, _history(false, true))
	assert_str(_hud.save_status_label.text).is_equal(
			"Zapisana historia była uszkodzona. Zachowaliśmy jej kopię i zaczęliśmy nową.\nWynik zapisany w tej przeglądarce.")
	assert_bool(_hud.save_status_label.visible).is_true()
	# Stacked under the end title and its cause, on the end screen.
	assert_object(_hud.save_status_label.get_parent()).is_same(_hud.ended_label.get_parent())
	assert_bool(_hud.ended_screen.is_ancestor_of(_hud.save_status_label)).is_true()
