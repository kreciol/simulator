# Execution plan — touch controls (issue #86)

Source doc: .ai/specs/2026-10-20-touch-controls.md (spec PR #89)

## Goal

A session can be driven on a touch screen with on-screen buttons that fire the same Input Map actions as the keyboard, with multitouch; nothing in `core/` changes.

## Scope

Phase 1 of the spec: `PlayerInput` action events with per-source holding, the `touch` launch param, `TouchConfig` + `TouchButton`, the `TouchControls` overlay wired in `main.gd`, docs (Q16, agent rules).

**Non-goals:** orientation, touch texts in the tutorial/settings, HUD re-layout (#87); mobile performance (#88); gestures, tilt, remapping.

## Implementation Plan

### Phase 1: Input
1. `PlayerInput` accepts `InputEventAction`; held accelerate/brake per source.
2. `touch` launch param (`LaunchOptions.touch`, `DevLauncher.KEY_TOUCH`, `DevLauncherConfig.default_touch`).

### Phase 2: Touch overlay
3. `TouchConfig` + `config/touch.tres` + `TouchButton` pointer tracking.
4. `TouchControls` overlay, show/hide policy, `main.gd` wiring, scene tests.

### Phase 3: Docs
5. Q16 in the MVP spec's Decisions table; rules in `docs/agents/input.md` and `session-flow.md`.

## Risks

- Godot GUI per-index touch routing is engine behaviour; tests feed `_gui_input` directly, a real phone is checked in QA.
- The spec file lands through spec PR #89, not this branch.

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles.

### Phase 1: Input

- [ ] 1.1 PlayerInput accepts action events
- [ ] 1.2 touch launch param

### Phase 2: Touch overlay

- [ ] 2.1 TouchConfig and TouchButton
- [ ] 2.2 TouchControls overlay and main.gd wiring

### Phase 3: Docs

- [ ] 3.1 Decisions table and agent docs
