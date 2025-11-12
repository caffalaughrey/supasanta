"""
Supa Santa - Blender helper
Usage (interactive):
1) Open Santa source mesh in Blender (one-object mesh as provided).
2) Select the Santa mesh object (Object Mode).
3) Run this script in Blender's Text Editor.

Usage (headless CLI):
blender -b /path/to/santa_source.blend --python /path/to/separate_and_rig_santa.py -- --export /path/to/santa_rigged.glb [--no-separate]

What it does:
- Creates a simple armature with named bones: arms, legs, belly, beard, hat.
- Parents Santa to the armature with automatic weights.
- Optionally (best-effort) creates vertex groups for Belly/Beard/Hat if missing,
  and separates them into child objects for a "kit-like" setup.
- Optionally exports GLB to the provided --export path.

Tested in Blender 3.x.
"""
import bpy
import sys
from mathutils import Vector

BONE_NAMES = {
    "root": "Root",
    "pelvis": "Pelvis",
    "spine": "Spine",
    "head": "Head",
    "arm_l": "Arm.L",
    "forearm_l": "Forearm.L",
    "hand_l": "Hand.L",
    "arm_r": "Arm.R",
    "forearm_r": "Forearm.R",
    "hand_r": "Hand.R",
    "thigh_l": "Thigh.L",
    "shin_l": "Shin.L",
    "foot_l": "Foot.L",
    "thigh_r": "Thigh.R",
    "shin_r": "Shin.R",
    "foot_r": "Foot.R",
    "belly": "Belly",
    "beard": "Beard",
    "hat": "Hat",
}

def ensure_object_mesh():
    # Prefer active object if it's a mesh
    obj = bpy.context.active_object
    if obj and obj.type == 'MESH':
        return obj
    # Fallback: first mesh in scene
    for o in bpy.data.objects:
        if o.type == 'MESH':
            bpy.context.view_layer.objects.active = o
            return o
    raise RuntimeError("No MESH object found. Please select or include a mesh in the .blend.")

def create_armature():
    arm_data = bpy.data.armatures.new("SantaArmature")
    arm_obj = bpy.data.objects.new("SantaArmature", arm_data)
    bpy.context.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode='EDIT')
    ed = arm_data.edit_bones

    def new_bone(name, head, tail, parent=None):
        b = ed.new(name)
        b.head = head
        b.tail = tail
        if parent:
            b.parent = parent
        return b

    root = new_bone(BONE_NAMES["root"], Vector((0,0,0)), Vector((0,0.1,0.0)))
    pelvis = new_bone(BONE_NAMES["pelvis"], Vector((0,0,1.0)), Vector((0,0,1.2)), root)
    spine = new_bone(BONE_NAMES["spine"], Vector((0,0,1.2)), Vector((0,0,1.6)), pelvis)
    head = new_bone(BONE_NAMES["head"], Vector((0,0,1.6)), Vector((0,0,1.9)), spine)

    thigh_l = new_bone(BONE_NAMES["thigh_l"], Vector((0.15,0,1.0)), Vector((0.15,0,0.6)), pelvis)
    shin_l = new_bone(BONE_NAMES["shin_l"], thigh_l.tail, Vector((0.15,0,0.2)), thigh_l)
    foot_l = new_bone(BONE_NAMES["foot_l"], shin_l.tail, Vector((0.35,0,0.2)), shin_l)

    thigh_r = new_bone(BONE_NAMES["thigh_r"], Vector((-0.15,0,1.0)), Vector((-0.15,0,0.6)), pelvis)
    shin_r = new_bone(BONE_NAMES["shin_r"], thigh_r.tail, Vector((-0.15,0,0.2)), thigh_r)
    foot_r = new_bone(BONE_NAMES["foot_r"], shin_r.tail, Vector((-0.35,0,0.2)), shin_r)

    arm_l = new_bone(BONE_NAMES["arm_l"], Vector((0.25,0,1.55)), Vector((0.55,0,1.45)), spine)
    forearm_l = new_bone(BONE_NAMES["forearm_l"], arm_l.tail, Vector((0.85,0,1.35)), arm_l)
    hand_l = new_bone(BONE_NAMES["hand_l"], forearm_l.tail, Vector((1.0,0,1.35)), forearm_l)

    arm_r = new_bone(BONE_NAMES["arm_r"], Vector((-0.25,0,1.55)), Vector((-0.55,0,1.45)), spine)
    forearm_r = new_bone(BONE_NAMES["forearm_r"], arm_r.tail, Vector((-0.85,0,1.35)), arm_r)
    hand_r = new_bone(BONE_NAMES["hand_r"], forearm_r.tail, Vector((-1.0,0,1.35)), forearm_r)

    belly = new_bone(BONE_NAMES["belly"], Vector((0,0,1.25)), Vector((0,0,1.35)), spine)
    beard = new_bone(BONE_NAMES["beard"], Vector((0,0.05,1.6)), Vector((0,0.05,1.4)), head)
    hat = new_bone(BONE_NAMES["hat"], Vector((0,0,1.9)), Vector((0,0,2.2)), head)

    bpy.ops.object.mode_set(mode='OBJECT')
    return arm_obj

