--[[
	CutsceneController
	Scene animate della storia: inquadrature cinematografiche, bande nere,
	sottotitoli, giganti costruiti al volo, fulmini, esplosioni e vapore.
	Il prologo viene girato su un "set" costruito nel cielo, così si vede sempre.
	Le altre scene si girano nel mondo vero: prima di cominciare si carica la zona
	(streaming), la telecamera non entra mai dentro muri o colline e lo schermo nero
	iniziale si apre da solo appena la prima inquadratura è pronta.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Lib.Net)
local Util = require(Shared.Lib.Util)
local W = require(Shared.Data.WorldLayout)
local Zones = require(Shared.Data.Zones)
local NPCs = require(Shared.Data.NPCs)
local TitanBuilder = require(Shared.Anim.TitanBuilder)
local ProceduralAnimator = require(Shared.Anim.ProceduralAnimator)
local Poses = require(Shared.Anim.Poses)

local CutsceneController = {}
local C
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local playing = false
local skipRequested = false
local revealed = false -- lo schermo nero iniziale è già stato aperto?
local shotCFrame: CFrame? = nil -- inquadratura attuale (senza scossa)
local props: { Instance } = {}
local animators: { any } = {}
local ui: any = nil

-- INTERFACCIA (bande nere e sottotitoli) -----------------------------------------------------

local function buildUI()
	local Theme = require(script.Parent.Parent.UI.Theme)
	local layer = C.UIController.Layers.Top
	local holder = Theme.New("Frame", { Name = "Cinematica", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = layer })
	local top = Theme.New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), Parent = holder })
	local bottom = Theme.New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 0), Parent = holder })
	local speaker = Theme.Label("", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -88),
		Size = UDim2.new(0.8, 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.Header,
		TextSize = 20,
		TextColor3 = Theme.Colors.Gold,
		ZIndex = 8,
		Parent = holder,
	})
	local text = Theme.Label("", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.new(0.8, 0, 0, 56),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.Body,
		TextSize = 22,
		TextStrokeTransparency = 0.5,
		ZIndex = 8,
		Parent = holder,
	})
	local fade = Theme.New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = holder })
	local title = Theme.Label("", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0, 80),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.Title,
		TextSize = 54,
		TextColor3 = Theme.Colors.GoldBright,
		TextTransparency = 1,
		ZIndex = 6,
		Parent = holder,
	})
	local skip = Theme.Button("Salta ▶▶", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 20),
		Size = UDim2.fromOffset(120, 36),
		ZIndex = 7,
		Parent = holder,
	}, function()
		skipRequested = true
	end)
	-- scheda informativa a sinistra (usata dalla scena dei giganti del tutorial)
	local card = Theme.New("CanvasGroup", { Name = "Scheda", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 40, 0.42, 0), Size = UDim2.fromOffset(360, 200), BackgroundTransparency = 1, GroupTransparency = 1, ZIndex = 7, Parent = holder })
	C.UIController.AttachScale(card)
	local cardBack = Theme.New("Frame", { Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4), BackgroundColor3 = Theme.Colors.Panel, BackgroundTransparency = 0.12, ZIndex = 7, Parent = card })
	Theme.Corner(cardBack, 12)
	Theme.Stroke(cardBack, Theme.Colors.Gold, 2, 0.15)
	Theme.Gradient(cardBack, Color3.fromRGB(62, 50, 38), Color3.fromRGB(26, 20, 16), 90)
	local cardTitle = Theme.Label("", { Position = UDim2.fromOffset(18, 14), Size = UDim2.new(1, -36, 0, 30), Font = Theme.Fonts.Header, TextSize = 22, TextColor3 = Theme.Colors.GoldBright, ZIndex = 8, Parent = card })
	local cardLine = Theme.New("Frame", { Position = UDim2.fromOffset(18, 48), Size = UDim2.new(1, -36, 0, 2), BackgroundColor3 = Theme.Colors.Gold, BorderSizePixel = 0, ZIndex = 8, Parent = card })
	Theme.New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = cardLine })
	local cardText = Theme.Label("", { Position = UDim2.fromOffset(18, 58), Size = UDim2.new(1, -36, 1, -70), Font = Theme.Fonts.Body, TextSize = 15, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 8, Parent = card })
	ui = { Holder = holder, Top = top, Bottom = bottom, Speaker = speaker, Text = text, Fade = fade, Title = title, Skip = skip, Card = card, CardTitle = cardTitle, CardText = cardText }
end

local function letterbox(on: boolean)
	ui.Holder.Visible = true
	local h = if on then 90 else 0
	TweenService:Create(ui.Top, TweenInfo.new(0.6, Enum.EasingStyle.Quart), { Size = UDim2.new(1, 0, 0, h) }):Play()
	TweenService:Create(ui.Bottom, TweenInfo.new(0.6, Enum.EasingStyle.Quart), { Size = UDim2.new(1, 0, 0, h) }):Play()
	if not on then
		ui.Speaker.Text = ""
		ui.Text.Text = ""
	end
end

-- API usata dagli script delle scene ----------------------------------------------------------

local api = {}

function api.Wait(t: number)
	local start = os.clock()
	while os.clock() - start < t do
		if skipRequested then
			error("skip", 0)
		end
		task.wait()
	end
end

function api.Say(speaker: string, text: string, duration: number?)
	ui.Speaker.Text = if speaker == "" then "" else NPCs.SpeakerName(speaker)
	ui.Text.Text = ""
	-- effetto macchina da scrivere
	task.spawn(function()
		for i = 1, #text do
			if ui.Text.Text == "" and i > 1 then
				return
			end
			ui.Text.Text = text:sub(1, i)
			task.wait(0.018)
		end
	end)
	if duration then
		api.Wait(duration)
	end
end

