--[[
	WorldLayout - la geografia del mondo: un arcipelago di isole separate dal mare
	(ci si sposta con i traghetti, come nei "mari" dei grandi MMO di Roblox).

	  Vermiglia  (Stagione 1, Lv. 1)    isola murata dove si addestrano i cadetti
	  Edenia     (Stagione 2, Lv. 200)  isola selvaggia di villaggi, castelli e gole
	  Aurea      (Stagione 3, Lv. 450)  isola della capitale Aurion, con il sottosuolo
	  Cenere     (Stagione 3, Lv. 800)  la patria perduta, mura in rovina e il distretto di Halvar
	  Valdoria   (Stagione 4, Lv. 1000) il continente oltre il mare
	  Arena      (Raid)                 l'isola dei raid

	Convenzione degli angoli: 0° = Nord (-Z), 90° = Est (+X), 180° = Sud (+Z), 270° = Ovest (-X).
]]

local Util = require(script.Parent.Parent.Lib.Util)

local W = {}

W.GroundY = 8 -- quota del terreno erboso
W.WaterY = 4 -- quota del mare

W.Islands = {
	Vermiglia = { Id = "Vermiglia", Name = "Isola di Vermiglia", Season = 1, LevelReq = 1, Hub = "CampoAddestramento", Center = Vector3.new(0, 0, 0), Land = 1000, Beach = 1080, Water = 1320 },
	Edenia = { Id = "Edenia", Name = "Isola di Edenia", Season = 2, LevelReq = 200, Hub = "AccampamentoEdenia", Center = Vector3.new(0, 0, -3300), Land = 950, Beach = 1030, Water = 1280 },
	Aurea = { Id = "Aurea", Name = "Isola Aurea", Season = 3, LevelReq = 450, Hub = "Aurion", Center = Vector3.new(-3400, 0, 0), Land = 950, Beach = 1030, Water = 1280 },
	Cenere = { Id = "Cenere", Name = "Isola di Cenere", Season = 3, LevelReq = 800, Hub = "ApprodoCenere", Center = Vector3.new(0, 0, 3300), Land = 850, Beach = 930, Water = 1180 },
	Valdoria = { Id = "Valdoria", Name = "Continente di Valdoria", Season = 4, LevelReq = 1000, Hub = "PortoRevelia", Center = Vector3.new(4300, 0, 0), Land = 900, Beach = 980, Water = 1250 },
	Arena = { Id = "Arena", Name = "Isola dell'Arena", Season = 0, LevelReq = 120, Hub = "ArenaRaid", Center = Vector3.new(3300, 0, -3300), Land = 420, Beach = 480, Water = 700, Raid = true },
}

W.IslandOrder = { "Vermiglia", "Edenia", "Aurea", "Cenere", "Valdoria", "Arena" }

-- Mura: ogni isola murata ha il suo anello di mura
W.Walls = {
	Vermiglia = { Id = "Vermiglia", Island = "Vermiglia", Name = "Muro Vermiglio", Radius = 480, Height = 150, Thickness = 26, Gates = { 0, 90 } },
	Aurea = { Id = "Aurea", Island = "Aurea", Name = "Muro Aureo", Radius = 380, Height = 140, Thickness = 24, Gates = { 0, 270 } },
	Cenere = { Id = "Cenere", Island = "Cenere", Name = "Muro di Cenere", Radius = 430, Height = 160, Thickness = 28, Gates = {}, Ruined = true },
}

W.WallOrder = { "Vermiglia", "Aurea", "Cenere" }

-- Distretti: semicerchi di mura che sporgono verso l'esterno
W.Districts = {
	Calaneth = { Id = "Calaneth", Name = "Distretto di Calaneth", Wall = "Vermiglia", Angle = 180, Radius = 140, OuterGate = "Boulder" },
	Stohlberg = { Id = "Stohlberg", Name = "Distretto di Stohlberg", Wall = "Aurea", Angle = 90, Radius = 110, OuterGate = "Open" },
	Halvar = { Id = "Halvar", Name = "Distretto di Halvar", Wall = "Cenere", Angle = 0, Radius = 170, Ruined = true, OuterGate = "Broken" },
}

W.GateWidth = 34

