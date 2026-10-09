"""Scene delle immagini del gioco (miniature 1920x1080 e icona 512x512).

  python3 tools/thumbnails/scenes.py <cartella modello Meshy> <cartella di uscita> [scala]

scala = 1 per l'anteprima veloce (960x540), 2 per le immagini finali.
"""
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from engine import (M_GROUND, M_WATER, Camera, Look, Scene, grid_quad, normalize, render)  # noqa: E402
from props import add_house, add_rubble, add_soldier, add_tower, add_tree, add_wall  # noqa: E402
from titan import add_titan, joints_world, load  # noqa: E402


def steam(scene, center, spread, count, rng, size=(2.5, 6.0), rise=10.0, color=(1.0, 0.95, 0.9), alpha=0.6):
    for _ in range(count):
        off = rng.normal(0, 1, 3) * np.array(spread)
        off[1] = abs(off[1]) + rng.uniform(0, rise)
        scene.particles.append((np.asarray(center) + off, rng.uniform(*size), color, alpha * rng.uniform(0.5, 1.0), rng.uniform(0, 100)))


def gas_trail(scene, points, rng, size=(0.35, 1.2), alpha=0.55):
    pts = np.asarray(points, float)
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        n = int(np.linalg.norm(b - a) / 0.5) + 1
        for k in range(n):
            t = k / n
            p = a + (b - a) * t + rng.normal(0, 0.15, 3)
            age = (i + t) / (len(pts) - 1)
            r = size[0] + (size[1] - size[0]) * age
            scene.particles.append((p, r, (0.96, 0.96, 0.98), alpha * (1 - age * 0.7), rng.uniform(0, 100)))


def street_houses(scene, rng, z0, z1, x_side, depth_rows=3, skip_near=None, ruined_near=None, skip_radius=9.0):
    z = z0
    chimneys = []
    while z < z1:
        w = rng.uniform(7, 10)
        d = rng.uniform(8, 11)
        for row in range(depth_rows):
            x = x_side * (9 + d / 2 + row * (d + 4))
            pos = np.array([x, 0, z + w / 2])
            if skip_near is not None and np.linalg.norm(pos[[0, 2]] - np.asarray(skip_near)[[0, 2]]) < skip_radius:
                continue
            h = rng.uniform(6, 11) if row == 0 else rng.uniform(5, 12)
            if ruined_near is not None and np.linalg.norm(pos[[0, 2]] - np.asarray(ruined_near)[[0, 2]]) < 16:
                h *= 0.45
                add_rubble(scene, pos, 5, 10, rng)
            palette = [(0.84, 0.77, 0.64), (0.78, 0.70, 0.55), (0.70, 0.66, 0.60), (0.86, 0.80, 0.70), (0.74, 0.62, 0.48)]
            wall_col = tuple(np.array(palette[rng.integers(len(palette))]) * rng.uniform(0.85, 1.02))
            roof_col = tuple(np.array([0.52, 0.24, 0.15]) * rng.uniform(0.75, 1.15))
            c = add_house(scene, pos, d, w, h, yaw=math.pi / 2, wall=wall_col, roof=roof_col, chimney=rng.random() < 0.6)
            chimneys.append(c)
        z += w + rng.uniform(0.3, 2.0)
    return chimneys


def res(scale, w=960, h=540):
    """Anteprima (scala 1): w x h. Finale (scala 2): il doppio, calcolato a 2x e ridotto (antialiasing)."""
    if scale <= 1:
        return w, h, 1, 1.0
    return w * 4, h * 4, 2, 4.0


def ground(scene, size=900, n=60, y=0.0, color=(0.55, 0.50, 0.44)):
    V, F = grid_quad((-size / 2, y, -size / 2), (size, 0, 0), (0, 0, size), n, n)
    scene.add(V, F, M_GROUND, color, smooth=False)


# ---------------------------------------------------------------------------------------------
# 1) Gigante in città, mura sullo sfondo, soldato in volo
# ---------------------------------------------------------------------------------------------


