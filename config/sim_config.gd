class_name SimConfig
extends Resource
## Physics tunables for the simulation core (spec Data Model). Values live in
## res://config/sim_config.tres; nothing is defaulted here.

## Arcade acceleration while accelerating (requirements §5.4).
@export var acceleration_mps2: float
## Arcade deceleration while braking.
@export var braking_mps2: float
## Vehicle top speed; the player may exceed the road's limit up to this (Q4).
@export var max_speed_kmh: float
## Speed the player starts the session with (requirements §9.3).
@export var start_speed_kmh: float
## Duration of the discrete animated lane change (Q12).
@export var lane_change_duration_s: float
## Default body size of a vehicle; `s` is the body's centre (spec Coordinates).
@export var vehicle_length_m: float
@export var vehicle_width_m: float
## Body size of a truck (`VehicleState.Kind.TRUCK`).
@export var truck_length_m: float
@export var truck_width_m: float
## Minimum time a signal must be on before a lane change starts to count as given
## in time (requirements §6.5); shorter is LATE.
@export var signal_min_on_s: float

## Intelligent Driver Model (spec Research, Treiber & Kesting) for AI car-following.
## Maximum acceleration `a`.
@export var idm_max_accel_mps2: float
## Comfortable deceleration `b`.
@export var idm_comfort_decel_mps2: float
## Desired time headway `T`; disciplined drivers stretch it to the legal gap (§7.2).
@export var idm_time_headway_s: float
## Minimum standstill gap `s0`, bumper to bumper.
@export var idm_min_spacing_m: float
## Free-road acceleration exponent `delta`.
@export var idm_accel_exponent: float
## Hardest braking an AI car can apply.
@export var ai_max_decel_mps2: float

## MOBIL lane-change model, asymmetric keep-right variant (spec Research).
## Weight of the acceleration change imposed on other drivers.
@export var mobil_politeness: float
## Net acceleration gain a lane change must exceed.
@export var mobil_threshold_mps2: float
## Hardest braking a lane change may impose on the new follower.
@export var mobil_safe_decel_mps2: float
## Bias towards the right lane for fully disciplined drivers (scaled by discipline).
@export var mobil_keep_right_bias_mps2: float
## How long an AI car signals before starting a lane change (spec Architecture: AI).
@export var ai_signal_lead_s: float
## Clearance beyond its own body an AI car needs on the target lane, ahead and behind.
@export var ai_lane_change_clearance_m: float
## How often an AI car weighs a new lane change; in between it only follows. Keeps the
## MOBIL cost per step low with many cars (spec Risks: web performance).
@export var ai_lane_decision_interval_s: float
## AI cars cruise around the road's limit plus this (negative: below the limit),
## spread by the level's `ai_speed_spread_kmh` (requirements §7.1).
@export var ai_car_speed_offset_kmh: float
## Range truck desired speeds are drawn from (requirements §7.1: ≈ 80–90 km/h).
@export var truck_speed_min_kmh: float
@export var truck_speed_max_kmh: float

## Traffic spawner (requirements §7.3, spec Architecture: Spawner). Traffic is kept
## at the level's density within this window around the player.
@export var spawn_window_ahead_m: float
@export var spawn_window_behind_m: float
## During a session vehicles appear only with their whole body at least this far
## ahead of / behind the player: beyond the draw distance ahead and the mirrors'
## useful range behind (requirements §7.3).
@export var spawn_hidden_ahead_m: float
@export var spawn_hidden_behind_m: float
## Vehicles are despawned this far beyond the window, so they do not flicker at its edge.
@export var despawn_margin_m: float
## Safety margin around the player: no vehicle is ever placed with its body closer.
@export var spawn_player_clearance_m: float
## Free road a new vehicle needs beyond its body, on top of the legal gaps to its
## leader and follower.
@export var spawn_clearance_m: float
## How often the spawner tops up and despawns traffic.
@export var spawn_interval_s: float
## Most spawn attempts per update; a failed attempt is skipped, not forced.
@export var spawn_attempts_per_update: int

## Teachable-moment guarantee (spec Research): at least this many slow vehicles
## appear ahead of the player in the right lane per session.
@export var min_overtake_opportunities: int
## The next guaranteed slow vehicle is due this long after the previous one.
@export var overtake_opportunity_interval_s: float
## A vehicle counts as slow when it cruises at least this far below the limit.
@export var overtake_opportunity_margin_kmh: float
