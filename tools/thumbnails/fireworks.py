"""Fuochi d'artificio fisici per il video e le immagini dell'evento "Grande Inaugurazione".

Ogni razzo sale con la sua scia e scoppia: le scintille seguono la fisica (velocità iniziale,
resistenza dell'aria, gravità) e lasciano strisce luminose. Vengono disegnate dopo il render della
scena (con il controllo della profondità: le case e le mura le coprono) e illuminano la città.
"""
import math

import numpy as np

from engine import gaussian

PALETTE = [
    (1.0, 0.25, 0.22),
    (1.0, 0.75, 0.25),
    (0.30, 0.85, 1.0),
    (0.45, 1.0, 0.45),
    (1.0, 0.40, 0.85),
    (0.65, 0.45, 1.0),
    (1.0, 1.0, 1.0),
    (1.0, 0.55, 0.20),
]
GOLD = (1.0, 0.72, 0.30)


def _sphere_dirs(n, rng):
    v = rng.normal(0, 1, (n, 3))
    return v / np.linalg.norm(v, axis=1, keepdims=True)


class Firework:
    """Un razzo: parte da base al tempo t0, sale per rise secondi e scoppia in cima."""

    def __init__(self, t0, base, height, rng, color=None, kind=None):
        self.t0 = t0
        self.base = np.asarray(base, float)
        self.rise = rng.uniform(1.0, 1.4)
        self.apex = self.base + np.array([rng.normal(0, 3), height, rng.normal(0, 3)])
        self.kind = kind or rng.choice(["peony", "peony", "peony", "willow", "willow", "ring", "palm", "crackle"])
        self.color = np.array(color if color is not None else PALETTE[rng.integers(len(PALETTE))], float)
        second = np.array(PALETTE[rng.integers(len(PALETTE))], float) if rng.random() < 0.5 else np.ones(3)
        if self.kind == "willow":
            n, speed, self.drag, self.grav, life = 150, 85.0, 1.25, 16.0, (2.6, 3.6)
            self.color = np.array(GOLD)
            second = np.array((1.0, 0.45, 0.10))
        elif self.kind == "ring":
            n, speed, self.drag, self.grav, life = 90, 120.0, 1.9, 6.0, (1.4, 1.9)
        elif self.kind == "palm":
            n, speed, self.drag, self.grav, life = 12, 95.0, 1.0, 14.0, (1.8, 2.4)
        elif self.kind == "crackle":
            n, speed, self.drag, self.grav, life = 130, 95.0, 2.0, 7.0, (1.0, 1.5)
            self.color = np.ones(3)
        else:
            n, speed, self.drag, self.grav, life = 170, 115.0, 1.75, 7.0, (1.5, 2.2)
        if self.kind == "ring":
            a = rng.uniform(0, 2 * math.pi, n)
            tilt = rng.uniform(-0.9, 0.9)
            d = np.stack([np.cos(a), np.sin(a) * math.sin(tilt), np.sin(a) * math.cos(tilt)], 1)
            yaw = rng.uniform(0, 2 * math.pi)
            c, s = math.cos(yaw), math.sin(yaw)
            d = d @ np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
            speeds = speed * rng.uniform(0.96, 1.0, n)
        elif self.kind == "palm":
            a = np.linspace(0, 2 * math.pi, n, endpoint=False) + rng.uniform(0, 1)
            d = np.stack([np.cos(a), rng.uniform(0.25, 0.65, n), np.sin(a)], 1)
            d /= np.linalg.norm(d, axis=1, keepdims=True)
            speeds = speed * rng.uniform(0.9, 1.0, n)
        else:
            d = _sphere_dirs(n, rng)
            speeds = speed * rng.uniform(0.82, 1.0, n)
        self.dirs = d
        self.speeds = speeds
        self.life = rng.uniform(life[0], life[1], n)
        mix = (rng.random(n) < 0.5)[:, None]
        self.cols = np.where(mix, self.color[None], second[None])
        self.seed = int(rng.integers(1 << 30))

    def burst_time(self):
        return self.t0 + self.rise

    def _pos(self, s):
        """Posizione delle scintille dopo s secondi dallo scoppio (s è un array per scintilla)."""
        s = np.maximum(s, 0)[:, None]
        k = self.drag
        travel = (1 - np.exp(-k * s)) / k
        p = self.apex[None] + self.dirs * self.speeds[:, None] * travel
        p[:, 1:2] -= 0.5 * self.grav * s * s
        return p

    def points(self, t, samples=16):
        """(posizioni, colori*intensità) di scie e scintille al tempo t."""
        tau = t - self.t0
        if tau < 0:
            return None
        if tau < self.rise:
            P, Cs = [], []
            for j in range(samples):
                tj = tau - j * 0.03
                if tj < 0:
                    break
                k = tj / self.rise
                up = 1 - (1 - k) ** 2
                P.append(self.base + (self.apex - self.base) * up + np.array([math.sin(tj * 20) * 0.3, 0, 0]))
                Cs.append(np.array((1.0, 0.65, 0.3)) * 2.2 * (1 - j / samples))
            return np.array(P), np.array(Cs)
        tb = tau - self.rise
        alive = tb < self.life
        if not alive.any():
            return None
        Ps, Cs = [], []
        bright = np.clip(1 - (tb / self.life) ** 2, 0, 1)
        hot = math.exp(-tb * 4.0)  # bianco caldo appena scoppiato
        base_col = self.cols * (1 - hot) + hot
        if self.kind == "crackle":
            flick = (np.sin(tb * 60 + np.arange(len(self.life)) * 1.7) > 0.2).astype(float)
            bright = bright * (0.3 + 0.7 * flick)
        streak = 0.011 if self.kind != "palm" else 0.03
        for j in range(samples):
            s = tb - j * streak
            fade = (1 - j / samples) ** 1.5
            P = self._pos(np.full(len(self.life), s))
            ok = alive & (s >= 0)
            Ps.append(P[ok])
            inten = (bright * fade)[ok] * (2.6 if self.kind == "palm" else 1.25)
            Cs.append(base_col[ok] * inten[:, None])
        return np.concatenate(Ps), np.concatenate(Cs)

    def flash(self, t):
        """Lampo dello scoppio (0..1)."""
        tb = t - self.burst_time()
        if tb < 0 or tb > 0.6:
            return 0.0
        return (1 - tb / 0.6) ** 2


