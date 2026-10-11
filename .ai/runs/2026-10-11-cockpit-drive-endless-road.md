# Execution plan — cockpit drive on an endless road (E03-S01)

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Issue: #7

## Goal

Let a player drive the simulation from the driver's seat on an endless dual-carriageway motorway: keyboard input through the Input Map drives the player's `VehicleState`, and the road is rendered from recycled segments around a floating origin. This is spec Phase 3, steps 1–2.

## Scope

- `config/view_config.gd` (`ViewConfig`) + `config/view_config.tres`: every rendering [PARAM]: segment length and count, segments kept behind, marking dash/gap and widths, median, barrier, terrain, eye position, FOV, signal blink rate.
- `game/world/road_layout.gd` (`RoadLayout`): pure cross-section geometry (lane lines, edge lines, shoulder, median, barriers, opposite carriageway, terrain) from `RoadProfile` + `ViewConfig`.
- `game/world/road_segment_mesh.gd`: builds one shared multi-surface `ArrayMesh` per road segment (one surface per material).
- `game/world/road_view.gd` (`RoadView`): a fixed pool of segment instances recycled from behind to front; each sits at `z = -(s_segment - player.s)` (floating origin, spec *Architecture*).
- `game/player/player_input.gd` (`PlayerInput`): turns Input Map action events into one `PlayerCommands` per physics step (held accelerate/brake, one-shot lane change and signal toggles).
- `game/player/player_view.gd` (`PlayerView`): cockpit rig — driver-seat `Camera3D`, dashboard + bonnet meshes, dashboard signal lamps — whose lateral position follows `TrafficSim.lateral_position`.
- `game/main.tscn` + `game/main.gd`: builds the sim (motorway profile, player on the right lane), steps it in `_physics_process`, and updates the views. Replaces the Phase 1 "hello" label.

## Non-goals

- HUD, `SessionManager`, 90 s session and countdown, start speed (Phase 3 step 3); dev launcher and profile selection (step 4) — the scene drives the motorway profile until then.
- Traffic, decorative opposite-carriageway traffic, mirrors, scoring, pause.

## Implementation Plan

### Phase 1 — Road view
1. `ViewConfig` resource and `RoadLayout` cross-section + segment mesh builder. *Tests:* layout positions (lanes, edge lines, shoulder, median, barriers, opposite carriageway) and that the segment mesh spans exactly one segment length; the dash period divides the segment length so recycled segments line up.
2. `RoadView` with pooled segment recycling. *Tests:* scene test driving 10 km of sim time at the motorway limit: on every frame segments are contiguous (no gap or overlap) and cover the camera's far distance ahead and the configured distance behind; nodes are reused, never created or freed after setup.

### Phase 2 — Player
1. `PlayerInput`: Input Map → `PlayerCommands`. *Tests:* W/↑ and S/↓ held map to accelerate/brake, A/D/←/→ request one lane change per press, Q/E/,/. toggle signals once per press, an unmapped key yields empty commands.
2. `PlayerView` cockpit rig. *Tests:* lateral position follows lane-change progress; the dashboard/bonnet is inside the camera's vertical field of view; signal lamps follow `signal_dir`.
3. Main scene wiring: sim + input + views stepped in `_physics_process`. *Tests:* scene test — simulated W press increases player speed and moves the road; A press moves the camera one lane left.

## Risks

- No popping is a manual check; the test guarantees recycled segments appear only beyond the camera's far plane.
- Dash pattern: segments are identical meshes, so the dash period (4 m dash + 8 m gap) must divide the segment length. `segment_length_m` is 48 m instead of the spec's example 50 m.
- Visual tuning (colours, eye height, FOV) is a first pass; Phase 11 tunes it.

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Road view

- [ ] 1.1 ViewConfig, road layout and segment mesh
- [ ] 1.2 RoadView segment recycling

### Phase 2: Player

- [ ] 2.1 PlayerInput mapping
- [ ] 2.2 PlayerView cockpit rig
- [ ] 2.3 Main scene wiring
