--[[
	Treasures - forzieri nascosti in tutto l'arcipelago (premiano chi esplora)

	Mode dice dove appoggiare il forziere:
	  Top    = sopra la prima cosa che si incontra scendendo dal cielo (tetti, mura, torri, chiome)
	  Ground = sul terreno (ignora edifici e alberi)
	  Under  = nelle grotte sotterranee (parte dal soffitto della grotta)
	  Inside = dentro una taverna (parte dal soffitto della stanza)
	Tier: Comune (oro ed esperienza), Raro (+ gemme), Leggendario (+ tante gemme)
	Hint: la voce che l'oste racconta nelle taverne.
	Ogni giocatore può aprire ogni forziere una sola volta.
]]

local W = require(script.Parent.WorldLayout)
local Zones = require(script.Parent.Zones)

local Treasures = {}

local function zc(id: string): Vector3
	local zone = Zones.Get(id)
	return if zone then zone.Center else Vector3.zero
end

local function tavern(id: string, localPos: Vector3): Vector3
	return zc(W.TavernById[id].Zone) + W.TavernOffset(id, localPos)
end

local function islet(id: string, offset: Vector3?): Vector3
	return W.IsletById[id].Center + (offset or Vector3.zero)
end

Treasures.List = {
	-- VERMIGLIA ------------------------------------------------------------------------------
	{ Id = "MuroNord", Tier = "Comune", Pos = W.WallPoint("Vermiglia", 45), Mode = "Top", Hint = "Le sentinelle del Muro Vermiglio nascondono le loro paghe sul camminamento, a nord-est." },
	{ Id = "TettoQG", Tier = "Raro", Pos = zc("QuartierGenerale") + Vector3.new(0, 0, -48), Mode = "Top", Hint = "Sul tetto del mastio del Quartier Generale c'è qualcosa che il comandante non deve vedere." },
	{ Id = "DietroRecinto", Tier = "Comune", Pos = W.At("Vermiglia", 330, 430), Mode = "Ground", Hint = "Dietro il Recinto dei giganti catturati qualcuno ha seppellito una cassa." },
	{ Id = "SpiaggiaSud", Tier = "Comune", Pos = W.At("Vermiglia", 170, 1045), Mode = "Ground", Hint = "La marea porta di tutto sulla spiaggia a sud di Vermiglia." },
	{ Id = "TettiCalaneth", Tier = "Comune", Pos = zc("Calaneth") + Vector3.new(40, 0, -10), Mode = "Top", Hint = "A Calaneth i ladri corrono sui tetti. Uno di loro ha perso il bottino." },
	{ Id = "CuoreForesta", Tier = "Raro", Pos = zc("Foresta") + Vector3.new(30, 0, 20), Mode = "Top", Hint = "In cima agli alberi giganti della foresta, dove nemmeno i giganti arrivano..." },
	{ Id = "CantinaMuro", Tier = "Comune", Pos = tavern("TavernaMuro", Vector3.new(12, 0, 9)), Mode = "Inside", Hint = "Qui nella mia taverna? Non so niente di nessuna cassa in fondo alla sala... niente!" },
	{ Id = "PortoOrientaleFaro", Tier = "Comune", Pos = zc("PortoOrientale") + Vector3.new(136, 0, 3), Mode = "Top", Hint = "In fondo al Porto Orientale, dove finisce il molo, i pescatori lasciano le reti... e non solo." },
	{ Id = "TavernaGabbiano", Tier = "Comune", Pos = tavern("TavernaGabbiano", Vector3.new(13, 0, -1)), Mode = "Inside", Hint = "Al Gabbiano i marinai giocano a carte. Chi perde nasconde la vincita sotto i tavoli." },
	{ Id = "ArenaDuelliArco", Tier = "Raro", Pos = W.Landmarks.ArenaDuelli + Vector3.new(0, 0, -78), Mode = "Top", Hint = "Il campione dell'Arena dei Duelli tiene il suo premio sopra l'arco d'ingresso." },

	-- EDENIA ----------------------------------------------------------------------------------
	{ Id = "TorreOstrava", Tier = "Raro", Pos = zc("Ostrava"), Mode = "Top", Hint = "Sulla cima del castello di Ostrava, oltre la merlatura. Serve un buon rampino." },
	{ Id = "LagoOstrava", Tier = "Comune", Pos = W.Landmarks.LagoOstrava + Vector3.new(66, 0, 10), Mode = "Ground", Hint = "Sulla riva del laghetto vicino a Ostrava qualcuno ha dimenticato la sua sacca." },
	{ Id = "MulinoBrenn", Tier = "Raro", Pos = zc("Brenn") + Vector3.new(60, 0, -48), Mode = "Top", Hint = "Il mugnaio di Brenn nasconde i risparmi sul tetto del mulino." },
	{ Id = "LocandaCervo", Tier = "Comune", Pos = tavern("LocandaCervo", Vector3.new(12, 0, 9)), Mode = "Inside", Hint = "La Locanda del Cervo ha un angolo buio vicino al camino. Io non ci guarderei." },
	{ Id = "CrestaGola", Tier = "Raro", Pos = zc("GolaEdenia") + Vector3.new(-30, 0, 45), Mode = "Top", Hint = "Sulle creste di roccia della Gola di Edenia brilla qualcosa al tramonto." },
	{ Id = "SpiaggiaEdenia", Tier = "Comune", Pos = W.At("Edenia", 300, 990), Mode = "Ground", Hint = "La spiaggia a nord-ovest di Edenia è piena di relitti." },

	-- AUREA -----------------------------------------------------------------------------------
	{ Id = "CupolaPalazzo", Tier = "Leggendario", Pos = W.IslandCenter("Aurea") + Vector3.new(0, 0, -40), Mode = "Top", Hint = "Il tesoro della corona? Si dice sia sulla cupola del Palazzo Reale. Folle chi ci prova." },
	{ Id = "MuroAureo", Tier = "Comune", Pos = W.WallPoint("Aurea", 135), Mode = "Top", Hint = "Le guardie del Muro Aureo, a sud-est, giocano d'azzardo sul camminamento." },
	{ Id = "OsteriaAurea", Tier = "Comune", Pos = tavern("OsteriaAurea", Vector3.new(12, 0, 9)), Mode = "Inside", Hint = "All'Osteria Aurea i nobili lasciano le mance... in un forziere in fondo alla sala." },
	{ Id = "TettiStohlberg", Tier = "Comune", Pos = zc("Stohlberg") + Vector3.new(-20, 0, 20), Mode = "Top", Hint = "Sui tetti di Stohlberg c'è un nascondiglio dei contrabbandieri." },
	{ Id = "CittaSotterranea", Tier = "Raro", Pos = zc("CittaSotterranea") + Vector3.new(120, 0, -110), Mode = "Under", Hint = "Nella Città Sotterranea, nell'angolo più buio, c'è la cassa di un vecchio ladro." },
	{ Id = "CavernaCristallo", Tier = "Leggendario", Pos = zc("CavernaCristallo") + Vector3.new(-110, 0, 90), Mode = "Under", Hint = "Tra i cristalli della caverna sotto Aurea dorme un forziere antico." },
	{ Id = "PianaOrvel", Tier = "Comune", Pos = W.At("Aurea", 40, 820), Mode = "Ground", Hint = "Oltre la Piana di Orvel, verso la costa, c'è un carro abbandonato." },

	-- CENERE ----------------------------------------------------------------------------------
	{ Id = "MuroCenere", Tier = "Raro", Pos = W.WallPoint("Cenere", 120), Mode = "Top", Hint = "Il Muro di Cenere è in rovina, ma in cima resiste ancora un vecchio deposito." },
	{ Id = "RovineHalvar", Tier = "Comune", Pos = zc("Halvar") + Vector3.new(-50, 0, 30), Mode = "Top", Hint = "Tra le rovine di Halvar, sopra una casa bruciata." },
	{ Id = "LandeCenere", Tier = "Comune", Pos = W.At("Cenere", 240, 720), Mode = "Ground", Hint = "Nelle Lande di Cenere, verso ovest, la terra nasconde ancora i beni dei profughi." },
	{ Id = "ApprodoCenere", Tier = "Comune", Pos = zc("ApprodoCenere") + Vector3.new(-50, 0, 30), Mode = "Ground", Hint = "All'Approdo di Cenere, dietro il pontile." },

	-- VALDORIA --------------------------------------------------------------------------------
	{ Id = "TorreFortezza", Tier = "Leggendario", Pos = zc("Fortezza"), Mode = "Top", Hint = "In cima alla Fortezza di Vael. Solo i migliori ci arrivano vivi." },
	{ Id = "TettiRevelia", Tier = "Raro", Pos = zc("Revelia") + Vector3.new(60, 0, -40), Mode = "Top", Hint = "Sui tetti di Revelia, dove i bambini giocano a nascondino." },
	{ Id = "Trincee", Tier = "Comune", Pos = zc("Trincee") + Vector3.new(70, 0, 55), Mode = "Ground", Hint = "In fondo alle Trincee di Valdoria, una cassa di munizioni... e d'oro." },
	{ Id = "OsteriaPorto", Tier = "Comune", Pos = tavern("OsteriaPorto", Vector3.new(12, 0, 9)), Mode = "Inside", Hint = "All'Osteria del Porto di Revelia il barista conta male. Guarda in fondo." },
	{ Id = "CostaEst", Tier = "Raro", Pos = W.At("Valdoria", 90, 950), Mode = "Ground", Hint = "Sulla costa più a est di Valdoria, dove finisce il mondo conosciuto." },
	{ Id = "FronteMarcia", Tier = "Leggendario", Pos = zc("FronteMarcia") + Vector3.new(-120, 0, 120), Mode = "Ground", Hint = "Sul Fronte della Grande Marcia, tra la lava. Un suicidio, se non sei forte." },

	-- ISOLOTTI ----------------------------------------------------------------------------------
	{ Id = "CimaFaro", Tier = "Leggendario", Pos = islet("IsolaFaro"), Mode = "Top", Hint = "In cima al Faro, sopra la lanterna. Da lassù si vede tutto l'arcipelago." },
	{ Id = "NidoGabbiani", Tier = "Comune", Pos = islet("IsolaGabbiani", Vector3.new(30, 0, 10)), Mode = "Ground", Hint = "I gabbiani della loro isola rubano tutto quello che luccica." },
	{ Id = "BancoSabbia", Tier = "Raro", Pos = islet("BancoSabbia", Vector3.new(-25, 0, 15)), Mode = "Ground", Hint = "Sul Banco di Sabbia, tra Vermiglia e Aurea, la sabbia nasconde un forziere." },
	{ Id = "RelittoNaufraghi", Tier = "Raro", Pos = islet("ScogliNaufraghi", Vector3.new(20, 0, 0)), Mode = "Top", Hint = "Il carico della nave mercantile è ancora sul ponte del relitto, agli Scogli dei Naufraghi." },
	{ Id = "TorreSommersa", Tier = "Raro", Pos = islet("TorreSommersa"), Mode = "Top", Hint = "In cima alla Torre Sommersa. Le onde non ci arrivano." },
	{ Id = "PalmeTesoro", Tier = "Comune", Pos = islet("IsolaPalme", Vector3.new(-45, 0, 40)), Mode = "Ground", Hint = "All'Isola delle Palme c'è una X disegnata sulla sabbia. Davvero!" },
	{ Id = "CovoContrabbandieri", Tier = "Leggendario", Pos = islet("RifugioContrabbandieri", Vector3.new(0, 0, -20)), Mode = "Ground", Hint = "Il bottino dei contrabbandieri è nel loro covo. Dovrai passare sui loro corpi." },
	{ Id = "CraterBrace", Tier = "Leggendario", Pos = islet("ScoglioBrace"), Mode = "Top", Hint = "Sull'orlo del cratere dello Scoglio di Brace. Fa caldo, lassù." },
	{ Id = "ObeliscoArena", Tier = "Raro", Pos = W.IslandCenter("Arena"), Mode = "Top", Hint = "Sulla punta dell'obelisco dell'Arena dei Raid." },
}

Treasures.ById = {}
for _, t in Treasures.List do
	assert(Treasures.ById[t.Id] == nil, "Tesoro duplicato: " .. t.Id)
	Treasures.ById[t.Id] = t
end

Treasures.TierInfo = {
	Comune = { Name = "Forziere", Color = Color3.fromRGB(150, 104, 60), Glow = Color3.fromRGB(255, 220, 140) },
	Raro = { Name = "Forziere Raro", Color = Color3.fromRGB(70, 110, 170), Glow = Color3.fromRGB(140, 200, 255) },
	Leggendario = { Name = "Forziere Leggendario", Color = Color3.fromRGB(200, 150, 40), Glow = Color3.fromRGB(255, 200, 80) },
}

function Treasures.Get(id: string?)
	return id and Treasures.ById[id]
end

-- Quanti forzieri ha aperto un giocatore
function Treasures.Count(profile): number
	local n = 0
	for id in (profile and profile.Treasures) or {} do
		if Treasures.ById[id] then
			n += 1
		end
	end
	return n
end

return Treasures
