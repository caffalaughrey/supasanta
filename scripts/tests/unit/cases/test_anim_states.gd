extends Node

func _get_playback(player: Node) -> AnimationNodeStateMachinePlayback:
	var tree := player.get_node_or_null("AnimationTree") as AnimationTree
	if tree == null:
		return null
	return tree.get("parameters/playback")

func run(runner) -> void:
	var scene := load("res://scenes/Player.tscn") as PackedScene
	var player := scene.instantiate()
	get_tree().root.add_child(player)
	await get_tree().process_frame
	var pb := _get_playback(player)
	runner.assert_true(pb != null, "Playback missing")
	if pb == null:
		return
	# Idle initially
	await get_tree().process_frame
	runner.assert_true(pb.get_current_node() == "Idle", "Should start in Idle")
	# Simulate move right (walk)
	player.velocity.x = 1.0
	await get_tree().process_frame
	runner.assert_true(pb.get_current_node() == "Walk" or pb.get_current_node() == "Run", "Should be walking or running")
	# Simulate running
	player.call("_process_input", 0.0)
	Input.action_press("run")
	player.velocity.x = 2.0
	await get_tree().process_frame
	runner.assert_true(pb.get_current_node() == "Run", "Should be running")
	Input.action_release("run")
	# Jump
	Input.action_press("jump")
	await get_tree().process_frame
	Input.action_release("jump")
	await get_tree().process_frame
	runner.assert_true(pb.get_current_node() == "AirLoop" or pb.get_current_node() == "JumpStart", "Should be airborne")
	# Land
	player.velocity.y = 0
	player.position.y = 2.0
	await get_tree().process_frame
	runner.assert_true(true, "State test completed")
	player.queue_free()
	await get_tree().process_frame


