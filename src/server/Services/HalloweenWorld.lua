--[[
	HalloweenWorld - il mondo "infestato" del file di Halloween (attributo Tema = "Halloween")
	Lo usa WorldBuilder mentre costruisce la mappa. Non è un servizio: non ha Init/Start.
	  • RIDIPINGE tutto alla fine: intonaci polverosi, tetti neri e viola, legno scuro, foglie
	    d'autunno (arancioni, rosse, oro), bandiere e tendoni arancio-nero-viola, merce del mercato
	    che diventa zucche e dolcetti, bombole del gas arancioni, fuochi verdi delle streghe;
	  • AGGIUNGE decorazioni solo grafiche: zucche intagliate con la candela davanti alle porte e ai
	    lampioni, zucche giganti alle porte delle mura, ragnatele, candele alle finestre, scope,
	    cimiteri con lapidi e croci fuori dalle città, orti di zucche, spaventapasseri, calderoni
	    che ribollono, alberi morti con i fantasmi di lenzuolo e le lanterne nella foresta.
	Le decorazioni non si toccano e non fermano rampini né colpi (niente collisioni né query) e
	hanno un generatore casuale tutto loro: la mappa di gioco resta identica al millimetro
	(lo controlla tools/check_layout.py --halloween).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Tema = require(Shared.Data.Tema)
local Zones = require(Shared.Data.Zones)

local HalloweenWorld = {}

local H = Tema.Colors
local rng = Random.new(Config.WorldSeed + 31013)
local folder: Model? = nil
local created = 0

type Context = {
	Map: Instance,
	G: number,
	OpenLand: (Vector3, number) -> boolean,
	GroundAt: (Vector3) -> Vector3,
}
local ctx: Context? = nil

function HalloweenWorld.Active(): boolean
	return Tema.IsHalloween()
end

-- MATTONI ----------------------------------------------------------------------------------------------

local function pause()
	created += 1
	if created % 400 == 0 and RunService:IsRunning() then
		task.wait()
	end
end

local function hpart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "Parent" and k ~= "Shape" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent or folder
	pause()
	return p
end

local function hwedge(props: { [string]: any }): WedgePart
	local p = Instance.new("WedgePart")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent or folder
	pause()
	return p
end

local function ellipsoid(props: { [string]: any }): Part
	local p = hpart(props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- luce che si accende al tramonto (AmbienceController: etichetta Lamp) su una parte invisibile
local function light(at: CFrame, color: Color3, range: number, brightness: number, flicker: boolean?): Part
	local holder = hpart({ Name = "Luce", Size = Vector3.one * 0.3, CFrame = at, Transparency = 1 })
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Enabled = false
	l.Parent = holder
	CollectionService:AddTag(holder, Config.Tags.Lamp)
	if flicker then
		holder:SetAttribute("Tremola", true)
	end
	return holder
end

-- lanterna che di giorno è vetro e di notte si accende (come le lanterne a muro delle case)
local function lanternLight(lantern: BasePart, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = lantern.Color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Enabled = false
	l.Parent = lantern
	lantern.Material = Enum.Material.Glass
	lantern:SetAttribute("Tremola", true)
	CollectionService:AddTag(lantern, Config.Tags.Lamp)
end

-- cilindro/trave da a a b (anche quasi verticale)
local function along(a: Vector3, b: Vector3): CFrame
	local dir = b - a
	local up = if dir.Magnitude > 0 and math.abs(dir.Unit.Y) > 0.98 then Vector3.xAxis else Vector3.yAxis
	return CFrame.lookAt((a + b) / 2, b, up)
end

local function pickOf<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local function tint(c: Color3, f: number): Color3
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end

-- triangolo (due cunei) sul piano della faccia, punta in alto. cf = centro, guarda verso -Z
local function triangle(cf: CFrame, w: number, h: number, color: Color3, material: Enum.Material): { BasePart }
	local parts: { BasePart } = {}
	for _, side in { -1, 1 } do
		table.insert(parts, hwedge({ Name = "Intaglio", Size = Vector3.new(0.08, h, w / 2), CFrame = cf * CFrame.new(side * w / 4, 0, 0) * CFrame.Angles(0, side * math.rad(-90), 0), Color = color, Material = material }))
	end
	return parts
end

-- DECORAZIONI -------------------------------------------------------------------------------------------

local PUMPKIN = { H.Pumpkin, Color3.fromRGB(226, 104, 22), Color3.fromRGB(244, 136, 40), Color3.fromRGB(214, 96, 30) }

-- Zucca: cf a terra (base della zucca), il davanti guarda verso -Z.
-- carved = faccia intagliata; lit = candela dentro: di notte la faccia si illumina (HalloweenController,
-- etichetta Tema.Tags.Carved) e si accende la luce
local CARVED_DARK = Color3.fromRGB(46, 22, 10)
local function pumpkin(cf: CFrame, size: number, carved: boolean, lit: boolean?)
	local color = pickOf(PUMPKIN)
	local h = size * 0.78
	local center = cf * CFrame.new(0, h / 2, 0)
	local body = ellipsoid({ Name = "Zucca", Size = Vector3.new(size, h, size * 0.94), CFrame = center, Color = color, Material = Enum.Material.SmoothPlastic, CastShadow = size > 3 })
	-- spicchi: un ellissoide più stretto, girato, un filo più scuro
	ellipsoid({ Name = "Spicchio", Size = Vector3.new(size * 0.62, h * 1.02, size * 1.0), CFrame = center * CFrame.Angles(0, math.rad(45), 0), Color = tint(color, 0.88), Material = Enum.Material.SmoothPlastic })
	hpart({ Name = "Gambo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(size * 0.24, size * 0.13, size * 0.13), CFrame = center * CFrame.new(0, h * 0.5 + size * 0.08, 0) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, math.rad(90) + rng:NextNumber(-0.25, 0.25)), Color = H.Stem, Material = Enum.Material.Wood })
	if not carved then
		return body
	end
	-- l'intaglio sta sulla buccia: z della superficie dell'ellissoide in (x, y)
	local function surface(x: number, y: number): number
		local k = 1 - (x / (size * 0.5)) ^ 2 - (y / (h * 0.5)) ^ 2
		return -size * 0.47 * math.sqrt(math.max(0.05, k)) - 0.02
	end
	local carvedParts = {}
	local function carve(p: BasePart)
		table.insert(carvedParts, p)
	end
	for _, sx in { -1, 1 } do
		local x, y = sx * size * 0.2, h * 0.12
		for _, w in triangle(center * CFrame.new(x, y, surface(x, y)), size * 0.22, h * 0.22, CARVED_DARK, Enum.Material.SmoothPlastic) do
			carve(w)
		end
	end
	for _, w in triangle(center * CFrame.new(0, -h * 0.02, surface(0, 0)), size * 0.12, h * 0.12, CARVED_DARK, Enum.Material.SmoothPlastic) do
		carve(w)
	end
	-- bocca a zig-zag: una fascia e due angoli all'insù
	carve(hpart({ Name = "Intaglio", Size = Vector3.new(size * 0.3, h * 0.09, 0.08), CFrame = center * CFrame.new(0, -h * 0.2, surface(0, -h * 0.2)), Color = CARVED_DARK }))
	for _, sx in { -1, 1 } do
		local x, y = sx * size * 0.21, -h * 0.15
		carve(hpart({ Name = "Intaglio", Size = Vector3.new(size * 0.13, h * 0.08, 0.08), CFrame = center * CFrame.new(x, y, surface(x, y)) * CFrame.Angles(0, sx * math.rad(-25), sx * math.rad(28)), Color = CARVED_DARK }))
	end
	if lit then
		for _, p in carvedParts do
			CollectionService:AddTag(p, Tema.Tags.Carved)
		end
		light(center, Color3.fromRGB(255, 150, 56), math.clamp(size * 3.2, 9, 30), 1.4, true)
	end
	return body
end

-- Ragnatela in un angolo: raggi e due giri di fili (piano XY, cf nell'angolo, i fili vanno verso -X e -Y)
local function cobweb(cf: CFrame, size: number)
	local color = Color3.fromRGB(232, 232, 238)
	local angles = { 4, 32, 60, 86 }
	local function radial(a: number, r: number): Vector3
		local rad = math.rad(a)
		return Vector3.new(-math.cos(rad) * r, -math.sin(rad) * r, 0)
	end
	for _, a in angles do
		local tip = radial(a, size)
		hpart({ Name = "Ragnatela", Size = Vector3.new(0.06, 0.06, size), CFrame = cf * CFrame.lookAt(tip / 2, tip), Color = color, Transparency = 0.35 })
	end
	for _, k in { 0.45, 0.85 } do
		for i = 1, #angles - 1 do
			local a, b = radial(angles[i], size * k), radial(angles[i + 1], size * k)
			local mid = (a + b) / 2 + Vector3.new(0.18 * k, 0.18 * k, 0) -- il filo cede un po'
			hpart({ Name = "Ragnatela", Size = Vector3.new(0.05, 0.05, (b - a).Magnitude), CFrame = cf * CFrame.lookAt(mid, mid + (b - a)), Color = color, Transparency = 0.4 })
		end
	end
end

-- Candela accesa (sul davanzale o davanti a una lapide). cf alla base
local function candle(cf: CFrame, h: number?)
	local ch = h or 1
	hpart({ Name = "Candela", Shape = Enum.PartType.Cylinder, Size = Vector3.new(ch, 0.36, 0.36), CFrame = cf * CFrame.new(0, ch / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(240, 232, 214), Material = Enum.Material.SmoothPlastic })
	hpart({ Name = "Fiammella", Shape = Enum.PartType.Ball, Size = Vector3.new(0.26, 0.4, 0.26), CFrame = cf * CFrame.new(0, ch + 0.2, 0), Color = H.Candle, Material = Enum.Material.Neon })
end

-- Scopa della strega appoggiata al muro. cf a terra, il muro è verso +Z
local function broom(cf: CFrame)
	local stick = cf * CFrame.new(0, 3.1, 0.25) * CFrame.Angles(math.rad(-14), 0, 0)
	hpart({ Name = "Scopa", Size = Vector3.new(0.22, 6.2, 0.22), CFrame = stick, Color = Color3.fromRGB(86, 60, 36), Material = Enum.Material.Wood })
	hwedge({ Name = "Saggina", Size = Vector3.new(1.1, 1.6, 0.6), CFrame = stick * CFrame.new(0, -3.4, 0) * CFrame.Angles(math.pi, 0, 0), Color = Color3.fromRGB(196, 160, 84), Material = Enum.Material.Fabric })
	hpart({ Name = "Legaccio", Size = Vector3.new(0.7, 0.18, 0.4), CFrame = stick * CFrame.new(0, -2.55, 0), Color = H.Witch, Material = Enum.Material.Fabric })
end

-- Lapide: tre tipi (arrotondata, croce, squadrata). cf a terra, la scritta guarda verso -Z
local GRAVE_STONE = { Color3.fromRGB(118, 116, 124), Color3.fromRGB(104, 104, 110), Color3.fromRGB(132, 128, 132), Color3.fromRGB(96, 98, 92) }
local function grave(cf: CFrame, s: number)
	local stone = pickOf(GRAVE_STONE)
	local lean = cf * CFrame.Angles(rng:NextNumber(-0.12, 0.08), 0, rng:NextNumber(-0.1, 0.1))
	local kind = rng:NextInteger(1, 3)
	if kind == 1 then
		hpart({ Name = "Lapide", Size = Vector3.new(2.4 * s, 2.6 * s, 0.6 * s), CFrame = lean * CFrame.new(0, 1.3 * s, 0), Color = stone, Material = Enum.Material.Slate, CastShadow = true })
		hpart({ Name = "Lapide", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6 * s, 2.4 * s, 2.4 * s), CFrame = lean * CFrame.new(0, 2.6 * s, 0) * CFrame.Angles(0, math.rad(90), 0), Color = stone, Material = Enum.Material.Slate })
		hpart({ Name = "Epitaffio", Size = Vector3.new(1.4 * s, 0.16 * s, 0.05), CFrame = lean * CFrame.new(0, 2.2 * s, -0.31 * s), Color = tint(stone, 0.6) })
		hpart({ Name = "Epitaffio", Size = Vector3.new(1.0 * s, 0.14 * s, 0.05), CFrame = lean * CFrame.new(0, 1.8 * s, -0.31 * s), Color = tint(stone, 0.6) })
	elseif kind == 2 then
		hpart({ Name = "Croce", Size = Vector3.new(0.5 * s, 3.6 * s, 0.5 * s), CFrame = lean * CFrame.new(0, 1.8 * s, 0), Color = stone, Material = Enum.Material.Slate, CastShadow = true })
		hpart({ Name = "Croce", Size = Vector3.new(2.0 * s, 0.5 * s, 0.5 * s), CFrame = lean * CFrame.new(0, 2.7 * s, 0), Color = stone, Material = Enum.Material.Slate })
	else
		hpart({ Name = "Lapide", Size = Vector3.new(2.8 * s, 2.0 * s, 0.8 * s), CFrame = lean * CFrame.new(0, 1.0 * s, 0), Color = stone, Material = Enum.Material.Slate, CastShadow = true })
		hpart({ Name = "Lapide", Size = Vector3.new(3.2 * s, 0.4 * s, 1.1 * s), CFrame = lean * CFrame.new(0, 2.1 * s, 0), Color = tint(stone, 0.9), Material = Enum.Material.Slate })
	end
	-- tumulo di terra davanti e, a volte, una candela o una zucca
	ellipsoid({ Name = "Tumulo", Size = Vector3.new(2.6 * s, 0.9 * s, 4.6 * s), CFrame = cf * CFrame.new(0, 0.05, -2.6 * s), Color = Color3.fromRGB(70, 56, 44), Material = Enum.Material.Ground })
	local extra = rng:NextNumber()
	if extra < 0.22 then
		candle(cf * CFrame.new(rng:NextNumber(-0.8, 0.8) * s, 0, -0.9 * s), 0.9)
	elseif extra < 0.36 then
		pumpkin(cf * CFrame.new(1.2 * s, 0, -1.2 * s) * CFrame.Angles(0, rng:NextNumber(-0.6, 0.6), 0), 1.6 * s, true, false)
	end
end

-- Fantasma di lenzuolo: testa tonda, corpo, orlo ondulato, occhi e bocca. cf al centro della testa
local function sheetGhost(cf: CFrame, s: number)
	local white = Color3.fromRGB(240, 242, 248)
	hpart({ Name = "Fantasma", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4 * s, CFrame = cf, Color = white, Transparency = 0.12 })
	hpart({ Name = "Fantasma", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6 * s, 2.4 * s, 2.4 * s), CFrame = cf * CFrame.new(0, -1.3 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = white, Transparency = 0.12 })
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		hpart({ Name = "Orlo", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9 * s, CFrame = cf * CFrame.new(math.cos(a) * 0.85 * s, -2.6 * s, math.sin(a) * 0.85 * s), Color = white, Transparency = 0.12 })
	end
	for _, sx in { -1, 1 } do
		ellipsoid({ Name = "Occhio", Size = Vector3.new(0.42 * s, 0.62 * s, 0.2 * s), CFrame = cf * CFrame.new(sx * 0.42 * s, 0.15 * s, -1.12 * s), Color = Color3.fromRGB(20, 18, 26) })
	end
	ellipsoid({ Name = "Bocca", Size = Vector3.new(0.5 * s, 0.6 * s, 0.2 * s), CFrame = cf * CFrame.new(0, -0.55 * s, -1.08 * s), Color = Color3.fromRGB(20, 18, 26) })
end

-- Spaventapasseri con la testa di zucca. cf a terra, guarda verso -Z
local function scarecrow(cf: CFrame)
	local wood = Color3.fromRGB(78, 56, 38)
	hpart({ Name = "Palo", Size = Vector3.new(0.5, 8.5, 0.5), CFrame = cf * CFrame.new(0, 4.25, 0), Color = wood, Material = Enum.Material.Wood, CastShadow = true })
	hpart({ Name = "Traversa", Size = Vector3.new(6.4, 0.45, 0.45), CFrame = cf * CFrame.new(0, 6.3, 0), Color = wood, Material = Enum.Material.Wood })
	local shirt = pickOf({ Color3.fromRGB(110, 60, 120), Color3.fromRGB(150, 70, 36), Color3.fromRGB(70, 90, 60), Color3.fromRGB(120, 40, 40) })
	hpart({ Name = "Camicia", Size = Vector3.new(2.4, 2.8, 1.2), CFrame = cf * CFrame.new(0, 5.4, 0), Color = shirt, Material = Enum.Material.Fabric, CastShadow = true })
	for _, sx in { -1, 1 } do
		hpart({ Name = "Manica", Size = Vector3.new(2.2, 0.9, 0.9), CFrame = cf * CFrame.new(sx * 2.2, 6.25, 0), Color = tint(shirt, 0.9), Material = Enum.Material.Fabric })
		hwedge({ Name = "Paglia", Size = Vector3.new(0.6, 0.7, 0.5), CFrame = cf * CFrame.new(sx * 3.45, 6.05, 0) * CFrame.Angles(0, sx * math.rad(90), 0), Color = Color3.fromRGB(214, 178, 90), Material = Enum.Material.Fabric })
	end
	pumpkin(cf * CFrame.new(0, 6.9, 0), 2.1, true, false)
	-- cappello a punta
	hpart({ Name = "Tesa", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.18, 3, 3), CFrame = cf * CFrame.new(0, 8.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(40, 32, 30), Material = Enum.Material.Fabric })
	hpart({ Name = "Cappello", Size = Vector3.new(1.3, 1.5, 1.3), CFrame = cf * CFrame.new(0, 9.4, 0) * CFrame.Angles(0.15, 0, 0.1), Color = Color3.fromRGB(46, 36, 34), Material = Enum.Material.Fabric })
end

-- Calderone della strega con la pozione verde che ribolle. cf a terra
local function cauldron(cf: CFrame, s: number)
	local iron = Color3.fromRGB(34, 32, 36)
	local pot = ellipsoid({ Name = "Calderone", Size = Vector3.new(4.2 * s, 3.4 * s, 4.2 * s), CFrame = cf * CFrame.new(0, 1.9 * s, 0), Color = iron, Material = Enum.Material.Metal, CastShadow = true })
	hpart({ Name = "Bordo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4 * s, 3.8 * s, 3.8 * s), CFrame = cf * CFrame.new(0, 3.35 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = iron, Material = Enum.Material.Metal })
	local brew = hpart({ Name = "Pozione", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2 * s, 3.3 * s, 3.3 * s), CFrame = cf * CFrame.new(0, 3.42 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = H.Slime, Material = Enum.Material.Neon })
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		hpart({ Name = "Zampa", Size = Vector3.new(0.4 * s, 1.0 * s, 0.4 * s), CFrame = cf * CFrame.new(math.cos(a) * 1.5 * s, 0.4 * s, math.sin(a) * 1.5 * s), Color = iron, Material = Enum.Material.Metal })
	end
	-- legna e brace sotto
	for i = 0, 1 do
		hpart({ Name = "Legna", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3 * s, 0.45 * s, 0.45 * s), CFrame = cf * CFrame.new(0, 0.25 * s, 0) * CFrame.Angles(0, i * math.pi / 2, 0), Color = Color3.fromRGB(56, 38, 26), Material = Enum.Material.Wood })
	end
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Name = "Bolle"
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Color = ColorSequence.new(Color3.fromRGB(160, 255, 110), Color3.fromRGB(60, 200, 80))
	bubbles.LightEmission = 0.8
	bubbles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3 * s), NumberSequenceKeypoint.new(1, 0) })
	bubbles.Lifetime = NumberRange.new(0.8, 1.6)
	bubbles.Speed = NumberRange.new(1, 3)
	bubbles.SpreadAngle = Vector2.new(25, 25)
	bubbles.EmissionDirection = Enum.NormalId.Right -- il cilindro è girato: +X locale = in alto
	bubbles.Rate = 6
	bubbles.Parent = brew
	local fumes = Instance.new("ParticleEmitter")
	fumes.Name = "Vapori"
	fumes.Texture = "rbxasset://textures/particles/smoke_main.dds"
	fumes.Color = ColorSequence.new(Color3.fromRGB(150, 230, 120), Color3.fromRGB(110, 70, 160))
	fumes.LightEmission = 0.3
	fumes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
	fumes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 * s), NumberSequenceKeypoint.new(1, 4 * s) })
	fumes.Lifetime = NumberRange.new(2, 3.5)
	fumes.Speed = NumberRange.new(1.5, 3)
	fumes.EmissionDirection = Enum.NormalId.Right
	fumes.Rate = 3
	fumes.Parent = brew
	light(cf * CFrame.new(0, 4 * s, 0), Color3.fromRGB(140, 255, 110), 18 * s, 1.3, true)
	return pot
end

-- Albero morto contorto (rami spogli neri), a volte con un fantasma o una lanterna appesi. cf a terra
local function deadTree(base: Vector3, s: number)
	local bark = Color3.fromRGB(44, 38, 40)
	local h = rng:NextNumber(15, 22) * s
	local lean = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * 1.4 * s
	local top = base + Vector3.new(0, h, 0) + lean
	local function stick(a: Vector3, b: Vector3, d: number)
		hpart({ Name = "AlberoMorto", Size = Vector3.new(d, d, (b - a).Magnitude), CFrame = along(a, b), Color = bark, Material = Enum.Material.Wood, CastShadow = true })
	end
	stick(base - Vector3.new(0, 1, 0), top, 1.5 * s)
	local hangFrom: Vector3? = nil
	for i = 1, 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		local from = base:Lerp(top, rng:NextNumber(0.45, 0.95))
		local to = from + Vector3.new(math.cos(a) * 6 * s, rng:NextNumber(1, 4) * s, math.sin(a) * 6 * s)
		stick(from, to, 0.55 * s)
		-- rametti
		local twig = to + Vector3.new(math.cos(a + 0.8) * 2.4 * s, 1.6 * s, math.sin(a + 0.8) * 2.4 * s)
		stick(to, twig, 0.3 * s)
		if i == 1 then
			hangFrom = to
		end
	end
	if hangFrom then
		local roll = rng:NextNumber()
		local rope = 3.2 * s
		if roll < 0.4 then
			hpart({ Name = "Corda", Size = Vector3.new(0.08, rope, 0.08), CFrame = CFrame.new(hangFrom - Vector3.new(0, rope / 2, 0)), Color = Color3.fromRGB(150, 130, 100), Material = Enum.Material.Fabric })
			sheetGhost(CFrame.new(hangFrom - Vector3.new(0, rope + 1.2 * s, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), 0.8 * s)
		elseif roll < 0.7 then
			hpart({ Name = "Corda", Size = Vector3.new(0.08, rope * 0.6, 0.08), CFrame = CFrame.new(hangFrom - Vector3.new(0, rope * 0.3, 0)), Color = Color3.fromRGB(60, 56, 54), Material = Enum.Material.Metal })
			local lantern = hpart({ Name = "Lanterna", Size = Vector3.new(0.9, 1.3, 0.9), CFrame = CFrame.new(hangFrom - Vector3.new(0, rope * 0.6 + 0.7, 0)), Color = Color3.fromRGB(150, 255, 120) })
			lanternLight(lantern, 16, 1.2)
		end
	end
end

-- Cimitero: lapidi in file, cancellata di ferro, un albero morto e a volte un calderone. center a terra
local function graveyard(center: Vector3, facing: Vector3, rows: number, cols: number)
	local fwd = if facing.Magnitude > 0.01 then facing.Unit else Vector3.new(0, 0, -1)
	local right = Vector3.new(-fwd.Z, 0, fwd.X)
	local gap = 7
	local w, d = cols * gap + 6, rows * gap + 6
	local g = (ctx :: Context).GroundAt
	for r = 1, rows do
		for c = 1, cols do
			if rng:NextNumber() < 0.85 then
				local p = center + right * ((c - (cols + 1) / 2) * gap + rng:NextNumber(-1, 1)) + fwd * ((r - (rows + 1) / 2) * gap + rng:NextNumber(-1, 1))
				local ground = g(p)
				grave(CFrame.lookAt(ground, ground - fwd), rng:NextNumber(0.85, 1.2))
			end
		end
	end
	-- cancellata: paletti di ferro con le punte
	local iron = Color3.fromRGB(30, 28, 32)
	local corners = {
		center - right * w / 2 - fwd * d / 2,
		center + right * w / 2 - fwd * d / 2,
		center + right * w / 2 + fwd * d / 2,
		center - right * w / 2 + fwd * d / 2,
	}
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		local len = (b - a).Magnitude
		local posts = math.max(2, math.floor(len / 3))
		local entrance = i == 1 -- l'ingresso è sul lato davanti
		for k = 0, posts do
			local t = k / posts
			if not (entrance and math.abs(t - 0.5) < 0.12) then
				local p = g(a:Lerp(b, t))
				hpart({ Name = "Cancellata", Size = Vector3.new(0.22, 4, 0.22), CFrame = CFrame.new(p + Vector3.new(0, 2, 0)), Color = iron, Material = Enum.Material.Metal })
				hwedge({ Name = "Punta", Size = Vector3.new(0.22, 0.6, 0.3), CFrame = CFrame.new(p + Vector3.new(0, 4.3, 0)), Color = iron, Material = Enum.Material.Metal })
			end
		end
		for _, y in { 1.2, 3.4 } do
			local mid = g((a + b) / 2)
			hpart({ Name = "Cancellata", Size = Vector3.new(0.16, 0.16, len), CFrame = CFrame.lookAt(Vector3.new(mid.X, mid.Y + y, mid.Z), Vector3.new(b.X, mid.Y + y, b.Z)), Color = iron, Material = Enum.Material.Metal })
		end
	end
	-- arco d'ingresso con due lanterne verdi
	local gate = g(center - fwd * d / 2)
	for _, sx in { -1, 1 } do
		local p = gate + right * sx * 3.2
		hpart({ Name = "Pilastro", Size = Vector3.new(1.2, 6.5, 1.2), CFrame = CFrame.new(p + Vector3.new(0, 3.25, 0)), Color = Color3.fromRGB(96, 94, 100), Material = Enum.Material.Slate, CastShadow = true })
		local lantern = hpart({ Name = "Lanterna", Size = Vector3.new(0.8, 1.1, 0.8), CFrame = CFrame.new(p + Vector3.new(0, 7.1, 0)), Color = Color3.fromRGB(150, 255, 120) })
		lanternLight(lantern, 20, 1.3)
	end
	hpart({ Name = "Arco", Size = Vector3.new(7.6, 0.6, 0.6), CFrame = CFrame.lookAt(gate + Vector3.new(0, 6.4, 0), gate + Vector3.new(0, 6.4, 0) + right), Color = iron, Material = Enum.Material.Metal })
	deadTree(g(center + right * (w / 2 - 2) + fwd * (d / 2 - 2)), rng:NextNumber(0.9, 1.2))
	if rng:NextNumber() < 0.5 then
		local p = g(center - right * (w / 2 - 3) + fwd * (d / 2 - 3))
		cauldron(CFrame.new(p), 1)
	end
end

-- Orto di zucche: zucche sparse con le foglie (senza faccia), un mucchio di fieno e lo spaventapasseri
local function pumpkinPatch(center: Vector3)
	local g = (ctx :: Context).GroundAt
	for _ = 1, rng:NextInteger(7, 12) do
		local p = g(center + Vector3.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-12, 12)))
		local s = rng:NextNumber(1.6, 3.4)
		pumpkin(CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), s, rng:NextNumber() < 0.25, false)
		ellipsoid({ Name = "Foglia", Size = Vector3.new(s * 1.1, 0.2, s * 0.8), CFrame = CFrame.new(p + Vector3.new(s * 0.6, 0.1, s * 0.3)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color = Color3.fromRGB(70, 96, 44), Material = Enum.Material.LeafyGrass })
	end
	local hay = g(center + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8)))
	hpart({ Name = "Fieno", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4.4, 4, 4), CFrame = CFrame.new(hay + Vector3.new(0, 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color = Color3.fromRGB(206, 170, 86), Material = Enum.Material.Fabric, CastShadow = true })
	scarecrow(CFrame.new(g(center)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
end

-- trova un posto aperto (fuori dalle zone e dai luoghi riservati) attorno a un punto
local function openSpot(around: Vector3, rMin: number, rMax: number, margin: number): Vector3?
	local c = ctx :: Context
	for _ = 1, 24 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(rMin, rMax)
		local p = Vector3.new(around.X + math.cos(a) * r, c.G, around.Z + math.sin(a) * r)
		if c.OpenLand(p, margin) then
			local ground = c.GroundAt(p)
			if ground.Y > c.G - 1.5 and ground.Y < c.G + 14 then
				return ground
			end
		end
	end
	return nil
end

-- AGGANCI CHIAMATI DA WORLDBUILDER ------------------------------------------------------------------------

function HalloweenWorld.Begin(context: Context)
	ctx = context
	created = 0
	rng = Random.new(Config.WorldSeed + 31013)
	local model = Instance.new("Model")
	model.Name = "Halloween"
	model.Parent = context.Map
	folder = model
end

-- colori del terreno e dell'acqua: erba secca d'autunno, terra scura e acqua torbida
function HalloweenWorld.Terrain(terrain: Terrain)
	pcall(function()
		terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(118, 108, 58))
		terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(104, 78, 44))
		terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(100, 82, 62))
		terrain:SetMaterialColor(Enum.Material.Cobblestone, Color3.fromRGB(112, 106, 114))
		terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(98, 92, 98))
		terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(176, 156, 120))
		terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(64, 50, 42))
	end)
	for prop, value in {
		WaterColor = Color3.fromRGB(30, 62, 60),
		WaterReflectance = 0.7,
		WaterTransparency = 0.3,
	} :: { [string]: any } do
		pcall(function()
			(terrain :: any)[prop] = value
		end)
	end
