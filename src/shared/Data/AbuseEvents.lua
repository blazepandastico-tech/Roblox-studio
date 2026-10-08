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
]]

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
}

AbuseEvents.ById = {}
for i, def in AbuseEvents.List do
	def.Order = i
	AbuseEvents.ById[def.Id] = def
end

function AbuseEvents.Get(id: any)
	return if type(id) == "string" then AbuseEvents.ById[id] else nil
end

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
