class_name ScoringTestHelper
extends RefCounted
## A motorway sim with a scripted player and a `ScoringSystem` observing it, for the
## scoring rule tests. Scripted vehicles keep their speed unless commanded.

const DT: float = 1.0 / 60.0

var sim: TrafficSim
var scoring: ScoringSystem
var player: VehicleState


## `scoring_config` overrides `scoring.tres` (e.g. a duplicate with one value changed).
func _init(player_lane: int, player_speed_kmh: float, scoring_config: ScoringConfig = null) -> void:
	sim = TrafficSim.new(
			load("res://config/road_profiles/motorway.tres") as RoadProfile,
			load("res://config/sim_config.tres") as SimConfig)
	player = sim.add_vehicle(0.0, player_lane, kmh(player_speed_kmh))
	sim.player = player
	if scoring_config == null:
		scoring_config = load("res://config/scoring.tres") as ScoringConfig
	scoring = ScoringSystem.new(sim, scoring_config)


static func kmh(speed_kmh: float) -> float:
	return speed_kmh / TrafficSim.KMH_PER_MPS


## Adds a scripted car on `lane` whose rear is `gap_m` ahead of the player's front.
func add_car_ahead(lane: int, gap_m: float, speed_kmh: float) -> VehicleState:
	var length_m: float = sim.config.vehicle_length_m
	return sim.add_vehicle(player.front_s() + gap_m + length_m / 2.0, lane, kmh(speed_kmh))


## Steps the sim and scoring for `seconds`, returning every event completed meanwhile.
func drive(seconds: float, commands: PlayerCommands = null) -> Array[ScoreEvent]:
	var completed: Array[ScoreEvent] = []
	for i: int in roundi(seconds / DT):
		sim.step(DT, commands if i == 0 else null)
		completed.append_array(scoring.observe(DT))
	return completed


func total_for(category: StringName) -> float:
	return scoring.event_log.total_for(category)


func total_of_type(type: StringName) -> float:
	var sum: float = 0.0
	for event: ScoreEvent in scoring.event_log.events_of_type(type):
		sum += event.points
	return sum


## A copy of `scoring.tres` to change values in, without touching the cached resource.
static func scoring_config_copy() -> ScoringConfig:
	return (load("res://config/scoring.tres") as ScoringConfig).duplicate() as ScoringConfig
