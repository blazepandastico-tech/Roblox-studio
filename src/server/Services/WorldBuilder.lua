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
local HttpService = game:GetService("HttpService")
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
	Roof = { Color3.fromRGB(168, 78, 52), Color3.fromRGB(150, 66, 46), Color3.fromRGB(176, 92, 60), Color3.fromRGB(128, 70, 52), Color3.fromRGB(140, 84, 62) },
	Slate = { Color3.fromRGB(74, 76, 84), Color3.fromRGB(64, 66, 72), Color3.fromRGB(86, 84, 88) },
	GroundStone = { Color3.fromRGB(170, 162, 146), Color3.fromRGB(158, 150, 136), Color3.fromRGB(180, 172, 156) },
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

-- vero se il punto è lontano (almeno margin) da tutte le zone e dai luoghi riservati
local function openLand(pos: Vector3, margin: number): boolean
	for _, zone in Zones.List do
		if not zone.Underground and Util.FlatDistance(pos, zone.Center) < zone.Radius + margin then
			return false
		end
	end
	return not isReserved(pos, margin)
end

-- quota del terreno in un punto (le colline ondulate non sono più a quota G)
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
local function groundAt(pos: Vector3): Vector3
	groundParams.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(pos.X, G + 80, pos.Z), Vector3.new(0, -140, 0), groundParams)
	return Vector3.new(pos.X, if hit then hit.Position.Y else G, pos.Z)
end

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
					terrain:FillBall(Vector3.new(pos.X, G - radius * 0.62, pos.Z), radius, Enum.Material.Grass)
					if rng:NextNumber() < 0.3 then
						-- affioramento di roccia sulla cima: massi grigi che bucano l'erba
						local top = Vector3.new(pos.X, G + radius * 0.38, pos.Z)
						for _ = 1, rng:NextInteger(3, 5) do
							local rs = rng:NextNumber(0.1, 0.2) * radius
							local off = Util.Polar(rng:NextNumber(0, 360), rng:NextNumber(0, radius * 0.4))
							terrain:FillBall(top + off - Vector3.new(0, rs * 0.5 + off.Magnitude * 0.25, 0), rs, Enum.Material.Rock)
						end
					end
				end
			end
		end
	end
	pause()

	-- Prati ondulati (dossi larghi e bassi) e massi sparsi: il terreno non è più un disco piatto.
	-- Lontano da zone, mura, spiagge e luoghi riservati, così niente finisce sepolto.
	for _, id in W.IslandOrder do
		local isl = W.Islands[id]
		if not isl.Raid then
			local wallR = wallRadiusOf(id)
			for _ = 1, 46 do
				local r = rng:NextNumber(60, isl.Land - 60)
				local pos = isl.Center + Util.Polar(rng:NextNumber(0, 360), r)
				local radius = rng:NextNumber(70, 150)
				local rise = rng:NextNumber(2.5, 6.5)
				local foot = math.sqrt(rise * (2 * radius - rise))
				local probe = Vector3.new(pos.X, G, pos.Z)
				local clearOfWall = not wallR or math.abs(r - wallR) > foot + 50
				if clearOfWall and r < isl.Land - foot - 20 and openLand(probe, foot + 20) then
					terrain:FillBall(Vector3.new(pos.X, G - radius + rise, pos.Z), radius, if id == "Cenere" then Enum.Material.Ground else Enum.Material.Grass)
				end
			end
			for _ = 1, 30 do
				local r = rng:NextNumber(60, isl.Land - 30)
				local pos = isl.Center + Util.Polar(rng:NextNumber(0, 360), r)
				local size = rng:NextNumber(2.5, 7)
				local probe = Vector3.new(pos.X, G, pos.Z)
				local clearOfWall = not wallR or math.abs(r - wallR) > 40
				if clearOfWall and openLand(probe, 12) then
					terrain:FillBall(Vector3.new(pos.X, G - size * 0.35, pos.Z), size, Enum.Material.Rock)
					if rng:NextNumber() < 0.5 then
						local s2 = size * rng:NextNumber(0.4, 0.7)
						terrain:FillBall(Vector3.new(pos.X, G - s2 * 0.3, pos.Z) + Util.Polar(rng:NextNumber(0, 360), size * 0.9), s2, Enum.Material.Rock)
					end
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
		local boulder = cf * CFrame.new(0, 30, -thickness / 2 - 14)
		local rockColor = Color3.fromRGB(130, 120, 106)
		part({ Name = "Masso", Shape = Enum.PartType.Ball, Size = Vector3.new(66, 66, 66), CFrame = boulder, Material = Enum.Material.Rock, Color = rockColor })
		-- bozze irregolari (non è una sfera perfetta), muschio in cima e terra alla base
		for _ = 1, 6 do
			local s = rng:NextNumber(28, 42)
			local dir = Util.SafeUnit(Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.4, 1), rng:NextNumber(-1, 0.3)), Vector3.yAxis)
			part({ Name = "Masso", Shape = Enum.PartType.Ball, Size = Vector3.one * s, CFrame = boulder * CFrame.new(dir * (33 - s * 0.32)), Material = Enum.Material.Rock, Color = tint(rockColor, rng:NextNumber(0.84, 1.08)) })
		end
		part({ Name = "Muschio", Shape = Enum.PartType.Ball, Size = Vector3.one * 44, CFrame = boulder * CFrame.new(0, 13, -2), Material = Enum.Material.Grass, Color = Color3.fromRGB(98, 106, 62), CastShadow = false })
		part({ Name = "Terra", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 70, 70), CFrame = cf * CFrame.new(0, -1.6, -thickness / 2 - 14) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Ground, Color = Color3.fromRGB(104, 90, 70), CastShadow = false })
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

local SHUTTERS = { Color3.fromRGB(62, 92, 64), Color3.fromRGB(58, 76, 104), Color3.fromRGB(110, 62, 44), Color3.fromRGB(86, 64, 46) }
local FLOWERS = { Color3.fromRGB(196, 52, 60), Color3.fromRGB(230, 190, 60), Color3.fromRGB(176, 90, 190), Color3.fromRGB(236, 236, 236) }

-- Finestra di facciata: cornice, vetro, davanzale e (a volte) persiane aperte e fiori.
-- side = -1 facciata (-Z), +1 retro (+Z)
local function facadeWindow(cf: CFrame, x: number, y: number, side: number, depth: number, valdoria: boolean, rich: boolean)
	local z = side * (depth / 2)
	local w, h = 3.2, if valdoria then 5.6 else 4.4
	local frameColor = if valdoria then Color3.fromRGB(214, 206, 190) else PALETTE.Timber
	if rich then
		part({ Name = "Cornice", Size = Vector3.new(w + 0.9, h + 0.9, 0.25), CFrame = cf * CFrame.new(x, y, z + side * 0.08), Material = if valdoria then Enum.Material.Limestone else Enum.Material.Wood, Color = frameColor, CastShadow = false, CanCollide = false })
	end
	part({ Name = "Finestra", Size = Vector3.new(w, h, 0.3), CFrame = cf * CFrame.new(x, y, z + side * 0.12), Material = Enum.Material.Glass, Color = Color3.fromRGB(40, 54, 66), Reflectance = 0.15, CastShadow = false })
	if not rich then
		return
	end
	part({ Name = "Davanzale", Size = Vector3.new(w + 1.4, 0.4, 0.9), CFrame = cf * CFrame.new(x, y - h / 2 - 0.4, z + side * 0.45), Material = if valdoria then Enum.Material.Limestone else Enum.Material.Wood, Color = frameColor, CastShadow = false, CanCollide = false })
	if valdoria then
		-- architrave di pietra sopra la finestra
		part({ Name = "Architrave", Size = Vector3.new(w + 1.6, 0.8, 0.6), CFrame = cf * CFrame.new(x, y + h / 2 + 0.7, z + side * 0.3), Material = Enum.Material.Limestone, Color = frameColor, CastShadow = false, CanCollide = false })
		return
	end
	local roll = rng:NextNumber()
	if roll < 0.45 then
		local color = pick(SHUTTERS)
		for _, s in { -1, 1 } do
			part({ Name = "Persiana", Size = Vector3.new(w / 2 + 0.2, h + 0.4, 0.2), CFrame = cf * CFrame.new(x + s * (w * 0.75 + 0.55), y, z + side * 0.2), Material = Enum.Material.WoodPlanks, Color = color, CastShadow = false, CanCollide = false })
		end
	elseif roll < 0.65 then
		part({ Name = "Fioriera", Size = Vector3.new(w + 0.6, 0.9, 0.9), CFrame = cf * CFrame.new(x, y - h / 2 - 0.1, z + side * 0.8), Material = Enum.Material.Wood, Color = Color3.fromRGB(96, 66, 44), CastShadow = false, CanCollide = false })
		part({ Name = "Fiori", Size = Vector3.new(w + 0.4, 0.8, 0.8), CFrame = cf * CFrame.new(x, y - h / 2 + 0.6, z + side * 0.8), Material = Enum.Material.Grass, Color = pick(FLOWERS), CastShadow = false, CanCollide = false })
	end
end

local furnishRoom: (CFrame, number, number, number, number, string, number) -> ()

