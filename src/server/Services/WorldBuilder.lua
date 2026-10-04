--[[
	WorldBuilder
	Genera tutta la mappa via codice all'avvio del server: un arcipelago nel mare.
	  - Vermiglia: mura, distretto di Calaneth, campo di addestramento, foresta
	  - Edenia: villaggio di Brenn, castello di Ostrava, la gola
	  - Aurea: la capitale Aurion, Stohlberg, la Città Sotterranea e la Caverna di Cristallo
	  - Cenere: le mura in rovina e il distretto di Halvar
	  - Valdoria: porto, trincee, Revelia, fortezza, fronte
	  - l'Isola dell'Arena per i raid

	TRUCCO: per vedere (e modificare) la mappa in Studio senza premere Play,
	scrivi nella Command Bar:
	    require(game.ServerScriptService.Server.Services.WorldBuilder).Build()
	e poi salva il luogo. All'avvio il server non la rigenererà se esiste già.
]]

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Lib.Util)
local Signal = require(Shared.Lib.Signal)
local W = require(Shared.Data.WorldLayout)
local Zones = require(Shared.Data.Zones)
local NPCs = require(Shared.Data.NPCs)

local WorldBuilder = {}
WorldBuilder.Ready = false
WorldBuilder.ReadySignal = Signal.new()

local G = W.GroundY
local rng = Random.new(Config.WorldSeed)
local partCount = 0
local mapFolder: Folder
local currentGroup: Instance

-- Aree da lasciare libere (attorno ai PNG e ai punti importanti)
local reserved: { { Pos: Vector3, Radius: number } } = {}

local PALETTE = {
	Plaster = { Color3.fromRGB(232, 222, 200), Color3.fromRGB(222, 210, 186), Color3.fromRGB(238, 230, 214), Color3.fromRGB(214, 200, 176) },
	Roof = { Color3.fromRGB(168, 78, 52), Color3.fromRGB(150, 66, 46), Color3.fromRGB(176, 92, 60), Color3.fromRGB(128, 70, 52) },
	Timber = Color3.fromRGB(78, 54, 38),
	Stone = Color3.fromRGB(176, 170, 156),
	Wall = Color3.fromRGB(196, 188, 170),
	WallDark = Color3.fromRGB(150, 144, 130),
	Brick = { Color3.fromRGB(150, 76, 58), Color3.fromRGB(128, 66, 52), Color3.fromRGB(168, 96, 72) },
	Wood = Color3.fromRGB(116, 84, 56),
	Leaf = { Color3.fromRGB(70, 118, 60), Color3.fromRGB(58, 104, 52), Color3.fromRGB(86, 132, 66), Color3.fromRGB(64, 112, 70) },
}

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

local function pause()
	if RunService:IsRunning() then
		task.wait()
	end
end

local function yieldMaybe()
	partCount += 1
	if partCount % 400 == 0 then
		pause()
	end
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = true
	for k, v in props do
		if k ~= "Parent" and k ~= "Shape" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent or currentGroup
	yieldMaybe()
	return p
end

local function wedge(props: { [string]: any }): WedgePart
	local p = Instance.new("WedgePart")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent or currentGroup
	yieldMaybe()
	return p
end

local function group(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent or mapFolder
	return m
end

local function isReserved(pos: Vector3, margin: number): boolean
	for _, r in reserved do
		if Util.FlatDistance(pos, r.Pos) < r.Radius + margin then
			return true
		end
	end
	return false
end

-- TERRENO ------------------------------------------------------------------------------

local function buildTerrain()
	local terrain = workspace.Terrain
	-- aspetto del terreno: ogni proprietà è protetta, alcune versioni di Studio non le permettono tutte
	for prop, value in {
		Decoration = true,
		WaterColor = Color3.fromRGB(32, 84, 110),
		WaterReflectance = 0.6,
		WaterTransparency = 0.35,
		WaterWaveSize = 0.18,
		WaterWaveSpeed = 9,
	} :: { [string]: any } do
		pcall(function()
			(terrain :: any)[prop] = value
		end)
	end
	pcall(function()
		terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(96, 140, 72))
		terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(78, 120, 60))
		terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(110, 92, 70))
		terrain:SetMaterialColor(Enum.Material.Cobblestone, Color3.fromRGB(140, 134, 124))
		terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(128, 118, 106))
		terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(214, 196, 150))
		terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(92, 74, 56))
	end)

	-- Oceano che collega tutte le isole (a blocchi, per non bloccare il server)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, isl in W.Islands do
		minX = math.min(minX, isl.Center.X - isl.Water - 600)
		maxX = math.max(maxX, isl.Center.X + isl.Water + 600)
		minZ = math.min(minZ, isl.Center.Z - isl.Water - 600)
		maxZ = math.max(maxZ, isl.Center.Z + isl.Water + 600)
	end
	local tile = 1024
	local oceanOk, oceanErr = pcall(function()
	for x = minX, maxX, tile do
		for z = minZ, maxZ, tile do
			local sx = math.min(tile, maxX - x)
			local sz = math.min(tile, maxZ - z)
			if sx > 4 and sz > 4 then
				terrain:FillBlock(CFrame.new(x + sx / 2, -8, z + sz / 2), Vector3.new(sx, 8, sz), Enum.Material.Sand)
				terrain:FillBlock(CFrame.new(x + sx / 2, 0, z + sz / 2), Vector3.new(sx, 8, sz), Enum.Material.Water)
				pause()
			end
		end
	end
	end)
	if not oceanOk then
		warn("[WorldBuilder] Oceano non generato: " .. tostring(oceanErr))
	end

	local function island(center: Vector3, land: number, beach: number)
		terrain:FillCylinder(CFrame.new(center.X, 1, center.Z), 10, beach, Enum.Material.Sand)
		pause()
		terrain:FillCylinder(CFrame.new(center.X, 2, center.Z), 12, land, Enum.Material.Grass)
		pause()
	end
	for _, id in W.IslandOrder do
		local isl = W.Islands[id]
		island(isl.Center, isl.Land, isl.Beach)
	end

	local function wallRadiusOf(islandId: string): number?
		for _, wall in W.Walls do
			if wall.Island == islandId then
				return wall.Radius
			end
		end
		return nil
	end

	-- Colline su ogni isola (evitando zone e mura)
	for _, id in W.IslandOrder do
		local isl = W.Islands[id]
		if not isl.Raid then
			local wallR = wallRadiusOf(id)
			for _ = 1, 16 do
				local r = rng:NextNumber(if wallR then wallR + 60 else 120, isl.Land - 80)
				local pos = isl.Center + Util.Polar(rng:NextNumber(0, 360), r)
				local radius = rng:NextNumber(40, 100)
				local zone = Zones.Find(Vector3.new(pos.X, G, pos.Z))
				if not zone and (not wallR or math.abs(r - wallR) > radius + 30) then
					local material = if rng:NextNumber() < 0.25 then Enum.Material.Rock else Enum.Material.Grass
					terrain:FillBall(Vector3.new(pos.X, G - radius * 0.62, pos.Z), radius, material)
				end
			end
		end
	end
	pause()

	-- Campi coltivati dentro le mura
	for _, wall in W.Walls do
		local center = W.WallCenter(wall.Id)
		for _ = 1, 18 do
			local pos = center + Util.Polar(rng:NextNumber(0, 360), rng:NextNumber(120, wall.Radius - 50))
			local zone = Zones.Find(Vector3.new(pos.X, G, pos.Z))
			if not zone then
				local size = Vector3.new(rng:NextNumber(50, 100), 4, rng:NextNumber(40, 80))
				local material = if wall.Ruined then Enum.Material.Mud else pick({ Enum.Material.Ground, Enum.Material.LeafyGrass, Enum.Material.Mud })
				terrain:FillBlock(CFrame.new(pos.X, G - 2, pos.Z) * CFrame.Angles(0, math.rad(rng:NextNumber(0, 180)), 0), size, material)
			end
		end
	end
	pause()

	-- Strade di ciottoli nella capitale e nei distretti
	local aurea = W.IslandCenter("Aurea")
	terrain:FillCylinder(CFrame.new(aurea.X, G - 2, aurea.Z), 4, W.Walls.Aurea.Radius - 12, Enum.Material.Cobblestone)
	for id, d in W.Districts do
		local gate = W.DistrictGatePoint(id)
		terrain:FillCylinder(CFrame.new(gate.X, G - 2, gate.Z), 4, d.Radius - 8, if d.Ruined then Enum.Material.Ground else Enum.Material.Cobblestone)
	end

	-- Laghetto vicino a Ostrava
	local lake = W.Landmarks.LagoOstrava
	terrain:FillCylinder(CFrame.new(lake.X, G - 4, lake.Z), 8, 55, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(lake.X, G - 6, lake.Z), 6, 55, Enum.Material.Water)

	-- Gola di Edenia: due creste di roccia con un canyon in mezzo
	local gola = Zones.Get("GolaEdenia")
	if gola then
		local c = gola.Center
		local dir = math.rad(30)
		for _, side in { -1, 1 } do
			for i = -3, 3 do
				local along = Vector3.new(math.cos(dir), 0, math.sin(dir)) * (i * 38)
				local across = Vector3.new(-math.sin(dir), 0, math.cos(dir)) * (side * 52)
				local pos = c + along + across
				local h = rng:NextNumber(60, 95)
				terrain:FillBlock(CFrame.new(pos.X, G + h / 2 - 6, pos.Z) * CFrame.Angles(0, -dir + math.rad(rng:NextNumber(-8, 8)), 0), Vector3.new(46, h, rng:NextNumber(26, 40)), Enum.Material.Rock)
			end
		end
		for _ = 1, 10 do
			local pos = c + Vector3.new(rng:NextNumber(-90, 90), 0, rng:NextNumber(-90, 90))
			terrain:FillBall(Vector3.new(pos.X, G, pos.Z), rng:NextNumber(6, 14), Enum.Material.Rock)
		end
	end

	-- Trincee di Valdoria (solchi nel fango)
	local trincee = Zones.Get("Trincee")
	if trincee then
		local c = trincee.Center
		terrain:FillCylinder(CFrame.new(c.X, G - 2, c.Z), 4, trincee.Radius, Enum.Material.Mud)
		for i = -2, 2 do
			local pos = c + Vector3.new(0, 0, i * 55)
			terrain:FillBlock(CFrame.new(pos.X, G - 3, pos.Z), Vector3.new(trincee.Radius * 1.6, 8, 10), Enum.Material.Air)
		end
		for _ = 1, 14 do
			local pos = c + Vector3.new(rng:NextNumber(-150, 150), 0, rng:NextNumber(-150, 150))
			terrain:FillBall(Vector3.new(pos.X, G + 2, pos.Z), rng:NextNumber(7, 14), Enum.Material.Air)
		end
	end
	-- Fronte della Grande Marcia: terra bruciata
	local fronte = Zones.Get("FronteMarcia")
	if fronte then
		local c = fronte.Center
		terrain:FillCylinder(CFrame.new(c.X, G - 2, c.Z), 4, fronte.Radius, Enum.Material.Basalt)
		for _ = 1, 22 do
			local pos = c + Vector3.new(rng:NextNumber(-200, 200), 0, rng:NextNumber(-200, 200))
			terrain:FillBall(Vector3.new(pos.X, G - 4, pos.Z), rng:NextNumber(8, 18), Enum.Material.CrackedLava)
		end
	end
	local revelia = Zones.Get("Revelia")
	if revelia then
		terrain:FillCylinder(CFrame.new(revelia.Center.X, G - 2, revelia.Center.Z), 4, revelia.Radius, Enum.Material.Pavement)
	end
	local rovine = Zones.Get("Halvar")
	if rovine then
		for _ = 1, 16 do
			local pos = rovine.Center + Vector3.new(rng:NextNumber(-140, 140), 0, rng:NextNumber(-120, 120))
			terrain:FillBall(Vector3.new(pos.X, G - 2, pos.Z), rng:NextNumber(5, 10), Enum.Material.Rock)
		end
	end
	local foresta = Zones.Get("Foresta")
	if foresta then
		terrain:FillCylinder(CFrame.new(foresta.Center.X, G - 2, foresta.Center.Z), 4, foresta.Radius + 20, Enum.Material.LeafyGrass)
	end
