# Execution plan — three mirrors and low/high quality presets (E06-S01)

Source doc: .ai/specs/2026-10-11-highway-driving-simulator-mvp.md
Issue: #25

## Goal

The player sees traffic behind in a rear-view and two side mirrors, and quality (low/high: mirror resolution and update interval, shadows, draw distance) plus mirrors on/off can be chosen through the dev launcher (`&quality=low|high&mirrors=0|1`) until the settings screen exists. Spec Phase 5, step 1.

## Scope

- `config/` — `QualityPreset` resource with `quality_presets/low.tres` and `high.tres`: mirror resolution scale and update interval (low: 1/4 res, every 2nd frame; high: 1/2 res, every frame — spec Architecture: Mirrors), shadows, road segment count (draw distance). `ViewConfig.for_quality(preset)` gives the session's view config with the preset's draw distance. Mirror placement, size on screen and field of view are `ViewConfig` [PARAM]s.
- `DevLauncherConfig` / `DevLauncher` / `LaunchOptions`: `quality` and `mirrors` params with documented defaults (`high`, mirrors on).
- `game/mirrors/` — `MirrorsView`: three `SubViewport`s sharing the main `World3D`, each with a rear-facing camera on the player's rig, shown mirror-flipped on screen; render size and update interval from the preset; mirrors off → none built, nothing renders. Mirror range ≤ the road kept behind and the spawner's hidden zone behind.
- `game/main.gd` / `main.tscn`: applies the preset (draw distance, fog, sun shadows) and the mirrors view.
- README dev-launcher params; AGENTS.md status and routing.

## Non-goals

- Settings screen and persisting quality (E11-S02), blind-spot icons (E08-S04).
- The level-4 FPS measurement (Phase 5 exit criterion) — needs a real browser on integrated GPU; noted for QA.

## Implementation Plan

### Phase 1 — Quality presets and launch params
1. `QualityPreset` low/high and `ViewConfig.for_quality`. *Tests:* both presets load with the spec's values; low draws less far than high; every preset's draw distance stays inside the spawner's hidden zone ahead; `for_quality` leaves the shared config untouched.
2. Dev launcher `quality` / `mirrors` params. *Tests:* `quality=low`, `mirrors=0` honoured; missing → documented defaults; invalid values fall back with a warning.

### Phase 2 — Mirrors
1. `MirrorsView` with three `SubViewport` mirrors. *Tests:* three viewports sharing the main world; size = on-screen size × preset scale; update interval (every frame vs every 2nd); a car behind in the left lane shows on the left of the rear-view mirror and in the left side mirror, a car in the right lane in the right one; mirror range inside the road behind and the hidden spawn zone; disabled → no viewports, hidden.
2. Main scene applies quality and mirrors. *Tests:* default launch uses the default preset (draw distance, shadows, mirrors shown); `mirrors=0` scene has no mirror viewports rendering; low preset shortens the camera far plane and turns shadows off.

### Phase 3 — Docs
1. README dev-launcher params, AGENTS.md status and routing.

## Risks

- Web performance: three extra 3D passes. Mitigated by the low preset (1/4 res, every 2nd frame); the FPS measurement on level 4 remains a manual QA item.
- Headless tests cannot check rendered pixels; mirror lane correctness is asserted by projecting vehicles through the mirror cameras.

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Quality presets and launch params

- [ ] 1.1 QualityPreset low/high and ViewConfig.for_quality
- [ ] 1.2 Dev launcher quality and mirrors params

### Phase 2: Mirrors

- [ ] 2.1 MirrorsView with three SubViewport mirrors
- [ ] 2.2 Main scene applies quality and mirrors

### Phase 3: Docs

- [ ] 3.1 README and AGENTS.md
