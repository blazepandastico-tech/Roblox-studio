--[[
	Story - "Sieri Perduti"
	Una storia ORIGINALE ambientata nell'Arcipelago dei Giganti,
	divisa nelle quattro stagioni: la caduta delle Mura, i traditori,
	la verità nel seminterrato e la guerra oltre il mare.

	Il protagonista è il giocatore: un sopravvissuto della caduta di Halvar che
	porta al collo una fiala spezzata. Dietro tutto c'è il Dott. Edric Vael,
	lo scienziato che ha imparato a distillare i poteri degli Otto Giganti in sieri.

	Tipi di passo (Type):
	  Cutscene  - scena animata                   (Cutscene)
	  Talk      - parla con un PNG                 (Npc, Dialogue)
	  Reach     - raggiungi una zona o un punto    (Zone | Position + Radius)
	  Kill      - uccidi giganti                   (Class, Zone, Count)
	  Enemy     - sconfiggi nemici umani           (Enemy, Zone, Count)
	  Boss      - sconfiggi un boss gigante        (Boss)
	  HumanBoss - sconfiggi un boss umano          (Boss)
	  Level     - raggiungi un livello             (Level)
	  Collect   - raccogli oggetti nella zona      (Item, Zone, Count)
	After = battute mostrate quando il passo è completato.
	Reward = { XP = moltiplicatore della XP di una missione, Gold = oro, Items = { Id = quantità } }
]]

local W = require(script.Parent.WorldLayout)

local Story = {}

local function L(speaker: string, text: string)
	return { Speaker = speaker, Text = text }
end

