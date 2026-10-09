#!/usr/bin/env python3
"""Foto di prova: il colosso dei filmati aggrappato al Muro, come in "La Caduta del Muro".

  python3 tools/mesh_titan/muro.py cartella_uscita [--glb GiganteColosso.glb] [--larghezza 960]

Senza --glb usa il colosso fatto con le parti (quello che si vede se il modello 3D non è importato),
con --glb il modello 3D. Il gigante è costruito e animato con il codice vero del gioco (muro.luau:
TitanBuilder, ProceduralAnimator, ArmReach) e fotografato dalle stesse inquadrature del filmato:
dal distretto, la testa da vicino, da fuori mentre ruggisce e da dietro la gamba durante il calcio.
Alla fine unisce tutte le foto in un foglio unico (muro_foglio.png).
"""
import json
import os
import sys
from concurrent.futures import ProcessPoolExecutor

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from video import FILE_HEIGHT, LOOK, SCALE, cf_matrix, mesh_lines, read_glb, run_luau  # noqa: E402
from engine import M_COLOR, M_STONE, M_TEX, Camera, Look, Scene, add_box, grid_quad, render, vertex_normals  # noqa: E402
from world_photo import add_part  # noqa: E402

HEIGHT = 230.0  # il colosso di "La Caduta del Muro" (AbuseEventController)
GIANT_Z = -78.0  # dietro il Muro, come "spot" nel filmato

# il piano come nel filmato (tempi accorciati): presa, ruggito, calcio tenendosi al Muro
PLAN = [(0.3, "Grip", 1), (2.0, "Clip", "Roar"), (4.0, "Clip", "WallKick")]
SHOTS = {1.6: "presa", 2.8: "ruggito", 4.62: "calcio"}

STONE = (0.74, 0.71, 0.65)
GATE = (0.34, 0.24, 0.16)

# inquadrature del filmato (Muro in z = 0, gigante in z = GIANT_Z, distretto verso +Z):
# posizione, punto guardato, campo visivo
VIEWS = {
    "distretto": ((-44.0, 48.0, 476.0), (0.0, 200.0, -70.0), 20),
    "testa": ((52.0, 174.0, 90.0), (0.0, 212.0, -66.0), 58),
    "fuori": ((270.0, 72.0, -240.0), (0.0, 160.0, -78.0), 70),
    "calcio": ((-145.0, 21.0, -250.0), (0.0, 64.0, -20.0), 70),
}


def wall(sc):
    """Il Muro del filmato: segmenti di 70 studs, merli in cima, cancello di legno al centro."""
    seg, height, gate_h = 70.0, 160.0, 160.0 * 0.42
    for i in range(-6, 7):
        x = i * seg
        if i == 0:
            add_box(sc, np.array([x, gate_h + (height - gate_h) / 2, 0.0]) * SCALE, np.array([seg + 1, height - gate_h, 30.0]) * SCALE, M_STONE, STONE, seg=4.0)
            for s in (-1, 1):
                add_box(sc, np.array([x + s * seg * 0.41, gate_h / 2, 0.0]) * SCALE, np.array([seg * 0.2, gate_h, 30.0]) * SCALE, M_STONE, STONE, seg=4.0)
            add_box(sc, np.array([x, gate_h / 2, 0.0]) * SCALE, np.array([seg * 0.62, gate_h, 8.0]) * SCALE, M_COLOR, GATE)
        else:
            add_box(sc, np.array([x, height / 2, 0.0]) * SCALE, np.array([seg + 1, height, 30.0]) * SCALE, M_STONE, STONE, seg=4.0)
            add_box(sc, np.array([x, height + 2.5, 0.0]) * SCALE, np.array([seg + 1, 5.0, 34.0]) * SCALE, M_STONE, (0.6, 0.57, 0.52), seg=4.0)


def parse(out):
    info, frames = {}, []
    for line in out.splitlines():
        f = line.split("\t")
        if f[0] == "S":
            info[int(f[1])] = {"name": f[2], "shape": f[3], "size": np.array(list(map(float, f[4:7]))), "color": np.array(list(map(float, f[7:10]))), "mat": f[10]}
        elif f[0] == "F":
            frames.append({"t": float(f[1]), "parts": {}})
        elif f[0] == "P":
            frames[-1]["parts"][int(f[1])] = cf_matrix(f[2:14])
        elif f[0] == "V":
            frames[-1].setdefault("steam", []).append((np.array(list(map(float, f[1:4]))), np.array(list(map(float, f[4:7])))))
    return info, frames


# getti di vapore del collo per ogni istante (Rate degli emettitori nel filmato: 8, 16 nel ruggito)
STEAM_RATE = {"presa": 8, "ruggito": 16, "calcio": 8}


def steam_particles(jets, rate, seed):
    """Le particelle dei getti "VaporeCollo" (stesse misure di TitanBuilder), come dopo qualche secondo."""
    rng = np.random.default_rng(seed)
    H = HEIGHT
    out = []
    for pos, up in jets:
        up = up / np.linalg.norm(up)
        side = np.cross(up, [0.0, 0.0, 1.0])
        if np.linalg.norm(side) < 1e-3:
            side = np.cross(up, [1.0, 0.0, 0.0])
        side /= np.linalg.norm(side)
        side2 = np.cross(up, side)
        for _ in range(int(rate * 3.6)):
            life = rng.uniform(2.2, 3.6)
            age = rng.uniform(0, life)
            k = age / life
            spread = np.radians(22) * np.sqrt(rng.uniform())
            ang = rng.uniform(0, 2 * np.pi)
            d = up * np.cos(spread) + (side * np.cos(ang) + side2 * np.sin(ang)) * np.sin(spread)
            speed = rng.uniform(0.06 * H, 0.12 * H)
            # resistenza dell'aria (Drag 0.7: la velocità si dimezza ogni 1/0.7 s) e spinta verso l'alto
            travel = speed * (1 - 2 ** (-0.7 * age)) / (0.7 * np.log(2))
            p = pos + d * travel + np.array([0.0, 0.5 * 0.025 * H * age * age, 0.0])
            size = np.interp(k, [0, 0.4, 1], [0.035 * H, 0.11 * H, 0.2 * H])
            alpha = 1 - np.interp(k, [0, 0.5, 1], [0.3, 0.5, 1.0])
            out.append((p * SCALE, size / 2 * SCALE, (1.0, 0.98, 0.95), alpha * 0.85, int(rng.integers(0, 8))))
    return out


