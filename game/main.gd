extends Node3D
## Drivable scene (spec Phase 3): the player's vehicle in the simulation, driven by
## the keyboard, seen from the cockpit on the endless road among AI traffic (Phase 4). `SessionManager` runs the
## session flow and the sim; this node feeds it input and hands its state to the views
## and the HUD, shows the mirrors (Phase 5), and saves the finished session through
## `SaveManager` (Phase 9). What the session starts with — including graphics quality
## and whether mirrors are shown — comes from the dev launcher (URL params on web, user
## args on desktop) until the Phase 10 menus exist.
## With `perf=1` an FPS probe samples the drive and prints its result (Phase 5 step 2);
## sustained low FPS suggests the low preset once per session (spec Edge Cases).
## `screen=history` opens the history screen instead of a session (Phase 9 step 2).
## Sound effects follow the drive (issue #72); `M` mutes them.

const HISTORY_SCENE: String = "res://ui/history_screen.tscn"

@export var launcher_config: DevLauncherConfig
@export var sim_config: SimConfig
@export var view_config: ViewConfig
@export var perf_config: PerfConfig
@export var audio_config: AudioConfig

## Set before the scene enters the tree to skip the dev launcher (tests).
var launch_options: LaunchOptions
var quality: QualityPreset
var road_profile: RoadProfile
var sim: TrafficSim
var player: VehicleState
## The FPS probe's printed line, empty until it has reported (or without `perf=1`).
var perf_report: String = ""
## Switches to another scene by path; tests replace it to watch instead.
var change_scene: Callable = func(path: String) -> void: get_tree().change_scene_to_file(path)

var _input: PlayerInput = PlayerInput.new()
## Null unless the launch asked for the probe.
var _fps_probe: FpsProbe
var _low_fps_watch: LowFpsWatch

@onready var session: SessionManager = $SessionManager
@onready var _road_view: RoadView = $RoadView
@onready var _hectometre_posts: HectometrePostsView = $HectometrePosts
@onready var _traffic_view: TrafficView = $TrafficView
@onready var _player_view: PlayerView = $PlayerView
@onready var _mirrors_view: MirrorsView = $MirrorsView
@onready var _sun: DirectionalLight3D = $Sun
@onready var _hud: Hud = $Hud
@onready var _audio_view: AudioView = $AudioView
@onready var _world_environment: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	if launch_options == null:
		launch_options = DevLauncher.from_environment(launcher_config)
	# Printed so a tester can replay the session with the same seed.
	print("Dev launcher: ", launch_options.describe())
	if launch_options.screen == LaunchOptions.SCREEN_HISTORY:
		# No session starts: nothing to step, draw or steer until the scene is swapped.
		set_process(false)
		set_physics_process(false)
		set_process_unhandled_input(false)
		change_scene.call_deferred(HISTORY_SCENE)
		return
	road_profile = launch_options.profile
	quality = launch_options.quality
	# The preset sets the draw distance; the shared config resource stays untouched.
	view_config = view_config.for_quality(quality)
	_sun.shadow_enabled = quality.shadows_enabled
	session.start(launch_options, sim_config)
	session.session_ended.connect(_on_session_ended)
	if launch_options.perf:
		_fps_probe = FpsProbe.new(perf_config)
	_low_fps_watch = LowFpsWatch.new(perf_config, quality.id != perf_config.suggested_quality)
	sim = session.sim
	player = session.player
	_road_view.setup(road_profile, view_config)
	_hectometre_posts.setup(road_profile, view_config)
	_traffic_view.setup(sim, view_config)
	_player_view.setup(view_config)
	_mirrors_view.setup(view_config, quality, launch_options.mirrors, _world_environment.environment)
	_hud.setup(view_config)
	_audio_view.setup(session, view_config, audio_config, _engine_top_speed_kmh())
	# Fog fades the road out by the draw distance, hiding where it ends.
	_world_environment.environment.fog_depth_end = view_config.draw_distance_m()
	_update_views()


