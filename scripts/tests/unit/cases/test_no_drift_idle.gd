extends Node

func run(runner) -> void:
	var world := load("res://scenes/World.tscn") as PackedScene
	var inst := world.instantiate()
	get_tree().root.add_child(inst)
	await get_tree().process_frame
	# Capture initial X
	var player := inst.get_node_or_null("Player") as CharacterBody3D
	runner.assert_true(player != null, "Player missing")
	if player == null:
		return
	var x0 := player.global_position.x
	# Wait ~2 seconds
	for i in range(0, 120):
		await get_tree().process_frame
	var x1 := player.global_position.x
	var dx := absf(x1 - x0)
	runner.assert_true(dx < 0.02, "Player drifted at idle (dx=%.4f)" % dx)
	inst.queue_free()
	await get_tree().process_frame









