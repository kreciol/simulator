class_name ScoringConfig
extends Resource
## Scoring tunables (requirements §8, spec Data Model). Values live in
## res://config/scoring.tres; nothing is defaulted here. Points are positive
## magnitudes; penalties are recorded as negative points.

## K1 — following too closely (requirements §8.2). While the gap to the leader is
## below the legal minimum, `k1_base_per_s * (1 - gap / min_gap)^k1_exponent` points
## are lost per second.
@export var k1_base_per_s: float
## Shape of the K1 curve; 2 makes the penalty grow ever sharper as the gap closes (Q7).
@export var k1_exponent: float

## K2 — staying in a left lane while the lane to the right is free (requirements §8.2).
## Time allowed to return right before the penalty starts.
@export var k2_grace_s: float
## Points lost per second after the grace period.
@export var k2_penalty_per_s: float
## The right lane counts as free when returning there would not soon force another
## overtake (requirements §8.4): the window ahead covers the distance closed on the
## slower right-lane leader within this horizon...
@export var k2_return_horizon_s: float
## ...and is never shorter than this.
@export var k2_min_look_ahead_m: float
## Free road behind the player's body needed on the right lane.
@export var k2_look_behind_m: float

## K3 — lane change without a valid signal (requirements §8.2). One-off penalty for no
## signal or a signal in the wrong direction.
@export var k3_penalty: float
## Share of `k3_penalty` charged for a signal switched on too late (§6.5: shorter than
## `SimConfig.signal_min_on_s`).
@export_range(0.0, 1.0) var k3_late_factor: float

## Overtaking (requirements §8.4): a slower vehicle on the lane to the right counts as
## being overtaken while alongside or at most this far ahead of the player's front.
## K1 and K2 are not charged while overtaking.
@export var overtake_look_ahead_m: float
