--[[
	Intro - schermata iniziale
	Titolo animato con braci che salgono e lampi di trasformazione, telecamera che sorvola
	il campo di addestramento, riepilogo dei progressi e pulsante GIOCA.
	Finché è aperta, i filmati della storia aspettano (CutsceneController controlla IsShowing).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Lib.Net)
local Util = require(Shared.Lib.Util)
local Story = require(Shared.Data.Story)
local Zones = require(Shared.Data.Zones)

local Theme = require(script.Parent.Theme)
local New = Theme.New
local Colors = Theme.Colors

local Intro = {}
local C
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local showing = true
local revealed = false
local revealClock = 0
local starting = false
local startClock = os.clock()
local orbitAngle = math.random() * math.pi * 2
local renderConnection: RBXScriptConnection? = nil
local nextFlash = os.clock() + 4

type Ember = { Frame: Frame, X: number, Y: number, Speed: number, Sway: number, Phase: number, Size: number }
local embers: { Ember } = {}

local ui = {} :: {
	Root: Frame,
	Backdrop: Frame,
	Flash: Frame,
	Content: Frame,
	Title: TextLabel,
	TitleGlow: TextLabel,
	TitleScale: UIScale,
	Subtitle: TextLabel,
	Line: Frame,
	Tagline: TextLabel,
	Welcome: TextLabel,
	Status: TextLabel,
	Play: TextButton,
	PlayScale: UIScale,
	Controls: Frame,
}

local CONTROLS = {
	{ "Q / E (tieni premuto)", "Rampino sinistro / destro" },
	{ "Spazio", "Salto • getto di gas in volo" },
	{ "W A S D in volo", "Sterzare attorno ai rampini" },
	{ "Shift", "Attiva/disattiva lo shift lock" },
	{ "Ctrl sinistro", "Schivata" },
	{ "Bloc Maiusc", "Cammina / corri" },
	{ "Clic sinistro", "Fendente (combo da 4 colpi)" },
	{ "Clic destro", "Arma a distanza" },
	{ "Z  X  C  V", "Abilità delle lame o del gigante" },
	{ "R", "Sostituisci le lame" },
	{ "T", "Trasformazione (prossimo aggiornamento)" },
	{ "G", "Risveglio Valkar" },
	{ "F", "Parla • usa • raccogli" },
	{ "M", "Menu (equipaggiamento, statistiche, sieri...)" },
	{ "Alt sinistro", "Sblocca il cursore" },
}

local function titleParts(): (string, string)
	local name = Config.GameName or "Sieri Perduti"
	local top, bottom = name:match("^(.-)%s*:%s*(.+)$")
	if top and bottom then
		return top:upper(), bottom:upper()
	end
	return name:upper(), ""
end

local function spaced(text: string): string
	local chars = {}
	for _, code in utf8.codes(text) do
		table.insert(chars, utf8.char(code))
	end
	return table.concat(chars, " ")
end

local function characterReady(): boolean
	local character = player.Character
	return character ~= nil and Util.GetRoot(character) ~= nil
end

local function canPlay(): boolean
	return characterReady() and (C.ClientData.Ready or os.clock() - startClock > 25)
end

-- testo di benvenuto con livello e capitolo
local function welcomeText(): string
	local profile = C.ClientData.Profile
	if not profile then
		return ""
	end
	local isNew = profile.Level <= 1 and profile.Story and profile.Story.Chapter == 1 and profile.Story.Step == 1
	if isNew then
		return ("Benvenuto, %s. Le Mura ti aspettano."):format(player.DisplayName)
	end
	local chapter = profile.Story and Story.Chapters[profile.Story.Chapter]
	local season = chapter and Zones.SeasonNames[chapter.Season] or ""
	local where = if profile.Story and profile.Story.Done then "Storia completata" elseif chapter then chapter.Title else ""
	return ("Bentornato, %s  •  Livello %d\n%s%s"):format(player.DisplayName, profile.Level, where, if season ~= "" then "  •  " .. season else "")
end

-- BRACI E LAMPI -----------------------------------------------------------------------------------

local function spawnEmbers(parent: Frame)
	for _ = 1, 46 do
		local size = math.random(2, 5)
		local frame = New("Frame", {
			BackgroundColor3 = if math.random() < 0.7 then Color3.fromRGB(255, 150, 60) else Color3.fromRGB(255, 220, 140),
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 0.2,
			Parent = parent,
		})
		Theme.Corner(frame, size)
		table.insert(embers, {
			Frame = frame,
			X = math.random(),
			Y = 1 + math.random() * 0.6,
			Speed = 0.03 + math.random() * 0.06,
			Sway = 0.004 + math.random() * 0.012,
			Phase = math.random() * 10,
			Size = size,
		})
	end
end

local function updateEmbers(dt: number, now: number)
	for _, ember in embers do
		ember.Y -= ember.Speed * dt
		if ember.Y < -0.05 then
			ember.Y = 1.05
			ember.X = math.random()
		end
		local x = ember.X + math.sin(now * 0.9 + ember.Phase) * ember.Sway
		ember.Frame.Position = UDim2.fromScale(x, ember.Y)
		-- le braci si spengono salendo
		ember.Frame.BackgroundTransparency = math.clamp(0.1 + (1 - ember.Y) * 0.8 + math.sin(now * 7 + ember.Phase) * 0.1, 0, 1)
	end
end

local function flash()
	ui.Flash.BackgroundTransparency = 0.55
	Theme.Tween(ui.Flash, 0.6, { BackgroundTransparency = 1 })
	ui.TitleGlow.TextTransparency = 0.2
	Theme.Tween(ui.TitleGlow, 1.2, { TextTransparency = 0.75 })
	if C.CameraController then
		C.CameraController.Shake(0.25, 0.4)
	end
	if C.SoundController then
		C.SoundController.Play("Thunder", nil, { Volume = 0.25 })
	end
end

-- TELECAMERA --------------------------------------------------------------------------------------

local function updateCamera(dt: number, now: number)
	local root = Util.GetRoot(player.Character)
	if not root then
		return
	end
	orbitAngle += dt * 0.06
	local center = root.Position + Vector3.new(0, 18, 0)
	local radius = 120 + math.sin(now * 0.15) * 20
	local height = 60 + math.sin(now * 0.11) * 12
	local eye = center + Vector3.new(math.cos(orbitAngle) * radius, height, math.sin(orbitAngle) * radius)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(eye, center) * C.CameraController.CinematicShake()
	camera.FieldOfView = 55
end

-- INTERFACCIA -------------------------------------------------------------------------------------

local function controlsPanel(parent: Frame): Frame
	local panel = Theme.Panel({
		Name = "Comandi",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 520),
		Visible = false,
		ZIndex = 5,
		Parent = parent,
	})
	Theme.Padding(panel, 16)
	Theme.Label("Comandi", { Size = UDim2.new(1, 0, 0, 30), Font = Theme.Fonts.Title, TextSize = 30, TextColor3 = Colors.GoldBright, Parent = panel })
	local list = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -96), Parent = panel })
	New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	for i, row in CONTROLS do
		local line = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = i, Parent = list })
		local key = Theme.Label(row[1], {
			Size = UDim2.new(0.4, -6, 1, 0),
			Font = Theme.Fonts.Bold,
			TextSize = 14,
			TextColor3 = Colors.Gold,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = line,
		})
		key.TextTruncate = Enum.TextTruncate.AtEnd
		Theme.Label(row[2], { Position = UDim2.new(0.4, 8, 0, 0), Size = UDim2.new(0.6, -8, 1, 0), Font = Theme.Fonts.UI, TextSize = 14, Parent = line })
	end
	Theme.Button("Ho capito", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(200, 40), Parent = panel }, function()
		panel.Visible = false
	end)
	return panel
