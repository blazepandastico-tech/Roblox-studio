"""Command line entry point: ``python -m studvox <command>``.

Commands
--------
make <spec.py|dir|all>...   bake -> Roblox exports -> Blender build/render/export -> concept sheet
bake <spec.py>              bake only and print counts (fast sanity check, no Blender)
trace <image>               trace a reference picture into a new model spec, then make it
gallery                     rebuild docs/gallery.png and docs/GALLERY.md from all previews
eggpack                     EggConfig.luau + one EggPack.rbxmx with every egg + egg catalogue images
list                        list model specs
doctor                      check Python deps and find Blender
"""

from __future__ import annotations

import argparse
import glob
import importlib.util
import json
import os
import platform
import shutil
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MODELS = REPO / "models"
OUT = REPO / "out"
BLENDER_SCRIPT = REPO / "blender" / "studvox_blender.py"


# ---------------------------------------------------------------------------- blender discovery

def _is_python(exe: str) -> bool:
    return "python" in Path(exe).name.lower()


def find_blender() -> list[str] | None:
    """Return the command prefix that runs the Blender pipeline script, or None."""
    env = os.environ.get("STUDVOX_BLENDER")
    cands: list[str] = []
    if env:
        cands.append(env)
    for venv in (REPO / ".venv-bpy", Path("/opt/bpyenv")):
        for sub in ("bin/python", "Scripts/python.exe"):
            p = venv / sub
            if p.exists():
                cands.append(str(p))
    w = shutil.which("blender")
    if w:
        cands.append(w)
    system = platform.system()
    if system == "Darwin":
        cands += ["/Applications/Blender.app/Contents/MacOS/Blender"]
    elif system == "Windows":
        cands += sorted(glob.glob(r"C:\Program Files\Blender Foundation\Blender*\blender.exe"), reverse=True)
    else:
        cands += ["/usr/bin/blender", "/snap/bin/blender", *sorted(glob.glob(os.path.expanduser("~/blender*/blender")))]
    if importlib.util.find_spec("bpy") is not None:
        cands.append(sys.executable)
    for c in cands:
        if c and (Path(c).exists() or shutil.which(c)):
            if _is_python(c):
                return [c, str(BLENDER_SCRIPT)]
            return [c, "-b", "--factory-startup", "--python", str(BLENDER_SCRIPT), "--"]
    return None


# ---------------------------------------------------------------------------- spec discovery

def collect_specs(targets: list[str]) -> list[Path]:
    out: list[Path] = []
    for t in targets:
        if t == "all":
            out += sorted(p for p in MODELS.rglob("*.py") if not p.name.startswith("_"))
            continue
        p = Path(t)
        if not p.exists() and (MODELS / t).exists():
            p = MODELS / t
        if not p.exists() and not t.endswith(".py"):
            hits = sorted(MODELS.rglob(f"{t}.py"))
            if hits:
                p = hits[0]
        if p.is_dir():
            out += sorted(q for q in p.rglob("*.py") if not q.name.startswith("_"))
        elif p.exists():
            out.append(p)
        else:
            raise SystemExit(f"no such model spec: {t}")
    seen, uniq = set(), []
    for p in out:
        rp = p.resolve()
        if rp not in seen:
            seen.add(rp)
            uniq.append(rp)
    return uniq


def out_dir_for(data: dict, out_root: Path) -> Path:
    return out_root / data["category"] / data["name"]


# ---------------------------------------------------------------------------- commands

def cmd_bake(args):
    from .io import load_spec, save
    from .mesher import ModelGeometry, greedy_boxes, part_arrays
    for spec in collect_specs(args.targets):
        t = time.time()
        model = load_spec(spec)
        data = model.to_dict()
        geo = ModelGeometry(data)
        c = geo.counts()
        boxes = sum(len(greedy_boxes(*part_arrays(p))) for p in data["parts"])
        lo, hi = data["bounds"]
        dims = [h - l + 1 for l, h in zip(lo, hi)]
        print(f"{data['category']}/{data['name']}: {dims[0]}x{dims[1]}x{dims[2]} voxels "
              f"({', '.join(f'{d * data['voxel_size']:g}' for d in dims)} studs), {c['voxels']} voxels, "
              f"{c['studs']} studs, {boxes} roblox parts, {len(data['parts'])} rig parts, "
              f"clips: {', '.join(cl['name'] for cl in data['clips']) or '-'}  [{time.time() - t:.2f}s]")
        if args.save:
            od = out_dir_for(data, Path(args.out))
            save(data, od / f"{data['name']}.svox.json")


