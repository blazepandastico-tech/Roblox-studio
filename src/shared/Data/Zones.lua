--[[
	Zones - le aree del mondo divise per Stagione
	Ogni stagione ha la sua isola (vedi WorldLayout):
	Stagione 1: Vermiglia, livelli 1-200   | Stagione 2: Edenia, 200-450
	Stagione 3: Aurea e Cenere, 450-1000   | Stagione 4: Valdoria, 1000-2000
	Ogni zona ha il campo Island con l'isola di appartenenza (calcolato in fondo al file).
]]

local Util = require(script.Parent.Parent.Lib.Util)
local W = require(script.Parent.WorldLayout)

local Zones = {}

local G = W.GroundY

-- Atmosfere (nebbia, colore, saturazione) applicate dal client entrando in una zona
Zones.Ambience = {
	Default = { Density = 0.28, Haze = 1.1, Glare = 0.35, Color = Color3.fromRGB(196, 212, 228), Decay = Color3.fromRGB(110, 118, 132), Tint = Color3.fromRGB(255, 250, 244), Saturation = 0.08, Contrast = 0.08, Exposure = 0.1 },
	Citta = { Density = 0.22, Haze = 0.8, Glare = 0.4, Color = Color3.fromRGB(214, 214, 220), Decay = Color3.fromRGB(120, 112, 104), Tint = Color3.fromRGB(255, 246, 232), Saturation = 0.1, Contrast = 0.1, Exposure = 0.1 },
	Foresta = { Density = 0.44, Haze = 2.2, Glare = 0.1, Color = Color3.fromRGB(160, 196, 150), Decay = Color3.fromRGB(70, 92, 62), Tint = Color3.fromRGB(226, 255, 226), Saturation = 0.12, Contrast = 0.12, Exposure = 0 },
	Nebbia = { Density = 0.42, Haze = 2.6, Glare = 0.1, Color = Color3.fromRGB(172, 204, 160), Decay = Color3.fromRGB(80, 110, 70), Tint = Color3.fromRGB(236, 255, 230), Saturation = -0.05, Contrast = 0.1, Exposure = 0 },
	Rovine = { Density = 0.46, Haze = 2.8, Glare = 0.2, Color = Color3.fromRGB(176, 166, 156), Decay = Color3.fromRGB(96, 84, 76), Tint = Color3.fromRGB(255, 236, 222), Saturation = -0.25, Contrast = 0.15, Exposure = 0 },
	Castello = { Density = 0.36, Haze = 1.8, Glare = 0.2, Color = Color3.fromRGB(160, 170, 192), Decay = Color3.fromRGB(80, 86, 104), Tint = Color3.fromRGB(232, 236, 255), Saturation = -0.05, Contrast = 0.12, Exposure = 0 },
	Gola = { Density = 0.3, Haze = 1.4, Glare = 0.3, Color = Color3.fromRGB(206, 190, 170), Decay = Color3.fromRGB(120, 100, 84), Tint = Color3.fromRGB(255, 242, 226), Saturation = 0, Contrast = 0.12, Exposure = 0.05 },
	Sotterraneo = { Density = 0.55, Haze = 2.2, Glare = 0, Color = Color3.fromRGB(46, 40, 34), Decay = Color3.fromRGB(30, 26, 22), Tint = Color3.fromRGB(255, 218, 178), Saturation = -0.1, Contrast = 0.18, Exposure = -0.3 },
	Cristallo = { Density = 0.4, Haze = 1.6, Glare = 0, Color = Color3.fromRGB(80, 140, 170), Decay = Color3.fromRGB(40, 70, 90), Tint = Color3.fromRGB(210, 240, 255), Saturation = 0.15, Contrast = 0.12, Exposure = -0.15 },
	Valdoria = { Density = 0.38, Haze = 2.0, Glare = 0.2, Color = Color3.fromRGB(176, 166, 154), Decay = Color3.fromRGB(100, 92, 84), Tint = Color3.fromRGB(255, 240, 226), Saturation = -0.12, Contrast = 0.12, Exposure = 0 },
	Marcia = { Density = 0.5, Haze = 3.0, Glare = 0.6, Color = Color3.fromRGB(232, 142, 92), Decay = Color3.fromRGB(150, 60, 40), Tint = Color3.fromRGB(255, 212, 182), Saturation = 0.1, Contrast = 0.2, Exposure = 0 },
	Arena = { Density = 0.32, Haze = 1.5, Glare = 0.5, Color = Color3.fromRGB(220, 190, 160), Decay = Color3.fromRGB(130, 90, 70), Tint = Color3.fromRGB(255, 236, 214), Saturation = 0.1, Contrast = 0.15, Exposure = 0.05 },
	Mare = { Density = 0.3, Haze = 1.6, Glare = 0.5, Color = Color3.fromRGB(190, 210, 232), Decay = Color3.fromRGB(100, 120, 150), Tint = Color3.fromRGB(244, 250, 255), Saturation = 0.08, Contrast = 0.08, Exposure = 0.1 },
}