end

local function carveCave(id: string, material: Enum.Material)
	local cave = W.Underground[id]
	local terrain = workspace.Terrain
	terrain:FillBlock(CFrame.new(cave.Center), cave.Size + Vector3.new(60, 60, 60), material)
	pause()
	terrain:FillBlock(CFrame.new(cave.Center), cave.Size, Enum.Material.Air)
	pause()
	-- stalattiti e rocce sul fondo
	local floorY = cave.Center.Y - cave.Size.Y / 2
	local ceilY = cave.Center.Y + cave.Size.Y / 2
	for _ = 1, 26 do
		local x = cave.Center.X + rng:NextNumber(-cave.Size.X / 2, cave.Size.X / 2)
		local z = cave.Center.Z + rng:NextNumber(-cave.Size.Z / 2, cave.Size.Z / 2)
		terrain:FillBall(Vector3.new(x, ceilY, z), rng:NextNumber(8, 20), material)
	end
	for _ = 1, 14 do
		local x = cave.Center.X + rng:NextNumber(-cave.Size.X / 2.2, cave.Size.X / 2.2)
		local z = cave.Center.Z + rng:NextNumber(-cave.Size.Z / 2.2, cave.Size.Z / 2.2)
		if Util.FlatDistance(Vector3.new(x, 0, z), cave.Center + Vector3.new(0, 0, 160)) > 40 then
			terrain:FillBall(Vector3.new(x, floorY, z), rng:NextNumber(6, 12), material)
		end
	end
end

-- MURA ---------------------------------------------------------------------------------

local function angleInGate(angleDeg: number, gates: { number }, halfWidthDeg: number): boolean
	for _, gate in gates do
		local diff = math.abs(((angleDeg - gate) + 540) % 360 - 180)
		if diff < halfWidthDeg then
			return true
		end
	end
	return false
end

-- Le mura sono fatte di enormi blocchi di pietra chiara: zoccolo a scarpa sporco di terra,
-- corsi orizzontali che segnano i blocchi, lesene sui giunti, camminamento con parapetto
-- merlato, binari e cannoni in cima, torri di guardia e grandi porte con stendardi.
local WALL_STONE = {
	Color3.fromRGB(202, 194, 176),
	Color3.fromRGB(193, 186, 169),
	Color3.fromRGB(208, 200, 184),
	Color3.fromRGB(187, 179, 161),
}
local WALL_COURSE = Color3.fromRGB(156, 148, 132)
local WALL_DIRT = Color3.fromRGB(112, 106, 90)
local WALL_TOP = Color3.fromRGB(124, 120, 112)
local IRON = Color3.fromRGB(52, 50, 50)
local BANNER = {
	Vermiglia = Color3.fromRGB(142, 30, 34),
	Aurea = Color3.fromRGB(190, 146, 46),
	Cenere = Color3.fromRGB(68, 64, 62),
}

local function tint(c: Color3, f: number): Color3
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end

-- Cannone su affusto di legno: cf a livello del camminamento, la canna punta verso +Z (fuori)
local function cannon(cf: CFrame)
	part({ Name = "Affusto", Size = Vector3.new(3.6, 1.6, 6), CFrame = cf * CFrame.new(0, 1.6, 0), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(92, 64, 42) })
	for _, s in { -1, 1 } do
		part({ Name = "Ruota", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 3.2, 3.2), CFrame = cf * CFrame.new(s * 2.2, 1.6, 1), Material = Enum.Material.Wood, Color = Color3.fromRGB(66, 46, 30), CastShadow = false })
	end
	part({ Name = "Cannone", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8.5, 1.9, 1.9), CFrame = cf * CFrame.new(0, 3.3, 2.2) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, math.rad(5)), Material = Enum.Material.Metal, Color = Color3.fromRGB(44, 44, 48) })
	part({ Name = "Culatta", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4), CFrame = cf * CFrame.new(0, 3.1, -2), Material = Enum.Material.Metal, Color = Color3.fromRGB(44, 44, 48), CastShadow = false })
	-- palle di cannone accatastate
	for i = 0, 2 do
		part({ Name = "Palla", Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.3, 1.3), CFrame = cf * CFrame.new(3.6 + i * 1.3, 0.65, -2), Material = Enum.Material.Metal, Color = IRON, CastShadow = false, CanCollide = false })
	end
end

-- Torcia a muro (fuoco e luce calda)
local function torch(cf: CFrame)
	part({ Name = "Torcia", Size = Vector3.new(0.6, 3, 0.6), CFrame = cf * CFrame.Angles(math.rad(-20), 0, 0), Material = Enum.Material.Wood, Color = Color3.fromRGB(60, 40, 26), CastShadow = false, CanCollide = false })
	local flame = part({ Name = "Fiamma", Size = Vector3.new(0.8, 0.8, 0.8), CFrame = cf * CFrame.new(0, 1.7, 0.6), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 160, 70), Transparency = 0.2, CastShadow = false, CanCollide = false })
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 6
	fire.Color = Color3.fromRGB(255, 150, 60)
	fire.SecondaryColor = Color3.fromRGB(255, 70, 20)
	fire.Parent = flame
	local light = Instance.new("PointLight")
	light.Range = 22
	light.Brightness = 1.8
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Shadows = false
	light.Parent = flame
	CollectionService:AddTag(flame, Config.Tags.Lamp)
end

-- Bandiera su asta (in cima a torri e porte)
local function flag(base: CFrame, poleH: number, color: Color3)
	part({ Name = "Asta", Size = Vector3.new(0.5, poleH, 0.5), CFrame = base * CFrame.new(0, poleH / 2, 0), Material = Enum.Material.Wood, Color = Color3.fromRGB(70, 50, 34), CastShadow = false })
	part({ Name = "Bandiera", Size = Vector3.new(0.15, 5, 8), CFrame = base * CFrame.new(0, poleH - 3, 4.2), Material = Enum.Material.Fabric, Color = color, CastShadow = false, CanCollide = false })
end

-- Stemma: anello di pietra, disco colorato e una spada d'argento (disegno originale)
local function emblem(cf: CFrame, diameter: number, color: Color3)
	local face = cf * CFrame.Angles(0, math.pi / 2, 0) -- l'asse del cilindro guarda verso +Z
	part({ Name = "Stemma", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, diameter, diameter), CFrame = face, Material = Enum.Material.Limestone, Color = Color3.fromRGB(176, 168, 150), CastShadow = false })
	part({ Name = "StemmaColore", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, diameter * 0.78, diameter * 0.78), CFrame = face, Material = Enum.Material.SmoothPlastic, Color = color, CastShadow = false })
	part({ Name = "StemmaSpada", Size = Vector3.new(diameter * 0.09, diameter * 0.62, 0.6), CFrame = cf * CFrame.new(0, -diameter * 0.04, 0.9), Material = Enum.Material.Metal, Color = Color3.fromRGB(214, 214, 220), CastShadow = false })
	part({ Name = "StemmaElsa", Size = Vector3.new(diameter * 0.34, diameter * 0.07, 0.6), CFrame = cf * CFrame.new(0, diameter * 0.16, 0.95), Material = Enum.Material.Metal, Color = Color3.fromRGB(222, 182, 82), CastShadow = false })
end

-- Tratto di muro. -Z locale = verso l'interno, +Z = faccia esterna
local function wallSegment(center: Vector3, faceTowards: Vector3, length: number, height: number, thickness: number, opts: { [string]: any }?)
	local o = opts or {}
	local ruined = o.Ruined == true
	local pos = Vector3.new(center.X, G + height / 2, center.Z)
	local cf = CFrame.lookAt(pos, Vector3.new(faceTowards.X, pos.Y, faceTowards.Z))
	local stone = pick(WALL_STONE)
	if ruined then
		stone = tint(stone, 0.8)
	end
	local half = height / 2
	part({ Name = "Muro", Size = Vector3.new(length, height, thickness), CFrame = cf, Material = Enum.Material.Limestone, Color = stone })

	-- zoccolo a scarpa (più largo alla base) e terra/muschio che risale la pietra
	local talusH = math.min(34, height * 0.24)
	local talusD = 7
	wedge({ Name = "Scarpa", Size = Vector3.new(length, talusH, talusD), CFrame = cf * CFrame.new(0, -half + talusH / 2, thickness / 2 + talusD / 2) * CFrame.Angles(0, math.pi, 0), Material = Enum.Material.Cobblestone, Color = tint(stone, 0.8) })
	wedge({ Name = "Scarpa", Size = Vector3.new(length, talusH * 0.6, talusD * 0.6), CFrame = cf * CFrame.new(0, -half + talusH * 0.3, -thickness / 2 - talusD * 0.3), Material = Enum.Material.Cobblestone, Color = tint(stone, 0.8) })
	part({ Name = "Sporco", Size = Vector3.new(length + 0.1, 4, thickness + talusD * 2 + 0.6), CFrame = cf * CFrame.new(0, -half + 2, talusD * 0.2), Material = Enum.Material.Ground, Color = WALL_DIRT, CastShadow = false })

	-- corsi di pietra: fasce orizzontali che dividono i grandi blocchi
	local courses = math.max(2, math.floor(height / 24))
	for i = 1, courses - 1 do
		local y = -half + i * (height / courses)
		part({ Name = "Corso", Size = Vector3.new(length, 1.1, thickness + 0.7), CFrame = cf * CFrame.new(0, y, 0), Material = Enum.Material.Slate, Color = WALL_COURSE, CastShadow = false })
	end
	-- lesena sul giunto esterno (nasconde lo spigolo tra due tratti)
	if not ruined or rng:NextNumber() < 0.6 then
		local ph = height - 6
		part({ Name = "Lesena", Size = Vector3.new(9, ph, 3.6), CFrame = cf * CFrame.new(length / 2, -half + ph / 2, thickness / 2 + 1.8), Material = Enum.Material.Limestone, Color = tint(stone, 0.92) })
	end
	-- crepe e macchie scure di umidità
	if rng:NextNumber() < 0.35 then
		local ch = rng:NextNumber(12, 30)
		part({ Name = "Crepa", Size = Vector3.new(0.6, ch, 0.3), CFrame = cf * CFrame.new(rng:NextNumber(-length * 0.4, length * 0.4), rng:NextNumber(-half * 0.3, half * 0.6), thickness / 2 + 0.12) * CFrame.Angles(0, 0, rng:NextNumber(-0.25, 0.25)), Material = Enum.Material.Slate, Color = tint(stone, 0.55), CastShadow = false, CanCollide = false })
	end
	if rng:NextNumber() < 0.5 then
		local mh = rng:NextNumber(20, 50)
		part({ Name = "Macchia", Size = Vector3.new(rng:NextNumber(6, 14), mh, 0.2), CFrame = cf * CFrame.new(rng:NextNumber(-length * 0.35, length * 0.35), half - mh / 2 - 2, thickness / 2 + 0.1), Material = Enum.Material.Limestone, Color = tint(stone, 0.86), CastShadow = false, CanCollide = false })
	end

	-- camminamento in cima
	part({ Name = "Camminamento", Size = Vector3.new(length + 0.2, 2, thickness + 1), CFrame = cf * CFrame.new(0, half + 1, 0), Material = Enum.Material.Slate, Color = WALL_TOP })
	if ruined then
		-- parapetto spezzato
		for i = 1, 3 do
			if rng:NextNumber() < 0.55 then
				local h = rng:NextNumber(2, 6)
				part({ Name = "MerloRotto", Size = Vector3.new(rng:NextNumber(4, 9), h, 3), CFrame = cf * CFrame.new(-length / 2 + i * length / 4, half + 2 + h / 2, thickness / 2 - 1.5) * CFrame.Angles(0, 0, rng:NextNumber(-0.2, 0.2)), Material = Enum.Material.Limestone, Color = stone })
			end
		end
		return
	end
	-- parapetto esterno con merli, parapetto basso interno
	part({ Name = "Parapetto", Size = Vector3.new(length + 0.2, 4, 3), CFrame = cf * CFrame.new(0, half + 4, thickness / 2 - 1.5), Material = Enum.Material.Limestone, Color = stone })
	local merlons = math.max(2, math.floor(length / 11))
	for i = 1, merlons do
		local x = -length / 2 + (i - 0.5) * length / merlons
		part({ Name = "Merlo", Size = Vector3.new(length / merlons * 0.55, 5, 3), CFrame = cf * CFrame.new(x, half + 8.5, thickness / 2 - 1.5), Material = Enum.Material.Limestone, Color = stone, CastShadow = false })
	end
	part({ Name = "ParapettoInterno", Size = Vector3.new(length + 0.2, 2.6, 1.6), CFrame = cf * CFrame.new(0, half + 3.3, -thickness / 2 + 0.8), Material = Enum.Material.Limestone, Color = tint(stone, 0.95) })
	-- binari su cui scorrono i cannoni
	for _, rz in { -2.5, 2.5 } do
		part({ Name = "Binario", Size = Vector3.new(length + 0.2, 0.4, 0.6), CFrame = cf * CFrame.new(0, half + 2.2, rz), Material = Enum.Material.Metal, Color = IRON, CastShadow = false, CanCollide = false })
	end
	if o.Cannon then
		cannon(cf * CFrame.new(rng:NextNumber(-length * 0.25, length * 0.25), half + 2, thickness / 2 - 9))
	end
