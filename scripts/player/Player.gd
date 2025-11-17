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
@export var require_input_to_enable_movement: bool = false
@export var use_animation_tree: bool = false
@export var idle_face_delay_s: float = 0.4
@export var land_hold_s: float = 0.12
@export var jumpstart_hold_s: float = 0.12
@export var spinjump_hold_s: float = 0.25
@export var swing_hold_s: float = 0.25
@export var throw_hold_s: float = 0.18
@export var turn_hold_s: float = 0.12
@export var spin_yaw_deg_per_sec: float = 360.0
@export var use_procedural_gait: bool = false
@export var walk_gait_hz: float = 1.8
@export var run_gait_hz: float = 3.0
@export var gait_thigh_swing_deg: float = 14.0
@export var gait_shin_swing_deg: float = 10.0
@export var gait_foot_pitch_deg: float = 5.0
@export var gait_invert_left_foot_pitch: bool = true
@export var gait_left_foot_scale: float = 0.75
@export var gait_enable_feet: bool = false
@export var gait_enable_toe_roll: bool = false
@export var gait_toe_roll_deg: float = 10.0
@export var use_boot_rigidity: bool = false
@export var boot_rigidity_strength: float = 1.0
@export var boot_pitch_stance_deg: float = 4.0
@export var boot_pitch_swing_deg: float = -6.0
@export var boot_lock_ankle: bool = true
@export var boot_lock_local: bool = false
@export var enable_boot_volume_compensation: bool = false
@export var boot_volume_scale_walk: float = 1.08
@export var boot_volume_scale_run: float = 1.12
var _align_frames_left: int = 0
var _align_process_frames_left: int = 0
var _align_done: bool = false

var anim_tree: AnimationTree
var sm_playback: AnimationNodeStateMachinePlayback
var was_on_floor: bool = true
var debug_lock_state: bool = false
var controls_enabled: bool = false
var _neutral_frames: int = 0
const _NEUTRAL_FRAMES_REQUIRED := 10
var debug_freeze_motion: bool = false
var _debug_prev_tree_active: bool = false
var clip_hold_timer: float = 0.0
var idle_time_s: float = 0.0
var current_air_clip: String = ""
var spin_active: bool = false
var gait_time: float = 0.0
var _bone_cache_ready: bool = false
var _bone_thigh_L: int = -1
var _bone_thigh_R: int = -1
var _bone_shin_L: int = -1
var _bone_shin_R: int = -1
var _bone_foot_L: int = -1
var _bone_foot_R: int = -1
var _bone_toe_L: int = -1
var _bone_toe_R: int = -1
@export var foot_debug_enabled: bool = true
var _foot_debug_frames: int = 180
var _boot_status_logged: bool = false
const SM_STATES := [
	"Idle","Walk","Run","Turn","Skid",
	"JumpStart","AirLoop","Land","SpinJump","Swing","Throw"
]


func _ready() -> void:
	z_plane = global_position.z
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 24.8))
	_ensure_model_root_present()
	model_root = get_node_or_null("ModelRoot") as Node3D
	_try_instance_santa_model()
	anim_player = _find_animation_player()
	if anim_player != null:
		# Ensure tracks resolve relative to the GLB root under ModelRoot
		if model_root != null:
			var glb_root := _find_glb_root()
			if glb_root != null:
				anim_player.root_node = glb_root.get_path()
			else:
				anim_player.root_node = model_root.get_path()
		print("[ANIM] AnimationPlayer root_node=", anim_player.root_node)
		var names := anim_player.get_animation_list()
		print("[ANIM] Available clips: ", names)
		# Ensure intended loops actually loop at runtime
		_ensure_anim_loops(["Idle","Walk","Run","AirLoop","SpinJump"])
		# Diagnostic: dump a few track paths so we can verify upper-body tracks are present
		if anim_player.has_animation("Walk"):
			var a_walk: Animation = anim_player.get_animation("Walk")
			var sample: int = int(min(12, a_walk.get_track_count()))
			print("[ANIM] Walk track sample (", sample, "):")
			for i in range(sample):
				print("   - ", a_walk.track_get_path(i))
		if anim_player.has_animation("Run"):
			var a_run: Animation = anim_player.get_animation("Run")
			var sample_r: int = int(min(12, a_run.get_track_count()))
			print("[ANIM] Run track sample (", sample_r, "):")
			for i in range(sample_r):
				print("   - ", a_run.track_get_path(i))
	anim_tree = get_node_or_null("AnimationTree") as AnimationTree
	_build_animation_tree()
	if anim_tree != null:
		# Prefer the imported AnimationPlayer under the model for real clips
		if anim_player != null:
			anim_tree.anim_player = anim_player.get_path()
		# Ensure the AnimationTree actually runs
		anim_tree.active = use_animation_tree
		sm_playback = anim_tree.get("parameters/playback")
		if use_animation_tree and sm_playback != null:
			sm_playback.travel("Idle")
	_play_if_exists("Idle")
	# Log skeleton/skin presence
	var sk := _find_skeleton()
	if sk != null:
		print("[ANIM] Skeleton bones=", sk.get_bone_count())
		_log_skin_joints(sk)
	else:
		print("[ANIM] No Skeleton3D found under ModelRoot")
	# Check skinned meshes
	if model_root:
		var stack: Array[Node] = [model_root]
		while stack.size() > 0:
			var n: Node = stack.pop_back()
			for ch in n.get_children():
				stack.append(ch)
			if n is MeshInstance3D:
				var mi := n as MeshInstance3D
				var resolves := false
				if String(mi.skeleton) != "":
					var node := n.get_node_or_null(mi.skeleton)
					resolves = node is Skeleton3D
				print("[ANIM] Mesh ", mi.name, " skin=", mi.skin, " skeleton=", mi.skeleton, " resolves_to_skeleton=", resolves)
	# Re-align over a couple physics frames to account for late GLB transforms/skins
	if auto_align_on_ready:
		_align_frames_left = 120
		_align_process_frames_left = 120
		_auto_align_model_to_feet()


