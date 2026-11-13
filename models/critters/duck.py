"""Duckling pet: big round head, tiny body, orange beak and feet, flappy wings."""

from studvox import Model


def build() -> Model:
    m = Model("duck", title="Duckling", category="critters",
              description="Chubby yellow duckling pet with waddle, flap and quack clips.")

    body = m.part("body", pivot=(0, 3, 0))
    body.ellipsoid((0, 3.5, -0.5), (3.6, 2.9, 3.9), "yellow")
    body.paint_where(lambda x, y, z: (y <= 3) & (z >= 1), "light_yellow")          # belly
    body.voxels([(0, 4, -5), (0, 5, -5), (0, 5, -6), (-1, 4, -5), (1, 4, -5)], "yellow")  # tail tuft

    head = m.part("head", parent="body", pivot=(0, 6, 0.5))
    head.ellipsoid((0, 9, 0.5), (3.8, 3.5, 3.5), "yellow")
    head.voxels([(0, 13, 0), (0, 14, 0), (1, 14, 0), (-1, 13, 1)], "yellow")      # hair tuft
    head.decal([".WB...WB.",
                ".BB...BB.",
                "P.......P"], at=(-4, 10, 0), colors={"W": "white", "B": "black", "P": "pink"})

    beak = m.part("beak", parent="head", pivot=(0, 7.5, 3.5))
    beak.box((-1, 8, 4), (1, 8, 6), "orange")
    beak.box((-1, 7, 4), (1, 7, 5), "dark_orange")

    wing_l = m.part("wing_l", parent="body", pivot=(3.5, 5, -1))
    wing_l.ellipsoid((4, 3.5, -1), (0.5, 1.9, 2.6), "mustard")
    wing_l.voxel((4, 2, -3), "mustard")
    m.mirror_part("wing_l", "wing_r")

    foot_l = m.part("foot_l", parent="body", pivot=(1.5, 1, 0))
    foot_l.box((1, 0, -1), (2, 0, 2), "orange")
    foot_l.voxel((2, 0, 2), "dark_orange")
    m.mirror_part("foot_l", "foot_r")

    idle = m.clip("idle", 2.0)
    idle.osc("body", pos=(0, 0.25, 0), period=1.0)
    idle.osc("head", rot=(4, 0, 6), period=2.0)
    idle.osc("wing_l", rot=(0, 0, 8), period=1.0)
    idle.osc("wing_r", rot=(0, 0, -8), period=1.0)

    walk = m.clip("walk", 0.8)
    walk.osc("body", rot=(0, 0, 7), period=0.8)
    walk.osc("body", pos=(0, 0.7, 0), period=0.4, wave="bounce")
    walk.osc("foot_l", rot=(35, 0, 0), period=0.8)
    walk.osc("foot_r", rot=(-35, 0, 0), period=0.8)
    walk.osc("head", rot=(6, 0, -5), period=0.8)
    walk.osc("wing_l", rot=(0, 0, 14), period=0.4)
    walk.osc("wing_r", rot=(0, 0, -14), period=0.4)

    quack = m.clip("quack", 1.2, loop=False)
    quack.keys("head", [(0, {}), (0.2, {"rot": (-18, 0, 0)}), (0.45, {"rot": (12, 0, 0)}),
                        (0.7, {"rot": (-10, 0, 0)}), (1.2, {})])
    quack.keys("beak", [(0, {}), (0.25, {"pos": (0, 0, 0.7)}), (0.5, {}), (0.75, {"pos": (0, 0, 0.7)}), (1.0, {})])
    quack.keys("wing_l", [(0, {}), (0.3, {"rot": (0, 0, 70)}), (0.5, {"rot": (0, 0, 20)}),
                          (0.7, {"rot": (0, 0, 70)}), (1.2, {})])
    quack.keys("wing_r", [(0, {}), (0.3, {"rot": (0, 0, -70)}), (0.5, {"rot": (0, 0, -20)}),
                          (0.7, {"rot": (0, 0, -70)}), (1.2, {})])
    quack.keys("body", [(0, {}), (0.3, {"pos": (0, 1.4, 0)}), (0.6, {}), (1.2, {})])
    return m
