#!/usr/bin/env python3
"""Video di prova di un gigante 3D (il .glb di convert.py) animato con il codice VERO del gioco.

  python3 tools/mesh_titan/video.py GiganteColosso.glb cartella_uscita [--larghezza 960] [--fps 24] [--solo-foto]

Come funziona:
  1. legge dal .glb le 15 parti del corpo (SP_...) e i segnaposto delle articolazioni (J_...);
  2. nel Roblox finto delle prove costruisce il gigante dei filmati (TitanBuilder → MeshTitan) e lo
     anima con ProceduralAnimator e le pose dei giganti (anima.luau): fermo, ruggito, camminata, calcio;
  3. sposta i triangoli di ogni parte come la parte nel gioco e disegna ogni fotogramma con il
     motore di tools/thumbnails/engine.py, con la texture del modello;
  4. unisce i fotogrammi in un .mp4 con ffmpeg (serve "luau" nella variabile LUAU o nel PATH).
"""
import io
import json
import math
import os
import shutil
import struct
import subprocess
import sys
import tempfile
from concurrent.futures import ProcessPoolExecutor

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "thumbnails"))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from engine import M_COLOR, M_TEX, Camera, Look, Scene, grid_quad, render, vertex_normals  # noqa: E402
from world_photo import long_string  # noqa: E402

HEIGHT = 190.0  # altezza del colosso nei filmati (studs)
SCALE = 0.3  # metri per stud nel motore
FILE_HEIGHT = 20.0  # altezza del gigante dentro il .glb (vedi convert.py)

# il piano dell'animazione: (secondo, azione, valore)
PLAN = [
    (0.0, "Move", 0), (1.0, "Clip", "Roar"),
    (3.4, "Move", 1), (3.4, "Speed", 26),
    (6.2, "Move", 0), (6.2, "Speed", 0), (6.3, "Clip", "Kick"),
]
DURATION = 8.6


# ---------------------------------------------------------------------------------------------
# lettura del .glb
# ---------------------------------------------------------------------------------------------

