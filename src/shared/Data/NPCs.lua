--[[
	NPCs - personaggi non giocanti
	Offset = posizione relativa al centro della zona (la Y viene calcolata sul terreno).
	Role: Story | Quest | Shop | Lab | Dealer | Travel | Ship | Lift | Genealogist | Object | Tavern | Duel
	Indoor = true: il PNG sta dentro un edificio (il pavimento si cerca sotto il soffitto)
	Character: lo stesso personaggio può apparire in più luoghi durante la storia.
]]

local W = require(script.Parent.WorldLayout)

local NPCs = {}

-- Personaggi della storia (nome mostrato nei dialoghi)
NPCs.Characters = {
	Brehm = { Name = "Konrad Brehm", Title = "Istruttore Capo", Color = Color3.fromRGB(150, 110, 80) },
	Tobias = { Name = "Tobias Renz", Title = "Cadetto", Color = Color3.fromRGB(90, 160, 120) },
	Mira = { Name = "Mira Kessler", Title = "Cadetta", Color = Color3.fromRGB(190, 70, 70) },
	Varis = { Name = "Varis Holt", Title = "Cadetto", Color = Color3.fromRGB(220, 190, 120) },
	Kael = { Name = "Kael Dorn", Title = "Cadetto", Color = Color3.fromRGB(120, 110, 180) },
	Morrow = { Name = "Dott.ssa Ilse Morrow", Title = "Ricercatrice", Color = Color3.fromRGB(170, 120, 210) },
	Falkner = { Name = "Rhea Falkner", Title = "Capitano della Squadra Grifone", Color = Color3.fromRGB(70, 140, 90) },
	Weiss = { Name = "Comandante Weiss", Title = "Guarnigione di Calaneth", Color = Color3.fromRGB(200, 80, 80) },
	Roth = { Name = "Sabine Roth", Title = "Ufficiale del Corpo dei Falchi", Color = Color3.fromRGB(110, 150, 200) },
	Elise = { Name = "Elise", Title = "Erede della Stirpe Reale", Color = Color3.fromRGB(240, 210, 130) },
	Corvo = { Name = "Il Corvo Nero", Title = "Squadra Ombra", Color = Color3.fromRGB(60, 60, 70) },
	Vael = { Name = "Dott. Edric Vael", Title = "???", Color = Color3.fromRGB(120, 200, 140) },
	Narratore = { Name = "Narratore", Title = "", Color = Color3.fromRGB(230, 220, 200) },
	Diario = { Name = "Diario di Aurel", Title = "Seminterrato", Color = Color3.fromRGB(200, 180, 140) },
}

