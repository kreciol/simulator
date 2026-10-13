# Mirrors

**Read first:** requirements §5, §14; `game/mirrors/`, `config/view_config.tres`, `QualityPreset` + `config/quality_presets/`.

- Mirrors are `SubViewport`s sharing the main `World3D` (no own world).
- They render at the preset's resolution scale and frame interval.
- They are flipped left-right on screen.
- Their range (`ViewConfig.mirror_range_m()`) stays within the road kept behind and the spawner's hidden zone.
- With mirrors off none is built.