function W.IslandCenter(id: string): Vector3
	return W.Islands[id].Center
end

-- Punto in coordinate polari rispetto al centro di un'isola
function W.At(islandId: string, angle: number, radius: number, y: number?): Vector3
	return W.Islands[islandId].Center + Util.Polar(angle, radius, y)
end

-- Isola che contiene (o è più vicina a) una posizione; nil in mare aperto
function W.IslandAt(position: Vector3)
	for _, id in W.IslandOrder do
		local island = W.Islands[id]
		if Util.FlatDistance(position, island.Center) <= island.Beach then
			return island
		end
	end
	return nil
end

-- Grotte sotterranee sotto l'Isola Aurea (raggiungibili con gli ascensori)
local aurea = W.Islands.Aurea.Center
W.Underground = {
	CittaSotterranea = { Center = aurea + Vector3.new(0, -300, 0), Size = Vector3.new(440, 120, 440) },
	CavernaCristallo = { Center = aurea + Vector3.new(0, -300, -640), Size = Vector3.new(380, 110, 380) },
}

function W.UndergroundFloor(id: string): number
	local cave = W.Underground[id]
	return cave.Center.Y - cave.Size.Y / 2
end

function W.WallCenter(wallId: string): Vector3
	return W.Islands[W.Walls[wallId].Island].Center
end

function W.WallPoint(wallId: string, angle: number): Vector3
	return W.WallCenter(wallId) + Util.Polar(angle, W.Walls[wallId].Radius)
end

function W.DistrictGatePoint(id: string): Vector3
	local d = W.Districts[id]
	return W.WallPoint(d.Wall, d.Angle)
end

-- Direzione "verso l'esterno" dell'isola nel punto del distretto
function W.DistrictOutward(id: string): Vector3
	local d = W.Districts[id]
	return Util.SafeUnit(Util.Polar(d.Angle, 1))
end

-- Centro "abitato" del distretto (a metà tra le mura interne ed esterne)
function W.DistrictCenter(id: string): Vector3
	local d = W.Districts[id]
	return W.WallCenter(d.Wall) + Util.Polar(d.Angle, W.Walls[d.Wall].Radius + d.Radius * 0.5)
end

-- Punti notevoli usati dalla storia e dalle scene animate
local campCenter = W.At("Vermiglia", 215, 260)
local halvarCenter = W.DistrictCenter("Halvar")
local ostrava = W.At("Edenia", 300, 470)

W.Landmarks = {
	-- cima della torre di addestramento (obiettivo del tutorial sui rampini)
	TorreAddestramento = campCenter + Vector3.new(-70, W.GroundY + 96, 30),
	PortoOrientale = W.At("Vermiglia", 90, 930, W.GroundY),
	PortoRevelia = Vector3.new(3560, W.GroundY, 0),
	Seminterrato = halvarCenter + Vector3.new(-60, W.GroundY, 30),
	IngressoCaverna = W.At("Aurea", 0, 700, W.GroundY),
	AscensoreAurion = aurea + Vector3.new(-120, W.GroundY, 60),
	LagoOstrava = ostrava + Vector3.new(-150, 0, -120),
}

-- MARE APERTO ------------------------------------------------------------------------------
-- Il mondo è aperto: tra le isole si naviga con la propria barca (o a nuoto).
-- Gli isolotti in mezzo al mare hanno giganti, relitti e tesori nascosti.
W.Islets = {
	{ Id = "IsolaGabbiani", Name = "Isola dei Gabbiani", Center = Vector3.new(150, 0, -1650), Radius = 85, Kind = "Gabbiani" },
	{ Id = "BancoSabbia", Name = "Banco di Sabbia", Center = Vector3.new(-1600, 0, 150), Radius = 80, Kind = "Sabbia" },
	{ Id = "TorreSommersa", Name = "Torre Sommersa", Center = Vector3.new(-150, 0, 1650), Radius = 80, Kind = "Torre" },
	{ Id = "IsolaFaro", Name = "Isola del Faro", Center = Vector3.new(1700, 0, -1700), Radius = 110, Kind = "Faro" },
	{ Id = "ScogliNaufraghi", Name = "Scogli dei Naufraghi", Center = Vector3.new(-1800, 0, -1900), Radius = 95, Kind = "Relitto" },
	{ Id = "IsolaPalme", Name = "Isola delle Palme", Center = Vector3.new(-1900, 0, 1900), Radius = 120, Kind = "Palme" },
	{ Id = "RifugioContrabbandieri", Name = "Rifugio dei Contrabbandieri", Center = Vector3.new(2000, 0, 1900), Radius = 130, Kind = "Rifugio" },
	{ Id = "ScoglioBrace", Name = "Scoglio di Brace", Center = Vector3.new(2600, 0, -1000), Radius = 100, Kind = "Vulcano" },
}

