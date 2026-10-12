class_name ExamCalibration
extends RefCounted
## Measures the exam pass marks (spec Q9, Phase 6 step 4): `IdealDriverBot` drives one
## seeded exam session per road profile on a level, with the level's traffic and full
## scoring, and the pass mark is `PASS_SHARE` of the lower of its scores, so it is
## reachable on either profile. The result is written by hand into
## `DifficultyLevel.exam_pass_score`; a test fails when the stored value drifts from
## a fresh measurement (after retuning weights, traffic or AI).

const PASS_SHARE: float = 0.6
const SEED: int = 1
const DT: float = 1.0 / 60.0


## The record of one bot exam session. Stops early on a collision or off-road, which
## end an exam.
static func run_session(
		road: RoadProfile,
		level: DifficultyLevel,
		sim_config: SimConfig,
		scoring_config: ScoringConfig,
		seed_value: int = SEED) -> SessionRecord:
	var sim: TrafficSim = TrafficSim.new(road, sim_config, seed_value)
	sim.player = sim.add_vehicle(0.0, 0, sim_config.start_speed_kmh / TrafficSim.KMH_PER_MPS)
	var scoring: ScoringSystem = ScoringSystem.new(sim, scoring_config)
	Spawner.new(level).attach(sim)
	var bot: IdealDriverBot = IdealDriverBot.new(sim, scoring_config)
	var builder: SessionRecordBuilder = SessionRecordBuilder.new(scoring_config)
	builder.mode = SessionRecord.MODE_EXAM
	builder.road_profile = road.id
	builder.difficulty = level.id
	builder.seed_value = seed_value
	builder.exam_pass_score = level.exam_pass_score
	for i: int in roundi(sim_config.session_length_s / DT):
		sim.step(DT, bot.commands())
		for event: ScoreEvent in scoring.observe(DT):
			if event.type == CollisionRule.TYPE_COLLISION:
				builder.status = SessionRecord.STATUS_ABORTED_COLLISION
			elif event.type == CollisionRule.TYPE_OFFROAD:
				builder.status = SessionRecord.STATUS_ABORTED_OFFROAD
		if builder.status != SessionRecord.STATUS_COMPLETED:
			break
	scoring.finish()
	builder.duration_s = sim.time_s
	return builder.build(scoring.event_log)


## The pass mark for `level`: `PASS_SHARE` of the bot's lowest score over `roads`, in
## whole points.
static func pass_score(
		level: DifficultyLevel,
		roads: Array[RoadProfile],
		sim_config: SimConfig,
		scoring_config: ScoringConfig) -> float:
	var lowest: float = INF
	for road: RoadProfile in roads:
		lowest = minf(lowest, run_session(road, level, sim_config, scoring_config).score_total)
	return roundf(lowest * PASS_SHARE)
