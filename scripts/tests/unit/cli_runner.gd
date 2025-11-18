extends SceneTree

func _initialize() -> void:
	# Load and attach the unit test runner, then execute all tests.
	var runner_script := load("res://scripts/tests/unit/UnitRunner.gd")
	if runner_script == null:
		push_error("Failed to load UnitRunner.gd")
		quit(1)
		return
	var runner: Node = runner_script.new()
	root.add_child(runner)
	# Ensure runner is inside the tree before invoking tests
	await process_frame
	await runner.run_all()
	# UnitRunner will call quit() with the appropriate code; this is a safeguard.
	quit(0)


