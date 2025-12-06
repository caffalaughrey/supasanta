extends Node

@export var target_fps: int = 60
@export var min_scale: float = 0.75
@export var max_scale: float = 1.0
@export var step: float = 0.05
@export var sample_interval: float = 0.5

var _accum_time: float = 0.0

func _ready() -> void:
	# Ensure an initial sane value is set according to project defaults
	var rs := get_viewport().scaling_3d_scale
	if rs <= 0.0:
		get_viewport().scaling_3d_scale = max_scale

func _process(delta: float) -> void:
	_accum_time += delta
	if _accum_time < sample_interval:
		return
	_accum_time = 0.0
	_on_sample_fps(Engine.get_frames_per_second())

func _on_sample_fps(fps: float) -> void:
	var rs := get_viewport().scaling_3d_scale
	if fps < float(target_fps) - 10.0 and rs > min_scale:
		get_viewport().scaling_3d_scale = max(min_scale, rs - step)
	elif fps > float(target_fps) + 5.0 and rs < max_scale:
		get_viewport().scaling_3d_scale = min(max_scale, rs + step)