end

-- Una casa: zucche alla porta, ragnatela, candela alla finestra, scopa. doorX = porta sulla facciata (-Z)
function HalloweenWorld.House(cf: CFrame, width: number, depth: number, height: number, floors: number, valdoria: boolean, ruined: boolean, doorX: number, plinthH: number)
	if not folder then
		return
	end
	local front = -depth / 2
	if ruined then
		-- nelle rovine: ragnatele e qualche lapide improvvisata
		if rng:NextNumber() < 0.35 then
			cobweb(cf * CFrame.new(width / 2 - 0.2, math.min(height, 10) - 0.3, front - 0.3), rng:NextNumber(3, 5))
		end
		if rng:NextNumber() < 0.2 then
			grave(cf * CFrame.new(rng:NextNumber(-width * 0.3, width * 0.3), 0, front - 4) * CFrame.Angles(0, math.pi, 0), 0.9)
		end
		return
	end
	-- zucche intagliate ai lati della porta (quella più vicina ha la candela accesa)
	local roll = rng:NextNumber()
	if roll < 0.55 then
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local s = rng:NextNumber(2.1, 2.9)
		pumpkin(cf * CFrame.new(doorX + side * 4.1, 0, front - 1.5) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), s, true, true)
		if rng:NextNumber() < 0.45 then
			pumpkin(cf * CFrame.new(doorX + side * 5.6, 0, front - 2.3) * CFrame.Angles(0, rng:NextNumber(-0.6, 0.6), 0), s * 0.7, rng:NextNumber() < 0.5, false)
		end
	end
	-- ragnatela su uno spigolo della facciata, sotto la gronda
	if rng:NextNumber() < 0.2 then
		local sx = if rng:NextNumber() < 0.5 then -1 else 1
		local web = cf * CFrame.new(sx * (width / 2 - 0.1), height - 0.4, front - 0.7)
		cobweb(if sx > 0 then web else web * CFrame.Angles(0, math.pi, 0), rng:NextNumber(3, 5.5))
	end
	-- candela accesa sul davanzale di una finestra del primo piano
	if floors >= 2 and rng:NextNumber() < 0.22 then
		local cols = math.max(1, math.floor(width / 9))
		local c = rng:NextInteger(1, cols)
		local x = -width / 2 + width * (c - 0.5) / cols
		local y = 12 + 7 - (if valdoria then 5.6 else 4.4) / 2 - 0.2
		candle(cf * CFrame.new(x + 0.6, y, front - 0.75), 0.8)
	end
	-- la scopa della strega appoggiata accanto alla porta
	if rng:NextNumber() < 0.08 then
		broom(cf * CFrame.new(doorX - 4.6, 0, front - 0.5))
	end
	-- un festone di pipistrelli di carta sopra la porta
	if rng:NextNumber() < 0.1 then
		for i = -2, 2 do
			local p = cf * CFrame.new(doorX + i * 1.1, plinthH + 9.4 + math.abs(i) * 0.2, front - 0.45)
			for _, sx in { -1, 1 } do
				hwedge({ Name = "Pipistrello", Size = Vector3.new(0.05, 0.5, 0.6), CFrame = p * CFrame.new(sx * 0.3, 0, 0) * CFrame.Angles(0, sx * math.rad(-90), math.pi), Color = Color3.fromRGB(26, 20, 30) })
			end
		end
	end
