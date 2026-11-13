"""Egg collection toolkit: stud-style collectible eggs for "steal / hatch" games.

An egg is described by an :class:`EggDesign` (colours, pattern layers and
accessories) and built with :func:`build_egg`. The structure follows the
common egg-collection loop: eggs belong to a speed-gated **biome**, have one of
ten **rarities**, roll a **weight** (kg) when they spawn, may roll a colour
**mutation**, hatch on a timer and then pay money per second.

All numbers (speeds, incomes, chances, timers) are this kit's own and live in
the tables below; :mod:`studvox.eggpack` turns them into ``EggConfig.luau``.

Geometry: eggs stand on y = 0, centred on x = z = 0, 1 voxel = 1 stud.
Rarer eggs are bigger and get extra effects (aura ring, sparkles, halo,
wings) so the tier reads at a glance.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Any

import numpy as np

from . import shapes as S
from .model import Model, Part

# ---------------------------------------------------------------------------- tables

RARITIES: list[dict[str, Any]] = [
    # id, title, colour, egg height/width (voxels), spawn %, hatch s, income x, base kg
    {"id": "common", "fx": "#FFFFFF", "title": "Common", "color": "#B9C1CB", "h": 15, "w": 11, "spawn": 38.0, "hatch": 10, "income": 1.0, "kg": 1.2},
    {"id": "uncommon", "fx": "#8CFF7A", "title": "Uncommon", "color": "#5FD35F", "h": 15, "w": 11, "spawn": 25.0, "hatch": 20, "income": 1.8, "kg": 1.8},
    {"id": "rare", "fx": "#5FB0FF", "title": "Rare", "color": "#3B8EFF", "h": 17, "w": 13, "spawn": 15.0, "hatch": 40, "income": 3.2, "kg": 2.6},
    {"id": "epic", "fx": "#C77DFF", "title": "Epic", "color": "#A75CFF", "h": 17, "w": 13, "spawn": 9.0, "hatch": 75, "income": 5.8, "kg": 3.8},
    {"id": "legendary", "fx": "#FFD24A", "title": "Legendary", "color": "#FFB21C", "h": 18, "w": 13, "spawn": 5.5, "hatch": 120, "income": 10.5, "kg": 5.5},
    {"id": "mythic", "fx": "#FF5A8A", "title": "Mythic", "color": "#FF3F6C", "h": 18, "w": 13, "spawn": 3.6, "hatch": 180, "income": 19.0, "kg": 8.0},
    {"id": "celestial", "fx": "#3FF0FF", "title": "Celestial", "color": "#3FF0FF", "h": 19, "w": 15, "spawn": 2.0, "hatch": 270, "income": 34.0, "kg": 12.0},
    {"id": "secret", "fx": "#B45CFF", "title": "Secret", "color": "#2A2D36", "h": 19, "w": 15, "spawn": 1.0, "hatch": 420, "income": 61.0, "kg": 18.0},
    {"id": "eternal", "fx": "#6CFFC4", "title": "Eternal", "color": "#6CFFC4", "h": 20, "w": 15, "spawn": 0.6, "hatch": 600, "income": 110.0, "kg": 26.0},
    {"id": "divine", "fx": "#FFF4C2", "title": "Divine", "color": "#FFF0A0", "h": 20, "w": 15, "spawn": 0.3, "hatch": 900, "income": 200.0, "kg": 40.0},
]
RARITY = {r["id"]: r for r in RARITIES}

BIOMES: list[dict[str, Any]] = [
    {"id": "meadow", "title": "Clover Meadow", "speed": 0, "color": "#59B84A"},
    {"id": "pond", "title": "Lily Pond", "speed": 1_000, "color": "#2FB3B0"},
    {"id": "dunes", "title": "Sunbaked Dunes", "speed": 7_500, "color": "#E0A84C"},
    {"id": "jungle", "title": "Vine Jungle", "speed": 40_000, "color": "#1F8A44"},
    {"id": "tundra", "title": "Frostpeak Tundra", "speed": 200_000, "color": "#8FD8FF"},
    {"id": "caldera", "title": "Ember Caldera", "speed": 1_000_000, "color": "#E8461E"},
    {"id": "reef", "title": "Coral Reef", "speed": 5_000_000, "color": "#2F7BE8"},
    {"id": "fossil", "title": "Fossil Valley", "speed": 25_000_000, "color": "#B07A45"},
    {"id": "candy", "title": "Sugar Isles", "speed": 125_000_000, "color": "#FF7BC0"},
    {"id": "clockwork", "title": "Clockwork Works", "speed": 600_000_000, "color": "#C7673A"},
    {"id": "haunted", "title": "Haunted Hollow", "speed": 3_000_000_000, "color": "#7C4DD6"},
    {"id": "blossom", "title": "Blossom Hills", "speed": 15_000_000_000, "color": "#FF9BC8"},
    {"id": "starlight", "title": "Starlight Rim", "speed": 75_000_000_000, "color": "#3A2A8C"},
    {"id": "sky", "title": "Sky Citadel", "speed": 400_000_000_000, "color": "#FFD86B"},
]
BIOME = {b["id"]: b for b in BIOMES}

MUTATIONS: list[dict[str, Any]] = [
    {"id": "normal", "title": "Normal", "multiplier": 1.0, "chance": 0.0, "look": "original colours"},
    {"id": "silver", "title": "Silver", "multiplier": 1.25, "chance": 6.0, "look": "metallic silver tint, white sparkles"},
    {"id": "golden", "title": "Golden", "multiplier": 2.0, "chance": 3.0, "look": "shiny gold tint, gold sparkles"},
    {"id": "rainbow", "title": "Rainbow", "multiplier": 3.0, "chance": 1.0, "look": "colours cycle through the rainbow"},
    {"id": "diamond", "title": "Diamond", "multiplier": 4.0, "chance": 0.3, "look": "see-through ice-blue crystal, sparkles"},
]


def egg_stats(biome: str, rarity: str) -> dict[str, Any]:
    """Game numbers for an egg of this biome and rarity (this kit's own economy)."""
    b = next(i for i, x in enumerate(BIOMES) if x["id"] == biome)
    r = RARITY[rarity]
    ri = RARITIES.index(r)
    income = 4.0 * (5.0 ** b) * r["income"]
    return {
        "biome_index": b,
        "rarity_index": ri,
        "spawn_chance": r["spawn"],
        "hatch_seconds": r["hatch"] + b * 5 * (ri + 1),
        "base_income": round(income, 2),
        "base_weight": round(r["kg"] * (1.15 ** b), 2),
        "unlock_speed": BIOMES[b]["speed"],
    }


# ---------------------------------------------------------------------------- design

@dataclass
class EggDesign:
    id: str
    name: str
    biome: str
    rarity: str
    base: str                       # shell colour
    accent: str                     # main pattern colour
    accent2: str = "white"
    accent3: str = "black"
    patterns: list = field(default_factory=list)  # [(kind, {args}), ...] painted in order
    extras: list = field(default_factory=list)    # ["kind" or (kind, {args}), ...]
    flavor: str = ""
    glow: str | None = None         # colour for rarity effects (default: rarity colour)
    height: int | None = None
    width: int | None = None


class EggGeo:
    """Shape of the shell: radius per layer."""

    def __init__(self, h: int, w: int):
        self.H = h
        self.R = w / 2.0
        self.radii = []
        for y in range(h):
            t = (y + 0.5) / h
            if t < 0.42:
                k = (0.42 - t) / 0.42
            else:
                k = (t - 0.42) / 0.58
            r = self.R * math.sqrt(max(0.0, 1.0 - k * k))
            if y == 0:
                r = max(r, self.R * 0.5)
            self.radii.append(max(r, 0.8))

    def r(self, y: float) -> float:
        i = int(round(min(max(y, 0), self.H - 1)))
        return self.radii[i]

    @property
    def top(self) -> int:
        return self.H - 1

    @property
    def mid(self) -> int:
        return int(round(self.H * 0.42))

    def coords(self) -> np.ndarray:
        out = []
        for y, r in enumerate(self.radii):
            n = int(math.floor(r + 0.5))
            for x in range(-n, n + 1):
                for z in range(-n, n + 1):
                    if x * x + z * z <= r * r + 0.35:
                        out.append((x, y, z))
        return np.asarray(out, dtype=np.int32)

    def surface_point(self, angle: float, y: int, out: float = 0.0) -> tuple[int, int, int]:
        """Voxel on (or ``out`` voxels outside) the shell at an angle around the y axis (0 = +x, pi/2 = +z)."""
        rr = self.r(y) + out
        return (int(round(math.cos(angle) * rr)), int(y), int(round(math.sin(angle) * rr)))


# ---------------------------------------------------------------------------- helpers

def _rng(seed: int):
    return np.random.default_rng(seed)


def _surface(part: Part) -> np.ndarray:
    c = part.coords()
    keys = set(map(tuple, c.tolist()))
    out = [p for p in c.tolist()
           if any((p[0] + dx, p[1] + dy, p[2] + dz) not in keys
                  for dx, dy, dz in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)))]
    return np.asarray(out, dtype=np.int32).reshape(-1, 3)


