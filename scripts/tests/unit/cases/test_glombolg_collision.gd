extends Node

func run(runner) -> void:
	var world: PackedScene = load("res://scenes/World.tscn") as PackedScene
	var inst: Node3D = world.instantiate()
	get_tree().root.add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	var player := inst.get_node_or_null("Player") as CharacterBody3D
	var glom := inst.get_node_or_null("Glombolg") as Node3D
	runner.assert_true(glom != null, "Glombolg node missing in World")
	runner.assert_true(player != null, "Player missing in World")
	if glom != null and player != null:
		var ppos := player.global_transform.origin
		var gpos := glom.global_transform.origin
		# Cast a ray from slightly left of player towards Glombolg along x at player chest height
		var origin := Vector3(min(ppos.x, gpos.x) - 0.5, ppos.y + 0.6, ppos.z)
		var target := Vector3(max(ppos.x, gpos.x) + 0.5, ppos.y + 0.6, ppos.z)
		var params := PhysicsRayQueryParameters3D.create(origin, target)
		params.exclude = [player.get_rid()]
		params.collide_with_areas = false
		params.collide_with_bodies = true
		var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(params)
		var collider_name := ""
		if hit.has("collider"):
			var col: Variant = hit["collider"]
			if col is Node:
				collider_name = (col as Node).name
		runner.assert_true(collider_name == "GlombolgBody", "Ray did not hit GlombolgBody (hit=%s)" % collider_name)
	inst.queue_free()
	await get_tree().process_frame















