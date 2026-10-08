#!/usr/bin/env python3
"""Foto del mondo di gioco senza Roblox Studio.

Costruisce il mondo con il Roblox finto delle prove (WorldBuilder + terreno + giganti di prova),
lo esporta (tools/tests/world_dump.luau) e lo disegna con il motore di tools/thumbnails/engine.py.
Le foto mostrano il mondo vero del gioco: utili per vedere le modifiche prima di aprire Studio.

  python3 tools/world_photo.py <cartella uscita> [inquadratura ...] [--larghezza 1280] [--dump file]

Inquadrature: calaneth_tetti, calaneth_strada, calaneth_case, muro_esterno, vermiglia_alto, campo, aurion,
bosco, giganti, giganti_vicino, volto, varieta, varieta_volti,
colosso, colosso_busto, colosso_testa, colosso_scena
(senza nomi le fa tutte). Serve il programma 'luau' (variabile LUAU o nel PATH).
"""
import math
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "thumbnails"))

from engine import (M_CLOTH, M_COLOR, M_GLOW, M_GRAIN, M_METAL, M_ROOF, M_SKIN, M_STONE, M_WATER, M_WOOD,  # noqa: E402
                    Camera, Look, Scene, add_box, add_cylinder, add_sphere, grid_quad, render)

# lato massimo dei triangoli (metri): il rasterizzatore è lento con triangoli enormi sullo schermo
SEG = 4.0

SCALE = 0.3  # 1 stud = 0.3 metri (le texture del motore sono pensate in metri)

STONE = {"Slate", "Limestone", "Sandstone", "Granite", "Marble", "Brick", "Cobblestone", "Pavement", "Asphalt", "CrackedLava", "Concrete"}
GRAIN = {"Rock", "Basalt", "Plaster", "SmoothPlastic", "Plastic", "Grass", "LeafyGrass", "Ground", "Mud", "Sand", "Snow", "Salt", "Pebble", "Cardboard", "Carpet", "Leather", "Rubber", "Ice", "Glacier"}
ROOF = {"ClayRoofTiles", "RoofShingles"}
WOOD = {"Wood", "WoodPlanks"}
METAL = {"Metal", "CorrodedMetal", "DiamondPlate", "Foil"}

TERRAIN_DEFAULT = {
    "Grass": (0.38, 0.55, 0.28), "LeafyGrass": (0.31, 0.47, 0.24), "Ground": (0.43, 0.36, 0.27), "Mud": (0.36, 0.29, 0.22),
    "Sand": (0.84, 0.77, 0.59), "Rock": (0.50, 0.46, 0.42), "Basalt": (0.25, 0.24, 0.24), "CrackedLava": (0.55, 0.22, 0.10),
    "Cobblestone": (0.55, 0.53, 0.49), "Pavement": (0.55, 0.55, 0.52), "Slate": (0.45, 0.47, 0.47), "Water": (0.10, 0.28, 0.32),
    "Snow": (0.92, 0.94, 0.96), "Limestone": (0.80, 0.76, 0.66), "Sandstone": (0.72, 0.56, 0.42),
}

# ---------------------------------------------------------------------------------------------
# Esportazione del mondo (Luau + Roblox finto)
# ---------------------------------------------------------------------------------------------


def long_string(text):
    level = 1
    while ("]" + "=" * level + "]") in text:
        level += 1
    return "[" + "=" * level + "[\n" + text + "]" + "=" * level + "]"


def dump(path):
    sources = []
    for prefix, folder in (("Shared", os.path.join(ROOT, "src", "shared")), ("Server/Services", os.path.join(ROOT, "src", "server", "Services")), ("Client", os.path.join(ROOT, "src", "client"))):
        for base, _, names in os.walk(folder):
            for n in sorted(names):
                if n.endswith(".lua"):
                    rel = os.path.relpath(os.path.join(base, n), folder)[:-4].replace(os.sep, "/")
                    sources.append('\t["%s/%s"] = %s,' % (prefix, rel, long_string(open(os.path.join(base, n), encoding="utf-8").read())))
    bundle = "SOURCES_TABLE = {\n" + "\n".join(sources) + "\n}\n"
    for name in ("roblox_api.luau", "roblox_mock.luau"):
        bundle += open(os.path.join(ROOT, "tools", "tests", name), encoding="utf-8").read() + "\n"
    bundle += "do\n" + open(os.path.join(ROOT, "tools", "tests", "world_dump.luau"), encoding="utf-8").read() + "\nend\n"
    luau = os.environ.get("LUAU") or shutil.which("luau")
    if not luau:
        sys.exit("Interprete 'luau' non trovato")
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as f:
        f.write(bundle)
        tmp = f.name
    proc = subprocess.run([luau, tmp], capture_output=True, text=True)
    os.unlink(tmp)
    if proc.returncode != 0 or "FINE\t" not in proc.stdout:
        sys.exit("Esportazione del mondo fallita:\n" + (proc.stdout[-3000:] + proc.stderr[-3000:]))
    with open(path, "w", encoding="utf-8") as f:
        f.write(proc.stdout)


