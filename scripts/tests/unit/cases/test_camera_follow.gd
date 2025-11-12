extends Node

func run(runner) -> void:
	var world: Node3D = Node3D.new()
	get_tree().root.add_child(world)
	var player: Node3D = Node3D.new()
	player.name = "Player"
	world.add_child(player)
	player.global_position = Vector3(0, 1, 0)
	var rig: Node3D = load("res://scripts/camera/CameraRig.gd").new()
	world.add_child(rig)
	rig.set("follow_smooth", 100.0)
	rig.set("vertical_deadzone", 0.5)
	rig._on_player_ready()
	await get_tree().process_frame
	# Move player and ensure camera follows horizontally
	player.global_position.x = 10.0
	await get_tree().process_frame
	var cam_pos: Vector3 = rig.global_position
	runner.assert_true(cam_pos.x > 5.0, "Camera did not move towards player X")
	# Move player up and ensure camera changes Y after deadzone
	var initial_y: float = rig.global_position.y
	player.global_position.y = initial_y + 5.0
	# Let multiple frames pass for smoothing
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	runner.assert_true(rig.global_position.y > initial_y + 1.0, "Camera did not adjust Y after deadzone")
	world.queue_free()
	await get_tree().process_frame


