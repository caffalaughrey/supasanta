extends Node

func run(runner) -> void:
	var world: PackedScene = load("res://scenes/World.tscn") as PackedScene
	var inst: Node3D = world.instantiate()
	get_tree().root.add_child(inst)
	await get_tree().process_frame

	var penguin := inst.get_node_or_null("PenguinFrench") as Node3D
	var player := inst.get_node_or_null("Player") as CharacterBody3D
	var glom := inst.get_node_or_null("Glombolg") as Node3D

	runner.assert_true(penguin != null, "PenguinFrench missing in World")
	runner.assert_true(player != null, "Player missing in World")

	if penguin != null and player != null:
		var ppos := player.global_transform.origin
		var peng_pos := penguin.global_transform.origin
		var dist := ppos.distance_to(peng_pos)
		print("[PENGUIN_COLLISION] player=", ppos, " penguin=", peng_pos, " dist=", dist)
		# Ensure they don't start interpenetrating; 1m spacing is plenty for these characters.
		runner.assert_true(dist > 1.0, "PenguinFrench starts too close to Player (dist=%f)" % dist)

	if penguin != null and glom != null:
		var gpos := glom.global_transform.origin
		var dist_pg := gpos.distance_to(penguin.global_transform.origin)
		print("[PENGUIN_COLLISION] penguin=", penguin.global_transform.origin, " glom=", gpos, " dist_pg=", dist_pg)
		runner.assert_true(dist_pg > 1.0, "PenguinFrench starts too close to Glombolg (dist=%f)" % dist_pg)

	inst.queue_free()
	await get_tree().process_frame



