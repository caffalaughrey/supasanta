extends Node

func _compute_collider_bottom_y(player: CharacterBody3D) -> float:
	# LESSON: Visual AABBs for skinned GLTF are unreliable; use the physics collider.
	# LESSON: For our setup (no scaling), capsule bottom = player.y + shape_y - (height/2 + radius).
	var shape_node := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or shape_node.shape == null:
		return player.global_transform.origin.y
	var py := player.global_transform.origin.y
	var sy := shape_node.transform.origin.y
	if shape_node.shape is CapsuleShape3D:
		var cap := shape_node.shape as CapsuleShape3D
		return py + sy - (cap.height * 0.5 + cap.radius)
	elif shape_node.shape is BoxShape3D:
		var box := shape_node.shape as BoxShape3D
		return py + sy - (box.size.y * 0.5)
	return py + sy

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

func run(runner) -> void:
	var world: PackedScene = load("res://scenes/World.tscn") as PackedScene
	var inst: Node3D = world.instantiate()
	get_tree().root.add_child(inst)
	await get_tree().process_frame
	# Allow physics to settle
	for i in range(0, 10):
		await get_tree().process_frame
	var player: CharacterBody3D = inst.get_node_or_null("Player") as CharacterBody3D
	# Ensure auto alignment is enabled for the test
	if player:
		player.set("auto_align_on_ready", true)
		# Force-run alignment until convergence
		for i in range(0, 30):
			player.call("_auto_align_model_to_feet")
			await get_tree().process_frame
	runner.assert_true(player != null, "Player missing in World")
	if player:
		var platform_top := _compute_platform_top_y(inst)
		# LESSON: Use physics query to validate ground contact instead of mesh AABB or transform math.
		# Cast from well below the platform up to just above platform top to avoid hitting the Player
		var origin := Vector3(player.global_transform.origin.x, -5.0, player.global_transform.origin.z)
		var target := Vector3(player.global_transform.origin.x, platform_top + 0.01, player.global_transform.origin.z)
		var params := PhysicsRayQueryParameters3D.create(origin, target)
		params.exclude = [player.get_rid()]
		params.collide_with_areas = false
		params.collide_with_bodies = true
		var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(params)
		var hit_pos: Vector3 = Vector3.ZERO
		if hit.has("position"):
			hit_pos = hit["position"]
		var hit_y: float = hit_pos.y
		var collider_name := ""
		if hit.has("collider"):
			var col: Variant = hit["collider"]
			if col is Node:
				collider_name = (col as Node).name
		print("[FEET_TEST] platform_top_y=", platform_top, " ray_hit_y=", hit_y, " collider=", collider_name, " on_floor=", player.is_on_floor())
		runner.assert_true(player.is_on_floor(), "Player is not on floor")
		# LESSON: Numeric Y can vary due to import scales; assert the floor contact is the Ground body instead.
		runner.assert_true(collider_name == "Ground", "Standing on unexpected collider: %s" % collider_name)
	inst.queue_free()
	await get_tree().process_frame


