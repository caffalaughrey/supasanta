extends Node

@export var enabled: bool = false
var overlay: Label
var current: String = ""

const MAP := {
	"1": "Idle",
	"2": "Walk",
	"3": "Run",
	"4": "Turn",
	"5": "Skid",
	"6": "JumpStart",
	"7": "AirLoop",
	"8": "Land",
	"9": "SpinJump",
	"0": "Swing"
}

func _ready() -> void:
	if OS.has_feature("headless"):
		return
	overlay = Label.new()
	overlay.top_level = true
	overlay.position = Vector2(16, 40)
	overlay.visible = false
	get_tree().root.call_deferred("add_child", overlay)
	_update_text()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var ev := event as InputEventKey
		if ev.keycode == Key.KEY_F1:
			enabled = not enabled
			if overlay:
				overlay.visible = enabled
			# When disabling, release player debug locks/freezes
			if not enabled:
				var p := _get_player()
				if p and p.has_method("debug_clear"):
					p.debug_clear()
			print("[ANIMDBG] Toggle=", enabled)
			_update_text()
			get_viewport().set_input_as_handled()
			return
		if not enabled:
			return
		# Accept number row, numpad, and physical keycodes
		var kc := ev.keycode if ev.keycode != 0 else ev.physical_keycode
		if kc == Key.KEY_1: print("[ANIMDBG] Key 1 -> Idle"); _travel("Idle"); _log_tracks("Idle")
		elif kc == Key.KEY_2: print("[ANIMDBG] Key 2 -> Walk"); _travel("Walk"); _log_tracks("Walk")
		elif kc == Key.KEY_3: print("[ANIMDBG] Key 3 -> Run"); _travel("Run"); _log_tracks("Run")
		elif kc == Key.KEY_4: print("[ANIMDBG] Key 4 -> Turn"); _travel("Turn"); _log_tracks("Turn")
		elif kc == Key.KEY_5: print("[ANIMDBG] Key 5 -> Skid"); _travel("Skid"); _log_tracks("Skid")
		elif kc == Key.KEY_6: print("[ANIMDBG] Key 6 -> JumpStart"); _travel("JumpStart"); _log_tracks("JumpStart")
		elif kc == Key.KEY_7: print("[ANIMDBG] Key 7 -> AirLoop"); _travel("AirLoop"); _log_tracks("AirLoop")
		elif kc == Key.KEY_8: print("[ANIMDBG] Key 8 -> Land"); _travel("Land"); _log_tracks("Land")
		elif kc == Key.KEY_9: print("[ANIMDBG] Key 9 -> SpinJump"); _travel("SpinJump"); _log_tracks("SpinJump")
		elif kc == Key.KEY_0: print("[ANIMDBG] Key 0 -> Swing"); _travel("Swing"); _log_tracks("Swing")
		elif kc == Key.KEY_T:
			print("[ANIMDBG] Key T -> TestNod/ExtremePose")
			var p := _get_player()
			if p and p.has_method("debug_play_candidates"):
				p.debug_play_candidates(["TestNod","ExtremePose"])
			_log_tracks("TestNod")
		elif kc == Key.KEY_Y:
			var p := _get_player()
			if p and p.has_method("debug_twist_pose"):
				print("[ANIMDBG] Twist pose")
				p.debug_twist_pose()
			get_viewport().set_input_as_handled()
			return
		elif kc == Key.KEY_KP_1: _travel("Idle")
		elif kc == Key.KEY_KP_2: _travel("Walk")
		elif kc == Key.KEY_KP_3: _travel("Run")
		elif kc == Key.KEY_KP_4: _travel("Turn")
		elif kc == Key.KEY_KP_5: _travel("Skid")
		elif kc == Key.KEY_KP_6: _travel("JumpStart")
		elif kc == Key.KEY_KP_7: _travel("AirLoop")
		elif kc == Key.KEY_KP_8: _travel("Land")
		elif kc == Key.KEY_KP_9: _travel("SpinJump")
		elif kc == Key.KEY_KP_0: _travel("Swing")
		elif kc == Key.KEY_BRACKETLEFT:
			_set_global_speed(0.8)
		elif kc == Key.KEY_BRACKETRIGHT:
			_set_global_speed(1.25)
		elif kc == Key.KEY_N:
			var p := _get_player()
			if p and p.has_method("debug_nod_head"):
				print("[ANIMDBG] Nod test")
				p.debug_nod_head()
			get_viewport().set_input_as_handled()
			return
		else:
			var char := OS.get_keycode_string(kc)
			if MAP.has(char):
				_travel(MAP[char])
				_log_tracks(MAP[char])
			_update_text()
			get_viewport().set_input_as_handled()

func _log_tracks(state_name: String) -> void:
	var p := _get_player()
	if p and p.has_method("debug_log_anim_paths"):
		p.debug_log_anim_paths(state_name)

func _get_player() -> Node:
	var root := get_tree().current_scene
	if root == null:
		return null
	# Search recursively so it works whether the player sits under World or root
	var n := root.find_child("Player", true, false)
	return n

func _travel(state_name: String) -> void:
	var p := _get_player()
	if p == null:
		return
	# Freeze motion while previewing animations for clarity
	if p.has_method("debug_travel"):
		p.debug_travel(state_name)
	var tree := p.get_node_or_null("AnimationTree") as AnimationTree
	if tree == null:
		return
	# Do not call playback.travel here; Player.debug_travel handles SM vs raw clips
	current = state_name

func _set_global_speed(scale: float) -> void:
	var p: Node = _get_player()
	if p == null:
		return
	var ap: AnimationPlayer = p.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap:
		ap.speed_scale *= scale
	_update_text()

func _update_text() -> void:
	if overlay:
		overlay.text = "AnimDebug (F1): " + (current if current != "" else "(none)") + "\\n[1-0] play, [ and ] speed"
