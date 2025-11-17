001 — Input Drift (Santa walks off platform)

Problem
- Santa moved left/right at startup without user intent. Drift varied with controller and sometimes sent axis=-1 on boot.

What we tried
- Simple deadzone on move_left/move_right actions.
- Removing analog axis; using D-pad only.
- Reducing vs increasing project deadzone.
- Offsetting spawn away from other bodies.

What worked (current approach)
- Read movement via Input.get_axis("move_left","move_right") with firm software deadzone and neutral gating:
  - Ignore |axis| < 0.35.
  - Require neutral frames and a just-pressed action before enabling controls.
  - While disabled: force move_input=0 and clamp velocity.x=0.
- Add a velocity snap-to-zero at very low speeds.
- Unit test: wait ~2s idle, assert |Δx| < 0.02.

Next steps
- Per-device calibration (log raw idle axis, auto-suggest thresholds).
- Settings toggle to enable/disable neutral gating for debugging.