end

-- Porta delle mura: due zucche giganti accese ai lati del passaggio (dentro e fuori)
function HalloweenWorld.Gate(center: Vector3, outward: Vector3, gateWidth: number, thickness: number)
	if not folder then
		return
	end
	local c = ctx :: Context
	local pos = Vector3.new(center.X, c.G, center.Z)
	local cf = CFrame.lookAt(pos, pos - outward)
	local pillarW = 22
	local towerD = thickness + 16
	for _, sz in { -1, 1 } do
		for _, sx in { -1, 1 } do
			local at = cf * CFrame.new(sx * (gateWidth / 2 + pillarW + 9), 0, sz * (towerD / 2 + 9))
			local ground = c.GroundAt(at.Position)
			pumpkin(CFrame.lookAt(ground, ground + (if sz > 0 then outward else -outward)), rng:NextNumber(8, 10), true, true)
			pumpkin(CFrame.lookAt(ground, ground + (if sz > 0 then outward else -outward)) * CFrame.new(sx * 7, 0, -3), 4, true, false)
		end
	end
end

-- Lampione: a volte una zucca accesa ai suoi piedi
function HalloweenWorld.Lamp(pos: Vector3)
	if folder and rng:NextNumber() < 0.5 then
		local a = rng:NextNumber(0, math.pi * 2)
		pumpkin(CFrame.new(pos + Vector3.new(math.cos(a) * 1.8, 0, math.sin(a) * 1.8)) * CFrame.Angles(0, a + math.pi / 2, 0), 1.9, true, true)
	end
