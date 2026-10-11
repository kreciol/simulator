class_name RoadSegmentMesh
extends RefCounted
## Builds the mesh of one road segment from a `RoadLayout`: one surface per material,
## so a segment costs one draw call per material. Local space: the segment starts at
## z = 0 and runs forward to z = -segment_length_m; all segments share this mesh.

const COLORS: Dictionary[RoadLayout.Surface, Color] = {
	RoadLayout.Surface.TERRAIN: Color(0.36, 0.5, 0.27),
	RoadLayout.Surface.ASPHALT: Color(0.24, 0.24, 0.26),
	RoadLayout.Surface.SHOULDER: Color(0.3, 0.3, 0.31),
	RoadLayout.Surface.PAINT: Color(0.92, 0.92, 0.9),
	RoadLayout.Surface.BARRIER: Color(0.7, 0.72, 0.74),
}


static func build(layout: RoadLayout) -> ArrayMesh:
	var length: float = layout.view.segment_length_m
	if not is_zero_approx(fmod(length, layout.view.dash_period_m())):
		push_error("RoadSegmentMesh: dash period must divide segment_length_m, or dashes jump at segment joints")
	var mesh: ArrayMesh = ArrayMesh.new()
	for surface: RoadLayout.Surface in COLORS:
		var tool: SurfaceTool = SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var has_geometry: bool = false
		for strip: RoadLayout.Strip in layout.strips_of(surface):
			has_geometry = true
			if surface == RoadLayout.Surface.BARRIER:
				_add_box(tool, strip, 0.0, length)
			elif strip.dashed:
				var period: float = layout.view.dash_period_m()
				for dash: int in floori(length / period + 1e-6):
					_add_top(tool, strip, dash * period, dash * period + layout.view.dash_length_m)
			else:
				_add_top(tool, strip, 0.0, length)
		if not has_geometry:
			continue
		tool.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material(COLORS[surface]))
	return mesh


static func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	# Strips are seen from above and barriers from both sides; skip winding concerns.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## Horizontal quad over the strip between distances `from_s` and `to_s` into the segment.
static func _add_top(tool: SurfaceTool, strip: RoadLayout.Strip, from_s: float, to_s: float) -> void:
	_add_quad(tool, Vector3.UP,
			Vector3(RoadLayout.x_of(strip.u_min), strip.top_y, -from_s),
			Vector3(RoadLayout.x_of(strip.u_max), strip.top_y, -from_s),
			Vector3(RoadLayout.x_of(strip.u_max), strip.top_y, -to_s),
			Vector3(RoadLayout.x_of(strip.u_min), strip.top_y, -to_s))


## Top and both long sides of a strip standing on the road (y = 0).
static func _add_box(tool: SurfaceTool, strip: RoadLayout.Strip, from_s: float, to_s: float) -> void:
	_add_top(tool, strip, from_s, to_s)
	for u: float in [strip.u_min, strip.u_max]:
		var x: float = RoadLayout.x_of(u)
		var normal: Vector3 = Vector3.LEFT if u == strip.u_max else Vector3.RIGHT
		_add_quad(tool, normal,
				Vector3(x, 0.0, -from_s),
				Vector3(x, strip.top_y, -from_s),
				Vector3(x, strip.top_y, -to_s),
				Vector3(x, 0.0, -to_s))


static func _add_quad(tool: SurfaceTool, normal: Vector3, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	tool.set_normal(normal)
	for vertex: Vector3 in [a, b, c, a, c, d]:
		tool.add_vertex(vertex)
