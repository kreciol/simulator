extends GdUnitTestSuite
## The sound effects' numbers come from data and make sense together (issue #72, spec
## `2026-10-13-sound-effects.md` Data Model).


func _config() -> AudioConfig:
	return load("res://config/audio_config.tres") as AudioConfig


func test_ranges_run_from_low_to_high() -> void:
	var audio: AudioConfig = _config()
	assert_float(audio.engine_pitch_min).is_greater(0.0)
	assert_float(audio.engine_pitch_max).is_greater(audio.engine_pitch_min)
	assert_float(audio.engine_volume_max_db).is_greater(audio.engine_volume_min_db)
	assert_float(audio.pass_volume_max_db).is_greater(audio.pass_volume_min_db)
	assert_float(audio.pass_full_speed_kmh).is_greater(audio.pass_min_relative_speed_kmh)


func test_sound_is_on_by_default() -> void:
	assert_bool(_config().muted_by_default).is_false()


func test_a_pass_needs_a_neighbouring_lane_and_a_voice() -> void:
	var audio: AudioConfig = _config()
	var road: RoadProfile = load("res://config/road_profiles/motorway.tres") as RoadProfile
	# The next lane's centre is in range; two lanes away is not.
	assert_float(audio.pass_sound_range_m).is_greater_equal(road.lane_width_m)
	assert_float(audio.pass_sound_range_m).is_less(2.0 * road.lane_width_m)
	assert_float(audio.pass_scan_window_m).is_greater(0.0)
	assert_int(audio.pass_voices).is_greater(0)
	assert_float(audio.pass_edge_loudness).is_between(0.0, 1.0)


func test_synthesis_settings_are_usable() -> void:
	var audio: AudioConfig = _config()
	assert_int(audio.engine_base_hz).is_greater(0)
	assert_int(audio.synth_mix_rate).is_greater_equal(2 * audio.engine_base_hz)


func test_the_bus_layout_has_engine_and_effects_into_master() -> void:
	for bus: StringName in [&"Engine", &"Effects"]:
		var index: int = AudioServer.get_bus_index(bus)
		assert_int(index).is_greater(0)
		assert_str(AudioServer.get_bus_send(index)).is_equal("Master")
