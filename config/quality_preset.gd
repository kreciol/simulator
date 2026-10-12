class_name QualityPreset
extends Resource
## Graphics quality (requirements §5.2, §14 Jakość; spec Data Model): what the
## low and high settings change — mirror render size and update rate, shadows and
## draw distance. Instances live in res://config/quality_presets/; nothing is
## defaulted here. Chosen through the dev launcher until the settings screen (Phase 10).

## `low` or `high`; the dev launcher's `quality` param selects by it.
@export var id: StringName
## Mirror render size as a share of the mirror's size on screen (spec: low 1/4, high 1/2).
@export_range(0.05, 1.0) var mirror_resolution_scale: float
## Mirrors re-render every this many frames (spec: low every 2nd, high every frame).
@export_range(1, 8) var mirror_update_interval_frames: int
## Whether the sun casts shadows.
@export var shadows_enabled: bool
## Road segments in the recycled pool; sets the draw distance (`ViewConfig.draw_distance_m`).
@export var road_segment_count: int
