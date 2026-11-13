"""Monster = named parts in a joint hierarchy + procedural animations baked at 30 fps."""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Callable

import numpy as np

from geo import Mesh, euler, outline as make_outline

FPS = 30


# ----------------------------------------------------------------------
# animation helpers (all angles in degrees, time in seconds)
# ----------------------------------------------------------------------
def wave(t, period, phase=0.0):
    """sin of a full cycle every `period` seconds; phase in cycles (0..1)."""
    return math.sin(2 * math.pi * (t / period + phase))


def cwave(t, period, phase=0.0):
    return math.cos(2 * math.pi * (t / period + phase))


def _ease(u, kind):
    if kind == "lin":
        return u
    if kind == "in":
        return u * u * u
    if kind == "out":
        return 1 - (1 - u) ** 3
    if kind == "back":  # overshoot, for snappy hits
        c = 1.70158
        return 1 + (c + 1) * (u - 1) ** 3 + c * (u - 1) ** 2
    return u * u * (3 - 2 * u)


def key(t, pts):
    """Keyed value: pts = [(time, value[, ease])...]; ease applies to the segment
    arriving at that key ('smooth' default, 'in', 'out', 'lin', 'back')."""
    if t <= pts[0][0]:
        return pts[0][1]
    for a, b in zip(pts[:-1], pts[1:]):
        if t <= b[0]:
            u = (t - a[0]) / max(b[0] - a[0], 1e-9)
            return a[1] + (b[1] - a[1]) * _ease(u, b[2] if len(b) > 2 else "smooth")
    return pts[-1][1]


def pulse(t, t0, t1, t2, t3):
    """0 -> 1 between t0..t1, hold, 1 -> 0 between t2..t3."""
    return key(t, [(t0, 0), (t1, 1), (t2, 1), (t3, 0)])


def mir(r):
    """Mirror a left-side rotation (rx, ry, rz) to the right side."""
    return (r[0], -r[1], -r[2]) + tuple(r[3:])


def quat(rx, ry, rz):
    M = euler(rx, ry, rz)
    tr = M[0, 0] + M[1, 1] + M[2, 2]
    if tr > 0:
        s = math.sqrt(tr + 1.0) * 2
        w = 0.25 * s
        x = (M[2, 1] - M[1, 2]) / s
        y = (M[0, 2] - M[2, 0]) / s
        z = (M[1, 0] - M[0, 1]) / s
    elif M[0, 0] > M[1, 1] and M[0, 0] > M[2, 2]:
        s = math.sqrt(1.0 + M[0, 0] - M[1, 1] - M[2, 2]) * 2
        w = (M[2, 1] - M[1, 2]) / s
        x = 0.25 * s
        y = (M[0, 1] + M[1, 0]) / s
        z = (M[0, 2] + M[2, 0]) / s
    elif M[1, 1] > M[2, 2]:
        s = math.sqrt(1.0 + M[1, 1] - M[0, 0] - M[2, 2]) * 2
        w = (M[0, 2] - M[2, 0]) / s
        x = (M[0, 1] + M[1, 0]) / s
        y = 0.25 * s
        z = (M[1, 2] + M[2, 1]) / s
    else:
        s = math.sqrt(1.0 + M[2, 2] - M[0, 0] - M[1, 1]) * 2
        w = (M[1, 0] - M[0, 1]) / s
        x = (M[0, 2] + M[2, 0]) / s
        y = (M[1, 2] + M[2, 1]) / s
        z = 0.25 * s
    return np.array([x, y, z, w])


# ----------------------------------------------------------------------
@dataclass
class Part:
    name: str
    mesh: Mesh
    pivot: np.ndarray
    parent: str | None
    glow: bool = False
    joint: bool = True
    outline: float = 0.14  # 0 = no outline mesh
    glow_color: np.ndarray | None = None


@dataclass
class Anim:
    name: str
    title: str
    duration: float
    loop: bool
    fn: Callable[[float], dict]
    step: int = 3  # frames between rows of the keyframe table / Roblox keyframes
    note: str = ""
    ground: str = "clamp"  # "none" | "clamp" (never sink below Y=0) | "stick" (lowest foot always on Y=0)


