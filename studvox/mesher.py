"""Voxel -> mesh data (pure numpy, shared by Blender and the Python exporters).

Works on the baked model dictionary (``Model.to_dict()`` / ``*.svox.json``).
All coordinates returned here are in **voxel units, author space**. Callers
subtract the model origin and scale by ``voxel_size``.
"""

from __future__ import annotations

import numpy as np

NOSTUD = 1 << 12
COLOR_MASK = NOSTUD - 1

# (normal, u, v) with u x v = normal, so quads come out counter-clockwise from outside.
FACES = [
    ((1, 0, 0), (0, 1, 0), (0, 0, 1)),
    ((-1, 0, 0), (0, 0, 1), (0, 1, 0)),
    ((0, 1, 0), (0, 0, 1), (1, 0, 0)),
    ((0, -1, 0), (1, 0, 0), (0, 0, 1)),
    ((0, 0, 1), (1, 0, 0), (0, 1, 0)),
    ((0, 0, -1), (0, 1, 0), (1, 0, 0)),
]


def keys(c: np.ndarray) -> np.ndarray:
    c = np.asarray(c, dtype=np.int64) + 4096
    return (c[:, 0] << 26) | (c[:, 1] << 13) | c[:, 2]


def part_arrays(part: dict):
    v = np.asarray(part["voxels"], dtype=np.int64).reshape(-1, 4)
    return v[:, :3].astype(np.int32), v[:, 3].astype(np.int32)


def animated_parts(model: dict) -> set[str]:
    out = set()
    for c in model.get("clips", []):
        for name, rows in c["tracks"].items():
            if any(any(abs(x) > 1e-6 for x in r) for r in rows):
                out.add(name)
    return out


def rigid_groups(model: dict) -> dict[str, str]:
    """Parts that never move relative to each other share a group id."""
    anim = animated_parts(model)
    by_name = {p["name"]: p for p in model["parts"]}
    out = {}

    def group(name):
        if name in out:
            return out[name]
        p = by_name[name]
        g = name if (name in anim or p["parent"] is None) else group(p["parent"])
        out[name] = g
        return g

    for p in model["parts"]:
        group(p["name"])
    return out


