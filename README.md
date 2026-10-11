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
