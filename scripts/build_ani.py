"""Build the optimised Ani GLB from the user-supplied CC female.

Reads the FBX from ANI_FBX (never committed). Writes a decimated, JPEG-compressed
GLB with idle/walk/jog/run/sit clips on the character's own rig.
"""

import os
import bpy
import bmesh
from mathutils import Vector

FBX = os.environ.get("ANI_FBX", "/tmp/ani-src/source/Female Animation.fbx")
OUT = os.environ.get("ANI_OUT", "/workspace/public/models/ani.glb")
LACE = os.environ.get("ANI_LACE", "/workspace/public/textures/lace.jpg")
LACE_N = os.environ.get("ANI_LACE_N", "/workspace/public/textures/lace_normal.png")
PREVIEW = os.environ.get("ANI_PREVIEW", "/tmp/ani-preview.png")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=FBX)

# Drop the demo take and the cameras. The game uses its own clips.
for action in list(bpy.data.actions):
    bpy.data.actions.remove(action)
for name in ("Crop_T_Shirt", "Denim_shorts", "Underwear_Bottoms", "Bun", "Real_Hair", "Preview_Camera", "Armature"):
    obj = bpy.data.objects.get(name)
    if obj:
        bpy.data.objects.remove(obj, do_unlink=True)

arm = bpy.data.objects["Camila"]
body = bpy.data.objects["CC_Base_Body"]


def foreach_pixels(img, fn):
    px = list(img.pixels)
    fn(px)
    img.pixels.foreach_set(px)
    img.update()


def blonde(px):
    for i in range(0, len(px), 4):
        r, g, b = px[i], px[i + 1], px[i + 2]
        lum = 0.3 * r + 0.5 * g + 0.2 * b
        px[i] = min(1.0, 0.25 * r + 0.78)
        px[i + 1] = min(1.0, 0.18 * g + 0.62)
        px[i + 2] = min(1.0, 0.08 * b + 0.22)


def blue_iris(px):
    for i in range(0, len(px), 4):
        r, g, b = px[i], px[i + 1], px[i + 2]
        if r > 0.82 and g > 0.82 and b > 0.82:
            continue
        px[i] = r * 0.25
        px[i + 1] = min(1.0, g * 0.55 + 0.25)
        px[i + 2] = min(1.0, b * 0.35 + 0.72)


for img in bpy.data.images:
    name = img.name.lower()
    if "hair" in name and "spec" not in name and "opac" not in name:
        foreach_pixels(img, blonde)
    if name.startswith("std_eye") and "normal" not in name and "occl" not in name:
        foreach_pixels(img, blue_iris)


def tune_materials():
    for mat in bpy.data.materials:
        if not mat or not mat.node_tree:
            continue
        name = mat.name.lower()
        for node in mat.node_tree.nodes:
            if node.type != "BSDF_PRINCIPLED":
                continue
            if "cornea" in name or "tear" in name:
                node.inputs["Roughness"].default_value = 0.04
                if "Coat Weight" in node.inputs:
                    node.inputs["Coat Weight"].default_value = 1.0
            elif "skin" in name:
                node.inputs["Roughness"].default_value = 0.48
                if "Sheen Weight" in node.inputs:
                    node.inputs["Sheen Weight"].default_value = 0.35


tune_materials()


