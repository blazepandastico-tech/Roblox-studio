--[[
	Festival - l'evento "Grande Inaugurazione" del gioco

	DATE (secondi Unix, ora UTC):
	  Start = 0           → l'evento è attivo da subito (appena pubblichi il gioco)
	  End   = 1792969200  → finisce il 26 ottobre 2026 alle 00:00 (ora italiana)
	Per cambiare le date usa https://www.epochconverter.com (incolla il numero che ti dà).
	Dal Pannello Admin (P → 📢 Server → 🎉 Grande Inaugurazione) si può accendere o spegnere l'evento in ogni momento.

	Durante l'evento:
	  - esperienza e oro DOPPI per tutti
	  - regalo di benvenuto (gemme + Medaglia dell'Inaugurazione)
	  - la cerimonia d'apertura (scena animata) la prima volta che entri
	  - il COLOSSO D'ORO cade dal cielo ogni 30 minuti nelle Pianure Meridionali
	  - spettacoli di fuochi d'artificio sopra le città ogni 10 minuti
	  - 8 sfide: completale tutte per il Mantello dell'Inaugurazione (esclusivo)
	  - addobbi di festa nelle città e il codice regalo INAUGURAZIONE
]]

local Festival = {}

Festival.Id = "Inaugurazione2026"
Festival.Name = "Grande Inaugurazione"
Festival.Start = 0
Festival.End = 1792969200

Festival.XPBonus = 1 -- +100% esperienza
Festival.GoldBonus = 1 -- +100% oro
Festival.WelcomeGems = 100
Festival.WelcomeItem = "MedagliaInaugurazione"
Festival.FinalItem = "MantelloInaugurazione"
Festival.FinalGems = 150

-- Colosso d'Oro: cade dal cielo, il livello si adatta ai giocatori presenti
Festival.Boss = {
	Id = "ColossoDorato",
	Zone = "PianureSud",
	FirstDelay = 240, -- secondi dopo l'avvio del server
	Interval = 1800, -- ogni 30 minuti
	Warning = 60, -- avviso un minuto prima
	Lifetime = 600, -- se nessuno lo sconfigge sparisce dopo 10 minuti
	HPPerPlayer = 0.35, -- +35% di vita per ogni giocatore in più nel server
	Gems = 15,
	Gold = 50000,
}

-- Spettacoli di fuochi d'artificio sopra le città (tutte insieme)
Festival.Fireworks = {
	Interval = 600,
	FirstDelay = 90,
	Duration = 40,
	Zones = { "CampoAddestramento", "Calaneth", "Aurion", "Brenn", "PortoRevelia", "ApprodoCenere", "PortoOrientale" },
	Range = 1300, -- chi è entro questa distanza vede lo spettacolo (e completa la sfida)
}

-- Città addobbate a festa
Festival.Decorated = { "CampoAddestramento", "Calaneth", "Aurion", "Brenn", "PortoRevelia", "PortoOrientale" }

-- Sfide dell'evento: Stat è il tipo di progresso registrato da FestivalService
Festival.Challenges = {
	{ Id = "Giganti", Icon = "⚔️", Name = "Caccia d'inaugurazione", Text = "Uccidi 30 giganti", Stat = "Titans", Goal = 30, Gems = 20, Gold = 20000 },
	{ Id = "Nuche", Icon = "🎯", Name = "Colpo da maestro", Text = "Uccidi 10 giganti colpendo la nuca", Stat = "Napes", Goal = 10, Gems = 15, Gold = 15000 },
	{ Id = "Colosso", Icon = "👑", Name = "Contro il Colosso d'Oro", Text = "Aiuta a sconfiggere il Colosso d'Oro", Stat = "Colossus", Goal = 1, Gems = 40, Gold = 40000 },
	{ Id = "Forzieri", Icon = "📦", Name = "Cacciatore di tesori", Text = "Apri 3 forzieri nascosti", Stat = "Treasures", Goal = 3, Gems = 20, Gold = 20000 },
	{ Id = "Isolotti", Icon = "⛵", Name = "Lupo di mare", Text = "Visita 3 isolotti del mare aperto", Stat = "Islets", Goal = 3, Gems = 20, Gold = 20000 },
	{ Id = "Fuochi", Icon = "🎆", Name = "Lo spettacolo", Text = "Guarda uno spettacolo di fuochi d'artificio in città", Stat = "Fireworks", Goal = 1, Gems = 10, Gold = 10000 },
	{ Id = "Taverna", Icon = "🍺", Name = "Un brindisi", Text = "Mangia un pasto caldo in una taverna", Stat = "Meal", Goal = 1, Gems = 10, Gold = 10000 },
	{ Id = "Duello", Icon = "🤺", Name = "Gloria nell'arena", Text = "Vinci un duello (Arena dei Duelli o PvP)", Stat = "PvPKills", Goal = 1, Gems = 15, Gold = 15000 },
}

Festival.ById = {}
for _, c in Festival.Challenges do
	Festival.ById[c.Id] = c
end

-- L'evento è attivo in questo momento? (override = scelta dell'admin: true/false/nil)
function Festival.IsActive(now: number, override: boolean?): boolean
	if override ~= nil then
		return override
	end
	return now >= Festival.Start and (Festival.End == 0 or now < Festival.End)
end

-- "5g 3h", "2h 14m", "45s"
function Festival.FormatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local d = seconds // 86400
	local h = (seconds % 86400) // 3600
	local m = (seconds % 3600) // 60
	if d > 0 then
		return ("%dg %dh"):format(d, h)
	elseif h > 0 then
		return ("%dh %dm"):format(h, m)
	elseif m > 0 then
		return ("%dm %02ds"):format(m, seconds % 60)
	end
	return ("%ds"):format(seconds % 60)
end

return Festival
