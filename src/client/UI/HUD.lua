--[[
	HUD - l'interfaccia di gioco
	  in alto a sinistra : livello, esperienza, oro, stirpe
	  in basso a sinistra: salute, gas dei Rampini, lame, munizioni, energia del gigante
	  in basso al centro : abilità Z X C V con ricarica
	  al centro          : mirino (verde = rampino in portata, oro = nuca!)
	  in alto al centro  : bussola con l'obiettivo della storia, barra del boss
	  in alto a destra   : obiettivo della storia e missione attiva
	  su telefono        : pulsanti touch per tutte le azioni
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Lib.Util)
local Leveling = require(Shared.Data.Leveling)
local Story = require(Shared.Data.Story)
local Quests = require(Shared.Data.Quests)
local Zones = require(Shared.Data.Zones)
local NPCs = require(Shared.Data.NPCs)
local Titans = require(Shared.Data.Titans)
local Enemies = require(Shared.Data.Enemies)
local Skills = require(Shared.Data.Skills)
local Serums = require(Shared.Data.Serums)
local Bloodlines = require(Shared.Data.Bloodlines)

local Theme = require(script.Parent.Theme)
local New = Theme.New
local Colors = Theme.Colors

local HUD = {}
local C
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local root: Frame
local refs: any = {}
local titanMode = false
local titanSerum: string? = nil
local mashCount = 0
local mashNeeded = 12
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- PANNELLO DEL GIOCATORE ----------------------------------------------------------------------

local function buildPlayerPanel()
	local panel = Theme.Panel({ Name = "Giocatore", Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(320, 108), Parent = root })
	C.UIController.AttachScale(panel)
	local badge = New("Frame", { BackgroundColor3 = Colors.Background, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(72, 72), Parent = panel })
	Theme.Corner(badge, 36)
	Theme.Stroke(badge, Colors.Gold, 2.5, 0)
	Theme.Gradient(badge, Color3.fromRGB(90, 70, 40), Color3.fromRGB(30, 22, 16), 90)
	New("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 10), Font = Theme.Fonts.UI, TextSize = 12, TextColor3 = Colors.TextDim, Text = "LIVELLO", Parent = badge })
	refs.Level = New("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 26), Font = Theme.Fonts.Number, TextSize = 30, TextColor3 = Colors.GoldBright, Text = "1", Parent = badge })
	refs.Name = Theme.Label(player.DisplayName, { Position = UDim2.fromOffset(94, 8), Size = UDim2.new(1, -104, 0, 22), Font = Theme.Fonts.Header, TextSize = 18, TextTruncate = Enum.TextTruncate.AtEnd, Parent = panel })
	refs.Bloodline = Theme.Label("", { Position = UDim2.fromOffset(94, 30), Size = UDim2.new(1, -104, 0, 16), Font = Theme.Fonts.UI, TextSize = 13, TextColor3 = Colors.TextDim, Parent = panel })
	local xpBar, setXP = Theme.Bar({ Position = UDim2.fromOffset(94, 52), Size = UDim2.new(1, -104, 0, 10), Parent = panel }, Colors.XP)
	refs.SetXP = setXP
	refs.XPText = Theme.Label("", { Position = UDim2.fromOffset(94, 64), Size = UDim2.new(0.5, -50, 0, 16), Font = Theme.Fonts.UI, TextSize = 12, TextColor3 = Colors.XP, Parent = panel })
	refs.Gold = Theme.Label("💰 0", { Position = UDim2.fromOffset(94, 84), Size = UDim2.fromOffset(110, 16), Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = Colors.GoldBright, Parent = panel })
	refs.Gems = Theme.Label("💎 0", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 84), Size = UDim2.fromOffset(100, 16), TextXAlignment = Enum.TextXAlignment.Right, Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = Color3.fromRGB(140, 220, 255), Parent = panel })
	refs.Points = Theme.Label("", { Position = UDim2.fromOffset(16, 120), Size = UDim2.fromOffset(300, 18), Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = Colors.GreenBright, Parent = panel })
	xpBar.Name = "XP"
end

-- BARRE ---------------------------------------------------------------------------------------

local function barRow(parent: Instance, y: number, icon: string, color: Color3, label: string)
	Theme.Label(icon, { Position = UDim2.fromOffset(10, y - 2), Size = UDim2.fromOffset(24, 22), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 16, Font = Theme.Fonts.Bold, Parent = parent })
	local bar, set = Theme.Bar({ Position = UDim2.fromOffset(38, y), Size = UDim2.new(1, -48, 0, 16), Parent = parent }, color)
	local text = Theme.Label(label, { Position = UDim2.fromOffset(44, y), Size = UDim2.new(1, -60, 0, 16), Font = Theme.Fonts.Bold, TextSize = 12, TextColor3 = Colors.White, TextStrokeTransparency = 0.5, ZIndex = 3, Parent = parent })
	bar.ZIndex = 2
	return set, text, bar
end

local function buildBars()
	local panel = Theme.Panel({ Name = "Barre", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -16), Size = UDim2.fromOffset(330, 150), Parent = root })
	C.UIController.AttachScale(panel)
	refs.SetHP, refs.HPText = barRow(panel, 12, "❤️", Colors.Health, "Salute")
	refs.SetGas, refs.GasText = barRow(panel, 36, "💨", Colors.Gas, "Gas")
	local energySet, energyText, energyBar = barRow(panel, 60, "⚡", Colors.Energy, "Energia del Gigante")
	refs.SetEnergy, refs.EnergyText, refs.EnergyBar = energySet, energyText, energyBar
	-- lame: 8 tacche + ricambi
	Theme.Label("⚔️", { Position = UDim2.fromOffset(10, 86), Size = UDim2.fromOffset(24, 22), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 16, Parent = panel })
	local notches = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(38, 88), Size = UDim2.new(1, -120, 0, 16), Parent = panel })
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3), Parent = notches })
	refs.Notches = {}
	for i = 1, 10 do
		local n = New("Frame", { BackgroundColor3 = Color3.fromRGB(210, 220, 230), BorderSizePixel = 0, Size = UDim2.fromOffset(16, 16), LayoutOrder = i, Parent = notches })
		Theme.Corner(n, 3)
		table.insert(refs.Notches, n)
	end
	refs.Spares = Theme.Label("x0", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 88), Size = UDim2.fromOffset(80, 16), TextXAlignment = Enum.TextXAlignment.Right, Font = Theme.Fonts.Bold, TextSize = 13, Parent = panel })
	refs.Ammo = Theme.Label("", { Position = UDim2.fromOffset(12, 112), Size = UDim2.new(1, -24, 0, 18), Font = Theme.Fonts.UI, TextSize = 13, TextColor3 = Colors.TextDim, Parent = panel })
	refs.Hint = Theme.Label("", { Position = UDim2.fromOffset(12, 128), Size = UDim2.new(1, -24, 0, 16), Font = Theme.Fonts.UI, TextSize = 12, TextColor3 = Colors.RedBright, Parent = panel })