end

-- Torre di guardia addossata alla faccia esterna. cf alla base del muro, +Z verso l'esterno
local function wallTower(cf: CFrame, height: number, thickness: number, bannerColor: Color3)
	local stone = tint(pick(WALL_STONE), 0.96)
	local w, d = 26, 20
	local h = height + 18
	local zc = thickness / 2 + d / 2 - 2
	part({ Name = "Torre", Size = Vector3.new(w, h, d), CFrame = cf * CFrame.new(0, h / 2, zc), Material = Enum.Material.Limestone, Color = stone })
	wedge({ Name = "Scarpa", Size = Vector3.new(w + 6, 30, 7), CFrame = cf * CFrame.new(0, 15, zc + d / 2 + 3.5) * CFrame.Angles(0, math.pi, 0), Material = Enum.Material.Cobblestone, Color = tint(stone, 0.8) })
	for _, side in { -1, 1 } do
		wedge({ Name = "Scarpa", Size = Vector3.new(d, 30, 5), CFrame = cf * CFrame.new(side * (w / 2 + 2.5), 15, zc) * CFrame.Angles(0, -side * math.pi / 2, 0), Material = Enum.Material.Cobblestone, Color = tint(stone, 0.8) })
	end
	local courses = math.floor(h / 24)
	for i = 1, courses - 1 do
		part({ Name = "Corso", Size = Vector3.new(w + 0.7, 1.1, d + 0.7), CFrame = cf * CFrame.new(0, i * h / courses, zc), Material = Enum.Material.Slate, Color = WALL_COURSE, CastShadow = false })
	end
	-- feritoie sulla faccia esterna
	for i = 1, 3 do
		part({ Name = "Feritoia", Size = Vector3.new(1.6, 7, 0.4), CFrame = cf * CFrame.new(0, h * (0.3 + i * 0.17), zc + d / 2 + 0.1), Material = Enum.Material.Slate, Color = Color3.fromRGB(30, 28, 28), CastShadow = false })
	end
	-- terrazza merlata
	part({ Name = "Terrazza", Size = Vector3.new(w + 2, 2, d + 2), CFrame = cf * CFrame.new(0, h + 1, zc), Material = Enum.Material.Slate, Color = WALL_TOP })
	for _, side in { -1, 1 } do
		for i = 0, 2 do
			local x = -w / 2 + 3 + i * (w - 6) / 2
			part({ Name = "Merlo", Size = Vector3.new(4.4, 5, 2.4), CFrame = cf * CFrame.new(x, h + 4.5, zc + side * (d / 2 + 1 - 1.2)), Material = Enum.Material.Limestone, Color = stone, CastShadow = false })
			local z = -d / 2 + 3 + i * (d - 6) / 2
			part({ Name = "Merlo", Size = Vector3.new(2.4, 5, 4.4), CFrame = cf * CFrame.new(side * (w / 2 + 1 - 1.2), h + 4.5, zc + z), Material = Enum.Material.Limestone, Color = stone, CastShadow = false })
		end
	end
	flag(cf * CFrame.new(0, h + 2, zc), 14, bannerColor)
end

local function buildGate(center: Vector3, outward: Vector3, height: number, thickness: number, kind: string, bannerColor: Color3?)
	local color = bannerColor or BANNER.Vermiglia
	local width = W.GateWidth
	local pos = Vector3.new(center.X, G, center.Z)
	-- +Z locale = verso l'esterno
	local cf = CFrame.lookAt(pos, pos - outward)
	local intact = kind ~= "Broken"
	local stone = pick(WALL_STONE)
	if not intact then
		stone = tint(stone, 0.78)
	end
	local pillarW = 22
	local towerH = height + 22
	local towerD = thickness + 16
	for _, side in { -1, 1 } do
		local x = side * (width / 2 + pillarW / 2)
		part({ Name = "Pilastro", Size = Vector3.new(pillarW, towerH, towerD), CFrame = cf * CFrame.new(x, towerH / 2, 0), Material = Enum.Material.Limestone, Color = tint(stone, 0.94) })
		wedge({ Name = "Scarpa", Size = Vector3.new(pillarW + 4, 34, 8), CFrame = cf * CFrame.new(x, 17, towerD / 2 + 4) * CFrame.Angles(0, math.pi, 0), Material = Enum.Material.Cobblestone, Color = tint(stone, 0.8) })
		local courses = math.floor(towerH / 24)
		for i = 1, courses - 1 do
			part({ Name = "Corso", Size = Vector3.new(pillarW + 0.7, 1.1, towerD + 0.7), CFrame = cf * CFrame.new(x, i * towerH / courses, 0), Material = Enum.Material.Slate, Color = WALL_COURSE, CastShadow = false })
		end
		-- merli in cima alle torri della porta
		for i = 0, 2 do
			for _, sz in { -1, 1 } do
				part({ Name = "Merlo", Size = Vector3.new(4.6, 5, 2.4), CFrame = cf * CFrame.new(x - pillarW / 2 + 3.5 + i * (pillarW - 7) / 2, towerH + 2.5, sz * (towerD / 2 - 1.2)), Material = Enum.Material.Limestone, Color = stone, CastShadow = false })
			end
		end
		if not intact then
			continue
		end
		flag(cf * CFrame.new(x, towerH, 0), 16, color)
		-- stendardo appeso alla faccia esterna
		local bannerH = height * 0.42
		part({ Name = "Stendardo", Size = Vector3.new(11, bannerH, 0.3), CFrame = cf * CFrame.new(x, height - bannerH / 2 - 6, towerD / 2 + 0.3), Material = Enum.Material.Fabric, Color = color, CastShadow = false, CanCollide = false })
		part({ Name = "BordoStendardo", Size = Vector3.new(12, 1, 0.5), CFrame = cf * CFrame.new(x, height - 5.5, towerD / 2 + 0.4), Material = Enum.Material.Metal, Color = Color3.fromRGB(196, 160, 72), CastShadow = false, CanCollide = false })
		emblem(cf * CFrame.new(x, height - bannerH * 0.35 - 6, towerD / 2 + 0.6), 7, Color3.fromRGB(236, 228, 210))
		-- torce ai lati del passaggio (dentro e fuori)
		for _, sz in { -1, 1 } do
			torch(cf * CFrame.new(side * (width / 2 + 1.2), 16, sz * (towerD / 2 + 0.6)) * CFrame.Angles(0, if sz > 0 then 0 else math.pi, 0))
		end
	end
	local archBottom = 62
	part({ Name = "Architrave", Size = Vector3.new(width + 2, height - archBottom, thickness + 4), CFrame = cf * CFrame.new(0, archBottom + (height - archBottom) / 2, 0), Material = Enum.Material.Limestone, Color = stone })
	-- angoli smussati dell'arco
	local ch = 9
	for _, side in { -1, 1 } do
		wedge({ Name = "Arco", Size = Vector3.new(thickness + 4, ch, ch), CFrame = cf * CFrame.new(side * (width / 2 - ch / 2), archBottom - ch / 2, 0) * CFrame.Angles(0, side * math.pi / 2, 0) * CFrame.Angles(0, 0, math.pi), Material = Enum.Material.Limestone, Color = stone })
	end
	part({ Name = "Chiave", Size = Vector3.new(7, 10, thickness + 5), CFrame = cf * CFrame.new(0, archBottom + 4, 0), Material = Enum.Material.Limestone, Color = tint(stone, 0.9) })
	part({ Name = "Camminamento", Size = Vector3.new(width + pillarW * 2, 3, thickness + 2), CFrame = cf * CFrame.new(0, height + 1.5, 0), Material = Enum.Material.Slate, Color = WALL_TOP })
	-- grande stemma sopra la porta, sulla faccia esterna
	if intact then
		emblem(cf * CFrame.new(0, archBottom + (height - archBottom) * 0.5, thickness / 2 + 2.6), 26, color)
	end
	if kind == "Open" then
		-- saracinesca sollevata: si vedono solo le punte sotto l'arco
		part({ Name = "Saracinesca", Size = Vector3.new(width - 2, 3, 1.6), CFrame = cf * CFrame.new(0, archBottom - 1.5, thickness / 2 - 3), Material = Enum.Material.CorrodedMetal, Color = IRON, CastShadow = false })
		for i = -3, 3 do
			part({ Name = "Punta", Size = Vector3.new(1.3, 4, 1.3), CFrame = cf * CFrame.new(i * (width / 7.5), archBottom - 4.5, thickness / 2 - 3), Material = Enum.Material.CorrodedMetal, Color = IRON, CastShadow = false })
		end
	elseif kind == "Closed" then
		for i = -3, 3 do
			part({ Name = "Grata", Size = Vector3.new(1.6, archBottom, 1.6), CFrame = cf * CFrame.new(i * (width / 7), archBottom / 2, -thickness / 2 + 2), Material = Enum.Material.CorrodedMetal, Color = Color3.fromRGB(70, 66, 60), CastShadow = false })
		end
		for j = 1, 3 do
			part({ Name = "GrataOrizzontale", Size = Vector3.new(width, 1.4, 1.4), CFrame = cf * CFrame.new(0, j * archBottom / 4, -thickness / 2 + 2), Material = Enum.Material.CorrodedMetal, Color = Color3.fromRGB(70, 66, 60), CastShadow = false })
		end
	elseif kind == "Boulder" then
		-- il masso che sigilla il cancello
		part({ Name = "Masso", Shape = Enum.PartType.Ball, Size = Vector3.new(66, 66, 66), CFrame = cf * CFrame.new(0, 30, -thickness / 2 - 14), Material = Enum.Material.Rock, Color = Color3.fromRGB(130, 120, 106) })
		for _ = 1, 5 do
			local s = rng:NextNumber(4, 9)
			part({ Name = "Frammento", Size = Vector3.new(s, s * 0.7, s), CFrame = cf * CFrame.new(rng:NextNumber(-width, width), s * 0.3, -thickness / 2 - rng:NextNumber(30, 55)) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, 6), rng:NextNumber(-0.6, 0.6)), Material = Enum.Material.Rock, Color = Color3.fromRGB(122, 112, 98) })
		end
	elseif kind == "Broken" then
		for _ = 1, 9 do
			local s = rng:NextNumber(6, 16)
			part({ Name = "Macerie", Size = Vector3.new(s, s * 0.7, s), CFrame = cf * CFrame.new(rng:NextNumber(-width, width), s * 0.3, rng:NextNumber(-thickness * 2, thickness * 2)) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, 6), rng:NextNumber(-0.6, 0.6)), Material = Enum.Material.Limestone, Color = tint(stone, 0.75) })
		end
	end
