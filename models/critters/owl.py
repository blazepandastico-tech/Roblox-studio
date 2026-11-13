"""Owl: round brown owl with huge eyes and ear tufts."""

from studvox import Model
from studvox.kit import flap


def build() -> Model:
    m = Model("owl", title="Owlet", category="critters",
              description="Wide-eyed owlet pet with head-turn idle, hop and wing flap clips.")
    body = m.part("body", pivot=(0, 3, 0))
    body.ellipsoid((0, 5, 0), (3.6, 4.4, 3.2), "brown")
    body.paint_where(lambda x, y, z: (z >= 1) & (abs(x) <= 2) & (y <= 6), "tan")
    body.paint_where(lambda x, y, z: (z >= 2) & (abs(x) <= 1) & (y <= 5) & ((x + y) % 2 == 0), "light_brown")
    body.box((-2, 0, 1), (-1, 0, 2), "orange")
    body.box((1, 0, 1), (2, 0, 2), "orange")

    head = m.part("head", parent="body", pivot=(0, 8, 0))
    head.ellipsoid((0, 10.5, 0.5), (3.8, 2.9, 3), "brown")
    head.box((-3, 13, 0), (-3, 14, 1), "dark_brown")
    head.box((3, 13, 0), (3, 14, 1), "dark_brown")
    head.decal(["YYY.YYY", "YBY.YBY", "YYY.YYY"], at=(-3, 12, 0), colors={"Y": "yellow", "B": "black"})
    head.emboss(["O"], at=(0, 10, 0), colors={"O": "orange"})

    wing_l = m.part("wing_l", parent="body", pivot=(-3.5, 7, 0))
    wing_l.ellipsoid((-4, 4.5, -0.5), (0.6, 2.6, 2.2), "dark_brown")
    m.mirror_part("wing_l", "wing_r")

    idle = m.clip("idle", 3.0)
    idle.keys("head", [(0, {}), (0.6, {"rot": (0, 70, 0)}), (1.4, {"rot": (0, 70, 0)}), (1.9, {"rot": (0, -20, 0)}),
                       (2.4, {}), (3.0, {})])
    idle.osc("body", pos=(0, 0.15, 0), period=1.5)
    walk = m.clip("walk", 0.6)
    walk.osc("body", pos=(0, 1.5, 0), period=0.6, wave="bounce")
    walk.osc("body", rot=(0, 0, 6), period=0.6)
    fl = m.clip("flap", 1.2, loop=False)
    flap(fl, "wing_l", "wing_r", amp=-60, period=0.3)
    fl.keys("body", [(0, {}), (0.4, {"pos": (0, 3, 0)}), (0.9, {"pos": (0, 3, 0)}), (1.2, {})])
    return m