end

-- ABILITÀ --------------------------------------------------------------------------------------

local function buildSkillBar()
	local bar = New("Frame", { Name = "Abilita", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(4 * 84 + 3 * 8, 84), BackgroundTransparency = 1, Parent = root })
	C.UIController.AttachScale(bar)
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = bar })
	refs.Skills = {}
	for i, key in Skills.Order do
		local slot = Theme.Panel({ Size = UDim2.fromOffset(84, 84), LayoutOrder = i, Parent = bar })
		local keyLabel = New("TextLabel", { BackgroundColor3 = Colors.Gold, Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(22, 22), Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = Colors.Background, Text = key, Parent = slot })
		Theme.Corner(keyLabel, 6)
		local name = Theme.Label("", { Position = UDim2.fromOffset(4, 30), Size = UDim2.new(1, -8, 0, 46), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Font = Theme.Fonts.Bold, TextSize = 12, Parent = slot })
		local shade = New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), ZIndex = 3, Parent = slot })
		Theme.Corner(shade, 10)
		local timer = Theme.Label("", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Number, TextSize = 26, ZIndex = 4, Parent = slot })
		local lock = Theme.Label("", { Position = UDim2.fromOffset(28, 4), Size = UDim2.new(1, -32, 0, 22), TextXAlignment = Enum.TextXAlignment.Right, Font = Theme.Fonts.UI, TextSize = 11, TextColor3 = Colors.TextDim, Parent = slot })
		refs.Skills[key] = { Slot = slot, Name = name, Shade = shade, Timer = timer, Lock = lock }
	end
end

-- MIRINO ----------------------------------------------------------------------------------------

