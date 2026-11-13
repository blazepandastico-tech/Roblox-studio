"""StudVox Blender pipeline: build, render and export a baked ``.svox.json`` model.

Run with Blender::

    blender -b --python blender/studvox_blender.py -- --model out/x/x.svox.json --out out/x --render --export

or with the ``bpy`` Python module (``pip install bpy``)::

    python blender/studvox_blender.py --model ... --out ... --render --export

What it does
------------
* one mesh object per rig part: merged voxel faces (coplanar same-colour faces
  dissolved), flat studs on open top faces (bump-shaded in renders, a stud
  tile per voxel in the exported texture atlas) and an inverted-hull black
  outline shell
* armature with one bone per part, every mesh rigidly skinned to its bone
* one action per clip, baked from the model's frames
* Cycles renders: hero 3/4 shot, front / side / back orthographic views, poses
* exports: FBX (rig + all clips), one FBX per clip (animation import), GLB,
  OBJ, palette texture; meshes are split to stay under the triangle limit
* ``stats.json`` with triangle counts, sizes and file names
"""

from __future__ import annotations

import argparse
import json
import warnings
import math
import sys
import time
from pathlib import Path

import bpy
import bmesh
from mathutils import Euler, Matrix, Vector

warnings.filterwarnings("ignore", category=DeprecationWarning)
REPO = Path(__file__).resolve().parent.parent
if str(REPO) not in sys.path:
    sys.path.insert(0, str(REPO))

import numpy as np  # noqa: E402

from studvox.mesher import ModelGeometry  # noqa: E402
from studvox.palette import parse_hex, srgb_to_linear  # noqa: E402

B = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))  # author (x right, y up, z front) -> Blender (z up, front = -Y)
B_np = np.array(B)
PALETTE_CELLS = 16
PALETTE_CELL_PX = 32
OUTLINE_CELL = PALETTE_CELLS * PALETTE_CELLS - 1
TRI_LIMIT = 10000


def log(*a):
    print("[studvox]", *a, flush=True)


# ---------------------------------------------------------------------------- args

def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--model", required=True, help="baked .svox.json")
    ap.add_argument("--out", required=True, help="output directory")
    ap.add_argument("--render", action="store_true")
    ap.add_argument("--export", action="store_true")
    ap.add_argument("--blend", action="store_true", help="save the render scene as <name>.blend")
    ap.add_argument("--quick", action="store_true", help="fast low-quality renders for iteration")
    ap.add_argument("--samples", type=int, default=0)
    ap.add_argument("--size", type=int, default=0, help="hero render size in pixels")
    ap.add_argument("--gif", action="store_true", help="also render looping clip frames for an animated GIF")
    ap.add_argument("--no-poses", action="store_true")
    ap.add_argument("--hero-only", action="store_true", help="render only the hero shot (fast catalogues)")
    return ap.parse_args(argv)


# ---------------------------------------------------------------------------- helpers

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    sc.unit_settings.scale_length = 1.0
    sc.render.fps = 24
    return sc


def hex_lin(hx):
    r, g, b = parse_hex(hx)
    return (srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b), 1.0)


def a2b(v):
    return Vector((v[0], -v[2], v[1]))


def stud_tile(rgb, n):
    """Flat stud tile (n x n, rows bottom->top, columns = +x, rows = +z), baked light from front-left."""
    a = (np.arange(n) + 0.5) / n
    X, Z = np.meshgrid(a, a)           # X across columns (+x), Z down rows (+z)
    px, pz = X - 0.5, Z - 0.5
    r = np.sqrt(px * px + pz * pz)
    R, w = 0.30, 0.025
    disc = np.clip((R + w - r) / (2 * w), 0, 1)
    ring = np.clip(1 - np.abs(r - R) / 0.045, 0, 1)
    # light from -x (left) and +z (front): rim facing the light is brighter
    ang = np.where(r > 1e-6, (-px + pz) / np.maximum(r, 1e-6) / math.sqrt(2), 0)
    base = np.asarray(rgb, dtype=np.float64) / 255.0
    shade = 1.0 + 0.07 * disc + ring * (0.22 * np.clip(ang, 0, 1) - 0.30 * np.clip(-ang, 0, 1)) - 0.06 * ring
    col = np.clip(base[None, None, :] * shade[..., None] + 0.05 * (ring * np.clip(ang, 0, 1))[..., None], 0, 1)
    return col


def atlas_cell(color_index, studded):
    return 2 * color_index + (1 if studded else 0)


