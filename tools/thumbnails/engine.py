"""Piccolo motore di rendering software (solo numpy) per le immagini promozionali del gioco.

Rasterizzazione vettoriale con z-buffer, ombre del sole (shadow map), materiali procedurali
(pietra delle mura, intonaco, tegole, terreno), texture del gigante, cielo con nuvole,
nebbia atmosferica, raggi di luce, bloom, vapore, cavi dei rampini e correzione colore.
"""
import math

import numpy as np
from PIL import Image, ImageFilter

# ---------------------------------------------------------------------------------------------
# Matematica
# ---------------------------------------------------------------------------------------------


def normalize(v):
    v = np.asarray(v, dtype=np.float64)
    n = np.linalg.norm(v, axis=-1, keepdims=True)
    return v / np.maximum(n, 1e-12)


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------------------------------------
# Rumore (value noise 3D e fbm)
# ---------------------------------------------------------------------------------------------


def _hash(ix, iy, iz, seed=0):
    h = (ix.astype(np.int64) * 73856093) ^ (iy.astype(np.int64) * 19349663) ^ (iz.astype(np.int64) * 83492791) ^ (seed * 2654435761)
    h = h & 0xFFFFFFFF
    h = ((h >> 16) ^ h) * 0x45D9F3B & 0xFFFFFFFF
    h = ((h >> 16) ^ h) * 0x45D9F3B & 0xFFFFFFFF
    h = (h >> 16) ^ h
    return (h & 0xFFFF).astype(np.float64) / 65535.0


def vnoise(p, seed=0):
    p = np.asarray(p, dtype=np.float64)
    i = np.floor(p)
    f = p - i
    u = f * f * (3 - 2 * f)
    ix, iy, iz = i[..., 0], i[..., 1], i[..., 2]
    res = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (u[..., 0] if dx else 1 - u[..., 0]) * (u[..., 1] if dy else 1 - u[..., 1]) * (u[..., 2] if dz else 1 - u[..., 2])
                res = res + w * _hash(ix + dx, iy + dy, iz + dz, seed)
    return res


def fbm(p, octaves=4, seed=0, lac=2.03, gain=0.5):
    total = 0
    amp = 0.5
    norm = 0
    q = np.asarray(p, dtype=np.float64)
    for o in range(octaves):
        total = total + amp * vnoise(q, seed + o * 17)
        norm += amp
        q = q * lac
        amp *= gain
    return total / norm


# ---------------------------------------------------------------------------------------------
# Geometria
# ---------------------------------------------------------------------------------------------

# materiali
M_TEX, M_COLOR, M_STONE, M_PLASTER, M_ROOF, M_GROUND, M_METAL, M_WOOD, M_SKIN, M_CLOTH, M_WATER, M_GLOW, M_FACE = range(13)


class Scene:
    def __init__(self):
        self.V = []  # vertici
        self.N = []  # normali per vertice
        self.UV = []
        self.C = []  # colore per vertice
        self.F = []  # facce
        self.M = []  # materiale per faccia
        self.count = 0
        self.texture = None
        self.face_tex = None
        self.particles = []  # (pos, radius, color, alpha, seed)
        self.lines = []  # (a, b, width_px, color)

    def add(self, V, F, mat, color=(1, 1, 1), N=None, UV=None, C=None, smooth=True):
        V = np.asarray(V, dtype=np.float64)
        F = np.asarray(F, dtype=np.int64)
        if N is None:
            N = vertex_normals(V, F) if smooth else None
        if N is None:  # normali piatte: duplica i vertici
            V = V[F].reshape(-1, 3)
            F = np.arange(len(V)).reshape(-1, 3)
            fn = normalize(np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]]))
            N = np.repeat(fn, 3, axis=0)
            if UV is not None:
                UV = np.asarray(UV)
            if C is not None:
                C = np.asarray(C)
        if UV is None:
            UV = np.zeros((len(V), 2))
        if C is None:
            C = np.tile(np.asarray(color, dtype=np.float64), (len(V), 1))
        self.V.append(V)
        self.N.append(np.asarray(N, dtype=np.float64))
        self.UV.append(np.asarray(UV, dtype=np.float64))
        self.C.append(np.asarray(C, dtype=np.float64))
        self.F.append(F + self.count)
        self.M.append(np.full(len(F), mat, dtype=np.int64))
        self.count += len(V)

    def arrays(self):
        return (np.concatenate(self.V), np.concatenate(self.N), np.concatenate(self.UV), np.concatenate(self.C), np.concatenate(self.F), np.concatenate(self.M))


def vertex_normals(V, F):
    fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
    N = np.zeros_like(V)
    for k in range(3):
        np.add.at(N, F[:, k], fn)
    return normalize(N)


def grid_quad(origin, du, dv, nu, nv):
    """Quad suddiviso (origin + u*du + v*dv), restituisce V, F (normali piatte)."""
    us = np.linspace(0, 1, nu + 1)
    vs = np.linspace(0, 1, nv + 1)
    uu, vv = np.meshgrid(us, vs, indexing="ij")
    V = np.asarray(origin) + uu[..., None] * np.asarray(du) + vv[..., None] * np.asarray(dv)
    V = V.reshape(-1, 3)
    F = []
    for i in range(nu):
        for j in range(nv):
            a = i * (nv + 1) + j
            b = (i + 1) * (nv + 1) + j
            F.append((a, b, b + 1))
            F.append((a, b + 1, a + 1))
    return V, np.array(F)


