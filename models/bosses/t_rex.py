"""T-rex boss: big-headed tyrannosaur with tiny arms and a stomping walk."""

from studvox import Model
from studvox.kit import wave_chain


def build() -> Model:
    m = Model("t_rex", title="T-Rex", category="bosses",
              description="Stomping tyrannosaur boss with tail-sway idle, heavy walk and a chomp roar.")
    body = m.part("body", pivot=(0, 14, 0))
    body.ellipsoid((0, 15, 0), (5, 5.5, 7.5), "olive")
    body.paint_where(lambda x, y, z: (y <= 12) & (z >= 1), "sand")
    body.paint_where(lambda x, y, z: (y >= 19) & (z % 3 == 0), "moss")
    neck = m.part("neck", parent="body", pivot=(0, 18, 5))
    neck.tube([(0, 17, 5), (0, 21, 8)], [3.5, 3], "olive")
    head = m.part("head", parent="neck", pivot=(0, 22, 8))
    head.box((-3, 21, 7), (3, 26, 17), "olive")
    head.box((-2, 25, 8), (2, 27, 14), "olive")
    head.voxels([(-3, 25, 12), (3, 25, 12)], "yellow")
    head.voxels([(-3, 26, 12), (3, 26, 12)], "dark_brown")
    head.voxels([(-1, 26, 17), (1, 26, 17)], "black", stud=False)
    head.voxels([(x, 20, z) for x in (-3, 3) for z in (10, 12, 14, 16)], "white", stud=False)
    jaw = m.part("jaw", parent="head", pivot=(0, 21, 8))
    jaw.box((-3, 18, 8), (3, 20, 16), "olive")
    jaw.box((-2, 18, 9), (2, 18, 15), "sand")
    jaw.voxels([(x, 21, z) for x in (-2, 2) for z in (11, 13, 15)], "white", stud=False)

    arm_l = m.part("arm_l", parent="body", pivot=(-3.5, 15, 6))
    arm_l.line((-4, 15, 6), (-4, 12, 9), "olive", radius=0.6)
    arm_l.voxel((-4, 12, 10), "cream")
    m.mirror_part("arm_l", "arm_r")

    leg_l = m.part("leg_l", parent="body", pivot=(-4, 13, -1))
    leg_l.ellipsoid((-4.5, 11, -1), (2.5, 4, 3.5), "olive")
    leg_l.box((-6, 0, -1), (-3, 7, 1), "olive")
    leg_l.box((-6, 0, 2), (-3, 1, 4), "olive")
    leg_l.voxels([(-6, 0, 5), (-4, 0, 5)], "cream", stud=False)
    m.mirror_part("leg_l", "leg_r")

    prev = "body"
    pts = [(0, 15, -7), (0, 14, -13), (0, 13, -19), (0, 12, -25)]
    rad = [4, 2.8, 1.8, 0.9]
    for i in range(3):
        t = m.part(f"tail{i + 1}", parent=prev, pivot=pts[i])
        t.tube([pts[i], pts[i + 1]], [rad[i], rad[i + 1]], "olive")
        t.paint_where(lambda x, y, z, i=i: y >= pts[i][1] + rad[i] - 1, "moss")
        prev = t.name

    idle = m.clip("idle", 3.0)
    idle.osc("body", pos=(0, 0.5, 0), period=1.5)
    idle.osc("neck", rot=(4, 6, 0), period=3.0)
    idle.osc("arm_l", rot=(15, 0, 0), period=1.5)
    idle.osc("arm_r", rot=(15, 0, 0), period=1.5, phase=0.5)
    wave_chain(idle, ["tail1", "tail2", "tail3"], rot=(0, 8, 0), period=3.0)

    walk = m.clip("walk", 1.4)
    walk.osc("body", pos=(0, 0.8, 0), period=0.7, wave="bounce")
    walk.osc("body", rot=(0, 5, 4), period=1.4)
    walk.osc("leg_l", rot=(28, 0, 0), period=1.4)
    walk.osc("leg_r", rot=(-28, 0, 0), period=1.4)
    walk.osc("neck", rot=(5, -5, 0), period=0.7)
    wave_chain(walk, ["tail1", "tail2", "tail3"], rot=(0, 12, 0), period=1.4)

    chomp = m.clip("roar", 1.8, loop=False)
    chomp.keys("neck", [(0, {}), (0.4, {"rot": (-25, 0, 0)}), (0.8, {"rot": (20, 0, 0), "ease": "back"}),
                        (1.4, {"rot": (10, 0, 0)}), (1.8, {})])
    chomp.keys("jaw", [(0, {}), (0.4, {"rot": (35, 0, 0)}), (0.8, {"rot": (0, 0, 0), "ease": "in"}),
                       (1.0, {"rot": (30, 0, 0)}), (1.4, {"rot": (30, 0, 0)}), (1.8, {})])
    chomp.keys("body", [(0, {}), (0.8, {"pos": (0, 0, 2), "rot": (6, 0, 0)}), (1.8, {})])
    return m