def parse(path):
    data = {"parts": [], "terrain": [], "colors": {}, "zones": {}, "views": {}, "titans": {}, "places": [], "ground": 8.0, "water": 4.0}
    current = None
    for line in open(path, encoding="utf-8"):
        f = line.rstrip("\n").split("\t")
        k = f[0]
        if k == "P":
            part = {
                "class": f[1], "shape": f[2], "size": np.array(list(map(float, f[3:6]))),
                "pos": np.array(list(map(float, f[6:9]))), "R": np.array(list(map(float, f[9:18]))).reshape(3, 3),
                "color": np.array(list(map(float, f[18:21]))), "mat": f[21], "alpha": float(f[22]),
            }
            if current is not None:
                current["parts"].append(part)
            else:
                data["parts"].append(part)
        elif k == "G":
            current = {"look": f[1], "height": float(f[2]), "index": int(f[3]), "parts": []}
        elif k == "GE":
            data["titans"][current["index"]] = current
            current = None
        elif k == "T":
            kind = f[1]
            if kind == "Ball":
                data["terrain"].append({"kind": "Ball", "pos": np.array(list(map(float, f[2:5]))), "r": float(f[5]), "mat": f[6]})
            elif kind == "Cylinder":
                data["terrain"].append({"kind": "Cylinder", "h": float(f[2]), "r": float(f[3]), "mat": f[4], "pos": np.array(list(map(float, f[5:8]))), "R": np.array(list(map(float, f[8:17]))).reshape(3, 3)})
            else:
                data["terrain"].append({"kind": kind, "size": np.array(list(map(float, f[2:5]))), "mat": f[5], "pos": np.array(list(map(float, f[6:9]))), "R": np.array(list(map(float, f[9:18]))).reshape(3, 3)})
        elif k == "C":
            data["colors"][f[1]] = tuple(map(float, f[2:5]))
        elif k == "Z":
            data["zones"][f[1]] = (np.array(list(map(float, f[2:5]))), float(f[5]))
        elif k == "V":
            data["views"][f[1]] = (np.array(list(map(float, f[2:5]))), np.array(list(map(float, f[5:8]))))
        elif k == "TP":
            data["places"].append((int(f[1]), np.array(list(map(float, f[2:5]))), float(f[5])))
        elif k == "W":
            data["ground" if f[1] == "GroundY" else "water"] = float(f[2])
    return data


# ---------------------------------------------------------------------------------------------
# Dal mondo di Roblox alla scena del motore
# ---------------------------------------------------------------------------------------------


def material_of(name, titan=False):
    if titan and name in ("SmoothPlastic", "Plastic", "Sand", "Pebble", "Fabric", "Concrete", "Granite", "Marble", "Slate"):
        return M_SKIN
    if name in STONE:
        return M_STONE
    if name in ROOF:
        return M_ROOF
    if name in WOOD:
        return M_WOOD
    if name in METAL:
        return M_METAL
    if name == "Fabric":
        return M_CLOTH
    if name == "Neon":
        return M_GLOW
    if name == "Water":
        return M_WATER
    if name == "Glass":
        return M_COLOR
    return M_GRAIN


def to_engine(p, origin):
    """Posizione di Roblox (studs) -> motore (metri), con il terreno a quota 0."""
    return (np.asarray(p, float) - origin) * SCALE


