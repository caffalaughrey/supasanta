002 — Feet Alignment (buried/invisible/inside platform)

Problem
- Santa’s visual model didn’t sit on the ground: buried in platform, floating, or invisible, inconsistent across edits and imports.

What we tried
- Align visual via mesh AABBs (unreliable for skinned GLTFs).
- Guessing “feet” using mesh names and offsets.
- One-off manual y-offsets per import.

What worked
- Treat y=0 as platform top and set capsule collider bottom to y=0.
- Add ModelRoot and parent imported GLB under it.
- Iteratively align ModelRoot in world-space using:
  - Skeleton-based feet detection if possible; else min Y of meshes, ignoring “top” substrings (cap/hat/beard/head/hair).
  - Apply small clearance.
- Replace unit test: physics raycast from player down, assert collider==Ground and is_on_floor()==true. Physics is source of truth.
- Added manual `model_visual_offset_y` for small artist tweaks.

Next steps
- Bake “reference foot bone” in rig for unambiguous feet.
- Save per-model offsets into .tres, not code.