W.IsletById = {}
for _, islet in W.Islets do
	W.IsletById[islet.Id] = islet
end

-- Isolotto che contiene una posizione (nil se non sei su un isolotto)
function W.IsletAt(position: Vector3)
	for _, islet in W.Islets do
		if Util.FlatDistance(position, islet.Center) <= islet.Radius + 20 then
			return islet
		end
	end
	return nil
end

-- Confini del mare (rettangolo che contiene tutte le isole, con un margine di mare aperto)
do
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, isl in W.Islands do
		minX = math.min(minX, isl.Center.X - isl.Water - 600)
		maxX = math.max(maxX, isl.Center.X + isl.Water + 600)
		minZ = math.min(minZ, isl.Center.Z - isl.Water - 600)
		maxZ = math.max(maxZ, isl.Center.Z + isl.Water + 600)
	end
	W.SeaBounds = { MinX = minX, MaxX = maxX, MinZ = minZ, MaxZ = maxZ }
end

-- In mare aperto (lontano dalla terra di isole e isolotti)?
function W.IsOpenSea(position: Vector3): boolean
	if position.Y < -60 then
		return false
	end
	for _, isl in W.Islands do
		if Util.FlatDistance(position, isl.Center) <= isl.Land + 30 then
			return false
		end
	end
	for _, islet in W.Islets do
		if Util.FlatDistance(position, islet.Center) <= islet.Radius then
			return false
		end
	end
	return true
end

-- Arena dei Duelli (PvP sempre attivo) sull'isola di Vermiglia, fuori dalla porta nord
W.Landmarks.ArenaDuelli = W.At("Vermiglia", 30, 720, W.GroundY)

-- Locande e taverne in cui si può entrare (Offset rispetto al centro della zona, la porta guarda verso Facing)
W.Taverns = {
	{ Id = "TavernaMuro", Name = "Taverna del Muro", Zone = "Calaneth", Offset = Vector3.new(-48, 0, 34), Facing = 90, Style = "Mura" },
	{ Id = "LocandaCervo", Name = "Locanda del Cervo", Zone = "Brenn", Offset = Vector3.new(-30, 0, 40), Facing = 0, Style = "Mura" },
	{ Id = "OsteriaAurea", Name = "Osteria Aurea", Zone = "Aurion", Offset = Vector3.new(110, 0, 150), Facing = 270, Style = "Mura" },
	{ Id = "TavernaGabbiano", Name = "Taverna del Gabbiano", Zone = "PortoOrientale", Offset = Vector3.new(-65, 0, 80), Facing = 0, Style = "Mura" },
	{ Id = "OsteriaPorto", Name = "Osteria del Porto", Zone = "PortoRevelia", Offset = Vector3.new(70, 0, 60), Facing = 180, Style = "Valdoria" },
}
W.TavernSize = Vector3.new(30, 12, 24)
W.TavernById = {}
for _, t in W.Taverns do
	W.TavernById[t.Id] = t
end

-- Punto dentro la taverna (coordinate locali: X a destra, Z verso il fondo) → offset dal centro della zona
-- (il davanti, con la porta, guarda verso Facing: è la stessa rotazione di CFrame.lookAt usata dal WorldBuilder)
function W.TavernOffset(id: string, localPos: Vector3): Vector3
	local t = W.TavernById[id]
	local a = math.rad(t.Facing)
	local c, s = math.cos(a), math.sin(a)
	return t.Offset + Vector3.new(localPos.X * c - localPos.Z * s, localPos.Y, localPos.X * s + localPos.Z * c)
end

return W
