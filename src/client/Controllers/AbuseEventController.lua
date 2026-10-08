--[[
	AbuseEventController - le animazioni degli eventi a tempo dell'Admin Abuse (prima stagione)
	Quando un admin avvia un evento (attributo AbuseEvento di ReplicatedStorage):
	  1. ANIMAZIONE D'APERTURA (circa 16 secondi), uguale per tutti i giocatori del server:
	     la telecamera passa alla REGIA (bande nere, titolo che si schianta sullo schermo) e mostra la scena
	     dell'evento su un set costruito nel cielo, con inquadrature che seguono l'azione (giganti enormi,
	     fulmini, razzi, cavalleria...). Durante l'animazione non si può fare altro: niente movimento,
	     rampini, attacchi, menu o interfaccia (e il server rende tutti intoccabili dai giganti).
	  2. DURANTE L'EVENTO: il cielo cambia colore, particelle attorno a te (cenere, foglie, polvere...),
	     piccoli eventi nel cielo ogni tanto e lo striscione con il conto alla rovescia.
	  3. FINE: il cielo torna normale e compare "EVENTO TERMINATO".
	Chi entra a evento già iniziato vede subito cielo e striscione; chi è dentro una scena della storia
	vede solo il titolo (senza regia).
	Tutto è solo grafico e viene calcolato da ogni client.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared.Lib.Util)
local AbuseEvents = require(Shared.Data.AbuseEvents)
local TitanBuilder = require(Shared.Anim.TitanBuilder)
local ProceduralAnimator = require(Shared.Anim.ProceduralAnimator)
local Poses = require(Shared.Anim.Poses)

local AbuseEventController = {}
local C

local player = Players.LocalPlayer
local rng = Random.new()

local folder: Folder
local activeId: string? = nil
local showToken = 0 -- cambia a ogni nuova animazione: le azioni in ritardo di quella vecchia si fermano
local showProps: { Instance } = {}
local animators: { any } = {}

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SPARKS = "rbxasset://textures/particles/fire_sparks_main.dds"
local STONE = Color3.fromRGB(190, 182, 166)

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function fx(): any
	return C.EffectsController
end

local function playSound(name: string, where: any, volume: number?, pitch: number?, range: number?)
	if C.SoundController then
		C.SoundController.Play(name, where, { Volume = volume, Pitch = pitch, Range = range })
	end
end

local function shake(intensity: number, duration: number)
	if C.CameraController then
		C.CameraController.Shake(intensity, duration)
	end
end

-- MOTORE: modelli che si spostano, giganti animati, oggetti che seguono altri oggetti ------------------

type Mover = { Model: Model?, Part: BasePart?, Path: (number) -> CFrame, Start: number, Duration: number, Done: (() -> ())? }
local movers: { Mover } = {}
local followers: { () -> () } = {}

-- regia: quando è attiva la telecamera segue l'inquadratura attuale (camShot) e il giocatore è bloccato
local cinematic = false
type Shot = { Path: (number) -> CFrame, Start: number, Duration: number }
local camShot: Shot? = nil

local function shotPath(path: (number) -> CFrame, duration: number)
	camShot = { Path = path, Start = os.clock(), Duration = math.max(0.01, duration) }
end

local function moveAlong(target: Instance, path: (number) -> CFrame, duration: number, done: (() -> ())?)
	local m: Mover = { Path = path, Start = os.clock(), Duration = math.max(0.01, duration), Done = done }
	if target:IsA("Model") then
		m.Model = target
	else
		m.Part = target :: BasePart
	end
	table.insert(movers, m)
end

local function tweenTo(target: Instance, to: CFrame, duration: number, style: string?, done: (() -> ())?)
	local from = if target:IsA("Model") then target:GetPivot() else (target :: BasePart).CFrame
	moveAlong(target, function(k)
		return from:Lerp(to, Util.Ease(k, style or "SineInOut"))
	end, duration, done)
end

local function step(dt: number)
	local now = os.clock()
	for i = #movers, 1, -1 do
		local m = movers[i]
		local k = math.clamp((now - m.Start) / m.Duration, 0, 1)
		local alive = (m.Model and m.Model.Parent) or (m.Part and m.Part.Parent)
		if alive then
			local cf = m.Path(k)
			if m.Model then
				m.Model:PivotTo(cf)
			elseif m.Part then
				m.Part.CFrame = cf
			end
		end
		if k >= 1 or not alive then
			table.remove(movers, i)
			if m.Done and alive then
				local ok, err = pcall(m.Done)
				if not ok then
					warn("[Admin Abuse] " .. tostring(err))
				end
			end
		end
	end
	for _, f in followers do
		pcall(f)
	end
	for _, a in animators do
		a.Context.Phase = (a.Context.Phase or 0) + dt * 3 * (a.Context.Move or 0)
		a:Update(dt)
	end
	local s = camShot
	if cinematic and s then
		local k = math.clamp((now - s.Start) / s.Duration, 0, 1)
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		local wobble = if C.CameraController and C.CameraController.CinematicShake then C.CameraController.CinematicShake() else CFrame.identity
		cam.CFrame = s.Path(k) * wobble
	end
end

-- MATTONI ----------------------------------------------------------------------------------------------

local function track<T>(instance: T): T
	table.insert(showProps, instance :: any)
	return instance
end

local function part(props: { [string]: any }): BasePart
	local className = props.ClassName or "Part"
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "ClassName" and k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = folder
	return track(p)
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.Rate = 0
	e.LightInfluence = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundAt(position: Vector3, fallbackY: number): Vector3
	local exclude = { folder }
	if player.Character then
		table.insert(exclude, player.Character)
	end
	local titanFolder = workspace:FindFirstChild("Giganti")
	if titanFolder then
		table.insert(exclude, titanFolder)
	end
	groundParams.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(position + Vector3.new(0, 900, 0), Vector3.new(0, -1800, 0), groundParams)
	return if hit then hit.Position else Vector3.new(position.X, fallbackY, position.Z)
end

-- IL SET NEL CIELO E LA REGIA ---------------------------------------------------------------------------
-- Le animazioni si girano su un set costruito sopra il mondo (come il prologo della storia):
-- nessuna collina o casa copre la scena e tutti i giocatori vedono la stessa cosa, ovunque siano.
-- Sul set: x = destra/sinistra, z = lontano (+) o verso la telecamera (-), y = altezza.

local SET = Vector3.new(-2600, 3300, 2600)

type Stage = { Center: Vector3, Fwd: Vector3, Right: Vector3, ToCamera: CFrame, Away: CFrame }

local function setStage(groundColor: Color3, material: Enum.Material): Stage
	for gx = -1, 1 do
		for gz = -1, 1 do
			part({ Name = "Terreno", Size = Vector3.new(2048, 8, 2048), CFrame = CFrame.new(SET + Vector3.new(gx * 2040, -4, gz * 2040)), Material = material, Color = groundColor })
		end
	end
	local fwd = Vector3.new(0, 0, -1)
	return {
		Center = SET,
		Fwd = fwd,
		Right = fwd:Cross(Vector3.yAxis),
		ToCamera = CFrame.lookAt(Vector3.zero, -fwd),
		Away = CFrame.lookAt(Vector3.zero, fwd),
	}
end

-- punto del set
local function at(st: Stage, x: number, z: number, y: number?): Vector3
	return st.Center + st.Right * x + st.Fwd * z + Vector3.new(0, y or 0, 0)
end

-- spostamento sul set (per le telecamere che seguono un gigante)
local function rel(st: Stage, x: number, z: number, y: number?): Vector3
	return st.Right * x + st.Fwd * z + Vector3.new(0, y or 0, 0)
end

local function look(from: Vector3, target: Vector3): CFrame
	return CFrame.lookAt(from, target)
end

-- l'inquadratura va da "from" a "to" in "duration" secondi (senza attendere)
local function shot(from: CFrame, to: CFrame, duration: number, style: string?)
	shotPath(function(k)
		return from:Lerp(to, Util.Ease(k, style or "SineInOut"))
	end, duration)
end

local HOUSE_WALLS = { Color3.fromRGB(226, 214, 190), Color3.fromRGB(214, 200, 172), Color3.fromRGB(236, 226, 206), Color3.fromRGB(206, 196, 180) }

-- una casa del distretto: muri, tetto a due falde e qualche trave scura
local function house(base: Vector3, w: number, h: number, yaw: number)
	local origin = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	local d = w * 0.8
	part({ Name = "Casa", Size = Vector3.new(w, h, d), CFrame = origin * CFrame.new(0, h / 2, 0), Material = Enum.Material.Plaster, Color = HOUSE_WALLS[rng:NextInteger(1, #HOUSE_WALLS)] })
	part({ Name = "Trave", Size = Vector3.new(w + 0.4, 1.2, d + 0.4), CFrame = origin * CFrame.new(0, 12, 0), Material = Enum.Material.Wood, Color = Color3.fromRGB(86, 60, 42) })
	local roofColor = Color3.fromRGB(166, 78, 52):Lerp(Color3.fromRGB(116, 58, 44), rng:NextNumber())
	local roofH = w * 0.4
	part({ ClassName = "WedgePart", Name = "Tetto", Size = Vector3.new(w + 2, roofH, d / 2 + 1), CFrame = origin * CFrame.new(0, h + roofH / 2, -d / 4), Material = Enum.Material.ClayRoofTiles, Color = roofColor })
	part({ ClassName = "WedgePart", Name = "Tetto", Size = Vector3.new(w + 2, roofH, d / 2 + 1), CFrame = origin * CFrame.new(0, h + roofH / 2, d / 4) * CFrame.Angles(0, math.pi, 0), Material = Enum.Material.ClayRoofTiles, Color = roofColor })
end

-- un distretto di case tra x0..x1 e z0..z1, tranne dove "avoid" dice di no (strade, piazze)
local function district(st: Stage, x0: number, x1: number, z0: number, z1: number, avoid: (number, number) -> boolean)
	local stepSize = 44
	local x = x0
	while x <= x1 do
		local z = z0
		while z <= z1 do
			local px, pz = x + rng:NextNumber(-6, 6), z + rng:NextNumber(-6, 6)
			if rng:NextNumber() < 0.72 and not avoid(px, pz) then
				house(at(st, px, pz), rng:NextNumber(18, 26), rng:NextInteger(2, 3) * 12, if rng:NextNumber() < 0.5 then 0 else math.pi / 2)
			end
			z += stepSize
		end
		x += stepSize
	end
end

-- la foresta degli alberi giganti (tranne dove "avoid" dice di no)
local function forest(st: Stage, avoid: (number, number) -> boolean)
	local stepSize = 125
	local x = -1000
	while x <= 1000 do
		local z = -600
		while z <= 900 do
			local px, pz = x + rng:NextNumber(-35, 35), z + rng:NextNumber(-35, 35)
			if not avoid(px, pz) then
				local base = at(st, px, pz)
				local h = rng:NextNumber(220, 290)
				local r = rng:NextNumber(22, 30)
				part({ Name = "Tronco", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, r, r), CFrame = CFrame.new(base + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Wood, Color = Color3.fromRGB(96, 70, 50):Lerp(Color3.fromRGB(70, 52, 40), rng:NextNumber()) })
				for j = 1, 3 do
					local size = rng:NextNumber(90, 140)
					part({ Name = "Chioma", Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = CFrame.new(base + Vector3.new(rng:NextNumber(-35, 35), h + (j - 2) * 34, rng:NextNumber(-35, 35))), Material = Enum.Material.Grass, Color = Color3.fromRGB(52, 98, 46):Lerp(Color3.fromRGB(88, 128, 58), rng:NextNumber()) })
				end
			end
			z += stepSize
		end
		x += stepSize
	end
end

-- colline erbose che chiudono l'orizzonte
local function hills(st: Stage, count: number, color: Color3, keepClear: number)
	for _ = 1, count do
		local x = rng:NextNumber(keepClear, 1100) * (if rng:NextNumber() < 0.5 then -1 else 1)
		local size = rng:NextNumber(220, 420)
		part({ Name = "Collina", Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = CFrame.new(at(st, x, rng:NextNumber(300, 1300), -size * 0.32)), Material = Enum.Material.Grass, Color = color:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.15)) })
	end
end


-- Un gigante costruito sul client, animato (Walk, Animate) e sempre in piedi sul punto "ground"
local function titan(look: string, height: number, ground: Vector3, facing: CFrame): Model
	local model = TitanBuilder.Build({ Height = height, Look = look, Seed = rng:NextInteger(1, 1e6) })
	local hip = (model:GetAttribute("HipHeight") :: number?) or height * 0.45
	model:PivotTo(CFrame.new(ground + Vector3.new(0, hip, 0)) * facing.Rotation)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = false
			d.CanCollide = false
			d.CanTouch = false
		end
	end
	local root = model.PrimaryPart
	if root then
		root.Anchored = true
	end
	model.Parent = folder
	track(model)
	local animator = ProceduralAnimator.new(model, true)
	animator.PositionScale = height
	animator.Context.Seed = rng:NextNumber() * 10
	animator:SetLayer("Base", Poses.Titan.Locomotion, 1, 0, 10)
	table.insert(animators, animator)
	model:SetAttribute("EventoAnimator", #animators)
	model:SetAttribute("EventoHip", hip)
	return model
end

local function animatorOf(model: Model): any
	local index = model:GetAttribute("EventoAnimator")
	return index and animators[index]
end

local function animate(model: Model, clipName: string)
	local animator = animatorOf(model)
	local clip = Poses.Titan.Clips[clipName]
	if animator and clip then
		animator:Play(clip)
	end
end

local function walk(model: Model, amount: number, run: number?)
	local animator = animatorOf(model)
	if animator then
		animator.Context.Move = amount
		animator.Context.Run = run or 0
	end
end

-- CFrame del gigante con i piedi a terra in "ground" e girato come "facing"
local function standing(model: Model, ground: Vector3, facing: CFrame): CFrame
	local hip = (model:GetAttribute("EventoHip") :: number?) or 0
	return CFrame.new(ground + Vector3.new(0, hip, 0)) * facing.Rotation
end

local function headPosition(model: Model, height: number): Vector3
	local att = model:FindFirstChild("HeadTopAtt", true) :: Attachment?
	if att then
		return att.WorldPosition
	end
	return model:GetPivot().Position + Vector3.new(0, height * 0.55, 0)
end

local function glowLight(parent: Instance, color: Color3, range: number, brightness: number): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = parent
	return light
end

-- Il Muro sul set (perpendicolare alla telecamera) con al centro:
--   "Cancello" (cancello di legno chiuso), "Aperto" (arco aperto) o "Breccia" (buco con macerie)
local function wallSegment(st: Stage, z: number, width: number, height: number, middle: string): { BasePart }
	local parts = {}
	local seg = 70
	local n = math.floor(width / seg / 2)
	local rot = st.ToCamera.Rotation
	local gateH = height * 0.42
	for i = -n, n do
		local p = at(st, i * seg, z)
		if i == 0 then
			if middle == "Breccia" then
				for _ = 1, 9 do
					local s = rng:NextNumber(10, 24)
					table.insert(parts, part({ Name = "Maceria", Size = Vector3.new(s, s * 0.7, s), CFrame = CFrame.new(p + st.Right * rng:NextNumber(-30, 30) + st.Fwd * rng:NextNumber(-25, 25) + Vector3.new(0, s * 0.3, 0)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 6), rng:NextNumber(0, 1)), Material = Enum.Material.Slate, Color = STONE }))
				end
			else
				if middle == "Cancello" then
					table.insert(parts, part({ Name = "Cancello", Size = Vector3.new(seg * 0.62, gateH, 8), CFrame = CFrame.new(p + Vector3.new(0, gateH / 2, 0)) * rot, Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(86, 60, 40) }))
				end
				table.insert(parts, part({ Name = "Arco", Size = Vector3.new(seg + 1, height - gateH, 30), CFrame = CFrame.new(p + Vector3.new(0, gateH + (height - gateH) / 2, 0)) * rot, Material = Enum.Material.Slate, Color = STONE }))
				table.insert(parts, part({ Name = "Spalla", Size = Vector3.new(seg * 0.2, gateH, 30), CFrame = CFrame.new(p + st.Right * seg * 0.41 + Vector3.new(0, gateH / 2, 0)) * rot, Material = Enum.Material.Slate, Color = STONE }))
				table.insert(parts, part({ Name = "Spalla", Size = Vector3.new(seg * 0.2, gateH, 30), CFrame = CFrame.new(p - st.Right * seg * 0.41 + Vector3.new(0, gateH / 2, 0)) * rot, Material = Enum.Material.Slate, Color = STONE }))
			end
		else
			table.insert(parts, part({ Name = "Muro", Size = Vector3.new(seg + 1, height, 30), CFrame = CFrame.new(p + Vector3.new(0, height / 2, 0)) * rot, Material = Enum.Material.Slate, Color = STONE:Lerp(Color3.new(0.6, 0.58, 0.54), rng:NextNumber(0, 0.2)) }))
			-- camminamento in cima
			table.insert(parts, part({ Name = "Merli", Size = Vector3.new(seg + 1, 5, 34), CFrame = CFrame.new(p + Vector3.new(0, height + 2.5, 0)) * rot, Material = Enum.Material.Slate, Color = Color3.fromRGB(150, 144, 132) }))
		end
	end
	return parts
end


-- Razzo di segnalazione con scia di fumo colorato (verde, rosso, nero, giallo)
local FLARE_COLORS = {
	Verde = Color3.fromRGB(90, 230, 110),
	Rosso = Color3.fromRGB(255, 70, 60),
	Nero = Color3.fromRGB(30, 30, 34),
	Giallo = Color3.fromRGB(255, 220, 80),
}
local function flare(from: Vector3, kind: string, height: number?, drift: Vector3?)
	local color = FLARE_COLORS[kind] or FLARE_COLORS.Verde
	local black = kind == "Nero"
	local h = height or rng:NextNumber(200, 280)
	local side = drift or Vector3.new(rng:NextNumber(-40, 40), 0, rng:NextNumber(-40, 40))
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 3
	ball.Material = Enum.Material.Neon
	ball.Color = if black then Color3.fromRGB(255, 160, 90) else color
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.CFrame = CFrame.new(from)
	ball.Parent = folder
	glowLight(ball, ball.Color, 40, 3)
	local smoke = emitter(ball, {
		Texture = SMOKE,
		Color = ColorSequence.new(color, color:Lerp(Color3.new(0.6, 0.6, 0.6), if black then 0.1 else 0.35)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, if black then 0.1 else 0.25), NumberSequenceKeypoint.new(0.7, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 22) }),
		Lifetime = NumberRange.new(6, 9),
		Speed = NumberRange.new(0.5, 2),
		Drag = 0.5,
		Acceleration = Vector3.new(4, 1, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-20, 20),
		LightEmission = if black then 0 else 0.2,
		LightInfluence = 0.6,
		Rate = 90,
	})
	playSound("Shot", from, 0.9, 0.7, 2500)
	moveAlong(ball, function(k)
		local up = 1 - (1 - k) * (1 - k)
		return CFrame.new(from + Vector3.new(0, h * up, 0) + side * k)
	end, 2.4, function()
		smoke.Enabled = false
		ball.Transparency = 1
		local spark = emitter(ball, {
			Color = ColorSequence.new(Color3.new(1, 1, 1), color),
			LightEmission = 1,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(0.6, 1),
			Speed = NumberRange.new(20, 40),
			SpreadAngle = Vector2.new(180, 180),
		})
		spark:Emit(40)
		task.delay(9, function()
			ball:Destroy()
		end)
	end)
end

-- Fulmine dorato con lampo e tuono (il tuono arriva dopo, più è lontano più tardi)
local function goldenStrike(ground: Vector3, thickness: number?, color: Color3?)
	local f = fx()
	if not f then
		return
	end
	local col = color or Color3.fromRGB(255, 226, 120)
	f.Lightning(ground + Vector3.new(rng:NextNumber(-80, 80), 1200, rng:NextNumber(-80, 80)), ground, col, thickness or 6)
	local cam = workspace.CurrentCamera.CFrame.Position
	local dist = (cam - ground).Magnitude
	f.Flash(Color3.fromRGB(255, 244, 210), math.clamp(0.6 - dist / 1600, 0.12, 0.5), 0.3)
	f.Shockwave(ground + Vector3.new(0, 1, 0), 40 + (thickness or 6) * 6, col, 0.6, 1.2)
	f.Sparks(ground + Vector3.new(0, 2, 0), col, 30, 70)
	task.delay(math.min(2.5, dist / 600), function()
		playSound("Thunder", nil, math.clamp(1.2 - dist / 1200, 0.35, 1), rng:NextNumber(0.22, 0.32))
		if dist < 450 then
			shake(0.35, 0.6)
		end
	end)
end

local function steamBurst(position: Vector3, size: number, count: number?, life: number?, color: Color3?)
	local f = fx()
	if f then
		f.Steam(position, size, count or 12, life or 4, color)
	end
end

-- INTERFACCIA: titolo dell'animazione, striscione con il conto alla rovescia ------------------------------

local Theme
local card: any = nil
local banner: any = nil

local function buildUI()
	Theme = require(script.Parent.Parent.UI.Theme)
	local New = Theme.New
	-- schermata del titolo (sopra tutto, non blocca i clic)
	local root = New("Frame", { Name = "EventoAdminAbuse", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 50, Parent = C.UIController.Layers.Top })
	local flash = New("Frame", { Name = "Lampo", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = root })
	local top = New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 0), ZIndex = 51, Parent = root })
	local bottom = New("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), ZIndex = 51, Parent = root })
	-- raggi di luce che girano dietro al titolo
	local rays = New("Frame", { Name = "Raggi", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromScale(1.6, 1.6), ZIndex = 52, Parent = root })
	New("UIAspectRatioConstraint", { AspectRatio = 1, Parent = rays })
	local rayList = {}
	for i = 0, 11 do
		local ray = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.05, 1), Rotation = i * 15, BackgroundTransparency = 1, ZIndex = 52, Parent = rays })
		New("UIGradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 0.55), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(0.55, 0.55), NumberSequenceKeypoint.new(1, 1) }),
			Rotation = 90,
			Parent = ray,
		})
		table.insert(rayList, ray)
	end
	local icon = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(300, 300), Text = "", TextSize = 190, Font = Theme.Fonts.Bold, TextTransparency = 1, ZIndex = 53, Parent = root })
	local iconScale = New("UIScale", { Scale = 1, Parent = icon })
	local kicker = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.new(1, 0, 0, 30), Text = "", TextSize = 22, Font = Theme.Fonts.Bold, TextColor3 = Color3.new(1, 1, 1), TextTransparency = 1, ZIndex = 55, Parent = root })
	local kickerStroke = New("UIStroke", { Thickness = 2, Color = Color3.new(0, 0, 0), Transparency = 1, Parent = kicker })
	local title = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.43), Size = UDim2.new(0.95, 0, 0, 110), Text = "", TextScaled = true, Font = Theme.Fonts.Title, TextColor3 = Color3.new(1, 1, 1), TextTransparency = 1, ZIndex = 56, Parent = root })
	New("UITextSizeConstraint", { MaxTextSize = 96, Parent = title })
	local titleStroke = New("UIStroke", { Thickness = 4, Color = Color3.new(0, 0, 0), Transparency = 1, Parent = title })
	local titleGradient = New("UIGradient", { Rotation = 20, Parent = title })
	local titleScale = New("UIScale", { Scale = 1, Parent = title })
	local episode = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53), Size = UDim2.new(1, 0, 0, 30), Text = "", TextSize = 24, Font = Theme.Fonts.Header, TextColor3 = Color3.fromRGB(240, 230, 210), TextTransparency = 1, ZIndex = 55, Parent = root })
	local episodeStroke = New("UIStroke", { Thickness = 1.5, Color = Color3.new(0, 0, 0), Transparency = 1, Parent = episode })
	local text = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.new(0.62, 0, 0, 60), Text = "", TextWrapped = true, TextSize = 19, Font = Theme.Fonts.Bold, TextColor3 = Color3.new(1, 1, 1), TextTransparency = 0, ZIndex = 55, Parent = root })
	New("UIStroke", { Thickness = 1.5, Color = Color3.new(0, 0, 0), Transparency = 0.2, Parent = text })
	local chip = New("TextLabel", { BackgroundColor3 = Color3.fromRGB(20, 16, 14), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.72), Size = UDim2.fromOffset(360, 36), Text = "", TextSize = 17, Font = Theme.Fonts.Bold, TextColor3 = Color3.new(1, 1, 1), TextTransparency = 1, ZIndex = 55, Parent = root })
	Theme.Corner(chip, 18)
	local chipStroke = New("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = chip })
	card = {
		Root = root,
		Flash = flash,
		Top = top,
		Bottom = bottom,
		Rays = rays,
		RayList = rayList,
		Icon = icon,
		IconScale = iconScale,
		Kicker = kicker,
		KickerStroke = kickerStroke,
		Title = title,
		TitleStroke = titleStroke,
		TitleGradient = titleGradient,
		TitleScale = titleScale,
		Episode = episode,
		EpisodeStroke = episodeStroke,
		Text = text,
		Chip = chip,
		ChipStroke = chipStroke,
	}

	-- striscione in alto con il conto alla rovescia
	local b = New("Frame", { Name = "StriscioneAdminAbuse", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 112), Size = UDim2.fromOffset(500, 50), BackgroundColor3 = Color3.fromRGB(24, 18, 16), BackgroundTransparency = 0.12, Visible = false, Parent = C.UIController.Layers.HUD })
	C.UIController.AttachScale(b)
	Theme.Corner(b, 12)
	local stroke = New("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), Transparency = 0.1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
	local name = New("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -110, 0, 22), Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextSize = 16, Font = Theme.Fonts.Bold, TextColor3 = Color3.new(1, 1, 1), Parent = b })
	local bonus = New("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 25), Size = UDim2.new(1, -110, 0, 16), Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12, Font = Theme.Fonts.UI, TextColor3 = Color3.fromRGB(230, 220, 200), Parent = b })
	local timer = New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 6), Size = UDim2.fromOffset(96, 30), Text = "", TextXAlignment = Enum.TextXAlignment.Right, TextSize = 24, Font = Theme.Fonts.Bold, TextColor3 = Color3.new(1, 1, 1), Parent = b })
	local barBack = New("Frame", { BackgroundColor3 = Color3.fromRGB(60, 50, 46), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -5), Size = UDim2.new(1, -20, 0, 4), Parent = b })
	Theme.Corner(barBack, 2)
	local bar = New("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = barBack })
	Theme.Corner(bar, 2)
	banner = { Frame = b, Stroke = stroke, Name = name, Bonus = bonus, Timer = timer, Bar = bar }
end

local function tween(instance: Instance, time: number, goals: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local t = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goals)
	t:Play()
	return t
end

local function bonusText(def): string
	local parts = {}
	local b = def.Bonus or {}
	if b.XP and b.XP > 0 then
		table.insert(parts, ("XP x%s"):format(tostring(1 + b.XP)))
	end
	if b.Gold and b.Gold > 0 then
		table.insert(parts, ("Oro x%s"):format(tostring(1 + b.Gold)))
	end
	if b.Damage and b.Damage > 0 then
		table.insert(parts, ("Danni x%s"):format(tostring(1 + b.Damage)))
	end
	if def.InfiniteGas then
		table.insert(parts, "Gas infinito")
	end
	return table.concat(parts, "  •  ")
end

-- La schermata del titolo: lampo, bande nere, raggi, titolo che si schianta, testo a macchina da scrivere.
-- Con la regia (cinematic) il titolo resta solo all'inizio, poi il testo scorre nella banda nera in basso
-- e la durata in quella in alto, mentre la scena continua; le bande si tolgono alla fine (endCinematic).
local function playCard(def, minutes: number, token: number, cinematic: boolean)
	local c = card
	if not c then
		return
	end
	local exitAt = if cinematic then 3.3 else 6.6
	c.Text.Position = if cinematic then UDim2.fromScale(0.5, 0.9) else UDim2.fromScale(0.5, 0.58)
	c.Text.Size = if cinematic then UDim2.new(0.8, 0, 0.09, 0) else UDim2.new(0.62, 0, 0, 60)
	c.Chip.Position = if cinematic then UDim2.fromScale(0.5, 0.06) else UDim2.fromScale(0.5, 0.72)
	local color = def.Color
	c.Root.Visible = true
	c.Flash.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.55)
	c.Flash.BackgroundTransparency = 0.05
	tween(c.Flash, 0.8, { BackgroundTransparency = 1 })
	c.Top.Size = UDim2.fromScale(1, 0)
	c.Bottom.Size = UDim2.fromScale(1, 0)
	tween(c.Top, 0.5, { Size = UDim2.fromScale(1, 0.12) }, Enum.EasingStyle.Quart)
	tween(c.Bottom, 0.5, { Size = UDim2.fromScale(1, 0.12) }, Enum.EasingStyle.Quart)
	for _, ray in c.RayList do
		ray.BackgroundColor3 = color
		ray.BackgroundTransparency = 1
		tween(ray, 0.9, { BackgroundTransparency = 0.25 })
	end
	c.Rays.Rotation = 0
	c.Icon.Text = def.Icon
	c.Icon.TextTransparency = 1
	c.IconScale.Scale = 0.4
	tween(c.Icon, 0.6, { TextTransparency = 0.55 })
	tween(c.IconScale, 0.9, { Scale = 1.15 }, Enum.EasingStyle.Back)
	c.Kicker.Text = "⚠️  ADMIN ABUSE  •  EVENTO A TEMPO  ⚠️"
	c.Kicker.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35)
	c.Kicker.TextTransparency = 1
	c.KickerStroke.Transparency = 1
	c.Kicker.Position = UDim2.fromScale(0.5, 0.26)
	task.delay(0.35, function()
		if token ~= showToken then
			return
		end
		tween(c.Kicker, 0.45, { TextTransparency = 0, Position = UDim2.fromScale(0.5, 0.3) }, Enum.EasingStyle.Back)
		tween(c.KickerStroke, 0.45, { Transparency = 0.2 })
	end)
	c.Title.Text = def.Name:upper()
	c.Title.TextTransparency = 1
	c.TitleStroke.Transparency = 1
	c.TitleGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.45, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.5, color:Lerp(Color3.new(1, 1, 1), 0.2)),
		ColorSequenceKeypoint.new(0.55, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, color),
	})
	c.TitleGradient.Offset = Vector2.new(-1, 0)
	c.TitleScale.Scale = 2.6
	task.delay(0.75, function()
		if token ~= showToken then
			return
		end
		tween(c.Title, 0.35, { TextTransparency = 0 })
		tween(c.TitleStroke, 0.35, { Transparency = 0 })
		tween(c.TitleScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(c.TitleGradient, 2.2, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.delay(0.3, function()
			if token ~= showToken then
				return
			end
			shake(0.5, 0.5)
			playSound("Explosion", nil, 0.8, 0.5)
			c.Flash.BackgroundColor3 = Color3.new(1, 1, 1)
			c.Flash.BackgroundTransparency = 0.6
			tween(c.Flash, 0.35, { BackgroundTransparency = 1 })
		end)
	end)
	c.Episode.Text = def.Episode
	c.Episode.TextTransparency = 1
	c.EpisodeStroke.Transparency = 1
	task.delay(1.4, function()
		if token ~= showToken then
			return
		end
		tween(c.Episode, 0.5, { TextTransparency = 0 })
		tween(c.EpisodeStroke, 0.5, { Transparency = 0.3 })
	end)
	-- testo a macchina da scrivere
	c.Text.Text = ""
	c.Text.TextTransparency = 0
	task.delay(if cinematic then 3.4 else 1.9, function()
		local full = def.Text
		local len = utf8.len(full) or #full
		for i = 1, len do
			if token ~= showToken then
				return
			end
			local cut = utf8.offset(full, i + 1)
			c.Text.Text = if cut then full:sub(1, cut - 1) else full
			if i % 3 == 0 then
				playSound("Type")
			end
			task.wait(0.022)
		end
	end)
	c.Chip.Text = ("⏱️  Durata: %d minut%s   •   %s"):format(minutes, if minutes == 1 then "o" else "i", bonusText(def))
	c.Chip.Size = UDim2.fromOffset(math.max(360, 26 + 8.6 * (utf8.len(c.Chip.Text) or 40)), 36)
	c.Chip.TextTransparency = 1
	c.Chip.BackgroundTransparency = 1
	c.ChipStroke.Color = color
	c.ChipStroke.Transparency = 1
	task.delay(if cinematic then 3.4 else 2.4, function()
		if token ~= showToken then
			return
		end
		tween(c.Chip, 0.4, { TextTransparency = 0, BackgroundTransparency = 0.2 })
		tween(c.ChipStroke, 0.4, { Transparency = 0 })
	end)
	-- i raggi girano e il titolo pulsa finché resta sullo schermo
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if token ~= showToken or not c.Root.Visible then
			conn:Disconnect()
			return
		end
		local t = os.clock() - start
		c.Rays.Rotation = t * 12
		c.IconScale.Scale = math.max(c.IconScale.Scale, 1.1 + math.sin(t * 3) * 0.05)
	end)
	-- uscita: il titolo sfuma (senza regia anche il testo e le bande)
	task.delay(exitAt, function()
		if token ~= showToken then
			return
		end
		for _, ray in c.RayList do
			tween(ray, 0.6, { BackgroundTransparency = 1 })
		end
		tween(c.Icon, 0.6, { TextTransparency = 1 })
		tween(c.Kicker, 0.5, { TextTransparency = 1 })
		tween(c.KickerStroke, 0.5, { Transparency = 1 })
		tween(c.Title, 0.6, { TextTransparency = 1 })
		tween(c.TitleStroke, 0.6, { Transparency = 1 })
		tween(c.TitleScale, 0.6, { Scale = 0.8 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(c.Episode, 0.5, { TextTransparency = 1 })
		tween(c.EpisodeStroke, 0.5, { Transparency = 1 })
		if cinematic then
			return
		end
		tween(c.Text, 0.5, { TextTransparency = 1 })
		tween(c.Chip, 0.5, { TextTransparency = 1, BackgroundTransparency = 1 })
		tween(c.ChipStroke, 0.5, { Transparency = 1 })
		tween(c.Top, 0.6, { Size = UDim2.fromScale(1, 0) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		tween(c.Bottom, 0.6, { Size = UDim2.fromScale(1, 0) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		task.delay(0.7, function()
			if token == showToken then
				c.Root.Visible = false
				c.Text.TextTransparency = 0
			end
		end)
	end)
end



-- Fine dell'evento: scritta "EVENTO TERMINATO" che appare e sparisce
local function playOutro(def)
	local c = card
	if not c then
		return
	end
	showToken += 1
	local token = showToken
	c.Root.Visible = true
	for _, ray in c.RayList do
		ray.BackgroundTransparency = 1
	end
	c.Icon.TextTransparency = 1
	c.Kicker.TextTransparency = 1
	c.KickerStroke.Transparency = 1
	c.Episode.TextTransparency = 1
	c.EpisodeStroke.Transparency = 1
	c.Text.Text = ""
	c.Chip.TextTransparency = 1
	c.Chip.BackgroundTransparency = 1
	c.ChipStroke.Transparency = 1
	c.Top.Size = UDim2.fromScale(1, 0)
	c.Bottom.Size = UDim2.fromScale(1, 0)
	c.Flash.BackgroundColor3 = Color3.new(1, 1, 1)
	c.Flash.BackgroundTransparency = 0.5
	tween(c.Flash, 0.6, { BackgroundTransparency = 1 })
	c.Title.Text = "⌛ EVENTO TERMINATO"
	c.TitleGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), if def then def.Color else Color3.new(1, 1, 1))
	c.TitleGradient.Offset = Vector2.zero
	c.Title.TextTransparency = 1
	c.TitleStroke.Transparency = 1
	c.TitleScale.Scale = 1.4
	tween(c.Title, 0.4, { TextTransparency = 0 })
	tween(c.TitleStroke, 0.4, { Transparency = 0 })
	tween(c.TitleScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	c.Episode.Text = if def then def.Name else ""
	tween(c.Episode, 0.5, { TextTransparency = 0 })
	tween(c.EpisodeStroke, 0.5, { Transparency = 0.3 })
	task.delay(3, function()
		if token ~= showToken then
			return
		end
		tween(c.Title, 0.6, { TextTransparency = 1 })
		tween(c.TitleStroke, 0.6, { Transparency = 1 })
		tween(c.Episode, 0.6, { TextTransparency = 1 })
		tween(c.EpisodeStroke, 0.6, { Transparency = 1 })
		task.delay(0.7, function()
			if token == showToken then
				c.Root.Visible = false
			end
		end)
	end)
end

-- PARTICELLE ATTORNO AL GIOCATORE DURANTE L'EVENTO -----------------------------------------------------

local ambientPart: BasePart? = nil
local ambientEmitters: { ParticleEmitter } = {}

local AMBIENT = {
	Cenere = {
		{ Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(120, 110, 104), Color3.fromRGB(70, 64, 60)), Size = NumberSequence.new(0.5, 0.8), Transparency = NumberSequence.new(0.2), Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(4, 9), Rate = 70, EmissionDirection = Enum.NormalId.Bottom, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90), LightInfluence = 0.8 },
		{ Texture = SPARKLE, Color = ColorSequence.new(Color3.fromRGB(255, 170, 70), Color3.fromRGB(255, 80, 30)), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }), Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(3, 8), Rate = 40, EmissionDirection = Enum.NormalId.Top, LightEmission = 1, Acceleration = Vector3.new(2, 3, 0) },
	},
	Polvere = {
		{ Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(214, 190, 150)), Size = NumberSequence.new(1.5, 4), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.8), NumberSequenceKeypoint.new(1, 1) }), Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(6, 12), Rate = 30, EmissionDirection = Enum.NormalId.Right, LightInfluence = 0.9 },
		{ Texture = SPARKLE, Color = ColorSequence.new(Color3.fromRGB(255, 236, 190)), Size = NumberSequence.new(0.18), Transparency = NumberSequence.new(0.3), Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(2, 6), Rate = 50, LightEmission = 0.6, SpreadAngle = Vector2.new(180, 180) },
	},
	Fumo = {
		{ Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(80, 70, 70), Color3.fromRGB(50, 44, 44)), Size = NumberSequence.new(4, 12), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 1) }), Lifetime = NumberRange.new(6, 9), Speed = NumberRange.new(2, 5), Rate = 14, EmissionDirection = Enum.NormalId.Top, LightInfluence = 0.8 },
		{ Texture = SPARKLE, Color = ColorSequence.new(Color3.fromRGB(255, 120, 70), Color3.fromRGB(255, 60, 40)), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }), Lifetime = NumberRange.new(2, 4), Speed = NumberRange.new(4, 10), Rate = 30, EmissionDirection = Enum.NormalId.Top, LightEmission = 1 },
	},
	Foglie = {
		{ Texture = SPARKLE, Color = ColorSequence.new(Color3.fromRGB(110, 190, 90), Color3.fromRGB(190, 170, 70)), Size = NumberSequence.new(0.55), Squash = NumberSequence.new(-0.4), Transparency = NumberSequence.new(0.1), Lifetime = NumberRange.new(6, 9), Speed = NumberRange.new(3, 6), Rate = 45, EmissionDirection = Enum.NormalId.Bottom, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-180, 180), LightInfluence = 1, Acceleration = Vector3.new(3, -2, 1) },
		{ Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(200, 230, 210)), Size = NumberSequence.new(6, 14), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.85), NumberSequenceKeypoint.new(1, 1) }), Lifetime = NumberRange.new(8, 12), Speed = NumberRange.new(1, 3), Rate = 8, LightInfluence = 1 },
	},
	Vento = {
		{ Texture = SPARKS, Color = ColorSequence.new(Color3.fromRGB(255, 250, 235)), Size = NumberSequence.new(0.12), Squash = NumberSequence.new(4), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 1) }), Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(60, 90), Rate = 35, EmissionDirection = Enum.NormalId.Right, LightEmission = 0.5, Orientation = Enum.ParticleOrientation.VelocityParallel },
		{ Texture = SPARKLE, Color = ColorSequence.new(Color3.fromRGB(255, 220, 140)), Size = NumberSequence.new(0.2), Transparency = NumberSequence.new(0.2), Lifetime = NumberRange.new(3, 6), Speed = NumberRange.new(4, 10), Rate = 40, LightEmission = 0.8, SpreadAngle = Vector2.new(180, 180) },
	},
	Pioggia = {
		{ Texture = SPARKLE, Color = ColorSequence.new(Color3.fromRGB(255, 230, 140)), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }), Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(1, 3), Rate = 18, LightEmission = 1, SpreadAngle = Vector2.new(180, 180) },
	},
}

