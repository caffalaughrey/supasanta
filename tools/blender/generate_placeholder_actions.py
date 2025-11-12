"""
Supa Santa - Generate Placeholder Actions
This script:
- Ensures an Armature exists (creates simple rest if needed)
- Generates placeholder actions: Idle, Walk, Run, Turn, Skid, JumpStart, AirLoop, Land, SpinJump, Swing, Throw
- Exports GLB with actions to the project models path.

Run headless:
blender -b /Users/amacgafraidh/Desktop/supasanta/tools/blender/work/santa_source.blend --python /Users/amacgafraidh/Desktop/supasanta/tools/blender/generate_placeholder_actions.py
"""
import bpy
import os
from math import radians
from mathutils import Vector

BONES = {
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
}

ACTIONS = [
    "Idle", "Walk", "Run", "Turn", "Skid",
    "JumpStart", "AirLoop", "Land",
    "SpinJump", "Swing", "Throw",
]

def get_armature():
    for obj in bpy.data.objects:
        if obj.type == 'ARMATURE':
            return obj
    return None

def get_first_mesh():
    for obj in bpy.data.objects:
        if obj.type == 'MESH':
            return obj
    return None

def create_armature_basic():
    arm_data = bpy.data.armatures.new("SantaArmature")
    arm_obj = bpy.data.objects.new("SantaArmature", arm_data)
    bpy.context.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode='EDIT')
    ed = arm_data.edit_bones
    def nb(name, head, tail, parent=None):
        b = ed.new(name)
        b.head = head
        b.tail = tail
        if parent:
            b.parent = parent
        return b
    root = nb(BONES["root"], Vector((0,0,0)), Vector((0,0.1,0)))
    pelvis = nb(BONES["pelvis"], Vector((0,0,1.0)), Vector((0,0,1.2)), root)
    spine = nb(BONES["spine"], Vector((0,0,1.2)), Vector((0,0,1.6)), pelvis)
    head = nb(BONES["head"], Vector((0,0,1.6)), Vector((0,0,1.85)), spine)
    thigh_l = nb(BONES["thigh_l"], Vector((0.15,0,1.0)), Vector((0.15,0,0.6)), pelvis)
    shin_l = nb(BONES["shin_l"], thigh_l.tail, Vector((0.15,0,0.2)), thigh_l)
    foot_l = nb(BONES["foot_l"], shin_l.tail, Vector((0.35,0,0.2)), shin_l)
    thigh_r = nb(BONES["thigh_r"], Vector((-0.15,0,1.0)), Vector((-0.15,0,0.6)), pelvis)
    shin_r = nb(BONES["shin_r"], thigh_r.tail, Vector((-0.15,0,0.2)), thigh_r)
    foot_r = nb(BONES["foot_r"], shin_r.tail, Vector((-0.35,0,0.2)), shin_r)
    arm_l = nb(BONES["arm_l"], Vector((0.25,0,1.55)), Vector((0.55,0,1.45)), spine)
    forearm_l = nb(BONES["forearm_l"], arm_l.tail, Vector((0.85,0,1.35)), arm_l)
    hand_l = nb(BONES["hand_l"], forearm_l.tail, Vector((1.0,0,1.35)), forearm_l)
    arm_r = nb(BONES["arm_r"], Vector((-0.25,0,1.55)), Vector((-0.55,0,1.45)), spine)
    forearm_r = nb(BONES["forearm_r"], arm_r.tail, Vector((-0.85,0,1.35)), arm_r)
    hand_r = nb(BONES["hand_r"], forearm_r.tail, Vector((-1.0,0,1.35)), forearm_r)
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

def ensure_pose_mode(arm):
    bpy.context.view_layer.objects.active = arm
    if bpy.context.mode != 'POSE':
        try:
            bpy.ops.object.mode_set(mode='POSE')
        except:
            pass

def new_action(arm, name):
    act = bpy.data.actions.get(name)
    if act is None:
        act = bpy.data.actions.new(name=name)
    arm.animation_data_create()
    arm.animation_data.action = act
    return act

def key_bone_rot(arm, bone_name, frame, rot_euler):
    pbone = arm.pose.bones.get(bone_name)
    if pbone is None:
        return
    pbone.rotation_mode = 'XYZ'
    pbone.rotation_euler = rot_euler
    pbone.keyframe_insert(data_path="rotation_euler", frame=frame)

def key_bone_loc(arm, bone_name, frame, vec):
    pbone = arm.pose.bones.get(bone_name)
    if pbone is None:
        return
    pbone.location = vec
    pbone.keyframe_insert(data_path="location", frame=frame)

def make_idle(arm):
    act = new_action(arm, "Idle")
    ensure_pose_mode(arm)
    for f in (0, 15, 30):
        key_bone_loc(arm, BONES["spine"], f, (0,0,0.0))
        key_bone_rot(arm, BONES["head"], f, (radians(2 if f==15 else 0),0,0))
    act.use_fake_user = True