end

local function buildRingWall(wall, districts)
	currentGroup = group(wall.Name)
	local center0 = W.WallCenter(wall.Id)
	local radius = wall.Radius
	local segLen = 64
	local n = math.ceil(2 * math.pi * radius / segLen)
	local step = 360 / n
	local halfGate = math.deg((W.GateWidth / 2 + 16) / radius)
	local length = 2 * (radius + wall.Thickness / 2) * math.tan(math.rad(step / 2)) + 1
	local color = BANNER[wall.Id] or BANNER.Vermiglia
	for i = 0, n - 1 do
		local angle = (i + 0.5) * step
		if not angleInGate(angle, wall.Gates, halfGate + step * 0.5) then
			local nearDistrict = false
			for _, d in districts do
				if d.Wall == wall.Id and math.abs(((angle - d.Angle) + 540) % 360 - 180) < 22 then
					nearDistrict = true
				end
			end
			-- mura in rovina: alcuni tratti crollati
			local broken = wall.Ruined and rng:NextNumber() < 0.12
			if broken then
				for _ = 1, 3 do
					local s0 = rng:NextNumber(10, 22)
					part({ Name = "Macerie", Size = Vector3.new(s0 * 1.4, s0, s0), CFrame = CFrame.new(center0 + Util.Polar(angle + rng:NextNumber(-step * 0.4, step * 0.4), radius + rng:NextNumber(-20, 30), G + s0 * 0.3)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)), Material = Enum.Material.Limestone, Color = tint(pick(WALL_STONE), 0.72) })
				end
			else
				local segCenter = center0 + Util.Polar(angle, radius)
				local h = wall.Height * (if wall.Ruined then rng:NextNumber(0.55, 1) else 1)
				wallSegment(segCenter, center0, length, h, wall.Thickness, { Ruined = wall.Ruined, Cannon = i % 3 == 1 })
				-- una torre di guardia ogni tanto (non vicino a porte e distretti)
				if not wall.Ruined and not nearDistrict and i % 8 == 4 then
					local base = Vector3.new(segCenter.X, G, segCenter.Z)
					local outward = Util.SafeUnit(Util.Flat(segCenter - center0))
					wallTower(CFrame.lookAt(base, base - outward), wall.Height, wall.Thickness, color)
				end
			end
		end
	end
	for _, gateAngle in wall.Gates do
		local center = center0 + Util.Polar(gateAngle, radius)
		local outward = Util.SafeUnit(center - center0)
		-- riempi lo spazio tra il cancello e i segmenti vicini
		for _, side in { -1, 1 } do
			local a = gateAngle + side * (halfGate + step * 0.5)
			wallSegment(center0 + Util.Polar(a, radius), center0, segLen, wall.Height, wall.Thickness)
		end
		buildGate(center, outward, wall.Height, wall.Thickness, "Open", color)
	end
end

local function buildDistrictWall(d)
	local wall = W.Walls[d.Wall]
	currentGroup = group("Mura di " .. d.Name)
	local gate = W.DistrictGatePoint(d.Id)
	local outward = W.DistrictOutward(d.Id)
	local right = Vector3.new(-outward.Z, 0, outward.X)
	local rb = d.Radius
	local n = math.ceil(math.pi * rb / 56)
	local step = 180 / n
	local length = 2 * (rb + wall.Thickness / 2) * math.tan(math.rad(step / 2)) + 1
	local halfGate = math.deg((W.GateWidth / 2 + 16) / rb)
	for i = 0, n - 1 do
		local theta = -90 + (i + 0.5) * step
		if math.abs(theta) > halfGate + step * 0.5 then
			local a = math.rad(theta)
			local dir = outward * math.cos(a) + right * math.sin(a)
			local pos = gate + dir * rb
			local h = wall.Height * (if d.Ruined then rng:NextNumber(0.6, 1) else 1)
			wallSegment(pos, gate, length, h, wall.Thickness, { Ruined = d.Ruined, Cannon = i % 2 == 0 })
		end
	end
	for _, side in { -1, 1 } do
		local a = math.rad(side * (halfGate + step * 0.25))
		local dir = outward * math.cos(a) + right * math.sin(a)
		wallSegment(gate + dir * rb, gate, 40, wall.Height, wall.Thickness, { Ruined = d.Ruined })
	end
	local outerGate = gate + outward * rb
	local kind = if d.OuterGate == "Boulder" then "Boulder" elseif d.OuterGate == "Broken" then "Broken" else "Open"
	buildGate(outerGate, outward, wall.Height, wall.Thickness, kind, BANNER[d.Wall])
	if d.OuterGate == "Broken" then
		-- breccia nel muro, come il giorno della caduta
		for _ = 1, 5 do
			local s = rng:NextNumber(12, 26)
			part({ Name = "Blocco", Size = Vector3.new(s, s * 0.8, s), CFrame = CFrame.new(outerGate + outward * rng:NextNumber(-70, -20) + right * rng:NextNumber(-40, 40) + Vector3.new(0, G + s * 0.3, 0)) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6), rng:NextNumber(-0.5, 0.5)), Material = Enum.Material.Concrete, Color = PALETTE.WallDark })
		end
	end
	-- montacarichi per salire sulle mura
	local liftPos = gate - outward * 30 + right * 34
	part({ Name = "Montacarichi", Size = Vector3.new(10, 1, 10), CFrame = CFrame.new(liftPos.X, G + 0.5, liftPos.Z), Material = Enum.Material.WoodPlanks, Color = PALETTE.Wood })
	for _, s in { -1, 1 } do
		part({ Name = "Palo", Size = Vector3.new(1, wall.Height, 1), CFrame = CFrame.new(liftPos + right * (s * 5) + Vector3.new(0, G + wall.Height / 2, 0)), Material = Enum.Material.Wood, Color = PALETTE.Timber, CastShadow = false })
	end
	local liftTop = Vector3.new(gate.X, G + wall.Height + 5, gate.Z) + right * 34
	local lift = currentGroup:FindFirstChild("Montacarichi") :: BasePart?
	if lift then
		lift:SetAttribute("LiftTarget", liftTop)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Sali sulle Mura"
		prompt.ObjectText = "Montacarichi"
		prompt.HoldDuration = 0.4
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.MaxActivationDistance = 12
		prompt.Parent = lift
		CollectionService:AddTag(lift, "Montacarichi")
	end
end

-- EDIFICI ------------------------------------------------------------------------------

local function window(parentCF: CFrame, offset: Vector3, faceSize: Vector2)
	part({ Name = "Finestra", Size = Vector3.new(faceSize.X, faceSize.Y, 0.3), CFrame = parentCF * CFrame.new(offset), Material = Enum.Material.Glass, Color = Color3.fromRGB(40, 54, 66), Reflectance = 0.15, CastShadow = false })
end

local function buildHouse(cf: CFrame, width: number, depth: number, floors: number, style: string, ruined: boolean?)
	local floorH = 12
	local height = floors * floorH
	local isValdoria = style == "Valdoria"
	local wallColor = if isValdoria then pick(PALETTE.Brick) else pick(PALETTE.Plaster)
	local material = if isValdoria then Enum.Material.Brick else Enum.Material.Plaster
	if ruined then
		wallColor = Color3.new(wallColor.R * 0.7, wallColor.G * 0.68, wallColor.B * 0.66)
		height = height * rng:NextNumber(0.55, 1)
	end
	local body = part({ Name = "Casa", Size = Vector3.new(width, height, depth), CFrame = cf * CFrame.new(0, height / 2, 0), Material = material, Color = wallColor })
	CollectionService:AddTag(body, "Edificio")
	body.CollisionGroup = Config.CollisionGroups.Buildings

	-- travi a vista (stile medievale delle Mura)
	if not isValdoria then
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				part({ Name = "Trave", Size = Vector3.new(1.2, height, 1.2), CFrame = cf * CFrame.new(sx * width / 2, height / 2, sz * depth / 2), Material = Enum.Material.Wood, Color = PALETTE.Timber, CastShadow = false })
			end
		end
		for f = 1, floors - 1 do
			part({ Name = "Fascia", Size = Vector3.new(width + 0.6, 1, depth + 0.6), CFrame = cf * CFrame.new(0, f * floorH, 0), Material = Enum.Material.Wood, Color = PALETTE.Timber, CastShadow = false })
		end
	else
		part({ Name = "Cornicione", Size = Vector3.new(width + 1.2, 1.4, depth + 1.2), CFrame = cf * CFrame.new(0, height + 0.7, 0), Material = Enum.Material.Concrete, Color = Color3.fromRGB(190, 184, 170), CastShadow = false })
	end

	-- finestre su facciata e retro
	local cols = math.max(1, math.floor(width / 9))
	for f = 0, floors - 1 do
		local y = f * floorH + 7
		if y < height - 3 then
			for c = 1, cols do
				local x = -width / 2 + width * (c - 0.5) / cols
				if not (f == 0 and c == math.ceil(cols / 2)) then
					window(cf, Vector3.new(x, y, -depth / 2 - 0.1), Vector2.new(3.2, 4.4))
				end
				if rng:NextNumber() < 0.6 then
					window(cf, Vector3.new(x, y, depth / 2 + 0.1), Vector2.new(3.2, 4.4))
				end
			end
		end
	end
	-- porta
	part({ Name = "Porta", Size = Vector3.new(4.4, 8, 0.4), CFrame = cf * CFrame.new(0, 4, -depth / 2 - 0.15), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(90, 60, 40), CastShadow = false })

	-- tetto
	if not ruined or rng:NextNumber() < 0.4 then
		if isValdoria then
			part({ Name = "Tetto", Size = Vector3.new(width, 1.2, depth), CFrame = cf * CFrame.new(0, height + 0.6, 0), Material = Enum.Material.Slate, Color = Color3.fromRGB(70, 70, 74) })
		else
			local roofH = math.min(width, depth) * 0.45
			local roofColor = pick(PALETTE.Roof)
			local overhang = 2
			local roofTop = height + roofH / 2
			local w1 = wedge({ Name = "Tetto", Size = Vector3.new(width + overhang, roofH, depth / 2 + overhang / 2), CFrame = cf * CFrame.new(0, roofTop, -depth / 4 - overhang / 4), Material = Enum.Material.ClayRoofTiles, Color = roofColor })
			local w2 = wedge({ Name = "Tetto", Size = Vector3.new(width + overhang, roofH, depth / 2 + overhang / 2), CFrame = cf * CFrame.new(0, roofTop, depth / 4 + overhang / 4) * CFrame.Angles(0, math.pi, 0), Material = Enum.Material.ClayRoofTiles, Color = roofColor })
			w1.CollisionGroup = Config.CollisionGroups.Buildings
			w2.CollisionGroup = Config.CollisionGroups.Buildings
		end
		if rng:NextNumber() < 0.65 then
			part({ Name = "Comignolo", Size = Vector3.new(2.6, 8, 2.6), CFrame = cf * CFrame.new(width * 0.3, height + 4, depth * 0.15), Material = Enum.Material.Brick, Color = Color3.fromRGB(120, 70, 56), CastShadow = false })
		end
	elseif ruined then
		-- travi bruciate al posto del tetto
		for _ = 1, 3 do
			part({ Name = "TraveBruciata", Size = Vector3.new(1.2, 1.2, depth * rng:NextNumber(0.6, 1.1)), CFrame = cf * CFrame.new(rng:NextNumber(-width / 2, width / 2), height + 0.6, 0) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.4, 0.4), 0), Material = Enum.Material.Wood, Color = Color3.fromRGB(30, 24, 20), CastShadow = false })
		end
	end
