#!/usr/bin/env python3
"""Converte un modello di gigante (FBX statico, es. generato da Meshy) in un file .glb
pronto per il 3D Importer di Roblox Studio, diviso nelle parti del corpo dei giganti del gioco.

  python3 tools/mesh_titan/convert.py modello.fbx texture.png normal.png roughness.png metallic.png uscita.glb NomeGigante [--profilo colosso]

Profili delle proporzioni: "normale" (gigante con il collo corto, es. la Furia) e "colosso"
(gigante altissimo con la testa piccola e le spalle alte, es. il colosso anatomico dei filmati).

Cosa fa:
  1. legge la geometria (vertici, poligoni, UV) dal file FBX binario;
  2. assegna ogni triangolo alla parte del corpo più vicina (testa, busto, braccia, gambe...),
     usando uno scheletro ricavato dalle proporzioni del modello;
  3. riduce i triangoli di ogni parte (Roblox accetta al massimo 20.000 triangoli per parte)
     mantenendo le coordinate della texture;
  4. aggiunge piccoli segnaposto "J_..." nei punti delle articolazioni: il gioco li legge per
     costruire le giunture Motor6D, quindi funziona qualunque scala o rotazione usi l'importer;
  5. scrive un .glb con le texture PBR incorporate (colore, normali, rugosità/metallo).
"""
import io
import json
import os
import struct
import sys
import tempfile
import zlib

import numpy as np
from PIL import Image

# ---------------------------------------------------------------------------------------------
# 1) Lettura FBX binario
# ---------------------------------------------------------------------------------------------


def read_fbx(path):
    d = open(path, "rb").read()
    ver = struct.unpack("<I", d[23:27])[0]
    found = {}

    def prop(o):
        t = chr(d[o])
        o += 1
        if t in "fdlicb":
            n, enc, clen = struct.unpack("<III", d[o : o + 12])
            o += 12
            raw = d[o : o + clen]
            o += clen
            if enc == 1:
                raw = zlib.decompress(raw)
            dt = {"f": "<f4", "d": "<f8", "l": "<i8", "i": "<i4", "c": "u1", "b": "u1"}[t]
            return np.frombuffer(raw, dtype=dt), o
        sizes = {"Y": 2, "C": 1, "I": 4, "F": 4, "D": 8, "L": 8}
        if t in sizes:
            return None, o + sizes[t]
        if t in "SR":
            n = struct.unpack("<I", d[o : o + 4])[0]
            return d[o + 4 : o + 4 + n], o + 4 + n
        raise ValueError("proprietà FBX sconosciuta: " + t)

    def walk(o):
        while o < len(d) - 200:
            if ver >= 7500:
                end, nprops, plen = struct.unpack("<QQQ", d[o : o + 24])
                o2 = o + 24
            else:
                end, nprops, plen = struct.unpack("<III", d[o : o + 12])
                o2 = o + 12
            nl = d[o2]
            name = d[o2 + 1 : o2 + 1 + nl].decode(errors="ignore")
            o2 += 1 + nl
            if end == 0:
                return
            p = o2
            values = []
            for _ in range(nprops):
                v, p = prop(p)
                values.append(v)
            if name in ("Vertices", "PolygonVertexIndex", "UV", "UVIndex") and values:
                found.setdefault(name, values[0])
            if o2 + plen < end:
                walk(o2 + plen)
            o = end

    walk(27)
    V = found["Vertices"].reshape(-1, 3).astype(np.float64)
    I = found["PolygonVertexIndex"]
    UV = found["UV"].reshape(-1, 2)
    UVI = found["UVIndex"]
    tris, tuv = [], []
    cur, curuv = [], []
    for k, idx in enumerate(I):
        last = idx < 0
        cur.append(~idx if last else idx)
        curuv.append(UVI[k])
        if last:
            for j in range(1, len(cur) - 1):
                tris.append((cur[0], cur[j], cur[j + 1]))
                tuv.append((curuv[0], curuv[j], curuv[j + 1]))
            cur, curuv = [], []
    return V, np.array(tris), UV, np.array(tuv)


# ---------------------------------------------------------------------------------------------
# 2) Orientamento e scheletro
# ---------------------------------------------------------------------------------------------

PARTS = [
    "Head", "Torso", "Hips",
    "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperLeg", "RightLowerLeg", "RightFoot",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
]
# triangoli massimi per parte dopo la riduzione
BUDGET = {
    "Head": 3600, "Torso": 3000, "Hips": 1300,
    "UpperArm": 900, "LowerArm": 750, "Hand": 900,
    "UpperLeg": 900, "LowerLeg": 750, "Foot": 600,
}

