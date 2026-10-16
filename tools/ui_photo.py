#!/usr/bin/env python3
"""Foto dei menu del gioco senza Roblox Studio.

Costruisce l'interfaccia con il codice vero del gioco nel Roblox finto delle prove
(tools/tests/ui_dump.luau) e la disegna: riquadri con angoli tondi, sfumature (UIGradient), bordi (UIStroke),
liste e griglie (UIListLayout, UIGridLayout), proporzioni, scale, rotazioni e testi (anche TextScaled ed emoji).

  python3 tools/ui_photo.py <cartella uscita> [schermata ...] [--halloween] [--sfondo foto.png] [--larghezza 1280]
                            [--caratteri cartella] [--evento Id]

Schermate: titolo (schermata iniziale), admin (pannello Admin Abuse), admin_programma (la parte
"Programma un evento" dello stesso pannello), evento (titolo dell'evento a tutto schermo), striscione
(lo striscione in alto con il conto alla rovescia). Senza nomi le fa tutte.
--sfondo mette sotto ai menu una foto (es. una foto di tools/world_photo.py).
--caratteri: cartella con i caratteri dei pacchetti npm @fontsource (creepster, montserrat, merriweather,
grenze-gotisch: file *-latin-<peso>-normal.woff, anche in sottocartelle). Senza, usa DejaVu.
Le emoji usano Noto Color Emoji (se c'è). Serve il programma 'luau' (variabile LUAU o nel PATH).
"""
import argparse
import glob
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SCENES = ("titolo", "admin", "admin_programma", "evento", "striscione")
EMOJI_FONT = "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf"
DEJAVU = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
DEJAVU_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

# carattere di Roblox -> (famiglia @fontsource, peso, ripiego DejaVu)
FONT_MAP = {
    "Creepster": ("creepster", 400, DEJAVU_BOLD),
    "GothamBlack": ("montserrat", 900, DEJAVU_BOLD),
    "GothamBold": ("montserrat", 700, DEJAVU_BOLD),
    "GothamMedium": ("montserrat", 500, DEJAVU),
    "Gotham": ("montserrat", 400, DEJAVU),
    "Merriweather": ("merriweather", 400, DEJAVU),
    "GrenzeGotisch": ("grenze-gotisch", 600, DEJAVU_BOLD),
    "Oswald": ("montserrat", 600, DEJAVU_BOLD),
    "SourceSansBold": ("montserrat", 700, DEJAVU_BOLD),
}

# ---------------------------------------------------------------------------------------------
# Esportazione (Luau + Roblox finto)
# ---------------------------------------------------------------------------------------------


def long_string(text):
    level = 1
    while ("]" + "=" * level + "]") in text:
        level += 1
    return "[" + "=" * level + "[\n" + text + "]" + "=" * level + "]"


def dump(scene, tema=None, event=None, src_root=None):
    src_root = src_root or os.path.join(ROOT, "src")
    sources = []
    for prefix, folder in (("Shared", os.path.join(src_root, "shared")), ("Client", os.path.join(src_root, "client"))):
        for base, _, names in os.walk(folder):
            for n in sorted(names):
                if n.endswith(".lua"):
                    rel = os.path.relpath(os.path.join(base, n), folder)[:-4].replace(os.sep, "/")
                    sources.append('\t["%s/%s"] = %s,' % (prefix, rel, long_string(open(os.path.join(base, n), encoding="utf-8").read())))
    bundle = "SOURCES_TABLE = {\n" + "\n".join(sources) + "\n}\n"
    for name in ("roblox_api.luau", "roblox_mock.luau"):
        bundle += open(os.path.join(ROOT, "tools", "tests", name), encoding="utf-8").read() + "\n"
    if tema:
        bundle += 'game:GetService("ReplicatedStorage"):SetAttribute("Tema", "%s")\n' % tema
    bundle += "UI_SCENE = %s\n" % long_string(scene).replace("\n", "", 1)
    if event:
        bundle += "UI_EVENT = %s\n" % long_string(event).replace("\n", "", 1)
    bundle += "do\n" + open(os.path.join(ROOT, "tools", "tests", "ui_dump.luau"), encoding="utf-8").read() + "\nend\n"
    luau = os.environ.get("LUAU") or shutil.which("luau")
    if not luau:
        sys.exit("Interprete 'luau' non trovato")
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as f:
        f.write(bundle)
        tmp = f.name
    proc = subprocess.run([luau, tmp], capture_output=True, text=True)
    os.unlink(tmp)
    if proc.returncode != 0 or "FINE\t" not in proc.stdout:
        sys.exit("Esportazione dell'interfaccia fallita:\n" + (proc.stdout[-3000:] + proc.stderr[-3000:]))
    for line in proc.stdout.splitlines():
        if line.startswith("ERRORE"):
            print("  " + line)
    return proc.stdout


