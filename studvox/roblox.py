"""Roblox exporters (pure Python, no Studio or Blender needed).

* ``<name>.rbxmx``  drag-and-drop model file for Roblox Studio. Built from
  ordinary Parts (greedy-merged boxes), so it needs no mesh upload:

  - animated models: ``Root`` part + one invisible joint part per rig part,
    connected with Motor6Ds; visible boxes are welded to their joint. The
    model ships with ``StudVoxelAnimator`` + ``Clips`` ModuleScripts and an
    ``Animate`` client Script that plays the clip named in the ``Clip``
    StringValue (change it from the server to switch clips).
  - static models (buildings, props, terrain): anchored boxes.
  - weapons: a ``Tool`` with a ``Handle`` at the grip point.

  Studs use Roblox's native surfaces: ``TopSurface = Studs`` and
  ``BottomSurface = Inlet`` (or ``Universal`` on top) on **Plastic** parts -
  the only material those surface textures render on. The texture shows one
  stud per stud of world size, so with 1-stud voxels every voxel gets exactly
  one stud. For smaller voxels the ``texture`` mode tiles an uploaded stud
  image (``roblox/assets/stud_tile.png``) once per voxel instead.
  A ``Highlight`` gives the black outline.

* ``<name>.luau``   ModuleScript data (geometry + clips) for building models at
  runtime with ``roblox/StudVoxelBuilder.luau``.

Roblox space: X right, Y up, the model faces -Z. Author space is turned 180°
about Y on the way in (author +Z front -> Roblox -Z).
"""

from __future__ import annotations

import math
from pathlib import Path
from xml.sax.saxutils import escape

import numpy as np

from .mesher import COLOR_MASK, NOSTUD, ModelGeometry, greedy_boxes, part_arrays
from .palette import parse_hex

REPO = Path(__file__).resolve().parent.parent
LUAU_DIR = REPO / "roblox"

MATERIAL_TOKENS = {
    "Plastic": 256, "SmoothPlastic": 272, "Neon": 288, "Wood": 512, "Slate": 800, "Concrete": 816,
    "Metal": 1088, "Grass": 1280, "Sand": 1296, "Ice": 1536, "Glass": 1568,
}
STYLE = {
    # studvox material -> (Roblox material, transparency, reflectance)
    # Stud / Inlet / Universal surfaces only render on Plastic, so every studded colour is Plastic.
    "plastic": ("Plastic", 0.0, 0.0),
    "matte": ("Plastic", 0.0, 0.0),
    "metal": ("Plastic", 0.0, 0.2),
    "glow": ("Neon", 0.0, 0.0),
    "glass": ("Glass", 0.35, 0.05),
    "water": ("Glass", 0.3, 0.05),
}
SURF_SMOOTH, SURF_STUDS, SURF_INLET, SURF_UNIVERSAL = 0, 3, 4, 5
NORMAL_TOP = 1  # Enum.NormalId.Top


# ---------------------------------------------------------------------------- maths

def a2r(v):
    """Author vector -> Roblox vector (180° turn about Y)."""
    return np.array([-v[0], v[1], -v[2]], dtype=np.float64)


def euler_xyz_matrix(rx, ry, rz):
    """R = Rz @ Ry @ Rx (X applied first), angles in degrees."""
    rx, ry, rz = (math.radians(a) for a in (rx, ry, rz))
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Rz @ Ry @ Rx


M_TURN = np.diag([-1.0, 1.0, -1.0])


def mat_to_quat(R):
    """Rotation matrix -> (x, y, z, w)."""
    t = R[0, 0] + R[1, 1] + R[2, 2]
    if t > 0:
        s = math.sqrt(t + 1.0) * 2
        w = 0.25 * s
        x = (R[2, 1] - R[1, 2]) / s
        y = (R[0, 2] - R[2, 0]) / s
        z = (R[1, 0] - R[0, 1]) / s
    elif R[0, 0] > R[1, 1] and R[0, 0] > R[2, 2]:
        s = math.sqrt(1.0 + R[0, 0] - R[1, 1] - R[2, 2]) * 2
        w = (R[2, 1] - R[1, 2]) / s
        x = 0.25 * s
        y = (R[0, 1] + R[1, 0]) / s
        z = (R[0, 2] + R[2, 0]) / s
    elif R[1, 1] > R[2, 2]:
        s = math.sqrt(1.0 + R[1, 1] - R[0, 0] - R[2, 2]) * 2
        w = (R[0, 2] - R[2, 0]) / s
        x = (R[0, 1] + R[1, 0]) / s
        y = 0.25 * s
        z = (R[1, 2] + R[2, 1]) / s
    else:
        s = math.sqrt(1.0 + R[2, 2] - R[0, 0] - R[1, 1]) * 2
        w = (R[1, 0] - R[0, 1]) / s
        x = (R[0, 2] + R[2, 0]) / s
        y = (R[1, 2] + R[2, 1]) / s
        z = 0.25 * s
    return x, y, z, w