def scene_hero(m, scale):
    rng = np.random.default_rng(12)
    sc = Scene()
    ground(sc)
    H = 20.0
    tpos = np.array([0.0, 0.0, 0.0])
    yaw = math.radians(12)
    add_titan(sc, m, H, tpos, yaw=yaw, pose="roar")
    J = joints_world(m, H, tpos, yaw)
    street_houses(sc, rng, -90, 60, 1, ruined_near=tpos)
    street_houses(sc, rng, -90, 60, -1, ruined_near=tpos)
    add_rubble(sc, tpos + np.array([3, 0, -4]), 7, 18, rng)
    # le mura lontane
    add_wall(sc, (-700, 0, 140), (700, 0, 140), 62, thick=16)
    for x in (-150, 70, 240):
        add_tower(sc, (x, 0, 131), 10, 76)
    # vapore dal gigante
    steam(sc, J["Neck"] + np.array([0, 1, 0]), (3.0, 1.5, 3.0), 30, rng, size=(2.2, 5.5), rise=12, alpha=0.6)
    steam(sc, J["Waist"], (3.0, 3.0, 2.0), 14, rng, size=(1.5, 3.5), rise=4, alpha=0.35)
    steam(sc, J["RightShoulder"], (1.5, 1.0, 1.5), 8, rng, size=(1.5, 3.5), rise=5, alpha=0.45)
    steam(sc, J["LeftShoulder"], (1.5, 1.0, 1.5), 8, rng, size=(1.5, 3.5), rise=5, alpha=0.45)
    # fumo dalle case distrutte
    for p in ((18, 0, 30), (-22, 0, 45), (35, 0, -10)):
        steam(sc, p, (4, 2, 4), 14, rng, size=(5, 11), rise=30, color=(0.42, 0.38, 0.36), alpha=0.55)
    # soldato in volo verso il gigante
    spos = np.array([7.5, 13.5, -18.0])
    anchors, _ = add_soldier(sc, spos, yaw=math.radians(115), pitch=-1.0, roll=-0.3, s=1.3, pose="fly")
    sc.lines.append((anchors[0], J["LeftShoulder"] + np.array([0.5, 0.5, 0]), 1.6 * scale, (0.12, 0.12, 0.13)))
    sc.lines.append((anchors[1], np.array([3.5, 15.5, -1.0]), 1.6 * scale, (0.12, 0.12, 0.13)))
    gas_trail(sc, [spos + np.array([0.9, -0.5, -0.2]), spos + np.array([5, -1.4, -1.0]), spos + np.array([10, -1.2, -2.5])], rng)
    # secondo soldato più lontano, sul tetto a destra
    s2 = np.array([-9.0, 17.5, 6.0])
    a2, _ = add_soldier(sc, s2, yaw=math.radians(-75), pitch=-0.9, roll=0.3, s=1.0, pose="dive")
    sc.lines.append((a2[0], J["Nape"] + np.array([0, 0.4, 0]), 1.2 * scale, (0.12, 0.12, 0.13)))
    gas_trail(sc, [s2, s2 + np.array([-4, -1, 3]), s2 + np.array([-8, -3, 5])], rng, size=(0.3, 0.9))
    W, Hh, ss, k = res(scale)
    for i, (a, b, wdt, col) in enumerate(sc.lines):
        sc.lines[i] = (a, b, wdt * k / scale, col)
    cam = Camera((-2.0, 2.2, -36), (-3.8, 12.5, 0), 50, W, Hh, roll=math.radians(-2.0))
    look = Look(
        sun_dir=(-0.22, 0.20, 0.95), sun_col=(2.6, 1.75, 1.05), sky_top=(0.16, 0.22, 0.42), sky_hor=(1.05, 0.62, 0.36),
        sky_amb=(0.30, 0.31, 0.42), ground_amb=(0.22, 0.15, 0.10), fog_density=0.0045, fog_height=35,
        cloud_cover=0.55, cloud_col=(1.15, 0.72, 0.48), cloud_dark=(0.32, 0.26, 0.30), rays=0.55, bloom=0.4,
        shadow_extent=160, shadow_center=(0, 0, 0), ground_mat="cobble", saturation=1.02, exposure=1.05,
    )
    return render(sc, cam, look, ss=ss)


