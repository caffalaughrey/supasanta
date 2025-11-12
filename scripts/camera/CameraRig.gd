extends Node3D

@export var target_path: NodePath
@export var horizontal_offset: float = 0.0
@export var vertical_offset: float = 1.5
@export var follow_smooth: float = 8.0
@export var vertical_deadzone: float = 0.8
@export var min_y: float = -1000.0
@export var max_y: float = 1000.0

var _target: Node3D
var _z_hold: float = 8.0

func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	_z_hold = global_position.z

func _process(delta: float) -> void:
	if _target == null:
		_target = get_node_or_null(target_path) as Node3D
		if _target == null:
			return
	var desired := Vector3(_target.global_position.x + horizontal_offset, _compute_target_y(_target.global_position.y), _z_hold)
	global_position = global_position.lerp(desired, clamp(follow_smooth * delta, 0.0, 1.0))

func _compute_target_y(target_y: float) -> float:
	var current := global_position.y
	var dz_top := current + vertical_deadzone
	var dz_bot := current - vertical_deadzone
	var new_y := current
	if target_y > dz_top:
		new_y = target_y - vertical_deadzone
	elif target_y < dz_bot:
		new_y = target_y + vertical_deadzone
	new_y = clamp(new_y + vertical_offset, min_y, max_y)
	return new_y

func _on_player_ready() -> void:
	# World connects Player.ready to this; set target
	var world := get_parent()
	if world and world.has_node("Player"):
		target_path = world.get_node("Player").get_path()
		_target = world.get_node("Player")