def add_wedge(sc, center, size, R, mat, color):
    x, y, z = size / 2
    L = np.array([
        (-x, -y, -z), (x, -y, -z), (x, -y, z), (-x, -y, z),  # base
        (x, y, z), (-x, y, z),  # spigolo alto (dietro, +Z)
    ])
    V = L @ R.T + center
    F = np.array([(0, 2, 1), (0, 3, 2), (3, 4, 2), (3, 5, 4), (0, 1, 4), (0, 4, 5), (0, 5, 3), (1, 2, 4)])
    sc.add(V, F, mat, color, smooth=False)


def add_part(sc, part, origin, titan=False, offset=None, R0=None, plain=False):
    size = part["size"] * SCALE
    R = part["R"]
    pos = part["pos"]
    if R0 is not None:
        pos = pos @ R0.T
        R = R0 @ R
    if offset is not None:
        pos = pos + offset
    c = to_engine(pos, origin)
    mat = M_COLOR if plain else material_of(part["mat"], titan)
    col = np.clip(part["color"], 0, 1)
    if part["mat"] == "Neon":
        col = col * 2.2
    elif part["mat"] == "Glass":
        col = col * 0.35 + np.array([0.02, 0.03, 0.05])
    shape = part["shape"]
    if shape == "Ellipsoid":
        add_sphere(sc, c, 1.0, mat, col, n=10, scale=size / 2, R=R)
    elif shape == "Ball":
        add_sphere(sc, c, float(np.min(size)) / 2, mat, col, n=10)
    elif shape == "Cylinder":
        axis = R[:, 0]
        add_cylinder(sc, c - axis * size[0] / 2, c + axis * size[0] / 2, float(min(size[1], size[2])) / 2, mat, col, n=14)
    elif shape in ("Wedge", "CornerWedge"):
        add_wedge(sc, c, size, R, mat, col)
    else:
        add_box(sc, c, size, mat, col, R=R, seg=SEG if float(np.max(size)) > SEG else 1e9)


def add_disc(sc, center, axis, r, mat, col, ring_step=12.0, n=64):
    """Disco suddiviso in anelli (per le basi dei cilindri di terreno, larghe centinaia di metri)."""
    axis = axis / np.linalg.norm(axis)
    t = np.cross(axis, [0, 0, 1] if abs(axis[2]) < 0.9 else [1, 0, 0])
    t /= np.linalg.norm(t)
    s = np.cross(axis, t)
    rings = max(1, int(math.ceil(r / ring_step)))
    ang = np.linspace(0, 2 * math.pi, n, endpoint=False)
    V = [center]
    for i in range(1, rings + 1):
        rr = r * i / rings
        V.extend(center + rr * (np.cos(ang)[:, None] * t + np.sin(ang)[:, None] * s))
    V = np.array(V)
    F = []
    for j in range(n):
        F.append((0, 1 + j, 1 + (j + 1) % n))
    for i in range(1, rings):
        a0 = 1 + (i - 1) * n
        b0 = 1 + i * n
        for j in range(n):
            j2 = (j + 1) % n
            F.append((a0 + j, b0 + j, b0 + j2))
            F.append((a0 + j, b0 + j2, a0 + j2))
    sc.add(V, np.array(F), mat, col, N=np.tile(axis, (len(V), 1)))


def add_terrain_cylinder(sc, c, axis, h, r, mat, col):
    a, b = c - axis * h / 2, c + axis * h / 2
    n = max(24, min(160, int(2 * math.pi * r / 6)))
    add_cylinder(sc, a, b, r, mat, col, n=n, caps=False)
    add_disc(sc, b, axis, r, mat, col, n=n)
    add_disc(sc, a, -axis, r, mat, col, n=n)


def seg_dist_xz(p, a, b):
    """Distanza in pianta (x, z) del punto p dal segmento a-b, e posizione lungo il segmento (0..1)."""
    a2, b2, p2 = a[[0, 2]], b[[0, 2]], p[[0, 2]]
    d = b2 - a2
    t = float(np.clip(np.dot(p2 - a2, d) / max(1e-6, np.dot(d, d)), 0.0, 1.0))
    return float(np.linalg.norm(p2 - (a2 + d * t))), t


