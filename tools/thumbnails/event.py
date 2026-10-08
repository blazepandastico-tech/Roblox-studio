"""Video e locandine dell'evento "Grande Inaugurazione".

  python3 event.py renderall <modello Meshy> <cartella> <processo> <processi>   fotogrammi del video
  python3 event.py music <file.wav>                                               musica (con i botti sincronizzati)
  python3 event.py edit <cartella> <musica.wav> <video.mp4> [verticale.mp4]     montaggio
  python3 event.py posters <modello Meshy> <cartella di uscita> [cartella render]  locandine e miniature
"""
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from engine import M_GLOW, M_METAL, M_STONE, M_CLOTH, Camera, Look, Scene, add_box, add_sphere, add_cylinder, render  # noqa: E402
from props import add_house, add_soldier, add_stall, add_tower, add_wall  # noqa: E402
from scenes import city_block, gas_trail, ground, steam  # noqa: E402
from titan import add_titan, joints_world, load  # noqa: E402
import fireworks as fwk  # noqa: E402

FPS = 24

SHOTS = [
    ("mura", 4.0),
    ("festa", 3.5),
    ("meteora", 3.0),
    ("colosso", 4.0),
    ("volo", 3.5),
    ("finale", 6.0),
]

GOLD_TINT = (1.75, 1.30, 0.50)