func _physics_process(delta: float) -> void:
	# If debug overlay is not active, ensure any lingering debug locks are cleared
	if not _animdebug_enabled() and (debug_lock_state or debug_freeze_motion):
		debug_clear()
	if auto_align_on_ready and not _align_done:
		_align_frames_left -= 1
		_auto_align_model_to_feet()
	# countdown for temporary clip holds (e.g., Land, SpinJump, JumpStart)
	if clip_hold_timer > 0.0:
		clip_hold_timer = max(0.0, clip_hold_timer - delta)
	_process_input(delta)
	_apply_gravity(delta)
	# Freeze horizontal movement when debugging animations
	if debug_freeze_motion:
		move_input = 0.0
		velocity.x = 0.0
	else:
		_move_horizontal(delta)
	_apply_jump_actions()
	_apply_misc_actions()
	_constrain_to_plane()
	_update_facing(delta)
	# Apply continuous horizontal spin while airborne in SpinJump
	if spin_active and not is_on_floor() and model_root != null:
		var dir := (1.0 if facing_left else -1.0) # choose a consistent spin direction
		var r := model_root.rotation
		r.y += deg_to_rad(spin_yaw_deg_per_sec) * dir * delta
		model_root.rotation = r
	# Foot diagnostics snapshot for first few seconds
	if foot_debug_enabled and _foot_debug_frames > 0:
		if (_foot_debug_frames % 15) == 0:
			_debug_feet_snapshot()
		_foot_debug_frames -= 1
	# Track idle dwell time (used to face camera while idle)
	if is_on_floor() and absf(velocity.x) < 0.1:
		idle_time_s += delta
	else:
		idle_time_s = 0.0
	# Drive via AnimationTree when enabled; otherwise use direct clips for visibility
	if use_animation_tree and anim_tree != null and sm_playback != null:
		if not _boot_status_logged:
			print("[ANIM] Using AnimationTree path (SM). sm_playback ok")
			_boot_status_logged = true
		_update_locomotion_state()
	else:
		if not _boot_status_logged:
			print("[ANIM] Using direct AnimationPlayer path. use_animation_tree=", use_animation_tree, " anim_tree=", anim_tree, " sm=", sm_playback)
			_boot_status_logged = true
		_update_locmotion_anim()
	move_and_slide()

func _process(delta: float) -> void:
	if auto_align_on_ready and not _align_done:
		_align_process_frames_left -= 1
		_auto_align_model_to_feet()
	# Apply subtle procedural gait overlay after animations update
	if not _animdebug_enabled():
		_apply_procedural_gait(delta)


func _process_input(delta: float) -> void:
	# Read combined axis from actions and apply deadzone
	var axis := Input.get_axis("move_left", "move_right")
	if absf(axis) < 0.35:
		axis = 0.0
	# Track neutral frames
	if absf(axis) < 0.2:
		_neutral_frames += 1
	else:
		_neutral_frames = 0
	# Gate controls until neutral observed and a deliberate press occurs
	if require_input_to_enable_movement and not controls_enabled:
		var deliberate_press := Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("run") or Input.is_action_just_pressed("swing") or Input.is_action_just_pressed("spin_jump")
		if _neutral_frames >= _NEUTRAL_FRAMES_REQUIRED and deliberate_press:
			controls_enabled = true
	move_input = (clamp(axis, -1.0, 1.0) if (controls_enabled or not require_input_to_enable_movement) else 0.0)
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
	# Drift guard: if input is zero and velocity is almost zero, snap to zero
	if move_input == 0.0 and absf(velocity.x) < 0.01:
		velocity.x = 0.0
	# When controls are not yet enabled, hard clamp velocity to zero
	if require_input_to_enable_movement and not controls_enabled:
		velocity.x = 0.0


