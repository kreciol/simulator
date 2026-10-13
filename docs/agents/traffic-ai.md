# Traffic AI and spawning

**Read first:** requirements §7, §10; `core/ai/`, `core/sim/spawner.gd`; tunables in `SimConfig`, levels in `config/difficulty_levels/`.

- IDM-style car-following.
- Simplified MOBIL lane changes, weighed every `ai_lane_decision_interval_s`.
- AI and the spawner use the **same** `is_lane_free` / `min_gap` functions as scoring.
- Never spawn into or near a collision: skip a spawn rather than force it.
- During a session spawn only beyond view.
- Vehicles are pooled by `TrafficSim` (`remove_vehicle` / add), no create/free churn.
- AI–AI collisions are despawned silently by the `Spawner`, never charged.