def make_one(spec: Path, args, blender: list[str] | None) -> dict:
    from .io import load_spec, save
    from . import roblox, sheet
    t0 = time.time()
    model = load_spec(spec)
    data = model.to_dict()
    od = out_dir_for(data, Path(args.out))
    od.mkdir(parents=True, exist_ok=True)
    svox = save(data, od / f"{data['name']}.svox.json")
    result = {"name": data["name"], "out": str(od)}
    rb = roblox.export_all(data, od)
    result.update(rb)
    if not (args.no_render and args.no_export):
        if blender is None:
            print("  ! Blender not found: skipped renders and mesh exports (run `python -m studvox doctor`)")
        else:
            cmd = blender + ["--model", str(svox), "--out", str(od)]
            if not args.no_render:
                cmd.append("--render")
            if not args.no_export:
                cmd.append("--export")
            if args.quick:
                cmd.append("--quick")
            if args.gif:
                cmd.append("--gif")
            if args.blend:
                cmd.append("--blend")
            if getattr(args, "hero_only", False):
                cmd.append("--hero-only")
            if getattr(args, "size", 0):
                cmd += ["--size", str(args.size)]
            if args.samples:
                cmd += ["--samples", str(args.samples)]
            proc = subprocess.run(cmd, capture_output=True, text=True)
            log_path = od / "blender.log"
            log_path.write_text(proc.stdout + "\n" + proc.stderr)
            if proc.returncode != 0:
                tail = "\n".join((proc.stdout + proc.stderr).strip().splitlines()[-25:])
                raise RuntimeError(f"Blender failed for {spec.name} (see {log_path}):\n{tail}")
    stats_path = od / "stats.json"
    if stats_path.exists():
        stats = json.load(open(stats_path))
        stats["roblox"] = {k: Path(v).name for k, v in rb.items()}
        json.dump(stats, open(stats_path, "w"), indent=1)
        if "renders" in stats:
            result.update(sheet.compose(od, data))
    if args.clean:
        shutil.rmtree(od / "renders" / "gif", ignore_errors=True)
    result["seconds"] = round(time.time() - t0, 1)
    return result


def cmd_make(args):
    blender = None if (args.no_render and args.no_export) else find_blender()
    specs = collect_specs(args.targets)
    if not specs:
        raise SystemExit("nothing to build")
    failures = []
    for i, spec in enumerate(specs, 1):
        print(f"[{i}/{len(specs)}] {spec.relative_to(REPO) if spec.is_relative_to(REPO) else spec}")
        try:
            res = make_one(spec, args, blender)
        except Exception as e:  # keep going on batch builds
            failures.append((spec, e))
            print(f"  ✗ {e}")
            continue
        od = Path(res["out"])
        shown = [Path(res[k]).name for k in ("sheet", "preview", "gif", "rbxmx", "luau") if k in res]
        print(f"  ✓ {od.relative_to(REPO) if od.is_relative_to(REPO) else od}  ({', '.join(shown)})  "
              f"{res['seconds']}s")
    if failures:
        print(f"\n{len(failures)} failed:")
        for s, e in failures:
            print(f"  {s.name}: {str(e).splitlines()[0]}")
        raise SystemExit(1)
    if args.gallery:
        cmd_gallery(args)


def cmd_trace(args):
    from .trace import write_trace_spec
    spec = write_trace_spec(args.image, name=args.name, category=args.category, height=args.height,
                            depth=args.depth, colors=args.colors, outline=not args.no_outline,
                            side=args.side, title=args.title, voxel_size=args.voxel_size)
    print(f"wrote {spec.relative_to(REPO) if spec.is_relative_to(REPO) else spec}")
    if not args.spec_only:
        args.targets = [str(spec)]
        args.gallery = False
        cmd_make(args)


def cmd_gallery(args):
    from .gallery import build_gallery
    paths = build_gallery(Path(args.out))
    for p in paths:
        print(f"wrote {p.relative_to(REPO) if p.is_relative_to(REPO) else p}")


def cmd_eggpack(args):
    from .eggpack import build
    blender = None if args.no_showcase else find_blender()
    for p in build(Path(args.out), images=not args.no_images, showcase=None if args.no_showcase else args.showcase,
                   blender=blender):
        print(f"wrote {p.relative_to(REPO) if p.is_relative_to(REPO) else p}")