Zones.SeasonNames = {
	[1] = "Stagione 1 - Vermiglia: Il Muro Infranto",
	[2] = "Stagione 2 - Edenia: Il Sangue tra le Isole",
	[3] = "Stagione 3 - Aurea e Cenere: La Verità nel Seminterrato",
	[4] = "Stagione 4 - Valdoria: Oltre il Mare",
}

local function districtCenter(id)
	return W.DistrictCenter(id) + Vector3.new(0, G, 0)
end

Zones.List = {
	-- STAGIONE 1 -------------------------------------------------------------------
	{
		Id = "CampoAddestramento",
		Name = "Campo di Addestramento Sud",
		Season = 1,
		Safe = true,
		Spawn = true,
		Center = W.At("Vermiglia", 215, 260, G),
		Radius = 120,
		Level = { 1, 10 },
		Ambience = "Default",
		Description = "Qui i cadetti imparano a usare i Rampini. Il tuo viaggio comincia da qui.",
	},
	{
		Id = "Recinto",
		Name = "Recinto dei Giganti Catturati",
		Season = 1,
		Center = W.At("Vermiglia", 300, 290, G),
		Radius = 110,
		Level = { 1, 20 },
		Ambience = "Default",
		Titans = {
			{ Class = "T3", Level = 4, Count = 6 },
			{ Class = "T4", Level = 12, Count = 5 },
		},
		Description = "I giganti catturati dalla Dott.ssa Morrow. Perfetti per allenarsi... con cautela.",
	},
	{
		Id = "QuartierGenerale",
		Name = "Quartier Generale del Corpo dei Falchi",
		Season = 1,
		Safe = true,
		Spawn = true,
		Center = W.At("Vermiglia", 100, 300, G),
		Radius = 75,
		Level = { 20, 200 },
		Ambience = "Default",
		Description = "Un vecchio castello trasformato nella base delle Ali del Falco.",
	},
	{
		Id = "Calaneth",
		Name = "Distretto di Calaneth",
		Season = 1,
		Center = districtCenter("Calaneth"),
		Radius = 135,
		Level = { 20, 70 },
		Ambience = "Citta",
		Titans = {
			{ Class = "T5", Level = 25, Count = 7 },
			{ Class = "T7", Level = 45, Count = 6, Abnormal = 0.1 },
		},
		Bosses = { "Ghignante" },
		Description = "Il distretto meridionale del Muro Vermiglio. Il cancello esterno è stato sfondato.",
	},
	{
		Id = "PianureSud",
		Name = "Pianure Meridionali",
		Season = 1,
		Center = W.At("Vermiglia", 130, 770, G),
		Radius = 170,
		Level = { 70, 120 },
		Ambience = "Default",
		Titans = {
			{ Class = "T7", Level = 80, Count = 7 },
			{ Class = "T10", Level = 100, Count = 6, Abnormal = 0.1 },
		},
		Description = "Le terre perdute del Muro di Cenere, oggi territorio dei giganti.",
	},
	{
		Id = "Avamposto",
		Name = "Avamposto della Spedizione",
		Season = 1,
		Safe = true,
		Spawn = true,
		Center = W.At("Vermiglia", 215, 720, G),
		Radius = 55,
		Level = { 100, 200 },
		Ambience = "Default",
		Description = "Tende, carri di rifornimento e una bandiera verde: l'ultimo luogo sicuro prima della foresta.",
	},
	{
		Id = "Foresta",
		Name = "Foresta degli Alberi Giganti",
		Season = 1,
		Center = W.At("Vermiglia", 285, 760, G),
		Radius = 235,
		Level = { 120, 200 },
		Ambience = "Foresta",
		Titans = {
			{ Class = "T10", Level = 130, Count = 6 },
			{ Class = "T12", Level = 160, Count = 6, Abnormal = 0.25 },
		},
		Bosses = { "Cacciatrice" },
		Description = "Alberi alti più di ottanta metri: il paradiso dei Rampini e il regno degli anomali.",
	},

	-- STAGIONE 2 -------------------------------------------------------------------
	{
		Id = "Brenn",
		Name = "Villaggio di Brenn",
		Season = 2,
		Center = W.At("Edenia", 70, 420, G),
		Radius = 120,
		Level = { 200, 280 },
		Ambience = "Nebbia",
		Titans = {
			{ Class = "T7", Level = 210, Count = 7 },
			{ Class = "T10", Level = 250, Count = 6 },
		},
		Description = "Un villaggio dentro il Muro Vermiglio avvolto da una strana nebbia verde.",
	},
	{
		Id = "Ostrava",
		Name = "Castello di Ostrava",
		Season = 2,
		Center = W.At("Edenia", 300, 470, G),
		Radius = 120,
		Level = { 280, 350 },
		Ambience = "Castello",
		Titans = {
			{ Class = "T10", Level = 290, Count = 6 },
			{ Class = "T12", Level = 320, Count = 6, Abnormal = 0.15 },
		},
		Bosses = { "Fauno" },
		Description = "Le rovine di un castello. Di notte, i giganti non dormono più.",
	},
	{
		Id = "AccampamentoEdenia",
		Name = "Accampamento di Edenia",
		Season = 2,
		Safe = true,
		Spawn = true,
		Center = W.At("Edenia", 180, 560, G),
		Radius = 50,
		Level = { 300, 450 },
		Ambience = "Default",
		Description = "Il campo base per le operazioni nella Gola di Edenia.",
	},
	{
		Id = "GolaEdenia",
		Name = "Gola di Edenia",
		Season = 2,
		Center = W.At("Edenia", 10, 640, G),
		Radius = 140,
		Level = { 350, 450 },
		Ambience = "Gola",
		Titans = {
			{ Class = "T12", Level = 370, Count = 6 },
			{ Class = "T15", Level = 410, Count = 5, Abnormal = 0.15 },
		},
		Bosses = { "Bastione", "Zanna" },
		Description = "Un canyon di roccia rossa dove i traditori si sono rivelati.",
	},

	-- STAGIONE 3 -------------------------------------------------------------------
	{
		Id = "Aurion",
		Name = "Capitale Aurion",
		Season = 3,
		Safe = true,
		Spawn = true,
		Center = W.At("Aurea", 0, 0, G),
		Radius = 320,
		Level = { 450, 2000 },
		Ambience = "Citta",
		Description = "Il cuore dentro il Muro Aureo. Qui vive il Mercante di Sieri.",
	},
	{
		Id = "Stohlberg",
		Name = "Distretto di Stohlberg",
		Season = 3,
		Center = districtCenter("Stohlberg"),
		Radius = 100,
		Level = { 450, 550 },
		Ambience = "Citta",
		Enemies = {
			{ Type = "PoliziaCorrotta", Level = 460, Count = 7 },
			{ Type = "PoliziaCorrotta", Level = 520, Count = 6 },
		},
		Description = "La Gendarmeria Reale corrotta sorveglia strani carichi notturni.",
	},
	{
		Id = "CittaSotterranea",
		Name = "Città Sotterranea",
		Season = 3,
		Underground = true,
		Center = W.Underground.CittaSotterranea.Center * Vector3.new(1, 0, 1) + Vector3.new(0, W.UndergroundFloor("CittaSotterranea"), 0),
		Radius = 200,
		Level = { 550, 650 },
		Ambience = "Sotterraneo",
		Enemies = {
			{ Type = "SquadraOmbra", Level = 560, Count = 7 },
			{ Type = "SquadraOmbra", Level = 620, Count = 6 },
		},
		HumanBosses = { "Corvo" },
		Description = "Una città senza cielo sotto la capitale. Il regno del Corvo Nero.",
	},
	{
		Id = "CavernaCristallo",
		Name = "Caverna di Cristallo",
		Season = 3,
		Underground = true,
		Center = W.Underground.CavernaCristallo.Center * Vector3.new(1, 0, 1) + Vector3.new(0, W.UndergroundFloor("CavernaCristallo"), 0),
		Radius = 175,
		Level = { 650, 720 },
		Ambience = "Cristallo",
		Titans = {
			{ Class = "T7", Level = 660, Count = 7, Look = "Cristallo" },
			{ Class = "T10", Level = 700, Count = 5, Look = "Cristallo" },
		},
		Description = "Una caverna di cristallo luminoso dove riposa un segreto della Stirpe Reale.",
	},
	{
		Id = "PianaOrvel",
		Name = "Piana di Orvel",
		Season = 3,
		Center = W.At("Aurea", 0, 650, G),
		Radius = 150,
		Level = { 720, 800 },
		Ambience = "Default",
		Titans = {
			{ Class = "T12", Level = 730, Count = 6 },
			{ Class = "T15", Level = 770, Count = 5 },
		},
		Bosses = { "Strisciante" },
		Description = "La piana davanti all'ingresso della caverna. La terra trema da giorni.",
	},
	{
		Id = "Halvar",
		Name = "Rovine di Halvar",
		Season = 3,
		Center = districtCenter("Halvar"),
		Radius = 160,
		Level = { 800, 950 },
		Ambience = "Rovine",
		Titans = {
			{ Class = "T12", Level = 820, Count = 7 },
			{ Class = "T15", Level = 880, Count = 6, Abnormal = 0.2 },
		},
		Bosses = { "Vulcano" },
		Description = "Il distretto dove tutto è cominciato. Da qualche parte c'è la tua vecchia casa.",
	},
	{
		Id = "LandeCenere",
		Name = "Lande Oltre il Muro",
		Season = 3,
		Center = W.At("Cenere", 200, 640, G),
		Radius = 165,
		Level = { 900, 1000 },
		Ambience = "Rovine",
		Titans = {
			{ Class = "T15", Level = 920, Count = 6 },
			{ Class = "T15", Level = 980, Count = 5, Abnormal = 0.5 },
		},
		Description = "Terre selvagge tra il Muro di Cenere e il mare.",
	},
	{
		Id = "ApprodoCenere",
		Name = "Approdo di Cenere",
		Season = 3,
		Safe = true,
		Spawn = true,
		Center = W.At("Cenere", 0, 760, G),
		Radius = 60,
		Level = { 800, 1000 },
		Ambience = "Rovine",
		Description = "Il pontile improvvisato da cui parte la riconquista della patria perduta.",
	},
	{
		Id = "PortoOrientale",
		Name = "Porto Orientale",
		Season = 4,
		Safe = true,
		Spawn = true,
		Center = W.At("Vermiglia", 90, 930, G),
		Radius = 70,
		Level = { 1000, 2000 },
		Ambience = "Mare",
		Description = "Il primo porto costruito dagli Isolani dopo aver visto il mare.",
	},

	-- STAGIONE 4 (VALDORIA) ------------------------------------------------------------
	{
		Id = "PortoRevelia",
		Name = "Porto di Revelia",
		Season = 4,
		Safe = true,
		Spawn = true,
		Center = Vector3.new(3600, G, 0),
		Radius = 110,
		Level = { 1000, 2000 },
		Ambience = "Valdoria",
		Description = "Il porto di Valdoria dove sbarcano i volontari di Edenia.",
	},
	{
		Id = "Trincee",
		Name = "Trincee di Valdoria",
		Season = 4,
		Center = Vector3.new(4050, G, -480),
		Radius = 170,
		Level = { 1000, 1200 },
		Ambience = "Valdoria",
		Enemies = {
			{ Type = "SoldatoValdoriano", Level = 1010, Count = 7 },
		},
		Titans = {
			{ Class = "T10", Level = 1080, Count = 5 },
			{ Class = "T15", Level = 1150, Count = 4 },
		},
		Bosses = { "Destriero" },
		Description = "Fango, filo spinato e giganti usati come armi da guerra.",
	},
	{
		Id = "Revelia",
		Name = "Distretto di Revelia",
		Season = 4,
		Center = Vector3.new(4250, G, 120),
		Radius = 190,
		Level = { 1200, 1450 },
		Ambience = "Valdoria",
		Enemies = {
			{ Type = "SoldatoValdoriano", Level = 1220, Count = 6 },
			{ Type = "GuardiaVael", Level = 1350, Count = 6 },
		},
		Titans = {
			{ Class = "T12", Level = 1300, Count = 5 },
		},
		Bosses = { "Forgia" },
		Description = "La zona d'internamento degli Isolani di Valdoria. Stanotte brucerà.",
	},
	{
		Id = "Fortezza",
		Name = "Fortezza di Vael",
		Season = 4,
		Center = Vector3.new(4750, G, -300),
		Radius = 150,
		Level = { 1450, 1700 },
		Ambience = "Valdoria",
		Enemies = {
			{ Type = "GuardiaVael", Level = 1480, Count = 6 },
			{ Type = "GuardiaVael", Level = 1600, Count = 6 },
		},
		Titans = {
			{ Class = "T15", Level = 1550, Count = 5, Look = "Cristallo" },
		},
		Bosses = { "Furia" },
		Description = "Il laboratorio-fortezza dove vengono distillati i Sieri Perduti.",
	},
	{
		Id = "FronteMarcia",
		Name = "Fronte della Grande Marcia",
		Season = 4,
		Center = Vector3.new(4700, G, 430),
		Radius = 230,
		Level = { 1700, 2000 },
		Ambience = "Marcia",
		Titans = {
			{ Class = "T15", Level = 1750, Count = 7 },
			{ Class = "T15", Level = 1850, Count = 5, Abnormal = 0.6 },
			{ Class = "TB", Level = 1900, Count = 3 },
		},
		Bosses = { "Primordiale" },
		Description = "La terra trema sotto i passi dei giganti della Marcia. L'ultima battaglia.",
	},

	-- ISOLA DEI RAID --------------------------------------------------------------------
	{
		Id = "ArenaRaid",
		Name = "Arena dei Raid",
		Season = 1,
		Raid = true,
		Spawn = true,
		Center = W.At("Arena", 0, 0, G),
		Radius = 300,
		Level = { 120, 2000 },
		Ambience = "Arena",
		Description = "Un'antica arena circondata dal mare: qui si combattono i raid a ondate.",
	},
}