def build_scene(data, cam_pos, target, reach, clear_view=False):
    """clear_view: toglie colline e alberi tra la telecamera e il soggetto (foto in posa dei giganti)."""
    origin = np.array([0.0, data["ground"], 0.0])

    def in_the_way(p, radius):
        if not clear_view:
            return False
        d, t = seg_dist_xz(p, cam_pos, target)
        return t < 0.97 and d < radius + 14
    sc = Scene()
    colors = dict(TERRAIN_DEFAULT)
    colors.update(data["colors"])
    fwd = (target - cam_pos) / max(1e-6, np.linalg.norm(target - cam_pos))

    def visible(p, radius):
        d = p - cam_pos
        dist = np.linalg.norm(d)
        if dist - radius > reach:
            return False
        if dist > radius + 30 and np.dot(d, fwd) < -radius:
            return False
        # i pezzi minuscoli molto lontani non si vedono
        return radius * 900 > dist or radius > 3

    # mare: un piano al livello dell'acqua attorno alla telecamera (a quadratini, vedi SEG)
    w = to_engine([cam_pos[0], data["water"], cam_pos[2]], origin)
    half = reach * 1.3 * SCALE
    cells = int(min(220, max(40, half * 2 / 18)))
    V, F = grid_quad(w + np.array([-half, 0, -half]), np.array([2 * half, 0, 0]), np.array([0, 0, 2 * half]), cells, cells)
    sc.add(V, F, M_WATER, (0.07, 0.22, 0.26), N=np.tile([0.0, 1.0, 0.0], (len(V), 1)))
    # terreno
    n_t = 0
    for t in data["terrain"]:
        if t["mat"] in ("Air",):
            continue
        col = np.array(colors.get(t["mat"], (0.5, 0.5, 0.5)))
        mat = M_WATER if t["mat"] == "Water" else M_GRAIN
        if t["mat"] in ("Water",):
            continue  # il mare è già il piano d'acqua
        if t["kind"] == "Ball":
            if not visible(t["pos"], t["r"]) or np.linalg.norm(cam_pos - t["pos"]) < t["r"]:
                continue
            if t["pos"][1] + t["r"] > data["ground"] + 1 and in_the_way(t["pos"], math.sqrt(max(0.0, t["r"] ** 2 - (data["ground"] - t["pos"][1]) ** 2))):
                continue
            add_sphere(sc, to_engine(t["pos"], origin), t["r"] * SCALE, mat, col, n=12)
        elif t["kind"] == "Cylinder":
            if not visible(t["pos"], max(t["r"], t["h"])):
                continue
            add_terrain_cylinder(sc, to_engine(t["pos"], origin), t["R"][:, 1], t["h"] * SCALE, t["r"] * SCALE, mat, col)
        else:
            if not visible(t["pos"], float(np.linalg.norm(t["size"])) / 2):
                continue
            if t["kind"] == "Wedge":
                add_wedge(sc, to_engine(t["pos"], origin), t["size"] * SCALE, t["R"], mat, col)
            else:
                add_box(sc, to_engine(t["pos"], origin), t["size"] * SCALE, mat, col, R=t["R"], seg=SEG * 3)
        n_t += 1
    # parti del mondo
    n_p = 0
    for p in data["parts"]:
        if p["alpha"] > 0.9 or not visible(p["pos"], float(np.linalg.norm(p["size"])) / 2):
            continue
        # una parte che contiene la telecamera (es. la chioma di un albero) coprirebbe tutta la foto
        if np.all(np.abs(cam_pos - p["pos"]) < np.abs(p["R"]) @ (p["size"] / 2) + 0.5):
            continue
        if in_the_way(p["pos"], float(np.max(p["size"])) / 2) and float(np.max(p["size"])) < 120:
            continue
        add_part(sc, p, origin)
        n_p += 1
    print(f"  terreno: {n_t} pezzi, mondo: {n_p} parti")
    return sc, origin


def add_titans(sc, data, origin, only=None):
    for idx, pos, yaw in data["places"]:
        titan = data["titans"].get(idx)
        if not titan or (only is not None and idx not in only) or (only is None and idx >= 30):
            continue
        # i giganti guardano verso la telecamera (verso l'esterno del distretto)
        a = yaw + math.pi
        c, s = math.cos(a), math.sin(a)
        R0 = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
        for p in titan["parts"]:
            add_part(sc, p, origin, titan=True, offset=pos, R0=R0, plain=only is not None)


