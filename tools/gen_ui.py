#!/usr/bin/env python3
"""Genera gli oggetti UI statici (StarterGui) come file Rojo .model.json.

Uso: python3 tools/gen_ui.py
Dopo `rojo serve` / `rojo build` trovi ShopMenu e ShopStore dentro StarterGui in Studio,
cosi puoi vedere e modificare bottoni, colori e posizioni a mano.
"""
import json, os

OUT = os.path.join(os.path.dirname(__file__), "..", "src", "gui")


def c(r, g, b):
    return [round(r / 255, 4), round(g / 255, 4), round(b / 255, 4)]


def dark(col, f):
    return [round(max(0, min(1, v * f)), 4) for v in col]


def u2(xs, xo, ys, yo):
    return [[xs, xo], [ys, yo]]


def inst(cls, name, props=None, children=None):
    d = {"ClassName": cls, "Name": name, "Properties": props or {}}
    if children:
        d["Children"] = children
    return d


def corner(r):
    return inst("UICorner", "Corner", {"CornerRadius": [0, r]})


def stroke(col, th, contextual=False):
    return inst("UIStroke", "Stroke", {
        "Color": col, "Thickness": th,
        "ApplyStrokeMode": "Contextual" if contextual else "Border"})


def uiscale(name="UIScale", s=1):
    return inst("UIScale", name, {"Scale": s})


def text(name, txt, size, extra=None, scaled=False, outline=2.5):
    p = {"BackgroundTransparency": 1, "Font": "FredokaOne", "Text": txt,
         "TextColor3": [1, 1, 1], "TextSize": size, "TextScaled": scaled}
    p.update(extra or {})
    kids = [stroke([0, 0, 0], outline, True)]
    if scaled:
        kids.append(inst("UITextSizeConstraint", "SizeLimit", {"MaxTextSize": size}))
    return inst("TextLabel", name, p, kids)


def image(name, extra):
    p = {"BackgroundTransparency": 1, "Image": "", "ScaleType": "Fit", "Visible": False}
    p.update(extra)
    return inst("ImageLabel", name, p)


# ---------------------------------------------------------------- Menu
CELL, GAP = 96, 10
MENU = [
    ("Sentieri", "🐾", c(176, 56, 214), "Sentieri", False),
    ("Rinascita", "🔄", c(34, 160, 185), "Rinascita", False),
    ("Giornaliero", "📅", c(232, 232, 236), "Giornaliero", True),
    ("Gift", "🎁", c(255, 150, 40), "2:46", False),
    ("Musica", "🎵", c(255, 214, 40), "Musica", False),
    ("Shop", "🧺", c(60, 205, 80), "Shop", False),
]


