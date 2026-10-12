extends GdUnitTestSuite
## FPS probe: average and 5th-percentile FPS over 60 s of driving (issue #26
## acceptance criteria, spec Phase 5 step 2).

const DT: float = 1.0 / 60.0

var _config: PerfConfig


func before_test() -> void:
	_config = load("res://config/perf_config.tres") as PerfConfig


func _feed(probe: FpsProbe, fps: float, duration_s: float, dt: float = DT) -> void:
	for i: int in roundi(duration_s / dt):
		probe.add_sample(fps, dt)


func test_the_window_fills_after_the_configured_driving_time() -> void:
	var probe: FpsProbe = FpsProbe.new(_config)
	_feed(probe, 60.0, _config.probe_duration_s - 1.0)
	assert_bool(probe.is_complete()).is_false()
	_feed(probe, 60.0, 1.0)
	assert_bool(probe.is_complete()).is_true()
	# Later frames are not sampled.
	var count: int = probe.sample_count()
	_feed(probe, 10.0, 5.0)
	assert_int(probe.sample_count()).is_equal(count)
	assert_float(probe.average_fps()).is_equal_approx(60.0, 0.001)


func test_average_and_5th_percentile() -> void:
	var probe: FpsProbe = FpsProbe.new(_config)
	# 95% of frames at 60 FPS, 5% at 20 FPS: the 5th percentile is the slow frames.
	for i: int in 100:
		probe.add_sample(20.0 if i % 20 == 0 else 60.0, DT)
	assert_float(probe.average_fps()).is_equal_approx(58.0, 0.001)
	assert_float(probe.percentile_fps()).is_equal(20.0)


func test_nearest_rank_percentile(p: float, expected: float, test_parameters: Array = [
		[0.0, 10.0],
		[5.0, 10.0],
		[10.0, 10.0],
		[11.0, 20.0],
		[50.0, 50.0],
		[100.0, 100.0],
		]) -> void:
	var values: PackedFloat32Array = PackedFloat32Array([100.0, 90.0, 80.0, 70.0, 60.0, 50.0, 40.0, 30.0, 20.0, 10.0])
	var weights: PackedFloat32Array = PackedFloat32Array()
	weights.resize(values.size())
	weights.fill(1.0)
	assert_float(FpsProbe.nearest_rank(values, weights, p)).is_equal(expected)


func test_slow_seconds_count_for_their_time_not_their_frames() -> void:
	# `TIME_FPS` holds one value per second: 30 s at 36 FPS and 30 s at 22 FPS is
	# 1740 frames in 60 s, 29 FPS — below the criterion, however many frames were fast.
	var probe: FpsProbe = FpsProbe.new(_config)
	_feed(probe, 36.0, 30.0, 1.0 / 36.0)
	_feed(probe, 22.0, 30.0, 1.0 / 22.0)
	assert_bool(probe.is_complete()).is_true()
	assert_float(probe.average_fps()).is_equal_approx(29.0, 0.1)
	# 5% of the time is in the slow half.
	assert_float(probe.percentile_fps()).is_equal(22.0)


func test_no_samples_report_zero() -> void:
	var probe: FpsProbe = FpsProbe.new(_config)
	assert_float(probe.average_fps()).is_equal(0.0)
	assert_float(probe.percentile_fps()).is_equal(0.0)


func test_report_names_the_numbers_and_an_unfilled_window() -> void:
	var probe: FpsProbe = FpsProbe.new(_config)
	_feed(probe, 45.0, 10.0)
	assert_str(probe.report()).contains("avg=45.0").contains("p5=45.0").contains("incomplete")
	_feed(probe, 45.0, _config.probe_duration_s)
	assert_str(probe.report()).contains("avg=45.0").not_contains("incomplete")