def ease(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return np.asarray(a, float) * (1 - t) + np.asarray(b, float) * t


# notte limpida con la luna: le luci vere sono i fuochi, le lanterne e le finestre
NIGHT = dict(
    sun_dir=(-0.55, 0.62, 0.55), sun_col=(0.26, 0.30, 0.46), sky_top=(0.006, 0.010, 0.032), sky_hor=(0.07, 0.06, 0.13),
    sky_amb=(0.16, 0.17, 0.27), ground_amb=(0.05, 0.045, 0.06), fog_density=0.0022, fog_height=70,
    cloud_cover=0.22, cloud_col=(0.10, 0.11, 0.19), cloud_dark=(0.02, 0.02, 0.04), rays=0.0, bloom=0.9,
    ground_mat="cobble", saturation=1.18, exposure=1.35, sun_disk=False, vignette=0.45,
)
# crepuscolo dorato (per il Colosso)
DUSK = dict(
    sun_dir=(0.55, 0.10, -0.83), sun_col=(2.2, 1.15, 0.55), sky_top=(0.05, 0.06, 0.16), sky_hor=(0.85, 0.42, 0.25),
    sky_amb=(0.22, 0.20, 0.30), ground_amb=(0.16, 0.10, 0.08), fog_density=0.0035, fog_height=50,
    cloud_cover=0.45, cloud_col=(1.0, 0.55, 0.35), cloud_dark=(0.18, 0.12, 0.18), rays=0.45, bloom=0.7,
    ground_mat="ground", saturation=1.12, exposure=1.1, sun_disk=True, vignette=0.4,
)

BULBS = [(1.9, 1.3, 0.45), (1.9, 0.45, 0.35), (0.45, 1.2, 1.9), (0.55, 1.8, 0.55), (1.8, 0.55, 1.5)]


def light_string(sc, a, b, rng, sag=1.8, step=1.6):
    """Festone di lampadine colorate tra due punti (luci vere, M_GLOW)."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    n = max(4, int(np.linalg.norm(b - a) / step))
    pts = []
    for i in range(n + 1):
        k = i / n
        p = a + (b - a) * k - np.array([0, math.sin(k * math.pi) * sag, 0])
        pts.append(p)
        if 0 < i < n:
            add_box(sc, p - np.array([0, 0.35, 0]), (0.32, 0.32, 0.32), M_GLOW, BULBS[(i + rng.integers(2)) % len(BULBS)])
    for p, q in zip(pts[:-1], pts[1:]):
        sc.lines.append((p, q, 0.8, (0.05, 0.05, 0.05)))


def banner_pole(sc, pos, color, h=11.0):
    add_cylinder(sc, pos, pos + np.array([0, h, 0]), 0.18, M_METAL, (0.3, 0.3, 0.32), n=8)
    add_sphere(sc, pos + np.array([0, h + 0.3, 0]), 0.45, M_GLOW, (1.8, 1.3, 0.5), n=8)
    add_box(sc, pos + np.array([0, h - 2.6, 1.3]), (0.08, 4.2, 2.4), M_CLOTH, color)
    add_box(sc, pos + np.array([0, h - 4.8, 1.3]), (0.1, 0.4, 2.4), M_METAL, (0.9, 0.7, 0.25))


def lit_windows(sc, rng, center, radius, count):
    """Finestre illuminate sparse tra le case (bagliori caldi nella notte)."""
    for _ in range(count):
        p = np.asarray(center) + np.array([rng.uniform(-radius, radius), rng.uniform(2.0, 7.5), rng.uniform(-radius, radius)])
        add_box(sc, p, (0.9, 1.3, 0.9), M_GLOW, (2.4, 1.6, 0.7))


def arch(sc, pos, width=24.0, h=18.0):
    """L'arco d'oro della Grande Inaugurazione."""
    p = np.asarray(pos, float)
    for sx in (-1, 1):
        add_box(sc, p + np.array([sx * width / 2, h / 2, 0]), (2.4, h, 2.4), M_STONE, (0.92, 0.88, 0.80))
        add_box(sc, p + np.array([sx * width / 2, h + 0.6, 0]), (3.2, 1.2, 3.2), M_METAL, (0.95, 0.72, 0.28))
        add_box(sc, p + np.array([sx * width / 2, h * 0.55, -1.35]), (1.8, h * 0.75, 0.1), M_CLOTH, (0.62, 0.08, 0.10))
    add_box(sc, p + np.array([0, h + 1.8, 0]), (width + 3, 2.4, 2.6), M_STONE, (0.92, 0.88, 0.80))
    add_box(sc, p + np.array([0, h + 5.0, 0]), (width * 0.8, 4.0, 0.4), M_CLOTH, (0.30, 0.06, 0.07))
    add_box(sc, p + np.array([0, h + 5.0, -0.25]), (width * 0.74, 2.6, 0.1), M_GLOW, (3.4, 2.5, 1.0))
    add_sphere(sc, p + np.array([0, h + 8.2, 0]), 1.2, M_GLOW, (4.0, 3.2, 1.4), n=10)


# fuochi d'artificio di ogni inquadratura (servono sia alle immagini sia alla musica, per i botti a tempo)
SHOW_ARGS = {
    "mura": (5, (40, 0, -150), -0.5, 6.0, dict(spread=190, heights=(150, 250), rate=(0.25, 0.5), finale=False)),
    "festa": (6, (0, 0, -260), -1.0, 5.5, dict(spread=150, heights=(150, 240), rate=(0.25, 0.5), finale=False)),
    "colosso": (8, (0, 0, -480), -0.4, 5.0, dict(spread=260, heights=(170, 280), rate=(0.3, 0.6), finale=False)),
    "volo": (10, (0, 0, -120), -1.0, 5.0, dict(spread=240, heights=(110, 190), rate=(0.2, 0.4), finale=False)),
    "finale": (12, (0, 0, -240), -1.0, 4.6, dict(spread=300, heights=(160, 270), rate=(0.18, 0.35), finale=True)),
}


def shows_for(shot):
    if shot not in SHOW_ARGS:
        return []
    seed, center, t0, dur, kw = SHOW_ARGS[shot]
    return fwk.show(np.random.default_rng(seed), center, t0, dur, **kw)


# ---------------------------------------------------------------------------------------------
# Inquadrature
# ---------------------------------------------------------------------------------------------


def build_mura(m):
    rng = np.random.default_rng(31)
    sc = Scene()
    ground(sc, size=1800, n=50)
    city_block(sc, rng, (0, 0, 110), 140, step=16.0)
    lit_windows(sc, rng, (0, 0, 110), 120, 160)
    add_wall(sc, (-900, 0, -60), (900, 0, -60), 62, thick=16)
    for x in (-260, -60, 140, 340):
        add_tower(sc, (x, 0, -69), 10, 76)
    for x in range(-200, 260, 40):
        add_box(sc, (x, 64.5, -58), (1.2, 1.2, 1.2), M_GLOW, (3.5, 2.2, 0.8))
    sc.mark_static()
    return {"scene": sc, "shows": shows_for("mura")}


def frame_mura(ctx, t, W, H):
    T = t * dict(SHOTS)["mura"]
    sc = ctx["scene"].fork()
    k = ease(t)
    cam = Camera(lerp((-30, 10, 250), (-14, 26, 190), k), lerp((10, 60, 0), (24, 92, -80), k), ctx.get("fov", 54), W, H, roll=math.radians(-2))
    look = Look(**dict(NIGHT, shadow_extent=500))
    return render(sc, cam, look, ss=1, extra_post=fwk.post(ctx["shows"], T), shadow_cache=ctx.setdefault("sh", {}))


def build_festa(m):
    rng = np.random.default_rng(41)
    sc = Scene()
    ground(sc, size=900, n=40)
    # strada principale addobbata: case ai lati, festoni sopra, bancarelle e stendardi
    z = -120
    while z < 60:
        for side in (1, -1):
            w = rng.uniform(7, 10)
            h = rng.uniform(7, 11)
            pos = np.array([side * 12.5, 0, z])
            add_house(sc, pos, 8.5, w, h, yaw=math.pi / 2, wall=tuple(np.array((0.84, 0.77, 0.64)) * rng.uniform(0.8, 1.0)),
                      roof=tuple(np.array([0.52, 0.24, 0.15]) * rng.uniform(0.75, 1.1)), chimney=rng.random() < 0.5)
            add_box(sc, pos + np.array([-side * 4.3, 3.2, rng.uniform(-2, 2)]), (0.1, 1.2, 0.9), M_GLOW, (2.6, 1.7, 0.7))
            add_box(sc, pos + np.array([-side * 4.3, 7.0, rng.uniform(-2, 2)]), (0.1, 1.2, 0.9), M_GLOW, (2.6, 1.7, 0.7))
        z += 11.5
    for zz in range(-110, 60, 14):
        light_string(sc, (-8.2, 9.5 + rng.uniform(-0.5, 0.5), zz), (8.2, 9.5 + rng.uniform(-0.5, 0.5), zz + rng.uniform(-3, 3)), rng)
    for zz in range(-100, 50, 22):
        banner_pole(sc, np.array([-7.0, 0, zz]), (0.62, 0.08, 0.10))
        banner_pole(sc, np.array([7.0, 0, zz + 11]), (0.85, 0.62, 0.18))
    for zz in (-60, -25, 12):
        add_stall(sc, np.array([rng.choice([-5.2, 5.2]), 0, zz]), rng.uniform(-0.2, 0.2) + math.pi / 2, rng)
    arch(sc, (0, 0, -88))
    # piccoli cittadini (soldati in posa da festa) lungo la strada
    for i in range(10):
        add_soldier(sc, np.array([rng.uniform(-5, 5), 1.0, rng.uniform(-80, 30)]), yaw=rng.uniform(0, 2 * math.pi), pose="stand" if "stand" in _poses() else "fly", s=1.0, blades=False)
    sc.mark_static()
    return {"scene": sc, "shows": shows_for("festa")}


def _poses():
    from props import SOLDIER_POSES
    return SOLDIER_POSES


def frame_festa(ctx, t, W, H):
    T = t * dict(SHOTS)["festa"]
    sc = ctx["scene"].fork()
    k = ease(t)
    cam = Camera(lerp((0, 3.2, 52), (0, 4.4, 8), k), lerp((0, 14, -60), (0, 22, -100), k), 60, W, H)
    look = Look(**dict(NIGHT, shadow_extent=200, fog_density=0.003, exposure=1.45))
    return render(sc, cam, look, ss=1, extra_post=fwk.post(ctx["shows"], T, light_scene=1.4), shadow_cache=ctx.setdefault("sh", {}))


def _meteor_points(t, start, end, dur):
    """Scia di fuoco dorato della meteora che cade (posizioni e colori)."""
    k = min(t / dur, 1.0)
    pos = start + (end - start) * (k * k)
    P, C = [], []
    for j in range(60):
        kj = max(0.0, k - j * 0.006)
        p = start + (end - start) * (kj * kj)
        P.append(p)
        C.append(np.array((4.0, 2.6, 0.9)) * (1 - j / 60) ** 1.5 * 3)
    rng = np.random.default_rng(int(t * 100))
    sparks = pos + rng.normal(0, 6, (120, 3)) + (start - end) * rng.uniform(0, 0.06, (120, 1))
    P.extend(sparks)
    C.extend([np.array((3.0, 1.8, 0.5)) * rng.uniform(0.5, 1.5)] * 120)
    return np.array(P), np.array(C), pos


def build_meteora(m):
    rng = np.random.default_rng(51)
    sc = Scene()
    ground(sc, size=2400, n=60, color=(0.42, 0.48, 0.30))
    for _ in range(40):
        p = np.array([rng.uniform(-500, 500), 0, rng.uniform(-700, -150)])
        from props import add_tree
        add_tree(sc, p, rng.uniform(8, 14), rng)
    add_wall(sc, (-900, 0, -900), (900, 0, -900), 62, thick=16)
    sc.mark_static()
    return {"scene": sc, "start": np.array([420.0, 900.0, -900.0]), "end": np.array([0.0, 4.0, -320.0])}


def frame_meteora(ctx, t, W, H):
    T = t * dict(SHOTS)["meteora"]
    sc = ctx["scene"].fork()
    dur = 2.4
    P, C, pos = _meteor_points(min(T, dur), ctx["start"], ctx["end"], dur)
    extra = [(P, C)] if T < dur else []
    if T < dur:
        add_sphere(sc, pos, 9.0, M_GLOW, (5.0, 3.6, 1.6), n=14)
    else:
        # impatto: polvere e onda d'urto
        rng = np.random.default_rng(9)
        age = T - dur
        steam(sc, ctx["end"], (30 + age * 80, 6, 30 + age * 80), 60, rng, size=(10, 26), rise=20 + age * 60, color=(0.55, 0.45, 0.32), alpha=0.7)
        ring = []
        for a in np.linspace(0, 2 * math.pi, 240, endpoint=False):
            ring.append(ctx["end"] + np.array([math.cos(a), 0.05, math.sin(a)]) * (40 + age * 380))
        extra.append((np.array(ring), np.tile(np.array((4.0, 2.8, 1.0)) * max(0.0, 1 - age * 1.4) * 2, (240, 1))))
    k = ease(t * 0.9)
    cam = Camera(lerp((-60, 12, 160), (-40, 10, 130), k), lerp((120, 360, -600), (10, 50, -330), ease(T / dur)), 60, W, H, roll=math.radians(4 * (1 - k)))
    look = Look(**dict(DUSK, shadow_extent=900, shadow_center=(0, 0, -300), sun_dir=(-0.55, 0.12, -0.83)))
    flash = 0.0
    if dur <= T < dur + 0.5:
        flash = (1 - (T - dur) / 0.5) ** 2
    img = render(sc, cam, look, ss=1, extra_post=fwk.post([], T, sky_stars=False, extra_points=extra), shadow_cache=ctx.setdefault("sh", {}))
    if flash > 0:
        img = Image.blend(img, Image.new("RGB", img.size, (255, 236, 190)), min(1.0, flash * 0.9))
    return img


def build_colosso(m):
    rng = np.random.default_rng(61)
    sc = Scene()
    ground(sc, size=1600, n=50, color=(0.45, 0.42, 0.30))
    for _ in range(30):
        from props import add_tree
        p = np.array([rng.uniform(-300, 300), 0, rng.uniform(-400, -90)])
        add_tree(sc, p, rng.uniform(8, 13), rng)
    add_wall(sc, (-900, 0, 260), (900, 0, 260), 62, thick=16)
    sc.mark_static()
    return {"scene": sc, "m": m, "shows": shows_for("colosso"), "tpos": np.array([0.0, 0.0, -40.0])}


def frame_colosso(ctx, t, W, H):
    T = t * dict(SHOTS)["colosso"]
    sc = ctx["scene"].fork()
    m = ctx["m"]
    Ht = 60.0
    yaw = math.radians(172)
    amount = 0.3 + 0.7 * ease((t - 0.1) / 0.45)
    add_titan(sc, m, Ht, ctx["tpos"], yaw=yaw, pose="roar", tint=GOLD_TINT, amount=amount)
    J = joints_world(m, Ht, ctx["tpos"], yaw)
    rng = np.random.default_rng(int(T * 50))
    steam(sc, J["Neck"] + np.array([0, 1 + T * 2, 0]), (5.0, 2 + T * 2, 5.0), 14, np.random.default_rng(7), size=(3, 7), rise=10 + T * 6, color=(1.0, 0.85, 0.55), alpha=0.35)
    # polvere d'oro che sale attorno al gigante
    dust = ctx["tpos"] + np.stack([rng.uniform(-45, 45, 260), rng.uniform(0, 70, 260), rng.uniform(-30, 30, 260)], 1)
    dust[:, 1] += (T * 12) % 30
    gold = np.tile(np.array((3.2, 2.2, 0.8)), (260, 1)) * rng.uniform(0.2, 1.0, (260, 1))
    k = ease(t)
    cam = Camera(lerp((-18, 3, 62), (-9, 6, 44), k), lerp((0, 40, -40), (2, 50, -40), k), ctx.get("fov", 56), W, H, roll=math.radians(-3))
    look = Look(**dict(DUSK, shadow_extent=260, shadow_center=(0, 0, -40), sun_dir=(-0.45, 0.22, 0.86), rays=0.0, sun_disk=False, fog_density=0.0022))
    return render(sc, cam, look, ss=1, extra_post=fwk.post(ctx["shows"], T, sky_stars=False, extra_points=[(dust, gold)], light_scene=0.6), shadow_cache=ctx.setdefault("sh", {}))


def build_volo(m):
    rng = np.random.default_rng(71)
    sc = Scene()
    ground(sc, size=1600, n=50)
    city_block(sc, rng, (0, 0, 0), 260, step=16.0)
    lit_windows(sc, rng, (0, 0, 0), 240, 260)
    for i in range(14):
        a = np.array([rng.uniform(-200, 200), 9.5, rng.uniform(-200, 200)])
        light_string(sc, a, a + np.array([rng.uniform(-14, 14), 0, rng.uniform(10, 16)]), rng)
    sc.mark_static()
    return {"scene": sc, "shows": shows_for("volo")}


def soldier_path(T):
    return np.array([-40 + T * 22, 34 + math.sin(T * 1.6) * 3, 60 - T * 26])


def frame_volo(ctx, t, W, H):
    T = t * dict(SHOTS)["volo"]
    sc = ctx["scene"].fork()
    rng = np.random.default_rng(int(T * 10))
    p = soldier_path(T)
    d = soldier_path(T + 0.1) - p
    fwd = d / np.linalg.norm(d)
    side = np.cross(fwd, (0, 1, 0))
    side /= np.linalg.norm(side)
    roll = 0.3 * math.sin(T * 1.8)
    anchors, _ = add_soldier(sc, p, yaw=math.atan2(-d[0], -d[2]), pitch=-1.15, roll=roll, s=1.0, pose="fly")
    trail = [soldier_path(T - j * 0.1) + np.array([0, -0.6, 0]) for j in range(1, 8)]
    gas_trail(sc, [p + np.array([0, -0.4, 0])] + trail, rng, size=(0.12, 0.5), alpha=0.3)
    # cavi del rampino agganciati in alto davanti, che cambiano lato
    for k_side in (1, -1):
        target = p + fwd * 60 + side * k_side * 26 + np.array([0, 18, 0])
        a = anchors[0] if k_side > 0 else anchors[1]
        sc.lines.append((a, target, 0.9, (0.12, 0.12, 0.12)))
    k = ease(t)
    cam_t = max(0.0, T - 0.04)
    cp = soldier_path(cam_t) - fwd * (4.6 - 0.8 * k) + np.array([0, 1.5, 0]) + side * (1.6 - 1.0 * k)
    cam = Camera(cp, p + fwd * 30 + np.array([0, 3.0, 0]), 62, W, H, roll=roll * 0.4)
    look = Look(**dict(NIGHT, shadow_extent=300, shadow_center=tuple(p * np.array([1, 0, 1]))))
    return render(sc, cam, look, ss=1, extra_post=fwk.post(ctx["shows"], T), shadow_cache=None)


def build_finale(m):
    rng = np.random.default_rng(81)
    sc = Scene()
    ground(sc, size=2400, n=60)
    city_block(sc, rng, (0, 0, 60), 220, step=16.0)
    lit_windows(sc, rng, (0, 0, 60), 200, 260)
    add_wall(sc, (-1100, 0, -200), (1100, 0, -200), 62, thick=16)
    for x in (-400, -150, 100, 350):
        add_tower(sc, (x, 0, -209), 10, 76)
    arch(sc, (0, 0, 150), width=30, h=22)
    sc.mark_static()
    return {"scene": sc, "shows": shows_for("finale")}


def frame_finale(ctx, t, W, H):
    T = t * dict(SHOTS)["finale"]
    sc = ctx["scene"].fork()
    k = ease(t)
    cam = Camera(lerp((0, 30, 330), (0, 60, 300), k), lerp((0, 70, 0), (0, 110, -150), k), ctx.get("fov", 62), W, H)
    look = Look(**dict(NIGHT, shadow_extent=700))
    return render(sc, cam, look, ss=1, extra_post=fwk.post(ctx["shows"], T), shadow_cache=ctx.setdefault("sh", {}))


# ---------------------------------------------------------------------------------------------
# Render dei fotogrammi (più processi in parallelo)
# ---------------------------------------------------------------------------------------------


def cmd_renderall(fbx_dir, out, worker, workers, W=1280, H=720, only=None):
    import time
    os.makedirs(out, exist_ok=True)
    m = load(fbx_dir)
    for shot, dur in SHOTS:
        if only and shot != only:
            continue
        n = int(round(dur * FPS))
        mine = [i for i in range(n) if i % workers == worker and not os.path.exists(os.path.join(out, f"{shot}_{i:04d}.png"))]
        if not mine:
            continue
        ctx = globals()["build_" + shot](m)
        for i in mine:
            t0 = time.time()
            img = globals()["frame_" + shot](ctx, i / max(1, n - 1), W, H)
            img.save(os.path.join(out, f"{shot}_{i:04d}.png"))
            print(f"{shot} {i + 1}/{n} {time.time() - t0:.1f}s", flush=True)


# ---------------------------------------------------------------------------------------------
# Tempi del video: introduzione, inquadrature, logo finale
# ---------------------------------------------------------------------------------------------

INTRO = 2.5
LOGO_AT = 2.6  # secondi dentro al "finale" in cui entra il logo
SR = 44100


def timeline():
    """Inizio di ogni parte del video (in secondi) e durata totale."""
    t = INTRO
    starts = {"intro": 0.0}
    for name, dur in SHOTS:
        starts[name] = t
        t += dur
    starts["fine"] = t
    return starts, t


def video_time(shot, T):
    """Istante del video in cui si vede il tempo T dell'inquadratura (i fotogrammi coprono 0..durata)."""
    starts, _ = timeline()
    n = int(round(dict(SHOTS)[shot] * FPS))
    return starts[shot] + T * (n - 1) / n


def _note(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def cmd_music(path):
    """Musica di festa epica in Re maggiore, con i botti dei fuochi sincronizzati con le immagini."""
    from scipy.signal import butter, fftconvolve, sosfilt
    import wave
    S, total = timeline()
    N = int(total * SR) + SR
    L = np.zeros(N)
    Rc = np.zeros(N)
    rng = np.random.default_rng(3)

    def add(sig, at, gain=1.0, pan=0.0):
        i = int(at * SR)
        if i >= N or i < 0:
            return
        sig = sig[: N - i]
        L[i:i + len(sig)] += sig * gain * (1 - max(0.0, pan))
        Rc[i:i + len(sig)] += sig * gain * (1 + min(0.0, pan))

    def lp(x, f, order=2):
        return sosfilt(butter(order, min(f, SR * 0.45), "low", fs=SR, output="sos"), x)

    def hp(x, f, order=2):
        return sosfilt(butter(order, f, "high", fs=SR, output="sos"), x)

    def bp(x, lo, hi):
        return sosfilt(butter(2, [lo, hi], "band", fs=SR, output="sos"), x)

    def saw(freq, dur, detune=0.0, phase=0.0):
        t = np.arange(int(dur * SR)) / SR
        return 2 * ((t * freq * (1 + detune) + phase) % 1.0) - 1

    def env(n, a, d, release=0.3):
        e = np.ones(n)
        ia = min(n, max(1, int(a * SR)))
        e[:ia] = np.linspace(0, 1, ia)
        ir = max(1, int(release * SR))
        if n > ir:
            e[-ir:] *= np.linspace(1, 0, ir)
        return e * (np.exp(-np.arange(n) / SR / d) if d else 1)

    def bell(at, note, gain=0.25, pan=0.0):
        n = int(1.6 * SR)
        t = np.arange(n) / SR
        f = _note(note)
        sig = (np.sin(2 * np.pi * f * t) * np.exp(-t * 3.2) + 0.45 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 7)
               + 0.22 * np.sin(2 * np.pi * f * 5.40 * t) * np.exp(-t * 12))
        sig[: int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))
        add(sig, at, gain, pan)

    def pad(at, notes, dur, gain=0.3, attack=0.4, cutoff=2400):
        n = int(dur * SR)
        sig = np.zeros(n)
        for note in notes:
            for dt in (-0.004, 0.0, 0.005):
                sig += saw(_note(note), dur, dt, rng.random())
        sig = lp(sig, cutoff) * env(n, attack, 0, release=min(0.6, dur * 0.4))
        add(sig * gain / len(notes), at)

    def pluck(at, note, dur, gain=0.2, pan=0.0):
        n = int(dur * SR)
        s = (saw(_note(note), dur) + saw(_note(note), dur, 0.004)) * 0.5
        s = lp(s, 3600) * np.exp(-np.arange(n) / SR * 9)
        add(s, at, gain, pan)

    def ostinato(at, dur, chord, gain=0.2, rate=8):
        pattern = [0, 1, 2, 1, 3, 1, 2, 1]
        notes = list(chord) + [chord[0] + 12]
        k, x = 0, at
        while x < at + dur - 1e-6:
            pluck(x, notes[pattern[k % 8] % len(notes)], 0.95 / rate, gain, 0.25 if k % 2 else -0.25)
            k += 1
            x += 1.0 / rate

    def taiko(at, gain=1.0, pitch=1.0):
        n = int(1.2 * SR)
        t = np.arange(n) / SR
        f = 88 * pitch * (1 + 1.5 * np.exp(-t * 30))
        body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 5)
        skin = bp(rng.normal(0, 1, n), 150, 1600) * np.exp(-t * 16)
        add(np.tanh((body + skin) * 1.5), at, gain)

    def snare(at, gain=0.3):
        n = int(0.4 * SR)
        t = np.arange(n) / SR
        s = bp(rng.normal(0, 1, n), 900, 7000) * np.exp(-t * 18) + np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30) * 0.6
        add(s, at, gain, rng.uniform(-0.15, 0.15))

    def crash(at, gain=0.4):
        n = int(2.4 * SR)
        t = np.arange(n) / SR
        s = bp(rng.normal(0, 1, n), 3500, 12000) * (np.exp(-t * 3.2) * 0.5 + 0.25 * np.exp(-t * 14))
        add(s, at, gain * 0.4, -0.2)
        add(bp(rng.normal(0, 1, n), 3500, 12000) * np.exp(-t * 3.2) * 0.5, at + 0.004, gain * 0.4, 0.2)

    def braam(at, root=38, dur=3.0, gain=1.0, third=4):
        n = int(dur * SR)
        sig = np.zeros(n)
        for note, g in ((root, 1.0), (root + 12, 0.7), (root + 7, 0.55), (root + 12 + third, 0.35), (root + 19, 0.3)):
            for dt in (-0.006, 0.0, 0.007):
                sig += saw(_note(note), dur, dt, rng.random()) * g
        sig = np.tanh(sig * 0.6)
        out = np.zeros(n)
        blk = 2048
        for i in range(0, n, blk):
            fc = 220 + 3000 * np.exp(-((i / SR) - 0.12) ** 2 / 0.4)
            seg = sig[i:i + blk]
            out[i:i + blk] = lp(sig[max(0, i - 4096):i + blk], fc)[-len(seg):]
        out *= env(n, 0.02, dur * 0.55, release=0.6)
        add(out * 0.35, at, gain)

    def boom(at, gain=0.6, pan=0.0, big=False):
        """Scoppio di un fuoco d'artificio: colpo basso, schiocco e rimbombo che si allontana."""
        n = int(2.2 * SR)
        t = np.arange(n) / SR
        f = 52 * (1 + 2.2 * np.exp(-t * 22))
        thump = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 6)
        crack = lp(rng.normal(0, 1, n), 2800) * np.exp(-t * 28)
        rumble = lp(rng.normal(0, 1, n), 260) * np.exp(-t * 2.0) * 2.2
        sig = np.tanh((thump * 1.4 + crack * 0.8 + rumble) * (1.6 if big else 1.0))
        add(sig, at, gain, pan)

    def crackle(at, dur, gain=0.25, pan=0.0, density=90):
        """Crepitio delle scintille (tanti piccoli schiocchi)."""
        n = int(dur * SR)
        sig = np.zeros(n)
        times = np.sort(rng.uniform(0, dur, int(density * dur)))
        click = bp(rng.normal(0, 1, int(0.012 * SR)), 1800, 9000) * np.exp(-np.arange(int(0.012 * SR)) / SR * 400)
        for tc in times:
            i = int(tc * SR)
            k = 1 - tc / dur
            seg = click[: n - i] * rng.uniform(0.3, 1.0) * k
            sig[i:i + len(seg)] += seg
        add(sig, at, gain, pan)

    def whistle(at, dur=1.1, gain=0.12, pan=0.0):
        """Fischio del razzo che sale."""
        n = int(dur * SR)
        t = np.arange(n) / SR
        f = 900 + 1500 * (t / dur) ** 0.7
        tone = np.sin(2 * np.pi * np.cumsum(f) / SR)
        hiss = bp(rng.normal(0, 1, n), 2500, 9000) * 0.5
        e = np.sin(np.linspace(0, np.pi, n)) ** 0.6 * np.linspace(0.6, 1, n)
        add((tone * 0.6 + hiss) * e, at, gain, pan)

    def riser(at, dur, gain=0.35):
        n = int(dur * SR)
        t = np.arange(n) / SR
        sig = np.zeros(n)
        for f0 in (220, 330, 440):
            sig += np.sin(2 * np.pi * np.cumsum(f0 * (1 + t / dur)) / SR)
        noise = bp(rng.normal(0, 1, n), 1500, 8000)
        add((sig * 0.3 + noise * 0.25) * (t / dur) ** 2, at, gain)

    def roar(at, dur, gain=0.6):
        """Rombo di fuoco della meteora che cade (cresce fino all'impatto)."""
        n = int(dur * SR)
        t = np.arange(n) / SR
        noise = rng.normal(0, 1, n)
        out = np.zeros(n)
        blk = 2048
        for i in range(0, n, blk):
            fc = 200 + 2200 * (i / n) ** 2
            seg = noise[i:i + blk]
            out[i:i + blk] = lp(noise[max(0, i - 4096):i + blk], fc)[-len(seg):]
        add(out * (t / dur) ** 1.5 * 2.0, at, gain)

    def thunder(at, gain=0.8):
        n = int(3.0 * SR)
        t = np.arange(n) / SR
        x = lp(rng.normal(0, 1, n), 400) * (np.exp(-t * 1.2) + 0.6 * np.exp(-((t - 0.25) ** 2) / 0.02))
        add(np.tanh(x * 3) * 0.6, at, gain, rng.uniform(-0.3, 0.3))

    # accordi (Re maggiore): I, vi, IV, V e il Do misolidio per il Colosso
    D = [50, 54, 57]
    Bm = [47, 50, 54]
    G = [43, 47, 50]
    A = [45, 49, 52]
    C = [48, 52, 55]
    melody = [74, 78, 81, 78, 76, 79, 83, 79, 74, 78, 81, 86, 85, 81, 78, 76]

    # INTRO: campanelle, tappeto morbido, il primo razzo che sale
    for i in range(8):
        bell(0.25 + i * 0.25, [74, 78, 81, 86][i % 4] + (12 if i >= 4 else 0), 0.10 + 0.02 * i, -0.3 + 0.6 * (i % 2))
    pad(0.0, [62, 66, 69], INTRO + 0.4, 0.22, attack=1.2, cutoff=1600)
    riser(1.0, INTRO - 1.0, 0.3)
    whistle(INTRO - 1.25, 1.2, 0.16)

    # MURA: grande colpo d'apertura, poi tappeto e melodia di campanelle
    braam(S["mura"], 38, 3.5, 1.15)
    crash(S["mura"], 0.55)
    taiko(S["mura"], 1.3, 0.8)
    pad(S["mura"], [62, 66, 69, 74], 4.0, 0.34)
    for i, note in enumerate(melody[:8]):
        bell(S["mura"] + 0.5 + i * 0.5, note, 0.16, 0.3 if i % 2 else -0.3)
    for b in range(4, 8):
        taiko(S["mura"] + b * 0.5, 0.45 if b % 2 else 0.7, 1.0)

    # FESTA: ritmo di festa (Re - Si minore)
    for chord, at, d in ((D, S["festa"], 2.0), (Bm, S["festa"] + 2.0, 1.5)):
        ostinato(at, d, [c + 12 for c in chord], 0.2)
        pad(at, [c + 12 for c in chord] + [chord[0] + 24], d, 0.36, attack=0.15)
        for b in range(int(d / 0.5 + 0.01)):
            taiko(at + b * 0.5, 0.8 if b % 2 == 0 else 0.5, 1.0 if b % 2 == 0 else 1.35)
            if b % 2 == 1:
                snare(at + b * 0.5, 0.28)
    for i, note in enumerate(melody[8:15]):
        bell(S["festa"] + i * 0.5, note, 0.15, -0.3 if i % 2 else 0.3)

    # METEORA: la musica si ferma, rombo e boato all'impatto
    impact = video_time("meteora", 2.4)
    pad(S["meteora"], [38, 45], impact - S["meteora"] + 0.2, 0.5, attack=0.3, cutoff=500)
    roar(S["meteora"], impact - S["meteora"], 0.55)
    riser(S["meteora"] + 0.4, impact - S["meteora"] - 0.4, 0.3)
    braam(impact, 38, 3.2, 1.25)
    thunder(impact, 1.0)
    taiko(impact, 1.5, 0.7)
    crash(impact, 0.6)
    boom(impact, 0.9, 0.0, big=True)

    # COLOSSO: ottoni pesanti e tamburi (Re - Do)
    for chord, at, d in ((D, S["colosso"], 2.0), (C, S["colosso"] + 2.0, 2.0)):
        braam(at, chord[0] - 12, d + 0.4, 0.8)
        pad(at, [c + 12 for c in chord] + [chord[0] + 24], d, 0.42, attack=0.1)
        for b in range(int(d / 0.25 + 0.01)):
            x = at + b * 0.25
            if b % 4 == 0:
                taiko(x, 1.0, 0.85)
            elif b % 2 == 0:
                taiko(x, 0.55, 1.2)
            else:
                taiko(x, 0.3, 1.6)
            if b % 4 == 2:
                snare(x, 0.32)

    # VOLO: spinta piena (Sol - La) e salita verso il finale
    crash(S["volo"], 0.35)
    for chord, at, d in ((G, S["volo"], 2.0), (A, S["volo"] + 2.0, 1.5)):
        ostinato(at, d, [c + 12 for c in chord], 0.24, rate=8)
        pad(at, [c + 12 for c in chord] + [chord[0] + 24], d, 0.45, attack=0.1)
        for b in range(int(d / 0.25 + 0.01)):
            taiko(at + b * 0.25, 0.75 if b % 2 == 0 else 0.4, 1.0 if b % 4 == 0 else 1.5)
            if b % 4 == 2:
                snare(at + b * 0.25, 0.35)
    riser(S["finale"] - 1.4, 1.4, 0.45)
    for i in range(8):
        snare(S["finale"] - 1.0 + i * 0.125, 0.12 + 0.03 * i)

    # FINALE: Re - La - Si minore - Sol, poi il colpo del logo e l'accordo lungo
    crash(S["finale"], 0.55)
    braam(S["finale"], 38, 2.4, 0.9)
    for j, chord in enumerate((D, A, Bm, G)):
        at = S["finale"] + j * 0.65
        d = 0.65
        pad(at, [c + 12 for c in chord] + [chord[0] + 24], d + 0.1, 0.45, attack=0.05)
        ostinato(at, d, [c + 12 for c in chord], 0.22)
        for b in range(int(d / 0.25 + 0.01) + 1):
            taiko(at + b * 0.25, 0.7 if b % 2 == 0 else 0.4, 1.0 if b % 2 == 0 else 1.5)
    logo = S["finale"] + LOGO_AT
    braam(logo, 38, total - logo + 0.5, 1.3)
    crash(logo, 0.7)
    taiko(logo, 1.5, 0.75)
    taiko(logo + 0.25, 0.9, 1.0)
    pad(logo, [50, 57, 62, 66, 69, 74], total - logo, 0.6, attack=0.05, cutoff=3000)
    for i in range(12):
        bell(logo + 0.15 + i * 0.18, [86, 81, 78, 74][i % 4] + (0 if i < 8 else -12), 0.12, -0.4 + 0.8 * ((i * 3) % 4) / 3)

    # i botti dei fuochi d'artificio, a tempo con quello che si vede
    for shot, dur in SHOTS:
        for fw in shows_for(shot):
            Tb = fw.burst_time()
            if not (0.0 <= Tb <= dur):
                continue
            at = video_time(shot, Tb)
            pan = float(np.clip(fw.base[0] / 300.0, -0.7, 0.7))
            g = 0.32 if shot != "finale" else 0.42
            boom(at, g * rng.uniform(0.7, 1.0), pan)
            if fw.kind in ("crackle", "willow"):
                crackle(at + 0.25, 1.6 if fw.kind == "willow" else 1.0, 0.16, pan)
            if 0.0 <= fw.t0 <= dur and rng.random() < 0.35:
                whistle(video_time(shot, fw.t0), fw.rise, 0.05, pan)

    # riverbero, pulizia dei bassi, dissolvenza e normalizzazione
    ir_n = int(2.0 * SR)
    ir = rng.normal(0, 1, ir_n) * np.exp(-np.arange(ir_n) / SR * 2.6)
    ir /= np.sqrt(np.sum(ir ** 2))
    Lw = L + fftconvolve(L, ir)[:N] * 0.32
    Rw = Rc + fftconvolve(Rc, ir[::-1].copy())[:N] * 0.32
    out = np.stack([Lw, Rw], -1)[: int(total * SR)]
    hpf = butter(2, 35, "high", fs=SR, output="sos")
    low = butter(2, 140, "low", fs=SR, output="sos")
    for ch in range(2):
        x = sosfilt(hpf, out[:, ch])
        out[:, ch] = x - 0.4 * sosfilt(low, x)
    fade = int(1.0 * SR)
    out[-fade:] *= np.linspace(1, 0, fade)[:, None]
    out = np.tanh(out / np.max(np.abs(out)) * 1.4) * 0.89
    data = (out * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("musica:", path, round(total, 1), "s")


# ---------------------------------------------------------------------------------------------
# Montaggio: testi animati, introduzione, logo finale, versione verticale
# ---------------------------------------------------------------------------------------------


def _stars_2d(W, H, t, seed=2):
    rng = np.random.default_rng(seed)
    n = int(W * H / 2600)
    x = rng.uniform(0, W, n).astype(int)
    y = rng.uniform(0, H, n).astype(int)
    mag = rng.uniform(0.1, 1.0, n) ** 2.5 * (0.6 + 0.4 * np.sin(t * 4 + np.arange(n)))
    buf = np.zeros((H, W))
    np.add.at(buf, (y, x), mag * 255)
    from engine import gaussian
    buf = buf + gaussian(buf[..., None], 1.2)[..., 0] * 1.5
    return buf


def _logo_layer(W, H, cx, cy, scale):
    from compose import plaque
    layer = plaque(Image.new("RGB", (W, H), (0, 0, 0)), cx, cy, scale)
    mask = np.asarray(layer.convert("L")) > 6
    rgba = layer.convert("RGBA")
    rgba.putalpha(Image.fromarray((mask * 255).astype(np.uint8)))
    return rgba


def cmd_edit(frames_dir, music, out_path, vertical_path=None):
    import subprocess
    import tempfile
    from trailer import Title, _darken_bottom, _flash, _shake, _text_layer
    probe = Image.open(os.path.join(frames_dir, f"{SHOTS[0][0]}_0000.png"))
    W, H = probe.size
    S, total = timeline()
    tmp = tempfile.mkdtemp(prefix="evento_")
    idx = 0
    gold = ((255, 236, 160), (230, 120, 30))
    white = ((255, 255, 255), (200, 210, 230))

    def save(img):
        nonlocal idx
        img.save(os.path.join(tmp, f"f_{idx:05d}.jpg"), quality=94)
        idx += 1

    def plain(text, size, y, t0, t1):
        return Title(text, int(H * size), H * y, t0, t1, W, H, game=False, slam=False)

    # INTRODUZIONE: cielo stellato, una frase e la scia del primo razzo che sale
    intro = [plain("L'ARCIPELAGO DEI GIGANTI È IN FESTA...", 0.05, 0.5, 0.15, 2.25)]
    n = int(INTRO * FPS)
    for i in range(n):
        t = i / FPS
        arr = np.zeros((H, W, 3)) + np.array([2, 3, 10])
        arr += _stars_2d(W, H, t)[..., None] * np.array([0.85, 0.9, 1.0]) * min(1.0, t / 0.8)
        if t > INTRO - 1.25:
            # scia dorata del razzo: dal basso verso l'alto
            k = (t - (INTRO - 1.25)) / 1.25
            from engine import gaussian
            buf = np.zeros((H, W, 3))
            for j in range(40):
                kj = k - j * 0.012
                if kj < 0:
                    break
                yy = int(H * (1.02 - 0.75 * (1 - (1 - kj) ** 2)))
                xx = int(W * 0.53 + math.sin(kj * 20) * 3)
                if 0 <= yy < H:
                    buf[yy, xx] += np.array([1.0, 0.7, 0.3]) * 900 * (1 - j / 40)
            arr += gaussian(buf, 1.5) * 1.2 + gaussian(buf, 6) * 2.5
        img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
        for ti in intro:
            img = ti.draw(img, t)
        save(img)

    titles = {
        "mura": [Title("GRANDE INAUGURAZIONE", int(H * 0.115), H * 0.80, 0.55, 3.9, W, H, *gold),
                 plain("SIERI PERDUTI • L'ARCIPELAGO DEI GIGANTI", 0.04, 0.91, 0.9, 3.9)],
        "festa": [Title("ESPERIENZA E ORO X2", int(H * 0.1), H * 0.16, 0.25, 3.4, W, H, *gold),
                  plain("Città in festa • Regalo di benvenuto per tutti", 0.042, 0.27, 0.5, 3.4)],
        "meteora": [Title("QUALCOSA CADE DAL CIELO...", int(H * 0.075), H * 0.84, 0.25, 2.25, W, H, *white)],
        "colosso": [Title("IL COLOSSO D'ORO", int(H * 0.12), H * 0.80, 0.5, 3.9, W, H, *gold),
                    plain("Il boss dell'evento arriva ogni 30 minuti", 0.042, 0.91, 0.8, 3.9)],
        "volo": [Title("8 SFIDE • PREMI ESCLUSIVI", int(H * 0.095), H * 0.16, 0.25, 3.4, W, H, *gold),
                 plain("Mantello dell'Inaugurazione • Medaglia • Gemme", 0.042, 0.27, 0.5, 3.4)],
        "finale": [Title("FUOCHI D'ARTIFICIO OGNI 10 MINUTI", int(H * 0.075), H * 0.84, 0.25, LOGO_AT - 0.15, W, H, *gold)],
    }
    logo = _logo_layer(W, H, W / 2, H * 0.37, 0.95 * W / 1920 * 1.25)
    end_titles = [
        Title("GIOCA ORA SU ROBLOX", int(H * 0.085), H * 0.735, LOGO_AT + 0.55, 99, W, H, top=(255, 255, 255), bottom=(255, 210, 120)),
        Title("CODICE REGALO: INAUGURAZIONE", int(H * 0.05), H * 0.835, LOGO_AT + 0.9, 99, W, H, *gold),
        plain("Evento fino al 25 ottobre", 0.038, 0.915, LOGO_AT + 1.2, 99),
    ]
    impact = 2.4
    for name, dur in SHOTS:
        n = int(round(dur * FPS))
        for i in range(n):
            t = i / FPS
            T = i / max(1, n - 1) * dur
            img = Image.open(os.path.join(frames_dir, f"{name}_{i:04d}.png")).convert("RGB")
            if name == "meteora" and T >= impact:
                img = _shake(img, max(0.0, 1 - (T - impact) / 0.5), t)
            if name == "colosso":
                img = _shake(img, max(0.0, 0.6 - T * 1.2), t)
            if name == "mura" and i < 6:
                img = _flash(img, 1 - i / 6, (255, 240, 200))
            elif i < 2 and name not in ("mura", "meteora"):
                img = _flash(img, 0.45 - i * 0.2)
            if name in ("mura", "colosso", "meteora"):
                img = _darken_bottom(img, 0.5)
            for ti in titles.get(name, []):
                img = ti.draw(img, t)
            if name == "finale" and T >= LOGO_AT:
                k = min(1.0, (T - LOGO_AT) / 0.4)
                img = Image.blend(img, Image.new("RGB", (W, H), (0, 0, 0)), 0.38 * k)
                img = _flash(img, max(0.0, 0.7 - (T - LOGO_AT) * 3), (255, 240, 200))
                # il logo arriva grande e si posa al suo posto
                s = 1.0 + 0.45 * (1 - k) ** 2
                Lg = logo
                if s > 1.0:
                    big = logo.resize((int(W * s), int(H * s)))
                    x0, y0 = (big.width - W) // 2, (big.height - H) // 2
                    Lg = big.crop((x0, y0, x0 + W, y0 + H))
                base = img.convert("RGBA")
                base.alpha_composite(Lg)
                img = base.convert("RGB")
                for ti in end_titles:
                    img = ti.draw(img, T)
                if T > dur - 0.5:
                    img = _flash(img, (T - (dur - 0.5)) / 0.5, (0, 0, 0))
            save(img)
    logo_frame = int((S["finale"] + LOGO_AT) * FPS)

    def encode(pattern, dst, extra=None):
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", pattern, "-i", music]
        if extra:
            cmd += extra
        cmd += ["-c:v", "libx264", "-preset", "slow", "-crf", "21", "-maxrate", "7500k", "-bufsize", "15000k",
                "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", dst]
        subprocess.run(cmd, check=True)

    encode(os.path.join(tmp, "f_%05d.jpg"), out_path, ["-vf", "scale=1920:1080:flags=lanczos"])
    print("video:", out_path, idx, "fotogrammi")
    if vertical_path:
        from PIL import ImageFilter
        logo_v = _logo_layer(1080, 560, 540, 250, 0.62)
        top_t = _text_layer("GRANDE INAUGURAZIONE", 62, (255, 236, 160), (230, 120, 30), 1080, 160)
        cta = _text_layer("CERCA SIERI PERDUTI SU ROBLOX", 44, (255, 255, 255), (255, 210, 120), 1080, 120)
        code = _text_layer("CODICE: INAUGURAZIONE", 40, (255, 236, 160), (230, 120, 30), 1080, 110)
        vt = tempfile.mkdtemp(prefix="evento_v_")
        mid_h = 608
        for j in range(idx):
            fr = Image.open(os.path.join(tmp, f"f_{j:05d}.jpg"))
            bg = fr.resize((3413, 1920)).crop(((3413 - 1080) // 2, 0, (3413 - 1080) // 2 + 1080, 1920)).filter(ImageFilter.GaussianBlur(28))
            bg = Image.blend(bg, Image.new("RGB", bg.size, (0, 0, 0)), 0.45)
            bg.paste(fr.resize((1080, mid_h), Image.LANCZOS), (0, (1920 - mid_h) // 2))
            base = bg.convert("RGBA")
            if j < logo_frame:
                base.alpha_composite(logo_v, (0, 70))
                base.alpha_composite(top_t, (0, 1920 // 2 - mid_h // 2 - 150))
            base.alpha_composite(cta, (0, 1500))
            base.alpha_composite(code, (0, 1610))
            base.convert("RGB").save(os.path.join(vt, f"v_{j:05d}.jpg"), quality=92)
        encode(os.path.join(vt, "v_%05d.jpg"), vertical_path)
        print("video verticale:", vertical_path)


# ---------------------------------------------------------------------------------------------
# Locandine: copertina dell'evento (16:9), storia (9:16), quadrata (1:1)
# ---------------------------------------------------------------------------------------------


def _poster_text(img, items):
    """items: (testo, dimensione, centro, stile) con stile 'oro', 'bianco' o 'semplice'."""
    from compose import _game_text, plain_text
    for text, size, center, style in items:
        if style == "semplice":
            img, _ = plain_text(img, text, size, center, spacing=0.05)
            continue
        top, bottom = ((255, 236, 160), (230, 120, 30)) if style == "oro" else ((255, 255, 255), (200, 210, 230))
        base, _, _ = _game_text(img.convert("RGBA"), text, size, center, top, bottom)
        img = base.convert("RGB")
    return img


def _ribbon(img, text, cy, size, color=(176, 32, 28)):
    from compose import badge, font, SANS
    from PIL import ImageDraw
    f = font(SANS, size)
    bb = ImageDraw.Draw(img).textbbox((0, 0), text, font=f)
    w = bb[2] - bb[0] + int(size * 0.9)
    return badge(img, text, (int(img.width / 2 - w / 2), int(cy - size * 0.95)), size=size, fill=color)


def cmd_posters(fbx_dir, out, raw_dir=None):
    from compose import plaque, shade
    os.makedirs(out, exist_ok=True)
    raw_dir = raw_dir or out
    m = load(fbx_dir)

    def raw(name, shot, t, W, H, fov=None):
        """Render 3D dell'immagine (salvato a parte: si possono ritoccare i testi senza rifarlo)."""
        path = os.path.join(raw_dir, f"_render_{name}.png")
        if os.path.exists(path):
            return Image.open(path).convert("RGB")
        ctx = globals()["build_" + shot](m)
        if fov:
            ctx["fov"] = fov
        img = globals()["frame_" + shot](ctx, t, W, H)
        img.save(path)
        return img

    # 1) copertina 1920x1080: il Colosso d'Oro tra i fuochi
    img = raw("copertina", "colosso", 0.8, 1920, 1080)
    img = shade(img, "top", 0.7, 0.4)
    img = shade(img, "bottom", 0.8, 0.38)
    img = _poster_text(img, [("GRANDE INAUGURAZIONE", 112, (960, 118), "oro")])
    img = _ribbon(img, "EVENTO DI LANCIO • FINO AL 25 OTTOBRE", 238, 34)
    img = plaque(img, 250, 935, 0.36)
    img = _poster_text(img, [("2x XP E ORO • COLOSSO D'ORO • FUOCHI D'ARTIFICIO", 40, (1150, 960), "semplice"),
                             ("CODICE: INAUGURAZIONE", 52, (1150, 1030), "oro")])
    img.save(os.path.join(out, "Evento_Copertina_1920x1080.png"))
    print("copertina")
    # 2) storia 1080x1920: il gran finale sopra le mura
    img = raw("storia", "finale", 0.62, 1080, 1920, fov=88)
    img = shade(img, "top", 0.6, 0.3)
    img = shade(img, "bottom", 0.85, 0.42)
    img = plaque(img, 540, 250, 0.62)
    img = _poster_text(img, [("GRANDE", 136, (540, 1295), "oro"), ("INAUGURAZIONE", 94, (540, 1425), "oro")])
    img = _ribbon(img, "FINO AL 25 OTTOBRE", 1560, 40)
    img = _poster_text(img, [("2x XP E ORO • COLOSSO D'ORO", 40, (540, 1680), "semplice"),
                             ("FUOCHI D'ARTIFICIO • PREMI ESCLUSIVI", 40, (540, 1740), "semplice"),
                             ("CODICE: INAUGURAZIONE", 58, (540, 1840), "oro")])
    img.save(os.path.join(out, "Evento_Storia_1080x1920.png"))
    print("storia")
    # 3) quadrata 1080x1080: fuochi sopra le mura
    img = raw("quadrata", "mura", 0.62, 1080, 1080, fov=70)
    img = shade(img, "bottom", 0.85, 0.45)
    img = _poster_text(img, [("GRANDE", 120, (540, 720), "oro"), ("INAUGURAZIONE", 92, (540, 830), "oro")])
    img = _ribbon(img, "SIERI PERDUTI • FINO AL 25 OTTOBRE", 935, 32)
    img = _poster_text(img, [("CODICE: INAUGURAZIONE", 46, (540, 1030), "oro")])
    img.save(os.path.join(out, "Evento_Quadrata_1080x1080.png"))
    print("quadrata")


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "renderall":
        a = sys.argv[2:]
        cmd_renderall(a[0], a[1], int(a[2]), int(a[3]), only=a[4] if len(a) > 4 else None)
    elif cmd == "music":
        cmd_music(sys.argv[2])
    elif cmd == "edit":
        a = sys.argv[2:]
        cmd_edit(a[0], a[1], a[2], a[3] if len(a) > 3 else None)
    elif cmd == "posters":
        cmd_posters(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else None)
    elif cmd == "frame":
        # anteprima di un fotogramma: frame <modello> <inquadratura> <t 0..1> <uscita.png>
        a = sys.argv[2:]
        m = load(a[0])
        ctx = globals()["build_" + a[1]](m)
        globals()["frame_" + a[1]](ctx, float(a[2]), 960, 540).save(a[3])
