--[[
	HalloweenShows - le animazioni degli eventi di Halloween dell'Admin Abuse (solo nel file di Halloween)
	Le usa AbuseEventController: qui ci sono le cinque scene d'apertura (girate sul set nel cielo, con la
	regia e i giganti animati), le particelle attorno al giocatore durante l'evento, i piccoli eventi
	nel cielo e gli effetti mandati dal server (zucche che esplodono, fantasmi, giganti che risorgono,
	zucche piene di dolci che cadono, scherzetti, pipistrelli).
	  🎃 La Notte delle Zucche     l'orto si accende, il Re Zucca sorge dalla terra e le zucche diventano giganti
	  👻 Il Gigante Fantasma       le luci si spengono e uno spettro enorme attraversa il Muro
	  💀 Il Risveglio dei Caduti   fulmini verdi sul cimitero dei giganti e i caduti risorgono
	  🍬 Dolcetto o Scherzetto     la Strega Bestia lancia zucche oltre il Muro come sassi: pioggia di dolci
	  🌕 La Luna di Sangue         la luna diventa rossa, il Colosso si alza davanti e i pipistrelli escono dalla luna
	Tutto è solo grafico.
]]

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared.Lib.Util)
local ArmReach = require(Shared.Anim.ArmReach)

local HalloweenShows = {}

local PUMPKIN = Color3.fromRGB(236, 118, 28)
local CANDLE = Color3.fromRGB(255, 196, 92)
local CARVED_DARK = Color3.fromRGB(40, 20, 10)
local STEM = Color3.fromRGB(70, 96, 40)
local BAT = Color3.fromRGB(22, 14, 28)
local GHOST_BLUE = Color3.fromRGB(170, 225, 255)
local WITCH_GREEN = Color3.fromRGB(130, 255, 100)
local BLOOD = Color3.fromRGB(255, 50, 50)
local CANDY = { Color3.fromRGB(255, 90, 170), Color3.fromRGB(255, 220, 80), Color3.fromRGB(120, 230, 120), Color3.fromRGB(120, 180, 255), Color3.fromRGB(255, 140, 40), Color3.fromRGB(190, 110, 255) }

local K: any = nil -- gli attrezzi di AbuseEventController (Register)

-- ATTREZZI ---------------------------------------------------------------------------------------------

local function fx(): any
	return K.Fx()
end

local function rng(): Random
	return K.Rng
end

local function candySequence(): ColorSequence
	local keys = {}
	for i, c in CANDY do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#CANDY - 1), c))
	end
	return ColorSequence.new(keys)
end

-- parte "di mondo" (non della scena): resta qualche secondo e poi sparisce da sola
local function worldPart(props: { [string]: any }, life: number): BasePart
	local className = props.ClassName or "Part"
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "ClassName" and k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = K.Folder() or workspace
	Debris:AddItem(p, life)
	return p
end

-- zucca con la faccia intagliata. make = K.Part (scena) o una funzione che crea parti di mondo
type Pumpkin = { Body: BasePart, Face: { BasePart }, Light: PointLight?, Parts: { BasePart } }
local function pumpkin(make: (any) -> BasePart, cf: CFrame, size: number, lit: boolean, withLight: boolean?): Pumpkin
	local h = size * 0.78
	local center = cf * CFrame.new(0, h / 2, 0)
	local parts = {}
	local function add(p: BasePart): BasePart
		table.insert(parts, p)
		return p
	end
	local body = add(make({ Name = "Zucca", Size = Vector3.new(size, h, size * 0.94), CFrame = center, Color = PUMPKIN, Material = Enum.Material.SmoothPlastic }))
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = body
	local rib = add(make({ Name = "Spicchio", Size = Vector3.new(size * 0.62, h * 1.02, size), CFrame = center * CFrame.Angles(0, math.rad(45), 0), Color = Color3.fromRGB(206, 96, 22), Material = Enum.Material.SmoothPlastic }))
	local ribMesh = Instance.new("SpecialMesh")
	ribMesh.MeshType = Enum.MeshType.Sphere
	ribMesh.Parent = rib
	add(make({ Name = "Gambo", Size = Vector3.new(size * 0.13, size * 0.26, size * 0.13), CFrame = center * CFrame.new(0, h * 0.5 + size * 0.08, 0) * CFrame.Angles(0.2, 0, -0.2), Color = STEM, Material = Enum.Material.Wood }))
	local face = {}
	local function surface(x: number, y: number): number
		local k = 1 - (x / (size * 0.5)) ^ 2 - (y / (h * 0.5)) ^ 2
		return -size * 0.47 * math.sqrt(math.max(0.05, k)) - 0.04
	end
	local color = if lit then CANDLE else CARVED_DARK
	local material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local function triangle(x: number, y: number, w: number, th: number)
		for _, side in { -1, 1 } do
			table.insert(face, add(make({ ClassName = "WedgePart", Name = "Intaglio", Size = Vector3.new(0.1, th, w / 2), CFrame = center * CFrame.new(x + side * w / 4, y, surface(x, y)) * CFrame.Angles(0, side * math.rad(-90), 0), Color = color, Material = material })))
		end
	end
	triangle(-size * 0.2, h * 0.12, size * 0.22, h * 0.22)
	triangle(size * 0.2, h * 0.12, size * 0.22, h * 0.22)
	triangle(0, -h * 0.02, size * 0.12, h * 0.12)
	table.insert(face, add(make({ Name = "Bocca", Size = Vector3.new(size * 0.34, h * 0.09, 0.1), CFrame = center * CFrame.new(0, -h * 0.2, surface(0, -h * 0.2)), Color = color, Material = material })))
	for _, sx in { -1, 1 } do
		local x, y = sx * size * 0.22, -h * 0.15
		table.insert(face, add(make({ Name = "Bocca", Size = Vector3.new(size * 0.14, h * 0.08, 0.1), CFrame = center * CFrame.new(x, y, surface(x, y)) * CFrame.Angles(0, sx * math.rad(-25), sx * math.rad(28)), Color = color, Material = material })))
	end
	local light: PointLight? = nil
	if withLight ~= false then
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 150, 56)
		l.Range = math.clamp(size * 3, 10, 60)
		l.Brightness = if lit then 2 else 0
		l.Shadows = false
		l.Parent = body
		light = l
	end
	return { Body = body, Face = face, Light = light, Parts = parts }
end

local function lightPumpkin(p: Pumpkin, on: boolean)
	for _, f in p.Face do
		if f.Parent then
			f.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
			f.Color = if on then CANDLE else CARVED_DARK
		end
	end
	if p.Light then
		p.Light.Brightness = if on then 2.2 else 0
	end
end