def num(v: float) -> str:
    if abs(v) < 5e-5:
        return "0"
    s = f"{v:.4f}".rstrip("0").rstrip(".")
    return s if s not in ("-0", "") else "0"


# ---------------------------------------------------------------------------- build plan

def stud_texture_id(data: dict) -> str | None:
    import os
    return data.get("roblox", {}).get("stud_texture") or os.environ.get("STUDVOX_STUD_TEXTURE") or None


def stud_style(data: dict) -> str:
    """'surface' | 'universal' | 'texture' | 'none'."""
    mode = data.get("roblox", {}).get("studs", "auto")
    if data.get("stud", {}).get("mode") == "none":
        return "none"
    if mode == "texture" and not stud_texture_id(data):
        mode = "auto"
    if mode != "auto":
        return mode
    if abs(float(data["voxel_size"]) - 1.0) < 1e-6:
        return "surface"
    return "texture" if stud_texture_id(data) else "surface"


def plan(data: dict) -> dict:
    """Everything the Roblox writers need, in Roblox space and studs."""
    vs = float(data["voxel_size"])
    origin = np.asarray(data["origin"], dtype=np.float64)
    geo = ModelGeometry(data)
    rb = data.get("roblox", {})
    pal = []
    for e in data["palette"]:
        mat, tr, refl = STYLE.get(e["material"], STYLE["plastic"])
        pal.append({"name": e["name"], "rgb": list(parse_hex(e["hex"])), "material": mat, "transparency": tr,
                    "reflectance": refl})

    def to_r(p):
        return a2r((np.asarray(p, dtype=np.float64) - origin) * vs)

    studs_by_part = {p["name"]: geo.studs(p["name"]) for p in data["parts"]}
    style = stud_style(data)

    parts = []
    for p in data["parts"]:
        coords, values = part_arrays(p)
        spos, scol = studs_by_part[p["name"]]
        stud_keys = {(int(round(x)), int(round(y - 0.5)), int(round(z))) for x, y, z in spos.tolist()}
        boxes = []
        whole_studs = abs(vs - round(vs)) < 1e-6
        for x0, y0, z0, x1, y1, z1, v in greedy_boxes(coords, values & (COLOR_MASK | NOSTUD), geo.hidden(p["name"]),
                                                      overlap=whole_studs):
            c = to_r(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
            size = [(x1 - x0 + 1) * vs, (y1 - y0 + 1) * vs, (z1 - z0 + 1) * vs]
            top = False
            if style != "none":
                top = any((x, y1, z) in stud_keys for x in range(x0, x1 + 1) for z in range(z0, z1 + 1))
            boxes.append({"pos": c.tolist(), "size": size, "color": int(v & COLOR_MASK), "studs": top})
        parts.append({"name": p["name"], "parent": p["parent"], "pivot": to_r(p["pivot"]).tolist(),
                      "boxes": boxes})

    lo = np.asarray(data["bounds"][0], dtype=np.float64) - 0.5
    hi = np.asarray(data["bounds"][1], dtype=np.float64) + 0.5
    a, b = to_r(lo), to_r(hi)
    bmin, bmax = np.minimum(a, b), np.maximum(a, b)

    clips = {}
    for cl in data.get("clips", []):
        tracks = {}
        for name, rows in cl["tracks"].items():
            flat = []
            prev = None
            for px, py, pz, rx, ry, rz in rows:
                pr = a2r((px * vs, py * vs, pz * vs))
                R = M_TURN @ euler_xyz_matrix(rx, ry, rz) @ M_TURN
                q = np.array(mat_to_quat(R))
                if prev is not None and float(q @ prev) < 0:
                    q = -q
                prev = q
                flat += [*pr.tolist(), *q.tolist()]
            tracks[name] = flat
        clips[cl["name"]] = {"length": cl["length"], "loop": cl["loop"], "fps": cl["fps"], "frames": cl["frames"],
                             "tracks": tracks}

    grip = None
    g = data.get("meta", {}).get("grip")
    if g:
        up = a2r(g["up"])
        up /= np.linalg.norm(up)
        fwd = a2r(g["forward"])
        fwd -= up * float(fwd @ up)
        fwd /= np.linalg.norm(fwd)
        # Tool.Grip is the hand's grip frame seen from the handle: +Y = up, -Z = forward, X = Y x Z
        zax = -fwd
        xax = np.cross(up, zax)
        grip = {"pos": to_r(g["pos"]).tolist(), "x": xax.tolist(), "y": up.tolist(), "z": zax.tolist()}

    default_clip = rb.get("default_clip") or ("idle" if "idle" in clips else (next(iter(clips)) if clips else None))
    kind = "tool" if grip else ("rig" if clips and len(parts) > 0 else "static")
    return {
        "name": data["name"], "title": data["title"], "category": data["category"], "voxel_size": vs,
        "kind": kind, "stud_style": style, "stud_texture": stud_texture_id(data) if style == "texture" else None,
        "anchored": bool(rb.get("anchored", True)), "collide": bool(rb.get("collide", False)),
        "highlight": bool(rb.get("highlight", True)), "palette": pal, "parts": parts,
        "bounds": [bmin.tolist(), bmax.tolist()], "clips": clips, "default_clip": default_clip, "grip": grip,
    }


# ---------------------------------------------------------------------------- Luau data module

def _lua(v, indent=0) -> str:
    pad = "\t" * indent
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, np.integer)):
        return str(int(v))
    if isinstance(v, (float, np.floating)):
        return num(float(v))
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if isinstance(v, (list, tuple)):
        if all(isinstance(x, (int, float, np.integer, np.floating)) and not isinstance(x, bool) for x in v):
            # flat numeric arrays on wrapped lines
            items = [_lua(x) for x in v]
            lines, cur = [], []
            for it in items:
                cur.append(it)
                if len(cur) >= 28:
                    lines.append(", ".join(cur))
                    cur = []
            if cur:
                lines.append(", ".join(cur))
            if len(lines) <= 1:
                return "{ " + lines[0] + " }" if lines else "{}"
            return "{\n" + ",\n".join(pad + "\t" + ln for ln in lines) + ",\n" + pad + "}"
        inner = ",\n".join(pad + "\t" + _lua(x, indent + 1) for x in v)
        return "{\n" + inner + ",\n" + pad + "}" if v else "{}"
    if isinstance(v, dict):
        if not v:
            return "{}"
        rows = []
        for k, x in v.items():
            key = k if (isinstance(k, str) and k.isidentifier()) else f"[{_lua(k)}]"
            rows.append(f"{pad}\t{key} = {_lua(x, indent + 1)}")
        return "{\n" + ",\n".join(rows) + ",\n" + pad + "}"
    raise TypeError(type(v))