def build_dress():
    world = [body.matrix_world @ v.co for v in body.data.vertices]

    def radius_at(z, band=0.05):
        pts = [p for p in world if abs(p.z - z) < band and abs(p.x) < 0.23]
        if len(pts) < 6:
            return 0.14
        cx = sum(p.x for p in pts) / len(pts)
        cy = sum(p.y for p in pts) / len(pts)
        return max(((p.x - cx) ** 2 + (p.y - cy) ** 2) ** 0.5 for p in pts)

    levels = [1.36, 1.22, 1.08, 0.94, 0.78, 0.58, 0.38, 0.16]
    flare = [0.03, 0.04, 0.05, 0.08, 0.14, 0.22, 0.30, 0.38]
    segs = 18
    bm = bmesh.new()
    rings = []
    for z, extra in zip(levels, flare):
        rad = radius_at(z) + extra
        ring = []
        for i in range(segs):
            ang = (i / segs) * 6.283185307
            x = rad * __import__("math").cos(ang)
            y = rad * __import__("math").sin(ang) * 0.82
            ring.append(bm.verts.new((x, y, z)))
        rings.append(ring)
    bm.verts.ensure_lookup_table()
    for a, b in zip(rings, rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((a[i], b[i], b[j], a[j]))
    uv = bm.loops.layers.uv.new("UVMap")
    for face in bm.faces:
        for loop in face.loops:
            loop[uv].uv = (loop.vert.co.x * 2.5 + 0.5, loop.vert.co.z * 0.8)
    mesh = bpy.data.meshes.new("LaceDress")
    bm.to_mesh(mesh)
    bm.free()
    dress = bpy.data.objects.new("LaceDress", mesh)
    bpy.context.collection.objects.link(dress)
    mat = bpy.data.materials.new("BlackLaceDress")
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.05, 0.02, 0.03, 1)
    bsdf.inputs["Roughness"].default_value = 0.55
    if os.path.exists(LACE):
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(LACE)
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if os.path.exists(LACE_N):
        nimg = bpy.data.images.load(LACE_N)
        nimg.colorspace_settings.name = "Non-Color"
        ntex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        ntex.image = nimg
        nmap = mat.node_tree.nodes.new("ShaderNodeNormalMap")
        mat.node_tree.links.new(ntex.outputs["Color"], nmap.inputs["Color"])
        mat.node_tree.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    dress.data.materials.append(mat)
    # Skin the dress to the body so it follows the rig.
    kd_coords = [body.matrix_world @ v.co for v in body.data.vertices]
    from mathutils.kdtree import KDTree

    torso = [i for i, co in enumerate(kd_coords) if abs(co.x) < 0.26 and co.z < 1.5]
    tree = KDTree(len(torso))
    for slot, index in enumerate(torso):
        tree.insert(kd_coords[index], slot)
    tree.balance()
    keep = ("hip", "pelvis", "waist", "spine", "thigh", "calf", "foot")
    for vg in body.vertex_groups:
        if any(token in vg.name.lower() for token in keep):
            dress.vertex_groups.new(name=vg.name)
    for v in dress.data.vertices:
        _, slot, _ = tree.find(dress.matrix_world @ v.co)
        index = torso[slot]
        for g in body.data.vertices[index].groups:
            name = body.vertex_groups[g.group].name
            if name in dress.vertex_groups:
                dress.vertex_groups[name].add([v.index], g.weight, "REPLACE")
    dress.parent = arm
    dress.matrix_parent_inverse = arm.matrix_world.inverted()
    mod = dress.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    mat.use_backface_culling = False
    return dress


def twin_tails():
    mesh = bpy.data.meshes.new("TwinTails")
    bm = bmesh.new()
    import math
    for side in (-1, 1):
        prev = None
        for step in range(8):
            z = 1.55 - step * 0.09
            radius = 0.028 - step * 0.002
            y = -0.02 - step * 0.012
            x = side * (0.09 + step * 0.004)
            ring = []
            for i in range(8):
                ang = (i / 8) * math.tau
                ring.append(bm.verts.new((x + radius * math.cos(ang), y + radius * math.sin(ang), z)))
            if prev:
                for i in range(8):
                    j = (i + 1) % 8
                    bm.faces.new((prev[i], prev[j], ring[j], ring[i]))
            prev = ring
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("TwinTails", mesh)
    bpy.context.collection.objects.link(obj)
    mat = bpy.data.materials.new("BlondeTails")
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.9, 0.74, 0.34, 1)
    bsdf.inputs["Roughness"].default_value = 0.4
    obj.data.materials.append(mat)
    head = "CC_Base_Head"
    obj.vertex_groups.new(name=head)
    obj.vertex_groups[head].add([v.index for v in obj.data.vertices], 1.0, "REPLACE")
    obj.parent = arm
    obj.matrix_parent_inverse = arm.matrix_world.inverted()
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return obj


build_dress()
twin_tails()

# Drop facial shape keys. The game does not play them and they dominate the file.
for obj in list(bpy.data.objects):
    if obj.type != "MESH" or not obj.data.shape_keys:
        continue
    bpy.context.view_layer.objects.active = obj
    try:
        bpy.ops.object.shape_key_remove(all=True)
    except Exception as exc:
        print("shape key skip", obj.name, exc)


