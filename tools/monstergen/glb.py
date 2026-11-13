"""Minimal GLB writer: named mesh nodes, vertex colours (written as sRGB, not linearised),
inverted-hull outline children, rotation/translation animations baked at 30 fps."""
from __future__ import annotations

import json
import struct

import numpy as np

from rig import Monster, quat

F32, U16, U32 = 5126, 5123, 5125
ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER = 34962, 34963


class _Bin:
    def __init__(self):
        self.data = bytearray()
        self.views = []
        self.accessors = []

    def add(self, arr: np.ndarray, ctype, kind, target=None, minmax=False):
        arr = np.ascontiguousarray(arr)
        while len(self.data) % 4:
            self.data.append(0)
        off = len(self.data)
        self.data += arr.tobytes()
        view = {"buffer": 0, "byteOffset": off, "byteLength": arr.nbytes}
        if target:
            view["target"] = target
        self.views.append(view)
        acc = {"bufferView": len(self.views) - 1, "componentType": ctype, "count": int(arr.shape[0]), "type": kind}
        if minmax:
            a2 = arr.reshape(arr.shape[0], -1)
            acc["min"] = [float(x) for x in a2.min(axis=0)]
            acc["max"] = [float(x) for x in a2.max(axis=0)]
        self.accessors.append(acc)
        return len(self.accessors) - 1


def _primitive(b: _Bin, tris, cols, material):
    """Flat-shaded indexed primitive (vertices shared only inside a flat facet)."""
    n = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
    pos = tris.reshape(-1, 3)
    nrm = np.repeat(n, 3, axis=0)
    col = np.repeat(cols, 3, axis=0)
    packed = np.concatenate([np.round(pos, 5), np.round(nrm, 4), np.round(col, 4)], axis=1)
    uniq, inv = np.unique(packed, axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    pos = uniq[:, 0:3].astype(np.float32)
    nrm = uniq[:, 3:6].astype(np.float32)
    ln = np.linalg.norm(nrm, axis=1, keepdims=True)
    nrm = (nrm / np.maximum(ln, 1e-9)).astype(np.float32)
    rgba = np.concatenate([uniq[:, 6:9], np.ones((len(uniq), 1))], axis=1).astype(np.float32)
    if len(uniq) < 65535:
        idx, ctype = inv.astype(np.uint16), U16
    else:
        idx, ctype = inv.astype(np.uint32), U32
    return {
        "attributes": {
            "POSITION": b.add(pos, F32, "VEC3", ARRAY_BUFFER, minmax=True),
            "NORMAL": b.add(nrm, F32, "VEC3", ARRAY_BUFFER),
            "COLOR_0": b.add(rgba, F32, "VEC4", ARRAY_BUFFER),
        },
        "indices": b.add(idx, ctype, "SCALAR", ELEMENT_ARRAY_BUFFER),
        "material": material,
        "mode": 4,
    }


def write_glb(mon: Monster, path: str):
    b = _Bin()
    materials = [
        {"name": "VertexColor", "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.0, "roughnessFactor": 1.0}},
        {"name": "Outline", "pbrMetallicRoughness": {"baseColorFactor": [0, 0, 0, 1], "metallicFactor": 0.0, "roughnessFactor": 1.0}},
    ]
    glow_mat = {}
    nodes, meshes = [], []
    index = {}

    for p in mon.parts.values():
        if p.glow:
            gc = p.glow_color if p.glow_color is not None else p.mesh.cols.mean(axis=0)
            k = tuple(round(float(x), 3) for x in gc)
            if k not in glow_mat:
                materials.append(
                    {
                        "name": f"Glow_{len(glow_mat) + 1}",
                        "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.0, "roughnessFactor": 1.0},
                        "emissiveFactor": [float(x) for x in k],
                    }
                )
                glow_mat[k] = len(materials) - 1
            mat = glow_mat[k]
        else:
            mat = 0
        meshes.append({"name": p.name, "primitives": [_primitive(b, p.mesh.tris - p.pivot, p.mesh.cols, mat)]})
        par = mon.parts[p.parent].pivot if p.parent else np.zeros(3)
        node = {"name": p.name, "mesh": len(meshes) - 1, "translation": [float(x) for x in (p.pivot - par)]}
        if p.glow:
            node["extras"] = {"glow": True}
        nodes.append(node)
        index[p.name] = len(nodes) - 1
        if p.outline_mesh is not None and len(p.outline_mesh):
            om = p.outline_mesh
            meshes.append({"name": p.name + "_Outline", "primitives": [_primitive(b, om.tris - p.pivot, om.cols, 1)]})
            nodes.append({"name": p.name + "_Outline", "mesh": len(meshes) - 1, "extras": {"outline": True}})
            nodes[index[p.name]].setdefault("children", []).append(len(nodes) - 1)
    for p in mon.parts.values():
        if p.parent:
            nodes[index[p.parent]].setdefault("children", []).append(index[p.name])

    movers = mon.moving_position_joints()
    animations = []
    for a in mon.anims:
        times, tracks = mon.bake(a)
        t_acc = b.add(times.astype(np.float32).reshape(-1, 1), F32, "SCALAR", minmax=True)
        samplers, channels = [], []
        for j in mon.joints:
            arr = tracks[j]
            q = np.array([quat(*r[:3]) for r in arr])
            for i in range(1, len(q)):
                if q[i] @ q[i - 1] < 0:
                    q[i] = -q[i]
            samplers.append({"input": t_acc, "output": b.add(q.astype(np.float32), F32, "VEC4"), "interpolation": "LINEAR"})
            channels.append({"sampler": len(samplers) - 1, "target": {"node": index[j], "path": "rotation"}})
            if j in movers:
                p = mon.parts[j]
                par = mon.parts[p.parent].pivot if p.parent else np.zeros(3)
                tr = (p.pivot - par)[None, :] + arr[:, 3:6]
                samplers.append({"input": t_acc, "output": b.add(tr.astype(np.float32), F32, "VEC3"), "interpolation": "LINEAR"})
                channels.append({"sampler": len(samplers) - 1, "target": {"node": index[j], "path": "translation"}})
        animations.append({"name": a.name, "samplers": samplers, "channels": channels})

    gltf = {
        "asset": {"version": "2.0", "generator": "monstergen (low-poly Roblox monsters)"},
        "scene": 0,
        "scenes": [{"name": mon.name, "nodes": [index[mon.root]]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": b.accessors,
        "bufferViews": b.views,
        "buffers": [{"byteLength": len(b.data)}],
        "animations": animations,
        "extras": {"vertexColorSpace": "sRGB", "units": "studs", "forward": "-Z"},
    }
    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    bin_ = bytes(b.data) + b"\0" * ((4 - len(b.data) % 4) % 4)
    gltf["buffers"][0]["byteLength"] = len(bin_)
    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    total = 12 + 8 + len(js) + 8 + len(bin_)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", len(js), b"JSON"))
        f.write(js)
        f.write(struct.pack("<I4s", len(bin_), b"BIN\0"))
        f.write(bin_)
    return total