-- opts.Enterable: il piano terra è una stanza vera (porta aperta, pareti, mobili) in cui si entra
-- opts.Kind: "Casa" | "Caserma" | "Taverna" (cambia l'arredamento)
local function buildHouse(cf: CFrame, width: number, depth: number, floors: number, style: string, ruined: boolean?, opts: { [string]: any }?)
	local floorH = 12
	local height = floors * floorH
	local isValdoria = style == "Valdoria"
	local wallColor = if isValdoria then pick(PALETTE.Brick) else pick(PALETTE.Plaster)
	local material = if isValdoria then Enum.Material.Brick else Enum.Material.Plaster
	if ruined then
		wallColor = Color3.new(wallColor.R * 0.7, wallColor.G * 0.68, wallColor.B * 0.66)
		height = height * rng:NextNumber(0.55, 1)
	end
	local enterable = opts ~= nil and opts.Enterable == true and not ruined and width >= 14 and depth >= 12
	local cols = math.max(1, math.floor(width / 9))
	local doorX = if cols % 2 == 1 then 0 else -width / 2 + width * (math.ceil(cols / 2) - 0.5) / cols
	-- zoccolo di pietra alla base (nelle case aperte è basso: è il pavimento)
	local plinthH = if enterable then 1.2 elseif isValdoria then 4 else 2.4
	if enterable then
		local T = 0.8
		local wallTop = if floors >= 2 then floorH else height
		local wallH = wallTop - plinthH
		local wy = plinthH + wallH / 2
		local walls = {}
		local function wall(name: string, size: Vector3, pos: Vector3)
			local w = part({ Name = name, Size = size, CFrame = cf * CFrame.new(pos), Material = material, Color = wallColor })
			CollectionService:AddTag(w, "Edificio")
			w.CollisionGroup = Config.CollisionGroups.Buildings
			table.insert(walls, w)
		end
		wall("Casa", Vector3.new(width, wallH, T), Vector3.new(0, wy, depth / 2 - T / 2))
		wall("Casa", Vector3.new(T, wallH, depth - 2 * T), Vector3.new(-width / 2 + T / 2, wy, 0))
		wall("Casa", Vector3.new(T, wallH, depth - 2 * T), Vector3.new(width / 2 - T / 2, wy, 0))
		-- facciata con il vano della porta
		local doorW, doorH = 5.2, 8.6
		local leftW = (doorX - doorW / 2) + width / 2
		local rightW = width / 2 - (doorX + doorW / 2)
		if leftW > 0.2 then
			wall("Casa", Vector3.new(leftW, wallH, T), Vector3.new(-width / 2 + leftW / 2, wy, -depth / 2 + T / 2))
		end
		if rightW > 0.2 then
			wall("Casa", Vector3.new(rightW, wallH, T), Vector3.new(width / 2 - rightW / 2, wy, -depth / 2 + T / 2))
		end
		local lintelH = wallTop - (plinthH + doorH)
		if lintelH > 0.2 then
			wall("Casa", Vector3.new(doorW, lintelH, T), Vector3.new(doorX, plinthH + doorH + lintelH / 2, -depth / 2 + T / 2))
		end
		if floors >= 2 then
			-- piani superiori pieni (sopra la stanza)
			wall("Casa", Vector3.new(width, height - floorH, depth), Vector3.new(0, floorH + (height - floorH) / 2, 0))
		else
			part({ Name = "Soffitto", Size = Vector3.new(width - 2 * T, 0.6, depth - 2 * T), CFrame = cf * CFrame.new(0, height - 0.3, 0), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(110, 80, 54), CastShadow = false })
		end
		-- pavimento di legno
		part({ Name = "Pavimento", Size = Vector3.new(width - 2 * T, 0.2, depth - 2 * T), CFrame = cf * CFrame.new(0, plinthH + 0.1, 0), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(128, 92, 62), CastShadow = false })
		local ok, err = pcall(furnishRoom, cf, width - 2 * T, depth - 2 * T, plinthH + 0.2, wallTop, (opts :: any).Kind or "Casa", doorX)
		if not ok then
			warn("[WorldBuilder] Arredamento: " .. tostring(err))
		end
	else
		local body = part({ Name = "Casa", Size = Vector3.new(width, height, depth), CFrame = cf * CFrame.new(0, height / 2, 0), Material = material, Color = wallColor })
		CollectionService:AddTag(body, "Edificio")
		body.CollisionGroup = Config.CollisionGroups.Buildings
	end

	part({ Name = "Zoccolo", Size = Vector3.new(width + 0.8, plinthH, depth + 0.8), CFrame = cf * CFrame.new(0, plinthH / 2, 0), Material = Enum.Material.Cobblestone, Color = if isValdoria then Color3.fromRGB(150, 144, 134) else Color3.fromRGB(132, 126, 116), CastShadow = false })

	-- molte case a graticcio hanno il piano terra in pietra e i piani di sopra intonacati
	local stoneBase = not isValdoria and not enterable and not ruined and floors >= 2 and rng:NextNumber() < 0.45
	if stoneBase then
		part({ Name = "PianoTerra", Size = Vector3.new(width + 0.2, floorH - plinthH, depth + 0.2), CFrame = cf * CFrame.new(0, plinthH + (floorH - plinthH) / 2, 0), Material = Enum.Material.Limestone, Color = pick(PALETTE.GroundStone), CastShadow = false })
	elseif not enterable then
		-- umidità che risale dal terreno: l'intonaco è più scuro alla base
		part({ Name = "Umidita", Size = Vector3.new(width + 0.12, 2.4, depth + 0.12), CFrame = cf * CFrame.new(0, plinthH + 1.2, 0), Material = material, Color = tint(wallColor, 0.84), CastShadow = false, CanCollide = false })
	end

	if not isValdoria then
		-- travi a vista: montanti agli angoli, fasce ai piani e croci di Sant'Andrea in facciata
		local beamFrom = if stoneBase then floorH else 0
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				part({ Name = "Trave", Size = Vector3.new(1.2, height - beamFrom, 1.2), CFrame = cf * CFrame.new(sx * width / 2, beamFrom + (height - beamFrom) / 2, sz * depth / 2), Material = Enum.Material.Wood, Color = PALETTE.Timber, CastShadow = false })
			end
		end
		if not ruined and floors >= 2 then
			-- montanti in facciata tra le colonne di finestre dei piani alti
			for c = 1, cols - 1 do
				local x = -width / 2 + width * c / cols
				part({ Name = "Montante", Size = Vector3.new(0.8, height - floorH, 0.5), CFrame = cf * CFrame.new(x, floorH + (height - floorH) / 2, -depth / 2 - 0.15), Material = Enum.Material.Wood, Color = PALETTE.Timber, CastShadow = false, CanCollide = false })
			end
		end
		for f = 1, floors - 1 do
			if f * floorH < height - 2 then
				part({ Name = "Fascia", Size = Vector3.new(width + 0.6, 1, depth + 0.6), CFrame = cf * CFrame.new(0, f * floorH, 0), Material = Enum.Material.Wood, Color = PALETTE.Timber, CastShadow = false })
			end
		end
		if not ruined and floors >= 2 then
			local y0 = floorH
			local panel = math.min(floorH, height - y0)
			local diag = math.sqrt((width * 0.22) ^ 2 + panel ^ 2)
			local angle = math.atan2(width * 0.22, panel)
			for _, s in { -1, 1 } do
				part({ Name = "Croce", Size = Vector3.new(0.8, diag, 0.5), CFrame = cf * CFrame.new(s * width * 0.36, y0 + panel / 2, -depth / 2 - 0.15) * CFrame.Angles(0, 0, s * angle), Material = Enum.Material.Wood, Color = PALETTE.Timber, CastShadow = false, CanCollide = false })
			end
		end
	else
		part({ Name = "Cornicione", Size = Vector3.new(width + 1.2, 1.4, depth + 1.2), CFrame = cf * CFrame.new(0, height + 0.7, 0), Material = Enum.Material.Concrete, Color = Color3.fromRGB(190, 184, 170), CastShadow = false })
		for f = 1, floors - 1 do
			part({ Name = "Marcapiano", Size = Vector3.new(width + 0.5, 0.7, depth + 0.5), CFrame = cf * CFrame.new(0, f * floorH, 0), Material = Enum.Material.Limestone, Color = Color3.fromRGB(206, 198, 182), CastShadow = false })
		end
		-- balcone con ringhiera al primo piano
		if not ruined and floors >= 2 and rng:NextNumber() < 0.45 then
			part({ Name = "Balcone", Size = Vector3.new(width * 0.4, 0.8, 3), CFrame = cf * CFrame.new(0, floorH + 0.4, -depth / 2 - 1.5), Material = Enum.Material.Limestone, Color = Color3.fromRGB(200, 192, 176) })
			part({ Name = "Ringhiera", Size = Vector3.new(width * 0.4, 3, 0.25), CFrame = cf * CFrame.new(0, floorH + 2.3, -depth / 2 - 2.9), Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 40, 42), CastShadow = false, CanCollide = false })
		end
	end

	-- finestre su facciata (con cornice) e retro (solo vetro)
	for f = 0, floors - 1 do
		local y = f * floorH + 7
		if y < height - 3 then
			for c = 1, cols do
				local x = -width / 2 + width * (c - 0.5) / cols
				if not (f == 0 and c == math.ceil(cols / 2)) then
					facadeWindow(cf, x, y, -1, depth, isValdoria, not ruined)
					if enterable and f == 0 then
						-- la luce del giorno che entra dalla finestra (vista da dentro)
						part({ Name = "LuceFinestra", Size = Vector3.new(3, 4.2, 0.1), CFrame = cf * CFrame.new(x, y, -depth / 2 + 0.85), Material = Enum.Material.Glass, Color = Color3.fromRGB(196, 218, 236), Transparency = 0.25, CastShadow = false, CanCollide = false })
					end
				end
				if rng:NextNumber() < 0.6 then
					facadeWindow(cf, x, y, 1, depth, isValdoria, false)
				end
			end
		end
	end
	-- porta con stipiti, architrave e gradino (nelle case aperte il vano è libero)
	if not enterable then
		part({ Name = "Porta", Size = Vector3.new(4.4, 8, 0.4), CFrame = cf * CFrame.new(doorX, plinthH / 2 + 4, -depth / 2 - 0.15), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(90, 60, 40), CastShadow = false })
	end
	local jambMaterial = if isValdoria then Enum.Material.Limestone else Enum.Material.Wood
	local jambColor = if isValdoria then Color3.fromRGB(214, 206, 190) else PALETTE.Timber
	if enterable then
		-- stipiti e architrave attorno al vano aperto
		for _, sx in { -1, 1 } do
			part({ Name = "Stipite", Size = Vector3.new(0.7, 9.2, 1.1), CFrame = cf * CFrame.new(doorX + sx * 2.95, plinthH + 4.6, -depth / 2 + 0.3), Material = jambMaterial, Color = jambColor, CastShadow = false })
		end
		part({ Name = "Architrave", Size = Vector3.new(6.6, 0.8, 1.1), CFrame = cf * CFrame.new(doorX, plinthH + 9, -depth / 2 + 0.3), Material = jambMaterial, Color = jambColor, CastShadow = false })
	else
		part({ Name = "Stipite", Size = Vector3.new(5.8, 9.2, 0.3), CFrame = cf * CFrame.new(doorX, plinthH / 2 + 4.6, -depth / 2 - 0.05), Material = jambMaterial, Color = jambColor, CastShadow = false, CanCollide = false })
	end
	part({ Name = "Gradino", Size = Vector3.new(6, 0.8, 2), CFrame = cf * CFrame.new(doorX, 0.4, -depth / 2 - 1), Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(140, 134, 124) })
	if not ruined and rng:NextNumber() < 0.5 then
		local lantern = part({ Name = "Lanterna", Size = Vector3.new(0.8, 1.2, 0.8), CFrame = cf * CFrame.new(doorX + 3.8, plinthH / 2 + 8, -depth / 2 - 0.7), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 196, 120), CastShadow = false, CanCollide = false })
		local light = Instance.new("PointLight")
		light.Range = 14
		light.Brightness = 1.2
		light.Color = Color3.fromRGB(255, 186, 110)
		light.Shadows = false
		light.Parent = lantern
		CollectionService:AddTag(lantern, Config.Tags.Lamp)
	end

	-- tetto
	if not ruined or rng:NextNumber() < 0.4 then
		if isValdoria then
			part({ Name = "Tetto", Size = Vector3.new(width, 1.2, depth), CFrame = cf * CFrame.new(0, height + 0.6, 0), Material = Enum.Material.Slate, Color = Color3.fromRGB(70, 70, 74) })
			part({ Name = "Parapetto", Size = Vector3.new(width + 1.2, 2.2, 0.8), CFrame = cf * CFrame.new(0, height + 2.5, -depth / 2 - 0.2), Material = Enum.Material.Limestone, Color = Color3.fromRGB(196, 188, 172), CastShadow = false })
		else
			local roofH = math.min(width, depth) * 0.45
			local slate = rng:NextNumber() < 0.28
			local roofColor = if slate then pick(PALETTE.Slate) else pick(PALETTE.Roof)
			local roofMat = if slate then Enum.Material.Slate else Enum.Material.ClayRoofTiles
			local eave, gableOh, slabT = 1.8, 1.2, 0.9
			local run = depth / 2
			-- sottotetto: i timpani sono muro come la casa (non tegole)
			for _, side in { -1, 1 } do
				local g = wedge({ Name = "Timpano", Size = Vector3.new(width, roofH, run), CFrame = cf * CFrame.new(0, height + roofH / 2, side * depth / 4) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0), Material = material, Color = wallColor })
				g.CollisionGroup = Config.CollisionGroups.Buildings
			end
			-- falde vere, con lo spessore, che sporgono oltre i muri (gronda davanti e dietro, timpani ai lati)
			local theta = math.atan2(roofH, run)
			local slabLen = math.sqrt(run * run + roofH * roofH) + eave / math.cos(theta) + 0.4
			local down = Vector3.new(0, -math.sin(theta), -math.cos(theta))
			local normal = Vector3.new(0, math.cos(theta), -math.sin(theta))
			local ridge = Vector3.new(0, height + roofH, 0)
			local slabCF = CFrame.fromMatrix(ridge + down * (slabLen / 2 - 0.4) + normal * (slabT / 2), Vector3.xAxis, normal)
			for _, side in { -1, 1 } do
				local slab = part({ Name = "Tetto", Size = Vector3.new(width + gableOh * 2, slabT, slabLen), CFrame = cf * CFrame.Angles(0, if side > 0 then math.pi else 0, 0) * slabCF, Material = roofMat, Color = roofColor })
				slab.CollisionGroup = Config.CollisionGroups.Buildings
			end
			-- colmo
			part({ Name = "Colmo", Size = Vector3.new(width + gableOh * 2 + 0.3, 0.9, 1.5), CFrame = cf * CFrame.new(0, height + roofH + slabT * math.cos(theta) + 0.15, 0), Material = roofMat, Color = tint(roofColor, 0.8), CastShadow = false })
			if not isValdoria and not ruined then
				-- catena e monaco di legno sui timpani
				for _, sx in { -1, 1 } do
					part({ Name = "Catena", Size = Vector3.new(0.5, 0.9, depth + 0.6), CFrame = cf * CFrame.new(sx * (width / 2 + 0.25), height + 0.45, 0), Material = Enum.Material.Wood, Color = PALETTE.Timber, CastShadow = false, CanCollide = false })
					part({ Name = "Monaco", Size = Vector3.new(0.5, roofH * 0.9, 0.8), CFrame = cf * CFrame.new(sx * (width / 2 + 0.25), height + roofH * 0.45, 0), Material = Enum.Material.Wood, Color = PALETTE.Timber, CastShadow = false, CanCollide = false })
				end
				-- abbaino sulla falda davanti (solo le case larghe)
				if width >= 16 and depth >= 12 and rng:NextNumber() < 0.45 then
					local dw = 5.2
					local dx = rng:NextNumber(-width * 0.22, width * 0.22)
					local zf = -run + 1.2
					local bottom = height + roofH * (1 - math.abs(zf) / run) - 0.3
					local dh = 4.2
					local back = -1
					local dd = back - zf
					local zc = (zf + back) / 2
					part({ Name = "Abbaino", Size = Vector3.new(dw, dh, dd), CFrame = cf * CFrame.new(dx, bottom + dh / 2, zc), Material = material, Color = wallColor })
					part({ Name = "Cornice", Size = Vector3.new(3.3, 3.2, 0.25), CFrame = cf * CFrame.new(dx, bottom + 2.2, zf - 0.05), Material = Enum.Material.Wood, Color = PALETTE.Timber, CastShadow = false, CanCollide = false })
					part({ Name = "Finestra", Size = Vector3.new(2.6, 2.6, 0.3), CFrame = cf * CFrame.new(dx, bottom + 2.2, zf - 0.12), Material = Enum.Material.Glass, Color = Color3.fromRGB(40, 54, 66), Reflectance = 0.15, CastShadow = false })
					for _, sx in { -1, 1 } do
						wedge({ Name = "TettoAbbaino", Size = Vector3.new(dd + 0.8, 1.7, dw / 2 + 0.5), CFrame = cf * CFrame.new(dx + sx * (dw / 2 + 0.5) / 2, bottom + dh + 0.85, zc - 0.4) * CFrame.Angles(0, -sx * math.pi / 2, 0), Material = roofMat, Color = roofColor })
					end
				end
				-- macchie di muschio sulle tegole più vecchie
				if not slate and rng:NextNumber() < 0.4 then
					local mossCF = cf * CFrame.Angles(0, if rng:NextNumber() < 0.5 then math.pi else 0, 0) * slabCF
					part({ Name = "Muschio", Size = Vector3.new(rng:NextNumber(3, width * 0.4), 0.2, rng:NextNumber(2, 4)), CFrame = mossCF * CFrame.new(rng:NextNumber(-width * 0.3, width * 0.3), slabT / 2 + 0.05, slabLen * rng:NextNumber(-0.05, 0.35)), Material = Enum.Material.Grass, Color = Color3.fromRGB(96, 104, 58), CastShadow = false, CanCollide = false })
				end
			end
		end
		if rng:NextNumber() < 0.65 then
			-- il comignolo deve uscire bene dalla falda (che ora ha lo spessore)
			local chimneyH = if isValdoria then 6 else math.max(8, math.min(width, depth) * 0.34 + 4.5)
			local chimneyY = height + chimneyH / 2
			part({ Name = "Comignolo", Size = Vector3.new(2.6, chimneyH, 2.6), CFrame = cf * CFrame.new(width * 0.3, chimneyY, depth * 0.15), Material = Enum.Material.Brick, Color = Color3.fromRGB(120, 70, 56), CastShadow = false })
			part({ Name = "CappelloComignolo", Size = Vector3.new(3.3, 0.6, 3.3), CFrame = cf * CFrame.new(width * 0.3, chimneyY + chimneyH / 2 + 0.3, depth * 0.15), Material = Enum.Material.Slate, Color = Color3.fromRGB(70, 66, 62), CastShadow = false })
		end
	elseif ruined then
		-- travi bruciate al posto del tetto
		for _ = 1, 3 do
			part({ Name = "TraveBruciata", Size = Vector3.new(1.2, 1.2, depth * rng:NextNumber(0.6, 1.1)), CFrame = cf * CFrame.new(rng:NextNumber(-width / 2, width / 2), height + 0.6, 0) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.4, 0.4), 0), Material = Enum.Material.Wood, Color = Color3.fromRGB(30, 24, 20), CastShadow = false })
		end
	end
