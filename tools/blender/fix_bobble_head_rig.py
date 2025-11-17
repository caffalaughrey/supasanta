import bpy
from mathutils import Vector

def find_armature():
    # Prefer metarig if present, else first armature
    arm = bpy.data.objects.get("metarig")
    if arm and arm.type == "ARMATURE":
        return arm
    for obj in bpy.data.objects:
        if obj.type == "ARMATURE":
            return obj
    raise RuntimeError("No armature found")

def find_deformed_mesh_for_armature(arm):
    # Return first mesh object using an Armature modifier that targets arm
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        for mod in obj.modifiers:
            if mod.type == "ARMATURE" and mod.object == arm:
                return obj
    # Fallback: any mesh
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            return obj
    return None

def estimate_character_height(mesh_obj):
    if not mesh_obj:
        return 1.0
    depsgraph = bpy.context.evaluated_depsgraph_get()
    eval_obj = mesh_obj.evaluated_get(depsgraph)
    bb = [Vector(c) for c in eval_obj.bound_box]
    zs = [c.z for c in bb]
    return max(zs) - min(zs) if zs else 1.0

def pick_head_bone(edit_bones):
    # Prefer 'head' if present, else highest-numbered spine.*
    if "head" in edit_bones:
        return edit_bones["head"]
    # iterate by names, not EditBone objects
    spine_candidates = [name for name in edit_bones.keys() if str(name).startswith("spine")]
    if spine_candidates:
        # choose lexicographically last, usually the highest spine.XXX
        name = sorted(spine_candidates)[-1]
        return edit_bones[name]
    # last resort: neck or chest
    for name in ("neck", "neck.001", "chest", "upper_chest"):
        if name in edit_bones:
            return edit_bones[name]
    return None

def ensure_head_gimbal(arm, eb_head):
    eb = arm.data.edit_bones
    gimbal_name = "head_gimbal"
    if gimbal_name in eb:
        return eb[gimbal_name]
    gimbal = eb.new(gimbal_name)
    gimbal.head = eb_head.head.copy()
    # tiny non-zero length
    gimbal.tail = gimbal.head + Vector((0.0, 0.0, 0.01))
    gimbal.use_deform = False

    # Reparent: put gimbal where head was, then parent head under gimbal
    gimbal.parent = eb_head.parent
    eb_head.parent = gimbal
    return gimbal

def move_head_tail_to_crown(eb_head, char_height):
    # Move tail upwards along world Z by 18% of character height (tunable)
    offset = Vector((0.0, 0.0, max(0.05, 0.18 * char_height)))
    eb_head.tail = eb_head.head + offset

def recalc_leg_rolls(arm):
    bpy.ops.armature.select_all(action='DESELECT')
    eb = arm.data.edit_bones
    changed = False
    for side in (".L", ".R"):
        for name in (f"thigh{side}", f"shin{side}", f"foot{side}", f"toe{side}"):
            if name in eb:
                eb[name].select = True
                changed = True
    if changed:
        bpy.ops.armature.calculate_roll(type='GLOBAL_POS_Z')
        for b in eb:
            b.select = False

def place_ik_poles_and_reset_angles(arm, char_height):
    # Pose mode operations
    bpy.ops.object.mode_set(mode='POSE')
    for side in (".L", ".R"):
        shin = arm.pose.bones.get(f"shin{side}")
        pole = arm.pose.bones.get(f"ik_pole{side}")
        if shin and pole:
            # Place pole in front of knee along -Y (common forward in Blender rigs)
            knee_world = arm.matrix_world @ shin.head
            pole_off = Vector((0.0, -0.25 * char_height, 0.0))
            pole_loc = knee_world + pole_off
            # Convert to armature local space for bone location
            pole_loc_local = arm.matrix_world.inverted() @ pole_loc
            pole.location = pole_loc_local - pole.bone.head_local
        if shin:
            for c in shin.constraints:
                if c.type == 'IK':
                    c.pole_angle = 0.0
                    c.iterations = max(16, c.iterations)

def run():
    arm = find_armature()
    mesh = find_deformed_mesh_for_armature(arm)
    char_h = estimate_character_height(mesh)

    # Ensure we start from Object Mode
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)

    bpy.ops.object.mode_set(mode='EDIT')
    eb_head = pick_head_bone(arm.data.edit_bones)
    if not eb_head:
        print("[RIG] No head-like bone found; skipping head adjustments.")
    else:
        gimbal = ensure_head_gimbal(arm, eb_head)
        move_head_tail_to_crown(eb_head, char_h)
        print(f"[RIG] Head base={eb_head.head}, new tail={eb_head.tail}, gimbal={gimbal.name}")

    recalc_leg_rolls(arm)
    place_ik_poles_and_reset_angles(arm, char_h)

    # Return to Object Mode
    bpy.ops.object.mode_set(mode='OBJECT')
    print("[RIG] Completed bobble-head adjustments.")

if __name__ == "__main__":
    run()


