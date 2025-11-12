extends RigidBody3D

@export var lifetime_seconds: float = 5.0

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(lifetime_seconds).timeout
	queue_free()