SHARED = {}  # dati del gigante: i processi figli li ereditano (fork)


def render_one(args):
    frame, view, width, out = args
    sc = Scene()
    half = 900.0
    V, F = grid_quad(np.array([-half, 0.0, -half]), np.array([2 * half, 0.0, 0.0]), np.array([0.0, 0.0, 2 * half]), 80, 80)
    sc.add(V, F, M_COLOR, (0.36, 0.42, 0.26), N=np.tile([0.0, 1.0, 0.0], (len(V), 1)))
    wall(sc)
    info, meshes = SHARED["info"], SHARED.get("meshes")
    if meshes is not None:
        sc.texture = SHARED["tex"]
    for idx, m in frame["parts"].items():
        part = info[idx]
        if meshes is not None:
            if part["name"] not in meshes:
                continue
            local, uv, faces = meshes[part["name"]]
            P = (local @ m[:3, :3].T + m[:3, 3]) * SCALE
            sc.add(P, faces, M_TEX, (1, 1, 1), N=vertex_normals(P, faces), UV=uv)
        else:
            add_part(sc, dict(part, pos=m[:3, 3], R=m[:3, :3]), np.zeros(3), titan=True)
    when = SHOTS[min(SHOTS, key=lambda t: abs(t - frame["t"]))]
    sc.particles = steam_particles(frame.get("steam", []), STEAM_RATE[when], 7)
    cam_pos, target, fov = VIEWS[view]
    cam = Camera(np.array(cam_pos) * SCALE, np.array(target) * SCALE, fov, width, int(width * 9 / 16))
    look = Look(**dict(LOOK, shadow_extent=160.0, shadow_center=(0.0, 0.0, -10.0)))
    render(sc, cam, look, ss=1, shadow_cache={}).save(out)
    return out


def main():
    args = sys.argv[1:]
    out_dir = args[0]
    width = int(args[args.index("--larghezza") + 1]) if "--larghezza" in args else 960
    glb = args[args.index("--glb") + 1] if "--glb" in args else None
    os.makedirs(out_dir, exist_ok=True)
    lines = ["MESH_LOOK = nil"]
    if glb:
        parts, joints, tex = read_glb(glb)
        look = os.path.splitext(os.path.basename(glb))[0].replace("Gigante", "")
        lines = mesh_lines(parts, joints, look)
        k = HEIGHT / FILE_HEIGHT
        meshes = {}
        for name, p in parts.items():
            lo, hi = p["V"].min(0), p["V"].max(0)
            meshes[name] = ((p["V"] - (lo + hi) / 2) * k, p["UV"], p["F"])
        SHARED["meshes"], SHARED["tex"] = meshes, tex
    lines.append("ANIM_HEIGHT = %.3f" % HEIGHT)
    lines.append("GIANT_Z = %.3f" % GIANT_Z)
    plan = ", ".join("{ %.3f, %s, %s }" % (t, json.dumps(a), json.dumps(v) if isinstance(v, str) else repr(v)) for t, a, v in PLAN)
    lines.append("ANIM_PLAN = { %s }" % plan)
    lines.append("ANIM_SHOTS = { %s }" % ", ".join("%.3f" % t for t in SHOTS))
    out = run_luau(lines, "muro.luau")
    for line in out.splitlines():
        if line.startswith(("MODELLO", "VAPORE")):
            print(line.replace("\t", ": "))
    info, frames = parse(out)
    SHARED["info"] = info
    print("parti visibili:", len(info), "fotogrammi:", len(frames))
    jobs = []
    for frame in frames:
        when = min(SHOTS, key=lambda s: abs(s - frame["t"]))
        for view in VIEWS:
            jobs.append((frame, view, width, os.path.join(out_dir, "muro_%s_%s.png" % (SHOTS[when], view))))
    with ProcessPoolExecutor(max(1, os.cpu_count() or 2)) as ex:
        done = list(ex.map(render_one, jobs))
    for d in done:
        print("  ", os.path.basename(d))
    # foglio unico: una riga per istante, una colonna per inquadratura
    tw = width // 2
    th = int(tw * 9 / 16)
    sheet = Image.new("RGB", (tw * len(VIEWS), (th + 22) * len(frames)), (24, 24, 26))
    draw = ImageDraw.Draw(sheet)
    for r, frame in enumerate(frames):
        when = SHOTS[min(SHOTS, key=lambda s: abs(s - frame["t"]))]
        for c, view in enumerate(VIEWS):
            img = Image.open(os.path.join(out_dir, "muro_%s_%s.png" % (when, view))).resize((tw, th))
            sheet.paste(img, (c * tw, r * (th + 22) + 22))
            draw.text((c * tw + 6, r * (th + 22) + 5), "%s - %s" % (when, view), fill=(235, 235, 235))
    sheet.save(os.path.join(out_dir, "muro_foglio.png"))
    print("foglio:", os.path.join(out_dir, "muro_foglio.png"))


if __name__ == "__main__":
    main()