func _unhandled_input(event: InputEvent) -> void:
	if _is_gesture(event):
		_audio_view.unlock()
	# Esc or P (the `pause` action) stops and resumes the session (requirements §9.3).
	if event.is_action_pressed(&"pause"):
		session.toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"mute"):
		_audio_view.toggle_mute()
		get_viewport().set_input_as_handled()
	elif _input.handle_event(event):
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	# Consumed every step, so presses during the countdown are dropped, not queued.
	session.step(delta, _input.consume())


func _process(delta: float) -> void:
	track_performance(Performance.get_monitor(Performance.TIME_FPS), delta)
	_update_views()


## Feeds one rendered frame's FPS to the probe and the low-FPS watch; only driving is
## measured, so the countdown's warm-up, a pause, a respawn fade and the frozen end
## screen do not count, and neither does a stall (a frame over `PerfConfig.max_frame_s`, e.g. a
## hidden tab).
func track_performance(fps: float, delta: float) -> void:
	if session.state != SessionManager.State.DRIVING or session.paused or delta > perf_config.max_frame_s:
		return
	if _low_fps_watch.add_sample(fps, delta):
		_hud.show_toast(tr(&"TOAST_LOW_FPS"), perf_config.toast_duration_s)
	if _fps_probe != null and perf_report.is_empty():
		_fps_probe.add_sample(fps, delta)
		if _fps_probe.is_complete():
			_report_probe()


## Printed with the launch options, so a result names the level, seed and preset it
## was measured on.
func _report_probe() -> void:
	perf_report = "%s | %s" % [_fps_probe.report(), launch_options.describe()]
	print(perf_report)


func _notification(what: int) -> void:
	# Key releases are not delivered while unfocused; never leave a key stuck down.
	# `SessionManager` pauses itself on the same notification.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_input.reset()


## Compares the finished session with the earlier results of its combination, saves it
## to the local history and tells the player how both went. Play never depends on it:
## with saving disabled the session just is not kept.
func _on_session_ended() -> void:
	# A session that ends before the probe's window fills still reports what it measured.
	if _fps_probe != null and perf_report.is_empty():
		_report_probe()
	if session.record == null:
		return
	var record: SessionRecord = session.record
	var history: HistoryStore = SaveManager.store
	# Read before saving, so the comparison is with the results before this one. With
	# saving disabled there is no history to compare with, and this result will not
	# join it either: the save status explains why instead.
	var comparison: Array[FeedbackLine] = []
	if history.can_save():
		comparison = ResultComparison.compare(record,
				history.previous_for(record.mode, record.road_profile, record.difficulty),
				history.best_for(record.mode, record.road_profile, record.difficulty))
	_hud.show_comparison(comparison)
	var saved: bool = SaveManager.save_record(record)
	_hud.show_save_status(saved, SaveManager.store)


## A key, click or touch: what browsers count as the user's go-ahead for sound.
static func _is_gesture(event: InputEvent) -> bool:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch:
		return event.is_pressed()
	return false


## Speed of the engine's top note: the profile's limit plus the S1 tolerance (issue #72).
func _engine_top_speed_kmh() -> float:
	var tolerance_kmh: float = 0.0
	if session.scoring_config != null:
		tolerance_kmh = session.scoring_config.speed_tolerance_kmh
	return road_profile.speed_limit_kmh + tolerance_kmh


func _update_views() -> void:
	_road_view.update(player.s)
	_hectometre_posts.update(player.s)
	_traffic_view.update()
	_player_view.update(player, sim.lateral_position(player), sim.time_s)
	# The end screen dims the frozen scene; the mirrors go with it.
	_mirrors_view.set_shown(session.state != SessionManager.State.ENDED)
	_mirrors_view.update(_player_view.position)
	_hud.update(session)
	_hud.set_muted(_audio_view.user_muted)
	_audio_view.update()