-- luna enorme (con l'alone) lontano sul set
local function moonDisc(pos: Vector3, size: number, color: Color3): { BasePart }
	local moon = K.Part({ Name = "Luna", Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = CFrame.new(pos), Material = Enum.Material.Neon, Color = color })
	local halo = K.Part({ Name = "Alone", Shape = Enum.PartType.Ball, Size = Vector3.one * size * 1.35, CFrame = CFrame.new(pos), Material = Enum.Material.Neon, Color = color, Transparency = 0.86 })
	return { moon, halo }
end

-- pipistrelli: count pipistrelli volano da from a to in duration secondi (sparsi di "spread" studs)
local function bats(make: (any) -> BasePart, from: Vector3, to: Vector3, count: number, duration: number, spread: number, scale: number, followers: { () -> () }?)
	local list = {}
	for _ = 1, count do
		local s = scale * rng():NextNumber(0.8, 1.25)
		local entry = {
			Body = make({ Name = "Pipistrello", Size = Vector3.new(0.9, 0.8, 1.6) * s, Color = BAT, Transparency = 1 }),
			Left = make({ Name = "Ala", Size = Vector3.new(2.4, 0.12, 1.3) * s, Color = BAT, Transparency = 1 }),
			Right = make({ Name = "Ala", Size = Vector3.new(2.4, 0.12, 1.3) * s, Color = BAT, Transparency = 1 }),
			Offset = Vector3.new(rng():NextNumber(-1, 1), rng():NextNumber(-0.5, 0.5), rng():NextNumber(-1, 1)) * spread,
			Delay = rng():NextNumber(0, duration * 0.35),
			Phase = rng():NextNumber(0, math.pi * 2),
			Speed = rng():NextNumber(0.85, 1.2),
			S = s,
		}
		table.insert(list, entry)
	end
	local start = os.clock()
	local dir = Util.SafeUnit(to - from, Vector3.new(0, 0, -1))
	local function update(): boolean
		local t = os.clock() - start
		for _, b in list do
			local k = math.clamp((t - b.Delay) / (duration * 0.65) * b.Speed, 0, 1)
			local visible = t >= b.Delay and k < 1
			local pos = from:Lerp(to, k) + b.Offset * (0.3 + k) + Vector3.new(0, math.sin(t * 3 + b.Phase) * 4 * b.S, 0)
			local cf = CFrame.lookAt(pos, pos + dir)
			local flap = math.sin(t * 17 + b.Phase) * 0.9
			if b.Body.Parent then
				b.Body.CFrame = cf
				b.Left.CFrame = cf * CFrame.new(-0.35 * b.S, 0, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-1.2 * b.S, 0, 0)
				b.Right.CFrame = cf * CFrame.new(0.35 * b.S, 0, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(1.2 * b.S, 0, 0)
				local a = if visible then 0 else 1
				b.Body.Transparency = a
				b.Left.Transparency = a
				b.Right.Transparency = a
			end
		end
		return t < duration + 0.5
	end
	if followers then
		table.insert(followers, function()
			update()
		end)
	else
		-- fuori dalle scene: si aggiornano da soli e poi spariscono
		local conn
		conn = RunService.RenderStepped:Connect(function()
			if not update() then
				conn:Disconnect()
				for _, b in list do
					b.Body:Destroy()
					b.Left:Destroy()
					b.Right:Destroy()
				end
			end
		end)
	end
	return list
end

-- esplosione di dolcetti colorati
local function candyBurst(pos: Vector3, size: number)
	local holder = worldPart({ Name = "Dolcetti", Size = Vector3.one, CFrame = CFrame.new(pos), Transparency = 1 }, 5)
	local e = Instance.new("ParticleEmitter")
	e.Texture = ""
	e.Color = candySequence()
	e.LightEmission = 0.4
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.06), NumberSequenceKeypoint.new(1, size * 0.04) })
	e.Lifetime = NumberRange.new(1.4, 2.6)
	e.Speed = NumberRange.new(size * 0.5, size * 1.2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -size * 0.6, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-300, 300)
	e.Drag = 0.6
	e.Rate = 0
	e.Parent = holder
	e:Emit(math.clamp(math.floor(size * 2), 20, 120))
	local f = fx()
	if f then
		f.Sparks(pos, Color3.fromRGB(255, 160, 220), 24, size * 0.8)
	end
end

local function purpleSmoke(pos: Vector3, size: number)
	K.Steam(pos, size, 16, 3, Color3.fromRGB(150, 80, 220))
end

local function greenStrike(ground: Vector3, thickness: number?)
	K.Strike(ground, thickness or 6, WITCH_GREEN)
end

-- un piccolo spaventapasseri con la testa di zucca (sul set)
local function scarecrow(cf: CFrame, s: number)
	local wood = Color3.fromRGB(70, 50, 34)
	K.Part({ Name = "Palo", Size = Vector3.new(0.6, 9, 0.6) * s, CFrame = cf * CFrame.new(0, 4.5 * s, 0), Material = Enum.Material.Wood, Color = wood })
	K.Part({ Name = "Traversa", Size = Vector3.new(7, 0.5, 0.5) * s, CFrame = cf * CFrame.new(0, 6.6 * s, 0), Material = Enum.Material.Wood, Color = wood })
	K.Part({ Name = "Camicia", Size = Vector3.new(2.6, 3, 1.3) * s, CFrame = cf * CFrame.new(0, 5.6 * s, 0), Material = Enum.Material.Fabric, Color = Color3.fromRGB(100, 50, 110) })
	pumpkin(K.Part, cf * CFrame.new(0, 7.2 * s, 0), 2.4 * s, false, false)
end

-- albero morto (sul set): tronco nero e rami spogli
local function deadTree(base: Vector3, h: number)
	local bark = Color3.fromRGB(30, 24, 28)
	local top = base + Vector3.new(rng():NextNumber(-8, 8), h, rng():NextNumber(-8, 8))
	local function stick(a: Vector3, b: Vector3, d: number)
		local dirv = b - a
		local up = if math.abs(Util.SafeUnit(dirv, Vector3.yAxis).Y) > 0.98 then Vector3.xAxis else Vector3.yAxis
		K.Part({ Name = "Ramo", Size = Vector3.new(d, d, dirv.Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b, up), Material = Enum.Material.Wood, Color = bark })
	end
	stick(base, top, h * 0.07)
	for _ = 1, 4 do
		local a = rng():NextNumber(0, math.pi * 2)
		local from = base:Lerp(top, rng():NextNumber(0.4, 0.95))
		local to = from + Vector3.new(math.cos(a) * h * 0.35, h * rng():NextNumber(0.08, 0.25), math.sin(a) * h * 0.35)
		stick(from, to, h * 0.025)
	end
end

-- lapide gigante (sul set). cf a terra, la faccia verso -Z
local function giantGrave(cf: CFrame, w: number, h: number)
	local stone = Color3.fromRGB(98, 96, 104):Lerp(Color3.fromRGB(70, 74, 70), rng():NextNumber())
	local lean = cf * CFrame.Angles(rng():NextNumber(-0.08, 0.05), 0, rng():NextNumber(-0.07, 0.07))
	K.Part({ Name = "Lapide", Size = Vector3.new(w, h, w * 0.26), CFrame = lean * CFrame.new(0, h / 2, 0), Material = Enum.Material.Slate, Color = stone })
	K.Part({ Name = "Lapide", Shape = Enum.PartType.Cylinder, Size = Vector3.new(w * 0.26, w, w), CFrame = lean * CFrame.new(0, h, 0) * CFrame.Angles(0, math.rad(90), 0), Material = Enum.Material.Slate, Color = stone })
	K.Part({ Name = "Crepa", Size = Vector3.new(w * 0.05, h * 0.5, 0.4), CFrame = lean * CFrame.new(w * 0.15, h * 0.55, -w * 0.13) * CFrame.Angles(0, 0, 0.3), Material = Enum.Material.Slate, Color = Color3.fromRGB(40, 40, 44) })
end

-- lampione della strada (sul set) con la sua luce
local function streetLamp(pos: Vector3): { Lantern: BasePart, Light: PointLight }
	K.Part({ Name = "Lampione", Size = Vector3.new(0.9, 14, 0.9), CFrame = CFrame.new(pos + Vector3.new(0, 7, 0)), Material = Enum.Material.Metal, Color = Color3.fromRGB(30, 28, 32) })
	local lantern = K.Part({ Name = "Lanterna", Size = Vector3.new(1.8, 2, 1.8), CFrame = CFrame.new(pos + Vector3.new(0, 14.6, 0)), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 180, 90) })
	local light = K.GlowLight(lantern, Color3.fromRGB(255, 170, 90), 34, 2)
	return { Lantern = lantern, Light = light }
