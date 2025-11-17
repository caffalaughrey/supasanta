003 — Animations Play, Mesh Does Not Deform

Problem
- Actions existed and “played” (AnimationPlayer said playing=true; AnimationTree traveled) but Santa’s pose never changed.

Symptoms
- Animation list present.
- No visible deformation on number-triggered clips.
- Sometimes logs showed state changes; still no pose change.

What we tried
- Re-export GLB with actions; forced sampling; NLA strips.
- Setting AnimationTree.active=true.
- Setting AnimationPlayer.root_node to ModelRoot.
- “Nod”/“twist” debug to force visible motion.

What worked
- Ensure mesh is skinned and bound in Blender (parent with auto weights).
- At runtime, force-bind MeshInstance3D.skeleton to the live Skeleton3D path under the imported GLB.
- Validate bind names vs Skeleton3D bones (log every skin bind and resolution).
- Use AnimationPlayer rooted at ModelRoot for debug clips; avoid state-machine travel for debug-only actions.
- Confirmed with runtime bone overrides (twist) and temporary reset.

Key lessons
- Animations must target Skeleton3D bone poses; object/node-level transforms won’t deform skinned meshes in Godot.
- GLB loader cache can mask re-exports; use ResourceLoader.CACHE_MODE_IGNORE for fresh loads.

Next steps
- Bake guaranteed debug clips (“TestNod”, “ExtremePose”) into the GLB as a CI step; assert presence and non-empty tracks in unit tests.
- Author a tiny verified “probe” rig for pipeline validation before replacing Santa’s asset.