# altezze delle articolazioni (altezza del gigante = 1), raggi delle ossa e triangoli per profilo
PROFILES = {
    "normale": {
        "neck": 0.83, "waist": 0.60, "root": 0.52, "shoulder": (0.775, 0.122), "elbow": 0.625, "wrist": 0.485,
        "hip_x": 0.05, "knee": 0.29, "ankle": 0.07, "eye": 0.895, "mouth": 0.86, "nape": 0.83, "head_x": 0.085,
        "radius": {"Head": 0.045, "Torso": 0.08, "Hips": 0.05, "UpperArm": 0.03, "LowerArm": 0.025, "Hand": 0.02,
                   "UpperLeg": 0.05, "LowerLeg": 0.032, "Foot": 0.02},
        "budget": BUDGET,
    },
    # colosso anatomico: collo e spalle alti, braccia lunghe vicine al corpo, cosce grosse.
    # Si vede da vicino nei filmati: molti più triangoli
    "colosso": {
        "neck": 0.9, "waist": 0.60, "root": 0.53, "shoulder": (0.815, 0.135), "elbow": 0.635, "wrist": 0.47,
        "hip_x": 0.06, "knee": 0.30, "ankle": 0.075, "eye": 0.96, "mouth": 0.93, "nape": 0.9, "head_x": 0.05,
        # le braccia toccano i fianchi: tra queste altezze, più vicino al centro di x è sempre busto
        "arm_gap": (0.50, 0.79, 0.118),
        "radius": {"Head": 0.04, "Torso": 0.11, "Hips": 0.07, "UpperArm": 0.035, "LowerArm": 0.028, "Hand": 0.024,
                   "UpperLeg": 0.06, "LowerLeg": 0.045, "Foot": 0.028},
        "budget": {"Head": 4500, "Torso": 9000, "Hips": 3500, "UpperArm": 2600, "LowerArm": 2000, "Hand": 2200,
                   "UpperLeg": 3800, "LowerLeg": 2800, "Foot": 2000},
    },
}
PROFILE = PROFILES["normale"]


def to_roblox(V):
    """Porta il modello nello spazio di Roblox: Y in alto, il gigante guarda verso -Z, destra = +X.
    L'asse "su" è quello più lungo; il davanti si trova guardando dove puntano le dita dei piedi."""
    ext = V.max(0) - V.min(0)
    up = int(np.argmax(ext))
    rest = [a for a in range(3) if a != up]
    # la profondità è l'asse più corto tra i due rimanenti
    depth = rest[int(np.argmin(ext[rest]))]
    lateral = [a for a in rest if a != depth][0]
    h = V[:, up]
    low = V[h < h.min() + 0.03 * ext[up]]
    ankle = V[(h > h.min() + 0.06 * ext[up]) & (h < h.min() + 0.09 * ext[up])]
    forward_sign = 1.0 if low[:, depth].mean() > ankle[:, depth].mean() else -1.0
    # sistema destrorso: destra = avanti x su (con avanti = -Z di Roblox)
    fwd = np.zeros(3); fwd[depth] = forward_sign
    upv = np.zeros(3); upv[up] = 1.0
    right = np.cross(fwd, upv)
    R = np.stack([right, upv, -fwd])  # righe: X, Y, Z di Roblox
    P = V @ R.T
    P[:, 1] -= P[:, 1].min()
    P[:, 0] -= (P[:, 0].min() + P[:, 0].max()) / 2
    P[:, 2] -= (P[:, 2].min() + P[:, 2].max()) / 2
    return P / P[:, 1].max()  # altezza = 1


def side_center(P, t0, t1, sign, xmin=0.0, xmax=1.0):
    m = (P[:, 1] > t0) & (P[:, 1] < t1) & (P[:, 0] * sign > xmin) & (P[:, 0] * sign < xmax)
    s = P[m]
    return s.mean(0) if len(s) else None


