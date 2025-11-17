007 — Test Stability (hangs, parse errors, exits)

Problem
- Headless runs hung or crashed; parse/type errors broke tests; exit didn’t terminate process.

What we tried
- OS.exit() on finish.
- Implicit type inference in tests.
- Minimal cleanup of spawned nodes.

What worked
- Replace `OS.exit()` with `get_tree().quit()`; add watchdog timeouts for unit/smoke runners.
- Explicit typing in tests to satisfy Godot 4 type checker.
- Deterministic cleanup: free spawned nodes and yield a frame.
- Throttle noisy input debug logs to avoid string churn and crashes.

Next steps
- CI timeouts for headless runs; aggregate logs.
- Standardized test helpers for node spawn/cleanup and type-safe stubs.









