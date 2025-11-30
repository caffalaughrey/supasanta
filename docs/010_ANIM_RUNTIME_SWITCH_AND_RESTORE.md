### Santa Animation Runtime Restore and Path Switch (2025‑11‑17)

This document records the steps, rationale, and current switches used to restore full-body gameplay animations for Santa, and how to safely toggle/diagnose going forward.

## What changed
- Restored the rig to a known‑good GLB with full upper‑body tracks:
  - Using `models/santa/santa_rigged.pre_footfix_20251117_190232.glb`.
  - This GLB’s Walk/Run contain arm and spine tracks, unlike the later variants.
- Switched gameplay from AnimationTree to direct `AnimationPlayer` playback:
  - `use_animation_tree = false` in `scripts/player/Player.gd`.
  - Ensures gameplay matches Fn+F1 debug previews and that featured actions are clearly visible.
- Added short “holds” for featured gameplay actions to make them read:
  - Turn (`turn_hold_s`), JumpStart (`jumpstart_hold_s`), Land (`land_hold_s`), Swing (`swing_hold_s`), Throw (`throw_hold_s`).
  - While a hold is active, locomotion does not override the featured clip.
- Separated Jump vs SpinJump:
  - A (Jump) uses `JumpStart` then `AirLoop` until Land.
  - B (SpinJump) uses `JumpStart` then continuous yaw spin while airborne (procedural), staying in `AirLoop` (no cartwheel clip).
- Idle facing: Santa rotates to face the camera after a brief dwell (`idle_face_delay_s`).
- Turn nudge: When flipping facing while moving on ground, a short `Turn` plays.
- Debug safety: If the debug overlay is off, any lingering debug locks are auto‑cleared so gameplay cannot get stuck.

## Why this was needed
- Later GLB iterations (during foot experiments) lost upper‑body animation tracks in Walk/Run, so arms didn’t move even though the state machine was playing clips.
- AnimationTree blending could mask brief actions (Turn, JumpStart, Land, Swing, Throw). Introducing per‑action hold windows guarantees visibility.
- Direct `AnimationPlayer` playback aligns gameplay visuals with Fn+F1 debug previews and removes state machine ambiguity while we stabilize.

## Current runtime configuration
- Model path (temporary):
  - `scripts/player/Player.gd` → loads `models/santa/santa_rigged.pre_footfix_20251117_190232.glb`.
- Animation path:
  - `use_animation_tree = false` (direct `AnimationPlayer` for gameplay).
- Featured action holds (tune as needed):
  - `turn_hold_s = 0.12`
  - `jumpstart_hold_s = 0.12`
  - `land_hold_s = 0.12`
  - `swing_hold_s = 0.25`
  - `throw_hold_s = 0.18`
- Spin jump:
  - Procedural yaw spin set by `spin_yaw_deg_per_sec` (default 360.0) while in `AirLoop`.
- Throw on Y‑tap while idle:
  - Quick tap of `run` while mostly neutral X input triggers `Throw` (spawns a bomb and plays the clip).

## Controls (Input actions)
- Left/Right: `move_left`, `move_right`
- Jump (A): `jump`
- SpinJump (B): `spin_jump`
- Run (Y): hold to run; quick tap (while idle) → `Throw`
- Swing: `swing`

## Debug usage
- Fn+F1 toggles the animation debug overlay (preview specific clips head‑on).
- While the overlay is enabled, previews use direct `AnimationPlayer`. When disabled, any debug lock is auto‑cleared so gameplay resumes normally.

## How to toggle back (for testing)
- To test the state machine again:
  - In `scripts/player/Player.gd`, set `use_animation_tree = true`.
  - Optionally keep the featured action holds in `_update_locomotion_state()` if you want actions to read clearly under the SM path.
- To try a different GLB:
  - Change `santa_path` in `Player.gd` back to `res://models/santa/santa_rigged.glb` or to another backup below.

## Available GLB backups (in repo)
- `models/santa/santa_rigged.pre_footfix_20251117_190232.glb`  ← current
- `models/santa/santa_rigged.pre_footfixY_20251117_190657.glb`
- `models/santa/santa_rigged.pre_deformOnly_20251117_202027.glb`
- `models/santa/santa_rigged.pre_deformOnly_20251117_202101.glb`
- `models/santa/santa_rigged.pre_frameNorm_20251117_202437.glb`
- `models/santa/santa_rigged.pre_heelTransfer_20251117_203134.glb`
- `models/santa/santa_rigged.pre_anatomical_20251117_203704.glb`
- `models/santa/santa_rigged.broken_20251117_204012.glb` (bad)

## Known issues / non‑goals right now
- Foot “crimping” and boot volume effects are disabled for stability. We’ll revisit after gameplay presentation is locked in.
- AnimationLayering: We are not using layered upper‑body on top of locomotion yet. Direct playback gives us baseline correctness first.

## Smoke/verification
- Smoke tests confirm: GLB loads, upper‑body tracks present in Walk/Run, Throw spawns a bomb, and logs show the direct playback path is active.

## Fast recovery checklist
1) If arms stop animating in gameplay:
   - Verify `use_animation_tree = false` and `santa_rigged.pre_footfix_...glb` is loaded in logs.
2) If debug preview works but gameplay doesn’t:
   - Ensure overlay is OFF and debug locks were auto‑cleared (logs on level start).
3) If actions feel too fast/slow:
   - Tweak `turn_hold_s`, `jumpstart_hold_s`, `land_hold_s`, `swing_hold_s`, `throw_hold_s` and re‑run.
4) If you need the SM path:
   - Flip `use_animation_tree = true` and keep action holds in place for readability.







