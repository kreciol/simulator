extends Node3D
## Drivable scene (spec Phase 3): the player's vehicle in the simulation, driven by
## the keyboard, seen from the cockpit on the endless road among AI traffic (Phase 4). `SessionManager` runs the
## session flow and the sim; this node feeds it input and hands its state to the views
## and the HUD, shows the mirrors (Phase 5), and saves the finished session through
## `SaveManager` (Phase 9). What the session starts with — including graphics quality
## and whether mirrors are shown — comes from the dev launcher (URL params on web, user
## args on desktop) until the Phase 10 menus exist.

@export var launcher_config: DevLauncherConfig
@export var sim_config: SimConfig
@export var view_config: ViewConfig

## Set before the scene enters the tree to skip the dev launcher (tests).
var launch_options: LaunchOptions
var quality: QualityPreset
var road_profile: RoadProfile
var sim: TrafficSim
var player: VehicleState

var _input: PlayerInput = PlayerInput.new()

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


func _process(_delta: float) -> void:
	_update_views()


func _notification(what: int) -> void:
	# Key releases are not delivered while unfocused; never leave a key stuck down.
	# `SessionManager` pauses itself on the same notification.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_input.reset()


## Saves the finished session to the local history and tells the player how it went.
## Play never depends on it: with saving disabled the session just is not kept.
func _on_session_ended() -> void:
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
