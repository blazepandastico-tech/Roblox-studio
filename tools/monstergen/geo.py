"""Low-poly geometry kit: faceted primitives, per-facet colouring, inverted-hull outlines.

Everything is flat shaded: a Mesh is a soup of triangles, each with its own
sRGB colour. 1 unit = 1 stud, +Y up, the creature faces -Z (left side = -X).
"""
from __future__ import annotations

import math
import zlib

import numpy as np
from scipy.spatial import ConvexHull


def V(*a):
    return np.array(a, dtype=float)


def hexc(h: str) -> np.ndarray:
    h = h.lstrip("#")
    return np.array([int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4)])


def lerp(a, b, t):
    return a + (np.asarray(b) - a) * t


def lighten(c, t):
    return lerp(np.asarray(c, float), np.ones(3), t)


def darken(c, t):
    return np.asarray(c, float) * (1.0 - t)


def norm(v):
    v = np.asarray(v, float)
    n = np.linalg.norm(v)
    return v / n if n > 1e-12 else v


def rotm(axis, deg) -> np.ndarray:
    """Rotation matrix about 'x' / 'y' / 'z' or an arbitrary axis vector."""
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    if isinstance(axis, str):
        axis = {"x": (1, 0, 0), "y": (0, 1, 0), "z": (0, 0, 1)}[axis]
    x, y, z = norm(axis)
    C = 1 - c
    return np.array(
        [
            [c + x * x * C, x * y * C - z * s, x * z * C + y * s],
            [y * x * C + z * s, c + y * y * C, y * z * C - x * s],
            [z * x * C - y * s, z * y * C + x * s, c + z * z * C],
        ]
    )


def euler(rx, ry, rz) -> np.ndarray:
    """Same convention as Roblox CFrame.Angles(rx, ry, rz): R = Rx * Ry * Rz (degrees)."""
    return rotm("x", rx) @ rotm("y", ry) @ rotm("z", rz)