end

local function fogBank(pos: Vector3, size: Vector3, color: Color3, rate: number)
	local p = K.Part({ Name = "Nebbia", Size = size, CFrame = CFrame.new(pos), Transparency = 1 })
	K.Emitter(p, {
		Texture = K.Textures.Smoke,
		Color = ColorSequence.new(color),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.78), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 30), NumberSequenceKeypoint.new(1, 70) }),
		Lifetime = NumberRange.new(6, 10),
		Speed = NumberRange.new(2, 6),
		SpreadAngle = Vector2.new(180, 20),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-8, 8),
		LightInfluence = 0.8,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Rate = rate,
	})
	return p
end

-- un proiettile-zucca che vola da a a b (parabola), con la scia; done() all'arrivo
local function pumpkinShot(from: Vector3, to: Vector3, size: number, time: number, arc: number, done: (() -> ())?): Pumpkin
	local p = pumpkin(K.Part, CFrame.new(from), size, true)
	local trail = K.Emitter(p.Body, {
		Texture = K.Textures.Sparks,
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 80, 160)),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.25), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.4, 0.9),
		Speed = NumberRange.new(2, 8),
		SpreadAngle = Vector2.new(30, 30),
		Rate = 60,
	})
	local offsets = {}
	for _, part in p.Parts do
		offsets[part] = p.Body.CFrame:ToObjectSpace(part.CFrame)
	end
	local spin = rng():NextNumber(-6, 6)
	K.MoveAlong(p.Body, function(k)
		local pos = from:Lerp(to, k) + Vector3.new(0, math.sin(k * math.pi) * arc, 0)
		return CFrame.new(pos) * CFrame.Angles(k * spin, k * spin * 0.6, 0)
	end, time, function()
		trail.Enabled = false
		if done then
			done()
		end
	end)
	-- le altre parti della zucca seguono il corpo
	table.insert(K.Followers, function()
		if p.Body.Parent then
			for part, off in offsets do
				if part ~= p.Body and part.Parent then
					part.CFrame = p.Body.CFrame * off
				end
			end
		end
	end)
	return p
end

local function hidePumpkin(p: Pumpkin)
	for _, part in p.Parts do
		if part.Parent then
			part.Transparency = 1
		end
	end
	if p.Light then
		p.Light.Brightness = 0
	end
end

local function fadeModel(model: Instance, time: number)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			TweenService:Create(d, TweenInfo.new(time), { Transparency = 1 }):Play()
		elseif d:IsA("ParticleEmitter") then
			d.Enabled = false
		elseif d:IsA("PointLight") then
			TweenService:Create(d, TweenInfo.new(time), { Brightness = 0 }):Play()
		end
	end
end

-- LE SCENE --------------------------------------------------------------------------------------------------

local SHOWS: { [string]: ((number, () -> ()) -> ()) -> () } = {}

-- 🎃 La Notte delle Zucche: l'orto buio sotto la luna, le zucche che si accendono a ondata, il Re Zucca
-- che sorge dalla terra, l'urlo con i pipistrelli e le zucche che esplodono in giganti-zucca
SHOWS.NotteZucche = function(after)
	local st = K.SetStage(Color3.fromRGB(58, 44, 36), Enum.Material.Ground)
	local at, look = K.At, K.Look
	K.Hills(st, 12, Color3.fromRGB(64, 54, 38), 420)
	K.WallSegment(st, -460, 1400, 150, "Cancello")
	moonDisc(at(st, 260, 1800, 380), 800, Color3.fromRGB(255, 156, 66))
	local face = st.ToCamera
	local spot = at(st, 0, 230)
	-- l'orto: zucche spente (una su tre con la candela pronta)
	local field: { { P: Pumpkin, Z: number } } = {}
	for i = 1, 64 do
		local x, z = rng():NextNumber(-340, 340), rng():NextNumber(-160, 520)
		if math.abs(x) > 46 or math.abs(z - 230) > 80 then
			local s = rng():NextNumber(3.5, 7.5)
			local p = pumpkin(K.Part, CFrame.new(at(st, x, z)) * face.Rotation * CFrame.Angles(0, rng():NextNumber(-0.5, 0.5), 0), s, false, i % 3 == 0)
			table.insert(field, { P = p, Z = z })
		end
	end
	table.sort(field, function(a, b)
		return a.Z < b.Z
	end)
	for i = 1, 3 do
		scarecrow(CFrame.new(at(st, -260 + i * 130, 60 + i * 90)) * face.Rotation, 1.6)
	end
	for i = 1, 6 do
		deadTree(at(st, (if i % 2 == 0 then -1 else 1) * rng():NextNumber(160, 420), rng():NextNumber(300, 700)), rng():NextNumber(60, 110))
	end
	local king = K.Titan("Zucca", 150, spot - Vector3.new(0, 170, 0), face)
	local H = 150
	local function head(): Vector3
		return K.HeadPosition(king, H)
	end

	-- 1. l'orto al buio sotto la luna (sotto il titolo)
	K.Shot(look(at(st, -30, -270, 10), at(st, 0, 400, 70)), look(at(st, -22, -215, 12), at(st, 10, 400, 80)), 3.6)
	after(1.2, function()
		K.Sound("Spettro", nil, 0.6, 0.35)
		K.Shake(0.1, 1)
	end)
	-- 2. le zucche si accendono a ondata, dalla telecamera verso la luna
	after(3.4, function()
		K.ShotPath(function(k)
			return look(at(st, 0, -150 + 260 * k, 6 + 4 * k), at(st, 0, 320, 34))
		end, 2.8, 0.6, 60)
	end)
	for i, entry in field do
		after(3.4 + i * 0.035, function()
			lightPumpkin(entry.P, true)
		end)
	end
	-- 3. la terra si spacca e sorge il Re Zucca, contro la luna
	after(6.2, function()
		local f = fx()
		if f then
			f.Explosion(spot + Vector3.new(0, 10, 0), 60, true)
			f.DebrisBurst(spot, 46, 7, Color3.fromRGB(70, 52, 38), Enum.Material.Ground, 220)
			f.Flash(Color3.fromRGB(255, 170, 80), 0.4, 0.6)
		end
		purpleSmoke(spot + Vector3.new(0, 20, 0), 120)
		K.Sound("Explosion", nil, 1, 0.3)
		K.Shake(0.9, 1.6)
		K.TweenTo(king, K.Standing(king, spot, face), 3.4, "QuadOut")
		K.ShotPath(function()
			local h = head()
			return look(at(st, 34, -70, 5), Vector3.new(h.X, math.max(h.Y - 30, spot.Y + 30), h.Z))
		end, 3.6, 0.6, 30)
	end)
	-- 4. l'urlo: le zucche tremolano e i pipistrelli escono dagli alberi passando davanti alla luna
	after(9.6, function()
		K.RoarAt(king, H, Color3.fromRGB(255, 160, 60), 0.18)
		bats(K.Part, at(st, -620, 700, 140), at(st, 640, 420, 190), 46, 4.2, 70, 2.4, K.Followers)
		for i, entry in field do
			if i % 2 == 0 then
				lightPumpkin(entry.P, false)
				task.delay(0.25, function()
					lightPumpkin(entry.P, true)
				end)
			end
		end
		K.ShotPath(function(k)
			local e = Util.Ease(k, "SineInOut")
			local a = math.rad(25 + 55 * e)
			local r = 330 - 40 * e
			local from = spot + st.Right * (math.sin(a) * r) - st.Fwd * (math.cos(a) * r) + Vector3.new(0, 40 + 50 * e, 0)
			return look(from, head() - Vector3.new(0, H * 0.25, 0))
		end, 2.2, 0.8)
	end)
	-- 5. le zucche vicine esplodono e ne escono giganti con la testa di zucca
	after(11.8, function()
		K.Shot(look(at(st, -230, -170, 140), spot), look(at(st, -270, -230, 170), spot - Vector3.new(0, 20, 0)), 3.6, "QuadOut")
		local n = 0
		for _, entry in field do
			local pos = entry.P.Body.Position
			if n < 8 and (pos - spot).Magnitude < 330 then
				n += 1
				local idx = n
				task.delay(idx * 0.18, function()
					local ground = Vector3.new(pos.X, spot.Y, pos.Z)
					hidePumpkin(entry.P)
					local f = fx()
					if f then
						f.Explosion(ground + Vector3.new(0, 4, 0), 18, false)
						f.DebrisBurst(ground, 10, 3, PUMPKIN, Enum.Material.SmoothPlastic, 90)
					end
					candyBurst(ground + Vector3.new(0, 6, 0), 30)
					local m = K.Titan("Puro", rng():NextNumber(22, 32), ground - Vector3.new(0, 30, 0), face, "Zucca")
					K.TweenTo(m, K.Standing(m, ground, face), 0.7, "BackOut")
					task.delay(0.8, function()
						if m.Parent then
							K.Walk(m, 1, 0.5)
							K.TweenTo(m, K.Standing(m, ground - st.Fwd * 160, face), 4, "Linear")
						end
					end)
				end)
			end
		end
		K.Sound("Explosion", nil, 0.8, 0.5)
	end)
	after(13.6, function()
		K.Animate(king, "Slam")
	end)
	after(14.3, function()
		local f = fx()
		if f then
			f.Shockwave(spot + Vector3.new(0, 2, 0), 420, Color3.fromRGB(255, 150, 50), 1.2, 4)
			f.Flash(Color3.fromRGB(255, 160, 70), 0.5, 0.8)
		end
		K.Shake(1, 1.2)
	end)
