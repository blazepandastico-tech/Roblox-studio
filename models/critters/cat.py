"""Ginger kitten: round body, big head with pointy ears, curly tail."""

from studvox import Model
from studvox.kit import face, idle_breathe, walk_quad


def build() -> Model:
    m = Model("cat", title="Ginger Kitten", category="critters",
              description="Round ginger kitten pet with trot, tail flick and pounce clips.")
    body = m.part("body", pivot=(0, 4, 0))
    body.ellipsoid((0, 4, -1), (3.2, 2.5, 4.3), "orange")
    body.paint_where(lambda x, y, z: (y >= 5) & (z % 3 == 0), "dark_orange")            # back stripes
    body.paint_where(lambda x, y, z: (y <= 3) & (z >= 0) & (abs(x) <= 2), "cream")      # belly

    head = m.part("head", parent="body", pivot=(0, 6, 2))
    head.ellipsoid((0, 9, 2), (3.9, 3.1, 3.1), "orange")
    head.box((-3, 12, 1), (-2, 12, 3), "orange")
    head.voxels([(-3, 13, 2), (-3, 13, 1)], "orange")
    head.voxel((-2, 12, 3), "pink", stud=False)
    head.symmetrize("x")
    head.paint_where(lambda x, y, z: (y == 12) & (abs(x) <= 1), "dark_orange")         # forehead stripe
    head.emboss(["CCC", ".C."], at=(-1, 8, 0), colors={"C": "cream"})                   # muzzle
    head.decal(["P"], at=(0, 8, 0), colors={"P": "pink"})
    face(head, [".GB...GB.", ".BB...BB."], y=10, colors={"G": "lime"})

    for name, x, z in (("leg_fl", 2, 2), ("leg_bl", 2, -4)):
        leg = m.part(name, parent="body", pivot=(x, 2.5, z))
        leg.box((x - 1, 1, z - 1), (x, 2, z), "orange")
        leg.box((x - 1, 0, z - 1), (x, 0, z + (1 if z > 0 else 0)), "cream")
        m.mirror_part(name, name[:-1] + "r")

    tail = m.part("tail", parent="body", pivot=(0, 5, -5))
    tail.tube([(0, 5, -5), (0, 7, -7), (0, 10, -7), (1, 12, -6)], [0.7, 0.7, 0.7, 0.6], "orange")
    tail.paint_where(lambda x, y, z: y >= 11, "cream")

    idle_breathe(m, extra=[("tail", (0, 14, 0), 0.0)])
    walk_quad(m, tail="tail")
    pounce = m.clip("pounce", 1.2, loop=False)
    pounce.keys("body", [(0, {}), (0.35, {"pos": (0, -1.2, -0.8), "rot": (-10, 0, 0)}),
                         (0.6, {"pos": (0, 3.5, 3), "rot": (12, 0, 0), "ease": "out"}),
                         (0.85, {"pos": (0, 0, 4), "rot": (-4, 0, 0), "ease": "in"}), (1.2, {"pos": (0, 0, 0)})])
    for leg, r in (("leg_fl", -40), ("leg_fr", -40), ("leg_bl", 35), ("leg_br", 35)):
        pounce.keys(leg, [(0, {}), (0.35, {}), (0.6, {"rot": (r, 0, 0)}), (0.85, {}), (1.2, {})])
    pounce.keys("tail", [(0, {}), (0.35, {"rot": (-25, 0, 0)}), (0.6, {"rot": (30, 0, 0)}), (1.2, {})])
    return m
