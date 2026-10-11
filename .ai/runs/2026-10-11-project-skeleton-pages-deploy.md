# Execution plan — project skeleton & delivery pipeline (E01-S01)

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Issue: #2

## Goal

Land the empty Godot 4.7.2 project, a working headless validation gate (import + gdUnit4), and a GitHub Actions pipeline that tests every PR and deploys the web build to GitHub Pages on push to `main` — spec Phase 1, steps 1–3.

## Scope

- `project.godot`: Compatibility renderer, 1280×720 base, stretch `canvas_items`/`expand`, Input Map actions `accelerate, brake, lane_left, lane_right, signal_left, signal_right, pause` with the requirements §6.3 bindings.
- Directory layout per requirements §15.1 (empty dirs kept with `.gitkeep`), main scene with a "hello" label.
- `.gitattributes` enforcing LF; Godot `.gitignore` entries.
- gdUnit4 vendored in `addons/gdUnit4` (pinned), one trivial test under `tests/`.
- `export_presets.cfg` with a single-threaded Web preset.
- `.github/workflows/ci.yml`: PR → import + tests; push to `main` → also web export + GitHub Pages deploy + printed build size.
- README: pinned Godot version, how to run locally and run tests.

## Non-goals

- Gameplay, simulation, menus, translations (later phases).
- Changing repository settings (enabling Pages) — documented as a manual one-time step.

## Implementation Plan

### Phase 1 — Project skeleton
1. `project.godot`, Input Map, directory layout, `.gitattributes`, `.gitignore`, hello main scene.

### Phase 2 — Test gate
1. Vendor gdUnit4 and add a trivial test; confirm both gate commands exit 0 and a failing test exits non-zero.

### Phase 3 — Delivery pipeline
1. Single-threaded Web export preset; verify a local headless web export.
2. GitHub Actions workflow (PR tests; main export + Pages deploy + build size).
3. README with Godot version and local run instructions; update AGENTS.md status.

## Risks

- gdUnit4 CLI flags may differ from the configured gate command — adjust config/AGENTS.md if so.
- Pages deploy needs the repo's Pages source set to "GitHub Actions" (one-time manual setting); the first deploy fails until it is.
- Export templates download (~1 GB zip) slows CI; cached by Godot version.

## Progress

PR: #15

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Project skeleton

- [x] 1.1 project.godot, Input Map, layout, gitattributes, gitignore, hello scene — 0fd70c8

### Phase 2: Test gate

- [x] 2.1 Vendor gdUnit4 and add a trivial test — 61068cf

### Phase 3: Delivery pipeline

- [x] 3.1 Single-threaded Web export preset — c894ad9
- [x] 3.2 GitHub Actions workflow with Pages deploy — 6dd9e55
- [x] 3.3 README and AGENTS.md status — 0e4d8d9
