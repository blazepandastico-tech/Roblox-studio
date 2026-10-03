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

return W