end

local function build()
	local layer = C.UIController.Layers.Top
	local root = New("Frame", { Name = "Intro", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = layer })
	ui.Root = root
	-- sfondo nero che si dissolve quando il mondo è pronto
	ui.Backdrop = New("Frame", { BackgroundColor3 = Colors.Black, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = root })
	-- vignettatura: sopra e sotto più scuri
	local vignette = New("Frame", { BackgroundColor3 = Colors.Black, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = root })
	New("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.35, 0.75),
			NumberSequenceKeypoint.new(0.65, 0.75),
			NumberSequenceKeypoint.new(1, 0.05),
		}),
		Parent = vignette,
	})
	local emberLayer = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = root })
	spawnEmbers(emberLayer)
	ui.Flash = New("Frame", { BackgroundColor3 = Color3.fromRGB(255, 236, 200), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = root })

	local content = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = root })
	ui.Content = content
	local column = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(1000, 620),
		Parent = content,
	})
	C.UIController.AttachScale(column)

	local top, bottom = titleParts()
	ui.TitleGlow = Theme.Label(top, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.new(1, 0, 0, 110),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.Title,
		TextSize = 92,
		TextColor3 = Color3.fromRGB(255, 120, 50),
		TextTransparency = 0.75,
		TextStrokeTransparency = 1,
		Parent = column,
	})
	New("UIScale", { Scale = 1.04, Parent = ui.TitleGlow })
	ui.Title = Theme.Label(top, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.new(1, 0, 0, 110),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.Title,
		TextSize = 92,
		TextColor3 = Colors.GoldBright,
		TextStrokeColor3 = Color3.fromRGB(40, 18, 8),
		TextStrokeTransparency = 0.1,
		TextTransparency = 1,
		Parent = column,
	})
	Theme.Gradient(ui.Title, Color3.fromRGB(255, 240, 200), Color3.fromRGB(210, 150, 70), 90)
	ui.TitleScale = New("UIScale", { Scale = 1.25, Parent = ui.Title })
	ui.Line = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Colors.Gold,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 0, 160),
		Size = UDim2.fromOffset(0, 2),
		Parent = column,
	})
	New("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = ui.Line,
	})
	ui.Subtitle = Theme.Label(spaced(bottom), {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 172),
		Size = UDim2.new(1, 0, 0, 50),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.Header,
		TextSize = 38,
		TextColor3 = Colors.Text,
		TextStrokeTransparency = 0.4,
		TextTransparency = 1,
		Parent = column,
	})
	ui.Tagline = Theme.Label("Cinque isole. Otto poteri. Un solo mondo da salvare.", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 228),
		Size = UDim2.new(1, 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.Body,
		TextSize = 18,
		TextColor3 = Colors.TextDim,
		TextTransparency = 1,
		Parent = column,
	})

	ui.Play = Theme.Button("GIOCA", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 340),
		Size = UDim2.fromOffset(300, 64),
		Font = Theme.Fonts.Title,
		TextSize = 40,
		TextColor3 = Colors.GoldBright,
		BackgroundColor3 = Color3.fromRGB(70, 40, 26),
		Visible = false,
		Parent = column,
	}, function()
		Intro.Begin()
	end)
	ui.PlayScale = New("UIScale", { Name = "Pulsazione", Scale = 0.6, Parent = ui.Play })
	Theme.Button("Comandi", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 418),
		Size = UDim2.fromOffset(200, 40),
		TextSize = 16,
		Parent = column,
	}, function()
		ui.Controls.Visible = not ui.Controls.Visible
	end)
	ui.Status = Theme.Label("Caricamento dei progressi...", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 470),
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.UI,
		TextSize = 15,
		TextColor3 = Colors.TextDim,
		Parent = column,
	})
	ui.Welcome = Theme.Label("", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 270),
		Size = UDim2.new(1, 0, 0, 48),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.UI,
		TextSize = 16,
		TextColor3 = Colors.Gold,
		Parent = column,
	})
	Theme.Label("Un'avventura originale • v1.0", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, -40, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.UI,
		TextSize = 12,
		TextColor3 = Colors.TextDim,
		TextTransparency = 0.3,
		Parent = content,
	})
	ui.Controls = controlsPanel(content)
	C.UIController.AttachScale(ui.Controls)
