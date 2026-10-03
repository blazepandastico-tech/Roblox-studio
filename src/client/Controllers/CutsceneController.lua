--[[
	CutsceneController
	Scene animate della storia: inquadrature cinematografiche, bande nere,
	sottotitoli, giganti costruiti al volo, fulmini, esplosioni e vapore.
	Il prologo viene girato su un "set" costruito nel cielo, così si vede sempre.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
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
	ui = { Holder = holder, Top = top, Bottom = bottom, Speaker = speaker, Text = text, Fade = fade, Title = title, Skip = skip }
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

function api.FadeOut(t: number)
	TweenService:Create(ui.Fade, TweenInfo.new(t), { BackgroundTransparency = 0 }):Play()
	api.Wait(t)
end

function api.FadeIn(t: number)
	TweenService:Create(ui.Fade, TweenInfo.new(t), { BackgroundTransparency = 1 }):Play()
end

-- Muove la telecamera da un'inquadratura all'altra (attende la fine)
function api.Shot(from: CFrame, to: CFrame, duration: number, style: string?)
	camera.CameraType = Enum.CameraType.Scriptable
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
	task.spawn(function()
		pcall(api.Shot, from, to, duration, style)
	end)
end

function api.Look(from: Vector3, at: Vector3): CFrame
	return CFrame.lookAt(from, at)
end

function api.Titan(look: string, height: number, position: Vector3, yaw: number?): Model
	local model = TitanBuilder.Build({ Height = height, Look = look, Seed = math.random(1, 1e6) })
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
	local rng = Random.new(845)
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
	api.Say("Narratore", "Anno 845. Distretto di Halvar, il confine più a sud del Muro di Cenere.", 3.5)
	api.Say("Narratore", "Per cento anni le Mura ci hanno protetti. Per cento anni abbiamo dimenticato la paura.", 3.5)
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
	api.Title("CINQUE ANNI DOPO", 2.5)
end

Scenes.Calaneth = function()
	local zone = Zones.Get("Calaneth")
	local gate = W.DistrictGatePoint("Calaneth")
	local outward = W.DistrictOutward("Calaneth")
	local outer = gate + outward * 140
	local colossal = api.Titan("Vulcano", 190, outer + outward * 60 - Vector3.new(0, 120, 0), 0)
	colossal:PivotTo(CFrame.lookAt(colossal:GetPivot().Position, colossal:GetPivot().Position - outward))
	letterbox(true)
	local camPos = gate + outward * 40 + Vector3.new(30, 25, 0)
	api.ShotAsync(api.Look(camPos, outer + Vector3.new(0, 120, 0)), api.Look(camPos + Vector3.new(0, -10, 0), outer + Vector3.new(0, 170, 0)), 5)
	fx().Lightning(outer + outward * 60 + Vector3.new(0, 700, 0), outer + outward * 60 + Vector3.new(0, 150, 0), Color3.fromRGB(255, 236, 130), 4)
	fx().Flash(Color3.fromRGB(255, 240, 200), 0.4, 0.6)
	local standing = outer + outward * 60 + Vector3.new(0, W.GroundY + (colossal:GetAttribute("HipHeight") :: number), 0)
	api.Move(colossal, CFrame.lookAt(standing, standing - outward), 3)
	api.Say("Narratore", "Cinque anni dopo, la stessa testa senza pelle si affacciò sopra il Muro Vermiglio.", 3.5)
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
	local tobias = api.Titan("Furia", 48, center + Vector3.new(30, 0, 30), 200)
	local enemy = api.Titan("Puro", 32, center + Vector3.new(30, 0, -12), 20)
	letterbox(true)
	api.ShotAsync(api.Look(center + Vector3.new(-60, 30, 10), center + Vector3.new(30, 30, 10)), api.Look(center + Vector3.new(-40, 22, 0), center + Vector3.new(30, 35, 10)), 6)
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
	local female = api.Titan("Cacciatrice", 45, center + Vector3.new(-120, 0, 0), 270)
	api.Walk(female, 1, 1)
	letterbox(true)
	api.Move(female, CFrame.new(center + Vector3.new(80, female:GetAttribute("HipHeight") :: number, 0)) * CFrame.Angles(0, math.rad(-90), 0), 5)
	api.Shot(api.Look(center + Vector3.new(-40, 30, 80), center + Vector3.new(-100, 25, 0)), api.Look(center + Vector3.new(40, 26, 70), center + Vector3.new(60, 30, 0)), 5)
	api.Say("Roth", "Qualcosa corre tra gli alberi... è un gigante, ma si muove come un soldato!", 3)
	api.Walk(female, 0)
	api.Animate(female, "Roar")
	api.Say("Falkner", "Il Gigante Cacciatrice! A tutte le squadre: prepararsi al combattimento!", 3)
	letterbox(false)
end

Scenes.Fauno = function()
	local zone = Zones.Get("Ostrava")
	local center = zone and zone.Center or Vector3.zero
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

-- RIPRODUZIONE --------------------------------------------------------------------------------------

function CutsceneController.IsPlaying(): boolean
	return playing
end

function CutsceneController.Play(id: string)
	if playing then
		return
	end
	local scene = Scenes[id]
	if not scene then
		Net.Event("CutsceneDone"):FireServer(id)
		return
	end
	playing = true
	skipRequested = false
	C.CameraController.SetCinematic(true)
	C.UIController.RequestCursor("cutscene", true)
	if C.HUD then
		C.HUD.SetVisible(false)
	end
	ui.Holder.Visible = true
	ui.Fade.BackgroundTransparency = 0
	ui.Title.TextTransparency = 1
	local ok, err = pcall(scene)
	if not ok and err ~= "skip" then
		warn("[Scene] " .. tostring(err))
	end
	cleanup()
	letterbox(false)
	ui.Speaker.Text = ""
	ui.Text.Text = ""
	ui.Title.TextTransparency = 1
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
	Net.Event("CutsceneDone"):FireServer(id)
end

function CutsceneController.Init(c)
	C = c
end

function CutsceneController.Start()
	buildUI()
	Net.Event("Cutscene").OnClientEvent:Connect(function(id)
		if type(id) == "string" then
			-- aspetta che l'intro sia stata chiusa
			while C.Intro and C.Intro.IsShowing() do
				task.wait(0.2)
			end
			CutsceneController.Play(id)
		end
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