local function setAmbient(kind: string?)
	for _, e in ambientEmitters do
		e.Enabled = false
		task.delay(10, function()
			e:Destroy()
		end)
	end
	table.clear(ambientEmitters)
	if not kind or not AMBIENT[kind] then
		return
	end
	if not ambientPart then
		local p = Instance.new("Part")
		p.Name = "ParticelleEvento"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 1
		p.Size = Vector3.new(160, 4, 160)
		p.Parent = workspace.CurrentCamera
		ambientPart = p
	end
	for _, props in AMBIENT[kind] do
		local e = emitter(ambientPart :: BasePart, props)
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Enabled = true
		table.insert(ambientEmitters, e)
	end
end

local function followCamera()
	local p = ambientPart
	local camera = workspace.CurrentCamera
	if p and camera then
		local cam = camera.CFrame.Position
		p.CFrame = CFrame.new(cam + Vector3.new(0, 35, 0) + camera.CFrame.LookVector * 25)
	end
end

-- un punto lontano attorno al giocatore (per i piccoli eventi del cielo)
local function farPoint(minDist: number, maxDist: number, inFront: boolean?): Vector3
	local cam = workspace.CurrentCamera.CFrame
	local base = Util.AngleOf(Util.SafeUnit(Util.Flat(cam.LookVector), Vector3.new(0, 0, -1)))
	local angle = if inFront then base + rng:NextNumber(-60, 60) else rng:NextNumber(0, 360)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local y = if root then root.Position.Y - 3 else cam.Position.Y - 20
	return groundAt(cam.Position + Util.Polar(angle, rng:NextNumber(minDist, maxDist)), y)