function api.Title(text: string, duration: number)
	ui.Title.Text = text
	TweenService:Create(ui.Title, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
	api.Wait(duration)
	TweenService:Create(ui.Title, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
end

-- Scheda informativa a sinistra: entra scorrendo, sostituisce quella di prima
function api.Card(title: string, lines: { string })
	local card = ui.Card
	local function fill()
		ui.CardTitle.Text = title
		ui.CardText.Text = "•  " .. table.concat(lines, "\n•  ")
		card.Position = UDim2.new(0, 10, 0.42, 0)
		TweenService:Create(card, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { Position = UDim2.new(0, 40, 0.42, 0), GroupTransparency = 0 }):Play()
	end
	if card.GroupTransparency < 0.99 then
		TweenService:Create(card, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0, 20, 0.42, 0), GroupTransparency = 1 }):Play()
		task.delay(0.22, fill)
	else
		fill()
	end
end

function api.HideCard()
	TweenService:Create(ui.Card, TweenInfo.new(0.3), { GroupTransparency = 1 }):Play()
end

-- Segno luminoso che pulsa su un punto (o che segue una parte): nuca, occhi, caviglie...
function api.Highlight(target: BasePart | Vector3, color: Color3, size: number, text: string?): Part
	local mark = api.Part({ Name = "Evidenzia", Shape = Enum.PartType.Ball, Size = Vector3.one * size, Material = Enum.Material.Neon, Color = color, Transparency = 0.35, CastShadow = false })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = size * 4
	light.Brightness = 2
	light.Parent = mark
	if text then
		local board = Instance.new("BillboardGui")
		board.Size = UDim2.fromOffset(140, 30)
		board.StudsOffset = Vector3.new(0, size * 0.9 + 1.5, 0)
		board.AlwaysOnTop = true
		board.LightInfluence = 0
		board.Parent = mark
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBlack
		label.TextSize = 20
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.2
		label.Text = text
		label.Parent = board
	end
	local start = os.clock()
	task.spawn(function()
		while mark.Parent do
			local t = os.clock() - start
			local pos = if typeof(target) == "Vector3" then target else (target :: BasePart).Position
			local pulse = 1 + math.sin(t * 6) * 0.18
			mark.Size = Vector3.one * size * pulse
			mark.CFrame = CFrame.new(pos)
			mark.Transparency = 0.3 + (1 - pulse) * 0.8
			RunService.RenderStepped:Wait()
		end
	end)
	return mark
end

function api.FadeOut(t: number)
	TweenService:Create(ui.Fade, TweenInfo.new(t), { BackgroundTransparency = 0 }):Play()
	api.Wait(t)
end

function api.FadeIn(t: number)
	revealed = true
	TweenService:Create(ui.Fade, TweenInfo.new(t), { BackgroundTransparency = 1 }):Play()
end

-- Apre lo schermo nero iniziale (una volta sola): chiamata in automatico dalla prima inquadratura
local function reveal()
	if not revealed then
		api.FadeIn(0.9)
	end
end

-- Carica dal server la zona dove si gira la scena (con lo streaming attivo le zone lontane non ci sono)
function api.Stream(position: Vector3)
	pcall(function()
		player:RequestStreamAroundAsync(position, 4)
	end)
end

-- La telecamera non deve finire dentro un muro, una casa o una collina: se tra il soggetto
-- e la telecamera c'è qualcosa, la telecamera si avvicina fino a vedere il soggetto.
local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Include
local function clearView(from: Vector3, at: Vector3): Vector3
	local map = workspace:FindFirstChild(Config.Folders.Map)
	sightParams.FilterDescendantsInstances = if map then { workspace.Terrain, map } else { workspace.Terrain }
	local offset = from - at
	if offset.Magnitude < 1 then
		return from
	end
	local hit = workspace:Raycast(at, offset, sightParams)
	if hit and (hit.Position - at).Magnitude > offset.Magnitude * 0.2 then
		return hit.Position - offset.Unit * 3
	end
	return from
end

-- Muove la telecamera da un'inquadratura all'altra (attende la fine)
function api.Shot(from: CFrame, to: CFrame, duration: number, style: string?)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = from
	shotCFrame = from
	reveal()
	local start = os.clock()
	while true do
		if skipRequested then
			error("skip", 0)
		end
		local k = math.clamp((os.clock() - start) / duration, 0, 1)
		local shot = from:Lerp(to, Util.Ease(k, style or "SineInOut"))
		shotCFrame = shot
		camera.CFrame = shot * C.CameraController.CinematicShake()
		if k >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
end

-- Come Shot, ma senza attendere (la scena continua mentre la telecamera si muove)
function api.ShotAsync(from: CFrame, to: CFrame, duration: number, style: string?)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = from
	shotCFrame = from
	reveal()
	task.spawn(function()
		pcall(api.Shot, from, to, duration, style)
	end)
end

function api.Look(from: Vector3, at: Vector3): CFrame
	return CFrame.lookAt(clearView(from, at), at)
end

