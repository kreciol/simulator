# Execution plan — issue #47: the final build meets every MVP acceptance criterion with evidence

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md (Phase 11 step 1 and the exit criteria)
Issue: #47 (E12-S01, epic #46)

## Goal

Check every requirements §16 criterion off with evidence — a test name or a recorded manual check — on the deployed build, and confirm the build-size, first-load and FPS exit criteria still hold.

## Scope

- A §16 evidence record in `.ai/analysis/` mapping each criterion to the tests that assert it, or to a recorded manual check on the deployed build.
- Headless tests for the criteria only partly covered today: the opposite carriageway in the cockpit view (W3), AI never hitting a passive player (A3), measured traffic rising level by level (A4), the N1 signal boundary at exactly `signal_min_on_s` (O5).
- Build size and first load measured on the web export and on GitHub Pages.
- The Phase 5 FPS method re-run on the deployed build; README results updated.
- A negative check that the tuned [PARAM]s live in `config/` resources, not code literals.

## Non-goals

- Playtests with target users (E12-T01, #48).
- Retuning weights, densities or exam pass marks: nothing in this run changes a [PARAM] value. Tuning from playtests lands with #48 (and only in `.tres` files).
- New features or UI changes.

## Implementation Plan

### Phase 1: Missing headless evidence
1. W3 test: the opposite carriageway and the median barrier are in the cockpit camera's view.
2. A3 test: across levels 1–4, on the right and the left lane, AI never runs into a player that just holds its speed.
3. A4 test: the measured traffic of each level is clearly denser than the level below.
4. O5 boundary test: a signal held for exactly `signal_min_on_s` earns N1.
5. [PARAM] check: every requirements [PARAM] is written in its `.tres`.

### Phase 2: Measurements and the evidence record
1. Record build size, first load and the FPS probe on the deployed build; update the README results table.
2. Write the §16 evidence record in `.ai/analysis/`.

## Risks

- A new test may expose a real defect (for example an AI rear-ending a slow player). Then the test is kept and the defect fixed or filed, not the assertion weakened.
- Manual checks are recorded on the product owner's reference laptop by an agent-driven Chrome; a human playtest may still disagree.

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Missing headless evidence

- [x] 1.1 W3 test: the opposite carriageway and the median barrier are in the cockpit camera's view — 54f460a
- [x] 1.2 A3 test: AI never runs into a player that just holds its speed — 54f460a
- [x] 1.3 A4 test: measured traffic rises level by level — 54f460a
- [x] 1.4 O5 boundary test: a signal held for exactly `signal_min_on_s` earns N1 — 54f460a
- [x] 1.5 [PARAM] check: every requirements [PARAM] is written in its .tres — 6372fd1

### Phase 2: Measurements and the evidence record

- [x] 2.1 Record build size, first load and FPS on the deployed build; update README results — 9c085f1
- [x] 2.2 Write the §16 evidence record — 9c085f1
