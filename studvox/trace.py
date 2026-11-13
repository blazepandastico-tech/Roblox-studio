"""Trace a reference picture into a stud-style voxel model.

The picture is read as a front view:

1. the background is removed (alpha, or flood-fill from the border colour)
2. the subject is resampled to a voxel grid (``height`` voxels tall), each cell
   taking the most common colour of its pixels, so flat cartoon colours stay crisp
3. colours are quantised (k-means) and snapped to named palette colours when close
4. dark line-art is detected and kept as black voxels, so the drawn **black
   outline** survives; the outer rim stays black all the way round the model
5. the silhouette is inflated into 3D (a rounded "balloon" depth from the
   distance to the edge), optionally shaped by a side-view picture
6. the front face carries every detail; the inside and back use the
   surrounding fill colours so eyes and mouths are not repeated on the back

``python -m studvox trace picture.png --name my_thing`` writes
``models/traced/my_thing.py`` (which just calls :func:`trace_model`) and copies
the picture to ``references/``, then builds it like any other model.
"""

from __future__ import annotations

import math
import shutil
from collections import Counter, deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

from .model import Model
from .palette import DEFAULT_PALETTE, parse_hex, to_hex

REPO = Path(__file__).resolve().parent.parent


# ---------------------------------------------------------------------------- image -> mask

def _border_color(rgb: np.ndarray) -> np.ndarray:
    b = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    return np.median(b, axis=0)


def subject_mask(img: Image.Image, tolerance: float = 38.0) -> np.ndarray:
    arr = np.asarray(img.convert("RGBA")).astype(np.float64)
    alpha = arr[..., 3]
    if (alpha < 250).mean() > 0.02:
        return alpha > 127
    rgb = arr[..., :3]
    bg = _border_color(rgb)
    diff = np.sqrt(((rgb - bg) ** 2).sum(axis=2))
    similar = diff < tolerance
    h, w = similar.shape
    seen = np.zeros_like(similar)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if similar[y, x] and not seen[y, x]:
                seen[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if similar[y, x] and not seen[y, x]:
                seen[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and similar[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))
    return ~seen


# ---------------------------------------------------------------------------- resample

def _luma(c):
    c = np.asarray(c, dtype=np.float64)
    return (0.2126 * c[..., 0] + 0.7152 * c[..., 1] + 0.0722 * c[..., 2]) / 255.0


def _sat(c):
    c = np.asarray(c, dtype=np.float64)
    mx, mn = c.max(axis=-1), c.min(axis=-1)
    return np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)


