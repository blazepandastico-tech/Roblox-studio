#!/usr/bin/env python3
"""Costruisce Shop.rbxlx (da aprire direttamente in Roblox Studio, senza Rojo).

Prima rigenera la UI:   python3 tools/gen_ui.py
Poi:                    python3 tools/build_rbxlx.py
"""
import json, os, uuid
from xml.sax.saxutils import escape

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "src")

INT_PROPS = {"DisplayOrder", "ZIndex", "TextSize", "MaxTextSize", "BorderSizePixel"}
COLOR_PROPS = {"BackgroundColor3", "TextColor3", "Color"}
ENUMS = {
    "ZIndexBehavior": {"Global": 0, "Sibling": 1},
    "ApplyStrokeMode": {"Contextual": 0, "Border": 1},
    "TextXAlignment": {"Left": 0, "Center": 1, "Right": 2},
    "ScaleType": {"Stretch": 0, "Slice": 1, "Tile": 2, "Fit": 3, "Crop": 4},
}


def ref():
    return "RBX" + uuid.uuid4().hex.upper()


def prop_xml(name, v):
    if name == "Font":  # usiamo FontFace (famiglia Fredoka One)
        return ('<Font name="FontFace"><Family><url>rbxasset://fonts/families/FredokaOne.json</url></Family>'
                '<Weight>400</Weight><Style>Normal</Style></Font>')
    if name in ENUMS:
        return f'<token name="{name}">{ENUMS[name][v]}</token>'
    if isinstance(v, bool):
        return f'<bool name="{name}">{str(v).lower()}</bool>'
    if isinstance(v, str):
        return f'<string name="{name}">{escape(v)}</string>'
    if name in COLOR_PROPS:
        return f'<Color3 name="{name}"><R>{v[0]}</R><G>{v[1]}</G><B>{v[2]}</B></Color3>'
    if name == "CornerRadius":
        return f'<UDim name="{name}"><S>{v[0]}</S><O>{v[1]}</O></UDim>'
    if name == "AnchorPoint":
        return f'<Vector2 name="{name}"><X>{v[0]}</X><Y>{v[1]}</Y></Vector2>'
    if isinstance(v, list):  # UDim2
        return (f'<UDim2 name="{name}"><XS>{v[0][0]}</XS><XO>{v[0][1]}</XO>'
                f'<YS>{v[1][0]}</YS><YO>{v[1][1]}</YO></UDim2>')
    if name in INT_PROPS:
        return f'<int name="{name}">{int(v)}</int>'
    return f'<float name="{name}">{v}</float>'


def item(cls, name, props_xml="", children=""):
    return (f'<Item class="{cls}" referent="{ref()}"><Properties>'
            f'<string name="Name">{escape(name)}</string>{props_xml}</Properties>{children}</Item>')


def from_json(node, overrides=None):
    props = dict(node.get("Properties", {}))
    props.update(overrides or {})
    px = "".join(prop_xml(k, v) for k, v in props.items())
    kids = "".join(from_json(c) for c in node.get("Children", []))
    return item(node["ClassName"], node["Name"], px, kids)


def script(cls, name, path):
    src = open(os.path.join(SRC, path), encoding="utf-8").read()
    assert "]]>" not in src
    return item(cls, name, f'<ProtectedString name="Source"><![CDATA[{src}]]></ProtectedString>')


def part(cls, name, pos, size, color):
    r, g, b = color
    cframe = (f'<CoordinateFrame name="CFrame"><X>{pos[0]}</X><Y>{pos[1]}</Y><Z>{pos[2]}</Z>'
              '<R00>1</R00><R01>0</R01><R02>0</R02><R10>0</R10><R11>1</R11><R12>0</R12>'
              '<R20>0</R20><R21>0</R21><R22>1</R22></CoordinateFrame>')
    px = (cframe + f'<Vector3 name="size"><X>{size[0]}</X><Y>{size[1]}</Y><Z>{size[2]}</Z></Vector3>'
          '<bool name="Anchored">true</bool>'
          f'<Color3uint8 name="Color3uint8">{(r << 16) | (g << 8) | b}</Color3uint8>')
    return item(cls, name, px)


load = lambda f: json.load(open(os.path.join(SRC, "gui", f), encoding="utf-8"))

workspace = item("Workspace", "Workspace", "",
                 part("Part", "Baseplate", (0, -10, 0), (512, 20, 512), (99, 95, 98))
                 + part("SpawnLocation", "SpawnLocation", (0, 0.5, 0), (12, 1, 12), (163, 162, 165)))
replicated = item("ReplicatedStorage", "ReplicatedStorage", "",
                  item("Folder", "Shared", "", script("ModuleScript", "ShopConfig", "shared/ShopConfig.lua")))
server = item("ServerScriptService", "ServerScriptService", "",
              script("Script", "ShopServer", "server/ShopServer.server.lua"))
# Enabled=True: cosi in Studio vedi subito la finestra; lo script la nasconde in Play.
starter_gui = item("StarterGui", "StarterGui", "",
                   from_json(load("ShopMenu.model.json"))
                   + from_json(load("ShopStore.model.json"), {"Enabled": True}))
starter_player = item("StarterPlayer", "StarterPlayer", "",
                      item("StarterPlayerScripts", "StarterPlayerScripts", "",
                           script("LocalScript", "ShopClient", "client/ShopClient.client.lua")))

xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
       'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
       'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
       + workspace + item("Lighting", "Lighting") + replicated + server
       + starter_gui + starter_player + "</roblox>")
out = os.path.join(ROOT, "Shop.rbxlx")
with open(out, "w", encoding="utf-8") as f:
    f.write('<?xml version="1.0" encoding="utf-8"?>\n' + xml)
print("scritto", out)