end

-- Il campo di addestramento infestato: zucche sui paletti dello steccato, calderone accanto al fuoco,
-- il piccolo cimitero dei cadetti, spaventapasseri e un orto di zucche
function HalloweenWorld.Camp(c: Vector3)
	if not folder then
		return
	end
	local g = (ctx :: Context).GroundAt
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + math.pi / 8
		local p = g(c + Vector3.new(math.cos(a) * 112, 0, math.sin(a) * 112))
		pumpkin(CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), 2.4, true, true)
	end
	local fire = c + Vector3.new(30, 0, 54)
	cauldron(CFrame.new(g(fire + Vector3.new(-9, 0, 4))), 1.1)
	local yard = c + Vector3.new(-70, 0, 70)
	graveyard(g(yard), Vector3.new(1, 0, -1), 3, 4)
	pumpkinPatch(c + Vector3.new(-80, 0, -50))
	for i = 1, 3 do
		local a = math.rad(200 + i * 25)
		local p = g(c + Vector3.new(math.cos(a) * 128, 0, math.sin(a) * 128))
		scarecrow(CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)))
	end
end

-- Albero gigante della foresta: lanterne verdi appese al tronco e ragnatele tra le radici
function HalloweenWorld.GiantTree(pos: Vector3, _h: number, d: number)
	if not folder or rng:NextNumber() > 0.55 then
		return
	end
	local a = rng:NextNumber(0, math.pi * 2)
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local y = rng:NextNumber(26, 46)
	local hook = pos + dir * (d * 0.5 + 0.4) + Vector3.new(0, y, 0)
	hpart({ Name = "Corda", Size = Vector3.new(0.12, 6, 0.12), CFrame = CFrame.new(hook - Vector3.new(0, 3, 0) + dir * 1.2), Color = Color3.fromRGB(60, 56, 54), Material = Enum.Material.Metal })
	local lantern = hpart({ Name = "Lanterna", Size = Vector3.new(1.4, 2, 1.4), CFrame = CFrame.new(hook - Vector3.new(0, 7, 0) + dir * 1.2), Color = if rng:NextNumber() < 0.5 then Color3.fromRGB(150, 255, 120) else Color3.fromRGB(255, 160, 60) })
	lanternLight(lantern, 26, 1.5)
	if rng:NextNumber() < 0.5 then
		sheetGhost(CFrame.new(pos + dir:Cross(Vector3.yAxis) * (d * 0.5 + 3) + Vector3.new(0, y * 0.6, 0)) * CFrame.Angles(0, a, 0), 1.3)
	end