end

-- Città su griglia dentro un cerchio (o semicerchio per i distretti)
local function buildTown(name: string, center: Vector3, radius: number, opts)
	currentGroup = group(name)
	local cell = opts.Cell or 34
	local forward = opts.Forward or Vector3.new(0, 0, -1)
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local halfPlane = opts.HalfPlaneOrigin
	local count = 0
	local maxCount = opts.Max or 200
	local steps = math.floor(radius / cell)
	for gx = -steps, steps do
		for gz = -steps, steps do
			if count >= maxCount then
				break
			end
			if math.abs(gx) ~= 0 and math.abs(gz) % 3 ~= 0 then
				local jitter = Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
				local pos = center + right * (gx * cell) + forward * (gz * cell) + jitter
				local inside = Util.FlatDistance(pos, center) < radius - 16
				if inside and halfPlane then
					inside = (pos - halfPlane):Dot(opts.HalfPlaneNormal) > 22
				end
				if inside and not isReserved(pos, 18) and rng:NextNumber() > (opts.Skip or 0.15) then
					local width = rng:NextNumber(cell * 0.55, cell * 0.78)
					local depth = rng:NextNumber(cell * 0.55, cell * 0.75)
					local floors = rng:NextInteger(opts.MinFloors or 2, opts.MaxFloors or 3)
					local cf = CFrame.lookAt(Vector3.new(pos.X, opts.Y or G, pos.Z), Vector3.new(pos.X, opts.Y or G, pos.Z) + forward * (if rng:NextNumber() < 0.5 then 1 else -1))
					buildHouse(cf, width, depth, floors, opts.Style or "Mura", opts.Ruined)
					count += 1
				end
			end
		end
	end
	return count
end

local function lamp(pos: Vector3, color: Color3?)
	local base = part({ Name = "Lampione", Size = Vector3.new(0.8, 12, 0.8), CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)), Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 40, 44), CastShadow = false })
	local bulb = part({ Name = "Luce", Size = Vector3.new(1.6, 1.6, 1.6), CFrame = CFrame.new(pos + Vector3.new(0, 12.5, 0)), Material = Enum.Material.Neon, Color = color or Color3.fromRGB(255, 196, 120), CastShadow = false })
	local light = Instance.new("PointLight")
	light.Range = 26
	light.Brightness = 1.6
	light.Color = color or Color3.fromRGB(255, 190, 120)
	light.Shadows = false
	light.Parent = bulb
	CollectionService:AddTag(bulb, Config.Tags.Lamp)
	return base
end

local function supplyStation(pos: Vector3, label: string?)
	local station = group("Rifornimento", currentGroup)
	local prev = currentGroup
	currentGroup = station
	local crate = part({ Name = "Cassa", Size = Vector3.new(6, 4, 4), CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)), Material = Enum.Material.WoodPlanks, Color = PALETTE.Wood })
	for i = -1, 1 do
		part({ Name = "Bombola", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4.5, 1.4, 1.4), CFrame = CFrame.new(pos + Vector3.new(i * 1.6, 6.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Metal, Color = Color3.fromRGB(150, 156, 164), Reflectance = 0.2 })
	end
	part({ Name = "Bandiera", Size = Vector3.new(0.4, 14, 0.4), CFrame = CFrame.new(pos + Vector3.new(3.5, 7, 2)), Material = Enum.Material.Wood, Color = PALETTE.Timber, CastShadow = false })
	part({ Name = "Telo", Size = Vector3.new(4, 2.6, 0.1), CFrame = CFrame.new(pos + Vector3.new(5.5, 12.5, 2)), Material = Enum.Material.Fabric, Color = Color3.fromRGB(46, 92, 58), CastShadow = false })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Rifornisci gas e lame"
	prompt.ObjectText = label or "Deposito di Rifornimento"
	prompt.HoldDuration = 0.6
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.MaxActivationDistance = 14
	prompt.Parent = crate
	CollectionService:AddTag(crate, Config.Tags.Supply)
	currentGroup = prev
end

-- ALBERI -------------------------------------------------------------------------------

local function tree(pos: Vector3, scale: number?)
	local s = scale or rng:NextNumber(0.8, 1.3)
	local h = 20 * s
	part({ Name = "Tronco", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 2.4 * s, 2.4 * s), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Wood, Color = Color3.fromRGB(96, 70, 48) })
	for i = 1, 2 do
		local size = rng:NextNumber(11, 15) * s
		part({ Name = "Chioma", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-2, 2) * s, h + (i - 1) * 4 * s, rng:NextNumber(-2, 2) * s)), Material = Enum.Material.LeafyGrass, Color = pick(PALETTE.Leaf), CastShadow = i == 1 })
	end
end

local function giantTree(pos: Vector3)
	local h = rng:NextNumber(230, 330)
	local d = rng:NextNumber(18, 30)
	local bark = Color3.fromRGB(rng:NextInteger(88, 104), rng:NextInteger(64, 76), rng:NextInteger(44, 54))
	local trunkCF = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	part({ Name = "TroncoGigante", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, d, d), CFrame = trunkCF, Material = Enum.Material.Wood, Color = bark })
	-- radici
	for i = 0, 3 do
		local a = i * math.pi / 2 + rng:NextNumber(-0.3, 0.3)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		wedge({ Name = "Radice", Size = Vector3.new(d * 0.35, d * 0.9, d * 0.9), CFrame = CFrame.lookAt(pos + dir * (d * 0.62) + Vector3.new(0, d * 0.45, 0), pos + dir * (d * 2) + Vector3.new(0, d * 0.45, 0)), Material = Enum.Material.Wood, Color = bark })
	end
	-- rami con fogliame
	local branches = rng:NextInteger(3, 5)
	for i = 1, branches do
		local y = h * rng:NextNumber(0.45, 0.85)
		local a = rng:NextNumber(0, math.pi * 2)
		local len = rng:NextNumber(45, 80)
		local dir = Vector3.new(math.cos(a), 0.45, math.sin(a)).Unit
		local start = pos + Vector3.new(0, y, 0)
		local mid = start + dir * (len / 2)
		local bd = rng:NextNumber(5, 9)
		part({ Name = "Ramo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(len, bd, bd), CFrame = CFrame.lookAt(mid, mid + dir) * CFrame.Angles(0, math.rad(90), 0), Material = Enum.Material.Wood, Color = bark })
		local tip = start + dir * len
		local leaf = rng:NextNumber(40, 64)
		part({ Name = "Fogliame", Shape = Enum.PartType.Ball, Size = Vector3.new(leaf, leaf, leaf), CFrame = CFrame.new(tip), Material = Enum.Material.LeafyGrass, Color = pick(PALETTE.Leaf), CastShadow = i <= 2 })
		if i == 1 then
			part({ Name = "Fogliame", Shape = Enum.PartType.Ball, Size = Vector3.new(leaf * 0.8, leaf * 0.8, leaf * 0.8), CFrame = CFrame.new(tip + Vector3.new(rng:NextNumber(-15, 15), 12, rng:NextNumber(-15, 15))), Material = Enum.Material.LeafyGrass, Color = pick(PALETTE.Leaf), CastShadow = false })
		end
	end
	local crown = rng:NextNumber(70, 100)
	part({ Name = "Chioma", Shape = Enum.PartType.Ball, Size = Vector3.new(crown, crown, crown), CFrame = CFrame.new(pos + Vector3.new(0, h + crown * 0.25, 0)), Material = Enum.Material.LeafyGrass, Color = pick(PALETTE.Leaf) })
end

-- LUOGHI SPECIALI ------------------------------------------------------------------------

local function zoneCenter(id: string): Vector3
	local zone = Zones.Get(id)
	return if zone then zone.Center else Vector3.zero
end

local function buildTrainingCamp()
	local c = zoneCenter("CampoAddestramento")
	currentGroup = group("Campo di Addestramento")
	-- torre di addestramento (obiettivo del tutorial)
	local towerTop = W.Landmarks.TorreAddestramento
	local towerBase = Vector3.new(towerTop.X, G, towerTop.Z)
	local towerH = towerTop.Y - G - 4
	part({ Name = "Torre", Size = Vector3.new(14, towerH, 14), CFrame = CFrame.new(towerBase + Vector3.new(0, towerH / 2, 0)), Material = Enum.Material.WoodPlanks, Color = PALETTE.Wood })
	part({ Name = "PiattaformaTorre", Size = Vector3.new(26, 2, 26), CFrame = CFrame.new(towerBase + Vector3.new(0, towerH + 1, 0)), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(130, 96, 64) })
	part({ Name = "BandieraTorre", Size = Vector3.new(0.6, 18, 0.6), CFrame = CFrame.new(towerBase + Vector3.new(10, towerH + 11, 10)), Material = Enum.Material.Wood, Color = PALETTE.Timber })
	part({ Name = "TeloTorre", Size = Vector3.new(7, 4.4, 0.15), CFrame = CFrame.new(towerBase + Vector3.new(13.6, towerH + 17, 10)), Material = Enum.Material.Fabric, Color = Color3.fromRGB(190, 160, 90) })
	-- pali per allenarsi con i rampini
	for i = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(30, 75)
		local pos = towerBase + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if not isReserved(pos, 8) then
			local h = rng:NextNumber(45, 80)
			part({ Name = "PaloAddestramento", Size = Vector3.new(3, h, 3), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)), Material = Enum.Material.Wood, Color = PALETTE.Timber })
		end
	end
	-- baracche
	for i = 0, 2 do
		local pos = c + Vector3.new(60, 0, 20 + i * 26)
		local cf = CFrame.lookAt(Vector3.new(pos.X, G, pos.Z), Vector3.new(pos.X - 10, G, pos.Z))
		buildHouse(cf, 36, 16, 1, "Mura")
	end
	-- recinto e bandiere del campo
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local pos = c + Vector3.new(math.cos(a) * 112, 0, math.sin(a) * 112)
		part({ Name = "Steccato", Size = Vector3.new(1, 6, 26), CFrame = CFrame.lookAt(pos + Vector3.new(0, 3, 0), c + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.rad(90), 0), Material = Enum.Material.Wood, Color = PALETTE.Wood, CastShadow = false })
	end
	supplyStation(c + Vector3.new(12, 0, 32))
	lamp(c + Vector3.new(-8, 0, 10))
	lamp(c + Vector3.new(8, 0, -40))
end

