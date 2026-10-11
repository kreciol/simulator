class_name RoadView
extends Node3D
## Endless straight road (requirements §4.3): a fixed pool of identical segments,
## recycled from behind the player to the front. Floating origin by construction:
## a segment starting at distance `s` sits at z = -(s - player_s), so the player
## stays at the origin however far the session goes. Only reads simulation state.

var layout: RoadLayout
var view: ViewConfig

var _segments: Array[MeshInstance3D] = []
## Index of the stretch of road each pooled segment shows: it starts at index * length.
var _indices: PackedInt64Array = PackedInt64Array()
## Index of the rearmost segment at the last update; INT64_MIN before the first one.
var _first_index: int = -9223372036854775807 - 1


func setup(road_profile: RoadProfile, view_config: ViewConfig) -> void:
	view = view_config
	layout = RoadLayout.new(road_profile, view_config)
	var mesh: ArrayMesh = RoadSegmentMesh.build(layout)
	for i: int in view.segment_count:
		var segment: MeshInstance3D = MeshInstance3D.new()
		segment.name = "Segment%d" % i
		segment.mesh = mesh
		add_child(segment)
		_segments.append(segment)
	_indices.resize(view.segment_count)


## Places the pool around `player_s`, recycling segments that fell out of the window.
func update(player_s: float) -> void:
	var length: float = view.segment_length_m
	var first: int = floori(player_s / length) - view.segments_behind
	if first != _first_index:
		_recycle(first)
	for i: int in _segments.size():
		_segments[i].position = Vector3(0.0, 0.0, -(float(_indices[i]) * length - player_s))


## Pooled segments, for inspection; never add or free them.
func segments() -> Array[MeshInstance3D]:
	return _segments


func _recycle(first: int) -> void:
	var count: int = _segments.size()
	var last: int = first + count - 1
	var shown: Dictionary[int, bool] = {}
	var free_slots: Array[int] = []
	for i: int in count:
		if _indices[i] >= first and _indices[i] <= last and not shown.has(_indices[i]):
			shown[_indices[i]] = true
		else:
			free_slots.append(i)
	for index: int in range(first, last + 1):
		if not shown.has(index):
			_indices[free_slots.pop_back()] = index
	_first_index = first
