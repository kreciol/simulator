class_name DriveScene
extends Node3D
## Drivable scene (spec Phase 3): the player's vehicle in the simulation, driven by
## the keyboard, seen from the cockpit on the endless road among AI traffic (Phase 4). `SessionManager` runs the
## session flow and the sim; this node feeds it input and hands its state to the views
## and the HUD, shows the mirrors (Phase 5), and saves the finished session through
## `SaveManager` (Phase 9). What the session starts with — including graphics quality
## and whether mirrors are shown — comes from the start screen's setup (`AppFlow` sets
## `launch_options`) or, when the scene runs on its own, from the dev launcher (URL
## params on web, user args on desktop). The end screen leads on (issue #43): the same
## session again with a new seed, the history or the start screen.
## With `perf=1` an FPS probe samples the drive and prints its result (Phase 5 step 2);
## sustained low FPS suggests the low preset once per session (spec Edge Cases).
## `screen=history` opens the history screen instead of a session (Phase 9 step 2).
## Sound effects follow the drive (issue #72); `M` mutes them.
## The tutorial (issue #45) runs in this scene too: Tab (`tutorial_skip`) or the HUD's
## skip button ends it and goes back to the start screen at once.
## On a touch device (or with `touch=1`) on-screen buttons drive the car through the
## same Input Map actions as the keys (issue #86); with the launch's `touch` left to the
## device they also appear on the first touch and hide on a key press.
## On a phone (issue #87) the HUD and the buttons stay inside the display's safe area and
## the HUD keeps clear of the buttons; held upright, a touch device shows the rotate
## notice and the session pauses until the player resumes it in landscape.

const HISTORY_SCENE: String = AppFlow.HISTORY_SCENE

@export var launcher_config: DevLauncherConfig
@export var sim_config: SimConfig
@export var view_config: ViewConfig
@export var perf_config: PerfConfig
@export var audio_config: AudioConfig
@export var touch_config: TouchConfig

## Set before the scene enters the tree to skip the dev launcher (tests).
var launch_options: LaunchOptions
var quality: QualityPreset
var road_profile: RoadProfile
var sim: TrafficSim
var player: VehicleState
## The FPS probe's printed line, empty until it has reported (or without `perf=1`).
var perf_report: String = ""
## Switches to another scene by path; tests replace it to watch instead.
var change_scene: Callable = func(path: String) -> void: AppFlow.open_scene(get_tree(), path)
## Starts another session in place of this one; tests replace it to watch instead.
var start_session: Callable = func(options: LaunchOptions) -> void: AppFlow.start_session(get_tree(), options)
## Whether the device has a touchscreen; tests replace it.
var touchscreen_available: Callable = func() -> bool: return DisplayServer.is_touchscreen_available()
## The on-screen touch buttons; null until they are built (never on a desktop without
## touch and no `touch` param).
var touch_controls: TouchControls
## Asks to turn a touch device held upright; the drive pauses while it shows.
var rotate_notice: RotateNotice
## CSS pixels per canvas unit and the display's safe area in canvas units; tests
## replace both.
var css_scale: Callable = func() -> float: return ScreenFit.css_scale_now(get_viewport())
var safe_area: Callable = func() -> Rect2: return ScreenFit.safe_rect_now(get_viewport())

var _player_input: PlayerInput = PlayerInput.new()
## Null unless the launch asked for the probe.
var _fps_probe: FpsProbe
var _low_fps_watch: LowFpsWatch
## Whether the touch buttons should show; the end screen hides them regardless.
var _touch_wanted: bool = false

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
		set_process_input(false)
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
	_hud.again_requested.connect(func() -> void: start_session.call(launch_options.again(randi())))
	_hud.history_requested.connect(func() -> void: change_scene.call(AppFlow.HISTORY_SCENE))
	_hud.menu_requested.connect(func() -> void: change_scene.call(AppFlow.START_SCENE))
	_hud.tutorial_skip_requested.connect(skip_tutorial)
	_audio_view.setup(session, view_config, audio_config, _engine_top_speed_kmh())
	rotate_notice = RotateNotice.new()
	add_child(rotate_notice)
	rotate_notice.shown_changed.connect(_on_rotate_notice_shown)
	rotate_notice.setup(touchscreen_available.call() or launch_options.touch == LaunchOptions.TOUCH_ON)
	get_viewport().size_changed.connect(layout_screen)
	if TouchControls.builds_at_start(launch_options.touch, touchscreen_available.call()):
		show_touch_controls()
	else:
		layout_screen()
	# Fog fades the road out by the draw distance, hiding where it ends.
	_world_environment.environment.fog_depth_end = view_config.draw_distance_m()
	_update_views()


