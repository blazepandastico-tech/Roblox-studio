--[[
	AbuseEvents - gli eventi a tempo dell'Admin Abuse, ispirati alla prima stagione
	Dal Pannello Admin (P → 😈 Admin Abuse → Animazioni) l'admin sceglie la durata e il tipo di evento:
	parte subito un'animazione per tutti i giocatori, poi l'evento dura il tempo scelto.

	Ogni evento ha:
	  - Bonus: esperienza, oro e danni in più per tutti (0.5 = +50%)
	  - Sky: colori del cielo durante l'evento (li usa SkyController)
	  - Ambient: le particelle che cadono attorno al giocatore
	Cosa succede nel mondo (giganti, boss, razzi) lo decide AbuseService sul server;
	le animazioni le fa AbuseEventController sul client.

	EVENTI DI HALLOWEEN (Theme = "Halloween"): ci sono solo nel file di Halloween (Shared/Data/Tema).
	PREMI: per ogni evento l'admin sceglie dal pannello i premi in più (Rewards qui sotto): dolcetti per
	ogni gigante, premio finale per chi ha partecipato, bonus doppi.
	PROGRAMMAZIONE: un evento si può far partire subito o programmare per un giorno e un'ora, con un
	annuncio scritto dall'admin e gli avvisi prima dell'inizio (AbuseScheduleService).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbuseEvents = {}

AbuseEvents.MinMinutes = 1
AbuseEvents.MaxMinutes = 120
AbuseEvents.DefaultMinutes = 5
AbuseEvents.Durations = { 1, 3, 5, 10, 15, 30, 60 } -- pulsanti rapidi nel pannello

AbuseEvents.List = {
	{
		Id = "CadutaMuro",
		Icon = "🧱",
		Name = "La Caduta del Muro",
		Episode = "Stagione 1 • Il giorno in cui il Muro cadde",
		Short = "Il Vulcano sfonda il cancello: invasioni ovunque",
		Text = "Il Gigante Vulcano si affaccia oltre il Muro e sfonda il cancello: i giganti invadono le zone dove siete voi!",
		Color = Color3.fromRGB(255, 96, 52),
		Bonus = { XP = 1, Gold = 0.5 },
		Sky = {
			Color = Color3.fromRGB(255, 120, 70),
			Decay = Color3.fromRGB(120, 30, 20),
			Tint = Color3.fromRGB(255, 196, 170),
			Density = 0.32,
			Haze = 2.4,
			Glare = 0.4,
			Exposure = -0.05,
			Saturation = 0.05,
			Contrast = 0.12,
			Bright = 0.7,
			CloudColor = Color3.fromRGB(150, 70, 50),
			Cover = 0.85,
			Rain = 0,
		},
		Ambient = "Cenere",
	},
	{
		Id = "CaricaBastione",
		Icon = "🛡️",
		Name = "La Carica del Bastione",
		Episode = "Stagione 1 • Il gigante corazzato",
		Short = "Il Bastione carica: boss corazzato e oro x3",
		Text = "Il Gigante Bastione carica le mura a tutta velocità! Abbattilo: oro triplo per tutti finché dura l'evento.",
		Color = Color3.fromRGB(230, 190, 110),
		Bonus = { Gold = 2, XP = 0.5 },
		Boss = "Bastione",
		Sky = {
			Color = Color3.fromRGB(220, 186, 130),
			Decay = Color3.fromRGB(140, 104, 60),
			Tint = Color3.fromRGB(255, 236, 200),
			Density = 0.36,
			Haze = 2.8,
			Glare = 0.2,
			Exposure = 0,
			Saturation = -0.12,
			Contrast = 0.1,
			Bright = 0.85,
			CloudColor = Color3.fromRGB(210, 180, 140),
			Cover = 0.7,
			Rain = 0,
		},
		Ambient = "Polvere",
	},
	{
		Id = "AssedioCalaneth",
		Icon = "🔥",
		Name = "L'Assedio di Calaneth",
		Episode = "Stagione 1 • La battaglia del distretto",
		Short = "Razzi rossi, invasione e giganti alleati",
		Text = "Il distretto è assediato! Razzi rossi nel cielo, i giganti entrano dalla breccia... e un gigante alleato combatte al vostro fianco.",
		Color = Color3.fromRGB(255, 60, 60),
		Bonus = { XP = 1, Gold = 1 },
		Sky = {
			Color = Color3.fromRGB(230, 110, 100),
			Decay = Color3.fromRGB(110, 40, 40),
			Tint = Color3.fromRGB(255, 210, 205),
			Density = 0.26,
			Haze = 1.8,
			Glare = 0.2,
			Exposure = -0.04,
			Saturation = 0,
			Contrast = 0.1,
			Bright = 0.8,
			CloudColor = Color3.fromRGB(170, 110, 110),
			Cover = 0.8,
			Rain = 0,
		},
		Ambient = "Fumo",
	},
	{
		Id = "UrloCacciatrice",
		Icon = "😱",
		Name = "L'Urlo della Cacciatrice",
		Episode = "Stagione 1 • La foresta degli alberi giganti",
		Short = "Boss Cacciatrice: il suo urlo richiama i giganti",
		Text = "La Cacciatrice urla tra gli alberi giganti e richiama orde di giganti contro di voi. Resistete e abbattetela!",
		Color = Color3.fromRGB(120, 230, 150),
		Bonus = { XP = 1.5, Gold = 0.5 },
		Boss = "Cacciatrice",
		Sky = {
			Color = Color3.fromRGB(150, 210, 160),
			Decay = Color3.fromRGB(40, 80, 50),
			Tint = Color3.fromRGB(220, 255, 225),
			Density = 0.34,
			Haze = 2.2,
			Glare = 0,
			Exposure = -0.06,
			Saturation = -0.05,
			Contrast = 0.08,
			Bright = 0.75,
			CloudColor = Color3.fromRGB(150, 180, 160),
			Cover = 0.75,
			Rain = 0,
		},
		Ambient = "Foglie",
	},
	{
		Id = "Spedizione",
		Icon = "🐎",
		Name = "La Spedizione oltre le Mura",
		Episode = "Stagione 1 • La grande spedizione",
		Short = "Razzi di segnalazione e giganti anomali: XP x3",
		Text = "Razzi di segnalazione nel cielo! Esperienza tripla e giganti anomali da cacciare: ognuno vale 5 gemme.",
		Color = Color3.fromRGB(90, 220, 110),
		Bonus = { XP = 2, Gold = 0.5 },
		AnomalyGems = 5,
		Sky = {
			Color = Color3.fromRGB(255, 214, 160),
			Decay = Color3.fromRGB(200, 120, 70),
			Tint = Color3.fromRGB(255, 240, 210),
			Density = 0.12,
			Haze = 1.2,
			Glare = 0.8,
			Exposure = 0.06,
			Saturation = 0.12,
			Contrast = 0.06,
			Bright = 1.1,
			CloudColor = Color3.fromRGB(255, 220, 190),
			Cover = 0.5,
			Rain = 0,
		},
		Ambient = "Vento",
	},
	{
		Id = "FulmineTrasformazione",
		Icon = "⚡",
		Name = "Il Fulmine della Trasformazione",
		Episode = "Stagione 1 • Il ragazzo diventato gigante",
		Short = "Temporale dorato: danni x2 e gas infinito",
		Text = "Fulmini dorati squarciano il cielo e risvegliano il Gigante della Furia: danni doppi e gas infinito per tutti!",
		Color = Color3.fromRGB(255, 220, 90),
		Bonus = { XP = 0.5, Gold = 0.5, Damage = 1 },
		InfiniteGas = true,
		Sky = {
			Color = Color3.fromRGB(110, 110, 150),
			Decay = Color3.fromRGB(30, 30, 50),
			Tint = Color3.fromRGB(215, 220, 255),
			Density = 0.3,
			Haze = 2,
			Glare = 0,
			Exposure = -0.12,
			Saturation = -0.2,
			Contrast = 0.18,
			Bright = 0.45,
			CloudColor = Color3.fromRGB(80, 82, 100),
			Cover = 0.98,
			Rain = 2,
		},
		Ambient = "Pioggia",
	},

	-- 🎃 EVENTI DI HALLOWEEN (solo nel file di Halloween) ---------------------------------------------
	{
		Id = "NotteZucche",
		Theme = "Halloween",
		Icon = "🎃",
		Name = "La Notte delle Zucche",
		Episode = "Halloween • Il Re Zucca sorge dall'orto stregato",
		Short = "Il Re Zucca e i giganti-zucca: oro x2 e dolcetti",
		Text = "Sotto la luna piena, dall'orto stregato oltre il Muro sorge il Re Zucca! Le zucche esplodono e ne escono giganti: ognuno abbattuto lascia un dolcetto d'oro.",
		Color = Color3.fromRGB(255, 136, 30),
		Bonus = { Gold = 1, XP = 0.5 },
		Boss = "ReZucca",
		Sky = {
			Color = Color3.fromRGB(255, 140, 60),
			Decay = Color3.fromRGB(90, 30, 70),
			Tint = Color3.fromRGB(255, 214, 180),
			Density = 0.3,
			Haze = 2.2,
			Glare = 0.3,
			Exposure = -0.06,
			Saturation = 0.1,
			Contrast = 0.14,
			Bright = 0.6,
			CloudColor = Color3.fromRGB(150, 70, 90),
			Cover = 0.75,
			Rain = 0,
		},
		Ambient = "Zucche",
	},
	{
		Id = "GiganteFantasma",
		Theme = "Halloween",
		Icon = "👻",
		Name = "Il Gigante Fantasma",
		Episode = "Halloween • Nella nebbia, oltre le mura",
		Short = "Giganti fantasma nella nebbia: ognuno vale 3 gemme",
		Text = "Una nebbia gelida avvolge l'arcipelago: giganti spettrali attraversano le mura come se non esistessero. Ogni fantasma abbattuto vale 3 gemme!",
		Color = Color3.fromRGB(140, 220, 255),
		Bonus = { XP = 1, Damage = 0.5 },
		Boss = "GiganteFantasma",
		GhostGems = 3,
		Sky = {
			Color = Color3.fromRGB(150, 170, 210),
			Decay = Color3.fromRGB(40, 50, 80),
			Tint = Color3.fromRGB(210, 230, 255),
			Density = 0.42,
			Haze = 3,
			Glare = 0,
			Exposure = -0.1,
			Saturation = -0.25,
			Contrast = 0.12,
			Bright = 0.5,
			CloudColor = Color3.fromRGB(110, 120, 150),
			Cover = 0.9,
			Rain = 0,
		},
		Ambient = "Nebbia",
	},
	{
		Id = "RisveglioCaduti",
		Theme = "Halloween",
		Icon = "💀",
		Name = "Il Risveglio dei Caduti",
		Episode = "Halloween • Il cimitero dei giganti",
		Short = "I giganti risorgono dalla terra: XP x3",
		Text = "Fulmini verdi sul cimitero oltre le mura: i giganti caduti risorgono dalla terra, vicino a voi! Esperienza tripla per chi li rimanda sottoterra.",
		Color = Color3.fromRGB(130, 255, 110),
		Bonus = { XP = 2, Gold = 0.5 },
		Sky = {
			Color = Color3.fromRGB(120, 170, 110),
			Decay = Color3.fromRGB(30, 50, 30),
			Tint = Color3.fromRGB(210, 255, 200),
			Density = 0.34,
			Haze = 2.4,
			Glare = 0,
			Exposure = -0.1,
			Saturation = -0.1,
			Contrast = 0.16,
			Bright = 0.5,
			CloudColor = Color3.fromRGB(70, 90, 70),
			Cover = 0.95,
			Rain = 0,
		},
		Ambient = "Cimitero",
	},
	{
		Id = "DolcettoScherzetto",
		Theme = "Halloween",
		Icon = "🍬",
		Name = "Dolcetto o Scherzetto",
		Episode = "Halloween • La Strega Bestia lancia le zucche",
		Short = "Pioggia di zucche piene di dolci: oro x3 e sorprese",
		Text = "La Strega Bestia lancia zucche oltre il Muro come fossero sassi! Raccogli le zucche cadute vicino a te: dentro ci sono oro, gemme ed esperienza... o uno scherzetto!",
		Color = Color3.fromRGB(255, 110, 190),
		Bonus = { Gold = 2 },
		CandyPumpkins = true,
		Sky = {
			Color = Color3.fromRGB(230, 150, 200),
			Decay = Color3.fromRGB(110, 50, 100),
			Tint = Color3.fromRGB(255, 225, 240),
			Density = 0.2,
			Haze = 1.6,
			Glare = 0.4,
			Exposure = 0,
			Saturation = 0.16,
			Contrast = 0.08,
			Bright = 0.85,
			CloudColor = Color3.fromRGB(220, 160, 200),
			Cover = 0.6,
			Rain = 0,
		},
		Ambient = "Dolcetti",
	},
	{
		Id = "LunaSangue",
		Theme = "Halloween",
		Icon = "🌕",
		Name = "La Luna di Sangue",
		Episode = "Halloween • Il Colosso contro la luna rossa",
		Short = "Luna rossa e pipistrelli: danni x2 e gas infinito",
		Text = "La luna diventa rossa come il sangue: il Colosso si staglia contro il cielo e nuvole di pipistrelli oscurano le stelle. Danni doppi e gas infinito per tutti!",
		Color = Color3.fromRGB(255, 50, 60),
		Bonus = { XP = 0.5, Gold = 0.5, Damage = 1 },
		InfiniteGas = true,
		Sky = {
			Color = Color3.fromRGB(200, 40, 50),
			Decay = Color3.fromRGB(60, 6, 20),
			Tint = Color3.fromRGB(255, 190, 190),
			Density = 0.3,
			Haze = 2,
			Glare = 0.2,
			Exposure = -0.14,
			Saturation = 0.05,
			Contrast = 0.2,
			Bright = 0.42,
			CloudColor = Color3.fromRGB(90, 20, 30),
			Cover = 0.7,
			Rain = 0,
		},
		Ambient = "Luna",
	},
}

-- tutti gli eventi (anche quelli di un altro tema); List tiene solo quelli di questo file
AbuseEvents.All = AbuseEvents.List
AbuseEvents.ById = {}
for i, def in AbuseEvents.All do
	def.Order = i
	AbuseEvents.ById[def.Id] = def
end

local function currentTheme(): string
	return if ReplicatedStorage:GetAttribute("Tema") == "Halloween" then "Halloween" else "Normale"
end

-- un evento si può lanciare in questo file? (gli eventi di Halloween solo nel file di Halloween)
function AbuseEvents.Available(def): boolean
	return def ~= nil and (def.Theme == nil or def.Theme == currentTheme())
end

-- nel file di Halloween gli eventi di Halloween vengono per primi
do
	local list = {}
	for _, def in AbuseEvents.All do
		if def.Theme ~= nil and AbuseEvents.Available(def) then
			table.insert(list, def)
		end
	end
	for _, def in AbuseEvents.All do
		if def.Theme == nil then
			table.insert(list, def)
		end
	end
	AbuseEvents.List = list
end

function AbuseEvents.Get(id: any)
	return if type(id) == "string" then AbuseEvents.ById[id] else nil
end

-- PREMI IN PIÙ (li sceglie l'admin per ogni evento) ------------------------------------------------------
AbuseEvents.Rewards = {
	{ Id = "Dolcetti", Icon = "🍬", Name = "Dolcetti", Text = "ogni gigante dell'evento abbattuto lascia un dolcetto: oro e a volte gemme o un giro della Ruota" },
	{ Id = "Partecipazione", Icon = "🏆", Name = "Premio finale", Text = "a fine evento gemme e oro per chi ha abbattuto almeno un gigante; i 3 migliori cacciatori vengono annunciati" },
	{ Id = "Doppio", Icon = "✨", Name = "Bonus doppi", Text = "raddoppia i bonus di esperienza e oro dell'evento" },
}

-- premi accesi all'inizio: nel file di Halloween dolcetti e premio finale, nel file normale nessuno
function AbuseEvents.DefaultRewards(): { [string]: boolean }
	local halloween = currentTheme() == "Halloween"
	return { Dolcetti = halloween, Partecipazione = halloween, Doppio = false }
end

-- solo i premi conosciuti, solo vero/falso
function AbuseEvents.CleanRewards(value: any): { [string]: boolean }
	local out = {}
	local src = if type(value) == "table" then value else AbuseEvents.DefaultRewards()
	for _, r in AbuseEvents.Rewards do
		out[r.Id] = src[r.Id] == true
	end
	return out
end

function AbuseEvents.RewardsText(rewards: { [string]: boolean }?): string
	local parts = {}
	for _, r in AbuseEvents.Rewards do
		if rewards and rewards[r.Id] then
			table.insert(parts, r.Icon .. " " .. r.Name)
		end
	end
	return table.concat(parts, "  •  ")
end

-- dolcetto per ogni gigante dell'evento: oro (più forte il gigante, più oro) e a volte gemme o un giro
AbuseEvents.Candy = {
	GoldBase = 30,
	GoldPerLevel = 1.4,
	GemChance = 0.12,
	SpinChance = 0.02,
	BossMult = 10,
}

-- premio finale: gemme (5 + 1 per gigante, al massimo 30), oro per gigante e il primo cacciatore
-- vince 20 gemme in più. Nel file di Halloween chi abbatte almeno 3 giganti vince anche un oggetto
-- della Collezione di Halloween che non ha ancora (Items.HalloweenCollection).
AbuseEvents.Participation = {
	GemsBase = 5,
	GemsPerKill = 1,
	GemsMax = 30,
	GoldKillsMax = 30,
	TopGems = 20,
	CollectionMinKills = 3,
}

-- zucche piene di dolci (Dolcetto o Scherzetto): una ogni tanto vicino a ogni giocatore
AbuseEvents.CandyPumpkin = {
	Every = 12, -- secondi
	PerPlayer = 5, -- al massimo, attorno a ogni giocatore
	Lifetime = 60,
	PickupRadius = 11,
	TrickChance = 0.2,
}

-- programmazione: avvisi prima dell'inizio (minuti) e limiti
AbuseEvents.Schedule = {
	Reminders = { 30, 10, 5, 1 },
	MaxDaysAhead = 60,
	MaxEntries = 20,
	MaxText = 150,
}

-- minuti validi (numero intero tra MinMinutes e MaxMinutes)
function AbuseEvents.ClampMinutes(value: any): number
	local n = tonumber(value) or AbuseEvents.DefaultMinutes
	if n ~= n then
		n = AbuseEvents.DefaultMinutes
	end
	return math.clamp(math.floor(n + 0.5), AbuseEvents.MinMinutes, AbuseEvents.MaxMinutes)
end

-- "4:05" oppure "1:02:30"
function AbuseEvents.FormatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return ("%d:%02d:%02d"):format(h, m, s)
	end
	return ("%d:%02d"):format(m, s)
end

return AbuseEvents
