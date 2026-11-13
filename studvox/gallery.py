"""Gallery: one image with every model preview, grouped by category, plus a markdown index."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw

from .model import CATEGORIES
from .sheet import CATEGORY_COLORS, INK, chip, font, rgba, stud_paper, text

REPO = Path(__file__).resolve().parent.parent
DOCS = REPO / "docs"

TITLES = {
    "eggs": "Eggs",
    "critters": "Critters & pets",
    "bosses": "Bosses",
    "mobs": "Mobs",
    "buildings": "Buildings",
    "props": "Props",
    "nature": "Nature",
    "terrain": "Terrain tiles",
    "weapons": "Weapons",
    "traced": "Traced from pictures",
}


def collect(out_root: Path):
    groups: dict[str, list[dict]] = {}
    for cat in CATEGORIES:
        if cat == "eggs":          # the 140 eggs have their own catalogue (docs/eggs/)
            continue
        for d in sorted((out_root / cat).glob("*")):
            st = d / "stats.json"
            if (d / "preview.jpg").exists() and st.exists():
                stats = json.load(open(st))
                stats["_dir"] = d
                groups.setdefault(cat, []).append(stats)
    return groups


def build_gallery(out_root: Path) -> list[Path]:
    DOCS.mkdir(exist_ok=True)
    groups = collect(out_root)
    tile, gap, cols = 280, 18, 6
    W = 40 * 2 + cols * tile + (cols - 1) * gap
    header = 150
    rows_h = 0
    for cat, items in groups.items():
        rows = (len(items) + cols - 1) // cols
        rows_h += 70 + rows * (tile + gap) + 20
    H = header + rows_h + 40
    im = stud_paper(W, H)
    d = ImageDraw.Draw(im)
    total = sum(len(v) for v in groups.values())
    text(d, (40, 70), "STUDVOX GALLERY", font("black", 64), fill=(255, 255, 255, 255), anchor="lm", stroke=8)
    text(d, (40, 122), f"{total} stud-style voxel models for Roblox, built from Python specs", font("bold", 26),
         fill=INK, anchor="lm")
    y = header
    for cat in CATEGORIES:
        items = groups.get(cat)
        if not items:
            continue
        chip(im, (40, y + 8), f"{TITLES[cat].upper()}  ·  {len(items)}", rgba(CATEGORY_COLORS[cat]),
             font("black", 26))
        y += 70
        for i, st in enumerate(items):
            x = 40 + (i % cols) * (tile + gap)
            yy = y + (i // cols) * (tile + gap)
            p = Image.open(st["_dir"] / "preview.jpg").convert("RGBA").resize((tile, tile), Image.LANCZOS)
            im.alpha_composite(p, (x, yy))
        y += ((len(items) + cols - 1) // cols) * (tile + gap) + 20
    out = DOCS / "gallery.jpg"
    im.convert("RGB").save(out, quality=86, optimize=True)

    # small per-category strips for the README
    strips = []
    for cat, items in groups.items():
        n = min(len(items), 6)
        st_im = Image.new("RGBA", (n * 220 + (n - 1) * 10, 220), (0, 0, 0, 0))
        for i, st in enumerate(items[:n]):
            p = Image.open(st["_dir"] / "preview.jpg").convert("RGBA").resize((220, 220), Image.LANCZOS)
            st_im.alpha_composite(p, (i * 230, 0))
        sp = DOCS / f"strip_{cat}.jpg"
        flat = Image.new("RGBA", st_im.size, (251, 247, 239, 255))
        flat.alpha_composite(st_im)
        flat.convert("RGB").save(sp, quality=86, optimize=True)
        strips.append(sp)

    lines = ["# Gallery", "", f"{total} example models. Click a name for its concept sheet.",
             "The 140 eggs have their own catalogue: [UOVA.md](UOVA.md).", "", "![gallery](gallery.jpg)", ""]
    for cat in CATEGORIES:
        items = groups.get(cat)
        if not items or cat == "eggs":
            continue
        lines += [f"## {TITLES[cat]}", "", "| Model | Size (studs) | Rig | Spec | Studio file |", "|---|---|---|---|---|"]
        for st in items:
            d_ = st["_dir"]
            rel = d_.relative_to(REPO) if d_.is_relative_to(REPO) else d_
            size = " x ".join(f"{v:g}" for v in st.get("size_studs", []))
            rig = (", ".join(st.get("clips", [])) or "static")
            spec = f"../models/{st['category']}/{st['name']}.py"
            lines.append(f"| [{st['title']}](../{rel}/sheet.jpg) | {size} | {rig} | [{st['name']}.py]({spec}) | "
                         f"[{st['name']}.rbxmx](../{rel}/{st['name']}.rbxmx) |")
        lines.append("")
    md = DOCS / "GALLERY.md"
    md.write_text("\n".join(lines))
    return [out, md, *strips]
