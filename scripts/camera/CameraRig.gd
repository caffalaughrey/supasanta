extends Node3D

@export var target_path: NodePath
@export var horizontal_offset: float = 0.0
@export var vertical_offset: float = 1.5
@export var follow_smooth: float = 8.0
@export var vertical_deadzone: float = 0.8
@export var min_y: float = -1000.0
@export var max_y: float = 1000.0
@export var vertical_deadzone_up_multiplier: float = 5.0
@export var prevent_upward_follow: bool = true
# Fraction of screen height (from the top) at which we start allowing upward follow.
# Example: 0.2 means allow upward tracking only when the player reaches the top 20% of the screen.
@export var upward_follow_trigger_ratio_from_top: float = 0.1

var _target: Node3D
var _z_hold: float = 8.0
var _camera: Camera3D
var _initialized_y: bool = false

func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	_z_hold = global_position.z
	_camera = get_node_or_null("Camera3D") as Camera3D

func _process(delta: float) -> void:
	if _target == null:
		_target = get_node_or_null(target_path) as Node3D
		# Fallback: auto-find Player sibling if not set by signal/inspector
		if _target == null:
			var world := get_parent()
			if world and world.has_node("Player"):
				var player := world.get_node("Player") as Node3D
				if player:
					target_path = player.get_path()
					_target = player
			if _target == null:
				return
	# Initialize baseline vertical framing once so the stage sits lower even when idle
	if not _initialized_y and _target != null:
		global_position.y = clamp(_target.global_position.y + vertical_offset, min_y, max_y)
		_initialized_y = true
	var desired := Vector3(_target.global_position.x + horizontal_offset, _compute_target_y(_target.global_position.y), _z_hold)
	global_position = global_position.lerp(desired, clamp(follow_smooth * delta, 0.0, 1.0))

func _get_view_half_height_world(z_at: float) -> float:
	if _camera == null:
		return INF
	var d: float = absf(_camera.global_position.z - z_at)
	return d * tan(deg_to_rad(_camera.fov) * 0.5)

func _compute_target_y(target_y: float) -> float:
	var current := global_position.y
	var dz_top := current + (vertical_deadzone * vertical_deadzone_up_multiplier)
	var dz_bot := current - vertical_deadzone
	var candidate_y := current
	var moved := false
	if target_y > dz_top:
		# Allow upward movement only if player is near the top of the viewport.
		if prevent_upward_follow and _camera != null and _target != null:
			var half_h: float = _get_view_half_height_world(_target.global_position.z)
			if half_h != INF:
				var view_h: float = half_h * 2.0
				var world_top_y: float = _camera.global_position.y + half_h
				var trigger_y: float = world_top_y - (view_h * upward_follow_trigger_ratio_from_top)
				if target_y >= trigger_y:
					candidate_y = target_y - (vertical_deadzone * vertical_deadzone_up_multiplier)
					moved = true
				else:
					# Do not move upward yet; keep current Y
					moved = false
			else:
				candidate_y = target_y - (vertical_deadzone * vertical_deadzone_up_multiplier)
				moved = true
		else:
			candidate_y = target_y - (vertical_deadzone * vertical_deadzone_up_multiplier)
			moved = true
	elif target_y < dz_bot:
		candidate_y = target_y + vertical_deadzone
		moved = true
	# Apply vertical offset only when we are actually adjusting towards the target
	if not moved:
		return current
	var adjusted: float = clamp(candidate_y + vertical_offset, min_y, max_y)
	# Final clamp: do not allow upward camera movement unless we explicitly approved it above.
	if prevent_upward_follow and adjusted > current:
		# Only permit if target is truly near top-of-screen
		if _camera != null and _target != null:
			var half_h2: float = _get_view_half_height_world(_target.global_position.z)
			if half_h2 != INF:
				var view_h2: float = half_h2 * 2.0
				var world_top_y2: float = _camera.global_position.y + half_h2
				var trigger_y2: float = world_top_y2 - (view_h2 * upward_follow_trigger_ratio_from_top)
				if target_y >= trigger_y2:
					return adjusted
				return current
			else:
				# No camera available to compute; default to not moving up
				return current
		return current
	return adjusted

func _on_player_ready() -> void:
	# World connects Player.ready to this; set target
	var world := get_parent()
	if world and world.has_node("Player"):
		target_path = world.get_node("Player").get_path()
		_target = world.get_node("Player")