def _u(c: np.ndarray) -> np.ndarray:
    """Angle around the egg as 0..1 (0 = +x, 0.25 = +z front)."""
    return (np.arctan2(c[:, 2], c[:, 0]) / (2 * math.pi)) % 1.0


class Ctx:
    def __init__(self, m: Model, shell: Part, g: EggGeo, d: EggDesign):
        self.m, self.shell, self.g, self.d = m, shell, g, d
        self.anims: list[tuple] = []
        self.glow_ref = d.glow or (RARITY[d.rarity]["fx"], "glow")

    def col(self, ref):
        if ref is None:
            return None
        if isinstance(ref, tuple):
            return ref
        return {"base": self.d.base, "accent": self.d.accent, "accent2": self.d.accent2,
                "accent3": self.d.accent3, "glow": self.glow_ref,
                "rarity": ("#%s" % RARITY[self.d.rarity]["color"].lstrip("#"), "plastic")}.get(ref, ref)

    def part(self, name: str, pivot=(0, 0, 0)) -> Part:
        if name in self.m.parts:
            return self.m.parts[name]
        return self.m.part(name, parent="shell", pivot=pivot)


# ---------------------------------------------------------------------------- patterns

def _mask_paint(ctx: Ctx, fn, color, only=None):
    c = ctx.shell.coords()
    if len(c) == 0:
        return
    mask = fn(c)
    ctx.shell.paint(c[mask], ctx.col(color), only=None if only is None else [ctx.col(o) for o in only])


def p_band(ctx, at=0.5, width=1, color="accent", **_):
    yb = int(round(at * (ctx.g.H - 1)))
    _mask_paint(ctx, lambda c: (c[:, 1] >= yb) & (c[:, 1] < yb + width), color)


def p_bands(ctx, at=(0.3, 0.6), width=1, color="accent", **_):
    for a in at:
        p_band(ctx, a, width, color)


def p_zigzag(ctx, at=0.5, teeth=8, width=1, color="accent", **_):
    yb = int(round(at * (ctx.g.H - 1)))

    def fn(c):
        off = (np.floor(_u(c) * teeth * 2) % 2).astype(int)
        return (c[:, 1] >= yb + off) & (c[:, 1] < yb + off + width)
    _mask_paint(ctx, fn, color)


def p_wave(ctx, at=0.5, amp=1.0, freq=3, width=1, color="accent", **_):
    yb = at * (ctx.g.H - 1)

    def fn(c):
        yc = np.round(yb + amp * np.sin(2 * math.pi * _u(c) * freq))
        return (c[:, 1] >= yc) & (c[:, 1] < yc + width)
    _mask_paint(ctx, fn, color)


def p_stripes(ctx, count=8, color="accent", y=(0.0, 1.0), **_):
    lo, hi = y[0] * ctx.g.H, y[1] * ctx.g.H
    _mask_paint(ctx, lambda c: (np.floor(_u(c) * count * 2) % 2 == 0) & (c[:, 1] >= lo) & (c[:, 1] <= hi), color)


def p_swirl(ctx, count=4, twist=8.0, color="accent", **_):
    _mask_paint(ctx, lambda c: np.floor((_u(c) * count + c[:, 1] / twist) * 2) % 2 == 0, color)


def p_checker(ctx, count=8, rows=2, color="accent", y=(0.0, 1.0), **_):
    lo, hi = y[0] * ctx.g.H, y[1] * ctx.g.H
    _mask_paint(ctx, lambda c: ((np.floor(_u(c) * count) + np.floor(c[:, 1] / rows)) % 2 == 0)
                & (c[:, 1] >= lo) & (c[:, 1] <= hi), color)


def p_gradient(ctx, stops=((0.5, "accent"),), **_):
    for frac, color in stops:
        y0 = frac * ctx.g.H
        _mask_paint(ctx, lambda c, y0=y0: c[:, 1] >= y0, color)


def p_cap(ctx, from_=0.72, color="accent", **kw):
    f = kw.get("from", from_)
    y0 = f * ctx.g.H
    _mask_paint(ctx, lambda c: c[:, 1] >= y0, color)


def p_bottom(ctx, to=0.25, color="accent", **_):
    y1 = to * ctx.g.H
    _mask_paint(ctx, lambda c: c[:, 1] <= y1, color)


def p_split(ctx, color="accent", axis="x", **_):
    a = "xyz".index(axis)
    _mask_paint(ctx, lambda c: c[:, a] > 0, color)


def p_spots(ctx, count=6, size=1.0, color="accent", seed=1, y=(0.12, 0.88), **_):
    surf = _surface(ctx.shell)
    lo, hi = y[0] * ctx.g.H, y[1] * ctx.g.H
    surf = surf[(surf[:, 1] >= lo) & (surf[:, 1] <= hi)]
    if len(surf) == 0:
        return
    rng = _rng(seed)
    centers = []
    tries = 0
    while len(centers) < count and tries < 400:
        tries += 1
        p = surf[rng.integers(len(surf))]
        if all(np.linalg.norm(p - q) > size * 2 + 1.5 for q in centers):
            centers.append(p)
    c = ctx.shell.coords()
    mask = np.zeros(len(c), dtype=bool)
    for p in centers:
        mask |= np.linalg.norm(c - p, axis=1) <= size + 0.25
    ctx.shell.paint(c[mask], ctx.col(color))