local function buildCrosshair()
	local holder = New("Frame", { Name = "Mirino", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(44, 44), BackgroundTransparency = 1, Parent = root })
	local ring = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, Parent = holder })
	Theme.Corner(ring, 13)
	refs.CrossStroke = New("UIStroke", { Color = Colors.White, Thickness = 2, Transparency = 0.2, Parent = ring })
	refs.CrossDot = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(4, 4), BackgroundColor3 = Colors.White, BorderSizePixel = 0, Parent = holder })
	Theme.Corner(refs.CrossDot, 2)
	for i = 0, 3 do
		local tick = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Colors.White, BorderSizePixel = 0, Size = if i % 2 == 0 then UDim2.fromOffset(2, 8) else UDim2.fromOffset(8, 2), Position = ({ UDim2.new(0.5, 0, 0, 2), UDim2.new(1, -2, 0.5, 0), UDim2.new(0.5, 0, 1, -2), UDim2.new(0, 2, 0.5, 0) })[i + 1], Parent = holder })
		refs["Tick" .. i] = tick
	end
	refs.CrossLabel = Theme.Label("", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 4), Size = UDim2.fromOffset(160, 18), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Bold, TextSize = 13, TextStrokeTransparency = 0.4, Parent = holder })
	refs.Crosshair = holder
end

-- BUSSOLA ----------------------------------------------------------------------------------------

local COMPASS_POINTS = { { "N", 0 }, { "NE", 45 }, { "E", 90 }, { "SE", 135 }, { "S", 180 }, { "SO", 225 }, { "O", 270 }, { "NO", 315 } }

local function buildCompass()
	local holder = Theme.Panel({ Name = "Bussola", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(460, 54), Parent = root })
	C.UIController.AttachScale(holder)
	holder.ClipsDescendants = true
	refs.CompassMarks = {}
	for _, point in COMPASS_POINTS do
		local label = Theme.Label(point[1], { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(40, 22), Position = UDim2.fromOffset(0, 4), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Bold, TextSize = if #point[1] == 1 then 18 else 13, TextColor3 = if point[1] == "N" then Colors.RedBright else Colors.Text, Parent = holder })
		table.insert(refs.CompassMarks, { Label = label, Angle = point[2] })
	end
	New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(2, 26), BackgroundColor3 = Colors.Gold, BorderSizePixel = 0, Parent = holder })
	refs.Objective = Theme.Label("◆", { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(80, 22), Position = UDim2.fromOffset(0, 2), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Bold, TextSize = 20, TextColor3 = Colors.GoldBright, Visible = false, Parent = holder })
	refs.ZoneName = Theme.Label("", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 28), Size = UDim2.new(1, -20, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Header, TextSize = 14, TextColor3 = Colors.TextDim, Parent = holder })
	refs.Compass = holder
end

-- OBIETTIVI ------------------------------------------------------------------------------------

local function buildTracker()
	local panel = Theme.Panel({ Name = "Obiettivi", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), Size = UDim2.fromOffset(330, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = root })
	C.UIController.AttachScale(panel)
	Theme.Padding(panel, 10)
	New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel })
	refs.ChapterTitle = Theme.Label("", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Theme.Fonts.Header, TextSize = 15, TextColor3 = Colors.Gold, LayoutOrder = 1, Parent = panel })
	refs.StoryObjective = Theme.Label("", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Theme.Fonts.Body, TextSize = 14, LayoutOrder = 2, Parent = panel })
	refs.QuestTitle = Theme.Label("", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Theme.Fonts.Bold, TextSize = 13, TextColor3 = Colors.XP, LayoutOrder = 3, Parent = panel })
	local questBar, setQuest = Theme.Bar({ Size = UDim2.new(1, 0, 0, 8), LayoutOrder = 4, Parent = panel }, Colors.XP)
	refs.QuestBar, refs.SetQuest = questBar, setQuest
	refs.Tracker = panel
end

-- BARRA DEL BOSS ---------------------------------------------------------------------------------

local function buildBossBar()
	local holder = New("Frame", { Name = "Boss", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 78), Size = UDim2.fromOffset(620, 64), BackgroundTransparency = 1, Visible = false, Parent = root })
	C.UIController.AttachScale(holder)
	refs.BossName = Theme.Label("", { Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Title, TextSize = 30, TextColor3 = Color3.fromRGB(255, 150, 120), TextStrokeTransparency = 0.3, Parent = holder })
	local bar, set = Theme.Bar({ Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 14), Parent = holder }, Color3.fromRGB(200, 40, 40))
	refs.SetBoss = set
	refs.BossInfo = Theme.Label("", { Position = UDim2.fromOffset(0, 47), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.UI, TextSize = 13, TextColor3 = Colors.Text, Parent = holder })
	bar.Name = "Vita"
	refs.Boss = holder
end

-- PRESA DI UN GIGANTE -------------------------------------------------------------------------------

