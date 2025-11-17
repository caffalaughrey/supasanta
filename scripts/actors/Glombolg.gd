extends Node3D

@export var material_path: String = "res://materials/glombolg_pbr.tres"
@export var model_node_path: NodePath = NodePath("Model")
@export var hitbox_node_path: NodePath = NodePath("GlombolgBody/CollisionShape3D")
@export var hitbox_depth: float = 0.6
@export var min_hitbox_height: float = 1.8

func _ready() -> void:
	_apply_material()
	_fit_hitbox_to_model()

func _apply_material() -> void:
	# Skip if textures/material not yet imported in headless runs
	if not ResourceLoader.exists(material_path):
		return
	var mat := load(material_path)
	if mat == null:
		return
	var model_root := get_node_or_null(model_node_path) as Node
	if model_root == null:
		return
	var mesh_inst := _find_first_mesh_instance(model_root)
	if mesh_inst == null:
		return
	# Override all surfaces to our PBR for consistency
	var mesh := mesh_inst.mesh
	if mesh != null:
		for i in range(0, mesh.get_surface_count()):
			mesh_inst.set_surface_override_material(i, mat)
	else:
		mesh_inst.material_override = mat

func _fit_hitbox_to_model() -> void:
	var model_root := get_node_or_null(model_node_path) as Node
	var hit_cs := get_node_or_null(hitbox_node_path) as CollisionShape3D
	if model_root == null or hit_cs == null:
		return
	var mesh_inst := _find_first_mesh_instance(model_root)
	if mesh_inst == null:
		return
	var aabb := mesh_inst.get_aabb()
	var box := BoxShape3D.new()
	var size := aabb.size
	if size.y < min_hitbox_height:
		size.y = min_hitbox_height
	size.z = hitbox_depth
	box.size = size
	hit_cs.shape = box
	var center := aabb.position + aabb.size * 0.5
	center.z = 0.0
	hit_cs.transform.origin = center

func _find_first_mesh_instance(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root as MeshInstance3D
	for c in root.get_children():
		var found := _find_first_mesh_instance(c)
		if found != null:
			return found
	return null