# ---------------------------------------------------------------------------------------------
# 2) Combattimento: soldato che si lancia sulla nuca del gigante, temporale
# ---------------------------------------------------------------------------------------------


def lightning_post(bolts, flash=0.25):
    """Fulmini disegnati sopra il cielo (dopo il render, prima della correzione colore)."""

    def fx(img, depth, cam):
        H, W = depth.shape
        rng = np.random.default_rng(5)
        glow = np.zeros((H, W))
        for (x0, y0, x1, y1) in bolts:
            pts = [(x0 * W, y0 * H)]
            n = 14
            for i in range(1, n + 1):
                t = i / n
                x = x0 * W + (x1 - x0) * W * t + rng.normal(0, W * 0.012)
                y = y0 * H + (y1 - y0) * H * t
                pts.append((x, y))
                if rng.random() < 0.3 and i < n - 2:  # ramificazioni
                    bx, by = x, y
                    for _ in range(4):
                        nx, ny = bx + rng.normal(W * 0.01, W * 0.01), by + H * 0.03
                        _seg(glow, bx, by, nx, ny, W * 0.0006)
                        bx, by = nx, ny
            for a, b in zip(pts[:-1], pts[1:]):
                _seg(glow, a[0], a[1], b[0], b[1], W * 0.0011)
        from engine import gaussian
        halo = gaussian(glow[..., None], W * 0.006)[..., 0]
        sky = np.isinf(depth)
        core = np.clip(glow, 0, 1) * sky
        img = img + (core[..., None] * 5 + (halo * (0.35 + 0.65 * sky))[..., None] * 2.2) * np.array([0.75, 0.82, 1.0])
        return img * (1 + flash)

    return fx


def _seg(buf, x0, y0, x1, y1, w):
    H, W = buf.shape
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    t = np.linspace(0, 1, n)
    xs = x0 + (x1 - x0) * t
    ys = y0 + (y1 - y0) * t
    r = max(1, int(w))
    for dx in range(-r, r + 1):
        for dy in range(-r, r + 1):
            xi = np.clip((xs + dx).astype(int), 0, W - 1)
            yi = np.clip((ys + dy).astype(int), 0, H - 1)
            buf[yi, xi] = 1.0


def rain_overlay(img, amount=2500, seed=3, angle=0.18):
    """Pioggia: righe sottili semitrasparenti (sull'immagine finale)."""
    from PIL import ImageDraw
    W, H = img.size
    layer = img.convert("RGBA")
    over = __import__("PIL.Image", fromlist=["Image"]).new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    rng = np.random.default_rng(seed)
    for _ in range(amount):
        x = rng.uniform(-50, W + 50)
        y = rng.uniform(-50, H)
        L = rng.uniform(H * 0.02, H * 0.06)
        a = int(rng.uniform(25, 70))
        d.line([(x, y), (x - L * angle, y + L)], fill=(210, 220, 235, a), width=1)
    return __import__("PIL.Image", fromlist=["Image"]).alpha_composite(layer, over).convert("RGB")


def city_block(sc, rng, center, radius, avoid=None, min_h=6, max_h=12, step=13.0):
    xs = np.arange(-radius, radius, step)
    for x in xs:
        for z in xs:
            if (x / step) % 3 == 0:  # strade
                continue
            p = np.asarray(center) + np.array([x + rng.uniform(-1.5, 1.5), 0, z + rng.uniform(-1.5, 1.5)])
            if np.hypot(x, z) > radius:
                continue
            if avoid is not None and np.linalg.norm((p - avoid)[[0, 2]]) < 14:
                continue
            palette = [(0.84, 0.77, 0.64), (0.78, 0.70, 0.55), (0.70, 0.66, 0.60), (0.86, 0.80, 0.70), (0.74, 0.62, 0.48)]
            add_house(sc, p, rng.uniform(7, 10), rng.uniform(8, 11), rng.uniform(min_h, max_h), yaw=rng.choice([0, math.pi / 2]),
                      wall=tuple(np.array(palette[rng.integers(len(palette))]) * rng.uniform(0.85, 1.02)),
                      roof=tuple(np.array([0.52, 0.24, 0.15]) * rng.uniform(0.7, 1.15)), chimney=rng.random() < 0.5)


