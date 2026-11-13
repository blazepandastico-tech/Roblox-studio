"""Goblin: green goblin mob with big ears, a leather vest and a spiked club."""

from studvox import Model
from studvox.kit import face, walk_biped


def build() -> Model:
    m = Model("goblin", title="Goblin Grunt", category="mobs",
              description="Sneaky goblin mob with ear-twitch idle, crouched run and a club smash.")
    body = m.part("body", pivot=(0, 6, 0))
    body.box((-3, 6, -2), (3, 10, 2), "brown")
    body.box((-3, 6, -2), (3, 6, 2), "dark_brown")
    body.voxels([(0, 8, 3), (0, 9, 3)], "gold")
    body.paint_where(lambda x, y, z: (abs(x) <= 1) & (z == 2) & (y >= 8), "light_green")
    head = m.part("head", parent="body", pivot=(0, 11, 0))
    head.box((-3, 11, -2), (3, 16, 3), "light_green")
    head.box((-1, 12, 4), (1, 13, 4), "green")                                            # nose
    head.voxel((0, 12, 5), "green")
    face(head, ["YB...BY"], y=14, colors={"Y": "neon_yellow"})
    head.decal(["W.....W", ".KKKKK."], at=(-3, 12, 0), colors={"W": "white", "K": "black"})
    head.box((-3, 16, -2), (3, 16, 2), "dark_brown")
    ear_l = m.part("ear_l", parent="head", pivot=(-3.5, 14, 0))
    ear_l.box((-6, 14, 0), (-4, 14, 1), "light_green")
    ear_l.voxel((-7, 15, 0), "light_green")
    m.mirror_part("ear_l", "ear_r")
    for side in (-1, 1):
        n = "l" if side < 0 else "r"
        arm = m.part(f"arm_{n}", parent="body", pivot=(side * 4, 10, 0))
        arm.box((side * 4, 6, -1), (side * 4, 10, 0), "light_green")
        leg = m.part(f"leg_{n}", parent="body", pivot=(side * 1.5, 6, 0))
        leg.box((side * 1 if side > 0 else -2, 0, -1), (side * 2 if side > 0 else -1, 5, 0), "dark_brown")
        leg.box((side * 1 if side > 0 else -2, 0, 1), (side * 2 if side > 0 else -1, 0, 1), "light_green")
    club = m.part("club", parent="arm_r", pivot=(4, 6, 0))
    club.box((4, 5, 0), (4, 5, 4), "light_brown")
    club.box((3, 4, 5), (5, 6, 8), "brown")
    club.voxels([(4, 7, 6), (4, 3, 7), (6, 5, 6), (2, 5, 7)], "steel")

    idle = m.clip("idle", 2.0)
    idle.osc("body", pos=(0, 0.2, 0), period=1.0)
    idle.keys("ear_l", [(0, {}), (0.5, {"rot": (0, 0, 20)}), (0.6, {}), (2.0, {})])
    idle.keys("ear_r", [(0, {}), (1.2, {"rot": (0, 0, -20)}), (1.3, {}), (2.0, {})])
    idle.osc("club", rot=(8, 0, 0), period=2.0)
    walk = walk_biped(m, length=0.6, swing=38, bob=0.5, sway=5, head="head")
    walk.hold("body", rot=(10, 0, 0))
    smash = m.clip("smash", 1.2, loop=False)
    smash.keys("arm_r", [(0, {}), (0.45, {"rot": (-170, 0, 0)}), (0.65, {"rot": (-10, 0, 0), "ease": "in"}),
                         (1.2, {})])
    smash.keys("body", [(0, {}), (0.45, {"rot": (-10, 0, 0)}), (0.65, {"rot": (15, 0, 0), "pos": (0, -0.5, 1)}),
                        (1.2, {})])
    return m
