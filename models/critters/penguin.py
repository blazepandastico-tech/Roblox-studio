"""Penguin: tuxedo penguin with flippers and orange feet."""

from studvox import Model
from studvox.kit import face, flap


def build() -> Model:
    m = Model("penguin", title="Penguin", category="critters",
              description="Tuxedo penguin pet with waddle walk and flipper-flap slide clips.")
    body = m.part("body", pivot=(0, 2, 0))
    body.ellipsoid((0, 6, 0), (3.6, 5.6, 3.3), "navy")
    body.paint_where(lambda x, y, z: (z >= 1) & (abs(x) <= 2) & (y <= 9), "white")       # tummy
    face(body, ".WB...WB.", y=9)
    body.emboss(["OOO"], at=(-1, 8, 0), colors={"O": "orange"})                           # beak
    body.decal(["P.......P"], at=(-4, 8, 0), colors={"P": "blush"})
    body.box((-1, 12, 0), (1, 12, 1), "navy")

    fl = m.part("flipper_l", parent="body", pivot=(-3.5, 8, 0))
    fl.box((-5, 4, -1), (-4, 8, 1), "navy")
    fl.voxel((-5, 3, 0), "navy")
    m.mirror_part("flipper_l", "flipper_r")

    foot_l = m.part("foot_l", parent="body", pivot=(-1.5, 1, 0))
    foot_l.box((-3, 0, 0), (-1, 0, 3), "orange")
    m.mirror_part("foot_l", "foot_r")

    idle = m.clip("idle", 2.0)
    idle.osc("body", rot=(0, 0, 3), period=2.0)
    idle.osc("flipper_l", rot=(0, 0, -6), period=1.0)
    idle.osc("flipper_r", rot=(0, 0, 6), period=1.0)

    walk = m.clip("walk", 0.7)
    walk.osc("body", rot=(0, 0, 10), period=0.7)
    walk.osc("body", pos=(0, 0.4, 0), period=0.35, wave="bounce")
    walk.osc("foot_l", pos=(0, 0.5, 0), period=0.7, wave="sin")
    walk.osc("foot_r", pos=(0, -0.5, 0), period=0.7, wave="sin")
    walk.osc("flipper_l", rot=(0, 0, -12), period=0.7)
    walk.osc("flipper_r", rot=(0, 0, -12), period=0.7)

    slide = m.clip("slide", 1.4, loop=False)
    slide.keys("body", [(0, {}), (0.3, {"rot": (70, 0, 0), "pos": (0, -1, 2)}), (1.0, {"rot": (70, 0, 0), "pos": (0, -1, 8)}),
                        (1.4, {})])
    flap(slide, "flipper_l", "flipper_r", amp=-40, period=0.35)
    return m