end

-- INTERNI: arredamento delle stanze in cui si entra -----------------------------------------------

local RUGS = { Color3.fromRGB(140, 46, 40), Color3.fromRGB(60, 86, 120), Color3.fromRGB(150, 120, 60), Color3.fromRGB(90, 60, 100) }
local BLANKETS = { Color3.fromRGB(150, 50, 46), Color3.fromRGB(70, 100, 70), Color3.fromRGB(70, 80, 130), Color3.fromRGB(170, 140, 90) }
local FURNITURE = Color3.fromRGB(122, 86, 56)

local function warmLight(p: BasePart, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Range = range
	light.Brightness = brightness
	light.Color = Color3.fromRGB(255, 184, 110)
	light.Shadows = false
	light.Parent = p
end

furnishRoom = function(cf: CFrame, w: number, d: number, floorY: number, ceilY: number, kind: string, doorX: number)
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, floorY + y, z)
	end
	local function piece(name: string, size: Vector3, x: number, y: number, z: number, material: Enum.Material, color: Color3, collide: boolean?)
		return part({ Name = name, Size = size, CFrame = at(x, y, z), Material = material, Color = color, CastShadow = false, CanCollide = collide ~= false })
	end
	local function tableWithStools(x: number, z: number, round: boolean)
		if round then
			part({ Name = "Tavolo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3.4, 3.4), CFrame = at(x, 2.9, z) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Wood, Color = FURNITURE, CastShadow = false })
			piece("GambaTavolo", Vector3.new(0.5, 2.75, 0.5), x, 1.375, z, Enum.Material.Wood, PALETTE.Timber)
			for i = 0, 2 do
				local a = i / 3 * math.pi * 2 + 0.4
				piece("Sgabello", Vector3.new(1.1, 1.7, 1.1), x + math.cos(a) * 2.5, 0.85, z + math.sin(a) * 2.5, Enum.Material.Wood, PALETTE.Wood)
			end
		else
			piece("Tavolo", Vector3.new(4.4, 0.3, 2.8), x, 2.9, z, Enum.Material.Wood, FURNITURE)
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					piece("GambaTavolo", Vector3.new(0.3, 2.75, 0.3), x + sx * 1.9, 1.375, z + sz * 1.1, Enum.Material.Wood, PALETTE.Timber)
				end
				piece("Sgabello", Vector3.new(1.2, 1.7, 1.2), x + sx * 2.9, 0.85, z, Enum.Material.Wood, PALETTE.Wood)
			end
		end
	end
	local function ceilingLamp(x: number, z: number, range: number)
		local h = ceilY - floorY
		piece("Catena", Vector3.new(0.15, 1.2, 0.15), x, h - 0.6, z, Enum.Material.Metal, Color3.fromRGB(50, 46, 44), false)
		local bulb = piece("Lume", Vector3.new(0.9, 0.9, 0.9), x, h - 1.6, z, Enum.Material.Neon, Color3.fromRGB(255, 206, 140), false)
		warmLight(bulb, range, 1.1)
	end
	local function fireplace(x: number, z: number, width: number)
		piece("Camino", Vector3.new(width, 6.5, 1.8), x, 3.25, z, Enum.Material.Brick, Color3.fromRGB(130, 80, 62))
		piece("BoccaCamino", Vector3.new(width * 0.55, 2.6, 0.3), x, 1.4, z - 0.85, Enum.Material.Slate, Color3.fromRGB(26, 22, 20), false)
		local ember = piece("Brace", Vector3.new(width * 0.4, 0.5, 0.6), x, 0.4, z - 0.75, Enum.Material.Neon, Color3.fromRGB(255, 120, 40), false)
		warmLight(ember, 18, 1.4)
		piece("Mensola", Vector3.new(width + 0.6, 0.4, 2.2), x, 6.7, z - 0.2, Enum.Material.Wood, PALETTE.Timber)
	end
	local function barrel(x: number, z: number)
		part({ Name = "Botte", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, 2.2, 2.2), CFrame = at(x, 1.3, z) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Wood, Color = Color3.fromRGB(108, 74, 46), CastShadow = false })
	end
	local function bed(x: number, z: number, bunk: boolean)
		piece("Letto", Vector3.new(3.4, 1.4, 6.6), x, 0.7, z, Enum.Material.Wood, PALETTE.Wood)
		piece("Materasso", Vector3.new(3, 0.6, 6.2), x, 1.7, z, Enum.Material.Fabric, Color3.fromRGB(226, 218, 200), false)
		piece("Coperta", Vector3.new(3.1, 0.3, 3.8), x, 2.1, z - 1.1, Enum.Material.Fabric, pick(BLANKETS), false)
		piece("Cuscino", Vector3.new(2.2, 0.5, 1.1), x, 2.2, z + 2.4, Enum.Material.Fabric, Color3.fromRGB(240, 236, 226), false)
		if bunk then
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					piece("PaloBranda", Vector3.new(0.35, 6.4, 0.35), x + sx * 1.55, 3.2, z + sz * 3.1, Enum.Material.Wood, PALETTE.Timber)
				end
			end
			piece("BrandaAlta", Vector3.new(3.4, 0.5, 6.6), x, 4.6, z, Enum.Material.Wood, PALETTE.Wood)
			piece("MaterassoAlto", Vector3.new(3, 0.5, 6.2), x, 5.1, z, Enum.Material.Fabric, Color3.fromRGB(226, 218, 200), false)
			piece("CopertaAlta", Vector3.new(3.1, 0.3, 3.8), x, 5.45, z - 1.1, Enum.Material.Fabric, Color3.fromRGB(70, 92, 66), false)
		end
	end

	if kind == "Taverna" then
		-- bancone lungo la parete sinistra, con l'oste dietro
		piece("Bancone", Vector3.new(1.8, 3.4, 10), -w / 2 + 4.4, 1.7, 1, Enum.Material.WoodPlanks, Color3.fromRGB(96, 64, 42))
		piece("PianoBancone", Vector3.new(2.3, 0.3, 10.4), -w / 2 + 4.4, 3.55, 1, Enum.Material.Wood, Color3.fromRGB(150, 106, 66))
		for i = 0, 1 do
			piece("Scaffale", Vector3.new(1.2, 0.25, 9), -w / 2 + 0.6, 4.6 + i * 2.2, 1, Enum.Material.Wood, PALETTE.Timber)
			for b = 0, 6 do
				local bottle = part({ Name = "Bottiglia", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.1, 0.5, 0.5), CFrame = at(-w / 2 + 0.6, 5.3 + i * 2.2, -3 + b * 1.3) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Glass, Color = pick({ Color3.fromRGB(60, 120, 60), Color3.fromRGB(120, 50, 40), Color3.fromRGB(170, 130, 50), Color3.fromRGB(70, 90, 140) }), Transparency = 0.15, CastShadow = false, CanCollide = false })
				bottle.Reflectance = 0.1
			end
		end
		barrel(-w / 2 + 1.7, d / 2 - 1.6)
		barrel(-w / 2 + 4.2, d / 2 - 1.4)
		fireplace(0, d / 2 - 1, 7)
		part({ Name = "Tappeto", Size = Vector3.new(10, 0.1, 14), CFrame = at(4, 0.05, -1), Material = Enum.Material.Fabric, Color = pick(RUGS), CastShadow = false, CanCollide = false })
		for _, t in { { 2.5, -5 }, { 8.5, -5 }, { 2.5, 3.5 }, { 8.5, 3.5 } } do
			tableWithStools(t[1], t[2], true)
		end
		ceilingLamp(-2, -3, 22)
		ceilingLamp(6, 4, 22)
	elseif kind == "Caserma" then
		-- brande a castello lungo la parete di fondo e un lungo tavolo
		local x = -w / 2 + 2.4
		while x < w / 2 - 2 do
			bed(x, d / 2 - 3.6, true)
			x += 4.6
		end
		local tableX = if doorX < 0 then w / 4 else -w / 4
		piece("TavoloLungo", Vector3.new(12, 0.3, 2.6), tableX, 2.9, -d / 2 + 3.6, Enum.Material.Wood, FURNITURE)
		for _, sx in { -1, 1 } do
			piece("GambaTavolo", Vector3.new(0.4, 2.75, 2), tableX + sx * 5.5, 1.375, -d / 2 + 3.6, Enum.Material.Wood, PALETTE.Timber)
			piece("Panca", Vector3.new(11, 1.6, 0.9), tableX, 0.8, -d / 2 + 3.6 + sx * 1.9, Enum.Material.Wood, PALETTE.Wood)
		end
		ceilingLamp(-w / 4, 0, 20)
		ceilingLamp(w / 4, 0, 20)
	else
		local side = if doorX > 0 then -1 else 1
		part({ Name = "Tappeto", Size = Vector3.new(math.min(8, w * 0.45), 0.1, math.min(6, d * 0.4)), CFrame = at(0, 0.05, 0), Material = Enum.Material.Fabric, Color = pick(RUGS), CastShadow = false, CanCollide = false })
		tableWithStools(-side * w / 4, d * 0.05, false)
		bed(side * (w / 2 - 2.2), d / 2 - 3.6, false)
		fireplace(-side * w / 4, d / 2 - 1, 4.4)
		piece("Mensola", Vector3.new(0.8, 0.25, 4), -side * (w / 2 - 0.45), 5.2, -d * 0.15, Enum.Material.Wood, PALETTE.Timber)
		for i = -1, 1 do
			piece("Vaso", Vector3.new(0.7, 0.9, 0.7), -side * (w / 2 - 0.45), 5.8, -d * 0.15 + i * 1.2, Enum.Material.SmoothPlastic, pick(FLOWERS), false)
		end
		barrel(side * (w / 2 - 1.5), -d / 2 + 1.5)
		ceilingLamp(0, 0, 18)
	end
