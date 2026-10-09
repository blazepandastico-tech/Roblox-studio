#!/usr/bin/env python3
"""Genera tools/tests/roblox_api.luau: le proprietà delle classi di Roblox e i valori degli Enum
usati dal gioco, presi dal file di definizioni di luau-lsp (globalTypes.d.luau).
Serve alla prova di costruzione del mondo (tools/test_world.py) per scoprire proprietà
scritte male o valori sbagliati senza aprire Roblox Studio.

Uso: python3 tools/gen_roblox_api.py percorso/globalTypes.d.luau
"""
import os, re, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "tools", "tests", "roblox_api.luau")

if len(sys.argv) < 2:
    print(__doc__)
    sys.exit(2)

src = open(sys.argv[1], encoding="utf-8").read()
classes = {}
enums = {}
cur = None
for line in src.splitlines():
    m = re.match(r"^declare class (\w+)(?: extends (\w+))?\s*$", line)
    if m:
        cur = m.group(1)
        classes[cur] = {"S": m.group(2), "P": {}}
        continue
    if line.startswith("end"):
        cur = None
        continue
    if cur:
        m = re.match(r"^\t(\w+): (.+)$", line)
        if m and not m.group(2).startswith("("):
            classes[cur]["P"][m.group(1)] = m.group(2).strip()

for name, c in classes.items():
    if name.startswith("Enum") and name.endswith("_INTERNAL"):
        enums[name[4:-9]] = sorted(c["P"].keys())

# classi e Enum usati dal codice del gioco
used_classes = set()
used_enums = set()
for base, _, names in os.walk(os.path.join(ROOT, "src")):
    for n in names:
        if n.endswith(".lua"):
            text = open(os.path.join(base, n), encoding="utf-8").read()
            used_classes |= set(re.findall(r'Instance\.new\("(\w+)"', text))
            used_classes |= set(re.findall(r'\bNew\("(\w+)"', text))
            used_classes |= set(re.findall(r'Util\.Create\("(\w+)"', text))
            used_classes |= set(re.findall(r'ClassName = "(\w+)"', text))
            used_classes |= set(re.findall(r':IsA\("(\w+)"\)', text))
            used_classes |= set(re.findall(r'FindFirstChildOfClass\("(\w+)"\)', text))
            used_enums |= set(re.findall(r"Enum\.(\w+)\.\w+", text))
used_classes |= {"Workspace", "Terrain", "Model", "Folder", "Part", "Players", "Player", "Humanoid", "CollectionService",
                 "HttpService", "PhysicsService", "RunService", "ReplicatedStorage", "Lighting", "Camera", "PlayerGui",
                 "UserInputService", "TweenService", "StarterGui", "SoundService", "MarketplaceService", "GuiService",
                 "TextService", "Debris", "ContextActionService", "ProximityPromptService", "PlayerScripts", "ScreenGui"}
used_classes |= set(re.findall(r'GetService\("(\w+)"\)', "".join(
    open(os.path.join(b, n), encoding="utf-8").read() for b, _, ns in os.walk(os.path.join(ROOT, "src")) for n in ns if n.endswith(".lua"))))

needed = set()
def add(name):
    while name and name in classes and name not in needed:
        needed.add(name)
        name = classes[name]["S"]
for c in used_classes:
    add(c)

def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

out = ["-- Generato da tools/gen_roblox_api.py: non modificare a mano", "ROBLOX_API = {", "\tClasses = {"]
for name in sorted(needed):
    c = classes[name]
    props = ", ".join(f"{k} = {lua_str(v)}" for k, v in sorted(c["P"].items()) if re.match(r"^[A-Za-z_]\w*$", k))
    sup = lua_str(c["S"]) if c["S"] else "nil"
    out.append(f"\t\t{name} = {{ S = {sup}, P = {{ {props} }} }},")
out.append("\t},")
out.append("\tEnums = {")
for name in sorted(used_enums):
    if name in enums:
        items = ", ".join(lua_str(i) for i in enums[name])
        out.append(f"\t\t{name} = {{ {items} }},")
out.append("\t},")
out.append("}")
with open(OUT, "w", encoding="utf-8") as f:
    f.write("\n".join(out) + "\n")
print(f"Scritto {OUT}: {len(needed)} classi, {len(used_enums)} Enum")