local function buildMash()
	local holder = New("Frame", { Name = "Liberati", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(420, 110), BackgroundTransparency = 1, Visible = false, Parent = root })
	C.UIController.AttachScale(holder)
	refs.MashText = Theme.Label(if isMobile then "TOCCA RIPETUTAMENTE!" else "PREMI SPAZIO RIPETUTAMENTE!", { Size = UDim2.new(1, 0, 0, 50), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Title, TextSize = 40, TextColor3 = Colors.RedBright, TextStrokeTransparency = 0.2, Parent = holder })
	refs.MashScale = New("UIScale", { Parent = refs.MashText })
	local _, set = Theme.Bar({ Position = UDim2.fromOffset(40, 60), Size = UDim2.new(1, -80, 0, 18), Parent = holder }, Colors.GoldBright)
	refs.SetMash = set
	if isMobile then
		Theme.Button("💪 LIBERATI", { Position = UDim2.new(0.5, -70, 0, 84), Size = UDim2.fromOffset(140, 40), Parent = holder }, function()
			C.InputController.Trigger("Boost", true)
			C.InputController.Trigger("Boost", false)
		end)
	end
	refs.Mash = holder
end

-- LINEE DI VELOCITÀ ---------------------------------------------------------------------------------

local function buildSpeedLines()
	local holder = New("Frame", { Name = "Velocita", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = root })
	refs.SpeedLines = {}
	for i = 1, 26 do
		local angle = (i / 26) * math.pi * 2
		local line = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Colors.White,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(2, 120),
			Rotation = math.deg(angle) + 90,
			Parent = holder,
		})
		table.insert(refs.SpeedLines, { Frame = line, Angle = angle, Offset = math.random() })
	end
	refs.SpeedHolder = holder
end

-- SCHERMATA DI MORTE ---------------------------------------------------------------------------------

local function buildDeath()
	local holder = New("Frame", { Name = "Morte", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(60, 0, 0), BackgroundTransparency = 1, Visible = false, Parent = root })
	refs.DeathTitle = Theme.Label("", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(900, 80), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Title, TextSize = 64, TextColor3 = Colors.RedBright, TextStrokeTransparency = 0.3, Parent = holder })
	refs.DeathSub = Theme.Label("", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(800, 30), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Body, TextSize = 20, Parent = holder })
	refs.Death = holder
end

local function showDeath(eaten: boolean)
	local holder = refs.Death
	holder.Visible = true
	holder.BackgroundTransparency = 1
	Theme.Tween(holder, 1, { BackgroundTransparency = 0.45 })
	refs.DeathTitle.Text = if eaten then "SEI STATO DIVORATO" else "SEI CADUTO IN BATTAGLIA"
	task.spawn(function()
		for i = Config.Player.RespawnDelay, 1, -1 do
			refs.DeathSub.Text = ("Sei caduto in battaglia... rinasci tra %d"):format(i)
			task.wait(1)
		end
	end)
end

-- PULSANTI DEL MENU E TOUCH ---------------------------------------------------------------------------

local function buildMenuButtons()
	local holder = New("Frame", { Name = "Menu", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(60, 4 * 60 + 3 * 8), BackgroundTransparency = 1, Parent = root })
	C.UIController.AttachScale(holder)
	New("UIListLayout", { Padding = UDim.new(0, 8), Parent = holder })
	local entries = {
		{ Icon = "🎒", Tab = "Equipaggiamento", Hint = "M" },
		{ Icon = "📊", Tab = "Statistiche" },
		{ Icon = "💉", Tab = "Sieri" },
		{ Icon = "💎", Tab = "Premium", Hint = "N" },
	}
	for i, entry in entries do
		local button = Theme.Button(entry.Icon, { Size = UDim2.fromOffset(60, 60), TextSize = 28, LayoutOrder = i, Parent = holder }, function()
			if entry.Tab == "Premium" then
				if C.Premium then
					C.Premium.Open()
				end
			elseif C.Menu then
				C.Menu.OpenTab(entry.Tab)
			end
		end)
		if entry.Hint then
			New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -1), Size = UDim2.fromOffset(16, 14), Font = Theme.Fonts.Bold, TextSize = 11, TextColor3 = Colors.Gold, Text = entry.Hint, Parent = button })
		end
	end
end

