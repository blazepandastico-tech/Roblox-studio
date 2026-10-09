--[[
	Quests - missioni ripetibili (stile Blox Fruits)
	Si accettano dai PNG "Quest". Ricompense calcolate dal livello della missione.
	Target.Kind: Titan (classe nella zona) | Boss | Enemy (umani) | HumanBoss
]]

local Quests = {}

local function titan(id, name, zone, class, count, level, levelReq)
	return { Id = id, Name = name, Target = { Kind = "Titan", Zone = zone, Class = class }, Count = count, Level = level, LevelReq = levelReq }
end

local function boss(id, name, bossId, level, levelReq)
	return { Id = id, Name = name, Target = { Kind = "Boss", Boss = bossId }, Count = 1, Level = level, LevelReq = levelReq, BossQuest = true }
end

local function enemy(id, name, zone, enemyType, count, level, levelReq)
	return { Id = id, Name = name, Target = { Kind = "Enemy", Zone = zone, Type = enemyType }, Count = count, Level = level, LevelReq = levelReq }
end

local list = {
	-- Stagione 1
	titan("Q_T3", "Elimina 6 Giganti da 3 metri", "Recinto", "T3", 6, 5, 1),
	titan("Q_T4", "Elimina 6 Giganti da 4 metri", "Recinto", "T4", 6, 13, 9),
	titan("Q_T5", "Ripulisci le strade: 7 Giganti da 5 metri", "Calaneth", "T5", 7, 26, 20),
	titan("Q_T7", "Difendi Calaneth: 7 Giganti da 7 metri", "Calaneth", "T7", 7, 46, 40),
	boss("Q_Ghignante", "Abbatti il Gigante Ghignante", "Ghignante", 72, 60),
	titan("Q_T7P", "Apri la strada: 7 Giganti da 7 metri", "PianureSud", "T7", 7, 82, 70),
	titan("Q_T10P", "Caccia nelle pianure: 6 Giganti da 10 metri", "PianureSud", "T10", 6, 102, 95),
	titan("Q_T10F", "Tra gli alberi: 6 Giganti da 10 metri", "Foresta", "T10", 6, 132, 120),
	titan("Q_T12F", "Gli anomali della foresta: 6 Giganti da 12 metri", "Foresta", "T12", 6, 162, 150),
	boss("Q_Cacciatrice", "Sconfiggi il Gigante Cacciatrice", "Cacciatrice", 205, 180),
	-- Stagione 2
	titan("Q_T7B", "Libera Brenn: 8 Giganti da 7 metri", "Brenn", "T7", 8, 212, 200),
	titan("Q_T10B", "La nebbia di Brenn: 6 Giganti da 10 metri", "Brenn", "T10", 6, 252, 240),
	titan("Q_T10O", "Difendi il castello: 6 Giganti da 10 metri", "Ostrava", "T10", 6, 292, 280),
	titan("Q_T12O", "Notte a Ostrava: 6 Giganti da 12 metri", "Ostrava", "T12", 6, 322, 310),
	boss("Q_Fauno", "Sconfiggi il Gigante Fauno", "Fauno", 355, 330),
	titan("Q_T12G", "La gola: 6 Giganti da 12 metri", "GolaEdenia", "T12", 6, 372, 350),
	titan("Q_T15G", "Giganti nel canyon: 5 Giganti da 15 metri", "GolaEdenia", "T15", 5, 412, 400),
	boss("Q_Bastione", "Sconfiggi il Gigante Bastione", "Bastione", 425, 400),
	boss("Q_Zanna", "Sconfiggi il Gigante Zanna", "Zanna", 455, 430),
	-- Stagione 3
	enemy("Q_Polizia1", "Arresta 7 Poliziotti Corrotti", "Stohlberg", "PoliziaCorrotta", 7, 462, 450),
	enemy("Q_Polizia2", "Smantella la rete: 8 Poliziotti Corrotti", "Stohlberg", "PoliziaCorrotta", 8, 522, 500),
	enemy("Q_Ombra1", "Ferma 7 Agenti Ombra", "CittaSotterranea", "SquadraOmbra", 7, 562, 550),
	enemy("Q_Ombra2", "Caccia nei vicoli: 8 Agenti Ombra", "CittaSotterranea", "SquadraOmbra", 8, 622, 600),
	{ Id = "Q_Corvo", Name = "Sconfiggi il Corvo Nero", Target = { Kind = "HumanBoss", Boss = "Corvo" }, Count = 1, Level = 655, LevelReq = 630, BossQuest = true },
	titan("Q_Cristallo1", "Giganti di cristallo: 7 Giganti da 7 metri", "CavernaCristallo", "T7", 7, 662, 650),
	titan("Q_Cristallo2", "Il cuore della caverna: 6 Giganti da 10 metri", "CavernaCristallo", "T10", 6, 702, 690),
	titan("Q_T12P", "La piana: 6 Giganti da 12 metri", "PianaOrvel", "T12", 6, 732, 720),
	titan("Q_T15P", "Il tremore: 5 Giganti da 15 metri", "PianaOrvel", "T15", 5, 772, 760),
	boss("Q_Strisciante", "Sconfiggi il Gigante Strisciante", "Strisciante", 805, 780),
	titan("Q_T12H", "Riconquista Halvar: 7 Giganti da 12 metri", "Halvar", "T12", 7, 822, 800),
	titan("Q_T15H", "Le rovine: 6 Giganti da 15 metri", "Halvar", "T15", 6, 882, 860),
	boss("Q_Vulcano", "Sconfiggi il Gigante Vulcano", "Vulcano", 955, 920),
	titan("Q_T15L", "Oltre il muro: 6 Giganti da 15 metri", "LandeCenere", "T15", 6, 922, 900),
	titan("Q_T15LA", "Lande selvagge: 6 Giganti da 15 metri", "LandeCenere", "T15", 6, 982, 960),
	-- Stagione 4
	enemy("Q_Soldati1", "Infiltrazione: 8 Soldati Valdoriani", "Trincee", "SoldatoValdoriano", 8, 1012, 1000),
	titan("Q_T10T", "Armi viventi: 6 Giganti da 10 metri", "Trincee", "T10", 6, 1082, 1060),
	titan("Q_T15T", "La terra di nessuno: 5 Giganti da 15 metri", "Trincee", "T15", 5, 1152, 1130),
	boss("Q_Destriero", "Sconfiggi il Gigante Destriero", "Destriero", 1205, 1180),
	enemy("Q_Soldati2", "Rivolta di Revelia: 8 Soldati Valdoriani", "Revelia", "SoldatoValdoriano", 8, 1222, 1200),
	enemy("Q_Guardie1", "Le guardie di Vael: 7 Guardie", "Revelia", "GuardiaVael", 7, 1352, 1330),
	titan("Q_T12R", "Caos in città: 6 Giganti da 12 metri", "Revelia", "T12", 6, 1302, 1280),
	boss("Q_Forgia", "Sconfiggi il Gigante della Forgia", "Forgia", 1455, 1420),
	enemy("Q_Guardie2", "Assalto alla fortezza: 8 Guardie di Vael", "Fortezza", "GuardiaVael", 8, 1482, 1450),
	enemy("Q_Guardie3", "Il laboratorio: 8 Guardie di Vael", "Fortezza", "GuardiaVael", 8, 1602, 1580),
	titan("Q_T15FV", "Esperimenti falliti: 6 Giganti da 15 metri", "Fortezza", "T15", 6, 1552, 1530),
	boss("Q_Furia", "Ferma il Gigante della Furia", "Furia", 1705, 1680),
	titan("Q_T15B1", "Il fronte: 7 Giganti da 15 metri", "FronteMarcia", "T15", 7, 1752, 1700),
	titan("Q_T15B2", "Anomali della Grande Marcia: 6 Giganti da 15 metri", "FronteMarcia", "T15", 6, 1852, 1820),
	titan("Q_TB", "Ferma la marcia: 3 Giganti della Grande Marcia", "FronteMarcia", "TB", 3, 1905, 1880),
	boss("Q_Primordiale", "RAID: Il Gigante Primordiale", "Primordiale", 2000, 1950),
}

Quests.List = {}
for _, quest in list do
	assert(Quests.List[quest.Id] == nil, "Missione duplicata: " .. quest.Id)
	Quests.List[quest.Id] = quest
end

function Quests.Get(id: string?)
	return id and Quests.List[id]
end

-- Ricompense (usano Leveling per restare bilanciate con la curva d'esperienza)
function Quests.Rewards(quest, leveling)
	local xp = leveling.QuestXP(quest.Level)
	local gold = leveling.QuestGold(quest.Level)
	if quest.BossQuest then
		xp *= 2.2
		gold *= 3
	end
	return math.floor(xp), math.floor(gold)
end

function Quests.TargetText(quest): string
	local t = quest.Target
	if t.Kind == "Boss" or t.Kind == "HumanBoss" then
		return quest.Name
	end
	return quest.Name
end

return Quests
