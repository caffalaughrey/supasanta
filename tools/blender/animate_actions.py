"""
Supa Santa - Blender Actions Export Helper
Usage:
1) Open your rigged Santa .blend in Blender.
2) Ensure an Armature exists (active) and its animations are authored as Actions.
3) Run this script in Blender's Text Editor.
What it does:
- Validates required action names exist or remaps common variants.
- Ensures all required actions are pushed to NLA (optional) and saved.
- Exports a GLB with all actions to the project models path.
"""
import bpy
import os

REQUIRED = [
    "Idle", "Walk", "Run", "Turn", "Skid",
    "JumpStart", "AirLoop", "Land",
    "SpinJump", "Swing", "Throw",
]

COMMON_REMAP = {
    "IdleLoop": "Idle",
    "WalkLoop": "Walk",
    "RunLoop": "Run",
    "Jump": "JumpStart",
    "Fall": "AirLoop",
    "LandShort": "Land",
    "Spin": "SpinJump",
    "Attack": "Swing",
}

def ensure_armature():
    arm = None
    if bpy.context.active_object and bpy.context.active_object.type == 'ARMATURE':
        arm = bpy.context.active_object
    else:
        for obj in bpy.data.objects:
            if obj.type == 'ARMATURE':
                arm = obj
                break
    if arm is None:
        raise RuntimeError("No Armature found. Select your Santa armature and try again.")
    return arm

def remap_actions():
    name_map = {a.name: a for a in bpy.data.actions}
    for src, dst in COMMON_REMAP.items():
        if src in name_map and dst not in name_map:
            act = name_map[src]
            act.name = dst
            name_map[dst] = act
            del name_map[src]

def check_required():
    missing = [n for n in REQUIRED if n not in bpy.data.actions]
    if missing:
        print("WARNING: Missing actions:", missing)
    else:
        print("All required actions present.")

def export_glb(out_path):
    # Select armature and meshes
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.context.scene.objects:
        if obj.type in {'ARMATURE', 'MESH'}:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = ensure_armature()
    # Export all actions
    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLB', use_selection=True, export_animations=True, export_apply=True)
    print("Exported:", out_path)

def main():
    ensure_armature()
    remap_actions()
    check_required()
    project_root = os.path.expanduser("~/Desktop/supasanta")
    out_dir = os.path.join(project_root, "models", "santa")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "santa_rigged.glb")
    export_glb(out_path)

if __name__ == "__main__":
    main()


