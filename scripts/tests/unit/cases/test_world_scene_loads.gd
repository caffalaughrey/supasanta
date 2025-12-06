extends Node

func run(runner: Node) -> void:
	var path := "res://scenes/World.tscn"
	runner.assert_true(ResourceLoader.exists(path), "World.tscn exists")
	var packed := load(path) as PackedScene
	runner.assert_true(packed != null, "World.tscn loads as PackedScene")
	if packed != null:
		var inst := packed.instantiate()
		get_tree().root.add_child(inst)
		await get_tree().process_frame
		# Assert key nodes exist
		runner.assert_true(inst.get_node_or_null("DirectionalLight3D") != null, "World has node: DirectionalLight3D")
		runner.assert_true(inst.get_node_or_null("CameraRig") != null, "World has node: CameraRig")
		var cam := inst.get_node_or_null("CameraRig/Camera3D")
		if cam == null:
			cam = inst.find_child("Camera3D", true, false)
		runner.assert_true(cam != null, "World has nested node: Camera3D")
		inst.queue_free()
		await get_tree().process_frame


