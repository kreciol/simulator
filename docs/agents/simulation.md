# Simulation core: vehicles, lanes, lane queries

**Read first:** requirements §4.3, §8.4, §15.2; `core/sim/`.

- Pure GDScript classes with **no scene or rendering dependencies** (a test scans `core/`).
- Logical coordinates only: longitudinal `s` in metres at the body centre, lane index / lateral offset.
- Fixed-step `_physics_process`.
- The only RNG is `TrafficSim.rng`, seeded at construction — seed + `InputLog` replays a session exactly.
- Free-lane, gap, overtaking and signal checks go through `LaneQuery`, never re-implemented.
- `LaneQuery`'s neighbour queries read `TrafficSim.lanes` (a `LaneIndex` of per-lane lists sorted by `s`), so add vehicles and change lanes only through `TrafficSim`.
- The player is a `VehicleState` like any AI car.
