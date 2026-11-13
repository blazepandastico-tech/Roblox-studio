"""Slime: wobbly see-through jelly blob with a shiny core and a happy face."""

from studvox import Model
from studvox.kit import face


def build() -> Model:
    m = Model("slime", title="Jelly Slime", category="critters",
              description="Bouncy jelly slime pet with wobble idle, squash hop and splat clips.")
    m.add_color("jelly", "#5EE07A", "plastic")
    m.add_color("jelly_dark", "#2FB457", "plastic")
    body = m.part("body", pivot=(0, 0, 0))
    body.ellipsoid((0, 4, 0), (5.2, 4.4, 4.8), "jelly")
    body.carve(body.coords()[body.coords()[:, 1] < 1])
    body.box((-5, 1, -4), (5, 1, 4), "jelly")
    body.carve(body.coords()[(abs(body.coords()[:, 0]) + abs(body.coords()[:, 2]) > 8) & (body.coords()[:, 1] == 1)])
    body.paint_where(lambda x, y, z: y <= 1, "jelly_dark")
    body.voxels([(-3, 7, 3), (-2, 8, 2), (-3, 8, 2)], "white")                             # shine
    face(body, [".BB.....BB.", ".BB.....BB."], y=6)
    body.decal(["P.........P", "....KKK...."], at=(-5, 4, 0), colors={"P": "pink", "K": "black"})
    crown = m.part("drip", parent="body", pivot=(0, 8, 0))
    crown.voxels([(0, 9, 0), (0, 10, 0), (1, 9, 0)], "jelly")

    idle = m.clip("idle", 1.6)
    idle.osc("body", pos=(0, 0.25, 0), period=0.8)
    idle.osc("body", rot=(0, 0, 4), period=1.6)
    idle.osc("drip", rot=(0, 0, 20), period=0.8, phase=0.2)
    walk = m.clip("walk", 0.7)
    walk.osc("body", pos=(0, 3, 0), period=0.7, wave="bounce")
    walk.osc("body", rot=(8, 0, 0), period=0.7)
    walk.osc("drip", rot=(-25, 0, 0), period=0.7, phase=0.15)
    splat = m.clip("splat", 1.0, loop=False)
    splat.keys("body", [(0, {}), (0.3, {"pos": (0, 6, 0), "ease": "out"}), (0.5, {"pos": (0, -1.5, 0), "ease": "in"}),
                        (0.7, {"pos": (0, 0.6, 0)}), (1.0, {})])
    return m
