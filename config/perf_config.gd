class_name PerfConfig
extends Resource
## Web performance check (spec Phase 5 step 2, Edge Cases: Low FPS; requirements §14,
## §16): the FPS probe started with the dev launcher's `perf=1`, and the low-FPS
## notice. Values live in res://config/perf_config.tres; nothing is defaulted here.

## Driving time the probe samples `Performance.TIME_FPS` over before printing.
@export var probe_duration_s: float
## Percentile of the sampled FPS printed beside the average (spec: the 5th).
@export_range(0.0, 100.0) var probe_percentile: float
## FPS below this, sustained, counts as low (spec Edge Cases: < 30).
@export var low_fps_threshold: float
## How long FPS must stay below the threshold, without a break, to count as sustained.
@export var low_fps_sustain_s: float
## Quality preset the low-FPS notice suggests; a session already on it gets no notice.
@export var suggested_quality: StringName
## Frames longer than this are not measured: a stall such as a hidden browser tab is
## not the game running slowly.
@export var max_frame_s: float
## How long the low-FPS notice stays on screen.
@export var toast_duration_s: float