# ---------------------------------------------------------------------------------------------
# Lettura
# ---------------------------------------------------------------------------------------------


class Node:
    def __init__(self):
        self.children = []
        self.text = None
        self.corner = None
        self.gradient = None
        self.stroke = None
        self.aspect = None
        self.scale = 1.0
        self.list = None
        self.grid = None
        self.pad = (0.0, 0.0, 0.0, 0.0)
        self.max_text = None
        self.scroll = 0.0
        self.rect = (0.0, 0.0, 0.0, 0.0)
        self.T = (1.0, 0.0, 0.0)


def floats(seq):
    return tuple(float(v) for v in seq)


def keys(text, color):
    out = []
    for item in text.split(","):
        if not item:
            continue
        v = floats(item.split(":"))
        out.append((v[0], v[1:4]) if color else (v[0], v[1]))
    return out


def parse(text):
    nodes, roots = {}, []
    size = (1920, 1080)
    for line in text.splitlines():
        f = line.split("\t")
        k = f[0]
        if k == "O" and len(f) >= 25:
            n = Node()
            n.id, n.parent, n.cls, n.name = int(f[1]), int(f[2]), f[3], f[4]
            n.visible = f[5] == "true"
            n.z, n.order = int(float(f[6])), int(float(f[7]))
            n.pos, n.size = floats(f[8:12]), floats(f[12:16])
            n.anchor, n.rot = floats(f[16:18]), float(f[18])
            n.bg, n.bgT = floats(f[19:22]), float(f[22])
            n.clip, n.auto = f[23] == "true", f[24]
            nodes[n.id] = n
            (nodes[n.parent].children if n.parent in nodes else roots).append(n)
        elif k == "T":
            nodes[int(f[1])].text = {
                "text": f[2].replace("\\n", "\n"), "font": f[3], "size": float(f[4]), "scaled": f[5] == "true",
                "color": floats(f[6:9]), "alpha": 1 - float(f[9]), "xa": f[10], "ya": f[11], "wrapped": f[12] == "true",
                "stroke": floats(f[13:16]), "stroke_alpha": 1 - float(f[16]),
            }
        elif k == "C":
            nodes[int(f[1])].corner = floats(f[2:4])
        elif k == "G":
            nodes[int(f[1])].gradient = {"rot": float(f[2]), "off": floats(f[3:5]), "color": keys(f[5], True), "alpha": keys(f[6] if len(f) > 6 else "", False)}
        elif k == "S":
            nodes[int(f[1])].stroke = {"color": floats(f[2:5]), "thick": float(f[5]), "alpha": 1 - float(f[6]), "mode": f[7]}
        elif k == "A":
            nodes[int(f[1])].aspect = float(f[2])
        elif k == "K":
            nodes[int(f[1])].scale = float(f[2])
        elif k == "L":
            nodes[int(f[1])].list = {"dir": f[2], "pad": floats(f[3:5]), "ha": f[5], "va": f[6]}
        elif k == "R":
            nodes[int(f[1])].grid = {"cell": floats(f[2:6]), "pad": floats(f[6:10])}
        elif k == "P":
            nodes[int(f[1])].pad = floats(f[2:6])  # sopra, sotto, sinistra, destra
        elif k == "M":
            nodes[int(f[1])].max_text = float(f[2])
        elif k == "FINE":
            size = (int(f[2]), int(f[3]))
    return roots, nodes, size


# ---------------------------------------------------------------------------------------------
# Caratteri ed emoji
# ---------------------------------------------------------------------------------------------


