#!/usr/bin/env python3
"""Genera Install.lua: un unico script da incollare nel Command Bar di Roblox Studio.
Crea nel place aperto: ShopMenu + ShopStore (StarterGui), ShopConfig, ShopServer, ShopClient.
Prima: python3 tools/gen_ui.py
"""
import json, os

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "src")


def rd(p):
    return open(os.path.join(SRC, p), encoding="utf-8").read()


def lstr(s):
    for n in range(1, 10):
        eq = "=" * n
        if f"]{eq}]" not in s and f"[{eq}[" not in s:
            return f"[{eq}[\n{s}]{eq}]"
    raise SystemExit("long string non possibile")


def gui(f):
    return json.dumps(json.load(open(os.path.join(SRC, "gui", f), encoding="utf-8")),
                      ensure_ascii=False, separators=(",", ":"))


lua = f'''-- Incolla TUTTO questo nel Command Bar di Studio (View > Command Bar) e premi Invio.
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SP = game:GetService("StarterPlayer")

local ENUMS = {{ZIndexBehavior = Enum.ZIndexBehavior, ApplyStrokeMode = Enum.ApplyStrokeMode,
	TextXAlignment = Enum.TextXAlignment, ScaleType = Enum.ScaleType, Font = Enum.Font}}
local COLORS = {{BackgroundColor3 = true, TextColor3 = true, Color = true}}

local function build(node, overrides)
	local inst = Instance.new(node.ClassName)
	inst.Name = node.Name
	local props = node.Properties or {{}}
	for k, v in pairs(overrides or {{}}) do props[k] = v end
	for k, v in pairs(props) do
		if ENUMS[k] then
			inst[k] = ENUMS[k][v]
		elseif COLORS[k] then
			inst[k] = Color3.new(v[1], v[2], v[3])
		elseif k == "CornerRadius" then
			inst[k] = UDim.new(v[1], v[2])
		elseif k == "AnchorPoint" then
			inst[k] = Vector2.new(v[1], v[2])
		elseif type(v) == "table" then
			inst[k] = UDim2.new(v[1][1], v[1][2], v[2][1], v[2][2])
		else
			inst[k] = v
		end
	end
	for _, child in ipairs(node.Children or {{}}) do
		build(child).Parent = inst
	end
	return inst
end

local function put(parent, name)
	local old = parent:FindFirstChild(name)
	if old then old:Destroy() end
end

local function script(class, name, parent, source)
	put(parent, name)
	local s = Instance.new(class)
	s.Name = name
	s.Source = source
	s.Parent = parent
end

-- UI
for _, entry in ipairs({{
	{{ json = {lstr(gui("ShopMenu.model.json"))}, over = {{}} }},
	{{ json = {lstr(gui("ShopStore.model.json"))}, over = {{ Enabled = true }} }},
}}) do
	local node = HttpService:JSONDecode(entry.json)
	put(StarterGui, node.Name)
	build(node, entry.over).Parent = StarterGui
end

-- Script
local shared = RS:FindFirstChild("Shared") or Instance.new("Folder")
shared.Name = "Shared"
shared.Parent = RS
script("ModuleScript", "ShopConfig", shared, {lstr(rd("shared/ShopConfig.lua"))})
script("Script", "ShopServer", SSS, {lstr(rd("server/ShopServer.server.lua"))})
script("LocalScript", "ShopClient", SP:WaitForChild("StarterPlayerScripts"), {lstr(rd("client/ShopClient.client.lua"))})

print("Shop installato! Guarda StarterGui > ShopMenu e ShopStore.")
'''
with open(os.path.join(ROOT, "Install.lua"), "w", encoding="utf-8") as f:
    f.write(lua)
print("ok", len(lua))