class Mesh:
    __slots__ = ("tris", "cols", "ow")

    def __init__(self, tris=None, cols=None, ow=None):
        self.tris = np.zeros((0, 3, 3)) if tris is None else np.asarray(tris, float).reshape(-1, 3, 3)
        n = len(self.tris)
        self.cols = np.ones((n, 3)) if cols is None else np.asarray(cols, float).reshape(n, 3)
        self.ow = np.ones(n) if ow is None else np.asarray(ow, float).reshape(n)

    # ---- combination -------------------------------------------------
    def copy(self):
        return Mesh(self.tris.copy(), self.cols.copy(), self.ow.copy())

    def __add__(self, o):
        if o is None:
            return self.copy()
        return Mesh(
            np.concatenate([self.tris, o.tris]),
            np.concatenate([self.cols, o.cols]),
            np.concatenate([self.ow, o.ow]),
        )

    __radd__ = __add__

    @staticmethod
    def join(meshes):
        meshes = [m for m in meshes if m is not None and len(m.tris)]
        if not meshes:
            return Mesh()
        return Mesh(
            np.concatenate([m.tris for m in meshes]),
            np.concatenate([m.cols for m in meshes]),
            np.concatenate([m.ow for m in meshes]),
        )

    def __len__(self):
        return len(self.tris)

    # ---- measurements ------------------------------------------------
    def raw_normals(self):
        a, b, c = self.tris[:, 0], self.tris[:, 1], self.tris[:, 2]
        return np.cross(b - a, c - a)

    def normals(self):
        n = self.raw_normals()
        l = np.linalg.norm(n, axis=1, keepdims=True)
        return n / np.maximum(l, 1e-12)

    def centroids(self):
        return self.tris.mean(axis=1)

    def volume(self):
        a, b, c = self.tris[:, 0], self.tris[:, 1], self.tris[:, 2]
        return float(np.einsum("ij,ij->i", a, np.cross(b, c)).sum() / 6.0)

    def bounds(self):
        v = self.tris.reshape(-1, 3)
        return v.min(axis=0), v.max(axis=0)

    def center(self):
        lo, hi = self.bounds()
        return (lo + hi) / 2

    # ---- transforms (all return new meshes) --------------------------
    def flipped(self):
        return Mesh(self.tris[:, ::-1].copy(), self.cols.copy(), self.ow.copy())

    def fixed(self):
        """Make a closed shape face outwards."""
        return self.flipped() if self.volume() < 0 else self

    def move(self, *v):
        v = np.asarray(v[0] if len(v) == 1 else v, float)
        return Mesh(self.tris + v, self.cols.copy(), self.ow.copy())

    def xf(self, M, origin=(0, 0, 0)):
        o = np.asarray(origin, float)
        t = (self.tris - o) @ np.asarray(M).T + o
        m = Mesh(t, self.cols.copy(), self.ow.copy())
        return m.flipped() if np.linalg.det(M) < 0 else m

    def rot(self, axis, deg, origin=(0, 0, 0)):
        return self.xf(rotm(axis, deg), origin)

    def scale(self, s, origin=(0, 0, 0)):
        s = np.asarray(s, float) * np.ones(3)
        return self.xf(np.diag(s), origin)

    def mirror(self):
        """Mirror across the YZ plane (left <-> right)."""
        return self.xf(np.diag([-1.0, 1.0, 1.0]))

    # ---- colour ------------------------------------------------------
    def paint(self, color):
        m = self.copy()
        m.cols[:] = np.asarray(color, float)
        return m

    def shade(self, base, light=None, dark=None, under=None, jitter=0.45, seed="", up=(0, 1, 0), under_at=-0.45):
        """Per-facet colour: upward facets drift to `light`, downward to `dark`,
        plus a deterministic random pick so neighbouring facets read as separate planes.
        `under` recolours facets that face down (belly plates)."""
        base = np.asarray(base, float)
        light = lighten(base, 0.28) if light is None else np.asarray(light, float)
        dark = darken(base, 0.22) if dark is None else np.asarray(dark, float)
        m = self.copy()
        if not len(m.tris):
            return m
        n = m.normals()
        t = n @ norm(up)
        c = m.centroids()
        rng = np.random.default_rng(zlib.crc32(seed.encode()) & 0xFFFFFFFF)
        # stable ordering so mirrored / rebuilt meshes get the same pattern
        r = rng.random(len(c))
        k = np.clip(0.5 + 0.38 * t + (r - 0.5) * jitter, 0.0, 1.0)
        lo = k < 0.5
        out = np.empty_like(m.cols)
        out[lo] = dark + (base - dark) * (k[lo] * 2.0)[:, None]
        out[~lo] = base + (light - base) * ((k[~lo] - 0.5) * 2.0)[:, None]
        if under is not None:
            u = np.asarray(under, float)
            sel = t < under_at
            ku = np.clip(0.75 + (r[sel] - 0.5) * 0.5, 0, 1)[:, None]
            out[sel] = darken(u, 0.18) + (u - darken(u, 0.18)) * ku
        m.cols = np.clip(out, 0, 1)
        return m

    def weight(self, w):
        """Outline thickness multiplier for these faces (small details get thinner lines)."""
        m = self.copy()
        m.ow[:] = w
        return m


# ----------------------------------------------------------------------
# primitives
# ----------------------------------------------------------------------
def _frame(t, up):
    t = norm(t)
    up = np.asarray(up, float)
    if abs(float(t @ up)) > 0.94:
        up = V(0, 0, -1) if abs(t[2]) < 0.9 else V(1, 0, 0)
    u = norm(np.cross(up, t))
    v = np.cross(t, u)
    return t, u, v


def loft(rings, cap0=0.0, cap1=0.0, t0=None, t1=None) -> Mesh:
    """Skin a list of same-sized rings; caps are fans whose apex is pushed out by cap0/cap1."""
    rings = np.asarray(rings, float)
    m, n, _ = rings.shape
    tris = []
    for i in range(m - 1):
        for j in range(n):
            j1 = (j + 1) % n
            a, b, c, d = rings[i, j], rings[i, j1], rings[i + 1, j1], rings[i + 1, j]
            if np.linalg.norm(a - c) <= np.linalg.norm(b - d):
                tris += [(a, b, c), (a, c, d)]
            else:
                tris += [(a, b, d), (b, c, d)]
    c0, c1 = rings[0].mean(axis=0), rings[-1].mean(axis=0)
    if t0 is None:
        t0 = norm(rings[1].mean(axis=0) - c0) if m > 1 else V(0, 0, 1)
    if t1 is None:
        t1 = norm(c1 - rings[-2].mean(axis=0)) if m > 1 else V(0, 0, 1)
    a0 = c0 - np.asarray(t0) * cap0
    a1 = c1 + np.asarray(t1) * cap1
    for j in range(n):
        j1 = (j + 1) % n
        tris.append((a0, rings[0, j1], rings[0, j]))
        tris.append((a1, rings[-1, j], rings[-1, j1]))
    return _clean(Mesh(np.array(tris))).fixed()


