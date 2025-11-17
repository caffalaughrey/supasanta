006 — World Scene Corruption (invalid/corrupt .tscn)

Problem
- `World.tscn` reported as invalid/corrupt; editor load errors.

What we tried
- Reordering nodes/resources by hand.
- Regenerating sub-resources.

What worked
- Correct `load_steps` and ensure `[sub_resource]` blocks appear before node declarations.
- Keep ground collider/mesh consistent; keep Player spawn sane.

Next steps
- Add a minimal scene linter to CI to catch `load_steps`/ordering issues.
- Keep sub-resources in separate .tres files where practical.









