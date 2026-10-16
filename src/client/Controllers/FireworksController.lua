--[[
	FireworksController - le animazioni della Grande Inaugurazione
	  - Show: spettacolo di razzi sopra una città (peonie, anelli, salici d'oro, palme e crepitii)
	    che finisce con un gran finale
	  - Confetti: pioggia di coriandoli sul giocatore (sfide completate, vittorie)
	  - ColossusArrival: il Colosso d'Oro cade dal cielo come una meteora d'oro
	Tutto è solo grafico e viene calcolato da ogni client (non pesa sul server).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FireworksController = {}
local C
local player = Players.LocalPlayer

local folder: Folder
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local COLORS = {
	Color3.fromRGB(255, 70, 70),
	Color3.fromRGB(255, 200, 70),
	Color3.fromRGB(90, 220, 255),
	Color3.fromRGB(120, 255, 120),
	Color3.fromRGB(255, 110, 220),
	Color3.fromRGB(170, 120, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 150, 60),
}
local GOLD = Color3.fromRGB(255, 196, 80)

-- MOTORE DEI MOVIMENTI (un solo aggiornamento per fotogramma per tutti i razzi) --------------------

type Mover = { Part: BasePart, Path: (number) -> Vector3, Start: number, Duration: number, Done: (() -> ())? }
local movers: { Mover } = {}

local function step()
	local now = os.clock()
	for i = #movers, 1, -1 do
		local m = movers[i]
		local k = math.clamp((now - m.Start) / m.Duration, 0, 1)
		if m.Part.Parent then
			m.Part.CFrame = CFrame.new(m.Path(k))
		end
		if k >= 1 then
			table.remove(movers, i)
			if m.Done then
				local ok, err = pcall(m.Done)
				if not ok then
					warn("[Fuochi] " .. tostring(err))
				end
			end
		end
	end
end

local function move(part: BasePart, path: (number) -> Vector3, duration: number, done: (() -> ())?)
	table.insert(movers, { Part = part, Path = path, Start = os.clock(), Duration = duration, Done = done })
end

-- MATTONI ------------------------------------------------------------------------------------------------

local function glowPart(size: number, color: Color3, position: Vector3): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * size
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = CFrame.new(position)
	p.Parent = folder
	return p
end

local function addTrail(p: BasePart, color: Color3, width: number, lifetime: number)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(-width / 2, 0, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(width / 2, 0, 0)
	a1.Parent = p
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = lifetime
	trail.FaceCamera = true
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
	trail.Parent = p
end

-- Un punto invisibile da cui partono le particelle (si cancella da solo)
local function anchorAt(position: Vector3, lifetime: number): Attachment
	local holder = Instance.new("Part")
	holder.Size = Vector3.one
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CFrame = CFrame.new(position)
	holder.Parent = folder
	local a = Instance.new("Attachment")
	a.Parent = holder
	task.delay(lifetime, function()
		holder:Destroy()
	end)
	return a
end

local function sparkEmitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = 0
	e.SpreadAngle = Vector2.new(180, 180)
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function flashLight(position: Vector3, color: Color3, brightness: number, time: number)
	local a = anchorAt(position, time + 0.2)
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = brightness
	light.Color = color
	light.Shadows = false
	light.Parent = a
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - start) / time
		if k >= 1 or not light.Parent then
			conn:Disconnect()
			return
		end
		light.Brightness = brightness * (1 - k) * (1 - k)
	end)
end

local function sound(name: string, position: Vector3, volume: number, pitch: number)
	if C.SoundController then
		C.SoundController.Play(name, position, { Range = 1600, Volume = volume, Pitch = pitch })
	end
end

local function pick(rng: Random, list)
	return list[rng:NextInteger(1, #list)]
end

-- ESPLOSIONI ------------------------------------------------------------------------------------------

local function burstPeony(apex: Vector3, color: Color3, rng: Random)
	local a = anchorAt(apex, 4)
	local second = if rng:NextNumber() < 0.5 then Color3.new(1, 1, 1) else pick(rng, COLORS)
	local e = sparkEmitter(a, {
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.15, color), ColorSequenceKeypoint.new(1, second) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(0.5, 1.4), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.4, 2.1),
		Speed = NumberRange.new(48, 62),
		Drag = 2.3,
		Acceleration = Vector3.new(0, -9, 0),
	})
	e:Emit(230)
end

local function burstWillow(apex: Vector3)
	local a = anchorAt(apex, 5)
	local e = sparkEmitter(a, {
		Color = ColorSequence.new(Color3.fromRGB(255, 240, 190), Color3.fromRGB(255, 150, 40)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.8), NumberSequenceKeypoint.new(1, 0.2) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(2.6, 3.8),
		Speed = NumberRange.new(30, 42),
		Drag = 1.3,
		Acceleration = Vector3.new(0, -24, 0),
	})
	e:Emit(190)
end

local function burstCrackle(apex: Vector3, delay: number)
	task.delay(delay, function()
		local a = anchorAt(apex, 2)
		local e = sparkEmitter(a, {
			Color = ColorSequence.new(Color3.new(1, 1, 1)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(0.08, 0.3),
			Speed = NumberRange.new(10, 40),
			Drag = 3,
		})
		e:Emit(140)
		sound("Shot", apex, 0.25, 3)
	end)
end

-- Anello: scintille con la scia che si allargano su un piano inclinato
local function burstRing(apex: Vector3, color: Color3, rng: Random)
	local tilt = CFrame.Angles(rng:NextNumber(-0.9, 0.9), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.9, 0.9))
	local count = 22
	local radius = rng:NextNumber(45, 60)
	for i = 1, count do
		local a = i / count * math.pi * 2
		local dir = tilt:VectorToWorldSpace(Vector3.new(math.cos(a), 0, math.sin(a)))
		local spark = glowPart(0.8, color, apex)
		addTrail(spark, color, 0.7, 0.45)
		move(spark, function(k)
			local spread = 1 - (1 - k) * (1 - k)
			return apex + dir * radius * spread - Vector3.new(0, 10 * k * k, 0)
		end, 1.5, function()
			spark:Destroy()
		end)
	end
end

-- Palma: grandi comete che si aprono verso l'alto e poi ricadono
local function burstPalm(apex: Vector3, color: Color3, rng: Random)
	local arms = 8
	for i = 1, arms do
		local a = i / arms * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local dir = Vector3.new(math.cos(a), rng:NextNumber(0.15, 0.6), math.sin(a)).Unit
		local comet = glowPart(1.6, color, apex)
		addTrail(comet, color, 1.4, 0.9)
		local speed = rng:NextNumber(55, 70)
		move(comet, function(k)
			local t = k * 2.2
			return apex + dir * speed * t * (1 - 0.35 * t) - Vector3.new(0, 14 * t * t, 0)
		end, 2.2, function()
			comet:Destroy()
		end)
	end
end

local function explode(apex: Vector3, color: Color3, kind: string, rng: Random)
	flashLight(apex, color, 7, 0.8)
	sound("Explosion", apex, 0.6, rng:NextNumber(0.9, 1.4))
	if kind == "Willow" then
		burstWillow(apex)
		burstCrackle(apex, 1.6)
	elseif kind == "Ring" then
		burstRing(apex, color, rng)
		burstPeony(apex, color, rng)
	elseif kind == "Palm" then
		burstPalm(apex, color, rng)
	elseif kind == "Crackle" then
		burstPeony(apex, Color3.new(1, 1, 1), rng)
		burstCrackle(apex, 0.6)
	else
		burstPeony(apex, color, rng)
		if rng:NextNumber() < 0.35 then
			burstCrackle(apex, 1.2)
		end
	end
end

local KINDS = { "Peony", "Peony", "Peony", "Willow", "Willow", "Ring", "Palm", "Crackle" }

-- Un razzo: sale con la scia e scoppia in cima
function FireworksController.Rocket(base: Vector3, height: number, color: Color3?, kind: string?, rng: Random?)
	local r = rng or Random.new()
	local c = color or pick(r, COLORS)
	local k = kind or pick(r, KINDS)
	local shell = glowPart(0.9, Color3.fromRGB(255, 230, 190), base)
	addTrail(shell, Color3.fromRGB(255, 170, 80), 0.5, 0.5)
	local sparks = sparkEmitter(shell, {
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 120)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.2, 0.4),
		Speed = NumberRange.new(2, 6),
		Rate = 60,
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(25, 25),
	})
	local drift = Vector3.new(r:NextNumber(-8, 8), 0, r:NextNumber(-8, 8))
	local apex = base + Vector3.new(0, height, 0) + drift
	sound("Shot", base, 0.25, r:NextNumber(1.6, 2.2))
	move(shell, function(t)
		local up = 1 - (1 - t) * (1 - t)
		return base:Lerp(apex, up) + Vector3.new(math.sin(t * 20) * 0.6, 0, 0)
	end, r:NextNumber(1.0, 1.4), function()
		sparks.Enabled = false
		shell.Transparency = 1
		task.delay(0.6, function()
			shell:Destroy()
		end)
		explode(apex, c, k, r)
	end)