local function buildHQ()
	local c = zoneCenter("QuartierGenerale")
	currentGroup = group("Quartier Generale")
	local back = c + Vector3.new(0, 0, -48)
	-- castello del Corpo dei Falchi
	part({ Name = "Mastio", Size = Vector3.new(56, 46, 30), CFrame = CFrame.new(back + Vector3.new(0, 23, 0)), Material = Enum.Material.Cobblestone, Color = PALETTE.Stone })
	for _, sx in { -1, 1 } do
		part({ Name = "TorreCastello", Shape = Enum.PartType.Cylinder, Size = Vector3.new(66, 18, 18), CFrame = CFrame.new(back + Vector3.new(sx * 30, 33, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Cobblestone, Color = PALETTE.Stone })
		wedge({ Name = "TettoTorre", Size = Vector3.new(19, 12, 9.5), CFrame = CFrame.new(back + Vector3.new(sx * 30, 72, -4.75)), Material = Enum.Material.Slate, Color = Color3.fromRGB(70, 74, 86) })
		wedge({ Name = "TettoTorre", Size = Vector3.new(19, 12, 9.5), CFrame = CFrame.new(back + Vector3.new(sx * 30, 72, 4.75)) * CFrame.Angles(0, math.pi, 0), Material = Enum.Material.Slate, Color = Color3.fromRGB(70, 74, 86) })
	end
	part({ Name = "Stendardo", Size = Vector3.new(12, 18, 0.2), CFrame = CFrame.new(back + Vector3.new(0, 30, -15.2)), Material = Enum.Material.Fabric, Color = Color3.fromRGB(46, 92, 58) })
	supplyStation(c + Vector3.new(30, 0, 22))
	lamp(c + Vector3.new(-30, 0, -10))
	lamp(c + Vector3.new(30, 0, -10))
end

local function buildTents(c: Vector3, count: number, radius: number)
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local pos = c + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		if not isReserved(pos, 6) then
			local cf = CFrame.lookAt(Vector3.new(pos.X, G, pos.Z), Vector3.new(c.X, G, c.Z))
			wedge({ Name = "Tenda", Size = Vector3.new(9, 7, 5), CFrame = cf * CFrame.new(0, 3.5, -2.5), Material = Enum.Material.Fabric, Color = Color3.fromRGB(196, 186, 160) })
			wedge({ Name = "Tenda", Size = Vector3.new(9, 7, 5), CFrame = cf * CFrame.new(0, 3.5, 2.5) * CFrame.Angles(0, math.pi, 0), Material = Enum.Material.Fabric, Color = Color3.fromRGB(186, 176, 150) })
		end
	end
end

local function buildCastle()
	local c = zoneCenter("Ostrava")
	currentGroup = group("Castello di Ostrava")
	part({ Name = "TorreMaestra", Shape = Enum.PartType.Cylinder, Size = Vector3.new(110, 34, 34), CFrame = CFrame.new(c + Vector3.new(0, 55, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(150, 146, 138) })
	part({ Name = "Merlatura", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 38, 38), CFrame = CFrame.new(c + Vector3.new(0, 112, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(140, 136, 128) })
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		if i ~= 3 then
			local pos = c + Vector3.new(math.cos(a) * 58, 0, math.sin(a) * 58)
			local h = rng:NextNumber(16, 34)
			part({ Name = "MuraCastello", Size = Vector3.new(36, h, 8), CFrame = CFrame.lookAt(pos + Vector3.new(0, h / 2, 0), c + Vector3.new(0, h / 2, 0)), Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(146, 142, 134) })
		end
	end
	lamp(c + Vector3.new(80, 0, 30), Color3.fromRGB(255, 160, 90))
end

local function buildVillage(id: string, houses: number)
	local zone = Zones.Get(id)
	if not zone then
		return
	end
	currentGroup = group(zone.Name)
	for _ = 1, houses do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(20, zone.Radius * 0.75)
		local pos = zone.Center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if not isReserved(pos, 16) then
			local cf = CFrame.lookAt(Vector3.new(pos.X, G, pos.Z), Vector3.new(zone.Center.X, G, zone.Center.Z))
			buildHouse(cf, rng:NextNumber(16, 24), rng:NextNumber(14, 20), rng:NextInteger(1, 2), "Mura")
		end
	end
	-- mulino a vento (le pale girano grazie al client)
	local mill = zone.Center + Vector3.new(zone.Radius * 0.5, 0, -zone.Radius * 0.4)
	part({ Name = "Mulino", Size = Vector3.new(14, 34, 14), CFrame = CFrame.new(mill + Vector3.new(0, 17, 0)), Material = Enum.Material.Plaster, Color = pick(PALETTE.Plaster) })
	local hub = part({ Name = "Pale", Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(mill + Vector3.new(0, 30, -8)), Material = Enum.Material.Wood, Color = PALETTE.Timber })
	local sails = Instance.new("Model")
	sails.Name = "PaleMulino"
	sails.Parent = currentGroup
	hub.Parent = sails
	for i = 0, 3 do
		local blade = part({ Name = "Pala", Size = Vector3.new(3, 26, 0.4), CFrame = hub.CFrame * CFrame.Angles(0, 0, i * math.pi / 2) * CFrame.new(0, 13, 0), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(210, 196, 170), CastShadow = false, Parent = sails })
		blade.Parent = sails
	end
	sails.PrimaryPart = hub
	CollectionService:AddTag(sails, Config.Tags.Spinner)
end

local function buildPalace()
	currentGroup = group("Palazzo Reale")
	local aurea = W.IslandCenter("Aurea")
	local c = aurea + Vector3.new(0, G, -40)
	part({ Name = "Palazzo", Size = Vector3.new(110, 52, 70), CFrame = CFrame.new(c + Vector3.new(0, 26, 0)), Material = Enum.Material.Marble, Color = Color3.fromRGB(232, 226, 214) })
	part({ Name = "Cupola", Shape = Enum.PartType.Ball, Size = Vector3.new(46, 46, 46), CFrame = CFrame.new(c + Vector3.new(0, 56, 0)), Material = Enum.Material.Metal, Color = Color3.fromRGB(150, 170, 160), Reflectance = 0.1 })
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part({ Name = "TorrePalazzo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(80, 16, 16), CFrame = CFrame.new(c + Vector3.new(sx * 58, 40, sz * 38)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Marble, Color = Color3.fromRGB(226, 220, 206) })
			part({ Name = "Pinnacolo", Size = Vector3.new(10, 14, 10), CFrame = CFrame.new(c + Vector3.new(sx * 58, 87, sz * 38)), Material = Enum.Material.Slate, Color = Color3.fromRGB(60, 70, 90) })
		end
	end
	-- colonnato
	for i = -4, 4 do
		part({ Name = "Colonna", Shape = Enum.PartType.Cylinder, Size = Vector3.new(30, 4, 4), CFrame = CFrame.new(c + Vector3.new(i * 11, 15, 40)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Marble, Color = Color3.fromRGB(240, 236, 228) })
	end
	part({ Name = "Frontone", Size = Vector3.new(104, 6, 10), CFrame = CFrame.new(c + Vector3.new(0, 33, 40)), Material = Enum.Material.Marble, Color = Color3.fromRGB(236, 230, 220) })
	-- piazza con fontana
	local plaza = aurea + Vector3.new(0, G, 120)
	part({ Name = "Fontana", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 24, 24), CFrame = CFrame.new(plaza + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Marble, Color = Color3.fromRGB(220, 214, 200) })
	part({ Name = "Acqua", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 21, 21), CFrame = CFrame.new(plaza + Vector3.new(0, 2.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Glass, Color = Color3.fromRGB(80, 150, 190), Transparency = 0.3, CastShadow = false })
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		lamp(plaza + Vector3.new(math.cos(a) * 40, 0, math.sin(a) * 40))
	end
	supplyStation(aurea + Vector3.new(20, G, 164))
end

local function buildLift(npcId: string)
	local npc = NPCs.Get(npcId)
	if not npc then
		return
	end
	local zone = Zones.Get(npc.Zone)
	if not zone then
		return
	end
	local pos = zone.Center + npc.Offset
	local y = zone.Center.Y
	part({ Name = "PiattaformaAscensore", Size = Vector3.new(12, 1, 12), CFrame = CFrame.new(pos.X, y + 0.5, pos.Z), Material = Enum.Material.DiamondPlate, Color = Color3.fromRGB(90, 90, 96) })
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part({ Name = "Catena", Size = Vector3.new(0.6, 40, 0.6), CFrame = CFrame.new(pos.X + sx * 5.5, y + 20, pos.Z + sz * 5.5), Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 60, 64), CastShadow = false })
		end
	end
end

local function buildUnderground()
	carveCave("CittaSotterranea", Enum.Material.Rock)
	carveCave("CavernaCristallo", Enum.Material.Slate)
	local city = W.Underground.CittaSotterranea
	local floorY = city.Center.Y - city.Size.Y / 2
	currentGroup = group("Citta Sotterranea")
	local c = Vector3.new(city.Center.X, floorY, city.Center.Z)
	buildTown("Case Sotterranee", c, 190, { Y = floorY, Cell = 30, Skip = 0.25, MinFloors = 2, MaxFloors = 4, Max = 60 })
	currentGroup = group("Lanterne Sotterranee")
	for _ = 1, 26 do
		local pos = c + Vector3.new(rng:NextNumber(-180, 180), 0, rng:NextNumber(-180, 180))
		lamp(pos, Color3.fromRGB(255, 170, 90))
	end
	supplyStation(c + Vector3.new(-18, 0, 150))

	local cave = W.Underground.CavernaCristallo
	local cFloor = cave.Center.Y - cave.Size.Y / 2
	currentGroup = group("Cristalli")
	for _ = 1, 45 do
		local pos = Vector3.new(cave.Center.X + rng:NextNumber(-170, 170), cFloor, cave.Center.Z + rng:NextNumber(-170, 170))
		if Util.FlatDistance(pos, cave.Center + Vector3.new(0, 0, 155)) > 30 then
			local h = rng:NextNumber(10, 34)
			local crystal = part({ Name = "Cristallo", Size = Vector3.new(h * 0.3, h, h * 0.3), CFrame = CFrame.new(pos + Vector3.new(0, h * 0.4, 0)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)), Material = Enum.Material.Glass, Color = Color3.fromRGB(140, 220, 255), Transparency = 0.25, CastShadow = false })
			if rng:NextNumber() < 0.4 then
				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(140, 220, 255)
				light.Range = 30
				light.Brightness = 1.2
				light.Parent = crystal
			end
		end
	end
	supplyStation(Vector3.new(cave.Center.X + 18, cFloor, cave.Center.Z + 150))
end

local function buildPort(id: string, toward: Vector3, withShip: boolean)
	local zone = Zones.Get(id)
	if not zone then
		return
	end
	currentGroup = group(zone.Name)
	local c = zone.Center
	local dir = Util.SafeUnit(Util.Flat(toward - c))
	local right = Vector3.new(-dir.Z, 0, dir.X)
	-- molo di legno verso il mare
	for i = 0, 9 do
		local pos = c + dir * (40 + i * 12)
		part({ Name = "Molo", Size = Vector3.new(14, 1.4, 12.4), CFrame = CFrame.lookAt(Vector3.new(pos.X, G - 1, pos.Z), Vector3.new(pos.X, G - 1, pos.Z) + dir), Material = Enum.Material.WoodPlanks, Color = PALETTE.Wood })
		for _, s in { -1, 1 } do
			part({ Name = "PaloMolo", Size = Vector3.new(1.2, 14, 1.2), CFrame = CFrame.new(pos + right * (s * 6.5) + Vector3.new(0, -6, 0)), Material = Enum.Material.Wood, Color = PALETTE.Timber, CastShadow = false })
		end
	end
	if withShip then
		local shipPos = c + dir * 120 + right * 20
		local shipCF = CFrame.lookAt(Vector3.new(shipPos.X, W.WaterY + 3, shipPos.Z), Vector3.new(shipPos.X, W.WaterY + 3, shipPos.Z) + right)
		part({ Name = "Scafo", Size = Vector3.new(18, 8, 60), CFrame = shipCF, Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(100, 70, 46) })
		wedge({ Name = "Prua", Size = Vector3.new(18, 8, 14), CFrame = shipCF * CFrame.new(0, 0, -37) * CFrame.Angles(0, math.pi, 0), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(100, 70, 46) })
		part({ Name = "Ponte", Size = Vector3.new(17, 0.6, 72), CFrame = shipCF * CFrame.new(0, 4.2, -4), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(150, 116, 78) })
		for i, z in { -14, 12 } do
			local mastH = 48 - i * 6
			part({ Name = "Albero", Size = Vector3.new(1.6, mastH, 1.6), CFrame = shipCF * CFrame.new(0, 4 + mastH / 2, z), Material = Enum.Material.Wood, Color = PALETTE.Timber })
			part({ Name = "Vela", Size = Vector3.new(16, mastH * 0.55, 0.3), CFrame = shipCF * CFrame.new(0, 4 + mastH * 0.6, z + 1), Material = Enum.Material.Fabric, Color = Color3.fromRGB(236, 230, 214), CastShadow = false })
		end
	end
	-- magazzini
	for i = -1, 1, 2 do
		local pos = c - dir * 30 + right * (i * 40)
		buildHouse(CFrame.lookAt(Vector3.new(pos.X, G, pos.Z), Vector3.new(pos.X, G, pos.Z) + dir), 24, 18, 2, if id == "PortoRevelia" then "Valdoria" else "Mura")
	end
	supplyStation(c - dir * 10 + right * 18)
	lamp(c + dir * 30 + right * 8)
	lamp(c + dir * 30 - right * 8)
end

-- Pontile con barca sulla costa di ogni isola, nella direzione del suo centro abitato
local function buildFerryDocks()
	for _, id in W.IslandOrder do
		local isl = W.Islands[id]
		local hub = Zones.Get(isl.Hub)
		if hub and not isl.Raid then
			currentGroup = group("Traghetto di " .. isl.Name)
			local dir = Util.SafeUnit(Util.Flat(hub.Center - isl.Center), Vector3.new(0, 0, 1))
			local right = Vector3.new(-dir.Z, 0, dir.X)
			local shore = isl.Center + dir * (isl.Land - 10)
			for i = 0, 7 do
				local pos = shore + dir * (i * 12)
				part({ Name = "Pontile", Size = Vector3.new(12, 1.4, 12.4), CFrame = CFrame.lookAt(Vector3.new(pos.X, G - 1, pos.Z), Vector3.new(pos.X, G - 1, pos.Z) + dir), Material = Enum.Material.WoodPlanks, Color = PALETTE.Wood })
				for _, side in { -1, 1 } do
					part({ Name = "PaloPontile", Size = Vector3.new(1.2, 14, 1.2), CFrame = CFrame.new(pos + right * (side * 5.5) + Vector3.new(0, -6, 0)), Material = Enum.Material.Wood, Color = PALETTE.Timber, CastShadow = false })
				end
			end
			-- traghetto ormeggiato
			local boatPos = shore + dir * 70 + right * 16
			local boatCF = CFrame.lookAt(Vector3.new(boatPos.X, W.WaterY + 2, boatPos.Z), Vector3.new(boatPos.X, W.WaterY + 2, boatPos.Z) + dir)
			part({ Name = "ScafoTraghetto", Size = Vector3.new(12, 5, 32), CFrame = boatCF, Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(96, 66, 44) })
			wedge({ Name = "PruaTraghetto", Size = Vector3.new(12, 5, 8), CFrame = boatCF * CFrame.new(0, 0, -20) * CFrame.Angles(0, math.pi, 0), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(96, 66, 44) })
			part({ Name = "AlberoTraghetto", Size = Vector3.new(1.2, 26, 1.2), CFrame = boatCF * CFrame.new(0, 15, 0), Material = Enum.Material.Wood, Color = PALETTE.Timber })
			part({ Name = "VelaTraghetto", Size = Vector3.new(11, 14, 0.3), CFrame = boatCF * CFrame.new(0, 18, 1), Material = Enum.Material.Fabric, Color = Color3.fromRGB(196, 60, 52), CastShadow = false })
			lamp(shore - dir * 6 + right * 8)
		end
	end
end

-- Isola dell'Arena: un anfiteatro di pietra dove si combattono i raid
local function buildArena()
	local isl = W.Islands.Arena
	local zone = Zones.Get("ArenaRaid")
	if not isl or not zone then
		return
	end
	currentGroup = group("Arena dei Raid")
	local c = Vector3.new(isl.Center.X, G, isl.Center.Z)
	workspace.Terrain:FillCylinder(CFrame.new(c.X, G - 2, c.Z), 4, 250, Enum.Material.Sand)
	local radius = 285
	local n = 40
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local pos = c + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		local length = 2 * radius * math.tan(math.pi / n) + 1
		local gate = i % 10 == 0
		local h = if gate then 30 else 70
		part({ Name = if gate then "Arco" else "Gradinata", Size = Vector3.new(length, h, 22), CFrame = CFrame.lookAt(pos + Vector3.new(0, if gate then 55 else h / 2, 0), c + Vector3.new(0, if gate then 55 else h / 2, 0)), Material = Enum.Material.Sandstone, Color = Color3.fromRGB(206, 180, 140) })
		if not gate then
			-- gradoni verso l'interno
			for step = 1, 3 do
				local inner = c + Vector3.new(math.cos(a) * (radius - 11 - step * 9), 0, math.sin(a) * (radius - 11 - step * 9))
				part({ Name = "Gradone", Size = Vector3.new(length * 0.97, 70 - step * 18, 9), CFrame = CFrame.lookAt(inner + Vector3.new(0, (70 - step * 18) / 2, 0), c + Vector3.new(0, (70 - step * 18) / 2, 0)), Material = Enum.Material.Sandstone, Color = Color3.fromRGB(190, 164, 126), CastShadow = false })
			end
		end
		if i % 4 == 0 then
			local torch = part({ Name = "Braciere", Size = Vector3.new(4, 4, 4), CFrame = CFrame.new(pos + Vector3.new(0, 74, 0)), Material = Enum.Material.CorrodedMetal, Color = Color3.fromRGB(60, 50, 44) })
			local fire = Instance.new("Fire")
			fire.Size = 8
			fire.Heat = 10
			fire.Parent = torch
		end
	end
	-- obelisco centrale e piattaforma di arrivo dei combattenti
	part({ Name = "Obelisco", Size = Vector3.new(10, 60, 10), CFrame = CFrame.new(c + Vector3.new(0, 30, 0)), Material = Enum.Material.Marble, Color = Color3.fromRGB(226, 220, 206) })
	part({ Name = "PiattaformaRaid", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 40, 40), CFrame = CFrame.new(c + Vector3.new(0, 1, 200)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Slate, Color = Color3.fromRGB(110, 104, 96) })
	supplyStation(c + Vector3.new(30, 0, 210))
	supplyStation(c + Vector3.new(-30, 0, 210))
	-- pali per i rampini dentro l'arena
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2
		local pos = c + Vector3.new(math.cos(a) * 150, 0, math.sin(a) * 150)
		part({ Name = "Colonna", Size = Vector3.new(6, 90, 6), CFrame = CFrame.new(pos + Vector3.new(0, 45, 0)), Material = Enum.Material.Sandstone, Color = Color3.fromRGB(214, 190, 150) })
	end
end

local function buildFortress()
	local zone = Zones.Get("Fortezza")
	if not zone then
		return
	end
	currentGroup = group("Fortezza di Vael")
	local c = zone.Center
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		if i ~= 6 then
			local pos = c + Vector3.new(math.cos(a) * 120, 0, math.sin(a) * 120)
			part({ Name = "MuraFortezza", Size = Vector3.new(66, 60, 14), CFrame = CFrame.lookAt(pos + Vector3.new(0, 30, 0), c + Vector3.new(0, 30, 0)), Material = Enum.Material.Concrete, Color = Color3.fromRGB(120, 122, 126) })
		end
	end
	part({ Name = "Laboratorio", Size = Vector3.new(70, 44, 54), CFrame = CFrame.new(c + Vector3.new(0, 22, 0)), Material = Enum.Material.Concrete, Color = Color3.fromRGB(96, 100, 106) })
	part({ Name = "Ciminiera", Shape = Enum.PartType.Cylinder, Size = Vector3.new(80, 12, 12), CFrame = CFrame.new(c + Vector3.new(26, 40, 18)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Brick, Color = Color3.fromRGB(110, 70, 60) })
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local tank = part({ Name = "VascaSiero", Shape = Enum.PartType.Cylinder, Size = Vector3.new(16, 8, 8), CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 60, 8, math.sin(a) * 60)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Glass, Color = Color3.fromRGB(110, 230, 140), Transparency = 0.3, CastShadow = false })
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(110, 230, 140)
		light.Range = 24
		light.Parent = tank
	end
end

local function buildRumbleFront()
	local zone = Zones.Get("FronteMarcia")
	if not zone then
		return
	end
	currentGroup = group("Fronte della Grande Marcia")
	local c = zone.Center
	-- costole gigantesche di colossali caduti
	for i = 1, 6 do
		local pos = c + Vector3.new(rng:NextNumber(-170, 170), 0, rng:NextNumber(-170, 170))
		if not isReserved(pos, 20) then
			local h = rng:NextNumber(60, 120)
			part({ Name = "Costola", Size = Vector3.new(8, h, 8), CFrame = CFrame.new(pos + Vector3.new(0, h * 0.4, 0)) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6), rng:NextNumber(0.3, 0.7)), Material = Enum.Material.Marble, Color = Color3.fromRGB(226, 216, 196) })
		end
	end
	for _ = 1, 10 do
		local pos = c + Vector3.new(rng:NextNumber(-200, 200), 0, rng:NextNumber(-200, 200))
		local ember = part({ Name = "Brace", Size = Vector3.new(4, 1, 4), CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0)), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 110, 40), CastShadow = false })
		local fire = Instance.new("Fire")
		fire.Size = 12
		fire.Heat = 14
		fire.Color = Color3.fromRGB(255, 120, 50)
		fire.SecondaryColor = Color3.fromRGB(255, 200, 80)
		fire.Parent = ember
	end
end

local function buildTrenches()
	local zone = Zones.Get("Trincee")
	if not zone then
		return
	end
	currentGroup = group("Trincee di Valdoria")
	local c = zone.Center
	for i = -2, 2 do
		for j = -6, 6 do
			local pos = c + Vector3.new(j * 22, 0, i * 55 - 7)
			if not isReserved(pos, 6) then
				part({ Name = "SacchiSabbia", Size = Vector3.new(20, 3, 3), CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0)), Material = Enum.Material.Fabric, Color = Color3.fromRGB(150, 130, 96) })
			end
		end
	end
	for _ = 1, 30 do
		local pos = c + Vector3.new(rng:NextNumber(-160, 160), 0, rng:NextNumber(-160, 160))
		part({ Name = "FiloSpinato", Size = Vector3.new(0.4, 4, 0.4), CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)), Material = Enum.Material.CorrodedMetal, Color = Color3.fromRGB(80, 70, 60), CastShadow = false })
	end