end

-- Fine della costruzione: cimiteri, orti, calderoni e alberi morti nei campi, poi si ridipinge tutto
function HalloweenWorld.Finish()
	if not folder or not ctx then
		return
	end
	local c = ctx :: Context
	-- un cimitero fuori da ogni città e villaggio (sulla terra aperta lì vicino)
	for _, zone in Zones.List do
		if not zone.Underground and (zone.Safe or zone.Ambience == Zones.Ambience.Rovine) then
			local spot = openSpot(zone.Center, zone.Radius + 30, zone.Radius + 160, 26)
			if spot then
				graveyard(spot, Vector3.new(zone.Center.X - spot.X, 0, zone.Center.Z - spot.Z), rng:NextInteger(2, 3), rng:NextInteger(3, 5))
			end
		end
	end
	-- orti di zucche e alberi morti sparsi nelle pianure
	for _, zone in Zones.List do
		if not zone.Underground and not zone.Safe then
			for _ = 1, 2 do
				local spot = openSpot(zone.Center, zone.Radius * 0.6, zone.Radius + 220, 14)
				if spot then
					if rng:NextNumber() < 0.6 then
						pumpkinPatch(spot)
					else
						deadTree(spot, rng:NextNumber(0.9, 1.4))
					end
				end
			end
		end
	end
	HalloweenWorld.Repaint(c.Map)
	print(("[Halloween] Decorazioni: %d parti"):format(created))
