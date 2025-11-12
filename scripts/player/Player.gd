extends CharacterBody3D

@export var walk_speed: float = 4.0
@export var run_speed: float = 8.0
@export var jump_velocity: float = 7.5
@export var air_control: float = 0.6
@export var accel: float = 20.0
@export var anim_turn_time: float = 0.06

var gravity: float = 24.8
var z_plane: float = 0.0
var move_input: float = 0.0
var facing_left: bool = false
var _last_input_dir: int = 0  # -1 left, 0 none, 1 right
const YAW_RIGHT := PI * 0.5   # face +X (Godot forward is -Z)
const YAW_LEFT := -PI * 0.5   # face -X

var run_pressed_time: float = -1.0
const THROW_TAP_MAX: float = 0.20

var model_root: Node3D
var anim_player: AnimationPlayer
const BombScene: PackedScene = preload("res://scenes/Bomb.tscn")

@export var auto_align_on_ready: bool = false
@export var model_visual_offset_y: float = 0.6
var _align_frames_left: int = 0
var _align_process_frames_left: int = 0
var _align_done: bool = false

var anim_tree: AnimationTree
var sm_playback: AnimationNodeStateMachinePlayback
var was_on_floor: bool = true


func _ready() -> void:
	z_plane = global_position.z
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 24.8))
	_ensure_model_root_present()
	model_root = get_node_or_null("ModelRoot") as Node3D
	_try_instance_santa_model()
	anim_player = _find_animation_player()
	anim_tree = get_node_or_null("AnimationTree") as AnimationTree
	_build_animation_tree()
	if anim_tree != null:
		# Prefer the imported AnimationPlayer under the model for real clips
		if anim_player != null:
			anim_tree.anim_player = anim_player.get_path()
		sm_playback = anim_tree.get("parameters/playback")
		if sm_playback != null:
			sm_playback.travel("Idle")
	_play_if_exists("Idle")
	# Re-align over a couple physics frames to account for late GLB transforms/skins
	if auto_align_on_ready:
		_align_frames_left = 120
		_align_process_frames_left = 120
		_auto_align_model_to_feet()


func _physics_process(delta: float) -> void:
	if auto_align_on_ready and not _align_done:
		_align_frames_left -= 1
		_auto_align_model_to_feet()
	_process_input(delta)
	_apply_gravity(delta)
	_move_horizontal(delta)
	_apply_jump_actions()
	_apply_misc_actions()
	_constrain_to_plane()
	_update_facing(delta)
	_update_locomotion_state()
	move_and_slide()

func _process(delta: float) -> void:
	if auto_align_on_ready and not _align_done:
		_align_process_frames_left -= 1
		_auto_align_model_to_feet()


func _process_input(delta: float) -> void:
	var right_strength := Input.get_action_strength("move_right")
	var left_strength := Input.get_action_strength("move_left")
	move_input = clamp(right_strength - left_strength, -1.0, 1.0)
	# Enforce facing matches current input direction immediately
	var dir := 0
	if move_input > 0.1:
		dir = 1
	elif move_input < -0.1:
		dir = -1
	if dir != 0 and dir != _last_input_dir:
		_set_facing(dir < 0)
	_last_input_dir = dir

	# Track Y button tap vs hold
	if Input.is_action_just_pressed("run"):
		run_pressed_time = 0.0
	elif run_pressed_time >= 0.0:
		run_pressed_time += delta
	if Input.is_action_just_released("run"):
		if run_pressed_time >= 0.0 and run_pressed_time <= THROW_TAP_MAX and absf(move_input) < 0.2:
			_throw_bomb()
		run_pressed_time = -1.0


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta


func _is_running() -> bool:
	# Consider it "running" if Y is held and we are moving, or held longer than the tap window
	var holding := Input.is_action_pressed("run")
	return holding and (absf(move_input) > 0.1 or (run_pressed_time > THROW_TAP_MAX or run_pressed_time < 0.0))


func _move_horizontal(delta: float) -> void:
	var target_speed := (run_speed if _is_running() else walk_speed) * move_input
	var control := 1.0 if is_on_floor() else air_control
	var accel_used := accel * control
	velocity.x = move_toward(velocity.x, target_speed, accel_used * delta)


func _apply_jump_actions() -> void:
	# Spin jump overrides normal jump on same frame if both pressed
	if is_on_floor() and Input.is_action_just_pressed("spin_jump"):
		velocity.y = jump_velocity
		if sm_playback != null:
			sm_playback.travel("SpinJump")
		else:
			_play_if_exists("SpinJump")
	elif is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
		if sm_playback != null:
			sm_playback.travel("JumpStart")
		else:
			_play_if_exists("Jump")


