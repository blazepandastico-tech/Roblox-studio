--[[
	Raids - battaglie a ondate nell'Arena (Isola dell'Arena)
	Si avviano dai Maestri dei Raid (Quartier Generale, Aurion, Porto di Revelia).
	Chi avvia il raid paga l'oro (o consegna un Sigillo del Raid); gli altri si uniscono gratis
	durante il conto alla rovescia. Le ondate di giganti finiscono con un boss.
	Se tutti i partecipanti cadono, o scade il tempo, il raid è perso.
]]

local Raids = {}

Raids.LobbyTime = 30 -- secondi per unirsi
Raids.Intermission = 5 -- pausa tra un'ondata e l'altra
Raids.ReturnDelay = 8 -- secondi prima di tornare alla base a fine raid

Raids.List = {
	{
		Id = "Recinto",
		Name = "Assalto al Recinto",
		Icon = "🪵",
		LevelReq = 120,
		Level = 150,
		Cost = 15000,
		TimeLimit = 420,
		Waves = {
			{ Class = "T4", Count = 6 },
			{ Class = "T5", Count = 7 },
			{ Class = "T7", Count = 6, Abnormal = 0.3 },
		},
		Boss = { Id = "Ghignante", Level = 170, HPMult = 0.7 },
		Rewards = { XP = 3, Gold = 25000, Gems = 15, Fragments = { 1, 3 }, Drops = { { Id = "FialaAdrenalina", Chance = 0.4 } } },
	},
	{
		Id = "Foresta",
		Name = "La Caccia nella Foresta",
		Icon = "🌲",
		LevelReq = 300,
		Level = 340,
		Cost = 90000,
		TimeLimit = 480,
		Waves = {
			{ Class = "T7", Count = 8 },
			{ Class = "T10", Count = 7, Abnormal = 0.25 },
			{ Class = "T12", Count = 6, Abnormal = 0.35 },
		},
		Boss = { Id = "Cacciatrice", Level = 370, HPMult = 0.6 },
		Rewards = { XP = 3.5, Gold = 120000, Gems = 25, Fragments = { 2, 5 }, Drops = { { Id = "PergamenaEsperienza", Chance = 0.3 } } },
	},
	{
		Id = "Pietra",
		Name = "Le Mura di Pietra",
		Icon = "🛡️",
		LevelReq = 550,
		Level = 600,
		Cost = 350000,
		TimeLimit = 540,
		Waves = {
			{ Class = "T10", Count = 8 },
			{ Class = "T12", Count = 8, Abnormal = 0.3 },
			{ Class = "T15", Count = 6, Abnormal = 0.4 },
		},
		Boss = { Id = "Bastione", Level = 640, HPMult = 0.6 },
		Rewards = { XP = 4, Gold = 450000, Gems = 35, Fragments = { 3, 7 }, Drops = { { Id = "CristalloIndurito", Chance = 0.6, Min = 1, Max = 3 } } },
	},
	{
		Id = "Vulcano",
		Name = "Il Risveglio del Vulcano",
		Icon = "🌋",
		LevelReq = 900,
		Level = 960,
		Cost = 1200000,
		TimeLimit = 600,
		Waves = {
			{ Class = "T12", Count = 9, Abnormal = 0.3 },
			{ Class = "T15", Count = 8, Abnormal = 0.4 },
			{ Class = "T15", Count = 8, Abnormal = 0.6 },
		},
		Boss = { Id = "Vulcano", Level = 1000, HPMult = 0.5 },
		Rewards = { XP = 4.5, Gold = 1500000, Gems = 50, Fragments = { 5, 10 }, Drops = { { Id = "CristalloIndurito", Chance = 0.8, Min = 2, Max = 5 } } },
	},
	{
		Id = "Marcia",
		Name = "La Grande Marcia",
		Icon = "👣",
		LevelReq = 1500,
		Level = 1650,
		Cost = 5000000,
		TimeLimit = 720,
		Waves = {
			{ Class = "T15", Count = 10, Abnormal = 0.5 },
			{ Class = "TB", Count = 3 },
			{ Class = "T15", Count = 10, Abnormal = 0.8 },
			{ Class = "TB", Count = 5 },
		},
		Boss = { Id = "Primordiale", Level = 1750, HPMult = 0.35 },
		Rewards = { XP = 5, Gold = 6000000, Gems = 80, Fragments = { 8, 15 }, Drops = { { Id = "CristalloIndurito", Chance = 1, Min = 4, Max = 8 }, { Id = "LameAurora", Chance = 0.01 } } },
	},
}

Raids.ById = {}
for _, raid in Raids.List do
	assert(Raids.ById[raid.Id] == nil, "Raid duplicato: " .. raid.Id)
	Raids.ById[raid.Id] = raid
end

function Raids.Get(id: string?)
	return id and Raids.ById[id]
end

return Raids
