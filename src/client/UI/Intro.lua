--[[
	Intro - schermata iniziale
	Titolo animato con braci che salgono e lampi di trasformazione, telecamera che sorvola
	il campo di addestramento, riepilogo dei progressi e pulsante GIOCA.
	Nel file di Halloween la schermata è infestata: luna arancione, il gigante che spunta dal Muro
	con gli occhi accesi, pipistrelli, zucche, fantasmi, ragnatele e foglie d'autunno che cadono.
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
local nextCharacterRequest = os.clock() + 20

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

local LEAF_COLORS = { Color3.fromRGB(236, 118, 28), Color3.fromRGB(196, 62, 30), Color3.fromRGB(220, 166, 48), Color3.fromRGB(140, 80, 40), Color3.fromRGB(150, 90, 220) }

local function spawnEmbers(parent: Frame)
	for _ = 1, 46 do
		local size = math.random(2, 5)
		if Theme.Halloween then
			size = math.random(5, 10)
		end
		local frame = New("Frame", {
			BackgroundColor3 = if Theme.Halloween then LEAF_COLORS[math.random(1, #LEAF_COLORS)] elseif math.random() < 0.7 then Color3.fromRGB(255, 150, 60) else Color3.fromRGB(255, 220, 140),
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 0.2,
			Parent = parent,
		})
		if Theme.Halloween then
			Theme.Corner(frame, 2)
		else
			Theme.Corner(frame, size)
		end
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
		if Theme.Halloween then
			-- foglie d'autunno che cadono girando su sé stesse
			ember.Y += ember.Speed * dt * 0.8
			if ember.Y > 1.05 then
				ember.Y = -0.05
				ember.X = math.random()
			end
			local x = ember.X + math.sin(now * 0.9 + ember.Phase) * ember.Sway * 3
			ember.Frame.Position = UDim2.fromScale(x, ember.Y)
			ember.Frame.Rotation = (now * 90 + ember.Phase * 40) % 360
			ember.Frame.BackgroundTransparency = 0.15
			continue
		end
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

-- L'IMMAGINE DI HALLOWEEN ------------------------------------------------------------------------
-- Disegnata con le cornici dell'interfaccia (nessuna immagine da caricare): cielo viola, luna, Muro,
-- il gigante che spunta con gli occhi accesi e le mani sul bordo, pipistrelli, zucche e fantasmi.

type Bat = { Frame: Frame, Left: Frame, Right: Frame, X: number, Y: number, Speed: number, Phase: number, Size: number }
local bats: { Bat } = {}
local spooky: { Eyes: { Frame }, Pumpkins: { TextLabel }, Ghosts: { { Label: TextLabel, X: number, Y: number, Phase: number } }, Moon: Frame?, Titan: Frame? } = { Eyes = {}, Pumpkins = {}, Ghosts = {} }

local SILHOUETTE = Color3.fromRGB(12, 6, 18)

local function circle(parent: Instance, color: Color3, pos: UDim2, size: UDim2, alpha: number?, z: number?): Frame
	local f = New("Frame", { BackgroundColor3 = color, BackgroundTransparency = alpha or 0, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = size, ZIndex = z or 1, Parent = parent })
	New("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
	return f
end

local function block(parent: Instance, color: Color3, pos: UDim2, size: UDim2, z: number?, anchor: Vector2?): Frame
	return New("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = anchor or Vector2.new(0.5, 1), Position = pos, Size = size, ZIndex = z or 1, Parent = parent })
end

local function makeBat(parent: Instance, size: number): Bat
	local holder = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size * 2.4, size), ZIndex = 3, Parent = parent })
	circle(holder, SILHOUETTE, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(size * 0.5, size * 0.62), 0, 4)
	for _, side in { -1, 1 } do
		circle(holder, SILHOUETTE, UDim2.new(0.5, side * size * 0.12, 0.5, -size * 0.32), UDim2.fromOffset(size * 0.16, size * 0.24), 0, 4) -- orecchie
	end
	local function wing(side: number): Frame
		local w = New("Frame", { BackgroundColor3 = SILHOUETTE, BorderSizePixel = 0, AnchorPoint = Vector2.new(if side < 0 then 1 else 0, 0.5), Position = UDim2.new(0.5, side * size * 0.15, 0.5, 0), Size = UDim2.fromOffset(size * 0.95, size * 0.34), ZIndex = 4, Parent = holder })
		New("UICorner", { CornerRadius = UDim.new(0.4, 0), Parent = w })
		-- le punte dell'ala
		for i = 1, 2 do
			local tip = New("Frame", { BackgroundColor3 = SILHOUETTE, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(if side < 0 then i * 0.3 else 1 - i * 0.3, 0.6), Size = UDim2.fromOffset(size * 0.2, size * 0.2), Rotation = 45, ZIndex = 4, Parent = w })
			tip.BackgroundTransparency = 0
		end
		return w
	end
	return {
		Frame = holder,
		Left = wing(-1),
		Right = wing(1),
		X = math.random(),
		Y = 0.08 + math.random() * 0.45,
		Speed = 0.025 + math.random() * 0.05,
		Phase = math.random() * 10,
		Size = size,
	}
end

local function buildHalloweenArt(root: Frame)
	local art = New("Frame", { Name = "Halloween", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = root })
	-- cielo viola sopra, che sfuma verso il basso (fondo bianco: UIGradient moltiplica il colore)
	local sky = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = art })
	New("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(40, 16, 60), Color3.fromRGB(110, 40, 30)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.55, 0.55), NumberSequenceKeypoint.new(1, 0.25) }),
		Parent = sky,
	})
	-- la luna arancione con l'alone e i crateri
	local moonHolder = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.8, 0.4), Size = UDim2.fromScale(0.5, 0.5), Parent = art })
	New("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height, Parent = moonHolder })
	for i, alpha in { 0.86, 0.78, 0.68 } do
		circle(moonHolder, Color3.fromRGB(255, 150, 60), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1.5 - i * 0.14, 1.5 - i * 0.14), alpha)
	end
	local moon = circle(moonHolder, Color3.fromRGB(255, 196, 110), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), 0, 2)
	New("UIGradient", { Rotation = 35, Color = ColorSequence.new(Color3.fromRGB(255, 236, 170), Color3.fromRGB(240, 120, 40)), Parent = moon })
	for _, crater in { { 0.32, 0.36, 0.16 }, { 0.62, 0.3, 0.1 }, { 0.55, 0.62, 0.2 }, { 0.3, 0.68, 0.08 } } do
		circle(moon, Color3.fromRGB(214, 110, 40), UDim2.fromScale(crater[1], crater[2]), UDim2.fromScale(crater[3], crater[3]), 0.55, 2)
	end
	spooky.Moon = moonHolder
	-- il gigante che spunta da dietro il Muro, davanti alla luna: testa, spalle, occhi accesi e mani sul bordo
	local titan = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.8, 0.9), Size = UDim2.fromScale(0.34, 0.46), ZIndex = 2, Parent = art })
	spooky.Titan = titan
	local head = block(titan, SILHOUETTE, UDim2.fromScale(0.5, 0.78), UDim2.fromScale(0.42, 0.52), 2)
	New("UICorner", { CornerRadius = UDim.new(0.18, 0), Parent = head })
	local shoulders = block(titan, SILHOUETTE, UDim2.fromScale(0.5, 1), UDim2.fromScale(0.9, 0.3), 2)
	New("UICorner", { CornerRadius = UDim.new(0.35, 0), Parent = shoulders })
	for _, side in { -1, 1 } do
		-- orecchie e occhi che brillano (con l'alone)
		block(titan, SILHOUETTE, UDim2.fromScale(0.5 + side * 0.23, 0.6), UDim2.fromScale(0.06, 0.14), 2)
		local glowEye = circle(head, Color3.fromRGB(255, 140, 40), UDim2.fromScale(0.5 + side * 0.2, 0.42), UDim2.fromScale(0.26, 0.16), 0.55, 3)
		local eye = circle(head, Color3.fromRGB(255, 214, 120), UDim2.fromScale(0.5 + side * 0.2, 0.42), UDim2.fromScale(0.13, 0.08), 0, 3)
		table.insert(spooky.Eyes, glowEye)
		table.insert(spooky.Eyes, eye)
	end
	-- il ghigno: denti chiari
	for i = -3, 3 do
		block(head, Color3.fromRGB(220, 200, 170), UDim2.fromScale(0.5 + i * 0.075, 0.74), UDim2.fromScale(0.055, 0.08), 3, Vector2.new(0.5, 0.5))
	end
	-- il Muro con i merli
	local wall = block(art, Color3.new(1, 1, 1), UDim2.fromScale(0.5, 1), UDim2.fromScale(1, 0.2), 3)
	New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(46, 28, 56), Color3.fromRGB(10, 6, 14)), Parent = wall })
	for i = 0, 24 do
		block(art, Color3.fromRGB(34, 20, 44), UDim2.fromScale(i / 24, 0.805), UDim2.fromScale(0.024, 0.035), 3)
	end
	-- le mani del gigante aggrappate al bordo del Muro
	for _, side in { -1, 1 } do
		local hand = block(art, SILHOUETTE, UDim2.fromScale(0.8 + side * 0.16, 0.84), UDim2.fromScale(0.07, 0.06), 4)
		New("UICorner", { CornerRadius = UDim.new(0.3, 0), Parent = hand })
		for f = 0, 3 do
			block(art, SILHOUETTE, UDim2.fromScale(0.8 + side * 0.16 + (f - 1.5) * 0.016, 0.86), UDim2.fromScale(0.012, 0.045), 4, Vector2.new(0.5, 0))
		end
	end
	-- zucche accese negli angoli in basso e fantasmi che fluttuano
	for _, at in { { 0.07, 0.9, 120 }, { 0.17, 0.94, 80 }, { 0.93, 0.92, 100 } } do
		local glow = circle(art, Color3.fromRGB(255, 140, 40), UDim2.fromScale(at[1], at[2]), UDim2.fromOffset(at[3] * 1.6, at[3] * 1.6), 0.7, 4)
		local label = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(at[1], at[2]), Size = UDim2.fromOffset(at[3], at[3]), Text = "🎃", TextScaled = true, Font = Theme.Fonts.Bold, ZIndex = 5, Parent = art })
		table.insert(spooky.Pumpkins, label)
		label:SetAttribute("Glow", true)
		glow.Name = "AloneZucca"
		label:SetAttribute("Base", at[3])
		table.insert(spooky.Eyes, glow)
	end
	for i, at in { { 0.12, 0.42 }, { 0.3, 0.2 }, { 0.92, 0.18 } } do
		local ghost = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(at[1], at[2]), Size = UDim2.fromOffset(64, 64), Text = "👻", TextScaled = true, TextTransparency = 0.3, Font = Theme.Fonts.Bold, ZIndex = 5, Parent = art })
		table.insert(spooky.Ghosts, { Label = ghost, X = at[1], Y = at[2], Phase = i * 1.7 })
	end
	-- ragnatele negli angoli in alto
	Theme.Cobweb(art, 190)
	local right = Theme.Cobweb(art, 190)
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.fromScale(1, 0)
	right.Rotation = 90
	-- pipistrelli
	for _ = 1, 14 do
		local bat = makeBat(art, math.random(14, 30))
		table.insert(bats, bat)
	end
	return art