class Fonts:
    def __init__(self, folder):
        self.files = {}
        if folder:
            for path in glob.glob(os.path.join(folder, "**", "*-latin-*-normal.woff"), recursive=True):
                m = re.match(r"(.+)-latin-(\d+)-normal\.woff$", os.path.basename(path))
                if m:
                    self.files[(m.group(1), int(m.group(2)))] = path
        self.cache = {}
        self.notdef = {}
        self.has = {}
        self.emoji = ImageFont.truetype(EMOJI_FONT, 109) if os.path.exists(EMOJI_FONT) else None
        self.emoji_cache = {}

    def path(self, name):
        family, weight, fallback = FONT_MAP.get(name, ("montserrat", 400, DEJAVU))
        best = None
        for (fam, w), p in self.files.items():
            if fam == family and (best is None or abs(w - weight) < abs(best[0] - weight)):
                best = (w, p)
        return best[1] if best else fallback

    def get(self, name, px):
        return self.get_path(self.path(name), px)

    def get_path(self, path, px):
        key = (path, round(px * 4) / 4)
        if key not in self.cache:
            self.cache[key] = ImageFont.truetype(path, max(1.0, key[1]))
        return self.cache[key]

    def has_glyph(self, path, ch):
        key = (path, ch)
        if key not in self.has:
            font = self.get_path(path, 32)

            def signature(c):
                img = Image.new("L", (64, 64), 0)
                ImageDraw.Draw(img).text((8, 8), c, font=font, fill=255)
                return img.tobytes() if img.getbbox() else None

            if path not in self.notdef:
                self.notdef[path] = signature(chr(0xE000))
            sig = signature(ch)
            self.has[key] = ch.isspace() or (sig is not None and sig != self.notdef[path])
        return self.has[key]

    def emoji_image(self, ch):
        if ch not in self.emoji_cache:
            img = None
            if self.emoji is not None:
                layer = Image.new("RGBA", (160, 160), (0, 0, 0, 0))
                ImageDraw.Draw(layer).text((8, 8), ch, font=self.emoji, embedded_color=True)
                box = layer.getbbox()
                if box and (box[2] - box[0]) > 20:
                    img = layer.crop(box)
            self.emoji_cache[ch] = img
        return self.emoji_cache[ch]


def is_emoji(cp):
    return 0x1F000 <= cp <= 0x1FAFF or 0x2600 <= cp <= 0x27BF or 0x2300 <= cp <= 0x23FF or 0x2B00 <= cp <= 0x2BFF or cp in (0x3030, 0x303D, 0x3297, 0x3299)


def runs(fonts, text, name):
    """Divide il testo in pezzi: ('t', testo, carattere) oppure ('e', emoji, None)."""
    main = fonts.path(name)
    out = []
    for ch in text:
        cp = ord(ch)
        if cp in (0xFE0F, 0xFE0E, 0x200D):
            continue
        if is_emoji(cp) and fonts.emoji_image(ch) is not None:
            out.append(("e", ch, None))
            continue
        path = main if fonts.has_glyph(main, ch) else (DEJAVU_BOLD if "Bold" in name or "Black" in name else DEJAVU)
        if out and out[-1][0] == "t" and out[-1][2] == path:
            out[-1] = ("t", out[-1][1] + ch, path)
        else:
            out.append(("t", ch, path))
    return out


def line_width(fonts, line, name, px):
    w = 0.0
    for kind, s, path in runs(fonts, line, name):
        if kind == "e":
            img = fonts.emoji_image(s)
            w += px * 1.08 * img.width / img.height + px * 0.08
        else:
            w += fonts.get_path(path, px).getlength(s)
    return w


def wrap(fonts, text, name, px, width):
    lines = []
    for para in text.split("\n"):
        words = para.split(" ")
        current = ""
        for word in words:
            trial = word if current == "" else current + " " + word
            if current != "" and line_width(fonts, trial, name, px) > width:
                lines.append(current)
                current = word
            else:
                current = trial
        lines.append(current)
    return lines


def fit_text(fonts, t, w, h):
    """Dimensione del testo (TextScaled cerca la più grande che ci sta, come Roblox) e righe."""
    if t["scaled"]:
        lo, hi = 1, int(min(100, t.get("max") or 100))
        best = 1
        while lo <= hi:
            mid = (lo + hi) // 2
            lines = wrap(fonts, t["text"], t["font"], mid, w)
            if len(lines) * mid <= h + 0.5 and all(line_width(fonts, ln, t["font"], mid) <= w + 0.5 for ln in lines):
                best, lo = mid, mid + 1
            else:
                hi = mid - 1
        return best, wrap(fonts, t["text"], t["font"], best, w)
    px = t["size"]
    if t["max"] is not None:
        px = min(px, t["max"])
    if t["wrapped"]:
        return px, wrap(fonts, t["text"], t["font"], px, w)
    return px, t["text"].split("\n")