@dataclass
class Monster:
    name: str
    title: str
    biome: str
    level: int
    rarity: str
    look: str
    palette: dict
    outline: float = 0.16
    scale: float = 1.0  # design units -> studs, applied in finalize()
    hover: float = 0.0  # floating creatures: gap (studs) between the ground and the lowest point
    parts: dict = field(default_factory=dict)
    anims: list = field(default_factory=list)
    vfx: list = field(default_factory=list)
    ground_parts: list = field(default_factory=list)  # feet used by the ground correction
    notes: str = ""

    # ---- building ----------------------------------------------------
    def part(self, name, mesh, pivot, parent=None, glow=False, joint=None, outline=None, glow_color=None):
        assert name not in self.parts, name
        assert parent is None or parent in self.parts, f"{name}: unknown parent {parent}"
        if joint is None:
            joint = not glow
        if outline is None:
            outline = 0.0 if glow else self.outline
        self.parts[name] = Part(name, mesh, np.asarray(pivot, float), parent, glow, joint, outline, glow_color)
        return self.parts[name]

    def sym(self, name, mesh, pivot, parent=None, **kw):
        """Add a left part (built at x < 0) and its mirrored right twin. Use '{}' for L / R."""
        pv = np.asarray(pivot, float)
        self.part(name.format("L"), mesh, pv, parent.format("L") if parent else None, **kw)
        self.part(name.format("R"), mesh.mirror(), pv * np.array([-1, 1, 1]), parent.format("R") if parent else None, **kw)

    def anim(self, name, title, duration, loop, fn, step=3, note="", ground="clamp"):
        self.anims.append(Anim(name, title, duration, loop, fn, step, note, ground))

    def fx(self, **kw):
        self.vfx.append(kw)

    # ---- finalising --------------------------------------------------
    def finalize(self):
        """Scale to studs, put the neutral pose on the ground (Y = 0) and centre it in X/Z."""
        k = self.scale
        for p in self.parts.values():
            p.mesh = p.mesh.scale(k)
            p.pivot = p.pivot * k
        lo = np.min([p.mesh.bounds()[0] for p in self.parts.values()], axis=0)
        hi = np.max([p.mesh.bounds()[1] for p in self.parts.values()], axis=0)
        shift = np.array([0.0, -lo[1] + self.hover, -(lo[2] + hi[2]) / 2])
        for p in self.parts.values():
            p.mesh = p.mesh.move(shift)
            p.pivot = p.pivot + shift
        self.size = hi - lo
        roots = [p.name for p in self.parts.values() if p.parent is None]
        assert len(roots) == 1, f"exactly one root mesh expected, got {roots}"
        self.root = roots[0]
        for p in self.parts.values():
            p.outline_mesh = make_outline(p.mesh, p.outline) if p.outline > 0 else None
            v = p.mesh.tris.reshape(-1, 3)
            p.verts = np.unique(np.round(v, 3), axis=0)
        self._bake_cache = {}
        return self

    @property
    def joints(self):
        return [p.name for p in self.parts.values() if p.joint]

    def tri_counts(self):
        out = {}
        for p in self.parts.values():
            out[p.name] = len(p.mesh)
            if p.outline_mesh is not None:
                out[p.name + "_Outline"] = len(p.outline_mesh)
        return out

    # ---- animation sampling ------------------------------------------
    def sample(self, anim: Anim, t: float) -> dict:
        raw = anim.fn(t)
        unknown = set(raw) - set(self.joints)
        assert not unknown, f"{self.name}.{anim.name}: pose uses unknown joints {sorted(unknown)}"
        out = {}
        for j in self.joints:
            v = tuple(raw.get(j, (0.0, 0.0, 0.0)))
            v = tuple(float(x) for x in (v + (0.0,) * 6)[:6])
            out[j] = v[:3] + tuple(x * self.scale for x in v[3:])
        if anim.ground != "none" and self.ground_parts:
            xf = self.world_transforms(out)
            low = np.inf
            for name in self.ground_parts:
                p = self.parts[name]
                R, T = xf[name]
                low = min(low, float(((p.verts - p.pivot) @ R.T + T)[:, 1].min()))
            fix = -low if anim.ground == "stick" else max(0.0, -low)
            r = out[self.root]
            out[self.root] = (r[0], r[1], r[2], r[3], r[4] + fix, r[5])
        return out

    def bake(self, anim: Anim):
        """-> times (N+1,), {joint: euler+pos array (N+1, 6)} sampled at 30 fps."""
        if anim.name in self._bake_cache:
            return self._bake_cache[anim.name]
        n = int(round(anim.duration * FPS))
        times = np.arange(n + 1) / FPS
        tracks = {j: np.zeros((n + 1, 6)) for j in self.joints}
        for i, t in enumerate(times):
            pose = self.sample(anim, 0.0 if (anim.loop and i == n) else float(t))
            for j, v in pose.items():
                tracks[j][i] = v
        self._bake_cache[anim.name] = (times, tracks)
        return times, tracks

    def moving_position_joints(self):
        """Joints that translate in at least one animation (need a position channel)."""
        mov = set()
        for a in self.anims:
            _, tr = self.bake(a)
            for j, arr in tr.items():
                if np.abs(arr[:, 3:]).max() > 1e-6:
                    mov.add(j)
        return mov

    # ---- forward kinematics (for checks) -----------------------------
    def world_transforms(self, pose: dict):
        """{part: (R, T)} so that world = R @ (rest_world - pivot) + T."""
        out = {}
        for p in self.parts.values():
            v = pose.get(p.name, (0, 0, 0, 0, 0, 0))
            Rl = euler(*v[:3])
            off = np.asarray(v[3:6], float) if len(v) >= 6 else np.zeros(3)
            if p.parent is None:
                out[p.name] = (Rl, p.pivot + off)
            else:
                Rp, Tp = out[p.parent]
                par = self.parts[p.parent]
                out[p.name] = (Rp @ Rl, Tp + Rp @ (p.pivot - par.pivot + off))
        return out

    def posed_bounds(self, pose: dict):
        xf = self.world_transforms(pose)
        lo, hi = np.full(3, np.inf), np.full(3, -np.inf)
        for p in self.parts.values():
            R, T = xf[p.name]
            v = (p.mesh.tris.reshape(-1, 3) - p.pivot) @ R.T + T
            lo, hi = np.minimum(lo, v.min(axis=0)), np.maximum(hi, v.max(axis=0))
        return lo, hi
