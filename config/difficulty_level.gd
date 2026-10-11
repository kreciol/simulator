class_name DifficultyLevel
extends Resource
## One difficulty level (requirements §10, spec Data Model). Difficulty is traffic
## density; higher levels also widen the AI speed spread and lower AI discipline,
## moderately (Q13). All levels are available from the start (Q14). Instances live in
## res://config/difficulty_levels/; nothing is defaulted here. `exam_pass_score`
## joins with scoring (Phase 6, Q9).

## 1–4, from calm to rush hour.
@export var id: int
## Translation key of the player-facing name.
@export var display_name_key: String
## Vehicles per kilometre per lane the spawner keeps around the player (§7.3).
@export var density_per_km_per_lane: float
## Share of spawned vehicles that are trucks.
@export_range(0.0, 1.0) var truck_share: float
## AI car desired speeds are drawn up to this far either side of the road's cruising
## speed (`SimConfig.ai_car_speed_offset_kmh` from the limit).
@export var ai_speed_spread_kmh: float
## Range AI discipline is drawn from (1 = model driver, §7.2).
@export_range(0.0, 1.0) var ai_discipline_min: float
@export_range(0.0, 1.0) var ai_discipline_max: float
## Highlighted as the suggested level in level selection (Q14).
@export var recommended: bool
