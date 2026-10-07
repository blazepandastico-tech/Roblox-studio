"""Oggetti di scena: soldato con il dispositivo di manovra (stile avatar Roblox), case, mura, torri."""
import math

import numpy as np

from engine import (M_CLOTH, M_COLOR, M_FACE, M_GLOW, M_METAL, M_PLASTER, M_ROOF, M_SKIN, M_STONE, M_WOOD,
                    add_box, add_cylinder, add_sphere, normalize, rot_x, rot_y, rot_z)

JACKET = (0.42, 0.27, 0.15)
PANTS = (0.86, 0.84, 0.78)
CAPE = (0.12, 0.30, 0.20)
SKIN = (0.93, 0.74, 0.58)
BOOTS = (0.16, 0.10, 0.07)
STRAP = (0.10, 0.07, 0.05)
STEEL = (0.78, 0.80, 0.84)
GEAR = (0.38, 0.39, 0.42)


class Frame:
    """Sistema di riferimento (rotazione + origine) per costruire pezzi in coordinate locali."""

    def __init__(self, R, o):
        self.R = np.asarray(R, float)
        self.o = np.asarray(o, float)

    def p(self, local):
        return self.R @ np.asarray(local, float) + self.o

    def child(self, R_local, local_origin):
        return Frame(self.R @ R_local, self.p(local_origin))

    def box(self, scene, local_center, size, mat, color, R_local=None, seg=0.25):
        R = self.R if R_local is None else self.R @ R_local
        add_box(scene, self.p(local_center), size, mat, color, R=R, seg=seg)


def face_texture(size=512, mood="grin"):
    """Faccia in stile Roblox: occhi ovali, sopracciglia decise e sorriso con i denti."""
    from PIL import Image, ImageDraw
    S = size * 2
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    k = S / 512
    ink = (24, 16, 12, 255)
    for cx in (176, 336):
        d.ellipse([(cx - 30) * k, 196 * k, (cx + 30) * k, 292 * k], fill=ink)
        d.ellipse([(cx - 16) * k, 210 * k, (cx + 2) * k, 236 * k], fill=(255, 255, 255, 255))
        d.ellipse([(cx + 6) * k, 246 * k, (cx + 14) * k, 258 * k], fill=(255, 255, 255, 200))
    # sopracciglia inclinate verso il centro (sguardo deciso)
    d.polygon([(132 * k, 168 * k), (222 * k, 182 * k), (218 * k, 200 * k), (128 * k, 188 * k)], fill=(60, 36, 20, 255))
    d.polygon([(380 * k, 168 * k), (290 * k, 182 * k), (294 * k, 200 * k), (384 * k, 188 * k)], fill=(60, 36, 20, 255))
    if mood == "grin":
        # bocca: sorriso aperto con i denti di sopra
        box = [150 * k, 280 * k, 362 * k, 420 * k]
        d.chord(box, 0, 180, fill=(110, 24, 22, 255), outline=ink, width=int(7 * k))
        d.chord([166 * k, 286 * k, 346 * k, 360 * k], 0, 180, fill=(250, 250, 245, 255))
        d.line([(154 * k, 350 * k), (358 * k, 350 * k)], fill=ink, width=int(7 * k))
        d.ellipse([214 * k, 380 * k, 298 * k, 414 * k], fill=(200, 70, 70, 255))
    else:
        d.arc([180 * k, 300 * k, 332 * k, 380 * k], 20, 160, fill=ink, width=int(12 * k))
    im = im.resize((size, size), Image.LANCZOS)
    return np.asarray(im).astype(np.float64) / 255.0


SOLDIER_POSES = {
    # gambe (dx, sx), braccia per lato: (avanti/indietro, apertura), mantello
    "fly": {"legs": (-0.45, -0.15), "armR": (-1.0, 0.3), "armL": (-1.0, 0.3), "cape": -1.2},
    "dive": {"legs": (-0.5, -0.15), "armR": (2.7, 0.3), "armL": (2.7, 0.3), "cape": -1.35},
    "stand": {"legs": (0.0, 0.0), "armR": (0.1, 0.1), "armL": (0.1, 0.1), "cape": -0.08},
    "hero": {"legs": (0.18, -0.22), "armR": (2.75, 0.25), "armL": (0.75, 0.95), "cape": -0.55},
    "flyhero": {"legs": (-0.7, -0.25), "armR": (1.75, 0.25), "armL": (-0.9, 0.45), "cape": -1.15},
}


