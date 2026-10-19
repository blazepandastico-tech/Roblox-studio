--[[
	Monetization - Negozio con Robux: Offerte, Monete, Gemme, Pass permanenti e Negozio delle Gemme

	COME ATTIVARE GLI ACQUISTI CON ROBUX
	  1) Pubblica il gioco su Roblox.
	  2) Su create.roblox.com → il tuo gioco → Monetizzazione:
	       • "Developer Products": crea un prodotto per ogni voce di Products, Offers e FlashOffers
	         (stesso prezzo in Robux; il nome può essere lo stesso)
	       • "Passes": crea un pass per ogni voce di GamePasses
	  3) Copia gli ID numerici qui sotto (ProductId / PassId).
	Finché un ID vale 0, in Studio l'acquisto viene simulato GRATIS (per provare),
	mentre nel gioco pubblicato la voce appare come "in arrivo".

	COME SONO FATTE LE OFFERTE
	  • Monete: la quantità cresce con il livello del giocatore (Amount + PerLevel × livello),
	    così un pacchetto resta utile anche a chi è al livello 1500.
	  • Offerte a tempo: ogni 6 ore cambiano le 3 offerte (uguali in tutti i server), ognuna si
	    compra una volta per turno.
	  • Offerte lampo del server: in ogni server, ogni 40 minuti, un'offerta molto scontata per
	    10 minuti con un numero vero di pezzi (FlashStock): quando finiscono, finiscono.
	  • Primo acquisto: il primo acquisto con Robux di ogni giocatore raddoppia le gemme dei
	    pacchetti di gemme, e con gli altri prodotti regala FirstPurchaseGems gemme.
	  • Il "Valore" mostrato nelle offerte si calcola davvero dai prezzi del negozio
	    (gemme al prezzo del Sacchetto, monete al prezzo della Cassa, oggetti al prezzo del negozio
	    delle gemme o con ItemGemValue): niente sconti inventati.

	Le Gemme sono la valuta premium: si comprano con Robux, ma se ne guadagnano
	anche giocando (raid, primo boss di ogni zona, codici), così il gioco resta equo.
]]

local Monetization = {}

-- Pacchetti con Robux (Developer Products)
Monetization.Products = {
	-- 💎 gemme
	{ Id = "Gemme100", ProductId = 0, Kind = "Gems", Amount = 100, Robux = 49, Name = "Manciata di Gemme", Icon = "💎" },
	{ Id = "Gemme600", ProductId = 0, Kind = "Gems", Amount = 600, Robux = 249, Name = "Sacchetto di Gemme", Icon = "💎" },
	{ Id = "Gemme1300", ProductId = 0, Kind = "Gems", Amount = 1300, Robux = 499, Name = "Scrigno di Gemme", Icon = "💎", Tag = "POPOLARE" },
	{ Id = "Gemme2800", ProductId = 0, Kind = "Gems", Amount = 2800, Robux = 999, Name = "Forziere di Gemme", Icon = "💎" },
	{ Id = "Gemme7500", ProductId = 0, Kind = "Gems", Amount = 7500, Robux = 2499, Name = "Tesoro Reale di Gemme", Icon = "👑" },
	{ Id = "Gemme16000", ProductId = 0, Kind = "Gems", Amount = 16000, Robux = 4999, Name = "Montagna di Gemme", Icon = "🏔️", Tag = "MIGLIOR VALORE" },
	-- 💰 monete d'oro (Amount + PerLevel × livello del giocatore)
	{ Id = "Monete1", ProductId = 0, Kind = "Gold", Amount = 40000, PerLevel = 2500, Robux = 49, Name = "Borsa di Monete", Icon = "💰" },
	{ Id = "Monete2", ProductId = 0, Kind = "Gold", Amount = 120000, PerLevel = 7500, Robux = 129, Name = "Sacco di Monete", Icon = "💰" },
	{ Id = "Monete3", ProductId = 0, Kind = "Gold", Amount = 300000, PerLevel = 19000, Robux = 299, Name = "Cassa di Monete", Icon = "💰", Tag = "POPOLARE" },
	{ Id = "Monete4", ProductId = 0, Kind = "Gold", Amount = 600000, PerLevel = 38000, Robux = 549, Name = "Forziere di Monete", Icon = "🪙" },
	{ Id = "Monete5", ProductId = 0, Kind = "Gold", Amount = 1200000, PerLevel = 76000, Robux = 999, Name = "Tesoro di Monete", Icon = "🪙" },
	{ Id = "Monete6", ProductId = 0, Kind = "Gold", Amount = 2800000, PerLevel = 175000, Robux = 1999, Name = "Caveau Reale", Icon = "🏦", Tag = "MIGLIOR VALORE" },
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
		Tag = "SOLO PER LE RECLUTE",
		Bundle = { Gems = 300, Gold = 150000, Spins = 3, Items = { MantelloNotte = 1, PergamenaEsperienza = 3 } },
		Contents = "300 💎 • 150.000 💰 • 3 🎡 • Mantello della Notte • 3 Pergamene XP",
	},
	-- tutti i pass in un colpo solo (si vede solo a chi non ha ancora nessun pass)
	{
		Id = "PacchettoLeggendario",
		ProductId = 0,
		Kind = "PassBundle",
		Robux = 1499,
		Name = "Pacchetto Leggendario",
		Icon = "🏆",
		Tag = "TUTTI I PASS",
		Bundle = { Gems = 1000, Items = { MantelloLeggenda = 1 } },
		Contents = "Tutti i 9 pass permanenti • 1.000 💎 • Mantello della Leggenda (esclusivo)",
	},
}