def _clean(m: Mesh) -> Mesh:
    """Drop degenerate (zero-area) triangles."""
    a = np.linalg.norm(m.raw_normals(), axis=1)
    keep = a > 1e-9
    return Mesh(m.tris[keep], m.cols[keep], m.ow[keep])


def tube(path, radii, n=6, roll=0.0, stagger=False, profile=None, caps=(0.0, 0.0), up=(0, 1, 0), twist=0.0) -> Mesh:
    """Faceted tube along a polyline. radii: scalar or (rx, ry) per path point.
    Ring angle 0 points to the frame's side vector, 90 to its up vector.
    `profile` multiplies the radius per ring vertex (sculpts the cross-section)."""
    path = np.asarray(path, float)
    m = len(path)
    rings = []
    frames = []
    for i, p in enumerate(path):
        if i == 0:
            t = path[1] - path[0]
        elif i == m - 1:
            t = path[-1] - path[-2]
        else:
            t = norm(path[i + 1] - path[i]) + norm(path[i] - path[i - 1])
        t, u, v = _frame(t, up)
        frames.append(t)
        r = radii[i]
        rx, ry = (r, r) if np.isscalar(r) else r
        a0 = math.radians(roll + twist * i) + (math.pi / n if (stagger and i % 2) else 0.0)
        pts = []
        for j in range(n):
            a = a0 + 2 * math.pi * j / n
            k = 1.0 if profile is None else profile[j % len(profile)]
            pts.append(p + u * (rx * k * math.cos(a)) + v * (ry * k * math.sin(a)))
        rings.append(pts)
    return loft(rings, caps[0], caps[1], frames[0], frames[-1])


def spike(base, tip, r, n=4, roll=0.0, up=(0, 1, 0)) -> Mesh:
    """Sharp cone-like spike with a flat faceted base."""
    base, tip = np.asarray(base, float), np.asarray(tip, float)
    t, u, v = _frame(tip - base, up)
    rx, ry = (r, r) if np.isscalar(r) else r
    ring = [
        base + u * rx * math.cos(math.radians(roll) + 2 * math.pi * j / n) + v * ry * math.sin(math.radians(roll) + 2 * math.pi * j / n)
        for j in range(n)
    ]
    tris = []
    for j in range(n):
        j1 = (j + 1) % n
        tris.append((ring[j], ring[j1], tip))
        tris.append((base, ring[j1], ring[j]))
    return Mesh(np.array(tris)).fixed()


def crystal(base, tip, r, n=5, waist=0.3, roll=0.0, up=(0, 1, 0)) -> Mesh:
    """Elongated faceted crystal: point at `base`, widest at `waist`, point at `tip`."""
    base, tip = np.asarray(base, float), np.asarray(tip, float)
    t, u, v = _frame(tip - base, up)
    rx, ry = (r, r) if np.isscalar(r) else r
    c = base + (tip - base) * waist
    ring = [
        c + u * rx * math.cos(math.radians(roll) + 2 * math.pi * j / n) + v * ry * math.sin(math.radians(roll) + 2 * math.pi * j / n)
        for j in range(n)
    ]
    tris = []
    for j in range(n):
        j1 = (j + 1) % n
        tris.append((ring[j], ring[j1], tip))
        tris.append((base, ring[j1], ring[j]))
    return Mesh(np.array(tris)).fixed()


def hull(points) -> Mesh:
    """Convex faceted solid through the given points (angular rocks, skulls, plates)."""
    pts = np.asarray(points, float)
    h = ConvexHull(pts)
    tris = pts[h.simplices]
    c = pts[h.vertices].mean(axis=0)
    n = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
    flip = np.einsum("ij,ij->i", n, tris[:, 0] - c) < 0
    tris[flip] = tris[flip][:, ::-1]
    return _clean(Mesh(tris))


