# AGENTS.md

## Project overview

A lightweight browser game that teaches inexperienced drivers correct motorway and expressway driving under Polish traffic law: keeping right, signalling lane changes, and keeping the legal following distance (half the speed in km/h, in metres). Short 90-second sessions, two modes (learn with live hints, exam without), scoring with supportive verbal feedback, local result history. Built with **Godot 4.x / GDScript** and exported to **Web (WebAssembly + WebGL 2)**.

The source of truth for scope and behaviour is [`wymagania-symulator-autostrady.md`](wymagania-symulator-autostrady.md) (Polish). Its markers mean: **[DECYZJA]** fixed requirement, **[PROPOZYCJA]** default that may change, **[PARAM]** value that must live in config, **[OTWARTE]** unresolved — implement the default and mark the code `# TODO(open):`.

**Decisions take precedence:** the MVP spec [`.ai/specs/2026-10-11-highway-driving-simulator-mvp.md`](.ai/specs/2026-10-11-highway-driving-simulator-mvp.md) resolves the requirements doc's [OTWARTE] items in its *Decisions* table and defines the architecture and phasing. Where the two disagree, the spec wins; use `# TODO(open):` only for questions neither document settles.

> Progress: the epics and stories in the tracker and [`.ai/specs/backlog.md`](.ai/specs/backlog.md). Do not record phase status in this file (see *Maintaining these docs*).

## Task routing

Before changing an area, read its file in [`docs/agents/`](docs/agents/): it lists what to read first and the area's rules.

- **Project skeleton, `project.godot`, export, CI** → [`docs/agents/project-setup.md`](docs/agents/project-setup.md)
- **Simulation core: vehicles, lanes, lane queries** (`core/sim/`) → [`docs/agents/simulation.md`](docs/agents/simulation.md)
- **Traffic AI and spawning** (`core/ai/`, `core/sim/spawner.gd`) → [`docs/agents/traffic-ai.md`](docs/agents/traffic-ai.md)
- **Scoring, event log and session record** (`core/scoring/`) → [`docs/agents/scoring.md`](docs/agents/scoring.md)
- **Feedback texts, live hints and session summary** (`core/feedback/`, `ui/summary_panel.gd`, `ui/hint_list.gd`) → [`docs/agents/feedback.md`](docs/agents/feedback.md)
- **Rendering: road, player camera, traffic** (`game/world/`, `game/player/`, `game/traffic/`) → [`docs/agents/rendering.md`](docs/agents/rendering.md)
- **Mirrors** (`game/mirrors/`) → [`docs/agents/mirrors.md`](docs/agents/mirrors.md)
- **Sound effects** (`game/audio/`) → [`docs/agents/audio.md`](docs/agents/audio.md)
- **HUD** (`ui/hud.gd`) → [`docs/agents/hud.md`](docs/agents/hud.md)
- **Performance and the FPS probe** (`game/perf/`) → [`docs/agents/performance.md`](docs/agents/performance.md)
- **Session flow, pause, respawn, dev launcher** (`game/session/`, `core/sim/respawn.gd`) → [`docs/agents/session-flow.md`](docs/agents/session-flow.md)
- **Input** (`game/player/player_input.gd`) → [`docs/agents/input.md`](docs/agents/input.md)
- **Persistence and history** (`persistence/`, `ui/history_screen.gd`) → [`docs/agents/persistence.md`](docs/agents/persistence.md)
- **Tunable numbers** (`config/`) → [`docs/agents/config.md`](docs/agents/config.md)
- **Tests** (`tests/`) → [`docs/agents/tests.md`](docs/agents/tests.md)
- **Product discovery, a product brief, or a backlog** → [`docs/agents/product.md`](docs/agents/product.md) <!-- discovery:routing-start --><!-- discovery:routing-end -->

A new area gets its own file in `docs/agents/`, one line here and an `@` import in `CLAUDE.md`.

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

## Maintaining these docs

Several PRs run in parallel, and git merges line by line, so these files are kept merge-friendly:

- Update them only when a **rule or contract** an agent must follow changes. A new class or file is not a reason on its own.
- Name directories, not every class in them (`core/feedback/`, not a list of its classes). Name a class only when a rule is about it.
- One rule per bullet, one bullet per line. Add a new rule as a new bullet next to the related ones; do not append sentences to an existing bullet.
- No progress, phase status or changelog here or in `docs/agents/` — that lives in the tracker, `.ai/specs/backlog.md` and git history.
- Keep this file an index: area rules belong in `docs/agents/<area>.md`.

## Process

- Ticket flow, labels, QA gate: [`SDLC.md`](SDLC.md)
- Review rules: [`CODE_REVIEW.md`](CODE_REVIEW.md)
- Pipeline config: [`.ai/agentic.config.json`](.ai/agentic.config.json); specs in `.ai/specs/`