-- Ore dal primo accesso in cui il Pacchetto della Recluta resta disponibile
Monetization.StarterHours = 72

-- Primo acquisto con Robux: gemme raddoppiate (pacchetti di gemme) o queste gemme in regalo
Monetization.FirstPurchaseGems = 150

-- Game Pass (si comprano una volta sola e valgono per sempre)
-- Bonuses usa le stesse chiavi dell'equipaggiamento (vedi StatsCalc)
Monetization.GamePasses = {
	{ Id = "OroDoppio", PassId = 0, Robux = 349, Icon = "💰", Name = "Oro Doppio", Description = "Guadagni il doppio dell'oro da giganti, missioni e raid.", Bonuses = { GoldBonus = 1 } },
	{ Id = "EsperienzaDoppia", PassId = 0, Robux = 399, Icon = "📈", Name = "Esperienza Doppia", Description = "Sali di livello due volte più in fretta.", Bonuses = { XPBonus = 1 } },
	{ Id = "MaestriaRapida", PassId = 0, Robux = 299, Icon = "⚔️", Name = "Maestria Rapida", Description = "La maestria delle armi sale il doppio: sblocchi prima le abilità X, C e V e fai più danni.", Bonuses = {}, MasteryMult = 2 },
	{ Id = "LameEterne", PassId = 0, Robux = 249, Icon = "🗡️", Name = "Lame Eterne", Description = "Le lame durano il doppio prima di spezzarsi: meno ricariche, più colpi alla nuca.", Bonuses = { BladeLife = 1 } },
	{ Id = "BomboleRinforzate", PassId = 0, Robux = 199, Icon = "💨", Name = "Bombole Rinforzate", Description = "+50% efficienza del gas dei rampini: voli molto più a lungo.", Bonuses = { GasEfficiency = 0.5 } },
	{ Id = "Fortuna", PassId = 0, Robux = 449, Icon = "🍀", Name = "Fortuna del Cacciatore", Description = "+50% probabilità di trovare Frammenti di Siero e oggetti rari.", Bonuses = { FragmentChance = 0.5, DropLuck = 0.5 } },
	{ Id = "ScontoMercante", PassId = 0, Robux = 199, Icon = "🏷️", Name = "Amico dei Mercanti", Description = "-20% sui prezzi in oro di armerie, empori e Laboratorio.", Bonuses = {}, ShopDiscount = 0.2 },
	{ Id = "Viaggiatore", PassId = 0, Robux = 249, Icon = "🧭", Name = "Viaggiatore", Description = "Viaggio rapido dal menu verso le isole sbloccate, ovunque ti trovi.", Bonuses = {} },
	{ Id = "VIP", PassId = 0, Robux = 499, Icon = "👑", Name = "VIP dell'Arcipelago", Description = "Nome dorato, Mantello Reale VIP in regalo, +10% oro ed esperienza e 100 gemme al giorno.", Bonuses = { GoldBonus = 0.1, XPBonus = 0.1 }, DailyGems = 100, GiftItem = "MantelloVIP" },
}