def show(rng, center, t0, duration, spread=90.0, heights=(85, 150), rate=(0.35, 0.8), finale=True):
    """Spettacolo di fuochi: razzi a intervalli casuali, poi un gran finale."""
    center = np.asarray(center, float)
    out = []
    t = t0
    end = t0 + duration - (2.5 if finale else 0)
    while t < end:
        base = center + np.array([rng.uniform(-spread, spread), 0, rng.uniform(-spread * 0.4, spread * 0.4)])
        out.append(Firework(t, base, rng.uniform(*heights), rng))
        t += rng.uniform(*rate)
    if finale:
        # gran finale a ondate: prima un ventaglio basso, poi anelli e palme in alto, infine i salici d'oro
        waves = [
            (5, (0.55, 0.75), [None], 0.0),
            (4, (0.95, 1.15), ["ring", "palm", "ring", "palm"], 0.55),
            (6, (0.75, 1.05), ["willow"], 1.1),
        ]
        for count, hk, kinds, dt in waves:
            for i in range(count):
                x = -spread + (i + 0.5) * spread * 2 / count + rng.uniform(-15, 15)
                base = center + np.array([x, 0, rng.uniform(-spread * 0.35, spread * 0.35)])
                h = rng.uniform(heights[1] * hk[0], heights[1] * hk[1])
                out.append(Firework(end + dt + i * 0.07 + rng.uniform(0, 0.05), base, h, rng, kind=kinds[i % len(kinds)]))
    return out


