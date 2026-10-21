# Project skeleton, export and CI

**Read first:** requirements §3, §17 step 1; `project.godot`, `export_presets.cfg`, `.github/workflows/ci.yml`.

- Renderer **Compatibility** (WebGL 2) only — no Forward+/Mobile-only features.
- Single-threaded web export (no COOP/COEP, no `SharedArrayBuffer`).
- Pin the Godot version (**4.7.2**) in `project.godot` and README.
- `.tscn`/`.tres` in text format.
- The §15.1 directories exist; an empty one keeps a `.gitkeep` until its phase lands.
- GitHub Pages deploys from the `gh-pages` branch: `main` owns the root, PR previews live under `pr/<n>/<sha7>/`.
- Every write to `gh-pages` goes through `.github/scripts/publish-gh-pages.sh`, in the `gh-pages` concurrency group (`cancel-in-progress: false`); change it together with `test-publish-gh-pages.sh`.
- Previews are published only for same-repo PRs carrying `needs-qa`, from CI's own `web-build` artifact (the PR merged with its base, as tested), and removed when the PR closes.
- Jobs that write `gh-pages` or comment hold `contents: write` / `pull-requests: write` at job level; the workflow default stays `contents: read`.