end

-- 👻 Il Gigante Fantasma: la strada nella nebbia, le luci che si spengono, lo spettro che attraversa il
-- Muro come se non ci fosse, l'urlo gelido e i fantasmi che escono dalla nebbia
SHOWS.GiganteFantasma = function(after)
	local st = K.SetStage(Color3.fromRGB(60, 58, 66), Enum.Material.Cobblestone)
	local at, rel, look = K.At, K.Rel, K.Look
	K.District(st, -380, 380, -640, -70, function(x, _)
		return math.abs(x) < 34
	end)
	K.WallSegment(st, 0, 1400, 160, "Cancello")
	K.Hills(st, 8, Color3.fromRGB(70, 72, 84), 500)
	for i = 0, 6 do
		fogBank(at(st, 0, -560 + i * 80, 6), Vector3.new(200, 6, 70), Color3.fromRGB(200, 214, 236), 7)
	end
	fogBank(at(st, 0, 60, 10), Vector3.new(1200, 20, 120), Color3.fromRGB(190, 206, 230), 14)
	local lamps = {}
	for i = 0, 7 do
		for _, side in { -1, 1 } do
			table.insert(lamps, streetLamp(at(st, side * 28, -560 + i * 62)))
		end
	end
	local face = st.ToCamera
	local H = 120
	local ghost = K.Titan("Spettro", H, at(st, 0, 130), face)
	local function head(): Vector3
		return K.HeadPosition(ghost, H)
	end

	-- 1. la strada nella nebbia, di notte (sotto il titolo)
	K.Shot(look(at(st, 8, -580, 8), at(st, 0, 0, 90)), look(at(st, 6, -520, 9), at(st, 0, 0, 96)), 3.8)
	after(2.6, function()
		local l = lamps[#lamps]
		l.Light.Brightness = 0.4
		task.delay(0.15, function()
			l.Light.Brightness = 2
		end)
	end)
	-- 2. le luci si spengono una dopo l'altra, dalla più lontana
	for i = #lamps, 1, -1 do
		after(3.6 + (#lamps - i) * 0.07, function()
			local l = lamps[i]
			l.Light.Brightness = 0
			l.Lantern.Material = Enum.Material.SmoothPlastic
			l.Lantern.Color = Color3.fromRGB(50, 46, 44)
		end)
	end
	after(3.7, function()
		K.Sound("Spettro", nil, 1, 0.25)
		local f = fx()
		if f then
			f.Flash(GHOST_BLUE, 0.2, 1.2)
		end
	end)
	-- 3. lo spettro attraversa il Muro: la testa spunta dalle pietre, poi tutto il corpo
	after(4.6, function()
		K.Walk(ghost, 0.6, 0)
		K.TweenTo(ghost, K.Standing(ghost, at(st, 0, -90), face), 7.5, "Linear")
		K.Shot(look(at(st, -20, -430, 10), at(st, 0, 0, 150)), look(at(st, -16, -405, 10), at(st, 0, -20, 128)), 4, nil, 0.8, 26)
	end)
	after(7.2, function()
		-- dove passa, la pietra fuma di freddo
		K.Steam(at(st, 0, 0, 80), 120, 18, 4, Color3.fromRGB(220, 236, 255))
		K.Sound("Spettro", nil, 0.9, 0.18)
	end)
	-- 4. il volto da vicino e l'urlo gelido
	after(8.6, function()
		K.ShotPath(function()
			local h = head()
			return look(h + rel(st, 40, -110, -14), h)
		end, 2.2, 0.6, 40)
	end)
	after(9.1, function()
		K.RoarAt(ghost, H, GHOST_BLUE, 0.5)
		K.Sound("Spettro", nil, 1, 0.4)
		local blur = Instance.new("BlurEffect")
		blur.Size = 0
		blur.Parent = Lighting
		K.Track(blur)
		TweenService:Create(blur, TweenInfo.new(0.3), { Size = 14 }):Play()
		task.delay(0.6, function()
			TweenService:Create(blur, TweenInfo.new(1), { Size = 0 }):Play()
		end)
	end)
	-- 5. dall'alto: lo spettro si dissolve e nella nebbia compaiono i giganti fantasma
	local small = {}
	after(10.9, function()
		K.Shot(look(at(st, 260, -640, 220), at(st, 0, -220, 0)), look(at(st, 300, -690, 260), at(st, 0, -240, 0)), 3)
		fadeModel(ghost, 1.4)
		K.Steam(ghost:GetPivot().Position, 160, 30, 5, Color3.fromRGB(210, 230, 255))
		for i = 1, 6 do
			task.delay(i * 0.22, function()
				local p = at(st, rng():NextNumber(-300, 300), rng():NextNumber(-560, -140))
				local h = rng():NextNumber(30, 42)
				local m = K.Titan("Spettro", h, p - Vector3.new(0, h * 0.6, 0), face)
				table.insert(small, m)
				K.TweenTo(m, K.Standing(m, p, face), 1, "QuadOut")
				local f = fx()
				if f then
					f.Shockwave(p + Vector3.new(0, 2, 0), 60, GHOST_BLUE, 0.8, 2)
				end
			end)
		end
	end)
	-- 6. la strada: le luci tornano, verdi, e i fantasmi camminano verso di noi
	after(13.8, function()
		for _, l in lamps do
			l.Lantern.Material = Enum.Material.Neon
			l.Lantern.Color = WITCH_GREEN
			l.Light.Color = WITCH_GREEN
			l.Light.Brightness = 2
		end
		K.Shot(look(at(st, 6, -600, 7), at(st, 0, -300, 30)), look(at(st, 4, -585, 8), at(st, 0, -300, 34)), 2)
		for _, m in small do
			if m.Parent then
				K.Walk(m, 1, 0)
				K.TweenTo(m, m:GetPivot() + st.Fwd * -60, 2, "Linear")
			end
		end
	end)
end

-- 💀 Il Risveglio dei Caduti: il cimitero dei giganti nella nebbia verde, i fulmini, i giganti che
-- escono dalla terra (zombie e scheletri) e la marcia verso il Muro
SHOWS.RisveglioCaduti = function(after)
	local st = K.SetStage(Color3.fromRGB(46, 42, 40), Enum.Material.Mud)
	local at, rel, look = K.At, K.Rel, K.Look
	K.Hills(st, 12, Color3.fromRGB(46, 50, 44), 380)
	K.WallSegment(st, -700, 1500, 150, "Cancello")
	moonDisc(at(st, -300, 1700, 520), 600, Color3.fromRGB(170, 255, 150))
	local graves = {}
	for row = 0, 2 do
		for i = -2, 2 do
			local p = at(st, i * 110 + rng():NextNumber(-20, 20), 120 + row * 130 + rng():NextNumber(-20, 20))
			local w, h = rng():NextNumber(18, 26), rng():NextNumber(28, 46)
			giantGrave(CFrame.new(p) * st.ToCamera.Rotation, w, h)
			table.insert(graves, p)
		end
	end
	for i = 1, 7 do
		deadTree(at(st, (if i % 2 == 0 then -1 else 1) * rng():NextNumber(300, 520), rng():NextNumber(60, 600)), rng():NextNumber(60, 120))
	end
	fogBank(at(st, 0, 250, 8), Vector3.new(800, 10, 600), Color3.fromRGB(150, 220, 140), 16)
	local face = st.ToCamera
	local risers = {}

	-- 1. tra le lapidi giganti nella nebbia verde (sotto il titolo)
	K.Shot(look(at(st, -270, -40, 30), at(st, 0, 240, 34)), look(at(st, -210, 0, 34), at(st, 0, 260, 36)), 3.6)
	for _, t in { 1.0, 2.3 } do
		after(t, function()
			greenStrike(at(st, rng():NextNumber(-600, 600), rng():NextNumber(700, 1200)), 5)
		end)
	end
	-- 2. tre fulmini verdi colpiscono le tombe
	after(3.6, function()
		K.Shot(look(at(st, 0, -120, 20), at(st, 0, 200, 40)), look(at(st, 0, -100, 22), at(st, 0, 200, 44)), 1.2)
		for i = 0, 2 do
			task.delay(i * 0.2, function()
				greenStrike(graves[2 + i * 5] or graves[1], 12)
			end)
		end
		local f = fx()
		if f then
			f.Flash(WITCH_GREEN, 0.5, 0.8)
		end
		K.Shake(0.7, 1)
	end)
	-- 3. la terra si apre davanti alle tombe e i caduti risorgono
	for i = 1, 5 do
		after(4.6 + i * 0.35, function()
			local g = graves[i] or at(st, 0, 120)
			local spot = g - st.Fwd * 34
			local h = rng():NextNumber(34, 52)
			local f = fx()
			if f then
				f.DebrisBurst(spot, 24, 5, Color3.fromRGB(60, 50, 40), Enum.Material.Mud, 140)
			end
			K.Steam(spot + Vector3.new(0, 6, 0), 50, 8, 3, Color3.fromRGB(150, 230, 140))
			local m = K.Titan("Puro", h, spot - Vector3.new(0, h + 10, 0), face, if i % 2 == 0 then "Scheletro" else "Zombie")
			table.insert(risers, { M = m, H = h, Spot = spot })
			K.TweenTo(m, K.Standing(m, spot, face), 2.4, "QuadOut")
			K.Sound("Land", nil, 0.9, 0.25)
			K.Shake(0.3, 0.5)
		end)
	end
	after(4.8, function()
		K.ShotPath(function(k)
			return look(at(st, -10 + 20 * k, -40 + 60 * k, 6 + 2 * k), at(st, 0, 140, 30))
		end, 3.4, 0.6, 55)
	end)
	-- 4. da vicino: lo scheletro apre la bocca e urla
	after(8.2, function()
		local r = risers[2] or risers[1]
		if not r then
			return
		end
		local h = K.HeadPosition(r.M, r.H)
		K.Shot(look(h + rel(st, 28, -70, -6), h), look(h + rel(st, 22, -60, -4), h), 2)
		K.RoarAt(r.M, r.H, WITCH_GREEN, 0.3)
	end)
	-- 5. dall'alto: altri giganti risorgono in tutto il cimitero e marciano verso il Muro
	after(10.2, function()
		K.Shot(look(at(st, 0, -260, 220), at(st, 0, 200, 0)), look(at(st, 60, -300, 250), at(st, 0, 160, 0)), 3)
		for i = 1, 8 do
			task.delay(i * 0.18, function()
				local spot = at(st, rng():NextNumber(-420, 420), rng():NextNumber(60, 520))
				local h = rng():NextNumber(26, 44)
				local m = K.Titan("Puro", h, spot - Vector3.new(0, h + 10, 0), face, if i % 2 == 0 then "Scheletro" else "Zombie")
				table.insert(risers, { M = m, H = h, Spot = spot })
				K.TweenTo(m, K.Standing(m, spot, face), 1.6, "QuadOut")
				K.Steam(spot + Vector3.new(0, 4, 0), 40, 6, 2.5, Color3.fromRGB(150, 230, 140))
			end)
		end
		task.delay(2, function()
			for _, r in risers do
				if r.M.Parent then
					K.Walk(r.M, 0.6, 0)
					K.TweenTo(r.M, K.Standing(r.M, r.Spot - st.Fwd * 140, face), 5, "Linear")
				end
			end
		end)
	end)
	-- 6. alle loro spalle, verso il Muro lontano, tra i fulmini verdi
	after(13.2, function()
		K.Shot(look(at(st, 30, 640, 60), at(st, 0, -700, 80)), look(at(st, 20, 600, 66), at(st, 0, -700, 86)), 2.4)
		greenStrike(at(st, 120, -500), 10)
		task.delay(0.6, function()
			greenStrike(at(st, -200, -560), 8)
		end)
	end)
end

-- 🍬 Dolcetto o Scherzetto: dall'alto del Muro si vede la Strega Bestia (col cappello a punta) che lancia
-- zucche come sassi; le zucche volano sopra il Muro e scoppiano in dolcetti sul distretto
SHOWS.DolcettoScherzetto = function(after)
	local st = K.SetStage(Color3.fromRGB(104, 96, 56), Enum.Material.Grass)
	local at, rel, look = K.At, K.Rel, K.Look
	K.Hills(st, 12, Color3.fromRGB(110, 92, 52), 300)
	K.District(st, -380, 380, -560, -90, function(x, _)
		return math.abs(x) < 32
	end)
	K.WallSegment(st, 0, 1400, 130, "Cancello")
	local face = st.ToCamera
	local H = 160
	local witch = K.Titan("Fauno", H, at(st, 40, 760), face, "Strega")
	local held = pumpkin(K.Part, CFrame.new(at(st, 40, 760, 60)), 14, true)
	local heldOffsets = {}
	for _, p in held.Parts do
		heldOffsets[p] = held.Body.CFrame:ToObjectSpace(p.CFrame)
	end
	local holding = true
	table.insert(K.Followers, function()
		if not holding or not witch.Parent then
			return
		end
		local hand = witch:FindFirstChild("RightHandAtt", true) :: Attachment?
		if hand and held.Body.Parent then
			local cf = CFrame.new(hand.WorldPosition + Vector3.new(0, 6, 0))
			for part, off in heldOffsets do
				if part.Parent then
					part.CFrame = cf * off
				end
			end
		end
	end)
	local function head(): Vector3
		return K.HeadPosition(witch, H)
	end
	local targets = {}
	for _ = 1, 7 do
		table.insert(targets, at(st, rng():NextNumber(-300, 300), rng():NextNumber(-480, -140)))
	end

	-- 1. dall'alto del Muro: la Strega Bestia lontana, con una zucca in mano (sotto il titolo)
	K.Shot(look(at(st, 30, -14, 138), at(st, 40, 760, 110)), look(at(st, 28, -14, 137), at(st, 40, 760, 124)), 3.6, nil, nil, 34)
	after(1.4, function()
		K.Sound("Scherzetto", nil, 0.7, 0.6)
	end)
	-- 2. il lancio: le zucche volano sopra il Muro
	after(3.0, function()
		K.Animate(witch, "Throw")
	end)
	local first: Pumpkin? = nil
	after(3.9, function()
		holding = false
		hidePumpkin(held)
		local hand = witch:FindFirstChild("RightHandAtt", true) :: Attachment?
		local from = if hand then hand.WorldPosition + Vector3.new(0, 6, 0) else head()
		for i, target in targets do
			task.delay((i - 1) * 0.28, function()
				local p = pumpkinShot(from + Vector3.new(rng():NextNumber(-20, 20), rng():NextNumber(-10, 10), 0), target, rng():NextNumber(10, 16), 2.4, rng():NextNumber(260, 340), function()
					local f = fx()
					if f then
						f.Explosion(target + Vector3.new(0, 4, 0), 24, false)
						f.Shockwave(target + Vector3.new(0, 1, 0), 70, Color3.fromRGB(255, 150, 210), 0.7, 2)
					end
					if i == 4 then
						-- SCHERZETTO: fumo viola e una risata
						purpleSmoke(target + Vector3.new(0, 8, 0), 70)
						K.Sound("Scherzetto", nil, 1, 0.9)
					else
						candyBurst(target + Vector3.new(0, 8, 0), 60)
					end
					K.Sound("Explosion", nil, 0.7, 0.55)
					K.Shake(0.4, 0.5)
				end)
				if i == 1 then
					first = p
				end
			end)
		end
	end)
	-- la telecamera segue la prima zucca in volo
	after(4.0, function()
		K.ShotPath(function()
			local p = first
			if p and p.Body.Parent then
				local pos = p.Body.Position
				return look(pos + rel(st, 70, 90, 30), pos)
			end
			return look(at(st, 60, -60, 160), at(st, 0, -200, 40))
		end, 2.4, 0.5, 50)
	end)
	-- 3. in strada, mentre le zucche cadono e scoppiano in dolcetti
	after(6.4, function()
		K.Shot(look(at(st, -20, -320, 8), at(st, 0, -160, 70)), look(at(st, -14, -296, 9), at(st, 0, -160, 50)), 2.6)
	end)
	-- 4. la Strega Bestia ride
	after(9.0, function()
		K.ShotPath(function()
			local h = head()
			return look(h + rel(st, 30, -170, -20), h)
		end, 2.2, 0.6, 30)
		K.RoarAt(witch, H, Color3.fromRGB(255, 140, 210), 0.9)
		K.Sound("Scherzetto", nil, 1, 0.7)
	end)
	-- 5. pioggia di dolcetti sul distretto
	after(11.2, function()
		local rain = K.Part({ Name = "PioggiaDolcetti", Size = Vector3.new(500, 4, 360), CFrame = CFrame.new(at(st, 0, -320, 140)), Transparency = 1 })
		K.Emitter(rain, {
			Texture = "",
			Color = candySequence(),
			Size = NumberSequence.new(1.6),
			Lifetime = NumberRange.new(3, 4),
			Speed = NumberRange.new(20, 40),
			EmissionDirection = Enum.NormalId.Bottom,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-200, 200),
			LightEmission = 0.3,
			LightInfluence = 0.6,
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Rate = 260,
		})
		K.ShotPath(function(k)
			return look(at(st, 0, -420 + 80 * k, 10), at(st, 0, -150, 40))
		end, 2.4, 0.6, 62)
	end)
	-- 6. una zucca enorme cade proprio davanti a noi e scoppia
	after(13.4, function()
		local target = at(st, 0, -270)
		pumpkinShot(at(st, 0, -120, 260), target, 22, 0.8, 30, function()
			candyBurst(target + Vector3.new(0, 12, 0), 120)
			local f = fx()
			if f then
				f.Explosion(target + Vector3.new(0, 6, 0), 36, true)
				f.Flash(Color3.fromRGB(255, 170, 220), 0.6, 0.8)
			end
			K.Sound("Explosion", nil, 1, 0.45)
			K.Shake(0.9, 0.8)
		end)
	end)
end

-- 🌕 La Luna di Sangue: la luna rossa che sorge dietro il Muro, il Colosso che si alza davanti alla luna,
-- i pipistrelli che escono dalla luna verso di noi, l'urlo e le mani sul bordo del Muro
SHOWS.LunaSangue = function(after)
	local st = K.SetStage(Color3.fromRGB(70, 56, 60), Enum.Material.Cobblestone)
	local at, rel, look = K.At, K.Rel, K.Look
	K.District(st, -360, 360, -640, -80, function(x, _)
		return math.abs(x) < 30
	end)
	K.WallSegment(st, 0, 1400, 160, "Cancello")
	K.Hills(st, 10, Color3.fromRGB(60, 40, 44), 460)
	local moonParts = moonDisc(at(st, 0, 1800, 200), 900, Color3.fromRGB(220, 36, 40))
	local moonTop = at(st, 0, 1800, 900)
	for _, p in moonParts do
		local from = p.CFrame
		K.MoveAlong(p, function(k)
			return from:Lerp(CFrame.new(moonTop), Util.Ease(k, "SineOut"))
		end, 4.2)
	end
	local H = 230
	local spot = at(st, 0, 78)
	local face = st.ToCamera
	local colossus = K.Titan("Vulcano", H, spot - Vector3.new(0, 270, 0), face)
	local glow = K.GlowLight(colossus.PrimaryPart or colossus, BLOOD, 200, 0)
	K.NeckSteam(colossus, 0)
	local animator = K.AnimatorOf(colossus)
	local grip = if animator then ArmReach.WallGrip(animator, H, at(st, 0, 17, 165), -st.Fwd) else nil
	local function head(): Vector3
		return K.HeadPosition(colossus, H)
	end

	-- 1. dalla strada: la luna sorge rossa dietro il Muro (sotto il titolo)
	K.Shot(look(at(st, 8, -420, 8), at(st, 0, 0, 120)), look(at(st, 6, -360, 9), at(st, 0, 0, 150)), 3.8)
	after(1.6, function()
		K.Sound("Thunder", nil, 0.7, 0.2)
		local f = fx()
		if f then
			f.Flash(Color3.fromRGB(255, 80, 80), 0.18, 0.8)
		end
	end)
	-- 2. fulmini rossi e il Colosso che si alza davanti alla luna
	after(3.6, function()
		K.Strike(spot + Vector3.new(0, 30, 0), 14, BLOOD)
		K.Strike(spot + st.Right * 90, 7, BLOOD)
		K.Steam(spot + Vector3.new(0, 30, 0), 120, 16, 3, Color3.fromRGB(255, 200, 200))
		K.TweenTo(colossus, K.Standing(colossus, spot, face), 3.4, "SineInOut")
		TweenService:Create(glow, TweenInfo.new(2), { Brightness = 5 }):Play()
		K.NeckSteam(colossus, 8)
		K.Shake(0.3, 3.4)
		local base = at(st, -40, -470, 40)
		K.ShotPath(function(k)
			local h = head()
			local target = Vector3.new(h.X, math.max(h.Y - 30, spot.Y + 170), h.Z)
			return look(base + rel(st, 6 * k, -16 * k, 2 * k), target)
		end, 3.6, 0.9, 22)
	end)
	after(5.4, function()
		if grip then
			grip:Set(1, 1.1)
		end
	end)
	-- 3. i pipistrelli escono dalla luna e ci volano addosso
	after(7.2, function()
		bats(K.Part, moonTop, at(st, 0, -520, 60), 90, 3.4, 260, 3, K.Followers)
		K.Sound("Spettro", nil, 1, 0.6)
		K.Shot(look(at(st, 0, -390, 30), moonTop), look(at(st, 0, -400, 28), moonTop + Vector3.new(0, -40, 0)), 3, nil, 0.6, 46)
		K.Shake(0.4, 2.6)
	end)
	-- 4. la testa sopra il Muro, contro la luna rossa: l'urlo
	after(10.3, function()
		K.ShotPath(function(k)
			local h = head()
			return look(at(st, 60 - 12 * k, -110 + 20 * k, 168 + 6 * k), h - Vector3.new(0, 12, 0))
		end, 1.9, 0.5, 52)
	end)
	after(10.6, function()
		K.RoarAt(colossus, H, BLOOD, 0.16)
		K.NeckSteam(colossus, 18)
		K.Steam(K.NeckPosition(colossus, H), 80, 12, 4, Color3.fromRGB(255, 210, 210))
	end)
	-- 5. dall'alto: la luna, il Colosso aggrappato al Muro e i pipistrelli che girano
	after(12.4, function()
		K.Shot(look(at(st, 200, -380, 220), at(st, 0, 60, 120)), look(at(st, 260, -470, 300), at(st, 0, 60, 140)), 3, "QuadOut")
		bats(K.Part, at(st, -500, 300, 260), at(st, 500, 100, 220), 50, 3.2, 120, 3, K.Followers)
	end)
	after(14.2, function()
		K.NeckSteam(colossus, 8)
		if grip then
			grip:Set(0, 0.8)
		end
	end)
end

-- PARTICELLE ATTORNO AL GIOCATORE DURANTE L'EVENTO ------------------------------------------------------

local function ambientKinds(T): { [string]: { any } }
	return {
		Zucche = {
			{ Texture = "", Color = ColorSequence.new(Color3.fromRGB(236, 118, 28), Color3.fromRGB(176, 50, 30)), Size = NumberSequence.new(0.5), Squash = NumberSequence.new(-0.3), Transparency = NumberSequence.new(0.1), Lifetime = NumberRange.new(6, 9), Speed = NumberRange.new(3, 6), Rate = 45, EmissionDirection = Enum.NormalId.Bottom, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-180, 180), LightInfluence = 1, Acceleration = Vector3.new(3, -2, 1) },
			{ Texture = T.Sparkle, Color = ColorSequence.new(Color3.fromRGB(255, 190, 80), Color3.fromRGB(255, 110, 40)), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }), Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(2, 6), Rate = 26, EmissionDirection = Enum.NormalId.Top, LightEmission = 1, Acceleration = Vector3.new(1, 2, 0) },
		},
		Nebbia = {
			{ Texture = T.Smoke, Color = ColorSequence.new(Color3.fromRGB(206, 222, 240)), Size = NumberSequence.new(10, 22), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.82), NumberSequenceKeypoint.new(1, 1) }), Lifetime = NumberRange.new(8, 12), Speed = NumberRange.new(1, 3), Rate = 14, LightInfluence = 1 },
			{ Texture = T.Sparkle, Color = ColorSequence.new(GHOST_BLUE), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.4), NumberSequenceKeypoint.new(1, 0) }), Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(0.5, 2), Rate = 16, LightEmission = 1, SpreadAngle = Vector2.new(180, 180) },
		},
		Cimitero = {
			{ Texture = T.Smoke, Color = ColorSequence.new(Color3.fromRGB(150, 220, 140), Color3.fromRGB(90, 140, 90)), Size = NumberSequence.new(6, 14), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.84), NumberSequenceKeypoint.new(1, 1) }), Lifetime = NumberRange.new(7, 10), Speed = NumberRange.new(1, 3), Rate = 12, LightInfluence = 1 },
			{ Texture = T.Sparkle, Color = ColorSequence.new(WITCH_GREEN), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }), Lifetime = NumberRange.new(2, 4), Speed = NumberRange.new(2, 6), Rate = 24, EmissionDirection = Enum.NormalId.Top, LightEmission = 1 },
		},
		Dolcetti = {
			{ Texture = "", Color = candySequence(), Size = NumberSequence.new(0.35), Transparency = NumberSequence.new(0.05), Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(3, 6), Rate = 40, EmissionDirection = Enum.NormalId.Bottom, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-240, 240), LightInfluence = 0.8, LightEmission = 0.2 },
			{ Texture = T.Sparkle, Color = ColorSequence.new(Color3.fromRGB(255, 180, 230)), Size = NumberSequence.new(0.25), Transparency = NumberSequence.new(0.2), Lifetime = NumberRange.new(3, 6), Speed = NumberRange.new(2, 5), Rate = 30, LightEmission = 0.8, SpreadAngle = Vector2.new(180, 180) },
		},
		Luna = {
			{ Texture = T.Smoke, Color = ColorSequence.new(Color3.fromRGB(120, 40, 44), Color3.fromRGB(60, 20, 26)), Size = NumberSequence.new(0.5, 0.8), Transparency = NumberSequence.new(0.25), Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(4, 8), Rate = 50, EmissionDirection = Enum.NormalId.Bottom, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90), LightInfluence = 0.8 },
			{ Texture = T.Sparkle, Color = ColorSequence.new(Color3.fromRGB(255, 90, 80), Color3.fromRGB(200, 20, 30)), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }), Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(3, 7), Rate = 30, EmissionDirection = Enum.NormalId.Top, LightEmission = 1 },
		},
	}