def menu_button(i, name, emoji, col, label, badge):
    cx = (i % 2) * (CELL + GAP) + CELL / 2
    cy = (i // 2) * (CELL + GAP) + CELL / 2
    body = inst("TextButton", "Body", {
        "Text": "", "AutoButtonColor": False, "BackgroundColor3": col,
        "AnchorPoint": [0.5, 0.5], "Position": u2(0.5, 0, 0.5, 0), "Size": u2(1, 0, 1, 0),
    }, [
        corner(16), stroke(dark(col, 0.45), 4),
        inst("Frame", "Gloss", {"BackgroundColor3": [1, 1, 1], "BackgroundTransparency": 0.8,
                                "BorderSizePixel": 0, "Position": u2(0, 6, 0, 5),
                                "Size": u2(1, -12, 0.3, 0)}, [corner(10)]),
        text("Icon", emoji, 50, {"AnchorPoint": [0.5, 0.5], "Position": u2(0.5, 0, 0.4, 0),
                                  "Size": u2(0, 64, 0, 64)}, outline=0),
        image("IconImage", {"AnchorPoint": [0.5, 0.5], "Position": u2(0.5, 0, 0.4, 0),
                            "Size": u2(0, 62, 0, 62)}),
        text("NameLabel", label, 24, {"AnchorPoint": [0.5, 1], "Position": u2(0.5, 0, 1, 2),
                                       "Size": u2(1, 0, 0, 26), "ZIndex": 3}, scaled=True, outline=3),
    ])
    kids = [uiscale(), body]
    if badge:
        kids.append(inst("Frame", "Badge", {
            "BackgroundColor3": c(235, 40, 40), "AnchorPoint": [0.5, 0.5],
            "Position": u2(1, -2, 0, 4), "Size": u2(0, 30, 0, 30), "ZIndex": 6,
        }, [corner(9), stroke(c(120, 10, 10), 3), uiscale(),
            text("Mark", "!", 26, {"Size": u2(1, 0, 1, 0), "ZIndex": 7}, outline=0)]))
    return inst("Frame", name, {
        "BackgroundTransparency": 1, "AnchorPoint": [0.5, 0.5],
        "Position": u2(0, cx, 0, cy), "Size": u2(0, CELL, 0, CELL)}, kids)


menu = inst("ScreenGui", "ShopMenu", {
    "ResetOnSpawn": False, "IgnoreGuiInset": True, "DisplayOrder": 1,
    "ZIndexBehavior": "Sibling"}, [
    inst("Frame", "Menu", {
        "BackgroundTransparency": 1, "AnchorPoint": [0, 0.5],
        "Position": u2(0, 14, 0.5, 0),
        "Size": u2(0, CELL * 2 + GAP, 0, CELL * 3 + GAP * 2)},
        [uiscale()] + [menu_button(i, *m) for i, m in enumerate(MENU)])])

# ---------------------------------------------------------------- Store
WIN_W, WIN_H, HEADER, PANEL_W, PANEL_H = 640, 430, 58, 624, 364
TABS = [
    ("Luck", "❄️", c(41, 128, 255)),
    ("Power", "💪", c(255, 196, 30)),
    ("Trophies", "🏆", c(255, 170, 30)),
    ("Pets", "🔴", c(40, 200, 90)),
]
NAVY = c(16, 44, 110)


def tab(i, name, emoji, col):
    return inst("Frame", "Tab_" + name, {
        "BackgroundTransparency": 1, "AnchorPoint": [0.5, 0.5],
        "Position": u2(0, 295 + i * 58, 0, 30), "Size": u2(0, 48, 0, 48), "ZIndex": 5},
        [uiscale(), inst("TextButton", "Body", {
            "Text": "", "AutoButtonColor": False, "BackgroundColor3": col,
            "Size": u2(1, 0, 1, 0), "ZIndex": 5},
            [corner(12), stroke(dark(col, 0.4), 4),
             text("Icon", emoji, 30, {"Size": u2(1, 0, 1, 0), "ZIndex": 6}, outline=0)])])


window = inst("Frame", "Window", {
    "BackgroundColor3": c(50, 150, 240), "AnchorPoint": [0.5, 0.5],
    "Position": u2(0.5, 0, 0.5, 0), "Size": u2(1, 0, 1, 0), "Active": True},
    [corner(22), stroke(NAVY, 5), uiscale("OpenScale"),
     inst("Frame", "Panel", {
         "BackgroundColor3": c(252, 246, 226), "Position": u2(0, 8, 0, HEADER),
         "Size": u2(0, PANEL_W, 0, PANEL_H), "ClipsDescendants": True},
         [corner(16), stroke(NAVY, 3),
          inst("Frame", "Cards", {"BackgroundTransparency": 1, "Size": u2(1, 0, 1, 0), "ZIndex": 2})]),
     text("Title", "Store!", 44, {"TextXAlignment": "Left", "Position": u2(0, 100, 0, 4),
                                   "Size": u2(0, 170, 0, 50), "ZIndex": 5}, outline=4),
     text("BasketIcon", "🧺", 78, {"AnchorPoint": [0.5, 0.5], "Position": u2(0, 44, 0, 24),
                                    "Size": u2(0, 92, 0, 92), "ZIndex": 6}, outline=0),
     image("BasketImage", {"AnchorPoint": [0.5, 0.5], "Position": u2(0, 44, 0, 24),
                           "Size": u2(0, 92, 0, 92), "ZIndex": 6}),
     ] + [tab(i, *t) for i, t in enumerate(TABS)] + [
     inst("Frame", "Close", {
         "BackgroundTransparency": 1, "AnchorPoint": [0.5, 0.5],
         "Position": u2(0, WIN_W - 4, 0, 26), "Size": u2(0, 50, 0, 50), "ZIndex": 8},
         [uiscale(), inst("TextButton", "Body", {
             "Text": "", "AutoButtonColor": False, "BackgroundColor3": c(235, 40, 40),
             "Size": u2(1, 0, 1, 0), "ZIndex": 8},
             [corner(12), stroke(c(110, 10, 10), 4),
              text("X", "✖", 30, {"Size": u2(1, 0, 1, 0), "ZIndex": 9}, outline=2)])])])

store = inst("ScreenGui", "ShopStore", {
    "ResetOnSpawn": False, "IgnoreGuiInset": True, "DisplayOrder": 10,
    "ZIndexBehavior": "Sibling", "Enabled": False}, [
    inst("TextButton", "Overlay", {
        "Text": "", "AutoButtonColor": False, "BackgroundColor3": [0, 0, 0],
        "BackgroundTransparency": 0.5, "Size": u2(1, 0, 1, 0)}),
    inst("Frame", "Fit", {
        "BackgroundTransparency": 1, "AnchorPoint": [0.5, 0.5],
        "Position": u2(0.5, 0, 0.5, 0), "Size": u2(0, WIN_W, 0, WIN_H)},
        [uiscale("FitScale"), window])])

os.makedirs(OUT, exist_ok=True)
for fname, data in (("ShopMenu.model.json", menu), ("ShopStore.model.json", store)):
    with open(os.path.join(OUT, fname), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
print("ok")
