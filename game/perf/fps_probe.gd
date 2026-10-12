class_name FpsProbe
extends RefCounted
## In-game FPS probe (spec Phase 5 step 2): fed one FPS sample per rendered frame of
## driving, it fills a window of `PerfConfig.probe_duration_s` and reports the average
## and a low percentile (the 5th), the numbers the §16 exit criterion is checked
## against. Fed by the main scene from `Performance.TIME_FPS`; pure, so tests feed it
## synthetic samples.

var duration_s: float
## Percentile reported beside the average, 0–100.
var percentile: float
## Driving time sampled so far.
var elapsed_s: float = 0.0

var _samples: PackedFloat32Array = PackedFloat32Array()


func _init(config: PerfConfig) -> void:
	duration_s = config.probe_duration_s
	percentile = config.probe_percentile


## Adds one frame's `fps`, `delta_s` after the previous one. Ignored once the window
## is full.
func add_sample(fps: float, delta_s: float) -> void:
	if is_complete():
		return
	_samples.append(fps)
	elapsed_s += delta_s


func is_complete() -> bool:
	return elapsed_s >= duration_s - SessionManager.TIME_EPSILON


func sample_count() -> int:
	return _samples.size()


func average_fps() -> float:
	if _samples.is_empty():
		return 0.0
	var total: float = 0.0
	for fps: float in _samples:
		total += fps
	return total / _samples.size()


func percentile_fps() -> float:
	return nearest_rank(_samples, percentile)


## One line for the console; marks a window the session ended before filling.
func report() -> String:
	return "FPS probe: avg=%.1f p%d=%.1f over %.1f s (%d frames)%s" % [
			average_fps(), roundi(percentile), percentile_fps(), elapsed_s, sample_count(),
			"" if is_complete() else " — incomplete, the session ended first"]


## The `p`-th percentile (0–100) of `values` by the nearest-rank method: the smallest
## value with at least p% of the values at or below it. 0 for no values.
static func nearest_rank(values: PackedFloat32Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: PackedFloat32Array = values.duplicate()
	sorted.sort()
	var rank: int = clampi(ceili(p / 100.0 * sorted.size()), 1, sorted.size())
	return sorted[rank - 1]