def scene_combat(m, scale):
    rng = np.random.default_rng(21)
    sc = Scene()
    ground(sc, size=1200, n=50)
    H = 21.0
    tpos = np.array([0.0, 0.0, 0.0])
    yaw = math.radians(-20)
    add_titan(sc, m, H, tpos, yaw=yaw, pose="attack")
    J = joints_world(m, H, tpos, yaw)
    city_block(sc, rng, (0, 0, 0), 110, avoid=tpos)
    add_wall(sc, (-900, 0, -260), (900, 0, -260), 62, thick=16)
    for x in (-200, 40, 230):
        add_tower(sc, (x, 0, -251), 10, 76)
    nape = J["Nape"]
    back = normalize(np.array([math.sin(yaw), 0, math.cos(yaw)]))
    # soldato in picchiata sulla nuca, lame alzate
    side = np.cross(np.array([0, 1.0, 0]), back)
    campos = nape + back * 13 + side * 9.0 + np.array([0, -1.0, 0])
    vdir = normalize((nape - campos) * np.array([1, 0, 1]))
    lateral = normalize(np.cross(vdir, np.array([0, 1.0, 0])))
    spos = nape + np.array([0, 3.4, 0]) - vdir * 4.0 + lateral * 4.8
    syaw = math.atan2(lateral[0], lateral[2])
    anchors, tips = add_soldier(sc, spos, yaw=syaw, pitch=-1.95, roll=0.1, s=1.3, pose="dive")
    for a, t in zip(anchors, (J["RightShoulder"], J["LeftShoulder"])):
        sc.lines.append((a, t + back * 1.2 + np.array([0, 0.3, 0]), 1.6, (0.10, 0.10, 0.11)))
    gas_trail(sc, [spos + lateral * 1.0, spos + lateral * 5 + np.array([0, 2.0, 0]), spos + lateral * 10 + np.array([0, 3.5, 0])], rng, size=(0.4, 1.4), alpha=0.6)
    steam(sc, nape + back * 0.6, (0.8, 0.5, 0.8), 7, rng, size=(0.8, 1.8), rise=3, alpha=0.4)
    steam(sc, J["RightShoulder"] + back * 0.5, (1.0, 0.6, 1.0), 6, rng, size=(1.0, 2.2), rise=4, alpha=0.35)
    # altri soldati lontani
    for p, yw in (((-28, 24, -20), 0.8), ((30, 18, 12), -2.2), ((-40, 14, 30), 2.4)):
        a3, _ = add_soldier(sc, np.array(p, float), yaw=yw, pitch=-1.0, roll=0.3, s=1.0, pose="fly")
        gas_trail(sc, [np.array(p, float), np.array(p, float) + np.array([math.sin(yw), 0, math.cos(yw)]) * 8], rng, size=(0.3, 0.8), alpha=0.45)
    W, Hh, ss, k = res(scale)
    for i, (a, b, wdt, col) in enumerate(sc.lines):
        sc.lines[i] = (a, b, wdt * k, col)
    cam = Camera(campos, nape + np.array([0, 2.6, 0]) - back * 3 + side * 1.5, 55, W, Hh, roll=math.radians(-4))
    look = Look(
        sun_dir=(0.35, 0.55, -0.75), sun_col=(1.55, 1.65, 1.95), sky_top=(0.05, 0.06, 0.10), sky_hor=(0.26, 0.29, 0.36),
        sky_amb=(0.22, 0.25, 0.33), ground_amb=(0.10, 0.10, 0.12), fog_density=0.0055, fog_height=60,
        cloud_cover=0.8, cloud_col=(0.50, 0.54, 0.64), cloud_dark=(0.06, 0.07, 0.10), rays=0.0, bloom=0.5,
        shadow_extent=160, shadow_center=tuple(tpos), ground_mat="cobble", saturation=0.92, exposure=1.1, sun_disk=False,
    )
    img = render(sc, cam, look, ss=ss, extra_post=lightning_post([(0.83, 0.0, 0.76, 0.45), (0.30, 0.0, 0.36, 0.22)], flash=0.12))
    return rain_overlay(img, amount=int(2600 * (img.size[0] / 960) ** 1.0))


