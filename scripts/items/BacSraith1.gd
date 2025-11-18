extends Node3D

@export var material: Material
@export var generate_collisions_on_ready: bool = true
@export var auto_align_on_ready: bool = true
@export var target_height: float = 3.0  # meters; reasonable rowhouse height for visibility

func _ready() -> void:
	if material != null:
		_apply_material_recursive(self, material)
	_normalize_model_scale_and_center()
	if generate_collisions_on_ready:
		_generate_static_collisions()
	if auto_align_on_ready:
		_auto_align_to_platform_top()

func _apply_material_recursive(root: Node, mat: Material) -> void:
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			mi.material_override = mat

func _generate_static_collisions() -> void:
	# Remove any existing collision container
	var prev: Node = get_node_or_null("Collision") as Node
	if prev != null:
		prev.queue_free()
		await get_tree().process_frame
	# Make a single StaticBody3D and attach shapes for each mesh surface
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Collision"
	add_child(body)
	# Iterate all MeshInstance3D descendants and build trimesh collision
	var node_stack: Array[Node] = [self]
	while node_stack.size() > 0:
		var n: Node = node_stack.pop_back()
		for c in n.get_children():
			node_stack.append(c)
		if n is MeshInstance3D:
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi.mesh == null:
				continue
			var shape: Shape3D = mi.mesh.create_trimesh_shape()
			if shape == null:
				continue
			var cs: CollisionShape3D = CollisionShape3D.new()
			cs.shape = shape
			# Place the collision shape at the same transform as the mesh, relative to the collision body
			cs.transform = body.global_transform.affine_inverse() * mi.global_transform
			body.add_child(cs)

func _auto_align_to_platform_top() -> void:
	# Align this node so that the lowest mesh point sits just above the platform top (y=platform_top + clearance)
	var platform_top: float = _compute_platform_top_y()
	var feet: Dictionary = _compute_min_y_world_under_node(self)
	if not feet["found"]:
		return
	var clearance: float = 0.02
	var delta: float = (feet["min_y"] - platform_top + clearance)
	# Clamp absurd offsets to avoid jolts if detection fails
	if delta > 2.0:
		delta = 2.0
	elif delta < -2.0:
		delta = -2.0
	if absf(delta) < 0.0005:
		return
	var gt: Transform3D = global_transform
	gt.origin.y -= delta
	global_transform = gt

func _compute_platform_top_y() -> float:
	# Mirrors Player.gd approach: find Ground/CollisionShape3D with BoxShape3D
	var world: Node = get_parent()
	if world:
		var cs: CollisionShape3D = world.get_node_or_null("Ground/CollisionShape3D") as CollisionShape3D
		if cs and cs.shape and cs.shape is BoxShape3D:
			var scale_y: float = cs.global_transform.basis.get_scale().y
			return cs.global_transform.origin.y + ((cs.shape as BoxShape3D).size.y * scale_y) * 0.5
	return 0.0

func _compute_min_y_world_under_node(root: Node) -> Dictionary:
	var min_y: float = INF
	var found: bool = false
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D:
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi.mesh == null:
				continue
			var aabb: AABB = mi.get_aabb()
			var to_world: Transform3D = mi.global_transform
			for corner in _aabb_corners(aabb):
				var p: Vector3 = to_world * (corner as Vector3)
				if p.y < min_y:
					min_y = p.y
					found = true
	return { "found": found, "min_y": min_y }

func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	var pos: Vector3 = aabb.position
	var size: Vector3 = aabb.size
	var corners: Array[Vector3] = []
	corners.append(Vector3(pos.x, pos.y, pos.z))
	corners.append(Vector3(pos.x + size.x, pos.y, pos.z))
	corners.append(Vector3(pos.x, pos.y + size.y, pos.z))
	corners.append(Vector3(pos.x, pos.y, pos.z + size.z))
	corners.append(Vector3(pos.x + size.x, pos.y + size.y, pos.z))
	corners.append(Vector3(pos.x + size.x, pos.y, pos.z + size.z))
	corners.append(Vector3(pos.x, pos.y + size.y, pos.z + size.z))
	corners.append(Vector3(pos.x + size.x, pos.y + size.y, pos.z + size.z))
	return corners

func _normalize_model_scale_and_center() -> void:
	# Find the GLB instance node (named 'Model' in our scenes)
	var model: Node3D = get_node_or_null("Model") as Node3D
	if model == null:
		# Fallback: first Node3D child
		for c in get_children():
			if c is Node3D:
				model = (c as Node3D)
				break
	if model == null:
		return
	# Compute combined AABB in model-local space
	var bounds: Dictionary = _compute_combined_aabb_local(model)
	if not bounds["found"]:
		return
	# Center horizontally (X,Z) by moving the model so its local center sits at origin
	var aabb: AABB = (bounds["aabb"] as AABB)
	var center_local: Vector3 = aabb.position + aabb.size * 0.5
	var pos: Vector3 = model.position
	pos.x -= center_local.x
	pos.z -= center_local.z
	model.position = pos
	# Scale uniformly so height approximates target_height (avoid extreme factors)
	var h: float = max(0.0001, aabb.size.y)
	var scale_factor: float = clamp(target_height / h, 0.05, 20.0)
	if absf(scale_factor - 1.0) > 0.001:
		model.scale = model.scale * scale_factor

func _compute_combined_aabb_local(root: Node3D) -> Dictionary:
	var have: bool = false
	var combined: AABB = AABB(Vector3.ZERO, Vector3.ZERO)
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D:
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi.mesh == null:
				continue
			# Transform the mesh's local AABB into the root's local space
			var aabb: AABB = mi.get_aabb()
			var to_root: Transform3D = root.global_transform.affine_inverse() * mi.global_transform
			var corners: Array[Vector3] = _aabb_corners(aabb)
			for corner in corners:
				var p: Vector3 = to_root * (corner as Vector3)
				if not have:
					combined.position = p
					combined.size = Vector3.ZERO
					have = true
				else:
					combined = combined.expand(p)
	return { "found": have, "aabb": combined }
