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
## Duration of the discrete animated lane change (Q12).
@export var lane_change_duration_s: float
## Default body size of a vehicle; `s` is the body's centre (spec Coordinates).
@export var vehicle_length_m: float
@export var vehicle_width_m: float
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