# ---------------------------------------------------------------------------------------------
# 3) Il mondo: isola con la città murata, il mare e le altre isole all'alba
# ---------------------------------------------------------------------------------------------


def island_height(x, z, radius, flat=300.0, seed=0):
    from engine import fbm
    r = np.hypot(x, z)
    n = fbm(np.stack([x * 0.006, z * 0.006, np.full_like(x, seed)], -1), 4, seed=200 + seed)
    hills = np.clip((r - flat * 0.95) / (radius * 0.35), 0, 1) * (6 + 28 * n)
    coast = np.clip((r - radius) / 70.0, 0, 1)
    h = hills * (1 - coast) - 9 * coast
    return np.where(r < flat * 0.95, 0.3 * (n - 0.5), h)


def add_island(sc, center, radius, n=180, flat=300.0, seed=0, color=(0.42, 0.40, 0.30)):
    size = radius * 2.6
    V, F = grid_quad((center[0] - size / 2, 0, center[2] - size / 2), (size, 0, 0), (0, 0, size), n, n)
    V[:, 1] = center[1] + island_height(V[:, 0] - center[0], V[:, 2] - center[2], radius, flat, seed)
    keep = (V[F][:, :, 1] > center[1] - 8).any(axis=1)
    sc.add(V, F[keep], M_GROUND, color, smooth=True)


def ring_wall(sc, center, radius, height, segments=28, towers=8):
    c = np.asarray(center, float)
    for i in range(segments):
        a0 = i / segments * 2 * math.pi
        a1 = (i + 1) / segments * 2 * math.pi
        p0 = c + np.array([math.cos(a0) * radius, 0, math.sin(a0) * radius])
        p1 = c + np.array([math.cos(a1) * radius, 0, math.sin(a1) * radius])
        add_wall(sc, p0, p1, height, thick=10, seg=6.0)
    for i in range(towers):
        a = i / towers * 2 * math.pi + 0.2
        add_tower(sc, c + np.array([math.cos(a) * radius, 0, math.sin(a) * radius]), 8, height + 14)