end

-- EFFETTI NEL MONDO (piccoli eventi nel cielo ed effetti mandati dal server) ---------------------------------

local function worldPumpkin(pos: Vector3, size: number, lit: boolean): Pumpkin
	return pumpkin(function(props)
		return worldPart(props, 8)
	end, CFrame.new(pos) * CFrame.Angles(0, rng():NextNumber(0, math.pi * 2), 0), size, lit)
end

-- una zucca che cade dal cielo con la scia e tocca terra in "time" secondi
local function fallingPumpkin(ground: Vector3, size: number, time: number, landed: (() -> ())?)
	local from = ground + Vector3.new(rng():NextNumber(-60, 60), 260, rng():NextNumber(-60, 60))
	local p = worldPumpkin(from, size, true)
	local offsets = {}
	for _, part in p.Parts do
		offsets[part] = p.Body.CFrame:ToObjectSpace(part.CFrame)
	end
	local trail = Instance.new("ParticleEmitter")
	trail.Texture = K.Textures.Sparks
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 80, 160))
	trail.LightEmission = 1
	trail.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.25), NumberSequenceKeypoint.new(1, 0) })
	trail.Lifetime = NumberRange.new(0.4, 0.8)
	trail.Speed = NumberRange.new(2, 6)
	trail.Rate = 60
	trail.Parent = p.Body
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - start) / time, 0, 1)
		local cf = CFrame.new(from:Lerp(ground + Vector3.new(0, 0, 0), k * k)) * CFrame.Angles(k * 6, k * 3, 0)
		for part, off in offsets do
			if part.Parent then
				part.CFrame = cf * off
			end
		end
		if k >= 1 then
			conn:Disconnect()
			for _, part in p.Parts do
				part:Destroy()
			end
			if landed then
				landed()
			end
		end
	end)
