#!/usr/bin/env python3
"""Foto di una scena animata del gioco (CutsceneController) senza Roblox Studio.

  python3 tools/scene_photo.py <cartella uscita> [--scena TutorialGiganti] [--larghezza 960] [--tempi 3.5,11,16]

La scena gira con il codice vero del gioco nel Roblox finto delle prove (tools/tests/scene_dump.luau),
con i giganti animati e la telecamera della regia; nei momenti scelti viene fotografata con il
motore di tools/thumbnails/engine.py dal punto di vista della telecamera. Alla fine unisce le foto
in un foglio unico (scena_foglio.png). Serve il programma 'luau' (variabile LUAU o nel PATH).
"""
import math
import os
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ProcessPoolExecutor

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "thumbnails"))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from engine import Camera, Look, Scene, render  # noqa: E402
from world_photo import DAY, SCALE, add_part, long_string  # noqa: E402

# i momenti da fotografare per ogni scena (secondi dall'inizio) e cosa si vede
SCENES = {
    "TutorialGiganti": [
        (3.5, "le taglie"),
        (11.0, "la nuca"),
        (16.0, "occhi e caviglie"),
        (18.7, "la presa"),
        (23.5, "l'anomalo che corre"),
        (27.5, "il boss che ruggisce"),
        (32.0, "il siero"),
    ],
}


def run(scene, times):
    sources = []
    for prefix, folder in (("Shared", os.path.join(ROOT, "src", "shared")), ("Server/Services", os.path.join(ROOT, "src", "server", "Services")), ("Client", os.path.join(ROOT, "src", "client"))):
        for base, _, names in os.walk(folder):
            for n in sorted(names):
                if n.endswith(".lua"):
                    rel = os.path.relpath(os.path.join(base, n), folder)[:-4].replace(os.sep, "/")
                    sources.append('\t["%s/%s"] = %s,' % (prefix, rel, long_string(open(os.path.join(base, n), encoding="utf-8").read())))
    bundle = "SOURCES_TABLE = {\n" + "\n".join(sources) + "\n}\n"
    for name in ("roblox_api.luau", "roblox_mock.luau"):
        bundle += open(os.path.join(ROOT, "tools", "tests", name), encoding="utf-8").read() + "\n"
    bundle += 'SCENE = "%s"\nSHOTS = { %s }\n' % (scene, ", ".join("%.3f" % t for t in times))
    bundle += "do\n" + open(os.path.join(ROOT, "tools", "tests", "scene_dump.luau"), encoding="utf-8").read() + "\nend\n"
    luau = os.environ.get("LUAU") or shutil.which("luau")
    if not luau:
        sys.exit("Interprete 'luau' non trovato")
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as f:
        f.write(bundle)
        tmp = f.name
    proc = subprocess.run([luau, tmp], capture_output=True, text=True, timeout=900)
    os.unlink(tmp)
    out = proc.stdout + proc.stderr
    if proc.returncode != 0 or "FINE" not in out:
        sys.exit("La scena non è andata a buon fine:\n" + out[-3000:])
    for line in out.splitlines():
        if line.startswith(("ERRORE", "DURATA")):
            print(line.replace("\t", ": "))
    frames = []
    for line in out.splitlines():
        f = line.split("\t")
        if f[0] == "F":
            frames.append({"t": float(f[1]), "parts": []})
        elif f[0] == "CAM":
            v = list(map(float, f[1:8]))
            frames[-1]["cam"] = (np.array(v[0:3]), np.array(v[3:6]), v[6] or 70.0)
        elif f[0] == "P" and frames:
            frames[-1]["parts"].append({
                "class": f[1], "shape": f[2], "size": np.array(list(map(float, f[3:6]))),
                "pos": np.array(list(map(float, f[6:9]))), "R": np.array(list(map(float, f[9:18]))).reshape(3, 3),
                "color": np.array(list(map(float, f[18:21]))), "mat": f[21], "alpha": float(f[22]), "name": f[23] if len(f) > 23 else "",
            })
    return frames


def render_one(args):
    frame, width, out = args
    parts = frame["parts"]
    ground = [p for p in parts if p["name"] == "Prato"]
    floor_y = (ground[0]["pos"][1] + ground[0]["size"][1] / 2) if ground else min(p["pos"][1] for p in parts)
    origin = np.array([0.0, floor_y, 0.0])
    sc = Scene()
    for p in parts:
        add_part(sc, p, origin, titan=p["mat"] in ("SmoothPlastic", "Plastic", "Fabric", "Sand", "Pebble"))
    cam_pos, target, fov = frame["cam"]
    cp = (cam_pos - origin) * SCALE
    tp = (target - origin) * SCALE
    cam = Camera(cp, tp, fov, width, int(width * 9 / 16))
    look = Look(**dict(DAY, shadow_extent=220.0, shadow_center=tuple(tp * np.array([1, 0, 1]))))
    render(sc, cam, look, ss=1, shadow_cache={}).save(out)
    return out


def main():
    args = sys.argv[1:]
    out_dir = args[0]
    scene = args[args.index("--scena") + 1] if "--scena" in args else "TutorialGiganti"
    width = int(args[args.index("--larghezza") + 1]) if "--larghezza" in args else 960
    shots = SCENES.get(scene, [])
    if "--tempi" in args:
        shots = [(float(t), "") for t in args[args.index("--tempi") + 1].split(",")]
    os.makedirs(out_dir, exist_ok=True)
    frames = run(scene, [t for t, _ in shots])
    print("fotogrammi:", len(frames))
    jobs = [(fr, width, os.path.join(out_dir, "scena_%02d.png" % i)) for i, fr in enumerate(frames)]
    with ProcessPoolExecutor(max(1, os.cpu_count() or 2)) as ex:
        done = list(ex.map(render_one, jobs))
    # foglio unico
    cols = 2
    tw = width // 2
    th = int(tw * 9 / 16)
    rows = math.ceil(len(done) / cols)
    sheet = Image.new("RGB", (tw * cols, (th + 22) * rows), (24, 24, 26))
    draw = ImageDraw.Draw(sheet)
    for i, path in enumerate(done):
        r, c = divmod(i, cols)
        sheet.paste(Image.open(path).resize((tw, th)), (c * tw, r * (th + 22) + 22))
        label = shots[i][1] if i < len(shots) else ""
        draw.text((c * tw + 6, r * (th + 22) + 5), "%.1f s  %s" % (frames[i]["t"], label), fill=(235, 235, 235))
    sheet.save(os.path.join(out_dir, "scena_foglio.png"))
    print("foglio:", os.path.join(out_dir, "scena_foglio.png"))


if __name__ == "__main__":
    main()