def make_walk(arm, name="Walk", stride=10, frames=30):
    act = new_action(arm, name)
    ensure_pose_mode(arm)
    half = frames//2
    # Simple leg swing
    key_bone_rot(arm, BONES["thigh_l"], 0, (radians(15),0,0))
    key_bone_rot(arm, BONES["thigh_r"], 0, (radians(-15),0,0))
    key_bone_rot(arm, BONES["thigh_l"], half, (radians(-15),0,0))
    key_bone_rot(arm, BONES["thigh_r"], half, (radians(15),0,0))
    key_bone_rot(arm, BONES["thigh_l"], frames, (radians(15),0,0))
    key_bone_rot(arm, BONES["thigh_r"], frames, (radians(-15),0,0))
    act.use_fake_user = True

def make_turn(arm):
    act = new_action(arm, "Turn")
    ensure_pose_mode(arm)
    key_bone_rot(arm, BONES["spine"], 0, (0,0,0))
    key_bone_rot(arm, BONES["spine"], 6, (0,radians(10),0))
    key_bone_rot(arm, BONES["spine"], 12, (0,0,0))
    act.use_fake_user = True

def make_skid(arm):
    act = new_action(arm, "Skid")
    ensure_pose_mode(arm)
    key_bone_rot(arm, BONES["spine"], 0, (radians(-5),0,0))
    key_bone_rot(arm, BONES["spine"], 6, (radians(5),0,0))
    act.use_fake_user = True

def make_jumpstart(arm):
    act = new_action(arm, "JumpStart")
    ensure_pose_mode(arm)
    key_bone_loc(arm, BONES["pelvis"], 0, (0,0,0))
    key_bone_loc(arm, BONES["pelvis"], 6, (0,0,-0.03))
    act.use_fake_user = True

def make_airloop(arm):
    act = new_action(arm, "AirLoop")
    ensure_pose_mode(arm)
    key_bone_rot(arm, BONES["spine"], 0, (radians(-5),0,0))
    key_bone_rot(arm, BONES["spine"], 10, (radians(-5),0,0))
    act.use_fake_user = True

def make_land(arm):
    act = new_action(arm, "Land")
    ensure_pose_mode(arm)
    key_bone_loc(arm, BONES["pelvis"], 0, (0,0,-0.02))
    key_bone_loc(arm, BONES["pelvis"], 6, (0,0,0))
    act.use_fake_user = True

def make_spinjump(arm):
    act = new_action(arm, "SpinJump")
    ensure_pose_mode(arm)
    key_bone_rot(arm, BONES["pelvis"], 0, (0,0,0))
    key_bone_rot(arm, BONES["pelvis"], 10, (0,radians(180),0))
    key_bone_rot(arm, BONES["pelvis"], 20, (0,radians(360),0))
    act.use_fake_user = True

def make_swing(arm):
    act = new_action(arm, "Swing")
    ensure_pose_mode(arm)
    key_bone_rot(arm, BONES["arm_r"], 0, (radians(-20),0,radians(10)))
    key_bone_rot(arm, BONES["arm_r"], 6, (radians(40),0,radians(-10)))
    key_bone_rot(arm, BONES["arm_r"], 12, (radians(-20),0,radians(10)))
    act.use_fake_user = True

def make_throw(arm):
    act = new_action(arm, "Throw")
    ensure_pose_mode(arm)
    key_bone_rot(arm, BONES["arm_r"], 0, (radians(-30),0,0))
    key_bone_rot(arm, BONES["arm_r"], 6, (radians(70),0,0))
    key_bone_rot(arm, BONES["arm_r"], 12, (radians(-10),0,0))
    act.use_fake_user = True

def main():
    arm = get_armature()
    if arm is None:
        mesh = get_first_mesh()
        if mesh is None:
            raise RuntimeError("No mesh to rig found.")
        arm = create_armature_basic()
        parent_with_auto_weights(mesh, arm)
    # Create actions
    make_idle(arm)
    make_walk(arm, "Walk", frames=30)
    make_walk(arm, "Run", frames=20)
    make_turn(arm)
    make_skid(arm)
    make_jumpstart(arm)
    make_airloop(arm)
    make_land(arm)
    make_spinjump(arm)
    make_swing(arm)
    make_throw(arm)
    # Export
    out_path = os.path.expanduser("~/Desktop/supasanta/models/santa/santa_rigged.glb")
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.context.scene.objects:
        if obj.type in {'ARMATURE', 'MESH'}:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLB', use_selection=True, export_animations=True, export_apply=True)
    print("Exported with placeholder actions:", out_path)

if __name__ == "__main__":
    main()


