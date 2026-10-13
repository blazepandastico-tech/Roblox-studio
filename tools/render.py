"""Tiny numpy z-buffer rasteriser used to produce preview PNGs of the generated models."""
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from core import H, rot_matrix

LIGHT = np.array([-0.45, 0.8, 0.55])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def _box():
    V, N, T = [], [], []
    for axis in range(3):
        for sgn in (-1, 1):
            n = np.zeros(3)
            n[axis] = sgn
            u, v = [i for i in range(3) if i != axis]
            base = len(V)
            for a, b in ((-.5, -.5), (.5, -.5), (.5, .5), (-.5, .5)):
                p = np.zeros(3)
                p[axis], p[u], p[v] = sgn * .5, a, b
                V.append(p)
                N.append(n)
            if sgn > 0:
                T += [(base, base + 1, base + 2), (base, base + 2, base + 3)]
            else:
                T += [(base, base + 2, base + 1), (base, base + 3, base + 2)]
    return np.array(V), np.array(N), np.array(T)


def _sphere(nlat=12, nlon=20):
    V = []
    for i in range(nlat + 1):
        ph = math.pi * i / nlat - math.pi / 2
        for j in range(nlon):
            th = 2 * math.pi * j / nlon
            V.append((.5 * math.cos(ph) * math.sin(th), .5 * math.sin(ph), .5 * math.cos(ph) * math.cos(th)))
    V = np.array(V)
    T = []
    for i in range(nlat):
        for j in range(nlon):
            a, b = i * nlon + j, i * nlon + (j + 1) % nlon
            c, d = a + nlon, b + nlon
            T += [(a, c, b), (b, c, d)]
    return V, V / 0.5, np.array(T)


def _cyl(n=20):
    V, N, T = [], [], []
    for j in range(n):
        th = 2 * math.pi * j / n
        x, z = .5 * math.sin(th), .5 * math.cos(th)
        V += [(x, -.5, z), (x, .5, z)]
        N += [(math.sin(th), 0, math.cos(th))] * 2
    for j in range(n):
        a, b = 2 * j, 2 * ((j + 1) % n)
        T += [(a, b, a + 1), (b, b + 1, a + 1)]
    for y, ny in ((.5, 1), (-.5, -1)):
        c = len(V)
        V.append((0, y, 0))
        N.append((0, ny, 0))
        for j in range(n):
            th = 2 * math.pi * j / n
            V.append((.5 * math.sin(th), y, .5 * math.cos(th)))
            N.append((0, ny, 0))
        for j in range(n):
            a, b = c + 1 + j, c + 1 + (j + 1) % n
            T.append((c, b, a) if ny > 0 else (c, a, b))
    return np.array(V), np.array(N, float), np.array(T)


def _fix(mesh):
    V, N, T = mesh
    T = T.copy()
    for k, (a, b, c) in enumerate(T):
        g = np.cross(V[b] - V[a], V[c] - V[a])
        if g @ (N[a] + N[b] + N[c]) < 0:
            T[k] = (a, c, b)
    return V, N, T


MESHES = {'box': _fix(_box()), 'ball': _fix(_sphere()), 'cyl': _fix(_cyl())}

MAT_STYLE = {  # (brightness boost, specular)
    'Neon': (1.0, 0.0), 'Glass': (1.0, 0.7), 'Ice': (1.0, 0.5), 'Foil': (1.0, 0.6), 'SmoothPlastic': (1.0, 0.18),
    'Plastic': (1.0, 0.1), 'Metal': (1.0, 0.5),
}


def look_at(eye, target, up=(0, 1, 0)):
    eye, target, up = map(lambda a: np.array(a, float), (eye, target, up))
    f = target - eye
    f /= np.linalg.norm(f)
    r = np.cross(f, up)
    r /= np.linalg.norm(r)
    u = np.cross(r, f)
    return eye, r, u, f


