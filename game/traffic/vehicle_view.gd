class_name VehicleView
extends Node3D
## One AI vehicle on screen (requirements §7.1): a low-poly body for its look (car,
## van/SUV or truck) in its paint, brake lights and four indicators that blink with
## its signal, so the player can read its intentions. Origin at the body centre on
## the road, front towards -z, left towards -x (`RoadLayout.x_of`). Built once per
## look and reused from `TrafficView`'s pool for any vehicle of that look. Only
## reads sim state.

const LAMP_DEPTH_M: float = 0.05
const BRAKE_LAMP_SIZE: Vector2 = Vector2(0.3, 0.15)
const INDICATOR_SIZE: Vector2 = Vector2(0.14, 0.12)
## Brake lamps sit this far in from the body's sides; indicators at its corners.
const BRAKE_LAMP_INSET_M: float = 0.25
const INDICATOR_INSET_M: float = 0.08
## Length of a truck's cab; the rest of the body is the trailer.
const TRUCK_CAB_LENGTH_M: float = 2.3
const TRUCK_CAB_GAP_M: float = 0.3

const CHASSIS_COLOR: Color = Color(0.06, 0.06, 0.07)
const GLASS_COLOR: Color = Color(0.12, 0.16, 0.2)
const TRAILER_COLOR: Color = Color(0.82, 0.83, 0.85)
const BRAKE_OFF_COLOR: Color = Color(0.3, 0.02, 0.02)
const BRAKE_ON_COLOR: Color = Color(1.0, 0.08, 0.05)
const INDICATOR_OFF_COLOR: Color = Color(0.35, 0.22, 0.05)
const INDICATOR_ON_COLOR: Color = Color(1.0, 0.6, 0.05)

## Materials shared by every view: one per paint colour and one per fixed surface,
## so bodies of the same colour batch and nothing is allocated per spawn.
static var _paints: Dictionary[Color, StandardMaterial3D] = {}
static var _fixed: Dictionary[Color, StandardMaterial3D] = {}
static var _lit: Dictionary[Color, StandardMaterial3D] = {}

var look: VehicleLook.Look
## The vehicle shown; null while the view waits in the pool.
var vehicle: VehicleState
var paint_color: Color
## Parts painted in the vehicle's colour.
var painted: Array[MeshInstance3D] = []
## Left then right, as seen from behind.
var brake_lights: Array[MeshInstance3D] = []
## Front then rear on each side.
var indicators_left: Array[MeshInstance3D] = []
var indicators_right: Array[MeshInstance3D] = []
var brake_lit: bool = false
var left_lit: bool = false
var right_lit: bool = false

var _view: ViewConfig


## Builds the body of `body_look` for a vehicle `length_m` long and `width_m` wide.
func build(body_look: VehicleLook.Look, length_m: float, width_m: float, view_config: ViewConfig) -> void:
	look = body_look
	_view = view_config
	var lamp_y: float = 0.0
	match look:
		VehicleLook.Look.CAR:
			_part("Chassis", Vector3(width_m * 0.95, 0.35, length_m * 0.92), 0.25, 0.0, _fixed_material(CHASSIS_COLOR))
			_paint("Body", Vector3(width_m, 0.55, length_m), 0.65, 0.0)
			_part("Cabin", Vector3(width_m * 0.88, 0.5, length_m * 0.5), 1.175, length_m * 0.05, _fixed_material(GLASS_COLOR))
			lamp_y = 0.75
		VehicleLook.Look.VAN:
			_part("Chassis", Vector3(width_m * 0.95, 0.4, length_m * 0.92), 0.25, 0.0, _fixed_material(CHASSIS_COLOR))
			_paint("Body", Vector3(width_m, 0.9, length_m), 0.85, 0.0)
			_part("Cabin", Vector3(width_m * 0.94, 0.5, length_m * 0.8), 1.55, length_m * 0.08, _fixed_material(GLASS_COLOR))
			_paint("Roof", Vector3(width_m * 0.94, 0.12, length_m * 0.8), 1.86, length_m * 0.08)
			lamp_y = 0.95
		VehicleLook.Look.TRUCK:
			var trailer_length: float = length_m - TRUCK_CAB_LENGTH_M - TRUCK_CAB_GAP_M
			_part("Chassis", Vector3(width_m * 0.9, 0.6, length_m), 0.5, 0.0, _fixed_material(CHASSIS_COLOR))
			_paint("Cab", Vector3(width_m, 2.4, TRUCK_CAB_LENGTH_M), 2.0, (TRUCK_CAB_LENGTH_M - length_m) / 2.0)
			_part("Trailer", Vector3(width_m, 3.0, trailer_length), 2.5, (length_m - trailer_length) / 2.0,
					_fixed_material(TRAILER_COLOR))
			lamp_y = 0.65

	var rear_z: float = (length_m + LAMP_DEPTH_M) / 2.0
	var front_z: float = -rear_z
	var brake_x: float = width_m / 2.0 - BRAKE_LAMP_INSET_M
	var indicator_x: float = width_m / 2.0 - INDICATOR_INSET_M
	for side: float in [-1.0, 1.0]:
		brake_lights.append(_lamp("BrakeLight", BRAKE_LAMP_SIZE, Vector3(side * brake_x, lamp_y, rear_z)))
	for z: float in [front_z, rear_z]:
		indicators_left.append(_lamp("IndicatorLeft", INDICATOR_SIZE, Vector3(-indicator_x, lamp_y, z)))
		indicators_right.append(_lamp("IndicatorRight", INDICATOR_SIZE, Vector3(indicator_x, lamp_y, z)))
	_set_lamps()


