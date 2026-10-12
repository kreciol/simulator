extends GdUnitTestSuite
## Low-FPS detection: FPS below 30 sustained suggests the low preset once per session,
## never more than once (issue #26 acceptance criteria, spec Edge Cases: Low FPS).

const DT: float = 1.0 / 60.0

var _config: PerfConfig


func before_test() -> void:
	_config = load("res://config/perf_config.tres") as PerfConfig


## How many frames of `fps` over `duration_s` triggered the watch.
func _feed(watch: LowFpsWatch, fps: float, duration_s: float) -> int:
	var triggers: int = 0
	for i: int in roundi(duration_s / DT):
		if watch.add_sample(fps, DT):
			triggers += 1
	return triggers


func test_sustained_low_fps_triggers_once() -> void:
	var watch: LowFpsWatch = LowFpsWatch.new(_config, true)
	var low: float = _config.low_fps_threshold - 5.0
	assert_int(_feed(watch, low, _config.low_fps_sustain_s - 0.5)).is_equal(0)
	assert_int(_feed(watch, low, 0.5)).is_equal(1)
	assert_bool(watch.triggered).is_true()
	# Never more than once, however long FPS stays low or drops again.
	assert_int(_feed(watch, low, 30.0)).is_equal(0)
	_feed(watch, 60.0, 5.0)
	assert_int(_feed(watch, low, 30.0)).is_equal(0)


func test_a_brief_dip_does_not_trigger() -> void:
	var watch: LowFpsWatch = LowFpsWatch.new(_config, true)
	var low: float = _config.low_fps_threshold - 5.0
	for i: int in 10:
		assert_int(_feed(watch, low, _config.low_fps_sustain_s - 1.0)).is_equal(0)
		# One frame at the threshold resets the count.
		watch.add_sample(_config.low_fps_threshold, DT)
	assert_bool(watch.triggered).is_false()


func test_fps_at_or_above_the_threshold_never_triggers() -> void:
	var watch: LowFpsWatch = LowFpsWatch.new(_config, true)
	assert_int(_feed(watch, _config.low_fps_threshold, 60.0)).is_equal(0)


func test_a_disabled_watch_never_triggers() -> void:
	var watch: LowFpsWatch = LowFpsWatch.new(_config, false)
	assert_int(_feed(watch, 5.0, 60.0)).is_equal(0)