local function touchButton(parent: Instance, text: string, action: string, position: UDim2, size: number, color: Color3?)
	local button = New("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color or Colors.PanelLight,
		BackgroundTransparency = 0.25,
		Text = text,
		TextColor3 = Colors.Text,
		Font = Theme.Fonts.Bold,
		TextSize = math.floor(size * 0.32),
		AutoButtonColor = true,
		Parent = parent,
	})
	Theme.Corner(button, size // 2)
	Theme.Stroke(button, Colors.Gold, 2, 0.3)
	button.MouseButton1Down:Connect(function()
		C.InputController.Trigger(action, true)
	end)
	button.MouseButton1Up:Connect(function()
		C.InputController.Trigger(action, false)
	end)
	button.MouseLeave:Connect(function()
		if C.InputController.IsHeld(action) then
			C.InputController.Trigger(action, false)
		end
	end)
	return button
end

local function buildMobile()
	if not isMobile then
		return
	end
	local pad = New("Frame", { Name = "Touch", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10), Size = UDim2.fromOffset(330, 300), BackgroundTransparency = 1, Parent = root })
	C.UIController.AttachScale(pad)
	touchButton(pad, "⚔️", "Attack", UDim2.fromOffset(270, 240), 96, Color3.fromRGB(120, 50, 40))
	touchButton(pad, "◀🪝", "HookLeft", UDim2.fromOffset(150, 250), 72)
	touchButton(pad, "🪝▶", "HookRight", UDim2.fromOffset(200, 160), 72)
	touchButton(pad, "💨", "Boost", UDim2.fromOffset(290, 130), 66)
	touchButton(pad, "↯", "Dodge", UDim2.fromOffset(60, 250), 58)
	touchButton(pad, "🎯", "Ranged", UDim2.fromOffset(110, 170), 56)
	touchButton(pad, "R", "Reload", UDim2.fromOffset(40, 180), 44)
	touchButton(pad, "T", "Transform", UDim2.fromOffset(300, 50), 50, Color3.fromRGB(150, 120, 40))
	local skills = New("Frame", { Name = "TouchAbilita", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(4 * 64, 64), BackgroundTransparency = 1, Parent = root })
	C.UIController.AttachScale(skills)
	for i, key in Skills.Order do
		touchButton(skills, key, "Skill" .. key, UDim2.fromOffset(32 + (i - 1) * 64, 32), 54)
	end
end

-- AGGIORNAMENTO ---------------------------------------------------------------------------------------

local function objectiveTarget(step): Vector3?
	if not step then
		return nil
	end
	local t = step.Type
	if t == "Talk" then
		local npc = NPCs.Get(step.Npc)
		local zone = npc and Zones.Get(npc.Zone)
		if npc and zone then
			return zone.Center + npc.Offset
		end
	elseif t == "Reach" then
		if step.Position then
			return step.Position
		end
		local zone = Zones.Get(step.Zone)
		return zone and zone.Center
	elseif t == "Kill" or t == "Enemy" or t == "Collect" then
		local zone = Zones.Get(step.Zone)
		return zone and zone.Center
	elseif t == "Boss" then
		local boss = Titans.Bosses[step.Boss]
		local zone = boss and Zones.Get(boss.Zone)
		return zone and zone.Center
	elseif t == "HumanBoss" then
		local boss = Enemies.Bosses[step.Boss]
		local zone = boss and Zones.Get(boss.Zone)
		return zone and zone.Center
	end
	return nil
end