DAY = dict(
    sun_dir=(0.45, 0.62, 0.64), sun_col=(2.4, 2.2, 1.95), sky_top=(0.20, 0.36, 0.66), sky_hor=(0.70, 0.78, 0.86),
    sky_amb=(0.34, 0.39, 0.48), ground_amb=(0.20, 0.18, 0.15), fog_density=0.0016, fog_height=45, cloud_cover=0.38,
    cloud_col=(1.0, 0.98, 0.95), cloud_dark=(0.55, 0.58, 0.66), rays=0.15, bloom=0.3, saturation=1.06, exposure=1.0,
    sun_disk=True, vignette=0.3, ground_mat="ground",
)


STUDIO = dict(
    sun_dir=(0.35, 0.72, 0.6), sun_col=(1.5, 1.46, 1.42), sky_top=(0.92, 0.92, 0.93), sky_hor=(0.99, 0.99, 0.99),
    sky_amb=(0.42, 0.42, 0.45), ground_amb=(0.30, 0.29, 0.29), fog_density=0.0, fog_height=45, cloud_cover=0.0,
    cloud_col=(1.0, 1.0, 1.0), cloud_dark=(0.9, 0.9, 0.9), rays=0.0, bloom=0.12, saturation=1.0, exposure=0.9,
    sun_disk=False, vignette=0.12, ground_mat="ground",
)


def studio_photo(data, name, out_path, width):
    """Il colosso dei filmati da solo, su un pavimento chiaro (come la foto di una statuetta)."""
    cam_pos, target = data["views"][name]
    origin = np.array([0.0, data["ground"], 0.0])
    sc = Scene()
    half = 160.0
    V, F = grid_quad(np.array([-half, 0.0, -half]), np.array([2 * half, 0.0, 0.0]), np.array([0.0, 0.0, 2 * half]), 64, 64)
    sc.add(V, F, M_COLOR, (0.88, 0.88, 0.89), N=np.tile([0.0, 1.0, 0.0], (len(V), 1)))
    add_titans(sc, data, origin, only={30})
    H = int(width * 9 / 16)
    cp = to_engine(cam_pos, origin)
    tp = to_engine(target, origin)
    cam = Camera(cp, tp, 55, width, H)
    look = Look(**dict(STUDIO, shadow_extent=90.0, shadow_center=(0.0, 0.0, 0.0)))
    img = render(sc, cam, look, ss=1, shadow_cache={})
    img.save(out_path)
    print("foto:", out_path)


def photo(data, name, out_path, width):
    if name.startswith("colosso") and name != "colosso_scena":
        return studio_photo(data, name, out_path, width)
    cam_pos, target = data["views"][name]
    reach = 4200 if name == "vermiglia_alto" else 2600
    with_titans = name in ("giganti", "giganti_vicino", "volto", "varieta", "varieta_volti")
    sc, origin = build_scene(data, cam_pos, target, reach, clear_view=with_titans)
    if with_titans:
        add_titans(sc, data, origin)
    if name == "colosso_scena":
        add_titans(sc, data, origin, only={31})
    H = int(width * 9 / 16)
    cp = to_engine(cam_pos, origin)
    tp = to_engine(target, origin)
    cam = Camera(cp, tp, 55 if name != "vermiglia_alto" else 50, width, H)
    dist = float(np.linalg.norm(tp - cp))
    look = Look(**dict(DAY, shadow_extent=max(120.0, dist * 2.2), shadow_center=tuple(tp * np.array([1, 0, 1]))))
    img = render(sc, cam, look, ss=1, shadow_cache={})
    img.save(out_path)
    print("foto:", out_path)


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(1)
    out = args[0]
    width = 1280
    dump_path = None
    names = []
    i = 1
    while i < len(args):
        if args[i] == "--larghezza":
            width = int(args[i + 1])
            i += 2
        elif args[i] == "--dump":
            dump_path = args[i + 1]
            i += 2
        else:
            names.append(args[i])
            i += 1
    os.makedirs(out, exist_ok=True)
    if not dump_path:
        dump_path = os.path.join(out, "mondo.txt")
        print("esporto il mondo...")
        dump(dump_path)
    elif not os.path.exists(dump_path):
        dump(dump_path)
    data = parse(dump_path)
    print(f"mondo: {len(data['parts'])} parti, {len(data['terrain'])} pezzi di terreno, {len(data['titans'])} giganti")
    for name in names or list(data["views"]):
        photo(data, name, os.path.join(out, name + ".png"), width)


if __name__ == "__main__":
    main()
