009 — Materials UID Warnings (PBR textures)

Problem
- Warnings like “ext_resource, invalid UID – using text path instead” on material loads.

What we tried
- Re-saving .tres; re-importing textures.

What worked
- Godot safely falls back to text paths; log is noisy but harmless.
- Kept `dnn_santa.tres` referencing textures by path; applied material to imported meshes programmatically on load.

Next steps
- Normalize textures into `res://textures/...` and re-save .tres with correct UIDs.
- Add a one-time fixup tool to rewrite UIDs to current project paths.