end

local function buildRecinto()
	local zone = Zones.Get("Recinto")
	if not zone then
		return
	end
	currentGroup = group("Recinto dei Giganti")
	local c = zone.Center
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local pos = c + Vector3.new(math.cos(a) * 88, 0, math.sin(a) * 88)
		part({ Name = "PaloRecinto", Size = Vector3.new(2.4, 26, 2.4), CFrame = CFrame.new(pos + Vector3.new(0, 13, 0)), Material = Enum.Material.Wood, Color = PALETTE.Timber })
	end
	for i = 0, 23 do
		local a = (i + 0.5) / 24 * math.pi * 2
		local pos = c + Vector3.new(math.cos(a) * 88, 0, math.sin(a) * 88)
		part({ Name = "Traversa", Size = Vector3.new(1, 1, 23.4), CFrame = CFrame.lookAt(pos + Vector3.new(0, 18, 0), c + Vector3.new(0, 18, 0)) * CFrame.Angles(0, math.rad(90), 0), Material = Enum.Material.Wood, Color = PALETTE.Wood, CastShadow = false })
	end
	-- torrette di osservazione
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + 0.4
		local pos = c + Vector3.new(math.cos(a) * 100, 0, math.sin(a) * 100)
		part({ Name = "Torretta", Size = Vector3.new(8, 40, 8), CFrame = CFrame.new(pos + Vector3.new(0, 20, 0)), Material = Enum.Material.WoodPlanks, Color = PALETTE.Wood })
	end