end

-- Spettacolo completo sopra una città
function FireworksController.Show(center: Vector3, duration: number, seed: number?)
	local rng = Random.new(seed or os.clock() * 1000)
	local dense = not C.ClientData or C.ClientData.Setting("Scenery", true) ~= false
	local function launch()
		local base = center + Vector3.new(rng:NextNumber(-90, 90), 6, rng:NextNumber(-90, 90))
		FireworksController.Rocket(base, rng:NextNumber(110, 190), nil, nil, rng)
	end
	task.spawn(function()
		local finale = math.max(4, duration - 5)
		local t0 = os.clock()
		while os.clock() - t0 < finale do
			launch()
			if dense and rng:NextNumber() < 0.35 then
				launch()
			end
			task.wait(rng:NextNumber(0.45, 1.1))
		end
		-- gran finale: un muro di salici d'oro e raffiche di colori
		for i = 1, (if dense then 18 else 9) do
			local base = center + Vector3.new(-80 + (i % 9) * 20, 6, rng:NextNumber(-30, 30))
			FireworksController.Rocket(base, rng:NextNumber(130, 200), if i % 3 == 0 then GOLD else nil, if i % 2 == 0 then "Willow" else nil, rng)
			task.wait(0.14)
		end
	end)
end

-- Pioggia di coriandoli sopra il giocatore
function FireworksController.Confetti(big: boolean?)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local a = anchorAt(root.Position + Vector3.new(0, 14, 0), 6)
	local e = sparkEmitter(a, {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 80)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 220, 120)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(100, 170, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 110, 255)),
		}),
		LightEmission = 0.3,
		Size = NumberSequence.new(0.7),
		Lifetime = NumberRange.new(2.5, 4),
		Speed = NumberRange.new(14, 30),
		Drag = 1.6,
		Acceleration = Vector3.new(0, -14, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-300, 300),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(70, 70),
	})
	e:Emit(if big then 320 else 140)
	if C.SoundController then
		C.SoundController.Play("Reward")
	end
