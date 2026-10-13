"""Builds everything: Studio files (.rbxmx + .lua) and the preview PNGs.

Run:  python3 tools/build.py [--no-previews]
"""
import os
import sys
from xml.sax.saxutils import escape

import numpy as np
from PIL import Image

from animals import ANIMALS
from core import H, TIER_COLORS, Model, Part, rot_matrix
from eggs import EGGS, build_egg
from render import caption, fit_camera, render, to_image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
OUT_EGG = os.path.join(ROOT, 'previews', 'eggs')
OUT_ANI = os.path.join(ROOT, 'previews', 'animals')

PED_Y = 0.4  # models stand on top of the pedestal
SPACING = 12.0
COLS = 10

MAT_TOKEN = {
    'Plastic': 256, 'SmoothPlastic': 272, 'Neon': 288, 'Wood': 512, 'WoodPlanks': 528, 'Marble': 784, 'Slate': 800,
    'Concrete': 816, 'Granite': 832, 'Brick': 848, 'Pebble': 864, 'Cobblestone': 880, 'DiamondPlate': 1056,
    'Foil': 1072, 'Metal': 1088, 'Grass': 1280, 'Sand': 1296, 'Fabric': 1312, 'Ice': 1536, 'Glass': 1568,
}


def tier_list():
    return [(name, tier, fn, animal) for name, tier, fn, animal in EGGS]


def make_items():
    """Returns [(group, model, (x, z))] with models already carrying their pedestal."""
    items = []
    eggs = [build_egg(e) for e in EGGS]
    animals = []
    for i, fn in enumerate(ANIMALS):
        a = fn()
        a.tier = EGGS[i][1]
        animals.append(a)
    for group, models, z0 in (('Eggs', eggs, -52.0), ('Animals', animals, 4.0)):
        for i, m in enumerate(models):
            col, row = i % COLS, i // COLS
            x = (col - (COLS - 1) / 2) * SPACING
            z = z0 + row * SPACING
            items.append((group, with_pedestal(m), (x, z)))
    return items


def with_pedestal(m):
    out = Model(m.name, m.tier)
    tc = TIER_COLORS[m.tier]
    ped = [Part('cyl', (0, 0.2 - PED_Y, 0), (8.0, 0.4, 8.0), (0, 0, 0), '#3b4150', 'SmoothPlastic', 0),
           Part('cyl', (0, 0.45 - PED_Y, 0), (8.5, 0.1, 8.5), (0, 0, 0), tc, 'Neon', 0)]
    out.parts = ped + m.parts
    out.n_ped = 2
    return out


def shift(parts, dy):
    return [Part(p.kind, (p.pos[0], p.pos[1] + dy, p.pos[2]), p.size, p.rot, p.color, p.mat, p.tr) for p in parts]


# ---------------------------------------------------------------- previews
def render_model(m, W=520, ss=2):
    parts = [(p, (0, PED_Y, 0)) for p in m.parts]
    eye, tg = fit_camera(parts, margin=1.18)
    arr = render(parts, W * ss, W * ss, eye, tg)
    return to_image(arr, ss)


