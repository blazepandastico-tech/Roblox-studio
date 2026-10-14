#!/usr/bin/env python3
"""Video del gioco con il mondo vero: il trailer di lancio e quello dell'aggiornamento di Halloween.

  python3 tools/trailer_video.py chiavi <lancio|halloween> <cartella> [inquadratura ...] [--processi 3]
  python3 tools/trailer_video.py menu halloween <cartella> --caratteri cartella_caratteri
  python3 tools/trailer_video.py musica <lancio|halloween> <file.wav>
  python3 tools/trailer_video.py monta <lancio|halloween> <cartella> <musica.wav> <uscita.mp4> [verticale.mp4]
                                       [--caratteri cartella] [--processi 4] [--solo da,a]

1) "chiavi" costruisce il mondo con il codice vero del gioco (come tools/world_photo.py) e disegna una foto
   chiave per ogni inquadratura, con la distanza di ogni punto dalla telecamera (lento: qualche minuto a foto).
2) "musica" compone la musica del trailer (nessun problema di diritti).
3) "monta" muove la telecamera dentro ogni foto chiave (i punti vengono riproiettati in 3D: carrellate,
   avvicinamenti e panoramiche con la prospettiva giusta), aggiunge vapore, gas, pioggia, pipistrelli, il
   cadetto in volo, i testi e il finale, e scrive il video (1920x1080, 30 fotogrammi al secondo) e la versione
   verticale (1080x1920) con ffmpeg.
Sono immagini simulate del gioco (motore di tools/thumbnails/engine.py), non riprese di Roblox Studio.
Per i caratteri giusti: --caratteri cartella con i pacchetti npm @fontsource (vedi tools/ui_photo.py).
"""
import json
import math
import os
import subprocess
import sys
from concurrent.futures import ProcessPoolExecutor

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "thumbnails"))
sys.path.insert(0, os.path.join(ROOT, "tools"))

import world_photo as wp  # noqa: E402
from engine import Camera, Look, Scene, render  # noqa: E402

FPS = 30
OUT_W, OUT_H = 1920, 1080
KEY_W, KEY_H = 2560, 1440  # le foto chiave sono più grandi del video: avvicinarsi resta nitido
SR = 44100

# ---------------------------------------------------------------------------------------------
# Le foto chiave: da dove guarda la telecamera (spostamenti in studs rispetto a una vista di world_dump.luau)
# ---------------------------------------------------------------------------------------------

KEYS = {
    "lancio": {
        "mura": dict(view="muro_esterno", night=True, fwd=-60, up=-20, tup=8, fov=64),
        "giganti": dict(view="giganti", fwd=200, up=-28, tup=25, fov=62, titans="fila"),
        "volto": dict(view="volto", fwd=-6, up=-2, fov=60, titans="fila"),
        "nuca": dict(nape=5, fov=66, titans="fila"),
        "isola": dict(view="vermiglia_alto", fwd=150, up=40, fov=60),
        "strada": dict(view="calaneth_strada", fwd=-10, up=24, tup=-6, fov=64),
        "case_notte": dict(view="calaneth_case", night=True, fwd=-15, up=6, fov=66),
        "aurion": dict(view="aurion", fwd=-20, fov=64),
        "campo": dict(view="campo", fwd=-25, up=10, fov=64),
        "colosso": dict(view="colosso_scena", up=-30, tup=10, fov=66, titans="colosso"),
        "varieta": dict(view="varieta_volti", fwd=-10, fov=62, titans="fila"),
    },
    "halloween": {
        "mura": dict(view="muro_esterno", night=True, fwd=-40, up=-24, tup=6, fov=64),
        "case_notte": dict(view="calaneth_case", night=True, fwd=-15, up=6, fov=66),
        "strada": dict(view="calaneth_strada", fwd=-10, up=24, tup=-6, fov=64),
        "giganti": dict(view="halloween_giganti", fwd=-20, up=-6, fov=66, titans="halloween"),
        "zucca": dict(view="halloween_zucca", fwd=-12, up=-6, fov=60, titans="halloween"),
        "campo_notte": dict(view="campo", night=True, fwd=-25, up=10, fov=64),
        "isola": dict(view="vermiglia_alto", fwd=150, up=40, fov=60),
    },
}


def key_camera(data, spec):
    """Posizione e punto guardato (in studs) della foto chiave."""
    up = np.array([0.0, 1.0, 0.0])
    if "nape" in spec:
        # dietro un gigante della fila, all'altezza della nuca (i giganti guardano verso l'esterno)
        idx = spec["nape"]
        place = next(p for p in data["places"] if p[0] == idx)
        h = data["titans"][idx]["height"]
        out = np.array([math.sin(place[2]), 0.0, math.cos(place[2])])
        side = np.cross(up, out)
        neck = place[1] + up * (h * 0.86)
        cam = place[1] - out * (h * 0.95) + side * (h * 0.35) + up * (h * 1.02)
        return cam, neck
    cam, target = data["views"][spec["view"]]
    f = target - cam
    f[1] = 0
    f = f / max(1e-6, np.linalg.norm(f))
    r = np.cross(f, up)
    cam = cam + f * spec.get("fwd", 0) + r * spec.get("right", 0) + up * spec.get("up", 0)
    target = target + r * spec.get("tright", 0) + up * spec.get("tup", 0)
    return cam, target


def titan_tops(data, origin, which):
    """Testa di ogni gigante nella foto (motore, metri): da lì esce il vapore."""
    out = []
    for idx, pos, yaw in data["places"]:
        if not included(idx, which) or idx not in data["titans"]:
            continue
        a = yaw + math.pi
        c, s = math.cos(a), math.sin(a)
        R0 = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
        pts = np.array([p["pos"] @ R0.T + pos for p in data["titans"][idx]["parts"]])
        top = pts[np.argmax(pts[:, 1])]
        out.append(list(wp.to_engine(top, origin)) + [data["titans"][idx]["height"] * wp.SCALE])
    return out


def included(idx, which):
    if which == "fila":
        return idx < 30
    if which == "halloween":
        return 41 <= idx <= 47
    if which == "colosso":
        return idx == 31
    return False


def render_key(args):
    theme, name, spec, dump_path, out_dir = args
    wp.HALLOWEEN["on"] = theme == "halloween"
    data = wp.parse(dump_path)
    cam_pos, target = key_camera(data, spec)
    night = spec.get("night", False)
    which = spec.get("titans")
    reach = 4200 if spec.get("view") == "vermiglia_alto" else 2600
    sc, origin = wp.build_scene(data, cam_pos, target, reach, clear_view=which in ("fila", "halloween"), night=night)
    if which == "fila":
        wp.add_titans(sc, data, origin)
    elif which == "halloween":
        wp.add_titans(sc, data, origin, only=set(range(41, 48)), plain=False)
    elif which == "colosso":
        wp.add_titans(sc, data, origin, only={31})
    cp = wp.to_engine(cam_pos, origin)
    tp = wp.to_engine(target, origin)
    cam = Camera(cp, tp, spec.get("fov", 60), KEY_W, KEY_H)
    dist = float(np.linalg.norm(tp - cp))
    shadows = dict(shadow_extent=max(140.0, dist * 2.4), shadow_center=tuple(tp * np.array([1, 0, 1])))
    halloween = theme == "halloween"
    lights = []
    if night:
        for light in data.get("lights", []):
            if np.linalg.norm(light["pos"] - cam_pos) < 1100:
                lights.append((wp.to_engine(light["pos"], origin), tuple(light["color"] * light["brightness"] * 1.3), light["range"] * wp.SCALE))
        look, grade = dict(wp.HALLOWEEN_NIGHT if halloween else wp.NIGHT, point_lights=lights, **shadows), (0.0, (1.0, 1.0, 1.0))
    elif halloween:
        look, grade = dict(wp.HALLOWEEN_DAY, **shadows), (0.06, (1.0, 0.97, 1.02))
    else:
        zone = "Citta" if spec.get("view", "").startswith(("calaneth", "aurion")) else "Default"
        look, grade = wp.day_look(data, zone, **shadows)
    look = dict(look, vignette=0.0)  # la vignettatura la mette il montaggio (resta ferma sullo schermo)
    captured = {}

    def keep_depth(img, depth, c):
        captured["depth"] = np.asarray(depth).reshape(KEY_H, KEY_W).astype(np.float32)
        return img

    img = render(sc, cam, Look(**look), ss=1, shadow_cache={}, extra_post=keep_depth)
    img = wp.apply_grade(img, grade)
    depth = captured["depth"]
    look_info = {k: (list(map(float, v)) if isinstance(v, (tuple, list, np.ndarray)) and k != "point_lights" else v) for k, v in look.items() if k != "point_lights"}
    np.savez_compressed(
        os.path.join(out_dir, name + ".npz"),
        rgb=np.asarray(img, dtype=np.uint8), depth=depth,
        pos=cam.pos, f=cam.f, r=cam.r, u=cam.u, focal=cam.focal, target=tp,
        titans=np.array(titan_tops(data, origin, which) if which else np.zeros((0, 4))),
        look=json.dumps(look_info),
    )
    img.resize((960, 540)).save(os.path.join(out_dir, name + "_anteprima.jpg"), quality=88)
    return name


def cmd_keys(theme, out_dir, names, workers):
    os.makedirs(out_dir, exist_ok=True)
    dump_path = os.path.join(out_dir, "mondo.txt")
    if not os.path.exists(dump_path):
        print("esporto il mondo...")
        wp.HALLOWEEN["on"] = theme == "halloween"
        wp.dump(dump_path, None, "Halloween" if theme == "halloween" else None)
    jobs = [(theme, n, s, dump_path, out_dir) for n, s in KEYS[theme].items() if not names or n in names]
    with ProcessPoolExecutor(max_workers=workers) as ex:
        for name in ex.map(render_key, jobs):
            print("foto chiave:", name, flush=True)