end

-- Il Colosso d'Oro cade dal cielo: meteora, fulmini, impatto e colonna di luce
function FireworksController.ColossusArrival(position: Vector3, height: number)
	local fx = C.EffectsController
	local sky = position + Vector3.new(320, 1100, 220)
	local size = math.max(16, height * 0.28)
	local meteor = glowPart(size, Color3.fromRGB(255, 214, 110), sky)
	addTrail(meteor, GOLD, size * 0.8, 1.2)
	local fire = Instance.new("Fire")
	fire.Size = math.min(30, size * 1.2)
	fire.Heat = 0
	fire.Color = Color3.fromRGB(255, 190, 60)
	fire.SecondaryColor = Color3.fromRGB(255, 120, 30)
	fire.Parent = meteor
	sparkEmitter(meteor, {
		Color = ColorSequence.new(Color3.fromRGB(255, 240, 180), Color3.fromRGB(255, 150, 40)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(10, 30),
		Rate = 120,
	})
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 5
	light.Color = GOLD
	light.Parent = meteor
	if fx then
		fx.Flash(Color3.fromRGB(255, 220, 150), 0.25, 1.2)
		for i = 0, 2 do
			task.delay(0.3 + i * 0.55, function()
				local around = position + Vector3.new(math.random(-120, 120), 0, math.random(-120, 120))
				fx.Lightning(around + Vector3.new(0, 900, 0), around, Color3.fromRGB(255, 226, 140), 5)
			end)
		end
	end
	if C.SoundController then
		C.SoundController.Play("Thunder", position, { Range = 4000, Volume = 1, Pitch = 0.6 })
	end
	if C.CameraController then
		C.CameraController.Shake(0.25, 2)
	end
	move(meteor, function(k)
		return sky:Lerp(position + Vector3.new(0, height * 0.4, 0), k * k)
	end, 2.0, function()
		meteor:Destroy()
		local impact = position + Vector3.new(0, 2, 0)
		if fx then
			fx.Explosion(impact, height * 0.7, true)
			fx.Shockwave(impact, height * 3.2, GOLD, 1.4, 3)
			fx.Shockwave(impact, height * 2.2, Color3.new(1, 1, 1), 1, 2)
			fx.Shockwave(impact + Vector3.new(0, 6, 0), height * 1.5, Color3.fromRGB(255, 150, 60), 0.8, 1.5)
			fx.Steam(impact, height * 0.9, 30, 4, Color3.fromRGB(196, 176, 140))
			fx.DebrisBurst(impact, 26, 5, Color3.fromRGB(120, 104, 84), Enum.Material.Ground, 160)
			fx.Flash(Color3.fromRGB(255, 240, 200), 0.6, 1)
			fx.ShakeAt(impact, 1, 3000, 1.6)
		end
		flashLight(impact + Vector3.new(0, 20, 0), GOLD, 10, 2.5)
		if C.SoundController then
			C.SoundController.Play("Explosion", impact, { Range = 4000, Volume = 1, Pitch = 0.45 })
		end
		-- colonna di luce dorata che sale al cielo e si spegne
		local pillar = Instance.new("Part")
		pillar.Shape = Enum.PartType.Cylinder
		pillar.Size = Vector3.new(600, height * 0.6, height * 0.6)
		pillar.CFrame = CFrame.new(impact + Vector3.new(0, 300, 0)) * CFrame.Angles(0, 0, math.rad(90))
		pillar.Material = Enum.Material.Neon
		pillar.Color = Color3.fromRGB(255, 220, 130)
		pillar.Transparency = 0.35
		pillar.Anchored = true
		pillar.CanCollide = false
		pillar.CanQuery = false
		pillar.CanTouch = false
		pillar.CastShadow = false
		pillar.Parent = folder
		local start = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local k = (os.clock() - start) / 2.6
			if k >= 1 or not pillar.Parent then
				conn:Disconnect()
				pillar:Destroy()
				return
			end
			local w = height * 0.6 * (1 - k * 0.8)
			pillar.Size = Vector3.new(600, w, w)
			pillar.Transparency = 0.35 + 0.65 * k
		end)
		local a = anchorAt(impact + Vector3.new(0, 10, 0), 5)
		sparkEmitter(a, {
			Color = ColorSequence.new(Color3.fromRGB(255, 240, 180), GOLD),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(1.5, 2.5),
			Speed = NumberRange.new(60, 110),
			Drag = 2,
			Acceleration = Vector3.new(0, -20, 0),
		}):Emit(260)
	end)
end

function FireworksController.Init(c)
	C = c
end

function FireworksController.Start()
	folder = Instance.new("Folder")
	folder.Name = "FuochiLocali"
	folder.Parent = workspace
	RunService.RenderStepped:Connect(step)
end

return FireworksController