func _apply_jump_actions() -> void:
	# Spin jump overrides normal jump on same frame if both pressed
	if is_on_floor() and Input.is_action_just_pressed("spin_jump"):
		print("[INPUT] spin_jump pressed")
		velocity.y = jump_velocity
		# Use procedural yaw spin + AirLoop, avoid cartwheel from SpinJump clip
		if sm_playback != null:
			_sm_travel_with_mirror("JumpStart")
			clip_hold_timer = max(jumpstart_hold_s, 0.0)
		current_air_clip = "AirLoop"
		spin_active = true
		# Hold JumpStart briefly for anticipation, then AirLoop while spinning
		_play_clip_with_hold("JumpStart", jumpstart_hold_s)
	elif is_on_floor() and Input.is_action_just_pressed("jump"):
		print("[INPUT] jump pressed")
		velocity.y = jump_velocity
		if sm_playback != null:
			_sm_travel_with_mirror("JumpStart")
			clip_hold_timer = max(jumpstart_hold_s, 0.0)
		# Our GLB provides JumpStart, not Jump
		current_air_clip = "AirLoop"
		_play_clip_with_hold("JumpStart", jumpstart_hold_s)


func _apply_misc_actions() -> void:
	if Input.is_action_just_pressed("swing"):
		print("[INPUT] swing pressed")
		# Play upper-body swing without interrupting locomotion state if possible
		if use_animation_tree and sm_playback != null:
			_play_upper_action("Swing")
		else:
			# Without layers, briefly hold Swing so it reads
			_play_clip_with_hold("Swing", 0.25)


func _throw_bomb() -> void:
	# Trigger Throw visually regardless of path
	if sm_playback != null and use_animation_tree:
		_sm_travel_with_mirror("Throw")
		clip_hold_timer = max(throw_hold_s, 0.0)
	else:
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
	# During debug-locked poses (e.g., head twist), don't rotate the body
	if debug_lock_state:
		return
	# During SpinJump airborne, preserve procedural spin orientation
	if spin_active and not is_on_floor():
		return
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
	# Nudge a Turn animation when we flip facing while moving on ground
	if is_on_floor() and absf(velocity.x) > 0.1:
		if sm_playback != null:
			print("[ANIM] TRAVEL Turn (SM)")
			_sm_travel_with_mirror("Turn")
			clip_hold_timer = max(turn_hold_s, 0.0)
		else:
			print("[ANIM] PLAY Turn (direct)")
			_play_if_exists("Turn")


func _update_locmotion_anim() -> void:
	if anim_player == null:
		return
	# When AnimDebug is active (F1), don't override the previewed clip
	if _animdebug_enabled():
		return
	var on_floor := is_on_floor()
	var speed := absf(velocity.x)
	# Respect short holds for featured clips so blends don't mask them
	if clip_hold_timer > 0.0:
		was_on_floor = on_floor
		return
	# Airborne: loop in-air clip until landing
	if not on_floor:
		# After any start/hold, continue a designated air clip (SpinJump or AirLoop)
		if clip_hold_timer <= 0.0:
			if current_air_clip == "":
				current_air_clip = "AirLoop"
			if anim_player.current_animation != current_air_clip:
				print("[ANIM] PLAY ", current_air_clip, " (air)")
				_play_if_exists(current_air_clip)
		was_on_floor = false
		return
	# Land detection
	if was_on_floor == false and on_floor == true:
		print("[ANIM] PLAY Land (hold=", land_hold_s, ")")
		_play_clip_with_hold("Land", land_hold_s)
		was_on_floor = true
		current_air_clip = ""
		spin_active = false
		_snap_facing_to_input()
		return
	# Skid when reversing or coasting fast after releasing input while running
	if _is_running():
		var reversing := (absf(move_input) > 0.1 and signf(move_input) != signf(velocity.x))
		var coasting_fast := (absf(move_input) < 0.1 and speed > run_speed * 0.5)
		if reversing or coasting_fast:
			print("[ANIM] PLAY Skid")
			_play_if_exists("Skid")
			return
	if speed < 0.1:
		if anim_player.current_animation != "Idle":
			print("[ANIM] PLAY Idle")
		_play_if_exists("Idle")
		# Face camera after a small dwell to avoid fidget snap
		if idle_time_s >= idle_face_delay_s:
			_face_camera_when_idle()
	elif _is_running():
		if anim_player.current_animation != "Run":
			print("[ANIM] PLAY Run")
		_play_if_exists("Run")
	else:
		if anim_player.current_animation != "Walk":
			print("[ANIM] PLAY Walk")
		_play_if_exists("Walk")
	# Optional small speed scaling parity with SM path
	if anim_player:
		if speed < 0.1:
			anim_player.speed_scale = 1.0
		elif _is_running():
			anim_player.speed_scale = 1.2
		else:
			anim_player.speed_scale = 1.0

func _play_clip_with_hold(anim_name: String, hold_s: float) -> void:
	if anim_player == null:
		return
	if anim_player.has_animation(anim_name):
		anim_player.play(anim_name)
		clip_hold_timer = max(hold_s, 0.0)

func _ensure_anim_loops(names: Array) -> void:
	if anim_player == null:
		return
	for n in names:
		if anim_player.has_animation(n):
			var a := anim_player.get_animation(n)
			# 1 = LOOP_LINEAR in Godot 4
			if a != null and a.loop_mode != 1:
				a.loop_mode = 1

