extends GdUnitTestSuite
## The performance check's numbers come from data and match the spec: a 60 s probe
## printing the 5th percentile, and a notice after FPS stays below 30 (issue #26, spec
## Phase 5 step 2 and Edge Cases: Low FPS).


func test_values_match_the_spec() -> void:
	var perf: PerfConfig = load("res://config/perf_config.tres") as PerfConfig
	assert_float(perf.probe_duration_s).is_equal(60.0)
	assert_float(perf.probe_percentile).is_equal(5.0)
	assert_float(perf.low_fps_threshold).is_equal(30.0)
	assert_float(perf.low_fps_sustain_s).is_greater(0.0)
	assert_float(perf.toast_duration_s).is_greater(0.0)


func test_the_suggested_preset_exists() -> void:
	var perf: PerfConfig = load("res://config/perf_config.tres") as PerfConfig
	var launcher: DevLauncherConfig = load("res://config/dev_launcher.tres") as DevLauncherConfig
	assert_object(launcher.find_quality(perf.suggested_quality)).is_not_null()


func test_the_main_scene_uses_it() -> void:
	var main: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	assert_object(main.perf_config).is_not_null()
	main.free()