func _apply_misc_actions() -> void:
	if Input.is_action_just_pressed("swing"):
		# Play upper-body swing without interrupting locomotion state if possible
		_play_upper_action("Swing")


func _throw_bomb() -> void:
	_play_if_exists("Throw")
	if BombScene == null:
		return
	var spawn: Marker3D = get_node_or_null("BombSpawn") as Marker3D
	var world: Node = get_tree().current_scene
	if world == null:
		return
	var bomb: Node = BombScene.instantiate()
	world.add_child(bomb)
	var spawn_pos := global_position
	if spawn != null:
		spawn_pos = spawn.global_position
	bomb.global_position = spawn_pos
	# Fire forward along X with slight upward arc
	var dir := Vector3.LEFT if facing_left else Vector3.RIGHT
	var throw_speed := 8.0
	var up := Vector3.UP * 3.5
	if bomb is RigidBody3D:
		(bomb as RigidBody3D).linear_velocity = dir * throw_speed + up


func _constrain_to_plane() -> void:
	if absf(global_position.z - z_plane) > 0.0001:
		global_position.z = z_plane


func _update_facing(delta: float) -> void:
	# Keep ensuring model orientation stays correct even if input is steady
	if move_input > 0.1 and facing_left:
		_set_facing(false)
	elif move_input < -0.1 and not facing_left:
		_set_facing(true)


func _rotate_model_smooth(left: bool, delta: float) -> void:
	if model_root == null:
		return
	# Face movement axis (sidescroller on X): left => -X (yaw +90), right => +X (yaw -90)
	var target_y := (YAW_LEFT if left else YAW_RIGHT)
	var current := model_root.rotation
	var new_y := lerp_angle(current.y, target_y, clamp(delta / anim_turn_time, 0.0, 1.0))
	current.y = new_y
	model_root.rotation = current

func _set_facing(left: bool) -> void:
	facing_left = left
	if model_root != null:
		var r := model_root.rotation
		# Snap to face along movement axis on X
		r.y = (YAW_LEFT if left else YAW_RIGHT)
		model_root.rotation = r


func _update_locmotion_anim() -> void:
	if anim_player == null:
		return
	if not is_on_floor():
		return # airborne handled when jump triggers
	var speed := absf(velocity.x)
	if speed < 0.1:
		_play_if_exists("Idle")
	elif _is_running():
		_play_if_exists("Run")
	else:
		_play_if_exists("Walk")

func _play_upper_action(action_name: String) -> void:
	if sm_playback != null:
		sm_playback.travel(action_name)
		return
	_play_if_exists(action_name)

func _build_animation_tree() -> void:
	if anim_tree == null:
		return
	# If already has Locomotion, skip
	var sm := AnimationNodeStateMachine.new()
	anim_tree.tree_root = sm
	_add_sm_anim(sm, "Idle", "Idle")
	_add_sm_anim(sm, "Walk", "Walk")
	_add_sm_anim(sm, "Run", "Run")
	_add_sm_anim(sm, "Turn", "Turn")
	_add_sm_anim(sm, "Skid", "Skid")
	_add_sm_anim(sm, "JumpStart", "JumpStart")
	_add_sm_anim(sm, "AirLoop", "AirLoop")
	_add_sm_anim(sm, "Land", "Land")
	_add_sm_anim(sm, "SpinJump", "SpinJump")
	_add_sm_anim(sm, "Swing", "Swing")
	_add_sm_anim(sm, "Throw", "Throw")
	# Basic transitions
	_add_tr(sm, "Idle", "Walk")
	_add_tr(sm, "Idle", "Run")
	_add_tr(sm, "Walk", "Idle")
	_add_tr(sm, "Run", "Idle")
	_add_tr(sm, "Walk", "Run")
	_add_tr(sm, "Run", "Walk")
	_add_tr(sm, "Walk", "Turn")
	_add_tr(sm, "Run", "Skid")
	_add_tr(sm, "Idle", "JumpStart")
	_add_tr(sm, "Walk", "JumpStart")
	_add_tr(sm, "Run", "JumpStart")
	_add_tr(sm, "JumpStart", "AirLoop")
	_add_tr(sm, "AirLoop", "Land")
	_add_tr(sm, "Land", "Idle")
	# Action transitions
	_add_tr(sm, "Idle", "Swing")
	_add_tr(sm, "Walk", "Swing")
	_add_tr(sm, "Run", "Swing")
	_add_tr(sm, "Idle", "Throw")
	_add_tr(sm, "Walk", "Throw")
	_add_tr(sm, "Run", "Throw")
	# Return transitions
	_add_tr(sm, "Turn", "Walk")
	_add_tr(sm, "Skid", "Run")
	_add_tr(sm, "Swing", "Idle")
	_add_tr(sm, "Throw", "Idle")
	# Start state will be set by initial travel in _ready()

