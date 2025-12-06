extends Node

func run(runner: Node) -> void:
	# Instantiate directly; don't depend on autoload registration
	var pl_script := load("res://scripts/autoload/pack_loader.gd")
	var pl: Node = (pl_script as Script).new()
	add_child(pl)
	var ok: bool = bool(await (pl as Object).callv("load_pack_and_change_scene", [ "res://packs/levels.pck", "res://levels/Level1.tscn" ]))
	runner.assert_true(not ok, "PackLoader returns false for missing pack")
	pl.queue_free()
	await get_tree().process_frame


