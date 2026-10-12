class_name Mirror
extends Control
## One mirror on screen (requirements §5.2): a rear-facing camera rendering into a
## low-resolution `SubViewport` that shares the main `World3D`, shown left-right
## flipped as a real mirror shows it, in a thin frame. Render size and update rate come
## from the quality preset (spec Architecture: Mirrors). Only reads the world.

const FRAME_PX: float = 3.0
const FRAME_COLOR: Color = Color(0.05, 0.05, 0.06)
const CAMERA_NEAR_M: float = 0.1

var quality: QualityPreset
var viewport: SubViewport
var camera: Camera3D
var image: TextureRect
## Camera placement relative to the player's rig.
var mount: Transform3D

var _frame: int = 0


## `screen_rect` is the mirror's place on screen as shares of the screen.
func setup(screen_rect: Rect2, mount_transform: Transform3D, fov_deg: float, range_m: float,
		environment: Environment, quality_preset: QualityPreset) -> void:
	quality = quality_preset
	mount = mount_transform
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = screen_rect.position.x
	anchor_top = screen_rect.position.y
	anchor_right = screen_rect.end.x
	anchor_bottom = screen_rect.end.y

	var frame: ColorRect = ColorRect.new()
	frame.name = "Frame"
	frame.color = FRAME_COLOR
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)

	viewport = SubViewport.new()
	viewport.name = "Viewport"
	# No own World3D: it renders the main world's road and traffic.
	viewport.own_world_3d = false
	viewport.gui_disable_input = true
	add_child(viewport)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = fov_deg
	camera.near = CAMERA_NEAR_M
	camera.far = range_m
	camera.environment = environment
	viewport.add_child(camera)
	camera.current = true

	image = TextureRect.new()
	image.name = "Image"
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.flip_h = true
	image.texture = viewport.get_texture()
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.offset_left = FRAME_PX
	image.offset_top = FRAME_PX
	image.offset_right = -FRAME_PX
	image.offset_bottom = -FRAME_PX
	add_child(image)

	_fit_resolution()
	resized.connect(_fit_resolution)
	# The window can grow while the stretched canvas keeps its size.
	get_viewport().size_changed.connect(_fit_resolution)
	_schedule_render()


## Places the camera on the rig at `rig_position` and renders this frame when the
## preset's interval says so.
func update(rig_position: Vector3) -> void:
	camera.transform = Transform3D(mount.basis, rig_position + mount.origin)
	_frame += 1
	_schedule_render()


## Render size: the mirror's size on screen in pixels, scaled by the preset (spec:
## low 1/4, high 1/2). The canvas is stretched to the window, so its units are
## converted to screen pixels first.
func render_size() -> Vector2i:
	var shown: Vector2 = (size - Vector2(2.0 * FRAME_PX, 2.0 * FRAME_PX)) * screen_scale()
	var scaled: Vector2 = shown * quality.mirror_resolution_scale
	return Vector2i(maxi(1, roundi(scaled.x)), maxi(1, roundi(scaled.y)))


## Screen pixels per canvas unit (the window's stretch).
func screen_scale() -> Vector2:
	return get_viewport().get_final_transform().get_scale()


## Where `world_point` shows in the mirror, in mirror pixels from the left: the
## camera's view flipped left-right, as on screen.
func mirrored_x(world_point: Vector3) -> float:
	return float(viewport.size.x) - camera.unproject_position(world_point).x


func _fit_resolution() -> void:
	viewport.size = render_size()


func _schedule_render() -> void:
	if quality.mirror_update_interval_frames <= 1:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	elif _frame % quality.mirror_update_interval_frames == 0:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	else:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
