"""Animation clips.

A clip is a set of tracks. Each track moves one part relative to its parent
around the part's pivot. Contributions (oscillators, holds, keyframes) are
summed, then baked at ``fps`` so every exporter (Blender actions, FBX, glTF,
Roblox Luau animator) plays exactly the same motion.

Units: ``pos`` in voxels (author space), ``rot`` in degrees (Euler XYZ, i.e.
X applied first, then Y, then Z, all about the parent's axes).

Typical clips: ``idle`` (loop), ``walk`` (loop), and one action clip
(``attack``, ``jump``, ``roar``...). Keep loops seamless: use periods that
divide the clip length.
"""

from __future__ import annotations

import math
from typing import Callable, Sequence

Vec3 = Sequence[float]
Contribution = Callable[[float], tuple[tuple[float, float, float], tuple[float, float, float]]]

ZERO = (0.0, 0.0, 0.0)


def _v(x) -> tuple[float, float, float]:
    if x is None:
        return ZERO
    return (float(x[0]), float(x[1]), float(x[2]))


def _wave(kind: str, x: float) -> float:
    """x is the phase in cycles."""
    s = math.sin(2 * math.pi * x)
    if kind == "sin":
        return s
    if kind == "cos":
        return math.cos(2 * math.pi * x)
    if kind == "bounce":          # 0..1..0 hops, one hop per period
        return abs(math.sin(math.pi * x))
    if kind == "square":          # smooth square wave -1..1
        return math.tanh(3.0 * s) / math.tanh(3.0)
    if kind == "saw":             # 0..1 ramp
        return x - math.floor(x)
    if kind == "tri":
        f = x - math.floor(x)
        return 4 * f - 1 if f < 0.5 else 3 - 4 * f
    raise ValueError(f"unknown wave {kind!r}")


def _ease(kind: str, t: float) -> float:
    if kind == "linear":
        return t
    if kind == "smooth":
        return t * t * (3 - 2 * t)
    if kind == "in":
        return t * t
    if kind == "out":
        return 1 - (1 - t) * (1 - t)
    if kind == "back":            # slight overshoot, good for snappy attacks
        c = 1.70158
        u = t - 1
        return 1 + (c + 1) * u * u * u + c * u * u
    if kind == "step":
        return 0.0 if t < 1 else 1.0
    raise ValueError(f"unknown ease {kind!r}")


class Clip:
    def __init__(self, model, name: str, length: float, *, loop: bool = True, fps: int = 24):
        self.model = model
        self.name = name
        self.length = float(length)
        self.loop = loop
        self.fps = int(fps)
        self.tracks: dict[str, list[Contribution]] = {}

    def _add(self, part: str, fn: Contribution):
        self.tracks.setdefault(part, []).append(fn)
        return self

    # ------------------------------------------------------------ building blocks
    def osc(self, part: str, *, pos: Vec3 | None = None, rot: Vec3 | None = None, period: float | None = None,
            phase: float = 0.0, wave: str = "sin") -> "Clip":
        """Periodic motion: ``value = amplitude * wave(t / period + phase)``.

        ``phase`` is in cycles (0.5 = half a cycle later). ``wave`` is one of
        sin, cos, bounce, square, saw, tri.
        """
        P = float(period or self.length)
        a_pos, a_rot = _v(pos), _v(rot)

        def fn(t):
            w = _wave(wave, t / P + phase)
            return (tuple(a * w for a in a_pos), tuple(a * w for a in a_rot))

        return self._add(part, fn)

    def hold(self, part: str, *, pos: Vec3 | None = None, rot: Vec3 | None = None) -> "Clip":
        """Constant offset for the whole clip (e.g. wings held open during a roar)."""
        p, r = _v(pos), _v(rot)
        return self._add(part, lambda t: (p, r))

    def spin(self, part: str, axis: str = "y", *, turns: float = 1.0) -> "Clip":
        """Continuous rotation (windmills, wheels, propellers). Seamless when turns is an integer."""
        i = "xyz".index(axis)

        def fn(t):
            r = [0.0, 0.0, 0.0]
            r[i] = 360.0 * turns * (t / self.length)
            return (ZERO, tuple(r))

        return self._add(part, fn)

    def keys(self, part: str, keys: Sequence, *, ease: str = "smooth") -> "Clip":
        """Keyframes: ``[(time, {"pos": (...), "rot": (...)}), ...]`` or ``[(time, pos, rot), ...]``.

        Missing pos/rot mean rest pose. Each key may carry its own ease as a
        third dict field ``"ease"`` (applied to the segment that ends at that key).
        """
        ks = []
        for k in keys:
            if isinstance(k, dict):
                t, d = k["t"], k
            elif len(k) == 2 and isinstance(k[1], dict):
                t, d = k
            else:
                t, d = k[0], {"pos": k[1] if len(k) > 1 else None, "rot": k[2] if len(k) > 2 else None}
            ks.append((float(t), _v(d.get("pos")), _v(d.get("rot")), d.get("ease", ease)))
        ks.sort(key=lambda e: e[0])
        if not ks:
            return self

        def fn(t):
            if t <= ks[0][0]:
                return ks[0][1], ks[0][2]
            for (t0, p0, r0, _), (t1, p1, r1, e1) in zip(ks, ks[1:]):
                if t <= t1:
                    u = 0.0 if t1 <= t0 else (t - t0) / (t1 - t0)
                    u = _ease(e1, u)
                    return (tuple(a + (b - a) * u for a, b in zip(p0, p1)),
                            tuple(a + (b - a) * u for a, b in zip(r0, r1)))
            return ks[-1][1], ks[-1][2]

        return self._add(part, fn)

    # ------------------------------------------------------------ evaluation
    def sample(self, part: str, t: float):
        px = py = pz = rx = ry = rz = 0.0
        for fn in self.tracks.get(part, ()):
            (a, b, c), (d, e, f) = fn(t)
            px += a
            py += b
            pz += c
            rx += d
            ry += e
            rz += f
        return (px, py, pz, rx, ry, rz)

    def bake(self) -> dict:
        n = max(1, int(round(self.length * self.fps)))
        tracks = {}
        for part in self.tracks:
            rows = []
            for i in range(n + 1):
                t = min(i / self.fps, self.length)
                rows.append([round(v, 4) for v in self.sample(part, t)])
            tracks[part] = rows
        return {"name": self.name, "length": self.length, "loop": self.loop, "fps": self.fps,
                "frames": n + 1, "tracks": tracks}
