extends GdUnitTestSuite
## The main scene measures FPS under `perf=1` (issue #26 acceptance criteria, spec
## Phase 5 step 2). Headless runs have no real frame rate, so frames are fed through
## `track_performance` with synthetic FPS values.

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
