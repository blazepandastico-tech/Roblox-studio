--[[
	Esporta l'interfaccia del gioco per tools/ui_photo.py (foto dei menu senza Roblox Studio).
	Le schermate si costruiscono con il codice vero del gioco nel Roblox finto delle prove; le
	animazioni (Tween) arrivano subito alla fine e un orologio finto fa scattare task.delay e task.wait
	in ordine fino al momento della foto (es. 6,5 s dopo l'inizio del titolo di un evento).
	Ingresso: UI_SCENE = "titolo" | "admin" | "evento" | "striscione"
	Uscita: una riga per ogni elemento (O), testo (T), angoli (C), sfumature (G), bordi (S),
	proporzioni (A), scale (K), liste (L), griglie (R), margini (P) e limiti del testo (M).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SCENE = UI_SCENE or "titolo"
local WIDTH, HEIGHT = 1920, 1080

-- le animazioni arrivano subito alla fine
local create = rawget(TweenService, "Create")
rawset(TweenService, "Create", function(self, inst, info, goals)
	local t = create(self, inst, info, goals)
	t.Play = function()
		for key, value in goals do
			(inst :: any)[key] = value
		end
	end
	return t
end)
-- orologio finto: task.delay e task.wait aspettano il loro turno, così la foto si scatta al momento giusto
-- dell'animazione (es. il titolo dell'evento già sullo schermo ma non ancora sparito)
local now = 0
local queue: { { T: number, S: number, Run: () -> () } } = {}
local seq = 0
local function push(t: number?, run: () -> ())
	seq += 1
	table.insert(queue, { T = now + math.max(t or 0, 0), S = seq, Run = run })
end
local function resume(co: thread, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		LOG("ERRORE nell'animazione: " .. tostring(err))
	end
end
MOCK_HOOKS.Clock = function()
	return now
end
MOCK_HOOKS.Spawn = function(fn, ...)
	resume(coroutine.create(fn), ...)
end
MOCK_HOOKS.Delay = function(t, fn, ...)
	local args = table.pack(...)
	push(t, function()
		resume(coroutine.create(fn), table.unpack(args, 1, args.n))
	end)
end
MOCK_HOOKS.Wait = function(t)
	local co = coroutine.running()
	if co and coroutine.isyieldable() then
		local waitFor = if type(t) == "number" and t > 0 then t else 1 / 60
		push(waitFor, function()
			resume(co, waitFor)
		end)
		return coroutine.yield()
	end
	return t or 0
end

local player = Instance.new("Player")
player.Name = "Fotografo"
player.DisplayName = "Fotografo"
player.UserId = 4242
Players.LocalPlayer = player
local playerGui = Instance.new("PlayerGui")
playerGui.Name = "PlayerGui"
playerGui.Parent = player
local scripts = Instance.new("PlayerScripts")
scripts.Name = "PlayerScripts"
scripts.Parent = player
local camera = Instance.new("Camera")
camera.ViewportSize = Vector2.new(WIDTH, HEIGHT)
camera.CFrame = CFrame.new(0, 20, 30)
workspace.CurrentCamera = camera
local character = Instance.new("Model")
character.Name = player.Name
local hrp = Instance.new("Part")
hrp.Name = "HumanoidRootPart"
hrp.Size = Vector3.new(2, 2, 1)
hrp.CFrame = CFrame.new(0, 10, 0)
hrp.Parent = character
character.PrimaryPart = hrp
character.Parent = workspace
player.Character = character

local C: any = {}
local function load(group: string, name: string)
	local ok, result = pcall(require, (CLIENT :: any)[group][name])
	if not ok then
		LOG("ERRORE caricamento " .. name .. ": " .. tostring(result))
		return nil
	end
	C[name] = result
	return result
end
load("Controllers", "ClientData")
load("UI", "UIController")
load("Controllers", "InputController")
C.Notifications = { Toast = function() end, Announce = function() end, ZoneBanner = function() end }
C.SoundController = { Play = function() end, Loop = function() end }
C.CameraController = {
	BaseFov = 70,
	IsCinematic = function()
		return false
	end,
	SetCursorMode = function() end,
	Shake = function() end,
	SetCinematic = function() end,
	CinematicShake = function()
		return CFrame.identity
	end,
}
C.HUD = { SetVisible = function() end, ObjectivePosition = function()
	return Vector3.zero
end }
C.Dialogue = { IsOpen = function()
	return false
end }
C.ClientData.Ready = true
C.ClientData.Profile = { Level = 1, Story = { Chapter = 1, Step = 1, Done = false }, Settings = {}, Gems = 0, Gold = 250 }

local order = { "ClientData", "UIController", "InputController" }
local function start(names: { string })
	for _, name in names do
		table.insert(order, name)
	end
	for _, name in order do
		local m = C[name]
		if m and m.Init then
			local ok, err = pcall(m.Init, C)
			if not ok then
				LOG("ERRORE " .. name .. ".Init: " .. tostring(err))
			end
		end
	end
	for _, name in order do
		local m = C[name]
		if m and m.Start then
			local ok, err = pcall(m.Start, C)
			if not ok then
				LOG("ERRORE " .. name .. ".Start: " .. tostring(err))
			end
		end
	end
end

-- fa passare il tempo fino a "until" secondi: le azioni in ritardo scattano in ordine, a ogni fotogramma
-- girano RenderStepped e Heartbeat
local function runUntil(untilTime: number, dt: number?)
	local step = dt or 1 / 30
	while now < untilTime do
		local frameEnd = math.min(untilTime, now + step)
		while true do
			table.sort(queue, function(a, b)
				if a.T ~= b.T then
					return a.T < b.T
				end
				return a.S < b.S
			end)
			local first = queue[1]
			if not first or first.T > frameEnd then
				break
			end
			table.remove(queue, 1)
			now = math.max(now, first.T)
			first.Run()
		end
		now = frameEnd
		RunService.RenderStepped:Fire(step)
		RunService.Heartbeat:Fire(step)
	end
end

if SCENE == "titolo" then
	load("UI", "Intro")
	start({ "Intro" })
	runUntil(6)
elseif SCENE == "admin" then
	load("UI", "AdminPanel")
	load("Controllers", "AbuseEventController")
	player:SetAttribute("Admin", true)
	-- due eventi programmati, per vedere la lista
	local AbuseEvents = require(SHARED.Data.AbuseEvents)
	local list = {}
	for i = 1, 2 do
		local def = AbuseEvents.List[i]
		table.insert(list, { Uid = "foto-" .. i, Event = def.Id, Minutes = if i == 1 then 30 else 15, At = os.time() + 3600 * (2 + i * 20), Text = if i == 1 then "Stasera tutti alle Pianure Meridionali! Premi per tutti 🎃" else "", By = "matyy_pandini", Rewards = { Dolcetti = true, Partecipazione = true } })
	end
	ReplicatedStorage:SetAttribute("ProgrammaEventi", game:GetService("HttpService"):JSONEncode(list))
	start({ "AdminPanel", "AbuseEventController" })
	C.UIController.Open("Admin")
	for _, d in playerGui:GetDescendants() do
		if d:IsA("TextButton") and d.Text == "😈 Admin Abuse" then
			d.Activated:Fire()
		end
	end
	runUntil(1)
elseif SCENE == "evento" or SCENE == "striscione" then
	load("Controllers", "AbuseEventController")
	start({ "AbuseEventController" })
	local AbuseEvents = require(SHARED.Data.AbuseEvents)
	local id = UI_EVENT or AbuseEvents.List[1].Id
	ReplicatedStorage:SetAttribute("AbusePremi", "Dolcetti,Partecipazione")
	ReplicatedStorage:SetAttribute("AbuseAnnuncio", "Stasera tutti alle Pianure Meridionali! — matyy_pandini")
	if SCENE == "evento" then
		-- un evento "vecchio" non fa partire da solo l'animazione con la regia: si fa partire qui solo il titolo
		ReplicatedStorage:SetAttribute("AbuseInizio", workspace:GetServerTimeNow() - 100)
		ReplicatedStorage:SetAttribute("AbuseEvento", id)
		-- solo il titolo (senza la regia sul set): i testi e il conto dei minuti
		C.AbuseEventController.PlayIntro(id, 15, false)
		-- poco prima che il titolo sparisca (6,6 s senza regia): testo quasi tutto scritto
		runUntil(6.5)
	else
		local okH = pcall(function()
			-- lo striscione con il conto alla rovescia (dopo l'animazione)
			ReplicatedStorage:SetAttribute("AbuseEvento", id)
			ReplicatedStorage:SetAttribute("AbuseInizio", workspace:GetServerTimeNow() - 600)
			ReplicatedStorage:SetAttribute("AbuseFine", workspace:GetServerTimeNow() + 754)
			ReplicatedStorage:SetAttribute("AbuseDurata", 1800)
		end)
		local _ = okH
		runUntil(1)
		local root = C.UIController.Layers.Top:FindFirstChild("EventoAdminAbuse")
		if root then
			root.Visible = false
		end
		-- il HUD si accende dopo la schermata del titolo
		C.UIController.Layers.HUD.Visible = true
		runUntil(2)
	end
end

-- ESPORTAZIONE ----------------------------------------------------------------------------------------------
local ids: { [Instance]: number } = {}
local nextId = 0
local out = {}
local function f(n: number): string
	return string.format("%.4f", n)
end
local function c3(c: Color3): string
	return f(c.R) .. "\t" .. f(c.G) .. "\t" .. f(c.B)
end
local function u2(u: UDim2): string
	return f(u.X.Scale) .. "\t" .. f(u.X.Offset) .. "\t" .. f(u.Y.Scale) .. "\t" .. f(u.Y.Offset)
end
local function clean(text: string): string
	return (string.gsub(string.gsub(text, "\t", " "), "\n", "\\n"))
end
local function keys(seq: any, isColor: boolean): string
	local parts = {}
	for _, k in seq.Keypoints do
		if isColor then
			table.insert(parts, f(k.Time) .. ":" .. f(k.Value.R) .. ":" .. f(k.Value.G) .. ":" .. f(k.Value.B))
		else
			table.insert(parts, f(k.Time) .. ":" .. f(k.Value))
		end
	end
	return table.concat(parts, ",")
end

-- il Roblox finto dà valori di partenza "vuoti" (false, 0...): qui servono quelli veri di Roblox
local ROBLOX_DEFAULTS: { [string]: any } = {
	Visible = true,
	ZIndex = 1,
	LayoutOrder = 0,
	Position = UDim2.new(),
	AnchorPoint = Vector2.new(0, 0),
	Rotation = 0,
	BackgroundColor3 = Color3.fromRGB(163, 162, 165),
	BackgroundTransparency = 0,
	ClipsDescendants = false,
	TextSize = 14,
	TextScaled = false,
	TextColor3 = Color3.fromRGB(27, 42, 53),
	TextTransparency = 0,
	TextWrapped = false,
	TextStrokeColor3 = Color3.new(0, 0, 0),
	TextStrokeTransparency = 1,
	PlaceholderColor3 = Color3.fromRGB(178, 178, 178),
	Thickness = 1,
	Transparency = 0,
	Color = Color3.new(0, 0, 0),
	AspectRatio = 1,
	Scale = 1,
	Enabled = true,
	DisplayOrder = 0,
}
local function p(inst: Instance, key: string, default: any?): any
	local props = rawget(inst :: any, "__props")
	local value = props and props[key]
	if value == nil then
		if default ~= nil then
			return default
		end
		return ROBLOX_DEFAULTS[key]
	end
	return value
end
local function enumName(inst: Instance, key: string, default: string): string
	local value = p(inst, key)
	return if value then value.Name else default
end

local function visit(inst: Instance, parentId: number)
	local id = parentId
	if inst:IsA("GuiObject") or inst:IsA("ScreenGui") then
		nextId += 1
		id = nextId
		ids[inst] = id
		if inst:IsA("ScreenGui") then
			-- lo schermo intero: l'ordine delle ScreenGui va nel posto di ZIndex
			table.insert(out, table.concat({ "O", tostring(id), "0", "ScreenGui", clean(inst.Name), tostring(p(inst, "Enabled")), tostring(p(inst, "DisplayOrder")), "0", u2(UDim2.new()), u2(UDim2.fromScale(1, 1)), f(0), f(0), f(0), c3(Color3.new()), f(1), "false", "None" }, "\t"))
		else
			local isText = inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox")
			local defaultSize = if isText then UDim2.fromOffset(200, 50) else UDim2.fromOffset(100, 100)
			local anchor = p(inst, "AnchorPoint")
			table.insert(out, table.concat({ "O", tostring(id), tostring(parentId), inst.ClassName, clean(inst.Name), tostring(p(inst, "Visible")), tostring(p(inst, "ZIndex")), tostring(p(inst, "LayoutOrder")), u2(p(inst, "Position")), u2(p(inst, "Size", defaultSize)), f(anchor.X), f(anchor.Y), f(p(inst, "Rotation")), c3(p(inst, "BackgroundColor3")), f(p(inst, "BackgroundTransparency")), tostring(p(inst, "ClipsDescendants") == true or inst:IsA("ScrollingFrame")), enumName(inst, "AutomaticSize", "None") }, "\t"))
			if isText then
				local text = p(inst, "Text", "")
				local color = p(inst, "TextColor3")
				if inst:IsA("TextBox") and text == "" then
					text = p(inst, "PlaceholderText", "")
					color = p(inst, "PlaceholderColor3")
				end
				table.insert(out, table.concat({ "T", tostring(id), clean(text), enumName(inst, "Font", "SourceSans"), f(p(inst, "TextSize")), tostring(p(inst, "TextScaled") == true), c3(color), f(p(inst, "TextTransparency")), enumName(inst, "TextXAlignment", "Center"), enumName(inst, "TextYAlignment", "Center"), tostring(p(inst, "TextWrapped") == true), c3(p(inst, "TextStrokeColor3")), f(p(inst, "TextStrokeTransparency")) }, "\t"))
			end
		end
	elseif parentId > 0 then
		if inst:IsA("UICorner") then
			local r = p(inst, "CornerRadius", UDim.new(0, 8))
			table.insert(out, table.concat({ "C", tostring(parentId), f(r.Scale), f(r.Offset) }, "\t"))
		elseif inst:IsA("UIGradient") then
			local offset = p(inst, "Offset", Vector2.new())
			local color = p(inst, "Color", ColorSequence.new(Color3.new(1, 1, 1)))
			local transparency = p(inst, "Transparency", NumberSequence.new(0))
			table.insert(out, table.concat({ "G", tostring(parentId), f(p(inst, "Rotation")), f(offset.X), f(offset.Y), keys(color, true), keys(transparency, false) }, "\t"))
		elseif inst:IsA("UIStroke") then
			table.insert(out, table.concat({ "S", tostring(parentId), c3(p(inst, "Color")), f(p(inst, "Thickness")), f(p(inst, "Transparency")), enumName(inst, "ApplyStrokeMode", "Contextual") }, "\t"))
		elseif inst:IsA("UIAspectRatioConstraint") then
			table.insert(out, table.concat({ "A", tostring(parentId), f(p(inst, "AspectRatio")), enumName(inst, "DominantAxis", "Width") }, "\t"))
		elseif inst:IsA("UIScale") then
			table.insert(out, table.concat({ "K", tostring(parentId), f(p(inst, "Scale")) }, "\t"))
		elseif inst:IsA("UIListLayout") then
			local pad = p(inst, "Padding", UDim.new())
			table.insert(out, table.concat({ "L", tostring(parentId), enumName(inst, "FillDirection", "Vertical"), f(pad.Scale), f(pad.Offset), enumName(inst, "HorizontalAlignment", "Left"), enumName(inst, "VerticalAlignment", "Top") }, "\t"))
		elseif inst:IsA("UIGridLayout") then
			table.insert(out, table.concat({ "R", tostring(parentId), u2(p(inst, "CellSize", UDim2.fromOffset(100, 100))), u2(p(inst, "CellPadding", UDim2.fromOffset(5, 5))) }, "\t"))
		elseif inst:IsA("UIPadding") then
			local function o(key: string): string
				local v = p(inst, key, UDim.new())
				return f(v.Offset)
			end
			table.insert(out, table.concat({ "P", tostring(parentId), o("PaddingTop"), o("PaddingBottom"), o("PaddingLeft"), o("PaddingRight") }, "\t"))
		elseif inst:IsA("UITextSizeConstraint") then
			table.insert(out, table.concat({ "M", tostring(parentId), f(p(inst, "MaxTextSize", 100)) }, "\t"))
		end
	end
	for _, child in inst:GetChildren() do
		visit(child, id)
	end
end

for _, gui in playerGui:GetChildren() do
	if gui:IsA("ScreenGui") then
		visit(gui, 0)
	end
end
LOG(table.concat(out, "\n"))
LOG(("FINE\t%d\t%d\t%d"):format(nextId, WIDTH, HEIGHT))