def skeleton(P):
    """Punti delle articolazioni ricavati dalle sezioni del modello (altezza normalizzata a 1)."""
    y = P[:, 1]

    def ring(t, sign=None, xmin=0.0, xmax=1.0, band=0.012):
        m = (y > t - band) & (y < t + band)
        if sign is not None:
            m &= (P[:, 0] * sign > xmin) & (P[:, 0] * sign < xmax)
        s = P[m]
        return np.array([s[:, 0].mean(), t, s[:, 2].mean()])

    # altezze tipiche di un corpo umano (verificate sulle sezioni del modello, vedi PROFILES)
    pr = PROFILE
    J = {}
    J["Neck"] = ring(pr["neck"])
    J["Waist"] = ring(pr["waist"]) * np.array([0, 1, 1])
    J["Root"] = ring(pr["root"]) * np.array([0, 1, 1])
    sh_y, sh_x = pr["shoulder"]
    for sign, side in ((1, "Right"), (-1, "Left")):
        # coordinate normalizzate: altezza del gigante = 1
        sh = ring(sh_y, sign, sh_x - 0.03, sh_x + 0.05)
        J[side + "Shoulder"] = np.array([sign * sh_x, sh_y, sh[2]])
        J[side + "Elbow"] = ring(pr["elbow"], sign, 0.1, 0.25)
        J[side + "Wrist"] = ring(pr["wrist"], sign, 0.11, 0.25)
        J[side + "HandTip"] = J[side + "Wrist"] + (J[side + "Wrist"] - J[side + "Elbow"]) * 0.5
        J[side + "Hip"] = np.array([sign * pr["hip_x"], pr["root"], J["Root"][2]])
        J[side + "Knee"] = ring(pr["knee"], sign, 0.0, 0.2)
        J[side + "Ankle"] = ring(pr["ankle"], sign, 0.0, 0.2)
        toe = P[(y < 0.03) & (P[:, 0] * sign > 0)]
        J[side + "Toe"] = np.array([toe[:, 0].mean(), 0.01, toe[:, 2].min()])
    J["HeadTop"] = np.array([0, 1.0, ring(0.95 + (pr["eye"] - 0.895) * 0.3)[2]])
    # volto: la superficie più avanzata della testa all'altezza degli occhi
    eye = pr["eye"]
    face = P[(y > eye - 0.01) & (y < eye + 0.01) & (np.abs(P[:, 0]) < 0.03)]
    front_z = face[:, 2].min() if len(face) else J["Neck"][2] - 0.06
    for sign, side in ((1, "Right"), (-1, "Left")):
        J[side + "Eye"] = np.array([sign * 0.017, eye, front_z + 0.006])
    mo = pr["mouth"]
    mouth = P[(y > mo - 0.005) & (y < mo + 0.005) & (np.abs(P[:, 0]) < 0.02)]
    J["Mouth"] = np.array([0, mo, (mouth[:, 2].min() if len(mouth) else front_z) + 0.005])
    na = pr["nape"]
    back = P[(y > na - 0.015) & (y < na + 0.015) & (np.abs(P[:, 0]) < 0.03)]
    J["Nape"] = np.array([0, na, back[:, 2].max() if len(back) else J["Neck"][2] + 0.05])
    J["Ground"] = np.array([0.0, 0.0, 0.0])
    return J


def bones(J):
    """Segmenti (parte, inizio, fine, raggio) usati per assegnare i triangoli."""
    r = PROFILE["radius"]
    b = [
        ("Head", J["Neck"] + [0, 0.02, 0], J["HeadTop"], r["Head"]),
        ("Torso", J["Waist"], J["Neck"], r["Torso"]),
        ("Hips", J["Root"] + [0, 0.01, 0], J["Waist"], r["Hips"]),
    ]
    for side in ("Right", "Left"):
        b += [
            (side + "UpperArm", J[side + "Shoulder"], J[side + "Elbow"], r["UpperArm"]),
            (side + "LowerArm", J[side + "Elbow"], J[side + "Wrist"], r["LowerArm"]),
            (side + "Hand", J[side + "Wrist"], J[side + "HandTip"], r["Hand"]),
            (side + "UpperLeg", J[side + "Hip"] + [0, 0.02, 0], J[side + "Knee"], r["UpperLeg"]),
            (side + "LowerLeg", J[side + "Knee"], J[side + "Ankle"], r["LowerLeg"]),
            (side + "Foot", J[side + "Ankle"], J[side + "Toe"], r["Foot"]),
        ]
    return b


def segment_distance(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / (ab @ ab), 0, 1)
    closest = a + t[:, None] * ab
    return np.linalg.norm(P - closest, axis=1)


