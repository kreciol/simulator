class_name MirrorsView
extends CanvasLayer
## The rear-view and the two side mirrors (requirements §5.2, spec Phase 5 step 1),
## mounted on the player's rig. With mirrors off none is built, so no extra view of
## the world is rendered. Mirror range never exceeds the road kept behind the player
## (`ViewConfig.mirror_range_m`), and fog fades the road out by it.

var view: ViewConfig
var quality: QualityPreset
var rear: Mirror
var left: Mirror
var right: Mirror

## Built once, so the per-frame update allocates nothing.
var _mirrors: Array[Mirror] = []


## Builds the mirrors when `enabled`; `world_environment` is the scene's, copied with
## the mirrors' own fog distance.
func setup(view_config: ViewConfig, quality_preset: QualityPreset, enabled: bool,
		world_environment: Environment) -> void:
	view = view_config
	quality = quality_preset
	visible = enabled
	if not enabled:
		return
	var environment: Environment = world_environment.duplicate() as Environment
	environment.fog_depth_end = view.mirror_range_m()
	environment.fog_depth_begin = view.mirror_range_m() * view.mirror_fog_begin_share

	var pitch: float = -deg_to_rad(view.mirror_pitch_down_deg)
	var outward: float = deg_to_rad(view.side_mirror_outward_deg)
	# Facing backwards is a half turn about y; a side mirror turns a little further
	# towards its own side (left is -x).
	rear = _mirror("RearMirror", view.rear_mirror_rect,
			_mount(view.rear_mirror_position, PI, pitch), view.rear_mirror_fov_deg, environment)
	left = _mirror("LeftMirror", view.left_mirror_rect,
			_mount(view.left_mirror_position, PI - outward, pitch), view.side_mirror_fov_deg, environment)
	var right_position: Vector3 = view.left_mirror_position * Vector3(-1.0, 1.0, 1.0)
	right = _mirror("RightMirror", view.right_mirror_rect(),
			_mount(right_position, PI + outward, pitch), view.side_mirror_fov_deg, environment)
	_mirrors = [rear, left, right]


## Mirrors built: none when off.
func mirrors() -> Array[Mirror]:
	return _mirrors


## Shows or hides the built mirrors; hidden mirrors render nothing (the end screen
## would otherwise show them bright above its dimmed backdrop, issue #58).
func set_shown(shown: bool) -> void:
	var was_visible: bool = visible
	visible = shown and not _mirrors.is_empty()
	if visible or not was_visible:
		return
	for mirror: Mirror in _mirrors:
		mirror.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


## Follows the player's rig at `rig_position`; hidden mirrors stay still.
func update(rig_position: Vector3) -> void:
	if not visible:
		return
	for mirror: Mirror in _mirrors:
		mirror.update(rig_position)


func _mount(origin: Vector3, yaw: float, pitch: float) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0.0)), origin)


func _mirror(node_name: String, screen_rect: Rect2, mount: Transform3D, fov_deg: float,
		environment: Environment) -> Mirror:
	var mirror: Mirror = Mirror.new()
	mirror.name = node_name
	add_child(mirror)
	mirror.setup(screen_rect, mount, fov_deg, view.mirror_range_m(), environment, quality)
	return mirror