def scene_world(m, scale):
    rng = np.random.default_rng(31)
    sc = Scene()
    V, F = grid_quad((-6000, -2.0, -6000), (12000, 0, 0), (0, 0, 12000), 40, 40)
    sc.add(V, F, M_WATER, (0.03, 0.16, 0.26), smooth=False)
    add_island(sc, (0, 0, 0), 470, n=170, flat=230, seed=1)
    for c, r, sd in (((-1500, 0, 2300), 520, 2), ((1700, 0, 2900), 650, 3), ((300, 0, 4200), 800, 4)):
        add_island(sc, c, r, n=60, flat=10, seed=sd, color=(0.36, 0.38, 0.28))
    ring_wall(sc, (0, 0, 0), 200, 36)
    city_block(sc, rng, (0, 0, 0), 185, min_h=6, max_h=13, step=15.0)
    # palazzo al centro
    add_tower(sc, (0, 0, 0), 14, 46, roof=(0.25, 0.30, 0.42))
    # alberi fuori dalle mura
    for _ in range(170):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(225, 380)
        x, z = math.cos(a) * r, math.sin(a) * r
        if z < -150 and abs(x) < 220:
            continue
        y = float(island_height(np.array([x]), np.array([z]), 470, 230, 1)[0])
        if y > -1:
            add_tree(sc, (x, y, z), rng.uniform(9, 16), rng)
    # giganti che marciano verso le mura
    for x, z, yw, h in ((-175, -255, math.radians(220), 26), (-95, -300, math.radians(195), 22), (-255, -165, math.radians(240), 24)):
        y = float(island_height(np.array([x]), np.array([z]), 470, 230, 1)[0])
        add_titan(sc, m, h, (x, y, z), yaw=yw + math.pi, pose="roar" if h > 24 else "stand")
        steam(sc, (x, y + h * 0.9, z), (2, 1, 2), 6, rng, size=(2, 4), rise=6, alpha=0.35)
    # soldato in primo piano che vola verso la città
    campos = np.array([-285.0, 120.0, -360.0])
    target = np.array([-10.0, 8.0, 30.0])
    fwd = normalize(target - campos)
    lat = normalize(np.cross(fwd, np.array([0, 1.0, 0])))
    spos = campos + fwd * 15 + lat * 4.6 + np.array([0, -1.6, 0])
    dirn = normalize(-lat + fwd * 0.6)
    syaw = math.atan2(-dirn[0], -dirn[2])
    anchors, _ = add_soldier(sc, spos, yaw=syaw, pitch=-1.25, roll=0.35, s=1.0, pose="fly")
    tower_top = np.array([math.cos(0.2 + 6 * 2 * math.pi / 8) * 200, 50, math.sin(0.2 + 6 * 2 * math.pi / 8) * 200])
    sc.lines.append((anchors[0], tower_top, 1.3, (0.10, 0.10, 0.11)))
    gas_trail(sc, [spos - dirn * 0.8, spos - dirn * 6 + np.array([0, 0.8, 0]), spos - dirn * 12 + np.array([0, 1.2, 0])], rng, size=(0.25, 0.8), alpha=0.55)
    # altri soldati sopra la città
    for p, yw in (((-40, 70, -140), 0.4), ((30, 60, -180), -0.3), ((-90, 55, -60), 1.2)):
        add_soldier(sc, np.array(p, float), yaw=yw, pitch=-1.0, roll=0.3, s=1.4, pose="fly")
        gas_trail(sc, [np.array(p, float), np.array(p, float) + np.array([math.sin(yw), 0.5, math.cos(yw)]) * 14], rng, size=(0.6, 1.8), alpha=0.5)
    # fumo dai camini
    for _ in range(8):
        p = np.array([rng.uniform(-150, 150), 14, rng.uniform(-150, 150)])
        steam(sc, p, (2, 2, 2), 5, rng, size=(4, 8), rise=25, color=(0.75, 0.72, 0.70), alpha=0.35)
    W, Hh, ss, k = res(scale)
    for i, (a, b, wdt, col) in enumerate(sc.lines):
        sc.lines[i] = (a, b, wdt * k, col)
    cam = Camera(campos, target, 50, W, Hh, roll=math.radians(3))
    look = Look(
        sun_dir=(-0.75, 0.33, 0.57), sun_col=(2.4, 1.8, 1.25), sky_top=(0.18, 0.32, 0.60), sky_hor=(0.95, 0.75, 0.58),
        sky_amb=(0.30, 0.36, 0.50), ground_amb=(0.16, 0.14, 0.10), fog_density=0.00045, fog_height=160,
        cloud_cover=0.45, cloud_col=(1.2, 0.85, 0.6), cloud_dark=(0.35, 0.32, 0.40), rays=0.5, bloom=0.45,
        shadow_extent=560, shadow_center=(-80, 0, -60), ground_mat="ground", saturation=1.1, exposure=1.0,
    )
    return render(sc, cam, look, ss=ss)


# ---------------------------------------------------------------------------------------------
# 4) Icona del gioco (512x512): il Gigante della Furia che urla
# ---------------------------------------------------------------------------------------------