def hull_sym(points) -> Mesh:
    """Convex solid from points mirrored across X (give one side only)."""
    pts = np.asarray(points, float)
    mir = pts * V(-1, 1, 1)
    return hull(np.concatenate([pts, mir]))


def plate(poly, thickness, fan=None) -> Mesh:
    """Thin solid from a 3D polygon (wings, fins, leaves). `fan` = index of the polygon
    vertex every triangle starts from (default: centroid)."""
    poly = np.asarray(poly, float)
    k = len(poly)
    nrm = np.zeros(3)
    for i in range(k):
        a, b = poly[i], poly[(i + 1) % k]
        nrm += np.cross(a, b)
    nrm = norm(nrm)
    top = poly + nrm * thickness / 2
    bot = poly - nrm * thickness / 2
    tris = []
    if fan is None:
        ct, cb = top.mean(axis=0), bot.mean(axis=0)
        for i in range(k):
            i1 = (i + 1) % k
            tris.append((ct, top[i], top[i1]))
            tris.append((cb, bot[i1], bot[i]))
    else:
        for o in range(1, k - 1):
            i, i1 = (fan + o) % k, (fan + o + 1) % k
            tris.append((top[fan], top[i], top[i1]))
            tris.append((bot[fan], bot[i1], bot[i]))
    for i in range(k):
        i1 = (i + 1) % k
        tris.append((top[i], bot[i], bot[i1]))
        tris.append((top[i], bot[i1], top[i1]))
    return _clean(Mesh(np.array(tris))).fixed()


def wedge_plate(poly, t_root, t_edge, root=0) -> Mesh:
    """Like plate() but thicker at vertex `root` and thin elsewhere (blade / fin look)."""
    poly = np.asarray(poly, float)
    k = len(poly)
    nrm = np.zeros(3)
    for i in range(k):
        nrm += np.cross(poly[i], poly[(i + 1) % k])
    nrm = norm(nrm)
    th = np.full(k, t_edge / 2.0)
    th[root] = t_root / 2.0
    top = poly + nrm * th[:, None]
    bot = poly - nrm * th[:, None]
    tris = []
    for o in range(1, k - 1):
        i, i1 = (root + o) % k, (root + o + 1) % k
        tris.append((top[root], top[i], top[i1]))
        tris.append((bot[root], bot[i1], bot[i]))
    for i in range(k):
        i1 = (i + 1) % k
        tris.append((top[i], bot[i], bot[i1]))
        tris.append((top[i], bot[i1], top[i1]))
    return _clean(Mesh(np.array(tris))).fixed()


def gem(center, size, n=6, roll=0.0, axis=(0, 0, -1), up=(0, 1, 0), table=0.45) -> Mesh:
    """Faceted cut gem (eyes, orbs): girdle ring + small flat table front and back."""
    c = np.asarray(center, float)
    sx, sy, sz = np.asarray(size, float) * np.ones(3)
    t, u, v = _frame(axis, up)
    rings = []
    for depth, k in ((-0.5, table), (0.0, 1.0), (0.5, table)):
        ring = []
        for j in range(n):
            a = math.radians(roll) + 2 * math.pi * j / n
            ring.append(c + t * depth * sz + u * sx * 0.5 * k * math.cos(a) + v * sy * 0.5 * k * math.sin(a))
        rings.append(ring)
    return loft(rings, 0.0, 0.0, t, t)


# ----------------------------------------------------------------------
# surface helpers
# ----------------------------------------------------------------------
def ray_hit(mesh: Mesh, origin, direction):
    """First intersection of a ray with the mesh -> (point, face normal) or None."""
    o = np.asarray(origin, float)
    d = norm(direction)
    a, b, c = mesh.tris[:, 0], mesh.tris[:, 1], mesh.tris[:, 2]
    e1, e2 = b - a, c - a
    p = np.cross(d, e2)
    det = np.einsum("ij,ij->i", e1, p)
    ok = np.abs(det) > 1e-10
    inv = np.where(ok, 1.0 / np.where(ok, det, 1.0), 0.0)
    s = o - a
    u = np.einsum("ij,ij->i", s, p) * inv
    q = np.cross(s, e1)
    v = (q @ d) * inv
    t = np.einsum("ij,ij->i", e2, q) * inv
    hit = ok & (u >= -1e-9) & (v >= -1e-9) & (u + v <= 1 + 1e-9) & (t > 1e-6)
    if not hit.any():
        return None
    idx = np.where(hit)[0]
    i = idx[np.argmin(t[idx])]
    n = norm(np.cross(e1[i], e2[i]))
    if n @ d > 0:
        n = -n
    return o + d * t[i], n