def make_palette_image(model, out_dir: Path | None):
    """Texture atlas: per colour a flat cell and a stud-tile cell; the last cell is the outline black."""
    n = PALETTE_CELLS * PALETTE_CELL_PX
    px = np.zeros((n, n, 4), dtype=np.float32)
    px[..., 3] = 1.0
    c = PALETTE_CELL_PX

    def put(cell, block):
        cx, cy = cell % PALETTE_CELLS, cell // PALETTE_CELLS
        y0 = n - (cy + 1) * c          # Blender pixel rows start at the bottom
        px[y0:y0 + c, cx * c:(cx + 1) * c, :3] = block

    for i, e in enumerate(model["palette"]):
        rgb = parse_hex(e["hex"])
        put(atlas_cell(i, False), np.asarray(rgb, dtype=np.float32) / 255.0)
        put(atlas_cell(i, True), stud_tile(rgb, c))
    put(OUTLINE_CELL, np.array([0.07, 0.07, 0.08], dtype=np.float32))
    img = bpy.data.images.new(f"{model['name']}_palette", n, n, alpha=False)
    img.colorspace_settings.name = "sRGB"
    img.pixels.foreach_set(px.ravel())
    if out_dir is not None:
        path = out_dir / f"{model['name']}_palette.png"
        img.filepath_raw = str(path)
        img.file_format = "PNG"
        img.save()
    return img


# ---------------------------------------------------------------------------- materials

def principled(mat):
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (-300, 0)
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return nt, bsdf, out


def set_input(node, names, value):
    for n in names if isinstance(names, (list, tuple)) else [names]:
        if n in node.inputs:
            node.inputs[n].default_value = value
            return True
    return False


def _math(nt, op, a, b=None, *, clamp=False):
    m = nt.nodes.new("ShaderNodeMath")
    m.operation = op
    m.use_clamp = clamp
    for i, v in enumerate((a, b)):
        if v is None:
            continue
        if isinstance(v, (int, float)):
            m.inputs[i].default_value = v
        else:
            nt.links.new(v, m.inputs[i])
    return m.outputs[0]


def _map(nt, v, a, b, c, d):
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.interpolation_type = "SMOOTHSTEP"
    mr.clamp = True
    nt.links.new(v, mr.inputs["Value"])
    mr.inputs["From Min"].default_value = a
    mr.inputs["From Max"].default_value = b
    mr.inputs["To Min"].default_value = c
    mr.inputs["To Max"].default_value = d
    return mr.outputs["Result"]


