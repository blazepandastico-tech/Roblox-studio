"""Bee: fuzzy bumblebee with buzzing wings and a little stinger."""

from studvox import Model
from studvox.kit import face, flap


def build() -> Model:
    m = Model("bee", title="Bumble Bee", category="critters",
              description="Fuzzy flying bumblebee pet with buzzing hover, flight and sting clips.")
    body = m.part("body", pivot=(0, 6, 0))
    body.ellipsoid((0, 6, -1), (3.6, 3.4, 4.6), "yellow")
    body.paint_where(lambda x, y, z: ((z + 10) % 3 == 0) & (z <= 1), "black")
    body.voxels([(0, 6, -6), (0, 5, -7)], "charcoal")                                     # stinger
    face(body, [".WB...WB.", ".BB...BB."], y=8, )
    body.decal(["P.......P", "...KKK..."], at=(-4, 6, 0), colors={"P": "pink", "K": "black"})
    body.line((-1, 10, 2), (-2, 12, 3), "black")
    body.line((1, 10, 2), (2, 12, 3), "black")
    body.voxels([(-2, 13, 3), (2, 13, 3)], "black")

    wing_l = m.part("wing_l", parent="body", pivot=(-1.5, 9, -1))
    wing_l.ellipsoid((-3.5, 11, -1.5), (2.2, 0.5, 1.8), "glass")
    m.mirror_part("wing_l", "wing_r")
    legs = m.part("legs", parent="body", pivot=(0, 3, 0))
    for x in (-2, 2):
        for z in (1, -2):
            legs.box((x, 2, z), (x, 2, z), "black", stud=False)

    idle = m.clip("idle", 1.2)
    idle.osc("body", pos=(0, 0.6, 0), period=1.2)
    flap(idle, "wing_l", "wing_r", amp=35, period=0.1)
    fly = m.clip("walk", 0.8)
    fly.osc("body", pos=(0, 0.8, 0), period=0.4)
    fly.osc("body", rot=(12, 0, 5), period=0.8)
    flap(fly, "wing_l", "wing_r", amp=40, period=0.1)
    sting = m.clip("sting", 1.0, loop=False)
    sting.keys("body", [(0, {}), (0.35, {"pos": (0, 1, -1), "rot": (-30, 0, 0)}), (0.5, {"pos": (0, -1, 3), "rot": (40, 0, 0)}),
                        (1.0, {})])
    flap(sting, "wing_l", "wing_r", amp=40, period=0.1)
    return m