def assign(P, T, J):
    bl = bones(J)
    scores = np.stack([segment_distance(P, a, b) - r * 0.8 for _, a, b, r in bl], axis=1)
    label_v = np.argmin(scores, axis=1)
    names = [n for n, *_ in bl]
    y = P[:, 1]
    # capelli e testa: tutto sopra il collo e vicino all'asse centrale
    head = names.index("Head")
    label_v[(y > J["Neck"][1] + 0.01) & (np.abs(P[:, 0]) < PROFILE["head_x"])] = head
    gap = PROFILE.get("arm_gap")
    if gap:
        # fianchi e dorsali non devono seguire il braccio quando si alza (resterebbero schegge sospese)
        y0, y1, xg = gap
        band = (y > y0) & (y < y1)
        for side, sign in (("Right", 1), ("Left", -1)):
            arm = [names.index(side + n) for n in ("UpperArm", "LowerArm", "Hand")]
            inner = band & (P[:, 0] * sign < xg) & np.isin(label_v, arm)
            label_v[inner & (y >= J["Waist"][1] - 0.03)] = names.index("Torso")
            label_v[inner & (y < J["Waist"][1] - 0.03)] = names.index("Hips")
            # la mano sfiora la coscia: quello che sta sulla coscia (lontano dall'asse del braccio) è gamba
            low = (y < J["Root"][1]) & np.isin(label_v, arm)
            if low.any():
                d_leg = segment_distance(P, J[side + "Hip"], J[side + "Knee"])
                d_fore = segment_distance(P, J[side + "Elbow"], J[side + "Wrist"])
                d_hand = segment_distance(P, J[side + "Wrist"], J[side + "HandTip"])
                label_v[low & (d_leg < 0.072) & (d_fore > 0.024) & (d_hand > 0.03)] = names.index(side + "UpperLeg")
    hips = names.index("Hips")
    # fascia del bacino: dalla vita all'inguine (prima la prendeva il busto)
    torso = names.index("Torso")
    label_v[(label_v == torso) & (y < J["Waist"][1] - 0.03)] = hips
    low = (label_v == hips) & (y < J["Root"][1] - 0.025)
    if low.any():
        for side in ("Right", "Left"):
            sign = 1 if side == "Right" else -1
            label_v[low & (P[:, 0] * sign >= 0)] = names.index(side + "UpperLeg")
    # ogni triangolo prende la parte della maggioranza dei suoi vertici
    lv = label_v[T]
    label_t = np.array([np.bincount(row, minlength=len(names)).argmax() for row in lv])
    return names, clean_islands(T, label_t, len(names))


def clean_islands(T, label_t, nparts):
    """Pezzetti staccati dal resto della loro parte (es. un lembo di coscia finito nella mano):
    passano alla parte con cui confinano, così non volano via quando l'arto si muove."""
    vert_tris = {}
    for t, tri in enumerate(T):
        for v in tri:
            vert_tris.setdefault(int(v), []).append(t)
    for part in range(nparts):
        tris = np.where(label_t == part)[0]
        if len(tris) == 0:
            continue
        parent = {int(t): int(t) for t in tris}

        def find(a):
            while parent[a] != a:
                parent[a] = parent[parent[a]]
                a = parent[a]
            return a

        for t in tris:
            for v in T[t]:
                for o in vert_tris[int(v)]:
                    if o != t and label_t[o] == part:
                        ra, rb = find(int(t)), find(int(o))
                        if ra != rb:
                            parent[ra] = rb
        groups = {}
        for t in tris:
            groups.setdefault(find(int(t)), []).append(int(t))
        biggest = max(len(g) for g in groups.values())
        for g in groups.values():
            if len(g) == biggest or len(g) > max(40, 0.04 * len(tris)):
                continue
            around = [label_t[o] for t in g for v in T[t] for o in vert_tris[int(v)] if label_t[o] != part]
            if around:
                label_t[g] = np.bincount(around, minlength=nparts).argmax()
    return label_t


# ---------------------------------------------------------------------------------------------
# 3) Riduzione dei triangoli (mantiene le UV)
# ---------------------------------------------------------------------------------------------