end

local AMBIENT_EVENTS: { [string]: { Every: { number }, Run: () -> () } } = {
	NotteZucche = {
		Every = { 7, 12 },
		Run = function()
			local p = K.FarPoint(300, 700, true)
			local f = fx()
			if f then
				f.Explosion(p + Vector3.new(0, 8, 0), 30, false)
				f.Sparks(p + Vector3.new(0, 10, 0), PUMPKIN, 30, 60)
			end
			candyBurst(p + Vector3.new(0, 10, 0), 40)
			if rng():NextNumber() < 0.4 then
				K.Sound("Scherzetto", nil, 0.4, 0.5)
			end
		end,
	},
	GiganteFantasma = {
		Every = { 8, 14 },
		Run = function()
			local p = K.FarPoint(300, 700, true)
			local f = fx()
			if f then
				f.Shockwave(p + Vector3.new(0, 30, 0), 300, GHOST_BLUE, 2, 2)
				f.Flash(GHOST_BLUE, 0.08, 0.8)
			end
			K.Sound("Spettro", nil, 0.6, 0.3)
		end,
	},
	RisveglioCaduti = {
		Every = { 5, 9 },
		Run = function()
			greenStrike(K.FarPoint(200, 700), rng():NextNumber(4, 8))
		end,
	},
	DolcettoScherzetto = {
		Every = { 4, 8 },
		Run = function()
			local ground = K.FarPoint(150, 450, true)
			fallingPumpkin(ground, rng():NextNumber(8, 14), 1.6, function()
				candyBurst(ground + Vector3.new(0, 6, 0), 50)
				K.Sound("Explosion", ground, 0.5, 0.6, 900)
			end)
		end,
	},
	LunaSangue = {
		Every = { 6, 11 },
		Run = function()
			local cam = workspace.CurrentCamera.CFrame
			local side = cam.RightVector * (if rng():NextNumber() < 0.5 then -1 else 1)
			local from = cam.Position + cam.LookVector * 160 - side * 200 + Vector3.new(0, 70, 0)
			local to = cam.Position + cam.LookVector * 120 + side * 220 + Vector3.new(0, 50, 0)
			bats(function(props)
				return worldPart(props, 8)
			end, from, to, 26, 4, 40, 1.6, nil)
			local f = fx()
			if f and rng():NextNumber() < 0.5 then
				f.Flash(Color3.fromRGB(255, 60, 60), 0.1, 0.6)
			end
		end,
	},
}

