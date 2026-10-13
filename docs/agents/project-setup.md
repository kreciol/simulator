# Project skeleton, export and CI

**Read first:** requirements §3, §17 step 1; `project.godot`, `export_presets.cfg`, `.github/workflows/ci.yml`.

- Renderer **Compatibility** (WebGL 2) only — no Forward+/Mobile-only features.
- Single-threaded web export (no COOP/COEP, no `SharedArrayBuffer`).
- Pin the Godot version (**4.7.2**) in `project.godot` and README.
- `.tscn`/`.tres` in text format.
- The §15.1 directories exist; an empty one keeps a `.gitkeep` until its phase lands.
