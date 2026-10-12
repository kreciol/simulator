class_name TrafficView
extends Node3D
## AI traffic on screen (spec Architecture: Spawner, Phase 4 step 4): one
## `VehicleView` per vehicle on the road except the player, who is seen from the
## cockpit. Views follow `TrafficSim.vehicle_added` / `vehicle_removed` and come from a
## pool per look, so spawning and despawning never create or free nodes once the pool
## has grown to the traffic's size. Floating origin: a vehicle sits at
## z = -(s - player.s). Only reads sim state.

var sim: TrafficSim
var view: ViewConfig
## Views ever built; stops growing once the pool covers the traffic.
var built_count: int = 0

## Live views by vehicle id.
var _views: Dictionary[int, VehicleView] = {}
## Idle views per look.
var _pool: Dictionary[VehicleLook.Look, Array] = {}


## Shows the vehicles already on `traffic_sim`'s road and follows it from now on.
func setup(traffic_sim: TrafficSim, view_config: ViewConfig) -> void:
	sim = traffic_sim
	view = view_config
	sim.vehicle_added.connect(_on_vehicle_added)
	sim.vehicle_removed.connect(_on_vehicle_removed)
	for vehicle: VehicleState in sim.vehicles:
		_show(vehicle)


func update() -> void:
	var player_s: float = sim.player.s
	for vehicle_view: VehicleView in _views.values():
		vehicle_view.update(player_s, sim.lateral_position(vehicle_view.vehicle), sim.time_s)


## Number of vehicles shown.
func live_count() -> int:
	return _views.size()


## The view showing the vehicle with `vehicle_id`, or null.
func view_of(vehicle_id: int) -> VehicleView:
	return _views.get(vehicle_id)


func _show(vehicle: VehicleState) -> void:
	if vehicle == sim.player:
		return
	var look: VehicleLook.Look = VehicleLook.look_of(vehicle, view)
	var idle: Array = _pool.get(look, [])
	var vehicle_view: VehicleView
	if idle.is_empty():
		vehicle_view = VehicleView.new()
		vehicle_view.name = "Vehicle%d" % built_count
		vehicle_view.build(look, vehicle.length_m, vehicle.width_m, view)
		add_child(vehicle_view)
		built_count += 1
	else:
		vehicle_view = idle.pop_back()
	vehicle_view.bind(vehicle)
	_views[vehicle.id] = vehicle_view


func _on_vehicle_added(vehicle_id: int) -> void:
	_show(sim.find_vehicle(vehicle_id))


func _on_vehicle_removed(vehicle_id: int) -> void:
	var vehicle_view: VehicleView = _views.get(vehicle_id)
	if vehicle_view == null:
		return
	_views.erase(vehicle_id)
	vehicle_view.unbind()
	if not _pool.has(vehicle_view.look):
		_pool[vehicle_view.look] = []
	_pool[vehicle_view.look].append(vehicle_view)