## Shows `shown` in its paint; the view then follows it on `update`.
func bind(shown: VehicleState) -> void:
	vehicle = shown
	paint_color = VehicleLook.color_of(shown, _view)
	var paint: StandardMaterial3D = _paint_material(paint_color)
	for part: MeshInstance3D in painted:
		part.material_override = paint
	brake_lit = false
	left_lit = false
	right_lit = false
	_set_lamps()
	visible = true


## Back to the pool: hidden and no longer following a vehicle.
func unbind() -> void:
	vehicle = null
	visible = false


## Places the body at lateral position `lateral_u`, `vehicle.s - player_s` ahead of
## the player, and lights its lamps for sim time `time_s`.
func update(player_s: float, lateral_u: float, time_s: float) -> void:
	position = Vector3(RoadLayout.x_of(lateral_u), 0.0, -(vehicle.s - player_s))
	var blink: bool = SignalBlink.is_lit(vehicle, time_s, _view.signal_blink_hz)
	var brake: bool = BrakeLights.is_lit(vehicle, _view.brake_light_decel_mps2)
	var left: bool = blink and vehicle.signal_dir == VehicleState.Dir.LEFT
	var right: bool = blink and vehicle.signal_dir == VehicleState.Dir.RIGHT
	if brake != brake_lit or left != left_lit or right != right_lit:
		brake_lit = brake
		left_lit = left
		right_lit = right
		_set_lamps()


func _set_lamps() -> void:
	for lamp: MeshInstance3D in brake_lights:
		lamp.material_override = _lamp_material(BRAKE_ON_COLOR if brake_lit else BRAKE_OFF_COLOR, brake_lit)
	for lamp: MeshInstance3D in indicators_left:
		lamp.material_override = _lamp_material(INDICATOR_ON_COLOR if left_lit else INDICATOR_OFF_COLOR, left_lit)
	for lamp: MeshInstance3D in indicators_right:
		lamp.material_override = _lamp_material(INDICATOR_ON_COLOR if right_lit else INDICATOR_OFF_COLOR, right_lit)


func _paint(node_name: String, size: Vector3, center_y: float, center_z: float) -> void:
	painted.append(_part(node_name, size, center_y, center_z, null))


func _part(node_name: String, size: Vector3, center_y: float, center_z: float, material: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = node_name
	part.mesh = mesh
	part.material_override = material
	part.position = Vector3(0.0, center_y, center_z)
	add_child(part)
	return part


func _lamp(node_name: String, size: Vector2, center: Vector3) -> MeshInstance3D:
	var lamp: MeshInstance3D = _part(node_name, Vector3(size.x, size.y, LAMP_DEPTH_M), center.y, center.z, null)
	lamp.position.x = center.x
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return lamp


static func _paint_material(color: Color) -> StandardMaterial3D:
	if not _paints.has(color):
		_paints[color] = _material(color, false)
	return _paints[color]


static func _fixed_material(color: Color) -> StandardMaterial3D:
	if not _fixed.has(color):
		_fixed[color] = _material(color, false)
	return _fixed[color]


## A lit lamp is unshaded so it glows in any light; an unlit one is shaded.
static func _lamp_material(color: Color, lit: bool) -> StandardMaterial3D:
	var cache: Dictionary[Color, StandardMaterial3D] = _lit if lit else _fixed
	if not cache.has(color):
		cache[color] = _material(color, lit)
	return cache[color]


static func _material(color: Color, unshaded: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
