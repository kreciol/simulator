# Touch controls in a mobile browser

Source: epic #85 (E13 — Mobile: touch controls in the browser), first story #86 (E13-S01). Requirements: [`wymagania-symulator-autostrady.md`](../../wymagania-symulator-autostrady.md); architecture and earlier decisions: the [MVP spec](2026-10-11-highway-driving-simulator-mvp.md). Section references like §6.3 point into the requirements doc.

## 📝 TLDR

Players who open the game on a phone or tablet can use the menus (Godot turns a touch into a mouse click) but cannot drive: `PlayerInput` reacts to `InputEventKey` only. We propose an on-screen touch-button overlay in the driving scene that fires the **same Input Map actions** as the keyboard (accelerate, brake, lane ◀/▶, signal ⟸/⟹, pause), with true multitouch, so a whole session can be driven by touch with unchanged rules and scoring. Phase 1 (#86) ships the buttons; phase 2 (#87) the phone layout of the tutorial, settings and HUD; phase 3 (#88) mobile performance.

## 📝 Problem Statement

A phone has no keyboard, so a session started on one sits at zero speed until time runs out. The product owner requested mobile play (epic #85) and, as owner of the decision, supersedes requirements §2.2 / §3.1 (mobile and touch listed as a later extension; desktop browser named as the platform) for **touch controls in a mobile browser** only. Evidence status: a product-owner request; no usage data on how many players arrive on a phone.

## 📝 Proposed Solution

On-screen buttons (the approach the product owner chose in #85), laid out for landscape thumbs:

```
┌──────────────────────────────────────────────┐
│ [⏸]          mirrors / HUD                   │
│                                              │
│ [⟸ sig.] [sig. ⟹]                  [BRAKE]   │
│ [◀ lane] [lane ▶]                    [GAS]   │
└──────────────────────────────────────────────┘
```

Each button turns its pointer's press and release into an `InputEventAction` for its Input Map action and hands it to `Input.parse_input_event`, so it arrives through `main.gd`'s `_unhandled_input` exactly like a key — `PlayerInput` builds the step's `PlayerCommands`, `main.gd` handles `pause`. Nothing in `core/` changes, and replays (seed + commands) stay valid because a touch only ever changes which commands are produced.

Alternatives considered:

- **Gestures (swipe to change lanes)** — rejected in #85: a swipe has no natural place for the indicator, which K2 scores, and the signal-then-change sequence is what the game teaches.
- **Tilt steering** — rejected in #85: lane changes are discrete (MVP Q12), and iOS needs a separate motion permission.
- **Godot's `TouchScreenButton`** — handles touches by index, but it is a `Node2D` outside the GUI: it does not stop the emulated mouse click from reaching the HUD's buttons beneath it, and it ignores the mouse, so the desktop QA path (`touch=1`) would need the global `emulate_touch_from_mouse` setting, which changes every menu's input. Lost to a small `Control` that handles `InputEventScreenTouch` by index itself (below).
- **A plain `Button`** — gets touches only through mouse emulation, one pointer at a time: the accelerator could not be held while signalling.

## 📝 Architecture

- **`TouchButton`** (new, `game/player/`) — a `Control` with an `action`. Its `_gui_input` takes `InputEventScreenTouch` (Godot's GUI routes each touch index to the control it started on, and its release and cancel to the same control) and a real left `InputEventMouseButton` (the `touch=1` desktop path); mouse events with `device == InputEvent.DEVICE_ID_EMULATION` — the emulated copy of a touch — are accepted (so they never reach the HUD beneath) and otherwise ignored. It tracks the set of pointers holding it: the first pointer down emits a pressed action event, the last pointer up (or a cancelled touch) a released one. A finger that slides off the button keeps it held until lifted. `release_all()` drops every pointer and emits the release.
- **`TouchControls`** (new, `ui/`) — a `CanvasLayer` above the HUD that builds one `TouchButton` per `TouchConfig` entry, with a drawn icon (polygons, not a font glyph, so every browser shows it) and a short `TOUCH_*` label (shrunk to fit the button; the longer `ACTION_*` names did not fit), and lays them out on resize. It `release_all()`s on hide and on focus loss.
- **`PlayerInput`** (changed) — also accepts `InputEventAction` for the driving actions. Held accelerate/brake are tracked per source: a key by its physical keycode, an action event by its action (the button aggregates its own fingers), so releasing a key keeps the action held by a touch and vice versa. Lane change and signal stay one-shot per press. `reset()` clears every source.
- **`main.gd`** (changed) — decides whether the controls exist (below), builds them lazily, and on focus loss also releases them. The `pause` action already toggles the session.
- **`DevLauncher` / `LaunchOptions`** (changed) — a `touch` param: `1` on, `0` off, missing or invalid → `DevLauncherConfig.default_touch` (`auto`). Like every known param, it skips the menus. `LaunchOptions.again` keeps it.
- **`TouchConfig`** (new, `config/touch_config.gd` + `config/touch.tres`) — every button's action, icon, anchor, offset and size, the reference size they scale from, and the look: opacities, colours, border, label size ([PARAM]s).

When the controls exist (`TouchControls.builds_at_start` / `builds_on_touch` / `hides_on_key`, pure functions so they are unit-tested):

| `touch` | Device | Controls |
|---|---|---|
| `0` | any | never built |
| `1` | any | built and shown at start; a key press does not hide them |
| `auto` | `DisplayServer.is_touchscreen_available()` | built and shown at start |
| `auto` | no touchscreen | not built until the first `InputEventScreenTouch`, then built and shown |

In `auto`, a key press hides them (a touch laptop's player has gone to the keyboard) and the next touch shows them again; hiding releases every held button.

Input flow: touch → `TouchButton._gui_input` → `InputEventAction` → `Input.parse_input_event` → `main.gd._unhandled_input` → `PlayerInput.handle_event` (driving) or `SessionManager.toggle_pause` (pause) → `PlayerInput.consume()` once per physics step → `SessionManager.step`. The session's existing gates apply unchanged: in the countdown, a pause or a respawn the step drops the commands, exactly as it drops keys.

## 📝 Data Model

No persisted data changes. The history does not tell touch and keyboard results apart (#85, non-blocking question, default: no) — the same mode × profile × level comparison applies.

`TouchConfig` (one `TouchButtonSpec` sub-resource per button):

| Field | Meaning |
|---|---|
| `buttons: Array[TouchButtonSpec]` | `action`, `icon`, `anchor` (0–1 of the viewport), `offset` and `size` in reference pixels |
| `reference_height_px`, `reference_width_px` | viewport size at which offsets and sizes apply 1:1; they scale with the height, or the width when that is relatively smaller, so no button leaves the screen |
| `idle_alpha`, `pressed_alpha` | button opacity at rest and while held |
| `idle_icon_alpha`, `background_color`, `icon_color`, `border_width_px`, `label_outline_px`, `label_font_size`, `icon_fraction`, `corner_radius_px` | the rest of the look |

## 📝 UI/UX

- The overlay sits above the HUD and below nothing; buttons are translucent so the road stays visible. Each button pairs a drawn icon (▲ gas, ▼ brake, ◀ ▶ lane, ⟸ ⟹ signal, ⏸ pause) with its short Polish `TOUCH_*` label — never colour alone. The layout keeps clear of the speedometer and the mirrors.
- A held button is drawn opaque (`pressed_alpha`) so the player sees what is held.
- The controls show in every session state but the end screen — the pause button must resume, and a held accelerator during the countdown behaves like a held key (the press counts once driving starts).
- Phase 2 (#87): orientation handling, touch wording in the tutorial and settings, and the HUD laid out around the buttons (Implementation Plan below).

## 📝 Edge Cases & Failure Scenarios

- **Accelerate and brake both held** (any mix of keys and touches) → brake wins, as on the keyboard (`PlayerInput.consume`).
- **Two fingers on one button** → it is released only when the last one lifts.
- **Touch cancelled by the OS** (a notification, a system gesture) → `InputEventScreenTouch.canceled` releases that pointer.
- **Window or tab loses focus mid-hold** → `main.gd` resets `PlayerInput` and releases the buttons; the session pauses itself; nothing stays stuck held on resume.
- **A tap on a lane button** → one press, one lane change; holding it does not repeat.
- **Touch during the countdown, a pause or a respawn** → the step drops the commands, as for keys.
- **The emulated mouse click of a touch** → swallowed by the button it lands on, so a HUD button beneath it (e.g. the tutorial's skip) is not clicked.
- **A desktop without a touchscreen and no `touch` param** → nothing is built; no node, no cost.
- **End screen** → the controls hide so they do not cover the again / history / menu buttons.

## 📝 Risks & Impact Review

- `PlayerInput`'s held-source keying changes from keycodes to source strings; it is internal, covered by its tests.
- The new `touch` URL param joins the documented dev-launcher params (`docs/agents/session-flow.md`).
- The buttons cover parts of the screen on small phones until phase 2 re-lays out the HUD — acceptable for phase 1, which is about being able to drive at all.
- Godot's GUI per-index touch routing is engine behaviour we rely on; if a browser delivers touches differently, phase 1's QA on a real phone (and phase 3's device pass) is where it surfaces.

## 📝 Decisions in play

- Supersedes requirements §2.2 / §3.1 for touch controls in a mobile browser — product owner's decision in #85; recorded as Q16 in the MVP spec's *Decisions* table by phase 1.
- Non-goals of #85 stay: gestures, tilt, gamepads, remapping, native/PWA packaging, portrait play, changes to scoring or traffic.

## 📋 Phasing

- **Phase 1 — Drive a session by touch (#86):** the button overlay, `PlayerInput` action events with per-source holding, the show/hide policy and `touch` param, `TouchConfig`. Shippable alone: a phone can drive every mode.
- **Phase 2 — Phone layout (#87):** orientation, touch wording in the tutorial and settings, HUD re-layout around the buttons.
- **Phase 3 — Mobile performance (#88):** a phone runs smoothly by default, measured on real devices.

## 📋 Implementation Plan

### Phase 1 (#86)

1. **`PlayerInput` accepts action events.** `InputEventAction` for the six driving actions (accelerate, brake, lane ×2, signal ×2 — `pause` stays with `main.gd`); held accelerate/brake keyed per source (key keycode / action); one-shot lane and signal; `reset()` clears all. Tests: action-only driving, key + touch mixes (release one, other keeps it held), brake wins, one lane change per tap, `reset`.
2. **`touch` launch param.** `LaunchOptions.touch` (`auto` / `on` / `off`), `DevLauncher.KEY_TOUCH`, `DevLauncherConfig.default_touch` = `auto` in `dev_launcher.tres`, `again` keeps it, `describe` prints it. Tests: parse, invalid → default, skips menus.
3. **`TouchConfig` + `TouchButton`.** The resource and `config/touch.tres` with the #85 layout; `TouchButton` pointer tracking (touch by index, real mouse, emulated mouse swallowed, cancel, multi-finger, `release_all`) emitting action events through an injectable sink (`Input.parse_input_event` by default). Tests drive `_gui_input` directly.
4. **`TouchControls` overlay and `main.gd` wiring.** Build per `TouchConfig`, layout scaled to the viewport, the show/hide policy table, lazy build on the first touch, hide on key in `auto`, hide on the end screen, release on focus loss. Tests: no node on desktop without the param; `touch=1` shows and a mouse press on the accelerator speeds the car up; pause button pauses and resumes; held accelerator plus signal and lane taps (multitouch); input dropped in the countdown; a seeded replay of a touch-driven session reproduces it.
5. **Docs.** Q16 in the MVP spec's *Decisions* table; the `touch` param and the touch rules in `docs/agents/input.md` / `session-flow.md`.

### Phase 2 (#87)

1. **Screen helpers.** `ScreenFit` (`ui/`): portrait, CSS px per canvas unit, the display's safe area in canvas units, `fit_buttons` for the minimum touch target (`TouchConfig.min_touch_target_px`, 24 CSS px — WCAG 2.2 target size minimum); `TouchControls.button_rect(s)` and `safe_area`; the screen-size matrix as one test fixture (`tests/fixtures/screen_matrix.gd`).
2. **Orientation.** `RotateNotice` (icon + text, above everything, takes every touch) on the drive, the start and the history screen of a touch device; the drive pauses while it shows and stays paused until the player resumes in landscape.
3. **Tutorial and texts.** `Tutorial.TOUCH_PROMPT_KEYS` / `ACTIONS`; by touch the HUD names the buttons, shows their icons (`TouchIcon`, the buttons' own drawing) and puts the skip button on the step's row; the pause hint names the pause button; the signal buttons are "Lewy/Prawy kierunkowskaz".
4. **HUD re-layout.** `Hud.set_layout(area, touch, min_target)` from `main.gd`: headings in the band above the button rows, blind-spot warnings above the side mirrors, muted sign beside the pause button, everything inside the safe area. Tests: no overlap and the touch target at every matrix size, each phone 60 px shorter; notch; desktop unchanged.
5. **Menus.** Start, setup, settings and history buttons fit a finger on a touch device; the settings preview the touch buttons instead of keys alone.

The brake stays 180×104 reference px: a taller one would reach the right mirror. A 44 px target (Apple HIG) would not fit the setup page on a 315 px tall screen without a redesign.

### Phase 3 (#88)

Specified in its own story; it builds on the `perf=1` probe.

## Resolved assumptions (autonomous defaults)

| # | Question | Applied default | Why |
|---|---|---|---|
| Q1 | One spec for the epic, or one per story? | One spec for E13; phase 1 (#86) is specified to step level and ships on its own PR, phases 2–3 build on it. | #86 asked for an epic-wide spec; each phase is independently shippable. Reversible. |
| Q2 | `TouchScreenButton` or a custom `Control`? | A small `Control` (`TouchButton`) handling `InputEventScreenTouch` by index. | It swallows the emulated mouse click (no HUD button fires beneath) and works with a real mouse for `touch=1` QA without a global input setting. Reversible. |
| Q3 | Does `touch=` alone skip the menus? | Yes, like every known launcher param. | One rule for all params (`DevLauncher.has_launch_params`). Reversible. |
| Q4 | A finger that slides off a button? | Stays held until lifted. | Thumbs drift on glass; dropping the accelerator under a drifting thumb would be worse. Reversible (a `TouchConfig` flag later). |
| Q5 | Keep touch and keyboard results apart in the history? | No. | #85's stated default; no schema change. |
