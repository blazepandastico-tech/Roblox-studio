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
        im.save(os.path.join(out, "1_SieriPerduti_Gigante.png"))
    im = load("combat")
    if im:
        im = shade(im, "bottom", 0.75, 0.4)
        im, _ = title(im, "COLPISCI LA NUCA!", 112, (960, 860), top=(255, 250, 235), bottom=(190, 205, 230), glow=(150, 190, 255))
        im, _ = plain_text(im, "Vola con il dispositivo di manovra e abbatti i giganti", 34, (960, 960), color=(235, 238, 245), path=SANS, spacing=0.04)
        im = badge(im, "SIERI PERDUTI", (40, 36), size=30, fill=(120, 76, 30))
        im.save(os.path.join(out, "2_SieriPerduti_Combattimento.png"))
    im = load("world")
    if im:
        im = shade(im, "top", 0.7, 0.32)
        im, _ = title(im, "5 ISOLE DA ESPLORARE", 104, (960, 110), top=(255, 246, 215), bottom=(214, 160, 70))
        im, _ = plain_text(im, "Storia in 4 stagioni  •  Raid  •  Livello massimo 2000", 36, (960, 210), color=(250, 245, 235), path=SANS, spacing=0.04)
        im = badge(im, "SIERI PERDUTI", (40, 980), size=30, fill=(120, 76, 30))
        im.save(os.path.join(out, "3_SieriPerduti_Isole.png"))
    im = load("icon")
    if im:
        im = shade(im, "bottom", 0.85, 0.42)
        im, (x, y, tw, th) = title(im, "SIERI", 96, (256, 395), spacing=0.08)
        im, _ = title(im, "PERDUTI", 64, (256, 462), spacing=0.12)
        im.save(os.path.join(out, "Icona_512.png"))


if __name__ == "__main__":
    main()