def p_dots(ctx, rows=(0.3, 0.55, 0.8), count=6, color="accent", **_):
    for i, fr in enumerate(rows):
        y = int(round(fr * (ctx.g.H - 1)))
        for k in range(count):
            ang = 2 * math.pi * (k + 0.5 * (i % 2)) / count
            # paint the outermost voxel along that ray
            for out in (0.5, 0, -0.5, -1):
                q = ctx.g.surface_point(ang, y, out)
                if ctx.shell.has(q):
                    ctx.shell.voxel(q, ctx.col(color))
                    break


def p_speckle(ctx, colors=None, fraction=0.25, seed=3, only=None, **_):
    c = _surface(ctx.shell)
    if len(c) == 0:
        return
    h1 = S._hash3(c[:, 0].astype(np.int64), c[:, 1].astype(np.int64), c[:, 2].astype(np.int64), seed)
    h2 = S._hash3(c[:, 0].astype(np.int64), c[:, 1].astype(np.int64), c[:, 2].astype(np.int64), seed + 77)
    sel = h1 < fraction
    colors = colors or {"accent": 1.0}
    total = sum(colors.values())
    acc = 0.0
    for col, w in colors.items():
        lo, acc = acc, acc + w / total
        pick = sel & (h2 >= lo) & (h2 < acc + 1e-9)
        ctx.shell.paint(c[pick], ctx.col(col), only=None if only is None else [ctx.col(o) for o in only])


def p_cracks(ctx, count=3, length=7, color="glow", seed=5, **_):
    surf = _surface(ctx.shell)
    keys = set(map(tuple, surf.tolist()))
    rng = _rng(seed)
    for _ in range(count):
        cand = surf[(surf[:, 1] > ctx.g.H * 0.3) & (surf[:, 1] < ctx.g.H * 0.85)]
        if len(cand) == 0:
            return
        p = tuple(cand[rng.integers(len(cand))].tolist())
        for _ in range(length):
            ctx.shell.voxel(p, ctx.col(color), stud=False)
            nbrs = [(p[0] + dx, p[1] + dy, p[2] + dz) for dx, dy, dz in
                    ((1, -1, 0), (-1, -1, 0), (0, -1, 1), (0, -1, -1), (1, 0, 0), (-1, 0, 0), (0, 0, 1), (0, 0, -1),
                     (0, -1, 0))]
            nbrs = [q for q in nbrs if q in keys]
            if not nbrs:
                break
            p = nbrs[rng.integers(len(nbrs))]


def p_drips(ctx, from_=0.68, color="accent", count=7, max_len=3, seed=2, **kw):
    f = kw.get("from", from_)
    y0 = int(math.ceil(f * ctx.g.H))
    p_cap(ctx, **{"from": y0 / ctx.g.H, "color": color})
    rng = _rng(seed)
    for k in range(count):
        ang = 2 * math.pi * (k + rng.random() * 0.4) / count
        L = int(rng.integers(1, max_len + 1))
        for dy in range(1, L + 1):
            y = y0 - dy
            for out in (0.4, 0, -0.6):
                q = ctx.g.surface_point(ang, y, out)
                if ctx.shell.has(q):
                    ctx.shell.voxel(q, ctx.col(color))
                    break