func _play_upper_action(action_name: String) -> void:
	if sm_playback != null:
		_sm_travel_with_mirror(action_name)
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
	if debug_lock_state:
		return
	# Respect temporary holds so featured clips read clearly
	if clip_hold_timer > 0.0:
		was_on_floor = is_on_floor()
		return
	var on_floor := is_on_floor()
	var speed := absf(velocity.x)
	var running := _is_running()
	var current := sm_playback.get_current_node()
	# Jump/air
	if not on_floor:
		if current != "AirLoop" and current != "JumpStart":
			_sm_travel_with_mirror("AirLoop")
		return
	# Land detection
	if was_on_floor == false and on_floor == true:
		_sm_travel_with_mirror("Land")
		clip_hold_timer = max(land_hold_s, 0.0)
	# Grounded actions
	if Input.is_action_just_pressed("swing"):
		_sm_travel_with_mirror("Swing")
		clip_hold_timer = max(swing_hold_s, 0.0)
		return
	# Skid when reversing or coasting fast after releasing input while running
	if running and on_floor:
		var reversing := (absf(move_input) > 0.1 and signf(move_input) != signf(velocity.x))
		var coasting_fast := (absf(move_input) < 0.1 and speed > run_speed * 0.5)
		if reversing or coasting_fast:
			print("[ANIM] TRAVEL Skid (SM) reversing=", reversing, " coasting_fast=", coasting_fast, " speed=", speed)
			_sm_travel_with_mirror("Skid")
			was_on_floor = on_floor
			return
	# Locomotion
	if speed < 0.1:
		_sm_travel_with_mirror("Idle")
		if anim_player: anim_player.speed_scale = 1.0
		_face_camera_when_idle()
	elif running:
		_sm_travel_with_mirror("Run")
		if anim_player: anim_player.speed_scale = 1.2
	else:
		_sm_travel_with_mirror("Walk")
		if anim_player: anim_player.speed_scale = 1.0
	was_on_floor = on_floor
 
func _face_camera_when_idle() -> void:
	if model_root == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	# Compute horizontal direction from model to camera and face it
	var to_cam := cam.global_transform.origin - model_root.global_transform.origin
	to_cam.y = 0.0
	if to_cam.length() < 0.001:
		return
	to_cam = to_cam.normalized()
	# Godot forward is -Z; yaw to face a world-space direction d = atan2(d.x, -d.z)
	# Add PI because our base facing convention is rotated relative to camera
	var target_yaw := atan2(to_cam.x, -to_cam.z) + PI
	var r := model_root.rotation
	r.y = lerp_angle(r.y, target_yaw, 0.25)
	model_root.rotation = r

# Returns true when the AnimDebug overlay is enabled (F1)
func _animdebug_enabled() -> bool:
	var root := get_tree().root
	if root == null:
		return false
	var dbg := root.get_node_or_null("AnimDebug")
	if dbg == null:
		return false
	var v = dbg.get("enabled")
	return (typeof(v) == TYPE_BOOL and v)

func _snap_facing_to_input() -> void:
	# On landing, snap the character’s facing to current input (or velocity fallback)
	var dir := 0
	if absf(move_input) > 0.1:
		dir = (-1 if move_input < 0.0 else 1)
	elif absf(velocity.x) > 0.1:
		dir = (-1 if velocity.x < 0.0 else 1)
	if dir != 0:
		_set_facing(dir < 0)

func _sm_travel_with_mirror(clip_name: String) -> void:
	# Drive the SM and also mirror the same clip on the AnimationPlayer for visibility
	if sm_playback != null:
		sm_playback.travel(clip_name)
	if anim_player != null and anim_player.has_animation(clip_name):
		anim_player.play(clip_name)

# Face camera immediately without interpolation (for debug previews)
func _face_camera_now() -> void:
	if model_root == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var to_cam := cam.global_transform.origin - model_root.global_transform.origin
	to_cam.y = 0.0
	if to_cam.length() < 0.001:
		return
	to_cam = to_cam.normalized()
	var target_yaw := atan2(to_cam.x, -to_cam.z) + PI
	var r := model_root.rotation
	r.y = target_yaw
	model_root.rotation = r

# Debug APIs (called by AnimDebug)
func debug_travel(state_name: String) -> void:
	# For debug preview, prefer raw clip playback for maximum visibility
	# Disable AnimationTree during preview to avoid blends masking motion
	_debug_prev_tree_active = (anim_tree.active if anim_tree else false)
	if anim_tree:
		anim_tree.active = false
	if anim_player != null and anim_player.has_animation(state_name):
		anim_player.play(state_name)
		print("[ANIM] debug_travel via AnimationPlayer -> ", state_name)
	elif sm_playback != null and SM_STATES.has(state_name):
		# Fallback to state machine if no direct clip found
		if anim_tree:
			anim_tree.active = true
		if anim_player:
			anim_player.stop()
		sm_playback.travel(state_name)
		print("[ANIM] debug_travel via StateMachine (fallback) -> ", state_name)
	if anim_player != null:
		print("[ANIM] current_animation=", anim_player.current_animation, " playing=", anim_player.is_playing(), " tree_active=", (anim_tree.active if anim_tree else false))
	# Face the active camera immediately for a head-on preview
	_face_camera_now()
	debug_lock_state = true
	debug_freeze_motion = true

