008 — Blender Rig Issues (hat deformation, spikes, IK, export)

Problem
- Visual artifacts: “horn” bones through hat, melted-looking deforms, cluttered armature display; generation scripts failing in headless mode.

What we tried
- Quick vertex weight tweaks; changing display modes; re-running scripts without context.

What worked
- MCP inside Blender (not headless) to:
  - Assign top verts 100% to hat/head bone; remove stray weights.
  - Change armature display to STICK; reduce bone size; shorten tails.
  - Add simple foot IK (chain 2) with per-foot target/pole; arms kept FK.
- Export GLB with `export_force_sampling` to bake constraints and stepped keys.

Next steps
- Authoring: keep deform bones separate from helpers; export deform only.
- Provide a validated .blend “source of truth” and scripted export profile.









