"""Fox: orange fox with white chest, black socks and a big bushy tail."""

from studvox import Model
from studvox.kit import face, idle_breathe, walk_quad, wave_chain


def build() -> Model:
    m = Model("fox", title="Fox Kit", category="critters",
              description="Bushy-tailed fox pet with tail swish idle, trot and leap clips.")
    body = m.part("body", pivot=(0, 4, 0))
    body.ellipsoid((0, 4.5, -1), (2.9, 2.4, 4.6), "dark_orange")
    body.paint_where(lambda x, y, z: (y <= 4) & (z >= 1) & (abs(x) <= 1), "white")

    head = m.part("head", parent="body", pivot=(0, 6, 3))
    head.ellipsoid((0, 8.5, 3), (3.4, 2.7, 2.7), "dark_orange")
    head.box((-1, 6, 5), (1, 8, 8), "white")                                               # snout
    head.box((-1, 8, 6), (1, 8, 8), "dark_orange")
    head.voxel((0, 8, 9), "black")
    head.box((-3, 11, 2), (-2, 12, 3), "dark_orange")                                     # ears
    head.voxel((-3, 13, 2), "black")
    head.symmetrize("x")
    head.paint_where(lambda x, y, z: (abs(x) >= 2) & (y <= 8) & (z >= 3), "white")        # cheeks
    face(head, [".B...B."], y=9)

    for name, x, z in (("leg_fl", 2, 2), ("leg_bl", 2, -4)):
        leg = m.part(name, parent="body", pivot=(x, 3, z))
        leg.box((x - 1, 0, z - 1), (x, 2, z), "black")
        m.mirror_part(name, name[:-1] + "r")

    tail1 = m.part("tail1", parent="body", pivot=(0, 5, -5))
    tail1.ellipsoid((0, 6, -7), (1.6, 1.6, 2.2), "dark_orange")
    tail2 = m.part("tail2", parent="tail1", pivot=(0, 6.5, -9))
    tail2.ellipsoid((0, 7.5, -10.5), (1.8, 1.8, 2.2), "dark_orange")
    tail2.paint_where(lambda x, y, z: z <= -11, "white")

    idle = idle_breathe(m)
    wave_chain(idle, ["tail1", "tail2"], rot=(0, 16, 0), period=1.0)
    walk = walk_quad(m, tail=None, swing=30)
    wave_chain(walk, ["tail1", "tail2"], rot=(6, 10, 0), period=0.7)
    leap = m.clip("leap", 1.1, loop=False)
    leap.keys("body", [(0, {}), (0.3, {"pos": (0, -1, 0), "rot": (-12, 0, 0)}),
                       (0.65, {"pos": (0, 5, 4), "rot": (15, 0, 0), "ease": "out"}), (1.1, {"pos": (0, 0, 6), "ease": "in"})])
    leap.keys("tail1", [(0, {}), (0.3, {"rot": (-20, 0, 0)}), (0.65, {"rot": (25, 0, 0)}), (1.1, {})])
    for leg, r in (("leg_fl", -45), ("leg_fr", -45), ("leg_bl", 40), ("leg_br", 40)):
        leap.keys(leg, [(0, {}), (0.3, {}), (0.65, {"rot": (r, 0, 0)}), (1.1, {})])
    return m