Story.Chapters = {
	-- =========================================================================
	-- STAGIONE 1 - IL MURO INFRANTO
	-- =========================================================================
	{
		Id = "S1C1",
		Season = 1,
		Title = "Capitolo 1 - Recluta",
		Level = 1,
		Summary = "Cinque anni dopo la caduta di Halvar, entri nel Corpo Cadetti con una sola cosa al collo: una fiala spezzata.",
		Steps = {
			{ Type = "Cutscene", Cutscene = "Prologo", Objective = "Il giorno della caduta" },
			{
				Type = "Talk",
				Npc = "Brehm",
				Objective = "Presentati all'Istruttore Brehm",
				Dialogue = {
					L("Brehm", "Tu! Sì, proprio tu. Nome, provenienza, e perché sei qui!"),
					L("Brehm", "Halvar, eh? Un altro sopravvissuto della caduta. Le Mura sono piene di ragazzi con la vendetta negli occhi."),
					L("Brehm", "La vendetta non ti terrà in vita. I Rampini a Gas sì."),
					L("Brehm", "Premi Q ed E per lanciare i rampini, tieni premuto per restare agganciato e usa Spazio per il gas. Ora vola fino in cima alla torre!"),
				},
				Reward = { XP = 0.6, Gold = 200 },
			},
			{
				Type = "Reach",
				Position = W.Landmarks.TorreAddestramento,
				Radius = 26,
				Objective = "Usa i Rampini (Q / E) e raggiungi la cima della Torre di Addestramento",
				After = { L("Brehm", "Non male. Almeno non ti sei spiaccicato come l'ultimo cadetto.") },
				Reward = { XP = 0.8, Gold = 150 },
			},
			{
				Type = "Kill",
				Class = "Sagoma",
				Zone = "CampoAddestramento",
				Count = 5,
				Objective = "Abbatti 5 Sagome di legno colpendo la NUCA (clic sinistro)",
				After = {
					L("Brehm", "La nuca. Sempre la nuca. Un taglio largo un palmo e profondo un pugno."),
					L("Brehm", "E ricorda: più vai veloce, più il colpo è letale. Un Taglio Perfetto ad alta velocità può abbattere un gigante in un colpo solo."),
				},
				Reward = { XP = 1, Gold = 200 },
			},
			{
				Type = "Talk",
				Npc = "Tobias",
				Objective = "Parla con il cadetto Tobias Renz",
				Dialogue = {
					L("Tobias", "Allora sei tu quello di Halvar! Anch'io c'ero, quel giorno. Non ricordo quasi niente... solo una luce, un ago, e poi la febbre."),
					L("Tobias", "Mira dice che sono strano. Varis e Kael dicono che sono solo testardo. Tu che dici?"),
					L("Mira", "Dico che parli troppo, Tobias."),
					L("Tobias", "Quando entreremo nel Corpo dei Falchi andremo oltre le Mura. Vedremo il mondo. E li sterminerò, fino all'ultimo gigante."),
				},
				Reward = { XP = 0.5 },
			},
			{
				Type = "Talk",
				Npc = "Brehm",
				Objective = "Torna dall'Istruttore Brehm per il giuramento",
				Dialogue = {
					L("Brehm", "Recluta. Hai superato l'addestramento tra i primi dieci. Non farmelo rimpiangere."),
					L("Brehm", "Da oggi sei un soldato delle Isole. Vola oltre la paura!"),
					L("Narratore", "La mano sull'elsa, lo sguardo al cielo. Il giuramento è fatto."),
				},
				Reward = { XP = 1, Gold = 500, Items = { DistintivoPrimiDieci = 1 } },
			},
		},
	},
	{
		Id = "S1C2",
		Season = 1,
		Title = "Capitolo 2 - Il Recinto",
		Level = 5,
		Summary = "La Dott.ssa Morrow studia i giganti catturati. E la tua fiala la interessa moltissimo.",
		Steps = {
			{
				Type = "Talk",
				Npc = "MorrowRecinto",
				Objective = "Raggiungi la Dott.ssa Morrow al Recinto dei Giganti",
				Dialogue = {
					L("Morrow", "Oh! Una recluta nuova di zecca! Perfetto, mi servono braccia. E possibilmente teste che restino attaccate al collo."),
					L("Morrow", "Questi piccoletti li abbiamo catturati vivi. Studiarli è il mio lavoro, sfoltirli è il tuo."),
					L("Morrow", "Aspetta... cos'è quella fiala che porti al collo? Fammela vedere! Subito!"),
					L("Morrow", "Liquido spinale di gigante, raffinato e cristallizzato. Qualcuno sta fabbricando SIERI. Tienila al sicuro."),
				},
				Reward = { XP = 0.6, Gold = 300 },
			},
			{ Type = "Kill", Class = "T3", Zone = "Recinto", Count = 8, Objective = "Elimina 8 Giganti da 3 metri nel Recinto", Reward = { XP = 1, Gold = 300 } },
			{ Type = "Level", Level = 12, Objective = "Raggiungi il livello 12 (accetta le missioni del Sergente Marr)" },
			{ Type = "Kill", Class = "T4", Zone = "Recinto", Count = 6, Objective = "Elimina 6 Giganti da 4 metri nel Recinto", Reward = { XP = 1, Gold = 400 } },
			{
				Type = "Talk",
				Npc = "Falkner",
				Objective = "Presentati al Quartier Generale del Corpo dei Falchi",
				Dialogue = {
					L("Falkner", "Rhea Falkner, capitano della Squadra Grifone. Morrow mi ha parlato di te. E della tua fiala."),
					L("Falkner", "Il Corpo dei Falchi non prende cadetti. Ma Calaneth ha bisogno di ogni lama disponibile."),
					L("Falkner", "Considera questo il tuo esame. Se sopravvivi, ne riparliamo."),
				},
				Reward = { XP = 1, Gold = 1500 },
			},
		},
	},
	{
		Id = "S1C3",
		Season = 1,
		Title = "Capitolo 3 - L'Assedio di Calaneth",
		Level = 25,
		Summary = "Il Gigante Vulcano riappare e sfonda il cancello di Calaneth. La storia si ripete.",
		Steps = {
			{ Type = "Cutscene", Cutscene = "Calaneth", Objective = "Il ritorno del Vulcano" },
			{
				Type = "Talk",
				Npc = "Weiss",
				Objective = "Corri a Calaneth e fai rapporto al Comandante Weiss",
				Dialogue = {
					L("Weiss", "Recluta! Il Vulcano è apparso dal nulla, ha sfondato il cancello esterno ed è svanito nel vapore. Come cinque anni fa."),
					L("Weiss", "Il deposito di rifornimento è circondato. Senza gas i miei uomini sono carne da macello."),
					L("Weiss", "Ripulisci le strade. E non farti afferrare: se un gigante ti prende, premi Spazio più veloce che puoi!"),
				},
				Reward = { XP = 0.5 },
			},
			{ Type = "Kill", Class = "T5", Zone = "Calaneth", Count = 10, Objective = "Elimina 10 Giganti da 5 metri a Calaneth", Reward = { XP = 1.2, Gold = 1000 } },
			{ Type = "Kill", Class = "T7", Zone = "Calaneth", Count = 8, Objective = "Elimina 8 Giganti da 7 metri a Calaneth", Reward = { XP = 1.2, Gold = 1500 } },
			{
				Type = "Boss",
				Boss = "Ghignante",
				Objective = "Abbatti il Gigante Ghignante che terrorizza il distretto",
				After = { L("Weiss", "Quel mostro sorridente è caduto! Ma guardate... laggiù, vicino al cancello!") },
				Reward = { XP = 2, Gold = 4000 },
			},
			{ Type = "Cutscene", Cutscene = "TobiasGigante", Objective = "Un gigante contro i giganti" },
			{
				Type = "Talk",
				Npc = "Weiss",
				Objective = "Parla con il Comandante Weiss",
				Dialogue = {
					L("Weiss", "Un gigante che combatte i giganti... e dentro la nuca c'era il ragazzo. Renz."),
					L("Weiss", "Ha sollevato un masso grande come una casa e ha sigillato il cancello. Abbiamo vinto, per oggi."),
					L("Weiss", "Ma la Gendarmeria Reale vorrà la sua testa. E forse anche la tua, visto che eri con lui."),
				},
				Reward = { XP = 1.5, Gold = 3000 },
			},
		},
	},
	{
		Id = "S1C4",
		Season = 1,
		Title = "Capitolo 4 - Oltre il Muro",
		Level = 70,
		Summary = "Entri ufficialmente nel Corpo dei Falchi. La prima spedizione punta alla Foresta degli Alberi Giganti.",
		Steps = {
			{
				Type = "Talk",
				Npc = "Falkner",
				Objective = "Torna dal Capitano Falkner al Quartier Generale",
				Dialogue = {
					L("Falkner", "Il tribunale ha affidato Tobias al Corpo dei Falchi. E tu sei nella mia squadra, adesso."),
					L("Falkner", "Questa è tua. Indossala con orgoglio: le Ali del Falco non si portano per caso."),
					L("Falkner", "La spedizione parte all'alba. Apri la strada nelle Pianure Meridionali."),
				},
				Reward = { XP = 1, Gold = 2000, Items = { UniformeFalchi = 1 } },
			},
			{ Type = "Kill", Class = "T7", Zone = "PianureSud", Count = 10, Objective = "Elimina 10 Giganti da 7 metri nelle Pianure Meridionali", Reward = { XP = 1.2, Gold = 3000 } },
			{ Type = "Level", Level = 100, Objective = "Raggiungi il livello 100" },
			{ Type = "Kill", Class = "T10", Zone = "PianureSud", Count = 10, Objective = "Elimina 10 Giganti da 10 metri nelle Pianure Meridionali", Reward = { XP = 1.2, Gold = 4000 } },
			{
				Type = "Talk",
				Npc = "UfficialeRoth",
				Objective = "Raggiungi l'Avamposto della Spedizione e parla con l'Ufficiale Roth",
				Dialogue = {
					L("Roth", "Abbiamo trovato un accampamento abbandonato ai margini della foresta. Casse, siringhe vuote..."),
					L("Roth", "...e lo stesso simbolo della tua fiala. Chiunque fosse qui sapeva che saremmo arrivati."),
				},
				Reward = { XP = 1, Gold = 3000 },
			},
		},
	},
	{
		Id = "S1C5",
		Season = 1,
		Title = "Capitolo 5 - La Cacciatrice",
		Level = 130,
		Summary = "Nella foresta, un gigante intelligente caccia Tobias. Chi c'è dentro?",
		Steps = {
			{ Type = "Kill", Class = "T10", Zone = "Foresta", Count = 12, Objective = "Elimina 12 Giganti da 10 metri nella Foresta", Reward = { XP = 1.2, Gold = 5000 } },
			{ Type = "Kill", Class = "T12", Zone = "Foresta", Count = 10, Objective = "Elimina 10 Giganti da 12 metri nella Foresta", Reward = { XP = 1.2, Gold = 6000 } },
			{ Type = "Level", Level = 180, Objective = "Raggiungi il livello 180" },
			{ Type = "Cutscene", Cutscene = "Cacciatrice", Objective = "Qualcosa corre tra gli alberi" },
			{
				Type = "Boss",
				Boss = "Cacciatrice",
				Objective = "Sconfiggi il Gigante Cacciatrice nella Foresta",
				After = { L("Falkner", "È caduta! Ma prima di uscire dalla nuca si è chiusa in un cristallo... Portiamola alla Dott.ssa Morrow.") },
				Reward = { XP = 2.5, Gold = 15000 },
			},
			{
				Type = "Talk",
				Npc = "MorrowQG",
				Objective = "Porta le prove alla Dott.ssa Morrow al Quartier Generale",
				Dialogue = {
					L("Morrow", "Lyra Venn. Gendarmeria Reale. Si è chiusa in un cristallo più duro del diamante prima che potessimo interrogarla."),
					L("Morrow", "Ma nel suo equipaggiamento c'era questa: una siringa vuota con il tuo simbolo. Il suo potere non era ereditato... era INIETTATO."),
					L("Morrow", "Sieri artificiali degli Otto Giganti. Sieri Perduti. Se qualcuno li sta producendo, la guerra che conosciamo è solo l'inizio."),
					L("Morrow", "Tieni questi frammenti. Se un giorno ne raccoglierai abbastanza, potrei sintetizzare un siero anche io. In teoria. Forse. Probabilmente."),
				},
				Reward = { XP = 2, Gold = 10000, Items = { FrammentoSiero = 5 } },
			},
		},
	},

	-- =========================================================================
	-- STAGIONE 2 - IL SANGUE DENTRO LE MURA
	-- =========================================================================
	{
		Id = "S2C1",
		Season = 2,
		Title = "Capitolo 6 - Nebbia su Brenn",
		Level = 200,
		Summary = "Giganti dentro il Muro Vermiglio senza nessuna breccia. A Brenn c'è stata una nebbia verde.",
		Steps = {
			{
				Type = "Talk",
				Npc = "Falkner",
				Objective = "Parla con il Capitano Falkner",
				Dialogue = {
					L("Falkner", "Giganti dentro il Muro Vermiglio. Nessuna breccia, nessun cancello aperto. Sono semplicemente... apparsi."),
					L("Falkner", "I superstiti del villaggio di Brenn parlano di una nebbia verde, la notte prima. Vai a vedere."),
				},
				Reward = { XP = 0.5 },
			},
			{ Type = "Reach", Zone = "Brenn", Objective = "Raggiungi il Villaggio di Brenn" },
			{ Type = "Kill", Class = "T7", Zone = "Brenn", Count = 10, Objective = "Elimina 10 Giganti da 7 metri a Brenn", Reward = { XP = 1.2, Gold = 15000 } },
			{
				Type = "Collect",
				Item = "BombolaNebbia",
				Zone = "Brenn",
				Count = 5,
				Objective = "Raccogli 5 Bombole di Nebbia sparse nel villaggio",
				Reward = { XP = 1, Gold = 8000 },
			},
			{
				Type = "Talk",
				Npc = "MorrowQG",
				Objective = "Porta le bombole alla Dott.ssa Morrow",
				Dialogue = {
					L("Morrow", "Siero vaporizzato. Chi respira questa nebbia diventa un gigante puro."),
					L("Morrow", "Gli abitanti di Brenn... sono quei giganti. Li hai liberati, in un certo senso."),
					L("Morrow", "Che orrore. Che genio. Che ORRORE. Prendi i miei occhiali di riserva: ti aiuteranno a trovare i frammenti."),
				},
				Reward = { XP = 2, Gold = 20000, Items = { OcchialiRicercatrice = 1 } },
			},
		},
	},
	{
		Id = "S2C2",
		Season = 2,
		Title = "Capitolo 7 - La Notte del Castello",
		Level = 280,
		Summary = "Al Castello di Ostrava i giganti attaccano di notte. Sulla collina, un gigante peloso lancia massi.",
		Steps = {
			{ Type = "Reach", Zone = "Ostrava", Objective = "Raggiungi il Castello di Ostrava" },
			{ Type = "Kill", Class = "T10", Zone = "Ostrava", Count = 12, Objective = "Difendi il castello: 12 Giganti da 10 metri", Reward = { XP = 1.2, Gold = 20000 } },
			{ Type = "Kill", Class = "T12", Zone = "Ostrava", Count = 10, Objective = "Elimina 10 Giganti da 12 metri a Ostrava", Reward = { XP = 1.2, Gold = 25000 } },
			{ Type = "Cutscene", Cutscene = "Fauno", Objective = "Il gigante che parla" },
			{
				Type = "Boss",
				Boss = "Fauno",
				Objective = "Sconfiggi il Gigante Fauno",
				After = { L("Varis", "Si è ritirato oltre il muro, ma l'abbiamo ferito. Hai sentito? Parlava! Ha detto un nome... Vael.") },
				Reward = { XP = 2.5, Gold = 60000 },
			},
			{
				Type = "Talk",
				Npc = "VarisOstrava",
				Objective = "Parla con Varis Holt",
				Dialogue = {
					L("Varis", "Quel gigante peloso parlava come un professore. 'Il dottor Vael manda i suoi saluti', ha detto."),
					L("Varis", "...Ascolta. Se dovesse succedermi qualcosa, voglio che tu sappia una cosa."),
					L("Varis", "Non avrei mai voluto mentirti. Mai."),
				},
				Reward = { XP = 1, Gold = 20000 },
			},
		},
	},
	{
		Id = "S2C3",
		Season = 2,
		Title = "Capitolo 8 - Il Tradimento",
		Level = 350,
		Summary = "Sulla cresta della Gola di Edenia, due compagni rivelano chi sono davvero.",
		Steps = {
			{
				Type = "Talk",
				Npc = "KaelEdenia",
				Objective = "Parla con Kael Dorn all'Accampamento di Edenia",
				Dialogue = {
					L("Kael", "Varis vuole parlarti. Da solo. Sulla cresta della Gola di Edenia."),
					L("Kael", "...Mi dispiace. Per tutto."),
				},
				Reward = { XP = 0.5 },
			},
			{ Type = "Reach", Zone = "GolaEdenia", Objective = "Raggiungi la Gola di Edenia" },
			{ Type = "Cutscene", Cutscene = "Tradimento", Objective = "La verità sulla cresta" },
			{ Type = "Kill", Class = "T12", Zone = "GolaEdenia", Count = 12, Objective = "Sopravvivi: elimina 12 Giganti da 12 metri nella gola", Reward = { XP = 1.2, Gold = 30000 } },
			{
				Type = "Boss",
				Boss = "Bastione",
				Objective = "Sconfiggi il Gigante Bastione (rompi la corazza, poi colpisci la nuca)",
				After = { L("Falkner", "Le Lance Dirompenti avrebbero fatto comodo... Ricordatelo: contro la corazza servono esplosivi o colpi continui.") },
				Reward = { XP = 2.5, Gold = 80000 },
			},
			{
				Type = "Talk",
				Npc = "FalknerEdenia",
				Objective = "Fai rapporto al Capitano Falkner",
				Dialogue = {
					L("Falkner", "Varis Holt è il Gigante Bastione. Kael Dorn il Vulcano. Erano con noi dal primo giorno."),
					L("Falkner", "Ma prima di fuggire Varis ha detto una cosa strana: 'Non siamo noi i vostri nemici. È Vael.'"),
					L("Falkner", "Un nemico del nostro nemico... o una bugia ben recitata. Lo scopriremo."),
				},
				Reward = { XP = 1.5, Gold = 40000 },
			},
		},
	},
	{
		Id = "S2C4",
		Season = 2,
		Title = "Capitolo 9 - L'Urlo",
		Level = 420,
		Summary = "Tobias urla, e i giganti obbediscono. Cosa gli ha fatto Vael da bambino?",
		Steps = {
			{ Type = "Kill", Class = "T15", Zone = "GolaEdenia", Count = 10, Objective = "Elimina 10 Giganti da 15 metri nella Gola di Edenia", Reward = { XP = 1.2, Gold = 40000 } },
			{
				Type = "Boss",
				Boss = "Zanna",
				Objective = "Sconfiggi il Gigante Zanna",
				Reward = { XP = 2.5, Gold = 90000 },
			},
			{ Type = "Cutscene", Cutscene = "Urlo", Objective = "L'urlo" },
			{
				Type = "Talk",
				Npc = "TobiasEdenia",
				Objective = "Parla con Tobias",
				Dialogue = {
					L("Tobias", "Ho urlato... e i giganti si sono fermati. Tutti. Come se mi ascoltassero."),
					L("Tobias", "Nella mia testa ho visto un uomo con gli occhiali verdi, un laboratorio, e migliaia di siringhe. Vael. Mi ha fatto qualcosa quando ero bambino."),
					L("Tobias", "Se si nasconde a Aurion, lo troveremo. E stavolta non scapperà."),
				},
				Reward = { XP = 2, Gold = 60000 },
			},
		},
	},

	-- =========================================================================
	-- STAGIONE 3 - LA VERITÀ NEL SEMINTERRATO
	-- =========================================================================
	{
		Id = "S3C1",
		Season = 3,
		Title = "Capitolo 10 - La Capitale Corrotta",
		Level = 450,
		Summary = "A Aurion la Gendarmeria Reale protegge Vael. Una ragazza delle cucine sa più di quanto dice.",
		Steps = {
			{ Type = "Reach", Zone = "Aurion", Objective = "Raggiungi la Capitale Aurion, dentro il Muro Aureo" },
			{
				Type = "Talk",
				Npc = "Elise",
				Objective = "Parla con la ragazza di nome Elise",
				Dialogue = {
					L("Elise", "Mi chiamo Elise. Lavoro nelle cucine del palazzo... almeno, è quello che dicono i miei documenti."),
					L("Elise", "La Polizia di Stohlberg nasconde casse marchiate con il simbolo della tua fiala. Le portano sottoterra, ogni notte."),
					L("Elise", "Stohlberg è oltre il cancello est del Muro Aureo. Fai attenzione: i poliziotti corrotti sparano a vista."),
				},
				Reward = { XP = 0.6 },
			},
			{ Type = "Enemy", Enemy = "PoliziaCorrotta", Zone = "Stohlberg", Count = 12, Objective = "Sconfiggi 12 Poliziotti Corrotti a Stohlberg", Reward = { XP = 1.3, Gold = 60000 } },
			{
				Type = "Talk",
				Npc = "Elise",
				Objective = "Torna da Elise con i registri",
				Dialogue = {
					L("Elise", "'Consegna per V., Città Sotterranea.' Il Corvo Nero lavora per lui."),
					L("Elise", "C'è un'altra cosa che devo dirti. Il mio vero nome è Elise Vellmore. Sono l'ultima erede della Stirpe Reale."),
					L("Elise", "Mio padre, Lord Ansel, ha fatto un patto con Vael. Ti prego... fermali entrambi."),
				},
				Reward = { XP = 1.5, Gold = 80000 },
			},
		},
	},
	{
		Id = "S3C2",
		Season = 3,
		Title = "Capitolo 11 - La Città Sotterranea",
		Level = 550,
		Summary = "Una città senza cielo sotto la capitale. Il regno del Corvo Nero e della Squadra Ombra.",
		Steps = {
			{ Type = "Reach", Zone = "CittaSotterranea", Objective = "Scendi nella Città Sotterranea (ascensore di Aurion)" },
			{ Type = "Enemy", Enemy = "SquadraOmbra", Zone = "CittaSotterranea", Count = 12, Objective = "Sconfiggi 12 Agenti Ombra", Reward = { XP = 1.3, Gold = 90000 } },
			{ Type = "Level", Level = 620, Objective = "Raggiungi il livello 620" },
			{
				Type = "HumanBoss",
				Boss = "Corvo",
				Objective = "Sconfiggi il Corvo Nero",
				After = {
					L("Corvo", "Bel lavoro, ragazzino... ma sei in ritardo."),
					L("Corvo", "Vael e Lord Vellmore sono già nella Caverna di Cristallo. Il Lord vuole il Siero Primordiale... e Vael gliel'ha promesso."),
				},
				Reward = { XP = 2.5, Gold = 200000 },
			},
		},
	},
	{
		Id = "S3C3",
		Season = 3,
		Title = "Capitolo 12 - La Caverna di Cristallo",
		Level = 650,
		Summary = "Lord Ansel Vellmore inietta un Siero Perduto. Il risultato è un gigante grande come una collina.",
		Steps = {
			{ Type = "Reach", Zone = "CavernaCristallo", Objective = "Entra nella Caverna di Cristallo (Piana di Orvel)" },
			{ Type = "Kill", Class = "T7", Zone = "CavernaCristallo", Count = 12, Objective = "Elimina 12 Giganti di Cristallo da 7 metri", Reward = { XP = 1.2, Gold = 100000 } },
			{ Type = "Kill", Class = "T10", Zone = "CavernaCristallo", Count = 10, Objective = "Elimina 10 Giganti di Cristallo da 10 metri", Reward = { XP = 1.2, Gold = 110000 } },
			{ Type = "Cutscene", Cutscene = "Strisciante", Objective = "La terra si apre" },
			{ Type = "Kill", Class = "T12", Zone = "PianaOrvel", Count = 10, Objective = "Proteggi la piana: 10 Giganti da 12 metri", Reward = { XP = 1.2, Gold = 120000 } },
			{
				Type = "Boss",
				Boss = "Strisciante",
				Objective = "Sconfiggi il Gigante Strisciante prima che raggiunga le Mura",
				Reward = { XP = 2.5, Gold = 300000 },
			},
			{
				Type = "Talk",
				Npc = "Elise",
				Objective = "Torna da Elise a Aurion",
				Dialogue = {
					L("Elise", "Mio padre ha scelto il siero. Io scelgo le persone."),
					L("Elise", "Da oggi sono la Regina di Edenia. E la Regina ordina al Corpo dei Falchi di riprendersi Halvar."),
					L("Elise", "Prendi questi cristalli: venivano dalla caverna. Che servano a qualcosa di buono, almeno una volta."),
				},
				Reward = { XP = 2, Gold = 200000, Items = { CristalloIndurito = 10 } },
			},
		},
	},
	{
		Id = "S3C4",
		Season = 3,
		Title = "Capitolo 13 - Ritorno ad Halvar",
		Level = 800,
		Summary = "La riconquista del tuo distretto natale. Nel seminterrato di casa tua ti aspetta la verità.",
		Steps = {
			{
				Type = "Talk",
				Npc = "FalknerHalvar",
				Objective = "Raggiungi le Rovine di Halvar e parla con il Capitano Falkner",
				Dialogue = {
					L("Falkner", "Operazione di riconquista di Halvar. Ripuliamo il distretto e raggiungiamo la tua vecchia casa."),
					L("Falkner", "Morrow crede che tuo padre lavorasse con Vael, prima della caduta. Le risposte sono in quel seminterrato."),
				},
				Reward = { XP = 0.6 },
			},
			{ Type = "Kill", Class = "T12", Zone = "Halvar", Count = 14, Objective = "Elimina 14 Giganti da 12 metri a Halvar", Reward = { XP = 1.2, Gold = 150000 } },
			{ Type = "Kill", Class = "T15", Zone = "Halvar", Count = 10, Objective = "Elimina 10 Giganti da 15 metri a Halvar", Reward = { XP = 1.2, Gold = 160000 } },
			{ Type = "Cutscene", Cutscene = "Vulcano", Objective = "Il cielo esplode" },
			{
				Type = "Boss",
				Boss = "Vulcano",
				Objective = "Sconfiggi il Gigante Vulcano",
				After = { L("Falkner", "Il Vulcano è caduto... Kael è fuggito con Varis verso il mare. La strada per la tua casa è libera.") },
				Reward = { XP = 3, Gold = 500000 },
			},
			{
				Type = "Talk",
				Npc = "Seminterrato",
				Objective = "Apri la porta del seminterrato della tua vecchia casa",
				Dialogue = {
					L("Narratore", "La fiala spezzata ha la forma esatta della serratura. La chiave era al tuo collo da sempre."),
					L("Diario", "'Vael ha trovato il modo di distillare gli Otto Giganti in sieri. Copie imperfette, ma reali.'"),
					L("Diario", "'Il suo obiettivo è il Siero Primordiale: tutti e otto i poteri in un solo corpo... più un nono, che nessuno ha mai visto. Un dio capace di riscrivere il mondo.'"),
					L("Diario", "'Ho iniettato a mio figlio l'antidoto prima che Vael potesse usarlo come cavia. Spero che un giorno mi perdoni.'"),
					L("Diario", "'Oltre il mare c'è Valdoria. Oltre il mare c'è il resto del mondo. E il mondo ci odia.'"),
				},
				Reward = { XP = 3, Gold = 300000, Items = { ChiaveSeminterrato = 1 } },
			},
			{ Type = "Level", Level = 1000, Objective = "Raggiungi il livello 1000 per salpare oltre il mare" },
		},
	},

	-- =========================================================================
	-- STAGIONE 4 - OLTRE IL MARE
	-- =========================================================================
	{
		Id = "S4C1",
		Season = 4,
		Title = "Capitolo 14 - La Traversata",
		Level = 1000,
		Summary = "Quattro anni dopo Halvar. Nuove uniformi, Lance Dirompenti, e una nave verso Valdoria.",
		Steps = {
			{
				Type = "Talk",
				Npc = "FalknerPorto",
				Objective = "Raggiungi il Porto Orientale e parla con il Capitano Falkner",
				Dialogue = {
					L("Falkner", "Quattro anni. Nuove uniformi, Lance Dirompenti, e una nave. Chi l'avrebbe detto?"),
					L("Falkner", "Valdoria prepara la guerra contro Edenia, e Vael è laggiù, protetto dai loro generali."),
					L("Falkner", "Parla con il capitano Haskel quando sei pronto. Si salpa."),
				},
				Reward = { XP = 0.6 },
			},
			{ Type = "Reach", Zone = "PortoRevelia", Objective = "Salpa per Valdoria e sbarca al Porto di Revelia" },
			{
				Type = "Talk",
				Npc = "VarisRevelia",
				Objective = "Incontra Varis Holt al porto",
				Dialogue = {
					L("Varis", "Sapevo che saresti venuto. Io e Kael abbiamo disertato."),
					L("Varis", "Vael ha usato la sua nebbia anche sui bambini di Valdoria. Per lui siamo tutti cavie, da una parte e dall'altra del mare."),
					L("Varis", "Il nemico è uno solo. Lascia che ti aiuti a raggiungerlo. Prima però dobbiamo superare le trincee."),
				},
				Reward = { XP = 1 },
			},
			{ Type = "Enemy", Enemy = "SoldatoValdoriano", Zone = "Trincee", Count = 15, Objective = "Sconfiggi 15 Soldati Valdoriani nelle Trincee", Reward = { XP = 1.3, Gold = 400000 } },
			{ Type = "Kill", Class = "T15", Zone = "Trincee", Count = 10, Objective = "Elimina 10 Giganti da 15 metri nelle Trincee", Reward = { XP = 1.2, Gold = 420000 } },
			{
				Type = "Boss",
				Boss = "Destriero",
				Objective = "Sconfiggi il Gigante Destriero",
				After = { L("Varis", "Wren si è ritirata. È una brava persona, sai? Un giorno capirà.") },
				Reward = { XP = 2.5, Gold = 900000 },
			},
		},
	},
	{
		Id = "S4C2",
		Season = 4,
		Title = "Capitolo 15 - La Notte di Revelia",
		Level = 1200,
		Summary = "La rivolta della zona d'internamento. Il Forgia difende i segreti di Vael.",
		Steps = {
			{ Type = "Reach", Zone = "Revelia", Objective = "Infiltrati nel Distretto di Revelia" },
			{ Type = "Enemy", Enemy = "GuardiaVael", Zone = "Revelia", Count = 15, Objective = "Sconfiggi 15 Guardie di Vael a Revelia", Reward = { XP = 1.3, Gold = 600000 } },
			{ Type = "Kill", Class = "T12", Zone = "Revelia", Count = 12, Objective = "Elimina 12 Giganti da 12 metri in città", Reward = { XP = 1.2, Gold = 600000 } },
			{
				Type = "Boss",
				Boss = "Forgia",
				Objective = "Sconfiggi il Gigante della Forgia",
				Reward = { XP = 2.5, Gold = 1500000 },
			},
			{ Type = "Cutscene", Cutscene = "TobiasRibelle", Objective = "Tobias se ne va" },
			{
				Type = "Talk",
				Npc = "VarisRevelia",
				Objective = "Torna da Varis al porto",
				Dialogue = {
					L("Varis", "Tobias ha preso le chiavi del caveau di Vael. Dice che la libertà ha un prezzo... e che lo pagherà da solo."),
					L("Varis", "Se arriva per primo al Siero Primordiale, non so chi tra lui e Vael sarà peggio."),
					L("Varis", "La fortezza di Vael è a est. Kael ci aspetta là."),
				},
				Reward = { XP = 1.5, Gold = 800000 },
			},
		},
	},
	{
		Id = "S4C3",
		Season = 4,
		Title = "Capitolo 16 - La Fortezza di Vael",
		Level = 1450,
		Summary = "Il laboratorio dove nascono i Sieri Perduti. E un vecchio amico che ti sbarra la strada.",
		Steps = {
			{ Type = "Reach", Zone = "Fortezza", Objective = "Raggiungi la Fortezza di Vael" },
			{ Type = "Enemy", Enemy = "GuardiaVael", Zone = "Fortezza", Count = 15, Objective = "Sconfiggi 15 Guardie di Vael nella fortezza", Reward = { XP = 1.3, Gold = 1000000 } },
			{ Type = "Kill", Class = "T15", Zone = "Fortezza", Count = 12, Objective = "Elimina 12 esperimenti falliti (Giganti da 15 metri)", Reward = { XP = 1.2, Gold = 1000000 } },
			{
				Type = "Boss",
				Boss = "Furia",
				Objective = "Ferma Tobias, il Gigante della Furia",
				Reward = { XP = 3, Gold = 2500000 },
			},
			{
				Type = "Talk",
				Npc = "TobiasFortezza",
				Objective = "Parla con Tobias",
				Dialogue = {
					L("Tobias", "Volevo solo... che nessuno dovesse più avere paura delle mura."),
					L("Tobias", "Ma Vael mi ha preceduto. Ha già iniettato il Siero Primordiale. La Grande Marcia è cominciato."),
					L("Tobias", "Vai al fronte. Io ti coprirò le spalle. Un'ultima volta, come al campo di addestramento."),
				},
				Reward = { XP = 2, Gold = 1500000 },
			},
		},
	},
	{
		Id = "S4C4",
		Season = 4,
		Title = "Capitolo 17 - La Grande Marcia",
		Level = 1700,
		Summary = "I Vulcani marciano. Vael è diventato il Gigante Primordiale. È l'ultima battaglia.",
		Steps = {
			{ Type = "Reach", Zone = "FronteMarcia", Objective = "Raggiungi il Fronte della Grande Marcia" },
			{ Type = "Kill", Class = "T15", Zone = "FronteMarcia", Count = 15, Objective = "Elimina 15 Giganti da 15 metri al fronte", Reward = { XP = 1.2, Gold = 2000000 } },
			{ Type = "Kill", Class = "TB", Zone = "FronteMarcia", Count = 5, Objective = "Abbatti 5 Giganti della Grande Marcia", Reward = { XP = 1.5, Gold = 3000000 } },
			{ Type = "Level", Level = 1950, Objective = "Raggiungi il livello 1950" },
			{ Type = "Cutscene", Cutscene = "Primordiale", Objective = "Il Gigante Primordiale" },
			{
				Type = "Boss",
				Boss = "Primordiale",
				Objective = "RAID FINALE: sconfiggi il Gigante Primordiale",
				After = { L("Narratore", "Il Gigante Primordiale crolla. I passi dei Vulcani si fermano, uno dopo l'altro.") },
				Reward = { XP = 4, Gold = 10000000 },
			},
			{
				Type = "Talk",
				Npc = "FalknerFronte",
				Objective = "Parla con il Capitano Falkner",
				Dialogue = {
					L("Falkner", "È finita. Il Primordiale è caduto e i giganti della Grande Marcia si sono fermati."),
					L("Falkner", "Vael voleva riscrivere il mondo con un siero. Noi l'abbiamo cambiato con le nostre scelte."),
					L("Falkner", "Ma i Sieri Perduti sono ancora là fuori. E finché esisteranno, avremo bisogno di te."),
					L("Falkner", "Vola oltre la paura, soldato. Ancora una volta."),
				},
				Reward = { XP = 3, Gold = 5000000, Items = { MedagliaComandante = 1 } },
			},
		},
	},
}

Story.ById = {}
for index, chapter in Story.Chapters do
	chapter.Index = index
	Story.ById[chapter.Id] = chapter
end

function Story.GetStep(chapterIndex: number, stepIndex: number)
	local chapter = Story.Chapters[chapterIndex]
	if not chapter then
		return nil, nil
	end
	return chapter, chapter.Steps[stepIndex]
end

function Story.TotalChapters(): number
	return #Story.Chapters
end

return Story