func _add_sm_anim(sm: AnimationNodeStateMachine, state_name: String, clip_name: String) -> void:
	var node := AnimationNodeAnimation.new()
	node.animation = clip_name
	sm.add_node(state_name, node)

func _add_tr(sm: AnimationNodeStateMachine, from: String, to: String) -> void:
	var tr := AnimationNodeStateMachineTransition.new()
	tr.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	tr.xfade_time = 0.1
	sm.add_transition(from, to, tr)

func _update_locomotion_state() -> void:
	if anim_tree == null or sm_playback == null:
		return
	var on_floor := is_on_floor()
	var speed := absf(velocity.x)
	var running := _is_running()
	var current := sm_playback.get_current_node()
	# Jump/air
	if not on_floor:
		if current != "AirLoop" and current != "JumpStart":
			sm_playback.travel("AirLoop")
		return
	# Land detection
	if was_on_floor == false and on_floor == true:
		sm_playback.travel("Land")
	# Grounded actions
	if Input.is_action_just_pressed("swing"):
		sm_playback.travel("Swing")
		return
	# Locomotion
	if speed < 0.1:
		sm_playback.travel("Idle")
	elif running:
		sm_playback.travel("Run")
	else:
		sm_playback.travel("Walk")
	was_on_floor = on_floor


func _play_if_exists(anim_name: String) -> void:
	if anim_player == null:
		return
	if anim_player.has_animation(anim_name):
		if anim_player.current_animation != anim_name:
			anim_player.play(anim_name)


func _find_animation_player() -> AnimationPlayer:
	# Prefer an AnimationPlayer under the imported model; fallback to local one
	var local: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if local != null:
		return local
	if model_root != null:
		var found_node: Node = model_root.find_child("AnimationPlayer", true, false)
		if found_node is AnimationPlayer:
			return found_node as AnimationPlayer
	return null


func _try_instance_santa_model() -> void:
	if model_root == null:
		return
	# If user exports santa to res://models/santa/santa_rigged.glb, instance it
	var santa_path := "res://models/santa/santa_rigged.glb"
	if ResourceLoader.exists(santa_path):
		for c in model_root.get_children():
			model_root.remove_child(c)
			c.queue_free()
		var scene_res: Resource = load(santa_path)
		if scene_res and scene_res is PackedScene:
			var inst: Node3D = (scene_res as PackedScene).instantiate() as Node3D
			model_root.add_child(inst)
			# If the imported model scale is tiny, scale it up to be visible
			if inst:
				var sc := inst.scale
				var avg := (absf(sc.x) + absf(sc.y) + absf(sc.z)) / 3.0
				if avg < 0.1:
					inst.scale = inst.scale * 10.0
			# Apply manual visual offset if set
			if model_visual_offset_y != 0.0:
				model_root.position.y += model_visual_offset_y
			# Refresh anim player reference
			anim_player = _find_animation_player()
			_apply_dnn_materials(inst)
			_auto_align_model_to_feet()

func _apply_dnn_materials(root: Node) -> void:
	var mat_path := "res://materials/dnn_santa.tres"
	if not ResourceLoader.exists(mat_path):
		return
	var mat: Material = load(mat_path)
	if mat == null:
		return
	# Apply to all MeshInstance3D descendants
	var node_stack: Array[Node] = [root]
	while node_stack.size() > 0:
		var n: Node = node_stack.pop_back()
		for child in n.get_children():
			node_stack.append(child)
		if n is MeshInstance3D:
			var mi: MeshInstance3D = n as MeshInstance3D
			mi.material_override = mat

func _auto_align_model_to_feet() -> void:
	if model_root == null:
		return
	var platform_top := _compute_platform_top_y()
	var clearance := 0.02
	for i in range(3):
		# Prefer skeleton bone-based feet computation if available
		var feet_from_bones := _compute_feet_y_world_from_skeleton()
		var feet_world := feet_from_bones if feet_from_bones["found"] else _compute_min_y_world_under_model(true)
		if not feet_world["found"]:
			# last fallback: do not ignore any mesh
			feet_world = _compute_min_y_world_under_model(false)
		if not feet_world["found"]:
			return
		var delta: float = (feet_world["min_y"] - platform_top + clearance)
		# Clamp to avoid extreme jumps due to bad detection
		if delta > 1.0:
			delta = 1.0
		elif delta < -1.0:
			delta = -1.0
		if absf(delta) < 0.005:
			_align_done = true
			return
		var gp := model_root.global_transform
		gp.origin.y -= delta
		model_root.global_transform = gp

