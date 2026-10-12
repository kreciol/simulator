# Execution plan — varied AI vehicles with brake lights and indicators; hitting one ends the session (E04-S03)

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Issue: #13

## Goal

The player sees the AI traffic: cars, vans/SUVs and trucks in several colours, brake lights when braking, indicators blinking before lane changes, rendered from a view pool that never creates or frees per spawn. Until Phase 7, a player collision or leaving the road ends the session with the plain "session ended" screen. Spec Phase 4, step 4.

## Scope

- Traffic in the session: `DevLauncherConfig.levels` (the four `DifficultyLevel` resources) and `LaunchOptions.difficulty`, resolved by `DevLauncher` from `level`; `SessionManager.start` attaches a `Spawner` for that level, so the drivable scene has traffic.
- `SessionManager` ends the session when the player collides or goes off-road (`end_reason`: `TIME_UP`, `COLLISION`, `OFF_ROAD`), handled after the step so the end is emitted once.
- `game/traffic/` — `VehicleView` (one low-poly body per look: car, van/SUV, truck; colour; brake lights; four indicators), `VehicleLook` (deterministic look and colour from the vehicle id — no RNG draw, so seed replays are unaffected), `BrakeLights` (lit while decelerating beyond a threshold), `TrafficView` (pooled views following `TrafficSim.vehicle_added` / `vehicle_removed`, placed at `z = -(s - player.s)`).
- `ViewConfig` [PARAM]s: vehicle colour palette, van share of cars, brake-light threshold.
- `game/main.gd` / `main.tscn`: `TrafficView` node; HUD's end notice gets a dimmed backdrop so it reads as a screen.
- AGENTS.md status/routing update.

## Non-goals

- Learn-mode respawn, exam abort reasons on screen, K4 wiring (Phase 7); the end screen stays plain.
- Mirrors (Phase 5), scoring wiring into the session.
- A sim-level van kind: vans/SUVs share the car footprint in the sim, so only the look differs.

## Implementation Plan

### Phase 1 — Traffic and the collision outcome in the session
1. Difficulty levels reach the session and the spawner runs in it. *Tests:* `level=3` resolves to level 3's resource; a started session has traffic at the level's density; default level without params.
2. Player collision / off-road ends the session. *Tests:* forced collision ends the session once with `COLLISION`; off-road lane change ends it with `OFF_ROAD`; AI–AI contact does not; no collision → ends at 90 s with `TIME_UP`.

### Phase 2 — Vehicle views
1. `VehicleView`, `VehicleLook`, `BrakeLights` with config. *Tests:* each look builds its body; colours vary; brake lights follow deceleration / brake command; indicators blink on the signalled side only.
2. `TrafficView` pooled and wired into the main scene; end-screen backdrop. *Tests:* view count equals live AI vehicle count across spawns/despawns, no new views after warm-up churn (pool reuse); positions follow `s` and lateral; main scene shows traffic; a forced collision in the main scene shows the end screen.

### Phase 3 — Docs
1. AGENTS.md status and routing rows.

## Risks

- Web performance with up to ~80 vehicle views: each view is a handful of `BoxMesh` instances sharing materials per colour; measured in Phase 5.
- Session start now populates traffic; existing main-scene tests drive the player and could hit traffic. Default level 1 is sparse and the spawner keeps a clearance around the player; tests that need an empty road use `SessionManager.setup` directly.

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Traffic and the collision outcome in the session

- [x] 1.1 Difficulty levels reach the session and the spawner runs in it — 4a0af5f
- [x] 1.2 Player collision or off-road ends the session — c0b2650

### Phase 2: Vehicle views

- [ ] 2.1 Vehicle view with looks, colours, brake lights and indicators
- [ ] 2.2 Pooled traffic view in the main scene and end-screen backdrop

### Phase 3: Docs

- [ ] 3.1 AGENTS.md status and routing
