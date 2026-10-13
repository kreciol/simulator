# Code review rules

Applied automatically by `om-code-review` (and therefore `om-auto-review-pr`) on top of its built-in checklist. Derived from the requirements in [`wymagania-symulator-autostrady.md`](wymagania-symulator-autostrady.md); update this file as the codebase establishes its own conventions.

## Review priorities

1. **Correctness of the driving rules.** Scoring and AI must match the requirements exactly: `min_gap_m = speed_kmh / 2`, K1 not applied while overtaking, K2 grace period before any penalty, signal validity (`OK / LATE / NONE / WRONG`) with the configured minimum signal time. A rule change without a matching requirements update is a blocker.
2. **Simulation/presentation separation.** Code in `core/` must not reference scenes, nodes, `Node3D`, cameras, or rendering. `game/` and `ui/` only read simulation state; scoring only observes it.
3. **Determinism.** Simulation advances in fixed-step `_physics_process`; randomness goes through the session's seeded RNG. Frame-rate-dependent logic in `core/` is a blocker.
4. **Web platform limits.** No Forward+/Mobile-only rendering features, no threads or APIs requiring `SharedArrayBuffer`/COOP/COEP.

## Repo-specific checks

- **Static typing everywhere**: every `var`, parameter, and return type is typed. Untyped GDScript in new code is a major finding.
- **No magic numbers for [PARAM] values**: speeds, gaps, grace periods, penalty weights, densities, durations come from `config/*.tres` resources. A tunable literal in code is a major finding.
- **Tests with logic changes**: any change in `core/` (sim, AI, scoring, feedback) ships with gdUnit4 tests. Scoring rules have tests mirroring the acceptance criteria in requirements §16 (e.g. 140 km/h: 50 m → K1 penalty, 75 m → none; 20 m penalised more than 50 m).
- **Shared lane logic**: AI and scoring call the same `is_lane_free` / `gap_to_leader` / `min_gap` functions; a duplicated re-implementation is a major finding.
- **Performance on hot paths**: no allocations or node creation per frame in traffic/road updates — use pooling and segment recycling. Mirrors and other `SubViewport`s respect the quality setting.
- **Input** through Input Map actions, never raw keycodes.
- **Player-facing text** through translation files; tone supportive and explanatory (requirements §1.3, §11.2).
- **Persistence**: changes to the saved session format bump `schema_version` and include a migration for older records.
- **Open questions**: an `[OTWARTE]` default implemented in code carries `# TODO(open):` with the requirements section number.
- **Scenes and resources** stay in text format (`.tscn`, `.tres`); no binary `.scn`/`.res` for authored content.
- **Agent docs stay merge-friendly** (`AGENTS.md`, `docs/agents/`, see *Maintaining these docs* in `AGENTS.md`): a PR that adds phase status or progress, lists classes instead of directories, or appends to an existing rule bullet instead of adding a new one is a minor finding. A changed rule or contract with no matching update in its `docs/agents/<area>.md` is a major finding.

## Severity

- **Blocker** — wrong rule behaviour vs. requirements, broken validation gate, web export broken, `core/` depending on scenes, non-deterministic simulation, data-loss risk in saves.
- **Major** — missing tests for logic, untyped code, hard-coded [PARAM] values, duplicated lane logic, per-frame allocations on hot paths.
- **Minor** — naming, comments, small readability issues; deferrable to a follow-up.

The validation gate (see `AGENTS.md`) must be green before approval.