func _compute_min_y_world_under_model(ignore_tops: bool = true) -> Dictionary:
	if model_root == null:
		return { "found": false, "min_y": 0.0 }
	var min_y := INF
	var found := false
	var ignore_top_substrings := [
		"cap", "hat", "beard", "head", "hair", "moustache", "mustache"
	]
	var stack: Array[Node] = [model_root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D:
			if ignore_tops:
				var name_lc := n.name.to_lower()
				var skip := false
				for s in ignore_top_substrings:
					if name_lc.find(s) != -1:
						skip = true
						break
				if skip:
					continue
			var mi := n as MeshInstance3D
			var aabb := mi.get_aabb()
			var to_world := mi.global_transform
			for corner in _aabb_corners(aabb):
				var p: Vector3 = to_world * corner
				if p.y < min_y:
					min_y = p.y
					found = true
	return { "found": found, "min_y": min_y }

func _compute_platform_top_y() -> float:
	var world := get_parent()
	if world:
		var cs := world.get_node_or_null("Ground/CollisionShape3D") as CollisionShape3D
		if cs and cs.shape and cs.shape is BoxShape3D:
			var scale_y := cs.global_transform.basis.get_scale().y
			return cs.global_transform.origin.y + ((cs.shape as BoxShape3D).size.y * scale_y) * 0.5
	return 0.0

func _find_skeleton() -> Skeleton3D:
	if model_root == null:
		return null
	var sk := model_root.find_child("Skeleton3D", true, false)
	return sk if sk is Skeleton3D else null

func _compute_feet_y_world_from_skeleton() -> Dictionary:
	var sk := _find_skeleton()
	if sk == null:
		return { "found": false, "min_y": 0.0 }
	var foot_like := [
		"foot", "feet", "toe", "ankle", "shoe", "boot"
	]
	var min_y := INF
	var found := false
	for i in range(sk.get_bone_count()):
		var name_lc := sk.get_bone_name(i).to_lower()
		var is_match := false
		for s in foot_like:
			if name_lc.find(s) != -1:
				is_match = true
				break
		if not is_match:
			continue
		var xform := sk.get_bone_global_pose(i)
		var y := xform.origin.y
		if y < min_y:
			min_y = y
			found = true
	return { "found": found, "min_y": min_y }


func _ensure_model_root_present() -> void:
	if get_node_or_null("ModelRoot") != null:
		return
	var mr := Node3D.new()
	mr.name = "ModelRoot"
	# Insert before AnimationPlayer so visual is above by default
	add_child(mr)
	# Move any existing MeshInstance3D children under ModelRoot (future-proof)
	var to_move: Array[Node] = []
	for c in get_children():
		if c == mr:
			continue
		if c is MeshInstance3D:
			to_move.append(c)
	for n in to_move:
		remove_child(n)
		mr.add_child(n)

func _compute_min_y_under_model_root(root: Node, ignore_bases: bool = true) -> Dictionary:
	var min_y := INF
	var found := false
	var ignore_substrings := [
		"base", "stand", "shadow", "ground", "platform", "pedestal"
	]
	# DFS
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D:
			if ignore_bases:
				var name_lc := n.name.to_lower()
				var skip := false
				for s in ignore_substrings:
					if name_lc.find(s) != -1:
						skip = true
						break
				if skip:
					continue
			var mi := n as MeshInstance3D
			var aabb := mi.get_aabb()
			var to_model := model_root.global_transform.affine_inverse() * mi.global_transform
			for corner in _aabb_corners(aabb):
				var p: Vector3 = to_model * corner
				if p.y < min_y:
					min_y = p.y
					found = true
	return { "found": found, "min_y": min_y }


func _aabb_corners(aabb: AABB) -> Array:
	var pos := aabb.position
	var size := aabb.size
	var corners := []
	corners.append(Vector3(pos.x, pos.y, pos.z))
	corners.append(Vector3(pos.x + size.x, pos.y, pos.z))
	corners.append(Vector3(pos.x, pos.y + size.y, pos.z))
	corners.append(Vector3(pos.x, pos.y, pos.z + size.z))
	corners.append(Vector3(pos.x + size.x, pos.y + size.y, pos.z))
	corners.append(Vector3(pos.x + size.x, pos.y, pos.z + size.z))
	corners.append(Vector3(pos.x, pos.y + size.y, pos.z + size.z))
	corners.append(Vector3(pos.x + size.x, pos.y + size.y, pos.z + size.z))
	return corners
