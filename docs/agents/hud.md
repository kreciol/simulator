# HUD

**Read first:** requirements §5, §9, §11; `ui/` (`Hud`); strings in `i18n/strings.csv`.

- The HUD only reads simulation and session state.
- The learn-mode HUD alone shows the live score and the blind-spot warnings — the exam shows neither (Q10, Q11).
- Hints show only while driving in learn mode: hidden in the exam, the countdown, a pause, a respawn and at the end.
- Warnings use icon + text, never colour alone.
- The blind-spot zone lives in `ViewConfig.blind_spot_*_m`.