end

-- VITA IN CITTÀ: mercato, carretti, festoni e strade per i cittadini --------------------------------

-- strade percorribili dai cittadini (le legge il client: CitizenController)
local streets: { { number } } = {}

local AWNINGS = {
	{ Color3.fromRGB(176, 44, 44), Color3.fromRGB(240, 232, 214) },
	{ Color3.fromRGB(52, 110, 64), Color3.fromRGB(236, 226, 196) },
	{ Color3.fromRGB(46, 84, 150), Color3.fromRGB(236, 236, 240) },
	{ Color3.fromRGB(214, 160, 40), Color3.fromRGB(110, 70, 40) },
}
local GOODS = {
	Color3.fromRGB(214, 48, 40), Color3.fromRGB(240, 170, 40), Color3.fromRGB(110, 170, 60),
	Color3.fromRGB(150, 90, 50), Color3.fromRGB(230, 210, 120), Color3.fromRGB(120, 60, 120),
}

-- Banco del mercato con tendone a strisce. cf a terra, il davanti guarda verso -Z
local function marketStall(cf: CFrame)
	local w, d = 8, 5
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part({ Name = "PaloBanco", Size = Vector3.new(0.45, 7, 0.45), CFrame = cf * CFrame.new(sx * (w / 2 - 0.3), 3.5, sz * (d / 2 - 0.3)), Material = Enum.Material.Wood, Color = PALETTE.Timber, CastShadow = false })
		end
	end
	part({ Name = "Bancone", Size = Vector3.new(w, 2.6, 1.6), CFrame = cf * CFrame.new(0, 1.3, -d / 2 + 0.8), Material = Enum.Material.WoodPlanks, Color = PALETTE.Wood })
	part({ Name = "PianoBancone", Size = Vector3.new(w + 0.3, 0.3, 1.9), CFrame = cf * CFrame.new(0, 2.75, -d / 2 + 0.8), Material = Enum.Material.Wood, Color = Color3.fromRGB(140, 104, 70), CastShadow = false })
	-- tendone a strisce, inclinato verso il davanti
	local colors = pick(AWNINGS)
	local stripes = 5
	for i = 1, stripes do
		local x = -w / 2 + (i - 0.5) * w / stripes
		part({ Name = "Tendone", Size = Vector3.new(w / stripes + 0.02, 0.25, d + 1.6), CFrame = cf * CFrame.new(x, 7.1, -0.5) * CFrame.Angles(math.rad(-14), 0, 0), Material = Enum.Material.Fabric, Color = colors[(i % 2) + 1], CastShadow = i == 1 })
	end
	-- merce sul bancone (frutta, verdura, sacchi)
	for i = 1, 6 do
		local size = rng:NextNumber(0.6, 0.95)
		part({ Name = "Merce", Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = cf * CFrame.new(-w / 2 + 0.9 + (i - 1) * (w - 1.8) / 5, 2.9 + size / 2, -d / 2 + 0.8 + rng:NextNumber(-0.3, 0.3)), Material = Enum.Material.SmoothPlastic, Color = pick(GOODS), CastShadow = false })
	end
	part({ Name = "Cassa", Size = Vector3.new(2, 1.6, 1.6), CFrame = cf * CFrame.new(-w / 2 + 1.4, 0.8, d / 2 - 1.1) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(150, 110, 72) })
	part({ Name = "Barile", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 1.8, 1.8), CFrame = cf * CFrame.new(w / 2 - 1.3, 1.2, d / 2 - 1.1) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 76, 46) })
end

-- Carretto di legno con il carico. cf a terra, lungo l'asse X
local function cart(cf: CFrame)
	part({ Name = "Carretto", Size = Vector3.new(6, 0.8, 3.4), CFrame = cf * CFrame.new(0, 2.4, 0), Material = Enum.Material.WoodPlanks, Color = PALETTE.Wood })
	for _, side in { -1, 1 } do
		part({ Name = "Sponda", Size = Vector3.new(6, 1.2, 0.25), CFrame = cf * CFrame.new(0, 3.3, side * 1.6), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(104, 74, 48), CastShadow = false })
		part({ Name = "Ruota", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.45, 3.8, 3.8), CFrame = cf * CFrame.new(0.4, 1.9, side * 1.95) * CFrame.Angles(0, math.rad(90), 0), Material = Enum.Material.Wood, Color = Color3.fromRGB(80, 56, 36) })
		part({ Name = "Stanga", Size = Vector3.new(5, 0.25, 0.25), CFrame = cf * CFrame.new(5, 1.6, side * 0.9) * CFrame.Angles(0, 0, math.rad(-14)), Material = Enum.Material.Wood, Color = PALETTE.Timber, CastShadow = false })
	end
	-- carico: fieno o sacchi
	if rng:NextNumber() < 0.5 then
		part({ Name = "Fieno", Size = Vector3.new(5.2, 1.8, 2.8), CFrame = cf * CFrame.new(0, 3.7, 0), Material = Enum.Material.Fabric, Color = Color3.fromRGB(214, 184, 96) })
	else
		for i = -1, 1 do
			part({ Name = "Sacco", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = cf * CFrame.new(i * 1.7, 3.5, rng:NextNumber(-0.4, 0.4)), Material = Enum.Material.Fabric, Color = Color3.fromRGB(196, 176, 140), CastShadow = false })
		end
	end
end

-- Festone di bandierine colorate tra due pali
local function bunting(a: Vector3, b: Vector3)
	local height = 13
	for _, p in { a, b } do
		part({ Name = "PaloFestone", Size = Vector3.new(0.5, height + 1, 0.5), CFrame = CFrame.new(p + Vector3.new(0, (height + 1) / 2, 0)), Material = Enum.Material.Wood, Color = PALETTE.Timber, CastShadow = false })
	end
	local top = Vector3.new(0, height, 0)
	local length = (b - a).Magnitude
	part({ Name = "Corda", Size = Vector3.new(0.12, 0.12, length), CFrame = CFrame.lookAt((a + b) / 2 + top - Vector3.new(0, 0.8, 0), b + top - Vector3.new(0, 0.8, 0)), Material = Enum.Material.Fabric, Color = Color3.fromRGB(90, 70, 50), CastShadow = false, CanCollide = false })
	local flags = math.max(4, math.floor(length / 3.5))
	for i = 1, flags do
		local k = i / (flags + 1)
		-- la corda scende un po' al centro
		local sag = math.sin(k * math.pi) * 1.6
		local pos = a:Lerp(b, k) + top - Vector3.new(0, 0.8 + sag, 0)
		local flag = wedge({ Name = "Bandierina", Size = Vector3.new(0.1, 1.4, 1.2), CFrame = CFrame.lookAt(pos, pos + (b - a).Unit) * CFrame.new(0, -0.7, 0) * CFrame.Angles(math.pi, 0, 0), Material = Enum.Material.Fabric, Color = pick(GOODS), CastShadow = false })
		flag.CanCollide = false
	end
end

-- Registra i tratti di strada liberi (per i cittadini) lungo una retta, dentro la città
local function recordStreet(from: Vector3, to: Vector3, inside: (Vector3) -> boolean)
	local length = (to - from).Magnitude
	local samples = math.max(2, math.floor(length / 4))
	local runStart: Vector3? = nil
	local last: Vector3? = nil
	for i = 0, samples do
		local p = from:Lerp(to, i / samples)
		if inside(p) then
			runStart = runStart or p
			last = p
		end
		if (not inside(p) or i == samples) and runStart and last then
			if (last - runStart).Magnitude > 30 then
				table.insert(streets, {
					math.floor(runStart.X * 10) / 10, math.floor(runStart.Y * 10) / 10, math.floor(runStart.Z * 10) / 10,
					math.floor(last.X * 10) / 10, math.floor(last.Y * 10) / 10, math.floor(last.Z * 10) / 10,
				})
			end
			runStart = nil
			last = nil
		end
	end
end

