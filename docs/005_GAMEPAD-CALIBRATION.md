005 — Gamepad Calibration (SNES-style mapping)

Problem
- Controller inputs didn’t map reliably; D-pad reported as axes on some devices; startup spam logged axis=-1; actions not firing.

What we tried
- Binding JoyAxis vs JoyButton (Godot 4 constants).
- Keyboard fallbacks.
- Axis-only vs D-pad-only bindings.

What worked
- Bind both: D-pad buttons (JOY_BUTTON_DPAD_LEFT/RIGHT) and Axis 0 (±1) for left/right.
- Add debug overlay to log raw events with throttling to avoid crashes.
- Default project deadzone ~0.25 for responsiveness; add stronger software deadzone and neutral gating in movement.
- Unit tested that actions exist and basic throw/jump paths run under headless.

Next steps
- In-game calibration screen that records raw axis/button indices per device.
- Persist per-device mappings and deadzones.