def scene_icon(m, scale):
    rng = np.random.default_rng(41)
    sc = Scene()
    ground(sc, size=600, n=30)
    H = 20.0
    tpos = np.array([0.0, 0.0, 0.0])
    yaw = math.radians(-18)
    add_titan(sc, m, H, tpos, yaw=yaw, pose="roar")
    J = joints_world(m, H, tpos, yaw)
    add_wall(sc, (-500, 0, 120), (500, 0, 120), 55, thick=14)
    street_houses(sc, rng, -60, 40, 1, depth_rows=2, ruined_near=tpos)
    street_houses(sc, rng, -60, 40, -1, depth_rows=2, ruined_near=tpos)
    steam(sc, J["Neck"] + np.array([0, 0.5, 0]), (2.5, 1.0, 2.5), 18, rng, size=(1.5, 3.5), rise=7, alpha=0.45)
    fwd0 = np.array([-math.sin(yaw), 0, -math.cos(yaw)])
    spos = J["Neck"] + fwd0 * 9 + np.array([-6.5, 1.0, 0])
    anchors, _ = add_soldier(sc, spos, yaw=math.radians(-80), pitch=-1.0, roll=0.3, s=1.1, pose="fly")
    sc.lines.append((anchors[0], J["LeftShoulder"] + np.array([0, 0.5, 0]), 1.2, (0.1, 0.1, 0.11)))
    gas_trail(sc, [spos, spos + np.array([-5, -0.8, 0.5]), spos + np.array([-10, -1.5, 1.0])], rng, size=(0.3, 0.9))
    if scale <= 1:
        W = Hh = 512
        ss, k = 1, 1.0
    else:
        W = Hh = 1024
        ss, k = 2, 2.0
    for i, (a, b, wdt, col) in enumerate(sc.lines):
        sc.lines[i] = (a, b, wdt * k, col)
    fwd = np.array([-math.sin(yaw), 0, -math.cos(yaw)])
    chest = J["Neck"] + np.array([0, -2.5, 0])
    campos = chest + fwd * 27 + np.array([-5.0, -9.0, 0])
    cam = Camera(campos, chest + np.array([0.0, 1.0, 0]), 50, W, Hh, roll=math.radians(-5))
    look = Look(
        sun_dir=(-0.62, 0.38, -0.68), sun_col=(2.5, 1.7, 1.05), sky_top=(0.30, 0.16, 0.30), sky_hor=(1.15, 0.50, 0.24),
        sky_amb=(0.34, 0.28, 0.36), ground_amb=(0.22, 0.14, 0.10), fog_density=0.005, fog_height=40,
        cloud_cover=0.6, cloud_col=(1.3, 0.62, 0.35), cloud_dark=(0.30, 0.16, 0.22), rays=0.0, bloom=0.45,
        shadow_extent=120, shadow_center=(0, 0, 0), ground_mat="cobble", saturation=1.12, exposure=1.08, vignette=0.45,
    )
    return render(sc, cam, look, ss=ss)


# ---------------------------------------------------------------------------------------------
# Stile "copertina": il soldato Roblox in primo piano, il gigante dietro (come gli esempi)
# ---------------------------------------------------------------------------------------------

VIVID = dict(
    sun_dir=(0.80, 0.30, -0.45), sun_col=(2.5, 1.85, 1.35), sky_top=(0.22, 0.30, 0.62), sky_hor=(1.15, 0.62, 0.42),
    sky_amb=(0.46, 0.44, 0.56), ground_amb=(0.26, 0.19, 0.13), fog_density=0.004, fog_height=45,
    cloud_cover=0.5, cloud_col=(1.25, 0.78, 0.62), cloud_dark=(0.42, 0.32, 0.48), rays=0.3, bloom=0.45,
    ground_mat="cobble", saturation=1.22, exposure=1.12, vignette=0.28,
)


