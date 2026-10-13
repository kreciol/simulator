# Execution plan — sound effects

Source doc: .ai/specs/2026-10-13-sound-effects.md (spec PR #74)
Issue: #72

## Goal

Simple sound effects that follow the simulation — engine pitch with speed, indicator tick-tock in sync with the blink, a whoosh for close passes, collision and off-road one-shots — plus a mute key with a HUD indicator, without touching `core/`.

## Scope

- New `game/audio/` (`AudioView`, `AudioSynth`, `PassDetector`), `config/audio_config.gd` + `.tres`, `default_bus_layout.tres`.
- `game/main.gd` / `game/main.tscn` wiring, the `mute` Input Map action, `Hud.set_muted` + strings.
- Tests in `tests/game/audio/`, `tests/config/`, `tests/ui/`, `tests/project_settings_test.gd`.
- Docs: MVP spec Q15 row, `docs/agents/audio.md`, AGENTS.md routing line, CLAUDE.md import.

## Non-goals

Voice, music, ambient noise, a settings screen, persisting mute, sample asset files.

## Implementation Plan

Phases and steps follow the spec's Implementation Plan one to one.

## Risks

- Web sample playback with `pitch_scale` cannot be verified headless; the manual web smoke check is noted on the PR as pending.
- `perf=1` on the reference machine cannot run here; noted as pending QA.

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Audio foundation and engine

- [x] 1.1 Buses and AudioConfig — 8f2e7af
- [x] 1.2 AudioSynth streams — 8fc6a6e
- [x] 1.3 AudioView engine and silence rules — 09fed8a
- [x] 1.4 Mute action, first-gesture unlock and HUD indicator — bccf8f3

### Phase 2: Indicator and incidents

- [x] 2.1 Indicator tick-tock — 361ab2f
- [x] 2.2 Collision and off-road one-shots — 361ab2f

### Phase 3: Passing vehicles

- [ ] 3.1 PassDetector and pooled whoosh
- [ ] 3.2 Docs: Q15, agents audio area