def p_scales(ctx, count=10, color="accent", y=(0.0, 1.0), **_):
    lo, hi = y[0] * ctx.g.H, y[1] * ctx.g.H

    def fn(c):
        row = (c[:, 1] // 2) % 2
        return ((np.floor(_u(c) * count * 2 + row) % 2) == 0) & (c[:, 1] % 2 == 0) & (c[:, 1] >= lo) & (c[:, 1] <= hi)
    _mask_paint(ctx, fn, color)


def p_plaid(ctx, count=6, color="accent", color2="accent2", **_):
    _mask_paint(ctx, lambda c: np.floor(_u(c) * count * 3) % 3 == 0, color)
    _mask_paint(ctx, lambda c: c[:, 1] % 3 == 1, color2)


def p_diamonds(ctx, count=6, rows=3.0, color="accent", **_):
    def fn(c):
        uu = (_u(c) * count) % 1.0
        vv = (c[:, 1] / rows + 0.5 * (np.floor(_u(c) * count) % 2)) % 1.0
        return np.abs(uu - 0.5) + np.abs(vv - 0.5) < 0.34
    _mask_paint(ctx, fn, color)


def p_web(ctx, color="accent", lines=6, from_=0.45, **kw):
    f = kw.get("from", from_)
    y0 = f * ctx.g.H

    def fn(c):
        uu = (_u(c) * lines) % 1.0
        radial = (np.abs(uu - 0.5) > 0.42) & (c[:, 1] >= y0)
        ring = (c[:, 1] >= y0) & (((ctx.g.H - c[:, 1]) % 3) == 0)
        return radial | ring
    _mask_paint(ctx, fn, color)


def p_vines(ctx, color="accent", turns=2, twist=7.0, leaf="accent2", seed=4, **_):
    _mask_paint(ctx, lambda c: np.abs(((_u(c) * turns + c[:, 1] / twist) % 1.0) - 0.5) > 0.44, color)
    rng = _rng(seed)
    for k in range(5):
        y = int(rng.integers(2, ctx.g.H - 2))
        ang = 2 * math.pi * ((y / twist) % 1.0) * -1 + 2 * math.pi * k / 5
        ctx.shell.voxel(ctx.g.surface_point(ang, y, 1), ctx.col(leaf))


def p_panels(ctx, color="accent", count=6, rows=(0.3, 0.7), **_):
    _mask_paint(ctx, lambda c: np.floor(_u(c) * count * 4) % 4 == 0, color)
    for fr in rows:
        p_band(ctx, fr, 1, color)


def p_face(ctx, style="cute", at=0.55, colors=None, **_):
    from .kit import face
    y = int(round(at * (ctx.g.H - 1)))
    cols = {k: ctx.col(v) for k, v in (colors or {}).items()}
    face(ctx.shell, style, y=y, colors=cols)


def p_art(ctx, rows=(), at=(0, 0.5), colors=None, emboss=False, facing="+z", **_):
    cols = {k: ctx.col(v) for k, v in (colors or {}).items()}
    width = max(len(r) for r in rows)
    x0 = at[0] if at[0] is not None else -(width // 2)
    y = int(round(at[1] * (ctx.g.H - 1)))
    if emboss:
        ctx.shell.emboss(list(rows), at=(x0, y, 0), colors=cols, facing=facing)
    else:
        ctx.shell.decal(list(rows), at=(x0, y, 0), colors=cols, facing=facing)


def p_material(ctx, color="accent", **_):
    """Recolour the whole shell (e.g. glass / ice / amber shells)."""
    _mask_paint(ctx, lambda c: np.ones(len(c), dtype=bool), color)


PATTERNS = {
    "band": p_band, "bands": p_bands, "zigzag": p_zigzag, "wave": p_wave, "stripes": p_stripes, "swirl": p_swirl,
    "checker": p_checker, "gradient": p_gradient, "cap": p_cap, "bottom": p_bottom, "split": p_split,
    "spots": p_spots, "dots": p_dots, "speckle": p_speckle, "cracks": p_cracks, "drips": p_drips,
    "scales": p_scales, "plaid": p_plaid, "diamonds": p_diamonds, "web": p_web, "vines": p_vines,
    "panels": p_panels, "face": p_face, "art": p_art, "material": p_material,
}


# ---------------------------------------------------------------------------- accessories

def x_sprout(ctx, stem="green", leaf="light_green", **_):
    t = ctx.g.H
    ctx.shell.voxels([(0, t, 0), (0, t + 1, 0)], ctx.col(stem))
    ctx.shell.voxels([(-1, t + 1, 0), (-2, t + 2, 0), (1, t + 2, 0), (2, t + 3, 0), (-1, t + 2, 0), (1, t + 3, 0)],
                     ctx.col(leaf))


def x_flower(ctx, petal="pink", center="yellow", stem="green", **_):
    t = ctx.g.H
    ctx.shell.voxel((0, t, 0), ctx.col(stem))
    ctx.shell.voxel((0, t + 1, 0), ctx.col(center))
    ctx.shell.voxels([(1, t + 1, 0), (-1, t + 1, 0), (0, t + 1, 1), (0, t + 1, -1), (0, t + 2, 0)], ctx.col(petal))


def x_leaf_crown(ctx, color="green", count=5, **_):
    y = ctx.g.top - 1
    for k in range(count):
        ang = 2 * math.pi * k / count
        a = ctx.g.surface_point(ang, y, 0.8)
        b = ctx.g.surface_point(ang, y + 2, 1.6)
        ctx.shell.line(a, b, ctx.col(color))


def x_crown(ctx, color="gold", gem="red", points=5, **_):
    y = ctx.g.top - 1
    r = ctx.g.r(y) + 0.7
    ring = S.ring((0, y, 0), r + 0.5, 1.0, height=1)
    ctx.shell.add(ring, ctx.col(color))
    for k in range(points):
        ang = 2 * math.pi * k / points + math.pi / 2
        p = (int(round(math.cos(ang) * r)), y + 1, int(round(math.sin(ang) * r)))
        ctx.shell.voxels([p, (p[0], p[1] + 1, p[2])], ctx.col(color))
    ctx.shell.voxel((0, y, int(round(r + 0.5))), ctx.col(gem), stud=False)


def x_halo(ctx, color="glow", **_):
    y = ctx.g.H + 2
    p = ctx.part("halo", pivot=(0, y, 0))
    p.add(S.ring((0, y, 0), 3.4, 1.0, height=1), ctx.col(color))
    p.paint(S.box((-1, y, -4), (1, y, -3)), ctx.col("gold"))
    ctx.anims.append(("spin", "halo", 1))
    ctx.anims.append(("bob", "halo", 0.35))


def x_wings(ctx, color="white", tip="light_blue", size=None, **_):
    """Feathered wings: an arched top edge, scalloped feather tips below, swept slightly back."""
    size = size or max(4, ctx.g.H // 3)
    y0 = ctx.g.mid
    for side, name in ((-1, "wing_l"), (1, "wing_r")):
        base_r = ctx.g.r(y0 + 1)
        x0 = side * int(math.floor(base_r + 0.5))
        p = ctx.part(name, pivot=(x0, y0 + 1, -2))
        for i in range(1, size + 1):
            x = x0 + side * i
            z = -2 - i // 3
            hi = y0 + 1 + int(round(size * 0.8 * math.sin(math.pi * i / (size + 1)) + i * 0.45))
            lo = y0 - 1 + i // 2 + (1 if i % 2 == 0 else 0)
            for y in range(lo, hi + 1):
                edge = y >= hi - 1 or i == size
                p.voxel((x, y, z), ctx.col(tip) if edge else ctx.col(color))
                if i < size and lo < y < hi:
                    p.voxel((x, y, z - 1), ctx.col(color))
        ctx.anims.append(("flap", name, side))


def x_horns(ctx, color="cream", tip="white", **_):
    y = ctx.g.top - 1
    for s in (-1, 1):
        x = s * int(math.floor(ctx.g.r(y)))
        pts = [(x, y, 0), (x + s, y + 1, 0), (x + s, y + 2, -1), (x, y + 3, -1)]
        for a, b in zip(pts, pts[1:]):
            ctx.shell.line(a, b, ctx.col(color))
        ctx.shell.voxel(pts[-1], ctx.col(tip))


def x_ears(ctx, color="base", inner="pink", **_):
    y = ctx.g.top - 1
    for s in (-1, 1):
        x = s * 2
        ctx.shell.voxels([(x, y + 1, 0), (x, y + 2, 0), (x + s, y + 1, 0)], ctx.col(color))
        ctx.shell.voxel((x, y + 1, 1), ctx.col(inner), stud=False)


def x_flame(ctx, outer="fire", inner="neon_yellow", core="light", **_):
    t = ctx.g.H
    p = ctx.part("flame", pivot=(0, t, 0))
    p.add(S.box((-1, t, -1), (1, t, 1)), ctx.col(outer))
    p.add(S.box((-1, t + 1, 0), (1, t + 1, 0)), ctx.col(outer))
    p.add(S.box((0, t + 1, -1), (0, t + 1, 1)), ctx.col(outer))
    p.voxels([(0, t + 1, 0), (0, t + 2, 0)], ctx.col(inner))
    p.voxel((0, t + 3, 0), ctx.col(core))
    ctx.anims.append(("bob", "flame", 0.4))


def x_snowcap(ctx, color="snow", **_):
    p_drips(ctx, **{"from": 0.74, "color": color, "count": 6, "max_len": 2, "seed": 9})
    t = ctx.g.H
    ctx.shell.voxels([(0, t, 0), (1, t, 0), (0, t, 1)], ctx.col(color))


def x_icicles(ctx, color="ice", at=0.62, count=8, **_):
    y = int(round(at * (ctx.g.H - 1)))
    ctx.shell.add(S.ring((0, y, 0), ctx.g.r(y) + 1.0, 1.0, height=1), ctx.col(color))
    for k in range(count):
        ang = 2 * math.pi * (k + 0.5) / count
        L = 1 + (k % 3)
        for dy in range(1, L + 1):
            ctx.shell.voxel(ctx.g.surface_point(ang, y - dy, 0.9), ctx.col(color))


def x_spikes(ctx, color="accent2", count=8, at=0.5, **_):
    y = int(round(at * (ctx.g.H - 1)))
    for k in range(count):
        ang = 2 * math.pi * k / count
        ctx.shell.voxel(ctx.g.surface_point(ang, y, 1), ctx.col(color))
        ctx.shell.voxel(ctx.g.surface_point(ang, y + 1, 1.6), ctx.col(color))


def x_ridge(ctx, color="accent2", **_):
    for y in range(2, ctx.g.H, 2):
        p = ctx.g.surface_point(-math.pi / 2, y, 1)
        ctx.shell.voxels([p, (p[0], p[1] + 1, p[2] - 1)], ctx.col(color))


def x_gear(ctx, color="copper", hub="gunmetal", at=0.5, size=2.6, **_):
    y = int(round(at * (ctx.g.H - 1)))
    z = int(math.floor(ctx.g.r(y))) + 1
    disc = S.cylinder((0, y, z), size, 1, "z")
    teeth = []
    for k in range(8):
        ang = 2 * math.pi * k / 8
        teeth.append((int(round(math.cos(ang) * (size + 1))), y + int(round(math.sin(ang) * (size + 1))), z))
    ctx.shell.add(disc, ctx.col(color))
    ctx.shell.voxels(teeth, ctx.col(color))
    ctx.shell.voxel((0, y, z), ctx.col(hub))


def x_rivets(ctx, color="gunmetal", rows=(0.25, 0.75), count=8, **_):
    for fr in rows:
        y = int(round(fr * (ctx.g.H - 1)))
        for k in range(count):
            ctx.shell.voxel(ctx.g.surface_point(2 * math.pi * k / count, y, 0.9), ctx.col(color), stud=False)


def x_pipe(ctx, color="copper", steam="white", **_):
    t = ctx.g.H
    ctx.shell.box((1, t - 1, -1), (2, t + 1, 0), ctx.col(color))
    p = ctx.part("steam", pivot=(1, t + 2, 0))
    p.voxels([(1, t + 2, 0), (2, t + 3, -1), (1, t + 4, 0), (2, t + 4, 0)], ctx.col(steam))
    ctx.anims.append(("bob", "steam", 0.6))


def x_candle(ctx, wax="cream", flame="fire", **_):
    t = ctx.g.H
    ctx.shell.box((0, t, 0), (0, t + 1, 0), ctx.col(wax))
    p = ctx.part("flame", pivot=(0, t + 2, 0))
    p.voxels([(0, t + 2, 0)], ctx.col(flame))
    p.voxel((0, t + 3, 0), ctx.col("neon_yellow"))
    ctx.anims.append(("bob", "flame", 0.25))


def x_witch_hat(ctx, color="dark_purple", band="lime", **_):
    t = ctx.g.H - 1
    ctx.shell.add(S.disc((0, t, 0), 3.2), ctx.col(color))
    ctx.shell.add(S.cylinder((0, t + 1, 0), 2.0, 1), ctx.col(band))
    ctx.shell.add(S.cylinder((0, t + 2, 0), 1.6, 2, top_radius=0.8), ctx.col(color))
    ctx.shell.voxels([(0, t + 4, 0), (0, t + 5, -1), (0, t + 6, -2)], ctx.col(color))


def x_stem(ctx, color="dark_brown", leaf="green", **_):
    t = ctx.g.H
    ctx.shell.voxels([(0, t, 0), (0, t + 1, 0), (1, t + 2, 0)], ctx.col(color))
    ctx.shell.voxels([(1, t, 0), (2, t, 1), (2, t + 1, 1)], ctx.col(leaf))


def x_bat_wings(ctx, color="charcoal", **_):
    x_wings(ctx, color=color, tip=color, size=3)


def x_lily_pad(ctx, color="green", flower="pink", **_):
    pad = S.difference(S.disc((0, 0, 0), ctx.g.R + 2.2), S.box((1, 0, 3), (2, 0, 9)))
    ctx.shell.add(pad, ctx.col(color))
    x = int(ctx.g.R) + 1
    ctx.shell.voxels([(-x, 1, 1), (-x - 1, 1, 1), (-x, 1, 2)], ctx.col(flower))
    ctx.shell.voxel((-x, 2, 1), ctx.col("yellow"))


def x_bubbles(ctx, color="glass", **_):
    p = ctx.part("bubbles", pivot=(0, ctx.g.mid, 0))
    R = ctx.g.R
    for k, (ang, y, s) in enumerate(((0.3, 0.3, 1.0), (2.2, 0.62, 0.7), (4.1, 0.45, 0.9), (5.3, 0.85, 0.5))):
        cx, cz = math.cos(ang) * (R + 2.5), math.sin(ang) * (R + 2.5)
        p.add(S.sphere((cx, y * ctx.g.H, cz), s + 0.2), ctx.col(color))
    ctx.anims.append(("spin", "bubbles", 1))
    ctx.anims.append(("bob", "bubbles", 0.6))


def x_coral(ctx, color="coral", color2="hot_pink", **_):
    R = ctx.g.R
    for ang, col in ((2.4, color), (3.6, color2), (0.4, color)):
        x, z = math.cos(ang) * (R + 0.5), math.sin(ang) * (R + 0.5)
        base = (round(x), 0, round(z))
        tip = (round(x * 1.35), 4, round(z * 1.35))
        ctx.shell.line(base, tip, ctx.col(col))
        ctx.shell.line((round(x * 1.15), 2, round(z * 1.15)), (round(x * 1.5), 3, round(z * 1.5) + 1), ctx.col(col))


def x_fins(ctx, color="accent2", count=4, **_):
    for k in range(count):
        ang = 2 * math.pi * k / count + math.pi / 4
        for h in range(3):
            for o in range(1, 3 - h):
                ctx.shell.voxel(ctx.g.surface_point(ang, h, o), ctx.col(color))


def x_side_fins(ctx, color="accent2", **_):
    y = ctx.g.mid
    for s in (-1, 1):
        x = s * (int(math.floor(ctx.g.r(y))) + 1)
        ctx.shell.voxels([(x, y, 0), (x + s, y + 1, -1), (x, y + 1, -1), (x + s, y, -1)], ctx.col(color))
    z = -(int(math.floor(ctx.g.r(y))) + 1)
    ctx.shell.voxels([(0, y, z), (0, y + 1, z - 1), (0, y - 1, z - 1), (0, y + 2, z - 1), (0, y - 2, z - 1)],
                     ctx.col(color))


def x_planet_ring(ctx, color="accent2", color2="accent", **_):
    y = ctx.g.mid + 1
    p = ctx.part("ring", pivot=(0, y, 0))
    ring = S.ring((0, y, 0), ctx.g.R + 3.0, 1.6, height=1)
    p.add(ring, ctx.col(color))
    u = _u(ring)
    p.paint(ring[np.floor(u * 12) % 2 == 0], ctx.col(color2))
    ctx.anims.append(("spin", "ring", 1))


def x_orbit(ctx, color="glow", count=3, **_):
    p = ctx.part("orbit", pivot=(0, ctx.g.mid, 0))
    for k in range(count):
        ang = 2 * math.pi * k / count
        y = ctx.g.mid + (k % 2) * 3 - 1
        x, z = math.cos(ang) * (ctx.g.R + 2.6), math.sin(ang) * (ctx.g.R + 2.6)
        p.add(S.box_c((round(x), y, round(z)), (1, 1, 1)), ctx.col(color))
    ctx.anims.append(("spin", "orbit", -1))


def x_moon(ctx, color="light_yellow", **_):
    p = ctx.part("orbit", pivot=(0, ctx.g.mid, 0))
    x = int(ctx.g.R) + 3
    p.add(S.sphere((x, ctx.g.H - 3, 0), 1.3), ctx.col(color))
    p.carve(S.sphere((x + 1, ctx.g.H - 2, 0), 1.0))
    ctx.anims.append(("spin", "orbit", 1))


def x_comet_tail(ctx, colors=("light", "neon_cyan", "sky"), **_):
    """A streaming tail from the top towards the right-back (visible from the usual 3/4 view)."""
    t = ctx.g.top
    for i, col in enumerate(colors):
        for j in range(4):
            k = i * 4 + j
            x = int(round(ctx.g.r(t - k // 2) * 0.6)) + k
            ctx.shell.voxel((x, t - k // 2, -1 - k // 3), ctx.col(col), stud=False)
            if j % 2 == 0:
                ctx.shell.voxel((x, t - k // 2 + 1, -1 - k // 3), ctx.col(col), stud=False)


def x_antenna(ctx, color="steel", tip="glow", **_):
    t = ctx.g.H
    ctx.shell.voxels([(0, t, 0), (0, t + 1, 0), (0, t + 2, 0)], ctx.col(color))
    ctx.shell.voxel((0, t + 3, 0), ctx.col(tip))


def x_big_eye(ctx, iris="glow", at=0.55, **_):
    p_art(ctx, rows=[".WWW.", "WWIWW", "WIBIW", "WWIWW", ".WWW."], at=(None, at),
          colors={"W": "white", "I": iris, "B": "black"})


def x_question(ctx, color="glow", at=0.68, **_):
    p_art(ctx, rows=[".QQ.", "Q..Q", "..Q.", ".Q..", "....", ".Q.."], at=(None, at), colors={"Q": color})


def x_gem(ctx, color="crystal", at=0.5, **_):
    p_art(ctx, rows=[".G.", "GGG", ".G."], at=(None, at), colors={"G": color}, emboss=True)


def x_clouds(ctx, color="white", **_):
    R = ctx.g.R
    for k, ang in enumerate((0.2, 1.4, 2.6, 3.9, 5.1)):
        cx, cz = math.cos(ang) * (R + 0.8), math.sin(ang) * (R + 0.8)
        ctx.shell.add(S.blob((cx, 0.8, cz), (1.8, 1.2, 1.8), noise=0.1, seed=k), ctx.col(color))


def x_feather(ctx, color="accent2", tip="accent", **_):
    t = ctx.g.H
    pts = [(0, t - 1, 0), (1, t + 1, -1), (2, t + 3, -1), (2, t + 4, -2)]
    for a, b in zip(pts, pts[1:]):
        ctx.shell.line(a, b, ctx.col(color))
    ctx.shell.voxels([(2, t + 5, -2), (3, t + 4, -2)], ctx.col(tip))


def x_lightning(ctx, color="neon_yellow", at=0.8, **_):
    p_art(ctx, rows=["..YY", ".YY.", "YYYY", ".YY.", "YY..", "Y..."], at=(None, at), colors={"Y": color})


def x_rays(ctx, color="glow", count=8, **_):
    y = ctx.g.mid
    p = ctx.part("rays", pivot=(0, y, 0))
    for k in range(count):
        ang = 2 * math.pi * k / count
        a = ctx.g.surface_point(ang, y, 2.0)
        b = ctx.g.surface_point(ang, y, 3.5)
        p.add(S.line(a, b), ctx.col(color))
    ctx.anims.append(("spin", "rays", 1))


def x_petals(ctx, color="pink", color2="blush", **_):
    p = ctx.part("petals", pivot=(0, ctx.g.mid, 0))
    rng = _rng(11)
    for k in range(7):
        ang = 2 * math.pi * k / 7 + rng.random() * 0.4
        y = int(rng.integers(2, ctx.g.H))
        p.voxel(ctx.g.surface_point(ang, y, 2.5 + rng.random()), ctx.col(color if k % 2 else color2))
    ctx.anims.append(("spin", "petals", 1))
    ctx.anims.append(("bob", "petals", 0.5))


def x_bamboo(ctx, color="lime", node="olive", **_):
    R = ctx.g.R
    for s, h in ((-1, 9), (1, 7)):
        x = s * (int(R) + 2)
        for y in range(0, h):
            ctx.shell.voxel((x, y, -1), ctx.col(node if y % 3 == 2 else color))
        ctx.shell.voxels([(x + s, h - 1, -1), (x + 2 * s, h, -1)], ctx.col("green"))


def x_bow(ctx, color="accent", knot="accent2", **_):
    t = ctx.g.H
    ctx.shell.voxels([(-2, t, 0), (-1, t, 0), (-2, t + 1, 0), (1, t, 0), (2, t, 0), (2, t + 1, 0)], ctx.col(color))
    ctx.shell.voxel((0, t, 0), ctx.col(knot))


def x_gumdrops(ctx, colors=("red", "lime", "yellow", "sky", "hot_pink"), count=7, seed=6, **_):
    surf = _surface(ctx.shell)
    surf = surf[(surf[:, 1] > 1) & (surf[:, 1] < ctx.g.H - 1)]
    rng = _rng(seed)
    for k in range(count):
        p = surf[rng.integers(len(surf))]
        out = np.array([p[0], 0, p[2]], dtype=float)
        n = out / (np.linalg.norm(out) + 1e-6)
        q = (int(round(p[0] + n[0])), int(p[1]), int(round(p[2] + n[2])))
        ctx.shell.voxel(q, ctx.col(colors[k % len(colors)]))


def x_cherry(ctx, color="red", stem="green", **_):
    t = ctx.g.H
    ctx.shell.add(S.box((0, t, 0), (1, t + 1, 1)), ctx.col(color))
    ctx.shell.voxels([(1, t + 2, 1), (1, t + 3, 0)], ctx.col(stem))


def x_bite(ctx, filling="cream", **_):
    c = (ctx.g.R * 0.75, ctx.g.H * 0.78, ctx.g.R * 0.55)
    ctx.shell.carve(S.sphere(c, 2.6))
    ctx.shell.paint(S.sphere(c, 3.6), ctx.col(filling))


def x_bone(ctx, color="cream", **_):
    t = ctx.g.H
    ctx.shell.box((-2, t, 0), (2, t, 0), ctx.col(color))
    ctx.shell.voxels([(-3, t, 1), (-3, t, -1), (3, t, 1), (3, t, -1), (-3, t + 1, 0), (3, t + 1, 0)], ctx.col(color))


def x_fossil(ctx, color="accent2", at=0.5, **_):
    p_art(ctx, rows=[".FFF.", "F...F", "F.F.F", "F..F.", ".F..."], at=(None, at), colors={"F": color})


def x_inner(ctx, color="accent2", shape="blob", **_):
    """Something trapped inside a see-through shell (amber bug, frozen gem, ghost)."""
    g = ctx.g
    p = ctx.part("core", pivot=(0, g.mid, 0))
    if shape == "bug":
        p.add(S.ellipsoid((0, g.mid, 0), (1.2, 1.2, 2.2)), ctx.col(color))
        p.voxels([(-2, g.mid, 1), (2, g.mid, 1), (-2, g.mid, -1), (2, g.mid, -1), (0, g.mid + 1, 3)], ctx.col(color))
    elif shape == "gem":
        p.add(S.ellipsoid((0, g.mid + 1, 0), (1.6, 2.4, 1.6)), ctx.col(color))
    else:
        p.add(S.sphere((0, g.mid + 1, 0), 2.0), ctx.col(color))
    ctx.shell.carve(p.coords())             # the core replaces the shell voxels it sits in
    ctx.anims.append(("spin", "core", 1))


def x_crystals(ctx, color="crystal", count=5, **_):
    for k in range(count):
        ang = 2 * math.pi * k / count + 0.3
        y = 2 + (k * 3) % max(ctx.g.H - 4, 1)
        a = ctx.g.surface_point(ang, y, 0)
        b = ctx.g.surface_point(ang, y + 2, 2.2)
        ctx.shell.line(a, b, ctx.col(color))


def x_chains(ctx, color="gunmetal", at=0.45, **_):
    y = int(round(at * (ctx.g.H - 1)))
    ring = S.ring((0, y, 0), ctx.g.r(y) + 1.0, 1.0, height=1)
    keep = ring[np.floor(_u(ring) * 16) % 2 == 0]
    ctx.shell.add(keep, ctx.col(color))
    ctx.shell.voxel((0, y - 1, int(ctx.g.r(y)) + 1), ctx.col("gold"))


def x_skull(ctx, color="white", eyes="glow", at=0.6, **_):
    p_art(ctx, rows=[".WWW.", "WEWEW", "WWWWW", ".W.W."], at=(None, at), colors={"W": color, "E": eyes})


def x_ghost(ctx, color="white", **_):
    x = int(ctx.g.R) + 1
    p = ctx.part("ghost", pivot=(x, 3, 0))
    p.add(S.ellipsoid((x + 1, 4, 1), (1.4, 1.8, 1.2)), ctx.col(color))
    p.voxels([(x + 1, 3, 2)], ctx.col(color))
    p.voxels([(x, 5, 2), (x + 2, 5, 2)], ctx.col("black"), stud=False)
    ctx.anims.append(("bob", "ghost", 0.7))


def x_thunder_cloud(ctx, color="dark_gray", bolt="neon_yellow", **_):
    t = ctx.g.H
    p = ctx.part("cloud", pivot=(0, t + 2, 0))
    p.add(S.blob((0, t + 2, 0), (3, 1.4, 2.2), noise=0.12, seed=3), ctx.col(color))
    p.voxels([(1, t, 2), (2, t - 1, 2), (1, t - 2, 2)], ctx.col(bolt))
    ctx.anims.append(("bob", "cloud", 0.4))


def x_aura(ctx, color="glow", **_):
    """Glowing rarity ring on the ground around the egg (its own part, so a game can hide it when carried)."""
    p = ctx.part("aura", pivot=(0, 0, 0))
    p.add(S.ring((0, 0, 0), ctx.g.R + 2.2, 1.0, height=1), ctx.col(color))


def x_sparkles(ctx, color="glow", count=7, **_):
    p = ctx.part("sparkles", pivot=(0, ctx.g.mid, 0))
    rng = _rng(21)
    for k in range(count):
        ang = 2 * math.pi * k / count
        y = int(rng.integers(1, ctx.g.H + 2))
        p.voxel(ctx.g.surface_point(ang, min(y, ctx.g.H - 1), 3.0 + rng.random() * 1.5) if y < ctx.g.H
                else (int(round(math.cos(ang) * 2)), y, int(round(math.sin(ang) * 2))), ctx.col(color))
    ctx.anims.append(("spin", "sparkles", 1))
    ctx.anims.append(("bob", "sparkles", 0.5))


def x_tiki(ctx, at=0.62, **_):
    p_art(ctx, rows=["BBBBB", "BYBYB", "BBBBB", ".RRR.", ".BBB."], at=(None, at),
          colors={"B": "dark_brown", "Y": "neon_yellow", "R": "red"})


def x_cactus_arms(ctx, color="green", flower="hot_pink", **_):
    y = ctx.g.mid
    for s, dy in ((-1, 0), (1, 2)):
        x = s * (int(math.floor(ctx.g.r(y + dy))) + 1)
        ctx.shell.voxels([(x, y + dy, 0), (x + s, y + dy, 0), (x + s, y + dy + 1, 0), (x + s, y + dy + 2, 0)],
                         ctx.col(color))
    ctx.shell.voxel((0, ctx.g.H, 0), ctx.col(flower))


def x_palm(ctx, trunk="light_brown", leaf="green", **_):
    t = ctx.g.H
    ctx.shell.voxels([(0, t, 0), (0, t + 1, 0), (0, t + 2, 0)], ctx.col(trunk))
    for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        ctx.shell.voxels([(dx, t + 3, dz), (2 * dx, t + 3, 2 * dz), (3 * dx, t + 2, 3 * dz)], ctx.col(leaf))
    ctx.shell.voxel((0, t + 3, 0), ctx.col(leaf))


def x_sun_disk(ctx, color="glow", **_):
    p = ctx.part("sundisk", pivot=(0, ctx.g.mid + 1, -int(ctx.g.R) - 2))
    z = -int(ctx.g.R) - 2
    ring = S.ring((0, ctx.g.mid + 1, z), ctx.g.R + 3.5, 1.2, axis="z")
    p.add(ring, ctx.col(color))
    u = (np.arctan2(ring[:, 1] - (ctx.g.mid + 1), ring[:, 0]) / (2 * math.pi)) % 1.0
    p.paint(ring[np.floor(u * 12) % 2 == 0], ctx.col("gold"))
    ctx.anims.append(("spinz", "sundisk", 1))


def x_scarab(ctx, color="teal", at=0.55, **_):
    p_art(ctx, rows=[".G.G.", "GGGGG", ".GGG.", "G.G.G"], at=(None, at), colors={"G": color}, emboss=True)


def x_lantern_ring(ctx, color="gold", **_):
    t = ctx.g.H
    ctx.shell.voxels([(-1, t, 0), (-1, t + 1, 0), (0, t + 2, 0), (1, t + 1, 0), (1, t, 0)], ctx.col(color))


def x_starfish(ctx, color="orange", at=0.5, **_):
    p_art(ctx, rows=["..S..", "SSSSS", ".SSS.", "S...S"], at=(None, at), colors={"S": color}, emboss=True)


def x_anchor(ctx, color="steel", at=0.62, **_):
    p_art(ctx, rows=[".A.", "AAA", ".A.", "AAA", "A.A"], at=(None, at), colors={"A": color})


def x_trident(ctx, color="gold", **_):
    x = int(ctx.g.R) + 2
    for y in range(0, ctx.g.H + 3):
        ctx.shell.voxel((x, y, 0), ctx.col(color))
    ctx.shell.voxels([(x - 1, ctx.g.H + 1, 0), (x + 1, ctx.g.H + 1, 0), (x - 1, ctx.g.H + 2, 0),
                      (x + 1, ctx.g.H + 2, 0), (x, ctx.g.H + 3, 0)], ctx.col(color))


def x_mushroom(ctx, cap="red", spot="white", stem="cream", **_):
    t = ctx.g.H
    ctx.shell.box((0, t, 0), (0, t, 0), ctx.col(stem))
    ctx.shell.add(S.cylinder((0, t + 1, 0), 2.2, 1), ctx.col(cap))
    ctx.shell.add(S.cylinder((0, t + 2, 0), 1.3, 1), ctx.col(cap))
    ctx.shell.voxels([(1, t + 2, 1), (-2, t + 1, 0)], ctx.col(spot))


def x_honey_drip(ctx, color="gold", **_):
    p_drips(ctx, **{"from": 0.8, "color": color, "count": 5, "max_len": 3, "seed": 5})


def x_eyes_peek(ctx, color="glow", at=0.6, **_):
    p_art(ctx, rows=["E...E"], at=(None, at), colors={"E": color})


def x_runes(ctx, color="glow", **_):
    p_art(ctx, rows=["R.R.R", ".....", "R...R", ".R.R."], at=(None, 0.62), colors={"R": color})


EXTRAS = {
    "sprout": x_sprout, "flower": x_flower, "leaf_crown": x_leaf_crown, "crown": x_crown, "halo": x_halo,
    "wings": x_wings, "horns": x_horns, "ears": x_ears, "flame": x_flame, "snowcap": x_snowcap,
    "icicles": x_icicles, "spikes": x_spikes, "ridge": x_ridge, "gear": x_gear, "rivets": x_rivets,
    "pipe": x_pipe, "candle": x_candle, "witch_hat": x_witch_hat, "stem": x_stem, "bat_wings": x_bat_wings,
    "lily_pad": x_lily_pad, "bubbles": x_bubbles, "coral": x_coral, "fins": x_fins, "side_fins": x_side_fins,
    "planet_ring": x_planet_ring, "orbit": x_orbit, "moon": x_moon, "comet_tail": x_comet_tail,
    "antenna": x_antenna, "big_eye": x_big_eye, "question": x_question, "gem": x_gem, "clouds": x_clouds,
    "feather": x_feather, "lightning": x_lightning, "rays": x_rays, "petals": x_petals, "bamboo": x_bamboo,
    "bow": x_bow, "gumdrops": x_gumdrops, "cherry": x_cherry, "bite": x_bite, "bone": x_bone,
    "fossil": x_fossil, "inner": x_inner, "crystals": x_crystals, "chains": x_chains, "skull": x_skull,
    "ghost": x_ghost, "thunder_cloud": x_thunder_cloud, "aura": x_aura, "sparkles": x_sparkles, "tiki": x_tiki,
    "cactus_arms": x_cactus_arms, "palm": x_palm, "sun_disk": x_sun_disk, "scarab": x_scarab,
    "lantern_ring": x_lantern_ring, "starfish": x_starfish, "anchor": x_anchor, "trident": x_trident,
    "mushroom": x_mushroom, "honey_drip": x_honey_drip, "eyes_peek": x_eyes_peek, "runes": x_runes,
}

ANIMATED = {"halo", "wings", "flame", "pipe", "candle", "bat_wings", "bubbles", "planet_ring", "orbit", "moon",
            "rays", "petals", "inner", "ghost", "thunder_cloud", "aura", "sparkles", "sun_disk"}


# ---------------------------------------------------------------------------- build

def _norm(items):
    out = []
    for it in items:
        if isinstance(it, str):
            out.append((it, {}))
        else:
            out.append((it[0], dict(it[1]) if len(it) > 1 else {}))
    return out


def build_egg(d: EggDesign) -> Model:
    r = RARITY[d.rarity]
    b = BIOME[d.biome]
    H = d.height or r["h"]
    W = d.width or r["w"]
    stats = egg_stats(d.biome, d.rarity)
    m = Model(d.id, title=d.name, category="eggs",
              description=f"{b['title']} · {r['title']} egg. {d.flavor}".strip(),
              tags=["egg", d.biome, d.rarity])
    m.roblox["highlight"] = False          # many eggs on screen: Highlights are capped at 31
    m.roblox["collide"] = True
    g = EggGeo(H, W)
    shell = m.part("shell", pivot=(0, 0, 0))
    shell.add(g.coords(), d.base)
    ctx = Ctx(m, shell, g, d)

    for kind, args in _norm(d.patterns):
        if "from" in args:
            args["from_"] = args.pop("from")
        PATTERNS[kind](ctx, **args)

    extras = _norm(d.extras)
    names = {k for k, _ in extras}
    ri = RARITIES.index(r)
    if ri >= RARITIES.index(RARITY["legendary"]) and "aura" not in names and "no_aura" not in names:
        extras.append(("aura", {}))
    if d.rarity == "celestial" and not (names & ANIMATED - {"aura"}):
        extras.append(("sparkles", {}))
    if d.rarity == "divine":
        if "halo" not in names:
            extras.append(("halo", {}))
        if "wings" not in names and "bat_wings" not in names:
            extras.append(("wings", {"color": "white", "tip": "gold"}))
    for kind, args in extras:
        if kind == "no_aura":
            continue
        EXTRAS[kind](ctx, **args)

    _clips(m, ctx)
    m.meta["egg"] = {"id": d.id, "name": d.name, "biome": d.biome, "biome_title": b["title"], "rarity": d.rarity,
                     "rarity_title": r["title"], "rarity_color": r["color"], "flavor": d.flavor, **stats}
    m.notes = [f"{b['title']} egg · {r['title']} ({r['spawn']:g}% spawn)",
               f"Hatch {stats['hatch_seconds']}s · base {stats['base_weight']:g} kg · ${stats['base_income']:,.0f}/s",
               "Idle wobble + hatch shake clips; mutations recolour it at runtime"]
    return m


def _clips(m: Model, ctx: Ctx):
    idle = m.clip("idle", 2.4)
    idle.osc("shell", rot=(1.5, 0, 2.5), period=2.4)
    hatch = m.clip("hatch", 1.6, loop=False)
    hatch.keys("shell", [(0, {}), (0.15, {"rot": (0, 0, 9)}), (0.3, {"rot": (0, 0, -9)}), (0.45, {"rot": (0, 0, 13)}),
                         (0.6, {"rot": (0, 0, -13)}), (0.75, {"rot": (4, 0, 17)}), (0.9, {"rot": (-4, 0, -17)}),
                         (1.1, {"pos": (0, 1.5, 0), "rot": (0, 0, 0), "ease": "out"}), (1.35, {"pos": (0, 0, 0), "ease": "in"}),
                         (1.6, {})])
    seen = set()
    for a in ctx.anims:
        kind, part = a[0], a[1]
        if (kind, part) in seen:
            continue
        seen.add((kind, part))
        if kind == "spin":
            idle.spin(part, "y", turns=a[2])
            hatch.osc(part, rot=(0, 120 * a[2], 0), period=1.6, wave="saw")
        elif kind == "spinz":
            idle.spin(part, "z", turns=a[2])
        elif kind == "bob":
            idle.osc(part, pos=(0, a[2], 0), period=1.2)
        elif kind == "flap":
            side = a[2]
            idle.osc(part, rot=(0, 0, 14 * side), period=0.8)
            hatch.osc(part, rot=(0, 0, 30 * side), period=0.2)