local NPCList = {
	-- CAMPO DI ADDESTRAMENTO ------------------------------------------------------
	{ Id = "Brehm", Character = "Brehm", Zone = "CampoAddestramento", Offset = Vector3.new(0, 0, -25), Facing = 180, Role = "Story",
		Look = { Skin = Color3.fromRGB(214, 170, 140), Hair = Color3.fromRGB(40, 35, 30), HairStyle = "Calvo", Uniform = "Guarnigione", Beard = true },
		Greeting = { "Non ti ho dato il permesso di riposare, recluta!", "Una postura così ti farà mangiare al primo gigante." } },
	{ Id = "Tobias", Character = "Tobias", Zone = "CampoAddestramento", Offset = Vector3.new(18, 0, -10), Facing = 200, Role = "Story",
		Look = { Skin = Color3.fromRGB(230, 190, 160), Hair = Color3.fromRGB(70, 50, 35), HairStyle = "Corto", Uniform = "Cadetto" },
		Greeting = { "Un giorno vedremo cosa c'è oltre le Mura. Te lo prometto." } },
	{ Id = "Mira", Character = "Mira", Zone = "CampoAddestramento", Offset = Vector3.new(26, 0, -4), Facing = 210, Role = "Story",
		Look = { Skin = Color3.fromRGB(236, 200, 175), Hair = Color3.fromRGB(25, 22, 22), HairStyle = "Lungo", Uniform = "Cadetto", Scarf = true },
		Greeting = { "Tobias si caccia sempre nei guai. Qualcuno deve tenerlo d'occhio." } },
	{ Id = "Varis", Character = "Varis", Zone = "CampoAddestramento", Offset = Vector3.new(-20, 0, -8), Facing = 160, Role = "Story",
		Look = { Skin = Color3.fromRGB(222, 182, 150), Hair = Color3.fromRGB(220, 195, 130), HairStyle = "Rasato", Uniform = "Cadetto" },
		Greeting = { "Se hai bisogno di una mano, chiedi pure. Siamo compagni, no?" } },
	{ Id = "Kael", Character = "Kael", Zone = "CampoAddestramento", Offset = Vector3.new(-28, 0, -2), Facing = 150, Role = "Story",
		Look = { Skin = Color3.fromRGB(205, 160, 125), Hair = Color3.fromRGB(30, 26, 24), HairStyle = "Corto", Uniform = "Cadetto" },
		Greeting = { "...Tutto bene. Sto solo pensando." } },
	{ Id = "ArmaioloFenn", Zone = "CampoAddestramento", Offset = Vector3.new(30, 0, 22), Facing = 300, Role = "Shop", Shop = "ArmeriaCampo",
		Name = "Fenn", Title = "Armaiolo",
		Look = { Skin = Color3.fromRGB(200, 150, 120), Hair = Color3.fromRGB(90, 70, 50), HairStyle = "Ricci", Uniform = "Civile", Apron = true },
		Greeting = { "Lame nuove? Dispositivi? Ho tutto quello che serve a un cadetto." } },
	{ Id = "VivandieraGreta", Zone = "CampoAddestramento", Offset = Vector3.new(-30, 0, 22), Facing = 60, Role = "Shop", Shop = "Emporio",
		Name = "Greta", Title = "Vivandiera",
		Look = { Skin = Color3.fromRGB(240, 205, 180), Hair = Color3.fromRGB(150, 90, 50), HairStyle = "Chignon", Uniform = "Civile" },
		Greeting = { "Razioni, gas e lame di ricambio! Nessuno parte a stomaco vuoto." } },
	{ Id = "CorriereCampo", Zone = "CampoAddestramento", Offset = Vector3.new(0, 0, 36), Facing = 0, Role = "Travel",
		Name = "Corriere", Title = "Viaggio Rapido",
		Look = { Skin = Color3.fromRGB(210, 165, 130), Hair = Color3.fromRGB(60, 45, 35), HairStyle = "Corto", Uniform = "Civile", Hat = true },
		Greeting = { "Il mio carro ti porta in qualsiasi base che hai già visitato." } },

	-- RECINTO -------------------------------------------------------------------------
	{ Id = "HildeMarr", Zone = "Recinto", Offset = Vector3.new(66, 0, 75), Facing = 220, Role = "Quest", Quests = { "Q_T3", "Q_T4" },
		Name = "Hilde Marr", Title = "Sergente del Recinto",
		Look = { Skin = Color3.fromRGB(226, 186, 160), Hair = Color3.fromRGB(180, 120, 70), HairStyle = "Coda", Uniform = "Guarnigione" },
		Greeting = { "Tieni gli occhi sulla nuca e i piedi lontani dalle loro mani." } },
	{ Id = "MorrowRecinto", Character = "Morrow", Zone = "Recinto", Offset = Vector3.new(80, 0, 60), Facing = 230, Role = "Story",
		Look = { Skin = Color3.fromRGB(232, 196, 172), Hair = Color3.fromRGB(110, 70, 50), HairStyle = "Coda", Uniform = "Scienziata", Glasses = true },
		Greeting = { "Hai visto come sbava quello lì? Adorabile! Ehm, cioè... pericoloso." } },

	-- QUARTIER GENERALE -----------------------------------------------------------------
	{ Id = "Falkner", Character = "Falkner", Zone = "QuartierGenerale", Offset = Vector3.new(0, 0, -15), Facing = 180, Role = "Story",
		Look = { Skin = Color3.fromRGB(226, 190, 165), Hair = Color3.fromRGB(45, 40, 38), HairStyle = "Corto", Uniform = "Falchi" },
		Greeting = { "Nel Corpo dei Falchi si torna in pochi. Assicurati di essere tra quelli." } },
	{ Id = "MorrowQG", Character = "Morrow", Zone = "QuartierGenerale", Offset = Vector3.new(20, 0, -5), Facing = 200, Role = "Lab",
		Look = { Skin = Color3.fromRGB(232, 196, 172), Hair = Color3.fromRGB(110, 70, 50), HairStyle = "Coda", Uniform = "Scienziata", Glasses = true },
		Greeting = { "Portami frammenti di siero e io ti porterò... scienza!" } },
	{ Id = "QuartiermastroOdo", Zone = "QuartierGenerale", Offset = Vector3.new(-22, 0, -2), Facing = 150, Role = "Shop", Shop = "ArmeriaQG",
		Name = "Odo", Title = "Quartiermastro",
		Look = { Skin = Color3.fromRGB(200, 150, 115), Hair = Color3.fromRGB(80, 80, 80), HairStyle = "Corto", Uniform = "Falchi", Beard = true },
		Greeting = { "Equipaggiamento da spedizione. Il meglio che il re ci concede." } },
	{ Id = "EmporioQG", Zone = "QuartierGenerale", Offset = Vector3.new(-18, 0, 18), Facing = 120, Role = "Shop", Shop = "Emporio",
		Name = "Paul", Title = "Vivandiere",
		Look = { Skin = Color3.fromRGB(236, 200, 170), Hair = Color3.fromRGB(200, 170, 110), HairStyle = "Ricci", Uniform = "Civile" },
		Greeting = { "Hai fame? Ho anche le bombole di gas, se preferisci." } },
	{ Id = "CorriereQG", Zone = "QuartierGenerale", Offset = Vector3.new(18, 0, 20), Facing = 240, Role = "Travel",
		Name = "Corriere", Title = "Viaggio Rapido",
		Look = { Skin = Color3.fromRGB(210, 165, 130), Hair = Color3.fromRGB(60, 45, 35), HairStyle = "Corto", Uniform = "Civile", Hat = true },
		Greeting = { "Dove ti porto?" } },

	-- CALANETH ----------------------------------------------------------------------------
	{ Id = "Weiss", Character = "Weiss", Zone = "Calaneth", Offset = Vector3.new(-14, 0, -56), Facing = 180, Role = "Story",
		Look = { Skin = Color3.fromRGB(220, 180, 150), Hair = Color3.fromRGB(200, 200, 200), HairStyle = "Calvo", Uniform = "Guarnigione", Beard = true },
		Greeting = { "Ogni casa di questo distretto è una tomba, finché non ripuliamo le strade." } },
	{ Id = "CaposquadraLenz", Zone = "Calaneth", Offset = Vector3.new(14, 0, -56), Facing = 180, Role = "Quest", Quests = { "Q_T5", "Q_T7", "Q_Ghignante" },
		Name = "Lenz", Title = "Caposquadra della Guarnigione",
		Look = { Skin = Color3.fromRGB(200, 155, 120), Hair = Color3.fromRGB(60, 40, 30), HairStyle = "Corto", Uniform = "Guarnigione" },
		Greeting = { "Le strade sono piene di giganti. Mi serve chiunque sappia volare." } },

	-- PIANURE / AVAMPOSTO / FORESTA ----------------------------------------------------------
	{ Id = "EsploratoreBram", Zone = "PianureSud", Offset = Vector3.new(-130, 0, -60), Facing = 120, Role = "Quest", Quests = { "Q_T7P", "Q_T10P" },
		Name = "Bram", Title = "Esploratore",
		Look = { Skin = Color3.fromRGB(190, 140, 110), Hair = Color3.fromRGB(40, 30, 25), HairStyle = "Lungo", Uniform = "Falchi" },
		Greeting = { "Da qui in poi niente più mura. Solo erba, vento e giganti." } },
	{ Id = "UfficialeRoth", Character = "Roth", Zone = "Avamposto", Offset = Vector3.new(0, 0, -10), Facing = 180, Role = "Quest", Quests = { "Q_T10F", "Q_T12F", "Q_Cacciatrice" },
		Look = { Skin = Color3.fromRGB(230, 195, 170), Hair = Color3.fromRGB(160, 110, 60), HairStyle = "Coda", Uniform = "Falchi" },
		Greeting = { "La foresta è perfetta per i Rampini. È perfetta anche per un'imboscata." } },
	{ Id = "EmporioAvamposto", Zone = "Avamposto", Offset = Vector3.new(16, 0, 8), Facing = 250, Role = "Shop", Shop = "Emporio",
		Name = "Ida", Title = "Vivandiera",
		Look = { Skin = Color3.fromRGB(226, 186, 160), Hair = Color3.fromRGB(90, 60, 40), HairStyle = "Chignon", Uniform = "Civile" },
		Greeting = { "Ultima occasione per fare scorte!" } },
	{ Id = "CorriereAvamposto", Zone = "Avamposto", Offset = Vector3.new(-16, 0, 8), Facing = 110, Role = "Travel",
		Name = "Corriere", Title = "Viaggio Rapido",
		Look = { Skin = Color3.fromRGB(210, 165, 130), Hair = Color3.fromRGB(60, 45, 35), HairStyle = "Corto", Uniform = "Civile", Hat = true },
		Greeting = { "Si torna indietro?" } },

	-- STAGIONE 2 ---------------------------------------------------------------------------------
	{ Id = "ContadinoUlrich", Zone = "Brenn", Offset = Vector3.new(-90, 0, 40), Facing = 60, Role = "Quest", Quests = { "Q_T7B", "Q_T10B" },
		Name = "Ulrich", Title = "Contadino Superstite",
		Look = { Skin = Color3.fromRGB(210, 160, 125), Hair = Color3.fromRGB(150, 150, 150), HairStyle = "Ricci", Uniform = "Civile", Hat = true },
		Greeting = { "Quella nebbia... ha preso tutti. Mia moglie, i vicini... Ti prego, liberali." } },
	{ Id = "SoldatoNils", Zone = "Ostrava", Offset = Vector3.new(90, 0, 40), Facing = 240, Role = "Quest", Quests = { "Q_T10O", "Q_T12O", "Q_Fauno" },
		Name = "Nils", Title = "Soldato della Guarnigione",
		Look = { Skin = Color3.fromRGB(226, 186, 160), Hair = Color3.fromRGB(110, 80, 50), HairStyle = "Corto", Uniform = "Guarnigione" },
		Greeting = { "Al castello si sentono urla tutte le notti." } },
	{ Id = "VarisOstrava", Character = "Varis", Zone = "Ostrava", Offset = Vector3.new(100, 0, 54), Facing = 250, Role = "Story",
		Look = { Skin = Color3.fromRGB(222, 182, 150), Hair = Color3.fromRGB(220, 195, 130), HairStyle = "Rasato", Uniform = "Falchi" },
		Greeting = { "Resta vicino a me. Stanotte non mi piace." } },
	{ Id = "TenenteVogt", Zone = "AccampamentoEdenia", Offset = Vector3.new(0, 0, -8), Facing = 270, Role = "Quest", Quests = { "Q_T12G", "Q_T15G", "Q_Bastione", "Q_Zanna" },
		Name = "Vogt", Title = "Tenente",
		Look = { Skin = Color3.fromRGB(200, 155, 120), Hair = Color3.fromRGB(30, 30, 30), HairStyle = "Rasato", Uniform = "Falchi", Beard = true },
		Greeting = { "La gola è un labirinto di roccia. Ottimo per i Rampini, pessimo per la ritirata." } },
	{ Id = "KaelEdenia", Character = "Kael", Zone = "AccampamentoEdenia", Offset = Vector3.new(14, 0, 4), Facing = 230, Role = "Story",
		Look = { Skin = Color3.fromRGB(205, 160, 125), Hair = Color3.fromRGB(30, 26, 24), HairStyle = "Corto", Uniform = "Falchi" },
		Greeting = { "..." } },
	{ Id = "FalknerEdenia", Character = "Falkner", Zone = "AccampamentoEdenia", Offset = Vector3.new(-14, 0, 4), Facing = 120, Role = "Story",
		Look = { Skin = Color3.fromRGB(226, 190, 165), Hair = Color3.fromRGB(45, 40, 38), HairStyle = "Corto", Uniform = "Falchi" },
		Greeting = { "Tieni gli occhi aperti. Non tutti qui sono chi dicono di essere." } },
	{ Id = "TobiasEdenia", Character = "Tobias", Zone = "AccampamentoEdenia", Offset = Vector3.new(-6, 0, 16), Facing = 90, Role = "Story",
		Look = { Skin = Color3.fromRGB(230, 190, 160), Hair = Color3.fromRGB(70, 50, 35), HairStyle = "Corto", Uniform = "Falchi" },
		Greeting = { "Ogni volta che mi trasformo, sento delle voci." } },
	{ Id = "EmporioEdenia", Zone = "AccampamentoEdenia", Offset = Vector3.new(12, 0, 18), Facing = 200, Role = "Shop", Shop = "Emporio",
		Name = "Kurt", Title = "Vivandiere",
		Look = { Skin = Color3.fromRGB(236, 200, 170), Hair = Color3.fromRGB(120, 90, 60), HairStyle = "Corto", Uniform = "Civile" },
		Greeting = { "Gas e razioni per chi va nella gola." } },
	{ Id = "CorriereEdenia", Zone = "AccampamentoEdenia", Offset = Vector3.new(-18, 0, 18), Facing = 150, Role = "Travel",
		Name = "Corriere", Title = "Viaggio Rapido",
		Look = { Skin = Color3.fromRGB(210, 165, 130), Hair = Color3.fromRGB(60, 45, 35), HairStyle = "Corto", Uniform = "Civile", Hat = true },
		Greeting = { "Pronto a partire." } },

	-- MITRAS -------------------------------------------------------------------------------------
	{ Id = "MercanteVelato", Zone = "Aurion", Offset = Vector3.new(-30, 0, 122), Facing = 180, Role = "Dealer",
		Name = "Il Mercante Velato", Title = "Mercante di Sieri",
		Look = { Skin = Color3.fromRGB(180, 140, 110), Hair = Color3.fromRGB(20, 20, 20), HairStyle = "Calvo", Uniform = "Mercante", Hood = true },
		Greeting = { "Sieri Perduti... merce rara, prezzi altissimi. La mia offerta cambia ogni quattro ore." } },
	{ Id = "MorrowAurion", Character = "Morrow", Zone = "Aurion", Offset = Vector3.new(30, 0, 122), Facing = 180, Role = "Lab",
		Look = { Skin = Color3.fromRGB(232, 196, 172), Hair = Color3.fromRGB(110, 70, 50), HairStyle = "Coda", Uniform = "Scienziata", Glasses = true },
		Greeting = { "Il laboratorio reale! Finalmente strumenti degni di questo nome!" } },
	{ Id = "MaestroCorvin", Zone = "Aurion", Offset = Vector3.new(-52, 0, 140), Facing = 150, Role = "Shop", Shop = "ArmeriaAurion",
		Name = "Corvin", Title = "Maestro d'Armi Reale",
		Look = { Skin = Color3.fromRGB(214, 170, 140), Hair = Color3.fromRGB(150, 150, 150), HairStyle = "Lungo", Uniform = "Nobile", Beard = true },
		Greeting = { "Solo il meglio per chi serve la Corona. A un prezzo adeguato, s'intende." } },
	{ Id = "EmporioAurion", Zone = "Aurion", Offset = Vector3.new(52, 0, 140), Facing = 210, Role = "Shop", Shop = "Emporio",
		Name = "Lotte", Title = "Mercantessa",
		Look = { Skin = Color3.fromRGB(240, 205, 180), Hair = Color3.fromRGB(200, 160, 90), HairStyle = "Chignon", Uniform = "Civile" },
		Greeting = { "Benvenuto nella capitale! Qui i prezzi sono... da capitale." } },
	{ Id = "Elise", Character = "Elise", Zone = "Aurion", Offset = Vector3.new(0, 0, 104), Facing = 180, Role = "Story",
		Look = { Skin = Color3.fromRGB(244, 214, 190), Hair = Color3.fromRGB(240, 215, 140), HairStyle = "Lungo", Uniform = "Nobile" },
		Greeting = { "Le Mura proteggono i ricchi molto meglio dei poveri, sai?" } },
	{ Id = "IspettoreGant", Zone = "Aurion", Offset = Vector3.new(290, 0, 14), Facing = 270, Role = "Quest", Quests = { "Q_Polizia1", "Q_Polizia2" },
		Name = "Gant", Title = "Ispettore Onesto",
		Look = { Skin = Color3.fromRGB(205, 160, 125), Hair = Color3.fromRGB(70, 60, 50), HairStyle = "Corto", Uniform = "Polizia", Hat = true },
		Greeting = { "Non tutta la Gendarmeria Reale è marcia. Solo quasi tutta." } },
	{ Id = "ArchivistaOdile", Zone = "Aurion", Offset = Vector3.new(0, 0, 150), Facing = 180, Role = "Genealogist",
		Name = "Odile", Title = "Archivista Reale (Stirpi)",
		Look = { Skin = Color3.fromRGB(236, 205, 180), Hair = Color3.fromRGB(230, 230, 230), HairStyle = "Chignon", Uniform = "Nobile", Glasses = true },
		Greeting = { "Ogni sangue racconta una storia. Posso risvegliarne un'altra nel tuo... per un prezzo." } },
	{ Id = "CorriereAurion", Zone = "Aurion", Offset = Vector3.new(-22, 0, 164), Facing = 160, Role = "Travel",
		Name = "Corriere", Title = "Viaggio Rapido",
		Look = { Skin = Color3.fromRGB(210, 165, 130), Hair = Color3.fromRGB(60, 45, 35), HairStyle = "Corto", Uniform = "Civile", Hat = true },
		Greeting = { "Le strade della capitale sono le più sicure del mondo. Fuori, meno." } },
	{ Id = "AscensoreAurion", Zone = "Aurion", Offset = Vector3.new(-120, 0, 60), Facing = 90, Role = "Lift", Destination = "CittaSotterranea", LevelReq = 450,
		Name = "Ascensore", Title = "Verso la Città Sotterranea", Object = "Ascensore" },

	-- SOTTOSUOLO --------------------------------------------------------------------------------
	{ Id = "InformatoreRat", Zone = "CittaSotterranea", Offset = Vector3.new(0, 0, 150), Facing = 180, Role = "Quest", Quests = { "Q_Ombra1", "Q_Ombra2", "Q_Corvo" },
		Name = "Rat", Title = "Informatore",
		Look = { Skin = Color3.fromRGB(190, 150, 120), Hair = Color3.fromRGB(40, 35, 30), HairStyle = "Ricci", Uniform = "Civile", Hood = true },
		Greeting = { "Quaggiù le informazioni costano. Ma per chi caccia il Corvo, faccio lo sconto." } },
	{ Id = "AscensoreSotto", Zone = "CittaSotterranea", Offset = Vector3.new(0, 0, 172), Facing = 180, Role = "Lift", Destination = "Aurion",
		Name = "Ascensore", Title = "Verso Aurion", Object = "Ascensore" },
	{ Id = "RicettatoreSotto", Zone = "CittaSotterranea", Offset = Vector3.new(18, 0, 160), Facing = 220, Role = "Shop", Shop = "Emporio",
		Name = "Ricettatore", Title = "Merce di dubbia provenienza",
		Look = { Skin = Color3.fromRGB(200, 160, 130), Hair = Color3.fromRGB(80, 60, 40), HairStyle = "Lungo", Uniform = "Civile" },
		Greeting = { "Non chiedere da dove viene. Paga e basta." } },
	{ Id = "MinatoreEdda", Zone = "CavernaCristallo", Offset = Vector3.new(0, 0, 150), Facing = 180, Role = "Quest", Quests = { "Q_Cristallo1", "Q_Cristallo2" },
		Name = "Edda", Title = "Minatrice",
		Look = { Skin = Color3.fromRGB(214, 170, 140), Hair = Color3.fromRGB(120, 60, 40), HairStyle = "Coda", Uniform = "Civile", Hat = true },
		Greeting = { "Questo cristallo non l'ha fatto la natura. L'hanno fatto loro." } },
	{ Id = "UscitaCaverna", Zone = "CavernaCristallo", Offset = Vector3.new(0, 0, 166), Facing = 180, Role = "Lift", Destination = "PianaOrvel",
		Name = "Uscita", Title = "Verso la Piana di Orvel", Object = "Ascensore" },

	-- STAGIONE 3 IN SUPERFICIE ---------------------------------------------------------------------
	{ Id = "SergenteIvo", Zone = "PianaOrvel", Offset = Vector3.new(0, 0, 128), Facing = 0, Role = "Quest", Quests = { "Q_T12P", "Q_T15P", "Q_Strisciante" },
		Name = "Ivo", Title = "Sergente",
		Look = { Skin = Color3.fromRGB(226, 186, 160), Hair = Color3.fromRGB(50, 40, 30), HairStyle = "Rasato", Uniform = "Falchi" },
		Greeting = { "Dalla caverna sale calore. E la terra non smette di tremare." } },
	{ Id = "IngressoCaverna", Zone = "PianaOrvel", Offset = Vector3.new(0, 0, -50), Facing = 180, Role = "Lift", Destination = "CavernaCristallo", LevelReq = 600,
		Name = "Ingresso della Caverna", Title = "Verso la Caverna di Cristallo", Object = "Caverna" },
	{ Id = "VeteranoHolm", Zone = "Halvar", Offset = Vector3.new(14, 0, -70), Facing = 180, Role = "Quest", Quests = { "Q_T12H", "Q_T15H", "Q_Vulcano" },
		Name = "Holm", Title = "Veterano di Halvar",
		Look = { Skin = Color3.fromRGB(205, 160, 125), Hair = Color3.fromRGB(160, 160, 160), HairStyle = "Corto", Uniform = "Falchi", Beard = true },
		Greeting = { "Sono nato qui. Voglio morire qui... ma non oggi." } },
	{ Id = "FalknerHalvar", Character = "Falkner", Zone = "Halvar", Offset = Vector3.new(-14, 0, -70), Facing = 180, Role = "Story",
		Look = { Skin = Color3.fromRGB(226, 190, 165), Hair = Color3.fromRGB(45, 40, 38), HairStyle = "Corto", Uniform = "Falchi" },
		Greeting = { "Siamo tornati a casa tua. Le risposte ti aspettano." } },
	{ Id = "Seminterrato", Zone = "Halvar", Offset = Vector3.new(-60, 0, 30), Facing = 0, Role = "Story", Object = "Porta",
		Name = "Seminterrato", Title = "La tua vecchia casa" },
	{ Id = "EsploratriceKaya", Zone = "LandeCenere", Offset = Vector3.new(-150, 0, 28), Facing = 100, Role = "Quest", Quests = { "Q_T15L", "Q_T15LA" },
		Name = "Kaya", Title = "Esploratrice",
		Look = { Skin = Color3.fromRGB(190, 140, 110), Hair = Color3.fromRGB(30, 25, 22), HairStyle = "Coda", Uniform = "Falchi" },
		Greeting = { "Ho visto il mare, sai? È più grande di qualsiasi muro." } },

	-- STAGIONE 4 ---------------------------------------------------------------------------------
	{ Id = "CapitanoHaskel", Zone = "PortoOrientale", Offset = Vector3.new(34, 0, 0), Facing = 270, Role = "Ship", Destination = "PortoRevelia", LevelReq = 1000,
		Name = "Haskel", Title = "Capitano di Nave",
		Look = { Skin = Color3.fromRGB(196, 146, 112), Hair = Color3.fromRGB(110, 110, 110), HairStyle = "Lungo", Uniform = "Civile", Beard = true, Hat = true },
		Greeting = { "Oltre l'orizzonte c'è Valdoria. Si salpa solo con i veterani (livello 1000)." } },
	{ Id = "FalknerPorto", Character = "Falkner", Zone = "PortoOrientale", Offset = Vector3.new(0, 0, -16), Facing = 90, Role = "Story",
		Look = { Skin = Color3.fromRGB(226, 190, 165), Hair = Color3.fromRGB(45, 40, 38), HairStyle = "Corto", Uniform = "NuovoCorpo" },
		Greeting = { "Il mare. Tutti quelli che abbiamo perso avrebbero voluto vederlo." } },
	{ Id = "EmporioPorto", Zone = "PortoOrientale", Offset = Vector3.new(-12, 0, 16), Facing = 60, Role = "Shop", Shop = "Emporio",
		Name = "Marta", Title = "Vivandiera",
		Look = { Skin = Color3.fromRGB(236, 200, 175), Hair = Color3.fromRGB(150, 90, 50), HairStyle = "Chignon", Uniform = "Civile" },
		Greeting = { "Provviste per la traversata?" } },
	{ Id = "CorrierePorto", Zone = "PortoOrientale", Offset = Vector3.new(-24, 0, -4), Facing = 90, Role = "Travel",
		Name = "Corriere", Title = "Viaggio Rapido",
		Look = { Skin = Color3.fromRGB(210, 165, 130), Hair = Color3.fromRGB(60, 45, 35), HairStyle = "Corto", Uniform = "Civile", Hat = true },
		Greeting = { "Ti riporto alle Isole in un attimo." } },
	{ Id = "CapitanoHaskelM", Zone = "PortoRevelia", Offset = Vector3.new(-62, 0, 0), Facing = 90, Role = "Ship", Destination = "PortoOrientale",
		Name = "Haskel", Title = "Capitano di Nave",
		Look = { Skin = Color3.fromRGB(196, 146, 112), Hair = Color3.fromRGB(110, 110, 110), HairStyle = "Lungo", Uniform = "Civile", Beard = true, Hat = true },
		Greeting = { "Quando vuoi tornare alle Isole, la nave è pronta." } },
	{ Id = "VarisRevelia", Character = "Varis", Zone = "PortoRevelia", Offset = Vector3.new(0, 0, -14), Facing = 180, Role = "Story",
		Look = { Skin = Color3.fromRGB(222, 182, 150), Hair = Color3.fromRGB(220, 195, 130), HairStyle = "Rasato", Uniform = "Valdoria" },
		Greeting = { "Qui nessuno deve sapere chi sei. Tieni il cappuccio alzato." } },
	{ Id = "ArmaioloDietz", Zone = "PortoRevelia", Offset = Vector3.new(16, 0, 12), Facing = 220, Role = "Shop", Shop = "ArmeriaRevelia",
		Name = "Dietz", Title = "Armaiolo Valdoriano",
		Look = { Skin = Color3.fromRGB(200, 150, 115), Hair = Color3.fromRGB(70, 60, 50), HairStyle = "Corto", Uniform = "Valdoria", Beard = true },
		Greeting = { "Armi marleyane, le migliori del mondo. Non chiedo per chi combatti." } },
	{ Id = "EmporioRevelia", Zone = "PortoRevelia", Offset = Vector3.new(-16, 0, 12), Facing = 140, Role = "Shop", Shop = "Emporio",
		Name = "Anya", Title = "Venditrice",
		Look = { Skin = Color3.fromRGB(226, 186, 160), Hair = Color3.fromRGB(40, 30, 25), HairStyle = "Lungo", Uniform = "Civile" },
		Greeting = { "Isolano? Non dirlo ad alta voce." } },
	{ Id = "MorrowRevelia", Character = "Morrow", Zone = "PortoRevelia", Offset = Vector3.new(24, 0, -6), Facing = 230, Role = "Lab",
		Look = { Skin = Color3.fromRGB(232, 196, 172), Hair = Color3.fromRGB(110, 70, 50), HairStyle = "Coda", Uniform = "NuovoCorpo", Glasses = true },
		Greeting = { "La tecnologia di Valdoria è incredibile! Ho già smontato tre cose." } },
	{ Id = "CorriereRevelia", Zone = "PortoRevelia", Offset = Vector3.new(0, 0, 24), Facing = 0, Role = "Travel",
		Name = "Corriere", Title = "Viaggio Rapido",
		Look = { Skin = Color3.fromRGB(210, 165, 130), Hair = Color3.fromRGB(60, 45, 35), HairStyle = "Corto", Uniform = "Civile", Hat = true },
		Greeting = { "Anche a Valdoria ho le mie strade." } },
	{ Id = "SpiaMila", Zone = "Trincee", Offset = Vector3.new(-150, 0, 40), Facing = 90, Role = "Quest", Quests = { "Q_Soldati1", "Q_T10T", "Q_T15T", "Q_Destriero" },
		Name = "Mila", Title = "Spia Isolana",
		Look = { Skin = Color3.fromRGB(214, 170, 140), Hair = Color3.fromRGB(150, 90, 50), HairStyle = "Coda", Uniform = "Valdoria" },
		Greeting = { "Abbassati! Le trincee hanno occhi ovunque." } },
	{ Id = "ResistenteFalk", Zone = "Revelia", Offset = Vector3.new(-170, 0, -20), Facing = 90, Role = "Quest", Quests = { "Q_Soldati2", "Q_Guardie1", "Q_T12R", "Q_Forgia" },
		Name = "Falk", Title = "Resistenza Isolana",
		Look = { Skin = Color3.fromRGB(205, 160, 125), Hair = Color3.fromRGB(60, 45, 35), HairStyle = "Ricci", Uniform = "Civile", Hood = true },
		Greeting = { "Siamo Isolani anche noi. Aiutaci a buttare giù queste mura." } },
	{ Id = "KaelFortezza", Character = "Kael", Zone = "Fortezza", Offset = Vector3.new(-130, 0, 40), Facing = 90, Role = "Quest", Quests = { "Q_Guardie2", "Q_Guardie3", "Q_T15FV", "Q_Furia" },
		Look = { Skin = Color3.fromRGB(205, 160, 125), Hair = Color3.fromRGB(30, 26, 24), HairStyle = "Corto", Uniform = "Valdoria" },
		Greeting = { "Ho distrutto un distretto intero, una volta. Lascia che stavolta ne salvi uno." } },
	{ Id = "TobiasFortezza", Character = "Tobias", Zone = "Fortezza", Offset = Vector3.new(-118, 0, 54), Facing = 120, Role = "Story",
		Look = { Skin = Color3.fromRGB(230, 190, 160), Hair = Color3.fromRGB(70, 50, 35), HairStyle = "Lungo", Uniform = "NuovoCorpo" },
		Greeting = { "..." } },
	{ Id = "FalknerFronte", Character = "Falkner", Zone = "FronteMarcia", Offset = Vector3.new(-200, 0, -60), Facing = 90, Role = "Quest", Quests = { "Q_T15B1", "Q_T15B2", "Q_TB", "Q_Primordiale" },
		Look = { Skin = Color3.fromRGB(226, 190, 165), Hair = Color3.fromRGB(45, 40, 38), HairStyle = "Corto", Uniform = "NuovoCorpo" },
		Greeting = { "Questa è l'ultima battaglia. Combatti come se il mondo dipendesse da te. Perché è così." } },
	-- TRAGHETTI TRA LE ISOLE --------------------------------------------------------------
	{ Id = "TraghettoVermiglia", Zone = "CampoAddestramento", Offset = Vector3.new(42, 0, 50), Facing = 240, Role = "Ferry",
		Name = "Nocchiero Bruno", Title = "Traghetti tra le isole",
		Look = { Skin = Color3.fromRGB(206, 160, 126), Hair = Color3.fromRGB(90, 70, 52), HairStyle = "Corto", Uniform = "Civile", Beard = true, Hat = true },
		Greeting = { "Le isole sono tante e il mare è grande. Dove ti porto?" } },
	{ Id = "TraghettoEdenia", Zone = "AccampamentoEdenia", Offset = Vector3.new(24, 0, -14), Facing = 300, Role = "Ferry",
		Name = "Nocchiera Ilva", Title = "Traghetti tra le isole",
		Look = { Skin = Color3.fromRGB(236, 200, 170), Hair = Color3.fromRGB(170, 90, 50), HairStyle = "Coda", Uniform = "Civile", Beard = false, Hat = true },
		Greeting = { "Edenia è bella, ma pericolosa. Se vuoi andartene, la barca è pronta." } },
	{ Id = "TraghettoAurea", Zone = "Aurion", Offset = Vector3.new(22, 0, 164), Facing = 200, Role = "Ferry",
		Name = "Nocchiero Lazlo", Title = "Traghetti tra le isole",
		Look = { Skin = Color3.fromRGB(190, 140, 106), Hair = Color3.fromRGB(40, 36, 32), HairStyle = "Rasato", Uniform = "Civile", Beard = true, Hat = true },
		Greeting = { "Aurion non dorme mai, ma il mio traghetto sì... quando non ci sono clienti." } },
	{ Id = "TraghettoCenere", Zone = "ApprodoCenere", Offset = Vector3.new(16, 0, -10), Facing = 180, Role = "Ferry",
		Name = "Nocchiero Teo", Title = "Traghetti tra le isole",
		Look = { Skin = Color3.fromRGB(216, 176, 146), Hair = Color3.fromRGB(130, 130, 130), HairStyle = "Lungo", Uniform = "Civile", Beard = true, Hat = true },
		Greeting = { "Su quest'isola c'è solo cenere e ricordi. Ti porto via quando vuoi." } },
	{ Id = "TraghettoValdoria", Zone = "PortoRevelia", Offset = Vector3.new(-40, 0, 30), Facing = 60, Role = "Ferry",
		Name = "Nocchiera Sabra", Title = "Traghetti tra le isole",
		Look = { Skin = Color3.fromRGB(160, 112, 82), Hair = Color3.fromRGB(30, 26, 22), HairStyle = "Coda", Uniform = "Civile", Beard = false, Hat = true },
		Greeting = { "Le correnti di Valdoria sono traditrici. Ma io le conosco tutte." } },

	-- APPRODO DI CENERE -------------------------------------------------------------------
	{ Id = "EmporioCenere", Zone = "ApprodoCenere", Offset = Vector3.new(-16, 0, -6), Facing = 120, Role = "Shop", Shop = "Emporio",
		Name = "Vivandiera Orla", Title = "Emporio",
		Look = { Skin = Color3.fromRGB(230, 196, 168), Hair = Color3.fromRGB(150, 120, 90), HairStyle = "Coda", Uniform = "Civile", Apron = true },
		Greeting = { "Ho portato quello che potevo dalla terraferma. Serviti." } },
	{ Id = "CorriereCenere", Zone = "ApprodoCenere", Offset = Vector3.new(0, 0, 20), Facing = 0, Role = "Travel",
		Name = "Corriere Abel", Title = "Viaggi a cavallo",
		Look = { Skin = Color3.fromRGB(216, 176, 146), Hair = Color3.fromRGB(60, 44, 32), HairStyle = "Corto", Uniform = "Civile" },
		Greeting = { "Il mio cavallo conosce ogni base che hai già visitato." } },

	-- RAID ----------------------------------------------------------------------------------
	{ Id = "MaestroRaidQG", Zone = "QuartierGenerale", Offset = Vector3.new(0, 0, 26), Facing = 0, Role = "Raid",
		Name = "Maestra d'Arme Vesna", Title = "Maestra dei Raid",
		Look = { Skin = Color3.fromRGB(200, 150, 118), Hair = Color3.fromRGB(30, 26, 24), HairStyle = "Coda", Uniform = "Falchi" },
		Greeting = { "Vuoi metterti alla prova con la tua squadra? L'Arena aspetta solo voi." } },
	{ Id = "MaestroRaidAurion", Zone = "Aurion", Offset = Vector3.new(0, 0, 178), Facing = 180, Role = "Raid",
		Name = "Maestro d'Arme Orsini", Title = "Maestro dei Raid",
		Look = { Skin = Color3.fromRGB(226, 190, 160), Hair = Color3.fromRGB(120, 120, 120), HairStyle = "Corto", Uniform = "Guarnigione", Beard = true },
		Greeting = { "Le ondate dell'Arena non perdonano. Ma le ricompense... quelle sì che valgono." } },
	{ Id = "MaestroRaidRevelia", Zone = "PortoRevelia", Offset = Vector3.new(40, 0, 30), Facing = 300, Role = "Raid",
		Name = "Comandante Ilyas", Title = "Maestro dei Raid",
		Look = { Skin = Color3.fromRGB(176, 128, 96), Hair = Color3.fromRGB(26, 24, 22), HairStyle = "Rasato", Uniform = "Valdoria" },
		Greeting = { "Anche oltre il mare serve allenamento. Prepara la squadra." } },
	-- TAVERNE (mondo aperto): l'oste dietro il bancone ------------------------------------------
	{ Id = "OsteMuro", Zone = "Calaneth", Offset = W.TavernOffset("TavernaMuro", Vector3.new(-12.5, 0, 2)), Facing = (W.TavernById.TavernaMuro.Facing + 90) % 360, Role = "Tavern", Indoor = true, Tavern = "TavernaMuro",
		Name = "Oste Gunther", Title = "Taverna del Muro",
		Look = { Skin = Color3.fromRGB(226, 180, 150), Hair = Color3.fromRGB(110, 80, 50), HairStyle = "Calvo", Uniform = "Civile", Beard = true },
		Greeting = { "Benvenuto alla Taverna del Muro! Qui si mangia bene e si ascoltano storie." } },
	{ Id = "OsteCervo", Zone = "Brenn", Offset = W.TavernOffset("LocandaCervo", Vector3.new(-12.5, 0, 2)), Facing = (W.TavernById.LocandaCervo.Facing + 90) % 360, Role = "Tavern", Indoor = true, Tavern = "LocandaCervo",
		Name = "Ostessa Marta", Title = "Locanda del Cervo",
		Look = { Skin = Color3.fromRGB(236, 196, 166), Hair = Color3.fromRGB(150, 60, 40), HairStyle = "Chignon", Uniform = "Civile" },
		Greeting = { "Siediti, forestiero. Lo stufato di cervo è appena pronto." } },
	{ Id = "OsteAurea", Zone = "Aurion", Offset = W.TavernOffset("OsteriaAurea", Vector3.new(-12.5, 0, 2)), Facing = (W.TavernById.OsteriaAurea.Facing + 90) % 360, Role = "Tavern", Indoor = true, Tavern = "OsteriaAurea",
		Name = "Oste Benedikt", Title = "Osteria Aurea",
		Look = { Skin = Color3.fromRGB(214, 170, 140), Hair = Color3.fromRGB(60, 50, 40), HairStyle = "Corto", Uniform = "Nobile", Beard = true },
		Greeting = { "L'osteria più raffinata della capitale. Le voci, però, sono gratis." } },
	{ Id = "OsteGabbiano", Zone = "PortoOrientale", Offset = W.TavernOffset("TavernaGabbiano", Vector3.new(-12.5, 0, 2)), Facing = (W.TavernById.TavernaGabbiano.Facing + 90) % 360, Role = "Tavern", Indoor = true, Tavern = "TavernaGabbiano",
		Name = "Ostessa Nella", Title = "Taverna del Gabbiano",
		Look = { Skin = Color3.fromRGB(200, 150, 116), Hair = Color3.fromRGB(30, 26, 24), HairStyle = "Ricci", Uniform = "Civile", Scarf = true },
		Greeting = { "I marinai raccontano di tutto: isolotti, relitti, tesori. Vuoi sentire?" } },
	{ Id = "OstePorto", Zone = "PortoRevelia", Offset = W.TavernOffset("OsteriaPorto", Vector3.new(-12.5, 0, 2)), Facing = (W.TavernById.OsteriaPorto.Facing + 90) % 360, Role = "Tavern", Indoor = true, Tavern = "OsteriaPorto",
		Name = "Oste Malik", Title = "Osteria del Porto",
		Look = { Skin = Color3.fromRGB(150, 104, 76), Hair = Color3.fromRGB(26, 22, 20), HairStyle = "Rasato", Uniform = "Civile", Beard = true },
		Greeting = { "Nuovo a Valdoria? Mangia qualcosa, poi ti racconto dove andare a cercare guai." } },
	-- MONDO APERTO -------------------------------------------------------------------------
	{ Id = "MercantePalme", Zone = "IsolaPalme", Offset = Vector3.new(10, 0, -12), Facing = 200, Role = "Shop", Shop = "Emporio",
		Name = "Vecchio Ezio", Title = "Mercante delle Palme",
		Look = { Skin = Color3.fromRGB(196, 146, 110), Hair = Color3.fromRGB(220, 220, 220), HairStyle = "Lungo", Uniform = "Civile", Beard = true, Hat = true },
		Greeting = { "Pochi arrivano fin qui. Hai bisogno di gas, razioni, lame?" } },
	{ Id = "MaestroDuelli", Zone = "ArenaDuelli", Offset = Vector3.new(0, 0, 62), Facing = 0, Role = "Duel",
		Name = "Maestro Ingrid", Title = "Arena dei Duelli",
		Look = { Skin = Color3.fromRGB(230, 192, 160), Hair = Color3.fromRGB(200, 190, 170), HairStyle = "Coda", Uniform = "Falchi", Scarf = true },
		Greeting = { "Dentro l'arena il PvP è sempre attivo. Vinci i duelli e la tua taglia salirà!" } },
	{ Id = "CustodeArena", Zone = "ArenaRaid", Offset = Vector3.new(0, 0, 230), Facing = 180, Role = "RaidArena",
		Name = "Custode dell'Arena", Title = "Arena dei Raid",
		Look = { Skin = Color3.fromRGB(220, 182, 150), Hair = Color3.fromRGB(200, 200, 200), HairStyle = "Lungo", Uniform = "Civile", Beard = true },
		Greeting = { "Benvenuto nell'Arena. Quando il raid comincia, resta dentro le mura." } },
}

NPCs.List = NPCList
NPCs.ById = {}
for _, npc in NPCList do
	assert(NPCs.ById[npc.Id] == nil, "NPC duplicato: " .. npc.Id)
	NPCs.ById[npc.Id] = npc
end

function NPCs.Get(id: string?)
	return id and NPCs.ById[id]
end

-- Nome e titolo da mostrare (dal personaggio, se presente)
function NPCs.DisplayName(npc): (string, string)
	local character = npc.Character and NPCs.Characters[npc.Character]
	local name = npc.Name or (character and character.Name) or npc.Id
	local title = npc.Title or (character and character.Title) or ""
	return name, title
end

-- Nome di chi parla in un dialogo della storia (Speaker = Character o NPC Id)
function NPCs.SpeakerName(speaker: string): string
	local character = NPCs.Characters[speaker]
	if character then
		return character.Name
	end
	local npc = NPCs.ById[speaker]
	if npc then
		return (NPCs.DisplayName(npc))
	end
	return speaker
end

return NPCs
