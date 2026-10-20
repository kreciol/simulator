# om-prepare-test-env — repo-local notes

- Entrypoint: `sh .ai/scripts/test-env-up.sh` (Git Bash on Windows). It exports the Godot Web build (`godot --headless --path . --export-release "Web" build/web/index.html`, ~30 s cold) and serves `build/web/` with `python -m http.server` on `127.0.0.1`.
- On Windows `python3` can be the Microsoft Store alias stub: the script picks the interpreter by running it, not by `command -v`.
- The game renders to a canvas: the DOM has no UI elements, so drive it with keyboard/mouse and verify with screenshots. Dev-launcher URL params (e.g. `?screen=tutorial`) skip the menus.
