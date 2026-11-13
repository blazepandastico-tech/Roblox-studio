"""Turtle: little tortoise with a studded green shell and a peeking head."""

from studvox import Model
from studvox.kit import face, walk_quad


def build() -> Model:
    m = Model("turtle", title="Turtle", category="critters",
              description="Shell-patterned turtle pet with peek idle, slow crawl and hide-in-shell clips.")
    shell = m.part("body", pivot=(0, 3, 0))
    shell.ellipsoid((0, 3, 0), (4.6, 3.4, 5), "green")
    shell.carve(shell.coords()[shell.coords()[:, 1] < 2])
    shell.box((-4, 1, -4), (4, 1, 4), "light_brown")
    shell.carve(shell.coords()[(abs(shell.coords()[:, 0]) == 4) & (abs(shell.coords()[:, 2]) == 4)])
    shell.paint_where(lambda x, y, z: ((x + 10) % 3 == 0) & ((z + 10) % 3 == 0) & (y >= 4), "dark_green")
    shell.paint_where(lambda x, y, z: y == 2, "olive")

    head = m.part("head", parent="body", pivot=(0, 3, 4))
    head.ellipsoid((0, 4, 6.5), (1.8, 1.6, 1.8), "lime")
    face(head, ["B.B"], y=5)
    head.decal(["P...P"], at=(-2, 4, 0), colors={"P": "blush"})

    for name, x, z in (("leg_fl", 3, 3), ("leg_bl", 3, -3)):
        leg = m.part(name, parent="body", pivot=(x, 1.5, z))
        leg.box((x, 0, z - 1), (x + 1, 1, z), "lime")
        m.mirror_part(name, name[:-1] + "r")
    tail = m.part("tail", parent="body", pivot=(0, 1.5, -5))
    tail.voxels([(0, 1, -5), (0, 1, -6)], "lime")

    idle = m.clip("idle", 3.0)
    idle.keys("head", [(0, {}), (0.8, {"rot": (0, 25, 0)}), (1.6, {"rot": (0, -25, 0)}), (2.4, {}), (3.0, {})])
    idle.osc("tail", rot=(0, 25, 0), period=1.0)
    walk_quad(m, length=1.2, swing=24, bob=0.15, tail="tail")
    hide = m.clip("hide", 1.6, loop=False)
    hide.keys("head", [(0, {}), (0.3, {"pos": (0, 0, -3.5)}), (1.2, {"pos": (0, 0, -3.5)}), (1.6, {})])
    for leg, d in (("leg_fl", (-1, 0, 0)), ("leg_fr", (1, 0, 0)), ("leg_bl", (-1, 0, 0)), ("leg_br", (1, 0, 0))):
        hide.keys(leg, [(0, {}), (0.3, {"pos": (-1.5 * d[0] * -1 if False else -1.5 * d[0], 1, 0)}), (1.2, {"pos": (-1.5 * d[0], 1, 0)}),
                        (1.6, {})])
    hide.keys("body", [(0, {}), (0.3, {"pos": (0, -0.8, 0)}), (1.2, {"pos": (0, -0.8, 0)}), (1.6, {})])
    return m