-- Mercato, carretti, festoni e strade di una città
local function townLife(center: Vector3, radius: number, cell: number, forward: Vector3, opts)
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local y = opts.Y or G
	local function inside(p: Vector3, margin: number): boolean
		if Util.FlatDistance(p, center) > radius - margin then
			return false
		end
		if opts.HalfPlaneOrigin then
			return (p - opts.HalfPlaneOrigin):Dot(opts.HalfPlaneNormal) > margin + 4
		end
		return true
	end
	local function ground(p: Vector3): Vector3
		return Vector3.new(p.X, y, p.Z)
	end
	-- città in rovina: niente mercato e niente cittadini
	if opts.Ruined then
		return
	end
	-- strade: il viale centrale e le vie trasversali (righe senza case)
	local steps = math.floor(radius / cell)
	local function walkable(p: Vector3): boolean
		return inside(p, 24) and not isReserved(p, 3)
	end
	recordStreet(ground(center - forward * steps * cell), ground(center + forward * steps * cell), walkable)
	for gz = -steps, steps do
		if gz % 3 == 0 then
			local mid = center + forward * gz * cell
			recordStreet(ground(mid - right * steps * cell), ground(mid + right * steps * cell), walkable)
		end
	end
	-- banchi del mercato lungo il viale, rivolti verso il centro della strada
	local edge = cell * 0.61 - 4
	local stalls = 0
	for _, f in { 0.6, -0.6, 1.3, -1.3, 2.0, -2.0, 2.7, 3.4 } do
		if stalls >= 6 then
			break
		end
		for _, side in { -1, 1 } do
			local pos = center + forward * (f * cell) + right * (side * edge)
			if stalls < 6 and inside(pos, 20) and not isReserved(pos, 8) then
				local g = ground(pos)
				marketStall(CFrame.lookAt(g, g - right * side))
				stalls += 1
			end
		end
	end
	-- carretti parcheggiati e festoni sopra il viale
	local carts = 0
	for _, f in { 2.4, -2.4, 3.1, -3.1, 1.0 } do
		local side = if carts % 2 == 0 then 1 else -1
		local pos = center + forward * (f * cell) + right * (side * (edge + 1))
		if carts < 2 and inside(pos, 20) and not isReserved(pos, 8) then
			local g = ground(pos)
			cart(CFrame.lookAt(g, g + forward) * CFrame.Angles(0, math.rad(90), 0))
			carts += 1
		end
	end
	local flags = 0
	for _, f in { 0.95, -0.95, 1.65, 2.35 } do
		local mid = center + forward * (f * cell)
		local a = mid - right * (edge + 2)
		local b = mid + right * (edge + 2)
		if flags < 2 and inside(a, 18) and inside(b, 18) and not isReserved(mid, 6) then
			bunting(ground(a), ground(b))
			flags += 1
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
					buildHouse(cf, width, depth, floors, opts.Style or "Mura", opts.Ruined, { Enterable = rng:NextNumber() < 0.28, Kind = "Casa" })
					count += 1
				end
			end
		end
	end
	local ok, err = pcall(townLife, center, radius, cell, forward, opts)
	if not ok then
		warn("[WorldBuilder] Vita in città (" .. name .. "): " .. tostring(err))
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

-- Punto in cui si prende la barca: un palo con il cartello e il tasto F. spawnCF = dove compare la barca
local function boatDock(pos: Vector3, spawnCF: CFrame, label: string?)
	local post = part({ Name = "PuntoBarca", Size = Vector3.new(1.2, 6, 1.2), CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)), Material = Enum.Material.Wood, Color = PALETTE.Timber })
	part({ Name = "CartelloBarca", Size = Vector3.new(4.4, 2.2, 0.3), CFrame = CFrame.new(pos + Vector3.new(0, 5.4, 0)) * CFrame.Angles(0, math.rad(rng:NextNumber(-10, 10)), 0), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(176, 136, 92), CastShadow = false, CanCollide = false })
	local ring = part({ Name = "Salvagente", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 2.6, 2.6), CFrame = CFrame.new(pos + Vector3.new(0.75, 2.8, 0)), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(220, 60, 50), CastShadow = false, CanCollide = false })
	ring.Name = "Salvagente"
	post:SetAttribute("SpawnX", spawnCF.Position.X)
	post:SetAttribute("SpawnY", spawnCF.Position.Y)
	post:SetAttribute("SpawnZ", spawnCF.Position.Z)
	local _, yaw = spawnCF:ToOrientation()
	post:SetAttribute("SpawnYaw", yaw)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Prendi la tua barca"
	prompt.ObjectText = label or "Pontile"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = post
	CollectionService:AddTag(post, Config.Tags.BoatDock)
	return post
end

-- Pontile di legno da "from" verso il mare, lungo "length" studs
local function pier(from: Vector3, dir: Vector3, length: number, width: number?)
	local right = Vector3.new(-dir.Z, 0, dir.X)
	local w = width or 10
	local n = math.max(1, math.ceil(length / 12))
	for i = 0, n - 1 do
		local pos = from + dir * (i * 12)
		part({ Name = "Pontile", Size = Vector3.new(w, 1.4, 12.4), CFrame = CFrame.lookAt(Vector3.new(pos.X, G - 1, pos.Z), Vector3.new(pos.X, G - 1, pos.Z) + dir), Material = Enum.Material.WoodPlanks, Color = PALETTE.Wood })
		for _, side in { -1, 1 } do
			part({ Name = "PaloPontile", Size = Vector3.new(1.2, 16, 1.2), CFrame = CFrame.new(pos + right * (side * (w / 2 - 0.5)) + Vector3.new(0, -7, 0)), Material = Enum.Material.Wood, Color = PALETTE.Timber, CastShadow = false })
		end
	end
	return from + dir * ((n - 1) * 12)
end

-- ALBERI -------------------------------------------------------------------------------

-- ALBERI ------------------------------------------------------------------------------------
-- Più specie fatte di più pezzi: il tronco si assottiglia verso l'alto, ha i rami e una chioma
-- irregolare di più "nuvole" di foglie (più scure sotto, in ombra, più chiare in cima, al sole).
-- Le foglie si chiamano "Chioma" (NatureController le fa ondeggiare): "Perno" è il punto attorno a
-- cui ruota tutta la chioma e "Fase" fa muovere insieme le foglie dello stesso albero.
local BARK = { Color3.fromRGB(94, 74, 56), Color3.fromRGB(82, 66, 52), Color3.fromRGB(106, 84, 62), Color3.fromRGB(74, 60, 50) }
local LEAF_SHADE = { Color3.fromRGB(50, 86, 44), Color3.fromRGB(44, 78, 42), Color3.fromRGB(58, 92, 46), Color3.fromRGB(52, 84, 52) }
local LEAF_SUN = { Color3.fromRGB(96, 138, 62), Color3.fromRGB(108, 144, 68), Color3.fromRGB(86, 130, 58), Color3.fromRGB(118, 146, 66) }
local FIR = { Color3.fromRGB(40, 68, 50), Color3.fromRGB(34, 60, 46), Color3.fromRGB(46, 76, 54), Color3.fromRGB(38, 66, 58) }

-- Cilindro da a a b (tronchi e rami)
local function stick(name: string, a: Vector3, b: Vector3, d: number, color: Color3, shadow: boolean?): Part
	local axis = b - a
	local dir = Util.SafeUnit(axis, Vector3.yAxis)
	local side = dir:Cross(Vector3.zAxis)
	if side.Magnitude < 0.1 then
		side = dir:Cross(Vector3.xAxis)
	end
	return part({ Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(axis.Magnitude, d, d), CFrame = CFrame.fromMatrix((a + b) / 2, dir, side.Unit), Material = Enum.Material.Wood, Color = color, CastShadow = shadow ~= false })
end

local function swayInfo(p: BasePart, pivot: Vector3, phase: number)
	p:SetAttribute("Perno", pivot)
	p:SetAttribute("Fase", phase)
end

-- Nuvola di foglie sferica
local function leafBall(center: Vector3, size: number, color: Color3, pivot: Vector3, phase: number, shadow: boolean): Part
	local p = part({ Name = "Chioma", Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = CFrame.new(center), Material = Enum.Material.LeafyGrass, Color = color, CastShadow = shadow })
	swayInfo(p, pivot, phase)
	return p
end

-- Ellissoide (palco di rami degli abeti): solo grafica, i rampini si agganciano al tronco
local function leafEllipsoid(cf: CFrame, size: Vector3, color: Color3, pivot: Vector3, phase: number, shadow: boolean): Part
	local p = part({ Name = "Chioma", Size = size, CFrame = cf, Material = Enum.Material.LeafyGrass, Color = color, CastShadow = shadow, CanCollide = false, CanQuery = false })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	swayInfo(p, pivot, phase)
	return p
end

-- Latifoglia (quercia, faggio): opts.Birch = betulla, chiara e slanciata
local function broadleaf(pos: Vector3, s: number, birch: boolean?)
	local bark = if birch then Color3.fromRGB(214, 210, 200) else pick(BARK)
	local h = (if birch then 23 else 19) * s
	local thick = if birch then 0.7 else 1
	local lean = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * 0.7 * s
	local p1 = pos + Vector3.new(0, h * 0.5, 0) + lean * 0.45
	local p2 = pos + Vector3.new(0, h * 0.8, 0) + lean
	-- colletto delle radici, tronco in due pezzi sempre più sottili
	stick("Radici", pos - Vector3.new(0, 0.8, 0), pos + Vector3.new(0, 0.9 * s, 0), 3.3 * s * thick, bark, false)
	stick("Tronco", pos - Vector3.new(0, 1, 0), p1, 2.6 * s * thick, bark)
	stick("Tronco", p1, p2 + Vector3.new(0, 1.5 * s, 0), 1.75 * s * thick, bark, false)
	local phase = rng:NextNumber(0, math.pi * 2)
	local crown = p2 + Vector3.new(0, 3.2 * s, 0)
	local spread = if birch then 0.75 else 1
	-- due rami che escono dal tronco verso la chioma
	local a0 = rng:NextNumber(0, math.pi * 2)
	for i = 1, 2 do
		local a = a0 + i * math.pi + rng:NextNumber(-0.5, 0.5)
		local from = p1:Lerp(p2, rng:NextNumber(0.15, 0.55))
		local to = from + Vector3.new(math.cos(a) * 5.5 * s * spread, 4.5 * s, math.sin(a) * 5.5 * s * spread)
		stick("Ramo", from, to, 0.85 * s * thick, bark, false)
	end
	-- chioma: una nuvola grande, tre più piccole attorno (in ombra) e una in cima (al sole)
	local main = rng:NextNumber(11, 13) * s * spread
	local shade = pick(LEAF_SHADE)
	local sun = pick(LEAF_SUN)
	if birch then
		shade = shade:Lerp(Color3.fromRGB(110, 150, 70), 0.35)
		sun = sun:Lerp(Color3.fromRGB(150, 176, 84), 0.3)
	end
	leafBall(crown, main, shade:Lerp(sun, 0.4), p2, phase, true)
	local a1 = rng:NextNumber(0, math.pi * 2)
	for i = 1, 3 do
		local a = a1 + i * math.pi * 2 / 3 + rng:NextNumber(-0.4, 0.4)
		local r = rng:NextNumber(4.2, 5.4) * s * spread
		local size = rng:NextNumber(7.5, 9.5) * s * spread
		leafBall(crown + Vector3.new(math.cos(a) * r, rng:NextNumber(-1.8, 1.2) * s, math.sin(a) * r), size, shade, p2, phase, false)
	end
	leafBall(crown + Vector3.new(rng:NextNumber(-1.5, 1.5) * s, main * 0.42, rng:NextNumber(-1.5, 1.5) * s), main * 0.66, sun, p2, phase, false)
end

