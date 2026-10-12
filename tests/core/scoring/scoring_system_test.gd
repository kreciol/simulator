extends GdUnitTestSuite
## Scoring observes the simulation and never changes it (spec Architecture: Scoring;
## issue #28).

const DT: float = 1.0 / 60.0


func _run(with_scoring: bool) -> Dictionary:
	var sim: TrafficSim = TrafficSim.new(
			load("res://config/road_profiles/motorway.tres") as RoadProfile,
			load("res://config/sim_config.tres") as SimConfig,
			7)
	sim.player = sim.add_vehicle(0.0, 0, 33.0)
	sim.add_ai_vehicle(60.0, 0, 25.0, 25.0, 1.0, VehicleState.Kind.TRUCK)
	sim.add_ai_vehicle(-80.0, 0, 36.0, 38.0, 0.6)
	sim.add_ai_vehicle(-150.0, 1, 40.0, 41.0, 0.9)
	var scoring: ScoringSystem = null
	if with_scoring:
		scoring = ScoringSystem.new(sim, load("res://config/scoring.tres") as ScoringConfig)
	var script_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	script_rng.seed = 11
	for i: int in 1200:
		var commands: PlayerCommands = PlayerCommands.new()
		commands.longitudinal = script_rng.randi_range(0, 2) as VehicleState.Longitudinal
		if script_rng.randf() < 0.01:
			commands.signal_toggle = VehicleState.Dir.LEFT if script_rng.randf() < 0.5 else VehicleState.Dir.RIGHT
		if script_rng.randf() < 0.01:
			commands.lane_change = VehicleState.Dir.LEFT if sim.player.lane == 0 else VehicleState.Dir.RIGHT
		sim.step(DT, commands)
		if scoring != null:
			scoring.observe(DT)
	if scoring != null:
		scoring.finish()
		assert_array(scoring.event_log.events).is_not_empty()
	return sim.snapshot()


func test_a_scored_sim_ends_in_the_same_state_as_an_unscored_one() -> void:
	assert_dict(_run(true)).is_equal(_run(false))


func test_observe_and_finish_emit_each_completed_event_once() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(1, 120.0)
	var emitted: Array[ScoreEvent] = []
	world.scoring.score_event_emitted.connect(func(event: ScoreEvent) -> void: emitted.append(event))
	var commands: PlayerCommands = PlayerCommands.new()
	commands.lane_change = VehicleState.Dir.RIGHT
	world.drive(1.0)
	world.drive(3.0, commands)
	world.scoring.finish()
	# The K3 event for the unsignalled return and the K2 segment closed by it.
	assert_int(emitted.size()).is_equal(2)
	assert_array(emitted).contains_exactly_in_any_order(world.scoring.event_log.events)


func test_finish_closes_open_segments() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(1, 120.0)
	world.drive(1.0)
	assert_bool(world.scoring.event_log.is_open(KeepRightRule.KEY)).is_true()
	var completed: Array[ScoreEvent] = world.scoring.finish()
	assert_int(completed.size()).is_equal(1)
	assert_bool(world.scoring.event_log.is_open(KeepRightRule.KEY)).is_false()


func test_nothing_is_scored_off_the_road() -> void:
	var world: ScoringTestHelper = ScoringTestHelper.new(1, 120.0)
	var commands: PlayerCommands = PlayerCommands.new()
	commands.signal_toggle = VehicleState.Dir.LEFT
	world.drive(1.5, commands)
	commands = PlayerCommands.new()
	commands.lane_change = VehicleState.Dir.LEFT
	world.drive(3.0, commands)
	assert_bool(world.player.off_road).is_true()
	var points_off_road: float = world.scoring.event_log.total()
	world.drive(10.0)
	assert_float(world.scoring.event_log.total()).is_equal(points_off_road)
	assert_bool(world.scoring.event_log.is_open(KeepRightRule.KEY)).is_false()