def previews(items):
    os.makedirs(OUT_EGG, exist_ok=True)
    os.makedirs(OUT_ANI, exist_ok=True)
    thumbs = {'Eggs': [], 'Animals': []}
    for idx, (group, m, _) in enumerate(items):
        i = idx % 30
        im = render_model(m)
        sub = 'hatches: ' + EGGS[i][3] if group == 'Eggs' else 'from: ' + EGGS[i][0]
        caption(im, f'{i + 1:02d}  {m.name}', f'{m.tier}   {sub}')
        folder = OUT_EGG if group == 'Eggs' else OUT_ANI
        path = os.path.join(folder, f'{i + 1:02d}_{m.name.replace(" ", "_")}.png')
        im.save(path)
        thumbs[group].append(im)
        print('preview', path, flush=True)
    for group, ims in thumbs.items():
        tw = 340
        cols, rows = 6, 5
        sheet = Image.new('RGB', (cols * tw, rows * (tw + 0)), (255, 255, 255))
        for k, im in enumerate(ims):
            t = im.resize((tw, int(im.height * tw / im.width)), Image.LANCZOS)
            sheet.paste(t, ((k % cols) * tw, (k // cols) * tw))
        sheet.save(os.path.join(ROOT, 'previews', f'ALL_{group.upper()}.png'))
    overview(items)


def overview(items):
    parts = []
    for _, m, (x, z) in items:
        parts += [(p, (x, PED_Y, z)) for p in m.parts]
    # baseplate
    base = Part('box', (0, -10, 0), (512, 20, 512), (0, 0, 0), '#6b8f5e', 'SmoothPlastic', 0)
    parts.append((base, (0, 0, 0)))
    W, Hh, ss = 1600, 900, 2
    eye, tg = np.array([0.0, 62.0, 78.0]), np.array([0.0, 0.0, -12.0])
    arr = render(parts, W * ss, Hh * ss, eye, tg, fov=50)
    to_image(arr, ss).save(os.path.join(ROOT, 'previews', 'OVERVIEW_baseplate.png'))
    print('overview done', flush=True)


# ---------------------------------------------------------------- exporters
def world_parts(m, x, z):
    return [Part(p.kind, (p.pos[0] + x, p.pos[1] + PED_Y, p.pos[2] + z), p.size, p.rot, p.color, p.mat, p.tr)
            for p in m.parts]


def roblox_cf(p):
    """Rotation matrix + size as Roblox expects them (cylinders have their axis on X)."""
    R = rot_matrix(*p.rot)
    size = p.size
    if p.kind == 'cyl':
        R = R @ rot_matrix(0, 0, 90)
        size = (p.size[1], p.size[0], p.size[2])
    return R, size


class Ref:
    n = 0

    @classmethod
    def next(cls):
        cls.n += 1
        return f'RBX{cls.n}'


def f(v):
    return f'{v:.4f}'.rstrip('0').rstrip('.') if abs(v) > 1e-9 else '0'


def part_xml(p, name, extra=''):
    R, size = roblox_cf(p)
    r, g, b = H(p.color)
    col = 0xFF000000 | (r << 16) | (g << 8) | b
    shape = 2 if p.kind == 'cyl' else 1
    mesh = ''
    if p.kind == 'ball':
        mesh = (f'<Item class="SpecialMesh" referent="{Ref.next()}"><Properties><string name="Name">BallMesh</string>'
                f'<token name="MeshType">3</token></Properties></Item>')
    cf = ''.join(f'<{k}>{f(v)}</{k}>' for k, v in zip(
        ('X', 'Y', 'Z'), p.pos)) + ''.join(
        f'<R{i}{j}>{f(R[i][j])}</R{i}{j}>' for i in range(3) for j in range(3))
    return (f'<Item class="Part" referent="{Ref.next()}"><Properties>'
            f'<string name="Name">{escape(name)}</string>'
            f'<CoordinateFrame name="CFrame">{cf}</CoordinateFrame>'
            f'<Vector3 name="size"><X>{f(size[0])}</X><Y>{f(size[1])}</Y><Z>{f(size[2])}</Z></Vector3>'
            f'<Color3uint8 name="Color3uint8">{col}</Color3uint8>'
            f'<token name="Material">{MAT_TOKEN[p.mat]}</token>'
            f'<token name="shape">{shape}</token>'
            f'<float name="Transparency">{f(p.tr)}</float>'
            f'<bool name="Anchored">true</bool>'
            f'<bool name="CanCollide">{"true" if name == "Pedestal" else "false"}</bool>'
            f'<token name="TopSurface">0</token><token name="BottomSurface">0</token>'
            f'</Properties>{mesh}{extra}</Item>')


def label_xml(text, tier, height):
    r, g, b = [c / 255 for c in H(TIER_COLORS[tier])]
    return (f'<Item class="BillboardGui" referent="{Ref.next()}"><Properties>'
            f'<string name="Name">NameTag</string>'
            f'<UDim2 name="Size"><XS>0</XS><XO>220</XO><YS>0</YS><YO>44</YO></UDim2>'
            f'<Vector3 name="StudsOffset"><X>0</X><Y>{f(height)}</Y><Z>0</Z></Vector3>'
            f'<float name="MaxDistance">140</float><bool name="AlwaysOnTop">false</bool></Properties>'
            f'<Item class="TextLabel" referent="{Ref.next()}"><Properties>'
            f'<string name="Name">Text</string><string name="Text">{escape(text)}</string>'
            f'<UDim2 name="Size"><XS>1</XS><XO>0</XO><YS>1</YS><YO>0</YO></UDim2>'
            f'<float name="BackgroundTransparency">1</float>'
            f'<Color3 name="TextColor3"><R>{f(r)}</R><G>{f(g)}</G><B>{f(b)}</B></Color3>'
            f'<bool name="TextScaled">true</bool><float name="TextStrokeTransparency">0</float>'
            f'</Properties></Item></Item>')


def export_rbxmx(items, path):
    groups = {'Eggs': [], 'Animals': []}
    for group, m, (x, z) in items:
        wp = world_parts(m, x, z)
        top = max(p.pos[1] + p.size[1] / 2 for p in wp) + 1.5 - PED_Y
        xs = []
        for k, p in enumerate(wp):
            if k == 0:
                xs.append(part_xml(p, 'Pedestal', label_xml(m.name, m.tier, top)))
            elif k == 1:
                xs.append(part_xml(p, 'TierRing'))
            else:
                xs.append(part_xml(p, 'Part'))
        groups[group].append(f'<Item class="Model" referent="{Ref.next()}"><Properties>'
                             f'<string name="Name">{escape(m.name)}</string></Properties>{"".join(xs)}</Item>')
    body = ''.join(
        f'<Item class="Folder" referent="{Ref.next()}"><Properties><string name="Name">{g}</string></Properties>'
        f'{"".join(v)}</Item>' for g, v in groups.items())
    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation='
           '"http://www.roblox.com/roblox.xsd" version="4"><Meta name="ExplicitAutoJoints">true</Meta>'
           f'<Item class="Folder" referent="{Ref.next()}"><Properties><string name="Name">EggsAndAnimals</string>'
           f'</Properties>{body}</Item></roblox>')
    with open(path, 'w') as fh:
        fh.write(xml)


LUA_HEAD = '''--[[
  Steal an Egg style pack: 30 eggs + 30 animals (Roblox simple style).

  HOW TO USE (pick one):
  A) Roblox Studio > open a Baseplate > View > Command Bar > paste this whole file > Enter.
     The models appear straight away in Workspace (folder "EggsAndAnimals").
  B) Put this file in a Script inside ServerScriptService and press Play.
]]

local DATA = [==[
'''

LUA_TAIL = ''']==]

local MATS = {}
for _, name in ipairs({"Plastic","SmoothPlastic","Neon","Wood","WoodPlanks","Marble","Slate","Concrete","Granite",
	"Brick","Pebble","Cobblestone","DiamondPlate","Foil","Metal","Grass","Sand","Fabric","Ice","Glass"}) do
	MATS[name] = Enum.Material[name]
end
local TIER = {Common=Color3.fromRGB(191,197,204), Uncommon=Color3.fromRGB(94,224,106), Rare=Color3.fromRGB(74,168,255),
	Epic=Color3.fromRGB(180,104,255), Legendary=Color3.fromRGB(255,201,51), Mythic=Color3.fromRGB(255,74,74)}

local old = workspace:FindFirstChild("EggsAndAnimals")
if old then old:Destroy() end
local root = Instance.new("Folder"); root.Name = "EggsAndAnimals"
local groups = {}
local model, labelHeight, tier, modelName

local function addLabel(part)
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"; gui.Size = UDim2.new(0, 220, 0, 44); gui.StudsOffset = Vector3.new(0, labelHeight, 0)
	gui.MaxDistance = 140; gui.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 1, 0); t.BackgroundTransparency = 1; t.Text = modelName; t.TextScaled = true
	t.TextColor3 = TIER[tier]; t.TextStrokeTransparency = 0; t.Parent = gui
end

for line in DATA:gmatch("[^\\n]+") do
	local f = line:split("|")
	if f[1] == "M" then
		local g = groups[f[2]]
		if not g then g = Instance.new("Folder"); g.Name = f[2]; g.Parent = root; groups[f[2]] = g end
		model = Instance.new("Model"); model.Name = f[3]; model.Parent = g
		modelName, tier, labelHeight = f[3], f[4], tonumber(f[5])
	else
		local n = function(i) return tonumber(f[i]) end
		local p = Instance.new("Part")
		p.Anchored = true; p.CanCollide = (f[16] == "Pedestal"); p.Name = f[16]
		p.Material = MATS[f[2]]; p.Color = Color3.fromRGB(n(3), n(4), n(5)); p.Transparency = n(15)
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		local cf = CFrame.new(n(6), n(7), n(8)) * CFrame.Angles(math.rad(n(12)), math.rad(n(13)), math.rad(n(14)))
		if f[1] == "c" then
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(n(10), n(9), n(11))
			cf = cf * CFrame.Angles(0, 0, math.pi / 2)
		else
			p.Size = Vector3.new(n(9), n(10), n(11))
			if f[1] == "o" then
				local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.Sphere; mesh.Parent = p
			end
		end
		p.CFrame = cf
		p.Parent = model
		if f[16] == "Pedestal" then addLabel(p) end
	end
end
root.Parent = workspace
print("Eggs and animals spawned!")
'''


def export_lua(items, path):
    lines = []
    for group, m, (x, z) in items:
        wp = world_parts(m, x, z)
        top = max(p.pos[1] + p.size[1] / 2 for p in wp) + 1.5 - PED_Y
        lines.append(f'M|{group}|{m.name}|{m.tier}|{f(top)}')
        for k, p in enumerate(wp):
            kind = {'box': 'b', 'ball': 'o', 'cyl': 'c'}[p.kind]
            r, g, b = H(p.color)
            name = 'Pedestal' if k == 0 else ('TierRing' if k == 1 else 'Part')
            lines.append('|'.join([kind, p.mat, str(r), str(g), str(b), *[f(v) for v in p.pos], *[f(v) for v in p.size],
                                   *[f(v) for v in p.rot], f(p.tr), name]))
    with open(path, 'w') as fh:
        fh.write(LUA_HEAD + '\n'.join(lines) + '\n' + LUA_TAIL)


if __name__ == '__main__':
    items = make_items()
    export_rbxmx(items, os.path.join(ROOT, 'EggsAndAnimals.rbxmx'))
    export_lua(items, os.path.join(ROOT, 'EggsAndAnimals.lua'))
    print('files written; parts:', sum(len(m.parts) for _, m, _ in items))
    if '--no-previews' not in sys.argv:
        previews(items)