-- OFFERTE A TEMPO (uguali in tutti i server, cambiano ogni OfferHours ore) ------------------------
-- Bundle: Gems, Gold, GoldPack (le monete di quel pacchetto al tuo livello), Items
Monetization.OfferHours = 6
Monetization.OfferSlots = 3
Monetization.Offers = {
	{ Id = "OffCacciatore", ProductId = 0, Robux = 129, Icon = "🏹", Name = "Kit del Cacciatore", Bundle = { Gems = 400, Items = { FialaAdrenalina = 5, PergamenaEsperienza = 2, PozioneOro = 1 } } },
	{ Id = "OffLaboratorio", ProductId = 0, Robux = 299, Icon = "🧪", Name = "Scorta del Laboratorio", Bundle = { Gems = 500, Items = { MidolloGigante = 50, CristalloIndurito = 20 } } },
	{ Id = "OffFrammenti", ProductId = 0, Robux = 349, Icon = "🧬", Name = "Tesoro dei Frammenti", Bundle = { Gems = 300, Items = { FrammentoSiero = 40, CristalloIndurito = 15 } } },
	{ Id = "OffStirpe", ProductId = 0, Robux = 249, Icon = "🩸", Name = "Eredità della Stirpe", Bundle = { Gems = 400, Items = { PergamenaAntenati = 4 } } },
	{ Id = "OffNotte", ProductId = 0, Robux = 179, Icon = "🌙", Name = "Notte di Caccia", Bundle = { Gems = 350, Items = { PozioneOro = 4, PergamenaEsperienza = 5 } } },
	{ Id = "OffRaid", ProductId = 0, Robux = 229, Icon = "🔱", Name = "Assalto ai Raid", Bundle = { Gems = 550, Items = { SigilloRaid = 8, FialaAdrenalina = 5 } } },
	{ Id = "OffAlba", ProductId = 0, Robux = 399, Icon = "🌅", Name = "Collezione dell'Alba", Exclusive = "MantelloAlba", Bundle = { Gems = 500, Items = { MantelloAlba = 1, PergamenaEsperienza = 2 } } },
	{ Id = "OffRe", ProductId = 0, Robux = 799, Icon = "👑", Name = "Bottino del Re", Bundle = { Gems = 1500, GoldPack = "Monete4", Items = { CristalloIndurito = 20, FrammentoSiero = 20 } } },
}

-- OFFERTE LAMPO DEL SERVER (una alla volta, pezzi limitati per server) ------------------------------
Monetization.FlashEveryMinutes = 40
Monetization.FlashMinutes = 10
Monetization.FlashFirstMinutes = 6
Monetization.FlashStock = 10
Monetization.FlashOffers = {
	{ Id = "LampoGemme", ProductId = 0, Robux = 149, Icon = "💎", Name = "Sacco di Gemme Lampo", Bundle = { Gems = 650 } },
	{ Id = "LampoMateriali", ProductId = 0, Robux = 199, Icon = "💠", Name = "Materiali Rari Lampo", Bundle = { Items = { CristalloIndurito = 20, FrammentoSiero = 20, MidolloGigante = 40 } } },
	{ Id = "LampoBottino", ProductId = 0, Robux = 99, Icon = "🧪", Name = "Doppio Bottino Lampo", Bundle = { Gems = 150, Items = { PozioneOro = 3, PergamenaEsperienza = 3 } } },
	{ Id = "LampoTempesta", ProductId = 0, Robux = 249, Icon = "🌩️", Name = "Mantello della Tempesta", Exclusive = "MantelloTempesta", Bundle = { Gems = 300, Items = { MantelloTempesta = 1, FialaAdrenalina = 3 } } },
	{ Id = "LampoMonete", ProductId = 0, Robux = 199, Icon = "🪙", Name = "Monete Lampo", Bundle = { GoldPack = "Monete4" } },
}