end

-- animazione d'ingresso del titolo
local function animateIn()
	task.wait(0.4)
	Theme.Tween(ui.Title, 1.4, { TextTransparency = 0 }, Enum.EasingStyle.Sine)
	Theme.Tween(ui.TitleScale, 1.8, { Scale = 1 }, Enum.EasingStyle.Quint)
	task.wait(0.9)
	flash()
	Theme.Tween(ui.Line, 1, { Size = UDim2.fromOffset(640, 2) }, Enum.EasingStyle.Quint)
	task.wait(0.3)
	Theme.Tween(ui.Subtitle, 0.9, { TextTransparency = 0 })
	task.wait(0.4)
	Theme.Tween(ui.Tagline, 1.2, { TextTransparency = 0.1 })
end

local function reveal()
	if revealed then
		return
	end
	revealed = true
	revealClock = os.clock()
	Theme.Tween(ui.Backdrop, 2.5, { BackgroundTransparency = 0.45 }, Enum.EasingStyle.Sine)
	ui.Play.Visible = true
end

local function step(dt: number)
	if not showing then
		return
	end
	local now = os.clock()
	updateEmbers(dt, now)
	if characterReady() then
		updateCamera(dt, now)
	end
	if canPlay() then
		reveal()
		ui.Status.Text = "Premi GIOCA per entrare nelle Mura"
		if not starting then
			-- il pulsante "esplode" fuori e poi pulsa piano
			local pop = math.clamp((now - revealClock) / 0.45, 0, 1)
			local base = 0.6 + 0.4 * Util.Ease(pop, "BackOut")
			ui.PlayScale.Scale = base + math.sin(now * 2.6) * 0.03 * pop
		end
	else
		local dots = string.rep(".", 1 + math.floor(now * 2) % 3)
		ui.Status.Text = (if C.ClientData.Ready then "Arrivo al campo di addestramento" else "Caricamento dei progressi") .. dots
	end
	if C.ClientData.Ready and ui.Welcome.Text == "" then
		ui.Welcome.Text = welcomeText()
	end
	if now >= nextFlash then
		nextFlash = now + 7 + math.random() * 6
		flash()
	end