def _target(h, toward):
    """Point the ray from hint `h` aims at: a point, or the nearest point of a polyline."""
    tw = np.asarray(toward, float)
    if tw.ndim == 1:
        return tw
    best, bd = None, 1e18
    for p0, p1 in zip(tw[:-1], tw[1:]):
        d = p1 - p0
        s_ = np.clip(((h - p0) @ d) / max(d @ d, 1e-12), 0, 1)
        q = p0 + d * s_
        dist = np.linalg.norm(h - q)
        if dist < bd:
            best, bd = q, dist
    return best


def project(mesh: Mesh, hint, toward):
    """Drop a hint point onto the surface -> (point, normal) or None.
    `toward` is a target point, a polyline (nearest point is used) or
    ("ray", direction) for a parallel projection."""
    h = np.asarray(hint, float)
    if isinstance(toward, tuple) and len(toward) == 2 and isinstance(toward[0], str):
        return ray_hit(mesh, h, toward[1])
    return ray_hit(mesh, h, _target(h, toward) - h)


def crack(mesh: Mesh, hints, width=0.16, lift=0.06, sink=0.05, toward=None, step=0.22, taper=0.25) -> Mesh:
    """Raised glowing ridge that hugs the surface of `mesh` along a polyline.
    `hints` are points outside the surface; each is projected towards `toward`
    (a point, or a (p0, p1) segment = the body axis). The ridge has a triangular
    cross-section, sunk slightly into the surface and lifted above it, so no face
    is coplanar with the body (no z-fighting)."""
    hints = [np.asarray(h, float) for h in hints]
    dense = [hints[0]]
    for a, b in zip(hints[:-1], hints[1:]):
        k = max(1, int(math.ceil(np.linalg.norm(b - a) / step)))
        for i in range(1, k + 1):
            dense.append(a + (b - a) * i / k)
    if toward is None:
        toward = mesh.center()
    pts, nrms = [], []
    for h in dense:
        hit = project(mesh, h, toward)
        if hit is None:
            continue
        pts.append(hit[0])
        nrms.append(hit[1])
    if len(pts) < 2:
        return Mesh()
    pts, nrms = np.array(pts), np.array(nrms)
    k = len(pts)
    L, R, T = [], [], []
    for i in range(k):
        d = norm(pts[min(i + 1, k - 1)] - pts[max(i - 1, 0)])
        w = norm(np.cross(nrms[i], d))
        e = min(i, k - 1 - i) / max(1.0, (k - 1) / 2.0)
        tw = width / 2 * (taper + (1 - taper) * min(1.0, e * 2.5))
        L.append(pts[i] - nrms[i] * sink + w * tw)
        R.append(pts[i] - nrms[i] * sink - w * tw)
        T.append(pts[i] + nrms[i] * lift)
    tris = []
    for i in range(k - 1):
        tris += [(L[i], L[i + 1], T[i + 1]), (L[i], T[i + 1], T[i])]
        tris += [(T[i], T[i + 1], R[i + 1]), (T[i], R[i + 1], R[i])]
        tris += [(R[i], R[i + 1], L[i + 1]), (R[i], L[i + 1], L[i])]
    tris += [(L[0], T[0], R[0]), (L[-1], R[-1], T[-1])]
    return _clean(Mesh(np.array(tris))).fixed()