def parent_with_auto_weights(mesh_obj, arm_obj):
    bpy.context.view_layer.objects.active = mesh_obj
    mesh_obj.select_set(True)
    arm_obj.select_set(True)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    mesh_obj.select_set(False)
    arm_obj.select_set(False)

def ensure_group(obj, group_name):
    vg = obj.vertex_groups.get(group_name)
    if vg is None:
        vg = obj.vertex_groups.new(name=group_name)
    return vg

def copy_group_if_missing(obj, src_group, dst_group):
    if obj.vertex_groups.get(dst_group):
        return
    if not obj.vertex_groups.get(src_group):
        return
    # Duplicate weights from src_group to dst_group
    vg_src = obj.vertex_groups[src_group]
    vg_dst = obj.vertex_groups.new(name=dst_group)
    # switch to edit mode to copy selection by weights threshold
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='DESELECT')
    bpy.ops.object.vertex_group_set_active(group=vg_src.index)
    bpy.ops.object.vertex_group_select()
    bpy.ops.object.vertex_group_set_active(group=vg_dst.index)
    bpy.ops.object.vertex_group_assign()
    bpy.ops.object.mode_set(mode='OBJECT')

def separate_to_object_by_group(mesh_obj, group_name):
    if not mesh_obj.vertex_groups.get(group_name):
        return None
    bpy.context.view_layer.objects.active = mesh_obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='DESELECT')
    mesh_obj.vertex_groups.active = mesh_obj.vertex_groups.get(group_name)
    bpy.ops.object.vertex_group_select()
    if bpy.ops.mesh.separate.poll():
        bpy.ops.mesh.separate(type='SELECTED')
    bpy.ops.object.mode_set(mode='OBJECT')
    # The newly created object becomes selected; find it
    selected = [o for o in bpy.context.selected_objects if o != mesh_obj]
    return selected[0] if selected else None

def main():
    # Parse optional args after '--'
    argv = sys.argv
    if '--' in argv:
        argv = argv[argv.index('--') + 1:]
    else:
        argv = []
    export_path = None
    do_separate = True
    i = 0
    while i < len(argv):
        if argv[i] == '--export' and i + 1 < len(argv):
            export_path = argv[i + 1]
            i += 2
        elif argv[i] == '--no-separate':
            do_separate = False
            i += 1
        else:
            i += 1

    mesh = ensure_object_mesh()
    arm = create_armature()
    parent_with_auto_weights(mesh, arm)
    # Best-effort groups for belly/beard/hat
    copy_group_if_missing(mesh, BONE_NAMES["spine"], BONE_NAMES["belly"])
    copy_group_if_missing(mesh, BONE_NAMES["head"], BONE_NAMES["beard"])
    copy_group_if_missing(mesh, BONE_NAMES["head"], BONE_NAMES["hat"])
    # Separate to kit parts (optional)
    parts = []
    if do_separate:
        for n in (BONE_NAMES["belly"], BONE_NAMES["beard"], BONE_NAMES["hat"]):
            part = separate_to_object_by_group(mesh, n)
            if part:
                part.name = n
                parts.append(part)
                # Parent part to armature (keep weights)
                part.parent = arm
                mod = part.modifiers.new(name="Armature", type='ARMATURE')
                mod.object = arm
    print("Rig created. Optional separated parts:", [p.name for p in parts])

    # Export if requested
    if export_path:
        # Select armature and all meshes
        bpy.ops.object.select_all(action='DESELECT')
        arm.select_set(True)
        for o in bpy.data.objects:
            if o.type == 'MESH':
                o.select_set(True)
        bpy.context.view_layer.objects.active = arm
        bpy.ops.export_scene.gltf(filepath=export_path, export_format='GLB', use_selection=True, export_animations=True, export_apply=True)
        print(f"Exported GLB to: {export_path}")
    else:
        print("Export: File > Export > glTF 2.0 (.glb), include 'Selected Objects' with Armature and Mesh, Apply Modifiers, +Anim if present.")

if __name__ == "__main__":
    main()


