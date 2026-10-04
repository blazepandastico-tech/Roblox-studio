--[[
	Achievements - Traguardi (con medaglie Roblox opzionali)

	Ogni traguardo dà gemme. Se crei una Medaglia (Badge) su create.roblox.com → il tuo gioco →
	Medaglie, copia il suo ID in BadgeId: il giocatore la riceverà anche sul suo profilo Roblox
	(le medaglie compaiono sul profilo e portano nuovi giocatori al gioco).

	Stat:
	  Titans / Napes / Bosses / Enemies  → profile.Kills[...]
	  Level      → livello
	  RaidsWon   → raid vinti
	  Chapter    → capitoli della storia completati
	  PlayHours  → ore di gioco
	  Streak     → giorni di fila nel calendario
	  Friends    → amici nello stesso server
]]

local Achievements = {}

Achievements.List = {
	{ Id = "Benvenuto", Icon = "🎖️", Name = "Benvenuto, Recluta", Description = "Entra nel gioco per la prima volta.", Stat = "Level", Goal = 1, Gems = 5, BadgeId = 0 },
	{ Id = "PrimoSangue", Icon = "🩸", Name = "Primo Sangue", Description = "Uccidi il tuo primo gigante.", Stat = "Titans", Goal = 1, Gems = 5, BadgeId = 0 },
	{ Id = "Cacciatore100", Icon = "⚔️", Name = "Cacciatore", Description = "Uccidi 100 giganti.", Stat = "Titans", Goal = 100, Gems = 15, BadgeId = 0 },
	{ Id = "Cacciatore1000", Icon = "⚔️", Name = "Sterminatore", Description = "Uccidi 1.000 giganti.", Stat = "Titans", Goal = 1000, Gems = 40, BadgeId = 0 },
	{ Id = "Cacciatore10000", Icon = "☠️", Name = "Flagello dei Giganti", Description = "Uccidi 10.000 giganti.", Stat = "Titans", Goal = 10000, Gems = 120, BadgeId = 0 },
	{ Id = "Nuca50", Icon = "🎯", Name = "Colpo Preciso", Description = "Uccidi 50 giganti colpendo la nuca.", Stat = "Napes", Goal = 50, Gems = 10, BadgeId = 0 },
	{ Id = "Nuca1000", Icon = "🎯", Name = "Lama Infallibile", Description = "Uccidi 1.000 giganti colpendo la nuca.", Stat = "Napes", Goal = 1000, Gems = 50, BadgeId = 0 },
	{ Id = "PrimoBoss", Icon = "👹", Name = "Ammazzaboss", Description = "Sconfiggi il tuo primo boss.", Stat = "Bosses", Goal = 1, Gems = 15, BadgeId = 0 },
	{ Id = "Boss50", Icon = "👹", Name = "Leggenda delle Mura", Description = "Sconfiggi 50 boss.", Stat = "Bosses", Goal = 50, Gems = 80, BadgeId = 0 },
	{ Id = "Livello50", Icon = "⭐", Name = "Soldato", Description = "Raggiungi il livello 50.", Stat = "Level", Goal = 50, Gems = 10, BadgeId = 0 },
	{ Id = "Livello200", Icon = "⭐", Name = "Veterano", Description = "Raggiungi il livello 200 e salpa per Edenia.", Stat = "Level", Goal = 200, Gems = 25, BadgeId = 0 },
	{ Id = "Livello500", Icon = "🌟", Name = "Capitano", Description = "Raggiungi il livello 500.", Stat = "Level", Goal = 500, Gems = 50, BadgeId = 0 },
	{ Id = "Livello1000", Icon = "🌟", Name = "Comandante", Description = "Raggiungi il livello 1000 e attraversa il mare.", Stat = "Level", Goal = 1000, Gems = 100, BadgeId = 0 },
	{ Id = "Livello2000", Icon = "👑", Name = "Leggenda dell'Arcipelago", Description = "Raggiungi il livello massimo.", Stat = "Level", Goal = 2000, Gems = 300, BadgeId = 0 },
	{ Id = "Stagione1", Icon = "📜", Name = "Il Muro Infranto", Description = "Completa la Stagione 1 della storia.", Stat = "Chapter", Goal = 5, Gems = 30, BadgeId = 0 },
	{ Id = "Stagione2", Icon = "📜", Name = "La Nebbia", Description = "Completa la Stagione 2 della storia.", Stat = "Chapter", Goal = 9, Gems = 50, BadgeId = 0 },
	{ Id = "Stagione3", Icon = "📜", Name = "La Verità", Description = "Completa la Stagione 3 della storia.", Stat = "Chapter", Goal = 13, Gems = 80, BadgeId = 0 },
	{ Id = "Stagione4", Icon = "🏆", Name = "Oltre il Mare", Description = "Completa tutta la storia.", Stat = "Chapter", Goal = 17, Gems = 150, BadgeId = 0 },
	{ Id = "PrimoRaid", Icon = "🔱", Name = "Squadra d'Assalto", Description = "Vinci il tuo primo raid.", Stat = "RaidsWon", Goal = 1, Gems = 15, BadgeId = 0 },
	{ Id = "Raid25", Icon = "🔱", Name = "Maestro dei Raid", Description = "Vinci 25 raid.", Stat = "RaidsWon", Goal = 25, Gems = 60, BadgeId = 0 },
	{ Id = "Fedele7", Icon = "📅", Name = "Fedele", Description = "Gioca 7 giorni di fila.", Stat = "Streak", Goal = 7, Gems = 30, BadgeId = 0 },
	{ Id = "Ore10", Icon = "⏳", Name = "Instancabile", Description = "Gioca per 10 ore in totale.", Stat = "PlayHours", Goal = 10, Gems = 30, BadgeId = 0 },
	{ Id = "Compagni", Icon = "🤝", Name = "Compagni d'Armi", Description = "Gioca nello stesso server con un amico.", Stat = "Friends", Goal = 1, Gems = 10, BadgeId = 0 },
	{ Id = "Squadra", Icon = "👥", Name = "La Squadra al Completo", Description = "Gioca con 3 amici nello stesso server.", Stat = "Friends", Goal = 3, Gems = 25, BadgeId = 0 },
}

function Achievements.Get(id: string)
	for _, a in Achievements.List do
		if a.Id == id then
			return a
		end
	end
	return nil
end

-- Valore attuale di una statistica (funziona sia sul server sia sul client)
function Achievements.Value(profile, stat: string, extra: { [string]: number }?): number
	if stat == "Level" then
		return profile.Level or 0
	elseif stat == "Titans" or stat == "Napes" or stat == "Bosses" or stat == "Enemies" then
		return profile.Kills and profile.Kills[stat] or 0
	elseif stat == "RaidsWon" then
		return profile.RaidsWon or 0
	elseif stat == "Chapter" then
		local story = profile.Story
		if not story then
			return 0
		end
		return if story.Done then 17 else math.max(0, (story.Chapter or 1) - 1)
	elseif stat == "PlayHours" then
		return math.floor((profile.PlayTime or 0) / 3600)
	elseif stat == "Streak" then
		return profile.Streak and profile.Streak.Best or 0
	elseif stat == "Friends" then
		return extra and extra.Friends or (profile.FriendsSeen or 0)
	end
	return 0
end

return Achievements