# ---------------------------------------------------------------------------------------------
# Il cadetto in volo (sprite con la trasparenza, disegnato con l'equipaggiamento vero del gioco)
# ---------------------------------------------------------------------------------------------


def cmd_sprites(out_dir):
    import pose_photo
    frames = pose_photo.run(os.path.join(ROOT, "src"))
    frame = next((f for f in frames if f["name"].startswith("Spinta")), frames[0])
    sprites = {}
    for name, view in (("lato", np.array([1.0, 0.18, 0.0])), ("schiena", np.array([0.0, 0.55, 1.0]))):
        sc = Scene()
        for p in frame["parts"]:
            wp.add_part(sc, p, np.zeros(3), titan=True)
        pts = np.array([p["pos"] for p in frame["parts"]]) * wp.SCALE
        center = (pts.min(0) + pts.max(0)) / 2
        radius = float(np.max(np.linalg.norm(pts - center, axis=1))) + 0.2
        view = view / np.linalg.norm(view)
        fov = 26
        dist = radius / math.tan(math.radians(fov / 2)) * 1.02
        cam = Camera(center + view * dist, center, fov, 640, 640)
        look = Look(**dict(wp.DAY, vignette=0.0, bloom=0.0, rays=0.0, fog_density=0.0, shadow_extent=6.0, shadow_center=tuple(center)))
        cap = {}

        def keep(img, depth, c):
            cap["d"] = np.asarray(depth).reshape(640, 640)
            return img

        img = render(sc, cam, look, ss=1, shadow_cache={}, extra_post=keep)
        alpha = np.isfinite(cap["d"]) & (cap["d"] < 1e5)
        rgba = np.dstack([np.asarray(img), (alpha * 255).astype(np.uint8)])
        im = Image.fromarray(rgba, "RGBA")
        im = im.crop(im.getbbox())
        im.save(os.path.join(out_dir, "cadetto_%s.png" % name))
        sprites[name] = im
        print("sprite:", name, im.size)


# ---------------------------------------------------------------------------------------------
# Riproiezione: la telecamera si muove dentro la foto chiave
# ---------------------------------------------------------------------------------------------


class Key:
    def __init__(self, path):
        z = np.load(path, allow_pickle=False)
        depth = z["depth"].astype(np.float64)
        H, W = depth.shape
        self.W, self.H = W, H
        self.pos = z["pos"].astype(np.float64)
        self.f, self.r, self.u = z["f"], z["r"], z["u"]
        self.focal = float(z["focal"])
        self.target = z["target"].astype(np.float64)
        self.titans = z["titans"]
        self.look = json.loads(str(z["look"]))
        ys, xs = np.mgrid[0:H, 0:W]
        dx = (xs + 0.5 - W / 2) / self.focal
        dy = -(ys + 0.5 - H / 2) / self.focal
        sky = ~np.isfinite(depth) | (depth > 5e4)
        d = np.where(sky, 1e5, depth)
        P = self.pos + (dx[..., None] * self.r + dy[..., None] * self.u + self.f) * d[..., None]
        self.P = P.reshape(-1, 3)
        self.col = (z["rgb"].astype(np.float32) / 255.0).reshape(-1, 3)
        self.depth = d
        self.zflat = d.reshape(-1)
        hor = self.f.copy()
        hor[1] = 0
        self.fh = hor / max(1e-6, np.linalg.norm(hor))
        self.rh = np.cross(self.fh, [0.0, 1.0, 0.0])

    def frame_point(self, fwd=0.0, right=0.0, up=0.0, base=None):
        """Un punto nel riferimento della foto chiave (metri: avanti, destra, su)."""
        b = self.pos if base is None else base
        return b + self.fh * fwd + self.rh * right + np.array([0.0, 1.0, 0.0]) * up

    def camera(self, m, W, H, shake=(0.0, 0.0)):
        pos = self.frame_point(m.get("fwd", 0), m.get("right", 0), m.get("up", 0))
        tgt = self.frame_point(m.get("tfwd", 0), m.get("tright", 0) + m.get("right", 0) * m.get("follow", 1.0), m.get("tup", 0), base=self.target)
        tgt = tgt + self.rh * shake[0] + np.array([0.0, 1.0, 0.0]) * shake[1]
        return Camera(pos, tgt, m.get("fov", 50), W, H, roll=m.get("roll", 0.0))


def warp(key, cam, W, H):
    v = key.P - cam.pos
    z = v @ cam.f
    ok = z > 0.15
    zs = np.where(ok, z, 1.0)
    x = W / 2 + (v @ cam.r) * cam.focal / zs
    y = H / 2 - (v @ cam.u) * cam.focal / zs
    ok &= (x >= -2) & (x < W + 2) & (y >= -2) & (y < H + 2)
    idx = np.nonzero(ok)[0]
    xi, yi, zz = x[idx], y[idx], z[idx]
    # quanto si ingrandisce ogni punto rispetto alla foto chiave: se più di un pixel, copre 2x2 o 3x3 pixel
    # (altrimenti tra i punti di un muro vicino si vedrebbe il cielo dietro, a griglia)
    mag = (cam.focal / zz) / (key.focal / key.zflat[idx])
    xs_l, ys_l, zs_l, src_l = [np.floor(xi)], [np.floor(yi)], [zz], [idx]
    for lo, offs in ((1.04, ((1, 0), (0, 1), (1, 1))), (2.04, ((-1, 0), (0, -1), (-1, -1), (1, -1), (-1, 1)))):
        sel = np.nonzero(mag > lo)[0]
        if len(sel) == 0:
            break
        bx, by = np.floor(xi[sel] - (0.5 if lo < 2 else 0.0)), np.floor(yi[sel] - (0.5 if lo < 2 else 0.0))
        for dx, dy in offs:
            xs_l.append(bx + dx)
            ys_l.append(by + dy)
            zs_l.append(zz[sel])
            src_l.append(idx[sel])
    X = np.concatenate(xs_l).astype(np.int64)
    Y = np.concatenate(ys_l).astype(np.int64)
    Z = np.concatenate(zs_l)
    SRC = np.concatenate(src_l)
    inside = (X >= 0) & (X < W) & (Y >= 0) & (Y < H)
    X, Y, Z, SRC = X[inside], Y[inside], Z[inside], SRC[inside]
    lin = Y * W + X
    # il punto più vicino di ogni pixel, poi la media dei punti alla stessa profondità (bordi morbidi)
    order = np.argsort(lin + Z / (Z.max() + 1.0), kind="stable")
    ls = lin[order]
    first = np.ones(len(ls), bool)
    first[1:] = ls[1:] != ls[:-1]
    zmin = np.full(W * H, np.inf)
    zmin[ls[first]] = Z[order][first]
    keep = Z <= zmin[lin] * 1.012 + 0.03
    lk = lin[keep]
    cnt = np.bincount(lk, minlength=W * H).astype(np.float64)
    cols = key.col[SRC[keep]]
    img = np.stack([np.bincount(lk, weights=cols[:, c], minlength=W * H) for c in range(3)], -1)
    valid = cnt > 0
    img[valid] /= cnt[valid, None]
    img = img.reshape(H, W, 3)
    zb = zmin.reshape(H, W)
    valid = valid.reshape(H, W)
    if not valid.all():
        fill_holes(img, zb, valid)
    return img, zb


def fill_holes(img, zb, valid):
    """I pixel rimasti vuoti prendono il colore del pixel pieno più vicino (un solo passaggio)."""
    from scipy.ndimage import distance_transform_edt
    _, (iy, ix) = distance_transform_edt(~valid, return_indices=True)
    holes = ~valid
    img[holes] = img[iy[holes], ix[holes]]
    zb[holes] = zb[iy[holes], ix[holes]]


# ---------------------------------------------------------------------------------------------
# Effetti nel mondo (vapore, pioggia, foglie, pipistrelli, scie di gas...) con la profondità giusta
# ---------------------------------------------------------------------------------------------


def project(cam, P, W, H):
    v = P - cam.pos
    z = float(v @ cam.f)
    if z < 0.25:
        return None
    return W / 2 + float(v @ cam.r) * cam.focal / z, H / 2 - float(v @ cam.u) * cam.focal / z, z


def splat(img, zb, x, y, z, rp, col, alpha, add=False, hard=False):
    H, W = zb.shape
    rp = max(rp, 0.6)
    ext = rp * (1.2 if hard else 2.0)
    x0, x1 = int(max(0, x - ext)), int(min(W, x + ext + 1))
    y0, y1 = int(max(0, y - ext)), int(min(H, y + ext + 1))
    if x1 <= x0 or y1 <= y0:
        return
    yy, xx = np.ogrid[y0:y1, x0:x1]
    d2 = ((xx + 0.5 - x) ** 2 + (yy + 0.5 - y) ** 2) / (rp * rp)
    w = np.clip(1.2 - d2, 0, 1) if hard else np.exp(-d2 * 2.0)
    w = w * alpha * (zb[y0:y1, x0:x1] > z)
    if not w.any():
        return
    if add:
        img[y0:y1, x0:x1] += np.asarray(col) * w[..., None]
    else:
        img[y0:y1, x0:x1] = img[y0:y1, x0:x1] * (1 - w[..., None]) + np.asarray(col) * w[..., None]


def particles(img, zb, cam, items, W, H):
    """items: (P, raggio in metri, colore, alpha, add)"""
    for P, rad, col, a, add in items:
        p = project(cam, P, W, H)
        if p is None:
            continue
        x, y, z = p
        rp = rad * cam.focal / z
        if rp > 400 or x < -rp * 2 or x > W + rp * 2 or y < -rp * 2 or y > H + rp * 2:
            continue
        if rp < 0.6:
            a *= rp / 0.6
        splat(img, zb, x, y, z, rp, col, a, add)