end

-- piccoli eventi nel cielo durante l'evento
local AMBIENT_EVENTS: { [string]: { Every: { number }, Run: () -> () } } = {
	CadutaMuro = {
		Every = { 6, 11 },
		Run = function()
			local p = farPoint(450, 900, true)
			steamBurst(p + Vector3.new(0, 40, 0), 120, 20, 7, Color3.fromRGB(230, 200, 180))
			if rng:NextNumber() < 0.4 and fx() then
				fx().Flash(Color3.fromRGB(255, 160, 100), 0.12, 0.6)
				playSound("Thunder", nil, 0.5, 0.2)
			end
		end,
	},
	CaricaBastione = {
		Every = { 9, 14 },
		Run = function()
			for i = 0, 2 do
				task.delay(i * 0.55, function()
					playSound("Land", nil, 1, 0.22)
					shake(0.18 + i * 0.06, 0.35)
				end)
			end
		end,
	},
	AssedioCalaneth = {
		Every = { 5, 9 },
		Run = function()
			flare(farPoint(250, 600, true), if rng:NextNumber() < 0.8 then "Rosso" else "Verde")
		end,
	},
	UrloCacciatrice = {
		Every = { 14, 22 },
		Run = function()
			local p = farPoint(500, 900, true)
			playSound("Roar", nil, 0.45, 0.55)
			if fx() then
				fx().Shockwave(p + Vector3.new(0, 30, 0), 400, Color3.fromRGB(200, 255, 220), 2, 2)
			end
		end,
	},
	Spedizione = {
		Every = { 4, 8 },
		Run = function()
			local roll = rng:NextNumber()
			flare(farPoint(250, 700, true), if roll < 0.7 then "Verde" elseif roll < 0.9 then "Rosso" else "Giallo")
		end,
	},
	FulmineTrasformazione = {
		Every = { 3, 7 },
		Run = function()
			goldenStrike(farPoint(180, 650), rng:NextNumber(4, 8))
		end,
	},
}