def add_stud_shading(nt, bsdf, base_color, voxel_size):
    """Flat stud look on top faces (StudUV), like Roblox's Studs surface: no extra geometry."""
    uvn = nt.nodes.new("ShaderNodeUVMap")
    uvn.uv_map = "StudUV"
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uvn.outputs["UV"], sep.inputs[0])
    u, v = sep.outputs[0], sep.outputs[1]
    off = _math(nt, "GREATER_THAN", u, 5000.0)                 # 1 = no stud on this face
    on = _math(nt, "SUBTRACT", 1.0, off)
    fu = _math(nt, "SUBTRACT", _math(nt, "FRACT", u), 0.5)
    fv = _math(nt, "SUBTRACT", _math(nt, "FRACT", v), 0.5)
    r = _math(nt, "SQRT", _math(nt, "ADD", _math(nt, "MULTIPLY", fu, fu), _math(nt, "MULTIPLY", fv, fv)))
    disc = _math(nt, "MULTIPLY", _map(nt, r, 0.275, 0.315, 1.0, 0.0), on)
    ring = _math(nt, "MULTIPLY", _math(nt, "MULTIPLY", _map(nt, r, 0.24, 0.29, 0.0, 1.0),
                                       _map(nt, r, 0.29, 0.335, 1.0, 0.0)), on)
    # light comes from the front-left (-x, +z): rim facing it is lit, the opposite rim is shaded
    inv_r = _math(nt, "DIVIDE", 0.7071, _math(nt, "MAXIMUM", r, 1e-4))
    ang = _math(nt, "MULTIPLY", _math(nt, "SUBTRACT", fv, fu), inv_r)
    hi = _math(nt, "MULTIPLY", ring, _math(nt, "MAXIMUM", ang, 0.0))
    lo = _math(nt, "MULTIPLY", ring, _math(nt, "MAXIMUM", _math(nt, "MULTIPLY", ang, -1.0), 0.0))
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.8
    bump.inputs["Distance"].default_value = 0.1 * voxel_size
    nt.links.new(disc, bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    # baked rim shading so studs read like Roblox's flat Studs surface in any light
    k = _math(nt, "ADD", 1.0, _math(nt, "MULTIPLY", hi, 0.32))
    k = _math(nt, "SUBTRACT", k, _math(nt, "MULTIPLY", lo, 0.42))
    k = _math(nt, "SUBTRACT", k, _math(nt, "MULTIPLY", ring, 0.08))
    k = _math(nt, "ADD", k, _math(nt, "MULTIPLY", disc, 0.05))
    rgb = nt.nodes.new("ShaderNodeRGB")
    rgb.outputs[0].default_value = base_color
    mul = nt.nodes.new("ShaderNodeVectorMath")
    mul.operation = "SCALE"
    nt.links.new(rgb.outputs[0], mul.inputs[0])
    nt.links.new(k, mul.inputs["Scale"])
    nt.links.new(mul.outputs[0], bsdf.inputs["Base Color"])


def render_material(entry, voxel_size):
    mat = bpy.data.materials.new(f"sv_{entry['name']}")
    nt, bsdf, _ = principled(mat)
    col = hex_lin(entry["hex"])
    bsdf.inputs["Base Color"].default_value = col
    m = entry["material"]
    rough = {"plastic": 0.3, "matte": 0.72, "metal": 0.32, "glow": 0.5, "glass": 0.04, "water": 0.08}[m]
    bsdf.inputs["Roughness"].default_value = rough
    set_input(bsdf, ["Specular IOR Level", "Specular"], 0.55 if m == "plastic" else 0.4)
    if m == "plastic":
        set_input(bsdf, ["Coat Weight"], 0.06)
        set_input(bsdf, ["Coat Roughness"], 0.2)
    if m == "metal":
        bsdf.inputs["Metallic"].default_value = 0.85
    if m == "glow":
        set_input(bsdf, ["Emission Color", "Emission"], col)
        set_input(bsdf, ["Emission Strength"], 2.5)
    if m in ("glass", "water"):
        set_input(bsdf, ["Transmission Weight", "Transmission"], 0.92 if m == "glass" else 0.75)
        set_input(bsdf, ["IOR"], 1.33 if m == "water" else 1.45)
    if m not in ("glow", "glass", "water"):
        add_stud_shading(nt, bsdf, col, voxel_size)
    mat.diffuse_color = col
    return mat


def outline_material():
    mat = bpy.data.materials.new("sv_outline")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    mix = nt.nodes.new("ShaderNodeMixShader")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (0.012, 0.012, 0.014, 1.0)
    em.inputs["Strength"].default_value = 1.0
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    nt.links.new(geo.outputs["Backfacing"], mix.inputs["Fac"])
    nt.links.new(em.outputs["Emission"], mix.inputs[1])
    nt.links.new(tr.outputs["BSDF"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])
    mat.diffuse_color = (0, 0, 0, 1)
    try:
        mat.use_backface_culling = True
    except AttributeError:
        pass
    return mat


def export_material(img):
    mat = bpy.data.materials.new("StudVoxPalette")
    nt, bsdf, _ = principled(mat)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    tex.location = (-650, 0)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.4
    return mat


# ---------------------------------------------------------------------------- geometry

def build_part_geometry(geo: ModelGeometry, model, part, *, outline: float):
    """Return (surface_mesh_data, hull_mesh_data) as numpy arrays in voxel/author units."""
    surf = geo.surface(part["name"])
    main = {"verts": surf["verts"], "quads": surf["quads"], "colors": surf["color"], "stud": surf["stud"]}
    hull = None
    if outline and outline > 0 and len(surf["quads"]):
        hl = geo.hull(surf, outline)
        hull = {"verts": hl["verts"], "quads": hl["quads"], "colors": np.zeros(len(hl["quads"]), dtype=np.int32),
                "stud": np.zeros(len(hl["quads"]), dtype=bool)}
    return main, hull


def to_blender_coords(verts, model):
    o = np.asarray(model["origin"], dtype=np.float64)
    vs = float(model["voxel_size"])
    p = (np.asarray(verts, dtype=np.float64) - o) * vs
    return p @ B_np.T


CORNER_AB = np.array([[0, 0], [0, 1], [1, 1], [1, 0]], dtype=np.float64)  # (x-frac, z-frac) of top-face corners


def make_mesh_object(name, data, model, *, materials, mode, hull=False, coll=None):
    """mode 'render': per-colour materials + StudUV; mode 'export': one atlas material, stud tiles per voxel."""
    verts = to_blender_coords(data["verts"], model)
    quads = np.asarray(data["quads"], dtype=np.int64)
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts.tolist(), [], quads.tolist())
    for m in materials:
        me.materials.append(m)
    nf = len(me.polygons)
    colors = np.asarray(data["colors"], dtype=np.int32)[:nf]
    stud = np.asarray(data["stud"], dtype=bool)[:nf]
    if len(materials) > 1:
        me.polygons.foreach_set("material_index", colors.tolist())
    me.polygons.foreach_set("use_smooth", [False] * nf)
    # every face is a quad straight from the voxel mesher: loop 4i+k is corner k of face i
    corner_xyz = np.asarray(data["verts"], dtype=np.float64)[quads]          # (F,4,3) author voxel units
    if mode == "export":
        uv = me.uv_layers.new(name="UVMap")
        if hull:
            cell = np.full(nf, OUTLINE_CELL)
        else:
            cell = 2 * colors + stud.astype(np.int64)
        cu0 = (cell % PALETTE_CELLS) / PALETTE_CELLS
        cv0 = 1.0 - (cell // PALETTE_CELLS + 1) / PALETTE_CELLS
        cw = 1.0 / PALETTE_CELLS
        inset = 0.5 / PALETTE_CELL_PX
        ab = np.where(stud[:, None, None], CORNER_AB[None], 0.5)          # flat faces sample the cell centre
        ab = inset + ab * (1 - 2 * inset)
        uvs = np.stack([cu0[:, None] + ab[..., 0] * cw, cv0[:, None] + ab[..., 1] * cw], axis=-1)
        uv.data.foreach_set("uv", uvs.reshape(-1).astype(np.float32))
    else:
        uv = me.uv_layers.new(name="StudUV")
        su = corner_xyz[..., 0] + 0.5
        sv = corner_xyz[..., 2] + 0.5
        offset = np.where(stud, 0.0, 10000.0)[:, None]
        uvs = np.stack([su + offset, sv + offset], axis=-1)
        uv.data.foreach_set("uv", uvs.reshape(-1).astype(np.float32))
    me.uv_layers.active = uv
    me.update()
    bm = bmesh.new()
    bm.from_mesh(me)
    dissolve_op = getattr(bmesh.ops, "dissolve_limit", None) or getattr(bmesh.ops, "dissolve_limited")
    dissolve_op(bm, angle_limit=math.radians(0.5), use_dissolve_boundaries=False,
                verts=bm.verts[:], edges=bm.edges[:], delimit={"MATERIAL", "UV"})
    bm.to_mesh(me)
    bm.free()
    me.update()
    ob = bpy.data.objects.new(name, me)
    (coll or bpy.context.scene.collection).objects.link(ob)
    return ob


def tri_count(ob):
    me = ob.data
    me.calc_loop_triangles()
    return len(me.loop_triangles)


def split_by_tris(ob, limit=TRI_LIMIT):
    """Split a mesh object into chunks of at most ``limit`` triangles (Roblox mesh limit)."""
    total = tri_count(ob)
    if total <= limit:
        return [ob]
    me = ob.data
    n = len(me.polygons)
    cent = np.zeros(n * 3)
    me.polygons.foreach_get("center", cent)
    cent = cent.reshape(-1, 3)
    totals = np.zeros(n, dtype=np.int64)
    me.polygons.foreach_get("loop_total", totals)
    tris = totals - 2
    axis = int(np.argmax(cent.max(axis=0) - cent.min(axis=0)))
    order = np.argsort(cent[:, axis], kind="stable")
    chunk_of = np.zeros(n, dtype=np.int64)
    acc, k = 0, 0
    for fi in order:
        if acc + tris[fi] > limit and acc > 0:
            k += 1
            acc = 0
        chunk_of[fi] = k
        acc += tris[fi]
    pieces = []
    for c in range(k + 1):
        nob = ob.copy()
        nob.data = ob.data.copy()
        nob.name = f"{ob.name}_{c + 1}"
        for col in ob.users_collection:
            col.objects.link(nob)
        bm = bmesh.new()
        bm.from_mesh(nob.data)
        bm.faces.ensure_lookup_table()
        kill = [f for f in bm.faces if chunk_of[f.index] != c]
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        bm.to_mesh(nob.data)
        bm.free()
        pieces.append(nob)
    bpy.data.objects.remove(ob, do_unlink=True)
    return pieces


def auto_outline(model):
    o = model.get("outline", "auto")
    if o != "auto":
        return float(o)
    lo, hi = np.asarray(model["bounds"][0]), np.asarray(model["bounds"][1])
    ext = float((hi - lo + 1).max())
    return float(min(max(0.11, 0.0048 * ext), 0.4))


# ---------------------------------------------------------------------------- scene build

def build(model, *, mode: str, out_dir: Path):
    """mode: 'render' (per-colour materials, procedural flat studs) or 'export' (atlas texture)."""
    sc = bpy.context.scene
    geo = ModelGeometry(model)
    outline = auto_outline(model)
    vs = float(model["voxel_size"])
    rigged = bool(model.get("clips"))

    if mode == "render":
        mats = [render_material(e, vs) for e in model["palette"]]
        hull_mats = [outline_material()]
        img = None
    else:
        img = make_palette_image(model, out_dir)
        pm = export_material(img)
        mats = [pm]
        hull_mats = [pm]

    arm = None
    if rigged:
        arm_data = bpy.data.armatures.new(f"{model['name']}_rig")
        arm = bpy.data.objects.new(f"{model['name']}_rig", arm_data)
        sc.collection.objects.link(arm)
        bpy.context.view_layer.objects.active = arm
        arm.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        o = np.asarray(model["origin"])
        for p in model["parts"]:
            eb = arm_data.edit_bones.new(p["name"])
            head = a2b((np.asarray(p["pivot"]) - o) * vs)
            eb.head = head
            eb.tail = head + Vector((0, max(vs, 0.1), 0))
            eb.roll = 0.0
        for p in model["parts"]:
            if p["parent"]:
                arm_data.edit_bones[p["name"]].parent = arm_data.edit_bones[p["parent"]]
                arm_data.edit_bones[p["name"]].use_connect = False
        bpy.ops.object.mode_set(mode="OBJECT")
        arm.select_set(False)
        for pb in arm.pose.bones:
            pb.rotation_mode = "QUATERNION"

    objects, hulls = [], []
    stats_parts = {}
    for p in model["parts"]:
        main, hull = build_part_geometry(geo, model, p, outline=outline)
        ob = make_mesh_object(p["name"], main, model, materials=mats, mode=mode)
        stats_parts[p["name"]] = {"tris": tri_count(ob)}
        objects.append(ob)
        hob = None
        if hull is not None:
            hob = make_mesh_object(f"{p['name']}_outline", hull, model, materials=hull_mats, mode=mode, hull=True)
            stats_parts[p["name"]]["outline_tris"] = tri_count(hob)
            hulls.append(hob)
        for o_ in (ob, hob):
            if o_ is None:
                continue
            if arm is not None:
                vg = o_.vertex_groups.new(name=p["name"])
                vg.add(list(range(len(o_.data.vertices))), 1.0, "REPLACE")
                mod = o_.modifiers.new("Armature", "ARMATURE")
                mod.object = arm
                o_.parent = arm
    if mode == "render":
        for h in hulls:
            for attr in ("visible_diffuse", "visible_glossy", "visible_transmission", "visible_volume_scatter",
                         "visible_shadow"):
                if hasattr(h, attr):
                    setattr(h, attr, False)

    actions = {}
    if arm is not None:
        arm.animation_data_create()
        bones = [p["name"] for p in model["parts"]]
        for clip in model["clips"]:
            act = bpy.data.actions.new(clip["name"])
            act.use_fake_user = True
            arm.animation_data.action = act
            n = clip["frames"]
            for bname in bones:
                pb = arm.pose.bones[bname]
                rows = clip["tracks"].get(bname)
                frames = range(n) if rows else (0, n - 1)
                prev = None
                for f in frames:
                    if rows:
                        px, py, pz, rx, ry, rz = rows[f]
                    else:
                        px = py = pz = rx = ry = rz = 0.0
                    pb.location = a2b((px * vs, py * vs, pz * vs))
                    ra = Euler((math.radians(rx), math.radians(ry), math.radians(rz)), "XYZ").to_matrix()
                    q = (B @ ra @ B.transposed()).to_quaternion()
                    if prev is not None and prev.dot(q) < 0:
                        q.negate()
                    prev = q.copy()
                    pb.rotation_quaternion = q
                    pb.keyframe_insert("location", frame=f)
                    pb.keyframe_insert("rotation_quaternion", frame=f)
            actions[clip["name"]] = act
        # rest pose by default
        arm.animation_data.action = None
        for pb in arm.pose.bones:
            pb.location = (0, 0, 0)
            pb.rotation_quaternion = (1, 0, 0, 0)

    return {"arm": arm, "objects": objects, "hulls": hulls, "actions": actions, "parts": stats_parts,
            "outline": outline, "image": img}


def world_points(objs, limit=6000):
    pts = []
    dg = bpy.context.evaluated_depsgraph_get()
    for ob in objs:
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        mw = ob.matrix_world
        co = np.zeros(len(me.vertices) * 3)
        me.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        if len(co):
            pts.append(co @ np.array(mw.to_3x3()).T + np.array(mw.translation))
        ev.to_mesh_clear()
    if not pts:
        return np.zeros((1, 3))
    allp = np.concatenate(pts)
    if len(allp) > limit:
        allp = allp[np.linspace(0, len(allp) - 1, limit).astype(np.int64)]
    return allp


def world_bounds(objs):
    allp = world_points(objs, limit=10 ** 9)
    return Vector(allp.min(axis=0)), Vector(allp.max(axis=0))


# ---------------------------------------------------------------------------- rendering

def setup_render(sc, *, samples):
    sc.render.engine = "CYCLES"
    cy = sc.cycles
    cy.device = "CPU"
    cy.samples = samples
    cy.use_adaptive_sampling = True
    cy.adaptive_threshold = 0.02
    cy.use_denoising = True
    try:
        cy.denoiser = "OPENIMAGEDENOISE"
    except Exception:
        pass
    cy.max_bounces = 6
    cy.diffuse_bounces = 2
    cy.glossy_bounces = 2
    cy.transmission_bounces = 6
    cy.transparent_max_bounces = 24
    cy.caustics_reflective = False
    cy.caustics_refractive = False
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.view_settings.exposure = 0.0
    try:
        sc.render.threads_mode = "AUTO"
    except Exception:
        pass

    world = bpy.data.worlds.new("sv_world")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.78, 0.86, 1.0, 1.0)
    bg.inputs["Strength"].default_value = 0.38

    def sun(name, direction_author, strength, angle):
        ld = bpy.data.lights.new(name, "SUN")
        ld.energy = strength
        ld.angle = angle
        ob = bpy.data.objects.new(name, ld)
        sc.collection.objects.link(ob)
        d = a2b(direction_author).normalized()   # direction towards the light
        ob.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        return ob

    sun("key", (-0.45, 1.0, 0.55), 2.9, math.radians(10))
    k = sun("fill", (0.95, 0.3, 0.55), 0.9, math.radians(30))
    try:
        k.data.use_shadow = False
    except AttributeError:
        pass
    rim = sun("rim", (0.3, 0.8, -1.0), 1.7, math.radians(10))
    try:
        rim.data.use_shadow = False
    except AttributeError:
        pass