function api.Titan(look: string, height: number, position: Vector3, yaw: number?): Model
	local model = TitanBuilder.Build({ Height = height, Look = look, Seed = math.random(1, 1e6), Cinematic = true })
	local hip = model:GetAttribute("HipHeight") :: number
	model:PivotTo(CFrame.new(position + Vector3.new(0, hip, 0)) * CFrame.Angles(0, math.rad(yaw or 0), 0))
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = false
		end
	end
	local root = model.PrimaryPart :: BasePart
	root.Anchored = true
	model.Parent = workspace:FindFirstChild("EffettiLocali") or workspace
	table.insert(props, model)
	local animator = ProceduralAnimator.new(model, true)
	animator.PositionScale = height
	animator.Context.Seed = math.random() * 10
	animator:SetLayer("Base", if look == "Strisciante" then Poses.Titan.Crawl else Poses.Titan.Locomotion, 1, 0, 10)
	table.insert(animators, animator)
	model:SetAttribute("CutsceneAnimator", #animators)
	return model
end

function api.Animate(model: Model, clipName: string)
	local index = model:GetAttribute("CutsceneAnimator")
	local animator = index and animators[index]
	local clip = Poses.Titan.Clips[clipName]
	if animator and clip then
		animator:Play(clip)
	end
end

function api.Walk(model: Model, amount: number, run: number?)
	local index = model:GetAttribute("CutsceneAnimator")
	local animator = index and animators[index]
	if animator then
		animator.Context.Move = amount
		animator.Context.Run = run or 0
	end
end

-- Sposta un gigante (o qualsiasi modello) nel tempo, senza attendere
function api.Move(model: Model, to: CFrame, duration: number)
	local from = model:GetPivot()
	local start = os.clock()
	task.spawn(function()
		while model.Parent do
			local k = math.clamp((os.clock() - start) / duration, 0, 1)
			model:PivotTo(from:Lerp(to, Util.Ease(k, "SineInOut")))
			if k >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

function api.Part(props_: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props_ do
		(p :: any)[k] = v
	end
	p.Parent = workspace:FindFirstChild("EffettiLocali") or workspace
	table.insert(props, p)
	return p
end

local function cleanup()
	shotCFrame = nil
	for _, p in props do
		if p.Parent then
			p:Destroy()
		end
	end
	table.clear(props)
	for _, a in animators do
		a:Destroy()
	end
	table.clear(animators)
end

local function fx(): any
	return C.EffectsController
end

-- SCENE -----------------------------------------------------------------------------------------

local Scenes = {}

-- Il set del prologo è nel cielo sopra il campo di addestramento
local function buildPrologueSet(base: Vector3)
	api.Part({ Name = "Terreno", Size = Vector3.new(700, 4, 700), CFrame = CFrame.new(base - Vector3.new(0, 2, 0)), Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(130, 124, 112) })
	api.Part({ Name = "Prato", Size = Vector3.new(700, 3.8, 400), CFrame = CFrame.new(base + Vector3.new(0, -2, 520)), Material = Enum.Material.Grass, Color = Color3.fromRGB(96, 140, 72) })
	-- il Muro di Cenere
	for i = -4, 4 do
		api.Part({ Name = "Muro", Size = Vector3.new(66, 160, 28), CFrame = CFrame.new(base + Vector3.new(i * 64, 80, 300)), Material = Enum.Material.Concrete, Color = Color3.fromRGB(196, 188, 170) })
	end
	api.Part({ Name = "Cancello", Size = Vector3.new(36, 62, 30), CFrame = CFrame.new(base + Vector3.new(0, 31, 300)), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(80, 56, 40) })
	-- case del distretto
	local rng = Random.new(312)
	for gx = -4, 4 do
		for gz = -3, 4 do
			if gx ~= 0 and rng:NextNumber() < 0.8 then
				local w = rng:NextNumber(20, 28)
				local h = rng:NextInteger(2, 3) * 12
				local pos = base + Vector3.new(gx * 36, h / 2, gz * 36 + 60)
				api.Part({ Size = Vector3.new(w, h, w * 0.8), CFrame = CFrame.new(pos), Material = Enum.Material.Plaster, Color = Color3.fromRGB(226, 214, 190) })
				local roof = Instance.new("WedgePart")
				roof.Anchored = true
				roof.CanCollide = false
				roof.Size = Vector3.new(w + 2, w * 0.4, w * 0.4 + 1)
				roof.CFrame = CFrame.new(pos + Vector3.new(0, h / 2 + w * 0.2, -w * 0.2))
				roof.Material = Enum.Material.ClayRoofTiles
				roof.Color = Color3.fromRGB(166, 78, 52)
				roof.Parent = workspace:FindFirstChild("EffettiLocali") or workspace
				table.insert(props, roof)
				local roof2 = roof:Clone()
				roof2.CFrame = CFrame.new(pos + Vector3.new(0, h / 2 + w * 0.2, w * 0.2)) * CFrame.Angles(0, math.pi, 0)
				roof2.Parent = roof.Parent
				table.insert(props, roof2)
			end
		end
	end
end

Scenes.Prologo = function()
	local base = Vector3.new(-356, 2600, 508)
	buildPrologueSet(base)
	local colossal = api.Titan("Vulcano", 190, base + Vector3.new(0, -130, 380), 180)
	api.Walk(colossal, 0)
	letterbox(true)
	api.FadeIn(1.5)
	api.ShotAsync(api.Look(base + Vector3.new(-160, 120, -160), base + Vector3.new(0, 40, 200)), api.Look(base + Vector3.new(-60, 70, -120), base + Vector3.new(0, 60, 300)), 7)
	api.Say("Narratore", "Anno 312 del Calendario delle Isole. Distretto di Halvar, sull'Isola di Cenere.", 3.5)
	api.Say("Narratore", "Per generazioni le Mura ci hanno protetti. E noi avevamo dimenticato la paura.", 3.5)
	-- il Vulcano si alza oltre il Muro
	fx().Lightning(base + Vector3.new(0, 700, 400), base + Vector3.new(0, 150, 380), Color3.fromRGB(255, 236, 130), 4)
	fx().Flash(Color3.fromRGB(255, 240, 200), 0.45, 0.6)
	if C.SoundController then
		C.SoundController.Play("Thunder")
	end
	api.Move(colossal, CFrame.new(base + Vector3.new(0, colossal:GetAttribute("HipHeight") :: number, 380)) * CFrame.Angles(0, math.pi, 0), 3.5)
	for i = 0, 6 do
		task.delay(i * 0.5, function()
			fx().Steam(base + Vector3.new(math.random(-60, 60), 150, 360), 40, 10, 4)
		end)
	end
	api.ShotAsync(api.Look(base + Vector3.new(0, 10, 120), base + Vector3.new(0, 150, 300)), api.Look(base + Vector3.new(10, 6, 150), base + Vector3.new(0, 200, 330)), 4.5)
	api.Say("Narratore", "Quel giorno, l'umanità ricordò.", 4.5)
	-- il calcio al cancello
	api.Animate(colossal, "Kick")
	api.Wait(0.6)
	fx().Explosion(base + Vector3.new(0, 30, 300), 40, true)
	fx().DebrisBurst(base + Vector3.new(0, 40, 290), 30, 6, Color3.fromRGB(150, 144, 130), Enum.Material.Concrete, 140)
	if C.CameraController then
		C.CameraController.Shake(1, 1.2)
	end
	api.ShotAsync(api.Look(base + Vector3.new(80, 30, 100), base + Vector3.new(0, 30, 300)), api.Look(base + Vector3.new(60, 25, 140), base + Vector3.new(0, 20, 300)), 3.5)
	api.Say("Narratore", "Il cancello esplose come se fosse di carta. I giganti entrarono nel distretto.", 3.5)
	-- la fiala
	local vial = api.Part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 0.4, 0.4), CFrame = CFrame.new(base + Vector3.new(30, 0.4, 40)) * CFrame.Angles(0, 0.6, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(120, 255, 150) })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(120, 255, 150)
	light.Range = 10
	light.Parent = vial
	api.Shot(api.Look(base + Vector3.new(36, 8, 30), base + Vector3.new(30, 0, 40)), api.Look(base + Vector3.new(32, 3, 37), base + Vector3.new(30, 0.4, 40)), 0.1)
	api.ShotAsync(api.Look(base + Vector3.new(32, 3, 37), base + Vector3.new(30, 0.4, 40)), api.Look(base + Vector3.new(31, 2, 38.5), base + Vector3.new(30, 0.4, 40)), 5)
	api.Say("Narratore", "Tra le macerie e il vapore, qualcuno perse una fiala spezzata... con un simbolo che nessuno aveva mai visto.", 5)
	api.FadeOut(1.2)
	letterbox(false)
	api.Title("ANNI DOPO...", 2.5)
end

Scenes.Calaneth = function()
	local zone = Zones.Get("Calaneth")
	local gate = W.DistrictGatePoint("Calaneth")
	local outward = W.DistrictOutward("Calaneth")
	local outer = gate + outward * 140
	api.Stream(outer)
	local colossal = api.Titan("Vulcano", 190, outer + outward * 60 - Vector3.new(0, 120, 0), 0)
	colossal:PivotTo(CFrame.lookAt(colossal:GetPivot().Position, colossal:GetPivot().Position - outward))
	letterbox(true)
	local camPos = gate + outward * 40 + Vector3.new(30, W.GroundY + 55, 0)
	api.ShotAsync(api.Look(camPos, outer + Vector3.new(0, 120, 0)), api.Look(camPos + Vector3.new(0, -10, 0), outer + Vector3.new(0, 170, 0)), 5)
	fx().Lightning(outer + outward * 60 + Vector3.new(0, 700, 0), outer + outward * 60 + Vector3.new(0, 150, 0), Color3.fromRGB(255, 236, 130), 4)
	fx().Flash(Color3.fromRGB(255, 240, 200), 0.4, 0.6)
	local standing = outer + outward * 60 + Vector3.new(0, W.GroundY + (colossal:GetAttribute("HipHeight") :: number), 0)
	api.Move(colossal, CFrame.lookAt(standing, standing - outward), 3)
	api.Say("Narratore", "Anni dopo, lo stesso gigante di fuoco tornò ad affacciarsi, questa volta sul Muro Vermiglio.", 3.5)
	api.Animate(colossal, "Kick")
	api.Wait(0.6)
	fx().Explosion(outer + Vector3.new(0, 30, 0), 40, true)
	if C.CameraController then
		C.CameraController.Shake(1, 1)
	end
	api.Say("Narratore", "Il cancello di Calaneth è stato sfondato. Corri al distretto!", 3)
	if zone then
		api.Wait(0.5)
	end
	letterbox(false)
end

Scenes.TobiasGigante = function()
	local zone = Zones.Get("Calaneth")
	local center = zone and zone.Center or Vector3.zero
	api.Stream(center)
	local tobias = api.Titan("Furia", 48, center + Vector3.new(30, 0, 30), 200)
	local enemy = api.Titan("Puro", 32, center + Vector3.new(30, 0, -12), 20)
	letterbox(true)
	api.ShotAsync(api.Look(center + Vector3.new(-70, 50, 10), center + Vector3.new(30, 30, 10)), api.Look(center + Vector3.new(-50, 42, 0), center + Vector3.new(30, 35, 10)), 6)
	api.Animate(tobias, "Roar")
	if C.SoundController then
		C.SoundController.Play("Roar")
	end
	api.Say("Narratore", "Un gigante dagli occhi verdi si gettò sugli altri giganti, urlando di rabbia.", 3)
	api.Animate(tobias, "Punch")
	api.Wait(0.55)
	fx().Explosion(center + Vector3.new(30, 25, -10), 12, false)
	api.Animate(enemy, "Death")
	api.Say("Narratore", "Quando il vapore si diradò, dalla sua nuca emerse un ragazzo: Tobias Renz.", 3.5)
	fx().Steam(center + Vector3.new(30, 40, 30), 30, 20, 5)
	api.Wait(1)
	letterbox(false)
end

Scenes.Cacciatrice = function()
	local zone = Zones.Get("Foresta")
	local center = zone and zone.Center or Vector3.zero
	api.Stream(center)
	local female = api.Titan("Cacciatrice", 45, center + Vector3.new(-120, 0, 0), 270)
	api.Walk(female, 1, 1)
	letterbox(true)
	api.Move(female, CFrame.new(center + Vector3.new(80, female:GetAttribute("HipHeight") :: number, 0)) * CFrame.Angles(0, math.rad(-90), 0), 5)
	api.Shot(api.Look(center + Vector3.new(-40, 45, 80), center + Vector3.new(-100, 25, 0)), api.Look(center + Vector3.new(40, 40, 70), center + Vector3.new(60, 30, 0)), 5)
	api.Say("Roth", "Qualcosa corre tra gli alberi... è un gigante, ma si muove come un soldato!", 3)
	api.Walk(female, 0)
	api.Animate(female, "Roar")
	api.Say("Falkner", "Il Gigante Cacciatrice! A tutte le squadre: prepararsi al combattimento!", 3)
	letterbox(false)
end

Scenes.Fauno = function()
	local zone = Zones.Get("Ostrava")
	local center = zone and zone.Center or Vector3.zero
	api.Stream(center)
	local beast = api.Titan("Fauno", 55, center + Vector3.new(0, 0, -150), 0)
	letterbox(true)
	api.ShotAsync(api.Look(center + Vector3.new(40, 60, -40), center + Vector3.new(0, 50, -150)), api.Look(center + Vector3.new(30, 40, -60), center + Vector3.new(0, 55, -150)), 6)
	api.Say("Narratore", "Sulla collina, un gigante coperto di pelo osservava il castello.", 3)
	api.Animate(beast, "Throw")
	api.Wait(0.9)
	fx().Projectile(center + Vector3.new(0, 55, -140), center + Vector3.new(10, 10, 20), 1.3, "Rock", 8)
	api.Wait(1.3)
	fx().Explosion(center + Vector3.new(10, 10, 20), 18, false)
	api.Say("Varis", "Lancia massi come se fossero sassolini! Al riparo!", 2.5)
	letterbox(false)
end

Scenes.Tradimento = function()
	local zone = Zones.Get("GolaEdenia")
	local center = zone and zone.Center or Vector3.zero
	api.Stream(center)
	letterbox(true)
	local camFrom = api.Look(center + Vector3.new(-60, 40, -60), center + Vector3.new(0, 30, 0))
	api.ShotAsync(camFrom, api.Look(center + Vector3.new(-40, 30, -40), center + Vector3.new(0, 40, 0)), 7)
	api.Say("Varis", "Mi dispiace. Io sono il Gigante Bastione. E Kael... è il Vulcano.", 3.5)
	fx().Lightning(center + Vector3.new(0, 600, 0), center, Color3.fromRGB(255, 236, 130), 3)
	fx().Flash(Color3.fromRGB(255, 240, 200), 0.45, 0.5)
	if C.SoundController then
		C.SoundController.Play("Thunder")
	end
	local armored = api.Titan("Bastione", 48, center, 45)
	fx().TransformBurst(center, 48)
	api.Wait(1)
	api.Animate(armored, "Roar")
	api.Say("Varis", "Non siamo noi i vostri nemici. Ma devo portare Tobias via con me!", 3.5)
	letterbox(false)
end

Scenes.Urlo = function()
	local root = Util.GetRoot(player.Character)
	local center = if root then root.Position else Vector3.zero
	letterbox(true)
	api.ShotAsync(api.Look(center + Vector3.new(30, 15, 30), center), api.Look(center + Vector3.new(50, 40, 50), center), 6)
	api.Say("Tobias", "FERMATEVI!", 1.5)
	for i = 0, 3 do
		task.delay(i * 0.25, function()
			fx().Shockwave(center, 60 + i * 50, Color3.fromRGB(150, 220, 255), 0.9, 1)
		end)
	end
	if C.CameraController then
		C.CameraController.Shake(0.8, 1)
	end
	api.Say("Narratore", "Per un istante, ogni gigante della gola si immobilizzò e si voltò verso Tobias.", 4)
	letterbox(false)
end

Scenes.Strisciante = function()
	local zone = Zones.Get("PianaOrvel")
	local center = zone and zone.Center or Vector3.zero
	api.Stream(center)
	local crawler = api.Titan("Strisciante", 110, center + Vector3.new(0, -60, -90), 180)
	letterbox(true)
	api.Move(crawler, CFrame.new(center + Vector3.new(0, (crawler:GetAttribute("HipHeight") :: number) * 0.6, -90)) * CFrame.Angles(0, math.pi, 0), 4)
	for i = 0, 6 do
		task.delay(i * 0.5, function()
			fx().Steam(center + Vector3.new(math.random(-40, 40), 10, -90 + math.random(-30, 30)), 40, 10, 4)
			fx().DebrisBurst(center + Vector3.new(0, 5, -70), 4, 5, nil, nil, 80)
		end)
	end
	api.ShotAsync(api.Look(center + Vector3.new(-120, 50, 80), center + Vector3.new(0, 40, -90)), api.Look(center + Vector3.new(-90, 40, 60), center + Vector3.new(0, 50, -90)), 6)
	if C.CameraController then
		C.CameraController.Shake(0.9, 3)
	end
	api.Say("Narratore", "Lord Ansel Vellmore aveva iniettato il siero. La terra della piana si aprì.", 3.5)
	api.Say("Elise", "Padre... cosa sei diventato?", 2.5)
	letterbox(false)
end

Scenes.Vulcano = function()
	local zone = Zones.Get("Halvar")
	local center = zone and zone.Center or Vector3.zero
	api.Stream(center)
	letterbox(true)
	api.ShotAsync(api.Look(center + Vector3.new(-150, 40, -120), center + Vector3.new(0, 100, 60)), api.Look(center + Vector3.new(-120, 30, -100), center + Vector3.new(0, 140, 60)), 7)
	api.Say("Narratore", "Una luce accecante squarciò il cielo sopra Halvar.", 2.5)
	fx().Lightning(center + Vector3.new(0, 900, 60), center + Vector3.new(0, 0, 60), Color3.fromRGB(255, 236, 130), 6)
	fx().Explosion(center + Vector3.new(0, 60, 60), 70, true)
	local colossal = api.Titan("Vulcano", 190, center + Vector3.new(0, 0, 60), 180)
	fx().TransformBurst(center + Vector3.new(0, 0, 60), 190)
	api.Wait(1.5)
	api.Animate(colossal, "Roar")
	api.Say("Kael", "Perdonami. Non posso tornare indietro, ormai.", 3)
	letterbox(false)
end

Scenes.TobiasRibelle = function()
	local root = Util.GetRoot(player.Character)
	local center = if root then root.Position else Vector3.zero
	letterbox(true)
	api.ShotAsync(api.Look(center + Vector3.new(0, 80, 80), center), api.Look(center + Vector3.new(0, 120, 120), center), 6)
	fx().Lightning(center + Vector3.new(120, 700, -120), center + Vector3.new(120, 0, -120), Color3.fromRGB(255, 236, 130), 3)
	api.Say("Tobias", "Ho visto il futuro. Nessuno di voi capirebbe.", 3)
	api.Say("Tobias", "Il mondo ci odierà sempre. Allora sarò io a decidere come finirà.", 3.5)
	letterbox(false)
end

Scenes.Primordiale = function()
	local zone = Zones.Get("FronteMarcia")
	local center = zone and zone.Center or Vector3.zero
	api.Stream(center)
	local boss = api.Titan("Primordiale", 240, center + Vector3.new(0, -200, 120), 180)
	local marchers = {}
	for i = -2, 2 do
		local m = api.Titan("Marcia", 100, center + Vector3.new(i * 70, 0, 260), 180)
		api.Walk(m, 1, 0)
		api.Move(m, CFrame.new(center + Vector3.new(i * 70, m:GetAttribute("HipHeight") :: number, 140)) * CFrame.Angles(0, math.pi, 0), 8)
		table.insert(marchers, m)
	end
	letterbox(true)
	api.Move(boss, CFrame.new(center + Vector3.new(0, boss:GetAttribute("HipHeight") :: number, 120)) * CFrame.Angles(0, math.pi, 0), 5)
	if C.CameraController then
		C.CameraController.Shake(1, 5)
	end
	api.ShotAsync(api.Look(center + Vector3.new(-200, 40, -150), center + Vector3.new(0, 120, 120)), api.Look(center + Vector3.new(-150, 30, -120), center + Vector3.new(0, 220, 120)), 8)
	api.Say("Vael", "Finalmente. Tutti e nove i poteri in un solo corpo.", 3)
	api.Say("Vael", "Io riscriverò il mondo. E tutto comincerà da capo.", 3.5)
	api.Animate(boss, "Roar")
	api.Say("Falkner", "A tutti i soldati: questa è l'ultima battaglia. Volate oltre la paura!", 3)
	letterbox(false)
end

-- Cerimonia d'apertura della Grande Inaugurazione: fuochi sul Campo, l'arco d'oro
-- e il Colosso d'Oro che cade dal cielo e si alza oltre il Muro Vermiglio
Scenes.Inaugurazione = function()
	local camp = Zones.Get("CampoAddestramento")
	local c = if camp then camp.Center else Vector3.new(0, W.GroundY, 0)
	local arch = c + Vector3.new(0, 0, -58)
	local wallPoint = W.WallPoint("Vermiglia", 215)
	local outward = Util.SafeUnit(Util.Flat(wallPoint - W.IslandCenter("Vermiglia")))
	local landing = Vector3.new(wallPoint.X, W.GroundY, wallPoint.Z) + outward * 150
	api.Stream(c)
	local fw = C.FireworksController
	letterbox(true)
	-- 1. dall'alto: il Campo in festa e i primi fuochi
	if fw then
		fw.Show(c + Vector3.new(0, 0, -30), 26, math.random(1, 1e6))
	end
	api.ShotAsync(api.Look(c + Vector3.new(170, 150, 150), c + Vector3.new(0, 70, -40)), api.Look(c + Vector3.new(100, 70, 100), c + Vector3.new(0, 110, -40)), 7.5)
	api.Title("GRANDE INAUGURAZIONE", 3)
	api.Say("Narratore", "Soldati dell'Arcipelago! Oggi le porte delle Isole si aprono a tutti.", 4)
	-- 2. l'arco d'oro con la scritta
	api.ShotAsync(api.Look(arch + Vector3.new(34, 10, 62), arch + Vector3.new(0, 32, 0)), api.Look(arch + Vector3.new(-22, 22, 46), arch + Vector3.new(0, 40, 0)), 5)
	api.Say("Narratore", "Esperienza e oro doppi, sfide speciali e premi che non torneranno mai più.", 4.5)
	-- 3. il Colosso d'Oro cade dal cielo oltre il Muro
	api.Stream(landing)
	local camPos = c + Vector3.new(70, 24, -40)
	api.ShotAsync(api.Look(camPos, landing + Vector3.new(0, 260, 0)), api.Look(camPos + Vector3.new(0, -6, 0), landing + Vector3.new(0, 170, 0)), 6)
	if fw then
		fw.ColossusArrival(landing, 200)
	end
	api.Wait(2.1)
	local colossus = api.Titan("Dorato", 200, landing - Vector3.new(0, 210, 0), 0)
	local hip = colossus:GetAttribute("HipHeight") :: number
	local facing = CFrame.lookAt(landing, Vector3.new(c.X, W.GroundY, c.Z)).Rotation
	colossus:PivotTo(CFrame.new(landing - Vector3.new(0, 200, 0)) * facing)
	api.Move(colossus, CFrame.new(landing + Vector3.new(0, hip, 0)) * facing, 3.2)
	if C.CameraController then
		C.CameraController.Shake(0.9, 3)
	end
	api.Say("Narratore", "Durante gli Admin Abuse il Colosso d'Oro cadrà dal cielo. Chi lo abbatte... vince l'oro.", 3.8)
	api.Animate(colossus, "Roar")
	if C.SoundController then
		C.SoundController.Play("Roar", landing, { Range = 4000, Volume = 1 })
	end
	api.Wait(1.5)
	-- 4. gran finale
	if fw then
		fw.Show(c + Vector3.new(0, 0, -60), 8, math.random(1, 1e6))
	end
	api.ShotAsync(api.Look(c + Vector3.new(-60, 30, 90), c + Vector3.new(0, 120, -60)), api.Look(c + Vector3.new(-40, 60, 60), c + Vector3.new(0, 160, -80)), 5)
	api.Title("VOLATE OLTRE LA PAURA!", 3)
	api.FadeOut(1)
	letterbox(false)
end

-- Addestramento di base: Mira spiega i giganti (taglie, nuca, occhi e arti, presa, anomali, boss, sieri).
-- Si gira su un prato nel cielo con un tratto di Muro sullo sfondo; i giganti guardano verso -Z.
Scenes.TutorialGiganti = function()
	local base = Vector3.new(1400, 2700, -1200)
	api.Part({ Name = "Prato", Size = Vector3.new(900, 4, 900), CFrame = CFrame.new(base - Vector3.new(0, 2, 0)), Material = Enum.Material.Grass, Color = Color3.fromRGB(98, 138, 74) })
	for i = -5, 5 do
		api.Part({ Name = "Muro", Size = Vector3.new(80, 120, 26), CFrame = CFrame.new(base + Vector3.new(i * 78, 60, 340)), Material = Enum.Material.Slate, Color = Color3.fromRGB(190, 182, 166) })
	end
	local rng = Random.new(77)
	for _ = 1, 16 do
		local p = base + Vector3.new(rng:NextNumber(-400, 400), 0, rng:NextNumber(280, 320))
		local h = rng:NextNumber(30, 55)
		api.Part({ Name = "Tronco", Size = Vector3.new(4, h, 4), CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)), Material = Enum.Material.Wood, Color = Color3.fromRGB(96, 70, 48) })
		api.Part({ Name = "Chioma", Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(26, 38), CFrame = CFrame.new(p + Vector3.new(0, h, 0)), Material = Enum.Material.LeafyGrass, Color = Color3.fromRGB(70, 112, 58) })
	end
	local small = api.Titan("Puro", 10, base + Vector3.new(-70, 0, 40), 0)
	local mid = api.Titan("Puro", 22, base + Vector3.new(-12, 0, 50), 0)
	local big = api.Titan("Puro", 48, base + Vector3.new(78, 0, 70), 0)
	api.Walk(small, 0)
	letterbox(true)
	api.FadeIn(1)

	-- 1. le taglie, in fila
	api.ShotAsync(api.Look(base + Vector3.new(-150, 10, -60), base + Vector3.new(-60, 8, 40)), api.Look(base + Vector3.new(150, 26, -110), base + Vector3.new(50, 26, 60)), 7.5)
	api.Card("🧍 Le taglie", { "Da 3 a 15 metri: più sono grandi, più sono lenti ma forti", "Vivono fuori dalle Mura, nelle zone colorate della mappa", "Più sali di livello, più grandi li affronti" })
	api.Say("Mira", "Ce ne sono di tutte le taglie: da 3 a 15 metri. Più sono grandi, più sono lenti... e più fanno male.", 4)
	api.Say("Mira", "Li trovi fuori dalle Mura. Sulla mappa le zone gialle sono quelle giuste per il tuo livello.", 3.5)

	-- 2. la nuca del più grande, vista da dietro
	local napePart = big:FindFirstChild("Nape", true)
	local nape = if napePart and napePart:IsA("BasePart") then napePart.Position else big:GetPivot().Position + Vector3.new(0, 20, 6)
	api.Highlight(if napePart and napePart:IsA("BasePart") then napePart else nape, Color3.fromRGB(255, 200, 80), 5, "NUCA")
	api.ShotAsync(api.Look(nape + Vector3.new(34, 6, 46), nape), api.Look(nape + Vector3.new(16, 10, 30), nape), 6.5)
	api.Card("🎯 La nuca", { "È il punto debole di OGNI gigante", "Mirino ORO = colpo mortale", "Più vai veloce, più il colpo è forte: TAGLIO PERFETTO" })
	api.Say("Mira", "Il punto debole è sempre la NUCA, dietro il collo. Un taglio profondo e cade.", 3.5)
	api.Say("Mira", "Vola veloce con i rampini e colpisci in corsa: è così che si abbattono i più grandi.", 3)

	-- 3. occhi e caviglie del gigante medio, visto da davanti
	for _, name in { "LeftEye", "RightEye" } do
		local eye = mid:FindFirstChild(name, true)
		if eye and eye:IsA("BasePart") then
			api.Highlight(eye, Color3.fromRGB(120, 200, 255), 1.4)
		end
	end
	for _, name in { "LeftFoot", "RightFoot" } do
		local foot = mid:FindFirstChild(name, true)
		if foot and foot:IsA("BasePart") then
			api.Highlight(foot, Color3.fromRGB(255, 150, 80), 2.6)
		end
	end
	local face = mid:GetPivot().Position + Vector3.new(0, 4, 0)
	api.ShotAsync(api.Look(face + Vector3.new(-12, 2, -46), face), api.Look(face + Vector3.new(8, 0, -36), face - Vector3.new(0, 2, 0)), 7.6)
	api.Card("👁️ Occhi e arti", { "Occhi colpiti = gigante cieco per qualche secondo", "Arto reciso = gigante più lento", "Poi gira dietro e prendi la nuca" })
	api.Say("Mira", "Colpisci gli OCCHI per accecarlo e le CAVIGLIE per rallentarlo. Poi gira dietro e prendi la nuca.", 4)
	-- 4. la presa
	api.Animate(mid, "Grab")
	api.Card("✋ La presa", { "Se ti afferra: SPAZIO più volte per liberarti", "Meglio schivare prima (Ctrl)", "Mai fermarsi davanti alle sue mani" })
	api.Say("Mira", "Attento alle mani! Se ti afferra, premi SPAZIO più volte per liberarti. Meglio schivare prima.", 3.6)

	-- 5. l'anomalo che corre attraverso il prato
	local runner = api.Titan("Puro", 32, base + Vector3.new(-280, 0, 130), -90)
	api.Walk(runner, 1, 1)
	local runnerHip = runner:GetAttribute("HipHeight") :: number
	api.Move(runner, CFrame.new(base + Vector3.new(260, runnerHip, 130)) * CFrame.Angles(0, math.rad(-90), 0), 6)
	api.ShotAsync(api.Look(base + Vector3.new(-120, 14, -40), base + Vector3.new(-120, 20, 130)), api.Look(base + Vector3.new(120, 18, -50), base + Vector3.new(160, 22, 130)), 6)
	api.Card("⚡ Anomali", { "Corrono, saltano e cambiano direzione", "Non seguono nessuno schema", "Durante alcuni eventi valgono gemme 💎" })
	api.Say("Mira", "Gli ANOMALI invece corrono e saltano senza nessuna regola. Non perderli mai di vista.", 3.8)

	-- 6. il boss che ruggisce
	local bossAt = base + Vector3.new(90, 0, 200)
	local boss = api.Titan("Ghignante", 40, bossAt, 0)
	api.ShotAsync(api.Look(bossAt + Vector3.new(30, 6, -110), bossAt + Vector3.new(0, 30, 0)), api.Look(bossAt + Vector3.new(14, 4, -80), bossAt + Vector3.new(0, 36, 0)), 5)
	api.Card("👑 Boss", { "Giganti unici con la barra della vita", "Attacchi speciali: impara a schivarli", "La prima volta che li abbatti: gemme 💎" })
	api.Wait(0.6)
	api.Animate(boss, "Roar")
	if C.SoundController then
		C.SoundController.Play("Roar", bossAt, { Range = 3000, Volume = 1 })
	end
	fx().Shockwave(bossAt + Vector3.new(0, 34, 0), 90, Color3.fromRGB(255, 190, 120), 1.2, 3)
	if C.CameraController then
		C.CameraController.Shake(0.45, 1)
	end
	api.Say("Mira", "E poi ci sono i BOSS: giganti unici, con attacchi speciali. Meglio affrontarli in squadra.", 3.8)

	-- 7. i sieri: il fulmine e un mutaforma che si alza nel vapore
	local shifterAt = base + Vector3.new(-90, 0, 250)
	local shifter = api.Titan("Furia", 48, shifterAt - Vector3.new(0, 70, 0), 0)
	local shifterHip = shifter:GetAttribute("HipHeight") :: number
	api.ShotAsync(api.Look(shifterAt + Vector3.new(-60, 20, -130), shifterAt + Vector3.new(0, 36, 0)), api.Look(shifterAt + Vector3.new(-40, 28, -110), shifterAt + Vector3.new(0, 46, 0)), 5)
	fx().Lightning(shifterAt + Vector3.new(0, 600, 0), shifterAt + Vector3.new(0, 30, 0), Color3.fromRGB(255, 236, 130), 4)
	fx().Flash(Color3.fromRGB(255, 240, 200), 0.4, 0.6)
	if C.SoundController then
		C.SoundController.Play("Thunder")
	end
	api.Move(shifter, CFrame.new(shifterAt + Vector3.new(0, shifterHip, 0)), 2.4)
	for i = 0, 3 do
		task.delay(i * 0.4, function()
			fx().Steam(shifterAt + Vector3.new(math.random(-20, 20), 30 + i * 8, 0), 30, 8, 3)
		end)
	end
	api.Card("💉 Sieri", { "Li scoprirai andando avanti nella storia", "Con un siero iniettato, T ti trasforma in gigante", "Ogni siero ha i suoi poteri" })
	api.Say("Mira", "E i SIERI... chi li inietta può trasformarsi in gigante. Questo lo scoprirai nella storia.", 4)
	api.HideCard()
	api.FadeOut(1)
	letterbox(false)
