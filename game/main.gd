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

@export var launcher_config: DevLauncherConfig
@export var sim_config: SimConfig
@export var view_config: ViewConfig
@export var perf_config: PerfConfig

## Set before the scene enters the tree to skip the dev launcher (tests).
var launch_options: LaunchOptions
var quality: QualityPreset
var road_profile: RoadProfile
var sim: TrafficSim
var player: VehicleState
## The FPS probe's printed line, empty until it has reported (or without `perf=1`).
var perf_report: String = ""

var _input: PlayerInput = PlayerInput.new()
## Null unless the launch asked for the probe.
var _fps_probe: FpsProbe
var _low_fps_watch: LowFpsWatch

@onready var session: SessionManager = $SessionManager
@onready var _road_view: RoadView = $RoadView
@onready var _traffic_view: TrafficView = $TrafficView
@onready var _player_view: PlayerView = $PlayerView
@onready var _mirrors_view: MirrorsView = $MirrorsView
@onready var _sun: DirectionalLight3D = $Sun
@onready var _hud: Hud = $Hud
@onready var _world_environment: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	if launch_options == null:
		launch_options = DevLauncher.from_environment(launcher_config)
	# Printed so a tester can replay the session with the same seed.
	print("Dev launcher: ", launch_options.describe())
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
	_traffic_view.setup(sim, view_config)
	_player_view.setup(view_config)
	_mirrors_view.setup(view_config, quality, launch_options.mirrors, _world_environment.environment)
	_hud.setup(view_config)
	# Fog fades the road out by the draw distance, hiding where it ends.
	_world_environment.environment.fog_depth_end = view_config.draw_distance_m()
	_update_views()


func _unhandled_input(event: InputEvent) -> void:
	# Esc or P (the `pause` action) stops and resumes the session (requirements §9.3).
	if event.is_action_pressed(&"pause"):
		session.toggle_pause()
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


## Saves the finished session to the local history and tells the player how it went.
## Play never depends on it: with saving disabled the session just is not kept.
func _on_session_ended() -> void:
	# A session that ends before the probe's window fills still reports what it measured.
	if _fps_probe != null and perf_report.is_empty():
		_report_probe()
	if session.record == null:
		return
	var saved: bool = SaveManager.save_record(session.record)
	_hud.show_save_status(saved, SaveManager.store)


func _update_views() -> void:
	_road_view.update(player.s)
	_traffic_view.update()
	_player_view.update(player, sim.lateral_position(player), sim.time_s)
	_mirrors_view.update(_player_view.position)
	_hud.update(session)
