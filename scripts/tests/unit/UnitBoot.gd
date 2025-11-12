extends Node
const UnitRunner = preload("res://scripts/tests/unit/UnitRunner.gd")

func _ready() -> void:
	var args := OS.get_cmdline_args()
	var user_args := []
	if OS.has_method("get_cmdline_user_args"):
		user_args = OS.get_cmdline_user_args()
	if ("--unit" in args) or ("--unit" in user_args):
		call_deferred("_run_unit")
		call_deferred("_start_watchdog")

func _run_unit() -> void:
	var r := UnitRunner.new()
	get_tree().root.add_child(r)
	await r.run_all()

func _start_watchdog() -> void:
	await get_tree().create_timer(30.0).timeout
	push_error("[UNIT] Watchdog timeout, forcing exit.")
	get_tree().quit(2)


