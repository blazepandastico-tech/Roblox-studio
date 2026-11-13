"""Model / Part authoring API.

A :class:`Model` is a set of named :class:`Part` s (rig bones). Each part owns
voxels in the shared author space and rotates around its ``pivot``. Parts can
be parented to build a hierarchy (body -> head -> ear). Animation clips move
parts around their pivots.

Author space: **+X right, +Y up, +Z front** (the side the model faces).
"""

from __future__ import annotations

import math
from typing import Callable, Iterable, Sequence

import numpy as np

from . import shapes as S
from .anim import Clip
from .palette import DEFAULT_PALETTE, MATERIALS, default_studs_for, parse_hex, to_hex

NOSTUD = 1 << 12
COLOR_MASK = NOSTUD - 1

CATEGORIES = ("eggs", "critters", "bosses", "mobs", "buildings", "props", "nature", "terrain", "weapons", "traced")

# Roblox scale per category (studs per voxel). At 1.0 every voxel lines up with
# exactly one stud of Roblox's native Studs surface. Smaller models use the
# "texture" stud mode (one stud image per voxel) when a stud texture asset id
# is configured, otherwise they fall back to the native surface.
CATEGORY_VOXEL_SIZE = {
    "eggs": 1.0,
    "critters": 0.25,
    "bosses": 1.0,
    "mobs": 0.5,
    "buildings": 1.0,
    "props": 1.0,
    "nature": 1.0,
    "terrain": 1.0,
    "weapons": 0.125,
    "traced": 0.25,
}

ColorRef = str | tuple