Zones.ById = {}
for _, zone in Zones.List do
	local island = W.IslandAt(zone.Center)
	zone.Island = if island then island.Id else nil
	Zones.ById[zone.Id] = zone
end

function Zones.Get(id: string?)
	return id and Zones.ById[id]
end

-- Zone ordinate dalla più piccola alla più grande (così le zone piccole
-- dentro quelle grandi vengono riconosciute per prime).
local bySize = table.clone(Zones.List)
table.sort(bySize, function(a, b)
	return a.Radius < b.Radius
end)

function Zones.Find(position: Vector3)
	local underground = position.Y < -120
	for _, zone in bySize do
		if (zone.Underground == true) == underground then
			local flat = Util.FlatDistance(position, zone.Center)
			if flat <= zone.Radius then
				if not underground or math.abs(position.Y - zone.Center.Y) < 140 then
					return zone
				end
			end
		end
	end
	return nil
end

-- Nome generico della regione quando non sei in una zona precisa
function Zones.RegionName(position: Vector3): string
	if position.Y < -120 then
		return "Sottosuolo di Aurea"
	end
	local island = W.IslandAt(position)
	if not island then
		return "Il Mare"
	end
	for _, wall in W.Walls do
		if wall.Island == island.Id and Util.FlatDistance(position, island.Center) < wall.Radius then
			return island.Name .. " • dentro il " .. wall.Name
		end
	end
	return island.Name
end

function Zones.AmbienceFor(position: Vector3)
	local zone = Zones.Find(position)
	if zone then
		return Zones.Ambience[zone.Ambience] or Zones.Ambience.Default
	end
	if position.Y < -120 then
		return Zones.Ambience.Sotterraneo
	end
	local island = W.IslandAt(position)
	if not island or Util.FlatDistance(position, island.Center) > island.Land then
		return Zones.Ambience.Mare
	end
	if island.Id == "Valdoria" then
		return Zones.Ambience.Valdoria
	elseif island.Id == "Cenere" then
		return Zones.Ambience.Rovine
	end
	return Zones.Ambience.Default
end

-- Punto di rinascita di una zona sicura
function Zones.SpawnPoint(zone): Vector3
	return zone.Center + Vector3.new(0, 4, 0)
end

return Zones