-- Abete: tronco dritto e palchi di rami sempre più stretti verso la punta
local function conifer(pos: Vector3, s: number)
	local h = 30 * s
	local bark = tint(pick(BARK), 0.85)
	stick("Tronco", pos - Vector3.new(0, 1, 0), pos + Vector3.new(0, h * 0.86, 0), 1.7 * s, bark)
	stick("Radici", pos - Vector3.new(0, 0.8, 0), pos + Vector3.new(0, 0.8 * s, 0), 2.5 * s, bark, false)
	local color = pick(FIR)
	local phase = rng:NextNumber(0, math.pi * 2)
	local pivot = pos + Vector3.new(0, h * 0.2, 0)
	local tiers = 4
	for i = 0, tiers - 1 do
		local k = i / tiers
		local r = (8.6 - i * 1.85) * s
		local th = (7.4 - i * 0.9) * s
		local y = h * (0.24 + k * 0.6)
		leafEllipsoid(CFrame.new(pos + Vector3.new(0, y, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Vector3.new(r * 2, th, r * 2 * rng:NextNumber(0.9, 1)), color:Lerp(Color3.fromRGB(74, 106, 70), k * 0.45), pivot, phase, i == 0)
	end
	leafEllipsoid(CFrame.new(pos + Vector3.new(0, h * 0.93, 0)), Vector3.new(2.8 * s, 8 * s, 2.8 * s), color:Lerp(Color3.fromRGB(80, 112, 74), 0.5), pivot, phase, false)
end

-- Albero morto (isola di Cenere): tronco annerito e rami spogli
local function deadTree(pos: Vector3, s: number)
	local bark = Color3.fromRGB(58, 50, 46)
	local h = 17 * s
	local lean = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * 1.2 * s
	local top = pos + Vector3.new(0, h, 0) + lean
	stick("Tronco", pos - Vector3.new(0, 1, 0), top, 2 * s, bark)
	for _ = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		local from = pos:Lerp(top, rng:NextNumber(0.45, 0.9))
		stick("Ramo", from, from + Vector3.new(math.cos(a) * 6 * s, rng:NextNumber(2, 5) * s, math.sin(a) * 6 * s), 0.7 * s, bark, false)
	end
end

-- Cespuglio basso (tra gli alberi e lungo i sentieri)
local function bush(pos: Vector3, s: number)
	local color = pick(LEAF_SHADE)
	for i = 1, 2 do
		local size = rng:NextNumber(3.6, 5.2) * s
		local b = part({ Name = "Cespuglio", Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-2, 2) * s, size * 0.25, rng:NextNumber(-2, 2) * s)), Material = Enum.Material.LeafyGrass, Color = if i == 1 then color else color:Lerp(pick(LEAF_SUN), 0.5), CastShadow = false })
		b.CanCollide = false
	end
end

-- species: "Latifoglia" | "Abete" | "Betulla" | "Morto" (se manca, a caso: soprattutto latifoglie)
local function tree(pos: Vector3, scale: number?, species: string?)
	local s = scale or rng:NextNumber(0.8, 1.3)
	local kind = species
	if not kind then
		local roll = rng:NextNumber()
		kind = if roll < 0.62 then "Latifoglia" elseif roll < 0.88 then "Abete" else "Betulla"
	end
	if kind == "Abete" then
		conifer(pos, s)
	elseif kind == "Morto" then
		deadTree(pos, s)
	else
		broadleaf(pos, s, kind == "Betulla")
	end
end

local function giantTree(pos: Vector3)
	local h = rng:NextNumber(230, 330)
	local d = rng:NextNumber(18, 30)
	local bark = Color3.fromRGB(rng:NextInteger(88, 104), rng:NextInteger(64, 76), rng:NextInteger(44, 54))
	-- tronco in due pezzi: largo alla base, più sottile verso la cima
	local split = pos + Vector3.new(0, h * 0.58, 0)
	local trunkCF = CFrame.new(pos + Vector3.new(0, h * 0.29, 0)) * CFrame.Angles(0, 0, math.rad(90))
	part({ Name = "TroncoGigante", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h * 0.58 + 2, d, d), CFrame = trunkCF, Material = Enum.Material.Wood, Color = bark })
	stick("TroncoGigante", split - Vector3.new(0, 4, 0), pos + Vector3.new(0, h, 0), d * 0.74, tint(bark, 1.04))
	-- anello di corteccia più scura dove il tronco si restringe
	stick("Corteccia", split - Vector3.new(0, 5, 0), split + Vector3.new(0, 3, 0), d * 0.86, tint(bark, 0.82), false)
	-- radici
	local roots = rng:NextInteger(5, 6)
	for i = 0, roots - 1 do
		local a = i * math.pi * 2 / roots + rng:NextNumber(-0.25, 0.25)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local rs = rng:NextNumber(0.75, 1.05)
		wedge({ Name = "Radice", Size = Vector3.new(d * 0.32, d * 0.9 * rs, d * 0.95 * rs), CFrame = CFrame.lookAt(pos + dir * (d * 0.6) + Vector3.new(0, d * 0.45 * rs, 0), pos + dir * (d * 2) + Vector3.new(0, d * 0.45 * rs, 0)), Material = Enum.Material.Wood, Color = tint(bark, 0.92) })
	end
	-- rami con ciuffi di fogliame (scuri sotto, chiari sopra)
	local phase = rng:NextNumber(0, math.pi * 2)
	local branches = rng:NextInteger(3, 5)
	for i = 1, branches do
		local y = h * rng:NextNumber(0.45, 0.85)
		local a = rng:NextNumber(0, math.pi * 2)
		local len = rng:NextNumber(45, 80)
		local dir = Vector3.new(math.cos(a), 0.45, math.sin(a)).Unit
		local start = pos + Vector3.new(0, y, 0)
		local tip = start + dir * len
		local bd = rng:NextNumber(5, 9)
		stick("Ramo", start, tip, bd, bark)
		local leaf = rng:NextNumber(40, 60)
		local shade = pick(LEAF_SHADE)
		local f = part({ Name = "Fogliame", Shape = Enum.PartType.Ball, Size = Vector3.one * leaf, CFrame = CFrame.new(tip), Material = Enum.Material.LeafyGrass, Color = shade:Lerp(pick(LEAF_SUN), 0.35), CastShadow = i <= 3 })
		local branchPivot = tip - dir * leaf * 0.6
		swayInfo(f, branchPivot, phase)
		for j = 1, 2 do
			local side = dir:Cross(Vector3.yAxis)
			local off = Util.SafeUnit(side, Vector3.xAxis) * (if j == 1 then 1 else -1) * leaf * 0.38 + Vector3.new(0, (j - 1) * leaf * 0.28 - leaf * 0.08, 0) + dir * leaf * 0.12
			local sat = part({ Name = "Fogliame", Shape = Enum.PartType.Ball, Size = Vector3.one * leaf * rng:NextNumber(0.6, 0.72), CFrame = CFrame.new(tip + off), Material = Enum.Material.LeafyGrass, Color = if j == 1 then shade else pick(LEAF_SUN), CastShadow = false })
			swayInfo(sat, branchPivot, phase)
		end
	end
	-- chioma in cima: una grande nuvola e tre attorno
	local crown = rng:NextNumber(70, 96)
	local top = pos + Vector3.new(0, h + crown * 0.2, 0)
	local crownPivot = pos + Vector3.new(0, h - crown * 0.3, 0)
	local c = part({ Name = "Chioma", Shape = Enum.PartType.Ball, Size = Vector3.one * crown, CFrame = CFrame.new(top), Material = Enum.Material.LeafyGrass, Color = pick(LEAF_SHADE):Lerp(pick(LEAF_SUN), 0.4) })
	swayInfo(c, crownPivot, phase)
	for j = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		local sat = part({ Name = "Chioma", Shape = Enum.PartType.Ball, Size = Vector3.one * crown * rng:NextNumber(0.5, 0.65), CFrame = CFrame.new(top + Vector3.new(math.cos(a) * crown * 0.42, (j - 2) * crown * 0.16, math.sin(a) * crown * 0.42)), Material = Enum.Material.LeafyGrass, Color = if j == 3 then pick(LEAF_SUN) else pick(LEAF_SHADE), CastShadow = false })
		swayInfo(sat, crownPivot, phase)
	end
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
		buildHouse(cf, 36, 16, 1, "Mura", false, { Enterable = true, Kind = "Caserma" })
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
			buildHouse(cf, rng:NextNumber(16, 24), rng:NextNumber(14, 20), rng:NextInteger(1, 2), "Mura", false, { Enterable = rng:NextNumber() < 0.4, Kind = "Casa" })
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
	local isl = W.IslandAt(c)
	if isl and Util.FlatDistance(c + dir * 148, isl.Center) > isl.Land then
		local pierEnd = c + dir * 148
		local spawnPos = Vector3.new(pierEnd.X, W.WaterY + 1, pierEnd.Z) + dir * 26 - right * 14
		boatDock(pierEnd - right * 4, CFrame.lookAt(spawnPos, spawnPos + dir), zone.Name)
	end
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
			local segments = math.ceil((isl.Beach - isl.Land + 40) / 12)
			for i = 0, segments do
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
			-- in fondo al pontile si prende la propria barca
			local pierEnd = shore + dir * (segments * 12)
			local spawnPos = Vector3.new(pierEnd.X, W.WaterY + 1, pierEnd.Z) + dir * 16 - right * 12
			boatDock(pierEnd - right * 4, CFrame.lookAt(spawnPos, spawnPos + dir), "Pontile di " .. isl.Name)
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
			local ground = Vector3.new(pos.X, G, pos.Z)
			if rng:NextNumber() < 0.35 then
				bush(ground, rng:NextNumber(0.9, 1.5))
			else
				tree(ground, rng:NextNumber(0.6, 1), if rng:NextNumber() < 0.45 then "Abete" else "Latifoglia")
			end
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
					-- piccoli boschetti della stessa specie (a Edenia più abeti, a Cenere alberi morti)
					local species: string? = nil
					local roll = rng:NextNumber()
					if id == "Cenere" then
						species = if roll < 0.6 then "Morto" else "Abete"
					elseif id == "Edenia" then
						species = if roll < 0.5 then "Abete" elseif roll < 0.85 then "Latifoglia" else "Betulla"
					elseif roll < 0.7 then
						species = if rng:NextNumber() < 0.75 then "Latifoglia" else "Abete"
					end
					local clump = rng:NextInteger(1, 4)
					for _ = 1, clump do
						tree(groundAt(probe + Vector3.new(rng:NextNumber(-15, 15), 0, rng:NextNumber(-15, 15))), nil, species)
					end
					if id ~= "Cenere" and rng:NextNumber() < 0.5 then
						bush(groundAt(probe + Vector3.new(rng:NextNumber(-18, 18), 0, rng:NextNumber(-18, 18))), rng:NextNumber(0.8, 1.3))
					end
					count += 1
				end
			end
		end
	end
end

-- Mondo aperto: niente muri invisibili attorno alle isole, solo il bordo del mare
local function buildBoundaries()
	currentGroup = group("Confini")
	local b = W.SeaBounds
	local inset = 40
	local minX, maxX, minZ, maxZ = b.MinX + inset, b.MaxX - inset, b.MinZ + inset, b.MaxZ - inset
	local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
	local sx, sz = maxX - minX, maxZ - minZ
	for _, wall in {
		{ Vector3.new(cx, 150, minZ), Vector3.new(sx + 8, 400, 4) },
		{ Vector3.new(cx, 150, maxZ), Vector3.new(sx + 8, 400, 4) },
		{ Vector3.new(minX, 150, cz), Vector3.new(4, 400, sz + 8) },
		{ Vector3.new(maxX, 150, cz), Vector3.new(4, 400, sz + 8) },
	} do
		part({ Name = "Confine", Size = wall[2], CFrame = CFrame.new(wall[1]), Transparency = 1, CanQuery = false, CastShadow = false })
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
	-- taverne (le case della città non ci finiscono sopra) e arena dei duelli
	for _, t in W.Taverns do
		local zone = Zones.Get(t.Zone)
		if zone then
			table.insert(reserved, { Pos = zone.Center + t.Offset, Radius = 22 })
		end
	end
	table.insert(reserved, { Pos = W.Landmarks.ArenaDuelli, Radius = 96 })
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

-- MONDO APERTO: pontili delle barche, taverne, arena dei duelli e isolotti ----------------------

local function zoneOffsetCF(zoneId: string, offset: Vector3, facing: number): CFrame
	local zone = Zones.Get(zoneId)
	local base = (if zone then zone.Center else Vector3.zero) + offset
	local ground = Vector3.new(base.X, G, base.Z)
	return CFrame.lookAt(ground, ground + Util.Polar(facing, 1))
end

