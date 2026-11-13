"""Reusable creature pieces built from the faceted primitives in geo.py."""
from __future__ import annotations

import math

import numpy as np

from geo import Mesh, V, _frame, crack, crystal, gem, hull, norm, project, ray_hit, spike, surface_plate, tube


# ----------------------------------------------------------------------
# Spine: a tube description that also knows how to place details on itself
# ----------------------------------------------------------------------
class Spine:
    """Path + radii of a faceted tube (torso, neck, tail segment, limb).
    Details are placed with (s, angle): s = 0..1 along the path, angle in degrees
    around it (0 = creature's right +X, 90 = up, 180 = left, 270 = down)."""

    def __init__(self, path, radii, n=8, roll=90.0, profile=None, caps=(0.3, 0.3), up=(0, 1, 0), stagger=False):
        self.path = np.asarray(path, float)
        self.radii = [((r, r) if np.isscalar(r) else tuple(r)) for r in radii]
        self.n, self.roll, self.profile, self.caps, self.up, self.stagger = n, roll, profile, caps, up, stagger
        seg = np.linalg.norm(np.diff(self.path, axis=0), axis=1)
        self.cum = np.concatenate([[0.0], np.cumsum(seg)])
        self._mesh = None

    def mesh(self) -> Mesh:
        if self._mesh is None:
            self._mesh = tube(self.path, self.radii, n=self.n, roll=self.roll, profile=self.profile, caps=self.caps, up=self.up, stagger=self.stagger)
        return self._mesh

    def frame(self, s):
        d = float(np.clip(s, 0, 1)) * self.cum[-1]
        i = int(np.clip(np.searchsorted(self.cum, d, side="right") - 1, 0, len(self.path) - 2))
        f = (d - self.cum[i]) / max(self.cum[i + 1] - self.cum[i], 1e-9)
        p = self.path[i] + (self.path[i + 1] - self.path[i]) * f
        rx = self.radii[i][0] + (self.radii[i + 1][0] - self.radii[i][0]) * f
        ry = self.radii[i][1] + (self.radii[i + 1][1] - self.radii[i][1]) * f
        t, u, v = _frame(self.path[i + 1] - self.path[i], self.up)
        if u[0] < -1e-6:  # keep angle 0 on the creature's right whatever the path direction
            u = -u
        return p, t, u, v, rx, ry

    def point(self, s):
        return self.frame(s)[0]

    def hint(self, s, ang, k=2.4):
        p, t, u, v, rx, ry = self.frame(s)
        a = math.radians(ang)
        return p + (u * rx * math.cos(a) + v * ry * math.sin(a)) * k

    def hints(self, pairs, k=2.4):
        return [self.hint(s, a, k) for s, a in pairs]

    def surf(self, s, ang):
        """(point, normal) on the tube surface, or None."""
        return project(self.mesh(), self.hint(s, ang), self.path)

    # ---- detail builders --------------------------------------------
    def crack(self, pairs, width=0.2, **kw) -> Mesh:
        return crack(self.mesh(), self.hints(pairs), toward=self.path, width=width, **kw)

    def plate(self, pairs, **kw) -> Mesh:
        return surface_plate(self.mesh(), self.hints(pairs), self.path, **kw)

    def plates(self, s0, s1, count, a0, a1, gap=0.12, tilt=0.0, lift=0.16, **kw) -> Mesh:
        """Row of plates along the path between angles a0..a1 (belly scutes, back armour)."""
        out = []
        am = (a0 + a1) / 2
        for i in range(count):
            sa = s0 + (s1 - s0) * (i + gap / 2) / count
            sb = s0 + (s1 - s0) * (i + 1 - gap / 2) / count
            sm = (sa + sb) / 2
            pairs = [(sa, a0), (sa, am), (sa, a1), (sm, a1), (sb, a1), (sb, am), (sb, a0), (sm, a0)]
            lifts = [1 - tilt, 1 - tilt, 1 - tilt, 1, 1 + tilt, 1 + tilt, 1 + tilt, 1]
            out.append(self.plate(pairs, lift=lift, lifts=lifts, **kw))
        return Mesh.join(out)

    def spikes(self, ss, sizes, ang=90.0, lean=0.45, thin=0.24, long=0.5, sink=0.22, n=4) -> Mesh:
        """Blade-like spikes standing on the surface, leaning along the path."""
        out = []
        for s, size in zip(ss, sizes):
            hit = self.surf(s, ang)
            if hit is None:
                continue
            p, nrm = hit
            t = self.frame(s)[1]
            d = norm(nrm + t * lean)
            out.append(spike(p - d * sink, p + d * size, (thin * size, long * size), n=n, up=t))
        return Mesh.join(out)

    def studs(self, pairs, size=0.3, lift=0.12, n=4) -> Mesh:
        """Small pyramid studs / scales on the surface."""
        out = []
        for s, a in pairs:
            hit = self.surf(s, a)
            if hit is None:
                continue
            p, nrm = hit
            out.append(spike(p - nrm * 0.08, p + nrm * lift, size / 2, n=n, roll=45))
        return Mesh.join(out)