-- Valore in gemme degli oggetti che non sono nel negozio delle gemme (per calcolare il "Valore")
Monetization.ItemGemValue = {
	CristalloIndurito = 25,
	FrammentoSiero = 20,
	MidolloGigante = 6,
	PolvereValdoriana = 6,
	Razione = 2,
	BombolaGas = 3,
	KitLame = 4,
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

-- Tutti i prodotti acquistabili con Robux (pacchetti, offerte a tempo e offerte lampo)
local function allProducts()
	local list = {}
	for _, group in { Monetization.Products, Monetization.Offers, Monetization.FlashOffers } do
		for _, p in group do
			table.insert(list, p)
		end
	end
	return list
end
Monetization.AllProducts = allProducts()
for _, offer in Monetization.Offers do
	offer.Kind = "Offer"
end
for _, offer in Monetization.FlashOffers do
	offer.Kind = "Flash"
end

function Monetization.Product(id: string)
	for _, p in Monetization.AllProducts do
		if p.Id == id then
			return p
		end
	end
	return nil
end

function Monetization.ProductByRobloxId(productId: number)
	for _, p in Monetization.AllProducts do
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

-- Monete di un pacchetto al livello del giocatore
function Monetization.GoldAmount(product, level: number): number
	return math.floor(product.Amount + (product.PerLevel or 0) * math.max(1, level or 1))
end

-- Quanto conviene un pacchetto rispetto al più piccolo dello stesso tipo (es. 0.36 = +36%)
function Monetization.ExtraValue(product, level: number?): number
	local base
	for _, p in Monetization.Products do
		if p.Kind == product.Kind and (not base or p.Robux < base.Robux) then
			base = p
		end
	end
	if not base or base == product then
		return 0
	end
	local function amount(p)
		return if p.Kind == "Gold" then Monetization.GoldAmount(p, level or 1) else p.Amount
	end
	return (amount(product) / product.Robux) / (amount(base) / base.Robux) - 1
end

-- Valore in Robux delle gemme e delle monete, ai prezzi dei pacchetti "di mezzo"
local function gemRobux(): number
	local p = Monetization.Product("Gemme600")
	return p.Robux / p.Amount
end

local function goldRobux(level: number): number
	local p = Monetization.Product("Monete3")
	return p.Robux / Monetization.GoldAmount(p, level)
end

-- Valore di un oggetto in gemme (negozio delle gemme o tabella ItemGemValue); nil = esclusivo
function Monetization.ItemGems(itemId: string): number?
	for _, g in Monetization.GemShop do
		if g.Item == itemId then
			return g.Gems / (g.Count or 1)
		end
	end
	return Monetization.ItemGemValue[itemId]
end

-- Monete di un'offerta al livello del giocatore
function Monetization.BundleGold(bundle, level: number): number
	local gold = bundle.Gold or 0
	if bundle.GoldPack then
		local pack = Monetization.Product(bundle.GoldPack)
		if pack then
			gold += Monetization.GoldAmount(pack, level)
		end
	end
	return gold
end

-- Valore in Robux di un'offerta se si comprasse tutto separatamente
function Monetization.BundleValue(entry, level: number): number
	local bundle = entry.Bundle or {}
	local robux = (bundle.Gems or 0) * gemRobux()
	robux += Monetization.BundleGold(bundle, level) * goldRobux(level)
	for id, count in bundle.Items or {} do
		local gems = Monetization.ItemGems(id)
		if gems then
			robux += gems * count * gemRobux()
		end
	end
	if entry.Kind == "PassBundle" then
		for _, pass in Monetization.GamePasses do
			robux += pass.Robux
		end
	end
	return math.floor(robux)
end

-- Turno attuale delle offerte a tempo: (numero del turno, ora in cui finisce, elenco di Id)
function Monetization.OfferRotation(now: number): (number, number, { string })
	local period = Monetization.OfferHours * 3600
	local slot = now // period
	local pool: { string } = {}
	for _, offer in Monetization.Offers do
		table.insert(pool, offer.Id)
	end
	local rng = Random.new(slot * 7919 + 17)
	local chosen: { string } = {}
	for _ = 1, math.min(Monetization.OfferSlots, #pool) do
		local index = rng:NextInteger(1, #pool)
		table.insert(chosen, pool[index])
		table.remove(pool, index)
	end
	return slot, (slot + 1) * period, chosen
end

-- Testo con il contenuto di un'offerta (al livello del giocatore)
function Monetization.Describe(entry, level: number, itemName: (string) -> string, formatNumber: (number) -> string): { string }
	local bundle = entry.Bundle or {}
	local lines = {}
	if entry.Kind == "PassBundle" then
		table.insert(lines, ("♾️ Tutti i %d pass permanenti"):format(#Monetization.GamePasses))
	end
	if bundle.Gems and bundle.Gems > 0 then
		table.insert(lines, ("💎 %s gemme"):format(formatNumber(bundle.Gems)))
	end
	local gold = Monetization.BundleGold(bundle, level)
	if gold > 0 then
		table.insert(lines, ("💰 %s monete"):format(formatNumber(gold)))
	end
	local ids = {}
	for id in bundle.Items or {} do
		table.insert(ids, id)
	end
	-- gli esclusivi prima di tutto
	table.sort(ids, function(a, b)
		local ea, eb = Monetization.ItemGems(a) == nil, Monetization.ItemGems(b) == nil
		if ea ~= eb then
			return ea
		end
		return a < b
	end)
	for _, id in ids do
		local count = bundle.Items[id]
		local name = itemName(id)
		if Monetization.ItemGems(id) == nil then
			table.insert(lines, ("⭐ %s (esclusivo)"):format(name))
		else
			table.insert(lines, ("%d× %s"):format(count, name))
		end
	end
	return lines
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
