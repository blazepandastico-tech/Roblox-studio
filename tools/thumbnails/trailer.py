"""Trailer del gioco: inquadrature 3D animate, testi, musica e montaggio con ffmpeg.

  python3 trailer.py render <modello Meshy> <cartella> <inquadratura> <da> <a> [larghezza altezza]
  python3 trailer.py music <file.wav>
  python3 trailer.py edit <cartella render> <immagine copertina> <musica.wav> <uscita.mp4> [verticale.mp4]
"""
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from engine import (M_GLOW, M_GROUND, M_WATER, M_WOOD, Camera, Look, Scene, add_box, grid_quad, normalize,  # noqa: E402
                    render)
from props import add_house, add_rubble, add_soldier, add_stall, add_tower, add_tree, add_vial, add_wall  # noqa: E402
from scenes import (VIVID, city_block, gas_trail, ground, island_height, add_island, lightning_post, ring_wall,  # noqa: E402
                    steam, street_houses)
from titan import add_titan, joints_world, load  # noqa: E402

FPS = 24

# (nome, durata in secondi)
SHOTS = [
    ("mura", 3.0),
    ("urlo", 3.5),
    ("volo", 4.0),
    ("nuca", 2.5),
    ("isola", 4.0),
    ("citta", 3.0),
    ("raid", 3.0),
    ("siero", 2.5),
]


