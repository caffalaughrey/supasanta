extends Node

signal pack_loaded(path: String)
signal pack_failed(path: String)

func load_pack_and_change_scene(pack_path: String, scene_path: String) -> bool:
	await get_tree().process_frame
	var ok := ProjectSettings.load_resource_pack(pack_path)
	if ok:
		emit_signal("pack_loaded", pack_path)
		if ResourceLoader.exists(scene_path):
			get_tree().change_scene_to_file(scene_path)
		else:
			push_error("Scene not found after loading pack: %s" % scene_path)
	else:
		emit_signal("pack_failed", pack_path)
	return ok