def stars(n=1600, seed=4):
    rng = np.random.default_rng(seed)
    d = rng.normal(0, 1, (n, 3))
    d[:, 1] = np.abs(d[:, 1]) + 0.05
    d /= np.linalg.norm(d, axis=1, keepdims=True)
    mag = rng.uniform(0.15, 1.0, n) ** 3
    return d, mag


def _splat(buf, depth, cam, P, C, soft=1.0):
    if P is None or len(P) == 0:
        return
    H, W = depth.shape
    s = cam.project(P)
    x, y, z = s[:, 0], s[:, 1], s[:, 2]
    ok = (z > 1.0) & (x >= 0) & (x < W - 1) & (y >= 0) & (y < H - 1)
    x, y, z, C = x[ok], y[ok], z[ok], C[ok]
    xi = x.astype(int)
    yi = y.astype(int)
    vis = depth[yi, xi] > z - 2.0  # dietro alle case e alle mura non si vede
    xi, yi, x, y, C = xi[vis], yi[vis], x[vis], y[vis], C[vis]
    fx, fy = x - xi, y - yi
    for dx, dy, w in ((0, 0, (1 - fx) * (1 - fy)), (1, 0, fx * (1 - fy)), (0, 1, (1 - fx) * fy), (1, 1, fx * fy)):
        np.add.at(buf, (yi + dy, xi + dx), C * (w * soft)[:, None])


def post(shows, t, sky_stars=True, extra_points=None, light_scene=1.0):
    """Funzione da passare a engine.render(extra_post=...): disegna stelle, fuochi e lampi."""

    def fx(img, depth, cam):
        H, W = depth.shape
        sky = np.isinf(depth)
        if sky_stars:
            d, mag = stars()
            P = cam.pos + d * 5000
            s = cam.project(P)
            ok = (s[:, 2] > 1) & (s[:, 0] >= 0) & (s[:, 0] < W) & (s[:, 1] >= 0) & (s[:, 1] < H)
            xi, yi = s[ok, 0].astype(int), s[ok, 1].astype(int)
            tw = 0.7 + 0.3 * np.sin(t * 5 + np.arange(ok.sum()))
            add = np.zeros((H, W))
            np.add.at(add, (yi, xi), mag[ok] * tw * 0.9)
            img = img + (add * sky)[..., None] * np.array([0.85, 0.9, 1.0])
        buf = np.zeros((H, W, 3))
        glow = np.zeros((H, W, 3))
        light = np.zeros(3)
        for fw in shows:
            r = fw.points(t)
            if r is not None:
                _splat(buf, depth, cam, r[0], r[1])
            f = fw.flash(t)
            if f > 0:
                # bagliore dello scoppio nel cielo
                s = cam.project(fw.apex[None])[0]
                if s[2] > 1:
                    yy, xx = np.ogrid[0:H, 0:W]
                    rad = 70.0 * cam.focal / s[2]
                    g = np.exp(-((xx - s[0]) ** 2 + (yy - s[1]) ** 2) / (2 * rad * rad)) * f * 0.22
                    glow += g[..., None] * fw.color
                light += fw.color * f
        # tanti scoppi insieme non devono diventare una macchia: il bagliore satura dolcemente
        glow = 0.2 * np.tanh(glow / 0.2)
        img = img + glow * (0.6 + 0.4 * sky[..., None])
        light = 2.5 * np.tanh(light / 2.5)
        if extra_points is not None:
            for P, C in extra_points:
                _splat(buf, depth, cam, P, C)
        core = gaussian(buf, 0.6)
        halo = gaussian(buf, max(2.0, W * 0.0035))
        img = img + core * 1.5 + halo * 1.4
        # la città si illumina con il colore dei fuochi
        if light.any():
            ground = (~sky)[..., None]
            img = img * (1 + ground * np.minimum(light, 2.5) * 0.35 * light_scene)
        return img

    return fx
