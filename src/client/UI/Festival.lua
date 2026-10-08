--[[
	Festival - interfaccia dell'evento "Grande Inaugurazione"
	  - striscione sotto la bussola: bonus attivi, quando arriva il Colosso d'Oro, quando finisce l'evento
	  - pannello (clic sullo striscione): le 8 sfide con i progressi, i premi e il codice regalo
	Lo stato arriva dagli attributi di ReplicatedStorage (li scrive FestivalService).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Festival = require(Shared.Data.Festival)
local Items = require(Shared.Data.Items)

local Theme = require(script.Parent.Theme)
local New = Theme.New
local Colors = Theme.Colors

local FestivalUI = {}
local C

local banner: TextButton
local bannerText: TextLabel
local panel: Frame
local subtitle: TextLabel
local timers: TextLabel
local rows: { [string]: any } = {}
local finalLabel: TextLabel

local GOLD = Color3.fromRGB(255, 206, 96)

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function festivalData()
	local profile = C.ClientData.Profile
	local f = profile and profile.Festival
	if type(f) == "table" and f.Id == Festival.Id then
		return f
	end
	return nil
end

local function buildBanner()
	banner = New("TextButton", {
		Name = "StriscioneFesta",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 76),
		Size = UDim2.fromOffset(560, 30),
		BackgroundColor3 = Color3.fromRGB(70, 22, 26),
		BackgroundTransparency = 0.1,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		Parent = C.UIController.Layers.HUD,
	})
	C.UIController.AttachScale(banner)
	Theme.Corner(banner, 15)
	Theme.Stroke(banner, GOLD, 1.5, 0.1)
	New("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 170, 150)), Rotation = 90, Parent = banner })
	bannerText = Theme.Label("", {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.Bold,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(255, 236, 190),
		Parent = banner,
	})
	banner.Activated:Connect(function()
		C.UIController.Toggle("Inaugurazione")
	end)
end

local function challengeRow(parent: Instance, order: number, c)
	local row = Theme.Panel({ Size = UDim2.new(1, -8, 0, 54), LayoutOrder = order, Parent = parent })
	New("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(40, 54), Text = c.Icon, TextSize = 26, Font = Theme.Fonts.Bold, TextColor3 = Colors.Text, Parent = row })
	local name = Theme.Label(c.Name, { Position = UDim2.fromOffset(52, 6), Size = UDim2.new(1, -200, 0, 18), Font = Theme.Fonts.Bold, TextSize = 15, Parent = row })
	Theme.Label(c.Text, { Position = UDim2.fromOffset(52, 24), Size = UDim2.new(1, -200, 0, 16), Font = Theme.Fonts.UI, TextSize = 12, TextColor3 = Colors.TextDim, Parent = row })
	local _, setBar = Theme.Bar({ Position = UDim2.new(1, -140, 0, 30), Size = UDim2.fromOffset(128, 10), Parent = row }, GOLD)
	local count = Theme.Label("", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(128, 18), TextXAlignment = Enum.TextXAlignment.Right, Font = Theme.Fonts.Bold, TextSize = 13, TextColor3 = GOLD, Parent = row })
	rows[c.Id] = { Name = name, SetBar = setBar, Count = count, Row = row }
end

local function buildPanel()
	panel = Theme.Panel({ Name = "Inaugurazione", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(760, 600), Parent = C.UIController.Layers.Panels })
	Theme.Padding(panel, 14)
	Theme.Label("🎉 " .. Festival.Name, { Size = UDim2.new(1, -50, 0, 36), Font = Theme.Fonts.Title, TextSize = 32, TextColor3 = GOLD, Parent = panel })
	Theme.Button("✕", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(36, 32), Parent = panel }, function()
		C.UIController.Close("Inaugurazione")
	end)
	subtitle = Theme.Label("", { Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 20), Font = Theme.Fonts.UI, TextSize = 14, TextColor3 = Colors.TextDim, Parent = panel })
	timers = Theme.Label("", { Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 44), Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = Colors.Text, TextYAlignment = Enum.TextYAlignment.Top, Parent = panel })
	local list = New("ScrollingFrame", { Position = UDim2.fromOffset(0, 108), Size = UDim2.new(1, 0, 1, -170), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = panel })
	New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	for i, c in Festival.Challenges do
		challengeRow(list, i, c)
	end
	local cloak = Items.Get(Festival.FinalItem)
	finalLabel = Theme.Label("", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 36), Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = GOLD, TextWrapped = true, Parent = panel })
	finalLabel.Text = ("Completa tutte le sfide: %s (esclusivo) + %d 💎"):format(cloak and cloak.Name or "premio finale", Festival.FinalGems)
	Theme.Label("Codice regalo dell'evento: INAUGURAZIONE (Menu → Codici)", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 18), Font = Theme.Fonts.UI, TextSize = 13, TextColor3 = Colors.TextDim, Parent = panel })
	C.UIController.RegisterPanel("Inaugurazione", panel)
