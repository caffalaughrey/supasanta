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

func _compute_platform_half_extents_x(inst: Node3D) -> float:
	var cs := inst.get_node_or_null("Ground/CollisionShape3D") as CollisionShape3D
	if cs == null:
		return 0.0
	var box := cs.shape as BoxShape3D
	if box == null:
		return 0.0
	var scale_x := cs.global_transform.basis.get_scale().x
	return (box.size.x * scale_x) * 0.5

func run(runner) -> void:
	var world: PackedScene = load("res://scenes/World.tscn") as PackedScene
	var inst: Node3D = world.instantiate()
	get_tree().root.add_child(inst)
	await get_tree().process_frame
	# allow a couple frames for any transforms to settle
	await get_tree().process_frame
	var player := inst.get_node_or_null("Player") as CharacterBody3D
	var glom := inst.get_node_or_null("Glombolg") as Node3D
	runner.assert_true(glom != null, "Glombolg node missing in World")
	runner.assert_true(player != null, "Player missing in World (needed for z-plane)")
	if glom != null and player != null:
		var platform_top := _compute_platform_top_y(inst)
		var half_x := _compute_platform_half_extents_x(inst)
		var gpos := glom.global_transform.origin
		var ppos := player.global_transform.origin
		# Assert side-scroller track alignment (z)
		runner.assert_true(abs(gpos.z - ppos.z) <= 0.001, "Glombolg z not on track")
		# Assert within platform horizontal bounds
		runner.assert_true(gpos.x >= -half_x - 0.001 and gpos.x <= half_x + 0.001, "Glombolg x is off platform bounds")
		# Assert vertical placement near or above platform top (allow slack for GLB origins)
		runner.assert_true(gpos.y >= platform_top - 0.01, "Glombolg y below platform top")
	inst.queue_free()
	await get_tree().process_frame










