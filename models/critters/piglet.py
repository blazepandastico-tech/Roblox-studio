"""Piglet: pink pig with a round snout, floppy ears and a curly tail."""

from studvox import Model
from studvox.kit import face, idle_breathe, walk_quad


def build() -> Model:
    m = Model("piglet", title="Piglet", category="critters",
              description="Pink piglet pet with snout-wiggle idle, trot and happy roll clips.")
    body = m.part("body", pivot=(0, 4, 0))
    body.ellipsoid((0, 4.5, -0.5), (3.8, 3.2, 4.6), "pink")
    body.paint_where(lambda x, y, z: (y <= 2), "blush")

    head = m.part("head", parent="body", pivot=(0, 6, 3))
    head.ellipsoid((0, 8, 3.5), (3.5, 3, 2.8), "pink")
    head.box((-2, 6, 6), (2, 8, 7), "hot_pink")                                            # snout
    head.voxels([(-1, 7, 7), (1, 7, 7)], "magenta", stud=False)
    face(head, [".B...B."], y=10)
    ear_l = m.part("ear_l", parent="head", pivot=(-2.5, 10.5, 3))
    ear_l.box((-4, 10, 2), (-2, 11, 4), "hot_pink")
    ear_l.voxel((-4, 9, 4), "hot_pink")
    m.mirror_part("ear_l", "ear_r")

    for name, x, z in (("leg_fl", 2, 2), ("leg_bl", 2, -3)):
        leg = m.part(name, parent="body", pivot=(x, 2, z))
        leg.box((x - 1, 0, z - 1), (x, 1, z), "pink")
        leg.box((x - 1, 0, z), (x, 0, z), "dark_brown", stud=False)
        m.mirror_part(name, name[:-1] + "r")

    tail = m.part("tail", parent="body", pivot=(0, 5, -5))
    tail.voxels([(0, 5, -5), (0, 5, -6), (0, 6, -6), (1, 6, -6), (1, 7, -6), (0, 7, -6)], "hot_pink")

    idle = idle_breathe(m, extra=[("ear_l", (0, 0, -10), 0.0), ("ear_r", (0, 0, 10), 0.0)])
    idle.osc("tail", rot=(0, 0, 40), period=0.5)
    walk_quad(m, tail="tail", swing=32)
    roll = m.clip("roll", 1.4, loop=False)
    roll.keys("body", [(0, {}), (0.2, {"pos": (0, 1, 0)}), (0.9, {"pos": (0, 1, 0), "rot": (0, 0, 360)}),
                       (1.4, {"rot": (0, 0, 360)})])
    return m
