"""Frog: squat green frog with bulging eyes and a long tongue."""

from studvox import Model


def build() -> Model:
    m = Model("frog", title="Froggy", category="critters",
              description="Squat green frog pet with throat-puff idle, hop and tongue-snap clips.")
    body = m.part("body", pivot=(0, 2, 0))
    body.ellipsoid((0, 3, 0), (4.4, 2.4, 3.9), "green")
    body.paint_where(lambda x, y, z: (y <= 2) & (z >= 1), "lime")                         # belly
    body.voxels([(-2, 5, -2), (2, 4, -3), (0, 5, -1), (-3, 4, 0)], "dark_green")          # spots
    body.box((-5, 0, -3), (-3, 1, 0), "green")                                            # back legs
    body.box((3, 0, -3), (5, 1, 0), "green")
    body.box((-3, 0, 2), (-2, 1, 4), "lime")                                              # front feet
    body.box((2, 0, 2), (3, 1, 4), "lime")
    body.decal(["KKKKK"], at=(-2, 3, 0), colors={"K": "dark_green"})                     # mouth line

    head = m.part("head", parent="body", pivot=(0, 5, 1))
    for sx in (-1, 1):
        head.sphere((sx * 2.5, 6.2, 1.5), 1.6, "green")
        head.box((sx * 2 + (0 if sx > 0 else -1), 6, 3), (sx * 2 + (1 if sx > 0 else 0), 7, 3), "white", stud=False)
        head.voxel((sx * 2 + (1 if sx > 0 else 0), 6, 3), "black", stud=False)

    throat = m.part("throat", parent="body", pivot=(0, 2, 3))
    throat.ellipsoid((0, 2, 3.5), (1.6, 1, 0.8), "light_yellow")

    tongue = m.part("tongue", parent="body", pivot=(0, 3, 4))
    tongue.box((0, 3, 4), (0, 3, 4), "hot_pink", stud=False)

    idle = m.clip("idle", 2.0)
    idle.osc("body", pos=(0, 0.15, 0), period=1.0)
    idle.keys("throat", [(0, {}), (0.4, {"pos": (0, 0, 0.6)}), (0.8, {}), (2.0, {})])
    idle.osc("head", rot=(0, 5, 0), period=2.0)

    walk = m.clip("walk", 0.8)
    walk.osc("body", pos=(0, 3, 0), period=0.8, wave="bounce")
    walk.osc("body", rot=(-10, 0, 0), period=0.8)

    snap = m.clip("snap", 0.9, loop=False)
    snap.keys("tongue", [(0, {}), (0.15, {"pos": (0, 0, 8)}), (0.3, {"pos": (0, 0, 8)}), (0.5, {}), (0.9, {})])
    snap.keys("head", [(0, {}), (0.15, {"rot": (-12, 0, 0)}), (0.5, {}), (0.9, {})])
    return m
