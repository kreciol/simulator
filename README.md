# Symulator autostrady

A lightweight browser game that teaches inexperienced drivers correct motorway and expressway driving under Polish traffic law: keeping right, signalling lane changes, and keeping the legal following distance. Built with Godot and exported to the Web.

- Requirements (Polish): [`wymagania-symulator-autostrady.md`](wymagania-symulator-autostrady.md)
- MVP spec and delivery plan: [`.ai/specs/2026-10-11-highway-driving-simulator-mvp.md`](.ai/specs/2026-10-11-highway-driving-simulator-mvp.md)
- Contributor and agent guide: [`AGENTS.md`](AGENTS.md)

## Requirements

- **Godot 4.7.2** (standard build, not .NET). The version is pinned in `project.godot`, in this README, and in `.github/workflows/ci.yml` — upgrade all three in one PR.
- For a local Web export: the Godot 4.7.2 export templates (Editor → Manage Export Templates).

## Run locally

Open the project in the Godot editor and press **F5**, or from a terminal:

```bash
godot --path .
```

The game opens on the start screen: **Nowa sesja** picks mode, road profile and level (learn mode selected, the recommended level marked, the exam marked as suggested after 3 completed learn sessions — `config/menu.tres`), then the 3-2-1 countdown starts the drive. The end screen offers the same session again (new seed), the history or the menu. **Ustawienia** sets the graphics quality and the mirrors for the next sessions — remembered in `user://settings.cfg` (IndexedDB on web) — toggles fullscreen and previews the key bindings (read-only). The tutorial is listed but not available yet.

### Dev launcher

The dev launcher is a debug shortcut past the menus: any of the params below in the URL on the web build, or in the user args after `--` on desktop, starts the session (or the history) directly, once per page load. The session's mode, road profile, difficulty level and seed — and the graphics quality, mirrors and FPS probe — then come from them:

```text
# Web (GitHub Pages or a local export)
https://<pages-url>/?mode=exam&profile=expressway&level=3&seed=42&quality=low&mirrors=0
# Desktop
godot --path . -- --mode=exam --profile=expressway --level=3 --seed=42 --quality=low --mirrors=0
```

| Param | Values | Default |
|---|---|---|
| `mode` | `learn`, `exam` | `learn` |
| `profile` | `motorway`, `expressway` | `motorway` |
| `level` | `1`–`4` | `1` |
| `seed` | integer ≥ 0 | random |
| `quality` | `low`, `high` — mirror resolution and refresh, shadows, draw distance (`config/quality_presets/`) | `high` |
| `mirrors` | `0` (off), `1` (on) | `1` |
| `perf` | `0` (off), `1` — print average and 5th-percentile FPS after 60 s of driving (see [Performance measurement](#performance-measurement)) | `0` |
| `screen` | `drive`, `history` — open the result history (recent sessions, bests, score trend) instead of a session | `drive` |

A missing or invalid value falls back to its default (with a warning in the console); defaults live in `config/dev_launcher.tres`. The resolved options, including the seed, are printed at start (`Dev launcher: mode=… seed=…`), so a session can be replayed with the same seed.

## Performance measurement

Web performance is the project's main risk (spec Phase 5 step 2, requirements §14 and §16). It is measured the same way every time, on one reference machine, so results compare across builds.

### Reference machine

The product owner's laptop, measured on its integrated GPU:

| | |
|---|---|
| Laptop model | Dell Latitude 5540 |
| CPU / integrated GPU | Intel Core i7-1370P / Intel Iris Xe Graphics (Chrome renders on it: `chrome://gpu` shows `ANGLE (Intel, Intel(R) Iris(R) Xe Graphics … Direct3D11 …)`; the laptop also has an NVIDIA MX550, which must not be the one in use) |
| OS | Windows 11 Pro (build 26200) |
| Browser | Google Chrome 154.0.8037.98 |

### Method

1. Plug the laptop in (no battery saver), close other tabs and apps, and open the deployed build (GitHub Pages) or a local Web export in Chrome at full screen.
2. Open DevTools → Console, then load the page with:
   - `?perf=1&level=4&profile=motorway&seed=1&quality=low`
   - `?perf=1&level=4&profile=motorway&seed=1&quality=high`
3. Drive for the whole session, keeping right at about the speed limit; do not switch tabs. FPS is read from `Performance.TIME_FPS` every frame over the first 60 s of driving, each reading weighted by its frame time; the countdown and stalls (frames over `max_frame_s`, such as a hidden tab) are not counted.
4. Copy the console line `FPS probe: avg=… p5=… over 60.0 s (… frames) | mode=… quality=…` for each preset into the PR. A line marked `incomplete` means the session ended early (a crash) — run it again.

**Exit criterion (§16):** on the `low` preset, average ≥ 30 FPS and 5th percentile ≥ 25 FPS. The probe's settings live in `config/perf_config.tres`.

### Results

| Date | Build | Preset | avg FPS | p5 FPS | Frames (60 s) |
|---|---|---|---|---|---|
| 2026-10-12 | PR #57 (`1a09a3e`), local Web export | `low` | 60.0 | 60.0 | 3599 |
| 2026-10-12 | PR #57 (`1a09a3e`), local Web export | `high` | 60.0 | 60.0 | 3599 |

Both presets hold the display's 60 Hz vsync cap at level 4 with mirrors on, so the §16 criterion is met with margin.

Separately from the probe, any session whose FPS stays below 30 for a few seconds shows a short notice suggesting the low preset — once per session at most, and never when already on `low`.

## Run the tests

The same two commands form the validation gate in CI; both must exit 0:

```bash
godot --headless --path . --import
godot --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests
```

Tests use [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) v6.2.2, vendored in `addons/gdUnit4`. Reports are written to `reports/` (git-ignored).

## Web build

```bash
godot --headless --path . --export-release "Web" build/web/index.html
```

The export is single-threaded, so it runs on any static host without COOP/COEP headers. To try it locally, serve `build/web/` over HTTP (for example `python -m http.server -d build/web`) — opening `index.html` from disk does not work.

## Deployment

`.github/workflows/ci.yml` runs import and tests on every pull request, and exports the Web build on every run. On a push to `main` it also deploys the build to GitHub Pages and prints the build size in the job summary.

One-time setup: in the repository settings, set **Pages → Build and deployment → Source** to **GitHub Actions**.
