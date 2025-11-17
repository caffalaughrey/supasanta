010 — Camera Framing (sidescroller ratio and tracking)

Problem
- Camera initially framed too high; ground sat mid-screen; didn’t follow left/right with the right feel.

What we tried
- Manual transforms and FOV tweaks in `World.tscn`.

What worked
- Camera rig node driving Camera3D:
  - Sidescroller offset and tilt; vertical deadzone with min/max clamp.
  - Ground-biased framing (approx. 25–30% of screen as ground).
- Unit test for follow behavior (basic).

Next steps
- Add parallax background; lock vertical follow in flat levels; tune exact SMW ratios once level art lands.