# ----------------------------------------------------------------------
def limb(p0, p1, r0, r1, n=6, bulge=None, ext=(0.25, 0.25), roll=0.0, up=(0, 1, 0), at=0.45, profile=None) -> Mesh:
    """Tapered limb segment from joint p0 to joint p1, with pointed ends that
    reach past the joints so the parts stay overlapped when they bend."""
    p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
    if bulge is None:
        return tube([p0, p1], [r0, r1], n=n, roll=roll, caps=ext, up=up, profile=profile)
    mid = p0 + (p1 - p0) * at
    return tube([p0, mid, p1], [r0, bulge, r1], n=n, roll=roll, caps=ext, up=up, profile=profile)


def limb_spine(p0, p1, r0, r1, n=6, bulge=None, ext=(0.25, 0.25), at=0.45, roll=0.0, up=(0, 1, 0)) -> Spine:
    p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
    if bulge is None:
        return Spine([p0, p1], [r0, r1], n=n, roll=roll, caps=ext, up=up)
    return Spine([p0, p0 + (p1 - p0) * at, p1], [r0, bulge, r1], n=n, roll=roll, caps=ext, up=up)


def bez(p0, p1, p2, k=6):
    """k+1 points on a quadratic Bezier curve."""
    p0, p1, p2 = (np.asarray(p, float) for p in (p0, p1, p2))
    return [(1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2 for t in np.linspace(0, 1, k + 1)]


def horn(p0, p1, p2, r0, n=5, k=6, ridges=True, tip=0.03, roll=90.0, squash=1.0) -> Mesh:
    """Curved, ridged horn through three control points."""
    pts = bez(p0, p1, p2, k)
    rad = []
    for i in range(k + 1):
        t = i / k
        r = r0 * (1 - t) ** 0.85 + tip
        if ridges and 0 < i < k:
            r *= 1.13 if i % 2 else 0.93
        rad.append((r, r * squash))
    return tube(pts, rad, n=n, roll=roll, caps=(0.1, 0.12))


def toed_paw(ankle, length, width, toes=3, claw=0.6, ground=0.0, heel=0.4, top=0.2, splay=13.0, claw_r=0.17, spur=False):
    """Chunky foot under `ankle` with separate toes pointing to -Z. Returns (foot, claws)."""
    ax, ay, az = (float(x) for x in ankle)
    w, L, g = width, length, ground
    h = ay - g
    pts = []
    for s in (-1, 1):
        pts += [
            (ax + s * w * 0.40, g, az + heel * L),
            (ax + s * w * 0.50, g, az - 0.38 * L),
            (ax + s * w * 0.46, g + h * 0.62, az - 0.42 * L),
            (ax + s * w * 0.36, ay + top, az - 0.26 * L),
            (ax + s * w * 0.34, ay + top, az + 0.30 * L),
            (ax + s * w * 0.42, g + h * 0.45, az + heel * L * 0.9),
        ]
    pts.append((ax, ay + top + 0.15, az))
    parts = [hull(pts)]
    claws = []
    tw = w * (0.5 / toes) * 0.92
    th = h * 0.5 + 0.12
    for i in range(toes):
        k = 0.0 if toes == 1 else (i / (toes - 1) * 2 - 1)
        cx = ax + k * w * (0.5 - 0.5 / toes) * 0.95
        z0, z1 = az - 0.28 * L, az - L
        tp = []
        for s in (-1, 1):
            tp += [
                (cx + s * tw, g, z0),
                (cx + s * tw, g + th, z0 - 0.04 * L),
                (cx + s * tw * 0.92, g + th * 1.12, z0 + (z1 - z0) * 0.5),
                (cx + s * tw * 0.72, g, z1),
                (cx + s * tw * 0.6, g + th * 0.62, z1 - 0.02 * L),
            ]
        toe = hull(tp)
        cl = spike((cx, g + th * 0.5, z1 + 0.12 * L), (cx, g + 0.03, z1 - claw), (claw_r, claw_r * 1.25), n=4, roll=45)
        if toes > 1:
            toe = toe.rot("y", -k * splay, origin=(ax, g, az))
            cl = cl.rot("y", -k * splay, origin=(ax, g, az))
        parts.append(toe)
        claws.append(cl)
    if spur:
        claws.append(spike((ax, g + h * 0.4, az + heel * L * 0.8), (ax, g + 0.05, az + heel * L + claw * 0.8), claw_r, n=4, roll=45))
    return Mesh.join(parts), Mesh.join(claws)


def eye(center, size, axis, up=(0, 1, 0), n=6, socket=1.5, pupil=0.3, slit=True):
    """Glowing gem eye. Returns (socket mesh, glow gem, pupil mesh).
    The socket is a darker faceted rim behind the gem; the pupil is a thin dark slit in front."""
    c = np.asarray(center, float)
    a = norm(axis)
    sx, sy, sz = size
    sock = gem(c - a * sz * 0.35, (sx * socket, sy * socket, sz), n=n, axis=a, up=up, table=0.7)
    g = gem(c, (sx, sy, sz), n=n, axis=a, up=up, table=0.5)
    if slit:
        pu = gem(c + a * sz * 0.42, (sx * pupil * 0.55, sy * 0.78, sz * 0.5), n=4, axis=a, up=up, table=0.3)
    else:
        pu = gem(c + a * sz * 0.42, (sx * pupil, sy * pupil, sz * 0.5), n=5, axis=a, up=up, table=0.4)
    return sock, g, pu


def teeth(a, b, count, length, direction=(0, -1, 0), r=0.1, inset=0.0, big=None) -> Mesh:
    """Row of fang spikes between points a and b. `big` = {index: scale} for oversized fangs."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    d = norm(direction)
    out = []
    for i in range(count):
        u = i / max(count - 1, 1)
        p = a + (b - a) * u
        k = (big or {}).get(i, 1.0) * (1.0 - 0.3 * abs(u - 0.25))
        out.append(spike(p - d * inset, p + d * length * k, r * (0.8 + 0.4 * k), n=4, roll=45))
    return Mesh.join(out)


def crystal_cluster(base, specs, n=5) -> Mesh:
    """Group of crystals growing from `base`. specs: [(dir_xyz, length, radius), ...]."""
    base = np.asarray(base, float)
    out = []
    for i, (d, ln, r) in enumerate(specs):
        d = norm(d)
        out.append(crystal(base - d * ln * 0.18, base + d * ln, r, n=n, waist=0.3, roll=17 * i))
    return Mesh.join(out)


def surface_top(mesh: Mesh, x, z, y_from=80.0):
    hit = ray_hit(mesh, (x, y_from, z), (0, -1, 0))
    return None if hit is None else hit[0]


def both(mesh: Mesh) -> Mesh:
    """Left-side mesh + its mirrored twin."""
    return mesh + mesh.mirror()


def cute_eye(mesh: Mesh, hint, toward, w, h, n=8, look=(0.0, 0.0), iris=0.66, pupil=0.4, depth=0.36):
    """Big friendly cartoon eye lying on the surface of `mesh`.
    Returns (white, iris, pupil, highlight): the white, pupil and highlight belong to the head,
    the iris is the glowing 'Eyes' mesh. `look` shifts the iris (fractions of w / h)."""
    hit = project(mesh, hint, toward)
    assert hit is not None, "cute_eye: hint does not hit the surface"
    p, nrm = hit
    t, u, v = _frame(nrm, (0, 1, 0))
    roll = 180.0 / n
    c0 = p + nrm * 0.03
    white = gem(c0, (w, h, depth), n=n, axis=nrm, table=0.84, roll=roll)
    ci = c0 + nrm * (depth * 0.5) + u * look[0] * w + v * look[1] * h
    iris_m = gem(ci, (w * iris, h * iris, depth * 0.6), n=n, axis=nrm, table=0.8, roll=roll)
    cp = ci + nrm * (depth * 0.34)
    pupil_m = gem(cp, (w * pupil, h * pupil * 1.12, depth * 0.4), n=6, axis=nrm, table=0.75)
    ch = cp + nrm * (depth * 0.22) + v * h * 0.17 + u * w * 0.13 * (1 if u[0] > 0 else -1)
    hl = gem(ch, (w * 0.2, h * 0.2, depth * 0.3), n=4, axis=nrm, table=0.6, roll=45)
    return white, iris_m, pupil_m, hl


def face_eyes(mesh: Mesh, hint, toward, w, h, iris_color, look=(0.0, 0.0), dark=(0.07, 0.06, 0.1), **kw):
    """Left eye built from a left-side hint, mirrored to the right.
    Returns (head_mesh_part, glow_mesh): add the first to the Head, use the second as 'Eyes'."""
    white, ir, pu, hl = cute_eye(mesh, hint, toward, w, h, look=look, **kw)
    wcol, wl = np.array([1.0, 1.0, 1.0]), np.array([0.9, 0.94, 1.0])
    head_part = (both(white).shade(wcol, wcol, wl, seed="eye.white", jitter=0.3).weight(0.7)
                 + both(pu).paint(dark).weight(0) + both(hl).paint((1, 1, 1)).weight(0))
    ic = np.asarray(iris_color, float)
    glow = both(ir).shade(ic, np.minimum(ic * 1.25 + 0.1, 1.0), ic * 0.9, seed="eye.iris", jitter=0.6)
    return head_part, glow


def brow(inner, outer, thick=0.38, depth=0.5, rise=0.0):
    """Chunky eyebrow wedge from `inner` (near the nose) to `outer` (points in world space, left side)."""
    a, b = np.asarray(inner, float), np.asarray(outer, float)
    up = V(0, thick, 0)
    back = V(0, 0, depth)
    return hull([a, b, a + up * 0.8, b + up + V(0, rise, 0), a + back, b + back, a + back + up * 0.8, b + back + up])


def fangs(points, length, r, direction=(0, -1, 0)) -> Mesh:
    """A few big chunky cartoon teeth at explicit points."""
    d = norm(direction)
    return Mesh.join([spike(np.asarray(p, float) - d * 0.12, np.asarray(p, float) + d * length, r, n=4, roll=45) for p in points])