def luau_data(pl: dict) -> dict:
    """Compact table for StudVoxelBuilder (flat number arrays)."""
    parts = []
    for p in pl["parts"]:
        boxes = []
        for b in p["boxes"]:
            boxes += [*b["pos"], *b["size"], b["color"] + 1, 1 if b["studs"] else 0]
        parts.append({"name": p["name"], "parent": p["parent"], "pivot": p["pivot"], "boxes": boxes})
    return {
        "format": "studvox", "version": 1, "name": pl["name"], "title": pl["title"], "category": pl["category"],
        "kind": pl["kind"], "voxelSize": pl["voxel_size"], "studStyle": pl["stud_style"],
        "studTexture": pl["stud_texture"], "anchored": pl["anchored"],
        "collide": pl["collide"], "highlight": pl["highlight"],
        "palette": [{"name": c["name"], "rgb": c["rgb"], "material": c["material"], "transparency": c["transparency"],
                     "reflectance": c["reflectance"]} for c in pl["palette"]],
        "bounds": pl["bounds"], "parts": parts, "grip": pl["grip"], "defaultClip": pl["default_clip"],
        "clips": pl["clips"],
    }


def write_luau(pl: dict, path: Path) -> Path:
    body = _lua(luau_data(pl))
    src = (f"--!strict\n-- StudVox model data: {pl['title']} ({pl['category']})\n"
           f"-- Build it at runtime with StudVoxelBuilder.Build(require(this))\n"
           f"-- Box layout: x, y, z, sizeX, sizeY, sizeZ, colorIndex, topStuds (studs, Roblox space)\n"
           f"-- studStyle: surface = native Studs/Inlet surfaces (Plastic), universal, texture, none\n"
           f"-- Track layout per frame: px, py, pz, qx, qy, qz, qw (Motor6D.Transform)\n"
           f"return {body}\n")
    path.write_text(src, encoding="utf-8")
    return path


