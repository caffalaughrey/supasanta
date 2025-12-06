tool
extends EditorScript

class_name AssetImportOptim

static func _desired_texture_params() -> Dictionary:
	return {
		"compress/mode": 2, # Lossy
		"compress/high_quality": false,
		"compress/lossy_quality": 0.7,
		"mipmaps/generate": true,
		"mipmaps/limit": -1,
		"process/size_limit": 2048, # cap to 2048; adjust as needed
	}

func _run() -> void:
	# Editor-only: walk textures and apply desired defaults, then reimport.
	var fs := EditorInterface.get_resource_filesystem()
	if fs == null:
		push_warning("Editor filesystem not available; run from editor.")
		return
	var changed := 0
	for dir_path in ["res://textures", "res://models"]:
		if not DirAccess.dir_exists_absolute(dir_path):
			continue
		changed += _process_dir(dir_path)
	print("AssetImportOptim: updated %d import files" % changed)

func _process_dir(path: String) -> int:
	var count := 0
	for file_name in DirAccess.get_files_at(path):
		if file_name.ends_with(".import"):
			continue
		if file_name.ends_with(".png") or file_name.ends_with(".jpg") or file_name.ends_with(".jpeg") or file_name.ends_with(".webp"):
			var res_path := path.plus_file(file_name)
			if _apply_texture_defaults(res_path):
				count += 1
	for child in DirAccess.get_directories_at(path):
		count += _process_dir(path.plus_file(child))
	return count

static func _apply_texture_defaults(res_path: String) -> bool:
	var import_path := ProjectSettings.globalize_path(res_path) + ".import"
	var cfg := ConfigFile.new()
	var err := cfg.load(import_path)
	if err != OK:
		return false
	var params := _desired_texture_params()
	var changed := false
	for k in params.keys():
		var section := "params"
		var old := cfg.get_value(section, k, null)
		var newv := params[k]
		if old != newv:
			cfg.set_value(section, k, newv)
			changed = true
	if changed:
		cfg.save(import_path)
		ResourceLoader.load(res_path) # trigger reimport
	return changed



