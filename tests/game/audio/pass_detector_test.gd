extends GdUnitTestSuite
## One whoosh per vehicle passing the player close by on a neighbouring lane, louder
## for closer and faster passes (issue #72 acceptance criteria, spec
## `2026-10-13-sound-effects.md` Phase 3 step 7).

const DT: float = 1.0 / 60.0
const KMH: float = 1.0 / TrafficSim.KMH_PER_MPS

var _audio_config: AudioConfig
var _sim: TrafficSim
var _detector: PassDetector


func before_test() -> void:
	_audio_config = load("res://config/audio_config.tres") as AudioConfig
	_sim = TrafficSim.new(load("res://config/road_profiles/motorway.tres") as RoadProfile,
			load("res://config/sim_config.tres") as SimConfig)
	_sim.player = _sim.add_vehicle(0.0, 1, 100.0 * KMH)
	_detector = PassDetector.new(_audio_config)


## Steps the sim for `duration_s`, updating the detector every step; all passes found.
func _run(duration_s: float) -> PackedFloat32Array:
	var passes: PackedFloat32Array = PackedFloat32Array()
	_detector.update(_sim)
	for i: int in roundi(duration_s / DT):
		_sim.step(DT)
		passes.append_array(_detector.update(_sim))
	return passes


func test_being_overtaken_on_the_left_is_one_pass() -> void:
	_sim.add_vehicle(-15.0, 2, 140.0 * KMH)
	var passes: PackedFloat32Array = _run(3.0)
	assert_int(passes.size()).is_equal(1)
	assert_float(passes[0]).is_greater(0.0)


func test_overtaking_on_the_right_lane_is_one_pass() -> void:
	_sim.add_vehicle(15.0, 0, 70.0 * KMH)
	assert_int(_run(4.0).size()).is_equal(1)


func test_a_vehicle_two_lanes_away_makes_no_pass() -> void:
	_sim.player.lane = 0
	_sim.lanes = LaneIndex.from_vehicles(_sim.vehicles, _sim.road.lane_count)
	_sim.add_vehicle(-15.0, 2, 140.0 * KMH)
	assert_int(_run(3.0).size()).is_equal(0)


func test_a_slow_crossing_makes_no_pass() -> void:
	var relative_kmh: float = _audio_config.pass_min_relative_speed_kmh / 2.0
	_sim.add_vehicle(-1.0, 2, (100.0 + relative_kmh) * KMH)
	assert_int(_run(3.0).size()).is_equal(0)


func test_driving_alongside_makes_no_pass() -> void:
	_sim.add_vehicle(-3.0, 2, 100.0 * KMH)
	assert_int(_run(3.0).size()).is_equal(0)


func test_loudness_grows_with_closeness_and_relative_speed() -> void:
	var near: float = PassDetector.pass_loudness(_audio_config, 3.0, 40.0)
	var far: float = PassDetector.pass_loudness(_audio_config, 4.0, 40.0)
	var fast: float = PassDetector.pass_loudness(_audio_config, 3.0, 55.0)
	assert_float(near).is_greater(far)
	assert_float(fast).is_greater(near)
	assert_float(PassDetector.pass_loudness(_audio_config, 0.0, _audio_config.pass_full_speed_kmh)).is_equal(1.0)
	assert_float(PassDetector.pass_loudness(_audio_config, _audio_config.pass_sound_range_m + 0.1, 60.0)).is_equal(0.0)
	assert_float(PassDetector.pass_loudness(_audio_config, 3.0,
			_audio_config.pass_min_relative_speed_kmh - 1.0)).is_equal(0.0)


func test_a_reset_forgets_the_sides_so_a_teleport_is_no_pass() -> void:
	var other: VehicleState = _sim.add_vehicle(-5.0, 2, 100.0 * KMH)
	_detector.update(_sim)
	# The player is put somewhere else, as a respawn does.
	_sim.place_vehicle(_sim.player, other.s - 10.0, 1, 100.0 * KMH)
	_detector.reset()
	assert_int(_detector.update(_sim).size()).is_equal(0)