def cmd_list(args):
    for p in collect_specs(["all"]):
        print(p.relative_to(MODELS))


def cmd_doctor(args):
    ok = True
    for mod in ("numpy", "PIL"):
        found = importlib.util.find_spec(mod) is not None
        ok &= found
        print(f"{'✓' if found else '✗'} python module {mod}")
    b = find_blender()
    if b:
        print(f"✓ Blender pipeline: {' '.join(b[:1])}")
        try:
            if _is_python(b[0]):
                v = subprocess.run([b[0], "-c", "import bpy;print(bpy.app.version_string)"], capture_output=True,
                                   text=True, timeout=120).stdout.strip().splitlines()[-1:]
            else:
                v = subprocess.run([b[0], "-b", "--version"], capture_output=True, text=True,
                                   timeout=120).stdout.strip().splitlines()[:1]
            print(f"  version: {' '.join(v)}")
        except Exception as e:
            print(f"  (could not query version: {e})")
    else:
        ok = False
        print("✗ Blender not found. Install Blender 4.2+ (https://www.blender.org/download/) and put `blender` on "
              "PATH, set STUDVOX_BLENDER=/path/to/blender, or run scripts/setup.sh to install the bpy module.")
    print("all good" if ok else "some checks failed")


def main(argv=None):
    ap = argparse.ArgumentParser(prog="python -m studvox", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    def add_make_flags(p):
        p.add_argument("--out", default=str(OUT), help="output root (default: out/)")
        p.add_argument("--quick", action="store_true", help="fast low-res renders while iterating")
        p.add_argument("--no-render", action="store_true")
        p.add_argument("--no-export", action="store_true", help="skip FBX/GLB/OBJ (Roblox .rbxmx/.luau always written)")
        p.add_argument("--gif", action="store_true", help="render an animated GIF of the first clip")
        p.add_argument("--blend", action="store_true", help="also save a .blend of the render scene")
        p.add_argument("--samples", type=int, default=0)
        p.add_argument("--size", type=int, default=0, help="hero render size in pixels")
        p.add_argument("--hero-only", action="store_true", help="only the hero render + preview (fast catalogues)")
        p.add_argument("--clean", action="store_true", help="delete intermediate GIF frames")
        p.add_argument("--gallery", action="store_true", help="rebuild the gallery afterwards")

    p = sub.add_parser("make", help="build models")
    p.add_argument("targets", nargs="+")
    add_make_flags(p)
    p.set_defaults(func=cmd_make)

    p = sub.add_parser("bake", help="bake specs and print counts")
    p.add_argument("targets", nargs="+")
    p.add_argument("--save", action="store_true")
    p.add_argument("--out", default=str(OUT))
    p.set_defaults(func=cmd_bake)

    p = sub.add_parser("trace", help="trace a reference picture into a voxel model")
    p.add_argument("image")
    p.add_argument("--name", required=True)
    p.add_argument("--title")
    p.add_argument("--category", default="traced")
    p.add_argument("--height", type=int, default=40, help="model height in voxels")
    p.add_argument("--depth", type=float, default=0.0, help="max thickness in voxels (0 = auto)")
    p.add_argument("--colors", type=int, default=12, help="max palette colours")
    p.add_argument("--side", help="optional side-view picture to shape the depth profile")
    p.add_argument("--voxel-size", type=float, default=None)
    p.add_argument("--no-outline", action="store_true", help="drop dark outline pixels instead of keeping them")
    p.add_argument("--spec-only", action="store_true", help="only write the spec file")
    add_make_flags(p)
    p.set_defaults(func=cmd_trace)

    p = sub.add_parser("gallery", help="rebuild the gallery image + markdown")
    p.add_argument("--out", default=str(OUT))
    p.set_defaults(func=cmd_gallery)

    p = sub.add_parser("eggpack", help="EggConfig.luau + EggPack.rbxmx + egg catalogue images")
    p.add_argument("--out", default=str(OUT))
    p.add_argument("--no-images", action="store_true")
    p.add_argument("--no-showcase", action="store_true", help="skip the mutation showcase renders")
    p.add_argument("--showcase", default="galaxy_egg", help="egg used for the mutation showcase")
    p.set_defaults(func=cmd_eggpack)

    p = sub.add_parser("list", help="list model specs")
    p.set_defaults(func=cmd_list)

    p = sub.add_parser("doctor", help="check the toolchain")
    p.set_defaults(func=cmd_doctor)

    args = ap.parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main()
