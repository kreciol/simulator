# Execution plan — simulated vehicle: motion, signals, lane changes (E02-S01)

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Issue: #4

## Goal

Land the first headless piece of the simulation core: road/sim config resources, `VehicleState`, and a `TrafficSim` that integrates speed at a fixed step, runs animated lane changes (including off-road beyond the outermost lane) and handles turn signals with `on_since_s` and auto-cancel — spec Phase 2, steps 1–2.

## Scope

- `config/road_profile.gd` (`RoadProfile`) + `config/road_profiles/motorway.tres` (140 km/h) and `expressway.tres` (120 km/h), 2 lanes of 3.75 m each.
- `config/sim_config.gd` (`SimConfig`) + `config/sim_config.tres`: acceleration, braking, max speed, lane change duration (Q12: 1.75 s).
- `core/sim/vehicle_state.gd`, `core/sim/player_commands.gd`, `core/sim/traffic_sim.gd` — pure `RefCounted` classes, no scene/render dependencies.
- `TrafficSim` signals `lane_change_started`, `lane_change_finished`, `offroad` (spec *API Contracts*).
- gdUnit4 tests mirroring every acceptance criterion of #4.

## Non-goals

- `LaneQuery`, collisions, seeded RNG, `InputLog` (Phase 2 steps 3–4, separate issues).
- Rendering, AI, scoring, session handling.

## Implementation Plan

### Phase 1 — Config and longitudinal motion
1. `RoadProfile`, `SimConfig` resources and their `.tres` instances; `VehicleState`, `PlayerCommands`, `TrafficSim` with arcade accel/brake integration clamped to [0, max speed]. *Tests:* profile values load from `.tres`, no road values hard-coded in `core/`, speed clamps, identical inputs → identical results.

### Phase 2 — Lane changes and signals
1. Lane change request → animated progress over `lane_change_duration_s`, lateral position derived from progress, lane updated on completion, requests ignored during an active change, off-road beyond the edges; signal toggle recording `on_since_s`, auto-cancel on completion. *Tests:* one per acceptance criterion.

## Risks

- Hand-written `.tres` files must stay loadable by Godot 4.7.2 — covered by tests that load them.

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Config and longitudinal motion

- [ ] 1.1 Config resources, VehicleState and longitudinal TrafficSim

### Phase 2: Lane changes and signals

- [ ] 2.1 Animated lane changes, off-road and signals