# ---------------------------------------------------------------------------------------------
# Disposizione (come Roblox: UDim2, AnchorPoint, liste, griglie, AutomaticSize, UIScale)
# ---------------------------------------------------------------------------------------------


class Layout:
    def __init__(self, fonts):
        self.fonts = fonts

    def gui_children(self, n):
        return [c for c in n.children if c.visible and c.cls != "ScreenGui"]

    def content(self, n, x, y, w, h):
        top, bottom, left, right = n.pad
        return x + left, y + top, max(0.0, w - left - right), max(0.0, h - top - bottom)

    def text_bounds(self, n, w):
        t = n.text
        t["max"] = n.max_text
        px, lines = fit_text(self.fonts, t, w if t["wrapped"] or t["scaled"] else 1e9, 1e9)
        width = max((line_width(self.fonts, ln, t["font"], px) for ln in lines), default=0)
        return width, len(lines) * px

    def base_size(self, n, cw, ch):
        w = cw * n.size[0] + n.size[1]
        h = ch * n.size[2] + n.size[3]
        if n.aspect:
            # AspectType FitWithinMaxSize: si rimpicciolisce per stare dentro mantenendo le proporzioni
            if h > 0 and w / h > n.aspect:
                w = h * n.aspect
            else:
                h = w / n.aspect if n.aspect else h
        return max(0.0, w), max(0.0, h)

    def size_of(self, n, cw, ch):
        w, h = self.base_size(n, cw, ch)
        if n.auto in ("X", "Y", "XY"):
            ew, eh = self.extent(n, w, h)
            if "X" in n.auto:
                w = max(w, ew)
            if "Y" in n.auto:
                h = max(h, eh)
        return w, h

    def extent(self, n, w, h):
        top, bottom, left, right = n.pad
        _, _, iw, ih = self.content(n, 0, 0, w, h)
        ew = eh = 0.0
        if n.text is not None:
            tw, th = self.text_bounds(n, iw)
            ew, eh = tw, th
        kids = self.gui_children(n)
        if n.list and kids:
            sizes = [self.size_of(c, iw, ih) for c in kids]
            vertical = n.list["dir"] == "Vertical"
            gap = n.list["pad"][0] * (ih if vertical else iw) + n.list["pad"][1]
            if vertical:
                eh = max(eh, sum(s[1] for s in sizes) + gap * (len(sizes) - 1))
                ew = max(ew, max(s[0] for s in sizes))
            else:
                ew = max(ew, sum(s[0] for s in sizes) + gap * (len(sizes) - 1))
                eh = max(eh, max(s[1] for s in sizes))
        elif n.grid and kids:
            cell, gpad = n.grid["cell"], n.grid["pad"]
            cw_, ch_ = iw * cell[0] + cell[1], ih * cell[2] + cell[3]
            px_, py_ = iw * gpad[0] + gpad[1], ih * gpad[2] + gpad[3]
            per_row = max(1, int((iw + px_) // (cw_ + px_))) if cw_ + px_ > 0 else 1
            rows = math.ceil(len(kids) / per_row)
            eh = max(eh, rows * ch_ + (rows - 1) * py_)
            ew = max(ew, min(len(kids), per_row) * (cw_ + px_) - px_)
        else:
            for c in kids:
                cw_, ch_ = self.size_of(c, iw, ih)
                ew = max(ew, iw * c.pos[0] + c.pos[1] + cw_ * (1 - c.anchor[0]))
                eh = max(eh, ih * c.pos[2] + c.pos[3] + ch_ * (1 - c.anchor[1]))
        return ew + left + right, eh + top + bottom

    def place(self, n, x, y, w, h, T):
        n.rect = (x, y, w, h)
        if n.scale != 1.0:
            s, tx, ty = T
            ax, ay = x + n.anchor[0] * w, y + n.anchor[1] * h
            k = n.scale
            T = (s * k, tx + s * ax * (1 - k), ty + s * ay * (1 - k))
        n.T = T
        cx, cy, cw, ch = self.content(n, x, y, w, h)
        cy -= n.scroll
        kids = self.gui_children(n)
        if n.list:
            kids = sorted(kids, key=lambda c: c.order)
            vertical = n.list["dir"] == "Vertical"
            gap = n.list["pad"][0] * (ch if vertical else cw) + n.list["pad"][1]
            sizes = [self.size_of(c, cw, ch) for c in kids]
            total = sum(s[1] if vertical else s[0] for s in sizes) + gap * max(0, len(kids) - 1)
            main_align = n.list["va"] if vertical else n.list["ha"]
            free = (ch if vertical else cw) - total
            cursor = {"Top": 0, "Left": 0, "Center": free / 2, "Bottom": free, "Right": free}.get(main_align, 0)
            cross = n.list["ha"] if vertical else n.list["va"]
            for c, (sw, sh) in zip(kids, sizes):
                if vertical:
                    off = {"Center": (cw - sw) / 2, "Right": cw - sw}.get(cross, 0)
                    self.place(c, cx + off, cy + cursor, sw, sh, T)
                    cursor += sh + gap
                else:
                    off = {"Center": (ch - sh) / 2, "Bottom": ch - sh}.get(cross, 0)
                    self.place(c, cx + cursor, cy + off, sw, sh, T)
                    cursor += sw + gap
        elif n.grid:
            kids = sorted(kids, key=lambda c: c.order)
            cell, gpad = n.grid["cell"], n.grid["pad"]
            gw, gh = cw * cell[0] + cell[1], ch * cell[2] + cell[3]
            px_, py_ = cw * gpad[0] + gpad[1], ch * gpad[2] + gpad[3]
            per_row = max(1, int((cw + px_) // (gw + px_))) if gw + px_ > 0 else 1
            for i, c in enumerate(kids):
                r, col = divmod(i, per_row)
                self.place(c, cx + col * (gw + px_), cy + r * (gh + py_), gw, gh, T)
        else:
            for c in kids:
                sw, sh = self.size_of(c, cw, ch)
                px_ = cx + cw * c.pos[0] + c.pos[1] - c.anchor[0] * sw
                py_ = cy + ch * c.pos[2] + c.pos[3] - c.anchor[1] * sh
                self.place(c, px_, py_, sw, sh, T)


def screen_rect(n):
    s, tx, ty = n.T
    x, y, w, h = n.rect
    return (s * x + tx, s * y + ty, s * w, s * h)


# ---------------------------------------------------------------------------------------------
# Disegno
# ---------------------------------------------------------------------------------------------


class Painter:
    def __init__(self, fonts):
        self.fonts = fonts
        self.masks = {}

    def rrect(self, w, h, r):
        key = (w, h, round(r, 1))
        if key not in self.masks:
            if r <= 0.5:
                mask = Image.new("L", (w, h), 255)
            else:
                ss = 3 if w * h < 600000 else 2
                big = Image.new("L", (w * ss, h * ss), 0)
                ImageDraw.Draw(big).rounded_rectangle([0, 0, w * ss - 1, h * ss - 1], radius=r * ss, fill=255)
                mask = big.resize((w, h), Image.LANCZOS)
            if len(self.masks) > 400:
                self.masks.clear()
            self.masks[key] = mask
        return self.masks[key]

    def radius(self, n, w, h):
        if not n.corner:
            return 0.0
        s = n.T[0]
        return min(min(w, h) / 2, min(w, h) * n.corner[0] + n.corner[1] * s)

    def gradient_maps(self, g, w, h):
        """Colore (RGB) e trasparenza (L) della sfumatura sull'oggetto."""
        theta = math.radians(g["rot"])
        c, s = math.cos(theta), math.sin(theta)
        # proiezione sulla direzione della sfumatura (0 = sinistra, 1 = destra per Rotation 0)
        n = 64
        lut_rgb, lut_a = [], []
        for i in range(n + 1):
            t = i / n
            lut_rgb.append(sample(g["color"], t, True))
            lut_a.append(1 - sample(g["alpha"], t, False) if g["alpha"] else 1.0)
        gw, gh = max(1, min(w, 256)), max(1, min(h, 256))
        rgb = Image.new("RGB", (gw, gh))
        al = Image.new("L", (gw, gh))
        prgb, pal = rgb.load(), al.load()
        span = abs(c) * 0.5 + abs(s) * 0.5
        for yy in range(gh):
            v = (yy + 0.5) / gh - 0.5
            for xx in range(gw):
                u = (xx + 0.5) / gw - 0.5
                t = (u * c + v * s) / (2 * span) + 0.5 - (g["off"][0] * c + g["off"][1] * s)
                t = min(1.0, max(0.0, t))
                i = int(t * n + 0.5)
                col = lut_rgb[i]
                prgb[xx, yy] = (int(col[0] * 255), int(col[1] * 255), int(col[2] * 255))
                pal[xx, yy] = int(lut_a[i] * 255)
        return rgb.resize((w, h), Image.BILINEAR), al.resize((w, h), Image.BILINEAR)

    def draw_text(self, layer, n, ox, oy, w, h, s):
        t = n.text
        if not t["text"] or t["alpha"] <= 0.01:
            return None
        t["max"] = n.max_text
        lw, lh = n.rect[2], n.rect[3]
        px, lines = fit_text(self.fonts, t, lw, lh)
        px_s = px * s
        if px_s < 3:
            return None
        stroke = n.stroke if (n.stroke and n.stroke["mode"] == "Contextual") else None
        text_stroke = t["stroke_alpha"] > 0.01
        block = len(lines) * px_s
        if t["ya"] == "Top":
            y0 = 0.0
        elif t["ya"] == "Bottom":
            y0 = h - block
        else:
            y0 = (h - block) / 2
        draw = ImageDraw.Draw(layer)
        under = Image.new("RGBA", layer.size, (0, 0, 0, 0)) if (stroke or text_stroke) else None
        udraw = ImageDraw.Draw(under) if under is not None else None
        col = tuple(int(v * 255) for v in t["color"]) + (int(t["alpha"] * 255),)
        for i, line in enumerate(lines):
            width = line_width(self.fonts, line, t["font"], px_s)
            if t["xa"] == "Left":
                x = 0.0
            elif t["xa"] == "Right":
                x = w - width
            else:
                x = (w - width) / 2
            top = y0 + i * px_s
            for kind, seg, path in runs(self.fonts, line, t["font"]):
                if kind == "e":
                    img = self.fonts.emoji_image(seg)
                    eh = max(1, int(round(px_s * 1.08)))
                    ew = max(1, int(round(eh * img.width / img.height)))
                    em = img.resize((ew, eh), Image.LANCZOS)
                    if t["alpha"] < 0.99:
                        a = em.getchannel("A").point(lambda v: int(v * t["alpha"]))
                        em.putalpha(a)
                    layer.alpha_composite(em, (int(round(ox + x)), int(round(oy + top + (px_s - eh) / 2))))
                    x += ew + px_s * 0.08
                    continue
                font = self.fonts.get_path(path, px_s)
                ascent, descent = font.getmetrics()
                ty = oy + top + (px_s - (ascent + descent)) / 2
                if udraw is not None:
                    if stroke:
                        sw = max(1, int(round(stroke["thick"] * s)))
                        sc = tuple(int(v * 255) for v in stroke["color"]) + (int(stroke["alpha"] * t["alpha"] * 255),)
                        udraw.text((ox + x, ty), seg, font=font, fill=sc, stroke_width=sw, stroke_fill=sc)
                    elif text_stroke:
                        sw = max(1, int(round(px_s / 16)))
                        sc = tuple(int(v * 255) for v in t["stroke"]) + (int(t["stroke_alpha"] * t["alpha"] * 255),)
                        udraw.text((ox + x, ty), seg, font=font, fill=sc, stroke_width=sw, stroke_fill=sc)
                draw.text((ox + x, ty), seg, font=font, fill=col)
                x += font.getlength(seg)
        return under

    def draw_node(self, canvas, n, clip, offset=(0, 0)):
        sx, sy, sw, sh = screen_rect(n)
        sx -= offset[0]
        sy -= offset[1]
        w, h = int(round(sw)), int(round(sh))
        has_bg = n.bgT < 0.99 and w > 0 and h > 0
        has_text = n.text is not None and n.text["text"] != ""
        border = n.stroke if (n.stroke and (n.stroke["mode"] == "Border" or n.text is None) and n.stroke["alpha"] > 0.01) else None
        if not (has_bg or has_text or border) or w <= 0 or h <= 0:
            return
        s = n.T[0]
        margin = int(math.ceil((border["thick"] * s) if border else 0)) + 2
        if has_text:
            # il testo può uscire dal riquadro (come in Roblox se non va a capo): spazio intorno
            t = n.text
            t["max"] = n.max_text
            px, lines = fit_text(self.fonts, t, n.rect[2], n.rect[3])
            widest = max((line_width(self.fonts, ln, t["font"], px) for ln in lines), default=0) * s
            margin = max(margin, int(h * 0.6) + 4, 24, int(widest - w) + 12, int(len(lines) * px * s - h) + 12)
        lx, ly = int(round(sx)) - margin, int(round(sy)) - margin
        layer = Image.new("RGBA", (w + 2 * margin, h + 2 * margin), (0, 0, 0, 0))
        r = self.radius(n, sw, sh)
        if has_bg:
            fill = Image.new("RGBA", (w, h), tuple(int(v * 255) for v in n.bg) + (255,))
            mask = self.rrect(w, h, r)
            alpha = 1 - n.bgT
            fill.putalpha(mask.point(lambda v: int(v * alpha)) if alpha < 0.999 else mask)
            layer.alpha_composite(fill, (margin, margin))
        under = None
        if has_text:
            under = self.draw_text(layer, n, margin, margin, w, h, s)
        if n.gradient:
            grgb, galpha = self.gradient_maps(n.gradient, w, h)
            full_rgb = Image.new("RGB", layer.size, (255, 255, 255))
            full_rgb.paste(grgb, (margin, margin))
            # fuori dal riquadro (testo che sporge) vale il colore del bordo più vicino: basta estendere
            full_a = Image.new("L", layer.size, 255)
            full_a.paste(galpha, (margin, margin))
            rgb = ImageChops.multiply(layer.convert("RGB"), full_rgb)
            a = ImageChops.multiply(layer.getchannel("A"), full_a)
            layer = rgb.convert("RGBA")
            layer.putalpha(a)
        if under is not None:
            under.alpha_composite(layer)
            layer = under
        if border:
            t = max(1, int(round(border["thick"] * s)))
            outer = self.rrect(w + 2 * t, h + 2 * t, r + t if r > 0 else 0)
            inner = Image.new("L", outer.size, 0)
            inner.paste(self.rrect(w, h, r), (t, t))
            ring = ImageChops.subtract(outer, inner)
            col = Image.new("RGBA", ring.size, tuple(int(v * 255) for v in border["color"]) + (255,))
            col.putalpha(ring.point(lambda v: int(v * border["alpha"])))
            layer.alpha_composite(col, (margin - t, margin - t))
        self.composite(canvas, layer, lx, ly, clip, offset)

    def composite(self, canvas, layer, lx, ly, clip, offset):
        cx0, cy0, cx1, cy1 = 0, 0, canvas.width, canvas.height
        if clip is not None:
            cx0 = max(cx0, int(math.floor(clip[0] - offset[0])))
            cy0 = max(cy0, int(math.floor(clip[1] - offset[1])))
            cx1 = min(cx1, int(math.ceil(clip[2] - offset[0])))
            cy1 = min(cy1, int(math.ceil(clip[3] - offset[1])))
        x0, y0 = max(lx, cx0), max(ly, cy0)
        x1, y1 = min(lx + layer.width, cx1), min(ly + layer.height, cy1)
        if x1 <= x0 or y1 <= y0:
            return
        part = layer.crop((x0 - lx, y0 - ly, x1 - lx, y1 - ly))
        canvas.alpha_composite(part, (x0, y0))

    def subtree_box(self, n):
        x, y, w, h = screen_rect(n)
        box = [x, y, x + w, y + h]
        for c in n.children:
            if c.visible:
                b = self.subtree_box(c)
                box = [min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3])]
        return box

    def paint(self, canvas, n, clip=None, offset=(0, 0), rotated=False):
        if not n.visible:
            return
        if n.rot % 360 != 0 and not rotated:
            x, y, w, h = screen_rect(n)
            cxs, cys = x + w / 2, y + h / 2
            box = self.subtree_box(n)
            rad = max(math.hypot(box[0] - cxs, box[1] - cys), math.hypot(box[2] - cxs, box[3] - cys),
                      math.hypot(box[0] - cxs, box[3] - cys), math.hypot(box[2] - cxs, box[1] - cys)) + 30
            side = int(math.ceil(rad * 2))
            if side > 6000:
                return
            org = (cxs - side / 2, cys - side / 2)
            layer = Image.new("RGBA", (side, side), (0, 0, 0, 0))
            self.paint(layer, n, None, (offset[0] + org[0], offset[1] + org[1]), True)
            layer = layer.rotate(-n.rot, resample=Image.BICUBIC, center=(side / 2, side / 2))
            self.composite(canvas, layer, int(round(org[0] - offset[0])), int(round(org[1] - offset[1])), clip, offset)
            return
        self.draw_node(canvas, n, clip, offset)
        child_clip = clip
        if n.clip:
            x, y, w, h = screen_rect(n)
            r = (x, y, x + w, y + h)
            child_clip = r if clip is None else (max(clip[0], r[0]), max(clip[1], r[1]), min(clip[2], r[2]), min(clip[3], r[3]))
        for c in sorted((c for c in n.children if c.visible), key=lambda c: c.z):
            self.paint(canvas, c, child_clip, offset, False)


def sample(keypoints, t, color):
    if not keypoints:
        return (1.0, 1.0, 1.0) if color else 0.0
    if t <= keypoints[0][0]:
        return keypoints[0][1]
    for (t0, v0), (t1, v1) in zip(keypoints, keypoints[1:]):
        if t <= t1:
            a = 0 if t1 == t0 else (t - t0) / (t1 - t0)
            if color:
                return tuple(v0[i] + (v1[i] - v0[i]) * a for i in range(3))
            return v0 + (v1 - v0) * a
    return keypoints[-1][1]


# ---------------------------------------------------------------------------------------------
# Foto
# ---------------------------------------------------------------------------------------------


def find_text(nodes, needle):
    for n in nodes.values():
        if n.text and needle in n.text["text"]:
            return n
    return None


def is_shown(n, nodes):
    while n is not None:
        if not n.visible:
            return False
        n = nodes.get(n.parent)
    return True


def render_scene(text, fonts, background=None, scroll_to=None):
    roots, nodes, (W, H) = parse(text)
    layout = Layout(fonts)

    def do_layout():
        for root in roots:
            layout.place(root, 0, 0, W, H, (1.0, 0.0, 0.0))

    do_layout()
    if scroll_to:
        target = find_text(nodes, scroll_to)
        frame = nodes.get(target.parent) if target else None
        while frame is not None and frame.cls != "ScrollingFrame":
            frame = nodes.get(frame.parent)
        if target and frame:
            frame.scroll = max(0.0, (target.rect[1] - frame.rect[1]) - 12)
            do_layout()
    canvas = Image.new("RGBA", (W, H), (18, 14, 22, 255))
    if background:
        bg = Image.open(background).convert("RGBA")
        scale = max(W / bg.width, H / bg.height)
        bg = bg.resize((int(math.ceil(bg.width * scale)), int(math.ceil(bg.height * scale))), Image.LANCZOS)
        canvas.alpha_composite(bg.crop((0, 0, W, H)))
    painter = Painter(fonts)
    for root in sorted(roots, key=lambda r: r.z):
        painter.paint(canvas, root)
    return canvas.convert("RGB")


def main():
    ap = argparse.ArgumentParser(description="Foto dei menu del gioco senza Roblox Studio")
    ap.add_argument("uscita")
    ap.add_argument("schermate", nargs="*")
    ap.add_argument("--halloween", action="store_true")
    ap.add_argument("--sfondo")
    ap.add_argument("--larghezza", type=int, default=1920)
    ap.add_argument("--caratteri")
    ap.add_argument("--evento")
    args = ap.parse_args()
    os.makedirs(args.uscita, exist_ok=True)
    fonts = Fonts(args.caratteri)
    if not fonts.files:
        print("  (caratteri @fontsource non trovati: uso DejaVu; vedi --caratteri)")
    tema = "Halloween" if args.halloween else None
    cache = {}
    for scene in args.schermate or SCENES:
        if scene not in SCENES:
            sys.exit("Schermata sconosciuta: " + scene)
        base = "admin" if scene == "admin_programma" else scene
        if base not in cache:
            cache[base] = dump(base, tema, args.evento)
        scroll = "📅 Programma un evento" if scene == "admin_programma" else None
        background = args.sfondo if scene != "titolo" else None
        img = render_scene(cache[base], fonts, background, scroll)
        if args.larghezza and args.larghezza != img.width:
            img = img.resize((args.larghezza, int(img.height * args.larghezza / img.width)), Image.LANCZOS)
        path = os.path.join(args.uscita, ("halloween_" if args.halloween else "") + "menu_" + scene + ".png")
        img.save(path)
        print("foto: " + path)


if __name__ == "__main__":
    main()
