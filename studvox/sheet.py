"""Concept sheets and preview images (Pillow only, no Blender needed).

Reads ``stats.json`` and the renders written by the Blender pipeline and
composes:

* ``preview.jpg`` - the hero render on a soft card with the model name
* ``sheet.jpg``   - concept sheet: hero, turnaround, poses, palette, specs
* ``anim.gif``    - optional looping clip preview (when frames were rendered)
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

from .palette import parse_hex, shade

FONT_DIR = Path(__file__).resolve().parent / "fonts"

CATEGORY_COLORS = {
    "eggs": "#FF9BC8",
    "critters": "#FFB627",
    "bosses": "#E2312E",
    "mobs": "#8E5BE8",
    "buildings": "#2F7BE8",
    "props": "#1AA39B",
    "nature": "#3DAE4A",
    "terrain": "#A8693A",
    "weapons": "#5C626B",
    "traced": "#F2489B",
}
INK = (24, 24, 28, 255)
PAPER = (251, 247, 239, 255)


def font(weight: str, size: int):
    name = {"black": "Inter-Black.otf", "bold": "Inter-Bold.otf", "medium": "Inter-Medium.otf"}[weight]
    try:
        return ImageFont.truetype(str(FONT_DIR / name), size)
    except OSError:
        return ImageFont.load_default()


def rgba(hx: str, a: int = 255):
    r, g, b = parse_hex(hx)
    return (r, g, b, a)


def stud_paper(w: int, h: int, color=PAPER, dot=(236, 229, 215, 255), step=34):
    im = Image.new("RGBA", (w, h), color)
    d = ImageDraw.Draw(im)
    r = step * 0.28
    for y in range(step // 2, h, step):
        for x in range(step // 2, w, step):
            d.ellipse((x - r, y - r, x + r, y + r), fill=dot)
    return im


def card(im: Image.Image, box, *, fill=(255, 255, 255, 255), outline=INK, radius=26, width=5, shadow=True):
    x0, y0, x1, y1 = box
    if shadow:
        sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle((x0 + 7, y0 + 9, x1 + 7, y1 + 9), radius, fill=(0, 0, 0, 70))
        sh = sh.filter(ImageFilter.GaussianBlur(5))
        im.alpha_composite(sh)
    ImageDraw.Draw(im).rounded_rectangle(box, radius, fill=fill, outline=outline, width=width)


def gradient(w, h, top, bottom):
    t = Image.new("RGBA", (w, h), top)
    b = Image.new("RGBA", (w, h), bottom)
    mask = Image.linear_gradient("L").resize((w, h))
    return Image.composite(b, t, mask)


def subject_crop(img: Image.Image, margin: float = 0.06) -> Image.Image:
    """Crop to the solid subject (ignores soft shadows) and feather what's left of the shadow at the edges."""
    a = img.getchannel("A")
    solid = a.point(lambda v: 255 if v > 235 else 0)
    bbox = solid.getbbox() or a.getbbox()
    if not bbox:
        return img
    x0, y0, x1, y1 = bbox
    mw, mh = (x1 - x0) * margin + 4, (y1 - y0) * margin + 4
    # shadows extend sideways/down: give them a bit more room
    box = (max(0, int(x0 - mw * 2.2)), max(0, int(y0 - mh)), min(img.width, int(x1 + mw * 2.2)),
           min(img.height, int(y1 + mh * 1.6)))
    out = img.crop(box)
    w, h = out.size
    fx, fy = max(int(w * 0.08), 1), max(int(h * 0.08), 1)
    ramp = Image.new("L", (w, h), 255)
    d = ImageDraw.Draw(ramp)
    for i in range(fx):
        v = int(255 * i / fx)
        d.line([(i, 0), (i, h)], fill=v)
        d.line([(w - 1 - i, 0), (w - 1 - i, h)], fill=v)
    ramp2 = Image.new("L", (w, h), 255)
    d2 = ImageDraw.Draw(ramp2)
    for i in range(fy):
        v = int(255 * i / fy)
        d2.line([(0, i), (w, i)], fill=v)
        d2.line([(0, h - 1 - i), (w, h - 1 - i)], fill=v)
    from PIL import ImageChops
    feather = ImageChops.multiply(ramp, ramp2)
    # never fade the solid subject itself
    feather = ImageChops.lighter(feather, solid.crop(box))
    out.putalpha(ImageChops.multiply(out.getchannel("A"), feather))
    return out