def render(parts, W, Hh, eye, target, fov=32, bg=None, transforms=None):
    """parts: list of (Part, world_offset)."""
    eye, r, u, f = look_at(eye, target)
    focal = 1 / math.tan(math.radians(fov) / 2) * (Hh / 2)
    img = np.zeros((Hh, W, 3), float)
    if bg is None:
        t = np.linspace(0, 1, Hh)[:, None, None]
        top, bot = np.array([120, 175, 235.]), np.array([215, 235, 250.])
        img[:] = top * (1 - t) + bot * t
    else:
        img[:] = bg
    zbuf = np.full((Hh, W), 1e9)

    def draw(part, off, opaque):
        kind = 'box' if part.kind == 'box' else part.kind
        V, N, T = MESHES[kind]
        R = rot_matrix(*part.rot)
        sz = np.array(part.size, float)
        wp = (V * sz) @ R.T + np.array(part.pos) + off
        wn = (N / sz) @ R.T
        wn /= np.linalg.norm(wn, axis=1, keepdims=True)
        rel = wp - eye
        cx, cy, cz = rel @ r, rel @ u, rel @ f
        if np.any(cz < 0.1):
            return
        sx = W / 2 + focal * cx / cz
        sy = Hh / 2 - focal * cy / cz
        base = np.array(H(part.color), float)
        mat = part.mat
        lam = np.clip(wn @ LIGHT, 0, 1)
        spec_k = MAT_STYLE.get(mat, (1, 0.12))[1]
        hv = LIGHT - f
        hv /= np.linalg.norm(hv)
        spec = np.clip(wn @ hv, 0, 1) ** 24 * spec_k
        if mat == 'Neon':
            shade = np.full(len(V), 1.05)
        else:
            shade = 0.5 + 0.55 * lam
        cols = np.clip(base[None, :] * shade[:, None] + 255 * spec[:, None], 0, 255)
        alpha = 1 - part.tr
        g = np.cross(wp[T[:, 1]] - wp[T[:, 0]], wp[T[:, 2]] - wp[T[:, 0]])
        cull = np.einsum('ij,ij->i', g, wp[T[:, 0]] - eye)
        for k, tri in enumerate(T):
            i0, i1, i2 = tri
            x0, y0, x1, y1, x2, y2 = sx[i0], sy[i0], sx[i1], sy[i1], sx[i2], sy[i2]
            area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
            if cull[k] >= 0 or abs(area) < 1e-9:
                continue
            xmin, xmax = max(int(math.floor(min(x0, x1, x2))), 0), min(int(math.ceil(max(x0, x1, x2))), W - 1)
            ymin, ymax = max(int(math.floor(min(y0, y1, y2))), 0), min(int(math.ceil(max(y0, y1, y2))), Hh - 1)
            if xmin > xmax or ymin > ymax:
                continue
            xs = np.arange(xmin, xmax + 1) + 0.5
            ys = np.arange(ymin, ymax + 1)[:, None] + 0.5
            w0 = ((x1 - xs) * (y2 - ys) - (x2 - xs) * (y1 - ys)) / area
            w1 = ((x2 - xs) * (y0 - ys) - (x0 - xs) * (y2 - ys)) / area
            w2 = 1 - w0 - w1
            m = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
            if not m.any():
                continue
            inv = w0 / cz[i0] + w1 / cz[i1] + w2 / cz[i2]
            z = 1 / np.maximum(inv, 1e-9)
            sub = zbuf[ymin:ymax + 1, xmin:xmax + 1]
            m &= z < sub
            if not m.any():
                continue
            b0, b1, b2 = w0 / cz[i0] * z, w1 / cz[i1] * z, w2 / cz[i2] * z
            c = (b0[..., None] * cols[i0] + b1[..., None] * cols[i1] + b2[..., None] * cols[i2])
            region = img[ymin:ymax + 1, xmin:xmax + 1]
            if opaque:
                region[m] = c[m]
                sub[m] = z[m]
            else:
                region[m] = region[m] * (1 - alpha) + c[m] * alpha

    for opaque in (True, False):
        for part, off in parts:
            if (part.tr == 0) == opaque:
                draw(part, np.array(off, float), opaque)
    return img


def fit_camera(parts, off=(0, 0, 0), dirv=(0.62, 0.42, 1.0), fov=32, margin=1.12):
    pts = []
    for p, o in parts:
        R = rot_matrix(*p.rot)
        for dx in (-.5, .5):
            for dy in (-.5, .5):
                for dz in (-.5, .5):
                    pts.append(R @ (np.array([dx, dy, dz]) * p.size) + p.pos + o)
    pts = np.array(pts)
    lo, hi = pts.min(0), pts.max(0)
    ctr = (lo + hi) / 2
    rad = np.linalg.norm(hi - lo) / 2
    d = np.array(dirv, float)
    d /= np.linalg.norm(d)
    dist = rad / math.sin(math.radians(fov) / 2) * margin * 0.82
    return ctr + d * dist, ctr


def to_image(arr, ss):
    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    return im.resize((im.width // ss, im.height // ss), Image.LANCZOS)


def caption(im, text, sub=None, color=(30, 30, 40)):
    d = ImageDraw.Draw(im)
    fb = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 22)
    fs = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 15)
    d.rectangle([0, im.height - 48, im.width, im.height], fill=(250, 250, 252))
    d.text((12, im.height - 44), text, font=fb, fill=color)
    if sub:
        w = d.textlength(sub, font=fs)
        d.text((im.width - w - 12, im.height - 38), sub, font=fs, fill=(90, 90, 100))
    return im
