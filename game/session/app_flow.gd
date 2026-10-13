class_name AppFlow
extends RefCounted
## The screens of the game and the way between them (requirements §9.4, spec UI/UX
## flow, issue #43): Start → New session → 3-2-1 → Drive → Summary → History / again /
## menu. Screens hold these as Callables so tests can watch instead of switching.

const START_SCENE: String = "res://ui/start_screen.tscn"
const MAIN_SCENE: String = "res://game/main.tscn"
const HISTORY_SCENE: String = "res://ui/history_screen.tscn"


## Switches to the scene at `path`.
static func open_scene(tree: SceneTree, path: String) -> void:
	tree.change_scene_to_file(path)


## Starts a session with `options` in place of the current scene. The drivable scene
## gets them before it enters the tree, so it does not read the dev launcher. Deferred,
## so a button of the scene being replaced can call it.
static func start_session(tree: SceneTree, options: LaunchOptions) -> void:
	_swap.call_deferred(tree, session_scene(options))


## The drivable scene, not yet in the tree, set to start a session with `options`.
static func session_scene(options: LaunchOptions) -> Node:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	main.set(&"launch_options", options)
	return main


static func _swap(tree: SceneTree, scene: Node) -> void:
	var old: Node = tree.current_scene
	if old != null:
		tree.root.remove_child(old)
		old.queue_free()
	tree.root.add_child(scene)
	tree.current_scene = scene
