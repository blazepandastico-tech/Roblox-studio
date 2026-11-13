"""Kraken boss: purple sea monster head rising from the water with eight curling tentacles."""

import math

from studvox import Model
from studvox.kit import face, wave_chain


def build() -> Model:
    m = Model("kraken", title="Kraken", category="bosses",
              description="Giant purple kraken boss with swaying tentacles, a lurch and a tentacle slam.")
    body = m.part("body", pivot=(0, 6, 0))
    body.ellipsoid((0, 14, -1), (7.5, 10, 7), "purple")
    body.paint_where(lambda x, y, z: (y >= 18) & ((x + z) % 4 == 0), "violet")
    body.paint_where(lambda x, y, z: y <= 6, "dark_purple")
    face(body, ["YYYY.....YYYY", "YBBY.....YBBY", "YYYY.....YYYY"], y=14, colors={"Y": "neon_yellow"})
    body.decal(["KKKKKKK"], at=(-3, 8, 0), colors={"K": "black"})
    water = m.part("water", pivot=(0, 0, 0))
    water.add(__import__("studvox").S.ring((0, 0, 0), 15, 7, height=2), "water")
    water.paint_where(lambda x, y, z: (y == 1) & ((x * 7 + z * 3) % 11 == 0), "foam")

    for i in range(8):
        ang = 2 * math.pi * (i + 0.5) / 8
        dx, dz = math.cos(ang), math.sin(ang)
        prev = "body"
        r0, h0 = 6.5, 3
        for seg in range(3):
            r1 = r0 + 3.2
            h1 = h0 + (2 if seg == 0 else 4 if seg == 1 else 3)
            a = (dx * r0, h0, dz * r0)
            b = (dx * r1, h1, dz * r1)
            p = m.part(f"tent{i}_{seg}", parent=prev, pivot=a)
            p.tube([a, b], [2.0 - seg * 0.5, 1.6 - seg * 0.45], "purple")
            if seg == 2:
                p.voxel((round(dx * (r1 + 1)), h1 + 1, round(dz * (r1 + 1))), "purple")
            p.paint_where(lambda x, y, z: y <= h0 + 0.5, "lavender")
            prev = p.name
            r0, h0 = r1, h1

    idle = m.clip("idle", 3.0)
    idle.osc("body", pos=(0, 0.6, 0), period=1.5)
    idle.osc("water", pos=(0, 0.2, 0), period=1.0)
    lurch = m.clip("walk", 2.0)
    lurch.osc("body", rot=(6, 0, 4), period=2.0)
    lurch.osc("body", pos=(0, 0.8, 0), period=1.0)
    slam = m.clip("slam", 2.0, loop=False)
    for i in range(8):
        tilt_axis = (math.sin(2 * math.pi * (i + 0.5) / 8), 0, -math.cos(2 * math.pi * (i + 0.5) / 8))
        chain = [f"tent{i}_{s}" for s in range(3)]
        wave_chain(idle, chain, rot=(tilt_axis[0] * 12, 0, tilt_axis[2] * 12), period=3.0, phase_step=0.15)
        wave_chain(lurch, chain, rot=(tilt_axis[0] * 15, 8, tilt_axis[2] * 15), period=2.0, phase_step=0.15)
        up = tuple(-v * 35 for v in tilt_axis)
        down = tuple(v * 45 for v in tilt_axis)
        for s, part in enumerate(chain):
            slam.keys(part, [(0, {}), (0.7, {"rot": up}), (1.0, {"rot": down, "ease": "in"}), (1.5, {"rot": down}),
                             (2.0, {})])
    slam.keys("body", [(0, {}), (0.7, {"pos": (0, 2, 0)}), (1.0, {"pos": (0, -1, 0)}), (2.0, {})])
    return m