def sprite(img, zb, cam, P, height_m, im, W, H, alpha=1.0, flip=False, rot=0.0, tint=None):
    p = project(cam, P, W, H)
    if p is None:
        return
    x, y, z = p
    hp = height_m * cam.focal / z
    if hp < 2 or hp > 4 * H:
        return
    wpx = max(1, int(hp * im.width / im.height))
    s = im.resize((wpx, max(1, int(hp))), Image.LANCZOS)
    if flip:
        s = s.transpose(Image.FLIP_LEFT_RIGHT)
    if rot:
        s = s.rotate(rot, resample=Image.BICUBIC, expand=True)
    a = np.asarray(s).astype(np.float64) / 255.0
    sh, sw = a.shape[:2]
    x0, y0 = int(x - sw / 2), int(y - sh / 2)
    xa, ya = max(0, x0), max(0, y0)
    xb, yb = min(W, x0 + sw), min(H, y0 + sh)
    if xb <= xa or yb <= ya:
        return
    part = a[ya - y0:yb - y0, xa - x0:xb - x0]
    w = part[..., 3] * alpha * (zb[ya:yb, xa:xb] > z)
    rgb = part[..., :3] if tint is None else part[..., :3] * np.asarray(tint)
    img[ya:yb, xa:xb] = img[ya:yb, xa:xb] * (1 - w[..., None]) + rgb * w[..., None]


