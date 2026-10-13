class_name AudioConfig
extends Resource
## Sound effects (issue #72, spec `2026-10-13-sound-effects.md`): volumes, the engine's
## pitch range, when a passing vehicle makes a whoosh, and the synthesised streams'
## sample rate. Values live in res://config/audio_config.tres; nothing is defaulted here.

## `Master` bus volume until the settings screen (E11-S02) owns it.
@export var master_volume_db: float
## Whether a session starts muted; either way nothing sounds before the first key,
## click or touch (browser autoplay policy).
@export var muted_by_default: bool

@export_group("Engine")
## Pitch at 0 km/h and at the top speed (the profile's limit plus the S1 tolerance).
@export var engine_pitch_min: float
@export var engine_pitch_max: float
## Loudness at 0 km/h and at the top speed.
@export var engine_volume_min_db: float
@export var engine_volume_max_db: float
## Fundamental of the synthesised engine loop, Hz; a whole number, so the loop is seamless.
@export var engine_base_hz: int

@export_group("Indicator")
@export var indicator_volume_db: float

@export_group("Passing vehicles")
## Farthest lateral distance between the centres that still counts as a close pass.
@export var pass_sound_range_m: float
## A slower crossing makes no whoosh.
@export var pass_min_relative_speed_kmh: float
## Share of full loudness a pass keeps at the edge of `pass_sound_range_m`.
@export var pass_edge_loudness: float
## Relative speed at which a whoosh is at full loudness.
@export var pass_full_speed_kmh: float
## Loudness of the faintest and of the loudest whoosh.
@export var pass_volume_min_db: float
@export var pass_volume_max_db: float
## Distance ahead of and behind the player scanned for crossings.
@export var pass_scan_window_m: float
## Whooshes that can sound at once; one more steals the oldest.
@export var pass_voices: int

@export_group("Incidents")
@export var collision_volume_db: float
@export var offroad_volume_db: float

@export_group("Synthesis")
## Sample rate of the synthesised streams, Hz.
@export var synth_mix_rate: int
