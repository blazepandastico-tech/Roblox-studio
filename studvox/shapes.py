"""Voxel shape primitives.

Every function returns an ``(N, 3)`` integer numpy array of voxel coordinates.
A voxel at integer coordinate ``(x, y, z)`` is a unit cube centred on that
point. Centres may be half-integers (``0.5``) to make even-sized shapes.

Axes (author space): **+X = right, +Y = up, +Z = front (towards the viewer)**.
"""

from __future__ import annotations

import math
from typing import Iterable, Sequence

import numpy as np

Vec = Sequence[float]
AXES = {"x": 0, "y": 1, "z": 2}


def _empty() -> np.ndarray:
    return np.zeros((0, 3), dtype=np.int32)


def _grid(lo: Vec, hi: Vec) -> np.ndarray:
    """All integer points in the inclusive box lo..hi (float bounds are rounded inwards/outwards)."""
    lo = [int(math.floor(v)) for v in lo]
    hi = [int(math.ceil(v)) for v in hi]
    if any(h < l for l, h in zip(lo, hi)):
        return _empty()
    xs = np.arange(lo[0], hi[0] + 1)
    ys = np.arange(lo[1], hi[1] + 1)
    zs = np.arange(lo[2], hi[2] + 1)
    g = np.stack(np.meshgrid(xs, ys, zs, indexing="ij"), axis=-1).reshape(-1, 3)
    return g.astype(np.int32)


def unique(coords: np.ndarray) -> np.ndarray:
    if len(coords) == 0:
        return _empty()
    return np.unique(np.asarray(coords, dtype=np.int32).reshape(-1, 3), axis=0)


def union(*shapes: np.ndarray) -> np.ndarray:
    shapes = [s for s in shapes if len(s)]
    if not shapes:
        return _empty()
    return unique(np.concatenate(shapes))


def _keys(c: np.ndarray) -> np.ndarray:
    c = np.asarray(c, dtype=np.int64) + 4096
    return (c[:, 0] << 26) | (c[:, 1] << 13) | c[:, 2]