-- LE ANIMAZIONI D'APERTURA (con la regia) ----------------------------------------------------------------
-- Ogni scena dura circa INTRO_LENGTH secondi: nei primi 3 c'è il titolo sopra un'inquadratura tranquilla,
-- poi parte l'azione. "after(t, fn)" fa succedere fn dopo t secondi (si ferma se parte un'altra scena).

local INTRO_LENGTH = 15.6

local SHOWS: { [string]: ((number, () -> ()) -> ()) -> () } = {}

local function roarAt(model: Model, height: number, color: Color3, pitch: number)
	animate(model, "Roar")
	playSound("Roar", nil, 1, pitch)
	shake(0.8, 1.6)
	local head = headPosition(model, height)
	for i = 0, 3 do
		task.delay(i * 0.2, function()
			if fx() and model.Parent then
				fx().Shockwave(head, height * 3 + i * height * 1.6, color, 1.2, 3)
			end
		end)
	end
end

-- 🧱 La Caduta del Muro: il distretto tranquillo, il fulmine, il Vulcano che si alza oltre il Muro e il calcio al cancello
SHOWS.CadutaMuro = function(after)
	local st = setStage(Color3.fromRGB(118, 108, 92), Enum.Material.Ground)
	district(st, -360, 360, -640, -80, function(x, _)
		return math.abs(x) < 30
	end)
	local wall = wallSegment(st, 0, 1400, 160, "Cancello")
	local spot = at(st, 0, 85)
	local face = st.ToCamera
	local vulcano = titan("Vulcano", 190, spot - Vector3.new(0, 215, 0), face)
	local glow = glowLight(vulcano.PrimaryPart or vulcano, Color3.fromRGB(255, 140, 60), 180, 0)
	-- 1. la strada del distretto verso il cancello: tutto tranquillo (sotto il titolo)
	shot(look(at(st, 10, -400, 7), at(st, 0, 0, 70)), look(at(st, 6, -340, 7), at(st, 0, 0, 80)), 3.8)
	after(2.6, function()
		shake(0.25, 1.4)
		playSound("Thunder", nil, 0.7, 0.2)
	end)
	-- 2. il fulmine dorato oltre il Muro e il gigante che si alza: la telecamera guarda in su
	after(3.7, function()
		shot(look(at(st, -40, -240, 10), at(st, 0, 80, 140)), look(at(st, -36, -250, 10), at(st, 0, 80, 235)), 3.8)
		goldenStrike(spot + Vector3.new(0, 30, 0), 16)
		goldenStrike(spot + st.Right * 80, 8)
		if fx() then
			fx().Flash(Color3.fromRGB(255, 240, 200), 0.75, 0.9)
			fx().Explosion(spot + Vector3.new(0, 50, 0), 70, true)
		end
		steamBurst(spot + Vector3.new(0, 80, 0), 200, 40, 7, Color3.fromRGB(255, 230, 210))
	end)
	after(3.9, function()
		tweenTo(vulcano, standing(vulcano, spot, face), 3.4, "QuadOut")
		TweenService:Create(glow, TweenInfo.new(2), { Brightness = 4 }):Play()
		for i = 0, 10 do
			task.delay(i * 0.32, function()
				steamBurst(spot + st.Right * rng:NextNumber(-50, 50) + Vector3.new(0, rng:NextNumber(40, 180), 0), 70, 10, 5, Color3.fromRGB(255, 236, 220))
			end)
		end
		shake(0.45, 3.2)
	end)
	-- 3. primo piano: la testa oltre il Muro urla
	after(7.5, function()
		local head = headPosition(vulcano, 190)
		shot(look(at(st, 100, -160, 168), head), look(at(st, 70, -100, 176), head), 2.4)
	end)
	after(7.8, function()
		roarAt(vulcano, 190, Color3.fromRGB(255, 190, 120), 0.16)
		steamBurst(headPosition(vulcano, 190), 160, 30, 6, Color3.fromRGB(255, 240, 230))
	end)
	-- 4. dai tetti del distretto: il calcio e il cancello che esplode
	after(9.9, function()
		shot(look(at(st, -150, -480, 72), at(st, 0, 0, 50)), look(at(st, -128, -440, 64), at(st, 0, 0, 45)), 3)
	end)
	after(10.1, function()
		animate(vulcano, "Kick")
	end)
	after(10.7, function()
		local g = at(st, 0, 0, 30)
		for _, p in wall do
			if p.Parent and (Util.Flat(p.Position - g)).Magnitude < 60 then
				p:Destroy()
			end
		end
		local f = fx()
		if f then
			f.Explosion(g, 60, true)
			f.DebrisBurst(g, 50, 9, STONE, Enum.Material.Slate, 260)
			f.Shockwave(at(st, 0, 0, 2), 340, Color3.fromRGB(255, 220, 180), 1.2, 4)
			f.Flash(Color3.fromRGB(255, 236, 210), 0.55, 0.7)
		end
		steamBurst(g, 150, 30, 6, Color3.fromRGB(200, 186, 170))
		playSound("Explosion", nil, 1, 0.35)
		shake(1.3, 1.5)
	end)
	-- 5. dall'alto: il vapore copre la breccia e il gigante sparisce
	after(12.9, function()
		shot(look(at(st, 170, -330, 120), at(st, 0, 0, 60)), look(at(st, 250, -580, 290), at(st, 0, 20, 50)), 2.8, "QuadOut")
		steamBurst(spot + Vector3.new(0, 100, 0), 240, 50, 6, Color3.fromRGB(255, 240, 230))
		tweenTo(vulcano, standing(vulcano, spot - Vector3.new(0, 230, 0), face), 3.2, "QuadIn")
	end)
end

-- 🛡️ La Carica del Bastione: la polvere all'orizzonte, la corsa, lo schianto contro il cancello e l'urlo
SHOWS.CaricaBastione = function(after)
	local st = setStage(Color3.fromRGB(150, 138, 100), Enum.Material.Ground)
	hills(st, 10, Color3.fromRGB(120, 130, 80), 260)
	district(st, -360, 360, -560, -110, function(x, _)
		return math.abs(x) < 32
	end)
	local wall = wallSegment(st, 0, 1400, 120, "Cancello")
	local face = st.ToCamera
	local startPos = at(st, 0, 980)
	local endPos = at(st, 0, -70)
	local bastione = titan("Bastione", 72, startPos, face)
	local hip = (bastione:GetAttribute("EventoHip") :: number?) or 30
	walk(bastione, 1, 1)
	local runStart, runTime = 1.0, 7.0
	local hitAt = runStart + runTime * (980 / 1050)
	-- 1. dall'alto del Muro: una nube di polvere all'orizzonte che si avvicina
	shot(look(at(st, 50, -16, 136), at(st, 0, 900, 30)), look(at(st, 44, -16, 134), at(st, 0, 760, 36)), 3.4)
	after(runStart, function()
		animate(bastione, "Charge")
		moveAlong(bastione, function(k)
			local p = startPos:Lerp(endPos, k)
			return CFrame.new(p + Vector3.new(0, hip + math.abs(math.sin(k * 44)) * 2, 0)) * face.Rotation
		end, runTime, function()
			walk(bastione, 0)
			roarAt(bastione, 72, Color3.fromRGB(255, 230, 170), 0.2)
			if fx() then
				fx().HighlightModel(bastione, Color3.fromRGB(255, 220, 140), 1.5, 0.4)
			end
		end)
		-- passi sempre più forti
		local token = showToken
		local start = os.clock()
		local function stepOnce()
			if token ~= showToken or os.clock() - start > runTime or not bastione.Parent then
				return
			end
			local k = (os.clock() - start) / runTime
			playSound("Land", nil, 0.6 + k * 0.4, 0.2)
			shake(0.12 + k * 0.4, 0.3)
			steamBurst(bastione:GetPivot().Position - Vector3.new(0, hip, 0), 34, 4, 2.5, Color3.fromRGB(196, 170, 130))
			task.delay(0.42, stepOnce)
		end
		stepOnce()
	end)
	-- 2. la telecamera corre accanto al Bastione
	after(3.4, function()
		shotPath(function(_)
			local p = bastione:GetPivot().Position
			return look(p + rel(st, 120, 40, -14), p + Vector3.new(0, 6, 0))
		end, 2.5)
	end)
	-- 3. dietro il cancello: lo schianto
	after(5.9, function()
		shot(look(at(st, 0, -200, 16), at(st, 0, 0, 45)), look(at(st, 0, -186, 14), at(st, 0, 0, 50)), 2.5)
	end)
	after(hitAt, function()
		local g = at(st, 0, 0, 40)
		for _, p in wall do
			if p.Parent and (Util.Flat(p.Position - g)).Magnitude < 110 then
				p:Destroy()
			end
		end
		local f = fx()
		if f then
			f.Explosion(g, 70, true)
			f.DebrisBurst(g, 60, 10, STONE, Enum.Material.Slate, 280)
			f.Shockwave(at(st, 0, 0, 2), 380, Color3.fromRGB(255, 230, 180), 1.3, 4)
			f.Flash(Color3.fromRGB(255, 240, 220), 0.6, 0.6)
		end
		steamBurst(g, 160, 30, 5, Color3.fromRGB(200, 180, 150))
		playSound("Explosion", nil, 1, 0.3)
		shake(1.4, 1.4)
	end)
	-- 4. dal basso: il Bastione nella breccia urla e si indurisce
	after(8.4, function()
		shot(look(at(st, -46, -165, 5), at(st, 0, -70, 60)), look(at(st, -34, -150, 5), at(st, 0, -70, 68)), 4)
	end)
	after(10.7, function()
		animate(bastione, "Harden")
		if fx() then
			fx().Sparks(headPosition(bastione, 72), Color3.fromRGB(255, 240, 200), 60, 60)
			fx().HighlightModel(bastione, Color3.fromRGB(255, 240, 200), 1.2, 0.5)
		end
	end)
	-- 5. dall'alto: polvere e macerie
	after(12.5, function()
		shot(look(at(st, 230, -380, 150), at(st, 0, -30, 30)), look(at(st, 280, -470, 220), at(st, 0, -30, 20)), 3, "QuadOut")
		steamBurst(bastione:GetPivot().Position, 130, 30, 5)
		tweenTo(bastione, bastione:GetPivot() - Vector3.new(0, 110, 0), 3, "QuadIn")
	end)
end

-- 🔥 L'Assedio di Calaneth: razzi rossi e campane, il fulmine, il Gigante della Furia e il masso sulla breccia
SHOWS.AssedioCalaneth = function(after)
	local st = setStage(Color3.fromRGB(128, 120, 110), Enum.Material.Cobblestone)
	district(st, -440, 440, -480, 230, function(x, z)
		return (x * x + z * z) < 130 * 130 or (math.abs(x) < 46 and z > 0)
	end)
	wallSegment(st, 275, 1400, 140, "Breccia")
	local spot = at(st, 0, 0)
	local face = st.ToCamera
	-- 1. dai tetti: i razzi rossi si alzano dal distretto e suonano le campane
	shot(look(at(st, -120, -270, 62), at(st, 0, 120, 70)), look(at(st, -104, -246, 66), at(st, 0, 140, 100)), 3.4)
	for i = 0, 6 do
		after(0.4 + i * 0.36, function()
			flare(at(st, rng:NextNumber(-380, 380), rng:NextNumber(-320, 200), 30), "Rosso", 250)
		end)
	end
	for i = 0, 7 do
		after(0.2 + i * 0.34, function()
			playSound("UI", nil, 0.9, if i % 2 == 0 then 0.32 else 0.27)
		end)
	end
	-- 2. il cielo pieno di razzi, poi giù verso la piazza
	after(3.4, function()
		shot(look(at(st, 20, -90, 12), at(st, 0, 120, 230)), look(at(st, 20, -90, 12), at(st, 0, 20, 40)), 1.7)
	end)
	local furia: Model? = nil
	-- 3. il fulmine e il Gigante della Furia che esce dal vapore
	after(5.1, function()
		shot(look(at(st, 0, -160, 14), at(st, 0, 0, 38)), look(at(st, 0, -146, 12), at(st, 0, 0, 52)), 1.5)
		goldenStrike(spot, 16)
		if fx() then
			fx().Flash(Color3.fromRGB(255, 244, 220), 0.75, 0.8)
			fx().TransformBurst(spot, 60)
		end
		steamBurst(spot + Vector3.new(0, 40, 0), 170, 40, 6)
		playSound("Explosion", nil, 1, 0.3)
		local m = titan("Furia", 60, spot - Vector3.new(0, 70, 0), face)
		furia = m
		tweenTo(m, standing(m, spot, face), 1, "QuadOut")
		glowLight(m.PrimaryPart or m, Color3.fromRGB(120, 255, 160), 60, 1.5)
	end)
	after(6.6, function()
		if furia then
			shot(look(at(st, -26, -74, 7), headPosition(furia, 60)), look(at(st, -20, -66, 7), headPosition(furia, 60)), 1.6)
			roarAt(furia, 60, Color3.fromRGB(150, 255, 180), 0.24)
		end
	end)
	-- 4. solleva il masso e lo porta verso la breccia (la telecamera lo segue di lato)
	local boulder: BasePart? = nil
	after(8.2, function()
		local m = furia
		if not m then
			return
		end
		local b = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 44, Material = Enum.Material.Slate, Color = Color3.fromRGB(128, 122, 114), CFrame = CFrame.new(headPosition(m, 60) + Vector3.new(0, 20, 0)) })
		boulder = b
		steamBurst(b.Position, 60, 14, 3, Color3.fromRGB(200, 186, 160))
		if fx() then
			fx().DebrisBurst(b.Position, 18, 4, Color3.fromRGB(128, 122, 114), Enum.Material.Slate, 80)
		end
		playSound("Land", nil, 1, 0.3)
		animate(m, "Grab")
		table.insert(followers, function()
			if b.Parent and m.Parent and b:GetAttribute("Caduto") ~= true then
				b.CFrame = CFrame.new(headPosition(m, 60) + Vector3.new(0, 19, 0))
			end
		end)
		tweenTo(m, standing(m, spot, st.Away), 0.4)
		task.delay(0.4, function()
			if m.Parent then
				walk(m, 0.7, 0)
				tweenTo(m, standing(m, at(st, 0, 190), st.Away), 3.1, "Linear")
			end
		end)
		shotPath(function(_)
			local p = m:GetPivot().Position
			return look(p + rel(st, 150, -30, 10), p + rel(st, 0, 40, 30))
		end, 3.6)
	end)
	-- 5. il masso chiude la breccia
	after(11.8, function()
		shot(look(at(st, -180, 110, 70), at(st, 0, 250, 40)), look(at(st, -156, 134, 60), at(st, 0, 258, 34)), 2.4)
		if furia then
			walk(furia, 0)
			animate(furia, "Slam")
		end
	end)
	after(12.2, function()
		local b = boulder
		if not b then
			return
		end
		b:SetAttribute("Caduto", true)
		local land = at(st, 0, 262, 22)
		tweenTo(b, CFrame.new(land), 0.5, "QuadIn", function()
			local f = fx()
			if f then
				f.Explosion(land, 55, true)
				f.DebrisBurst(land, 40, 7, Color3.fromRGB(128, 122, 114), Enum.Material.Slate, 200)
				f.Shockwave(at(st, 0, 262, 2), 320, Color3.fromRGB(230, 210, 180), 1.2, 3)
				f.Flash(Color3.fromRGB(255, 240, 220), 0.4, 0.5)
			end
			steamBurst(land, 140, 30, 6, Color3.fromRGB(196, 176, 150))
			playSound("Explosion", nil, 1, 0.3)
			shake(1.3, 1.4)
		end)
	end)
	-- 6. dall'alto: la breccia è chiusa, il gigante si dissolve nel vapore
	after(14.2, function()
		shot(look(at(st, 170, -40, 150), at(st, 0, 210, 30)), look(at(st, 210, -120, 210), at(st, 0, 210, 20)), 1.6)
		if furia then
			local pos = furia:GetPivot().Position
			if fx() then
				fx().TransformEnd(pos, 60)
			end
			steamBurst(pos, 120, 40, 6)
		end
	end)
end

-- 😱 L'Urlo della Cacciatrice: la foresta, la corsa tra gli alberi, l'urlo e i giganti che arrivano da ogni parte
SHOWS.UrloCacciatrice = function(after)
	local st = setStage(Color3.fromRGB(62, 92, 52), Enum.Material.Grass)
	forest(st, function(x, z)
		return (x * x + (z - 60) * (z - 60)) < 160 * 160 or math.abs(z - 60) < 55 or (math.abs(x) < 140 and z < -120)
	end)
	local spot = at(st, 0, 60)
	local runFace = CFrame.lookAt(Vector3.zero, st.Right)
	local hunter = titan("Cacciatrice", 62, at(st, -820, 60), runFace)
	-- 1. tra gli alberi giganti, nella penombra
	shot(look(at(st, -70, -260, 14), at(st, 0, 60, 70)), look(at(st, -50, -214, 16), at(st, 0, 60, 80)), 3.4)
	-- 2. lei corre tra gli alberi e la telecamera le corre accanto
	after(2.9, function()
		walk(hunter, 1, 1)
		tweenTo(hunter, standing(hunter, spot, runFace), 4, "Linear")
		for i = 0, 9 do
			task.delay(i * 0.4, function()
				playSound("Land", nil, 0.8, 0.28)
				shake(0.15, 0.25)
			end)
		end
	end)
	after(3.4, function()
		shotPath(function(_)
			local p = hunter:GetPivot().Position
			return look(p + rel(st, -50, -120, 0), p + rel(st, 20, 0, 12))
		end, 3.5)
	end)
	-- 3. si ferma, si gira verso di noi e urla
	after(6.9, function()
		walk(hunter, 0)
		tweenTo(hunter, standing(hunter, spot, st.ToCamera), 0.5, "QuadOut")
		shot(look(at(st, -14, -16, 6), at(st, 0, 60, 58)), look(at(st, -9, -4, 6), at(st, 0, 60, 66)), 2.4)
	end)
	after(7.6, function()
		roarAt(hunter, 62, Color3.fromRGB(210, 255, 225), 0.55)
		playSound("Roar", nil, 0.8, 0.42)
		local blur = Instance.new("BlurEffect")
		blur.Size = 0
		blur.Parent = Lighting
		track(blur)
		TweenService:Create(blur, TweenInfo.new(0.35), { Size = 16 }):Play()
		task.delay(0.6, function()
			TweenService:Create(blur, TweenInfo.new(1.2), { Size = 0 }):Play()
		end)
	end)
	-- 4. dall'alto: i giganti richiamati corrono verso di lei da tutte le parti
	after(9.4, function()
		shot(look(at(st, 0, -360, 300), spot), look(at(st, 60, -280, 340), spot), 3.4)
		local token = showToken
		for i = 1, 9 do
			task.delay(i * 0.1, function()
				if token ~= showToken then
					return
				end
				local a = (i / 9) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
				local start = spot + rel(st, math.cos(a) * 520, math.sin(a) * 520)
				local goal = spot + rel(st, math.cos(a) * 140, math.sin(a) * 140)
				local dir = CFrame.lookAt(Vector3.zero, Util.SafeUnit(Util.Flat(goal - start)))
				local m = titan("Puro", rng:NextNumber(22, 34), start, dir)
				walk(m, 1, 1)
				tweenTo(m, standing(m, goal, dir), rng:NextNumber(4, 5), "Linear")
			end)
		end
	end)
	-- 5. arrivano attorno a lei
	after(12.9, function()
		shot(look(at(st, 180, -70, 24), at(st, 0, 60, 40)), look(at(st, 156, -50, 26), at(st, 0, 60, 46)), 2.7)
	end)
	after(14.3, function()
		steamBurst(spot + Vector3.new(0, 30, 0), 200, 40, 6, Color3.fromRGB(220, 240, 225))
	end)
end


local function rider(base: CFrame): { Model: Model, Parts: { [string]: BasePart } }
	local model = Instance.new("Model")
	model.Name = "Cavaliere"
	local coat = ({ Color3.fromRGB(110, 76, 50), Color3.fromRGB(70, 50, 36), Color3.fromRGB(150, 120, 90), Color3.fromRGB(40, 36, 34) })[rng:NextInteger(1, 4)]
	local function p(name: string, size: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?): BasePart
		local x = Instance.new("Part")
		x.Name = name
		x.Size = size
		x.Color = color
		x.Material = material or Enum.Material.SmoothPlastic
		if shape then
			x.Shape = shape
		end
		x.Anchored = true
		x.CanCollide = false
		x.CanQuery = false
		x.CanTouch = false
		x.CFrame = base
		x.Parent = model
		return x
	end
	local parts = {
		Body = p("Corpo", Vector3.new(3.2, 3.4, 8), coat),
		Neck = p("Collo", Vector3.new(1.8, 4.2, 1.8), coat),
		Head = p("Testa", Vector3.new(1.6, 1.8, 3.4), coat),
		LegFL = p("Zampa", Vector3.new(0.9, 4.6, 0.9), coat),
		LegFR = p("Zampa", Vector3.new(0.9, 4.6, 0.9), coat),
		LegBL = p("Zampa", Vector3.new(0.9, 4.6, 0.9), coat),
		LegBR = p("Zampa", Vector3.new(0.9, 4.6, 0.9), coat),
		Tail = p("Coda", Vector3.new(0.6, 3.6, 0.6), Color3.fromRGB(30, 26, 24)),
		Rider = p("Soldato", Vector3.new(2.2, 2.8, 1.4), Color3.fromRGB(150, 116, 80)),
		RiderHead = p("TestaSoldato", Vector3.new(1.4, 1.4, 1.4), Color3.fromRGB(234, 196, 160), nil, Enum.PartType.Ball),
		Cape = p("Mantello", Vector3.new(2.6, 3.2, 0.25), Color3.fromRGB(46, 104, 58), Enum.Material.Fabric),
	}
	model.PrimaryPart = parts.Body
	model.Parent = folder
	track(model)
	return { Model = model, Parts = parts }
end

local function poseRider(r, cf: CFrame, t: number)
	local P = r.Parts
	local gallop = math.sin(t * 14)
	local bob = math.abs(math.sin(t * 14)) * 0.8
	local body = cf * CFrame.new(0, 6 + bob, 0) * CFrame.Angles(gallop * 0.06, 0, 0)
	P.Body.CFrame = body
	P.Neck.CFrame = body * CFrame.new(0, 2.2, -4.2) * CFrame.Angles(math.rad(-35), 0, 0)
	P.Head.CFrame = body * CFrame.new(0, 4.4, -5.6) * CFrame.Angles(math.rad(25) + gallop * 0.1, 0, 0)
	P.LegFL.CFrame = body * CFrame.new(-1.1, -3.6, -3) * CFrame.Angles(gallop * 0.8, 0, 0)
	P.LegFR.CFrame = body * CFrame.new(1.1, -3.6, -3) * CFrame.Angles(-gallop * 0.8, 0, 0)
	P.LegBL.CFrame = body * CFrame.new(-1.1, -3.6, 3) * CFrame.Angles(-gallop * 0.8, 0, 0)
	P.LegBR.CFrame = body * CFrame.new(1.1, -3.6, 3) * CFrame.Angles(gallop * 0.8, 0, 0)
	P.Tail.CFrame = body * CFrame.new(0, 0.6, 4.6) * CFrame.Angles(math.rad(40) + gallop * 0.2, 0, 0)
	P.Rider.CFrame = body * CFrame.new(0, 3.1, -0.4) * CFrame.Angles(math.rad(-12), 0, 0)
	P.RiderHead.CFrame = body * CFrame.new(0, 5.2, -0.7)
	P.Cape.CFrame = body * CFrame.new(0, 3.2, 0.9) * CFrame.Angles(math.rad(35 + gallop * 10), 0, 0)
