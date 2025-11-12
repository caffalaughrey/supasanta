extends Node

@export var show_overlay: bool = true
const MAX_LOG_LINES := 50
const AXIS_MIN_INTERVAL_MS := 150
const AXIS_MIN_DELTA := 0.08

var log: Array[String] = []
var overlay: Label

var _last_axis_value := {}
var _last_axis_time_ms := {}

func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	if show_overlay and OS.is_debug_build() and not OS.has_feature("headless"):
		call_deferred("_create_overlay")
	_update_connected()

func _create_overlay() -> void:
	overlay = Label.new()
	overlay.text = "Controllers: (none)"
	overlay.top_level = true
	overlay.position = Vector2(16, 16)
	get_tree().root.add_child(overlay)

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	var name := Input.get_joy_name(device)
	var msg := "Device %d %s: %s" % [device, "connected" if connected else "disconnected", name]
	_log(msg)
	_update_connected()

func _update_connected() -> void:
	var names: Array[String] = []
	for d in range(0, 8):
		if Input.is_joy_known(d):
			names.append("%d:%s" % [d, Input.get_joy_name(d)])
	_set_overlay_lines(["Controllers: " + (", ".join(names) if names.size() > 0 else "(none)")])

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		var e := event as InputEventJoypadButton
		_log("Button dev=%d idx=%d pressed" % [e.device, e.button_index])
	elif event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		var key := "%d:%d" % [m.device, m.axis]
		var now_ms := Time.get_ticks_msec()
		var last_v := float(_last_axis_value.get(key, 0.0))
		var last_t := int(_last_axis_time_ms.get(key, 0))
		if absf(m.axis_value - last_v) >= AXIS_MIN_DELTA and (now_ms - last_t) >= AXIS_MIN_INTERVAL_MS:
			_log("Axis dev=%d axis=%d val=%.2f" % [m.device, m.axis, m.axis_value])
			_last_axis_value[key] = m.axis_value
			_last_axis_time_ms[key] = now_ms

func _log(msg: String) -> void:
	log.append(msg)
	while log.size() > MAX_LOG_LINES:
		log.pop_front()
	print("[INPUT] " + msg)
	_set_overlay_lines(log)

func _set_overlay_lines(lines: Array[String]) -> void:
	if overlay:
		overlay.text = "\n".join(lines)

func _process_event_for_test(event: InputEvent) -> void:
	_unhandled_input(event)


