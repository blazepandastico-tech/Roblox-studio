"""Aggiunge logo e scritte alle immagini renderizzate.

  python3 tools/thumbnails/compose.py <cartella render> <cartella di uscita>
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SERIF = "/usr/share/fonts/truetype/freefont/FreeSerifBold.ttf"
SANS = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
if not os.path.exists(SERIF):
    SERIF = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"


def font(path, size):
    return ImageFont.truetype(path, size)


def spaced_size(draw, text, f, spacing):
    w = 0
    for i, ch in enumerate(text):
        bb = draw.textbbox((0, 0), ch, font=f)
        w += bb[2] - bb[0] + (spacing if i < len(text) - 1 else 0)
    asc, desc = f.getmetrics()
    return w, asc + desc


def draw_spaced(draw, xy, text, f, spacing, **kw):
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=f, **kw)
        bb = draw.textbbox((0, 0), ch, font=f)
        x += bb[2] - bb[0] + spacing


def title(img, text, size, center, spacing=0.06, top=(255, 236, 170), bottom=(196, 120, 40), stroke=None, glow=(255, 160, 60), path=SERIF):
    """Scritta metallica dorata con contorno scuro, ombra e alone."""
    W, H = img.size
    f = font(path, size)
    sp = int(size * spacing)
    d0 = ImageDraw.Draw(img)
    tw, th = spaced_size(d0, text, f, sp)
    x = int(center[0] - tw / 2)
    y = int(center[1] - th / 2)
    stroke = stroke or max(2, size // 14)
    # maschera del testo e del contorno
    mask = Image.new("L", (W, H), 0)
    draw_spaced(ImageDraw.Draw(mask), (x, y), text, f, sp, fill=255)
    outline = Image.new("L", (W, H), 0)
    draw_spaced(ImageDraw.Draw(outline), (x, y), text, f, sp, fill=255, stroke_width=stroke, stroke_fill=255)
    base = img.convert("RGBA")
    # ombra
    shadow = outline.filter(ImageFilter.GaussianBlur(size * 0.08))
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sh.putalpha(shadow.point(lambda v: int(v * 0.85)))
    base = Image.alpha_composite(base, _offset(sh, int(size * 0.04), int(size * 0.06)))
    # alone colorato
    g = outline.filter(ImageFilter.GaussianBlur(size * 0.18))
    gl = Image.new("RGBA", (W, H), glow + (0,))
    gl.putalpha(g.point(lambda v: int(v * 0.55)))
    base = Image.alpha_composite(base, gl)
    # contorno scuro
    ol = Image.new("RGBA", (W, H), (28, 14, 6, 0))
    ol.putalpha(outline)
    base = Image.alpha_composite(base, ol)
    # riempimento con sfumatura verticale e riflesso
    yy = np.linspace(0, 1, H)[:, None]
    rel = np.clip((yy * H - y) / max(1, th), 0, 1)
    t = np.asarray(top, float)
    b = np.asarray(bottom, float)
    band = 1 - np.abs(rel - 0.48) * 6
    grad = t * (1 - rel[..., None]) + b * rel[..., None]
    grad = grad + np.clip(band, 0, 1)[..., None] * 40
    grad = np.broadcast_to(np.clip(grad, 0, 255), (H, W, 3)).astype(np.uint8)
    fill = Image.fromarray(grad, "RGB").convert("RGBA")
    fill.putalpha(mask)
    base = Image.alpha_composite(base, fill)
    return base.convert("RGB"), (x, y, tw, th)


def _offset(im, dx, dy):
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(im, (dx, dy))
    return out


def shade(img, region="bottom", strength=0.75, extent=0.45):
    """Sfumatura scura per far leggere le scritte."""
    W, H = img.size
    a = np.zeros((H, W))
    if region == "bottom":
        y = np.linspace(0, 1, H)[:, None]
        a = np.clip((y - (1 - extent)) / extent, 0, 1) ** 1.4 * strength
    elif region == "top":
        y = np.linspace(0, 1, H)[:, None]
        a = np.clip((extent - y) / extent, 0, 1) ** 1.4 * strength
    elif region == "left":
        x = np.linspace(0, 1, W)[None, :]
        a = np.clip((extent - x) / extent, 0, 1) ** 1.4 * strength
    a = np.broadcast_to(a, (H, W))
    arr = np.asarray(img).astype(np.float64)
    arr = arr * (1 - a[..., None])
    return Image.fromarray(arr.astype(np.uint8))


def plain_text(img, text, size, center, color=(255, 255, 255), path=SANS, spacing=0.12, stroke=None, anchor_mid=True):
    W, H = img.size
    f = font(path, size)
    sp = int(size * spacing)
    d = ImageDraw.Draw(img)
    tw, th = spaced_size(d, text, f, sp)
    x = int(center[0] - tw / 2) if anchor_mid else int(center[0])
    y = int(center[1] - th / 2)
    base = img.convert("RGBA")
    m = Image.new("L", (W, H), 0)
    draw_spaced(ImageDraw.Draw(m), (x, y), text, f, sp, fill=255, stroke_width=stroke or max(2, size // 9), stroke_fill=255)
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sh.putalpha(m.filter(ImageFilter.GaussianBlur(size * 0.12)).point(lambda v: int(v * 0.8)))
    base = Image.alpha_composite(base, sh)
    d2 = ImageDraw.Draw(base)
    draw_spaced(d2, (x, y), text, f, sp, fill=color + (255,), stroke_width=max(1, size // 16), stroke_fill=(20, 12, 6, 255))
    return base.convert("RGB"), (x, y, tw, th)


def divider(img, cx, y, half, color=(230, 190, 110)):
    d = ImageDraw.Draw(img)
    d.line([(cx - half, y), (cx - 18, y)], fill=color, width=3)
    d.line([(cx + 18, y), (cx + half, y)], fill=color, width=3)
    d.polygon([(cx, y - 9), (cx + 9, y), (cx, y + 9), (cx - 9, y)], fill=color)
    return img


def logo(img, cx, cy, scale=1.0):
    img, (x, y, tw, th) = title(img, "SIERI PERDUTI", int(150 * scale), (cx, cy))
    divider(img, cx, int(cy + th * 0.62), int(tw * 0.45))
    img, _ = plain_text(img, "L'ARCIPELAGO DEI GIGANTI", int(40 * scale), (cx, int(cy + th * 0.62 + 40 * scale)), color=(245, 232, 205), path=SERIF, spacing=0.22)
    return img


def badge(img, text, xy, size=34, fill=(176, 32, 28), color=(255, 255, 255)):
    f = font(SANS, size)
    d = ImageDraw.Draw(img)
    bb = d.textbbox((0, 0), text, font=f)
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    x, y = xy
    pad = int(size * 0.45)
    base = img.convert("RGBA")
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([x + 4, y + 6, x + w + pad * 2 + 4, y + h + pad * 2 + 6], radius=10, fill=(0, 0, 0, 140))
    base = Image.alpha_composite(base, sh.filter(ImageFilter.GaussianBlur(6)))
    d = ImageDraw.Draw(base)
    d.rounded_rectangle([x, y, x + w + pad * 2, y + h + pad * 2], radius=10, fill=fill + (255,), outline=(255, 220, 150, 255), width=3)
    d.text((x + pad - bb[0], y + pad - bb[1]), text, font=f, fill=color + (255,))
    return base.convert("RGB")


def main():
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)

    def load(name):
        p = os.path.join(src, name + "_raw.png")
        return Image.open(p).convert("RGB") if os.path.exists(p) else None

    im = load("hero")
    if im:
        im = shade(im, "bottom", 0.8, 0.42)
        im = logo(im, 960, 850, 1.0)
        im.save(os.path.join(out, "4_SieriPerduti_Gigante.png"))
    im = load("combat")
    if im:
        im = shade(im, "bottom", 0.75, 0.4)
        im, _ = title(im, "COLPISCI LA NUCA!", 112, (960, 860), top=(255, 250, 235), bottom=(190, 205, 230), glow=(150, 190, 255))
        im, _ = plain_text(im, "Vola con il dispositivo di manovra e abbatti i giganti", 34, (960, 960), color=(235, 238, 245), path=SANS, spacing=0.04)
        im = plaque(im, 230, 120, 0.36, subtitle=False)
        im.save(os.path.join(out, "2_SieriPerduti_Combattimento.png"))
    im = load("world")
    if im:
        im = shade(im, "top", 0.7, 0.32)
        im, _ = title(im, "5 ISOLE DA ESPLORARE", 104, (960, 110), top=(255, 246, 215), bottom=(214, 160, 70))
        im, _ = plain_text(im, "Storia in 4 stagioni  •  Raid  •  Livello massimo 2000", 36, (960, 210), color=(250, 245, 235), path=SANS, spacing=0.04)
        im = plaque(im, 230, 960, 0.36, subtitle=False)
        im.save(os.path.join(out, "3_SieriPerduti_Isole.png"))
    im = load("icon2")
    if im:
        card = icon_card(im)
        card.save(os.path.join(out, "Icona_1024.png"))
        card.resize((512, 512), Image.LANCZOS).save(os.path.join(out, "Icona_512.png"))
    im = load("hero2")
    if im:
        im = plaque(im, 960, 205, 0.8)
        im.save(os.path.join(out, "1_SieriPerduti_Copertina.png"))
    im = None
    if im:
        im = shade(im, "bottom", 0.85, 0.42)
        im, (x, y, tw, th) = title(im, "SIERI", 96, (256, 395), spacing=0.08)
        im, _ = title(im, "PERDUTI", 64, (256, 462), spacing=0.12)
        im.save(os.path.join(out, "Icona_512.png"))



# ---------------------------------------------------------------------------------------------
# Stile "gioco Roblox": targa con il logo, ingranaggi, lame incrociate, cornice dell'icona
# ---------------------------------------------------------------------------------------------

GAME_FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def _metal(size, top=(235, 238, 242), bottom=(110, 116, 126), mid=None):
    """Riempimento metallico a fasce (luce in alto, riflesso al centro)."""
    W, H = size
    y = np.linspace(0, 1, H)[:, None, None]
    t = np.asarray(top, float)
    b = np.asarray(bottom, float)
    c = t * (1 - y) + b * y
    c = c + 45 * np.exp(-((y - 0.42) ** 2) / 0.004)
    c = c - 25 * np.exp(-((y - 0.55) ** 2) / 0.002)
    return Image.fromarray(np.broadcast_to(np.clip(c, 0, 255), (H, W, 3)).astype(np.uint8))


def _shape_layer(size, draw_fn):
    m = Image.new("L", size, 0)
    draw_fn(ImageDraw.Draw(m))
    return m


def _paint(base, mask, fill_img, outline=(18, 14, 12), ow=0, shadow=True, sh_off=(6, 9), sh_blur=8):
    W, H = base.size
    if shadow:
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        sh.putalpha(mask.filter(ImageFilter.GaussianBlur(sh_blur)).point(lambda v: int(v * 0.6)))
        base = Image.alpha_composite(base, _offset(sh, *sh_off))
    if ow:
        grown = mask.filter(ImageFilter.MaxFilter(ow * 2 + 1))
        ol = Image.new("RGBA", (W, H), outline + (255,))
        ol.putalpha(grown)
        base = Image.alpha_composite(base, ol)
    f = fill_img.convert("RGBA")
    f.putalpha(mask)
    return Image.alpha_composite(base, f)


def gear(base, cx, cy, r, teeth=10, angle=0.0):
    W, H = base.size
    pts = []
    for i in range(teeth * 4):
        a = angle + i / (teeth * 4) * 2 * np.pi
        rr = r if (i % 4) in (0, 1) else r * 0.8
        pts.append((cx + np.cos(a) * rr, cy + np.sin(a) * rr))
    mask = _shape_layer((W, H), lambda d: d.polygon(pts, fill=255))
    hole = _shape_layer((W, H), lambda d: d.ellipse([cx - r * 0.32, cy - r * 0.32, cx + r * 0.32, cy + r * 0.32], fill=255))
    mask = Image.fromarray(np.clip(np.asarray(mask, np.int32) - np.asarray(hole, np.int32), 0, 255).astype(np.uint8))
    met = _metal((W, H), (225, 228, 232), (95, 100, 110))
    base = _paint(base, mask, met, ow=max(2, int(r * 0.07)))
    # anello interno in rilievo
    d = ImageDraw.Draw(base)
    d.ellipse([cx - r * 0.55, cy - r * 0.55, cx + r * 0.55, cy + r * 0.55], outline=(70, 74, 82, 255), width=max(2, int(r * 0.06)))
    d.ellipse([cx - r * 0.34, cy - r * 0.34, cx + r * 0.34, cy + r * 0.34], outline=(40, 40, 46, 255), width=max(2, int(r * 0.05)))
    return base


def blade(base, x0, y0, x1, y1, width):
    """Lama del dispositivo di manovra: lunga, dritta, con il manico scuro."""
    W, H = base.size
    v = np.array([x1 - x0, y1 - y0], float)
    L = np.linalg.norm(v)
    t = v / L
    n = np.array([-t[1], t[0]])
    hw = width / 2
    tip = np.array([x1, y1])
    start = np.array([x0, y0]) + t * L * 0.22
    body = [start + n * hw, tip - t * width * 1.5 + n * hw, tip, tip - t * width * 1.5 - n * hw * 0.2, start - n * hw]
    mask = _shape_layer((W, H), lambda d: d.polygon([tuple(p) for p in body], fill=255))
    base = _paint(base, mask, _metal((W, H), (250, 252, 255), (150, 160, 175)), ow=max(2, int(width * 0.12)))
    d = ImageDraw.Draw(base)
    d.line([tuple(start + n * hw * 0.35), tuple(tip - t * width * 1.6 + n * hw * 0.35)], fill=(255, 255, 255, 230), width=max(1, int(width * 0.12)))
    # manico e guardia
    h0 = np.array([x0, y0])
    grip = [h0 + n * hw * 0.7, start + n * hw * 0.7, start - n * hw * 0.7, h0 - n * hw * 0.7]
    gmask = _shape_layer((W, H), lambda d: d.polygon([tuple(p) for p in grip], fill=255))
    base = _paint(base, gmask, Image.new("RGB", (W, H), (58, 52, 50)), ow=max(2, int(width * 0.1)), shadow=False)
    guard = [start + n * hw * 1.6 - t * width * 0.4, start + n * hw * 1.6 + t * width * 0.2, start - n * hw * 1.6 + t * width * 0.2, start - n * hw * 1.6 - t * width * 0.4]
    gm = _shape_layer((W, H), lambda d: d.polygon([tuple(p) for p in guard], fill=255))
    return _paint(base, gm, _metal((W, H), (240, 210, 130), (150, 100, 40)), ow=max(2, int(width * 0.1)), shadow=False)


def _game_text(base, text, size, center, top, bottom, outline=(30, 16, 8), ow=None, spacing=0.02, path=GAME_FONT):
    """Scritta da videogioco: lettere grosse con contorno spesso, sfumatura e lucentezza."""
    W, H = base.size
    f = font(path, size)
    sp = int(size * spacing)
    d0 = ImageDraw.Draw(base)
    tw, th = spaced_size(d0, text, f, sp)
    x = int(center[0] - tw / 2)
    asc, desc = f.getmetrics()
    y = int(center[1] - asc * 0.58)
    ow = ow or max(3, int(size * 0.11))
    mask = Image.new("L", (W, H), 0)
    draw_spaced(ImageDraw.Draw(mask), (x, y), text, f, sp, fill=255)
    outer = Image.new("L", (W, H), 0)
    draw_spaced(ImageDraw.Draw(outer), (x, y), text, f, sp, fill=255, stroke_width=ow, stroke_fill=255)
    # ombra 3D sotto le lettere
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sh.putalpha(outer.filter(ImageFilter.GaussianBlur(size * 0.05)).point(lambda v: int(v * 0.7)))
    base = Image.alpha_composite(base, _offset(sh, 0, int(size * 0.08)))
    ol = Image.new("RGBA", (W, H), outline + (255,))
    ol.putalpha(outer)
    base = Image.alpha_composite(base, ol)
    yy = np.linspace(0, 1, H)[:, None]
    rel = np.clip((yy * H - (center[1] - size * 0.45)) / (size * 0.9), 0, 1)
    t = np.asarray(top, float)
    b = np.asarray(bottom, float)
    g = t * (1 - rel[..., None]) + b * rel[..., None]
    g = g + 60 * np.exp(-((rel - 0.18) ** 2) / 0.006)[..., None]
    fill = Image.fromarray(np.broadcast_to(np.clip(g, 0, 255), (H, W, 3)).astype(np.uint8)).convert("RGBA")
    fill.putalpha(mask)
    base = Image.alpha_composite(base, fill)
    return base, tw, th


def plaque(img, cx, cy, scale=1.0, subtitle=True):
    """Il logo del gioco su una targa di legno con bordo d'acciaio, lame incrociate e ingranaggi."""
    base = img.convert("RGBA")
    W, H = base.size
    w, h = 760 * scale, 330 * scale
    # lame incrociate dietro la targa
    L = 560 * scale
    for sgn in (1, -1):
        base = blade(base, cx - sgn * L * 0.62, cy + L * 0.30, cx + sgn * L * 0.66, cy - L * 0.42, 46 * scale)
    # ingranaggi ai lati
    base = gear(base, cx - w * 0.52, cy + h * 0.06, 92 * scale, teeth=11, angle=0.1)
    base = gear(base, cx + w * 0.52, cy + h * 0.06, 92 * scale, teeth=11, angle=0.3)
    box = [cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2]
    rad = int(h * 0.42)
    rim = _shape_layer((W, H), lambda d: d.rounded_rectangle(box, radius=rad, fill=255))
    base = _paint(base, rim, _metal((W, H), (238, 240, 245), (105, 110, 122)), ow=int(7 * scale), sh_off=(int(8 * scale), int(14 * scale)), sh_blur=int(14 * scale))
    inset = 22 * scale
    ibox = [box[0] + inset, box[1] + inset, box[2] - inset, box[3] - inset]
    inner = _shape_layer((W, H), lambda d: d.rounded_rectangle(ibox, radius=int(rad - inset), fill=255))
    # legno scuro con venature
    rng = np.random.default_rng(3)
    yy = np.arange(H)[:, None]
    xx = np.arange(W)[None, :]
    grain = np.sin((yy * 0.09 / scale + np.sin(xx * 0.01 / scale + yy * 0.002) * 2.0)) * 0.5 + 0.5
    noise = rng.normal(0, 1, (H // 4 + 1, W // 4 + 1))
    noise = np.repeat(np.repeat(noise, 4, 0), 4, 1)[:H, :W]
    wood = np.array([96, 56, 30])[None, None, :] * (0.75 + 0.3 * grain[..., None] + 0.04 * noise[..., None])
    vgrad = np.clip((yy - ibox[1]) / (ibox[3] - ibox[1]), 0, 1)
    wood = wood * (1.1 - 0.35 * vgrad[..., None])
    wood_img = Image.fromarray(np.clip(wood, 0, 255).astype(np.uint8))
    base = _paint(base, inner, wood_img, ow=int(5 * scale), outline=(40, 22, 10), shadow=False)
    # bordo interno chiaro (smussatura)
    d = ImageDraw.Draw(base)
    d.rounded_rectangle([ibox[0] + 6 * scale, ibox[1] + 6 * scale, ibox[2] - 6 * scale, ibox[3] - 6 * scale], radius=int(rad - inset - 6 * scale), outline=(150, 98, 58, 160), width=max(2, int(3 * scale)))
    # chiodi
    for px, py in ((box[0] + 48 * scale, cy), (box[2] - 48 * scale, cy)):
        d.ellipse([px - 11 * scale, py - 11 * scale, px + 11 * scale, py + 11 * scale], fill=(200, 205, 212, 255), outline=(40, 40, 44, 255), width=max(2, int(3 * scale)))
    base, _, _ = _game_text(base, "SIERI", int(118 * scale), (cx, cy - 72 * scale), (255, 255, 255), (186, 196, 214))
    base, _, _ = _game_text(base, "PERDUTI", int(126 * scale), (cx, cy + 52 * scale), (255, 226, 92), (236, 112, 20))
    if subtitle:
        # nastro rosso con il sottotitolo
        rw, rh = w * 0.86, 66 * scale
        ry = cy + h / 2 + rh * 0.35
        pts = [(cx - rw / 2, ry - rh / 2), (cx + rw / 2, ry - rh / 2), (cx + rw / 2 - rh * 0.35, ry), (cx + rw / 2, ry + rh / 2), (cx - rw / 2, ry + rh / 2), (cx - rw / 2 + rh * 0.35, ry)]
        rm = _shape_layer((W, H), lambda d: d.polygon(pts, fill=255))
        red = _metal((W, H), (220, 60, 48), (120, 18, 16))
        base = _paint(base, rm, red, ow=int(5 * scale))
        base, _, _ = _game_text(base, "L'ARCIPELAGO DEI GIGANTI", int(38 * scale), (cx, ry), (255, 255, 255), (250, 226, 190), ow=int(5 * scale), spacing=0.05)
    return base.convert("RGB")


def cable_frame(img, margin, thick, radius):
    """Cornice dell'icona: cavo d'acciaio intrecciato con ingranaggi negli angoli."""
    base = img.convert("RGBA")
    W, H = base.size
    box = [margin, margin, W - margin, H - margin]
    ring = _shape_layer((W, H), lambda d: d.rounded_rectangle(box, radius=radius, outline=255, width=thick))
    met = _metal((W, H), (230, 232, 238), (100, 104, 116))
    base = _paint(base, ring, met, ow=max(2, thick // 6), sh_off=(4, 6), sh_blur=6)
    # intreccio del cavo: tacche diagonali lungo il bordo
    d = ImageDraw.Draw(base)
    step = thick * 0.9
    m = margin + thick / 2
    for x in np.arange(margin + radius, W - margin - radius, step):
        for yc in (m, H - m):
            d.line([(x - thick * 0.3, yc + thick * 0.4), (x + thick * 0.3, yc - thick * 0.4)], fill=(70, 72, 80, 255), width=max(2, thick // 7))
    for y in np.arange(margin + radius, H - margin - radius, step):
        for xc in (m, W - m):
            d.line([(xc - thick * 0.4, y + thick * 0.3), (xc + thick * 0.4, y - thick * 0.3)], fill=(70, 72, 80, 255), width=max(2, thick // 7))
    r = thick * 2.1
    for (gx, gy), a in (((margin + thick * 0.6, margin + thick * 0.6), 0.0), ((W - margin - thick * 0.6, margin + thick * 0.6), 0.2), ((margin + thick * 0.6, H - margin - thick * 0.6), 0.4), ((W - margin - thick * 0.6, H - margin - thick * 0.6), 0.1)):
        base = gear(base, gx, gy, r, teeth=9, angle=a)
    return base.convert("RGB")


def icon_card(img):
    """Icona: scena con cornice di cavo d'acciaio e ingranaggi, logo sulla targa in basso."""
    W, H = img.size
    k = W / 1024
    soft = img.filter(ImageFilter.GaussianBlur(10 * k))
    margin = int(52 * k)
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rounded_rectangle([margin, margin, W - margin, H - margin], radius=int(90 * k), fill=255)
    out = Image.composite(img, soft, mask)
    out = cable_frame(out, int(40 * k), int(30 * k), int(100 * k))
    out = plaque(out, W / 2, H * 0.80, 0.62 * k, subtitle=False)
    return out


if __name__ == "__main__":
    main()