def clips_module_source(pl: dict) -> str:
    return ("-- StudVox clip data (Motor6D transforms per frame: px, py, pz, qx, qy, qz, qw)\nreturn "
            + _lua(pl["clips"]) + "\n")


# ---------------------------------------------------------------------------- rbxmx

class XmlWriter:
    def __init__(self):
        self.lines: list[str] = []
        self.n = 0

    def ref(self) -> str:
        self.n += 1
        return f"RBX{self.n:08X}"

    def open(self, cls: str, ref: str):
        self.lines.append(f'<Item class="{cls}" referent="{ref}"><Properties>')

    def props_end(self):
        self.lines.append("</Properties>")

    def close(self):
        self.lines.append("</Item>")

    def string(self, name, v):
        self.lines.append(f'<string name="{name}">{escape(str(v))}</string>')

    def bool(self, name, v):
        self.lines.append(f'<bool name="{name}">{"true" if v else "false"}</bool>')

    def float(self, name, v):
        self.lines.append(f'<float name="{name}">{num(v)}</float>')

    def token(self, name, v):
        self.lines.append(f'<token name="{name}">{int(v)}</token>')

    def refp(self, name, r):
        self.lines.append(f'<Ref name="{name}">{r if r else "null"}</Ref>')

    def vec3(self, name, v):
        self.lines.append(f'<Vector3 name="{name}"><X>{num(v[0])}</X><Y>{num(v[1])}</Y><Z>{num(v[2])}</Z></Vector3>')

    def color3u8(self, name, rgb):
        r, g, b = rgb
        self.lines.append(f'<Color3uint8 name="{name}">{0xFF000000 | (r << 16) | (g << 8) | b}</Color3uint8>')

    def color3(self, name, rgb):
        self.lines.append(f'<Color3 name="{name}"><R>{num(rgb[0])}</R><G>{num(rgb[1])}</G><B>{num(rgb[2])}</B></Color3>')

    @staticmethod
    def _cf(pos, rot=None):
        R = np.eye(3) if rot is None else np.asarray(rot)
        s = f"<X>{num(pos[0])}</X><Y>{num(pos[1])}</Y><Z>{num(pos[2])}</Z>"
        for i in range(3):
            for j in range(3):
                s += f"<R{i}{j}>{num(R[i, j])}</R{i}{j}>"
        return s

    def cframe(self, name, pos, rot=None):
        self.lines.append(f'<CoordinateFrame name="{name}">{self._cf(pos, rot)}</CoordinateFrame>')

    def opt_cframe(self, name, pos, rot=None):
        self.lines.append(f'<OptionalCoordinateFrame name="{name}"><CFrame>{self._cf(pos, rot)}</CFrame>'
                          f'</OptionalCoordinateFrame>')

    def source(self, name, src):
        self.lines.append(f'<ProtectedString name="{name}"><![CDATA[{src}]]></ProtectedString>')

    def text(self) -> str:
        return ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
                'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
                'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
                '<Meta name="ExplicitAutoJoints">true</Meta>\n' + "\n".join(self.lines) + "\n</roblox>\n")


def _part(w: XmlWriter, ref, name, pos, size, *, color, material="SmoothPlastic", transparency=0.0,
          reflectance=0.0, anchored=False, collide=False, massless=False, shape=1, rot=None, top=SURF_SMOOTH,
          bottom=SURF_SMOOTH, shadow=True, query=True, pivot_offset=None, children=None):
    # Only non-default values are written (Part defaults: CanTouch/CanQuery/CastShadow true, Massless false,
    # Transparency/Reflectance 0, Block shape, smooth side surfaces) to keep big packs small.
    w.open("Part", ref)
    w.string("Name", name)
    w.bool("Anchored", anchored)
    w.bool("CanCollide", collide)
    if not collide:
        w.bool("CanTouch", False)
    if not query:
        w.bool("CanQuery", False)
    if not shadow:
        w.bool("CastShadow", False)
    if massless:
        w.bool("Massless", True)
    w.cframe("CFrame", pos, rot)
    w.color3u8("Color3uint8", color)
    w.token("Material", MATERIAL_TOKENS.get(material, 272))
    if transparency:
        w.float("Transparency", transparency)
    if reflectance:
        w.float("Reflectance", reflectance)
    w.vec3("size", size)
    if shape != 1:
        w.token("shape", shape)
    w.token("TopSurface", top)
    w.token("BottomSurface", bottom)
    if pivot_offset is not None:
        w.cframe("PivotOffset", pivot_offset)
    w.props_end()
    for ch in children or ():
        ch()
    w.close()


