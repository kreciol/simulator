class_name AudioSynth
extends RefCounted
## The game's sounds, synthesised once into in-memory 16-bit mono `AudioStreamWAV`s
## (spec `2026-10-13-sound-effects.md`: no asset files, no licences). A WAV stream
## plays in the web export's sample playback, which uploads its data to the browser on
## the first play — so a stream is never changed after it is built. Noise comes from a
## local generator with a fixed seed, never the sim's RNG: every build yields the same
## bytes and a seeded replay is never disturbed.

const SEED: int = 72
## Peak level of a built sound, leaving headroom below full scale.
const PEAK: float = 0.8
const S16_MAX: float = 32767.0

## Electric motor whine's partials, fundamental first: an almost pure, soft tone.
const ENGINE_HARMONICS: PackedFloat32Array = [1.0, 0.18, 0.05]

## Length of the road-noise loop, s; long enough that its pattern is not heard.
const ROAD_S: float = 2.0
## One-pole low-pass of the road noise: a dull tyre roar.
const ROAD_SMOOTHING: float = 0.97
## Cross-fade folded over the road loop's seam, s, so it loops without a click.
const ROAD_SEAM_S: float = 0.1

const TICK_HZ: float = 2100.0
const TOCK_HZ: float = 1500.0
const CLICK_S: float = 0.03
const CLICK_DECAY_S: float = 0.006
## Share of noise in a click, for a relay-like attack.
const CLICK_NOISE: float = 0.3

const WHOOSH_S: float = 0.7
## One-pole low-pass of the whoosh noise: 0 keeps everything, 1 nothing.
const WHOOSH_SMOOTHING: float = 0.85

const IMPACT_S: float = 0.6
const IMPACT_DECAY_S: float = 0.12
const IMPACT_THUD_HZ: float = 60.0
const IMPACT_SMOOTHING: float = 0.5

const RUMBLE_S: float = 0.9
const RUMBLE_SMOOTHING: float = 0.95
## Gravel crackle on top of the rumble.
const RUMBLE_GRIT: float = 0.15


## One second of an electric motor's whine at `base_hz`, looping seamlessly: every
## partial completes whole cycles in it.
static func engine(mix_rate: int, base_hz: int) -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(mix_rate)
	for i: int in mix_rate:
		var t: float = float(i) / mix_rate
		var value: float = 0.0
		for k: int in ENGINE_HARMONICS.size():
			value += ENGINE_HARMONICS[k] * sin(TAU * base_hz * (k + 1) * t)
		samples[i] = value
	var stream: AudioStreamWAV = _wav(samples, mix_rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = mix_rate
	return stream


## Tyre and wind roar: low-passed noise, looping without a click (the tail is folded
## over the start).
static func road(mix_rate: int) -> AudioStreamWAV:
	var seam: int = roundi(ROAD_SEAM_S * mix_rate)
	var length: int = roundi(ROAD_S * mix_rate)
	var noise: PackedFloat32Array = _low_passed_noise(mix_rate, ROAD_S + ROAD_SEAM_S, ROAD_SMOOTHING)
	var samples: PackedFloat32Array = noise.slice(0, length)
	for i: int in seam:
		samples[i] = lerpf(noise[length + i], noise[i], float(i) / seam)
	var stream: AudioStreamWAV = _wav(samples, mix_rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = length
	return stream


## The indicator relay closing: a short, high click.
static func tick(mix_rate: int) -> AudioStreamWAV:
	return _click(mix_rate, TICK_HZ)


## The indicator relay opening: a lower click.
static func tock(mix_rate: int) -> AudioStreamWAV:
	return _click(mix_rate, TOCK_HZ)


## A vehicle passing close by: soft noise swelling and fading.
static func whoosh(mix_rate: int) -> AudioStreamWAV:
	var noise: PackedFloat32Array = _low_passed_noise(mix_rate, WHOOSH_S, WHOOSH_SMOOTHING)
	for i: int in noise.size():
		noise[i] *= pow(sin(PI * i / noise.size()), 2.0)
	return _wav(noise, mix_rate)


## A crash: a burst of noise over a low thud, dying away fast.
static func impact(mix_rate: int) -> AudioStreamWAV:
	var noise: PackedFloat32Array = _low_passed_noise(mix_rate, IMPACT_S, IMPACT_SMOOTHING)
	for i: int in noise.size():
		var t: float = float(i) / mix_rate
		noise[i] = (noise[i] + sin(TAU * IMPACT_THUD_HZ * t)) * exp(-t / IMPACT_DECAY_S)
	return _wav(noise, mix_rate)


## Leaving the road: a deep rumble with gravel crackle, fading out.
static func rumble(mix_rate: int) -> AudioStreamWAV:
	var noise: PackedFloat32Array = _low_passed_noise(mix_rate, RUMBLE_S, RUMBLE_SMOOTHING)
	var rng: RandomNumberGenerator = _rng()
	for i: int in noise.size():
		var grit: float = RUMBLE_GRIT * rng.randf_range(-1.0, 1.0)
		noise[i] = (noise[i] + grit) * (1.0 - float(i) / noise.size())
	return _wav(noise, mix_rate)


static func _click(mix_rate: int, hz: float) -> AudioStreamWAV:
	var rng: RandomNumberGenerator = _rng()
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(roundi(CLICK_S * mix_rate))
	for i: int in samples.size():
		var t: float = float(i) / mix_rate
		var tone: float = sin(TAU * hz * t) + CLICK_NOISE * rng.randf_range(-1.0, 1.0)
		samples[i] = tone * exp(-t / CLICK_DECAY_S)
	return _wav(samples, mix_rate)


## White noise through a one-pole low-pass; `smoothing` near 1 leaves only the lows.
static func _low_passed_noise(mix_rate: int, duration_s: float, smoothing: float) -> PackedFloat32Array:
	var rng: RandomNumberGenerator = _rng()
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(roundi(duration_s * mix_rate))
	var value: float = 0.0
	for i: int in samples.size():
		value = lerpf(rng.randf_range(-1.0, 1.0), value, smoothing)
		samples[i] = value
	return samples


static func _rng() -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	return rng


## `samples` normalised to `PEAK` as 16-bit mono PCM.
static func _wav(samples: PackedFloat32Array, mix_rate: int) -> AudioStreamWAV:
	var peak: float = 0.0
	for value: float in samples:
		peak = maxf(peak, absf(value))
	var gain: float = PEAK / peak if peak > 0.0 else 0.0
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, roundi(clampf(samples[i] * gain, -1.0, 1.0) * S16_MAX))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream
