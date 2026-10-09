--[[
	Tutorial - l'Addestramento di base: la prima missione del gioco, dopo il prologo e prima
	dell'Istruttore Brehm. La guida è Mira, cadetta del Corpo: Brehm le ha chiesto di mostrare
	le basi alla recluta nuova.

	PARTE 1 - I COMANDI: passi interattivi, ognuno si completa facendo davvero la cosa.
	PARTE 2 - IL MONDO: le isole sulla mappa, l'interfaccia e le missioni, i giganti, la crescita.

	Ogni passo ha: Id, Section (indice in Tutorial.Sections), Title, Text (parla Mira),
	Keys = { PC = { tasti }, Touch = "testo", Gamepad = { tasti } } (senza voce per un dispositivo
	il passo diventa una spiegazione con "Avanti"), Goal (cosa controllare), Hint (consiglio che
	compare se ci metti un po'), Target (dove punta la colonna di luce).
	Goal:
	  Look     ruota la visuale di Amount gradi        Walk     percorri a piedi Amount studs
	  Jump     salta                                   Action   premi l'azione Action, Count volte
	  Hook     aggancia un rampino                     Boost    gas in volo per Amount secondi
	  Rings    attraversa gli anelli d'oro             NapeKill abbatti una sagoma dalla nuca
	  Refill   rifornisciti a un Deposito              Panel    apri e richiudi il pannello Panel
]]

local W = require(script.Parent.WorldLayout)
local Zones = require(script.Parent.Zones)

local Tutorial = {}

Tutorial.Guide = "Mira"
Tutorial.Title = "Addestramento di base"

-- il tutorial si fa al posto di questo passo della storia (Capitolo 1: "Presentati all'Istruttore Brehm")
Tutorial.StoryChapter = 1
Tutorial.StoryStep = 2

Tutorial.Sections = {
	{ Id = "Movimento", Name = "Movimento", Icon = "🧭" },
	{ Id = "Rampini", Name = "Rampini", Icon = "🪝" },
	{ Id = "Combattimento", Name = "Combattimento", Icon = "⚔️" },
	{ Id = "Interfaccia", Name = "Interfaccia", Icon = "🎒" },
}

local camp = Zones.Get("CampoAddestramento")
local campCenter = if camp then camp.Center else W.At("Vermiglia", 215, 260, W.GroundY)
local towerTop = W.Landmarks.TorreAddestramento
local towerBase = Vector3.new(towerTop.X, W.GroundY, towerTop.Z)

-- gli anelli d'oro salgono a spirale attorno alla torre di addestramento (vicini a torre e pali)
Tutorial.Rings = {
	towerBase + Vector3.new(30, 24, -6),
	towerBase + Vector3.new(4, 46, -32),
	towerBase + Vector3.new(-28, 68, -2),
}
Tutorial.RingRadius = 12

-- dove sono le sagome e il deposito del campo (TitanService e WorldBuilder)
Tutorial.DummyArea = campCenter + Vector3.new(62, 0, -48)
Tutorial.SupplyPoint = campCenter + Vector3.new(12, 0, 32)

Tutorial.Steps = {
	-- MOVIMENTO -------------------------------------------------------------------------------------
	{
		Id = "Guarda",
		Section = 1,
		Title = "Guardati intorno",
		Text = "Ehi, tu sei quello nuovo! Sono Mira. Brehm mi ha chiesto di mostrarti le basi prima di presentarti a lui. Per cominciare: guardati intorno.",
		Keys = { PC = { "Mouse" }, Touch = "Trascina il dito sullo schermo", Gamepad = { "Levetta destra" } },
		Note = { PC = "Con lo Shift lock attivo basta muovere il mouse" },
		Goal = { Kind = "Look", Amount = 150 },
		Hint = "Muovi il mouse (o tieni premuto il tasto destro e trascina).",
	},
	{
		Id = "Cammina",
		Section = 1,
		Title = "Muoviti",
		Text = "Fai qualche passo per il campo. Con Bloc Maiusc passi dalla corsa alla camminata.",
		Keys = { PC = { "W", "A", "S", "D" }, Touch = "Usa il joystick in basso a sinistra", Gamepad = { "Levetta sinistra" } },
		Goal = { Kind = "Walk", Amount = 40 },
	},
	{
		Id = "Salta",
		Section = 1,
		Title = "Salta",
		Text = "Un soldato delle Isole non resta mai con i piedi a terra a lungo. Salta!",
		Keys = { PC = { "Spazio" }, Touch = "Tocca il pulsante del salto", Gamepad = { "A" } },
		Goal = { Kind = "Jump" },
	},
	{
		Id = "Schiva",
		Section = 1,
		Title = "Schivata",
		Text = "Uno scatto rapido nella direzione in cui ti muovi: ti salva dalle mani dei giganti. Costa un po' di gas.",
		Keys = { PC = { "Ctrl" }, Touch = "Tocca ↯", Gamepad = { "B" } },
		Goal = { Kind = "Action", Action = "Dodge", Count = 1 },
	},
	-- RAMPINI --------------------------------------------------------------------------------------
	{
		Id = "Rampino",
		Section = 2,
		Title = "Lancia un rampino",
		Text = "Ora la parte bella. Punta il mirino sulla torre di legno o su un palo: quando diventa VERDE è in portata. Tieni premuto per restare agganciato.",
		Keys = { PC = { "Q", "E" }, Touch = "Tieni premuto ◀🪝 o 🪝▶", Gamepad = { "L1", "R1" } },
		Note = { PC = "Q = rampino sinistro • E = rampino destro" },
		Goal = { Kind = "Hook" },
		Target = towerBase + Vector3.new(0, 40, 0),
		Hint = "Il mirino deve essere verde: avvicinati alla torre e guardala.",
	},
	{
		Id = "Gas",
		Section = 2,
		Title = "Gas!",
		Text = "Mentre sei agganciato, il gas ti spinge in avanti e ti fa salire. Si consuma: tienilo d'occhio nella barra azzurra in basso a sinistra.",
		Keys = { PC = { "Spazio" }, Touch = "Tieni premuto 💨", Gamepad = { "A" } },
		Note = { PC = "Tieni premuto Q o E e intanto Spazio" },
		Goal = { Kind = "Boost", Amount = 0.6 },
		Target = towerBase + Vector3.new(0, 40, 0),
		Hint = "Aggancia la torre (Q o E) e tieni premuto Spazio mentre voli.",
	},
	{
		Id = "Anelli",
		Section = 2,
		Title = "Vola tra gli anelli",
		Text = "Attraversa i tre anelli d'oro attorno alla torre. Alterna i rampini, sterza con W A S D e usa il gas per salire.",
		Keys = { PC = { "Q", "E", "Spazio" }, Touch = "◀🪝  🪝▶  💨", Gamepad = { "L1", "R1", "A" } },
		Goal = { Kind = "Rings" },
		Hint = "Aggancia la torre vicino all'anello, tieni premuto Spazio per salire e rilascia il rampino per oscillare dentro l'anello.",
		SkipAfter = 75,
	},
	-- COMBATTIMENTO -------------------------------------------------------------------------------------
	{
		Id = "Fendente",
		Section = 3,
		Title = "Fendente",
		Text = "Le lame colpiscono in combo da quattro. Prova qualche fendente.",
		Keys = { PC = { "Clic sinistro" }, Touch = "Tocca ⚔️", Gamepad = { "R2" } },
		Goal = { Kind = "Action", Action = "Attack", Count = 3 },
	},
	{
		Id = "Nuca",
		Section = 3,
		Title = "Colpisci la NUCA",
		Text = "Il punto debole di ogni gigante è la nuca, dietro il collo. Quando la punti il mirino diventa ORO: abbatti una sagoma colpendola lì!",
		Keys = { PC = { "Clic sinistro" }, Touch = "Tocca ⚔️", Gamepad = { "R2" } },
		Goal = { Kind = "NapeKill" },
		Target = Tutorial.DummyArea,
		Hint = "Giragli attorno e colpiscilo da dietro, in alto: aggancia un rampino per arrivarci.",
		SkipAfter = 90,
	},
	{
		Id = "Abilita",
		Section = 3,
		Title = "Abilità delle lame",
		Text = "Z, X, C e V sono le abilità delle lame. Z si usa da subito: le altre si sbloccano con la maestria, colpendo con le stesse lame.",
		Keys = { PC = { "Z" }, Touch = "Tocca Z in basso", Gamepad = { "X" } },
		Goal = { Kind = "Action", Action = "SkillZ", Count = 1 },
	},
	{
		Id = "Lame",
		Section = 3,
		Title = "Lame nuove",
		Text = "Le lame si consumano a ogni colpo. Quando sono rovinate, sostituiscile al volo.",
		Keys = { PC = { "R" }, Touch = "Tocca R" },
		Goal = { Kind = "Action", Action = "Reload", Count = 1 },
	},
	{
		Id = "Rifornimento",
		Section = 3,
		Title = "Rifornimento",
		Text = "Gas e lame finiscono! Ai Depositi di Rifornimento, la cassa con le bombole, ricarichi tutto. Avvicinati e tieni premuto il tasto.",
		Keys = { PC = { "F" }, Touch = "Tocca il pulsante che compare", Gamepad = { "X" } },
		Note = { PC = "Tieni premuto F vicino alla cassa" },
		Goal = { Kind = "Refill" },
		Target = Tutorial.SupplyPoint,
		Hint = "Segui la colonna di luce dorata fino alla cassa con le bombole.",
	},
	-- INTERFACCIA -------------------------------------------------------------------------------------
	{
		Id = "Menu",
		Section = 4,
		Title = "Il menu",
		Text = "Nel menu trovi equipaggiamento, statistiche, sieri, storia, traguardi e impostazioni. Aprilo e poi richiudilo.",
		Keys = { PC = { "M" }, Touch = "Tocca 🎒 sulla destra" },
		Goal = { Kind = "Panel", Panel = "Menu" },
	},
	{
		Id = "Mappa",
		Section = 4,
		Title = "La mappa",
		Text = "La mappa dell'arcipelago: zone colorate in base al tuo livello, porti, negozi e il tuo obiettivo. Aprila e poi richiudila.",
		Keys = { PC = { "B" }, Touch = "Tocca la minimappa", Gamepad = { "Select" } },
		Goal = { Kind = "Panel", Panel = "Mappa" },
	},
}

-- PARTE 2: L'ARCIPELAGO (mappa animata, un'isola alla volta) ---------------------------------------------
Tutorial.Islands = {
	{ Island = "Vermiglia", Text = "La tua casa. Qui cominci: Campo di Addestramento, Recinto dei giganti catturati, Quartier Generale e il Distretto di Calaneth. Fuori dalle Mura: pianure e foresta." },
	{ Island = "Edenia", Text = "Foreste di alberi giganti e la Gola. Il Corpo dei Falchi si accampa qui per le missioni oltre le Mura." },
	{ Island = "Aurea", Text = "La capitale Aurion, la Città Sotterranea e la Caverna di Cristallo. Intrighi, polizia militare e segreti." },
	{ Island = "Cenere", Text = "Le rovine di Halvar, dove tutto è cominciato. Nel seminterrato si nasconde la verità sulla tua fiala." },
	{ Island = "Valdoria", Text = "Il continente oltre il mare: trincee, fortezze e la Grande Marcia dei giganti." },
	{ Island = "Arena", Text = "L'Isola dell'Arena: raid a ondate con boss enormi, da soli o in squadra. Si sblocca al livello 120." },
}
Tutorial.SeaText = "In mezzo al mare ci sono isolotti con giganti, relitti e forzieri nascosti. Ti sposti con i Corrieri 🐎 (viaggio rapido), con la barca ⛵ dai pontili (F) o con il cavallo (H)."
Tutorial.LevelText = "Ogni isola ha un livello consigliato: sulla mappa le zone GIALLE sono giuste per te, quelle ROSSE troppo pericolose."