def difference(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    if len(a) == 0 or len(b) == 0:
        return a
    return a[~np.isin(_keys(a), _keys(b))]


def intersect(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    if len(a) == 0 or len(b) == 0:
        return _empty()
    return a[np.isin(_keys(a), _keys(b))]


# ---------------------------------------------------------------- solids

def box(a: Vec, b: Vec) -> np.ndarray:
    """Solid box between two corner voxels (inclusive, any order)."""
    lo = [min(p, q) for p, q in zip(a, b)]
    hi = [max(p, q) for p, q in zip(a, b)]
    lo = [int(round(v)) for v in lo]
    hi = [int(round(v)) for v in hi]
    return _grid(lo, hi)


def box_c(center: Vec, size: Vec) -> np.ndarray:
    """Box from a centre and a size in voxels (size 3 -> 3 voxels wide)."""
    lo = [c - (s - 1) / 2 for c, s in zip(center, size)]
    hi = [c + (s - 1) / 2 for c, s in zip(center, size)]
    return box([math.ceil(v - 1e-6) for v in lo], [math.floor(v + 1e-6) for v in hi])


def ellipsoid(center: Vec, radii: Vec | float, *, soft: float = 0.12) -> np.ndarray:
    """Solid ellipsoid. ``soft`` slightly fattens the surface for rounder voxel shapes."""
    if isinstance(radii, (int, float)):
        radii = (radii, radii, radii)
    r = np.maximum(np.asarray(radii, dtype=float), 0.5)
    c = np.asarray(center, dtype=float)
    g = _grid(c - r, c + r)
    if len(g) == 0:
        return g
    d = (((g - c) / r) ** 2).sum(axis=1)
    return g[d <= 1.0 + soft]


def sphere(center: Vec, radius: float, **kw) -> np.ndarray:
    return ellipsoid(center, (radius, radius, radius), **kw)


def half(coords: np.ndarray, axis: str, side: str = "+", at: float = 0.0) -> np.ndarray:
    """Keep only the voxels on one side of a plane (inclusive). ``side`` is '+' or '-'."""
    a = AXES[axis]
    if side == "+":
        return coords[coords[:, a] >= at]
    return coords[coords[:, a] <= at]


def cylinder(base: Vec, radius: float | Vec, height: int, axis: str = "y", *,
             top_radius: float | Vec | None = None, soft: float = 0.15) -> np.ndarray:
    """Cylinder / frustum starting at ``base`` and extending ``height`` voxels along ``axis``.

    ``radius`` can be a pair ``(ru, rv)`` for an elliptic cross-section.
    Use a negative height to extend in the negative direction.
    ``top_radius`` tapers the shape (0 gives a cone).
    """
    a = AXES[axis]
    u, v = [i for i in range(3) if i != a]
    r0 = np.array(radius if isinstance(radius, (tuple, list)) else (radius, radius), dtype=float)
    r1 = r0 if top_radius is None else np.array(
        top_radius if isinstance(top_radius, (tuple, list)) else (top_radius, top_radius), dtype=float)
    n = int(abs(height))
    if n == 0:
        return _empty()
    step = 1 if height > 0 else -1
    out = []
    for k in range(n):
        t = 0.0 if n == 1 else k / (n - 1)
        r = r0 + (r1 - r0) * t
        if r[0] < 0.35 or r[1] < 0.35:
            # keep a single centre voxel for very small radii
            if r[0] >= 0.0 and r[1] >= 0.0 and (top_radius is None or t < 1.0 or r[0] > 0.2):
                p = [0, 0, 0]
                p[a] = base[a] + k * step
                p[u] = base[u]
                p[v] = base[v]
                out.append(np.array([[round(p[0]), round(p[1]), round(p[2])]], dtype=np.int32))
            continue
        lo = [0.0] * 3
        hi = [0.0] * 3
        lo[a] = hi[a] = base[a] + k * step
        lo[u], hi[u] = base[u] - r[0], base[u] + r[0]
        lo[v], hi[v] = base[v] - r[1], base[v] + r[1]
        g = _grid(lo, hi)
        g = g[g[:, a] == int(round(base[a] + k * step))]
        du = (g[:, u] - base[u]) / max(r[0], 0.5)
        dv = (g[:, v] - base[v]) / max(r[1], 0.5)
        out.append(g[du * du + dv * dv <= 1.0 + soft])
    return union(*out) if out else _empty()


def cone(base: Vec, radius: float, height: int, axis: str = "y", **kw) -> np.ndarray:
    return cylinder(base, radius, height, axis, top_radius=kw.pop("top_radius", 0.0), **kw)


def disc(center: Vec, radius: float | Vec, axis: str = "y", **kw) -> np.ndarray:
    return cylinder(center, radius, 1, axis, **kw)


def ring(center: Vec, radius: float, thickness: float = 1.0, axis: str = "y", height: int = 1) -> np.ndarray:
    outer = cylinder(center, radius, height, axis)
    inner = cylinder(center, max(radius - thickness, 0.0), height, axis) if radius - thickness > 0.3 else _empty()
    return difference(outer, inner)


def torus(center: Vec, major: float, minor: float, axis: str = "y") -> np.ndarray:
    a = AXES[axis]
    c = np.asarray(center, dtype=float)
    ext = np.full(3, major + minor)
    ext[a] = minor
    g = _grid(c - ext, c + ext)
    if len(g) == 0:
        return g
    d = g - c
    u, v = [i for i in range(3) if i != a]
    q = np.sqrt(d[:, u] ** 2 + d[:, v] ** 2) - major
    return g[q * q + d[:, a] ** 2 <= minor * minor + 0.25]


def line(a: Vec, b: Vec, radius: float = 0.0) -> np.ndarray:
    """Voxel line (radius 0) or capsule (radius > 0) between two points."""
    pa = np.asarray(a, dtype=float)
    pb = np.asarray(b, dtype=float)
    if radius <= 0.49:
        n = int(max(np.abs(pb - pa).max() * 3, 1))
        t = np.linspace(0.0, 1.0, n + 1)[:, None]
        pts = np.round(pa + (pb - pa) * t).astype(np.int32)
        return unique(pts)
    lo = np.minimum(pa, pb) - radius
    hi = np.maximum(pa, pb) + radius
    g = _grid(lo, hi)
    ab = pb - pa
    denom = float(ab @ ab) or 1.0
    t = np.clip(((g - pa) @ ab) / denom, 0.0, 1.0)
    closest = pa + t[:, None] * ab
    d2 = ((g - closest) ** 2).sum(axis=1)
    return g[d2 <= radius * radius + 0.2]


def polyline(points: Iterable[Vec], radius: float = 0.0) -> np.ndarray:
    pts = list(points)
    return union(*[line(p, q, radius) for p, q in zip(pts, pts[1:])])


def tube(points: Iterable[Vec], radii: Iterable[float]) -> np.ndarray:
    """A tapering tube through ``points`` with a radius per point (tails, tentacles, necks)."""
    pts = [np.asarray(p, dtype=float) for p in points]
    rs = list(radii)
    out = []
    for i in range(len(pts) - 1):
        steps = int(max(np.abs(pts[i + 1] - pts[i]).max() * 2, 1))
        for s in range(steps + 1):
            t = s / steps
            p = pts[i] + (pts[i + 1] - pts[i]) * t
            r = rs[i] + (rs[i + 1] - rs[i]) * t
            if r < 0.5:
                out.append(np.round(p).astype(np.int32)[None, :])
            else:
                out.append(sphere(p, r, soft=0.05))
    return union(*out)


def roof(a: Vec, b: Vec, ridge: str = "x", *, overhang: int = 0, step: int = 1) -> np.ndarray:
    """Stepped gable roof. ``a``/``b`` are the footprint corners at the eave height (y of ``a``).

    ``ridge`` is the axis the ridge runs along ('x' or 'z'). ``step`` is how many
    voxels each layer steps in.
    """
    x0, x1 = sorted((int(a[0]), int(b[0])))
    z0, z1 = sorted((int(a[2]), int(b[2])))
    y = int(a[1])
    x0 -= overhang
    x1 += overhang
    z0 -= overhang
    z1 += overhang
    out = []
    k = 0
    while True:
        if ridge == "x":
            lo, hi = z0 + k * step, z1 - k * step
            if lo > hi:
                break
            out.append(box((x0, y + k, lo), (x1, y + k, hi)))
        else:
            lo, hi = x0 + k * step, x1 - k * step
            if lo > hi:
                break
            out.append(box((lo, y + k, z0), (hi, y + k, z1)))
        k += 1
    return union(*out)


def pyramid(a: Vec, b: Vec, *, step: int = 1) -> np.ndarray:
    """Stepped pyramid (hip roof) over the footprint a..b starting at y of ``a``."""
    x0, x1 = sorted((int(a[0]), int(b[0])))
    z0, z1 = sorted((int(a[2]), int(b[2])))
    y = int(a[1])
    out = []
    k = 0
    while x0 + k * step <= x1 - k * step and z0 + k * step <= z1 - k * step:
        out.append(box((x0 + k * step, y + k, z0 + k * step), (x1 - k * step, y + k, z1 - k * step)))
        k += 1
    return union(*out)


def stairs(a: Vec, b: Vec, rise: str = "+z") -> np.ndarray:
    """Solid staircase filling the box a..b, climbing towards the ``rise`` direction (e.g. '+z', '-x')."""
    lo = [min(p, q) for p, q in zip(a, b)]
    hi = [max(p, q) for p, q in zip(a, b)]
    g = box(lo, hi)
    ax = AXES[rise[1]]
    run = hi[ax] - lo[ax] + 1
    height = hi[1] - lo[1] + 1
    pos = (g[:, ax] - lo[ax]) if rise[0] == "+" else (hi[ax] - g[:, ax])
    limit = np.floor((pos + 1) * height / run) - 1
    return g[(g[:, 1] - lo[1]) <= limit]


# ---------------------------------------------------------------- organic

def _hash3(ix, iy, iz, seed):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
    h = (h ^ (h >> 13)) * 1274126177
    h = h ^ (h >> 16)
    return (h & 0xFFFFFF).astype(np.float64) / float(0xFFFFFF)


def noise3(p: np.ndarray, scale: float = 4.0, seed: int = 0) -> np.ndarray:
    """Smooth value noise in [0, 1] for points ``p`` (N,3)."""
    q = np.asarray(p, dtype=np.float64) / max(scale, 1e-6)
    i = np.floor(q).astype(np.int64)
    f = q - i
    f = f * f * (3 - 2 * f)
    out = np.zeros(len(q))
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                out += w * _hash3(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seed)
    return out


def blob(center: Vec, radii: Vec | float, *, noise: float = 0.25, scale: float = 3.0, seed: int = 0) -> np.ndarray:
    """Lumpy ellipsoid (rocks, bushes, tree canopies, clouds)."""
    if isinstance(radii, (int, float)):
        radii = (radii, radii, radii)
    r = np.maximum(np.asarray(radii, dtype=float), 0.5)
    c = np.asarray(center, dtype=float)
    g = _grid(c - r * (1 + noise), c + r * (1 + noise))
    if len(g) == 0:
        return g
    d = np.sqrt((((g - c) / r) ** 2).sum(axis=1))
    n = noise3(g, scale, seed) * 2 - 1
    return g[d <= 1.0 + n * noise]


def scatter(points: np.ndarray, fraction: float, seed: int = 0) -> np.ndarray:
    """Randomly keep ``fraction`` of the given voxels (deterministic)."""
    if len(points) == 0:
        return points
    h = _hash3(points[:, 0].astype(np.int64), points[:, 1].astype(np.int64), points[:, 2].astype(np.int64), seed + 7)
    return points[h < fraction]


# ---------------------------------------------------------------- transforms

def translate(coords: np.ndarray, d: Vec) -> np.ndarray:
    return (np.asarray(coords, dtype=np.int32) + np.asarray([int(round(v)) for v in d], dtype=np.int32))


def mirror(coords: np.ndarray, axis: str = "x", center: float = 0.0) -> np.ndarray:
    """Mirror across the plane ``axis = center`` (use 0 for odd widths, -0.5 for even widths)."""
    c = np.asarray(coords, dtype=np.int32).copy()
    a = AXES[axis]
    c[:, a] = np.round(2 * center - c[:, a]).astype(np.int32)
    return c


def rotate90(coords: np.ndarray, axis: str = "y", k: int = 1, about: Vec = (0, 0, 0)) -> np.ndarray:
    """Rotate voxels by k*90 degrees about an axis through ``about`` (right-hand rule)."""
    c = np.asarray(coords, dtype=np.float64) - np.asarray(about, dtype=np.float64)
    a = AXES[axis]
    u, v = {0: (1, 2), 1: (2, 0), 2: (0, 1)}[a]
    for _ in range(k % 4):
        cu, cv = c[:, u].copy(), c[:, v].copy()
        c[:, u], c[:, v] = -cv, cu
    return np.round(c + np.asarray(about, dtype=np.float64)).astype(np.int32)


def hollow(coords: np.ndarray, thickness: int = 1) -> np.ndarray:
    """Remove interior voxels, keeping a shell ``thickness`` voxels thick."""
    c = unique(coords)
    keys = set(map(tuple, c.tolist()))
    shell = []
    t = thickness
    for p in c.tolist():
        x, y, z = p
        inside = True
        for dx, dy, dz in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)):
            for s in range(1, t + 1):
                if (x + dx * s, y + dy * s, z + dz * s) not in keys:
                    inside = False
                    break
            if not inside:
                break
        if not inside:
            shell.append(p)
    return np.asarray(shell, dtype=np.int32).reshape(-1, 3)
