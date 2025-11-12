extends Node

func run(runner) -> void:
	var dbg: Node = load("res://scripts/autoload/input_debug.gd").new()
	get_tree().root.add_child(dbg)
	await get_tree().process_frame
	# Simulate button
	var evb: InputEventJoypadButton = InputEventJoypadButton.new()
	evb.device = 0
	evb.button_index = JOY_BUTTON_A
	evb.pressed = true
	dbg._process_event_for_test(evb)
	# Simulate axis
	var eva: InputEventJoypadMotion = InputEventJoypadMotion.new()
	eva.device = 0
	eva.axis = JOY_AXIS_LEFT_X
	eva.axis_value = 0.8
	dbg._process_event_for_test(eva)
	await get_tree().process_frame
	runner.assert_true((dbg.log as Array).size() >= 2, "InputDebug did not capture events")
	dbg.queue_free()
	await get_tree().process_frame