def scene_hero2(m, scale):
    rng = np.random.default_rng(52)
    sc = Scene()
    ground(sc)
    H = 25.0
    tpos = np.array([17.5, 0.0, 13.0])
    yaw = math.radians(-30)
    add_titan(sc, m, H, tpos, yaw=yaw, pose="roar")
    J = joints_world(m, H, tpos, yaw)
    street_houses(sc, rng, -60, 70, 1, skip_near=tpos + np.array([0, 0, -4]), skip_radius=20, ruined_near=tpos)
    add_rubble(sc, tpos + np.array([-4, 0, -10]), 10, 26, rng)
    street_houses(sc, rng, -60, 70, -1)
    add_rubble(sc, tpos + np.array([0, 0, -6]), 8, 20, rng)
    add_wall(sc, (-700, 0, 150), (700, 0, 150), 62, thick=16)
    for x in (-150, 75, 250):
        add_tower(sc, (x, 0, 141), 10, 76)
    steam(sc, J["Neck"] + np.array([0, 1, 0]), (3.0, 1.5, 3.0), 24, rng, size=(2.2, 5.0), rise=10, alpha=0.5)
    for p in ((22, 0, 40), (-24, 0, 55)):
        steam(sc, p, (4, 2, 4), 12, rng, size=(5, 10), rise=28, color=(0.45, 0.40, 0.38), alpha=0.5)
    # il soldato: in aria davanti alla telecamera, lama alzata, sorride
    spos = np.array([-1.3, 4.05, -24.7])
    anchors, tips = add_soldier(sc, spos, yaw=math.radians(-28), pitch=0.08, roll=-0.08, s=1.0, pose="hero")
    sc.lines.append((anchors[0], np.array([-10.5, 13.0, 2.0]), 1.4, (0.10, 0.10, 0.11)))
    sc.lines.append((anchors[1], np.array([7.0, 12.0, -8.0]), 1.4, (0.10, 0.10, 0.11)))
    gas_trail(sc, [spos + np.array([-0.4, 0.2, 0.8]), spos + np.array([-1.5, 1.4, 5.0]), spos + np.array([-3.0, 2.8, 10.0])], rng, size=(0.25, 0.9), alpha=0.5)
    # altri soldati in volo vicino al gigante
    for p, yw, ps in (((25, 24, 6), 2.6, "dive"), ((8, 19, 8), 0.9, "fly")):
        a3, _ = add_soldier(sc, np.array(p, float), yaw=yw, pitch=-1.0, roll=0.3, s=1.0, pose=ps)
        sc.lines.append((a3[0], J["Nape"], 1.0, (0.10, 0.10, 0.11)))
    W, Hh, ss, k = res(scale)
    for i, (a, b, wdt, col) in enumerate(sc.lines):
        sc.lines[i] = (a, b, wdt * k, col)
    cam = Camera((0.6, 4.4, -29.5), (1.2, 7.6, 0), 50, W, Hh, roll=math.radians(-1.5))
    look = Look(shadow_extent=110, shadow_center=(0, 0, -5), **VIVID)
    return render(sc, cam, look, ss=ss)


def scene_icon2(m, scale):
    rng = np.random.default_rng(61)
    sc = Scene()
    ground(sc, size=600, n=30)
    H = 22.0
    tpos = np.array([5.0, 0.0, 30.0])
    yaw = math.radians(-12)
    add_titan(sc, m, H, tpos, yaw=yaw, pose="roar")
    J = joints_world(m, H, tpos, yaw)
    street_houses(sc, rng, -30, 60, 1, depth_rows=2, ruined_near=tpos)
    street_houses(sc, rng, -30, 60, -1, depth_rows=2)
    add_wall(sc, (-500, 0, 140), (500, 0, 140), 60, thick=14)
    steam(sc, J["Neck"] + np.array([0, 1, 0]), (3.0, 1.5, 3.0), 18, rng, size=(2.2, 5.0), rise=9, alpha=0.5)
    spos = np.array([-0.45, 1.55, -6.5])
    add_soldier(sc, spos, yaw=math.radians(-22), pitch=0.05, roll=-0.05, s=1.0, pose="hero", head_scale=1.15)
    if scale <= 1:
        W = Hh = 512
        ss = 1
    else:
        W = Hh = 2048
        ss = 2
    cam = Camera((0.15, 2.55, -9.6), (-0.15, 3.45, 0), 44, W, Hh)
    look = Look(shadow_extent=80, shadow_center=(0, 0, 0), dof=(3.8, 0.75), **VIVID)
    return render(sc, cam, look, ss=ss)


if __name__ == "__main__":
    fbx_dir, out_dir = sys.argv[1], sys.argv[2]
    scale = int(sys.argv[3]) if len(sys.argv) > 3 else 1
    which = sys.argv[4].split(",") if len(sys.argv) > 4 else ["hero"]
    os.makedirs(out_dir, exist_ok=True)
    m = load(fbx_dir)
    for name in which:
        print("scena", name)
        img = globals()["scene_" + name](m, scale)
        img.save(os.path.join(out_dir, f"{name}_raw.png"))
