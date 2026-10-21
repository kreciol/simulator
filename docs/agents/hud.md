# HUD

**Read first:** requirements §5, §9, §11; `ui/` (`Hud`); strings in `i18n/strings.csv`.

- The HUD only reads simulation and session state.
- The learn-mode HUD alone shows the live score and the blind-spot warnings — the exam shows neither (Q10, Q11).
- Hints show only while driving in learn mode: hidden in the exam, the countdown, a pause, a respawn and at the end.
- Warnings use icon + text, never colour alone.
- The blind-spot zone lives in `ViewConfig.blind_spot_*_m`.
- The end screen's again / history / menu buttons only emit signals; `main.gd` acts on them.
- The tutorial panel shows only while driving: hidden in the countdown, a pause and a respawn, whose headings sit in the centre it would cover.
- With touch buttons on, `main.gd` lays the HUD out through `Hud.set_layout` (safe area, `TouchConfig`, touch target); without them the desktop layout and texts stay unchanged.
- By touch the centred headings sit in the band between the rear-view mirror and the button rows, the blind-spot warnings above the side mirrors, the muted sign beside the pause button.
- No touch button may cover the mirrors, hints, score, tutorial panel or a centred heading at any size of `tests/fixtures/screen_matrix.gd` (each phone also 60 px shorter).
- The HUD and the touch buttons stay inside the display's safe area (`ScreenFit.safe_rect`); full-screen backdrops still cover the whole screen.
- On a touch device every button a finger presses is at least `TouchConfig.min_touch_target_px` CSS px each way (`ScreenFit.fit_buttons`).
