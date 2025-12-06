extends Node

func _compute_platform_top_y(inst: Node3D) -> float:
	var cs := inst.get_node_or_null("Ground/CollisionShape3D") as CollisionShape3D
	if cs == null:
		return 0.0
	var box := cs.shape as BoxShape3D
	if box == null:
		return cs.global_transform.origin.y
	var scale_y := cs.global_transform.basis.get_scale().y
	var top_y := cs.global_transform.origin.y + (box.size.y * scale_y) * 0.5
	return top_y

func _gather_meshes(root: Node3D) -> Array:
	var meshes: Array = []
	for child in root.get_children():
		if child is MeshInstance3D:
			meshes.append(child)
		elif child is Node3D:
			meshes += _gather_meshes(child)
	return meshes

func _compute_bottom_y(root: Node3D) -> float:
	var min_y := INF
	var meshes := _gather_meshes(root)
	for m in meshes:
		var mesh := m as MeshInstance3D
		var aabb := mesh.get_aabb()
		var xs := [aabb.position.x, aabb.position.x + aabb.size.x]
		var ys := [aabb.position.y, aabb.position.y + aabb.size.y]
		var zs := [aabb.position.z, aabb.position.z + aabb.size.z]
		for x in xs:
			for y in ys:
				for z in zs:
					var p_world := mesh.to_global(Vector3(x, y, z))
					if p_world.y < min_y:
						min_y = p_world.y
	return min_y

func run(runner) -> void:
	var world: PackedScene = load("res://scenes/World.tscn") as PackedScene
	var inst: Node3D = world.instantiate()
	get_tree().root.add_child(inst)
	await get_tree().process_frame

	var penguin := inst.get_node_or_null("PenguinFrench") as Node3D
	runner.assert_true(penguin != null, "PenguinFrench missing in World")
	if penguin != null:
		var platform_top := _compute_platform_top_y(inst)
		var bottom_y := _compute_bottom_y(penguin)
		# Allow a small tolerance because AABBs are approximate and the mesh may not be perfectly flat.
		var diff := abs(bottom_y - platform_top)
		print("[PENGUIN_FEET] bottom_y=", bottom_y, " platform_top=", platform_top, " diff=", diff)
		runner.assert_true(diff < 0.25, "PenguinFrench feet not near ground (bottom_y=%f, ground_y=%f)" % [bottom_y, platform_top])

	inst.queue_free()
	await get_tree().process_frame



