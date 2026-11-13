"""Bunny: white rabbit with tall ears, pink nose and a pom-pom tail."""

from studvox import Model
from studvox.kit import face, hop


def build() -> Model:
    m = Model("bunny", title="Bunny", category="critters",
              description="Snow-white bunny pet with ear-twitch idle, hop and happy spin clips.")
    body = m.part("body", pivot=(0, 3, 0))
    body.ellipsoid((0, 4, -0.5), (3.4, 3.1, 3.8), "white")
    body.sphere((0, 4, -4.5), 1.4, "light_gray")                                          # pom-pom tail
    body.box((-3, 0, 1), (-2, 1, 3), "white")                                             # front paws
    body.box((2, 0, 1), (3, 1, 3), "white")
    body.box((-4, 0, -3), (-2, 1, -1), "white")                                           # back feet
    body.box((2, 0, -3), (4, 1, -1), "white")

    head = m.part("head", parent="body", pivot=(0, 6.5, 1))
    head.ellipsoid((0, 9, 1.5), (3.4, 3, 3), "white")
    face(head, ".B.....B.", y=10)
    head.decal(["P.....P", "...P..."], at=(-3, 9, 0), colors={"P": "pink"})

    ear_l = m.part("ear_l", parent="head", pivot=(-1.5, 11.5, 1))
    ear_l.box((-2, 12, 0), (-1, 17, 1), "white")
    ear_l.box((-2, 13, 2), (-1, 16, 2), "pink", stud=False)
    ear_l.voxel((-2, 18, 0), "white")
    m.mirror_part("ear_l", "ear_r", center=0.0)

    c = m.clip("idle", 2.0)
    c.osc("body", pos=(0, 0.2, 0), period=1.0)
    c.keys("ear_l", [(0, {}), (0.6, {}), (0.7, {"rot": (0, 0, 18)}), (0.8, {}), (2.0, {})])
    c.keys("ear_r", [(0, {}), (1.3, {}), (1.4, {"rot": (0, 0, -18)}), (1.5, {}), (2.0, {})])
    c.osc("head", rot=(3, 4, 0), period=2.0)
    hop(m, name="walk", length=0.6, height=2.2, parts=[("ear_l", (12, 0, 0)), ("ear_r", (12, 0, 0))])
    spin = m.clip("happy", 1.2, loop=False)
    spin.keys("body", [(0, {}), (0.2, {"pos": (0, -0.6, 0)}), (0.7, {"pos": (0, 4, 0), "rot": (0, 360, 0), "ease": "out"}),
                       (1.0, {"pos": (0, 0, 0), "rot": (0, 360, 0), "ease": "in"}), (1.2, {"rot": (0, 360, 0)})])
    spin.keys("ear_l", [(0, {}), (0.5, {"rot": (0, 0, 25)}), (1.2, {})])
    spin.keys("ear_r", [(0, {}), (0.5, {"rot": (0, 0, -25)}), (1.2, {})])
    return m