def bat_image(size, flap):
    """Un pipistrello nero con le ali (flap: -1..1 per il battito)."""
    s = size * 4
    im = Image.new("RGBA", (s * 2, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, cy = s, s // 2
    lift = int(flap * s * 0.32)
    col = (14, 8, 20, 255)
    for side in (-1, 1):
        tip = (cx + side * int(s * 0.95), cy - lift - int(s * 0.1))
        d.polygon([(cx + side * int(s * 0.08), cy - int(s * 0.08)), tip, (cx + side * int(s * 0.7), cy + int(s * 0.05) - lift // 2),
                   (cx + side * int(s * 0.5), cy + int(s * 0.12) - lift // 3), (cx + side * int(s * 0.28), cy + int(s * 0.06)), (cx + side * int(s * 0.1), cy + int(s * 0.14))], fill=col)
    d.ellipse([cx - int(s * 0.12), cy - int(s * 0.16), cx + int(s * 0.12), cy + int(s * 0.2)], fill=col)
    for side in (-1, 1):
        d.polygon([(cx + side * int(s * 0.03), cy - int(s * 0.12)), (cx + side * int(s * 0.1), cy - int(s * 0.28)), (cx + side * int(s * 0.12), cy - int(s * 0.1))], fill=col)
    return im.resize((size * 2, size), Image.LANCZOS)


BATS = [bat_image(48, f) for f in (-1.0, -0.4, 0.3, 1.0, 0.3, -0.4)]


class FX:
    """Gli effetti di un'inquadratura: tutti nel riferimento della foto chiave (metri)."""

    def __init__(self, key, shot, assets):
        self.key, self.shot, self.assets = key, shot, assets
        self.rng = np.random.default_rng(abs(hash(shot.name)) % (2 ** 31))

    def apply(self, img, zb, cam, t, W, H):
        k = self.key
        T = t * self.shot.dur
        for fx in self.shot.fx:
            kind, opt = fx[0], (fx[1] if len(fx) > 1 else {})
            rng = np.random.default_rng(hash((self.shot.name, kind)) % (2 ** 31))
            if kind == "vapore":
                items = []
                for top in k.titans:
                    P0 = np.array(top[:3])
                    h = top[3]
                    for i in range(opt.get("n", 14)):
                        age = (T * 0.9 + i / 14.0 * 3.0 + rng.random()) % 3.0
                        off = np.array([rng.normal() * 0.08 * h, age * 0.25 * h, rng.normal() * 0.08 * h])
                        items.append((P0 + off - np.array([0, 0.06 * h, 0]), (0.06 + age * 0.05) * h, (0.95, 0.95, 0.93), 0.32 * (1 - age / 3.0), False))
                particles(img, zb, cam, items, W, H)
            elif kind == "pioggia":
                items = []
                for i in range(opt.get("n", 900)):
                    base = k.frame_point(rng.uniform(4, 70), rng.uniform(-45, 45), 0)
                    yy = (rng.uniform(0, 40) - T * 28) % 40 - 6
                    P = base + np.array([0, yy, 0])
                    items.append((P, 0.035, (0.75, 0.8, 0.9), 0.35, False))
                    items.append((P + np.array([0, 0.5, 0]), 0.03, (0.75, 0.8, 0.9), 0.25, False))
                particles(img, zb, cam, items, W, H)
            elif kind == "foglie":
                items = []
                cols = opt.get("colori", [(0.95, 0.45, 0.1), (0.75, 0.25, 0.08), (0.95, 0.7, 0.2), (0.45, 0.2, 0.35)])
                for i in range(opt.get("n", 160)):
                    base = k.frame_point(rng.uniform(3, 45), rng.uniform(-25, 25), 0)
                    yy = (rng.uniform(0, 18) - T * 1.6) % 18
                    sway = math.sin(T * 2 + i) * 0.8
                    P = base + np.array([sway, yy, math.cos(T * 1.5 + i) * 0.6])
                    items.append((P, 0.09, cols[i % len(cols)], 0.9, False))
                particles(img, zb, cam, items, W, H)
            elif kind == "lucciole":
                items = []
                col = opt.get("colore", (1.0, 0.85, 0.35))
                for i in range(opt.get("n", 90)):
                    base = k.frame_point(rng.uniform(5, 60), rng.uniform(-30, 30), rng.uniform(0.5, 7))
                    P = base + np.array([math.sin(T * 0.7 + i) * 0.7, math.sin(T * 1.1 + i * 1.7) * 0.4, math.cos(T * 0.6 + i) * 0.7])
                    blink = 0.5 + 0.5 * math.sin(T * 3 + i * 2.3)
                    items.append((P, 0.12, col, 0.9 * blink, True))
                particles(img, zb, cam, items, W, H)
            elif kind == "nebbia":
                items = []
                col = opt.get("colore", (0.55, 0.5, 0.7))
                for i in range(opt.get("n", 70)):
                    base = k.frame_point(rng.uniform(8, 120), rng.uniform(-60, 60), rng.uniform(0, 2.5))
                    P = base + k.rh * (T * 1.2)
                    items.append((P, rng.uniform(3, 7), col, 0.1, False))
                particles(img, zb, cam, items, W, H)
            elif kind == "pipistrelli":
                for i in range(opt.get("n", 14)):
                    start = k.frame_point(rng.uniform(15, 80), rng.uniform(-50, 50), rng.uniform(6, 30))
                    vel = k.rh * rng.choice([-1, 1]) * rng.uniform(5, 10) + k.fh * rng.uniform(-3, 3)
                    P = start + vel * T + np.array([0, math.sin(T * 3 + i) * 1.2, 0])
                    frame = BATS[int((T * 14 + i) % len(BATS))]
                    sprite(img, zb, cam, P, rng.uniform(0.6, 1.2), frame, W, H)
            elif kind == "fantasmi":
                ghost = self.assets.get("fantasma")
                if ghost is not None:
                    for i, (fw, rt, upv) in enumerate(opt.get("dove", [(30, -8, 6)])):
                        P = k.frame_point(fw, rt + math.sin(T * 0.8 + i) * 1.5, upv + math.sin(T * 1.3 + i) * 0.6)
                        a = 0.55 * min(1.0, T / 0.6) * (0.75 + 0.25 * math.sin(T * 2 + i))
                        sprite(img, zb, cam, P, opt.get("alto", 4.0), ghost, W, H, alpha=a)
            elif kind == "cadetto":
                self.cadet(img, zb, cam, T, W, H, opt)
        return img

    def cadet(self, img, zb, cam, T, W, H, opt):
        """Il cadetto che vola con i rampini: percorso, scia di gas e cavo agganciato."""
        k = self.key
        pts = [k.frame_point(*p) for p in opt["percorso"]]
        t0, t1 = opt.get("da", 0.0), opt.get("a", self.shot.dur)

        def at(tt):
            u = min(max((tt - t0) / (t1 - t0), 0.0), 1.0)
            n = len(pts) - 1
            i = min(int(u * n), n - 1)
            f = u * n - i
            p0, p1 = pts[i], pts[i + 1]
            pm = pts[i - 1] if i > 0 else p0
            p2 = pts[i + 2] if i + 2 <= n else p1
            # Catmull-Rom: curva morbida tra i punti
            return 0.5 * (2 * p0 + (-pm + p1) * f + (2 * pm - 5 * p0 + 4 * p1 - p2) * f * f + (-pm + 3 * p0 - 3 * p1 + p2) * f ** 3)

        if T < t0:
            return
        # scia di gas: i punti già passati, che si allargano e svaniscono
        trail = []
        steps = 40
        for j in range(steps):
            tt = T - j * 0.03
            if tt < t0:
                break
            age = j * 0.03
            trail.append((at(tt) + np.array([0, -0.2, 0]), 0.18 + age * 0.9, (0.96, 0.97, 1.0), 0.55 * (1 - j / steps), False))
        particles(img, zb, cam, trail[::-1], W, H)
        P = at(T)
        # cavo verso il punto d'aggancio
        if "aggancio" in opt and T <= t1:
            A = k.frame_point(*opt["aggancio"])
            items = []
            for j in range(1, 60):
                q = P + (A - P) * (j / 60.0)
                items.append((q, 0.03, (0.15, 0.13, 0.12), 0.8, False))
            particles(img, zb, cam, items, W, H)
        im = self.assets["cadetto_" + opt.get("vista", "lato")]
        nxt = at(min(T + 0.05, t1))
        pa, pb = project(cam, P, W, H), project(cam, nxt, W, H)
        flip = bool(pa and pb and pb[0] < pa[0]) if opt.get("vista", "lato") == "lato" else False
        if T <= t1 + 0.4:
            sprite(img, zb, cam, P, opt.get("alto", 2.2), im, W, H, flip=flip, rot=opt.get("ruota", 0.0))


# ---------------------------------------------------------------------------------------------
# Testi
# ---------------------------------------------------------------------------------------------


class Typo:
    def __init__(self, fonts_dir):
        import ui_photo
        self.ui = ui_photo
        self.fonts = ui_photo.Fonts(fonts_dir)

    def line(self, text, name, px, fill=(255, 255, 255), stroke=0, stroke_fill=(0, 0, 0), spacing=0.0, gradient=None, glow=None):
        """Una riga di testo (con le emoji) come immagine RGBA."""
        ui, fonts = self.ui, self.fonts
        runs = ui.runs(fonts, text, name)
        width = 0.0
        for kind, s, path in runs:
            if kind == "e":
                img = fonts.emoji_image(s)
                width += px * 1.08 * img.width / img.height + px * 0.08
            else:
                f = fonts.get_path(path, px)
                width += f.getlength(s) + spacing * px * len(s)
        pad = int(stroke + px * 0.5 + (glow[1] * 3 if glow else 0))
        W, H = int(width) + 2 * pad, int(px * 1.5) + 2 * pad
        txt = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        mask = Image.new("L", (W, H), 0)
        emo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d, dm = ImageDraw.Draw(txt), ImageDraw.Draw(mask)
        x = float(pad)
        base_y = pad + px * 0.12
        for kind, s, path in runs:
            if kind == "e":
                img = fonts.emoji_image(s)
                eh = int(px * 1.08)
                ew = int(eh * img.width / img.height)
                emo.alpha_composite(img.resize((ew, eh), Image.LANCZOS), (int(x), int(base_y + px * 0.02)))
                x += ew + px * 0.08
                continue
            f = fonts.get_path(path, px)
            if spacing:
                for ch in s:
                    if stroke:
                        d.text((x, base_y), ch, font=f, fill=stroke_fill, stroke_width=stroke, stroke_fill=stroke_fill)
                    dm.text((x, base_y), ch, font=f, fill=255)
                    x += f.getlength(ch) + spacing * px
            else:
                if stroke:
                    d.text((x, base_y), s, font=f, fill=stroke_fill, stroke_width=stroke, stroke_fill=stroke_fill)
                dm.text((x, base_y), s, font=f, fill=255)
                x += f.getlength(s)
        if gradient:
            top, bottom = np.array(gradient[0], float), np.array(gradient[1], float)
            ys = np.linspace(0, 1, H)[:, None, None]
            g = (top * (1 - ys) + bottom * ys) * np.ones((1, W, 1))
            fill_img = Image.fromarray(g.astype(np.uint8), "RGB").convert("RGBA")
        else:
            fill_img = Image.new("RGBA", (W, H), tuple(fill) + (255,))
        fill_img.putalpha(mask)
        out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        if glow:
            gl = Image.new("RGBA", (W, H), tuple(glow[0]) + (0,))
            gl.putalpha(mask.filter(ImageFilter.GaussianBlur(glow[1])).point(lambda v: min(255, int(v * 1.6))))
            out.alpha_composite(gl)
        # ombra morbida sotto il testo
        shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        sh_mask = mask.filter(ImageFilter.GaussianBlur(max(2, px * 0.06)))
        shadow.putalpha(sh_mask.point(lambda v: int(v * 0.7)))
        out.alpha_composite(shadow, (0, max(1, int(px * 0.05))))
        out.alpha_composite(txt)
        out.alpha_composite(fill_img)
        out.alpha_composite(emo)
        return out.crop(out.getbbox() or (0, 0, W, H))


def paste(frame, im, cx, cy, alpha=1.0, scale=1.0):
    """Incolla un'immagine RGBA centrata in (cx, cy) su un fotogramma (array float 0..1)."""
    if alpha <= 0.003:
        return
    if abs(scale - 1.0) > 1e-3:
        im = im.resize((max(1, int(im.width * scale)), max(1, int(im.height * scale))), Image.LANCZOS)
    a = np.asarray(im).astype(np.float64) / 255.0
    H, W = frame.shape[:2]
    h, w = a.shape[:2]
    x0, y0 = int(cx - w / 2), int(cy - h / 2)
    xa, ya, xb, yb = max(0, x0), max(0, y0), min(W, x0 + w), min(H, y0 + h)
    if xb <= xa or yb <= ya:
        return
    part = a[ya - y0:yb - y0, xa - x0:xb - x0]
    wgt = part[..., 3:4] * alpha
    frame[ya:yb, xa:xb] = frame[ya:yb, xa:xb] * (1 - wgt) + part[..., :3] * wgt


# ---------------------------------------------------------------------------------------------
# Le inquadrature dei due trailer
# ---------------------------------------------------------------------------------------------


def ease(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


def ease_out(t):
    t = min(max(t, 0.0), 1.0)
    return 1 - (1 - t) ** 3


def move(a, b, curve=ease):
    """Movimento di telecamera: da a a b (dizionari con fwd, right, up, tright, tup, fov, roll)."""
    def m(t):
        k = curve(t)
        out = {}
        for key in set(a) | set(b):
            va, vb = a.get(key, b.get(key, 0.0)), b.get(key, a.get(key, 0.0))
            out[key] = va + (vb - va) * k
        return out
    return m


class Shot:
    def __init__(self, name, dur, key=None, image=None, cam=None, fx=(), caption=None, title=None, flashes=(), shake=0.0,
                 fade_in=0.0, fade_out=0.0, blur=1, zoom=(1.0, 1.0), focus=(0.5, 0.5), grade=None, dark=0.0, logo=None, slash=None):
        self.name, self.dur, self.key, self.image = name, dur, key, image
        self.cam = cam or (lambda t: {})
        self.fx, self.caption, self.title = list(fx), caption, title
        self.flashes, self.shake = list(flashes), shake
        self.fade_in, self.fade_out, self.blur = fade_in, fade_out, blur
        self.zoom, self.focus, self.grade, self.dark, self.logo = zoom, focus, grade, dark, logo
        self.slash = slash


GOLD = (255, 214, 120)
RED = (255, 96, 70)
ORANGE = (255, 150, 40)
GREEN = (150, 255, 110)


def shots_lancio():
    return [
        Shot("intro", 3.0, caption=("Un tempo le Mura ci proteggevano...", "Merriweather", None), fade_in=0.6, fade_out=0.5),
        Shot("mura", 3.5, key="mura", cam=move({"fov": 52}, {"fwd": 16, "up": 3, "fov": 48}), fx=[("pioggia", {"n": 700})],
             flashes=[(0.25, 0.9, (0.75, 0.82, 1.0)), (1.6, 0.5, (0.75, 0.82, 1.0))], fade_in=0.15,
             title=("Poi tornarono i GIGANTI.", "GothamBlack", RED)),
        Shot("giganti", 3.5, key="giganti", cam=move({"fov": 52, "up": 0}, {"fwd": 30, "up": 5, "tup": 4, "fov": 50}), fx=[("vapore", {"n": 10})], shake=0.6,
             caption=("Sono enormi... e hanno fame.", "GothamBlack", None)),
        Shot("volto", 2.0, key="volto", cam=move({"fov": 50, "roll": 0.0}, {"fwd": 2.5, "fov": 44, "roll": -0.04}), fx=[("vapore", {"n": 8})], flashes=[(1.85, 0.6, (1, 1, 1))]),
        Shot("tetti", 4.0, key="aurion", cam=move({"fov": 56}, {"fwd": 8, "up": -1, "fov": 52}),
             fx=[("cadetto", {"percorso": [(26, 20, -2), (32, 8, -5), (38, -4, -6), (46, -16, -4), (56, -28, -1)], "aggancio": (68, -24, 8), "da": 0.2, "a": 3.7, "alto": 1.9})],
             caption=("Vola tra i tetti con i rampini", "GothamBlack", GOLD)),
        Shot("nuca", 3.0, key="nuca", cam=move({"fov": 56}, {"fwd": 5, "fov": 46}, ease_out), blur=2, shake=0.4,
             fx=[("vapore", {"n": 12}), ("cadetto", {"percorso": [(1, -5, -5), (5, -3, -3), (9, -1, -2), (12.4, 0, -1.8)], "da": 0.1, "a": 2.0, "vista": "schiena", "alto": 1.9})],
             flashes=[(2.0, 0.55, (1, 1, 1))], slash=2.0, title=("COLPISCI LA NUCA!", "GothamBlack", GOLD)),
        Shot("isola", 3.5, key="isola", cam=move({"fov": 52}, {"fwd": 40, "right": 50, "up": -10, "fov": 50, "follow": 0.2}),
             caption=("5 isole. Un arcipelago tutto da esplorare.", "GothamBlack", None)),
        Shot("strada", 2.5, key="strada", cam=move({"fov": 56}, {"fwd": 5, "up": 0.3, "fov": 54}),
             caption=("Città vive: mercati, cavalli e barche", "GothamBlack", None)),
        Shot("case_notte", 2.5, key="case_notte", cam=move({"fov": 56, "right": -3}, {"right": 4, "fov": 54, "follow": 0.6}), fx=[("lucciole", {"n": 70})],
             caption=("Giorno, notte, pioggia e temporali", "GothamBlack", None)),
        Shot("campo", 2.5, key="campo", cam=move({"fov": 56}, {"up": 6, "fwd": 6, "fov": 54}),
             caption=("Storia in 4 stagioni, missioni e raid", "GothamBlack", None)),
        Shot("colosso", 3.5, key="colosso", cam=move({"fov": 58, "tup": -12}, {"fwd": 6, "tup": 2, "fov": 52}), fx=[("vapore", {"n": 14})], shake=0.8,
             flashes=[(0.1, 0.8, (1.0, 0.9, 0.8))], title=("I GIGANTI PIÙ GRANDI TI ASPETTANO", "GothamBlack", RED)),
        Shot("varieta", 1.5, key="varieta", cam=move({"fov": 52}, {"fwd": 3, "fov": 48}), fx=[("vapore", {"n": 8})],
             caption=("Ogni gigante è diverso", "GothamBlack", None)),
        Shot("finale", 5.5, key="giganti", cam=move({"fov": 50, "fwd": -6}, {"fwd": 6, "fov": 50}), dark=0.6, fade_out=0.6,
             logo="lancio", fx=[("vapore", {"n": 8})]),
    ]


def shots_halloween():
    return [
        Shot("intro", 2.5, caption=("Questa notte le Mura sono infestate...", "Merriweather", None), fade_in=0.5,
             flashes=[(1.3, 0.8, (0.7, 0.55, 1.0))], fx=[("pipistrelli2d",)]),
        Shot("mura", 3.5, key="mura", cam=move({"fov": 52}, {"fwd": 16, "up": 2, "fov": 48}), fx=[("nebbia", {}), ("pipistrelli", {"n": 16})],
             flashes=[(0.05, 0.7, (0.7, 0.55, 1.0))], title=("🎃 AGGIORNAMENTO DI HALLOWEEN", "Creepster", ORANGE)),
        Shot("case_notte", 3.0, key="case_notte", cam=move({"fov": 56, "right": -3}, {"right": 4, "fov": 54, "follow": 0.6}),
             fx=[("pipistrelli", {"n": 10}), ("fantasmi", {"dove": [(28, -6, 7), (40, 10, 9)], "alto": 4.5}), ("lucciole", {"n": 50, "colore": (0.6, 1.0, 0.45)})],
             caption=("Case e giardini infestati", "GothamBlack", ORANGE)),
        Shot("strada", 2.5, key="strada", cam=move({"fov": 56}, {"fwd": 5, "up": 0.3, "fov": 54}), fx=[("foglie", {"n": 140})],
             caption=("Zucche, lapidi, ragnatele e candele", "GothamBlack", None)),
        Shot("giganti", 3.5, key="giganti", cam=move({"fov": 52, "right": -8}, {"right": 8, "fwd": 6, "fov": 50, "follow": 0.7}), fx=[("nebbia", {"colore": (0.7, 0.55, 0.6)}), ("foglie", {"n": 80})],
             title=("I GIGANTI SI TRAVESTONO!", "Creepster", ORANGE)),
        Shot("zucca", 3.0, key="zucca", cam=move({"fov": 52}, {"fwd": 5, "up": 1, "fov": 46}), shake=0.4, flashes=[(0.15, 0.6, (1.0, 0.6, 0.2))],
             caption=("Arrivano il Re Zucca e il Gigante Fantasma", "GothamBlack", ORANGE)),
        Shot("ev1", 1.3, image="evento_NotteZucche", zoom=(1.0, 1.06), flashes=[(0.0, 0.7, (1.0, 0.7, 0.3))], title=("5 NUOVI EVENTI ADMIN ABUSE", "Creepster", ORANGE)),
        Shot("ev2", 1.3, image="evento_GiganteFantasma", zoom=(1.02, 1.08), flashes=[(0.0, 0.6, (0.8, 0.9, 1.0))], title=("5 NUOVI EVENTI ADMIN ABUSE", "Creepster", ORANGE)),
        Shot("ev3", 1.3, image="evento_RisveglioCaduti", zoom=(1.0, 1.06), flashes=[(0.0, 0.6, (0.6, 1.0, 0.5))], title=("5 NUOVI EVENTI ADMIN ABUSE", "Creepster", ORANGE)),
        Shot("ev4", 1.3, image="evento_DolcettoScherzetto", zoom=(1.02, 1.08), flashes=[(0.0, 0.6, (1.0, 0.6, 0.9))], title=("5 NUOVI EVENTI ADMIN ABUSE", "Creepster", ORANGE)),
        Shot("ev5", 1.3, image="evento_LunaSangue", zoom=(1.0, 1.06), flashes=[(0.0, 0.6, (1.0, 0.3, 0.3))], title=("5 NUOVI EVENTI ADMIN ABUSE", "Creepster", ORANGE)),
        Shot("premi", 2.6, image="admin", zoom=(1.05, 1.25), focus=(0.5, 0.36), caption=("Dolcetti, premio finale e bonus doppi", "GothamBlack", ORANGE)),
        Shot("programma", 2.6, image="admin_programma", zoom=(1.05, 1.22), focus=(0.5, 0.5),
             caption=("Programma gli eventi: giorno, ora e annuncio", "GothamBlack", ORANGE)),
        Shot("campo_notte", 2.5, key="campo_notte", cam=move({"fov": 56}, {"up": 5, "fwd": 6, "fov": 54}), fx=[("pipistrelli", {"n": 12}), ("lucciole", {"n": 60, "colore": (0.6, 1.0, 0.45)})],
             caption=("Pipistrelli, fantasmi e fuochi fatui", "GothamBlack", None)),
        Shot("isola", 2.5, key="isola", cam=move({"fov": 52}, {"fwd": 30, "right": 40, "up": -8, "fov": 50, "follow": 0.2}),
             caption=("Tutto l'arcipelago è in festa", "GothamBlack", ORANGE)),
        Shot("finale", 5.5, image="titolo", zoom=(1.0, 1.05), focus=(0.5, 0.35), fade_out=0.6, logo="halloween"),
    ]


SHOTS = {"lancio": shots_lancio, "halloween": shots_halloween}


def timeline(theme):
    t, out = 0.0, []
    for s in SHOTS[theme]():
        out.append((s, t))
        t += s.dur
    return out, t


# ---------------------------------------------------------------------------------------------
# I menu del gioco per il trailer di Halloween (con tools/ui_photo.py)
# ---------------------------------------------------------------------------------------------

EVENT_BACKGROUNDS = {"NotteZucche": "zucca", "GiganteFantasma": "mura", "RisveglioCaduti": "campo_notte", "DolcettoScherzetto": "strada", "LunaSangue": "case_notte"}


def cmd_menus(theme, out_dir, fonts_dir):
    import ui_photo
    fonts = ui_photo.Fonts(fonts_dir)
    tema = "Halloween" if theme == "halloween" else None

    def background(name):
        path = os.path.join(out_dir, "sfondo_%s.png" % name)
        if not os.path.exists(path):
            z = np.load(os.path.join(out_dir, name + ".npz"))
            Image.fromarray(z["rgb"]).resize((OUT_W, OUT_H), Image.LANCZOS).save(path)
        return path

    jobs = [("titolo", "titolo", None, None, None), ("admin", "admin", None, "mura", None), ("admin_programma", "admin", None, "mura", "📅 Programma un evento")]
    if theme == "halloween":
        for ev, bg in EVENT_BACKGROUNDS.items():
            jobs.append(("evento_" + ev, "evento", ev, bg, None))
    for name, scene, event, bg, scroll in jobs:
        text = ui_photo.dump(scene, tema, event)
        img = ui_photo.render_scene(text, fonts, background(bg) if bg else None, scroll)
        img.save(os.path.join(out_dir, name + ".png"))
        print("menu:", name)


# ---------------------------------------------------------------------------------------------
# Un fotogramma
# ---------------------------------------------------------------------------------------------

STATE = {}


def assets(folder, fonts_dir):
    if "assets" not in STATE:
        a = {}
        for n in ("cadetto_lato", "cadetto_schiena"):
            p = os.path.join(folder, n + ".png")
            if os.path.exists(p):
                a[n] = Image.open(p).convert("RGBA")
        typo = Typo(fonts_dir)
        g = typo.fonts.emoji_image("👻")
        if g is not None:
            a["fantasma"] = g
        STATE["assets"] = a
        STATE["typo"] = typo
        STATE["keys"] = {}
        STATE["images"] = {}
        STATE["texts"] = {}
        yy, xx = np.mgrid[0:OUT_H, 0:OUT_W]
        r = np.sqrt(((xx - OUT_W / 2) / (OUT_W / 2)) ** 2 + ((yy - OUT_H / 2) / (OUT_H / 2)) ** 2)
        STATE["vignette"] = (1 - 0.32 * np.clip(r - 0.45, 0, 1) ** 1.6)[..., None]
    return STATE["assets"]


def get_key(folder, name):
    keys = STATE["keys"]
    if name not in keys:
        if len(keys) >= 2:
            keys.pop(next(iter(keys)))
        keys[name] = Key(os.path.join(folder, name + ".npz"))
    return keys[name]


def get_image(folder, name):
    if name not in STATE["images"]:
        STATE["images"][name] = Image.open(os.path.join(folder, name + ".png")).convert("RGB")
    return STATE["images"][name]


def text_image(spec, px, role):
    key = (spec, px, role)
    if key not in STATE["texts"]:
        text, font, accent = spec[0], spec[1], spec[2]
        typo = STATE["typo"]
        if font == "Merriweather":
            im = typo.line(text, "Merriweather", px, fill=(240, 232, 220), stroke=0)
        elif font == "Creepster":
            im = typo.line(text, "Creepster", px, gradient=((255, 210, 90), (235, 90, 20)), stroke=max(2, px // 18), stroke_fill=(30, 8, 40), glow=((120, 255, 80), px * 0.12))
        else:
            im = typo.line(text, font, px, fill=accent or (255, 255, 255), stroke=max(2, px // 14), stroke_fill=(16, 12, 10))
        STATE["texts"][key] = im
    return STATE["texts"][key]


def fit(im, max_w):
    if im.width <= max_w:
        return im
    return im.resize((max_w, max(1, int(im.height * max_w / im.width))), Image.LANCZOS)


def grade(img, theme):
    lum = img.mean(-1, keepdims=True)
    if theme == "halloween":
        sh, hi = np.array([0.05, 0.0, 0.08]), np.array([0.05, 0.015, -0.03])
    else:
        sh, hi = np.array([-0.01, 0.015, 0.03]), np.array([0.04, 0.02, -0.02])
    img = img + sh * (1 - lum) * 0.6 + hi * lum * 0.6
    return (img - 0.5) * 1.06 + 0.5


def embers_2d(frame, T, theme, n=70):
    rng = np.random.default_rng(7)
    H, W = frame.shape[:2]
    for i in range(n):
        x = (rng.random() * W + math.sin(T * 0.7 + i) * 30) % W
        y = H - ((rng.random() * H + T * (40 + rng.random() * 80)) % (H + 40))
        r = 1.5 + rng.random() * 3
        col = (1.0, 0.55, 0.2) if theme != "halloween" else ((0.95, 0.5, 0.15) if i % 2 else (0.6, 0.3, 0.8))
        a = 0.5 + 0.5 * math.sin(T * 3 + i)
        x0, x1, y0, y1 = int(max(0, x - r * 3)), int(min(W, x + r * 3)), int(max(0, y - r * 3)), int(min(H, y + r * 3))
        if x1 <= x0 or y1 <= y0:
            continue
        yy, xx = np.ogrid[y0:y1, x0:x1]
        w = np.exp(-((xx - x) ** 2 + (yy - y) ** 2) / (r * r)) * a
        frame[y0:y1, x0:x1] += np.asarray(col) * w[..., None]


def bats_2d(frame, T, n=12):
    rng = np.random.default_rng(11)
    H, W = frame.shape[:2]
    for i in range(n):
        x = (rng.random() * W + T * (120 + rng.random() * 200)) % (W + 200) - 100
        y = H * (0.15 + rng.random() * 0.5) + math.sin(T * 3 + i) * 20
        size = int(26 + rng.random() * 40)
        im = BATS[int((T * 14 + i) % len(BATS))].resize((size * 2, size), Image.LANCZOS)
        a = np.asarray(im).astype(np.float64) / 255.0
        # sagome chiare sul nero: si vedono contro il lampo
        h, w = a.shape[:2]
        x0, y0 = int(x - w / 2), int(y - h / 2)
        xa, ya, xb, yb = max(0, x0), max(0, y0), min(W, x0 + w), min(H, y0 + h)
        if xb > xa and yb > ya:
            wgt = a[ya - y0:yb - y0, xa - x0:xb - x0, 3:4]
            frame[ya:yb, xa:xb] = frame[ya:yb, xa:xb] * (1 - wgt) + np.array([0.12, 0.06, 0.16]) * wgt


def world_frame(folder, shot, T, theme):
    W, H = OUT_W, OUT_H
    key = get_key(folder, shot.key)
    fx = FX(key, shot, STATE["assets"])
    acc = None
    samples = [T] if shot.blur <= 1 else [T - i * 0.6 / FPS for i in range(shot.blur)]
    for Ts in samples:
        t = min(max(Ts / shot.dur, 0.0), 1.0)
        m = shot.cam(t)
        sh = (0.0, 0.0)
        if shot.shake:
            sh = (shot.shake * 0.12 * (math.sin(Ts * 37.0) + 0.6 * math.sin(Ts * 53.0 + 1.0)), shot.shake * 0.12 * math.sin(Ts * 41.0 + 2.0))
        for ft, strength, _ in shot.flashes:
            if Ts >= ft:
                k = math.exp(-(Ts - ft) * 6.0) * strength
                sh = (sh[0] + k * 0.5 * math.sin(Ts * 60), sh[1] + k * 0.5 * math.cos(Ts * 70))
        cam = key.camera(m, W, H, sh)
        img, zb = warp(key, cam, W, H)
        img = fx.apply(img, zb, cam, max(Ts, 0.0) / shot.dur, W, H)
        acc = img if acc is None else acc + img
    return acc / len(samples)


def image_frame(folder, shot, T):
    im = get_image(folder, shot.image)
    t = ease(T / shot.dur)
    z = shot.zoom[0] + (shot.zoom[1] - shot.zoom[0]) * t
    w, h = im.width / z, im.height / z
    cx = shot.focus[0] * im.width
    cy = shot.focus[1] * im.height
    x0 = min(max(cx - w / 2, 0), im.width - w)
    y0 = min(max(cy - h / 2, 0), im.height - h)
    out = im.transform((OUT_W, OUT_H), Image.EXTENT, (x0, y0, x0 + w, y0 + h), Image.BICUBIC)
    return np.asarray(out).astype(np.float64) / 255.0


def logo_layers(theme):
    """Gli elementi del finale: (immagine, posizione orizzontale y, posizione verticale y, comparsa in s)."""
    typo = STATE["typo"]
    if "logo" in STATE:
        return STATE["logo"]
    items = []
    if theme == "lancio":
        title = typo.line("SIERI PERDUTI", "GrenzeGotisch", 190, gradient=((255, 244, 205), (212, 150, 66)), stroke=8, stroke_fill=(44, 22, 10), glow=((255, 140, 50), 18))
        sub = typo.line("L'ARCIPELAGO DEI GIGANTI", "Merriweather", 50, fill=(245, 236, 220), spacing=0.18)
        play = typo.line("GIOCA ORA GRATIS SU ROBLOX", "GothamBlack", 54, fill=(255, 255, 255), stroke=3, stroke_fill=(70, 20, 10))
        code = typo.line("🎁 Codice regalo: SIERIPERDUTI", "GothamBold", 38, fill=GOLD, stroke=3, stroke_fill=(20, 12, 8))
        items = [(title, 0.36, 0.30, 0.3), (sub, 0.52, 0.42, 0.7), (button(play, (150, 40, 24), (255, 200, 110)), 0.68, 0.62, 1.3), (code, 0.8, 0.72, 1.7)]
    else:
        play = typo.line("🎃 ORA SU ROBLOX 🎃", "Creepster", 96, gradient=((255, 210, 90), (235, 90, 20)), stroke=5, stroke_fill=(30, 8, 40), glow=((120, 255, 80), 12))
        sub = typo.line("Aggiornamento di Halloween • solo per poco!", "GothamBold", 40, fill=(240, 228, 255), stroke=3, stroke_fill=(20, 8, 30))
        items = [(play, 0.86, 0.78, 1.2), (sub, 0.94, 0.85, 1.6)]
    STATE["logo"] = items
    return items


def button(text_im, fill, border):
    w, h = text_im.width + 80, text_im.height + 36
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([3, 3, w - 4, h - 4], radius=h // 2, fill=tuple(fill) + (235,), outline=tuple(border) + (255,), width=5)
    im.alpha_composite(text_im, ((w - text_im.width) // 2, (h - text_im.height) // 2))
    return im


def text_alpha(T, start, dur, fade=0.25):
    if T < start:
        return 0.0, 0.0
    a = min(1.0, (T - start) / fade)
    out = min(1.0, max(0.0, (dur - T) / fade))
    return a * out, 1 - ease_out((T - start) / 0.35)


def render_frame(args):
    theme, folder, fonts_dir, i = args
    assets(folder, fonts_dir)
    tl, total = STATE.setdefault("timeline", timeline(theme))
    T_abs = i / FPS
    shot, start = tl[-1]
    for s, st in tl:
        if st <= T_abs < st + s.dur:
            shot, start = s, st
            break
    T = T_abs - start
    if shot.key:
        img = world_frame(folder, shot, T, theme)
        img = grade(img, theme)
    elif shot.image:
        img = image_frame(folder, shot, T)
    else:
        img = np.zeros((OUT_H, OUT_W, 3))
        if theme == "halloween":
            img[:] = np.array([0.03, 0.01, 0.05])
            bats_2d(img, T)
        else:
            embers_2d(img, T, theme)
    if shot.dark:
        k = shot.dark * ease(min(1.0, T / 1.2))
        if k > 0:
            blurred = np.asarray(Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6 * k))).astype(np.float64) / 255
            img = blurred * (1 - k * 0.75)
    if shot.slash is not None and 0 <= T - shot.slash < 0.35:
        img = slash_fx(img, (T - shot.slash) / 0.35)
    for ft, strength, col in shot.flashes:
        if T >= ft:
            img = img + np.asarray(col) * strength * math.exp(-(T - ft) * 7.0)
    if shot.key:
        img = img * STATE["vignette"]
    if shot.fade_in and T < shot.fade_in:
        img = img * (T / shot.fade_in)
    if shot.fade_out and T > shot.dur - shot.fade_out:
        img = img * max(0.0, (shot.dur - T) / shot.fade_out)
    rng = np.random.default_rng(i)
    img = img + rng.normal(0, 0.012, (OUT_H, OUT_W, 1))
    img = np.clip(img, 0, 1)
    vert = vertical(img)
    texts(img, vert, shot, T, theme)
    return (np.clip(img, 0, 1) * 255).astype(np.uint8).tobytes(), (np.clip(vert, 0, 1) * 255).astype(np.uint8).tobytes()


def slash_fx(img, k):
    """Il colpo di lama: due archi bianchi che attraversano lo schermo e svaniscono."""
    layer = Image.new("L", (OUT_W, OUT_H), 0)
    d = ImageDraw.Draw(layer)
    reach = min(1.0, k * 2.5)
    for off, width in ((0, 26), (70, 12)):
        box = [-OUT_W * 0.3, OUT_H * 0.15 + off, OUT_W * 1.3, OUT_H * 1.9 + off]
        d.arc(box, 200, 200 + 140 * reach, fill=255, width=width)
    layer = layer.filter(ImageFilter.GaussianBlur(4))
    a = np.asarray(layer).astype(np.float64)[..., None] / 255.0 * (1 - k) ** 0.7
    return img * (1 - a) + np.array([1.0, 1.0, 0.98]) * a


def vertical(img):
    """Versione 1080x1920: il video al centro e sotto/sopra lo stesso video sfocato."""
    pil = Image.fromarray((img * 255).astype(np.uint8))
    bg = pil.resize((360, 203), Image.BILINEAR).crop((180 - 57, 0, 180 + 57, 203)).filter(ImageFilter.GaussianBlur(6)).resize((1080, 1920), Image.BILINEAR)
    bg = np.asarray(bg).astype(np.float64) / 255 * 0.42
    fg = pil.crop((240, 0, 1680, 1080)).resize((1080, 810), Image.LANCZOS)
    bg[555:1365] = np.asarray(fg).astype(np.float64) / 255
    return bg


def watermark(theme):
    if "marchio" not in STATE:
        typo = STATE["typo"]
        if theme == "halloween":
            im = typo.line("SIERI PERDUTI • HALLOWEEN", "Creepster", 64, gradient=((255, 210, 90), (235, 90, 20)), stroke=3, stroke_fill=(30, 8, 40))
        else:
            im = typo.line("SIERI PERDUTI", "GrenzeGotisch", 72, gradient=((255, 244, 205), (212, 150, 66)), stroke=4, stroke_fill=(44, 22, 10))
        sub = typo.line("Gioca gratis su Roblox", "GothamBold", 30, fill=(235, 230, 220), stroke=2, stroke_fill=(10, 8, 8))
        STATE["marchio"] = (im, sub)
    return STATE["marchio"]


def texts(img, vert, shot, T, theme):
    if not shot.logo:
        # nella versione verticale il nome del gioco resta sempre in basso
        mark, sub = watermark(theme)
        paste(vert, fit(mark, 900), 540, 1765, 0.92)
        paste(vert, sub, 540, 1840, 0.85)
    if shot.caption:
        center = shot.key is None and shot.image is None
        px = 62 if center else 56
        im = text_image(shot.caption, px, "c")
        a, slide = text_alpha(T, 0.25 if not center else 0.4, shot.dur - (0.05 if center else 0.0))
        if center:
            paste(img, fit(im, 1700), OUT_W / 2, OUT_H / 2 + slide * 20, a)
            paste(vert, fit(im, 1000), 540, 960 + slide * 20, a)
        else:
            paste(img, fit(im, 1700), OUT_W / 2, OUT_H * 0.84 + slide * 24, a)
            paste(vert, fit(im, 1000), 540, 1520 + slide * 24, a)
    if shot.title:
        start = shot.title[3] if len(shot.title) > 3 else (shot.flashes[-1][0] if shot.flashes and shot.name == "nuca" else 0.35)
        px = 96 if shot.title[1] != "Creepster" else 110
        im = text_image(shot.title, px, "t")
        a, slide = text_alpha(T, start, shot.dur, 0.15)
        scale = 1.0 + 0.25 * slide
        y = OUT_H * (0.5 if shot.image is None else 0.13)
        paste(img, fit(im, 1760), OUT_W / 2, y, a, scale)
        paste(vert, fit(im, 1020), 540, 330 if shot.image is None else 300, a, scale)
    if shot.logo:
        for im, yh, yv, at in logo_layers(theme):
            a, slide = text_alpha(T, at, shot.dur + 10, 0.4)
            paste(img, fit(im, 1700), OUT_W / 2, OUT_H * yh + slide * 30, a, 1.0 + 0.08 * slide)
            paste(vert, fit(im, 1000), 540, 1920 * yv + slide * 30, a, 1.0 + 0.08 * slide)


def cmd_edit(theme, folder, music, out_path, vert_path, fonts_dir, workers=4, only=None):
    tl, total = timeline(theme)
    n = int(round(total * FPS))
    frames = range(n) if only is None else range(int(only[0] * FPS), int(only[1] * FPS))

    def ffmpeg(path, w, h):
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (w, h), "-r", str(FPS), "-i", "-"]
        if music and only is None:
            cmd += ["-i", music, "-c:a", "aac", "-b:a", "192k", "-shortest"]
        cmd += ["-c:v", "libx264", "-preset", "medium", "-crf", "19", "-pix_fmt", "yuv420p", "-movflags", "+faststart", path]
        return subprocess.Popen(cmd, stdin=subprocess.PIPE)

    ph = ffmpeg(out_path, OUT_W, OUT_H)
    pv = ffmpeg(vert_path, 1080, 1920) if vert_path else None
    from multiprocessing import get_context
    with get_context("fork").Pool(workers) as pool:
        for k, (h, v) in enumerate(pool.imap(render_frame, [(theme, folder, fonts_dir, i) for i in frames], chunksize=2)):
            ph.stdin.write(h)
            if pv:
                pv.stdin.write(v)
            if k % 30 == 0:
                print("fotogramma %d/%d" % (k, len(frames)), flush=True)
    ph.stdin.close()
    ph.wait()
    if pv:
        pv.stdin.close()
        pv.wait()
    print("video:", out_path, vert_path or "")


# ---------------------------------------------------------------------------------------------
# Musica
# ---------------------------------------------------------------------------------------------


def _note(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def cmd_music(theme, path):
    from scipy.signal import butter, fftconvolve, sosfilt
    import wave
    tl, total = timeline(theme)
    S = {s.name: st for s, st in tl}
    N = int((total + 0.5) * SR)
    L = np.zeros(N)
    Rc = np.zeros(N)
    rng = np.random.default_rng(3 if theme == "halloween" else 1)

    def add(sig, at, gain=1.0, pan=0.0):
        i = int(at * SR)
        if i >= N or i < 0:
            return
        sig = sig[: N - i]
        L[i:i + len(sig)] += sig * gain * (1 - max(0, pan))
        Rc[i:i + len(sig)] += sig * gain * (1 + min(0, pan))

    def lp(x, f, order=2):
        return sosfilt(butter(order, min(f, SR * 0.45), "low", fs=SR, output="sos"), x)

    def bp(x, lo, hi):
        return sosfilt(butter(2, [lo, hi], "band", fs=SR, output="sos"), x)

    def saw(freq, dur, detune=0.0, phase=0.0):
        t = np.arange(int(dur * SR)) / SR
        return 2 * ((t * freq * (1 + detune) + phase) % 1.0) - 1

    def env(n, a, d=0.0, release=0.3):
        e = np.ones(n)
        ia = max(1, int(a * SR))
        e[:ia] = np.linspace(0, 1, ia)
        ir = max(1, int(release * SR))
        if n > ir:
            e[-ir:] *= np.linspace(1, 0, ir)
        return e * (np.exp(-np.arange(n) / SR / d) if d else 1)

    def taiko(at, gain=1.0, pitch=1.0):
        n = int(1.2 * SR)
        t = np.arange(n) / SR
        f = 88 * pitch * (1 + 1.5 * np.exp(-t * 30))
        body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 5)
        skin = bp(rng.normal(0, 1, n), 150, 1600) * np.exp(-t * 16)
        add(np.tanh((body + skin) * 1.5), at, gain)

    def braam(at, root=38, dur=3.0, gain=1.0):
        n = int(dur * SR)
        sig = np.zeros(n)
        for note, g in ((root, 1.0), (root + 12, 0.7), (root + 7, 0.5), (root + 19, 0.3)):
            for dt in (-0.006, 0.0, 0.007):
                sig += saw(_note(note), dur, dt, rng.random()) * g
        sig = np.tanh(sig * 0.6)
        out = np.zeros(n)
        blk = 2048
        for i in range(0, n, blk):
            fc = 200 + 2600 * np.exp(-((i / SR) - 0.15) ** 2 / 0.35)
            out[i:i + blk] = lp(sig[max(0, i - 4096):i + blk], fc)[-len(sig[i:i + blk]):]
        add(out * env(n, 0.02, dur * 0.5, 0.6) * 0.35, at, gain)

    def whoosh(at, dur=0.8, gain=0.5):
        n = int(dur * SR)
        noise = rng.normal(0, 1, n)
        out = np.zeros(n)
        blk = 1024
        for i in range(0, n, blk):
            fc = 300 + 4000 * i / n
            out[i:i + blk] = bp(noise[max(0, i - 2048):i + blk], fc * 0.6, fc * 1.4)[-len(noise[i:i + blk]):]
        add(out * np.sin(np.linspace(0, np.pi, n)) ** 2 * 0.5, at - dur, gain)

    def thunder(at, gain=0.8):
        n = int(3.0 * SR)
        t = np.arange(n) / SR
        x = lp(rng.normal(0, 1, n), 400) * (np.exp(-t * 1.2) + 0.6 * np.exp(-((t - 0.25) ** 2) / 0.02))
        crack = bp(rng.normal(0, 1, n), 800, 5000) * np.exp(-t * 25) * 0.4
        add(np.tanh(x * 3 + crack) * 0.6, at, gain, pan=rng.uniform(-0.4, 0.4))

    def pad(at, notes, dur, gain=0.25, cutoff=2600, attack=0.35):
        n = int(dur * SR)
        sig = np.zeros(n)
        for note in notes:
            for dt in (-0.004, 0.0, 0.005):
                sig += saw(_note(note), dur, dt, rng.random())
        add(lp(sig, cutoff) * env(n, attack, release=0.5) * gain / len(notes), at)

    def ostinato(at, dur, root=50, gain=0.22, rate=8, pattern=(0, 0, 12, 0, 7, 0, 10, 0)):
        step = 1.0 / rate
        k, x = 0, at
        while x < at + dur - 1e-6:
            note = root + pattern[k % len(pattern)]
            n = int(step * 0.95 * SR)
            s = (saw(_note(note), step * 0.95) + saw(_note(note), step * 0.95, 0.004)) * 0.5
            add(lp(s, 3400) * np.exp(-np.arange(n) / SR * 8), x, gain, pan=0.25 if k % 2 else -0.25)
            k += 1
            x += step

    def heartbeat(at, gain=0.7):
        for off, g in ((0.0, 1.0), (0.28, 0.7)):
            n = int(0.5 * SR)
            t = np.arange(n) / SR
            add(np.sin(2 * np.pi * 50 * t) * np.exp(-t * 9) * g, at + off, gain)

    def riser(at, dur, gain=0.35):
        n = int(dur * SR)
        t = np.arange(n) / SR
        sig = sum(np.sin(2 * np.pi * np.cumsum(f0 * (1 + t / dur)) / SR) for f0 in (220, 330, 440))
        noise = bp(rng.normal(0, 1, n), 1500, 8000)
        add((sig * 0.3 + noise * 0.25) * (t / dur) ** 2, at, gain)

    def bell(at, note, gain=0.25, dur=3.0):
        n = int(dur * SR)
        t = np.arange(n) / SR
        f = _note(note)
        sig = sum(np.sin(2 * np.pi * f * r * t) * a * np.exp(-t * d) for r, a, d in ((1, 1, 1.2), (2.76, 0.5, 2.0), (5.4, 0.25, 3.5), (8.9, 0.12, 5)))
        add(sig, at, gain, pan=rng.uniform(-0.3, 0.3))

    def musicbox(at, note, gain=0.18):
        n = int(1.4 * SR)
        t = np.arange(n) / SR
        f = _note(note)
        sig = (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 3 * t) * np.exp(-t * 6)) * np.exp(-t * 3.2)
        add(sig, at, gain, pan=0.2)

    def organ(at, notes, dur, gain=0.2):
        n = int(dur * SR)
        t = np.arange(n) / SR
        sig = np.zeros(n)
        for note in notes:
            f = _note(note)
            for r, a in ((0.5, 0.5), (1, 1.0), (2, 0.5), (3, 0.25), (4, 0.18)):
                sig += np.sin(2 * np.pi * f * r * t) * a
        sig *= (1 + 0.15 * np.sin(2 * np.pi * 5.5 * t))
        add(lp(sig, 3000) * env(n, 0.2, release=0.6) * gain / len(notes), at)

    if theme == "lancio":
        intro = S["mura"]
        wind = lp(rng.normal(0, 1, int(intro * SR)), 500) * 0.25
        add(wind * np.linspace(0, 1, len(wind)), 0.0)
        heartbeat(0.5)
        heartbeat(1.6)
        riser(intro - 1.4, 1.4)
        braam(S["mura"], 38, 3.2, 1.1)
        taiko(S["mura"], 1.2, 0.8)
        thunder(S["mura"] + 0.25)
        thunder(S["mura"] + 1.6, 0.6)
        braam(S["giganti"], 36, 3.2, 1.0)
        for b in range(7):
            taiko(S["giganti"] + b * 0.5, 0.9 if b % 2 == 0 else 0.5)
        pad(S["giganti"], [62, 65, 69], 5.5, 0.32)
        braam(S["volto"] + 1.85, 38, 1.2, 0.7)
        whoosh(S["tetti"], 0.9, 0.7)
        prog = [(50, [50, 53, 57]), (46, [46, 50, 53]), (41, [53, 57, 60]), (48, [48, 52, 55])]
        x, k, end = S["tetti"], 0, S["finale"]
        while x < end - 0.01:
            root, chord = prog[k % 4]
            d = min(2.0, end - x)
            ostinato(x, d, root + 12, 0.32)
            pad(x, [c + 12 for c in chord] + [chord[0] + 24], d, 0.4)
            for b in range(int(round(d / 0.5))):
                taiko(x + b * 0.5, 0.75 if b % 2 == 0 else 0.45, 1.0 if b % 2 == 0 else 1.4)
                if x > S["citta" if "citta" in S else "strada"]:
                    taiko(x + b * 0.5 + 0.25, 0.35, 1.6)
            k += 1
            x += 2.0
        for name in ("nuca", "isola", "strada", "colosso"):
            whoosh(S[name], 0.6, 0.5)
            braam(S[name], 38, 2.0, 0.6)
        braam(S["nuca"] + 2.0, 41, 1.5, 0.9)
        thunder(S["colosso"] + 0.1, 0.9)
        riser(S["finale"] - 1.5, 1.5, 0.45)
        braam(S["finale"], 38, 5.0, 1.2)
        taiko(S["finale"], 1.3, 0.8)
        pad(S["finale"], [62, 69, 74, 77], 5.5, 0.5)
    else:
        # Halloween: carillon stonato, organo, campane, battito e tamburi
        heartbeat(0.3, 0.6)
        heartbeat(1.2, 0.6)
        thunder(S["intro"] + 1.3, 1.0)
        melody = [69, 72, 76, 75, 72, 69, 68, 71, 74, 72, 69, 64]
        beat = 0.25
        x = 0.2
        for k in range(int((S["ev1"] - 0.2) / beat)):
            musicbox(x + k * beat, melody[k % len(melody)] + 12, 0.16)
        braam(S["mura"], 37, 3.4, 1.0)
        taiko(S["mura"], 1.2, 0.8)
        bell(S["mura"], 57, 0.4, 4)
        organ(S["mura"], [45, 52, 57, 60], 3.5, 0.28)
        prog = [[45, 52, 57, 60], [41, 48, 53, 57], [43, 50, 55, 59], [40, 47, 52, 56]]
        x, k, end = S["case_notte"], 0, S["finale"]
        while x < end - 0.01:
            d = min(2.0, end - x)
            organ(x, prog[k % 4], d, 0.24)
            ostinato(x, d, prog[k % 4][0] + 12, 0.2, 8, (0, 12, 7, 12, 3, 12, 7, 12))
            for b in range(int(round(d / 0.5))):
                taiko(x + b * 0.5, 0.7 if b % 2 == 0 else 0.4, 1.0 if b % 2 == 0 else 1.3)
            if x >= S["ev1"] - 0.01:
                for b in range(int(round(d / 0.25))):
                    taiko(x + b * 0.25 + 0.125, 0.25, 1.8)
            k += 1
            x += 2.0
        for name in ("giganti", "zucca", "ev1", "ev2", "ev3", "ev4", "ev5", "premi", "campo_notte"):
            whoosh(S[name], 0.6, 0.45)
            bell(S[name], 57 + (hash(name) % 5), 0.25)
        braam(S["zucca"], 36, 2.5, 0.9)
        riser(S["finale"] - 1.5, 1.5, 0.45)
        braam(S["finale"], 37, 5.0, 1.1)
        bell(S["finale"], 45, 0.6, 5)
        organ(S["finale"], [45, 52, 57, 60, 64], 5.5, 0.35)
        thunder(S["finale"] + 0.1, 0.8)
    ir_n = int(2.2 * SR)
    ir = rng.normal(0, 1, ir_n) * np.exp(-np.arange(ir_n) / SR * 2.5)
    ir /= np.sqrt(np.sum(ir ** 2))
    wet = 0.35 if theme == "lancio" else 0.5
    Lw = L + fftconvolve(L, ir)[:N] * wet
    Rw = Rc + fftconvolve(Rc, ir[::-1].copy())[:N] * wet
    out = np.stack([Lw, Rw], -1)[: int(total * SR)]
    hp = butter(2, 35, "high", fs=SR, output="sos")
    low = butter(2, 140, "low", fs=SR, output="sos")
    for ch in range(2):
        x = sosfilt(hp, out[:, ch])
        out[:, ch] = x - 0.45 * sosfilt(low, x)
    fade = int(1.2 * SR)
    out[-fade:] *= np.linspace(1, 0, fade)[:, None]
    out = np.tanh(out / np.max(np.abs(out)) * 1.3) * 0.89
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((out * 32767).astype("<i2").tobytes())
    print("musica:", path, round(total, 1), "s")


def main():
    args = sys.argv[1:]
    if len(args) < 3:
        print(__doc__)
        sys.exit(1)
    workers = 3
    fonts_dir = None
    only = None
    for flag in ("--processi", "--caratteri", "--solo"):
        if flag in args:
            i = args.index(flag)
            value = args[i + 1]
            del args[i:i + 2]
            if flag == "--processi":
                workers = int(value)
            elif flag == "--caratteri":
                fonts_dir = value
            else:
                only = tuple(float(v) for v in value.split(","))
    cmd, theme = args[0], args[1]
    if theme not in KEYS:
        sys.exit("trailer sconosciuto: " + theme)
    if cmd == "chiavi":
        cmd_keys(theme, args[2], args[3:], workers)
        if not args[3:] or "cadetto" in args[3:]:
            cmd_sprites(args[2])
    elif cmd == "menu":
        cmd_menus(theme, args[2], fonts_dir)
    elif cmd == "musica":
        cmd_music(theme, args[2])
    elif cmd == "monta":
        cmd_edit(theme, args[2], args[3] if len(args) > 3 else None, args[4] if len(args) > 4 else "trailer.mp4",
                 args[5] if len(args) > 5 else None, fonts_dir, workers, only)
    else:
        sys.exit("comando sconosciuto: " + cmd)


if __name__ == "__main__":
    main()
