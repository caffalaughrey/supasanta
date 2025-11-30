extends Node3D

@export var parallax: float = 0.15
@export var align_y: float = -12.0
@export var depth_z: float = -140.0
@export var material_override_path: NodePath

var _camera: Camera3D
var _tile_nodes: Array[Node3D] = []
var _tile_width: float = 0.0

func _ready() -> void:
	_camera = get_viewport().get_camera_3d()
	position.y = align_y
	position.z = depth_z
	# Find a mesh node inside this instance to tile
	var src: Node3D = _find_mesh_node(self)
	if src == null:
		return
	# Compute world width of one tile
	_tile_width = _compute_world_width(src)
	# Prepare three tiles: left, center, right
	_tile_nodes = [src]
	var left := src.duplicate() as Node3D
	var right := src.duplicate() as Node3D
	add_child(left)
	add_child(right)
	_tile_nodes.push_front(left)
	_tile_nodes.push_back(right)
	# Apply material override to each tile if provided path points to a material on this scene
	var mat_owner := self
	var mat := _try_get_material_override()
	if mat:
		for n in _tile_nodes:
			_apply_material_override(n, mat)
	# Initial layout
	_update_tiles()

func _process(_delta: float) -> void:
	if _camera == null:
		_camera = get_viewport().get_camera_3d()
		if _camera == null:
			return
	_update_tiles()

func _update_tiles() -> void:
	if _tile_width <= 0.0 or _camera == null:
		return
	var camx := _camera.global_position.x * parallax
	var base: float = floor(camx / _tile_width)
	# Arrange tiles centered around camera parallax position
	_tile_nodes[0].position.x = (base - 1.0) * _tile_width
	_tile_nodes[1].position.x = (base + 0.0) * _tile_width
	_tile_nodes[2].position.x = (base + 1.0) * _tile_width

func _find_mesh_node(root: Node) -> Node3D:
	if root is MeshInstance3D:
		return root
	for c in root.get_children():
		var found := _find_mesh_node(c)
		if found:
			return found
	return null

func _compute_world_width(n: Node3D) -> float:
	var mesh_aabb: Vector3 = Vector3.ZERO
	if n is MeshInstance3D:
		var aabb: AABB = (n as MeshInstance3D).get_aabb()
		mesh_aabb = aabb.size
	var scale: Vector3 = n.global_transform.basis.get_scale()
	return mesh_aabb.x * absf(scale.x)

func _try_get_material_override() -> Material:
	# For simplicity, return null; instance-level overrides are applied in scene.
	return null

func _apply_material_override(node: Node3D, mat: Material) -> void:
	if node is MeshInstance3D:
		node.set_surface_override_material(0, mat)
	for c in node.get_children():
		if c is Node3D:
			_apply_material_override(c, mat)


