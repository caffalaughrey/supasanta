extends Node

func run(runner) -> void:
	# Validate that the Player scene ships with the 0–11 core clips
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
	print("[ANIMS] Player clips: ", names)
	var expected := [
		"Idle","Walk","Run","Turn","Skid",
		"JumpStart","AirLoop","Land","SpinJump","Swing","Throw"
	]
	for n in expected:
		runner.assert_true(n in names, "Missing player animation: " + n)
		if n in names:
			var anim := ap.get_animation(n)
			var tracks := anim.get_track_count()
			print("[ANIMS] clip=", n, " tracks=", tracks)
			# Placeholder clips may be empty; only check existence deterministically
	inst.queue_free()
	await get_tree().process_frame