class Part:
    """A rigid group of voxels that moves as one (one bone)."""

    def __init__(self, model: "Model", name: str, parent: str | None, pivot, studs: bool):
        self.model = model
        self.name = name
        self.parent = parent
        self.pivot = None if pivot is None else tuple(float(v) for v in pivot)
        self.studs = studs
        self.vox: dict[tuple[int, int, int], int] = {}

    # ------------------------------------------------------------ core ops
    def _value(self, color: ColorRef, stud: bool | None) -> int:
        idx = self.model.color_index(color)
        if stud is None:
            stud = self.model._palette[idx]["studs"]
        return idx | (0 if stud else NOSTUD)

    def add(self, coords: np.ndarray, color: ColorRef, *, stud: bool | None = None) -> "Part":
        v = self._value(color, stud)
        for p in np.asarray(coords, dtype=np.int32).reshape(-1, 3).tolist():
            self.vox[(p[0], p[1], p[2])] = v
        return self

    def carve(self, coords: np.ndarray) -> "Part":
        for p in np.asarray(coords, dtype=np.int32).reshape(-1, 3).tolist():
            self.vox.pop((p[0], p[1], p[2]), None)
        return self

    def paint(self, coords: np.ndarray, color: ColorRef, *, only: Iterable[ColorRef] | None = None,
              stud: bool | None = None) -> "Part":
        """Recolour voxels that already exist inside ``coords``."""
        v = self._value(color, stud)
        allowed = None if only is None else {self.model.color_index(c) for c in only}
        for p in np.asarray(coords, dtype=np.int32).reshape(-1, 3).tolist():
            k = (p[0], p[1], p[2])
            cur = self.vox.get(k)
            if cur is None:
                continue
            if allowed is not None and (cur & COLOR_MASK) not in allowed:
                continue
            self.vox[k] = v
        return self

    def paint_where(self, fn: Callable[[np.ndarray, np.ndarray, np.ndarray], np.ndarray], color: ColorRef,
                    *, only: Iterable[ColorRef] | None = None, stud: bool | None = None) -> "Part":
        """Recolour voxels where ``fn(x, y, z)`` (numpy arrays) is True."""
        c = self.coords()
        if len(c) == 0:
            return self
        mask = np.asarray(fn(c[:, 0], c[:, 1], c[:, 2]), dtype=bool)
        return self.paint(c[mask], color, only=only, stud=stud)

    def paint_top(self, color: ColorRef, depth: int = 1, *, only: Iterable[ColorRef] | None = None,
                  stud: bool | None = None) -> "Part":
        """Recolour voxels within ``depth`` of an open top (grass on dirt, snow caps)."""
        sel = []
        for (x, y, z) in self.vox:
            for k in range(1, depth + 1):
                if (x, y + k, z) not in self.vox:
                    sel.append((x, y, z))
                    break
        return self.paint(np.asarray(sel, dtype=np.int32).reshape(-1, 3), color, only=only, stud=stud)

    def speckle(self, colors: dict[ColorRef, float], *, only: Iterable[ColorRef] | None = None,
                seed: int = 0, where: np.ndarray | None = None) -> "Part":
        """Randomly recolour voxels with a weighted mix, e.g. ``{"stone": .6, "dark_stone": .4}``."""
        c = self.coords() if where is None else S.intersect(where, self.coords())
        if len(c) == 0:
            return self
        h = S._hash3(c[:, 0].astype(np.int64), c[:, 1].astype(np.int64), c[:, 2].astype(np.int64), seed + 101)
        total = float(sum(colors.values()))
        acc = 0.0
        for col, w in colors.items():
            lo, acc = acc, acc + w / total
            sel = c[(h >= lo) & (h < acc + (1e-9 if acc >= 0.999 else 0))]
            self.paint(sel, col, only=only)
        return self

    def _surface_columns(self, facing: str):
        """Axis index, sign, and (u, v) axis indices for painting on a side of the part."""
        sign = 1 if facing[0] == "+" else -1
        a = S.AXES[facing[1]]
        # u runs left->right and v runs top->bottom as seen when looking at that side
        uv = {
            ("z", 1): (0, 1, 1, -1), ("z", -1): (0, -1, 1, -1),
            ("x", 1): (2, -1, 1, -1), ("x", -1): (2, 1, 1, -1),
            ("y", 1): (0, 1, 2, 1), ("y", -1): (0, 1, 2, -1),
        }[(facing[1], sign)]
        return a, sign, uv

    def decal(self, rows: Sequence[str], at: Sequence[int], colors: dict[str, ColorRef], *,
              facing: str = "+z", depth: int = 1, stud: bool | None = None, mirror: bool = False) -> "Part":
        """Paint ASCII-art pixels onto the outermost voxels of one side (faces, eyes, logos, windows).

        ``rows`` are read top to bottom, left to right as seen from the ``facing`` side.
        ``at`` is the voxel coordinate of the top-left character (the coordinate along
        the facing axis is ignored). ``.`` or space = leave alone. With ``mirror`` the
        art is also painted mirrored around x = 0 (for symmetric faces).
        """
        a, sign, (ui, us, vi, vs) = self._surface_columns(facing)
        cols: dict[tuple[int, int], list[int]] = {}
        for (x, y, z) in self.vox:
            p = (x, y, z)
            cols.setdefault((p[ui], p[vi]), []).append(p[a])
        jobs = []
        for r, row in enumerate(rows):
            for c, ch in enumerate(row):
                if ch in ". " or ch not in colors:
                    continue
                u = at[ui] + c * us
                v = at[vi] + r * vs
                jobs.append((u, v, colors[ch]))
                if mirror and ui == 0:
                    jobs.append((int(round(-u)), v, colors[ch]))
        for u, v, col in jobs:
            depths = cols.get((u, v))
            if not depths:
                continue
            outer = max(depths) if sign > 0 else min(depths)
            for k in range(depth):
                p = [0, 0, 0]
                p[ui], p[vi], p[a] = u, v, outer - sign * k
                cur = self.vox.get(tuple(p))
                if cur is not None:
                    if stud is None:
                        self.vox[tuple(p)] = self.model.color_index(col) | (cur & NOSTUD)
                    else:
                        self.vox[tuple(p)] = self._value(col, stud)
        return self

    def emboss(self, rows: Sequence[str], at: Sequence[int], colors: dict[str, ColorRef], *,
               facing: str = "+z", height: int = 1, stud: bool | None = None, mirror: bool = False) -> "Part":
        """Like :meth:`decal` but adds ``height`` voxels on top of the surface (noses, buttons, trims)."""
        a, sign, (ui, us, vi, vs) = self._surface_columns(facing)
        cols: dict[tuple[int, int], list[int]] = {}
        for (x, y, z) in self.vox:
            p = (x, y, z)
            cols.setdefault((p[ui], p[vi]), []).append(p[a])
        jobs = []
        for r, row in enumerate(rows):
            for c, ch in enumerate(row):
                if ch in ". " or ch not in colors:
                    continue
                u = at[ui] + c * us
                v = at[vi] + r * vs
                jobs.append((u, v, colors[ch]))
                if mirror and ui == 0:
                    jobs.append((int(round(-u)), v, colors[ch]))
        for u, v, col in jobs:
            depths = cols.get((u, v))
            if not depths:
                continue
            outer = max(depths) if sign > 0 else min(depths)
            for k in range(1, height + 1):
                p = [0, 0, 0]
                p[ui], p[vi], p[a] = u, v, outer + sign * k
                self.vox[tuple(p)] = self._value(col, stud)
        return self

    def symmetrize(self, axis: str = "x", center: float = 0.0, *, keep: str = "+") -> "Part":
        """Mirror the ``keep`` half onto the other half (build one side, mirror the rest)."""
        a = S.AXES[axis]
        src = {k: v for k, v in self.vox.items() if (k[a] >= center if keep == "+" else k[a] <= center)}
        for k, v in src.items():
            m = list(k)
            m[a] = int(round(2 * center - k[a]))
            self.vox[tuple(m)] = v
        return self

    def move(self, d: Sequence[int]) -> "Part":
        dx, dy, dz = (int(round(v)) for v in d)
        self.vox = {(x + dx, y + dy, z + dz): v for (x, y, z), v in self.vox.items()}
        if self.pivot is not None:
            self.pivot = (self.pivot[0] + dx, self.pivot[1] + dy, self.pivot[2] + dz)
        return self

    def take(self, coords: np.ndarray, into: "Part") -> "Part":
        """Move the voxels inside ``coords`` from this part into another part."""
        for p in np.asarray(coords, dtype=np.int32).reshape(-1, 3).tolist():
            k = (p[0], p[1], p[2])
            if k in self.vox:
                into.vox[k] = self.vox.pop(k)
        return self

    # ------------------------------------------------------------ shortcuts
    def voxel(self, p: Sequence[int], color: ColorRef, **kw) -> "Part":
        return self.add(np.asarray([p], dtype=np.int32), color, **kw)

    def voxels(self, pts: Iterable[Sequence[int]], color: ColorRef, **kw) -> "Part":
        return self.add(np.asarray(list(pts), dtype=np.int32).reshape(-1, 3), color, **kw)

    def box(self, a, b, color, **kw):
        return self.add(S.box(a, b), color, **kw)

    def box_c(self, center, size, color, **kw):
        return self.add(S.box_c(center, size), color, **kw)

    def ellipsoid(self, center, radii, color, *, soft: float = 0.12, **kw):
        return self.add(S.ellipsoid(center, radii, soft=soft), color, **kw)

    def sphere(self, center, radius, color, *, soft: float = 0.12, **kw):
        return self.add(S.sphere(center, radius, soft=soft), color, **kw)

    def cylinder(self, base, radius, height, color, axis="y", *, top_radius=None, **kw):
        return self.add(S.cylinder(base, radius, height, axis, top_radius=top_radius), color, **kw)

    def cone(self, base, radius, height, color, axis="y", **kw):
        return self.add(S.cone(base, radius, height, axis), color, **kw)

    def disc(self, center, radius, color, axis="y", **kw):
        return self.add(S.disc(center, radius, axis), color, **kw)

    def line(self, a, b, color, radius: float = 0.0, **kw):
        return self.add(S.line(a, b, radius), color, **kw)

    def tube(self, points, radii, color, **kw):
        return self.add(S.tube(points, radii), color, **kw)

    def roof(self, a, b, color, ridge="x", *, overhang=0, step=1, **kw):
        return self.add(S.roof(a, b, ridge, overhang=overhang, step=step), color, **kw)

    def pyramid(self, a, b, color, *, step=1, **kw):
        return self.add(S.pyramid(a, b, step=step), color, **kw)

    def stairs(self, a, b, color, rise="+z", **kw):
        return self.add(S.stairs(a, b, rise), color, **kw)

    def blob(self, center, radii, color, *, noise=0.25, scale=3.0, seed=0, **kw):
        return self.add(S.blob(center, radii, noise=noise, scale=scale, seed=seed), color, **kw)

    # ------------------------------------------------------------ queries
    def coords(self) -> np.ndarray:
        if not self.vox:
            return np.zeros((0, 3), dtype=np.int32)
        return np.asarray(list(self.vox.keys()), dtype=np.int32)

    def has(self, p) -> bool:
        return tuple(int(v) for v in p) in self.vox

    def bounds(self):
        c = self.coords()
        if len(c) == 0:
            return None
        return c.min(axis=0), c.max(axis=0)

    def __len__(self):
        return len(self.vox)

    def __repr__(self):
        return f"<Part {self.name} parent={self.parent} voxels={len(self.vox)}>"