local function updateData()
	local profile = C.ClientData.Profile
	if not profile then
		return
	end
	refs.Level.Text = tostring(profile.Level)
	local need = Leveling.XPToNext(profile.Level)
	refs.SetXP(if profile.Level >= Config.MaxLevel then 1 else profile.XP / need)
	refs.XPText.Text = if profile.Level >= Config.MaxLevel then "LIVELLO MASSIMO" else ("%s / %s XP"):format(Util.Abbreviate(profile.XP), Util.Abbreviate(need))
	refs.Gold.Text = "💰 " .. Util.Abbreviate(profile.Gold)
	refs.Gems.Text = "💎 " .. Util.FormatNumber(profile.Gems or 0)
	refs.Name.TextColor3 = if profile.Passes and profile.Passes.VIP then Colors.GoldBright else Colors.Text
	local bloodline = Bloodlines.Get(profile.Bloodline)
	refs.Bloodline.Text = "Stirpe: " .. bloodline.Name
	refs.Bloodline.TextColor3 = bloodline.Color
	refs.Points.Text = if profile.StatPoints > 0 then ("✚ %d punti statistica da assegnare (M)"):format(profile.StatPoints) else ""

	-- storia
	if profile.Story.Done then
		refs.ChapterTitle.Text = "Storia completata"
		refs.StoryObjective.Text = "Caccia ai Sieri Perduti: boss, casse nel mondo e il Mercante di Aurion."
		refs.ObjectivePos = nil
	else
		local chapter, step = Story.GetStep(profile.Story.Chapter, profile.Story.Step)
		if chapter and step then
			refs.ChapterTitle.Text = "📜 " .. chapter.Title
			local progress = ""
			if step.Count and step.Count > 1 then
				progress = ("  (%d/%d)"):format(profile.Story.Progress or 0, step.Count)
			elseif step.Type == "Level" then
				progress = ("  (%d/%d)"):format(profile.Level, step.Level)
			end
			refs.StoryObjective.Text = "▶ " .. step.Objective .. progress
			refs.ObjectivePos = objectiveTarget(step)
		end
	end
	-- missione
	local quest = profile.Quest.Id ~= "" and Quests.Get(profile.Quest.Id)
	if quest then
		refs.QuestTitle.Text = ("Missione: %s (%d/%d)"):format(quest.Name, profile.Quest.Progress, quest.Count)
		refs.SetQuest(profile.Quest.Progress / quest.Count)
		refs.QuestBar.Visible = true
	else
		refs.QuestTitle.Text = "Nessuna missione attiva: parla con un PNG con 📜"
		refs.QuestBar.Visible = false
	end
	HUD.RefreshSkills()
end

function HUD.RefreshSkills()
	local profile = C.ClientData.Profile
	local stats = C.ClientData.Stats
	for _, key in Skills.Order do
		local ref = refs.Skills[key]
		if titanMode then
			local serum = Serums.Get(titanSerum or (profile and profile.Serum))
			local skill = serum and serum.Skills[key]
			ref.Name.Text = if skill then skill.Name else "-"
			local mastery = profile and serum and profile.SerumMastery[serum.Id] or 0
			ref.Lock.Text = if skill and mastery < skill.Mastery then ("🔒 %d"):format(skill.Mastery) else ""
		else
			local skill = Skills.Blade[key]
			ref.Name.Text = skill.Name
			local mastery = stats and stats.BladeMastery or 0
			ref.Lock.Text = if mastery < skill.Mastery then ("🔒 %d"):format(skill.Mastery) else ""
		end
	end
end

local function updateBars()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		refs.SetHP(humanoid.Health / math.max(1, humanoid.MaxHealth))
		refs.HPText.Text = ("%s / %s"):format(Util.Abbreviate(humanoid.Health), Util.Abbreviate(humanoid.MaxHealth))
	end
	local gas, maxGas = C.ODMController.Gas()
	refs.SetGas(gas / math.max(1, maxGas))
	refs.GasText.Text = ("Gas %d%%"):format(math.floor(gas / math.max(1, maxGas) * 100))
	local energyMax = player:GetAttribute("TitanEnergyMax") or 0
	local energy = player:GetAttribute("TitanEnergy") or 0
	if energyMax > 0 then
		refs.SetEnergy(energy / energyMax)
		refs.EnergyText.Text = if titanMode then ("FORMA DI GIGANTE • %d"):format(energy) else ("Energia del Gigante • T per trasformarti")
	else
		refs.SetEnergy(0)
		refs.EnergyText.Text = "Nessun siero iniettato"
	end
	local dur = player:GetAttribute("BladeDur") or 0
	local durMax = math.max(1, player:GetAttribute("BladeDurMax") or 1)
	local filled = math.ceil(dur / durMax * 10)
	for i, notch in refs.Notches do
		notch.BackgroundColor3 = if i <= filled then (if filled <= 3 then Colors.RedBright else Color3.fromRGB(210, 220, 230)) else Color3.fromRGB(60, 50, 44)
	end
	refs.Spares.Text = ("ricambi x%d"):format(player:GetAttribute("BladeSpares") or 0)
	local profile = C.ClientData.Profile
	local rangedId = profile and profile.Equipped and profile.Equipped.Ranged
	if rangedId and rangedId ~= "" then
		refs.Ammo.Text = ("🎯 Munizioni: %d / %d (clic destro)"):format(player:GetAttribute("RangedAmmo") or 0, player:GetAttribute("RangedAmmoMax") or 0)
	else
		refs.Ammo.Text = "🎯 Nessuna arma a distanza"
	end
	if dur <= 0 then
		refs.Hint.Text = "Lame spezzate! Premi R"
	elseif gas <= 0 then
		refs.Hint.Text = "Gas esaurito! Cerca un Deposito"
	else
		refs.Hint.Text = ""
	end
	-- ricariche delle abilità
	local cooldowns = C.CombatController.Cooldowns
	for _, key in Skills.Order do
		local ref = refs.Skills[key]
		local id = if titanMode then "T" .. key else key
		local remaining = (cooldowns[id] or 0) - os.clock()
		local total
		if titanMode then
			local serum = Serums.Get(titanSerum or (profile and profile.Serum))
			local skill = serum and serum.Skills[key]
			total = skill and skill.Cooldown or 1
		else
			total = Skills.Blade[key].Cooldown
		end
		if remaining > 0 then
			ref.Shade.Size = UDim2.fromScale(1, math.clamp(remaining / total, 0, 1))
			ref.Timer.Text = tostring(math.ceil(remaining))
		else
			ref.Shade.Size = UDim2.fromScale(1, 0)
			ref.Timer.Text = ""
		end
	end
