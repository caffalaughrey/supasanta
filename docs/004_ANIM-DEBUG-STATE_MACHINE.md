004 — Anim Debug vs State Machine (travel errors)

Problem
- AnimDebug triggered playback.travel() for clips not present in the AnimationNodeStateMachine, causing errors like “get_node: X is not found current state.”

What we tried
- Adding custom states to the SM.
- Calling travel(), then forcing AnimationPlayer.play().

What worked
- Split debug paths:
  - Known locomotion/action states → travel via SM.
  - Debug-only clips (e.g., TestNod/ExtremePose) → play via AnimationPlayer only (no SM travel).
- Freeze horizontal motion while previewing; add overlay feedback; avoid compounding rotations; auto-reset for twist tests.

Next steps
- Add a dedicated “Debug” sub-state machine or a one-shot blend node for debug overrides.
- Provide an explicit “Release debug lock” keybind (in addition to F1 toggle).








