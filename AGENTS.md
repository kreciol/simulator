# AGENTS.md

## Project overview

A lightweight browser game that teaches inexperienced drivers correct motorway and expressway driving under Polish traffic law: keeping right, signalling lane changes, and keeping the legal following distance (half the speed in km/h, in metres). Short 90-second sessions, two modes (learn with live hints, exam without), scoring with supportive verbal feedback, local result history. Built with **Godot 4.x / GDScript** and exported to **Web (WebAssembly + WebGL 2)**.

The source of truth for scope and behaviour is [`wymagania-symulator-autostrady.md`](wymagania-symulator-autostrady.md) (Polish). Its markers mean: **[DECYZJA]** fixed requirement, **[PROPOZYCJA]** default that may change, **[PARAM]** value that must live in config, **[OTWARTE]** unresolved — implement the default and mark the code `# TODO(open):`.

**Decisions take precedence:** the MVP spec [`.ai/specs/2026-10-11-highway-driving-simulator-mvp.md`](.ai/specs/2026-10-11-highway-driving-simulator-mvp.md) resolves the requirements doc's [OTWARTE] items in its *Decisions* table and defines the architecture and phasing. Where the two disagree, the spec wins; use `# TODO(open):` only for questions neither document settles.

> Status: Phase 1 skeleton in place — Godot **4.7.2** project, gdUnit4 gate, CI with GitHub Pages deploy; Phase 2 simulation core in place (vehicle motion, lane changes, signals, `LaneQuery`, collisions, seeded replay); Phase 4 AI drivers in place (IDM car-following, MOBIL keep-right lane changes). The §15.1 directories exist but stay empty (`.gitkeep`) until their phase lands; entries still marked (planned) have no code yet.

## Task routing

| When the task involves… | Read first | Key rules |
|---|---|---|
| Project skeleton, `project.godot`, export, CI | requirements §3, §17 step 1; `project.godot`, `export_presets.cfg`, `.github/workflows/ci.yml` | Renderer **Compatibility** (WebGL 2) only — no Forward+/Mobile-only features. Single-threaded web export (no COOP/COEP, no `SharedArrayBuffer`). Pin the Godot version in `project.godot` and README. `.tscn`/`.tres` in text format. |
| Simulation core: vehicles, lanes, lane queries | requirements §4.3, §8.4, §15.2; `core/sim/` (`TrafficSim`, `VehicleState`, `PlayerCommands`, `LaneQuery`, `InputLog`) | Pure GDScript classes with **no scene or rendering dependencies** (a test scans `core/`). Logical coordinates only (longitudinal `s` in metres at the body centre, lane index / lateral offset). Fixed-step `_physics_process`; the only RNG is `TrafficSim.rng`, seeded at construction — seed + `InputLog` replays a session exactly. Free-lane, gap, overtaking and signal checks go through `LaneQuery`, never re-implemented. The player is a `VehicleState` like any AI car. |
| Traffic AI | requirements §7; `core/ai/` (`Idm`, `AiDriver`); tunables in `SimConfig` | IDM-style car-following, simplified MOBIL lane changes. AI uses the **same** `is_lane_free` / `min_gap` functions as scoring. Never spawn into or near a collision. Object pooling, no create/free churn. |
| Scoring and event log | requirements §8, §16 (Ocenianie); `core/scoring/`, `config/scoring.tres` (planned) | Scoring **observes** the simulation, never mutates it. Every rule K1–K4 / N1–N3 has unit tests mirroring the acceptance criteria. Continuous events are aggregated into segments, not logged per frame. |
| Feedback texts and session summary | requirements §11; `core/feedback/` (planned) | Rule/template based, no external API. Supportive tone, explain the rule ("why"), not just the error. All strings through translation files (Polish first). |
| Rendering: road, player camera, mirrors, HUD | requirements §4–§5, §14; `game/`, `ui/` (planned) | Presentation only reads simulation state. Floating origin and segment recycling for the infinite road. Mirrors via low-res `SubViewport` behind a quality switch. Budget: 60 FPS target / 30 FPS min on integrated GPU, package ≤ 50 MB. |
| Input | requirements §6 | Actions defined in the Godot **Input Map**, never hard-coded keys. |
| Persistence and history | requirements §13; `persistence/` (planned) | `user://` (IndexedDB on web). Every saved record carries `schema_version`; changing the format needs a migration. |
| Tunable numbers | requirements §0, §14 (Konfigurowalność); `config/` (`RoadProfile` + `road_profiles/*.tres`, `SimConfig` + `sim_config.tres`) | Every **[PARAM]** lives in a `.tres` resource or the single config file — never a literal in code. Road profiles and difficulty levels are `Resource`s. |
| Tests | requirements §14 (Testowalność); `tests/`, `addons/gdUnit4/` (vendored, v6.2.2) | gdUnit4. Logic in `core/` is fully unit-tested; tests run headless. |

## Code conventions

- GDScript with **full static typing**: typed variables, parameters, and return types (`var speed: float`, `func min_gap(speed_kmh: float) -> float`).
- Cross-node communication through Godot signals (`lane_change_started`, `lane_change_finished`, `collision`, `score_event_emitted`, `session_ended`). Autoloads only for global services (`Config`, `SaveManager`, optionally `EventBus`).
- Language: code, comments, commits, PRs, and issues in **English**; player-facing UI text in **Polish**, via translation files.
- No personal data collection, no accounts, no external telemetry.

## Validation gate

Run in order; any non-zero exit fails the gate (CI runs the same two commands on every PR):

```bash
godot --headless --path . --import
godot --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests
```

## Process

- Ticket flow, labels, QA gate: [`SDLC.md`](SDLC.md)
- Review rules: [`CODE_REVIEW.md`](CODE_REVIEW.md)
- Pipeline config: [`.ai/agentic.config.json`](.ai/agentic.config.json); specs in `.ai/specs/`