end

-- RIDIPINTURA ----------------------------------------------------------------------------------------------
-- Ogni parte prende il colore di Halloween secondo il nome e il materiale. Il colore dipende dalla
-- posizione (Tema.Hash): stessa casa = stesso colore su server, client e foto.

local PLASTER = { Color3.fromRGB(150, 128, 150), Color3.fromRGB(128, 138, 116), Color3.fromRGB(178, 160, 128), Color3.fromRGB(118, 104, 132), Color3.fromRGB(164, 118, 92), Color3.fromRGB(112, 106, 114), Color3.fromRGB(96, 116, 108) }
local BRICK = { Color3.fromRGB(104, 48, 50), Color3.fromRGB(88, 42, 54), Color3.fromRGB(118, 62, 52) }
local ROOF = { Color3.fromRGB(50, 38, 60), Color3.fromRGB(40, 46, 46), Color3.fromRGB(72, 36, 58), Color3.fromRGB(56, 56, 66), Color3.fromRGB(46, 40, 44), Color3.fromRGB(126, 60, 30) }
local SHUTTER = { Color3.fromRGB(212, 100, 30), Color3.fromRGB(92, 44, 124), Color3.fromRGB(30, 26, 32), Color3.fromRGB(84, 122, 52) }
local FLOWER = { Color3.fromRGB(232, 110, 28), Color3.fromRGB(122, 50, 162), Color3.fromRGB(36, 26, 34), Color3.fromRGB(160, 22, 34) }
local LEAF = { Color3.fromRGB(214, 104, 30), Color3.fromRGB(184, 58, 32), Color3.fromRGB(214, 160, 46), Color3.fromRGB(134, 78, 38), Color3.fromRGB(124, 42, 60), Color3.fromRGB(198, 84, 24) }
local FABRIC = { Color3.fromRGB(226, 112, 28), Color3.fromRGB(38, 30, 42), Color3.fromRGB(110, 50, 150), Color3.fromRGB(96, 160, 58) }
local GOODS = { H.Pumpkin, Color3.fromRGB(244, 136, 40), H.Witch, H.Slime, Color3.fromRGB(230, 60, 120), Color3.fromRGB(250, 220, 90) }

