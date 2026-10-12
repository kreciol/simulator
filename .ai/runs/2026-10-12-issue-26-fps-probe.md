# Execution plan — FPS probe and low-FPS toast (issue #26)

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Issue: #26 (E06-S02) — spec Phase 5 step 2, Edge Cases "Low FPS".

## Goal

Make web performance measurable reproducibly: `&perf=1` samples `Performance.TIME_FPS`
for 60 s of driving and prints average and 5th-percentile FPS; the README records the
reference machine and the measuring method; a sustained FPS below 30 shows a
non-blocking toast suggesting the low preset, at most once per session.

## Scope

- `PerfConfig` resource (`config/perf_config.tres`) with every tunable: probe duration,
  percentile, low-FPS threshold, how long it must be sustained, toast duration.
- Dev launcher `perf` param (`0`/`1`, default from `DevLauncherConfig.default_perf`).
- `FpsProbe` and `LowFpsWatch` — pure, sample-fed classes in `game/perf/`, unit-tested.
- `main.gd` feeds both from `Performance.TIME_FPS` while the session is driving; the
  probe prints its result once (also when the session ends before the window is full,
  marked incomplete).
- `Hud.show_toast` — a mouse-transparent, timed notice; Polish text in `i18n/strings.csv`.
- README: "Performance measurement" section — reference machine (to be filled in by the
  product owner) and the method (Chrome, level 4, motorway, `seed=1`, both presets).

## Non-goals

- Performance tuning (E12). The measurement itself on the reference machine — a human
  runs it and records results in the PR.
- A settings screen to switch quality from the toast (Phase 10).

## Decisions / assumptions

- Samples are taken once per rendered frame while the session is `DRIVING` (the
  countdown's shader warm-up is excluded); `TIME_FPS` is Godot's per-second average.
- 5th percentile uses the nearest-rank method on the frame samples.
- The toast is not shown when the session already runs on the `low` preset — there is
  nothing lower to suggest. # assumption, flagged in the PR.
- "Sustained" = FPS below the threshold continuously for `low_fps_sustain_s` (5 s).

## Implementation Plan

### Phase 1: Config and launcher
- 1.1 `PerfConfig` resource + `perf_config.tres`, wired into `main.tscn`
- 1.2 Dev launcher `perf` param and `LaunchOptions.perf`

### Phase 2: FPS probe
- 2.1 `FpsProbe` (average, nearest-rank percentile, window) with unit tests
- 2.2 Main scene feeds and prints the probe under `perf=1`

### Phase 3: Low-FPS toast
- 3.1 `LowFpsWatch` (sustained-below detection, once per session) with unit tests
- 3.2 `Hud.show_toast` + Polish string, main scene wiring and tests

### Phase 4: Docs
- 4.1 README: `perf` param, reference machine and measuring method; AGENTS.md status

## Risks

- `TIME_FPS` only updates once per second, so the percentile is over per-second
  averages repeated per frame — what the spec asks for; frame-time spikes inside one
  second are smoothed.
- Headless tests cannot measure real FPS; logic is tested with synthetic samples.

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Config and launcher

- [ ] 1.1 PerfConfig resource wired into the main scene
- [ ] 1.2 Dev launcher perf param

### Phase 2: FPS probe

- [ ] 2.1 FpsProbe with unit tests
- [ ] 2.2 Main scene feeds and prints the probe

### Phase 3: Low-FPS toast

- [ ] 3.1 LowFpsWatch with unit tests
- [ ] 3.2 HUD toast, Polish string and main scene wiring

### Phase 4: Docs

- [ ] 4.1 README and AGENTS.md
