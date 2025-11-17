extends Node

func _ready() -> void:
	# Set a moderate default deadzone so axes register while avoiding drift
	ProjectSettings.set_setting("input_devices/joypad/default_deadzone", 0.25)
	# Movement
	_add_action_key("move_left", Key.KEY_LEFT)
	_add_action_key("move_right", Key.KEY_RIGHT)
	# Support BOTH D-pad buttons and analog/D-pad axes
	_add_action_joypad_button("move_left", JOY_BUTTON_DPAD_LEFT)
	_add_action_joypad_button("move_right", JOY_BUTTON_DPAD_RIGHT)
	# axis 0: left (-1) / right (+1)
	_add_action_joypad_axis_index("move_left", 0, -1.0)
	_add_action_joypad_axis_index("move_right", 0, 1.0)

	# Run (hold) / Throw Bomb (tap)
	_add_action_key("run", Key.KEY_Y)
	# Y button is idx 0 per user calibration
	_add_action_joypad_button_index("run", 0)
	_add_action_key("throw_bomb", Key.KEY_Y)
	_add_action_joypad_button_index("throw_bomb", 0)

	# Jump (B) and Spin Jump (A)
	_add_action_key("jump", Key.KEY_B)
	_add_action_key("jump", Key.KEY_SPACE) # convenience on keyboard
	# B button is idx 2 per user calibration
	_add_action_joypad_button_index("jump", 2)

	_add_action_key("spin_jump", Key.KEY_A)
	# A button is idx 1 per user calibration
	_add_action_joypad_button_index("spin_jump", 1)

	# Swing (X)
	_add_action_key("swing", Key.KEY_X)
	# X button is idx 3 per user calibration
	_add_action_joypad_button_index("swing", 3)

	# Optional: Pause (Start)
	_ensure_action("pause")
	_add_action_key("pause", Key.KEY_ESCAPE)
	_add_action_joypad_button_index("pause", 9) # Start idx 9


func _ensure_action(action_name: String) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.5)


func _add_action_key(action_name: String, keycode: int) -> void:
	_ensure_action(action_name)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action_name, ev)


func _add_action_joypad_button(action_name: String, button: int) -> void:
	_ensure_action(action_name)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action_name, ev)

func _add_action_joypad_button_index(action_name: String, button_index: int) -> void:
	_ensure_action(action_name)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button_index
	InputMap.action_add_event(action_name, ev)


func _add_action_joypad_axis(action_name: String, axis: int, axis_value: float) -> void:
	_ensure_action(action_name)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = axis_value
	InputMap.action_add_event(action_name, ev)

func _add_action_joypad_axis_index(action_name: String, axis_index: int, axis_value: float) -> void:
	_ensure_action(action_name)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis_index
	ev.axis_value = axis_value
	InputMap.action_add_event(action_name, ev)