class ModelGeometry:
    """Caches per-part voxel arrays and occupancy lookups for one model."""

    def __init__(self, model: dict):
        self.model = model
        self.parts = model["parts"]
        self.by_name = {p["name"]: p for p in self.parts}
        self.arrays = {p["name"]: part_arrays(p) for p in self.parts}
        self.groups = rigid_groups(model)
        self.all_keys = np.unique(np.concatenate([keys(c) for c, _ in self.arrays.values()]))
        # see-through colours (glass, water): faces of solid voxels behind them stay visible
        self.clear = np.array([e.get("material") in ("glass", "water") for e in model["palette"]] or [False])
        self.group_keys = {}
        self.group_solid_keys = {}
        for g in set(self.groups.values()):
            members = [n for n, gg in self.groups.items() if gg == g]
            ks = [keys(self.arrays[n][0]) for n in members]
            self.group_keys[g] = np.unique(np.concatenate(ks))
            solid = [keys(self.arrays[n][0][~self.is_clear(self.arrays[n][1])]) for n in members]
            self.group_solid_keys[g] = np.unique(np.concatenate(solid)) if solid else np.zeros(0, dtype=np.int64)

    def is_clear(self, values: np.ndarray) -> np.ndarray:
        idx = values & COLOR_MASK
        out = np.zeros(len(values), dtype=bool)
        ok = idx < len(self.clear)
        out[ok] = self.clear[idx[ok]]
        return out

    # -------------------------------------------------------------- faces
    def stud_mask(self, name: str, coords: np.ndarray, values: np.ndarray) -> np.ndarray:
        """Which voxels of a part show a stud on their top face."""
        part = self.by_name[name]
        if self.model.get("stud", {}).get("mode", "top") == "none" or not part.get("studs", True):
            return np.zeros(len(coords), dtype=bool)
        ok = (values & NOSTUD) == 0
        above = coords + np.array([0, 1, 0], dtype=np.int32)
        return ok & ~np.isin(keys(above), self.all_keys)

    def surface(self, name: str) -> dict:
        """Exposed faces of a part as welded quads.

        Returns verts (V,3) in voxel units, quads (F,4), color (F,), dir (F,),
        stud (F,) bool - top faces that carry a stud - and vmask (V,) for the hull.
        """
        coords, values = self.arrays[name]
        occ = self.group_keys[self.groups[name]]
        occ_solid = self.group_solid_keys[self.groups[name]]
        clear = self.is_clear(values)
        studded = self.stud_mask(name, coords, values)
        quads, fcol, fdir, fstud = [], [], [], []
        for di, (n, u, v) in enumerate(FACES):
            n, u, v = (np.asarray(a, dtype=np.int32) for a in (n, u, v))
            nk = keys(coords + n)
            # a solid voxel is hidden only by solid neighbours; a clear voxel by any neighbour
            exposed = np.where(clear, ~np.isin(nk, occ), ~np.isin(nk, occ_solid))
            c = coords[exposed]
            if len(c) == 0:
                continue
            base = 2 * c + n
            quads.append(np.stack([base - u - v, base + u - v, base + u + v, base - u + v], axis=1))
            fcol.append(values[exposed] & COLOR_MASK)
            fdir.append(np.full(len(c), di, dtype=np.int32))
            fstud.append(studded[exposed] if di == 2 else np.zeros(len(c), dtype=bool))
        if not quads:
            return {"verts": np.zeros((0, 3)), "quads": np.zeros((0, 4), dtype=np.int64),
                    "color": np.zeros(0, dtype=np.int32), "dir": np.zeros(0, dtype=np.int32),
                    "stud": np.zeros(0, dtype=bool), "vmask": np.zeros(0, dtype=np.int32)}
        Q = np.concatenate(quads)
        flat = Q.reshape(-1, 3)
        uniq, inv = np.unique(flat, axis=0, return_inverse=True)
        quads_idx = inv.reshape(-1, 4)
        fdir = np.concatenate(fdir)
        vmask = np.zeros(len(uniq), dtype=np.int32)
        np.bitwise_or.at(vmask, quads_idx.ravel(), np.repeat(1 << fdir, 4))
        return {"verts": uniq.astype(np.float64) / 2.0, "quads": quads_idx, "color": np.concatenate(fcol),
                "dir": fdir, "stud": np.concatenate(fstud), "vmask": vmask}

    @staticmethod
    def hull_offsets(vmask: np.ndarray) -> np.ndarray:
        bit = lambda i: ((vmask >> i) & 1).astype(np.float64)
        return np.stack([bit(0) - bit(1), bit(2) - bit(3), bit(4) - bit(5)], axis=1)

    def hull(self, surf: dict, thickness: float) -> dict:
        """Inverted hull (outline shell): vertices pushed out, faces flipped."""
        verts = surf["verts"] + self.hull_offsets(surf["vmask"]) * thickness
        return {"verts": verts, "quads": surf["quads"][:, ::-1].copy()}

    def hidden(self, name: str) -> np.ndarray:
        """Voxels of a part enclosed on all six sides by solid voxels of the same rigid group."""
        coords, values = self.arrays[name]
        solid = self.group_solid_keys[self.groups[name]]
        out = np.ones(len(coords), dtype=bool)
        for n, _, _ in FACES:
            out &= np.isin(keys(coords + np.asarray(n, dtype=np.int32)), solid)
        return out

    # -------------------------------------------------------------- studs
    def studs(self, name: str) -> tuple[np.ndarray, np.ndarray]:
        """Top-centre positions (voxel units) and colour indices of the studded voxels of a part."""
        coords, values = self.arrays[name]
        ok = self.stud_mask(name, coords, values)
        c = coords[ok].astype(np.float64)
        c[:, 1] += 0.5
        return c, values[ok] & COLOR_MASK

    def counts(self) -> dict:
        n_vox = sum(len(c) for c, _ in self.arrays.values())
        n_studs = sum(len(self.studs(p["name"])[0]) for p in self.parts)
        return {"voxels": int(n_vox), "studs": int(n_studs)}


