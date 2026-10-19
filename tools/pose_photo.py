#!/usr/bin/env python3
"""Foto delle pose del volo con i Rampini (senza Roblox Studio).

  python3 tools/pose_photo.py <cartella uscita> [--prima cartella_src] [--larghezza 420]

Un cadetto con l'equipaggiamento vero del gioco viene messo in posa dal codice vero delle animazioni
(tools/tests/pose_dump.luau) in alcune situazioni del volo: crociera, spinta del gas, frenata, risalita
e discesa dell'oscillazione. Con --prima fa anche la riga con un'altra copia del codice (per il
confronto "prima e dopo"). Il risultato è pose_foglio.png. Serve il programma 'luau'.
"""
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "thumbnails"))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from engine import Camera, Look, Scene, render  # noqa: E402
from world_photo import STUDIO, SCALE, add_part, long_string  # noqa: E402


def run(src_root):
    sources = []
    for prefix, folder in (("Shared", os.path.join(src_root, "shared")), ("Server/Services", os.path.join(src_root, "server", "Services")), ("Client", os.path.join(src_root, "client"))):
        for base, _, names in os.walk(folder):
            for n in sorted(names):
                if n.endswith(".lua"):
                    rel = os.path.relpath(os.path.join(base, n), folder)[:-4].replace(os.sep, "/")
                    sources.append('\t["%s/%s"] = %s,' % (prefix, rel, long_string(open(os.path.join(base, n), encoding="utf-8").read())))
    bundle = "SOURCES_TABLE = {\n" + "\n".join(sources) + "\n}\n"
    for name in ("roblox_api.luau", "roblox_mock.luau"):
        bundle += open(os.path.join(ROOT, "tools", "tests", name), encoding="utf-8").read() + "\n"
    bundle += "do\n" + open(os.path.join(ROOT, "tools", "tests", "pose_dump.luau"), encoding="utf-8").read() + "\nend\n"
    luau = os.environ.get("LUAU") or shutil.which("luau")
    if not luau:
        sys.exit("Interprete 'luau' non trovato")
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as f:
        f.write(bundle)
        tmp = f.name
    proc = subprocess.run([luau, tmp], capture_output=True, text=True, timeout=600)
    os.unlink(tmp)
    out = proc.stdout + proc.stderr
    if proc.returncode != 0 or "FINE" not in out:
        sys.exit("Pose non esportate:\n" + out[-3000:])
    frames = []
    for line in out.splitlines():
        f = line.split("\t")
        if f[0] == "F":
            frames.append({"name": f[1], "parts": []})
        elif f[0] == "P" and frames:
            frames[-1]["parts"].append({
                "class": f[1], "shape": f[2], "size": np.array(list(map(float, f[3:6]))),
                "pos": np.array(list(map(float, f[6:9]))), "R": np.array(list(map(float, f[9:18]))).reshape(3, 3),
                "color": np.array(list(map(float, f[18:21]))), "mat": f[21], "alpha": float(f[22]), "name": f[23] if len(f) > 23 else "",
            })
    return frames


def shoot(frame, width, height):
    sc = Scene()
    for p in frame["parts"]:
        add_part(sc, p, np.zeros(3), titan=True)
    # inquadratura automatica sul corpo (senza le lame, che sono lunghe e sottili)
    body = [p for p in frame["parts"] if p["name"] not in ("Lama", "Impugnatura")]
    pts = np.array([p["pos"] for p in body]) * SCALE
    center = (pts.min(0) + pts.max(0)) / 2
    radius = float(np.max(np.linalg.norm(pts - center, axis=1))) + 0.35
    # di tre quarti, dal lato destro e un po' dall'alto: si vedono la sagoma, le gambe e il mantello
    view = np.array([0.82, 0.42, -0.38])
    view = view / np.linalg.norm(view)
    fov = 30
    dist = radius / np.tan(np.radians(fov / 2)) * 1.05
    cam = Camera(center + view * dist, center, fov, width, height)
    look = Look(**dict(STUDIO, shadow_extent=6.0, shadow_center=tuple(center)))
    return render(sc, cam, look, ss=1, shadow_cache={})


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(1)
    out = args[0]
    width = int(args[args.index("--larghezza") + 1]) if "--larghezza" in args else 420
    height = int(width * 0.75)
    rows = []
    if "--prima" in args:
        rows.append(("Prima", run(os.path.abspath(args[args.index("--prima") + 1]))))
    rows.append(("Dopo" if rows else "Pose", run(os.path.join(ROOT, "src"))))
    os.makedirs(out, exist_ok=True)
    label_w, head_h = 90, 26
    cols = max(len(r[1]) for r in rows)
    sheet = Image.new("RGB", (label_w + cols * width, head_h + len(rows) * height), (28, 28, 30))
    draw = ImageDraw.Draw(sheet)
    for r, (label, frames) in enumerate(rows):
        draw.text((10, head_h + r * height + height // 2 - 6), label, fill=(240, 240, 240))
        for c, frame in enumerate(frames):
            img = shoot(frame, width, height)
            img.save(os.path.join(out, "posa_%s_%d.png" % (label.lower(), c)))
            sheet.paste(img, (label_w + c * width, head_h + r * height))
            if r == 0:
                draw.text((label_w + c * width + 8, 7), frame["name"], fill=(240, 240, 240))
    path = os.path.join(out, "pose_foglio.png")
    sheet.save(path)
    print("foglio:", path)


if __name__ == "__main__":
    main()