def write_obj(path, P, T, UV, TUV):
    used_v = np.unique(T)
    used_uv = np.unique(TUV)
    vmap = {v: i + 1 for i, v in enumerate(used_v)}
    uvmap = {u: i + 1 for i, u in enumerate(used_uv)}
    with open(path, "w") as f:
        f.write("mtllib dummy.mtl\nusemtl m\n")
        for v in used_v:
            f.write("v %.6f %.6f %.6f\n" % tuple(P[v]))
        for u in used_uv:
            f.write("vt %.6f %.6f\n" % tuple(UV[u]))
        for t, tu in zip(T, TUV):
            f.write("f %d/%d %d/%d %d/%d\n" % (vmap[t[0]], uvmap[tu[0]], vmap[t[1]], uvmap[tu[1]], vmap[t[2]], uvmap[tu[2]]))
    with open(os.path.join(os.path.dirname(path), "dummy.mtl"), "w") as f:
        f.write("newmtl m\nKd 1 1 1\nmap_Kd dummy.png\n")


def decimate(P, T, UV, TUV, target):
    import pymeshlab

    tmp = tempfile.mkdtemp()
    Image.new("RGB", (4, 4)).save(os.path.join(tmp, "dummy.png"))
    src = os.path.join(tmp, "in.obj")
    write_obj(src, P, T, UV, TUV)
    ms = pymeshlab.MeshSet()
    ms.load_new_mesh(src)
    if len(T) > target:
        ms.meshing_decimation_quadric_edge_collapse_with_texture(
            targetfacenum=int(target), qualitythr=0.5, preserveboundary=True, boundaryweight=2.0, optimalplacement=True, preservenormal=True
        )
    m = ms.current_mesh()
    verts = m.vertex_matrix()
    faces = m.face_matrix()
    wuv = m.wedge_tex_coord_matrix()  # (3*facce, 2)
    return verts, faces, wuv.reshape(-1, 3, 2)


# ---------------------------------------------------------------------------------------------
# 4) Scrittura GLB
# ---------------------------------------------------------------------------------------------


