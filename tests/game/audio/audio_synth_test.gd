extends GdUnitTestSuite
## The synthesised sounds are 16-bit mono PCM at the configured rate, the engine loops
## seamlessly, and every build yields the same bytes (issue #72, spec
## `2026-10-13-sound-effects.md` Phase 1 step 2).

const MIX_RATE: int = 22050
const BASE_HZ: int = 55


func _one_shots() -> Array[AudioStreamWAV]:
	return [AudioSynth.tick(MIX_RATE), AudioSynth.tock(MIX_RATE), AudioSynth.whoosh(MIX_RATE),
			AudioSynth.impact(MIX_RATE), AudioSynth.rumble(MIX_RATE)]


func _peak(stream: AudioStreamWAV) -> int:
	var peak: int = 0
	for i: int in range(0, stream.data.size(), 2):
		peak = maxi(peak, absi(stream.data.decode_s16(i)))
	return peak


func test_every_sound_is_16_bit_mono_at_the_mix_rate() -> void:
	var sounds: Array[AudioStreamWAV] = _one_shots()
	sounds.append(AudioSynth.engine(MIX_RATE, BASE_HZ))
	for stream: AudioStreamWAV in sounds:
		assert_int(stream.format).is_equal(AudioStreamWAV.FORMAT_16_BITS)
		assert_bool(stream.stereo).is_false()
		assert_int(stream.mix_rate).is_equal(MIX_RATE)
		assert_int(stream.data.size()).is_greater(0)
		# Normalised: loud enough to hear, never clipping.
		assert_int(_peak(stream)).is_equal(roundi(AudioSynth.PEAK * AudioSynth.S16_MAX))


func test_the_engine_loops_over_one_second() -> void:
	var engine: AudioStreamWAV = AudioSynth.engine(MIX_RATE, BASE_HZ)
	assert_int(engine.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	assert_int(engine.loop_begin).is_equal(0)
	assert_int(engine.loop_end).is_equal(MIX_RATE)
	assert_int(engine.data.size()).is_equal(MIX_RATE * 2)
	# Whole cycles: the loop's end runs on into its start without a jump.
	var first: int = engine.data.decode_s16(0)
	var last: int = engine.data.decode_s16(engine.data.size() - 2)
	assert_int(absi(first - last)).is_less(int(0.05 * AudioSynth.S16_MAX))


func test_one_shots_do_not_loop() -> void:
	for stream: AudioStreamWAV in _one_shots():
		assert_int(stream.loop_mode).is_equal(AudioStreamWAV.LOOP_DISABLED)


func test_tick_and_tock_differ() -> void:
	assert_bool(AudioSynth.tick(MIX_RATE).data == AudioSynth.tock(MIX_RATE).data).is_false()


func test_every_build_yields_the_same_bytes() -> void:
	assert_bool(AudioSynth.whoosh(MIX_RATE).data == AudioSynth.whoosh(MIX_RATE).data).is_true()
	assert_bool(AudioSynth.rumble(MIX_RATE).data == AudioSynth.rumble(MIX_RATE).data).is_true()
	assert_bool(AudioSynth.engine(MIX_RATE, BASE_HZ).data == AudioSynth.engine(MIX_RATE, BASE_HZ).data).is_true()
