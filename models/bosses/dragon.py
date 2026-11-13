"""Dragon boss: red winged dragon with horns, belly plates, spiked tail and a roar."""

import math

from studvox import Model
from studvox.kit import walk_quad, wave_chain


def wing(m, name, side):
    w = m.part(name, parent="body", pivot=(side * 5, 15, 1))
    for i in range(0, 16):
        x = side * (6 + i)
        top = 15 + i * 0.9
        bottom = 11 + i * 0.75 + 2.2 * abs(math.sin(i / 15 * math.pi * 2.5))
        for y in range(int(round(bottom)), int(round(top)) + 1):
            w.voxel((x, y, 0), "dark_red")
        w.voxel((x, int(round(top)) + 1, 0), "red")
    w.line((side * 5, 16, 0), (side * 21, 29, -1), "red", radius=0.7)
    w.voxel((side * 22, 30, -1), "cream")
    for k in (9, 14, 18):
        w.line((side * 6, 16, 0), (side * k, 11 + (k - 6) * 0.75, 0), "red")
    return w


def build() -> Model:
    m = Model("dragon", title="Ember Dragon", category="bosses",
              description="Winged fire dragon boss: breathing idle, stomping walk and a jaw-snapping roar.")
    body = m.part("body", pivot=(0, 10, 0))
    body.ellipsoid((0, 10, 0), (6, 5.5, 9), "red")
    body.paint_where(lambda x, y, z: (y <= 7) & (abs(x) <= 3), "tan")
    body.paint_where(lambda x, y, z: (y <= 7) & (abs(x) <= 3) & (z % 2 == 0), "sand")
    for z in range(-7, 8, 3):
        body.voxels([(0, 16, z), (0, 17, z)], "cream")

    neck = m.part("neck", parent="body", pivot=(0, 13, 7))
    neck.tube([(0, 12, 7), (0, 17, 11), (0, 21, 13)], [3.4, 2.9, 2.6], "red")
    neck.paint_where(lambda x, y, z: (z >= 10) & (abs(x) <= 1) & (y <= 19), "tan")
    for y, z in ((18, 9), (21, 11)):
        neck.voxel((0, y + 2, z - 1), "cream")

    head = m.part("head", parent="neck", pivot=(0, 21, 13))
    head.ellipsoid((0, 24, 15), (3.8, 3.2, 4.2), "red")
    head.box((-2, 22, 17), (2, 25, 22), "red")                                             # snout
    head.voxels([(-1, 25, 22), (1, 25, 22)], "black", stud=False)                         # nostrils
    head.voxels([(-3, 25, 18), (3, 25, 18)], "neon_yellow")                               # eyes
    head.voxels([(-3, 26, 18), (3, 26, 18), (-2, 26, 19), (2, 26, 19)], "dark_red")       # brows
    for s_ in (-1, 1):
        head.line((s_ * 2, 26, 13), (s_ * 3, 30, 9), "cream", radius=0.6)
        head.voxel((s_ * 3, 31, 8), "white")
    head.voxels([(x, 21, 21) for x in (-2, 0, 2)], "white", stud=False)                   # teeth

    jaw = m.part("jaw", parent="head", pivot=(0, 21.5, 15))
    jaw.box((-2, 20, 15), (2, 21, 21), "red")
    jaw.box((-1, 20, 17), (1, 20, 21), "tan")
    jaw.voxels([(-2, 22, 21), (2, 22, 21)], "white", stud=False)

    wing(m, "wing_l", -1)
    wing(m, "wing_r", 1)

    for name, x, z in (("leg_fl", 5, 5), ("leg_bl", 5, -5)):
        leg = m.part(name, parent="body", pivot=(x, 8, z))
        leg.ellipsoid((x, 6.5, z), (2.2, 3, 2.5), "red")
        leg.box((x - 1, 0, z - 1), (x + 1, 4, z + 1), "red")
        leg.box((x - 1, 0, z + 2), (x + 1, 0, z + 2), "cream", stud=False)
        m.mirror_part(name, name[:-1] + "r")

    pts = [(0, 9, -8), (0, 8, -13), (0, 6, -18), (0, 5, -23), (0, 5, -27)]
    rad = [3.4, 2.5, 1.8, 1.2, 0.8]
    prev = "body"
    for i in range(4):
        t = m.part(f"tail{i + 1}", parent=prev, pivot=pts[i])
        t.tube([pts[i], pts[i + 1]], [rad[i], rad[i + 1]], "red")
        t.voxel((0, int(pts[i][1] + rad[i]) + 1, int((pts[i][2] + pts[i + 1][2]) / 2)), "cream")
        prev = t.name
    m.parts["tail4"].box((-1, 4, -30), (1, 6, -28), "cream")

    idle = m.clip("idle", 3.0)
    idle.osc("body", pos=(0, 0.4, 0), period=1.5)
    idle.osc("neck", rot=(4, 0, 0), period=3.0)
    idle.osc("head", rot=(-4, 6, 0), period=3.0, phase=0.2)
    idle.osc("wing_l", rot=(0, 10, -8), period=1.5)
    idle.osc("wing_r", rot=(0, -10, 8), period=1.5)
    wave_chain(idle, ["tail1", "tail2", "tail3", "tail4"], rot=(0, 10, 0), period=3.0)

    walk = walk_quad(m, head="neck", length=1.2, swing=22, bob=0.6)
    wave_chain(walk, ["tail1", "tail2", "tail3", "tail4"], rot=(0, 12, 0), period=1.2)
    walk.osc("wing_l", rot=(0, 0, -6), period=0.6)
    walk.osc("wing_r", rot=(0, 0, 6), period=0.6)

    roar = m.clip("roar", 2.0, loop=False)
    roar.keys("neck", [(0, {}), (0.5, {"rot": (25, 0, 0)}), (0.9, {"rot": (-30, 0, 0), "ease": "back"}),
                       (1.6, {"rot": (-30, 0, 0)}), (2.0, {})])
    roar.keys("head", [(0, {}), (0.5, {"rot": (15, 0, 0)}), (0.9, {"rot": (-15, 0, 0)}), (1.6, {"rot": (-10, 0, 0)}),
                       (2.0, {})])
    roar.keys("jaw", [(0, {}), (0.7, {}), (0.9, {"rot": (40, 0, 0)}), (1.6, {"rot": (40, 0, 0)}), (2.0, {})])
    roar.keys("wing_l", [(0, {}), (0.9, {"rot": (0, 0, 35)}), (1.6, {"rot": (0, 0, 30)}), (2.0, {})])
    roar.keys("wing_r", [(0, {}), (0.9, {"rot": (0, 0, -35)}), (1.6, {"rot": (0, 0, -30)}), (2.0, {})])
    roar.keys("body", [(0, {}), (0.9, {"rot": (-8, 0, 0), "pos": (0, 1, 0)}), (1.6, {"rot": (-8, 0, 0)}), (2.0, {})])
    return m
