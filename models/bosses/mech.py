"""Mech boss: chunky battle robot with shoulder cannons and a glowing core."""

from studvox import Model
from studvox.kit import walk_biped


def build() -> Model:
    m = Model("mech", title="Titan Mech", category="bosses",
              description="Armoured battle mech boss: hum idle, heavy stomp walk and a cannon barrage.")
    hip = m.part("body", pivot=(0, 12, 0))
    hip.box((-4, 11, -3), (4, 13, 3), "gunmetal")
    torso = m.part("torso", parent="body", pivot=(0, 14, 0))
    torso.box((-6, 14, -4), (6, 23, 4), "steel")
    torso.box((-5, 15, 5), (5, 22, 5), "light_gray")
    torso.box((-2, 17, 6), (2, 20, 6), "neon_cyan", stud=False)                          # core
    torso.box((-7, 22, -3), (7, 23, 3), "gunmetal")
    torso.paint_where(lambda x, y, z: (y == 14), "yellow")
    torso.paint_where(lambda x, y, z: (y == 14) & (x % 2 == 0), "black")
    head = m.part("head", parent="torso", pivot=(0, 24, 0))
    head.box((-3, 24, -2), (3, 28, 3), "steel")
    head.box((-2, 26, 4), (2, 26, 4), "neon_red", stud=False)
    head.box((-1, 29, -1), (-1, 31, -1), "dark_gray")
    for side in (-1, 1):
        n = "l" if side < 0 else "r"
        arm = m.part(f"arm_{n}", parent="torso", pivot=(side * 7.5, 21, 0))
        arm.box((side * 7, 19, -3) if side < 0 else (7, 19, -3), (side * 10, 24, 3), "gunmetal")
        arm.box((side * 8, 11, -2), (side * 10, 18, 2), "steel")
        arm.box((side * 8, 8, -2), (side * 10, 10, 4), "dark_gray")                       # fist/blaster
        arm.box((side * 9, 9, 5), (side * 9, 9, 5), "neon_cyan", stud=False)
        can = m.part(f"cannon_{n}", parent="torso", pivot=(side * 5, 24, -1))
        can.box((side * 4, 24, -3), (side * 6, 26, 0), "dark_gray")
        can.box((side * 5, 25, 1), (side * 5, 25, 6), "gunmetal")
        can.voxel((side * 5, 25, 7), "fire")
        leg = m.part(f"leg_{n}", parent="body", pivot=(side * 3, 12, 0))
        leg.box((side * 2, 6, -2), (side * 5, 11, 2), "steel")
        leg.box((side * 2, 1, -2), (side * 5, 5, 2), "gunmetal")
        leg.box((side * 1, 0, -3), (side * 6, 0, 5), "dark_gray")
        leg.voxel((side * 3, 8, 3), "yellow")

    idle = m.clip("idle", 2.0)
    idle.osc("body", pos=(0, 0.3, 0), period=1.0)
    idle.osc("torso", rot=(0, 5, 0), period=2.0)
    idle.osc("head", rot=(0, -10, 0), period=2.0, phase=0.1)
    walk = walk_biped(m, legs=("leg_l", "leg_r"), arms=("arm_l", "arm_r"), length=1.4, swing=22, bob=0.6, sway=3)
    walk.osc("torso", rot=(0, 6, 0), period=1.4)
    fire = m.clip("barrage", 2.0, loop=False)
    for t in (0.3, 0.6, 0.9, 1.2):
        pass
    fire.keys("cannon_l", [(0, {}), (0.3, {"rot": (-20, 0, 0)}), (0.4, {"rot": (-20, 0, 0), "pos": (0, 0, -1)}),
                           (0.5, {"rot": (-20, 0, 0)}), (0.8, {"rot": (-20, 0, 0), "pos": (0, 0, -1)}),
                           (0.9, {"rot": (-20, 0, 0)}), (1.6, {"rot": (-20, 0, 0)}), (2.0, {})])
    fire.keys("cannon_r", [(0, {}), (0.3, {"rot": (-20, 0, 0)}), (0.55, {"rot": (-20, 0, 0), "pos": (0, 0, -1)}),
                           (0.65, {"rot": (-20, 0, 0)}), (0.95, {"rot": (-20, 0, 0), "pos": (0, 0, -1)}),
                           (1.05, {"rot": (-20, 0, 0)}), (1.6, {"rot": (-20, 0, 0)}), (2.0, {})])
    fire.keys("arm_l", [(0, {}), (0.3, {"rot": (-80, 0, 0)}), (1.6, {"rot": (-80, 0, 0)}), (2.0, {})])
    fire.keys("arm_r", [(0, {}), (0.3, {"rot": (-80, 0, 0)}), (1.6, {"rot": (-80, 0, 0)}), (2.0, {})])
    fire.keys("torso", [(0, {}), (0.4, {"pos": (0, 0, -0.5)}), (0.5, {}), (0.8, {"pos": (0, 0, -0.5)}), (0.9, {}),
                        (2.0, {})])
    return m