end

-- RIPRODUZIONE --------------------------------------------------------------------------------------

function CutsceneController.IsPlaying(): boolean
	return playing
end

-- silent = true: scena locale (es. il tutorial), il server non viene avvisato della fine
function CutsceneController.Play(id: string, silent: boolean?)
	if playing then
		return
	end
	local scene = Scenes[id]
	if not scene then
		if not silent then
			Net.Event("CutsceneDone"):FireServer(id)
		end
		return
	end
	playing = true
	skipRequested = false
	revealed = false
	C.CameraController.SetCinematic(true)
	C.UIController.RequestCursor("cutscene", true)
	if C.HUD then
		C.HUD.SetVisible(false)
	end
	ui.Holder.Visible = true
	ui.Fade.BackgroundTransparency = 0
	ui.Title.TextTransparency = 1
	ui.Speaker.Text = ""
	ui.Text.Text = ""
	-- sicurezza: se una scena non muove mai la telecamera, lo schermo nero si apre comunque
	task.delay(6, function()
		if playing and not revealed then
			api.FadeIn(0.9)
		end
	end)
	local ok, err = pcall(scene)
	if not ok and err ~= "skip" then
		warn("[Scene] " .. tostring(err))
	end
	cleanup()
	letterbox(false)
	ui.Speaker.Text = ""
	ui.Text.Text = ""
	ui.Title.TextTransparency = 1
	ui.Card.GroupTransparency = 1
	TweenService:Create(ui.Fade, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	task.delay(0.8, function()
		if not playing then
			ui.Holder.Visible = false
		end
	end)
	C.CameraController.SetCinematic(false)
	C.UIController.RequestCursor("cutscene", false)
	if C.HUD then
		C.HUD.SetVisible(true)
	end
	playing = false
	if not silent then
		Net.Event("CutsceneDone"):FireServer(id)
	end
end

-- Interrompe la scena in corso (come il pulsante "Salta")
function CutsceneController.Skip()
	if playing then
		skipRequested = true
	end
end

function CutsceneController.Init(c)
	C = c
end

function CutsceneController.Start()
	buildUI()
	-- le scene arrivano in fila (es. cerimonia dell'evento e prologo della storia): una alla volta
	local queue: { string } = {}
	local running = false
	Net.Event("Cutscene").OnClientEvent:Connect(function(id)
		if type(id) ~= "string" or table.find(queue, id) then
			return
		end
		table.insert(queue, id)
		if running then
			return
		end
		running = true
		task.spawn(function()
			while #queue > 0 do
				-- aspetta che l'intro, l'eventuale dialogo e la scena precedente siano finiti
				while (C.Intro and C.Intro.IsShowing()) or (C.Dialogue and C.Dialogue.IsOpen()) or playing or (C.AbuseEventController and C.AbuseEventController.IsCinematic()) or (C.Tutorial and C.Tutorial.IsActive()) do
					task.wait(0.2)
				end
				local nextId = table.remove(queue, 1)
				if nextId then
					CutsceneController.Play(nextId)
					task.wait(0.6)
				end
			end
			running = false
		end)
	end)
	RunService.RenderStepped:Connect(function(dt)
		if playing then
			-- la scossa resta visibile anche quando l'inquadratura è ferma
			if shotCFrame then
				camera.CFrame = shotCFrame * C.CameraController.CinematicShake()
			end
			for _, a in animators do
				a.Context.Phase = (a.Context.Phase or 0) + dt * 3 * (a.Context.Move or 0)
				a:Update(dt)
			end
		end
	end)
end

return CutsceneController
