"""Stone golem boss: hulking rock giant with moss, glowing runes and huge fists."""

from studvox import Model
from studvox.kit import walk_biped


def build() -> Model:
    m = Model("golem", title="Stone Golem", category="bosses",
              description="Mossy rock golem boss with rumbling idle, heavy walk and a ground pound.")
    body = m.part("body", pivot=(0, 12, 0))
    body.blob((0, 17, 0), (7, 6.5, 5), "stone", noise=0.15, seed=3)
    body.speckle({"stone": 0.6, "dark_stone": 0.3, "gray": 0.1}, seed=2)
    body.paint_top("moss", only=["stone", "dark_stone", "gray"])
    body.box((-1, 15, 5), (1, 18, 5), "neon_cyan", stud=False)
    body.voxels([(0, 19, 5), (-2, 16, 5), (2, 16, 5)], "neon_cyan", stud=False)
    head = m.part("head", parent="body", pivot=(0, 22, 1))
    head.blob((0, 24.5, 1.5), (3, 2.6, 2.6), "stone", noise=0.12, seed=8)
    head.speckle({"stone": 0.7, "dark_stone": 0.3}, seed=4)
    head.paint_top("moss")
    head.decal(["C...C"], at=(-2, 25, 0), colors={"C": "neon_cyan"})
    for side in (-1, 1):
        n = "l" if side < 0 else "r"
        arm = m.part(f"arm_{n}", parent="body", pivot=(side * 7, 20, 0))
        arm.blob((side * 8.5, 18, 0), (2.4, 3.5, 2.4), "dark_stone", noise=0.15, seed=11 + side)
        arm.blob((side * 9, 10, 1), (3.2, 3.2, 3.2), "stone", noise=0.12, seed=21 + side)
        arm.speckle({"stone": 0.6, "dark_stone": 0.4}, seed=5 + side)
        arm.paint_top("moss", only=["stone"])
        leg = m.part(f"leg_{n}", parent="body", pivot=(side * 3.5, 11, 0))
        leg.blob((side * 3.5, 5, 0), (2.6, 5.5, 2.8), "dark_stone", noise=0.12, seed=31 + side)
        leg.box((side * 2 - (1 if side > 0 else 0) , 0, -2), (side * 5, 1, 3), "dark_stone")
        leg.speckle({"dark_stone": 0.7, "slate": 0.3}, seed=7 + side)

    idle = m.clip("idle", 3.0)
    idle.osc("body", pos=(0, 0.4, 0), period=1.5)
    idle.osc("arm_l", rot=(6, 0, 4), period=3.0)
    idle.osc("arm_r", rot=(6, 0, -4), period=3.0, phase=0.5)
    idle.osc("head", rot=(0, 8, 0), period=3.0)
    walk_biped(m, length=1.6, swing=20, bob=0.7, sway=5)
    pound = m.clip("pound", 2.0, loop=False)
    pound.keys("arm_l", [(0, {}), (0.6, {"rot": (-160, 0, 20)}), (0.9, {"rot": (-40, 0, 0), "ease": "in"}),
                         (1.4, {"rot": (-40, 0, 0)}), (2.0, {})])
    pound.keys("arm_r", [(0, {}), (0.6, {"rot": (-160, 0, -20)}), (0.9, {"rot": (-40, 0, 0), "ease": "in"}),
                         (1.4, {"rot": (-40, 0, 0)}), (2.0, {})])
    pound.keys("body", [(0, {}), (0.6, {"pos": (0, 1, 0), "rot": (-8, 0, 0)}), (0.9, {"pos": (0, -2, 1), "rot": (15, 0, 0)}),
                        (1.4, {"pos": (0, -2, 1), "rot": (15, 0, 0)}), (2.0, {})])
    return m
