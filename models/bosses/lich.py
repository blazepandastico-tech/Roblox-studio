"""Lich boss: floating undead sorcerer with a crown, ragged robe and a glowing staff."""

from studvox import Model


def build() -> Model:
    m = Model("lich", title="Lich King", category="bosses",
              description="Floating undead sorcerer boss: hover idle, glide and a staff-raise spell.")
    body = m.part("body", pivot=(0, 10, 0))
    body.cylinder((0, 3, 0), 5, 14, "dark_purple", top_radius=3)
    body.paint_where(lambda x, y, z: (y <= 4) & ((x + z) % 2 == 0), "navy")
    body.carve(body.coords()[(body.coords()[:, 1] == 3) & ((body.coords()[:, 0] * 3 + body.coords()[:, 2]) % 3 == 0)])
    body.box((-3, 13, -2), (3, 16, 2), "purple")
    body.box((-1, 9, 3), (1, 15, 3), "neon_purple", stud=False)
    body.box((-5, 15, -3), (5, 17, 3), "dark_purple")                                     # shoulders
    body.voxels([(-5, 18, 0), (5, 18, 0), (-6, 17, 0), (6, 17, 0)], "silver")
    head = m.part("head", parent="body", pivot=(0, 17, 0))
    head.ellipsoid((0, 20, 0), (2.6, 2.8, 2.6), "bone" if False else "cream")
    head.decal(["CC.CC", "...", ".K.K."], at=(-2, 21, 0), colors={"C": "neon_cyan", "K": "black"})
    head.decal(["KKK"], at=(-1, 18, 0), colors={"K": "charcoal"})
    head.box((-3, 23, -2), (3, 23, 2), "gold")
    head.voxels([(-3, 24, 0), (0, 24, 2), (3, 24, 0), (0, 25, 2), (0, 24, -2)], "gold")
    head.voxel((0, 25, 3) if False else (0, 24, 3), "neon_red")
    hood = m.part("hood", parent="head", pivot=(0, 19, -1))
    hood.box((-3, 17, -3), (3, 22, -3), "dark_purple")
    hood.box((-3, 17, -2), (-3, 21, 1), "dark_purple")
    hood.box((3, 17, -2), (3, 21, 1), "dark_purple")
    arm_l = m.part("arm_l", parent="body", pivot=(-5, 16, 0))
    arm_l.box((-7, 10, -1), (-5, 16, 1), "dark_purple")
    arm_l.box((-7, 9, -1), (-6, 9, 0), "cream")
    arm_r = m.part("arm_r", parent="body", pivot=(5, 16, 0))
    arm_r.box((5, 10, -1), (7, 16, 1), "dark_purple")
    arm_r.box((6, 9, 0), (7, 9, 1), "cream")
    staff = m.part("staff", parent="arm_r", pivot=(7, 10, 1))
    staff.box((7, 2, 2), (7, 22, 2), "dark_brown")
    staff.ellipsoid((7, 24, 2), (1.6, 1.6, 1.6), "neon_purple")
    staff.voxels([(6, 22, 2), (8, 22, 2), (7, 22, 1), (7, 22, 3)], "silver")

    idle = m.clip("idle", 3.0)
    idle.osc("body", pos=(0, 1.0, 0), period=3.0)
    idle.osc("body", rot=(0, 0, 3), period=3.0, phase=0.25)
    idle.osc("arm_l", rot=(8, 0, -6), period=1.5)
    idle.osc("staff", rot=(0, 0, 4), period=3.0)
    walk = m.clip("walk", 2.0)
    walk.osc("body", pos=(0, 0.8, 0), period=1.0)
    walk.hold("body", rot=(12, 0, 0))
    walk.osc("arm_l", rot=(15, 0, 0), period=2.0)
    walk.osc("hood", rot=(-6, 0, 0), period=1.0)
    spell = m.clip("cast", 2.2, loop=False)
    spell.keys("arm_r", [(0, {}), (0.6, {"rot": (-150, 0, 0)}), (1.6, {"rot": (-150, 0, 0)}), (2.2, {})])
    spell.keys("arm_l", [(0, {}), (0.6, {"rot": (-60, 0, -30)}), (1.6, {"rot": (-60, 0, -30)}), (2.2, {})])
    spell.keys("body", [(0, {}), (0.6, {"pos": (0, 3, 0)}), (1.6, {"pos": (0, 3, 0)}), (2.2, {})])
    spell.keys("head", [(0, {}), (0.6, {"rot": (-15, 0, 0)}), (1.6, {"rot": (-15, 0, 0)}), (2.2, {})])
    return m