def fit(img: Image.Image, w: int, h: int) -> Image.Image:
    img = subject_crop(img)
    s = min(w / img.width, h / img.height)
    return img.resize((max(1, int(img.width * s)), max(1, int(img.height * s))), Image.LANCZOS)


def paste_center(dst: Image.Image, img: Image.Image, box):
    x0, y0, x1, y1 = box
    dst.alpha_composite(img, (int(x0 + (x1 - x0 - img.width) / 2), int(y0 + (y1 - y0 - img.height) / 2)))


def text(d: ImageDraw.ImageDraw, xy, s, f, fill=INK, anchor="la", stroke=0, stroke_fill=INK):
    d.text(xy, s, font=f, fill=fill, anchor=anchor, stroke_width=stroke, stroke_fill=stroke_fill)


def chip(im, xy, label, color, f, *, pad=(16, 8)):
    d = ImageDraw.Draw(im)
    w = d.textlength(label, font=f)
    x, y = xy
    h = f.size + pad[1] * 2
    d.rounded_rectangle((x, y, x + w + pad[0] * 2, y + h), h // 2, fill=color, outline=INK, width=3)
    text(d, (x + pad[0], y + h / 2), label, f, fill=(255, 255, 255, 255), anchor="lm", stroke=2)
    return x + w + pad[0] * 2


def _hero_backdrop(w, h, accent):
    top = rgba(shade(accent, 0.82))
    bottom = rgba(shade(accent, 0.55))
    g = gradient(w, h, top, bottom)
    # soft light burst behind the model
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((w * 0.12, h * 0.08, w * 0.88, h * 0.84), fill=(255, 255, 255, 120))
    g.alpha_composite(glow.filter(ImageFilter.GaussianBlur(w // 10)))
    return g


def make_preview(out_dir: Path, stats: dict, size: int | None = None) -> Path:
    size = size or (512 if stats.get("category") == "eggs" else 900)
    accent = CATEGORY_COLORS.get(stats["category"], "#FFB627")
    hero = Image.open(out_dir / stats["renders"]["hero"]).convert("RGBA")
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pad = 14
    box = (pad, pad, size - pad, size - pad)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, 40, fill=255)
    bg = _hero_backdrop(size, size, accent)
    im.paste(bg, (0, 0), mask)
    art = fit(hero, int(size * 0.84), int(size * 0.74))
    paste_center(im, art, (0, int(size * 0.03), size, int(size * 0.86)))
    d = ImageDraw.Draw(im)
    f = font("black", int(size * 0.062))
    text(d, (size / 2, size * 0.915), stats["title"].upper(), f, fill=(255, 255, 255, 255), anchor="mm", stroke=6)
    d.rounded_rectangle(box, 40, outline=INK, width=8)
    p = out_dir / "preview.jpg"
    flat = Image.new("RGBA", im.size, PAPER)
    flat.alpha_composite(im)
    flat.convert("RGB").save(p, quality=88, optimize=True)
    old = out_dir / "preview.png"
    if old.exists():
        old.unlink()
    return p


def make_sheet(out_dir: Path, stats: dict, model: dict | None = None) -> Path:
    W, H = 1800, 1120
    accent = CATEGORY_COLORS.get(stats["category"], "#FFB627")
    im = stud_paper(W, H)
    d = ImageDraw.Draw(im)
    r = stats["renders"]

    # ---- header
    card(im, (36, 28, W - 36, 138), fill=rgba(accent), radius=30, width=6)
    d = ImageDraw.Draw(im)
    text(d, (72, 84), stats["title"].upper(), font("black", 64), fill=(255, 255, 255, 255), anchor="lm", stroke=7)
    tw = d.textlength(stats["title"].upper(), font=font("black", 64)) + 7 * 2
    x = 72 + tw + 26
    x = chip(im, (x, 62), stats["category"].upper(), rgba(shade(accent, -0.35)), font("black", 24)) + 12
    chip(im, (x, 62), "CONCEPT SHEET", rgba("#1D1E22"), font("black", 24))
    desc = (model or {}).get("description") or ""
    d = ImageDraw.Draw(im)
    text(d, (W - 72, 84), f"{stats['name']}.svox", font("bold", 26), fill=(255, 255, 255, 235), anchor="rm",
         stroke=3)

    # ---- hero card
    hx0, hy0, hx1, hy1 = 36, 168, 960, 1012
    card(im, (hx0, hy0, hx1, hy1), fill=(255, 255, 255, 255))
    inner = _hero_backdrop(hx1 - hx0 - 24, hy1 - hy0 - 24, accent)
    m = Image.new("L", inner.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, inner.width - 1, inner.height - 1), 18, fill=255)
    im.paste(inner, (hx0 + 12, hy0 + 12), m)
    hero = Image.open(out_dir / r["hero"]).convert("RGBA")
    paste_center(im, fit(hero, hx1 - hx0 - 80, hy1 - hy0 - 120), (hx0, hy0 + 10, hx1, hy1 - 50))
    d = ImageDraw.Draw(im)
    if desc:
        f = font("bold", 24)
        # wrap description to the card width
        words, lines, cur = desc.split(), [], ""
        for w_ in words:
            t = (cur + " " + w_).strip()
            if d.textlength(t, font=f) > hx1 - hx0 - 80:
                lines.append(cur)
                cur = w_
            else:
                cur = t
        lines.append(cur)
        for i, ln in enumerate(lines[:2][::-1]):
            text(d, ((hx0 + hx1) / 2, hy1 - 34 - i * 30), ln, f, fill=(255, 255, 255, 255), anchor="mm", stroke=4)

    # ---- right column
    rx0, rx1 = 990, W - 36
    y = 168

    def section(title, y):
        dd = ImageDraw.Draw(im)
        text(dd, (rx0 + 4, y), title, font("black", 26), fill=INK)
        return y + 38

    views = [v for v in ("front", "side", "back", "top") if v in r]
    y = section("TURNAROUND", y)
    n = len(views)
    gap = 14
    vw = (rx1 - rx0 - gap * (n - 1)) / n
    vh = 250 if n <= 3 else 210
    for i, v in enumerate(views):
        bx0 = rx0 + i * (vw + gap)
        card(im, (bx0, y, bx0 + vw, y + vh), radius=18, width=4)
        img = Image.open(out_dir / r[v]).convert("RGBA")
        paste_center(im, fit(img, int(vw - 30), int(vh - 56)), (bx0, y + 6, bx0 + vw, y + vh - 34))
        dd = ImageDraw.Draw(im)
        text(dd, (bx0 + vw / 2, y + vh - 22), v.upper(), font("black", 18), fill=rgba(shade(accent, -0.45)),
             anchor="mm")
    y += vh + 26

    poses = r.get("poses") or []
    if poses:
        y = section("ANIMATION CLIPS", y)
        n = len(poses)
        pw = (rx1 - rx0 - gap * (n - 1)) / max(n, 1)
        ph = 214
        for i, pinfo in enumerate(poses):
            bx0 = rx0 + i * (pw + gap)
            card(im, (bx0, y, bx0 + pw, y + ph), fill=rgba(shade(accent, 0.86)), radius=18, width=4)
            img = Image.open(out_dir / pinfo["file"]).convert("RGBA")
            paste_center(im, fit(img, int(pw - 24), int(ph - 58)), (bx0, y + 4, bx0 + pw, y + ph - 40))
            dd = ImageDraw.Draw(im)
            chip(im, (bx0 + 12, y + ph - 46), pinfo["clip"].upper(), rgba(accent), font("black", 16), pad=(12, 6))
        y += ph + 26
    else:
        y = section("BUILD NOTES", y)
        notes = (model or {}).get("notes") or []
        tile = (model or {}).get("meta", {}).get("tile")
        if tile:
            notes = [f"Modular tile: {tile['studs'][0]:g} x {tile['studs'][1]:g} studs footprint, snaps on a "
                     f"{tile['studs'][0]:g}-stud grid"] + notes
        grip = (model or {}).get("meta", {}).get("grip")
        if grip:
            notes = ["Exports as a Roblox Tool with the handle at the grip point"] + notes
        if not notes:
            notes = ["Static model: anchored parts, collisions on, ready to drop into a map"]
        card(im, (rx0, y, rx1, y + 120), radius=18, width=4)
        dd = ImageDraw.Draw(im)
        for i, nline in enumerate(notes[:3]):
            text(dd, (rx0 + 22, y + 22 + i * 32), "• " + nline, font("bold", 21), fill=INK)
        y += 120 + 26

    # palette
    y = section("PALETTE", y)
    pal = stats.get("palette", [])[:20]
    sw = 50
    per_row = int((rx1 - rx0 + 14) // (sw + 14))
    for i, e in enumerate(pal):
        cx = rx0 + (i % per_row) * (sw + 14)
        cy = y + (i // per_row) * (sw + 14)
        dd = ImageDraw.Draw(im)
        dd.rounded_rectangle((cx, cy, cx + sw, cy + sw), 12, fill=rgba(e["hex"]), outline=INK, width=3)
        # a little stud on each swatch
        sr = sw * 0.2
        dd.ellipse((cx + sw / 2 - sr, cy + sw / 2 - sr, cx + sw / 2 + sr, cy + sw / 2 + sr),
                   fill=rgba(shade(e["hex"], 0.18)), outline=rgba(shade(e["hex"], -0.25)), width=2)
        if e["material"] in ("glow", "glass", "water", "metal"):
            text(dd, (cx + sw - 6, cy + 6), e["material"][0].upper(), font("black", 13), fill=INK, anchor="ra")
    rows = (len(pal) + per_row - 1) // per_row
    y += rows * (sw + 14) + 14

    # specs
    y = section("SPECS", y)
    size = stats.get("size_studs", [0, 0, 0])
    specs = [
        ("SIZE", f"{size[0]:g} x {size[1]:g} x {size[2]:g} studs"),
        ("VOXELS", f"{stats.get('voxels', 0):,}  ·  {stats.get('studs', 0):,} studs"),
        ("TRIS", f"{stats.get('export_tris', 0):,} (with outline)"),
        ("RIG", (f"{stats.get('bones', 0)} bones · " + ", ".join(stats.get("clips", []))) if stats.get("clips")
         else "static"),
        ("SCALE", f"{stats.get('voxel_size', 1):g} studs per voxel"),
    ]
    box_h = H - 40 - y
    card(im, (rx0, y, rx1, y + box_h), radius=18, width=4)
    dd = ImageDraw.Draw(im)
    lh = min(36, (box_h - 20) / len(specs))
    for i, (k, v) in enumerate(specs):
        yy = y + 14 + i * lh + lh / 2
        text(dd, (rx0 + 22, yy), k, font("black", 19), fill=rgba(shade(accent, -0.45)), anchor="lm")
        text(dd, (rx0 + 130, yy), v, font("bold", 20), fill=INK, anchor="lm")

    # footer
    dd = ImageDraw.Draw(im)
    files = stats.get("exports", {})
    exp = " · ".join(x for x in [f"{stats['name']}.rbxmx", files.get("fbx"), files.get("glb"), files.get("obj")] if x)
    text(dd, (36 + 6, H - 54), "STUDVOX", font("black", 28), fill=INK, anchor="lm")
    text(dd, (190, H - 54), "stud-style voxel kit for Roblox   |   " + exp, font("medium", 20),
         fill=(90, 90, 96, 255), anchor="lm")
    p = out_dir / "sheet.jpg"
    im.convert("RGB").save(p, quality=88, optimize=True)
    old = out_dir / "sheet.png"
    if old.exists():
        old.unlink()
    return p


def make_gif(out_dir: Path, stats: dict) -> Path | None:
    frames = stats.get("renders", {}).get("gif_frames")
    if not frames:
        return None
    accent = CATEGORY_COLORS.get(stats["category"], "#FFB627")
    imgs = []
    for f in frames:
        fr = Image.open(out_dir / f).convert("RGBA")
        bg = _hero_backdrop(fr.width, fr.height, accent)
        bg.alpha_composite(fr)
        imgs.append(bg.convert("RGB").quantize(colors=128, method=Image.Quantize.MEDIANCUT))
    p = out_dir / "anim.gif"
    dur = int(1000 / max(stats["renders"].get("gif_fps", 12), 1))
    imgs[0].save(p, save_all=True, append_images=imgs[1:], duration=dur, loop=0, optimize=True)
    return p


def compose(out_dir: Path, model: dict | None = None) -> dict:
    out_dir = Path(out_dir)
    stats = json.load(open(out_dir / "stats.json"))
    res = {}
    if "renders" in stats:
        res["preview"] = str(make_preview(out_dir, stats))
        if any(v in stats["renders"] for v in ("front", "side", "back")):
            res["sheet"] = str(make_sheet(out_dir, stats, model))
        g = make_gif(out_dir, stats)
        if g:
            res["gif"] = str(g)
    return res