def add_box(scene, center, size, mat, color=(1, 1, 1), R=None, seg=1.0):
    """Scatola con facce suddivise (seg = lato massimo dei triangoli, in metri)."""
    c = np.asarray(center, dtype=np.float64)
    sx, sy, sz = [s / 2 for s in size]
    R = np.eye(3) if R is None else R
    faces = [
        ((-sx, -sy, sz), (2 * sx, 0, 0), (0, 2 * sy, 0)),  # +Z
        ((sx, -sy, -sz), (-2 * sx, 0, 0), (0, 2 * sy, 0)),  # -Z
        ((sx, -sy, sz), (0, 0, -2 * sz), (0, 2 * sy, 0)),  # +X
        ((-sx, -sy, -sz), (0, 0, 2 * sz), (0, 2 * sy, 0)),  # -X
        ((-sx, sy, sz), (2 * sx, 0, 0), (0, 0, -2 * sz)),  # +Y
        ((-sx, -sy, -sz), (2 * sx, 0, 0), (0, 0, 2 * sz)),  # -Y
    ]
    for o, du, dv in faces:
        o, du, dv = np.array(o), np.array(du), np.array(dv)
        nu = max(1, int(math.ceil(np.linalg.norm(du) / seg)))
        nv = max(1, int(math.ceil(np.linalg.norm(dv) / seg)))
        V, F = grid_quad(o, du, dv, nu, nv)
        V = V @ R.T + c
        scene.add(V, F, mat, color, smooth=False)


def add_cylinder(scene, a, b, r, mat, color=(1, 1, 1), n=12, caps=True):
    a, b = np.asarray(a, float), np.asarray(b, float)
    axis = normalize(b - a)
    t = normalize(np.cross(axis, [0, 1, 0] if abs(axis[1]) < 0.9 else [1, 0, 0]))
    s = np.cross(axis, t)
    ang = np.linspace(0, 2 * math.pi, n, endpoint=False)
    ring = np.cos(ang)[:, None] * t + np.sin(ang)[:, None] * s
    V = np.concatenate([a + r * ring, b + r * ring])
    N = np.concatenate([ring, ring])
    F = []
    for i in range(n):
        j = (i + 1) % n
        F += [(i, j, n + j), (i, n + j, n + i)]
    scene.add(V, np.array(F), mat, color, N=N)
    if caps:
        for p, sgn in ((a, -1), (b, 1)):
            Vc = np.concatenate([[p], p + r * ring])
            Fc = [(0, 1 + (i + 1) % n, 1 + i) if sgn < 0 else (0, 1 + i, 1 + (i + 1) % n) for i in range(n)]
            scene.add(Vc, np.array(Fc), mat, color, N=np.tile(axis * sgn, (n + 1, 1)))


def add_sphere(scene, c, r, mat, color=(1, 1, 1), n=14, scale=(1, 1, 1), R=None):
    lat = np.linspace(0, math.pi, n + 1)
    lon = np.linspace(0, 2 * math.pi, 2 * n, endpoint=False)
    L, O = np.meshgrid(lat, lon, indexing="ij")
    P = np.stack([np.sin(L) * np.cos(O), np.cos(L), np.sin(L) * np.sin(O)], -1).reshape(-1, 3)
    m = 2 * n
    F = []
    for i in range(n):
        for j in range(m):
            a = i * m + j
            b = i * m + (j + 1) % m
            F += [(a, b, b + m), (a, b + m, a + m)]
    R = np.eye(3) if R is None else R
    V = (P * np.asarray(scale) * r) @ R.T + c
    N = normalize((P / np.asarray(scale)) @ R.T)
    scene.add(V, np.array(F), mat, color, N=N)


# ---------------------------------------------------------------------------------------------
# Telecamera e rasterizzazione
# ---------------------------------------------------------------------------------------------


class Camera:
    def __init__(self, pos, target, fov_deg, width, height, roll=0.0):
        self.pos = np.asarray(pos, float)
        f = normalize(np.asarray(target, float) - self.pos)
        r = normalize(np.cross(f, [0, 1, 0]))
        u = np.cross(r, f)
        if roll:
            c, s = math.cos(roll), math.sin(roll)
            r, u = r * c + u * s, -r * s + u * c
        self.f, self.r, self.u = f, r, u
        self.w, self.h = width, height
        self.focal = (height / 2) / math.tan(math.radians(fov_deg) / 2)

    def to_view(self, P):
        d = P - self.pos
        return np.stack([d @ self.r, d @ self.u, d @ self.f], -1)

    def project(self, P):
        v = self.to_view(P)
        z = v[..., 2]
        zs = np.where(z > 1e-3, z, 1e-3)
        x = self.w / 2 + v[..., 0] * self.focal / zs
        y = self.h / 2 - v[..., 1] * self.focal / zs
        return np.stack([x, y, z], -1)

    def ray_dirs(self):
        ys, xs = np.mgrid[0 : self.h, 0 : self.w].astype(np.float64)
        dx = (xs + 0.5 - self.w / 2) / self.focal
        dy = -(ys + 0.5 - self.h / 2) / self.focal
        d = dx[..., None] * self.r + dy[..., None] * self.u + self.f
        return normalize(d)


