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
	# Walk
	player.velocity.x = 1.2
	await get_tree().process_frame
	var before := pb.get_current_node()
	# Trigger swing
	Input.action_press("swing")
	await get_tree().process_frame
	Input.action_release("swing")
	await get_tree().process_frame
	var during := pb.get_current_node()
	# Locomotion should continue as Walk/Run, not Idle
	runner.assert_true(during == "Walk" or during == "Run" or during == "Swing", "Locomotion continues while swinging")
	player.queue_free()
	await get_tree().process_frame


