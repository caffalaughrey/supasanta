extends Node
const SmokeTestRunner = preload("res://scripts/tests/smoke/SmokeTestRunner.gd")
var runner

func _ready() -> void:
	var args := OS.get_cmdline_args()
	var user_args := []
	if OS.has_method("get_cmdline_user_args"):
		user_args = OS.get_cmdline_user_args()
	var should_run := ("--smoke" in args) or ("--smoke" in user_args) or OS.has_feature("headless")
	if should_run:
		print("[SMOKE] Booting test runner...")
		call_deferred("_run_smoke")
		call_deferred("_start_watchdog")

func _run_smoke() -> void:
	runner = SmokeTestRunner.new()
	get_tree().root.add_child(runner)
	runner.run_all()

func _start_watchdog() -> void:
	await get_tree().create_timer(30.0).timeout
	push_error("[SMOKE] Watchdog timeout, forcing exit.")
	get_tree().quit(2)


