extends GdUnitTestSuite
## The way between screens (issue #43): a session scene gets its options before it
## enters the tree, and a swap puts the new scene in place of the old one — also when
## deferred from a button of the scene being replaced.


func test_the_session_scene_carries_the_options() -> void:
	var launcher: DevLauncherConfig = load("res://config/dev_launcher.tres") as DevLauncherConfig
	var options: LaunchOptions = SessionSetup.options_for(LaunchOptions.MODE_LEARN, &"motorway", 2, launcher, 3)
	var main: DriveScene = AppFlow.session_scene(options)
	assert_object(main.launch_options).is_same(options)
	assert_bool(main.is_inside_tree()).is_false()
	main.free()


func test_replace_swaps_the_old_scene_for_the_new_one() -> void:
	var parent: Node = auto_free(Node.new()) as Node
	add_child(parent)
	var old: Node = Node.new()
	parent.add_child(old)
	var scene: Node = Node.new()
	assert_object(AppFlow.replace(parent, old, scene)).is_same(scene)
	assert_array(parent.get_children()).contains_exactly([scene])
	assert_bool(old.is_queued_for_deletion()).is_true()


func test_a_deferred_swap_lands_on_the_next_frame() -> void:
	# `start_session` defers the static swap, so a pressed button is not freed mid-signal.
	var parent: Node = auto_free(Node.new()) as Node
	add_child(parent)
	var old: Node = Node.new()
	parent.add_child(old)
	var scene: Node = Node.new()
	AppFlow.replace.call_deferred(parent, old, scene)
	assert_array(parent.get_children()).contains_exactly([old])
	await get_tree().process_frame
	assert_array(parent.get_children()).contains_exactly([scene])
	assert_bool(is_instance_valid(old)).is_false()


func test_without_an_old_scene_the_new_one_is_just_added() -> void:
	var parent: Node = auto_free(Node.new()) as Node
	add_child(parent)
	var scene: Node = Node.new()
	AppFlow.replace(parent, null, scene)
	assert_array(parent.get_children()).contains_exactly([scene])