def _superhead(scene, frame, size, face=True, hair=None, n=18):
    """Testa arrotondata (come quella classica di Roblox) con la faccia sul davanti."""
    lat = np.linspace(0, math.pi, n + 1)
    lon = np.linspace(0, 2 * math.pi, 2 * n, endpoint=False)
    L, O = np.meshgrid(lat, lon, indexing="ij")
    P = np.stack([np.sin(L) * np.cos(O), np.cos(L), np.sin(L) * np.sin(O)], -1).reshape(-1, 3)
    q = P / (np.sum(P ** 4, axis=1) ** 0.25)[:, None]
    Ng = normalize(q ** 3)
    m = 2 * n
    F = []
    for i in range(n):
        for j in range(m):
            a = i * m + j
            b = i * m + (j + 1) % m
            F += [(a, b, b + m), (a, b + m, a + m)]
    F = np.array(F)
    half = np.asarray(size) / 2
    V = frame.p(np.zeros(3))[None] + (q * half) @ frame.R.T
    N = normalize(Ng / half @ frame.R.T)
    u = 0.5 - q[:, 0] * 0.56
    v = 0.5 + q[:, 1] * 0.56 - 0.02
    UV = np.stack([np.where(q[:, 2] < -0.05, u, u + 10), v], -1)
    scene.add(V, F, M_FACE if face else M_SKIN, SKIN, N=N, UV=UV)
    if hair is not None:
        hq = q * 1.09
        keep_v = (q[:, 1] > 0.28) | ((q[:, 2] > 0.25) & (q[:, 1] > -0.45)) | ((np.abs(q[:, 0]) > 0.85) & (q[:, 1] > 0.0) & (q[:, 2] > -0.3))
        Fh = F[keep_v[F].all(axis=1)]
        Vh = frame.p(np.zeros(3))[None] + (hq * half) @ frame.R.T
        scene.add(Vh, Fh, M_CLOTH, hair, N=N)
        # ciuffo sulla fronte
        for k, (x, rz) in enumerate(((-0.45, 0.25), (-0.05, -0.15), (0.38, 0.3))):
            frame.box(scene, (x * half[0], 0.62 * half[1], -0.98 * half[2]), (0.55 * half[0], 0.35 * half[1], 0.2 * half[2]), M_CLOTH, hair, R_local=rot_z(rz), seg=0.2)