def ease(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return np.asarray(a, float) * (1 - t) + np.asarray(b, float) * t


STORM = dict(
    sun_dir=(0.35, 0.55, -0.75), sun_col=(1.55, 1.65, 1.95), sky_top=(0.05, 0.06, 0.10), sky_hor=(0.26, 0.29, 0.36),
    sky_amb=(0.22, 0.25, 0.33), ground_amb=(0.10, 0.10, 0.12), fog_density=0.0055, fog_height=60,
    cloud_cover=0.8, cloud_col=(0.50, 0.54, 0.64), cloud_dark=(0.06, 0.07, 0.10), rays=0.0, bloom=0.5,
    ground_mat="cobble", saturation=0.95, exposure=1.1, sun_disk=False,
)


# ---------------------------------------------------------------------------------------------
# Inquadrature: build(m) prepara la scena fissa, frame(ctx, t, W, H) aggiunge ciò che si muove
# ---------------------------------------------------------------------------------------------


def build_mura(m):
    rng = np.random.default_rng(1)
    sc = Scene()
    ground(sc, size=1600, n=50)
    city_block(sc, rng, (0, 0, 120), 150, step=16.0)
    add_wall(sc, (-900, 0, -60), (900, 0, -60), 62, thick=16)
    for x in (-220, -40, 150, 330):
        add_tower(sc, (x, 0, -69), 10, 76)
    # il gigante enorme che guarda oltre le mura
    add_titan(sc, m, 120, (30, 0, -100), yaw=math.radians(8), pose="stand")
    sc.mark_static()
    return {"scene": sc, "rng": rng}


def frame_mura(ctx, t, W, H):
    sc = ctx["scene"].fork()
    rng = np.random.default_rng(int(t * 1000))
    steam(sc, (34, 108, -98), (7, 3, 7), 10, np.random.default_rng(3), size=(7, 14), rise=14 + t * 10, alpha=0.45)
    k = ease(t)
    cam = Camera(lerp((-20, 14, 230), (-12, 34, 175), k), lerp((10, 40, 0), (20, 62, -60), k), 52, W, H, roll=math.radians(-3))
    flash = 0.0
    bolts = []
    if 0.30 < t < 0.42:
        flash = 0.5
        bolts = [(0.72, 0.0, 0.62, 0.42)]
    if 0.78 < t < 0.86:
        flash = 0.35
        bolts = [(0.18, 0.0, 0.26, 0.35)]
    look = Look(**dict(STORM, shadow_extent=400, shadow_center=(0, 0, 0), fog_density=0.0022, fog_height=90))
    post = lightning_post(bolts, flash=flash) if bolts else None
    return render(sc, cam, look, ss=1, extra_post=post, shadow_cache=ctx.setdefault("sh", {}))


def build_urlo(m):
    rng = np.random.default_rng(12)
    sc = Scene()
    ground(sc)
    tpos = np.array([0.0, 0.0, 0.0])
    street_houses(sc, rng, -90, 60, 1, ruined_near=tpos)
    street_houses(sc, rng, -90, 60, -1, ruined_near=tpos)
    add_rubble(sc, tpos + np.array([3, 0, -4]), 7, 18, rng)
    add_wall(sc, (-700, 0, 140), (700, 0, 140), 62, thick=16)
    for x in (-150, 70, 240):
        add_tower(sc, (x, 0, 131), 10, 76)
    sc.mark_static()
    return {"scene": sc, "m": m, "tpos": tpos}


def frame_urlo(ctx, t, W, H):
    sc = ctx["scene"].fork()
    m = ctx["m"]
    H_t = 20.0
    yaw = math.radians(12)
    amount = 0.25 + 0.75 * ease((t - 0.15) / 0.4)
    add_titan(sc, m, H_t, ctx["tpos"], yaw=yaw, pose="roar", amount=amount)
    J = joints_world(m, H_t, ctx["tpos"], yaw)
    steam(sc, J["Neck"] + np.array([0, 1 + t * 3, 0]), (3.0, 1.5 + t * 2, 3.0), 26, np.random.default_rng(7), size=(2.2, 5.5), rise=10 + t * 6, alpha=0.55)
    k = ease(t)
    cam = Camera(lerp((-2.0, 2.0, -44), (-1.5, 3.0, -30), k), lerp((-2.0, 11.0, 0), (-1.0, 14.0, 0), k), 50, W, H, roll=math.radians(-2))
    look = Look(
        sun_dir=(-0.22, 0.20, 0.95), sun_col=(2.6, 1.75, 1.05), sky_top=(0.16, 0.22, 0.42), sky_hor=(1.05, 0.62, 0.36),
        sky_amb=(0.30, 0.31, 0.42), ground_amb=(0.22, 0.15, 0.10), fog_density=0.0045, fog_height=35,
        cloud_cover=0.55, cloud_col=(1.15, 0.72, 0.48), cloud_dark=(0.32, 0.26, 0.30), rays=0.55, bloom=0.4,
        shadow_extent=160, ground_mat="cobble", saturation=1.08, exposure=1.08,
    )
    return render(sc, cam, look, ss=1, shadow_cache=ctx.setdefault("sh", {}))


def build_volo(m):
    rng = np.random.default_rng(22)
    sc = Scene()
    ground(sc)
    tpos = np.array([0.0, 0.0, 30.0])
    street_houses(sc, rng, -120, 90, 1, ruined_near=tpos)
    street_houses(sc, rng, -120, 90, -1, ruined_near=tpos)
    add_wall(sc, (-700, 0, 170), (700, 0, 170), 62, thick=16)
    for x in (-150, 70, 240):
        add_tower(sc, (x, 0, 161), 10, 76)
    add_titan(sc, m, 20, tpos, yaw=math.radians(-5), pose="roar")
    sc.mark_static()
    return {"scene": sc, "m": m, "J": joints_world(m, 20, tpos, math.radians(-5))}


def soldier_path_volo(t):
    z = -60 + 70 * t
    x = 2.5 * math.sin(t * 5.0)
    y = 8 + 4 * math.sin(t * math.pi) + 1.2 * math.sin(t * 9)
    return np.array([x, y, z])


def frame_volo(ctx, t, W, H):
    sc = ctx["scene"].fork()
    J = ctx["J"]
    p = soldier_path_volo(t)
    ahead = soldier_path_volo(min(1, t + 0.02)) - p
    yaw = math.atan2(-ahead[0], -ahead[2])
    roll = -0.5 * math.cos(t * 5.0)
    anchors, _ = add_soldier(sc, p, yaw=yaw, pitch=-1.15, roll=roll, s=1.0, pose="fly")
    # cavi agganciati alle case che cambiano lato mentre vola
    side = 1 if math.sin(t * 10) > 0 else -1
    hook = np.array([side * 10.5, 10.5, p[2] + 14])
    sc.lines.append((anchors[0 if side > 0 else 1], hook, 1.4 * W / 960, (0.10, 0.10, 0.11)))
    if t > 0.75:
        sc.lines.append((anchors[1], J["LeftShoulder"], 1.4 * W / 960, (0.10, 0.10, 0.11)))
    trail = [soldier_path_volo(max(0, t - d)) for d in (0.0, 0.03, 0.06, 0.1, 0.14)]
    gas_trail(sc, trail, np.random.default_rng(int(t * 500)), size=(0.25, 1.0), alpha=0.55)
    cam_t = max(0.0, t - 0.015)
    cp = soldier_path_volo(cam_t) + np.array([-2.2, 1.3, -3.6])
    cam = Camera(cp, p + np.array([0.6, 0.6, 7]), 60, W, H, roll=roll * 0.35)
    look = Look(**dict(VIVID, shadow_extent=200, shadow_center=(0, 0, -20), fog_density=0.003))
    return render(sc, cam, look, ss=1, shadow_cache=ctx.setdefault("sh", {}))


def build_nuca(m):
    rng = np.random.default_rng(21)
    sc = Scene()
    ground(sc, size=1200, n=50)
    H = 21.0
    tpos = np.array([0.0, 0.0, 0.0])
    yaw = math.radians(-20)
    add_titan(sc, m, H, tpos, yaw=yaw, pose="attack")
    city_block(sc, rng, (0, 0, 0), 110, avoid=tpos)
    add_wall(sc, (-900, 0, -260), (900, 0, -260), 62, thick=16)
    for x in (-200, 40, 230):
        add_tower(sc, (x, 0, -251), 10, 76)
    sc.mark_static()
    J = joints_world(m, H, tpos, yaw)
    back = normalize(np.array([math.sin(yaw), 0, math.cos(yaw)]))
    side = np.cross(np.array([0, 1.0, 0]), back)
    return {"scene": sc, "J": J, "back": back, "side": side}


def frame_nuca(ctx, t, W, H):
    sc = ctx["scene"].fork()
    J, back, side = ctx["J"], ctx["back"], ctx["side"]
    nape = J["Nape"]
    campos = nape + back * 13 + side * 9.0 + np.array([0, -1.0, 0])
    vdir = normalize((nape - campos) * np.array([1, 0, 1]))
    lateral = normalize(np.cross(vdir, np.array([0, 1.0, 0])))
    start = nape + np.array([0, 9.0, 0]) - vdir * 6.0 + lateral * 14.0
    end = nape + np.array([0, 1.2, 0]) + back * 0.8 + lateral * 0.8
    k = ease(t / 0.85)
    p = lerp(start, end, k)
    syaw = math.atan2(lateral[0], lateral[2])
    anchors, _ = add_soldier(sc, p, yaw=syaw, pitch=-1.4 - 0.6 * k, roll=0.1, s=1.3, pose="dive")
    for a, tgt in zip(anchors, (J["RightShoulder"], J["LeftShoulder"])):
        sc.lines.append((a, tgt + back * 1.2 + np.array([0, 0.3, 0]), 1.6 * W / 960, (0.10, 0.10, 0.11)))
    trail = [lerp(start, end, ease(max(0, t - d) / 0.85)) for d in (0, 0.05, 0.1, 0.18)]
    gas_trail(sc, trail, np.random.default_rng(int(t * 400)), size=(0.4, 1.4), alpha=0.6)
    if t > 0.85:
        steam(sc, nape + back * 0.8, (1.5, 1.0, 1.5), 22, np.random.default_rng(9), size=(1.2, 3.5), rise=2 + (t - 0.85) * 30, alpha=0.75)
    cam = Camera(campos, nape + np.array([0, 2.6, 0]) - back * 3 + side * 1.5, 55 - 6 * k, W, H, roll=math.radians(-4))
    look = Look(shadow_extent=160, **STORM)
    post = lightning_post([(0.83, 0.0, 0.76, 0.45)], flash=0.12) if 0.1 < t < 0.2 else None
    return render(sc, cam, look, ss=1, extra_post=post, shadow_cache=ctx.setdefault("sh", {}))


def build_isola(m):
    rng = np.random.default_rng(31)
    sc = Scene()
    V, F = grid_quad((-6000, -2.0, -6000), (12000, 0, 0), (0, 0, 12000), 40, 40)
    sc.add(V, F, M_WATER, (0.03, 0.16, 0.26), smooth=False)
    add_island(sc, (0, 0, 0), 470, n=130, flat=230, seed=1)
    for c, r, sd in (((-1500, 0, 2300), 520, 2), ((1700, 0, 2900), 650, 3), ((300, 0, 4200), 800, 4)):
        add_island(sc, c, r, n=50, flat=10, seed=sd, color=(0.36, 0.38, 0.28))
    ring_wall(sc, (0, 0, 0), 200, 36, segments=24)
    city_block(sc, rng, (0, 0, 0), 185, min_h=6, max_h=13, step=18.0)
    add_tower(sc, (0, 0, 0), 14, 46, roof=(0.25, 0.30, 0.42))
    for _ in range(90):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(225, 380)
        x, z = math.cos(a) * r, math.sin(a) * r
        y = float(island_height(np.array([x]), np.array([z]), 470, 230, 1)[0])
        if y > -1:
            add_tree(sc, (x, y, z), rng.uniform(9, 16), rng)
    for x, z, yw, h in ((-175, -255, math.radians(220), 26), (-95, -300, math.radians(195), 22), (-255, -165, math.radians(240), 24), (260, -120, math.radians(110), 24)):
        y = float(island_height(np.array([x]), np.array([z]), 470, 230, 1)[0])
        add_titan(sc, m, h, (x, y, z), yaw=yw + math.pi, pose="roar" if h > 24 else "stand")
    sc.mark_static()
    return {"scene": sc}


def frame_isola(ctx, t, W, H):
    sc = ctx["scene"].fork()
    rng = np.random.default_rng(int(t * 300))
    for i, (r, h, ph) in enumerate(((150, 60, 0.0), (120, 70, 2.1), (170, 55, 4.0))):
        a = ph + t * 1.6
        p = np.array([math.cos(a) * r, h, math.sin(a) * r])
        d = np.array([-math.sin(a), 0, math.cos(a)])
        add_soldier(sc, p, yaw=math.atan2(-d[0], -d[2]), pitch=-1.1, roll=0.4, s=2.4, pose="fly")
        gas_trail(sc, [p, p - d * 10, p - d * 20], rng, size=(0.9, 2.6), alpha=0.5)
    a = math.radians(-128) + t * 0.55
    campos = np.array([math.cos(a) * 470, 160 - 40 * t, math.sin(a) * 470])
    cam = Camera(campos, (0, 10, 0), 50, W, H, roll=math.radians(3))
    look = Look(
        sun_dir=(-0.75, 0.33, 0.57), sun_col=(2.4, 1.8, 1.25), sky_top=(0.18, 0.32, 0.60), sky_hor=(0.95, 0.75, 0.58),
        sky_amb=(0.30, 0.36, 0.50), ground_amb=(0.16, 0.14, 0.10), fog_density=0.00045, fog_height=160,
        cloud_cover=0.45, cloud_col=(1.2, 0.85, 0.6), cloud_dark=(0.35, 0.32, 0.40), rays=0.3, bloom=0.45,
        shadow_extent=620, shadow_center=(0, 0, 0), ground_mat="ground", saturation=1.12, exposure=1.0,
    )
    return render(sc, cam, look, ss=1, shadow_cache=ctx.setdefault("sh", {}))


CITIZEN_OUTFITS = [
    {"jacket": (0.62, 0.20, 0.16), "pants": (0.30, 0.24, 0.18), "shirt": (0.92, 0.88, 0.80), "cape": None},
    {"jacket": (0.20, 0.36, 0.55), "pants": (0.28, 0.26, 0.24), "shirt": (0.95, 0.93, 0.88), "cape": None},
    {"jacket": (0.55, 0.48, 0.30), "pants": (0.22, 0.20, 0.18), "shirt": (0.80, 0.30, 0.25), "cape": None},
    {"jacket": (0.40, 0.25, 0.45), "pants": (0.35, 0.30, 0.25), "shirt": (0.95, 0.90, 0.70), "cape": None},
    {"jacket": (0.25, 0.42, 0.25), "pants": (0.40, 0.32, 0.22), "shirt": (0.90, 0.90, 0.90), "cape": None},
]
HAIRS = [(0.28, 0.17, 0.09), (0.12, 0.09, 0.07), (0.70, 0.55, 0.30), (0.45, 0.25, 0.12), (0.55, 0.52, 0.50)]


def build_citta(m):
    rng = np.random.default_rng(41)
    sc = Scene()
    ground(sc)
    street_houses(sc, rng, -80, 80, 1)
    street_houses(sc, rng, -80, 80, -1)
    for i, z in enumerate(range(-30, 40, 9)):
        side = 1 if i % 2 == 0 else -1
        add_stall(sc, np.array([side * 6.3, 0, z]), math.pi / 2 * side, rng)
    add_wall(sc, (-700, 0, 170), (700, 0, 170), 62, thick=16)
    sc.mark_static()
    walkers = []
    for i in range(14):
        walkers.append({
            "x": rng.uniform(-3.8, 3.8), "z": rng.uniform(-6, 42), "dir": rng.choice([-1, 1]), "speed": rng.uniform(1.0, 1.4),
            "outfit": CITIZEN_OUTFITS[i % len(CITIZEN_OUTFITS)], "hair": HAIRS[(i * 3) % len(HAIRS)], "phase": rng.uniform(0, 6.28),
        })
    return {"scene": sc, "walkers": walkers}


def frame_citta(ctx, t, W, H):
    sc = ctx["scene"].fork()
    time = t * 3.0
    for w in ctx["walkers"]:
        z = w["z"] + w["dir"] * w["speed"] * time
        ph = w["phase"] + time * 7.0
        swing = 0.45 * math.sin(ph)
        add_soldier(sc, np.array([w["x"], 0.95 + 0.04 * abs(math.cos(ph)), z]), yaw=0.0 if w["dir"] < 0 else math.pi, pose="stand", blades=False,
                    hair=w["hair"], outfit=dict(w["outfit"], gear=False), overrides={"legs": (swing, -swing), "armR": (-swing * 0.8, 0.08), "armL": (swing * 0.8, 0.08)})
    # il soldato che saluta in primo piano
    add_soldier(sc, np.array([2.4, 1.0, -15.5]), yaw=math.radians(25), pose="hero", head_scale=1.1)
    k = ease(t)
    cam = Camera(lerp((-3.0, 2.6, -24), (-1.0, 2.3, -21), k), lerp((1.5, 2.2, 0), (1.0, 2.4, 0), k), 48, W, H)
    look = Look(**dict(VIVID, sun_dir=(0.6, 0.55, -0.55), shadow_extent=120, shadow_center=(0, 0, 0)))
    return render(sc, cam, look, ss=1, shadow_cache=ctx.setdefault("sh", {}))


def build_raid(m):
    rng = np.random.default_rng(51)
    sc = Scene()
    ground(sc, size=1400, n=60, color=(0.50, 0.46, 0.38))
    # arena: anello di pietra con gradinate
    ring_wall(sc, (0, 0, 0), 120, 18, segments=28, towers=6)
    add_titan(sc, m, 38, (0, 0, 20), yaw=math.radians(180), pose="roar")
    add_titan(sc, m, 20, (-35, 0, 0), yaw=math.radians(150), pose="attack")
    add_titan(sc, m, 22, (38, 0, 5), yaw=math.radians(215), pose="stand")
    sc.mark_static()
    return {"scene": sc, "J": joints_world(m, 38, (0, 0, 20), math.radians(180))}


def frame_raid(ctx, t, W, H):
    sc = ctx["scene"].fork()
    rng = np.random.default_rng(int(t * 300))
    J = ctx["J"]
    for i in range(5):
        a = i / 5 * 2 * math.pi + t * 2.2
        r = 28 + 6 * math.sin(i)
        p = np.array([math.cos(a) * r, 22 + 6 * math.sin(a * 2 + i), 20 + math.sin(a) * r])
        d = np.array([-math.sin(a), 0, math.cos(a)])
        anchors, _ = add_soldier(sc, p, yaw=math.atan2(-d[0], -d[2]), pitch=-1.1, roll=0.45, s=1.2, pose="fly")
        sc.lines.append((anchors[0], J["Nape"] + np.array([0, 0.5, 0]), 1.2 * W / 960, (0.1, 0.1, 0.11)))
        gas_trail(sc, [p, p - d * 6, p - d * 12], rng, size=(0.4, 1.4), alpha=0.5)
    steam(sc, J["Neck"] + np.array([0, 2, 0]), (4, 2, 4), 18, np.random.default_rng(4), size=(3, 7), rise=12 + t * 6, alpha=0.5)
    a = math.radians(-80) + t * 0.6
    cam = Camera(np.array([math.cos(a) * 95, 14 + 6 * t, 20 + math.sin(a) * 95]), (0, 22, 20), 55, W, H)
    look = Look(
        sun_dir=(0.5, 0.22, 0.8), sun_col=(2.7, 1.6, 0.9), sky_top=(0.20, 0.14, 0.32), sky_hor=(1.15, 0.50, 0.25),
        sky_amb=(0.34, 0.28, 0.36), ground_amb=(0.22, 0.14, 0.10), fog_density=0.003, fog_height=60,
        cloud_cover=0.55, cloud_col=(1.3, 0.62, 0.35), cloud_dark=(0.30, 0.16, 0.22), rays=0.45, bloom=0.5,
        shadow_extent=260, shadow_center=(0, 0, 0), ground_mat="ground", saturation=1.15, exposure=1.08,
    )
    return render(sc, cam, look, ss=1, shadow_cache=ctx.setdefault("sh", {}))


def build_siero(m):
    sc = Scene()
    add_box(sc, (0, -0.05, 0), (3.0, 0.1, 1.6), M_WOOD, (0.35, 0.22, 0.12), seg=0.3)
    # scrigno aperto e pergamena
    add_box(sc, (0.9, 0.12, 0.35), (0.7, 0.24, 0.45), M_WOOD, (0.30, 0.18, 0.10), seg=0.2)
    add_box(sc, (-0.9, 0.01, 0.2), (0.8, 0.02, 0.55), M_WOOD, (0.80, 0.72, 0.55), seg=0.2)
    V, F = grid_quad((-30, -1.2, -30), (60, 0, 0), (0, 0, 60), 6, 6)
    sc.add(V, F, M_GROUND, (0.15, 0.12, 0.10), smooth=False)
    sc.mark_static()
    return {"scene": sc}


def frame_siero(ctx, t, W, H):
    sc = ctx["scene"].fork()
    pulse = 0.8 + 0.4 * math.sin(t * 12)
    add_vial(sc, (0, 0.0, 0), h=0.32, color=(0.5 * pulse, 3.2 * pulse, 1.3 * pulse))
    add_vial(sc, (-0.35, 0.0, 0.25), h=0.26, color=(3.0 * pulse, 0.6 * pulse, 0.4 * pulse))
    add_vial(sc, (0.38, 0.0, 0.22), h=0.26, color=(0.6 * pulse, 1.2 * pulse, 3.2 * pulse))
    rng = np.random.default_rng(5)
    for i in range(30):
        ang = rng.uniform(0, 6.28)
        r = rng.uniform(0.1, 0.6)
        y = (rng.uniform(0, 0.8) + t * 0.5) % 0.9
        sc.particles.append(((math.cos(ang + t) * r, y, math.sin(ang + t) * r), 0.012, (0.6, 2.5, 1.2), 0.9, i))
    k = ease(t)
    cam = Camera(lerp((0.0, 0.35, -1.6), (0.05, 0.28, -1.05), k), (0, 0.18, 0), 40, W, H)
    look = Look(
        sun_dir=(-0.4, 0.8, -0.3), sun_col=(0.5, 0.45, 0.4), sky_top=(0.0, 0.0, 0.0), sky_hor=(0.02, 0.03, 0.03),
        sky_amb=(0.06, 0.08, 0.07), ground_amb=(0.03, 0.03, 0.03), fog_density=0.0, cloud_cover=0.0, rays=0.0, bloom=0.9,
        shadow_extent=6, ground_mat="ground", saturation=1.2, exposure=1.3, sun_disk=False, dof=(1.2, 0.6),
    )
    return render(sc, cam, look, ss=1, shadow_cache=ctx.setdefault("sh", {}), particle_light=1.0)


# ---------------------------------------------------------------------------------------------
# Render di un intervallo di fotogrammi (più processi in parallelo)
# ---------------------------------------------------------------------------------------------


def cmd_renderall(fbx_dir, out, worker, workers, W=1280, H=720):
    """Ogni processo prende una parte di ogni inquadratura (così lavorano tutti in parallelo)."""
    for shot, dur in SHOTS:
        n = int(round(dur * FPS))
        per = (n + workers - 1) // workers
        cmd_render(fbx_dir, out, shot, worker * per, (worker + 1) * per, W, H)


def cmd_render(fbx_dir, out, shot, a, b, W=1280, H=720):
    import time
    os.makedirs(out, exist_ok=True)
    m = load(fbx_dir)
    dur = dict(SHOTS)[shot]
    n = int(round(dur * FPS))
    todo = [i for i in range(a, min(b, n)) if not os.path.exists(os.path.join(out, f"{shot}_{i:04d}.png"))]
    if not todo:
        return
    ctx = globals()["build_" + shot](m)
    for i in todo:
        path = os.path.join(out, f"{shot}_{i:04d}.png")
        if os.path.exists(path):
            continue
        t0 = time.time()
        img = globals()["frame_" + shot](ctx, i / max(1, n - 1), W, H)
        img.save(path)
        print(f"{shot} {i + 1}/{n} {time.time() - t0:.1f}s", flush=True)


# ---------------------------------------------------------------------------------------------
# Musica epica sintetizzata (niente copyright): tamburi, "braam", archi, crescendo
# ---------------------------------------------------------------------------------------------

SR = 44100
INTRO = 2.5
OUTRO = 4.5


def timeline():
    """Inizio di ogni parte del trailer (in secondi)."""
    t = INTRO
    starts = {"intro": 0.0}
    for name, dur in SHOTS:
        starts[name] = t
        t += dur
    starts["fine"] = t
    return starts, t + OUTRO


def _note(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def cmd_music(path):
    from scipy.signal import butter, fftconvolve, sosfilt
    import wave
    starts, total = timeline()
    N = int(total * SR) + SR
    L = np.zeros(N)
    Rch = np.zeros(N)
    rng = np.random.default_rng(1)
    tt = np.arange(N) / SR

    def add(sig, at, gain=1.0, pan=0.0):
        i = int(at * SR)
        if i >= N:
            return
        sig = sig[: N - i]
        L[i:i + len(sig)] += sig * gain * (1 - max(0, pan))
        Rch[i:i + len(sig)] += sig * gain * (1 + min(0, pan))

    def lp(x, f, order=2):
        return sosfilt(butter(order, min(f, SR * 0.45), "low", fs=SR, output="sos"), x)

    def bp(x, lo, hi):
        return sosfilt(butter(2, [lo, hi], "band", fs=SR, output="sos"), x)

    def saw(freq, dur, detune=0.0, phase=0.0):
        t = np.arange(int(dur * SR)) / SR
        return 2 * ((t * freq * (1 + detune) + phase) % 1.0) - 1

    def env(n, a, d, sustain=1.0, release=0.3):
        e = np.ones(n) * sustain
        ia = max(1, int(a * SR))
        e[:ia] = np.linspace(0, 1, ia)
        ir = max(1, int(release * SR))
        if n > ir:
            e[-ir:] *= np.linspace(1, 0, ir)
        dec = np.exp(-np.arange(n) / SR / d) if d else 1
        return e * dec

    def taiko(at, gain=1.0, pitch=1.0):
        n = int(1.2 * SR)
        t = np.arange(n) / SR
        f = 88 * pitch * (1 + 1.5 * np.exp(-t * 30))
        body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 5)
        skin = bp(rng.normal(0, 1, n), 150, 1600) * np.exp(-t * 16) * 1.0
        add(np.tanh((body + skin) * 1.5), at, gain)

    def braam(at, root=38, dur=3.0, gain=1.0):
        n = int(dur * SR)
        sig = np.zeros(n)
        for note, g in ((root, 1.0), (root + 12, 0.7), (root + 7, 0.5), (root + 19, 0.3)):
            for dt in (-0.006, 0.0, 0.007):
                sig += saw(_note(note), dur, dt, rng.random()) * g
        t = np.arange(n) / SR
        sig = np.tanh(sig * 0.6)
        # filtro che si apre e si richiude (a blocchi)
        out = np.zeros(n)
        blk = 2048
        for i in range(0, n, blk):
            fc = 200 + 2600 * np.exp(-((i / SR) - 0.15) ** 2 / 0.35)
            out[i:i + blk] = lp(sig[max(0, i - 4096):i + blk], fc)[-len(sig[i:i + blk]):]
        out *= env(n, 0.02, dur * 0.5, release=0.6)
        add(out * 0.35, at, gain)

    def whoosh(at, dur=0.8, gain=0.5, up=True):
        n = int(dur * SR)
        noise = rng.normal(0, 1, n)
        out = np.zeros(n)
        blk = 1024
        for i in range(0, n, blk):
            k = i / n
            fc = 300 + (4000 * k if up else 4000 * (1 - k))
            seg = bp(noise[max(0, i - 2048):i + blk], fc * 0.6, fc * 1.4)[-len(noise[i:i + blk]):]
            out[i:i + blk] = seg
        e = np.sin(np.linspace(0, np.pi, n)) ** 2
        add(out * e * 0.5, at - (dur if up else 0), gain)

    def thunder(at, gain=0.8):
        n = int(3.0 * SR)
        t = np.arange(n) / SR
        x = lp(rng.normal(0, 1, n), 400) * (np.exp(-t * 1.2) + 0.6 * np.exp(-((t - 0.25) ** 2) / 0.02))
        crack = bp(rng.normal(0, 1, n), 800, 5000) * np.exp(-t * 25) * 0.4
        add(np.tanh((x * 3 + crack)) * 0.6, at, gain, pan=rng.uniform(-0.4, 0.4))

    def strings(at, notes, dur, gain=0.25):
        n = int(dur * SR)
        sig = np.zeros(n)
        for note in notes:
            for dt in (-0.004, 0.0, 0.005):
                sig += saw(_note(note), dur, dt, rng.random())
        sig = lp(sig, 2600) * env(n, 0.35, 0, release=0.5)
        add(sig * gain / len(notes), at, 1.0)

    def ostinato(at, dur, root=50, gain=0.22, rate=8):
        step = 1.0 / rate
        pattern = [0, 0, 12, 0, 7, 0, 10, 0]
        k = 0
        x = at
        while x < at + dur - 1e-6:
            note = root + pattern[k % len(pattern)]
            n = int(step * 0.95 * SR)
            s = (saw(_note(note), step * 0.95) + saw(_note(note), step * 0.95, 0.004)) * 0.5
            s = lp(s, 3400) * np.exp(-np.arange(n) / SR * 8)
            add(s, x, gain, pan=0.25 if k % 2 else -0.25)
            k += 1
            x += step

    def heartbeat(at, gain=0.7):
        for off in (0.0, 0.28):
            n = int(0.5 * SR)
            t = np.arange(n) / SR
            add(np.sin(2 * np.pi * 50 * t) * np.exp(-t * 9) * (1 if off == 0 else 0.7), at + off, gain)

    def riser(at, dur, gain=0.35):
        n = int(dur * SR)
        t = np.arange(n) / SR
        sig = np.zeros(n)
        for f0 in (220, 330, 440):
            f = f0 * (1 + t / dur)
            sig += np.sin(2 * np.pi * np.cumsum(f) / SR)
        noise = bp(rng.normal(0, 1, n), 1500, 8000)
        e = (t / dur) ** 2
        add((sig * 0.3 + noise * 0.25) * e, at, gain)

    def shimmer(at, dur, gain=0.15):
        n = int(dur * SR)
        t = np.arange(n) / SR
        sig = np.zeros(n)
        for note in (74, 77, 81, 86):
            sig += np.sin(2 * np.pi * _note(note) * t + rng.random() * 6) * (0.5 + 0.5 * np.sin(t * 3 + note))
        add(sig * env(n, 0.5, 0, release=0.8) / 4, at, gain)

    S = starts
    # INTRO: battito, vento, primo colpo
    wind = lp(rng.normal(0, 1, int(INTRO * SR)), 500) * 0.25
    add(wind * np.linspace(0, 1, len(wind)), 0.0)
    heartbeat(0.4)
    heartbeat(1.4)
    riser(S["mura"] - 1.6, 1.6)
    # MURA: colpo enorme + tuono
    braam(S["mura"], 38, 3.0, 1.1)
    thunder(S["mura"] + 0.9)
    thunder(S["mura"] + 2.4, 0.6)
    taiko(S["mura"], 1.2, 0.8)
    # URLO
    braam(S["urlo"] + 0.6, 36, 3.0, 1.0)
    for i in range(4):
        taiko(S["urlo"] + 0.6 + i * 0.75, 0.9)
    strings(S["urlo"], [62, 65, 69], 3.5, 0.35)
    # dal VOLO in poi: ritmo incalzante con accordi Rem - Sib - Fa - Do
    prog = [(50, [50, 53, 57]), (46, [46, 50, 53]), (41, [53, 57, 60]), (48, [48, 52, 55])]
    whoosh(S["volo"], 0.9, 0.7)
    t0 = S["volo"]
    t_end = S["siero"]
    bar = 2.0
    k = 0
    x = t0
    while x < t_end - 0.01:
        root, chord = prog[k % 4]
        d = min(bar, t_end - x)
        ostinato(x, d, root + 12, 0.34)
        strings(x, [c + 12 for c in chord] + [chord[0] + 24], d, 0.42 + 0.08 * (x > S["isola"]))
        for b in range(int(d / 0.5)):
            taiko(x + b * 0.5, 0.75 if b % 2 == 0 else 0.45, 1.0 if b % 2 == 0 else 1.4)
            if x > S["raid"]:
                taiko(x + b * 0.5 + 0.25, 0.4, 1.6)
        k += 1
        x += bar
    for name in ("nuca", "isola", "citta", "raid"):
        whoosh(S[name], 0.6, 0.5)
        braam(S[name], 38, 2.0, 0.6)
    # SIERO: silenzio improvviso, luccichio misterioso
    shimmer(S["siero"], 2.5, 0.2)
    heartbeat(S["siero"] + 0.6, 0.6)
    riser(S["fine"] - 1.5, 1.5, 0.45)
    # FINE: colpo finale e accordo lungo
    braam(S["fine"], 38, 4.5, 1.2)
    taiko(S["fine"], 1.3, 0.8)
    strings(S["fine"], [62, 69, 74, 77], 4.5, 0.5)
    # riverbero
    ir_n = int(2.2 * SR)
    ir = rng.normal(0, 1, ir_n) * np.exp(-np.arange(ir_n) / SR * 2.5)
    ir /= np.sqrt(np.sum(ir ** 2))
    Lw = L + fftconvolve(L, ir)[:N] * 0.35
    Rw = Rch + fftconvolve(Rch, ir[::-1].copy())[:N] * 0.35
    out = np.stack([Lw, Rw], -1)[: int(total * SR)]
    # meno bassi (si sente meglio anche dal telefono) e niente rimbombo sotto i 35 Hz
    hp = butter(2, 35, "high", fs=SR, output="sos")
    low = butter(2, 140, "low", fs=SR, output="sos")
    for ch in range(2):
        x = sosfilt(hp, out[:, ch])
        out[:, ch] = x - 0.45 * sosfilt(low, x)
    # dissolvenza finale e normalizzazione
    fade = int(1.2 * SR)
    out[-fade:] *= np.linspace(1, 0, fade)[:, None]
    out = np.tanh(out / np.max(np.abs(out)) * 1.3) * 0.89
    data = (out * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("musica:", path, round(total, 1), "s")


# ---------------------------------------------------------------------------------------------
# Montaggio: testi animati, effetti, finale con il logo, versione verticale
# ---------------------------------------------------------------------------------------------


def _text_layer(text, size, top, bottom, W, H, game=True):
    from PIL import Image as _I
    from compose import _game_text, plain_text, SANS
    layer = _I.new("RGBA", (W, H), (0, 0, 0, 0))
    if game:
        layer, _, _ = _game_text(layer, text, size, (W / 2, H / 2), top, bottom, ow=max(3, int(size * 0.1)))
        return layer
    rgb = _I.new("RGB", (W, H), (0, 0, 0))
    # testo semplice bianco con ombra: disegnato su nero e trasformato in alfa
    img, _ = plain_text(rgb, text, size, (W / 2, H / 2), color=(255, 255, 255), path=SANS, spacing=0.04)
    a = np.asarray(img.convert("L"))
    out = np.zeros((H, W, 4), np.uint8)
    out[..., :3] = np.asarray(img)
    out[..., 3] = np.clip(a.astype(int) * 2, 0, 255)
    return _I.fromarray(out, "RGBA")


class Title:
    def __init__(self, text, size, y, t0, t1, W, H, top=(255, 236, 160), bottom=(230, 120, 30), game=True, slam=True):
        self.layer = _text_layer(text, size, top, bottom, W, int(size * 2.4), game)
        self.y, self.t0, self.t1, self.slam = y, t0, t1, slam

    def draw(self, frame, t):
        if t < self.t0 or t > self.t1:
            return frame
        k = (t - self.t0) / 0.22
        out_k = (self.t1 - t) / 0.18
        alpha = min(1.0, k, out_k)
        scale = 1.0 + (0.35 * max(0.0, 1 - k) if self.slam else 0.0)
        L = self.layer
        if scale != 1.0:
            L = L.resize((int(L.width * scale), int(L.height * scale)))
        if alpha < 1:
            a = np.asarray(L.getchannel("A")).astype(np.float64) * max(0.0, alpha)
            L = L.copy()
            L.putalpha(Image.fromarray(a.astype(np.uint8)))
        x = (frame.width - L.width) // 2
        y = int(self.y - L.height / 2)
        base = frame.convert("RGBA")
        base.alpha_composite(L, (max(0, x), max(0, y)) if x >= 0 else (0, max(0, y)))
        return base.convert("RGB")


def _shake(frame, amount, t):
    if amount <= 0:
        return frame
    W, H = frame.size
    z = 1.0 + amount * 0.04
    big = frame.resize((int(W * z), int(H * z)))
    dx = int((big.width - W) / 2 + math.sin(t * 90) * amount * W * 0.012)
    dy = int((big.height - H) / 2 + math.cos(t * 77) * amount * H * 0.012)
    return big.crop((dx, dy, dx + W, dy + H))


def _flash(frame, k, color=(255, 255, 255)):
    if k <= 0:
        return frame
    return Image.blend(frame, Image.new("RGB", frame.size, color), min(1.0, k))


def _darken_bottom(frame, strength=0.6):
    W, H = frame.size
    y = np.linspace(0, 1, H)[:, None, None]
    a = np.clip((y - 0.55) / 0.45, 0, 1) ** 1.5 * strength
    arr = np.asarray(frame).astype(np.float64) * (1 - a)
    return Image.fromarray(arr.astype(np.uint8))


def _slash(frame, k):
    """Fendente luminoso a forma di arco."""
    from PIL import ImageDraw, ImageFilter
    W, H = frame.size
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    box = [W * 0.28, H * 0.18, W * 0.78, H * 0.88]
    start = 200
    end = 200 + 140 * min(1, k * 2)
    d.arc(box, start, end, fill=(255, 255, 255, int(255 * max(0, 1 - k))), width=int(H * 0.018))
    glow = layer.filter(ImageFilter.GaussianBlur(H * 0.02))
    base = frame.convert("RGBA")
    base.alpha_composite(glow)
    base.alpha_composite(glow)
    base.alpha_composite(layer)
    return base.convert("RGB")


def cmd_edit(frames_dir, cover_path, music, out_path, vertical_path=None):
    import subprocess
    import tempfile
    from scenes import rain_overlay
    from compose import plaque
    probe = Image.open(os.path.join(frames_dir, f"{SHOTS[0][0]}_0000.png"))
    W, H = probe.size
    starts, total = timeline()
    tmp = tempfile.mkdtemp(prefix="trailer_")
    idx = 0
    gold = ((255, 236, 160), (230, 120, 30))
    white = ((255, 255, 255), (200, 210, 230))

    def save(img):
        nonlocal idx
        img.save(os.path.join(tmp, f"f_{idx:05d}.jpg"), quality=94)
        idx += 1

    # INTRO: testo nel buio con lampi
    intro_titles = [
        Title("UN TEMPO LE MURA CI PROTEGGEVANO...", int(H * 0.055), H * 0.5, 0.15, 2.3, W, H, top=(235, 235, 240), bottom=(170, 175, 190), game=False, slam=False),
    ]
    n = int(INTRO * FPS)
    for i in range(n):
        t = i / FPS
        img = Image.new("RGB", (W, H), (0, 0, 0))
        for ti in intro_titles:
            img = ti.draw(img, t)
        if 1.55 < t < 1.68:
            img = _flash(img, 0.25, (200, 210, 255))
        save(img)

    shot_titles = {
        "mura": [Title("I GIGANTI SONO TORNATI", int(H * 0.11), H * 0.80, 0.9, 2.95, W, H, *white)],
        "urlo": [Title("IL GIGANTE DELLA FURIA", int(H * 0.075), H * 0.86, 1.6, 3.45, W, H, *gold)],
        "volo": [Title("VOLA CON IL DISPOSITIVO DI MANOVRA", int(H * 0.075), H * 0.84, 0.4, 3.9, W, H, *gold)],
        "nuca": [Title("COLPISCI LA NUCA!", int(H * 0.12), H * 0.78, 2.05, 2.5, W, H, *white)],
        "isola": [Title("5 ISOLE DA ESPLORARE", int(H * 0.095), H * 0.16, 0.3, 3.9, W, H, *gold),
                  Title("Storia originale in 4 stagioni", int(H * 0.045), H * 0.27, 0.6, 3.9, W, H, game=False, slam=False)],
        "citta": [Title("CITTÀ PIENE DI VITA", int(H * 0.095), H * 0.16, 0.3, 2.95, W, H, *gold),
                  Title("Meteo dinamico • Giorno e notte • Mercati", int(H * 0.042), H * 0.27, 0.5, 2.95, W, H, game=False, slam=False)],
        "raid": [Title("RAID IN SQUADRA", int(H * 0.1), H * 0.80, 0.3, 2.95, W, H, *gold),
                 Title("Boss giganti • Livello massimo 2000", int(H * 0.045), H * 0.91, 0.5, 2.95, W, H, game=False, slam=False)],
        "siero": [Title("I SIERI DEI GIGANTI...", int(H * 0.085), H * 0.18, 0.25, 2.45, W, H, top=(200, 255, 210), bottom=(40, 190, 90)),
                  Title("in arrivo nei prossimi aggiornamenti", int(H * 0.042), H * 0.85, 0.7, 2.45, W, H, game=False, slam=False)],
    }
    for name, dur in SHOTS:
        n = int(round(dur * FPS))
        for i in range(n):
            t = i / FPS
            k = i / max(1, n - 1)
            img = Image.open(os.path.join(frames_dir, f"{name}_{i:04d}.png")).convert("RGB")
            if name == "urlo":
                img = _shake(img, max(0.0, 1 - abs(k - 0.45) / 0.2), t)
            if name in ("mura", "nuca"):
                img = rain_overlay(img, amount=int(900 * W / 960), seed=i * 7 + len(name))
            if name == "nuca" and k > 0.82:
                img = _slash(img, (k - 0.82) / 0.18)
                img = _flash(img, max(0.0, 0.6 - (k - 0.82) * 4))
            if name == "mura" and i < 8:
                img = _flash(img, 1 - i / 8, (0, 0, 0))
            if i < 2 and name != "mura":
                img = _flash(img, 0.55 - i * 0.25)
            if name in ("mura", "nuca", "raid", "urlo", "volo"):
                img = _darken_bottom(img, 0.45)
            for ti in shot_titles.get(name, []):
                img = ti.draw(img, t)
            save(img)

    # FINALE: copertina, logo che entra, "GIOCA ORA SU ROBLOX"
    cover = Image.open(cover_path).convert("RGB").resize((W, H), Image.LANCZOS)
    logo_layer = plaque(Image.new("RGB", (W, H), (0, 0, 0)), W / 2, H * 0.40, 0.95 * W / 1920 * 1.25)
    logo_mask = np.asarray(logo_layer.convert("L")) > 6
    logo_rgba = logo_layer.convert("RGBA")
    logo_rgba.putalpha(Image.fromarray((logo_mask * 255).astype(np.uint8)))
    play = Title("GIOCA ORA SU ROBLOX", int(H * 0.085), H * 0.80, 1.4, OUTRO, W, H, top=(255, 255, 255), bottom=(255, 210, 120))
    code = Title("Codice regalo: SIERIPERDUTI", int(H * 0.04), H * 0.90, 2.0, OUTRO, W, H, game=False, slam=False)
    n = int(OUTRO * FPS)
    for i in range(n):
        t = i / FPS
        z = 1.0 + 0.06 * t / OUTRO
        bg = cover.resize((int(W * z), int(H * z)))
        bx, by = (bg.width - W) // 2, (bg.height - H) // 2
        img = bg.crop((bx, by, bx + W, by + H))
        img = Image.blend(img, Image.new("RGB", (W, H), (0, 0, 0)), 0.35)
        img = _flash(img, max(0.0, 0.8 - t * 3))
        k = min(1.0, max(0.0, (t - 0.25) / 0.4))
        if k > 0:
            s = 1.0 + 0.5 * (1 - k) ** 2 - 0.06 * math.sin(k * math.pi)
            L = logo_rgba.resize((int(W * s), int(H * s)))
            base = img.convert("RGBA")
            base.alpha_composite(L, ((W - L.width) // 2, (H - L.height) // 2)) if s >= 1 else None
            if s < 1:
                base.alpha_composite(L, ((W - L.width) // 2, (H - L.height) // 2))
            img = base.convert("RGB")
        img = play.draw(img, t)
        img = code.draw(img, t)
        if t > OUTRO - 0.6:
            img = _flash(img, (t - (OUTRO - 0.6)) / 0.6, (0, 0, 0))
        save(img)

    def encode(pattern, dst, extra=None):
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", pattern, "-i", music]
        if extra:
            cmd += extra
        cmd += ["-c:v", "libx264", "-preset", "slow", "-crf", "22", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", dst]
        subprocess.run(cmd, check=True)

    encode(os.path.join(tmp, "f_%05d.jpg"), out_path, ["-vf", "scale=1920:1080:flags=lanczos"])
    print("video:", out_path, idx, "fotogrammi")
    if vertical_path:
        # verticale 1080x1920: sfondo sfocato, video al centro, logo sopra e invito sotto
        logo_v = plaque(Image.new("RGB", (1080, 520), (0, 0, 0)), 540, 250, 0.62)
        lm = np.asarray(logo_v.convert("L")) > 6
        logo_v = logo_v.convert("RGBA")
        logo_v.putalpha(Image.fromarray((lm * 255).astype(np.uint8)))
        cta = _text_layer("CERCA SIERI PERDUTI SU ROBLOX", 44, (255, 255, 255), (255, 210, 120), 1080, 140)
        vt = tempfile.mkdtemp(prefix="vert_")
        from PIL import ImageFilter
        for j in range(idx):
            fr = Image.open(os.path.join(tmp, f"f_{j:05d}.jpg"))
            bg = fr.resize((int(1920 * fr.width / fr.height), 1920)).crop((0, 0, 1080, 1920)) if False else fr.resize((3413, 1920))
            bg = bg.crop(((3413 - 1080) // 2, 0, (3413 - 1080) // 2 + 1080, 1920)).filter(ImageFilter.GaussianBlur(28))
            bg = Image.blend(bg, Image.new("RGB", bg.size, (0, 0, 0)), 0.45)
            mid = fr.resize((1080, 608), Image.LANCZOS)
            bg.paste(mid, (0, (1920 - 608) // 2))
            base = bg.convert("RGBA")
            if j < idx - int(OUTRO * FPS):
                base.alpha_composite(logo_v, (0, 140))
            base.alpha_composite(cta, (0, 1500))
            base.convert("RGB").save(os.path.join(vt, f"v_{j:05d}.jpg"), quality=92)
        encode(os.path.join(vt, "v_%05d.jpg"), vertical_path)
        print("video verticale:", vertical_path)


if __name__ == "__main__":
    if sys.argv[1] == "render":
        args = sys.argv[2:]
        W, H = (int(args[5]), int(args[6])) if len(args) > 6 else (1280, 720)
        cmd_render(args[0], args[1], args[2], int(args[3]), int(args[4]), W, H)
    elif sys.argv[1] == "renderall":
        a = sys.argv[2:]
        cmd_renderall(a[0], a[1], int(a[2]), int(a[3]))
    elif sys.argv[1] == "music":
        cmd_music(sys.argv[2])
    elif sys.argv[1] == "edit":
        a = sys.argv[2:]
        cmd_edit(a[0], a[1], a[2], a[3], a[4] if len(a) > 4 else None)