local function buildTaverns()
	currentGroup = group("Taverne")
	for _, t in W.Taverns do
		local cf = zoneOffsetCF(t.Zone, t.Offset, t.Facing)
		local size = W.TavernSize
		buildHouse(cf, size.X, size.Z, 1, t.Style or "Mura", false, { Enterable = true, Kind = "Taverna" })
		-- insegna appesa sopra la porta
		local sign = part({ Name = "Insegna", Size = Vector3.new(9, 2.6, 0.4), CFrame = cf * CFrame.new(0, 11.2, -size.Z / 2 - 1.6), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(96, 64, 40), CastShadow = false, CanCollide = false })
		part({ Name = "BraccioInsegna", Size = Vector3.new(0.3, 0.3, 2), CFrame = cf * CFrame.new(0, 12.7, -size.Z / 2 - 0.9), Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 38, 36), CastShadow = false, CanCollide = false })
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.CanvasSize = Vector2.new(360, 104)
			gui.LightInfluence = 0.6
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.GrenzeGotisch
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(240, 210, 140)
			label.Text = t.Name
			label.Parent = gui
			gui.Parent = sign
		end
		local lantern = part({ Name = "Lanterna", Size = Vector3.new(0.9, 1.3, 0.9), CFrame = cf * CFrame.new(4.2, 9, -size.Z / 2 - 0.8), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 196, 120), CastShadow = false, CanCollide = false })
		warmLight(lantern, 16, 1.2)
		CollectionService:AddTag(lantern, Config.Tags.Lamp)
	end
end

-- Arena dei Duelli: un piccolo anfiteatro con colonne per i rampini
local function buildDuelArena()
	local c = W.Landmarks.ArenaDuelli
	currentGroup = group("Arena dei Duelli")
	workspace.Terrain:FillCylinder(CFrame.new(c.X, G - 2, c.Z), 4, 74, Enum.Material.Sand)
	local radius = 76
	local n = 28
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local angleDeg = (math.deg(a) + 90) % 360 -- Polar: 0 = nord
		local gate = math.abs(((angleDeg - 0) + 540) % 360 - 180) < 9 or math.abs(((angleDeg - 180) + 540) % 360 - 180) < 9
		local pos = c + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		local length = 2 * radius * math.tan(math.pi / n) + 1
		if not gate then
			part({ Name = "Gradinata", Size = Vector3.new(length, 20, 10), CFrame = CFrame.lookAt(pos + Vector3.new(0, 10, 0), c + Vector3.new(0, 10, 0)), Material = Enum.Material.Sandstone, Color = Color3.fromRGB(198, 172, 132) })
			local inner = c + Vector3.new(math.cos(a) * (radius - 8), 0, math.sin(a) * (radius - 8))
			part({ Name = "Gradone", Size = Vector3.new(length * 0.96, 9, 6), CFrame = CFrame.lookAt(inner + Vector3.new(0, 4.5, 0), c + Vector3.new(0, 4.5, 0)), Material = Enum.Material.Sandstone, Color = Color3.fromRGB(184, 158, 120), CastShadow = false })
			if i % 4 == 1 then
				local torchPart = part({ Name = "Braciere", Size = Vector3.new(2.6, 2.6, 2.6), CFrame = CFrame.new(pos + Vector3.new(0, 21.3, 0)), Material = Enum.Material.CorrodedMetal, Color = Color3.fromRGB(60, 50, 44) })
				local fire = Instance.new("Fire")
				fire.Size = 6
				fire.Heat = 8
				fire.Parent = torchPart
			end
		end
	end
	-- archi d'ingresso a nord e a sud
	for _, z in { -1, 1 } do
		local gatePos = c + Vector3.new(0, 0, z * radius)
		for _, sx in { -1, 1 } do
			part({ Name = "PilastroArco", Size = Vector3.new(4, 24, 8), CFrame = CFrame.new(gatePos + Vector3.new(sx * 9, 12, 0)), Material = Enum.Material.Sandstone, Color = Color3.fromRGB(210, 186, 146) })
		end
		part({ Name = "Arco", Size = Vector3.new(22, 4, 8), CFrame = CFrame.new(gatePos + Vector3.new(0, 26, 0)), Material = Enum.Material.Sandstone, Color = Color3.fromRGB(210, 186, 146) })
		part({ Name = "StendardoArena", Size = Vector3.new(8, 10, 0.2), CFrame = CFrame.new(gatePos + Vector3.new(0, 19, z * 4.2)), Material = Enum.Material.Fabric, Color = Color3.fromRGB(150, 36, 40), CastShadow = false, CanCollide = false })
	end
	-- colonne al centro per combattere anche coi rampini
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local pos = c + Vector3.new(math.cos(a) * 38, 0, math.sin(a) * 38)
		part({ Name = "Colonna", Size = Vector3.new(4, 46, 4), CFrame = CFrame.new(pos + Vector3.new(0, 23, 0)), Material = Enum.Material.Sandstone, Color = Color3.fromRGB(214, 190, 150) })
	end
	part({ Name = "PedanaCentrale", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 22, 22), CFrame = CFrame.new(c + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Slate, Color = Color3.fromRGB(120, 112, 100) })
	supplyStation(c + Vector3.new(14, 0, 60))
	lamp(c + Vector3.new(-12, 0, -92))
	lamp(c + Vector3.new(12, 0, -92))
end

-- Palma: tronco ricurvo a segmenti e foglie a ventaglio
local function palm(pos: Vector3, scale: number?)
	local s = scale or rng:NextNumber(0.8, 1.2)
	local lean = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
	lean = Util.SafeUnit(lean) * 0.35
	local top = pos
	local segments = 6
	for i = 1, segments do
		local k = i / segments
		local nextPos = pos + Vector3.new(0, 26 * s * k, 0) + lean * (26 * s * k * k)
		local mid = (top + nextPos) / 2
		-- l'asse Y del segmento segue il tronco (fromMatrix funziona anche se il tronco è verticale)
		local up = Util.SafeUnit(nextPos - top, Vector3.yAxis)
		local side = up:Cross(Vector3.zAxis)
		if side.Magnitude < 0.1 then
			side = up:Cross(Vector3.xAxis)
		end
		part({ Name = "TroncoPalma", Size = Vector3.new(1.8 * s * (1.15 - k * 0.3), (nextPos - top).Magnitude + 0.4, 1.8 * s * (1.15 - k * 0.3)), CFrame = CFrame.fromMatrix(mid, side.Unit, up), Material = Enum.Material.Wood, Color = Color3.fromRGB(132, 100, 66), CastShadow = i == segments })
		top = nextPos
	end
	for i = 0, 6 do
		local a = i / 7 * math.pi * 2
		local dir = Vector3.new(math.cos(a), -0.35, math.sin(a)).Unit
		local leafPos = top + dir * 6 * s
		local leaf = part({ Name = "Chioma", Size = Vector3.new(2.6 * s, 0.3, 12 * s), CFrame = CFrame.lookAt(leafPos, leafPos + dir), Material = Enum.Material.LeafyGrass, Color = pick({ Color3.fromRGB(70, 130, 60), Color3.fromRGB(86, 146, 64), Color3.fromRGB(60, 118, 56) }), CastShadow = i % 2 == 0 })
		leaf.CanCollide = false
	end
	for i = 1, 3 do
		part({ Name = "Cocco", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.3 * s, CFrame = CFrame.new(top + Vector3.new(math.cos(i * 2.1), -1.1, math.sin(i * 2.1)) * s), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(96, 66, 40), CastShadow = false, CanCollide = false })
	end
end

local function rock(pos: Vector3, size: number, material: Enum.Material?)
	workspace.Terrain:FillBall(pos, size, material or Enum.Material.Rock)
end