local function lum(c: Color3): number
	return c.R * 0.3 + c.G * 0.59 + c.B * 0.11
end

local function fromList(list: { Color3 }, p: BasePart, salt: number): Color3
	return list[math.floor(Tema.Hash(p.Position, salt) * #list) + 1]
end

-- tonalità "spettrale": meno saturo, più scuro e un filo viola
local function haunt(c: Color3, dark: number): Color3
	local l = lum(c)
	local grey = Color3.new(l, l, l)
	local m = c:Lerp(grey, 0.32)
	return Color3.new(math.clamp(m.R * dark * 0.98, 0, 1), math.clamp(m.G * dark * 0.94, 0, 1), math.clamp(m.B * dark * 1.04, 0, 1))
end

-- colore di Halloween per i tessuti: arancio, nero, viola o verde a seconda del colore di prima
local function fabricColor(c: Color3, p: BasePart): Color3
	local l = lum(c)
	if l > 0.75 then
		return Color3.fromRGB(34, 28, 38)
	elseif c.R > c.G * 1.25 and c.R > c.B * 1.25 then
		return if c.G > c.B * 1.3 then Color3.fromRGB(240, 140, 30) else H.Pumpkin
	elseif c.B > c.R and c.B > c.G then
		return H.Witch
	elseif c.G > c.R and c.G > c.B then
		return Color3.fromRGB(70, 120, 48)
	end
	return fromList(FABRIC, p, 3)
end

local SKIP = { Halloween = true }

local function repaintPart(p: BasePart)
	if p.Transparency >= 0.98 then
		return
	end
	local name = p.Name
	local c = p.Color
	local mat = p.Material
	if name == "Casa" or name == "Timpano" or name == "Abbaino" or name == "Umidita" or name == "Mulino" then
		if mat == Enum.Material.Brick then
			p.Color = fromList(BRICK, p, 1):Lerp(c, 0.25)
		else
			local base = fromList(PLASTER, p, 1)
			p.Color = tint(base:Lerp(c, 0.15), if name == "Umidita" then 0.74 else 0.86)
		end
	elseif name == "Tetto" or name == "Colmo" or name == "TettoAbbaino" or name == "TettoTorre" or name == "TettoPaglia" or name == "TettoCapanna" or name == "TettoFaro" or name == "Pinnacolo" then
		local roof = fromList(ROOF, p, 2)
		p.Color = if name == "Colmo" then tint(roof, 0.8) else roof
	elseif name == "Trave" or name == "Fascia" or name == "Montante" or name == "Croce" or name == "Catena" or name == "Monaco" or name == "Stipite" or name == "Cornice" or name == "Davanzale" or name == "TavolaTetto" or name == "Telaio" or name == "Porta" then
		if mat == Enum.Material.Wood or mat == Enum.Material.WoodPlanks then
			p.Color = tint(Color3.fromRGB(48, 36, 32), 0.85 + Tema.Hash(p.Position, 4) * 0.3)
		else
			p.Color = haunt(c, 0.82)
		end
	elseif name == "Persiana" then
		p.Color = fromList(SHUTTER, p, 5)
	elseif name == "Fiori" then
		p.Color = fromList(FLOWER, p, 6)
	elseif name == "Edera" then
		p.Color = Color3.fromRGB(70, 52, 50):Lerp(Color3.fromRGB(96, 70, 40), Tema.Hash(p.Position, 7))
	elseif name == "Muschio" then
		p.Color = Color3.fromRGB(70, 74, 44)
	elseif name == "Chioma" or name == "Fogliame" or name == "Cespuglio" then
		local isFir = p:FindFirstChildOfClass("SpecialMesh") ~= nil and c.G > c.R * 1.4 and lum(c) < 0.3
		if isFir then
			p.Color = Color3.fromRGB(28, 44, 42):Lerp(Color3.fromRGB(44, 60, 52), math.clamp((lum(c) - 0.2) * 6, 0, 1))
		else
			-- foglie d'autunno: stesso albero = stesso colore (dal perno), più scure in ombra
			local pivot = p:GetAttribute("Perno")
			local where = if typeof(pivot) == "Vector3" then pivot else p.Position
			local autumn = LEAF[math.floor(Tema.Hash(where, 8) * #LEAF) + 1]
			local shade = math.clamp(lum(c) / 0.42, 0.7, 1.25)
			p.Color = tint(autumn, shade)
		end
	elseif name == "Tronco" or name == "Ramo" or name == "Radici" or name == "TroncoGigante" or name == "Radice" or name == "Corteccia" or name == "TroncoPalma" then
		p.Color = haunt(c, 0.72)
	elseif name == "Stendardo" or name == "Bandiera" or name == "Bandierina" or name == "StendardoArena" or name == "Tendone" or name == "Telo" or name == "TeloTorre" or name == "Tenda" or name == "Tappeto" or name == "StemmaColore" then
		p.Color = fabricColor(c, p)
	elseif name == "Merce" then
		p.Color = fromList(GOODS, p, 9)
	elseif name == "Bombola" then
		p.Color = H.Pumpkin
		p.Reflectance = 0.12
	elseif name == "TestaManichino" then
		p.Color = H.Pumpkin
	elseif name == "Manichino" then
		p.Color = Color3.fromRGB(110, 60, 120)
	elseif name == "Finestra" then
		p.Color = Color3.fromRGB(46, 38, 62)
	elseif mat == Enum.Material.Neon then
		-- luci: arancio delle zucche, qualcuna verde da strega
		if lum(c) > 0.45 and c.R > c.B then
			p.Color = if Tema.Hash(p.Position, 11) < 0.3 then Color3.fromRGB(150, 255, 110) else Color3.fromRGB(255, 150, 56)
		end
	elseif mat == Enum.Material.Grass or mat == Enum.Material.LeafyGrass then
		p.Color = Color3.fromRGB(118, 108, 58)
	elseif mat == Enum.Material.Fabric then
		-- stoffe senza nome speciale (sacchi, tappeti, coperte): un filo più scure delle bandiere
		p.Color = tint(fabricColor(c, p), 0.92)
	elseif mat == Enum.Material.Wood or mat == Enum.Material.WoodPlanks then
		p.Color = haunt(c, 0.7)
	elseif mat == Enum.Material.Glass or mat == Enum.Material.ForceField then
		return
	else
		-- pietra, metallo, intonaco e tutto il resto: più cupo e freddo
		p.Color = haunt(c, 0.86)
	end
	-- fuochi e luci dentro la parte: un fuoco su tre diventa verde, da strega
	local green = Tema.Hash(p.Position, 11) < 0.3
	for _, child in p:GetChildren() do
		if child:IsA("Fire") then
			child.Color = if green then Color3.fromRGB(120, 255, 90) else Color3.fromRGB(255, 130, 40)
			child.SecondaryColor = if green then Color3.fromRGB(30, 150, 60) else Color3.fromRGB(200, 40, 20)
		elseif child:IsA("PointLight") and child.Color.R > child.Color.B then
			child.Color = if green then Color3.fromRGB(130, 255, 100) else Color3.fromRGB(255, 142, 56)
		end
	end
end

function HalloweenWorld.Repaint(root: Instance)
	local count = 0
	local function visit(node: Instance)
		for _, child in node:GetChildren() do
			if not SKIP[child.Name] then
				if child:IsA("BasePart") then
					repaintPart(child)
					count += 1
					if count % 2000 == 0 and RunService:IsRunning() then
						task.wait()
					end
				end
				visit(child)
			end
		end
	end
	visit(root)
	return count
end

return HalloweenWorld