def add_shadow_catcher(sc, bmin, bmax):
    size = max(bmax.x - bmin.x, bmax.y - bmin.y) * 6 + 2
    me = bpy.data.meshes.new("ground")
    s = size / 2
    me.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
    ob = bpy.data.objects.new("ground", me)
    sc.collection.objects.link(ob)
    ob.location = ((bmin.x + bmax.x) / 2, (bmin.y + bmax.y) / 2, bmin.z)
    ob.is_shadow_catcher = True
    return ob


def view_dir(az_deg, el_deg):
    """Author-space direction from the model towards the camera."""
    az, el = math.radians(az_deg), math.radians(el_deg)
    return (math.sin(az) * math.cos(el), math.sin(el), math.cos(az) * math.cos(el))


def frame_camera(cam, pts, d_author, *, ortho: bool, margin: float = 1.12):
    """Aim the camera along ``d_author`` and fit the point cloud ``pts`` (N,3) tightly."""
    pts = np.asarray(pts, dtype=np.float64)
    d = a2b(d_author).normalized()
    fwd = -d
    up_w = Vector((0, 0, 1)) if abs(fwd.z) < 0.98 else Vector((0, 1, 0))
    right = fwd.cross(up_w).normalized()
    up = right.cross(fwd).normalized()
    R, U, D = (np.array(v) for v in (right, up, d))
    center = pts.mean(axis=0)
    rel = pts - center
    xs, ys, depth = rel @ R, rel @ U, rel @ D
    cx, cy = (xs.max() + xs.min()) / 2, (ys.max() + ys.min()) / 2
    hx, hy = (xs.max() - xs.min()) / 2, (ys.max() - ys.min()) / 2
    target = Vector(center + R * cx + U * cy)
    cam.data.clip_start = 0.01
    if ortho:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 2 * max(hx, hy) * margin
        dist = float(depth.max()) + 10.0 * max(hx, hy, 1.0)
    else:
        cam.data.type = "PERSP"
        cam.data.sensor_fit = "AUTO"
        cam.data.lens = 50
        t = math.tan(cam.data.angle / 2)
        need = depth + np.maximum(np.abs(xs - cx), np.abs(ys - cy)) * margin / t
        dist = float(need.max())
    cam.location = target + d * dist
    cam.rotation_euler = fwd.to_track_quat("-Z", "Y").to_euler()
    cam.data.clip_end = dist * 4 + 100


