extends Node

class_name UnitRunner

var failures: Array[String] = []
var passes: int = 0

func assert_true(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
	else:
		failures.append(msg)
		push_error("[UNIT] " + msg)

func run_all() -> void:
	var cases: Array[String] = [
		"res://scripts/tests/unit/cases/test_camera_follow.gd",
		"res://scripts/tests/unit/cases/test_input_debug.gd",
		"res://scripts/tests/unit/cases/test_material_applied.gd",
		"res://scripts/tests/unit/cases/test_player_feet_on_ground.gd",
		"res://scripts/tests/unit/cases/test_glombolg_position.gd",
		"res://scripts/tests/unit/cases/test_glombolg_collision.gd",
		"res://scripts/tests/unit/cases/test_no_drift_idle.gd",
		"res://scripts/tests/unit/cases/test_glb_anims_present.gd",
		"res://scripts/tests/unit/cases/test_anim_pose_changes_moving.gd",
		"res://scripts/tests/unit/cases/test_anim_loops.gd"
	]
	for path in cases:
		var s := load(path)
		if s == null:
			failures.append("Missing test: %s" % path)
			continue
		var inst: Node = s.new()
		add_child(inst)
		if inst.has_method("run"):
			await inst.run(self)
		inst.queue_free()
		await get_tree().process_frame
	# Summary
	if failures.is_empty():
		print("*** UNIT TESTS: OK (%d passes) ***" % passes)
		get_tree().quit(0)
	else:
		push_error("*** UNIT TESTS: FAILED (%d fails, %d passes) ***" % [failures.size(), passes])
		for f in failures:
			push_error(" - " + f)
		get_tree().quit(1)
