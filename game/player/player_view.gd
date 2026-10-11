class_name PlayerView
extends Node3D
## Cockpit rig (requirements §5.1): driver-seat camera with the dashboard and bonnet
## in the lower part of the view, and dashboard turn signal lamps. The rig stays at
## the floating origin longitudinally; laterally it follows the sim's lateral
## position, so lane changes animate with the sim's progress. Only reads sim state.

## Placeholder cockpit geometry, relative to the driver's eye (x, y) and the rig (z).
const DASHBOARD_SIZE: Vector3 = Vector3(1.6, 0.3, 0.6)
const DASHBOARD_TOP_BELOW_EYE_M: float = 0.4
const DASHBOARD_NEAR_Z: float = -0.55
const BONNET_SIZE: Vector3 = Vector3(1.7, 0.08, 1.6)
const BONNET_TOP_BELOW_EYE_M: float = 0.56
const LAMP_SIZE: Vector3 = Vector3(0.06, 0.02, 0.04)
const LAMP_SPACING_M: float = 0.16
const LAMP_Z: float = -0.7
const CAMERA_NEAR_M: float = 0.05

var view: ViewConfig
var camera: Camera3D
var dashboard: MeshInstance3D
var bonnet: MeshInstance3D
var signal_left: MeshInstance3D
var signal_right: MeshInstance3D


func setup(view_config: ViewConfig) -> void:
	view = view_config
	var eye_x: float = RoadLayout.x_of(view.eye_offset_left_m)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(eye_x, view.eye_height_m, 0.0)
	camera.rotation.x = -deg_to_rad(view.camera_pitch_down_deg)
	camera.fov = view.camera_fov_deg
	camera.near = CAMERA_NEAR_M
	camera.far = view.draw_distance_m()
	add_child(camera)

	var dashboard_top: float = view.eye_height_m - DASHBOARD_TOP_BELOW_EYE_M
	dashboard = _box("Dashboard", DASHBOARD_SIZE, Color(0.08, 0.08, 0.09),
			Vector3(0.0, dashboard_top - DASHBOARD_SIZE.y / 2.0, DASHBOARD_NEAR_Z - DASHBOARD_SIZE.z / 2.0))
	var bonnet_top: float = view.eye_height_m - BONNET_TOP_BELOW_EYE_M
	bonnet = _box("Bonnet", BONNET_SIZE, Color(0.55, 0.08, 0.08),
			Vector3(0.0, bonnet_top - BONNET_SIZE.y / 2.0, dashboard_near_far_z().y - BONNET_SIZE.z / 2.0))

	var lamp_y: float = dashboard_top + LAMP_SIZE.y / 2.0
	signal_left = _lamp("SignalLeft", Vector3(eye_x - LAMP_SPACING_M / 2.0, lamp_y, LAMP_Z))
	signal_right = _lamp("SignalRight", Vector3(eye_x + LAMP_SPACING_M / 2.0, lamp_y, LAMP_Z))


## Near and far z of the dashboard top.
func dashboard_near_far_z() -> Vector2:
	return Vector2(DASHBOARD_NEAR_Z, DASHBOARD_NEAR_Z - DASHBOARD_SIZE.z)


## Places the rig at lateral position `lateral_u` and lights the signal lamp of
## `vehicle` in its blink phase at sim time `time_s`.
func update(vehicle: VehicleState, lateral_u: float, time_s: float) -> void:
	position = Vector3(RoadLayout.x_of(lateral_u), 0.0, 0.0)
	var lit: bool = SignalBlink.is_lit(vehicle, time_s, view.signal_blink_hz)
	signal_left.visible = lit and vehicle.signal_dir == VehicleState.Dir.LEFT
	signal_right.visible = lit and vehicle.signal_dir == VehicleState.Dir.RIGHT


func _box(node_name: String, size: Vector3, color: Color, center: Vector3) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = center
	add_child(instance)
	return instance


func _lamp(node_name: String, center: Vector3) -> MeshInstance3D:
	var lamp: MeshInstance3D = _box(node_name, LAMP_SIZE, Color(0.2, 1.0, 0.3), center)
	var material: StandardMaterial3D = (lamp.mesh as BoxMesh).material as StandardMaterial3D
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp.visible = false
	return lamp