def add_soldier(scene, pos, yaw=0.0, pitch=0.0, roll=0.0, s=1.0, pose="fly", hair=(0.28, 0.17, 0.09), blades=True, head_scale=1.0):
    """Avatar in stile Roblox (proporzioni R15) alto circa 1.9*s metri. Origine = anche.
    Restituisce le posizioni (mondo) delle due fondine del rampino e le punte delle lame."""
    if scene.face_tex is None:
        scene.face_tex = face_texture()
    cfg = SOLDIER_POSES[pose]
    R = rot_y(yaw) @ rot_x(pitch) @ rot_z(roll)
    body = Frame(R * s, pos)
    u = 0.38  # unità avatar: 1 stud ≈ 0.38 m
    for side, a in ((1, cfg["legs"][0]), (-1, cfg["legs"][1])):
        hip = body.child(rot_x(a), (side * 0.5 * u, 0, 0))
        hip.box(scene, (0, -1.0 * u, 0), (0.95 * u, 2.0 * u, 0.95 * u), M_CLOTH, PANTS)
        hip.box(scene, (0, -1.75 * u, 0), (1.0 * u, 0.6 * u, 1.05 * u), M_CLOTH, BOOTS)
        hip.box(scene, (0, -0.45 * u, 0), (1.0 * u, 0.12 * u, 1.0 * u), M_CLOTH, STRAP)
    body.box(scene, (0, 1.0 * u, 0), (2.0 * u, 2.0 * u, 1.0 * u), M_CLOTH, JACKET)
    body.box(scene, (0, 0.15 * u, 0), (2.02 * u, 0.3 * u, 1.02 * u), M_CLOTH, STRAP)
    body.box(scene, (0, 1.0 * u, -0.505 * u), (0.9 * u, 1.9 * u, 0.02 * u), M_CLOTH, (0.92, 0.90, 0.86))
    for side in (1, -1):
        body.box(scene, (side * 0.45 * u, 1.0 * u, -0.53 * u), (0.14 * u, 2.0 * u, 0.06 * u), M_CLOTH, STRAP)
    hs = 1.3 * u * head_scale
    head = body.child(np.eye(3), (0, 2.0 * u + hs * 0.5, 0))
    _superhead(scene, head, (hs * 1.02, hs, hs), face=True, hair=hair)
    blade_tips = []
    for side in (1, -1):
        arm = cfg["armR"] if side > 0 else cfg["armL"]
        sh = body.child(rot_x(arm[0]) @ rot_z(side * arm[1]), (side * 1.5 * u, 1.8 * u, 0))
        sh.box(scene, (0, -0.95 * u, 0), (0.95 * u, 2.0 * u, 0.95 * u), M_CLOTH, JACKET)
        sh.box(scene, (0, -2.05 * u, 0), (0.9 * u, 0.35 * u, 0.9 * u), M_SKIN, SKIN)
        if blades:
            hand = sh.child(rot_z(side * 0.12), (0, -2.1 * u, 0))
            hand.box(scene, (0, -0.1 * u, 0), (0.55 * u, 0.35 * u, 0.7 * u), M_METAL, GEAR)
            hand.box(scene, (0, -2.6 * u, 0), (0.08 * u, 4.8 * u, 0.5 * u), M_METAL, STEEL, seg=0.4)
            blade_tips.append(hand.p((0, -5.0 * u, 0)))
    cape = body.child(rot_x(cfg["cape"]), (0, 1.95 * u, 0.55 * u))
    cape.box(scene, (0, -1.6 * u, 0.0), (2.3 * u, 3.2 * u, 0.08 * u), M_CLOTH, CAPE, seg=0.3)
    cape.box(scene, (0, -0.15 * u, 0.0), (2.4 * u, 0.3 * u, 0.12 * u), M_CLOTH, (0.10, 0.25, 0.17))
    em = cape.child(np.eye(3), (0, -1.3 * u, 0.06 * u))
    add_cylinder(scene, em.p((0, 0, 0)), em.p((0, 0, 0.02 * u)), 0.45 * u * s, M_METAL, (0.85, 0.66, 0.22), n=16)
    anchors = []
    for side in (1, -1):
        gb = body.child(np.eye(3), (side * 1.25 * u, -0.1 * u, 0.15 * u))
        gb.box(scene, (0, 0, 0), (0.55 * u, 0.9 * u, 1.9 * u), M_METAL, GEAR)
        gb.box(scene, (0, 0.5 * u, 0), (0.6 * u, 0.12 * u, 2.0 * u), M_METAL, (0.25, 0.25, 0.27))
        anchors.append(gb.p((side * 0.2 * u, 0.1 * u, -0.9 * u)))
    tank = body.child(np.eye(3), (0, 0.3 * u, 0.75 * u))
    add_cylinder(scene, tank.p((-0.55 * u, 0, 0)), tank.p((0.55 * u, 0, 0)), 0.35 * u * s, M_METAL, (0.55, 0.57, 0.6), n=12)
    return anchors, blade_tips


def add_house(scene, pos, w, d, h, yaw=0.0, wall=(0.86, 0.79, 0.66), roof=(0.55, 0.24, 0.15), chimney=True, rng=None):
    R = rot_y(yaw)
    f = Frame(R, pos)
    add_box(scene, f.p((0, h / 2, 0)), (w, h, d), M_PLASTER, wall, R=R, seg=1.2)
    # basamento in pietra
    add_box(scene, f.p((0, 0.5, 0)), (w + 0.2, 1.0, d + 0.2), M_STONE, (0.55, 0.52, 0.47), R=R, seg=1.2)
    rh = w * 0.42
    ang = math.atan2(rh, w / 2)
    slope = math.hypot(w / 2, rh) + 0.5
    for side in (1, -1):
        Rr = R @ rot_z(-side * ang)
        c = f.p((side * w / 4, h + rh / 2, 0))
        add_box(scene, c, (slope, 0.25, d + 0.8), M_ROOF, roof, R=Rr, seg=1.0)
    # timpani
    for zs in (1, -1):
        a = f.p((-w / 2, h, zs * d / 2))
        b = f.p((w / 2, h, zs * d / 2))
        c = f.p((0, h + rh, zs * d / 2))
        scene.add(np.array([a, b, c]), np.array([[0, 1, 2]]), M_PLASTER, wall, smooth=False)
    if chimney:
        add_box(scene, f.p((w * 0.22, h + rh * 0.8, d * 0.2)), (0.9, rh * 1.2, 0.9), M_STONE, (0.5, 0.45, 0.42), R=R, seg=0.8)
    return f.p((w * 0.22, h + rh * 1.45, d * 0.2))