end

local function updateHalloweenArt(dt: number, now: number)
	for _, bat in bats do
		bat.X += bat.Speed * dt
		if bat.X > 1.08 then
			bat.X = -0.08
			bat.Y = 0.08 + math.random() * 0.45
		end
		local y = bat.Y + math.sin(now * 1.6 + bat.Phase) * 0.03
		bat.Frame.Position = UDim2.fromScale(bat.X, y)
		local flap = math.sin(now * 16 + bat.Phase) * 32
		bat.Left.Rotation = flap
		bat.Right.Rotation = -flap
	end
	-- occhi del gigante e zucche che tremolano come candele
	local flicker = 0.5 + 0.5 * math.noise(now * 3, 1.7)
	for _, f in spooky.Eyes do
		if f.Name == "AloneZucca" then
			f.BackgroundTransparency = 0.62 + flicker * 0.18
		end
	end
	for _, g in spooky.Ghosts do
		g.Label.Position = UDim2.fromScale(g.X + math.sin(now * 0.5 + g.Phase) * 0.02, g.Y + math.sin(now * 1.1 + g.Phase) * 0.025)
		g.Label.TextTransparency = 0.25 + 0.35 * (0.5 + 0.5 * math.sin(now * 0.8 + g.Phase))
	end
	-- il gigante sale piano da dietro il Muro e ogni tanto torna giù
	if spooky.Titan then
		local rise = 0.5 + 0.5 * math.sin(now * 0.25)
		spooky.Titan.Position = UDim2.fromScale(0.8, 0.9 + (1 - rise) * 0.08)
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
	if Theme.Halloween then
		buildHalloweenArt(root)
	end
	local emberLayer = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = root })
	spawnEmbers(emberLayer)
	ui.Flash = New("Frame", { BackgroundColor3 = if Theme.Halloween then Color3.fromRGB(170, 120, 255) else Color3.fromRGB(255, 236, 200), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = root })

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
		TextColor3 = if Theme.Halloween then Color3.fromRGB(140, 255, 90) else Color3.fromRGB(255, 120, 50),
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
	if Theme.Halloween then
		ui.Title.TextStrokeColor3 = Color3.fromRGB(30, 8, 40)
		Theme.Gradient(ui.Title, Color3.fromRGB(255, 200, 90), Color3.fromRGB(230, 90, 20), 90)
	else
		Theme.Gradient(ui.Title, Color3.fromRGB(255, 240, 200), Color3.fromRGB(210, 150, 70), 90)
	end
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
	ui.Tagline = Theme.Label(if Theme.Halloween then "🎃  EDIZIONE DI HALLOWEEN  •  Le Mura sono infestate: i giganti hanno fame di dolcetti  🦇" else "Cinque isole. Otto poteri. Un solo mondo da salvare.", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 228),
		Size = UDim2.new(1, 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.Body,
		TextSize = 18,
		TextColor3 = Colors.TextDim,
		TextStrokeTransparency = if Theme.Halloween then 0.35 else 1, -- leggibile anche davanti alla luna
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
		BackgroundColor3 = if Theme.Halloween then Color3.fromRGB(70, 26, 90) else Color3.fromRGB(70, 40, 26),
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
	if Theme.Halloween then
		updateHalloweenArt(dt, now)
	end
	if characterReady() then
		updateCamera(dt, now)
	end
	if canPlay() then
		reveal()
		ui.Status.Text = if Theme.Halloween then "Premi GIOCA... se hai il coraggio di entrare nelle Mura 🎃" else "Premi GIOCA per entrare nelle Mura"
		if not starting then
			-- il pulsante "esplode" fuori e poi pulsa piano
			local pop = math.clamp((now - revealClock) / 0.45, 0, 1)
			local base = 0.6 + 0.4 * Util.Ease(pop, "BackOut")
			ui.PlayScale.Scale = base + math.sin(now * 2.6) * 0.03 * pop
		end
	else
		local dots = string.rep(".", 1 + math.floor(now * 2) % 3)
		ui.Status.Text = (if C.ClientData.Ready then "Arrivo al campo di addestramento" else "Caricamento dei progressi") .. dots
		-- il personaggio non arriva: chiediamo al server di ricrearlo (ogni 15 secondi)
		if not characterReady() and now >= nextCharacterRequest then
			nextCharacterRequest = now + 15
			ui.Status.Text = "Il caricamento sta impiegando più del solito, riprovo" .. dots
			Net.Event("ClientReady"):FireServer("NoCharacter")
		end
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
	-- sicurezza: il nero non resta mai sullo schermo, qualunque cosa succeda
	task.delay(4, function()
		if fade.Parent then
			fade:Destroy()
		end
	end)
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
	table.clear(bats)
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
