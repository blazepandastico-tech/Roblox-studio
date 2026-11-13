#!/usr/bin/env python3
"""Build every monster: GLB + keyframe tables + Roblox animation data.

    python3 tools/monstergen/build.py            # all monsters
    python3 tools/monstergen/build.py Dragon     # only some
"""
from __future__ import annotations

import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.dirname(os.path.dirname(HERE))

import numpy as np  # noqa: E402

from glb import write_glb  # noqa: E402

MODULES = ["dragon", "crab", "angler", "snapper", "ape", "wolf", "cobra", "golem", "hawk"]


def load_all(only=None):
    mons = []
    for name in MODULES:
        if not os.path.exists(os.path.join(HERE, "monsters", name + ".py")):
            continue
        mod = importlib.import_module(f"monsters.{name}")
        mon = mod.build()
        if only and mon.name not in only:
            continue
        mons.append(mon.finalize())
    return mons


def report(mon, verbose=False):
    tc = mon.tri_counts()
    total = sum(tc.values())
    worst = max(tc.items(), key=lambda kv: kv[1])
    s = mon.size
    print(f"{mon.name:14s} parts={len(mon.parts):3d} joints={len(mon.joints):3d} tris={total:6d} (max {worst[0]}={worst[1]}) "
          f"size W{s[0]:.1f} H{s[1]:.1f} L{s[2]:.1f}")
    for a in mon.anims:
        times, tracks = mon.bake(a)
        low, who, when = np.inf, "", 0.0
        for i in range(0, len(times), 2):
            pose = {j: tracks[j][i] for j in tracks}
            xf = mon.world_transforms(pose)
            for p in mon.parts.values():
                R, T = xf[p.name]
                y = float(((p.verts - p.pivot) @ R.T + T)[:, 1].min())
                if y < low:
                    low, who, when = y, p.name, times[i]
        flag = "  <-- below ground" if low < -0.25 else ""
        if verbose or flag:
            print(f"    {a.name:8s} lowest y={low:6.2f} ({who} at {when:.2f}s){flag}")
    assert worst[1] < 10000 and total < 45000


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    verbose = "-v" in sys.argv
    only = set(args) or None
    mons = load_all(only)
    try:
        import export
    except ImportError:
        export = None
    for mon in mons:
        out = os.path.join(ROOT, "monsters", mon.name)
        os.makedirs(out, exist_ok=True)
        write_glb(mon, os.path.join(out, f"{mon.name}.glb"))
        if export:
            export.write_all(mon, ROOT)
        report(mon, verbose)
    if export and not only:
        export.write_index(mons, ROOT)


if __name__ == "__main__":
    main()