def add_wall(scene, a, b, height, thick=9.0, color=(0.72, 0.68, 0.60), seg=3.0):
    """Muro dritto da a a b (a terra)."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    d = b - a
    L = float(np.linalg.norm(d[[0, 2]]))
    yaw = math.atan2(d[0], d[2])
    R = rot_y(yaw)
    c = (a + b) / 2 + np.array([0, height / 2, 0])
    add_box(scene, c, (thick, height, L), M_STONE, color, R=R, seg=seg)
    # cornicione e camminamento
    add_box(scene, c + np.array([0, height / 2 + 0.6, 0]), (thick + 1.2, 1.2, L), M_STONE, tuple(np.array(color) * 0.9), R=R, seg=seg)
    # merli
    n = int(L / 4)
    for i in range(n):
        t = (i + 0.5) / n
        p = a + d * t + np.array([0, height + 1.9, 0])
        for side in (1, -1):
            off = R @ np.array([side * (thick / 2 + 0.2), 0, 0])
            add_box(scene, p + off, (0.8, 1.6, 1.8), M_STONE, tuple(np.array(color) * 0.85), R=R, seg=2)


def add_tower(scene, pos, r, h, color=(0.70, 0.66, 0.58), roof=(0.30, 0.32, 0.38)):
    pos = np.asarray(pos, float)
    add_cylinder(scene, pos, pos + np.array([0, h, 0]), r, M_STONE, color, n=20)
    add_cylinder(scene, pos + np.array([0, h, 0]), pos + np.array([0, h + 1.5, 0]), r + 1.0, M_STONE, tuple(np.array(color) * 0.9), n=20)
    # tetto conico
    n = 20
    ang = np.linspace(0, 2 * math.pi, n, endpoint=False)
    base = pos + np.array([0, h + 1.5, 0])
    ring = base + np.stack([np.cos(ang) * (r + 1.2), np.zeros(n), np.sin(ang) * (r + 1.2)], -1)
    apex = base + np.array([0, r * 1.8, 0])
    V = np.concatenate([ring, [apex]])
    F = np.array([(i, (i + 1) % n, n) for i in range(n)])
    scene.add(V, F, M_ROOF, roof, smooth=False)


def add_rubble(scene, center, radius, count, rng, color=(0.6, 0.56, 0.5)):
    for _ in range(count):
        p = np.asarray(center) + np.array([rng.uniform(-radius, radius), 0, rng.uniform(-radius, radius)])
        sz = rng.uniform(0.4, 1.8)
        R = rot_y(rng.uniform(0, 6.3)) @ rot_x(rng.uniform(-0.6, 0.6))
        add_box(scene, p + np.array([0, sz * 0.3, 0]), (sz * rng.uniform(0.8, 1.6), sz * 0.7, sz), M_STONE, color, R=R, seg=2)


def add_tree(scene, pos, h, rng, leaf=(0.16, 0.26, 0.10)):
    pos = np.asarray(pos, float)
    add_cylinder(scene, pos, pos + np.array([0, h * 0.5, 0]), h * 0.035, M_WOOD, (0.30, 0.20, 0.12), n=8)
    for k in range(5):
        c = pos + np.array([rng.uniform(-1, 1) * h * 0.12, h * (0.5 + 0.1 * k), rng.uniform(-1, 1) * h * 0.12])
        add_sphere(scene, c, h * (0.26 - 0.03 * k), M_COLOR, tuple(np.array(leaf) * rng.uniform(0.8, 1.2)), n=8)


def add_vial(scene, pos, h=0.3, color=(0.4, 2.6, 1.0)):
    """Fiala di siero luminosa."""
    pos = np.asarray(pos, float)
    add_cylinder(scene, pos, pos + np.array([0, h, 0]), h * 0.18, M_GLOW, color, n=16)
    add_cylinder(scene, pos + np.array([0, h, 0]), pos + np.array([0, h * 1.25, 0]), h * 0.12, M_METAL, (0.7, 0.55, 0.25), n=12)