-- Faro bianco e rosso con la lanterna che si accende di notte
local function lighthouse(base: Vector3)
	local h = 92
	local bands = 6
	for i = 0, bands - 1 do
		local y0 = h * i / bands
		local d = 18 - i * 1.2
		part({ Name = "Faro", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h / bands + 0.1, d, d), CFrame = CFrame.new(base + Vector3.new(0, y0 + h / bands / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Concrete, Color = if i % 2 == 0 then Color3.fromRGB(236, 232, 224) else Color3.fromRGB(180, 44, 40) })
	end
	local top = base + Vector3.new(0, h, 0)
	part({ Name = "Ballatoio", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 18, 18), CFrame = CFrame.new(top + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Metal, Color = Color3.fromRGB(50, 50, 54) })
	local lantern = part({ Name = "LanternaFaro", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8, 8, 8), CFrame = CFrame.new(top + Vector3.new(0, 5.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 230, 160), CastShadow = false })
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 2
	light.Color = Color3.fromRGB(255, 220, 150)
	light.Parent = lantern
	CollectionService:AddTag(lantern, Config.Tags.Lamp)
	part({ Name = "TettoFaro", Shape = Enum.PartType.Ball, Size = Vector3.new(10, 6, 10), CFrame = CFrame.new(top + Vector3.new(0, 10, 0)), Material = Enum.Material.Metal, Color = Color3.fromRGB(150, 40, 36) })
end

-- Relitto di una nave mercantile arenata sugli scogli
local function shipwreck(c: Vector3, yaw: number)
	local cf = CFrame.new(c + Vector3.new(0, G + 2, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(6), 0, math.rad(14))
	local hull = Color3.fromRGB(84, 60, 42)
	part({ Name = "ScafoRelitto", Size = Vector3.new(16, 8, 50), CFrame = cf, Material = Enum.Material.WoodPlanks, Color = hull })
	wedge({ Name = "PruaRelitto", Size = Vector3.new(16, 8, 12), CFrame = cf * CFrame.new(0, 0, -31) * CFrame.Angles(0, math.pi, 0), Material = Enum.Material.WoodPlanks, Color = hull })
	part({ Name = "PonteRelitto", Size = Vector3.new(15, 0.6, 58), CFrame = cf * CFrame.new(0, 4.2, -4), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(128, 98, 66) })
	-- buco nello scafo e albero spezzato
	part({ Name = "Squarcio", Size = Vector3.new(0.4, 5, 8), CFrame = cf * CFrame.new(8.1, -0.5, 6), Material = Enum.Material.Slate, Color = Color3.fromRGB(20, 18, 16), CastShadow = false })
	part({ Name = "AlberoSpezzato", Size = Vector3.new(1.8, 22, 1.8), CFrame = cf * CFrame.new(0, 15, -8), Material = Enum.Material.Wood, Color = PALETTE.Timber })
	part({ Name = "AlberoCaduto", Size = Vector3.new(1.6, 30, 1.6), CFrame = cf * CFrame.new(10, 6, 14) * CFrame.Angles(math.rad(80), 0, math.rad(20)), Material = Enum.Material.Wood, Color = PALETTE.Timber })
	part({ Name = "VelaStrappata", Size = Vector3.new(12, 10, 0.2), CFrame = cf * CFrame.new(0, 18, -6.8) * CFrame.Angles(0, 0, math.rad(8)), Material = Enum.Material.Fabric, Color = Color3.fromRGB(200, 190, 170), Transparency = 0.15, CastShadow = false, CanCollide = false })
	for i = 1, 5 do
		part({ Name = "CassaCarico", Size = Vector3.new(3, 3, 3), CFrame = cf * CFrame.new(rng:NextNumber(-5, 5), 6, rng:NextNumber(-20, 18)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(150, 110, 72) })
	end
end

-- Torre di guardia antica, mezza sommersa e inclinata
local function ruinedTower(c: Vector3)
	local base = Vector3.new(c.X, G - 6, c.Z)
	local tilt = CFrame.Angles(math.rad(5), 0, math.rad(-4))
	local h = 74
	local cf = CFrame.new(base) * tilt
	part({ Name = "TorreSommersa", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 24, 24), CFrame = cf * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(120, 126, 118) })
	part({ Name = "CimaTorre", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 28, 28), CFrame = cf * CFrame.new(0, h + 1, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(110, 116, 108) })
	for i = 0, 7 do
		if i ~= 3 and i ~= 6 then
			local a = i / 8 * math.pi * 2
			part({ Name = "Merlo", Size = Vector3.new(4, 4, 3), CFrame = cf * CFrame.new(math.cos(a) * 12.5, h + 4, math.sin(a) * 12.5) * CFrame.Angles(0, -a, 0), Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(110, 116, 108) })
		end
	end
	-- alghe e muschio alla base
	part({ Name = "Muschio", Shape = Enum.PartType.Cylinder, Size = Vector3.new(10, 24.6, 24.6), CFrame = cf * CFrame.new(0, 9, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Grass, Color = Color3.fromRGB(60, 96, 60), CastShadow = false })
end

-- Cono di un vulcano spento con il cratere che fuma
local function volcano(c: Vector3, radius: number)
	local terrain = workspace.Terrain
	for i = 0, 5 do
		local r = radius * (1 - i * 0.15)
		terrain:FillCylinder(CFrame.new(c.X, G + i * 9, c.Z), 10, r, if i < 2 then Enum.Material.Rock else Enum.Material.Basalt)
		pause()
	end
	local craterY = G + 5 * 9 + 5
	terrain:FillCylinder(CFrame.new(c.X, craterY - 2, c.Z), 8, radius * 0.24, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(c.X, craterY - 7, c.Z), 2, radius * 0.24, Enum.Material.CrackedLava)
	local smoke = part({ Name = "Fumarola", Size = Vector3.new(4, 1, 4), CFrame = CFrame.new(c.X, craterY - 4, c.Z), Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Rate = 6
	emitter.Lifetime = NumberRange.new(6, 9)
	emitter.Speed = NumberRange.new(8, 14)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 30) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	emitter.Color = ColorSequence.new(Color3.fromRGB(90, 84, 80), Color3.fromRGB(150, 146, 140))
	emitter.SpreadAngle = Vector2.new(15, 15)
	emitter.Parent = smoke
	local glow = Instance.new("PointLight")
	glow.Range = 40
	glow.Brightness = 1.5
	glow.Color = Color3.fromRGB(255, 110, 50)
	glow.Parent = smoke
end

-- Covo dei contrabbandieri: palizzata, capanne, casse e un molo nascosto
local function smugglersCove(c: Vector3, radius: number)
	local ground = Vector3.new(c.X, G, c.Z)
	for i = 0, 17 do
		local a = i / 18 * math.pi * 2
		if i ~= 4 then
			local pos = ground + Vector3.new(math.cos(a) * radius * 0.62, 0, math.sin(a) * radius * 0.62)
			for k = -1, 1 do
				local p = pos + Vector3.new(-math.sin(a), 0, math.cos(a)) * (k * 4.2)
				part({ Name = "Palizzata", Size = Vector3.new(1.6, rng:NextNumber(11, 14), 1.6), CFrame = CFrame.new(p + Vector3.new(0, 6, 0)), Material = Enum.Material.Wood, Color = Color3.fromRGB(96, 70, 46), CastShadow = k == 0 })
			end
		end
	end
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2 + 0.5
		local pos = ground + Vector3.new(math.cos(a) * radius * 0.32, 0, math.sin(a) * radius * 0.32)
		local cf = CFrame.lookAt(pos, ground)
		part({ Name = "Capanna", Size = Vector3.new(14, 9, 12), CFrame = cf * CFrame.new(0, 4.5, 0), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(110, 82, 56) })
		wedge({ Name = "TettoCapanna", Size = Vector3.new(15, 4, 7), CFrame = cf * CFrame.new(0, 11, -3.25), Material = Enum.Material.Fabric, Color = Color3.fromRGB(96, 84, 60) })
		wedge({ Name = "TettoCapanna", Size = Vector3.new(15, 4, 7), CFrame = cf * CFrame.new(0, 11, 3.25) * CFrame.Angles(0, math.pi, 0), Material = Enum.Material.Fabric, Color = Color3.fromRGB(96, 84, 60) })
	end
	for _ = 1, 10 do
		local pos = ground + Vector3.new(rng:NextNumber(-radius * 0.45, radius * 0.45), 0, rng:NextNumber(-radius * 0.45, radius * 0.45))
		if Util.FlatDistance(pos, ground) > 14 then
			part({ Name = "CassaContrabbando", Size = Vector3.new(3, 3, 3), CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(140, 104, 66) })
		end
	end
	local fire = part({ Name = "Falo", Size = Vector3.new(3, 1, 3), CFrame = CFrame.new(ground + Vector3.new(8, 0.5, 8)), Material = Enum.Material.Slate, Color = Color3.fromRGB(50, 44, 40) })
	local flame = Instance.new("Fire")
	flame.Size = 5
	flame.Parent = fire
	warmLight(fire, 24, 1.5)
end

local function buildIslets()
	local terrain = workspace.Terrain
	for _, islet in W.Islets do
		currentGroup = group(islet.Name)
		local c = islet.Center
		local r = islet.Radius
		-- spiaggia e terra (come le isole grandi, ma piccole)
		terrain:FillCylinder(CFrame.new(c.X, 1, c.Z), 10, r + 16, Enum.Material.Sand)
		local top = if islet.Kind == "Sabbia" or islet.Kind == "Palme" then Enum.Material.Sand else if islet.Kind == "Vulcano" then Enum.Material.Basalt else Enum.Material.Grass
		terrain:FillCylinder(CFrame.new(c.X, 2, c.Z), 12, r, top)
		if islet.Kind == "Palme" then
			terrain:FillCylinder(CFrame.new(c.X, 2.5, c.Z), 12, r * 0.55, Enum.Material.Grass)
		end
		pause()
		local ground = Vector3.new(c.X, G, c.Z)
		if islet.Kind == "Gabbiani" then
			for _ = 1, 9 do
				local p = ground + Util.Polar(rng:NextNumber(0, 360), rng:NextNumber(20, r - 10))
				rock(p + Vector3.new(0, 2, 0), rng:NextNumber(6, 12))
			end
			for _ = 1, 6 do
				tree(ground + Util.Polar(rng:NextNumber(0, 360), rng:NextNumber(15, r - 20)), rng:NextNumber(0.7, 1))
			end
			rock(ground + Vector3.new(-20, 10, -20), 18)
		elseif islet.Kind == "Sabbia" then
			for _ = 1, 5 do
				local p = ground + Util.Polar(rng:NextNumber(0, 360), rng:NextNumber(10, r - 12))
				part({ Name = "Tronco", Shape = Enum.PartType.Cylinder, Size = Vector3.new(rng:NextNumber(8, 14), 1.6, 1.6), CFrame = CFrame.new(p + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Material = Enum.Material.Wood, Color = Color3.fromRGB(150, 130, 104) })
			end
			for _ = 1, 3 do
				rock(ground + Util.Polar(rng:NextNumber(0, 360), rng:NextNumber(10, r - 15)), rng:NextNumber(4, 7))
			end
		elseif islet.Kind == "Torre" then
			for _ = 1, 8 do
				rock(ground + Util.Polar(rng:NextNumber(0, 360), rng:NextNumber(25, r)) + Vector3.new(0, -2, 0), rng:NextNumber(5, 10))
			end
			ruinedTower(ground)
		elseif islet.Kind == "Faro" then
			for _ = 1, 8 do
				rock(ground + Util.Polar(rng:NextNumber(0, 360), rng:NextNumber(35, r - 5)), rng:NextNumber(6, 11))
			end
			lighthouse(ground)
			buildHouse(CFrame.lookAt(ground + Vector3.new(30, 0, 18), ground + Vector3.new(30, 0, 30)), 18, 14, 1, "Mura", false, { Enterable = true, Kind = "Casa" })
			for _ = 1, 4 do
				tree(ground + Util.Polar(rng:NextNumber(150, 300), rng:NextNumber(40, r - 15)), 0.8)
			end
		elseif islet.Kind == "Relitto" then
			for _ = 1, 14 do
				rock(ground + Util.Polar(rng:NextNumber(0, 360), rng:NextNumber(10, r + 10)) + Vector3.new(0, rng:NextNumber(-2, 6), 0), rng:NextNumber(5, 12), Enum.Material.Slate)
			end
			shipwreck(c + Vector3.new(20, 0, 0), math.rad(70))
		elseif islet.Kind == "Palme" then
			for _ = 1, 12 do
				palm(ground + Util.Polar(rng:NextNumber(0, 360), rng:NextNumber(18, r - 12)))
			end
			-- capanna del mercante e falò
			local hutCF = CFrame.lookAt(ground + Vector3.new(16, 0, -22), ground)
			part({ Name = "Capanna", Size = Vector3.new(12, 8, 10), CFrame = hutCF * CFrame.new(0, 4, 0), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(150, 120, 80) })
			wedge({ Name = "TettoPaglia", Size = Vector3.new(14, 4, 6), CFrame = hutCF * CFrame.new(0, 10, -2.75), Material = Enum.Material.Fabric, Color = Color3.fromRGB(206, 180, 110) })
			wedge({ Name = "TettoPaglia", Size = Vector3.new(14, 4, 6), CFrame = hutCF * CFrame.new(0, 10, 2.75) * CFrame.Angles(0, math.pi, 0), Material = Enum.Material.Fabric, Color = Color3.fromRGB(206, 180, 110) })
			local fire = part({ Name = "Falo", Size = Vector3.new(3, 1, 3), CFrame = CFrame.new(ground + Vector3.new(-6, 0.5, 4)), Material = Enum.Material.Slate, Color = Color3.fromRGB(50, 44, 40) })
			local flame = Instance.new("Fire")
			flame.Size = 4
			flame.Parent = fire
			warmLight(fire, 20, 1.3)
			supplyStation(ground + Vector3.new(-18, 0, -10), "Deposito delle Palme")
		elseif islet.Kind == "Rifugio" then
			for _ = 1, 10 do
				rock(ground + Util.Polar(rng:NextNumber(0, 360), rng:NextNumber(r * 0.7, r + 8)), rng:NextNumber(6, 12), Enum.Material.Slate)
			end
			smugglersCove(c, r)
		elseif islet.Kind == "Vulcano" then
			volcano(c, r * 0.8)
			for _ = 1, 6 do
				rock(ground + Util.Polar(rng:NextNumber(0, 360), rng:NextNumber(r * 0.8, r + 6)), rng:NextNumber(6, 10), Enum.Material.Basalt)
			end
		end
		-- pontile verso Vermiglia con il punto barca (nessuno resta bloccato su un isolotto)
		local dir = Util.SafeUnit(Util.Flat(Vector3.zero - c), Vector3.new(0, 0, 1))
		local right = Vector3.new(-dir.Z, 0, dir.X)
		local start = ground + dir * (r - 6)
		local finish = pier(start, dir, 40, 8)
		local spawnPos = Vector3.new(finish.X, W.WaterY + 1, finish.Z) + dir * 14 + right * 10
		boatDock(finish + right * 3, CFrame.lookAt(spawnPos, spawnPos + dir), islet.Name)
		lamp(start - dir * 4 + right * 5)
		pause()
	end
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
	step("Taverne", buildTaverns)
	step("Arena dei Duelli", buildDuelArena)
	step("Isolotti", buildIslets)
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

	-- alberi che ondeggiano e camini che fumano (li anima il client)
	for _, d in mapFolder:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "Chioma" or d.Name == "Fogliame" then
				CollectionService:AddTag(d, "Fogliame")
			elseif d.Name == "Comignolo" then
				CollectionService:AddTag(d, "Comignolo")
			end
		end
	end
	mapFolder:SetAttribute("Strade", HttpService:JSONEncode(streets))
	print(("[WorldBuilder] Mappa generata: %d parti in %.1fs, %d tratti di strada"):format(partCount, os.clock() - t0, #streets))
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
