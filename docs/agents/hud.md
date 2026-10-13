# HUD

**Read first:** requirements §5, §9, §11; `ui/` (`Hud`); strings in `i18n/strings.csv`.

- The HUD only reads simulation and session state.
- The learn-mode HUD alone shows the live score and the blind-spot warnings — the exam shows neither (Q10, Q11).
- Warnings use icon + text, never colour alone.
- The blind-spot zone lives in `ViewConfig.blind_spot_*_m`.
- The end screen's again / history / menu buttons only emit signals; `main.gd` acts on them.