def _weld(w: XmlWriter, cls, name, p0, p1, c0_pos, c0_rot=None):
    r = w.ref()
    w.open(cls, r)
    if name != cls:
        w.string("Name", name)
    w.refp("Part0", p0)
    w.refp("Part1", p1)
    w.cframe("C0", c0_pos, c0_rot)
    w.props_end()
    w.close()


def _value(w: XmlWriter, cls, name, v):
    r = w.ref()
    w.open(cls, r)
    w.string("Name", name)
    w.string("Value", v)
    w.props_end()
    w.close()


def _script(w: XmlWriter, cls, name, src, run_context=None):
    r = w.ref()
    w.open(cls, r)
    w.string("Name", name)
    if run_context is not None:
        w.token("RunContext", run_context)
        w.bool("Disabled", False)
    w.source("Source", src)
    w.props_end()
    w.close()


def _stud_texture(w: XmlWriter, asset: str, voxel_size: float):
    r = w.ref()
    w.open("Texture", r)
    w.string("Name", "Studs")
    w.lines.append(f'<Content name="Texture"><url>{escape(asset)}</url></Content>')
    w.token("Face", NORMAL_TOP)
    w.float("StudsPerTileU", voxel_size)
    w.float("StudsPerTileV", voxel_size)
    w.float("OffsetStudsU", 0)
    w.float("OffsetStudsV", 0)
    w.float("Transparency", 0)
    w.color3("Color3", (1, 1, 1))
    w.props_end()
    w.close()


def _highlight(w: XmlWriter):
    r = w.ref()
    w.open("Highlight", r)
    w.string("Name", "Outline")
    w.float("FillTransparency", 1)
    w.float("OutlineTransparency", 0)
    w.color3("OutlineColor", (0.07, 0.07, 0.08))
    w.color3("FillColor", (1, 1, 1))
    w.token("DepthMode", 1)
    w.bool("Enabled", True)
    w.props_end()
    w.close()


ANIMATE_SCRIPT = """-- StudVox: plays the clip named in the "Clip" StringValue on every client.
-- Change Clip.Value from a server Script to switch clips (it replicates).
if not script:IsDescendantOf(workspace) then
	return -- templates in ReplicatedStorage stay idle; clones in workspace animate
end
local model = script.Parent
local Animator = require(model:WaitForChild("StudVoxelAnimator"))
local clips = require(model:WaitForChild("Clips"))
local clipValue = model:WaitForChild("Clip") :: StringValue

local anim = Animator.new(model, clips)
anim:Start()
local function apply()
	if clipValue.Value ~= "" then
		anim:Play(clipValue.Value, 0.2)
	else
		anim:Stop(0.2)
	end
end
clipValue:GetPropertyChangedSignal("Value"):Connect(apply)
apply()
"""


def write_rbxmx(pl: dict, path: Path) -> Path:
    w = XmlWriter()
    emit_model(w, pl)
    path.write_text(w.text(), encoding="utf-8")
    return path


