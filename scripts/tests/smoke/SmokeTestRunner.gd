extends Node

class_name SmokeTestRunner

var failures: Array[String] = []
var infos: Array[String] = []

func _log_fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)

func _log_info(msg: String) -> void:
	infos.append(msg)
	print(msg)

func run_all() -> void:
	await get_tree().process_frame
	await _test_input_actions_exist()
	await _test_player_scene_loads()
	await _test_player_has_expected_children()
	await _test_bomb_scene_loads()
	await _test_throw_spawns_bomb()
	await _test_santa_glb_optional()

	# Summary
	if failures.is_empty():
		print("*** SMOKE TESTS: OK ***")
	else:
		push_error("*** SMOKE TESTS: FAILED (%d) ***" % failures.size())
	for f in failures:
		push_error(" - " + f)
	# Exit with code
	get_tree().quit(0 if failures.is_empty() else 1)


func _test_input_actions_exist() -> void:
	var expected := [
		"move_left", "move_right",
		"run", "throw_bomb",
		"jump", "spin_jump",
		"swing"
	]
	for action in expected:
		if not InputMap.has_action(action):
			_log_fail("Missing input action: %s" % action)
		else:
			_log_info("Action present: %s" % action)


func _test_player_scene_loads() -> void:
	var path := "res://scenes/Player.tscn"
	if not ResourceLoader.exists(path):
		_log_fail("Player scene missing: %s" % path)
		return
	var packed := load(path)
	if packed == null or not (packed is PackedScene):
		_log_fail("Player scene not a PackedScene: %s" % path)
		return
	var inst := (packed as PackedScene).instantiate()
	if inst == null:
		_log_fail("Player scene failed to instantiate")
	else:
		_log_info("Player scene instantiated")
		# Ensure proper creation and cleanup to avoid RID leaks
		get_tree().root.add_child(inst)
		await get_tree().process_frame
		inst.queue_free()
		await get_tree().process_frame


func _test_player_has_expected_children() -> void:
	var packed := load("res://scenes/Player.tscn") as PackedScene
	if packed == null:
		return
	var player := packed.instantiate()
	get_tree().root.add_child(player)
	await get_tree().process_frame
	var expected_nodes := ["CollisionShape3D", "ModelRoot", "AnimationPlayer", "BombSpawn"]
	for n in expected_nodes:
		if player.get_node_or_null(n) == null:
			_log_fail("Player missing child node: %s" % n)
	_log_info("Player children presence check completed")
	player.queue_free()
	await get_tree().process_frame


func _test_bomb_scene_loads() -> void:
	var path := "res://scenes/Bomb.tscn"
	if not ResourceLoader.exists(path):
		_log_fail("Bomb scene missing: %s" % path)
		return
	var packed := load(path)
	if packed == null or not (packed is PackedScene):
		_log_fail("Bomb scene not a PackedScene: %s" % path)
		return
	var inst := (packed as PackedScene).instantiate()
	if inst == null:
		_log_fail("Bomb scene failed to instantiate")
	else:
		if not (inst is RigidBody3D):
			_log_fail("Bomb instance is not RigidBody3D")
		_log_info("Bomb scene instantiated")
		get_tree().root.add_child(inst)
		await get_tree().process_frame
		inst.queue_free()
		await get_tree().process_frame


func _test_throw_spawns_bomb() -> void:
	var world := Node3D.new()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	if player_scene == null:
		_log_fail("Cannot load Player.tscn for throw test")
		return
	var player := player_scene.instantiate()
	world.add_child(player)
	await get_tree().process_frame
	var before := _count_bombs(world)
	player.call("_throw_bomb")
	await get_tree().process_frame
	var after := _count_bombs(world)
	if after <= before:
		_log_fail("Throw did not spawn a bomb")
	else:
		_log_info("Throw spawns a bomb (before=%d, after=%d)" % [before, after])
	# Cleanup spawned objects to avoid RID leaks
	_free_all_bombs(world)
	player.queue_free()
	await get_tree().process_frame
	get_tree().current_scene = null
	world.queue_free()
	# Give cleanup a couple frames
	await get_tree().process_frame
	await get_tree().process_frame


func _test_santa_glb_optional() -> void:
	var santa_path := "res://models/santa/santa_rigged.glb"
	if ResourceLoader.exists(santa_path):
		var santa_res := load(santa_path)
		if santa_res == null:
			_log_fail("Santa GLB exists but failed to load: %s" % santa_path)
		else:
			_log_info("Santa GLB present and loadable")
	else:
		_log_info("Santa GLB not present (ok for smoke)")


func _count_bombs(root: Node) -> int:
	var count := 0
	for child in root.get_children():
		if child is RigidBody3D and child.name.begins_with("Bomb"):
			count += 1
		# dive one level down just in case
		for g in child.get_children():
			if g is RigidBody3D and g.name.begins_with("Bomb"):
				count += 1
	return count


func _free_all_bombs(root: Node) -> void:
	for child in root.get_children():
		if child is RigidBody3D and child.name.begins_with("Bomb"):
			child.queue_free()
		for g in child.get_children():
			if g is RigidBody3D and g.name.begins_with("Bomb"):
				g.queue_free()