def read_glb(path):
    d = open(path, "rb").read()
    jl = struct.unpack("<I", d[12:16])[0]
    js = json.loads(d[20:20 + jl])
    binb = d[20 + jl + 8:]

    def acc(i):
        a = js["accessors"][i]
        v = js["bufferViews"][a["bufferView"]]
        dt = {5126: np.float32, 5125: np.uint32, 5123: np.uint16}[a["componentType"]]
        n = {"VEC3": 3, "VEC2": 2, "SCALAR": 1}[a["type"]]
        arr = np.frombuffer(binb[v["byteOffset"]:v["byteOffset"] + v["byteLength"]], dtype=dt)
        return arr.reshape(-1, n) if n > 1 else arr

    parts, joints = {}, {}
    for node in js["nodes"]:
        prim = js["meshes"][node["mesh"]]["primitives"][0]
        P = acc(prim["attributes"]["POSITION"]).astype(np.float64)
        if node["name"].startswith("SP_"):
            uv = acc(prim["attributes"]["TEXCOORD_0"]).astype(np.float64).copy()
            uv[:, 1] = 1.0 - uv[:, 1]  # il .glb ha la V capovolta rispetto al motore
            parts[node["name"][3:]] = {"V": P, "UV": uv, "F": acc(prim["indices"]).reshape(-1, 3).astype(np.int64)}
        elif node["name"].startswith("J_"):
            joints[node["name"][2:]] = P.mean(0)
    img = js["images"][js["textures"][js["materials"][0]["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]]
    v = js["bufferViews"][img["bufferView"]]
    tex = np.asarray(Image.open(io.BytesIO(binb[v["byteOffset"]:v["byteOffset"] + v["byteLength"]])).convert("RGB")).astype(np.float64) / 255.0
    return parts, joints, tex


# ---------------------------------------------------------------------------------------------
# animazione con il codice del gioco
# ---------------------------------------------------------------------------------------------

def lua_v3(p):
    return "Vector3.new(%.5f, %.5f, %.5f)" % tuple(p)


def animate(parts, joints, look, fps):
    lines = mesh_lines(parts, joints, look)
    lines += ["ANIM_HEIGHT = %.3f" % HEIGHT, "ANIM_FPS = %d" % fps, "ANIM_DURATION = %.3f" % DURATION]
    plan = ", ".join("{ %.3f, %s, %s }" % (t, json.dumps(a), json.dumps(v) if isinstance(v, str) else repr(v)) for t, a, v in PLAN)
    lines.append("ANIM_PLAN = { %s }" % plan)
    out = run_luau(lines, "anima.luau")
    rest, frames = {}, []
    for line in out.splitlines():
        f = line.split("\t")
        if f[0] == "R":
            rest[f[1]] = cf_matrix(f[2:14])
        elif f[0] == "F":
            frames.append({"t": float(f[2]), "parts": {}})
        elif f[0] == "P":
            frames[-1]["parts"][f[1]] = cf_matrix(f[2:14])
    return rest, frames


def mesh_lines(parts, joints, look):
    """Le parti SP_ e i segnaposto J_ del .glb come variabili Luau (MESH_LOOK, MESH_PARTS, MESH_JOINTS)."""
    lines = ["MESH_LOOK = %s" % json.dumps(look), "MESH_PARTS = {"]
    for name, p in parts.items():
        lo, hi = p["V"].min(0), p["V"].max(0)
        lines.append("\t%s = { Center = %s, Size = %s }," % (name, lua_v3((lo + hi) / 2), lua_v3(np.maximum(hi - lo, 0.05))))
    lines.append("}")
    lines.append("MESH_JOINTS = {")
    for name, p in joints.items():
        lines.append("\t%s = %s," % (name, lua_v3(p)))
    lines.append("}")
    return lines


def run_luau(lines, script):
    """Esegue uno script di questa cartella nel Roblox finto delle prove, con tutto il codice del gioco."""
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
    bundle += "\n".join(lines) + "\n"
    bundle += "do\n" + open(os.path.join(HERE, script), encoding="utf-8").read() + "\nend\n"
    luau = os.environ.get("LUAU") or shutil.which("luau") or "luau"
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, script)
        open(path, "w", encoding="utf-8").write(bundle)
        res = subprocess.run([luau, path], capture_output=True, text=True, timeout=600)
    out = res.stdout + res.stderr
    if "FINE" not in out:
        raise SystemExit("animazione non riuscita:\n" + out[-3000:])
    return out


def cf_matrix(values):
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = map(float, values)
    m = np.eye(4)
    m[:3, :3] = [[r00, r01, r02], [r10, r11, r12], [r20, r21, r22]]
    m[:3, 3] = [x, y, z]
    return m


# ---------------------------------------------------------------------------------------------
# disegno
# ---------------------------------------------------------------------------------------------

LOOK = dict(
    sun_dir=(-0.45, 0.62, -0.64), sun_col=(2.2, 2.0, 1.8), sky_top=(0.30, 0.40, 0.58), sky_hor=(0.80, 0.80, 0.80),
    sky_amb=(0.36, 0.38, 0.44), ground_amb=(0.20, 0.17, 0.15), fog_density=0.0012, fog_height=60, cloud_cover=0.45,
    cloud_col=(1.0, 0.97, 0.94), cloud_dark=(0.55, 0.56, 0.62), rays=0.12, bloom=0.25, saturation=1.05, exposure=1.0,
    sun_disk=False, vignette=0.28, ground_mat="ground",
)


def body_meshes(parts, rest):
    """Vertici di ogni parte nel suo sistema di riferimento (in studs, gigante alto HEIGHT)."""
    k = HEIGHT / FILE_HEIGHT
    out = {}
    for name, p in parts.items():
        lo, hi = p["V"].min(0), p["V"].max(0)
        center = (lo + hi) / 2
        out[name] = ((p["V"] - center) * k, p["UV"], p["F"])
    return out


def frame_scene(meshes, frame, tex):
    sc = Scene()
    sc.texture = tex
    # prato
    half = 700.0
    V, F = grid_quad(np.array([-half, 0.0, -half]), np.array([2 * half, 0.0, 0.0]), np.array([0.0, 0.0, 2 * half]), 70, 70)
    sc.add(V, F, M_COLOR, (0.32, 0.42, 0.24), N=np.tile([0.0, 1.0, 0.0], (len(V), 1)))
    for name, (local, uv, faces) in meshes.items():
        m = frame["parts"][name]
        world = local @ m[:3, :3].T + m[:3, 3]
        P = world * SCALE
        sc.add(P, faces, M_TEX, (1, 1, 1), N=vertex_normals(P, faces), UV=uv)
    return sc


def camera_for(frame, index, count, width):
    hips = frame["parts"]["Hips"][:3, 3]
    k = index / max(1, count - 1)
    yaw = math.radians(-24 + 40 * k)
    dist = 300 - 30 * math.sin(k * math.pi)
    height = 58 + 30 * k
    pos = np.array([hips[0] + math.sin(yaw) * dist, height, hips[2] - math.cos(yaw) * dist])
    target = np.array([hips[0], 112.0, hips[2]])
    return Camera(pos * SCALE, target * SCALE, 50, width, int(width * 9 / 16))


SHARED = {}  # modello e texture: i processi figli li ereditano (fork) invece di riceverli ogni volta


def render_frame(args):
    frame, index, count, width, out = args
    sc = frame_scene(SHARED["meshes"], frame, SHARED["tex"])
    cam = camera_for(frame, index, count, width)
    hips = frame["parts"]["Hips"][:3, 3] * SCALE
    look = Look(**dict(LOOK, shadow_extent=110.0, shadow_center=(hips[0], 0.0, hips[2])))
    render(sc, cam, look, ss=1, shadow_cache={}).save(out)
    return out


def main():
    args = sys.argv[1:]
    glb, out_dir = args[0], args[1]
    width = int(args[args.index("--larghezza") + 1]) if "--larghezza" in args else 960
    fps = int(args[args.index("--fps") + 1]) if "--fps" in args else 24
    os.makedirs(out_dir, exist_ok=True)
    parts, joints, tex = read_glb(glb)
    look = os.path.splitext(os.path.basename(glb))[0].replace("Gigante", "")
    print("parti:", len(parts), "articolazioni:", len(joints))
    rest, frames = animate(parts, joints, look, fps)
    print("fotogrammi:", len(frames))
    SHARED["meshes"] = body_meshes(parts, rest)
    SHARED["tex"] = tex
    if "--solo-foto" in args:
        pick = [int(len(frames) * 0.3)]
    else:
        pick = list(range(len(frames)))
    jobs = [(frames[i], i, len(frames), width, os.path.join(out_dir, "f%04d.png" % i)) for i in pick]
    workers = max(1, (os.cpu_count() or 2))
    with ProcessPoolExecutor(workers) as ex:
        for done in ex.map(render_frame, jobs):
            print("  ", os.path.basename(done), flush=True)
    if "--solo-foto" not in args:
        video = os.path.join(out_dir, "colosso_animato.mp4")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps), "-i", os.path.join(out_dir, "f%04d.png"),
                        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20", video], check=True)
        print("video:", video)


if __name__ == "__main__":
    main()