def rasterize(S, F, W, H, near=0.05, cull=False, want_bary=True):
    """S: (n,3) vertici in schermo (x, y, z vista). Restituisce depth, tri id, bary (prospettiche)."""
    depth = np.full(H * W, np.inf)
    tri = np.full(H * W, -1, dtype=np.int64)
    bary = np.zeros((H * W, 2)) if want_bary else None
    p0, p1, p2 = S[F[:, 0]], S[F[:, 1]], S[F[:, 2]]
    ok = (p0[:, 2] > near) & (p1[:, 2] > near) & (p2[:, 2] > near)
    area = (p1[:, 0] - p0[:, 0]) * (p2[:, 1] - p0[:, 1]) - (p1[:, 1] - p0[:, 1]) * (p2[:, 0] - p0[:, 0])
    if cull:
        ok &= area < 0  # in schermo la Y va in basso: le facce verso la telecamera hanno area negativa
    else:
        ok &= np.abs(area) > 1e-9
    xmin = np.floor(np.minimum(np.minimum(p0[:, 0], p1[:, 0]), p2[:, 0]))
    xmax = np.ceil(np.maximum(np.maximum(p0[:, 0], p1[:, 0]), p2[:, 0]))
    ymin = np.floor(np.minimum(np.minimum(p0[:, 1], p1[:, 1]), p2[:, 1]))
    ymax = np.ceil(np.maximum(np.maximum(p0[:, 1], p1[:, 1]), p2[:, 1]))
    xmin = np.clip(xmin, 0, W)
    ymin = np.clip(ymin, 0, H)
    xmax = np.clip(xmax, 0, W)
    ymax = np.clip(ymax, 0, H)
    ok &= (xmax > xmin) & (ymax > ymin)
    idx = np.nonzero(ok)[0]
    bw = (xmax - xmin)[idx]
    bh = (ymax - ymin)[idx]
    size = np.maximum(bw, bh)
    buckets = [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 4096]
    lo = 0
    for k in buckets:
        sel = idx[(size > lo) & (size <= k)]
        lo = k
        if len(sel) == 0:
            continue
        chunk = max(1, 3_000_000 // (k * k))
        for c0 in range(0, len(sel), chunk):
            t = sel[c0 : c0 + chunk]
            ox = np.arange(k)
            gx = xmin[t][:, None, None] + ox[None, None, :]
            gy = ymin[t][:, None, None] + ox[None, :, None]
            gx = np.broadcast_to(gx, (len(t), k, k)).reshape(len(t), -1)
            gy = np.broadcast_to(gy, (len(t), k, k)).reshape(len(t), -1)
            inside = (gx < xmax[t][:, None]) & (gy < ymax[t][:, None])
            px = gx + 0.5
            py = gy + 0.5
            a0, a1, a2 = p0[t], p1[t], p2[t]
            ar = area[t][:, None]
            w0 = ((a1[:, 0, None] - px) * (a2[:, 1, None] - py) - (a1[:, 1, None] - py) * (a2[:, 0, None] - px)) / ar
            w1 = ((a2[:, 0, None] - px) * (a0[:, 1, None] - py) - (a2[:, 1, None] - py) * (a0[:, 0, None] - px)) / ar
            w2 = 1 - w0 - w1
            eps = -1e-7
            inside &= (w0 >= eps) & (w1 >= eps) & (w2 >= eps)
            if not inside.any():
                continue
            rows, cols = np.nonzero(inside)
            tt = t[rows]
            w0 = w0[rows, cols]
            w1 = w1[rows, cols]
            w2 = w2[rows, cols]
            z0, z1, z2 = p0[tt, 2], p1[tt, 2], p2[tt, 2]
            invz = w0 / z0 + w1 / z1 + w2 / z2
            z = 1 / invz
            pix = (gy[rows, cols] * W + gx[rows, cols]).astype(np.int64)
            # minimo per pixel
            order = np.lexsort((z, pix))
            pix_s = pix[order]
            first = np.ones(len(pix_s), bool)
            first[1:] = pix_s[1:] != pix_s[:-1]
            o = order[first]
            pix_u = pix[o]
            z_u = z[o]
            better = z_u < depth[pix_u]
            o = o[better]
            pix_u = pix_u[better]
            depth[pix_u] = z[o]
            tri[pix_u] = tt[o]
            if want_bary:
                b0 = (w0[o] / z0[o]) * z[o]
                b1 = (w1[o] / z1[o]) * z[o]
                bary[pix_u, 0] = b0
                bary[pix_u, 1] = b1
    return depth.reshape(H, W), tri.reshape(H, W), (bary.reshape(H, W, 2) if want_bary else None)


# ---------------------------------------------------------------------------------------------
# Materiali procedurali
# ---------------------------------------------------------------------------------------------


def tex_sample(tex, uv):
    h, w = tex.shape[:2]
    u = np.mod(uv[..., 0], 1.0) * (w - 1)
    v = (1 - np.mod(uv[..., 1], 1.0)) * (h - 1)
    x0 = np.floor(u).astype(int)
    y0 = np.floor(v).astype(int)
    x1 = np.minimum(x0 + 1, w - 1)
    y1 = np.minimum(y0 + 1, h - 1)
    fx = (u - x0)[..., None]
    fy = (v - y0)[..., None]
    c = tex[y0, x0] * (1 - fx) * (1 - fy) + tex[y0, x1] * fx * (1 - fy) + tex[y1, x0] * (1 - fx) * fy + tex[y1, x1] * fx * fy
    return c


def face_uv(P, N):
    """Coordinate (u, v) sulla superficie: v = altezza, u = lungo la parete."""
    ax = np.abs(N)
    use_x = ax[:, 2] >= ax[:, 0]
    u = np.where(use_x, P[:, 0], P[:, 2])
    v = P[:, 1]
    top = ax[:, 1] > 0.7
    u = np.where(top, P[:, 0], u)
    v = np.where(top, P[:, 2], v)
    return u, v


def mat_stone(P, N, base):
    u, v = face_uv(P, N)
    bh, bw = 1.1, 2.3
    row = np.floor(v / bh)
    uu = u / bw + 0.5 * (row % 2)
    col = np.floor(uu)
    fu = uu - col
    fv = v / bh - row
    mortar = np.minimum(np.minimum(fu, 1 - fu) * bw, np.minimum(fv, 1 - fv) * bh)
    mort = smoothstep(0.02, 0.09, mortar)
    blockvar = vnoise(np.stack([col * 1.7, row * 1.3, col * 0.3 + row], -1), seed=3)
    detail = fbm(P * np.array([1.6, 1.6, 1.6]), 4, seed=5)
    streak = fbm(np.stack([u * 0.25, v * 0.02, u * 0.1], -1), 3, seed=9)
    base = np.asarray(base)
    c = base * (0.72 + 0.4 * blockvar[:, None]) * (0.8 + 0.4 * detail[:, None])
    c = c * (1 - 0.35 * smoothstep(0.55, 0.85, streak)[:, None])
    moss = smoothstep(0.6, 0.0, v - np.min(v) * 0 - 0) if False else None
    c = c * (0.45 + 0.55 * mort[:, None])
    return c


def mat_plaster(P, N, base, seed=0):
    u, v = face_uv(P, N)
    detail = fbm(P * 0.9, 4, seed=11 + seed)
    grime = fbm(np.stack([u * 0.3, v * 0.6, u * 0.2], -1), 3, seed=21)
    c = np.asarray(base) * (0.82 + 0.3 * detail[:, None]) * (1 - 0.25 * smoothstep(0.5, 0.8, grime)[:, None])
    # travi di legno (piani ogni 3.2 m) e finestre
    floor_line = np.abs(((v + 0.15) % 3.2) - 0.0) < 0.28
    wood = np.array([0.20, 0.12, 0.07])
    win_u = np.mod(u, 3.0)
    win_v = np.mod(v, 3.2)
    window = (win_u > 1.0) & (win_u < 2.0) & (win_v > 1.0) & (win_v < 2.5) & (np.abs(N[:, 1]) < 0.5)
    frame = (win_u > 0.85) & (win_u < 2.15) & (win_v > 0.85) & (win_v < 2.65) & ~window & (np.abs(N[:, 1]) < 0.5)
    c = np.where((floor_line & (np.abs(N[:, 1]) < 0.5))[:, None], wood * (0.8 + 0.4 * detail[:, None]), c)
    c = np.where(frame[:, None], wood * 0.9, c)
    glass = np.array([0.05, 0.06, 0.08]) + 0.08 * fbm(P * 3, 2, seed=4)[:, None]
    c = np.where(window[:, None], glass, c)
    return c


def mat_roof(P, N, base):
    # tegole: righe lungo la pendenza
    along = P[:, 0] + P[:, 2] * 0.0
    down = P[:, 1] * 2.2
    row = np.floor(down)
    fv = down - row
    tile = np.floor(P[:, 0] * 2.5 + P[:, 2] * 2.5 + 0.5 * (row % 2))
    var = vnoise(np.stack([tile, row, tile * 0.5], -1), seed=7)
    detail = fbm(P * 1.3, 3, seed=8)
    c = np.asarray(base) * (0.7 + 0.45 * var[:, None]) * (0.8 + 0.35 * detail[:, None])
    c = c * (0.55 + 0.45 * smoothstep(0.0, 0.25, fv)[:, None])
    return c


def mat_ground(P, N, base):
    d1 = fbm(P * np.array([0.03, 0.03, 0.03]), 5, seed=31)
    d2 = fbm(P * 0.9, 3, seed=33)
    d3 = fbm(P * 0.25, 3, seed=35)
    grass = np.array([0.20, 0.30, 0.11]) * (0.8 + 0.4 * d3[:, None])
    dirt = np.asarray(base)
    k = smoothstep(0.38, 0.55, d1)[:, None]
    c = dirt * (1 - k) + grass * k
    sand = np.array([0.72, 0.64, 0.48])
    beach = smoothstep(1.2, -0.5, P[:, 1])[:, None] * (np.abs(P[:, 1]) > 0.05)[:, None]
    c = c * (1 - beach) + sand * beach
    return c * (0.75 + 0.5 * d2[:, None])


def voronoi2(q, seed=0):
    """Distanze dal punto più vicino (F1) e dal secondo (F2) su una griglia con punti a caso."""
    cell = np.floor(q)
    f1 = np.full(len(q), 9.0)
    f2 = np.full(len(q), 9.0)
    idc = np.zeros((len(q), 2))
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            c = cell + np.array([dx, dy])
            jx = _hash(c[:, 0], c[:, 1], np.zeros(len(q)), seed)
            jy = _hash(c[:, 0], c[:, 1], np.ones(len(q)), seed)
            pt = c + 0.15 + 0.7 * np.stack([jx, jy], -1)
            d = np.linalg.norm(q - pt, axis=1)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            idc = np.where(closer[:, None], c, idc)
            f1 = np.where(closer, d, f1)
    return f1, f2, idc


def mat_cobble(P, N, base):
    q = P[:, [0, 2]] / 0.55
    f1, f2, idc = voronoi2(q, seed=5)
    edge = f2 - f1
    var = _hash(idc[:, 0], idc[:, 1], np.full(len(q), 3.0), 9)
    detail = fbm(P * 2.5, 3, seed=43)
    dirt = fbm(P * 0.12, 4, seed=44)
    c = np.asarray(base) * (0.65 + 0.55 * var[:, None]) * (0.8 + 0.35 * detail[:, None])
    c = c * (0.35 + 0.65 * smoothstep(0.03, 0.22, edge)[:, None])
    mud = np.array([0.30, 0.24, 0.17])
    k = smoothstep(0.5, 0.75, dirt)[:, None] * 0.6
    return c * (1 - k) + mud * k


# ---------------------------------------------------------------------------------------------
# Render completo
# ---------------------------------------------------------------------------------------------


class Look:
    """Impostazioni di luce e atmosfera."""

    def __init__(self, **kw):
        self.sun_dir = normalize(kw.get("sun_dir", (0.4, 0.25, 0.8)))
        self.sun_col = np.array(kw.get("sun_col", (2.3, 1.7, 1.15)))
        self.sky_top = np.array(kw.get("sky_top", (0.18, 0.28, 0.55)))
        self.sky_hor = np.array(kw.get("sky_hor", (1.0, 0.62, 0.38)))
        self.sky_amb = np.array(kw.get("sky_amb", (0.30, 0.34, 0.46)))
        self.ground_amb = np.array(kw.get("ground_amb", (0.20, 0.15, 0.11)))
        self.fog_density = kw.get("fog_density", 0.0035)
        self.fog_height = kw.get("fog_height", 60.0)
        self.cloud_cover = kw.get("cloud_cover", 0.5)
        self.cloud_col = np.array(kw.get("cloud_col", (1.0, 0.72, 0.55)))
        self.cloud_dark = np.array(kw.get("cloud_dark", (0.30, 0.25, 0.30)))
        self.exposure = kw.get("exposure", 1.0)
        self.rays = kw.get("rays", 0.35)
        self.bloom = kw.get("bloom", 0.35)
        self.saturation = kw.get("saturation", 1.08)
        self.vignette = kw.get("vignette", 0.35)
        self.ground_mat = kw.get("ground_mat", "ground")
        self.shadow_extent = kw.get("shadow_extent", 220.0)
        self.shadow_center = np.array(kw.get("shadow_center", (0.0, 0.0, 0.0)))
        self.sun_disk = kw.get("sun_disk", True)
        self.lightning = kw.get("lightning", None)  # lista di punti (x,y) in pixel per fulmini
        self.dof = kw.get("dof", None)  # (distanza a fuoco, forza): sfoca lo sfondo come una fotocamera


def sky_color(D, look, seed=0):
    up = np.clip(D[..., 1], -1, 1)
    t = np.clip(up, 0, 1) ** 0.45
    sky = look.sky_hor * (1 - t[..., None]) + look.sky_top * t[..., None]
    mu = np.clip(np.sum(D * look.sun_dir, -1), -1, 1)
    glow = np.exp((mu - 1) * 8)[..., None] * look.sun_col * 0.18 + np.exp((mu - 1) * 60)[..., None] * look.sun_col * 0.35
    sky = sky + glow * (1 - 0.3 * t[..., None])
    if look.sun_disk:
        disk = smoothstep(0.99955, 0.99975, mu)[..., None]
        sky = sky + disk * look.sun_col * 4
    # nuvole su un piano alto
    h = np.maximum(up, 0.03)
    q = D[..., [0, 2]] / h[..., None] * 0.9
    p3 = np.stack([q[..., 0] * 0.6, q[..., 1] * 1.6, np.zeros_like(q[..., 0]) + seed], -1)
    n = fbm(p3, 6, seed=101 + seed)
    cover = look.cloud_cover
    dens = smoothstep(1 - cover - 0.05, 1 - cover + 0.35, n)
    # parte illuminata verso il sole, scura dall'altra parte
    n2 = fbm(p3 + np.array([0.06, 0.0, 0.0]) * (D[..., [0]] if False else 1), 6, seed=101 + seed)
    lit = np.clip(0.55 + 2.5 * (n - n2) + 0.5 * mu, 0, 1)[..., None]
    ccol = look.cloud_dark * (1 - lit) + look.cloud_col * lit
    ccol = ccol + np.exp((mu - 1) * 12)[..., None] * look.sun_col * 0.25
    fade = smoothstep(0.0, 0.12, up)[..., None]
    a = (dens * 0.95)[..., None] * fade
    sky = sky * (1 - a) + ccol * a
    return sky


def render(scene, cam, look, ss=2, shadows=True, extra_post=None, particle_light=1.0):
    W, H = cam.w, cam.h
    V, N, UV, C, F, M = scene.arrays()
    S = cam.project(V)
    print(f"  triangoli: {len(F)}")
    depth, tri, bary = rasterize(S, F, W, H)
    D = cam.ray_dirs()
    img = sky_color(D, look)
    hit = tri >= 0
    ti = tri[hit]
    b = bary[hit]
    bw = np.stack([b[:, 0], b[:, 1], 1 - b[:, 0] - b[:, 1]], -1)
    fv = F[ti]

    def interp(A):
        return A[fv[:, 0]] * bw[:, 0:1] + A[fv[:, 1]] * bw[:, 1:2] + A[fv[:, 2]] * bw[:, 2:3]

    P = interp(V)
    Nn = normalize(interp(N))
    view = normalize(cam.pos - P)
    flip = np.sum(Nn * view, -1) < 0
    Nn[flip] *= -1
    mat = M[ti]
    col = interp(C)
    alb = col.copy()
    sel = mat == M_TEX
    if sel.any() and scene.texture is not None:
        alb[sel] = tex_sample(scene.texture, interp(UV)[sel]) * col[sel]
    sel = mat == M_STONE
    if sel.any():
        alb[sel] = mat_stone(P[sel], Nn[sel], col[sel])
    sel = mat == M_PLASTER
    if sel.any():
        alb[sel] = mat_plaster(P[sel], Nn[sel], col[sel])
    sel = mat == M_ROOF
    if sel.any():
        alb[sel] = mat_roof(P[sel], Nn[sel], col[sel])
    sel = mat == M_GROUND
    if sel.any():
        alb[sel] = (mat_cobble if look.ground_mat == "cobble" else mat_ground)(P[sel], Nn[sel], col[sel])
    sel = mat == M_WOOD
    if sel.any():
        g = fbm(P[sel] * np.array([0.6, 6.0, 0.6]), 3, seed=51)
        alb[sel] = col[sel] * (0.7 + 0.5 * g[:, None])
    sel = mat == M_FACE
    if sel.any() and scene.face_tex is not None:
        uv = interp(UV)[sel]
        front = uv[:, 0] < 2
        rgba = tex_sample(scene.face_tex, np.clip(uv, 0.001, 0.999))
        a = (rgba[:, 3] * front)[:, None]
        alb[sel] = col[sel] * (1 - a) + rgba[:, :3] * a
    sel = (mat == M_CLOTH) | (mat == M_SKIN)
    if sel.any():
        g = fbm(P[sel] * 8, 2, seed=61)
        alb[sel] = col[sel] * (0.88 + 0.2 * g[:, None])

    # ombre
    shade = np.ones(len(P))
    if shadows:
        shade = shadow_factor(V, F, P, Nn, look)
    L = look.sun_dir
    ndl = np.clip(np.sum(Nn * L, -1), 0, 1)
    # luce ambiente emisferica + occlusione semplice verso il basso
    hemi = (Nn[:, 1:2] * 0.5 + 0.5)
    amb = look.ground_amb * (1 - hemi) + look.sky_amb * hemi
    occ = 0.55 + 0.45 * smoothstep(-0.5, 2.5, P[:, 1:2] - 0.0)
    occ = np.where((mat == M_TEX)[:, None], 1.0, occ)
    Hh = normalize(L + view)
    ndh = np.clip(np.sum(Nn * Hh, -1), 0, 1)
    spec_k = np.select([mat == M_METAL, mat == M_TEX, mat == M_SKIN, mat == M_FACE, mat == M_ROOF], [1.4, 0.10, 0.12, 0.18, 0.05], 0.03)
    shin = np.select([mat == M_METAL, mat == M_TEX, mat == M_SKIN, mat == M_FACE], [120.0, 18.0, 24.0, 30.0], 10.0)
    spec = (spec_k * ndh ** shin * ndl * shade)[:, None] * look.sun_col
    rim = (np.clip(1 - np.sum(Nn * view, -1), 0, 1) ** 3 * 0.6 * np.clip(-np.sum(view * L, -1) * 0.5 + 0.5, 0, 1))[:, None]
    rim = rim * look.sun_col * np.where(np.isin(mat, [M_TEX, M_SKIN, M_FACE, M_CLOTH, M_COLOR, M_METAL]), 1.0, 0.25)[:, None]
    metal_env = np.where((mat == M_METAL)[:, None], look.sky_amb * 1.5, 0)
    lit = alb * ((ndl * shade)[:, None] * look.sun_col + amb * occ) + spec + rim * alb.mean(-1, keepdims=True) * 1.2 + metal_env * 0.3
    # nebbia
    dist = depth[hit]
    fog = fog_amount(cam.pos, P, dist, look)
    fogc = sky_color(normalize(P - cam.pos) * np.array([1, 0, 1]) + np.array([0, 0.02, 0]), look)
    fogc = fogc * 0.85 + look.sky_hor * 0.15
    lit = lit * (1 - fog[:, None]) + fogc * fog[:, None]
    sel = mat == M_WATER
    if sel.any():
        Pw = P[sel]
        nx = fbm(Pw * np.array([0.05, 0, 0.11]), 4, seed=71) - 0.5
        nz = fbm(Pw * np.array([0.11, 0, 0.05]), 4, seed=73) - 0.5
        dist_w = np.linalg.norm(Pw - cam.pos, axis=1)
        amp = 0.16 / (1 + dist_w / 400)
        Nw = normalize(np.stack([nx * amp, np.ones(len(Pw)), nz * amp], -1))
        vd = -view[sel]
        refl = vd - 2 * np.sum(vd * Nw, -1, keepdims=True) * Nw
        refl[:, 1] = np.abs(refl[:, 1])
        skyc = sky_color(normalize(refl), look)
        cosv = np.clip(np.sum(view[sel] * Nw, -1), 0, 1)
        fres = (0.04 + 0.96 * (1 - cosv) ** 5)[:, None]
        deep = col[sel] * (look.sky_amb * 1.2 + look.sun_col * 0.12)
        sun_spec = np.clip(np.sum(normalize(refl) * look.sun_dir, -1), 0, 1) ** 300 * 6
        wl = deep * (1 - fres) + skyc * fres * 0.9 + sun_spec[:, None] * look.sun_col
        wl = wl * (1 - fog[sel][:, None]) + fogc[sel] * fog[sel][:, None]
        lit[sel] = wl
    sel = mat == M_GLOW
    if sel.any():
        lit[sel] = col[sel]
    img[hit] = lit
    if extra_post:
        img = extra_post(img, depth, cam)
    img = draw_particles(img, depth, cam, scene.particles, look, particle_light)
    img = draw_lines(img, depth, cam, scene.lines, look)
    img = post(img, depth, cam, look)
    out = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
    if ss > 1:
        out = out.resize((W // ss, H // ss), Image.LANCZOS)
    return out


def fog_amount(campos, P, dist, look):
    dens = look.fog_density * np.exp(-np.maximum(P[:, 1], 0) / look.fog_height)
    return 1 - np.exp(-dist * dens)


def shadow_factor(V, F, P, Nn, look, res=3072):
    L = look.sun_dir
    up = np.array([0, 1, 0]) if abs(L[1]) < 0.95 else np.array([1, 0, 0])
    r = normalize(np.cross(up, L))
    u = np.cross(L, r)
    ext = look.shadow_extent
    c = look.shadow_center

    def proj(X):
        d = X - c
        x = (d @ r / ext * 0.5 + 0.5) * res
        y = (0.5 - d @ u / ext * 0.5) * res
        z = 2000 - d @ L
        return np.stack([x, y, z], -1)

    S = proj(V)
    dmap, _, _ = rasterize(S, F, res, res, near=-1e9, cull=False, want_bary=False)
    Q = proj(P + Nn * 0.15)
    bias = 0.25
    sh = np.zeros(len(P))
    taps = [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)]
    for dx, dy in taps:
        x = np.clip((Q[:, 0] + dx * 1.2).astype(int), 0, res - 1)
        y = np.clip((Q[:, 1] + dy * 1.2).astype(int), 0, res - 1)
        inside = (Q[:, 0] >= 0) & (Q[:, 0] < res) & (Q[:, 1] >= 0) & (Q[:, 1] < res)
        lit = (Q[:, 2] <= dmap[y, x] + bias) | ~inside
        sh += lit
    return sh / len(taps)


def draw_particles(img, depth, cam, particles, look, light=1.0):
    H, W = depth.shape
    for (pos, radius, color, alpha, seed) in particles:
        s = cam.project(np.asarray(pos, float)[None])[0]
        if s[2] < 0.5:
            continue
        rpx = radius * cam.focal / s[2]
        if rpx < 0.8:
            continue
        x0, x1 = int(max(0, s[0] - rpx * 1.3)), int(min(W, s[0] + rpx * 1.3))
        y0, y1 = int(max(0, s[1] - rpx * 1.3)), int(min(H, s[1] + rpx * 1.3))
        if x1 <= x0 or y1 <= y0:
            continue
        ys, xs = np.mgrid[y0:y1, x0:x1].astype(np.float64)
        dx = (xs - s[0]) / rpx
        dy = (ys - s[1]) / rpx
        r2 = dx * dx + dy * dy
        n = fbm(np.stack([dx * 1.4 + seed, dy * 1.4, np.full_like(dx, seed * 0.37)], -1), 4, seed=int(seed) % 97)
        a = np.exp(-r2 * 2.2) * smoothstep(0.25, 0.75, n + 0.25 - 0.35 * r2) * alpha
        # morbido contro la geometria
        d = depth[y0:y1, x0:x1]
        soft = np.clip((d - s[2]) / (radius * 0.8), 0, 1)
        a = a * soft
        # luce: più chiaro verso il sole
        shade = 0.75 + 0.35 * np.clip(-dy * look.sun_dir[1] - dx * 0.2, -1, 1)
        c = np.asarray(color)[None, None, :] * shade[..., None] * light
        img[y0:y1, x0:x1] = img[y0:y1, x0:x1] * (1 - a[..., None]) + c * a[..., None]
    return img


def draw_lines(img, depth, cam, lines, look):
    H, W = depth.shape
    for (a, b, width, color) in lines:
        a, b = np.asarray(a, float), np.asarray(b, float)
        n = int(np.linalg.norm(cam.project(b[None])[0][:2] - cam.project(a[None])[0][:2]) * 1.5) + 2
        n = min(n, 20000)
        t = np.linspace(0, 1, n)
        P = a[None] * (1 - t[:, None]) + b[None] * t[:, None]
        # cavo leggermente curvo
        P[:, 1] -= np.sin(t * math.pi) * np.linalg.norm(b - a) * 0.015
        S = cam.project(P)
        ok = S[:, 2] > 0.3
        S = S[ok]
        for ox in np.linspace(-width / 2, width / 2, max(1, int(width * 2))):
            x = np.round(S[:, 0] + ox * 0.0).astype(int)
            y = np.round(S[:, 1] + ox).astype(int)
            good = (x >= 0) & (x < W) & (y >= 0) & (y < H)
            x, y, z = x[good], y[good], S[good, 2]
            vis = z <= depth[y, x] + 0.5
            img[y[vis], x[vis]] = img[y[vis], x[vis]] * 0.35 + np.asarray(color) * 0.65
    return img


def _box(a, r, axis):
    if r < 1:
        return a
    pad = [(0, 0)] * a.ndim
    pad[axis] = (r + 1, r)
    c = np.cumsum(np.pad(a, pad, mode="edge"), axis=axis)
    n = a.shape[axis]
    hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
    lo = np.take(c, np.arange(0, n), axis=axis)
    return (hi - lo) / (2 * r + 1)


def gaussian(img, sigma):
    """Sfocatura gaussiana approssimata con tre sfocature a scatola."""
    r = max(1, int(round(sigma * 0.95)))
    out = img.astype(np.float64)
    for _ in range(3):
        out = _box(out, r, 0)
        out = _box(out, r, 1)
    return out


def post(img, depth, cam, look):
    H, W = depth.shape
    img = img * look.exposure
    if look.dof:
        focus, strength = look.dof
        inv = np.where(np.isinf(depth), 0.0, 1.0 / np.maximum(depth, 1e-3))
        coc = np.clip(np.abs(inv - 1.0 / focus) * focus * strength, 0, 1)
        small = img[::2, ::2]
        b1 = np.repeat(np.repeat(gaussian(small, W * 0.0025), 2, 0), 2, 1)[:H, :W]
        b2 = np.repeat(np.repeat(gaussian(small, W * 0.007), 2, 0), 2, 1)[:H, :W]
        c = coc[..., None]
        img = np.where(c < 0.5, img * (1 - c * 2) + b1 * c * 2, b1 * (2 - c * 2) + b2 * (c * 2 - 1))
    # raggi di luce: sfocatura radiale del cielo luminoso verso il sole
    sun = cam.project((cam.pos + look.sun_dir * 1e4)[None])[0]
    if look.rays > 0 and np.sum(look.sun_dir * cam.f) > 0.05:
        sky = np.isinf(depth)[..., None] * np.clip(img - 0.9, 0, None)
        small = (sky[::4, ::4]).copy()
        acc = np.zeros_like(small)
        hs, ws = small.shape[:2]
        sx, sy = sun[0] / 4, sun[1] / 4
        ys, xs = np.mgrid[0:hs, 0:ws].astype(np.float64)
        steps = 48
        for i in range(steps):
            k = 1 - i / steps * 0.85
            xx = np.clip((sx + (xs - sx) * k).astype(int), 0, ws - 1)
            yy = np.clip((sy + (ys - sy) * k).astype(int), 0, hs - 1)
            acc += small[yy, xx] * (1 - i / steps)
        acc /= steps
        acc = np.asarray(Image.fromarray((np.clip(acc, 0, 8) / 8 * 65535).astype(np.uint16)[..., 0], mode="I;16").resize((W, H), Image.BILINEAR)) if False else np.repeat(np.repeat(acc, 4, 0), 4, 1)[:H, :W]
        acc = gaussian(acc, 6)
        img = img + acc * look.rays * look.sun_col / look.sun_col.max() * 3
    # bloom
    if look.bloom > 0:
        bright = np.clip(img - 1.0, 0, None)
        small = bright[::4, ::4]
        bl = gaussian(small, 6) + gaussian(small, 18) * 0.6
        bl = np.repeat(np.repeat(bl, 4, 0), 4, 1)[:H, :W]
        img = img + bl * look.bloom
    # tonemap filmico (ACES approssimato)
    a, b, c, d, e = 2.51, 0.03, 2.43, 0.59, 0.14
    img = np.clip((img * (a * img + b)) / (img * (c * img + d) + e), 0, 1)
    # saturazione
    lum = img @ np.array([0.2126, 0.7152, 0.0722])
    img = lum[..., None] + (img - lum[..., None]) * look.saturation
    # vignettatura
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float64)
    r = ((xs / W - 0.5) ** 2 * 1.2 + (ys / H - 0.5) ** 2) * 2
    img = img * (1 - look.vignette * r[..., None] ** 1.5)
    # grana
    rng = np.random.default_rng(7)
    img = img + rng.normal(0, 0.012, img.shape[:2])[..., None]
    return np.clip(img, 0, 1)
