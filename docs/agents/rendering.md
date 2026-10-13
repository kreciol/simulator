# Rendering: road, player camera, traffic

**Read first:** requirements §4–§5, §7.1, §14; `game/main.tscn`, `game/world/`, `game/player/`, `game/traffic/`, `config/view_config.tres`, `QualityPreset` + `config/quality_presets/`.

- Presentation only reads simulation state.
- Vehicle views are pooled per look and follow `TrafficSim.vehicle_added` / `vehicle_removed` — no create/free per spawn.
- A vehicle's look and colour come from its id, never from an RNG.
- Floating origin: objects sit at `z = -(s - player.s)`.
- Segment recycling for the infinite road: recycled segments appear only beyond `ViewConfig.draw_distance_m()`.
- Hectometre posts (every `hectometre_post_spacing_m` beside the right shoulder) are pooled the same way and exist only within `RoadView`'s segment window.
- A session's draw distance comes from its preset via `ViewConfig.for_quality` (a copy — never mutate the shared `.tres`).