## Seen before the GUI, which takes a touch on a touch button for itself.
func _input(event: InputEvent) -> void:
	if _is_gesture(event):
		_audio_view.unlock()
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null and touch.pressed and TouchControls.builds_on_touch(launch_options.touch):
		show_touch_controls()
	elif event is InputEventKey and event.is_pressed() and touch_controls != null \
			and TouchControls.hides_on_key(launch_options.touch):
		_touch_wanted = false
		touch_controls.set_shown(false)
		layout_screen()


func _unhandled_input(event: InputEvent) -> void:
	# Esc or P (the `pause` action) stops and resumes the session (requirements §9.3).
	if event.is_action_pressed(&"pause"):
		session.toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"mute"):
		_audio_view.toggle_mute()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"tutorial_skip") and session.is_tutorial():
		skip_tutorial()
		get_viewport().set_input_as_handled()
	elif _player_input.handle_event(event):
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	# Consumed every step, so presses during the countdown are dropped, not queued.
	session.step(delta, _player_input.consume())


func _process(delta: float) -> void:
	# Upright, the drive stays paused: a key cannot resume it behind the notice either.
	if rotate_notice.visible:
		session.pause()
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
		_player_input.reset()
		if touch_controls != null:
			touch_controls.release_all()


## Builds the touch buttons the first time and shows them.
func show_touch_controls() -> void:
	_touch_wanted = true
	TouchControls.run_shown = true
	if touch_controls == null:
		touch_controls = TouchControls.new()
		touch_controls.name = "TouchControls"
		add_child(touch_controls)
		touch_controls.setup(touch_config)
	if not rotate_notice.applies:
		rotate_notice.applies = true
		rotate_notice.refresh()
	_update_touch_controls()
	layout_screen()


## Lays the buttons and the HUD out inside the display's safe area; with the buttons
## wanted the HUD keeps clear of them and sizes its buttons for a finger.
func layout_screen() -> void:
	var area: Rect2 = safe_area.call()
	if touch_controls != null:
		touch_controls.safe_area = area
		touch_controls.layout()
	if _touch_wanted:
		_hud.set_layout(area, touch_config, ScreenFit.min_target(touch_config, css_scale.call()))
	else:
		_hud.set_layout(area, null, 0.0)


## Upright, the drive pauses and every held button lets go; back in landscape the
## player resumes it from the pause screen.
func _on_rotate_notice_shown(shown: bool) -> void:
	if not shown:
		return
	session.pause()
	_player_input.reset()
	if touch_controls != null:
		touch_controls.release_all()


## Hidden on the end screen, so they never cover its again / history / menu buttons.
func _update_touch_controls() -> void:
	if touch_controls != null:
		touch_controls.set_shown(_touch_wanted and session.state != SessionManager.State.ENDED)


## Ends the tutorial at once (requirements §12: skippable); `_on_session_ended` then
## goes back to the start screen, where it can be run again.
func skip_tutorial() -> void:
	session.skip_tutorial()


## Compares the finished session with the earlier results of its combination, saves it
## to the local history and tells the player how both went. Play never depends on it:
## with saving disabled the session just is not kept.
func _on_session_ended() -> void:
	# A session that ends before the probe's window fills still reports what it measured.
	if _fps_probe != null and perf_report.is_empty():
		_report_probe()
	if session.is_tutorial():
		_on_tutorial_ended()
		return
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


## A finished or skipped tutorial is no longer suggested on the start screen. A finished
## one stays on its recap; a skipped one leaves for the menu at once.
func _on_tutorial_ended() -> void:
	SaveManager.settings.mark_tutorial_seen()
	if session.tutorial.skipped:
		change_scene.call(AppFlow.START_SCENE)


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
	_update_touch_controls()
	_audio_view.update()