end

local lastPreview = 0
local function updateFrame()
	local look = camera.CFrame.LookVector
	local yaw = Util.AngleOf(look)
	local width = refs.Compass.AbsoluteSize.X / math.max(0.01, C.UIController.Scale)
	for _, mark in refs.CompassMarks do
		local delta = ((mark.Angle - yaw + 540) % 360) - 180
		mark.Label.Visible = math.abs(delta) < 85
		mark.Label.Position = UDim2.fromOffset(width / 2 + delta / 90 * (width / 2), 4)
	end
	local rootPart = Util.GetRoot(player.Character)
	if rootPart and refs.ObjectivePos then
		local to = refs.ObjectivePos - rootPart.Position
		local angle = Util.AngleOf(to)
		local delta = ((angle - yaw + 540) % 360) - 180
		refs.Objective.Visible = true
		local clamped = math.clamp(delta, -84, 84)
		refs.Objective.Position = UDim2.fromOffset(width / 2 + clamped / 90 * (width / 2), 2)
		local meters = math.floor(Util.Flat(to).Magnitude / 3.2)
		refs.Objective.Text = ("◆ %dm"):format(meters)
	else
		refs.Objective.Visible = false
	end
	local zoneId = C.AmbienceController.ZoneId
	local zone = Zones.Get(zoneId)
	refs.ZoneName.Text = if zone then zone.Name else C.AmbienceController.RegionName

	-- mirino
	local now = os.clock()
	if now - lastPreview > 0.05 then
		lastPreview = now
		local target, inRange, part = C.ODMController.Preview(nil)
		local color = Color3.fromRGB(170, 170, 170)
		local text = ""
		if target and inRange then
			color = Colors.GreenBright
			if part and part.Name == "Nape" then
				color = Colors.GoldBright
				text = "NUCA"
			elseif part and Util.FindAncestorWithAttribute(part, "TitanUid") then
				color = Color3.fromRGB(255, 120, 100)
			end
			if rootPart and text == "" then
				text = ("%dm"):format(math.floor((target - rootPart.Position).Magnitude / 3.2))
			end
		elseif target then
			text = "fuori portata"
		end
		refs.CrossStroke.Color = color
		refs.CrossDot.BackgroundColor3 = color
		refs.CrossLabel.Text = text
		refs.CrossLabel.TextColor3 = color
		for i = 0, 3 do
			refs["Tick" .. i].BackgroundColor3 = color
		end
	end

	-- linee di velocità
	local speed = if rootPart then rootPart.AssemblyLinearVelocity.Magnitude else 0
	local k = math.clamp((speed - 95) / 90, 0, 1)
	if C.ClientData.Setting("SpeedLines", true) == false or titanMode then
		k = 0
	end
	local size = camera.ViewportSize
	for _, line in refs.SpeedLines do
		if k > 0 then
			local wobble = (os.clock() * 3 + line.Offset) % 1
			local dist = 0.32 + wobble * 0.25
			line.Frame.Position = UDim2.fromOffset(size.X / 2 + math.cos(line.Angle) * size.X * dist, size.Y / 2 + math.sin(line.Angle) * size.Y * dist)
			line.Frame.Size = UDim2.fromOffset(2, 60 + 140 * k)
			line.Frame.BackgroundTransparency = 1 - k * 0.55 * (1 - wobble * 0.6)
		else
			line.Frame.BackgroundTransparency = 1
		end
	end

	-- barra del boss
	local bestModel, bestDist = nil, 650
	local titanFolder = workspace:FindFirstChild(Config.Folders.Titans)
	if rootPart and titanFolder then
		for _, model in titanFolder:GetChildren() do
			if model:GetAttribute("Boss") and model:GetAttribute("State") ~= "Dead" and model:IsA("Model") and model.PrimaryPart then
				local d = (model.PrimaryPart.Position - rootPart.Position).Magnitude
				if d < bestDist then
					bestModel, bestDist = model, d
				end
			end
		end
	end
	if not bestModel then
		local enemyFolder = workspace:FindFirstChild(Config.Folders.Enemies)
		if rootPart and enemyFolder then
			for _, model in enemyFolder:GetChildren() do
				local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?
				if model:GetAttribute("Boss") and not model:GetAttribute("Dead") and hrp then
					local d = (hrp.Position - rootPart.Position).Magnitude
					if d < 300 and d < bestDist then
						bestModel, bestDist = model, d
					end
				end
			end
		end
	end
	if bestModel then
		refs.Boss.Visible = true
		refs.BossName.Text = ("%s  •  Lv. %s"):format(bestModel:GetAttribute("Name") or "Boss", tostring(bestModel:GetAttribute("Level") or ""))
		local hp = bestModel:GetAttribute("HP") or 0
		local maxHP = math.max(1, bestModel:GetAttribute("MaxHP") or 1)
		refs.SetBoss(hp / maxHP)
		local info = bestModel:GetAttribute("BossTitle") or ""
		if bestModel:GetAttribute("Armored") then
			info ..= if bestModel:GetAttribute("ArmorBroken") then "   •   CORAZZA SPEZZATA!" else "   •   Corazza intatta (usa Lance Dirompenti o colpi continui)"
		end
		if bestModel:GetAttribute("Steam") then
			info ..= "   •   VAPORE: allontanati!"
		end
		refs.BossInfo.Text = info .. ("   •   %s / %s"):format(Util.Abbreviate(hp), Util.Abbreviate(maxHP))
	else
		refs.Boss.Visible = false
	end