-- gli effetti che il server manda durante gli eventi di Halloween; true se l'effetto è di Halloween
function HalloweenShows.ServerEffect(name: string, p: any): boolean
	if not K then
		return false
	end
	local pos = if typeof(p.Position) == "Vector3" then p.Position else nil
	if name == "AbusePumpkinBurst" then
		if pos then
			local big = worldPumpkin(pos, 16, true)
			local f = fx()
			if f then
				f.HighlightModel(big.Body, PUMPKIN, 0.8, 0.3)
			end
			K.Sound("Scherzetto", pos, 0.6, 0.5, 600)
			task.delay(0.8, function()
				hidePumpkin(big)
				local f2 = fx()
				if f2 then
					f2.Explosion(pos + Vector3.new(0, 6, 0), 40, true)
					f2.DebrisBurst(pos, 20, 4, PUMPKIN, Enum.Material.SmoothPlastic, 120)
				end
				candyBurst(pos + Vector3.new(0, 8, 0), 60)
				K.Shake(0.4, 0.5)
			end)
		end
	elseif name == "AbuseGhost" then
		if pos then
			local f = fx()
			if f then
				f.Shockwave(pos + Vector3.new(0, 4, 0), 120, GHOST_BLUE, 1, 3)
				f.Flash(GHOST_BLUE, 0.12, 0.6)
			end
			K.Steam(pos + Vector3.new(0, 10, 0), 70, 14, 3, Color3.fromRGB(214, 232, 255))
			K.Sound("Spettro", pos, 1, 0.3, 900)
		end
	elseif name == "AbuseRise" then
		if pos then
			greenStrike(pos, 10)
			local f = fx()
			if f then
				f.DebrisBurst(pos, 30, 5, Color3.fromRGB(70, 56, 42), Enum.Material.Ground, 160)
			end
			K.Steam(pos + Vector3.new(0, 6, 0), 90, 18, 4, Color3.fromRGB(150, 230, 140))
		end
	elseif name == "AbuseCandyDrop" then
		if pos then
			fallingPumpkin(pos, 4.4, 1.3, function()
				local f = fx()
				if f then
					f.Shockwave(pos + Vector3.new(0, 1, 0), 30, Color3.fromRGB(255, 160, 220), 0.6, 1)
					f.GroundDust(pos, 10)
				end
			end)
		end
	elseif name == "AbuseTrick" then
		if pos then
			purpleSmoke(pos + Vector3.new(0, 4, 0), 50)
			local f = fx()
			if f then
				f.Flash(Color3.fromRGB(170, 90, 255), 0.35, 0.7)
				f.Explosion(pos + Vector3.new(0, 3, 0), 16, false)
			end
			K.Sound("Scherzetto", pos, 1, 0.8, 300)
			K.Shake(0.6, 0.6)
		end
	elseif name == "AbuseCandy" then
		if pos then
			candyBurst(pos + Vector3.new(0, 3, 0), 28)
			K.Sound("Coins", pos, 0.8, 1.2, 300)
		end
	elseif name == "AbuseBats" then
		local cam = workspace.CurrentCamera.CFrame
		local center = pos or cam.Position
		local side = cam.RightVector * (if rng():NextNumber() < 0.5 then -1 else 1)
		bats(function(props)
			return worldPart(props, 7)
		end, center - side * 160 + Vector3.new(0, 40, 0) + cam.LookVector * 60, center + side * 180 + Vector3.new(0, 25, 0) + cam.LookVector * 30, 34, 3.6, 30, 1.4, nil)
		K.Sound("Spettro", nil, 0.5, 0.7)
	else
		return false
	end
	return true
end

-- Collega le scene e gli effetti di Halloween ad AbuseEventController
function HalloweenShows.Register(kit)
	K = kit
	for id, show in SHOWS do
		kit.Shows[id] = show
	end
	for kind, list in ambientKinds(kit.Textures) do
		kit.Ambient[kind] = list
	end
	for id, ev in AMBIENT_EVENTS do
		kit.AmbientEvents[id] = ev
	end
end

-- per le prove
HalloweenShows.Shows = SHOWS

return HalloweenShows