def render_to(sc, path: Path, size: int, samples: int):
    sc.render.resolution_x = size
    sc.render.resolution_y = size
    sc.render.resolution_percentage = 100
    sc.cycles.samples = samples
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def set_pose(built, clip_name, frame):
    arm = built["arm"]
    if arm is None:
        return
    arm.animation_data.action = built["actions"][clip_name] if clip_name else None
    if clip_name is None:
        for pb in arm.pose.bones:
            pb.location = (0, 0, 0)
            pb.rotation_quaternion = (1, 0, 0, 0)
    bpy.context.scene.frame_set(int(frame))


def do_render(model, built, out_dir: Path, args):
    sc = bpy.context.scene
    rd = out_dir / "renders"
    rd.mkdir(parents=True, exist_ok=True)
    quick = args.quick
    hero_size = args.size or (512 if quick else 1024)
    view_size = 320 if quick else 560
    pose_size = 256 if quick else 420
    samples = args.samples or (8 if quick else 40)
    setup_render(sc, samples=samples)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    objs = built["objects"] + built["hulls"]
    pts = world_points(objs)
    gmin, gmax = world_bounds(built["objects"])
    ground = add_shadow_catcher(sc, gmin, gmax)
    files = {}
    t0 = time.time()
    hero_dir = view_dir(32, 24)
    if model["category"] == "eggs":
        hero_dir = view_dir(28, 16)
    if model["category"] in ("terrain", "buildings"):
        hero_dir = view_dir(35, 32)
    if model["category"] == "weapons":
        hero_dir = view_dir(28, 18)

    frame_camera(cam, pts, hero_dir, ortho=False, margin=1.25)
    render_to(sc, rd / "hero.png", hero_size, samples)
    files["hero"] = "renders/hero.png"

    ground.hide_render = True
    views = {"front": view_dir(0, 0), "side": view_dir(-90, 0), "back": view_dir(180, 0)}
    if args.hero_only:
        views = {}
    if model["category"] in ("terrain", "buildings"):
        views["top"] = (0.0, 1.0, 0.0001)
    for vname, vd in views.items():
        frame_camera(cam, pts, vd, ortho=True, margin=1.08)
        render_to(sc, rd / f"{vname}.png", view_size, max(8, samples // 2))
        files[vname] = f"renders/{vname}.png"

    poses = []
    if built["arm"] is not None and not args.no_poses and not args.hero_only:
        ground.hide_render = False
        # union of bounds over the poses so framing doesn't jump
        for clip in model["clips"][:3]:
            n = clip["frames"]
            f = int(n * (0.25 if clip["loop"] else 0.3))
            set_pose(built, clip["name"], f)
            frame_camera(cam, world_points(objs), hero_dir, ortho=False, margin=1.25)
            p = rd / f"pose_{clip['name']}.png"
            render_to(sc, p, pose_size, max(8, samples // 2))
            poses.append({"clip": clip["name"], "frame": f, "file": f"renders/pose_{clip['name']}.png"})
        set_pose(built, None, 0)
    files["poses"] = poses

    if args.gif and built["arm"] is not None and model["clips"]:
        ground.hide_render = False
        clip = model["clips"][0]
        gif_dir = rd / "gif"
        gif_dir.mkdir(exist_ok=True)
        n = clip["frames"] - 1 if clip["loop"] else clip["frames"]
        step = max(1, n // 16)
        frame_camera(cam, pts, hero_dir, ortho=False, margin=1.3)
        gif_frames = []
        for i, f in enumerate(range(0, n, step)):
            set_pose(built, clip["name"], f)
            p = gif_dir / f"f{i:03d}.png"
            render_to(sc, p, 320, max(6, samples // 4))
            gif_frames.append(f"renders/gif/f{i:03d}.png")
        set_pose(built, None, 0)
        files["gif_frames"] = gif_frames
        files["gif_fps"] = clip["fps"] / step
    log(f"renders done in {time.time() - t0:.1f}s")
    return files


# ---------------------------------------------------------------------------- export

def select_only(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    if objs:
        bpy.context.view_layer.objects.active = objs[0]


def do_export(model, built, out_dir: Path):
    name = model["name"]
    files = {}
    arm = built["arm"]
    meshes = built["objects"] + built["hulls"]
    if arm is None and len(built["objects"]) > 1:
        # static model: join parts into one mesh and one outline mesh
        def join(objs, new_name):
            select_only(objs)
            bpy.ops.object.join()
            ob = bpy.context.view_layer.objects.active
            ob.name = new_name
            ob.data.name = new_name
            return ob
        main = join(built["objects"], name)
        hull = join(built["hulls"], f"{name}_outline") if built["hulls"] else None
        meshes = [main] + ([hull] if hull else [])
    chunked = []
    for ob in meshes:
        chunked.extend(split_by_tris(ob))
    meshes = chunked
    tris = sum(tri_count(o) for o in meshes)

    objs = meshes + ([arm] if arm else [])
    select_only(objs)
    fbx = out_dir / f"{name}.fbx"
    common = dict(use_selection=True, object_types={"ARMATURE", "MESH"}, use_mesh_modifiers=True,
                  mesh_smooth_type="FACE", use_triangles=True, add_leaf_bones=False, primary_bone_axis="Y",
                  secondary_bone_axis="X", axis_forward="Z", axis_up="Y", path_mode="COPY", embed_textures=True,
                  apply_unit_scale=True, global_scale=1.0)
    if arm is not None:
        bpy.ops.export_scene.fbx(filepath=str(fbx), bake_anim=True, bake_anim_use_all_actions=True,
                                 bake_anim_use_nla_strips=False, bake_anim_force_startend_keying=True,
                                 bake_anim_simplify_factor=0.0, **common)
    else:
        bpy.ops.export_scene.fbx(filepath=str(fbx), bake_anim=False, **common)
    files["fbx"] = fbx.name

    if arm is not None and built["actions"]:
        ad = out_dir / "anims"
        ad.mkdir(exist_ok=True)
        files["anim_fbx"] = {}
        for cname, act in built["actions"].items():
            arm.animation_data.action = act
            select_only([arm])
            p = ad / f"{name}_{cname}.fbx"
            c2 = dict(common)
            c2["object_types"] = {"ARMATURE"}
            c2["embed_textures"] = False
            bpy.ops.export_scene.fbx(filepath=str(p), bake_anim=True, bake_anim_use_all_actions=False,
                                     bake_anim_use_nla_strips=False, bake_anim_force_startend_keying=True,
                                     bake_anim_simplify_factor=0.0, **c2)
            files["anim_fbx"][cname] = f"anims/{p.name}"
        arm.animation_data.action = None

    select_only(objs)
    glb = out_dir / f"{name}.glb"
    gl_kw = dict(filepath=str(glb), export_format="GLB", use_selection=True, export_apply=False,
                 export_animations=arm is not None, export_yup=True)
    try:
        bpy.ops.export_scene.gltf(export_animation_mode="ACTIONS", **gl_kw)
    except TypeError:
        bpy.ops.export_scene.gltf(**gl_kw)
    files["glb"] = glb.name

    select_only(meshes)
    obj = out_dir / f"{name}.obj"
    bpy.ops.wm.obj_export(filepath=str(obj), export_selected_objects=True, export_materials=True,
                          path_mode="COPY", forward_axis="Z", up_axis="Y", export_triangulated_mesh=True,
                          apply_modifiers=False, export_animation=False)
    files["obj"] = obj.name
    files["palette"] = f"{name}_palette.png"
    return files, {"tris_total": tris, "objects": [o.name for o in meshes], "chunks": len(meshes)}


# ---------------------------------------------------------------------------- main

def main():
    args = parse_args()
    model = json.load(open(args.model, encoding="utf-8"))
    out_dir = Path(args.out).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    stats_path = out_dir / "stats.json"
    stats = json.load(open(stats_path)) if stats_path.exists() else {}
    t0 = time.time()
    vs = model["voxel_size"]
    lo, hi = np.asarray(model["bounds"][0]), np.asarray(model["bounds"][1])
    dims = (hi - lo + 1)
    stats.update({
        "name": model["name"], "title": model["title"], "category": model["category"],
        "voxel_size": vs, "voxels_dims": dims.tolist(),
        "size_studs": [round(float(v) * vs, 2) for v in dims],
        "parts": len(model["parts"]), "clips": [c["name"] for c in model["clips"]],
        "palette": [{"name": e["name"], "hex": e["hex"], "material": e["material"]} for e in model["palette"]],
    })
    geo = ModelGeometry(model)
    stats.update(geo.counts())

    if args.render:
        reset_scene()
        built = build(model, mode="render", out_dir=out_dir)
        stats["render_tris"] = sum(v["tris"] + v.get("outline_tris", 0) for v in built["parts"].values())
        stats["outline_render"] = built["outline"]
        stats["renders"] = do_render(model, built, out_dir, args)
        if args.blend:
            bpy.ops.wm.save_as_mainfile(filepath=str(out_dir / f"{model['name']}.blend"), compress=True)
            stats["blend"] = f"{model['name']}.blend"

    if args.export:
        reset_scene()
        built = build(model, mode="export", out_dir=out_dir)
        files, info = do_export(model, built, out_dir)
        stats["exports"] = files
        stats["export_tris"] = info["tris_total"]
        stats["export_meshes"] = info["objects"]
        stats["export_tris_by_part"] = {k: v["tris"] for k, v in built["parts"].items()}
        stats["export_outline_tris_by_part"] = {k: v.get("outline_tris", 0) for k, v in built["parts"].items()}
        stats["bones"] = len(model["parts"]) if built["arm"] is not None else 0

    stats["blender_version"] = bpy.app.version_string
    with open(stats_path, "w") as f:
        json.dump(stats, f, indent=1)
    log(f"{model['name']} done in {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