def make_lod(obj, ratio):
    copy = obj.copy()
    copy.data = obj.data.copy()
    copy.name = "low-poly-" + obj.name
    bpy.context.collection.objects.link(copy)
    if copy.parent:
        copy.parent = obj.parent
    mod = copy.modifiers.new("lod", "DECIMATE")
    mod.ratio = ratio
    bpy.context.view_layer.objects.active = copy
    try:
        bpy.ops.object.modifier_move_to_index(modifier="lod", index=0)
        bpy.ops.object.modifier_apply(modifier="lod")
    except Exception as exc:
        print("lod skip", obj.name, exc)
    return copy


for obj in list(bpy.data.objects):
    if obj.type != "MESH" or obj.name.startswith("low-poly"):
        continue
    if obj.name in ("LaceDress", "TwinTails"):
        continue
    make_lod(obj, 0.25 if len(obj.data.vertices) > 2500 else 0.5)


def author(name, keys):
    bpy.context.view_layer.objects.active = arm
    if bpy.context.object.mode != "POSE":
        bpy.ops.object.mode_set(mode="POSE")
    pb = arm.pose.bones
    ad = arm.animation_data_create()
    act = bpy.data.actions.new(name)
    ad.action = act
    for frame, poses in keys:
        for bone_name, euler in poses.items():
            bone = pb[bone_name]
            bone.rotation_mode = "XYZ"
            bone.rotation_euler = euler
            bone.keyframe_insert("rotation_euler", frame=frame)
    track = ad.nla_tracks.new()
    track.name = name
    track.strips.new(name, 1, act)
    ad.action = None
    bpy.ops.object.mode_set(mode="OBJECT")


LT, RT = "CC_Base_L_Thigh", "CC_Base_R_Thigh"
LC, RC = "CC_Base_L_Calf", "CC_Base_R_Calf"
LA, RA = "CC_Base_L_Upperarm", "CC_Base_R_Upperarm"
LF, RF = "CC_Base_L_Forearm", "CC_Base_R_Forearm"


def step(lt, rt, lc, rc, la, ra):
    return {
        LT: (lt, 0, 0),
        RT: (rt, 0, 0),
        LC: (lc, 0, 0),
        RC: (rc, 0, 0),
        LA: (la, 0, 0),
        RA: (ra, 0, 0),
        LF: (0.35, 0, 0),
        RF: (0.35, 0, 0),
    }


author(
    "Idle_Standing",
    [
        (1, {"CC_Base_Spine01": (0.02, 0, 0)}),
        (40, {"CC_Base_Spine01": (0.05, 0.02, 0), "CC_Base_Head": (0.04, 0, 0)}),
        (80, {"CC_Base_Spine01": (0.02, 0, 0)}),
    ],
)
author(
    "Walk_Relaxed",
    [
        (1, step(0.45, -0.4, 0.15, 0.35, -0.35, 0.4)),
        (9, step(0.0, 0.0, 0.85, 0.2, 0.0, 0.0)),
        (17, step(-0.4, 0.45, 0.35, 0.15, 0.4, -0.35)),
        (25, step(0.0, 0.0, 0.2, 0.85, 0.0, 0.0)),
        (33, step(0.45, -0.4, 0.15, 0.35, -0.35, 0.4)),
    ],
)
author(
    "Jog",
    [
        (1, step(0.7, -0.55, 0.35, 0.7, -0.55, 0.6)),
        (7, step(0.0, 0.0, 1.05, 0.3, 0.0, 0.0)),
        (13, step(-0.55, 0.7, 0.7, 0.35, 0.6, -0.55)),
        (19, step(0.0, 0.0, 0.3, 1.05, 0.0, 0.0)),
        (25, step(0.7, -0.55, 0.35, 0.7, -0.55, 0.6)),
    ],
)
author(
    "Run",
    [
        (1, step(0.95, -0.7, 0.45, 0.95, -0.8, 0.85)),
        (6, step(0.05, 0.0, 1.25, 0.35, 0.1, 0.0)),
        (12, step(-0.7, 0.95, 0.95, 0.45, 0.85, -0.8)),
        (18, step(0.0, 0.05, 0.35, 1.25, 0.0, 0.1)),
        (24, step(0.95, -0.7, 0.45, 0.95, -0.8, 0.85)),
    ],
)
sit = {
    LT: (1.25, 0, 0),
    RT: (1.25, 0, 0),
    LC: (1.05, 0, 0),
    RC: (1.05, 0, 0),
    LA: (0.9, 0, 0.2),
    RA: (0.9, 0, -0.2),
    LF: (0.7, 0, 0),
    RF: (0.7, 0, 0),
    "CC_Base_Spine01": (0.18, 0, 0),
}
author("Sit_Stand", [(1, sit), (12, sit)])
author(
    "Enter_Car",
    [
        (1, {}),
        (8, {LT: (0.6, 0, 0), RT: (0.6, 0, 0), LC: (0.4, 0, 0), RC: (0.4, 0, 0)}),
        (16, sit),
    ],
)
author(
    "Exit_Car",
    [
        (1, sit),
        (8, {LT: (0.5, 0, 0), RT: (0.5, 0, 0), LC: (0.3, 0, 0), RC: (0.3, 0, 0)}),
        (16, {}),
    ],
)