class GLB:
    def __init__(self):
        self.bin = bytearray()
        self.views, self.accessors, self.meshes, self.nodes = [], [], [], []
        self.images, self.textures = [], []

    def _view(self, data, target=None):
        while len(self.bin) % 4:
            self.bin += b"\x00"
        view = {"buffer": 0, "byteOffset": len(self.bin), "byteLength": len(data)}
        if target:
            view["target"] = target
        self.bin += data
        self.views.append(view)
        return len(self.views) - 1

    def _accessor(self, arr, kind, comp, target, minmax=False):
        view = self._view(arr.tobytes(), target)
        acc = {"bufferView": view, "componentType": comp, "count": int(arr.shape[0]), "type": kind}
        if minmax:
            acc["min"] = [float(x) for x in arr.min(0)]
            acc["max"] = [float(x) for x in arr.max(0)]
        self.accessors.append(acc)
        return len(self.accessors) - 1

    def image(self, png_bytes):
        view = self._view(png_bytes)
        self.images.append({"bufferView": view, "mimeType": "image/png"})
        self.textures.append({"source": len(self.images) - 1})
        return len(self.textures) - 1

    def mesh(self, name, positions, normals, uvs, indices, material):
        attrs = {"POSITION": self._accessor(positions.astype(np.float32), "VEC3", 5126, 34962, True)}
        if normals is not None:
            attrs["NORMAL"] = self._accessor(normals.astype(np.float32), "VEC3", 5126, 34962)
        if uvs is not None:
            attrs["TEXCOORD_0"] = self._accessor(uvs.astype(np.float32), "VEC2", 5126, 34962)
        idx = self._accessor(indices.astype(np.uint32).reshape(-1), "SCALAR", 5125, 34963)
        prim = {"attributes": attrs, "indices": idx}
        if material is not None:
            prim["material"] = material
        self.meshes.append({"name": name, "primitives": [prim]})
        self.nodes.append({"name": name, "mesh": len(self.meshes) - 1})

    def save(self, path, materials):
        doc = {
            "asset": {"version": "2.0", "generator": "Sieri Perduti mesh_titan"},
            "scene": 0,
            "scenes": [{"nodes": list(range(len(self.nodes)))}],
            "nodes": self.nodes,
            "meshes": self.meshes,
            "materials": materials,
            "textures": self.textures,
            "images": self.images,
            "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
            "accessors": self.accessors,
            "bufferViews": self.views,
            "buffers": [{"byteLength": len(self.bin)}],
        }
        for t in doc["textures"]:
            t["sampler"] = 0
        js = json.dumps(doc, separators=(",", ":")).encode()
        js += b" " * ((4 - len(js) % 4) % 4)
        binary = bytes(self.bin) + b"\x00" * ((4 - len(self.bin) % 4) % 4)
        total = 12 + 8 + len(js) + 8 + len(binary)
        with open(path, "wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, total))
            f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
            f.write(struct.pack("<II", len(binary), 0x004E4942) + binary)


def png_bytes(img, size=1024):
    img = img.resize((size, size), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    return buf.getvalue()


def vertex_normals(pos, faces):
    n = np.zeros_like(pos)
    fn = np.cross(pos[faces[:, 1]] - pos[faces[:, 0]], pos[faces[:, 2]] - pos[faces[:, 0]])
    for k in range(3):
        np.add.at(n, faces[:, k], fn)
    n /= np.linalg.norm(n, axis=1, keepdims=True) + 1e-12
    return n


def cube(center, size):
    h = size / 2
    c = np.array([[x, y, z] for x in (-h, h) for y in (-h, h) for z in (-h, h)]) + center
    f = np.array([[0, 1, 3], [0, 3, 2], [4, 6, 7], [4, 7, 5], [0, 4, 5], [0, 5, 1], [2, 3, 7], [2, 7, 6], [0, 2, 6], [0, 6, 4], [1, 5, 7], [1, 7, 3]])
    return c, f


def main():
    global PROFILE
    fbx, color, normal, rough, metal, out, name = sys.argv[1:8]
    if "--profilo" in sys.argv:
        PROFILE = PROFILES[sys.argv[sys.argv.index("--profilo") + 1]]
    scale = 20.0  # studs di altezza nel file (il gioco poi lo ridimensiona come vuole)
    V, T, UV, TUV = read_fbx(fbx)
    P = to_roblox(V)
    J = skeleton(P)
    names, label = assign(P, T, J)
    glb = GLB()
    # materiale PBR: colore, normali, metallo (B) + rugosità (G)
    col = Image.open(color).convert("RGB")
    tex_color = glb.image(png_bytes(col))
    tex_normal = glb.image(png_bytes(Image.open(normal).convert("RGB")))
    r = Image.open(rough).convert("L").resize((1024, 1024))
    m = Image.open(metal).convert("L").resize((1024, 1024))
    mr = Image.merge("RGB", (Image.new("L", (1024, 1024), 0), r, m))
    tex_mr = glb.image(png_bytes(mr))
    materials = [{
        "name": name + "_Pelle",
        "pbrMetallicRoughness": {"baseColorTexture": {"index": tex_color}, "metallicRoughnessTexture": {"index": tex_mr}, "metallicFactor": 1.0, "roughnessFactor": 1.0},
        "normalTexture": {"index": tex_normal},
    }, {"name": "Segnaposto", "pbrMetallicRoughness": {"baseColorFactor": [1, 0, 1, 1]}}]
    report = []
    for i, part in enumerate(names):
        sel = label == i
        key = part.replace("Right", "").replace("Left", "")
        verts, faces, wuv = decimate(P[...], T[sel], UV, TUV[sel], PROFILE["budget"][key])
        # vertici separati per ogni coppia (posizione, UV)
        pos = verts[faces].reshape(-1, 3) * scale
        uv = wuv.reshape(-1, 2).copy()
        uv[:, 1] = 1.0 - uv[:, 1]
        key_arr = np.round(np.hstack([pos, uv]) * 1e5).astype(np.int64)
        uniq, inverse = np.unique(key_arr, axis=0, return_index=False, return_inverse=True)
        inverse = inverse.reshape(-1)
        upos = np.zeros((len(uniq), 3)); uuv = np.zeros((len(uniq), 2))
        upos[inverse] = pos; uuv[inverse] = uv
        idx = inverse.reshape(-1, 3)
        glb.mesh("SP_" + part, upos, vertex_normals(upos, idx), uuv, idx, 0)
        report.append((part, int(sel.sum()), len(idx)))
    # segnaposto delle articolazioni (cubetti minuscoli, il gioco li legge e poi li elimina)
    for joint, p in J.items():
        c, f = cube(p * scale, 0.04)
        glb.mesh("J_" + joint, c, None, None, f, 1)
    glb.save(out, materials)
    # colore medio della pelle (per le giunture)
    small = np.asarray(col.resize((64, 64))).reshape(-1, 3)
    bright = small[small.sum(1) > 200]
    skin = bright.mean(0) if len(bright) else small.mean(0)
    print(json.dumps({"parts": report, "skin": [int(x) for x in skin], "joints": {k: [round(float(x), 4) for x in v] for k, v in J.items()}}, indent=1))


if __name__ == "__main__":
    main()
