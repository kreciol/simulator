extends GdUnitTestSuite
## Low and high quality presets come from data: mirror resolution and update
## interval, shadows, draw distance (issue #25, requirements §14 Jakość, spec Data
## Model and Architecture: Mirrors).

var _low: QualityPreset
var _high: QualityPreset
var _view: ViewConfig


func before_test() -> void:
	_low = load("res://config/quality_presets/low.tres") as QualityPreset
	_high = load("res://config/quality_presets/high.tres") as QualityPreset
	_view = load("res://config/view_config.tres") as ViewConfig


func test_presets_carry_the_specs_mirror_settings() -> void:
	assert_str(_low.id).is_equal(&"low")
	assert_str(_high.id).is_equal(&"high")
	# Spec Architecture: low renders at 1/4 res every 2nd frame, high at 1/2 res every frame.
	assert_float(_low.mirror_resolution_scale).is_equal(0.25)
	assert_int(_low.mirror_update_interval_frames).is_equal(2)
	assert_float(_high.mirror_resolution_scale).is_equal(0.5)
	assert_int(_high.mirror_update_interval_frames).is_equal(1)


func test_low_is_cheaper_than_high() -> void:
	assert_bool(_low.shadows_enabled).is_false()
	assert_bool(_high.shadows_enabled).is_true()
	assert_float(_view.for_quality(_low).draw_distance_m()).is_less(_view.for_quality(_high).draw_distance_m())


func test_every_preset_keeps_spawns_out_of_view_ahead() -> void:
	var sim: SimConfig = load("res://config/sim_config.tres") as SimConfig
	for quality: QualityPreset in [_low, _high]:
		var view: ViewConfig = _view.for_quality(quality)
		assert_float(sim.spawn_hidden_ahead_m).is_greater_equal(view.draw_distance_m())
		# Still a useful look ahead at the motorway limit (140 km/h).
		assert_float(view.draw_distance_m() / (140.0 / 3.6)).is_greater(8.0)


func test_for_quality_leaves_the_shared_config_untouched() -> void:
	var count: int = _view.segment_count
	var low_view: ViewConfig = _view.for_quality(_low)
	assert_int(low_view.segment_count).is_equal(_low.road_segment_count)
	assert_int(_view.segment_count).is_equal(count)
	assert_object(low_view).is_not_same(_view)
	assert_float(low_view.segment_length_m).is_equal(_view.segment_length_m)