end

local function timeUntil(attr: string): string
	local at = ReplicatedStorage:GetAttribute(attr)
	if type(at) ~= "number" then
		return "-"
	end
	return Festival.FormatTime(at - serverNow())
end

local accumulator = 0
local function update(dt: number)
	accumulator += dt
	if accumulator < 0.5 then
		return
	end
	accumulator = 0
	local active = ReplicatedStorage:GetAttribute("FestaAttiva") == true
	local cinematic = C.CameraController and C.CameraController.IsCinematic()
	local intro = C.Intro and C.Intro.IsShowing and C.Intro.IsShowing()
	banner.Visible = active and not cinematic and not intro
	banner.Position = UDim2.new(0.5, 0, 0, math.floor(14 + 62 * C.UIController.Scale))
	if not active then
		if C.UIController.IsOpen("Inaugurazione") then
			C.UIController.Close("Inaugurazione")
		end
		return
	end
	local fine = ReplicatedStorage:GetAttribute("FestaFine")
	local ends = if type(fine) == "number" and fine > 0 then ("  •  fine tra " .. Festival.FormatTime(fine - serverNow())) else ""
	local bossHere = ReplicatedStorage:GetAttribute("FestaBossPos") ~= nil
	local boss = if bossHere then "👑 COLOSSO D'ORO IN CAMPO!" else ("👑 Colosso tra " .. timeUntil("FestaProssimoBoss"))
	bannerText.Text = ("🎉 GRANDE INAUGURAZIONE  •  2x XP e ORO  •  %s%s"):format(boss, ends)
	if not C.UIController.IsOpen("Inaugurazione") then
		return
	end
	subtitle.Text = "Esperienza e oro doppi per tutti" .. (if ends ~= "" then ends else "")
	timers.Text = ("👑 Colosso d'Oro: %s (Pianure Meridionali, Vermiglia)\n🎆 Prossimi fuochi d'artificio sopra le città: tra %s"):format(if bossHere then "in campo ORA!" else "tra " .. timeUntil("FestaProssimoBoss"), timeUntil("FestaProssimiFuochi"))
	local f = festivalData()
	local done = 0
	for _, c in Festival.Challenges do
		local row = rows[c.Id]
		local progress = f and f.Progress and f.Progress[c.Id] or 0
		local complete = f and f.Done and f.Done[c.Id] == true
		if complete then
			done += 1
		end
		row.SetBar(progress / c.Goal)
		row.Count.Text = if complete then "✅ Completata" else ("%d / %d  •  +%d 💎"):format(progress, c.Goal, c.Gems)
		row.Name.TextColor3 = if complete then Colors.GreenBright else Colors.Text
	end
	if f and f.Final then
		finalLabel.Text = "🏆 Tutte le sfide completate! Il Mantello dell'Inaugurazione è nel tuo equipaggiamento."
	else
		local cloak = Items.Get(Festival.FinalItem)
		finalLabel.Text = ("Sfide completate: %d / %d  •  Premio finale: %s (esclusivo) + %d 💎"):format(done, #Festival.Challenges, cloak and cloak.Name or "", Festival.FinalGems)
	end
end

function FestivalUI.Init(c)
	C = c
end

function FestivalUI.Start()
	buildBanner()
	buildPanel()
	RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(update, dt)
		if not ok then
			warn("[Evento] " .. tostring(err))
		end
	end)
end

return FestivalUI
