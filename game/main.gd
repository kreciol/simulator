extends Node3D
## Drivable scene (spec Phase 3): the player's vehicle in the simulation, driven by
## the keyboard, seen from the cockpit on the endless road. This node only drives the
## sim and hands its state to the views; `SessionManager` takes over the session
## flow (countdown, timer, start speed) in Phase 3 step 3.

@export var road_profile: RoadProfile
@export var sim_config: SimConfig
@export var view_config: ViewConfig

var sim: TrafficSim
var player: VehicleState

var _input: PlayerInput = PlayerInput.new()

@onready var _road_view: RoadView = $RoadView
@onready var _player_view: PlayerView = $PlayerView
@onready var _world_environment: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	sim = TrafficSim.new(road_profile, sim_config)
	player = sim.add_vehicle(0.0, 0, 0.0)
	sim.player = player
	_road_view.setup(road_profile, view_config)
	_player_view.setup(view_config)
	# Fog fades the road out by the draw distance, hiding where it ends.
	_world_environment.environment.fog_depth_end = view_config.draw_distance_m()
	_update_views()


func _unhandled_input(event: InputEvent) -> void:
	if _input.handle_event(event):
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	sim.step(delta, _input.consume())


func _process(_delta: float) -> void:
	_update_views()


func _notification(what: int) -> void:
	# Key releases are not delivered while unfocused; never leave a key stuck down.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_input.reset()


func _update_views() -> void:
	_road_view.update(player.s)
	_player_view.update(player, sim.lateral_position(player), sim.time_s)
