extends Node

func run(runner) -> void:
	var world: Node3D = Node3D.new()
	get_tree().root.add_child(world)
	var player_scene: PackedScene = load("res://scenes/Player.tscn") as PackedScene
	if player_scene == null:
		runner.assert_true(false, "Player.tscn missing")
		return
	var player: Node = player_scene.instantiate()
	world.add_child(player)
	await get_tree().process_frame
	# If santa GLB is not present, skip this test
	if not ResourceLoader.exists("res://models/santa/santa_rigged.glb"):
		runner.assert_true(true, "Skip: santa_rigged.glb not present")
		world.queue_free()
		await get_tree().process_frame
		return
	# Find a MeshInstance3D under ModelRoot (recursive)
	var model_root: Node = player.get_node_or_null("ModelRoot")
	var found_mat: bool = false
	if model_root:
		var stack: Array[Node] = [model_root]
		while stack.size() > 0 and not found_mat:
			var n: Node = stack.pop_back()
			for c in n.get_children():
				stack.append(c)
			if n is MeshInstance3D:
				var mi: MeshInstance3D = n as MeshInstance3D
				if mi.material_override != null:
					found_mat = true
	runner.assert_true(found_mat, "DNN material was not applied to Santa meshes")
	world.queue_free()
	await get_tree().process_frame


