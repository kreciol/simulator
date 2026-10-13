# Sound effects

**Read first:** issue #72, `.ai/specs/2026-10-13-sound-effects.md`; `game/audio/`, `AudioConfig` + `config/audio_config.tres`, `default_bus_layout.tres`.

- Audio only reads the session and the sim, like the other views — nothing in `core/` knows about it.
- Sounds are synthesised by `AudioSynth` from a fixed local seed, never `TrafficSim.rng`.
- A stream is built once and never modified (web sample playback keeps its first upload).
- No bus effects (web sample playback ignores them); only bus volume and mute.
- The engine, the indicator and passes are silent in `INTRO`, while paused and in `ENDED`.
- The indicator clicks on `SignalBlink` edges, never on its own timer.
- Pass detection reads `TrafficSim.lanes`; it is reset on `SessionManager.player_respawned`.
- Nothing sounds before the first key, click or touch; `mute` is handled by `main.gd`, not as a driving command.
- Tests assert trigger counters and player settings, never `playing` timing of one-shots.
- Write `stream_paused` only when the pause changes: every write pauses or resumes the browser's sample playback and makes it stutter.
- The engine is an electric motor's whine plus a road-noise loop (`AudioSynth.road`), both following the speed.