class Model:
    """A stud-style voxel model: parts (bones), palette, animation clips, metadata."""

    def __init__(self, name: str, *, title: str | None = None, category: str = "props",
                 description: str = "", voxel_size: float | None = None, tags: Iterable[str] = (),
                 origin="auto"):
        if category not in CATEGORIES:
            raise ValueError(f"category must be one of {CATEGORIES}")
        self.name = name
        self.title = title or name.replace("_", " ").title()
        self.category = category
        self.description = description
        self.voxel_size = float(voxel_size if voxel_size is not None else CATEGORY_VOXEL_SIZE[category])
        self.tags = list(tags)
        self.origin = origin
        self.parts: dict[str, Part] = {}
        self.clips: dict[str, Clip] = {}
        self._palette: list[dict] = []
        self._palette_lookup: dict[str, int] = {}
        self.custom_colors: dict[str, tuple[str, str]] = {}
        # Styling / export options (override per model as needed)
        self.outline = "auto"        # outline hull thickness in voxels ("auto" scales with model size, 0 = none)
        self.stud_mode = "top"       # "top" (flat stud texture on every open top face) or "none"
        self.roblox = {
            # "auto" | "surface" (native Studs top + Inlet bottom) | "universal" (native Universal top)
            # | "texture" (stud image per voxel, needs stud_texture) | "none"
            "studs": "auto",
            "stud_texture": None,    # e.g. "rbxassetid://123" (upload roblox/assets/stud_tile.png once)
            "anchored": True,        # anchor the root part
            "collide": category in ("buildings", "props", "nature", "terrain"),
            "highlight": True,       # add a black-outline Highlight to the Roblox model
            "default_clip": None,    # clip played automatically (defaults to "idle" if present)
        }
        self.meta: dict = {}
        self.notes: list[str] = []

    # ------------------------------------------------------------ colours
    def add_color(self, name: str, hex_value: str, material: str = "plastic", *, studs: bool | None = None) -> str:
        if material not in MATERIALS:
            raise ValueError(f"material must be one of {MATERIALS}")
        parse_hex(hex_value)
        self.custom_colors[name] = (hex_value, material)
        if studs is not None:
            self.custom_colors[name] = (hex_value, material, studs)  # type: ignore[assignment]
        return name

    def _resolve(self, ref: ColorRef) -> tuple[str, str, str, bool]:
        if isinstance(ref, tuple):
            hx, mat = ref[0], (ref[1] if len(ref) > 1 else "plastic")
            hx = to_hex(parse_hex(hx))
            return f"{hx}:{mat}", hx, mat, default_studs_for(mat)
        if ref in self.custom_colors:
            entry = self.custom_colors[ref]
            hx, mat = entry[0], entry[1]
            studs = entry[2] if len(entry) > 2 else default_studs_for(mat)
            return ref, to_hex(parse_hex(hx)), mat, studs
        if ref in DEFAULT_PALETTE:
            hx, mat = DEFAULT_PALETTE[ref]
            return ref, hx, mat, default_studs_for(mat)
        if isinstance(ref, str) and ref.startswith("#"):
            hx = to_hex(parse_hex(ref))
            return hx, hx, "plastic", True
        raise KeyError(f"unknown colour {ref!r} (use a palette name, '#rrggbb' or Model.add_color)")

    def color_index(self, ref: ColorRef) -> int:
        key, hx, mat, studs = self._resolve(ref)
        idx = self._palette_lookup.get(key)
        if idx is None:
            idx = len(self._palette)
            self._palette.append({"name": key, "hex": hx, "material": mat, "studs": studs})
            self._palette_lookup[key] = idx
        return idx

    # ------------------------------------------------------------ parts
    def part(self, name: str, *, parent: str | None = None, pivot=None, studs: bool = True) -> Part:
        if name in self.parts:
            raise ValueError(f"part {name!r} already exists")
        if parent is not None and parent not in self.parts:
            raise ValueError(f"parent {parent!r} must be created before {name!r}")
        p = Part(self, name, parent, pivot, studs)
        self.parts[name] = p
        return p

    def get(self, name: str) -> Part:
        return self.parts[name]

    def mirror_part(self, src: str, dst: str, *, axis: str = "x", center: float = 0.0,
                    parent: str | None = "__same__") -> Part:
        """Create ``dst`` as a mirror image of ``src`` (e.g. leg_l -> leg_r)."""
        s = self.parts[src]
        a = S.AXES[axis]
        par = s.parent if parent == "__same__" else parent
        piv = None
        if s.pivot is not None:
            piv = list(s.pivot)
            piv[a] = 2 * center - piv[a]
        p = self.part(dst, parent=par, pivot=piv, studs=s.studs)
        for k, v in s.vox.items():
            m = list(k)
            m[a] = int(round(2 * center - k[a]))
            p.vox[tuple(m)] = v
        return p

    def clip(self, name: str, length: float, *, loop: bool = True, fps: int = 24) -> Clip:
        c = Clip(self, name, length, loop=loop, fps=fps)
        self.clips[name] = c
        return c

    # ------------------------------------------------------------ layout helpers
    def tile(self, size_x: int, size_z: int | None = None, *, ground: int = 0):
        """Declare a modular terrain tile.

        The footprint covers voxels ``-size_x/2 .. size_x/2-1`` (and the same for z),
        the ground (bottom of the tile) is the bottom of voxel layer ``ground``.
        Tiles with the same size line up on a grid of ``size * voxel_size`` studs.
        """
        size_z = size_z or size_x
        self.origin = (-0.5, ground - 0.5, -0.5)
        self.meta["tile"] = {"size": [size_x, size_z], "studs": [size_x * self.voxel_size, size_z * self.voxel_size],
                             "x_range": [-size_x // 2, size_x // 2 - 1], "z_range": [-size_z // 2, size_z // 2 - 1]}
        return (-size_x // 2, size_x // 2 - 1, -size_z // 2, size_z // 2 - 1)

    def grip(self, pos: Sequence[float], *, forward: Sequence[float], up: Sequence[float]):
        """Weapons: where the hand holds it, which way points away from the player, which way is up."""
        self.meta["grip"] = {"pos": [float(v) for v in pos], "forward": [float(v) for v in forward],
                             "up": [float(v) for v in up]}

    # ------------------------------------------------------------ export
    def all_coords(self) -> np.ndarray:
        cs = [p.coords() for p in self.parts.values() if len(p)]
        return np.concatenate(cs) if cs else np.zeros((0, 3), dtype=np.int32)

    def resolved_origin(self) -> list[float]:
        if self.origin != "auto":
            return [float(v) for v in self.origin]
        c = self.all_coords()
        lo, hi = c.min(axis=0), c.max(axis=0)
        return [float((lo[0] + hi[0]) / 2), float(lo[1] - 0.5), float((lo[2] + hi[2]) / 2)]

    def validate(self):
        if not self.parts:
            raise ValueError("model has no parts")
        for p in self.parts.values():
            if not p.vox:
                raise ValueError(f"part {p.name!r} has no voxels")
        for c in self.clips.values():
            for part in c.tracks:
                if part not in self.parts:
                    raise ValueError(f"clip {c.name!r} animates unknown part {part!r}")

    def to_dict(self) -> dict:
        self.validate()
        # compact palette: only colours actually used, sorted by usage
        counts: dict[int, int] = {}
        for p in self.parts.values():
            for v in p.vox.values():
                counts[v & COLOR_MASK] = counts.get(v & COLOR_MASK, 0) + 1
        order = sorted(counts, key=lambda i: -counts[i])
        remap = {old: new for new, old in enumerate(order)}
        palette = []
        for old in order:
            e = dict(self._palette[old])
            e["count"] = counts[old]
            palette.append(e)
        parts = []
        for p in self.parts.values():
            pivot = p.pivot
            if pivot is None:
                lo, hi = p.bounds()
                pivot = tuple(float((a + b) / 2) for a, b in zip(lo, hi))
            vox = sorted(p.vox.items())
            parts.append({
                "name": p.name,
                "parent": p.parent,
                "pivot": [float(v) for v in pivot],
                "studs": bool(p.studs),
                "voxels": [[k[0], k[1], k[2], remap[v & COLOR_MASK] | (v & NOSTUD)] for k, v in vox],
            })
        c = self.all_coords()
        lo, hi = c.min(axis=0), c.max(axis=0)
        return {
            "format": "studvox",
            "version": 1,
            "name": self.name,
            "title": self.title,
            "category": self.category,
            "description": self.description,
            "tags": self.tags,
            "voxel_size": self.voxel_size,
            "origin": self.resolved_origin(),
            "bounds": [lo.tolist(), hi.tolist()],
            "outline": self.outline,
            "stud": {"mode": self.stud_mode},
            "palette": palette,
            "parts": parts,
            "clips": [cl.bake() for cl in self.clips.values()],
            "roblox": dict(self.roblox),
            "meta": self.meta,
            "notes": self.notes,
        }


def deg(v: float) -> float:
    return math.radians(v)
