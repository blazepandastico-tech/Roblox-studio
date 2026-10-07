"""Oggetti di scena: soldato con il dispositivo di manovra (stile avatar Roblox), case, mura, torri."""
import math

import numpy as np

from engine import (M_CLOTH, M_COLOR, M_GLOW, M_METAL, M_PLASTER, M_ROOF, M_SKIN, M_STONE, M_WOOD,
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


def add_soldier(scene, pos, yaw=0.0, pitch=0.0, roll=0.0, s=1.0, pose="fly", hair=(0.20, 0.13, 0.08), blades=True):
    """Avatar a blocchi (proporzioni Roblox R15) alto circa 1.9*s metri. Origine = anche.
    Restituisce le posizioni (mondo) delle due fondine del rampino, per attaccarci i cavi."""
    R = rot_y(yaw) @ rot_x(pitch) @ rot_z(roll)
    body = Frame(R * s, pos)
    u = 0.38  # unità avatar: 1 stud ≈ 0.38 m
    # gambe
    leg_rot = {"fly": (-0.45, -0.15), "dive": (-0.5, -0.15), "stand": (0, 0)}[pose]
    for side, a in ((1, leg_rot[0]), (-1, leg_rot[1])):
        hip = body.child(rot_x(a), (side * 0.5 * u, 0, 0))
        hip.box(scene, (0, -1.0 * u, 0), (0.95 * u, 2.0 * u, 0.95 * u), M_CLOTH, PANTS)
        hip.box(scene, (0, -1.75 * u, 0), (1.0 * u, 0.6 * u, 1.05 * u), M_CLOTH, BOOTS)
        hip.box(scene, (0, -0.45 * u, 0), (1.0 * u, 0.12 * u, 1.0 * u), M_CLOTH, STRAP)
    # busto (giacca corta) e cinghie
    body.box(scene, (0, 1.0 * u, 0), (2.0 * u, 2.0 * u, 1.0 * u), M_CLOTH, JACKET)
    body.box(scene, (0, 0.15 * u, 0), (2.02 * u, 0.3 * u, 1.02 * u), M_CLOTH, STRAP)
    for side in (1, -1):
        body.box(scene, (side * 0.45 * u, 1.0 * u, -0.52 * u), (0.14 * u, 2.0 * u, 0.06 * u), M_CLOTH, STRAP)
    # testa e capelli
    head = body.child(np.eye(3), (0, 2.6 * u, 0))
    add_sphere(scene, head.p((0, 0, 0)), 0.62 * u, M_SKIN, SKIN, n=12, scale=(1.0, 1.0, 1.0), R=head.R / s)
    hair_frame = head
    hair_frame.box(scene, (0, 0.38 * u, 0.08 * u), (1.32 * u, 0.5 * u, 1.3 * u), M_CLOTH, hair)
    hair_frame.box(scene, (0, 0.05 * u, 0.5 * u), (1.3 * u, 0.9 * u, 0.35 * u), M_CLOTH, hair)
    # braccia: in volo tese indietro con le lame
    arm_rot = {"fly": (-1.0, 0.3), "dive": (2.7, 0.3), "stand": (0.1, 0.1)}[pose]
    blade_tips = []
    for side in (1, -1):
        sh = body.child(rot_x(arm_rot[0]) @ rot_z(side * arm_rot[1]), (side * 1.5 * u, 1.8 * u, 0))
        sh.box(scene, (0, -0.95 * u, 0), (0.95 * u, 2.0 * u, 0.95 * u), M_CLOTH, JACKET)
        sh.box(scene, (0, -2.05 * u, 0), (0.9 * u, 0.35 * u, 0.9 * u), M_SKIN, SKIN)
        if blades:
            hand = sh.child(rot_z(side * 0.15), (0, -2.1 * u, 0))
            hand.box(scene, (0, -0.1 * u, 0), (0.55 * u, 0.35 * u, 0.7 * u), M_METAL, GEAR)
            hand.box(scene, (0, -2.6 * u, 0), (0.08 * u, 4.8 * u, 0.5 * u), M_METAL, STEEL, seg=0.4)
            blade_tips.append(hand.p((0, -5.0 * u, 0)))
    # mantello verde che sventola dietro
    cape = body.child(rot_x({"fly": -1.2, "dive": -1.35, "stand": -0.08}[pose]), (0, 1.95 * u, 0.55 * u))
    cape.box(scene, (0, -1.6 * u, 0.0), (2.3 * u, 3.2 * u, 0.08 * u), M_CLOTH, CAPE, seg=0.3)
    cape.box(scene, (0, -0.15 * u, 0.0), (2.4 * u, 0.3 * u, 0.12 * u), M_CLOTH, (0.10, 0.25, 0.17))
    # emblema (cerchio dorato con due ali stilizzate: originale del gioco)
    em = cape.child(np.eye(3), (0, -1.3 * u, 0.06 * u))
    add_cylinder(scene, em.p((0, 0, 0)), em.p((0, 0, 0.02 * u)), 0.45 * u * s, M_METAL, (0.85, 0.66, 0.22), n=16)
    # dispositivo di manovra: scatole del gas sui fianchi e bombola dietro
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