func debug_log_anim_paths(anim_name: String) -> void:
	if anim_player == null or not anim_player.has_animation(anim_name):
		print("[ANIM] No anim or player for ", anim_name)
		return
	var a := anim_player.get_animation(anim_name)
	for i in range(a.get_track_count()):
		var path := a.track_get_path(i)
		var ttype := a.track_get_type(i)
		print("[ANIM] track#", i, " type=", ttype, " path=", path)

func debug_nod_head() -> void:
	var sk := _find_skeleton()
	if sk == null:
		print("[ANIM] No skeleton for debug nod")
		return
	# Pick a spine/head-like bone
	var pick := -1
	for i in range(sk.get_bone_count()):
		var n := sk.get_bone_name(i).to_lower()
		if n.find("spine") != -1 or n.find("head") != -1:
			pick = i
	# fallback to last
	if pick == -1:
		pick = sk.get_bone_count() - 1
	var pose := sk.get_bone_global_pose(pick)
	print("[ANIM] NOD on bone ", sk.get_bone_name(pick))
	var rot := pose.basis.get_euler()
	rot.x += 0.35
	pose.basis = Basis.from_euler(rot)
	sk.set_bone_global_pose_override(pick, pose, 1.0, true)
	# schedule revert
	var revert := func():
		sk.set_bone_global_pose_override(pick, Transform3D(), 0.0, true)
	await get_tree().process_frame
	# small delay
	for i in range(0, 10):
		await get_tree().process_frame
	revert.call()

func debug_clear() -> void:
	debug_lock_state = false
	debug_freeze_motion = false
	# Restore AnimationTree active state and stop direct clip overrides
	if anim_player:
		anim_player.stop()
	if anim_tree:
		anim_tree.active = _debug_prev_tree_active

func debug_twist_pose() -> void:
	var sk := _find_skeleton()
	if sk == null:
		return
	# Lock state so locomotion/facing don't update
	debug_lock_state = true
	# Temporarily pause animation playback so only the head rotates
	var prev_tree_active := false
	if anim_tree:
		prev_tree_active = anim_tree.active
		anim_tree.active = false
	debug_freeze_motion = true
	# Choose a safe head-like deform bone to preview without destabilizing the chain
	var head_idx := _pick_head_like_bone(sk)
	if head_idx == -1:
		print("[ANIM] No head-like bone for twist test")
		if anim_tree:
			anim_tree.active = prev_tree_active
		debug_freeze_motion = false
		debug_lock_state = false
		return
	var head_name := sk.get_bone_name(head_idx)
	# Apply a small yaw (around local Y) via global pose override; avoid compounding
	var pose := sk.get_bone_global_pose(head_idx)
	var e := pose.basis.get_euler()
	e.y += 0.30
	pose.basis = Basis.from_euler(e)
	sk.set_bone_global_pose_override(head_idx, pose, 0.85, true)
	print("[ANIM] Applied head twist on ", head_name)
	# Auto-reset
	await get_tree().create_timer(0.8).timeout
	# Clear the override (reset weight to 0), ensures a crisp snap-back
	sk.set_bone_global_pose_override(head_idx, Transform3D(), 0.0, true)
	print("[ANIM] Reset head twist")
	# Restore animation playback and unfreeze motion
	if anim_tree:
		anim_tree.active = prev_tree_active
	debug_freeze_motion = false
	debug_lock_state = false

func _pick_head_like_bone(sk: Skeleton3D) -> int:
	var exclude := ["ik_", "pole", "target", "gimbal", "neutral"]
	var prefer := ["head", "face", "skull", "neck", "spine.006", "spine.005", "spine.004"]
	# Pass 1: direct matches
	for p in prefer:
		for i in range(sk.get_bone_count()):
			var n := sk.get_bone_name(i).to_lower()
			var bad := false
			for ex in exclude:
				if n.find(ex) != -1:
					bad = true
					break
			if bad:
				continue
			if n == p:
				return i
	# Pass 2: substring contains
	for p in prefer:
		for i in range(sk.get_bone_count()):
			var n := sk.get_bone_name(i).to_lower()
			var bad := false
			for ex in exclude:
				if n.find(ex) != -1:
					bad = true
					break
			if bad:
				continue
			if n.find(p) != -1:
				return i
	# Fallback: last spine-like
	var last_spine := -1
	for i in range(sk.get_bone_count()):
		var n := sk.get_bone_name(i).to_lower()
		if n.begins_with("spine"):
			last_spine = i
	return last_spine

func debug_play_candidates(names: Array) -> void:
	if anim_player == null:
		print("[ANIM] No AnimationPlayer for candidates")
		return
	for n in names:
		if anim_player.has_animation(n):
			anim_player.play(n)
			debug_lock_state = true
			debug_freeze_motion = true
			print("[ANIM] Played candidate clip -> ", n)
			return
	print("[ANIM] No candidate clips found in AnimationPlayer: ", names)
	# Fallback to a visible head nod if special clips are absent
	if has_method("debug_nod_head"):
		debug_nod_head()

