extends Node3D
## Drivable scene (spec Phase 3): the player's vehicle in the simulation, driven by
## the keyboard, seen from the cockpit on the endless road. `SessionManager` runs the
## session flow and the sim; this node feeds it input and hands its state to the views
## and the HUD. What the session starts with comes from the dev launcher (URL params
## on web, user args on desktop) until the Phase 10 menus exist.

@export var launcher_config: DevLauncherConfig
@export var sim_config: SimConfig
@export var view_config: ViewConfig

var launch_options: LaunchOptions
var road_profile: RoadProfile
var sim: TrafficSim
var player: VehicleState

var _input: PlayerInput = PlayerInput.new()

@onready var session: SessionManager = $SessionManager
@onready var _road_view: RoadView = $RoadView
@onready var _player_view: PlayerView = $PlayerView
@onready var _hud: Hud = $Hud
@onready var _world_environment: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	launch_options = DevLauncher.from_environment(launcher_config)
	# Printed so a tester can replay the session with the same seed.
	print("Dev launcher: ", launch_options.describe())
	road_profile = launch_options.profile
	session.start(launch_options, sim_config)
	sim = session.sim
	player = session.player
	_road_view.setup(road_profile, view_config)
	_player_view.setup(view_config)
	_hud.setup(view_config)
	# Fog fades the road out by the draw distance, hiding where it ends.
	_world_environment.environment.fog_depth_end = view_config.draw_distance_m()
	_update_views()


func _unhandled_input(event: InputEvent) -> void:
	if _input.handle_event(event):
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	# Consumed every step, so presses during the countdown are dropped, not queued.
	session.step(delta, _input.consume())


func _process(_delta: float) -> void:
	_update_views()


func _notification(what: int) -> void:
	# Key releases are not delivered while unfocused; never leave a key stuck down.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_input.reset()


func _update_views() -> void:
	_road_view.update(player.s)
	_player_view.update(player, sim.lateral_position(player), sim.time_s)
	_hud.update(session)