end

-- API ---------------------------------------------------------------------------------------------

-- Posizione dell'obiettivo attuale della storia (usata dal segnalino 3D)
function HUD.ObjectivePosition(): Vector3?
	return refs.ObjectivePos
end

function HUD.SetVisible(visible: boolean)
	if root then
		root.Visible = visible
	end
end

function HUD.SetTitanMode(on: boolean, serumId: string?)
	titanMode = on
	titanSerum = serumId
	HUD.RefreshSkills()
	if refs.EnergyBar then
		refs.EnergyBar.Size = if on then UDim2.new(1, -48, 0, 20) else UDim2.new(1, -48, 0, 16)
	end
end

function HUD.ShowMash(on: boolean, needed: number?)
	if not refs.Mash then
		return
	end
	refs.Mash.Visible = on
	mashCount = 0
	mashNeeded = needed or mashNeeded
	refs.SetMash(0, true)
end

function HUD.MashPulse()
	mashCount += 1
	refs.SetMash(mashCount / math.max(1, mashNeeded))
	refs.MashScale.Scale = 1.15
	Theme.Tween(refs.MashScale, 0.12, { Scale = 1 })
end

function HUD.Init(c)
	C = c
end

function HUD.Start()
	root = New("Frame", { Name = "HUDPrincipale", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = C.UIController.Layers.HUD })
	buildSpeedLines()
	buildPlayerPanel()
	buildBars()
	buildSkillBar()
	buildCrosshair()
	buildCompass()
	buildTracker()
	buildBossBar()
	buildMash()
	buildDeath()
	buildMenuButtons()
	buildMobile()

	C.ClientData.Changed:Connect(function()
		local ok, err = pcall(updateData)
		if not ok then
			warn("[HUD] " .. tostring(err))
		end
	end)
	if C.ClientData.Ready then
		pcall(updateData)
	end
	task.spawn(function()
		while true do
			pcall(updateBars)
			task.wait(0.1)
		end
	end)
	RunService.RenderStepped:Connect(function()
		if root.Visible then
			local ok, err = pcall(updateFrame)
			if not ok then
				warn("[HUD] " .. tostring(err))
			end
		end
		refs.Crosshair.Visible = not C.UIController.CursorActive() or isMobile
		-- senza shift lock il mirino segue il cursore del mouse
		local aim = C.CameraController.AimScreenPoint()
		refs.Crosshair.Position = UDim2.fromOffset(aim.X, aim.Y)
	end)
	local function onCharacter(character: Model)
		refs.Death.Visible = false
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			humanoid.Died:Connect(function()
				showDeath(C.CombatController.IsGrabbed())
			end)
		end
	end
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

return HUD
