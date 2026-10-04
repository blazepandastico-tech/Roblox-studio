--[[
	Monetization - Negozio premium: Gemme, Monete, Game Pass e Negozio delle Gemme

	COME ATTIVARE GLI ACQUISTI CON ROBUX
	  1) Pubblica il gioco su Roblox.
	  2) Su create.roblox.com → il tuo gioco → Monetizzazione:
	       • "Developer Products": crea un prodotto per ogni voce di Products (stesso prezzo)
	       • "Passes": crea un pass per ogni voce di GamePasses
	  3) Copia gli ID numerici qui sotto (ProductId / PassId).
	Finché un ID vale 0, in Studio l'acquisto viene simulato GRATIS (per provare),
	mentre nel gioco pubblicato la voce appare come "non disponibile".

	Le Gemme sono la valuta premium: si comprano con Robux, ma se ne guadagnano
	anche giocando (raid, primo boss di ogni zona, codici), così il gioco resta equo.
]]

local Monetization = {}

-- Pacchetti con Robux (Developer Products)
Monetization.Products = {
	{ Id = "Gemme100", ProductId = 0, Kind = "Gems", Amount = 100, Robux = 49, Name = "Manciata di Gemme", Icon = "💎" },
	{ Id = "Gemme550", ProductId = 0, Kind = "Gems", Amount = 550, Robux = 249, Name = "Sacchetto di Gemme", Icon = "💎", Tag = "+10%" },
	{ Id = "Gemme1200", ProductId = 0, Kind = "Gems", Amount = 1200, Robux = 499, Name = "Scrigno di Gemme", Icon = "💎", Tag = "+20%" },
	{ Id = "Gemme2600", ProductId = 0, Kind = "Gems", Amount = 2600, Robux = 999, Name = "Forziere di Gemme", Icon = "💎", Tag = "+30%" },
	{ Id = "Gemme7000", ProductId = 0, Kind = "Gems", Amount = 7000, Robux = 2499, Name = "Tesoro Reale di Gemme", Icon = "👑", Tag = "MIGLIOR VALORE" },
	{ Id = "Monete50K", ProductId = 0, Kind = "Gold", Amount = 50000, Robux = 49, Name = "Borsa di Monete", Icon = "💰" },
	{ Id = "Monete400K", ProductId = 0, Kind = "Gold", Amount = 400000, Robux = 249, Name = "Cassa di Monete", Icon = "💰", Tag = "+60%" },
	{ Id = "Monete2M", ProductId = 0, Kind = "Gold", Amount = 2000000, Robux = 799, Name = "Tesoro di Monete", Icon = "💰", Tag = "+150%" },
	-- giri della Ruota della Fortuna (non compaiono dove i premi casuali a pagamento sono vietati)
	{ Id = "Giri3", ProductId = 0, Kind = "Spins", Amount = 3, Robux = 79, Name = "3 giri della Ruota", Icon = "🎡" },
	{ Id = "Giri10", ProductId = 0, Kind = "Spins", Amount = 10, Robux = 229, Name = "10 giri della Ruota", Icon = "🎡", Tag = "+25%" },
	-- offerta di benvenuto: una sola volta, solo nei primi 3 giorni dal primo accesso
	{
		Id = "PacchettoIniziale",
		ProductId = 0,
		Kind = "Starter",
		Robux = 99,
		Name = "Pacchetto della Recluta",
		Icon = "🎁",
		Tag = "-80% SOLO ORA",
		Bundle = { Gems = 300, Gold = 150000, Spins = 3, Items = { MantelloNotte = 1, PergamenaEsperienza = 3 } },
		Contents = "300 💎 • 150.000 💰 • 3 🎡 • Mantello della Notte • 3 Pergamene XP",
	},
}

-- Ore dal primo accesso in cui il Pacchetto della Recluta resta disponibile
Monetization.StarterHours = 72

