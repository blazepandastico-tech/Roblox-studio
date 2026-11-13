"""Mimic chest: a treasure chest with teeth, a tongue and a nasty bite."""

from studvox import Model


def build() -> Model:
    m = Model("mimic_chest", title="Mimic Chest", category="mobs",
              description="Treasure-chest mimic mob: breathing lid idle, hopping chase and a lid-snapping bite.")
    base = m.part("body", pivot=(0, 0, 0))
    base.box((-6, 0, -4), (6, 5, 4), "brown")
    base.box((-6, 0, -4), (-6, 5, 4), "gold")
    base.box((6, 0, -4), (6, 5, 4), "gold")
    base.box((-6, 0, 4), (6, 0, 4), "gold")
    base.paint_where(lambda x, y, z: (y == 3) & (abs(z) < 4) & (abs(x) < 6), "dark_brown")
    base.carve(__import__("studvox").S.box((-5, 5, -3), (5, 5, 3)))
    base.box((-5, 4, -3), (5, 4, 3), "maroon")
    for x in (-4, -2, 0, 2, 4):
        base.voxel((x, 5, 4), "white", stud=False)
    tongue = m.part("tongue", parent="body", pivot=(0, 5, 0))
    tongue.box((-1, 5, -1), (1, 5, 5), "hot_pink", stud=False)
    tongue.voxel((0, 5, 6), "hot_pink", stud=False)

    lid = m.part("lid", parent="body", pivot=(0, 6, -4))
    lid.box((-6, 6, -4), (6, 8, 4), "brown")
    lid.box((-5, 9, -3), (5, 9, 3), "brown")
    lid.box((-6, 6, -4), (-6, 8, 4), "gold")
    lid.box((6, 6, -4), (6, 8, 4), "gold")
    lid.box((-6, 6, 4), (6, 6, 4), "gold")
    lid.box((-1, 5, 5), (1, 7, 5), "gold")                                                # lock
    lid.voxel((0, 6, 6), "dark_gray")
    for x in (-5, -3, -1, 1, 3, 5):
        lid.voxel((x, 5, 4), "white", stud=False)
    lid.decal(["Y.........Y"], at=(-5, 8, 0), colors={"Y": "neon_yellow"})

    idle = m.clip("idle", 2.0)
    idle.keys("lid", [(0, {}), (0.6, {"rot": (-12, 0, 0)}), (1.2, {}), (2.0, {})])
    idle.keys("tongue", [(0, {}), (0.6, {"pos": (0, 0.5, 0.5)}), (1.2, {}), (2.0, {})])
    walk = m.clip("walk", 0.6)
    walk.osc("body", pos=(0, 2.5, 0), period=0.6, wave="bounce")
    walk.osc("lid", rot=(-18, 0, 0), period=0.3, wave="bounce")
    walk.osc("body", rot=(0, 0, 6), period=1.2)
    bite = m.clip("bite", 1.0, loop=False)
    bite.keys("lid", [(0, {}), (0.35, {"rot": (-70, 0, 0)}), (0.5, {"rot": (2, 0, 0), "ease": "in"}),
                      (0.65, {"rot": (-30, 0, 0)}), (1.0, {})])
    bite.keys("body", [(0, {}), (0.35, {"pos": (0, 1, -1)}), (0.5, {"pos": (0, 0, 3), "ease": "back"}), (1.0, {})])
    bite.keys("tongue", [(0, {}), (0.35, {"pos": (0, 0, 2)}), (0.5, {}), (1.0, {})])
    return m
