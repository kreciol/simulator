class_name LowFpsWatch
extends RefCounted
## Low-FPS detection (spec Edge Cases: Low FPS): FPS below
## `PerfConfig.low_fps_threshold` without a break for `low_fps_sustain_s` triggers the
## suggestion to switch to the low preset — once per session, never again. A session
## already on the suggested preset is never told to switch to it. Pure, fed one sample
## per rendered frame.

var threshold_fps: float
var sustain_s: float
## True once the suggestion has been triggered; it stays true for the session.
var triggered: bool = false

var _below_s: float = 0.0


## `enabled` false (the session already runs on the suggested preset) never triggers.
func _init(config: PerfConfig, enabled: bool) -> void:
	threshold_fps = config.low_fps_threshold
	sustain_s = config.low_fps_sustain_s
	triggered = not enabled


## Adds one frame's `fps`, `delta_s` after the previous one. True only on the frame
## the low FPS becomes sustained, the first time it does.
func add_sample(fps: float, delta_s: float) -> bool:
	if triggered:
		return false
	if fps >= threshold_fps:
		_below_s = 0.0
		return false
	_below_s += delta_s
	if _below_s >= sustain_s - SessionManager.TIME_EPSILON:
		triggered = true
		return true
	return false
