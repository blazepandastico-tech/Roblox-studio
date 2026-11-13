"""Skeleton warrior: bony undead mob with a rusty sword and a round shield."""

from studvox import Model
from studvox.kit import walk_biped


def build() -> Model:
    m = Model("skeleton", title="Skeleton Warrior", category="mobs",
              description="Rattling skeleton mob with jittery idle, shambling walk and a sword slash.")
    body = m.part("body", pivot=(0, 8, 0))
    body.box((-1, 7, -1), (1, 8, 1), "cream")                                              # pelvis
    body.box((0, 9, -1), (0, 14, -1), "white")                                             # spine
    for y in (10, 12, 14):
        body.box((-3, y, -1), (3, y, 1), "white")                                          # ribs
        body.carve(__import__("studvox").S.box((-2, y, 0), (2, y, 0)))
    body.box((-4, 15, -1), (4, 15, 1), "cream")                                            # shoulders
    head = m.part("head", parent="body", pivot=(0, 16, 0))
    head.box((-3, 16, -2), (3, 21, 3), "white")
    head.decal(["BB.BB", ".....", "..B..", "W.W.W"], at=(-2, 20, 0), colors={"B": "black", "W": "white"})
    head.decal(["B.B.B"], at=(-2, 16, 0), colors={"B": "dark_gray"})
    head.voxels([(-1, 19, 4), (1, 19, 4)], "neon_red", stud=False)
    head.carve(__import__("studvox").S.box((-1, 19, 3), (-1, 19, 3)))
    head.carve(__import__("studvox").S.box((1, 19, 3), (1, 19, 3)))
    for side in (-1, 1):
        n = "l" if side < 0 else "r"
        arm = m.part(f"arm_{n}", parent="body", pivot=(side * 4, 15, 0))
        arm.box((side * 4, 9, 0), (side * 4, 14, 0), "white")
        arm.voxel((side * 4, 8, 0), "cream")
        leg = m.part(f"leg_{n}", parent="body", pivot=(side * 1, 7, 0))
        leg.box((side * 1, 1, 0), (side * 1, 6, 0), "white")
        leg.box((side * 1, 0, 0), (side * 1, 0, 2), "cream")
    sword = m.part("sword", parent="arm_r", pivot=(4, 8, 0))
    sword.box((4, 8, 1), (4, 8, 2), "dark_brown")
    sword.box((3, 8, 3), (5, 8, 3), "steel")
    sword.box((4, 8, 4), (4, 8, 11), "copper")
    shield = m.part("shield", parent="arm_l", pivot=(-4, 11, 0))
    shield.add(__import__("studvox").S.cylinder((-5, 11, 0), 3, -1, "x"), "brown")
    shield.voxel((-6, 11, 0), "steel")
    shield.paint_where(lambda x, y, z: (abs(y - 11) + abs(z) >= 3), "steel")

    idle = m.clip("idle", 1.6)
    idle.osc("head", rot=(0, 10, 6), period=0.8)
    idle.osc("body", pos=(0, 0.2, 0), period=0.4)
    idle.osc("arm_l", rot=(5, 0, 0), period=0.8)
    walk_biped(m, length=1.0, swing=30, bob=0.4, sway=6, head="head")
    slash = m.clip("slash", 1.0, loop=False)
    slash.keys("arm_r", [(0, {}), (0.35, {"rot": (-150, 0, 0)}), (0.55, {"rot": (20, 0, 0), "ease": "back"}),
                         (1.0, {})])
    slash.keys("body", [(0, {}), (0.35, {"rot": (0, 15, 0)}), (0.55, {"rot": (8, -20, 0)}), (1.0, {})])
    return m
