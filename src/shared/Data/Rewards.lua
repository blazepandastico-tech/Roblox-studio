--[[
	Rewards - premi che fanno tornare i giocatori
	  • Calendario di 7 giorni: ogni giorno di fila un premio più grande (se salti un giorno si riparte).
	  • Regali a tempo: più minuti giochi oggi, più regali apri (si azzerano ogni giorno).
	  • Ruota della Fortuna: un giro gratis ogni 20 ore, altri giri dai premi o con Robux.
	    Le probabilità sono SEMPRE mostrate al giocatore (regola di Roblox per i premi casuali);
	    nei paesi dove i premi casuali a pagamento sono vietati, i giri a pagamento non compaiono.

	Oro: "GoldQuests = 3" significa "quanto 3 missioni al tuo livello", così il premio vale
	sia al livello 5 sia al livello 1500.
]]

local Rewards = {}

-- CALENDARIO -----------------------------------------------------------------------------
Rewards.Daily = {
	{ Day = 1, Icon = "💰", Name = "Borsa d'oro", GoldQuests = 3 },
	{ Day = 2, Icon = "💎", Name = "15 gemme", Gems = 15 },
	{ Day = 3, Icon = "🧪", Name = "Pozione dell'Oro", Items = { PozioneOro = 1 }, GoldQuests = 2 },
	{ Day = 4, Icon = "🎡", Name = "2 giri della Ruota", Spins = 2 },
	{ Day = 5, Icon = "📜", Name = "2 Pergamene XP", Items = { PergamenaEsperienza = 2 } },
	{ Day = 6, Icon = "💎", Name = "30 gemme", Gems = 30, GoldQuests = 3 },
	{ Day = 7, Icon = "👑", Name = "Forziere settimanale", Gems = 60, Spins = 3, Items = { SigilloRaid = 1, FrammentoSiero = 3 }, Big = true },
}

-- REGALI A TEMPO (minuti di gioco nella giornata) ----------------------------------------
Rewards.Playtime = {
	{ Minutes = 3, Icon = "🍞", Name = "3 Razioni", Items = { Razione = 3 } },
	{ Minutes = 8, Icon = "💰", Name = "Oro", GoldQuests = 1 },
	{ Minutes = 15, Icon = "🎡", Name = "1 giro della Ruota", Spins = 1 },
	{ Minutes = 25, Icon = "💉", Name = "2 Fiale di Adrenalina", Items = { FialaAdrenalina = 2 } },
	{ Minutes = 35, Icon = "💎", Name = "10 gemme", Gems = 10 },
	{ Minutes = 50, Icon = "📜", Name = "Pergamena XP", Items = { PergamenaEsperienza = 1 }, GoldQuests = 2 },
	{ Minutes = 70, Icon = "🎡", Name = "2 giri della Ruota", Spins = 2 },
	{ Minutes = 90, Icon = "👑", Name = "Gran regalo", Gems = 25, Items = { FrammentoSiero = 2 }, GoldQuests = 3, Big = true },
}

-- RUOTA DELLA FORTUNA -------------------------------------------------------------------
-- Weight = probabilità in percentuale (la somma deve fare 100)
Rewards.Wheel = {
	{ Id = "OroPiccolo", Icon = "💰", Name = "Oro", GoldQuests = 1, Weight = 28, Color = Color3.fromRGB(196, 150, 50) },
	{ Id = "Gemme10", Icon = "💎", Name = "10 gemme", Gems = 10, Weight = 18, Color = Color3.fromRGB(70, 150, 210) },
	{ Id = "Pozione", Icon = "🧪", Name = "Pozione dell'Oro", Items = { PozioneOro = 1 }, Weight = 12, Color = Color3.fromRGB(150, 110, 40) },
	{ Id = "Pergamena", Icon = "📜", Name = "Pergamena XP", Items = { PergamenaEsperienza = 1 }, Weight = 12, Color = Color3.fromRGB(90, 160, 110) },
	{ Id = "OroGrande", Icon = "💰", Name = "Tanto oro", GoldQuests = 4, Weight = 12, Color = Color3.fromRGB(220, 176, 60) },
	{ Id = "Frammenti", Icon = "🧬", Name = "2 Frammenti di Siero", Items = { FrammentoSiero = 2 }, Weight = 9, Color = Color3.fromRGB(150, 70, 160) },
	{ Id = "Gemme50", Icon = "💎", Name = "50 gemme", Gems = 50, Weight = 5, Color = Color3.fromRGB(60, 120, 230) },
	{ Id = "Sigillo", Icon = "🔱", Name = "Sigillo del Raid", Items = { SigilloRaid = 1 }, Weight = 3, Color = Color3.fromRGB(180, 60, 60) },
	-- premio massimo: mantello raro (se lo hai già, 150 gemme)
	{ Id = "Jackpot", Icon = "🧥", Name = "JACKPOT: Mantello Cremisi", Items = { MantelloCremisi = 1 }, UniqueItem = "MantelloCremisi", FallbackGems = 150, Weight = 1, Color = Color3.fromRGB(230, 40, 50), Big = true },
}

Rewards.FreeSpinHours = 20

function Rewards.WheelTotal(): number
	local total = 0
	for _, prize in Rewards.Wheel do
		total += prize.Weight
	end
	return total
end

function Rewards.WheelPrize(id: string)
	for _, prize in Rewards.Wheel do
		if prize.Id == id then
			return prize
		end
	end
	return nil
end

return Rewards
