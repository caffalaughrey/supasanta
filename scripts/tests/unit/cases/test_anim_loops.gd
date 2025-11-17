extends Node

# Validates loop settings on Player.tscn's core loop clips

const LOOP_CLIPS := ["Idle", "Walk", "Run", "AirLoop"]

func run(runner: Node) -> void:
	var scene_path := "res://scenes/Player.tscn"
	var res := load(scene_path)
	runner.assert_true(res is PackedScene, "Player.tscn not a scene")
	if not (res is PackedScene):
		return
	var inst := (res as PackedScene).instantiate()
	add_child(inst)
	await get_tree().process_frame
	var ap: AnimationPlayer = inst.get_node_or_null("AnimationPlayer") as AnimationPlayer
	runner.assert_true(ap != null, "Player.AnimationPlayer missing")
	if ap == null:
		inst.queue_free()
		await get_tree().process_frame
		return
	var names := ap.get_animation_list()
	for clip in LOOP_CLIPS:
		runner.assert_true(clip in names, "Missing loop clip: %s" % clip)
		if not (clip in names):
			continue
		var anim: Animation = ap.get_animation(clip)
		# 1 = LOOP_FORWARD in Godot 4
		runner.assert_true(anim.loop_mode != 0, "Clip not set to loop: %s" % clip)
		runner.assert_true(anim.length > 0.0, "Loop clip has zero length: %s" % clip)
	inst.queue_free()
	await get_tree().process_frame