def surface_plate(mesh: Mesh, hints, toward, lift=0.16, sink=0.1, bevel=0.7, lifts=None, peak=1.25) -> Mesh:
    """Raised bevelled armour plate / scale / scute hugging the surface of `mesh`.
    `hints` are the plate corners (points outside the surface). `lifts` optionally
    scales the height per corner (tilted, overlapping 'roof tile' scales)."""
    pts, nrms = [], []
    ls = []
    for i, h in enumerate(hints):
        hit = project(mesh, h, toward)
        if hit is None:
            continue
        pts.append(hit[0])
        nrms.append(hit[1])
        ls.append(1.0 if lifts is None else lifts[i])
    if len(pts) < 3:
        return Mesh()
    pts, nrms, ls = np.array(pts), np.array(nrms), np.array(ls)
    n = norm(nrms.mean(axis=0))
    c = pts.mean(axis=0)
    hit = ray_hit(mesh, c + n * 3.0, -n)
    cs = hit[0] if hit is not None else c
    base = pts - nrms * sink
    top = cs + (pts - cs) * bevel + n * (lift * ls)[:, None]
    # keep the top ring above the real surface even on strongly curved bodies
    for i in range(len(top)):
        h2 = ray_hit(mesh, top[i] + n * 3.0, -n)
        if h2 is not None:
            d = (top[i] - h2[0]) @ n
            if d < lift * ls[i] * 0.6:
                top[i] = h2[0] + n * lift * ls[i] * 0.6
    apex = cs + n * lift * peak * ls.mean()
    return hull(np.concatenate([base, top, apex[None]]))


def shard(mesh: Mesh, hint, toward, size=0.3, lift=0.07, sink=0.06, n=4, roll=45.0, stretch=1.0) -> Mesh:
    """Small faceted stud sitting on the surface (rune dot / scale / rivet)."""
    hit = project(mesh, hint, toward)
    if hit is None:
        return Mesh()
    p, nrm = hit
    t, u, v = _frame(nrm, (0, 1, 0))
    ring = [
        p - nrm * sink + u * size / 2 * math.cos(math.radians(roll) + 2 * math.pi * j / n) + v * size / 2 * stretch * math.sin(math.radians(roll) + 2 * math.pi * j / n)
        for j in range(n)
    ]
    tip = p + nrm * lift
    tris = []
    c = p - nrm * sink
    for j in range(n):
        j1 = (j + 1) % n
        tris.append((ring[j], ring[j1], tip))
        tris.append((c, ring[j1], ring[j]))
    return Mesh(np.array(tris)).fixed()


# ----------------------------------------------------------------------
# inverted hull outline
# ----------------------------------------------------------------------
def outline(mesh: Mesh, thickness=0.14, max_miter=2.2) -> Mesh:
    """Black inverted hull: every vertex is pushed out so each adjacent facet plane
    moves by `thickness` (mitred offset), then the faces are flipped."""
    sel = mesh.ow > 0
    tris = mesh.tris[sel]
    ow = mesh.ow[sel]
    if not len(tris):
        return Mesh()
    fn = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
    fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12)
    verts = tris.reshape(-1, 3)
    key = np.round(verts / 2e-4).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    nu = inv.max() + 1
    vn = np.repeat(fn, 3, axis=0)
    vw = np.repeat(ow, 3)
    # normal equations of  n_i . d = 1  for all facets touching the vertex
    A = np.zeros((nu, 3, 3))
    b = np.zeros((nu, 3))
    np.add.at(A, inv, vn[:, :, None] * vn[:, None, :])
    np.add.at(b, inv, vn)
    cnt = np.zeros(nu)
    np.add.at(cnt, inv, 1.0)
    avg = b / np.maximum(np.linalg.norm(b, axis=1, keepdims=True), 1e-9)
    eps = 0.06 * cnt[:, None, None] * np.eye(3)[None]
    d = np.linalg.solve(A + eps, (b + 0.06 * cnt[:, None] * avg)[:, :, None])[:, :, 0]
    l = np.linalg.norm(d, axis=1, keepdims=True)
    d = np.where(l > max_miter, d * (max_miter / np.maximum(l, 1e-9)), d)
    d = np.where(l < 0.5, avg, d)
    wmin = np.full(nu, np.inf)
    np.minimum.at(wmin, inv, vw)
    out = verts + d[inv] * (thickness * wmin[inv])[:, None]
    out = out.reshape(-1, 3, 3)[:, ::-1]
    return Mesh(out, np.zeros((len(out), 3)), np.zeros(len(out)))