def resample(img: Image.Image, mask: np.ndarray, height: int, *, line_luma=0.2, line_frac=0.28):
    """Return (cells_rgb (H,W,3), cell_mask (H,W), cell_line (H,W)) on the voxel grid."""
    ys, xs = np.nonzero(mask)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    rgb = np.asarray(img.convert("RGB"))[y0:y1, x0:x1]
    m = mask[y0:y1, x0:x1]
    ph, pw = m.shape
    cell = ph / height
    width = max(1, int(round(pw / cell)))
    H, W = height, width
    out = np.zeros((H, W, 3), dtype=np.float64)
    cmask = np.zeros((H, W), dtype=bool)
    cline = np.zeros((H, W), dtype=bool)
    q = (rgb // 12).astype(np.int32)
    for j in range(H):
        ya, yb = int(j * cell), max(int((j + 1) * cell), int(j * cell) + 1)
        for i in range(W):
            xa, xb = int(i * pw / W), max(int((i + 1) * pw / W), int(i * pw / W) + 1)
            mm = m[ya:yb, xa:xb]
            if mm.size == 0 or mm.mean() < 0.45:
                continue
            cmask[j, i] = True
            px = rgb[ya:yb, xa:xb][mm]
            dark = (_luma(px) < line_luma) & (_sat(px) < 0.55)
            if dark.mean() >= line_frac:
                cline[j, i] = True
                out[j, i] = np.median(px[dark], axis=0)
                continue
            keep = px[~dark] if (~dark).any() else px
            kq = q[ya:yb, xa:xb][mm][~dark] if (~dark).any() else q[ya:yb, xa:xb][mm]
            keys = kq[:, 0] * 10000 + kq[:, 1] * 100 + kq[:, 2]
            mode = Counter(keys.tolist()).most_common(1)[0][0]
            sel = keep[keys == mode]
            out[j, i] = sel.mean(axis=0)
    return out, cmask, cline


# ---------------------------------------------------------------------------- colours

def kmeans(colors: np.ndarray, k: int, iters: int = 20, seed: int = 3) -> np.ndarray:
    rng = np.random.default_rng(seed)
    uniq = np.unique(np.round(colors), axis=0)
    if len(uniq) <= k:
        return uniq
    centers = [colors[rng.integers(len(colors))]]
    for _ in range(1, k):
        d = np.min(((colors[:, None, :] - np.asarray(centers)[None]) ** 2).sum(-1), axis=1)
        if d.sum() <= 0:
            break
        centers.append(colors[rng.choice(len(colors), p=d / d.sum())])
    C = np.asarray(centers, dtype=np.float64)
    for _ in range(iters):
        lab = np.argmin(((colors[:, None, :] - C[None]) ** 2).sum(-1), axis=1)
        newC = np.array([colors[lab == i].mean(axis=0) if (lab == i).any() else C[i] for i in range(len(C))])
        if np.allclose(newC, C):
            break
        C = newC
    return C


def snap_to_palette(rgb, max_dist=22.0):
    best, bd = None, 1e9
    for name, (hx, mat) in DEFAULT_PALETTE.items():
        if mat in ("glow", "glass", "water"):
            continue
        d = math.dist(rgb, parse_hex(hx))
        if d < bd:
            best, bd = name, d
    return best if bd <= max_dist else None


# ---------------------------------------------------------------------------- distance / depth

def chamfer_distance(mask: np.ndarray) -> np.ndarray:
    """Distance (in cells) from each inside cell to the outside (3-4 chamfer / 3)."""
    H, W = mask.shape
    INF = 10 ** 6
    d = np.where(mask, INF, 0).astype(np.int64)
    pad = np.zeros((H + 2, W + 2), dtype=np.int64)
    pad[1:-1, 1:-1] = d
    for y in range(1, H + 1):
        for x in range(1, W + 1):
            if pad[y, x]:
                pad[y, x] = min(pad[y, x], pad[y - 1, x] + 3, pad[y, x - 1] + 3, pad[y - 1, x - 1] + 4,
                                pad[y - 1, x + 1] + 4)
    for y in range(H, 0, -1):
        for x in range(W, 0, -1):
            if pad[y, x]:
                pad[y, x] = min(pad[y, x], pad[y + 1, x] + 3, pad[y, x + 1] + 3, pad[y + 1, x + 1] + 4,
                                pad[y + 1, x - 1] + 4)
    return pad[1:-1, 1:-1] / 3.0


def fill_lines(labels: np.ndarray, mask: np.ndarray, bad: np.ndarray) -> np.ndarray:
    """Replace ``bad`` cells by the nearest good label (breadth-first growth)."""
    out = labels.copy()
    good = mask & ~bad
    H, W = labels.shape
    q = deque((y, x) for y, x in zip(*np.nonzero(good)))
    done = good.copy()
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < H and 0 <= nx < W and mask[ny, nx] and not done[ny, nx]:
                done[ny, nx] = True
                out[ny, nx] = out[y, x]
                q.append((ny, nx))
    return out


def side_profile(path, height: int):
    """Per-row (front, back) extents in voxels from a side-view picture (subject faces right)."""
    img = Image.open(path)
    mask = subject_mask(img)
    ys, xs = np.nonzero(mask)
    m = mask[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    ph, pw = m.shape
    cell = ph / height
    rows = []
    for j in range(height):
        row = m[int(j * cell):max(int((j + 1) * cell), int(j * cell) + 1)].any(axis=0)
        idx = np.nonzero(row)[0]
        if len(idx) == 0:
            rows.append(None)
        else:
            rows.append((idx.min() / cell, idx.max() / cell))
    depth = pw / cell
    return rows, depth


# ---------------------------------------------------------------------------- model

def trace_model(image: str | Path, *, name: str, title: str | None = None, category: str = "traced",
                height: int = 32, depth: float = 0.0, colors: int = 12, outline: str | bool = "auto",
                side: str | Path | None = None, voxel_size: float | None = None, description: str = "",
                idle: bool = True) -> Model:
    image = Path(image)
    if not image.is_absolute():
        image = (REPO / image) if (REPO / image).exists() else image
    img = Image.open(image)
    img.thumbnail((1024, 1024))
    img = img.filter(ImageFilter.MedianFilter(3))
    mask = subject_mask(img)
    cells, cmask, cline = resample(img, mask, height)
    H, W = cmask.shape
    if outline in (False, "none"):
        cline[:] = False

    # quantise non-line colours
    pts = cells[cmask & ~cline]
    C = kmeans(pts, colors) if len(pts) else np.zeros((1, 3))
    lab = np.full((H, W), -1, dtype=np.int64)
    ys, xs = np.nonzero(cmask & ~cline)
    lab[ys, xs] = np.argmin(((cells[ys, xs][:, None, :] - C[None]) ** 2).sum(-1), axis=1)
    LINE = len(C)
    lab[cline] = LINE

    # detail colours (small areas such as eyes) are not pushed through the body
    counts = Counter(lab[cmask].tolist())
    area = cmask.sum()
    detail = np.zeros_like(cmask)
    for li, cnt in counts.items():
        if li != LINE and cnt < 0.025 * area:
            detail |= lab == li
    fill = fill_lines(lab, cmask, cline | detail)

    # rim: silhouette border; keep it black if the art is outlined
    border = cmask & ~(np.pad(cmask, 1)[2:, 1:-1] & np.pad(cmask, 1)[:-2, 1:-1] & np.pad(cmask, 1)[1:-1, 2:]
                       & np.pad(cmask, 1)[1:-1, :-2])
    outlined = (cline & border).sum() >= 0.35 * max(border.sum(), 1)
    if outline == "force" or (outline == "auto" and outlined):
        rim_black = border.copy()
    else:
        rim_black = cline & border

    # names for colours
    m = Model(name, title=title, category=category, description=description or
              f"Traced from {image.name}: {W}x{H} voxels, balloon depth, original line-art kept.",
              voxel_size=voxel_size)
    color_names = {}
    for i, c in enumerate(C):
        rgb = tuple(int(round(v)) for v in np.clip(c, 0, 255))
        snapped = snap_to_palette(rgb)
        color_names[i] = snapped or m.add_color(f"trace_{i}", to_hex(rgb), "plastic")
    color_names[LINE] = "black"

    # depth
    dist = chamfer_distance(cmask)
    maxd = depth if depth > 0 else max(3.0, min(W, H) * 0.42)
    half = maxd / 2.0
    R = max(half, 1.0)
    sprof = None
    if side:
        sprof, sdepth = side_profile(side, height)
        maxd = sdepth
    body = m.part("body", pivot=(0, H / 2, 0))
    for j in range(H):
        y = H - 1 - j
        prof = sprof[j] if sprof else None
        for i in range(W):
            if not cmask[j, i]:
                continue
            x = i - W // 2
            t = min(dist[j, i] / R, 1.0)
            h = half * math.sqrt(max(0.0, 1.0 - (1.0 - t) ** 2))
            if prof is not None:
                zf = maxd / 2 - prof[0]
                zb = maxd / 2 - prof[1]
                zf_, zb_ = int(round(min(zf, h if h > 0 else zf))), int(round(max(zb, -h)))
            else:
                zf_, zb_ = int(round(h)), -int(round(h))
            if zf_ < zb_:
                zf_ = zb_
            front_col = "black" if rim_black[j, i] else color_names[int(lab[j, i])]
            inner_col = color_names[int(fill[j, i])]
            # the drawn outline wraps the silhouette on the back too; sides keep the fill colour
            back_col = "black" if (rim_black[j, i] or (cline[j, i] and border[j, i])) else inner_col
            for z in range(zb_, zf_ + 1):
                if z == zf_:
                    col = front_col
                elif z == zb_:
                    col = back_col
                else:
                    col = inner_col
                body.voxel((x, y, z), col)
    # studs on line-art look busy; keep black voxels smooth
    for k, v in list(body.vox.items()):
        if m._palette[v & 0xFFF]["name"] == "black":
            body.vox[k] = v | (1 << 12)

    m.meta["trace"] = {"image": image.name, "grid": [W, H], "depth": maxd, "colors": len(C),
                       "outlined": bool(outlined)}
    m.notes = [f"Traced from {image.name} on a {W} x {H} grid", "Front face keeps every drawn detail",
               "Drawn black line-art kept as smooth black voxels"]
    if idle:
        c = m.clip("idle", 2.0)
        c.osc("body", pos=(0, 0.35, 0), period=1.0)
        c.osc("body", rot=(0, 8, 3), period=2.0)
        c2 = m.clip("hop", 0.8)
        c2.osc("body", pos=(0, 2.5, 0), period=0.8, wave="bounce")
        c2.osc("body", rot=(6, 0, 0), period=0.8)
    return m


SPEC_TEMPLATE = '''"""Traced model: {title}. Regenerate with `python -m studvox make {rel}`."""

from studvox.trace import trace_model


def build():
    return trace_model(
        "{image}",
        name="{name}",
        title="{title}",
        category="{category}",
        height={height},
        depth={depth},
        colors={colors},
        outline="{outline}",
        side={side},
        voxel_size={voxel_size},
    )
'''


def write_trace_spec(image, *, name, category="traced", height=32, depth=0.0, colors=12, outline=True,
                     side=None, title=None, voxel_size=None) -> Path:
    image = Path(image)
    refs = REPO / "references"
    refs.mkdir(exist_ok=True)
    dst = refs / f"{name}{image.suffix.lower()}"
    if image.resolve() != dst.resolve():
        shutil.copyfile(image, dst)
    side_rel = None
    if side:
        sd = refs / f"{name}_side{Path(side).suffix.lower()}"
        if Path(side).resolve() != sd.resolve():
            shutil.copyfile(side, sd)
        side_rel = repr(str(sd.relative_to(REPO)))
    spec_dir = REPO / "models" / category
    spec_dir.mkdir(parents=True, exist_ok=True)
    spec = spec_dir / f"{name}.py"
    title = title or name.replace("_", " ").title()
    spec.write_text(SPEC_TEMPLATE.format(
        title=title, rel=spec.relative_to(REPO), image=dst.relative_to(REPO), name=name, category=category,
        height=height, depth=depth, colors=colors, outline="auto" if outline else "none", side=side_rel,
        voxel_size=voxel_size))
    return spec
