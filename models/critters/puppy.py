"""Puppy: brown and cream pup with floppy ears and a wagging tail."""

from studvox import Model
from studvox.kit import face, idle_breathe, walk_quad


def build() -> Model:
    m = Model("puppy", title="Puppy", category="critters",
              description="Floppy-eared puppy pet with tail wag idle, trot and bark clips.")
    body = m.part("body", pivot=(0, 4, 0))
    body.ellipsoid((0, 4, -1), (3.3, 2.7, 4.4), "light_brown")
    body.paint_where(lambda x, y, z: (y <= 3) & (z >= -1) & (abs(x) <= 2), "cream")
    body.ellipsoid((1, 6, -2), (1.8, 1, 1.6), "dark_brown")                              # back patch

    head = m.part("head", parent="body", pivot=(0, 6, 2))
    head.ellipsoid((0, 9, 2), (3.6, 3.2, 3.2), "light_brown")
    head.box((-2, 6, 4), (2, 8, 6), "cream")                                              # snout
    head.box((-1, 8, 6), (1, 8, 6), "black")                                              # nose
    head.decal(["W....", ".W..."], at=(-2, 11, 0), colors={"W": "cream"})
    face(head, "cute", y=10)
    head.decal(["P"], at=(0, 6, 0), colors={"P": "pink"})                                 # tongue tip

    ear_l = m.part("ear_l", parent="head", pivot=(-3.5, 11, 2))
    ear_l.box((-5, 7, 1), (-4, 11, 3), "dark_brown")
    m.mirror_part("ear_l", "ear_r")

    for name, x, z in (("leg_fl", 2, 2), ("leg_bl", 2, -4)):
        leg = m.part(name, parent="body", pivot=(x, 2.5, z))
        leg.box((x - 1, 1, z - 1), (x, 2, z), "light_brown")
        leg.box((x - 1, 0, z - 1), (x, 0, z + (1 if z > 0 else 0)), "cream")
        m.mirror_part(name, name[:-1] + "r")

    tail = m.part("tail", parent="body", pivot=(0, 6, -5))
    tail.tube([(0, 6, -5), (0, 8, -6), (0, 10, -6)], [0.7, 0.7, 0.6], "light_brown")
    tail.voxel((0, 11, -6), "cream")

    c = idle_breathe(m, extra=[("ear_l", (0, 0, -8), 0.0), ("ear_r", (0, 0, 8), 0.0)])
    c.osc("tail", rot=(0, 0, 30), period=0.5)
    walk_quad(m, tail="tail")
    bark = m.clip("bark", 1.0, loop=False)
    bark.keys("head", [(0, {}), (0.15, {"rot": (-20, 0, 0)}), (0.3, {"rot": (8, 0, 0)}),
                       (0.45, {"rot": (-20, 0, 0)}), (0.6, {"rot": (8, 0, 0)}), (1.0, {})])
    bark.keys("body", [(0, {}), (0.15, {"pos": (0, 0.8, 0)}), (0.3, {}), (0.45, {"pos": (0, 0.8, 0)}), (0.6, {}),
                       (1.0, {})])
    bark.keys("ear_l", [(0, {}), (0.15, {"rot": (0, 0, -30)}), (0.6, {"rot": (0, 0, -10)}), (1.0, {})])
    bark.keys("ear_r", [(0, {}), (0.15, {"rot": (0, 0, 30)}), (0.6, {"rot": (0, 0, 10)}), (1.0, {})])
    return m
