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
## Minimum time a signal must be on before a lane change starts to count as given
## in time (requirements §6.5); shorter is LATE.
@export var signal_min_on_s: float