-- Game Pass (si comprano una volta sola e valgono per sempre)
-- Bonuses usa le stesse chiavi dell'equipaggiamento (vedi StatsCalc)
Monetization.GamePasses = {
	{ Id = "OroDoppio", PassId = 0, Robux = 349, Icon = "💰", Name = "Oro Doppio", Description = "Guadagni il doppio dell'oro da giganti, missioni e raid.", Bonuses = { GoldBonus = 1 } },
	{ Id = "EsperienzaDoppia", PassId = 0, Robux = 399, Icon = "📈", Name = "Esperienza Doppia", Description = "Sali di livello due volte più in fretta.", Bonuses = { XPBonus = 1 } },
	{ Id = "BomboleRinforzate", PassId = 0, Robux = 199, Icon = "💨", Name = "Bombole Rinforzate", Description = "+50% efficienza del gas dei rampini: voli molto più a lungo.", Bonuses = { GasEfficiency = 0.5 } },
	{ Id = "Fortuna", PassId = 0, Robux = 449, Icon = "🍀", Name = "Fortuna del Cacciatore", Description = "+50% probabilità di trovare Frammenti di Siero e oggetti rari.", Bonuses = { FragmentChance = 0.5, DropLuck = 0.5 } },
	{ Id = "Viaggiatore", PassId = 0, Robux = 249, Icon = "🧭", Name = "Viaggiatore", Description = "Viaggio rapido dal menu verso le isole sbloccate, ovunque ti trovi.", Bonuses = {} },
	{ Id = "VIP", PassId = 0, Robux = 499, Icon = "👑", Name = "VIP dell'Arcipelago", Description = "Nome dorato, Mantello Reale VIP in regalo, +10% oro ed esperienza e 100 gemme al giorno.", Bonuses = { GoldBonus = 0.1, XPBonus = 0.1 }, DailyGems = 100, GiftItem = "MantelloVIP" },
}

-- Negozio delle Gemme (si paga con le gemme guadagnate o comprate)
Monetization.GemShop = {
	{ Id = "SigilloRaid", Gems = 40, Item = "SigilloRaid", Count = 1, Icon = "🔱", Name = "Sigillo del Raid", Description = "Avvia un raid senza pagare l'oro richiesto." },
	{ Id = "PozioneOro", Gems = 60, Item = "PozioneOro", Count = 1, Icon = "🧪", Name = "Pozione dell'Oro", Description = "Oro doppio per 30 minuti (si somma al pass)." },
	{ Id = "PergamenaEsperienza", Gems = 60, Item = "PergamenaEsperienza", Count = 2, Icon = "📜", Name = "2 Pergamene dell'Esperienza", Description = "Esperienza doppia per 15 minuti ciascuna." },
	{ Id = "FialaAdrenalina", Gems = 35, Item = "FialaAdrenalina", Count = 3, Icon = "💉", Name = "3 Fiale di Adrenalina", Description = "+50% danni per 30 secondi ciascuna." },
	{ Id = "PergamenaAntenati", Gems = 150, Item = "PergamenaAntenati", Count = 1, Icon = "🧬", Name = "Pergamena degli Antenati", Description = "Cambia la tua Stirpe a caso." },
	{ Id = "AzzeraStatistiche", Gems = 50, Action = "ResetStats", Icon = "📊", Name = "Azzera Statistiche", Description = "Recupera tutti i punti statistica per ridistribuirli." },
	{ Id = "MantelloCremisi", Gems = 400, Item = "MantelloCremisi", Count = 1, Unique = true, Icon = "🧥", Name = "Mantello Cremisi", Description = "Accessorio cosmetico: un mantello rosso fuoco. +5% oro." },
	{ Id = "MantelloNotte", Gems = 400, Item = "MantelloNotte", Count = 1, Unique = true, Icon = "🌙", Name = "Mantello della Notte", Description = "Accessorio cosmetico: un mantello blu notte. +5% esperienza." },
}

-- Gemme guadagnate giocando
Monetization.Earn = {
	FirstBossKill = 25, -- prima volta che sconfiggi un boss
	DailyLogin = 10, -- primo accesso del giorno
}

-- Un prodotto o pass si può comprare solo se ha il suo ID Roblox (in Studio viene simulato)
function Monetization.IsAvailable(entry): boolean
	local id = entry.ProductId or entry.PassId or 0
	return id ~= 0 or game:GetService("RunService"):IsStudio()
end

function Monetization.Product(id: string)
	for _, p in Monetization.Products do
		if p.Id == id then
			return p
		end
	end
	return nil
end

function Monetization.ProductByRobloxId(productId: number)
	for _, p in Monetization.Products do
		if p.ProductId ~= 0 and p.ProductId == productId then
			return p
		end
	end
	return nil
end

function Monetization.Pass(id: string)
	for _, p in Monetization.GamePasses do
		if p.Id == id then
			return p
		end
	end
	return nil
end

function Monetization.GemItem(id: string)
	for _, g in Monetization.GemShop do
		if g.Id == id then
			return g
		end
	end
	return nil
end

-- Bonus dei pass posseduti (profile.Passes = { [Id] = true })
function Monetization.PassBonuses(passes: { [string]: boolean }?)
	local total = {}
	if not passes then
		return total
	end
	for _, pass in Monetization.GamePasses do
		if passes[pass.Id] then
			for key, value in pass.Bonuses do
				total[key] = (total[key] or 0) + value
			end
		end
	end
	return total
end

return Monetization