# ------------------------------------------------------------------ boxes

def greedy_boxes(coords: np.ndarray, values: np.ndarray, hidden: np.ndarray | None = None, *,
                 overlap: bool = False) -> list[tuple[int, int, int, int, int, int, int]]:
    """Cover the voxels with as few axis-aligned boxes as possible.

    Returns ``(x0, y0, z0, x1, y1, z1, value)`` with inclusive voxel bounds.
    Visible voxels are covered exactly once by a box of their own value.
    ``hidden`` (bool per voxel) marks voxels enclosed on all six sides: any box
    may run through them whatever their colour, and they need not be covered,
    so solid shapes collapse into far fewer boxes (the inside can't be seen).
    ``overlap`` lets boxes of one colour overlap each other (safe when box edges
    sit on whole studs, so overlapping stud textures line up exactly).
    """
    if len(coords) == 0:
        return []
    lo = coords.min(axis=0)
    dims = coords.max(axis=0) - lo + 1
    grid = np.full(tuple(dims), -1, dtype=np.int32)
    idx = coords - lo
    grid[idx[:, 0], idx[:, 1], idx[:, 2]] = values
    hid = np.zeros(tuple(dims), dtype=bool)
    if hidden is not None and hidden.any():
        h = idx[hidden]
        hid[h[:, 0], h[:, 1], h[:, 2]] = True
    used = np.zeros(tuple(dims), dtype=bool)
    out = []
    dims = tuple(int(d) for d in dims)
    vis = np.ones(len(idx), dtype=bool) if hidden is None else ~hidden
    vidx = idx[vis]
    order = np.lexsort((vidx[:, 0], vidx[:, 2], vidx[:, 1]))

    def fits(gs, hs, us, v):
        if overlap:
            return bool(np.all(hs | (gs == v)))
        return bool(np.all(hs | ((gs == v) & ~us)))

    def slab(lo3, hi3, axis, at):
        sl = [slice(lo3[0], hi3[0] + 1), slice(lo3[1], hi3[1] + 1), slice(lo3[2], hi3[2] + 1)]
        sl[axis] = slice(at, at + 1)
        return tuple(sl)

    def grow(seed, v, order):
        lo3, hi3 = list(seed), list(seed)
        for axis in order:                     # grow forwards along each axis in turn
            while hi3[axis] + 1 < dims[axis]:
                sl = slab(lo3, hi3, axis, hi3[axis] + 1)
                if not fits(grid[sl], hid[sl], used[sl], v):
                    break
                hi3[axis] += 1
        for axis in order:                     # then backwards (through hidden voxels or same colour)
            while lo3[axis] - 1 >= 0:
                sl = slab(lo3, hi3, axis, lo3[axis] - 1)
                if not fits(grid[sl], hid[sl], used[sl], v):
                    break
                lo3[axis] -= 1
        box = (slice(lo3[0], hi3[0] + 1), slice(lo3[1], hi3[1] + 1), slice(lo3[2], hi3[2] + 1))
        gain = int(np.count_nonzero(~hid[box] & ~used[box] & (grid[box] == v)))
        return gain, lo3, hi3

    orders = ((0, 2, 1), (2, 0, 1), (1, 0, 2), (0, 1, 2), (2, 1, 0), (1, 2, 0))
    for i in order:
        x, y, z = (int(v) for v in vidx[i])
        if used[x, y, z]:
            continue
        v = grid[x, y, z]
        best = max((grow((x, y, z), v, o) for o in orders), key=lambda r: r[0])
        _, (x0, y0, z0), (x1, y1, z1) = best
        box_vis = ~hid[x0:x1 + 1, y0:y1 + 1, z0:z1 + 1]
        used[x0:x1 + 1, y0:y1 + 1, z0:z1 + 1] |= box_vis
        out.append((x0 + int(lo[0]), y0 + int(lo[1]), z0 + int(lo[2]),
                    x1 + int(lo[0]), y1 + int(lo[1]), z1 + int(lo[2]), int(v)))
    return out
