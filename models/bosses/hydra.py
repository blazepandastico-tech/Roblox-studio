"""Hydra boss: three-headed green serpent on a scaly body."""

from studvox import Model
from studvox.kit import wave_chain


def build() -> Model:
    m = Model("hydra", title="Hydra", category="bosses",
              description="Three-headed swamp hydra boss: weaving necks, slither and a triple bite.")
    body = m.part("body", pivot=(0, 8, 0))
    body.ellipsoid((0, 7, -2), (8, 6, 9), "dark_green")
    body.paint_where(lambda x, y, z: (y <= 5) & (z >= 0), "light_green")
    body.paint_where(lambda x, y, z: (y >= 11) & ((x + z) % 3 == 0), "forest")
    for x in (-5, 5):
        body.box((x - 1, 0, 2), (x + 1, 3, 4), "dark_green")
        body.box((x - 1, 0, -7), (x + 1, 3, -5), "dark_green")
    tail = m.part("tail", parent="body", pivot=(0, 6, -10))
    tail.tube([(0, 6, -10), (0, 4, -16), (2, 3, -21), (4, 3, -24)], [3, 2.2, 1.4, 0.8], "dark_green")

    heads = {"l": (-6, 5), "c": (0, 0), "r": (6, 5)}
    for k, (x, back) in heads.items():
        base = (x * 0.6, 11, 3 - back * 0.3)
        mid = (x * 0.9, 17, 6 - back * 0.4)
        top = (x, 23 - back * 0.4, 8)
        n1 = m.part(f"neck_{k}", parent="body", pivot=base)
        n1.tube([base, mid], [2.4, 2.0], "green")
        n2 = m.part(f"neck2_{k}", parent=f"neck_{k}", pivot=mid)
        n2.tube([mid, top], [2.0, 1.8], "green")
        n2.paint_where(lambda X, Y, Z: Z >= top[2] - 1, "lime")
        h = m.part(f"head_{k}", parent=f"neck2_{k}", pivot=top)
        hx, hy, hz = top
        h.ellipsoid((hx, hy + 1, hz + 2), (2.4, 2, 3), "green")
        h.box((hx - 1, hy, hz + 3), (hx + 1, hy + 1, hz + 6), "green")
        h.voxels([(hx - 2, hy + 2, hz + 3), (hx + 2, hy + 2, hz + 3)], "neon_yellow")
        h.voxels([(hx - 1, hy + 4, hz + 1), (hx + 1, hy + 4, hz + 1), (hx, hy + 4, hz)], "cream")
        h.voxels([(hx - 1, hy - 1, hz + 6), (hx + 1, hy - 1, hz + 6)], "white", stud=False)

    idle = m.clip("idle", 3.0)
    idle.osc("body", pos=(0, 0.3, 0), period=1.5)
    walk = m.clip("walk", 1.6)
    walk.osc("body", rot=(0, 6, 3), period=1.6)
    walk.osc("body", pos=(0, 0.5, 0), period=0.8)
    walk.osc("tail", rot=(0, 20, 0), period=1.6)
    bite = m.clip("bite", 1.8, loop=False)
    for i, k in enumerate("lcr"):
        wave_chain(idle, [f"neck_{k}", f"neck2_{k}", f"head_{k}"], rot=(6, 10, 6), period=3.0, phase_step=0.1 + i * 0.05)
        wave_chain(walk, [f"neck_{k}", f"neck2_{k}"], rot=(5, 8, 0), period=1.6)
        t0 = 0.2 + i * 0.25
        bite.keys(f"neck_{k}", [(0, {}), (t0, {"rot": (-15, 0, 0)}), (t0 + 0.25, {"rot": (25, 0, 0), "ease": "back"}),
                                (t0 + 0.6, {}), (1.8, {})])
        bite.keys(f"head_{k}", [(0, {}), (t0, {"rot": (-20, 0, 0)}), (t0 + 0.25, {"rot": (20, 0, 0)}), (t0 + 0.6, {}),
                                (1.8, {})])
    idle.osc("tail", rot=(0, 10, 0), period=3.0)
    return m