-- le zone principali di un'isola (per la scheda della mappa)
function Tutorial.IslandZones(islandId: string, max: number?): { string }
	local names = {}
	for _, zone in Zones.List do
		if zone.Island == islandId and not zone.Islet and not zone.Underground then
			table.insert(names, zone.Name)
			if #names >= (max or 4) then
				break
			end
		end
	end
	return names
end

-- PARTE 2: L'INTERFACCIA (riflettore sugli elementi del HUD) ----------------------------------------------
-- Element = nome dell'elemento (vedi HUD.Element)
Tutorial.Spotlight = {
	{ Element = "Tracker", Title = "📜 Le missioni", Text = "In alto a destra c'è la STORIA: la missione principale che sblocca capitoli, isole e poteri. Sotto, la missione secondaria attiva." },
	{ Element = "Compass", Title = "◆ Dove andare", Text = "La bussola e la colonna di luce dorata indicano sempre il tuo obiettivo, con la distanza in metri." },
	{ Element = "Player", Title = "⭐ Livello e oro", Text = "Livello, esperienza, oro e gemme. A ogni livello guadagni punti statistica da spendere nel menu (M)." },
	{ Element = "Bars", Title = "❤️ Salute, gas e lame", Text = "Se il gas finisce in volo, cadi! Ricarica ai Depositi di Rifornimento. Le lame si cambiano con R." },
	{ Element = "Rewards", Title = "🎁 Premi", Text = "Calendario dei premi giornalieri, regali a tempo, ruota della fortuna, classifiche e invito agli amici." },
	{ Element = "MenuButtons", Title = "🎒 Menu rapido", Text = "Equipaggiamento, mappa, cavallo, statistiche e negozio a portata di clic." },
	{ Element = "Minimap", Title = "🗺️ Minimappa", Text = "Il nord è sempre in alto. Puntini rossi = giganti vicini, ◆ oro = il tuo obiettivo." },
}
Tutorial.QuestText = "Le missioni secondarie te le danno i personaggi con ❗ sopra la testa: XP e oro extra. Una alla volta."

-- PARTE 2: COSA TI ASPETTA (schede finali) -------------------------------------------------------------
Tutorial.Outro = {
	{ Icon = "📜", Title = "Storia", Text = "4 stagioni e 5 isole: segui i capitoli per scoprire chi fabbrica i Sieri." },
	{ Icon = "❗", Title = "Missioni", Text = Tutorial.QuestText },
	{ Icon = "🔱", Title = "Raid ed eventi", Text = "Raid con boss enormi, eventi a tempo con XP doppia e il Colosso d'Oro." },
	{ Icon = "💉", Title = "Sieri", Text = "Più avanti potrai iniettarti un siero e trasformarti in gigante (T)." },
}

-- premio dell'addestramento completato (una volta sola)
Tutorial.Reward = { XP = 0.8, Gold = 300, Items = { Razione = 2 } }
-- secondi minimi per completarlo davvero (sotto non si riceve il premio)
Tutorial.MinSeconds = 45

return Tutorial
