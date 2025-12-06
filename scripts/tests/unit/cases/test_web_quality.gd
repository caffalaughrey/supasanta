extends Node

func run(runner: Node) -> void:
	# Arrange
	var vp := get_viewport()
	vp.scaling_3d_scale = 1.0
	var scaler_script := load("res://scripts/autoload/web_quality.gd")
	var scaler: Node = (scaler_script as Script).new()
	add_child(scaler)
	await get_tree().process_frame

	# Act: simulate low FPS
	scaler.target_fps = 60
	scaler.min_scale = 0.75
	scaler.max_scale = 1.0
	scaler.step = 0.05
	var before_low := vp.scaling_3d_scale
	scaler._on_sample_fps(40.0)
	await get_tree().process_frame
	var after_low := vp.scaling_3d_scale
	runner.assert_true(after_low < before_low, "WebQuality lowers scale on low FPS")

	# Act: simulate high FPS to step up
	var before_high := vp.scaling_3d_scale
	(scaler as Object).call("_on_sample_fps", 70.0)
	await get_tree().process_frame
	var after_high := vp.scaling_3d_scale
	runner.assert_true(after_high > before_high, "WebQuality increases scale on high FPS")

	scaler.queue_free()
	await get_tree().process_frame