end

-- GIOCA: chiude l'intro e restituisce la telecamera al giocatore
function Intro.Begin()
	if starting or not showing or not canPlay() then
		return
	end
	starting = true
	C.SoundController.Play("Reward")
	Theme.Tween(ui.PlayScale, 0.15, { Scale = 1.15 }, Enum.EasingStyle.Back)
	local fade = New("Frame", {
		BackgroundColor3 = Colors.Black,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 40,
		Parent = C.UIController.Layers.Top,
	})
	Theme.Tween(fade, 0.6, { BackgroundTransparency = 0 }).Completed:Wait()
	showing = false
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	ui.Root.Visible = false
	camera.FieldOfView = C.CameraController.BaseFov
	C.CameraController.SetCinematic(false)
	C.UIController.RequestCursor("intro", false)
	if C.HUD then
		C.HUD.SetVisible(true)
	end
	Net.Event("ClientReady"):FireServer()
	task.wait(0.2)
	Theme.Tween(fade, 0.9, { BackgroundTransparency = 1 }).Completed:Wait()
	fade:Destroy()
	ui.Root:Destroy()
	table.clear(embers)
end

function Intro.IsShowing(): boolean
	return showing
end

function Intro.Init(c)
	C = c
end

function Intro.Start()
	build()
	C.CameraController.SetCinematic(true)
	C.UIController.RequestCursor("intro", true)
	renderConnection = RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(step, dt)
		if not ok then
			warn("[Intro] " .. tostring(err))
		end
	end)
	task.spawn(animateIn)
end

return Intro