end

local function buildForest()
	local zone = Zones.Get("Foresta")
	if not zone then
		return
	end
	currentGroup = group("Foresta degli Alberi Giganti")
	local placed = {}
	local attempts = 0
	while #placed < 60 and attempts < 600 do
		attempts += 1
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber()) * (zone.Radius + 10)
		local pos = zone.Center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local ok = not isReserved(pos, 30)
		for _, other in placed do
			if Util.FlatDistance(other, pos) < 52 then
				ok = false
				break
			end
		end
		if ok then
			table.insert(placed, pos)
			giantTree(Vector3.new(pos.X, G, pos.Z))
		end
	end
	-- sottobosco
	for _ = 1, 50 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber()) * zone.Radius
		local pos = zone.Center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if not isReserved(pos, 6) then
			tree(Vector3.new(pos.X, G, pos.Z), rng:NextNumber(0.6, 1))
		end
	end
end

local function scatterTrees()
	currentGroup = group("Alberi")
	for _, id in W.IslandOrder do
		local isl = W.Islands[id]
		if not isl.Raid then
			local wall = nil
			for _, w in W.Walls do
				if w.Island == id then
					wall = w
				end
			end
			local count = 0
			local attempts = 0
			local target = math.floor(isl.Land / 12)
			while count < target and attempts < target * 8 do
				attempts += 1
				local r = rng:NextNumber(60, isl.Land - 40)
				local pos = isl.Center + Util.Polar(rng:NextNumber(0, 360), r)
				local probe = Vector3.new(pos.X, G, pos.Z)
				local nearWall = wall ~= nil and math.abs(r - wall.Radius) < 32
				local insideCapital = id == "Aurea" and wall ~= nil and r < wall.Radius
				local zone = Zones.Find(probe)
				local blockedByZone = zone ~= nil and (zone.Safe or zone.Id == "Calaneth" or zone.Id == "Halvar" or zone.Id == "Recinto" or zone.Id == "Foresta" or zone.Id == "Stohlberg")
				if not nearWall and not insideCapital and not blockedByZone and not isReserved(probe, 10) then
					-- piccoli boschetti
					local clump = rng:NextInteger(1, 4)
					for _ = 1, clump do
						tree(probe + Vector3.new(rng:NextNumber(-14, 14), 0, rng:NextNumber(-14, 14)))
					end
					count += 1
				end
			end
		end
	end
end

local function buildBoundaries()
	currentGroup = group("Confini")
	local function ring(center: Vector3, radius: number)
		local n = 48
		for i = 0, n - 1 do
			local a = (i + 0.5) / n * math.pi * 2
			local pos = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
			local length = 2 * radius * math.tan(math.pi / n) + 2
			part({ Name = "Confine", Size = Vector3.new(length, 400, 4), CFrame = CFrame.lookAt(pos + Vector3.new(0, 150, 0), center + Vector3.new(0, 150, 0)), Transparency = 1, CanQuery = false, CastShadow = false })
		end
	end
	for _, id in W.IslandOrder do
		local isl = W.Islands[id]
		ring(isl.Center, isl.Water - 20)
	end
end

local function reserveAreas()
	table.clear(reserved)
	for _, npc in NPCs.List do
		local zone = Zones.Get(npc.Zone)
		if zone then
			table.insert(reserved, { Pos = zone.Center + npc.Offset, Radius = 12 })
		end
	end
	for _, zone in Zones.List do
		if zone.Safe then
			table.insert(reserved, { Pos = zone.Center, Radius = 26 })
		end
	end
	for _, pos in W.Landmarks do
		table.insert(reserved, { Pos = pos, Radius = 18 })
	end
	-- strade principali tra i cancelli
	local aurea = W.IslandCenter("Aurea")
	table.insert(reserved, { Pos = aurea + Vector3.new(0, 0, 120), Radius = 44 }) -- piazza di Aurion
	table.insert(reserved, { Pos = aurea + Vector3.new(0, 0, -40), Radius = 75 }) -- palazzo
	for id in W.Districts do
		local gate = W.DistrictGatePoint(id)
		table.insert(reserved, { Pos = gate, Radius = 36 })
	end
end

local function setupCollisionGroups()
	local groups = Config.CollisionGroups
	for _, name in { groups.Players, groups.TitanForm, groups.Buildings, groups.NPC, groups.Debris } do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(name)
		end)
	end
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(groups.Players, groups.Players, false)
		PhysicsService:CollisionGroupSetCollidable(groups.Players, groups.NPC, false)
		PhysicsService:CollisionGroupSetCollidable(groups.TitanForm, groups.Buildings, false)
		PhysicsService:CollisionGroupSetCollidable(groups.TitanForm, groups.NPC, false)
		PhysicsService:CollisionGroupSetCollidable(groups.Debris, groups.Players, false)
		PhysicsService:CollisionGroupSetCollidable(groups.Debris, groups.NPC, false)
	end)
end

-- COSTRUZIONE COMPLETA --------------------------------------------------------------------

-- Pavimento solido sotto ogni isola: se il terreno non si genera, nessuno cade nel vuoto
local function buildIslandBases()
	currentGroup = group("Basi delle Isole")
	for _, id in W.IslandOrder do
		local isl = W.Islands[id]
		local diameter = math.min(2040, isl.Land * 2)
		part({
			Name = "Base_" .. id,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(6, diameter, diameter),
			CFrame = CFrame.new(isl.Center.X, G - 4, isl.Center.Z) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Grass,
			Color = Color3.fromRGB(96, 140, 72),
			CastShadow = false,
		})
	end
end

-- Esegue un passo della costruzione: se fallisce, lo segnala e continua con gli altri
local function step(name: string, fn: () -> ())
	local t = os.clock()
	local ok, err = xpcall(fn, debug.traceback)
	if ok then
		print(("[WorldBuilder] %s ✓ (%.1fs)"):format(name, os.clock() - t))
	else
		warn(("[WorldBuilder] ERRORE in '%s': %s"):format(name, tostring(err)))
	end
end

function WorldBuilder.Build()
	local existing = workspace:FindFirstChild(Config.Folders.Map)
	if existing then
		return existing
	end
	local t0 = os.clock()
	rng = Random.new(Config.WorldSeed)
	partCount = 0
	setupCollisionGroups()
	reserveAreas()

	-- la cartella va subito nel mondo: la mappa compare man mano che viene costruita
	mapFolder = Instance.new("Folder")
	mapFolder.Name = Config.Folders.Map
	mapFolder.Parent = workspace

	step("Basi delle isole", buildIslandBases)
	step("Terreno", buildTerrain)
	step("Mura", function()
		for _, id in W.WallOrder do
			buildRingWall(W.Walls[id], W.Districts)
		end
		for _, d in W.Districts do
			buildDistrictWall(d)
		end
	end)
	step("Città di Aurion", function()
		buildTown("Aurion", W.IslandCenter("Aurea") + Vector3.new(0, G, 0), W.Walls.Aurea.Radius - 20, { Cell = 36, Skip = 0.12, MinFloors = 2, MaxFloors = 4, Max = 110 })
	end)
	step("Distretti", function()
		for id, d in W.Districts do
			local gate = W.DistrictGatePoint(id)
			local outward = W.DistrictOutward(id)
			buildTown(d.Name, gate, d.Radius, {
				Forward = outward,
				HalfPlaneOrigin = gate,
				HalfPlaneNormal = outward,
				Cell = 32,
				Skip = if d.Ruined then 0.3 else 0.12,
				Ruined = d.Ruined,
				MinFloors = 2,
				MaxFloors = 3,
				Max = 60,
			})
			currentGroup = group(d.Name .. " - Rifornimento")
			if not d.Ruined then
				supplyStation(gate + outward * 24 + Vector3.new(-outward.Z, 0, outward.X) * 22 + Vector3.new(0, G, 0))
			end
		end
	end)
	step("Palazzo Reale", buildPalace)
	step("Campo di Addestramento", buildTrainingCamp)
	step("Quartier Generale", buildHQ)
	step("Recinto", buildRecinto)
	step("Castello di Ostrava", buildCastle)
	step("Villaggio di Brenn", function()
		buildVillage("Brenn", 14)
	end)
	step("Foresta", buildForest)
	step("Accampamenti", function()
		currentGroup = group("Accampamenti")
		buildTents(zoneCenter("Avamposto"), 8, 34)
		buildTents(zoneCenter("AccampamentoEdenia"), 7, 30)
		supplyStation(zoneCenter("Avamposto") + Vector3.new(24, 0, -14))
		supplyStation(zoneCenter("AccampamentoEdenia") + Vector3.new(-26, 0, -12))
		local halvarZone = Zones.Get("Halvar")
		if halvarZone then
			supplyStation(halvarZone.Center + Vector3.new(30, 0, -70))
		end
		supplyStation(zoneCenter("PianaOrvel") + Vector3.new(24, 0, 120))
	end)
	step("Ingresso della caverna", function()
		currentGroup = group("Ingresso Caverna")
		local caveMouth = W.Landmarks.IngressoCaverna
		for i = 0, 5 do
			local a = math.rad(-60 + i * 24)
			part({ Name = "RocciaIngresso", Size = Vector3.new(16, 22 + i % 2 * 8, 14), CFrame = CFrame.new(caveMouth + Vector3.new(math.sin(a) * 20, 8, math.cos(a) * 12)) * CFrame.Angles(0, a, 0.2), Material = Enum.Material.Slate, Color = Color3.fromRGB(80, 84, 92) })
		end
	end)
	step("Ascensori", function()
		buildLift("AscensoreAurion")
		buildLift("AscensoreSotto")
		buildLift("UscitaCaverna")
	end)
	step("Sottosuolo", buildUnderground)
	step("Porti", function()
		buildPort("PortoOrientale", W.IslandCenter("Valdoria"), true)
		buildPort("PortoRevelia", W.IslandCenter("Vermiglia"), true)
	end)
	step("Traghetti", buildFerryDocks)
	step("Arena dei raid", buildArena)
	step("Revelia", function()
		local revelia = Zones.Get("Revelia")
		if revelia then
			buildTown("Distretto di Revelia", revelia.Center, revelia.Radius, { Cell = 34, Skip = 0.15, Style = "Valdoria", MinFloors = 3, MaxFloors = 5, Max = 70 })
		end
	end)
	step("Trincee", buildTrenches)
	step("Fortezza", buildFortress)
	step("Fronte della Grande Marcia", buildRumbleFront)
	step("Alberi", scatterTrees)
	step("Confini", buildBoundaries)

	print(("[WorldBuilder] Mappa generata: %d parti in %.1fs"):format(partCount, os.clock() - t0))
	return mapFolder
end

function WorldBuilder.WaitReady()
	if WorldBuilder.Ready then
		return
	end
	WorldBuilder.ReadySignal:Wait()
end

local function ensureFolders()
	for key, name in Config.Folders do
		if key ~= "Map" and not workspace:FindFirstChild(name) then
			local folder = Instance.new("Folder")
			folder.Name = name
			folder.Parent = workspace
		end
	end
end

function WorldBuilder.Init(_services)
	ensureFolders()
end

function WorldBuilder.Start()
	if RunService:IsRunning() then
		setupCollisionGroups()
		local ok, err = pcall(WorldBuilder.Build)
		if not ok then
			warn("[WorldBuilder] Errore durante la generazione della mappa: " .. tostring(err))
		end
	end
	WorldBuilder.Ready = true
	WorldBuilder.ReadySignal:Fire()
end

return WorldBuilder
