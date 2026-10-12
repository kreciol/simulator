extends GdUnitTestSuite
## The main scene measures FPS under `perf=1` and suggests the low preset once when
## FPS stays low (issue #26 acceptance criteria, spec Phase 5 step 2 and Edge Cases).
## Headless runs have no real frame rate, so frames are fed through `track_performance`
## with synthetic FPS values.

const DT: float = 1.0 / 60.0
const MAIN_SCENE: String = "res://game/main.tscn"

var _launcher: DevLauncherConfig


func before_test() -> void:
	_launcher = load("res://config/dev_launcher.tres") as DevLauncherConfig


## The main scene started as the dev launcher would start it with `query`.
func _main(query: String) -> Node3D:
	var main: Node3D = (load(MAIN_SCENE) as PackedScene).instantiate() as Node3D
	main.launch_options = DevLauncher.resolve(DevLauncher.parse_query(query), _launcher, 1)
	add_child(auto_free(main))
	return main


func _finish_countdown(main: Node3D) -> void:
	while main.session.state == SessionManager.State.INTRO:
		main._physics_process(DT)


func _frames(main: Node3D, fps: float, duration_s: float) -> void:
	for i: int in roundi(duration_s / DT):
		main.track_performance(fps, DT)


func test_perf_prints_average_and_5th_percentile_after_60_s_of_driving() -> void:
	var main: Node3D = _main("?perf=1&level=4&profile=motorway&seed=1&quality=low")
	var window_s: float = main.perf_config.probe_duration_s
	# The countdown is not measured.
	_frames(main, 5.0, 1.0)
	_finish_countdown(main)
	_frames(main, 40.0, window_s - 1.0)
	assert_str(main.perf_report).is_empty()
	_frames(main, 40.0, 1.0)
	assert_str(main.perf_report).contains("avg=40.0").contains("p5=40.0").not_contains("incomplete")
	# The line names what was measured, for the record in the PR.
	assert_str(main.perf_report).contains("level=4").contains("profile=motorway").contains("seed=1").contains("quality=low")
	# Reported once: the session ending later does not print again.
	var report: String = main.perf_report
	main.session._end(SessionManager.EndReason.TIME_UP)
	assert_str(main.perf_report).is_equal(report)


func test_a_session_ending_early_still_reports_marked_incomplete() -> void:
	var main: Node3D = _main("?perf=1&seed=1")
	_finish_countdown(main)
	_frames(main, 50.0, 10.0)
	main.session._end(SessionManager.EndReason.COLLISION)
	assert_str(main.perf_report).contains("avg=50.0").contains("incomplete")


func test_without_perf_nothing_is_measured() -> void:
	var main: Node3D = _main("?seed=1")
	_finish_countdown(main)
	_frames(main, 40.0, main.perf_config.probe_duration_s + 1.0)
	main.session._end(SessionManager.EndReason.TIME_UP)
	assert_str(main.perf_report).is_empty()


func _toast(main: Node3D) -> PanelContainer:
	return (main.get_node("Hud") as Hud).toast


## Lets the HUD's notice run its course.
func _wait_out_toast(main: Node3D) -> void:
	var hud: Hud = main.get_node("Hud") as Hud
	for i: int in roundi((main.perf_config.toast_duration_s + 1.0) / DT):
		hud._process(DT)


func test_sustained_low_fps_suggests_the_low_preset_once_per_session() -> void:
	var main: Node3D = _main("?quality=high&seed=1")
	var low: float = main.perf_config.low_fps_threshold - 10.0
	_finish_countdown(main)
	_frames(main, low, main.perf_config.low_fps_sustain_s + 0.5)
	assert_bool(_toast(main).visible).is_true()
	assert_str((main.get_node("Hud") as Hud).toast_label.text).is_equal(tr(&"TOAST_LOW_FPS"))
	# Non-blocking: it takes no input and the drive goes on.
	assert_int(_toast(main).mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(main.session.state).is_equal(SessionManager.State.DRIVING)
	_wait_out_toast(main)
	assert_bool(_toast(main).visible).is_false()
	# Never more than once, however long FPS stays low.
	_frames(main, low, 30.0)
	assert_bool(_toast(main).visible).is_false()


func test_low_fps_during_the_countdown_does_not_count() -> void:
	var main: Node3D = _main("?quality=high&seed=1")
	_frames(main, 5.0, main.perf_config.low_fps_sustain_s + 1.0)
	assert_bool(_toast(main).visible).is_false()


func test_a_session_already_on_the_low_preset_gets_no_suggestion() -> void:
	var main: Node3D = _main("?quality=low&seed=1")
	_finish_countdown(main)
	_frames(main, 5.0, 30.0)
	assert_bool(_toast(main).visible).is_false()


func test_a_stall_is_not_measured_and_does_not_suggest_anything() -> void:
	var main: Node3D = _main("?perf=1&quality=high&seed=1")
	_finish_countdown(main)
	# A hidden tab: one long frame while the per-second FPS still reads low.
	main.track_performance(1.0, main.perf_config.probe_duration_s + main.perf_config.low_fps_sustain_s)
	assert_bool(_toast(main).visible).is_false()
	assert_str(main.perf_report).is_empty()