def emit_model(w: "XmlWriter", pl: dict, name: str | None = None, *, animator_source: str | None = None):
    """Write one model (Model / Tool) item into an open XmlWriter. ``name`` overrides the instance name."""
    inst_name = name or pl["title"]
    animator_src = animator_source if animator_source is not None else (LUAU_DIR / "StudVoxelAnimator.luau").read_text()
    pal = pl["palette"]
    bmin, bmax = np.asarray(pl["bounds"][0]), np.asarray(pl["bounds"][1])
    center = (bmin + bmax) / 2
    size = np.maximum(bmax - bmin, 0.2)
    kind = pl["kind"]
    style = pl["stud_style"]
    top_studded = {"surface": SURF_STUDS, "universal": SURF_UNIVERSAL}.get(style, SURF_SMOOTH)
    bottom_style = SURF_INLET if style == "surface" else SURF_SMOOTH
    static = kind == "static"
    collide = pl["collide"]
    anchored_root = pl["anchored"]

    def box_part(b, joint_ref=None, joint_pos=None, idx=0, part_name=""):
        c = pal[b["color"]]
        r = w.ref()
        kids = []
        if joint_ref is not None:
            off = np.asarray(b["pos"]) - np.asarray(joint_pos)
            kids.append(lambda: _weld(w, "Weld", "Weld", joint_ref, r, off))
        plastic = c["material"] == "Plastic"
        if b["studs"] and style == "texture":
            kids.append(lambda: _stud_texture(w, pl["stud_texture"], pl["voxel_size"]))
        _part(w, r, c["name"].replace("#", "c").replace(":", "_"), b["pos"], b["size"], color=c["rgb"],
              material=c["material"], transparency=c["transparency"], reflectance=c["reflectance"],
              anchored=static, collide=collide if static else False, massless=not static,
              top=top_studded if (b["studs"] and plastic) else SURF_SMOOTH,
              bottom=bottom_style if plastic else SURF_SMOOTH, children=kids)

    model_ref = w.ref()
    if kind == "tool":
        g = pl["grip"]
        handle_ref = w.ref()
        w.open("Tool", model_ref)
        w.string("Name", inst_name)
        w.bool("RequiresHandle", True)
        w.bool("CanBeDropped", True)
        w.string("ToolTip", pl["title"])
        R = np.stack([g["x"], g["y"], g["z"]], axis=1)
        w.cframe("Grip", (0, 0, 0), R)
        w.props_end()
        hp = g["pos"]
        _part(w, handle_ref, "Handle", hp, (0.4, 0.4, 0.4), color=(255, 255, 255), transparency=1.0,
              anchored=False, collide=False, massless=False, query=False, shadow=False)
        for p in pl["parts"]:
            for b in p["boxes"]:
                box_part(b, handle_ref, hp)
        if pl["highlight"]:
            _highlight(w)
        w.close()
    elif static:
        w.open("Model", model_ref)
        w.string("Name", inst_name)
        w.opt_cframe("WorldPivotData", (0, 0, 0))
        w.props_end()
        for p in pl["parts"]:
            for b in p["boxes"]:
                box_part(b)
        if pl["highlight"]:
            _highlight(w)
        w.close()
    else:
        root_ref = w.ref()
        joint_refs = {p["name"]: w.ref() for p in pl["parts"]}
        pivots = {p["name"]: np.asarray(p["pivot"]) for p in pl["parts"]}
        w.open("Model", model_ref)
        w.string("Name", inst_name)
        w.refp("PrimaryPart", root_ref)
        w.props_end()
        _part(w, root_ref, "Root", center, size, color=(255, 255, 255), transparency=1.0, anchored=anchored_root,
              collide=collide, massless=False, query=True, shadow=False, pivot_offset=(-center).tolist())
        for p in pl["parts"]:
            name = p["name"]
            jr = joint_refs[name]
            jpos = pivots[name]
            parent_ref = joint_refs[p["parent"]] if p["parent"] else root_ref
            parent_pos = pivots[p["parent"]] if p["parent"] else center
            grp = w.ref()
            w.open("Model", grp)
            w.string("Name", name)
            w.props_end()
            _part(w, jr, f"{name}Joint", jpos, (0.2, 0.2, 0.2), color=(255, 255, 255), transparency=1.0,
                  anchored=False, collide=False, massless=True, query=False, shadow=False,
                  children=[lambda pr=parent_ref, j=jr, off=(jpos - parent_pos), nm=name:
                            _weld(w, "Motor6D", nm, pr, j, off)])
            for b in p["boxes"]:
                box_part(b, jr, jpos)
            w.close()
        _script(w, "ModuleScript", "StudVoxelAnimator", animator_src)
        _script(w, "ModuleScript", "Clips", clips_module_source(pl))
        _script(w, "Script", "Animate", ANIMATE_SCRIPT, run_context=2)
        _value(w, "StringValue", "Clip", pl["default_clip"] or "")
        if pl["highlight"]:
            _highlight(w)
        w.close()


def export_all(data: dict, out_dir: Path) -> dict:
    out_dir = Path(out_dir)
    pl = plan(data)
    rbxmx = write_rbxmx(pl, out_dir / f"{data['name']}.rbxmx")
    luau = write_luau(pl, out_dir / f"{data['name']}.luau")
    n_parts = sum(len(p["boxes"]) for p in pl["parts"])
    (out_dir / "roblox.txt").write_text(
        f"kind={pl['kind']} studs={pl['stud_style']} parts={n_parts} clips={','.join(pl['clips']) or '-'}\n")
    return {"rbxmx": str(rbxmx), "luau": str(luau)}