func _reset_pose_for_bones(names: Array) -> void:
	var sk := _find_skeleton()
	if sk == null:
		return
	for bn in names:
		var idx := sk.find_bone(bn)
		if idx == -1:
			continue
		if sk.has_method("reset_bone_pose"):
			sk.reset_bone_pose(idx)
		else:
			sk.set_bone_pose_rotation(idx, Quaternion())
			if sk.has_method("set_bone_pose_position"):
				sk.set_bone_pose_position(idx, Vector3.ZERO)
			if sk.has_method("set_bone_pose_scale"):
				sk.set_bone_pose_scale(idx, Vector3.ONE)

func _play_if_exists(anim_name: String) -> void:
	if anim_player == null:
		return
	if anim_player.has_animation(anim_name):
		if anim_player.current_animation != anim_name:
			anim_player.play(anim_name)

func debug_enable_controls() -> void:
	controls_enabled = true


func _find_animation_player() -> AnimationPlayer:
	# Prefer an AnimationPlayer under the imported model; fallback to local one
	if model_root != null:
		var found_node: Node = model_root.find_child("AnimationPlayer", true, false)
		if found_node is AnimationPlayer:
			return found_node as AnimationPlayer
	var local: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if local != null:
		return local
	return null

func _find_glb_root() -> Node:
	if model_root == null:
		return null
	# Prefer a known GLB root name if present
	var named := model_root.get_node_or_null("santa_rigged")
	if named != null:
		return named
	# Otherwise take the first Node3D child under ModelRoot
	for c in model_root.get_children():
		if c is Node3D:
			return c
	return null