end

-- 🐎 La Spedizione: dal Muro esce la cavalleria, razzi verdi, un razzo nero e l'anomalo che salta fuori
SHOWS.Spedizione = function(after)
	local st = setStage(Color3.fromRGB(120, 150, 80), Enum.Material.Grass)
	hills(st, 14, Color3.fromRGB(100, 140, 70), 220)
	wallSegment(st, -200, 1500, 130, "Aperto")
	local dir = st.Away
	local runStart, speed = 1.8, 95
	local function leadZ(t: number): number
		return -200 + math.max(0, t - runStart) * speed
	end
	local showStart = os.clock()
	local riders = {}
	local function lead(): Vector3
		return at(st, 0, leadZ(os.clock() - showStart), 6)
	end
	-- 1. dall'alto del Muro: l'alba sulla pianura e la fanfara
	shot(look(at(st, 34, -216, 142), at(st, 0, 260, 20)), look(at(st, 28, -216, 140), at(st, 0, 330, 10)), 3.4)
	for i, pitch in { 0.5, 0.63, 0.75, 1 } do
		after((i - 1) * 0.22, function()
			playSound("Reward", nil, 0.8, pitch)
		end)
	end
	-- la cavalleria esce dal cancello in formazione (2 colonne)
	after(runStart, function()
		for i = 1, 12 do
			local col = (i - 1) % 2
			local row = math.floor((i - 1) / 2)
			table.insert(riders, { R = rider(CFrame.new(st.Center)), X = (col - 0.5) * 16 + rng:NextNumber(-2, 2), Back = row * 20, Phase = rng:NextNumber(0, 6) })
		end
		table.insert(followers, function()
			local t = os.clock() - showStart
			for _, entry in riders do
				if entry.R.Model.Parent then
					poseRider(entry.R, CFrame.new(at(st, entry.X, leadZ(t) - entry.Back)) * dir.Rotation, t + entry.Phase)
				end
			end
		end)
		for i = 0, 16 do
			task.delay(i * 0.5, function()
				if #riders > 0 then
					steamBurst(lead() - Vector3.new(0, 5, 0) - st.Fwd * 60, 30, 6, 2.5, Color3.fromRGB(210, 190, 150))
				end
			end)
		end
	end)
	-- 2. i razzi verdi: la telecamera è dietro la formazione e guarda in alto
	after(3.4, function()
		shotPath(function(_)
			local p = lead()
			return look(p + rel(st, 24, -150, 12), p + rel(st, 0, 140, 150))
		end, 2.3)
		for i = 0, 5 do
			task.delay(i * 0.25, function()
				flare(lead() + rel(st, (i - 2.5) * 30, -i * 12, 4), "Verde", 260, st.Fwd * 30)
			end)
		end
	end)
	-- 3. accanto ai cavalli al galoppo
	after(5.7, function()
		shotPath(function(_)
			local p = lead()
			return look(p + rel(st, 46, 20, 2), p + rel(st, 0, -40, 4))
		end, 2.3)
	end)
	after(6.9, function()
		flare(lead() + rel(st, 260, 120), "Rosso", 240)
	end)
	after(7.5, function()
		flare(lead() + rel(st, 180, 220), "Nero", 230)
		playSound("UI", nil, 0.8, 0.3)
	end)
	-- 4. l'anomalo salta fuori da dietro una collina e insegue la cavalleria
	after(8.0, function()
		local lz = leadZ(os.clock() - showStart)
		local from = at(st, 340, lz + 260)
		local land = at(st, 70, lz + 150)
		local face = CFrame.lookAt(Vector3.zero, Util.SafeUnit(Util.Flat(land - from)))
		local abnormal = titan("Puro", 42, from - Vector3.new(0, 40, 0), face)
		local hip = (abnormal:GetAttribute("EventoHip") :: number?) or 18
		shot(look(at(st, -70, lz + 30, 14), at(st, 200, lz + 210, 60)), look(at(st, -60, lz + 60, 12), at(st, 90, lz + 160, 40)), 2.4)
		animate(abnormal, "Leap")
		moveAlong(abnormal, function(k)
			local p = from:Lerp(land, k) + Vector3.new(0, hip + math.sin(k * math.pi) * 120 - (1 - k) * (1 - k) * 40, 0)
			return CFrame.new(p) * face.Rotation
		end, 1.4, function()
			local f = fx()
			if f then
				f.Explosion(land, 30, false)
				f.Shockwave(land + Vector3.new(0, 1, 0), 200, Color3.fromRGB(230, 210, 170), 0.9, 2)
				f.DebrisBurst(land, 20, 4, Color3.fromRGB(120, 100, 80), Enum.Material.Ground, 120)
			end
			playSound("Land", nil, 1, 0.25)
			shake(0.9, 0.8)
			abnormal:PivotTo(standing(abnormal, land, dir))
			walk(abnormal, 1, 1)
			tweenTo(abnormal, standing(abnormal, land + st.Fwd * 560, dir), 5.5, "Linear")
		end)
	end)
	-- 5. dall'alto: la formazione e l'anomalo all'inseguimento
	after(10.6, function()
		shotPath(function(k)
			local p = lead()
			return look(p + rel(st, -170 - k * 40, -280, 170 + k * 40), p + rel(st, 0, 40, 0))
		end, 5)
	end)
end

-- ⚡ Il Fulmine della Trasformazione: fulmini dorati sul distretto, il fulmine gigante e la Furia che emerge
SHOWS.FulmineTrasformazione = function(after)
	local st = setStage(Color3.fromRGB(100, 98, 96), Enum.Material.Cobblestone)
	district(st, -440, 440, -440, 440, function(x, z)
		return (x * x + z * z) < 140 * 140 or (math.abs(x) < 36 and z < 0)
	end)
	local spot = at(st, 0, 0)
	local face = st.ToCamera
	-- 1. il distretto nel temporale: fulmini dorati sulle case
	shot(look(at(st, -180, -300, 74), at(st, 0, 0, 20)), look(at(st, -156, -260, 68), at(st, 0, 0, 24)), 3.7)
	for i = 0, 10 do
		after(0.3 + i * 0.34, function()
			goldenStrike(at(st, rng:NextNumber(-400, 400), rng:NextNumber(-320, 400), 30), rng:NextNumber(4, 8))
		end)
	end
	-- 2. in strada: il fulmine gigante
	after(3.7, function()
		shot(look(at(st, 0, -160, 8), at(st, 0, 0, 28)), look(at(st, 0, -150, 8), at(st, 0, 0, 32)), 0.6)
	end)
	local furia: Model? = nil
	after(4.3, function()
		goldenStrike(spot, 22)
		goldenStrike(spot + st.Right * 30, 9)
		goldenStrike(spot - st.Right * 30, 9)
		local f = fx()
		if f then
			f.Flash(Color3.new(1, 1, 1), 0.95, 1.1)
			f.Explosion(spot + Vector3.new(0, 10, 0), 80, true)
			f.Shockwave(spot + Vector3.new(0, 2, 0), 520, Color3.fromRGB(255, 220, 100), 1.6, 6)
			f.TransformBurst(spot, 72)
		end
		steamBurst(spot + Vector3.new(0, 50, 0), 240, 50, 7)
		playSound("Thunder", nil, 1, 0.2)
		playSound("Explosion", nil, 1, 0.3)
		shake(1.4, 1.6)
		local m = titan("Furia", 72, spot - Vector3.new(0, 80, 0), face)
		furia = m
		glowLight(m.PrimaryPart or m, Color3.fromRGB(110, 255, 150), 80, 2)
		tweenTo(m, standing(m, spot, face), 1.8, "QuadOut")
		for i = 0, 6 do
			task.delay(i * 0.25, function()
				steamBurst(spot + st.Right * rng:NextNumber(-25, 25) + Vector3.new(0, rng:NextNumber(10, 70), 0), 60, 10, 4)
			end)
		end
		-- la telecamera sale lungo il gigante che emerge
		shot(look(at(st, 0, -140, 8), at(st, 0, 0, 24)), look(at(st, 0, -128, 8), at(st, 0, 0, 82)), 2.2)
	end)
	-- 3. primo piano: l'urlo, con un fulmine accanto
	after(6.7, function()
		if not furia then
			return
		end
		local head = headPosition(furia, 72)
		shot(look(at(st, 34, -64, 24), head), look(at(st, 26, -54, 26), head), 2)
		roarAt(furia, 72, Color3.fromRGB(130, 255, 170), 0.22)
		goldenStrike(spot + st.Right * 90, 7)
	end)
	-- 4. il pugno verso la telecamera
	after(8.7, function()
		shot(look(at(st, 0, -82, 48), at(st, 0, 0, 52)), look(at(st, 0, -78, 48), at(st, 0, 0, 52)), 2.2)
		if furia then
			animate(furia, "Punch")
		end
	end)
	after(9.15, function()
		local fist = at(st, 0, -40, 44)
		if fx() then
			fx().Shockwave(fist, 220, Color3.new(1, 1, 1), 0.8, 2)
			fx().Flash(Color3.fromRGB(255, 255, 230), 0.45, 0.4)
		end
		playSound("Explosion", nil, 0.9, 0.45)
		shake(1.2, 0.8)
	end)
	-- 5. dall'alto: il temporale sul distretto, il gigante si dissolve nel vapore
	after(11.1, function()
		shot(look(at(st, -210, -310, 96), at(st, 0, 0, 40)), look(at(st, -250, -380, 140), at(st, 0, 0, 40)), 4.4, "QuadOut")
		for i = 0, 4 do
			task.delay(i * 0.6, function()
				goldenStrike(at(st, rng:NextNumber(-360, 360), rng:NextNumber(-260, 360), 30), rng:NextNumber(5, 9))
			end)
		end
	end)
	after(12.4, function()
		if furia then
			local pos = furia:GetPivot().Position
			if fx() then
				fx().TransformEnd(pos, 72)
			end
			steamBurst(pos, 160, 40, 6)
			tweenTo(furia, furia:GetPivot() - Vector3.new(0, 100, 0), 2.6, "QuadIn")
		end
	end)
end


local function cleanupShow()
	table.clear(movers)
	table.clear(followers)
	camShot = nil
	for _, a in animators do
		pcall(function()
			a:Destroy()
		end)
	end
	table.clear(animators)
	for _, p in showProps do
		if p.Parent then
			p:Destroy()
		end
	end
	table.clear(showProps)
end

