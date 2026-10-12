class_name FpsProbe
extends RefCounted
## In-game FPS probe (spec Phase 5 step 2): fed the FPS once per rendered frame of
## driving, it fills a window of `PerfConfig.probe_duration_s` and reports the average
## and a low percentile (the 5th), the numbers the §16 exit criterion is checked
## against. Every sample counts for the time its frame took, not once per frame:
## `Performance.TIME_FPS` holds one value per second, so counting frames would let
## fast seconds outweigh slow ones and flatter the result. Fed by the main scene; pure,
## so tests feed it synthetic samples.

var duration_s: float
## Percentile reported beside the average, 0–100.
var percentile: float
## Driving time sampled so far.
var elapsed_s: float = 0.0

var _fps: PackedFloat32Array = PackedFloat32Array()
## How long each sample's frame took, in step with `_fps`.
var _weights: PackedFloat32Array = PackedFloat32Array()


func _init(config: PerfConfig) -> void:
	duration_s = config.probe_duration_s
	percentile = config.probe_percentile


## Adds one frame's `fps`, `delta_s` after the previous one. Ignored once the window
## is full.
func add_sample(fps: float, delta_s: float) -> void:
	if is_complete():
		return
	_fps.append(fps)
	_weights.append(delta_s)
	elapsed_s += delta_s


func is_complete() -> bool:
	return elapsed_s >= duration_s - SessionManager.TIME_EPSILON


func sample_count() -> int:
	return _fps.size()


## Time-weighted mean FPS.
func average_fps() -> float:
	if elapsed_s <= 0.0:
		return 0.0
	var total: float = 0.0
	for i: int in _fps.size():
		total += _fps[i] * _weights[i]
	return total / elapsed_s


## The FPS the drive ran at or below for `percentile`% of its time.
func percentile_fps() -> float:
	return nearest_rank(_fps, _weights, percentile)


## One line for the console; marks a window the session ended before filling.
func report() -> String:
	return "FPS probe: avg=%.1f p%d=%.1f over %.1f s (%d frames)%s" % [
			average_fps(), roundi(percentile), percentile_fps(), elapsed_s, sample_count(),
			"" if is_complete() else " — incomplete, the session ended first"]


## The weighted `p`-th percentile (0–100) of `values` by the nearest-rank method: the
## smallest value with at least p% of the total weight at or below it. 0 for no
## values or no weight.
static func nearest_rank(values: PackedFloat32Array, weights: PackedFloat32Array, p: float) -> float:
	var total: float = 0.0
	for weight: float in weights:
		total += weight
	if values.is_empty() or total <= 0.0:
		return 0.0
	var order: Array[int] = []
	for i: int in values.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return values[a] < values[b])
	var target: float = p / 100.0 * total
	var covered: float = 0.0
	for i: int in order:
		covered += weights[i]
		if covered >= target - SessionManager.TIME_EPSILON and weights[i] > 0.0:
			return values[i]
	return values[order[order.size() - 1]]