func _try_instance_santa_model() -> void:
	if model_root == null:
		return
	# If user exports santa to res://models/santa/santa_rigged.glb, instance it
	# Temporarily load the last known-good rig (pre foot fixes) to restore full upper-body tracks
	var santa_path := "res://models/santa/santa_rigged.pre_footfix_20251117_190232.glb"
	if ResourceLoader.exists(santa_path):
		for c in model_root.get_children():
			model_root.remove_child(c)
			c.queue_free()
		var scene_res: Resource = ResourceLoader.load(santa_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
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
			# Bind meshes to skeleton if importer failed to wire it
			var sk := _find_skeleton()
			_bind_meshes_to_skeleton(sk)
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

func _log_skin_joints(sk: Skeleton3D) -> void:
	if model_root == null:
		return
	var stack: Array[Node] = [model_root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.skin != null:
				var cnt := mi.skin.get_bind_count()
				print("[ANIM] Skin binds=", cnt, " for mesh=", mi.name)
				for i in range(cnt):
					var bind_name := mi.skin.get_bind_name(i)
					var has := sk.find_bone(bind_name) != -1
					print("[ANIM]  bind[", i, "] name=", bind_name, " sk_has=", has)


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

func _ensure_bone_cache() -> void:
	if _bone_cache_ready:
		return
	var sk := _find_skeleton()
	if sk == null:
		return
	_bone_thigh_L = sk.find_bone("thigh.L")
	_bone_thigh_R = sk.find_bone("thigh.R")
	_bone_shin_L = sk.find_bone("shin.L")
	_bone_shin_R = sk.find_bone("shin.R")
	_bone_foot_L = sk.find_bone("foot.L")
	_bone_foot_R = sk.find_bone("foot.R")
	_bone_toe_L = sk.find_bone("toe.L")
	_bone_toe_R = sk.find_bone("toe.R")
	_bone_cache_ready = (_bone_thigh_L != -1 and _bone_thigh_R != -1 and _bone_shin_L != -1 and _bone_shin_R != -1 and _bone_foot_L != -1 and _bone_foot_R != -1)

func _apply_procedural_gait(delta: float) -> void:
	if not use_procedural_gait:
		return
	if anim_player == null:
		return
	var sk := _find_skeleton()
	if sk == null:
		return
	_ensure_bone_cache()
	if not _bone_cache_ready:
		return
	# Gait only on ground, only for Walk/Run, and not during spin airborne
	if not is_on_floor() or spin_active:
		_reset_gait_if_needed(sk)
		_clear_boot_overrides(sk)
		_reset_boot_scales(sk)
		return
	var speed := absf(velocity.x)
	var running := _is_running()
	var gaiting := (speed > 0.1) and (anim_player.current_animation == "Walk" or anim_player.current_animation == "Run")
	if not gaiting:
		_reset_gait_if_needed(sk)
		_clear_boot_overrides(sk)
		_reset_boot_scales(sk)
		return
	# Advance phase based on frequency
	var hz := (run_gait_hz if running else walk_gait_hz)
	gait_time += delta * hz * TAU
	# Compute per-leg swing (L/R out of phase by PI)
	var phase_L := gait_time
	var phase_R := gait_time + PI
	var thigh_swing := deg_to_rad(gait_thigh_swing_deg)
	var shin_swing := deg_to_rad(gait_shin_swing_deg)
	var foot_pitch := deg_to_rad(gait_foot_pitch_deg)
	var toe_roll := deg_to_rad(gait_toe_roll_deg)
	# Small offsets; assume local X for forward/back swing, local Z for foot pitch fallback
	var rot_thigh_L := Quaternion(Vector3(1,0,0), sin(phase_L) * thigh_swing)
	var rot_thigh_R := Quaternion(Vector3(1,0,0), sin(phase_R) * thigh_swing)
	var rot_shin_L := Quaternion(Vector3(1,0,0), max(0.0, -sin(phase_L)) * shin_swing) # more bend on back swing
	var rot_shin_R := Quaternion(Vector3(1,0,0), max(0.0, -sin(phase_R)) * shin_swing)
	var left_pitch_sign := (-1.0 if gait_invert_left_foot_pitch else 1.0)
	var rot_foot_L := (Quaternion() if not gait_enable_feet else Quaternion(Vector3(0,0,1), cos(phase_L) * foot_pitch * gait_left_foot_scale * left_pitch_sign))
	var rot_foot_R := (Quaternion() if not gait_enable_feet else Quaternion(Vector3(0,0,1), cos(phase_R) * foot_pitch))
	# Gentle toe roll to preserve boot silhouette during contact/push-off.
	# Use a half-wave so roll happens during stance, not flight.
	var toe_factor_L: float = max(0.0, -cos(phase_L))
	var toe_factor_R: float = max(0.0, -cos(phase_R))
	var rot_toe_L := (Quaternion() if not gait_enable_toe_roll or _bone_toe_L == -1 else Quaternion(Vector3(0,0,1), toe_factor_L * toe_roll))
	var rot_toe_R := (Quaternion() if not gait_enable_toe_roll or _bone_toe_R == -1 else Quaternion(Vector3(0,0,1), toe_factor_R * toe_roll))
	# Apply overlay directly (non-accumulating). Animations provide the base pose.
	sk.set_bone_pose_rotation(_bone_thigh_L, rot_thigh_L)
	sk.set_bone_pose_rotation(_bone_thigh_R, rot_thigh_R)
	sk.set_bone_pose_rotation(_bone_shin_L, rot_shin_L)
	sk.set_bone_pose_rotation(_bone_shin_R, rot_shin_R)
	# Feet/toes: lock to rest locally to prevent any ankle/toe deformation if requested.
	if boot_lock_local:
		sk.set_bone_pose_rotation(_bone_foot_L, Quaternion())
		sk.set_bone_pose_rotation(_bone_foot_R, Quaternion())
		if _bone_toe_L != -1:
			sk.set_bone_pose_rotation(_bone_toe_L, Quaternion())
		if _bone_toe_R != -1:
			sk.set_bone_pose_rotation(_bone_toe_R, Quaternion())
	else:
		sk.set_bone_pose_rotation(_bone_foot_L, rot_foot_L)
		sk.set_bone_pose_rotation(_bone_foot_R, rot_foot_R)
		if gait_enable_toe_roll:
			if _bone_toe_L != -1:
				sk.set_bone_pose_rotation(_bone_toe_L, rot_toe_L)
			if _bone_toe_R != -1:
				sk.set_bone_pose_rotation(_bone_toe_R, rot_toe_R)
	# Optional: global rigidity (disabled by default). Clear if not used.
	if use_boot_rigidity:
		_apply_boot_rigidity(sk, phase_L, phase_R)
	else:
		_clear_boot_overrides(sk)
	# Volume compensation: scale cross-section (Y,Z) to keep boot full in motion
	if enable_boot_volume_compensation:
		var cross: float = (boot_volume_scale_run if running else boot_volume_scale_walk)
		_apply_boot_volume_scale(sk, cross)

func _reset_gait_if_needed(sk: Skeleton3D) -> void:
	# Reset gait bones back to animation-driven pose using Skeleton3D API
	if anim_player == null:
		return
	if _bone_cache_ready:
		_reset_pose_for_bones(["thigh.L","thigh.R","shin.L","shin.R","foot.L","foot.R","toe.L","toe.R"])
 
func _apply_boot_rigidity(sk: Skeleton3D, phase_L: float, phase_R: float) -> void:
	if not use_boot_rigidity or not _bone_cache_ready:
		return
	# Make the boot fully rigid throughout gait (no phase weighting).
	# Hinge pitch is zero when boot_lock_ankle is true; otherwise small stance/swing blend.
	var pitchL_deg: float = 0.0
	var pitchR_deg: float = 0.0
	if not boot_lock_ankle:
		var stance_L: float = max(0.0, -cos(phase_L))
		var stance_R: float = max(0.0, -cos(phase_R))
		pitchL_deg = lerp(boot_pitch_swing_deg, boot_pitch_stance_deg, stance_L)
		pitchR_deg = lerp(boot_pitch_swing_deg, boot_pitch_stance_deg, stance_R)
	# Compose target global from shin global * (foot rest * local hinge rotation)
	_apply_boot_for_leg(sk, _bone_shin_L, _bone_foot_L, _bone_toe_L, pitchL_deg, 1.0)
	_apply_boot_for_leg(sk, _bone_shin_R, _bone_foot_R, _bone_toe_R, pitchR_deg, 1.0)
 
func _apply_boot_for_leg(sk: Skeleton3D, shin_idx: int, foot_idx: int, toe_idx: int, pitch_deg: float, weight: float) -> void:
	if shin_idx == -1 or foot_idx == -1 or weight <= 0.0:
		# If no weight (no stance), soften any previous override on this leg
		if foot_idx != -1:
			sk.set_bone_global_pose_override(foot_idx, Transform3D(), 0.0, true)
		if toe_idx != -1:
			sk.set_bone_global_pose_override(toe_idx, Transform3D(), 0.0, true)
		return
	var shin_g := sk.get_bone_global_pose(shin_idx)
	var foot_rest := sk.get_bone_rest(foot_idx)
	var toe_rest := (sk.get_bone_rest(toe_idx) if toe_idx != -1 else Transform3D())
	var hinge := Basis(Quaternion(Vector3(0,0,1), deg_to_rad(pitch_deg)))
	# Foot target = shin_global * (foot_rest rotated about local Z by hinge)
	var foot_local := foot_rest
	foot_local.basis = foot_local.basis * hinge
	var foot_target := shin_g * foot_local
	sk.set_bone_global_pose_override(foot_idx, foot_target, clamp(weight * boot_rigidity_strength, 0.0, 1.0), true)
	# Toe: keep near rest (no curl) but inherit same hinge to avoid crease at MTP
	if toe_idx != -1:
		var toe_local := toe_rest
		toe_local.basis = toe_local.basis * hinge
		var toe_target := foot_target * toe_local
		sk.set_bone_global_pose_override(toe_idx, toe_target, clamp(weight * boot_rigidity_strength, 0.0, 1.0), true)
 
func _clear_boot_overrides(sk: Skeleton3D) -> void:
	if _bone_foot_L != -1:
		sk.set_bone_global_pose_override(_bone_foot_L, Transform3D(), 0.0, true)
	if _bone_foot_R != -1:
		sk.set_bone_global_pose_override(_bone_foot_R, Transform3D(), 0.0, true)
	if _bone_toe_L != -1:
		sk.set_bone_global_pose_override(_bone_toe_L, Transform3D(), 0.0, true)
	if _bone_toe_R != -1:
		sk.set_bone_global_pose_override(_bone_toe_R, Transform3D(), 0.0, true)
 
func _apply_boot_volume_scale(sk: Skeleton3D, cross: float) -> void:
	if not _bone_cache_ready:
		return
	var s := Vector3(1.0, cross, cross)
	if _bone_foot_L != -1: sk.set_bone_pose_scale(_bone_foot_L, s)
	if _bone_foot_R != -1: sk.set_bone_pose_scale(_bone_foot_R, s)
	if _bone_toe_L != -1: sk.set_bone_pose_scale(_bone_toe_L, s)
	if _bone_toe_R != -1: sk.set_bone_pose_scale(_bone_toe_R, s)
 
func _reset_boot_scales(sk: Skeleton3D) -> void:
	if not _bone_cache_ready:
		return
	if _bone_foot_L != -1: sk.set_bone_pose_scale(_bone_foot_L, Vector3.ONE)
	if _bone_foot_R != -1: sk.set_bone_pose_scale(_bone_foot_R, Vector3.ONE)
	if _bone_toe_L != -1: sk.set_bone_pose_scale(_bone_toe_L, Vector3.ONE)
	if _bone_toe_R != -1: sk.set_bone_pose_scale(_bone_toe_R, Vector3.ONE)
 
func _debug_feet_snapshot() -> void:
	var sk := _find_skeleton()
	if sk == null:
		return
	_ensure_bone_cache()
	if not _bone_cache_ready:
		return
	var fl := sk.get_bone_global_pose(_bone_foot_L)
	var fr := sk.get_bone_global_pose(_bone_foot_R)
	var tl := sk.find_bone("toe.L")
	var tr := sk.find_bone("toe.R")
	var gl := (sk.get_bone_global_pose(tl) if tl != -1 else fl)
	var gr := (sk.get_bone_global_pose(tr) if tr != -1 else fr)
	var fwdL := -fl.basis.z.normalized()
	var fwdR := -fr.basis.z.normalized()
	var upL := fl.basis.y.normalized()
	var upR := fr.basis.y.normalized()
	var angle_fwd := rad_to_deg(acos(clamp(fwdL.dot(fwdR), -1.0, 1.0)))
	var angle_up := rad_to_deg(acos(clamp(upL.dot(upR), -1.0, 1.0)))
	print("[FEET] fwdAngle(L,R)=", angle_fwd, " upAngle(L,R)=", angle_up)
	print("[FEET] foot.L pos=", fl.origin, " eulerDeg=", fl.basis.get_euler() * 180.0 / PI)
	print("[FEET] foot.R pos=", fr.origin, " eulerDeg=", fr.basis.get_euler() * 180.0 / PI)
	print("[FEET] toe.L pos=", gl.origin, " toe.R pos=", gr.origin)
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

func _bind_meshes_to_skeleton(sk: Skeleton3D) -> void:
	if sk == null or model_root == null:
		return
	var sk_path := sk.get_path()
	var fixed := 0
	var stack: Array[Node] = [model_root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.skin != null:
				mi.skeleton = sk_path
				fixed += 1
	if fixed > 0:
		print("[ANIM] Bound ", fixed, " meshes to skeleton ", sk.name)