for block in (bpy.data.materials, bpy.data.images):
    for item in list(block):
        if item.users == 0:
            block.remove(item)

# Sensible sizes: 2K on the face and body colour, 1K everywhere else.
for img in list(bpy.data.images):
    w, h = img.size
    if not w or not h:
        continue
    lname = img.name.lower()
    limit = 2048 if ("skin_head" in lname or "skin_body" in lname) and "normal" not in lname else 1024
    if max(w, h) > limit:
        scale = limit / max(w, h)
        img.scale(max(1, int(w * scale)), max(1, int(h * scale)))
        print("scaled", img.name, img.size[:])

# Preview from the front (character faces -Y).
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT"
try:
    scene.eevee.taa_render_samples = 6
except Exception:
    pass
scene.render.resolution_x = 720
scene.render.resolution_y = 960
scene.render.filepath = PREVIEW
cam_data = bpy.data.cameras.new("Preview")
cam = bpy.data.objects.new("Preview", cam_data)
bpy.context.collection.objects.link(cam)
cam.location = (0.0, -2.8, 1.15)
target = bpy.data.objects.new("CamTarget", None)
target.location = (0.0, 0.0, 1.0)
bpy.context.collection.objects.link(target)
track = cam.constraints.new("TRACK_TO")
track.target = target
track.track_axis = "TRACK_NEGATIVE_Z"
track.up_axis = "UP_Y"
scene.camera = cam
sun = bpy.data.lights.new("Sun", "SUN")
sun.energy = 3.5
sun_obj = bpy.data.objects.new("Sun", sun)
bpy.context.collection.objects.link(sun_obj)
sun_obj.rotation_euler = (0.9, 0.2, 0.4)
bpy.context.view_layer.objects.active = arm
arm.animation_data.action = bpy.data.actions["Idle_Standing"]
scene.frame_set(1)
bpy.ops.render.render(write_still=True)
print("preview", PREVIEW)
arm.animation_data.action = bpy.data.actions["Walk_Relaxed"]
scene.frame_set(9)
scene.render.filepath = PREVIEW.replace(".png", "-walk.png")
bpy.ops.render.render(write_still=True)
print("preview", PREVIEW)

# Do not export the preview camera or the sun.
for obj in (cam, sun_obj, target):
    bpy.data.objects.remove(obj, do_unlink=True)
for mat in list(bpy.data.materials):
    if any(token in mat.name.lower() for token in ("t_shirt", "denim", "underwear", "shorts")):
        bpy.data.materials.remove(mat)
for img in list(bpy.data.images):
    if img.users == 0:
        bpy.data.images.remove(img)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format="GLB",
    export_animations=True,
    export_animation_mode="ACTIONS",
    export_yup=True,
    export_image_format="JPEG",
    export_jpeg_quality=82,
    export_skins=True,
    export_morph=False,
    export_lights=False,
    export_cameras=False,
)
print("EXPORTED", OUT, os.path.getsize(OUT))