-- BLOCCO DEL GIOCATORE DURANTE LA REGIA ---------------------------------------------------------------------
-- La telecamera passa alla regia; niente movimento, rampini, attacchi, menu né interfaccia di gioco.
-- (Il server intanto rende tutti intoccabili: attributo CutsceneUntil.)

local controls: any = nil

local function lockPlayer(on: boolean)
	if on == cinematic then
		return
	end
	cinematic = on
	if C.CameraController then
		pcall(C.CameraController.SetCinematic, on)
	end
	if controls then
		pcall(function()
			if on then
				controls:Disable()
			else
				controls:Enable()
			end
		end)
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if on and humanoid then
		pcall(function()
			humanoid:Move(Vector3.zero)
		end)
	end
	if on and C.UIController and C.UIController.CloseAll then
		C.UIController.CloseAll()
	end
	if C.HUD and C.HUD.SetVisible then
		C.HUD.SetVisible(not on)
	end
	-- via anche pulsanti laterali, striscioni e pannelli: sullo schermo resta solo l'animazione
	local layers = C.UIController and C.UIController.Layers
	if layers then
		for _, name in { "HUD", "Panels" } do
			local layer = layers[name]
			if layer then
				layer.Visible = not on
			end
		end
	end
	if not on then
		camShot = nil
	end
end

function AbuseEventController.IsCinematic(): boolean
	return cinematic
end

-- Fine della regia: dissolvenza al nero, si torna al proprio personaggio, dissolvenza dal nero
local function endCinematic(token: number)
	local c = card
	if not c then
		cleanupShow()
		lockPlayer(false)
		return
	end
	c.Flash.BackgroundColor3 = Color3.new(0, 0, 0)
	tween(c.Flash, 0.45, { BackgroundTransparency = 0 })
	task.delay(0.5, function()
		if token ~= showToken then
			return
		end
		cleanupShow()
		pcall(lockPlayer, false)
		tween(c.Text, 0.3, { TextTransparency = 1 })
		tween(c.Chip, 0.3, { TextTransparency = 1, BackgroundTransparency = 1 })
		tween(c.ChipStroke, 0.3, { Transparency = 1 })
		tween(c.Top, 0.6, { Size = UDim2.fromScale(1, 0) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		tween(c.Bottom, 0.6, { Size = UDim2.fromScale(1, 0) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		tween(c.Flash, 0.7, { BackgroundTransparency = 1 })
		task.delay(0.75, function()
			if token == showToken then
				c.Root.Visible = false
			end
		end)
	end)
end

-- Fa partire l'animazione d'apertura dell'evento "id".
-- withCamera = true: regia completa (telecamera sul set, giocatore bloccato); false: solo il titolo.
function AbuseEventController.PlayIntro(id: string, minutes: number?, withCamera: boolean?)
	local def = AbuseEvents.Get(id)
	if not def then
		return
	end
	cleanupShow()
	showToken += 1
	local token = showToken
	local show = SHOWS[id]
	local cine = withCamera ~= false and show ~= nil
	playCard(def, minutes or AbuseEvents.DefaultMinutes, token, cine)
	if not cine or not show then
		return
	end
	-- la regia finisce sempre, anche se qualcosa nella scena va storto
	task.delay(INTRO_LENGTH, function()
		if token == showToken then
			endCinematic(token)
		end
	end)
	local okLock, errLock = pcall(lockPlayer, true)
	if not okLock then
		warn("[Admin Abuse] " .. tostring(errLock))
	end
	local function after(t: number, fn: () -> ())
		task.delay(t, function()
			if token ~= showToken then
				return
			end
			local ok, err = pcall(fn)
			if not ok then
				warn("[Admin Abuse] " .. tostring(err))
			end
		end)
	end
	local ok, err = pcall(show, after)
	if not ok then
		warn("[Admin Abuse] " .. tostring(err))
	end
end


-- EFFETTI MANDATI DAL SERVER DURANTE L'EVENTO ------------------------------------------------------------

function AbuseEventController.ServerEffect(name: string, p: any)
	p = p or {}
	if name == "AbuseTremor" then
		for i = 0, 3 do
			task.delay(i * 0.5, function()
				playSound("Land", nil, 1, 0.2)
				shake(0.3 + i * 0.1, 0.4)
			end)
		end
	elseif name == "AbuseScream" then
		local where = if typeof(p.Position) == "Vector3" then p.Position else farPoint(400, 700, true)
		playSound("Roar", nil, 1, 0.55)
		shake(0.6, 1.5)
		for i = 0, 3 do
			task.delay(i * 0.2, function()
				if fx() then
					fx().Shockwave(where + Vector3.new(0, 40, 0), 400 + i * 200, Color3.fromRGB(210, 255, 225), 1.4, 3)
				end
			end)
		end
		local blur = Instance.new("BlurEffect")
		blur.Size = 0
		blur.Parent = Lighting
		TweenService:Create(blur, TweenInfo.new(0.3), { Size = 10 }):Play()
		task.delay(0.5, function()
			TweenService:Create(blur, TweenInfo.new(1), { Size = 0 }):Play()
			task.delay(1.1, function()
				blur:Destroy()
			end)
		end)
		if C.Notifications then
			C.Notifications.Toast("😱 L'urlo della Cacciatrice! Arrivano i giganti!", "Errore", 4)
		end
	elseif name == "AbuseFlare" then
		if typeof(p.Position) == "Vector3" then
			flare(p.Position, if type(p.Kind) == "string" then p.Kind else "Nero", 240)
		end
	elseif name == "AbuseLightning" then
		if typeof(p.Position) == "Vector3" then
			goldenStrike(p.Position, 12)
			if fx() then
				fx().Shockwave(p.Position + Vector3.new(0, 2, 0), 70, Color3.fromRGB(255, 230, 120), 0.8, 2)
			end
		end
	end
end

-- STATO DELL'EVENTO (attributi di ReplicatedStorage) -------------------------------------------------------

local nextAmbient = 0
local activeStart: number? = nil

-- il giocatore sta guardando una scena della storia, l'introduzione del gioco o un dialogo?
local function busy(): boolean
	return (C.CutsceneController ~= nil and C.CutsceneController.IsPlaying())
		or (C.Intro ~= nil and C.Intro.IsShowing ~= nil and C.Intro.IsShowing())
		or (C.Dialogue ~= nil and C.Dialogue.IsOpen ~= nil and C.Dialogue.IsOpen())
end

local function refresh()
	local id = ReplicatedStorage:GetAttribute("AbuseEvento")
	local def = AbuseEvents.Get(id)
	local started = ReplicatedStorage:GetAttribute("AbuseInizio")
	-- un evento nuovo (anche lo stesso evento rilanciato da capo)
	if def and (id ~= activeId or started ~= activeStart) then
		activeId = id
		activeStart = started
		local duration = ReplicatedStorage:GetAttribute("AbuseDurata")
		local minutes = if type(duration) == "number" then math.max(1, math.floor(duration / 60 + 0.5)) else AbuseEvents.DefaultMinutes
		if C.SkyController and C.SkyController.SetEventSky then
			C.SkyController.SetEventSky(def.Sky)
		end
		setAmbient(def.Ambient)
		nextAmbient = os.clock() + INTRO_LENGTH + 4
		-- l'animazione d'apertura solo se l'evento è appena partito (non per chi entra dopo).
		-- Se il giocatore è dentro una scena della storia aspetta un attimo; se non finisce, solo il titolo.
		if type(started) ~= "number" or serverNow() - started < 15 then
			task.spawn(function()
				local waited = os.clock()
				while busy() and os.clock() - waited < 5 do
					task.wait(0.2)
				end
				if activeId == def.Id and activeStart == started then
					AbuseEventController.PlayIntro(def.Id, minutes, not busy())
				end
			end)
		end
	elseif not def and activeId then
		local old = AbuseEvents.Get(activeId)
		activeId = nil
		activeStart = nil
		if C.SkyController and C.SkyController.SetEventSky then
			C.SkyController.SetEventSky(nil)
		end
		setAmbient(nil)
		cleanupShow()
		lockPlayer(false)
		playOutro(old)
	end
end

local function updateBanner()
	local b = banner
	if not b then
		return
	end
	local def = AbuseEvents.Get(activeId)
	local cinematic = C.CameraController and C.CameraController.IsCinematic and C.CameraController.IsCinematic()
	local intro = card and card.Root.Visible
	b.Frame.Visible = def ~= nil and not cinematic and not intro
	if not def then
		return
	end
	local ends = ReplicatedStorage:GetAttribute("AbuseFine")
	local duration = ReplicatedStorage:GetAttribute("AbuseDurata")
	local left = if type(ends) == "number" then ends - serverNow() else 0
	b.Name.Text = ("%s  %s"):format(def.Icon, def.Name:upper())
	b.Bonus.Text = "😈 ADMIN ABUSE  •  " .. bonusText(def)
	b.Timer.Text = AbuseEvents.FormatTime(left)
	b.Timer.TextColor3 = if left < 30 then Color3.fromRGB(255, 110, 100) else Color3.new(1, 1, 1)
	b.Bar.BackgroundColor3 = def.Color
	b.Bar.Size = UDim2.fromScale(if type(duration) == "number" and duration > 0 then math.clamp(left / duration, 0, 1) else 0, 1)
	b.Stroke.Color = def.Color
	b.Stroke.Transparency = 0.05 + 0.35 * (0.5 + 0.5 * math.sin(os.clock() * 4))
	-- sotto lo striscione della Grande Inaugurazione, se c'è
	local festival = ReplicatedStorage:GetAttribute("FestaAttiva") == true
	b.Frame.Position = UDim2.new(0.5, 0, 0, math.floor(14 + (62 + (if festival then 38 else 0)) * C.UIController.Scale))
end

function AbuseEventController.ActiveId(): string?
	return activeId
end

function AbuseEventController.Init(c)
	C = c
end

function AbuseEventController.Start()
	folder = Instance.new("Folder")
	folder.Name = "EventoAdminLocale"
	folder.Parent = workspace
	buildUI()
	-- i controlli di movimento (per bloccarli durante la regia)
	task.spawn(function()
		local ok, module = pcall(function()
			return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript)
		end)
		if ok and module then
			controls = (module :: any):GetControls()
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		followCamera()
		local ok, err = pcall(step, dt)
		if not ok then
			warn("[Admin Abuse] " .. tostring(err))
		end
	end)
	-- gli attributi arrivano insieme: si aspetta un attimo e si guarda lo stato completo
	local pending = false
	for _, attribute in { "AbuseEvento", "AbuseInizio", "AbuseFine", "AbuseDurata" } do
		ReplicatedStorage:GetAttributeChangedSignal(attribute):Connect(function()
			if pending then
				return
			end
			pending = true
			task.delay(0.1, function()
				pending = false
				local ok, err = pcall(refresh)
				if not ok then
					warn("[Admin Abuse] " .. tostring(err))
				end
			end)
		end)
	end
	pcall(refresh)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		pcall(updateBanner)
		if activeId and os.clock() >= nextAmbient then
			local ambient = AMBIENT_EVENTS[activeId]
			if ambient then
				nextAmbient = os.clock() + rng:NextNumber(ambient.Every[1], ambient.Every[2])
				local ok, err = pcall(ambient.Run)
				if not ok then
					warn("[Admin Abuse] " .. tostring(err))
				end
			else
				nextAmbient = os.clock() + 10
			end
		end
	end)
end

return AbuseEventController
