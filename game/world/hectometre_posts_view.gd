class_name HectometrePostsView
extends Node3D
## Hectometre posts beside the right shoulder (issue #68): post k stands at
## s = k * spacing in road coordinates and sits at z = -(s - player_s), the floating
## origin `RoadView` uses. Posts exist exactly where `RoadView` keeps road, so a post
## only appears on a stretch that itself appears beyond the draw distance (no popping)
## and the mirrors see the posts behind. A fixed pool, recycled; only reads the sim.

## The band wraps the body by a hair, against z-fighting.
const BAND_WIDTH_SCALE: float = 1.05
const POST_ROUGHNESS: float = 0.8

var layout: RoadLayout
var view: ViewConfig

var _posts: Array[MeshInstance3D] = []
## Post index each pooled node shows; meaningful only while the node is visible.
var _indices: PackedInt64Array = PackedInt64Array()
## Post index range shown at the last update; first > last before the first one.
var _first_index: int = 0
var _last_index: int = -1


func setup(road_profile: RoadProfile, view_config: ViewConfig) -> void:
	view = view_config
	layout = RoadLayout.new(road_profile, view_config)
	var mesh: ArrayMesh = build_mesh(view_config)
	for i: int in view.hectometre_post_count():
		var post: MeshInstance3D = MeshInstance3D.new()
		post.name = "Post%d" % i
		post.mesh = mesh
		post.visible = false
		add_child(post)
		_posts.append(post)
	_indices.resize(_posts.size())


## One post standing on the road (y = 0) centred on x = z = 0: a body surface and a
## slightly wider band surface just below the top, so a post costs two draw calls.
static func build_mesh(view_config: ViewConfig) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var width: float = view_config.hectometre_post_width_m
	var height: float = view_config.hectometre_post_height_m
	var band: float = view_config.hectometre_post_band_height_m
	var band_width: float = width * BAND_WIDTH_SCALE
	_add_box(mesh, Vector3(width, height, width), height / 2.0, view_config.hectometre_post_color)
	_add_box(mesh, Vector3(band_width, band, band_width), height - band, view_config.hectometre_post_band_color)
	return mesh


## Places the posts in the road's window around `player_s`, recycling those that left it.
func update(player_s: float) -> void:
	var spacing: float = view.hectometre_post_spacing_m
	var length: float = view.segment_length_m
	# The same window RoadView keeps: `segment_count` segments from the rearmost one.
	var first_segment: int = floori(player_s / length) - view.segments_behind
	var start: float = float(first_segment) * length
	var end: float = float(first_segment + view.segment_count) * length
	var first: int = ceili(start / spacing)
	var last: int = ceili(end / spacing) - 1
	if first != _first_index or last != _last_index:
		_recycle(first, last)
	var x: float = RoadLayout.x_of(layout.hectometre_post_u())
	for i: int in _posts.size():
		if _posts[i].visible:
			_posts[i].position = Vector3(x, 0.0, -(float(_indices[i]) * spacing - player_s))


## Pooled posts, for inspection; never add or free them.
func posts() -> Array[MeshInstance3D]:
	return _posts


func _recycle(first: int, last: int) -> void:
	var shown: Dictionary[int, bool] = {}
	var free_slots: Array[int] = []
	for i: int in _posts.size():
		if _posts[i].visible and _indices[i] >= first and _indices[i] <= last and not shown.has(_indices[i]):
			shown[_indices[i]] = true
		else:
			free_slots.append(i)
	# The pool holds as many posts as the window can, so a free slot is always left;
	# the guard only covers a spacing whose float division rounds the window wider.
	for index: int in range(first, last + 1):
		if not shown.has(index) and not free_slots.is_empty():
			var slot: int = free_slots.pop_back()
			_indices[slot] = index
			_posts[slot].visible = true
	for i: int in free_slots:
		_posts[i].visible = false
	_first_index = first
	_last_index = last


static func _add_box(mesh: ArrayMesh, size: Vector3, center_y: float, color: Color) -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	var arrays: Array = box.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i: int in vertices.size():
		vertices[i].y += center_y
	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = POST_ROUGHNESS
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)
