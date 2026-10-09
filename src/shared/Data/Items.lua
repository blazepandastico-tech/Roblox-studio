--[[
	Items
	Tutto l'equipaggiamento del gioco (nomi e stemmi originali).
	Per aggiungere un oggetto basta copiare una voce e cambiare Id e valori.
]]

local Items = {}

Items.RarityOrder = { "Comune", "NonComune", "Raro", "Epico", "Leggendario", "Mitico", "Divino" }

Items.Rarities = {
	Comune = { Label = "Comune", Order = 1, Color = Color3.fromRGB(182, 182, 182) },
	NonComune = { Label = "Non Comune", Order = 2, Color = Color3.fromRGB(102, 205, 110) },
	Raro = { Label = "Raro", Order = 3, Color = Color3.fromRGB(72, 146, 255) },
	Epico = { Label = "Epico", Order = 4, Color = Color3.fromRGB(176, 92, 255) },
	Leggendario = { Label = "Leggendario", Order = 5, Color = Color3.fromRGB(255, 192, 64) },
	Mitico = { Label = "Mitico", Order = 6, Color = Color3.fromRGB(255, 74, 74) },
	Divino = { Label = "Divino", Order = 7, Color = Color3.fromRGB(255, 244, 190) },
}

-- Slot equipaggiabili
Items.Slots = { "Blade", "Gear", "Ranged", "Armor", "Accessory" }
Items.SlotNames = {
	Blade = "Lame",
	Gear = "Rampini a Gas",
	Ranged = "Arma a distanza",
	Armor = "Uniforme / Armatura",
	Accessory = "Accessorio",
}

Items.Categories = {
	Lame = { Name = "Lame", Slot = "Blade", Icon = "⚔️" },
	DMT = { Name = "Rampini a Gas", Slot = "Gear", Icon = "⚙️" },
	Distanza = { Name = "Armi a distanza", Slot = "Ranged", Icon = "🎯" },
	Armatura = { Name = "Uniformi e Armature", Slot = "Armor", Icon = "🛡️" },
	Accessorio = { Name = "Accessori", Slot = "Accessory", Icon = "💍" },
	Consumabile = { Name = "Consumabili", Icon = "🧪" },
	Materiale = { Name = "Materiali", Icon = "💎" },
	Chiave = { Name = "Oggetti chiave", Icon = "🗝️" },
}

Items.CategoryOrder = { "Lame", "DMT", "Distanza", "Armatura", "Accessorio", "Consumabile", "Materiale", "Chiave" }

Items.Starter = {
	Blade = "LameAddestramento",
	Gear = "DMTAddestramento",
	Armor = "UniformeCadetto",
}

Items.List = {}

local function add(def)
	assert(Items.List[def.Id] == nil, "Oggetto duplicato: " .. def.Id)
	Items.List[def.Id] = def
end

-- LAME ------------------------------------------------------------------------
-- Damage: danno base | Durability: colpi prima che la lama si spezzi | Spares: coppie di ricambio

add({
	Id = "LameAddestramento",
	Name = "Lame da Addestramento",
	Category = "Lame",
	Rarity = "Comune",
	LevelReq = 1,
	Damage = 12,
	Durability = 25,
	Spares = 4,
	BladeColor = Color3.fromRGB(170, 170, 175),
	TrailColor = Color3.fromRGB(220, 220, 230),
	Description = "Lame smussate in dotazione ai cadetti. Si spezzano facilmente, ma insegnano dove colpire.",
})

add({
	Id = "LameStandard",
	Name = "Lame Standard del Corpo",
	Category = "Lame",
	Rarity = "NonComune",
	LevelReq = 10,
	Price = 2500,
	Damage = 20,
	Durability = 35,
	Spares = 6,
	BladeColor = Color3.fromRGB(196, 200, 206),
	TrailColor = Color3.fromRGB(235, 240, 255),
	Description = "Le lame usate da ogni soldato delle Mura. Affidabili e facili da sostituire.",
})

add({
	Id = "LameTemprato",
	Name = "Lame in Acciaio Temprato",
	Category = "Lame",
	Rarity = "Raro",
	LevelReq = 60,
	Price = 25000,
	Damage = 34,
	Durability = 45,
	Spares = 8,
	BladeColor = Color3.fromRGB(210, 222, 235),
	TrailColor = Color3.fromRGB(150, 210, 255),
	Description = "Forgiate con il raro acciaio temprato delle miniere di Edenia. Tagliano la carne dei giganti come burro.",
})

add({
	Id = "LameVeterano",
	Name = "Lame del Veterano",
	Category = "Lame",
	Rarity = "Epico",
	LevelReq = 180,
	Price = 250000,
	Damage = 55,
	Durability = 55,
	Spares = 8,
	BladeColor = Color3.fromRGB(225, 230, 240),
	TrailColor = Color3.fromRGB(190, 130, 255),
	Description = "Bilanciate a mano per chi è sopravvissuto a più di dieci spedizioni oltre il Muro.",
})

add({
	Id = "LameCapitano",
	Name = "Lame del Capitano",
	Category = "Lame",
	Rarity = "Leggendario",
	LevelReq = 400,
	Price = 1500000,
	Damage = 85,
	Durability = 70,
	Spares = 8,
	BladeColor = Color3.fromRGB(240, 240, 248),
	TrailColor = Color3.fromRGB(255, 205, 90),
	Description = "Impugnatura rovesciata, filo perfetto. Si dice che il loro primo proprietario abbattesse un gigante a ogni battito di ciglia.",
})

add({
	Id = "LameValkar",
	Name = "Lame del Clan Valkar",
	Category = "Lame",
	Rarity = "Mitico",
	LevelReq = 700,
	Damage = 120,
	Durability = 90,
	Spares = 8,
	ValkarBonus = 0.25,
	BladeColor = Color3.fromRGB(60, 60, 70),
	TrailColor = Color3.fromRGB(255, 60, 60),
	Description = "Lame nere tramandate dal clan Valkar. Chi ne porta il sangue ottiene +25% di danno extra.",
})

add({
	Id = "LameCristallo",
	Name = "Lame di Cristallo Indurito",
	Category = "Lame",
	Rarity = "Mitico",
	LevelReq = 1000,
	Damage = 165,
	Durability = 400,
	Spares = 2,
	Glow = true,
	BladeColor = Color3.fromRGB(150, 225, 255),
	TrailColor = Color3.fromRGB(120, 230, 255),
	Description = "Ricavate dal cristallo di un mutaforma. Quasi indistruttibili, brillano di luce azzurra.",
})

add({
	Id = "LameNuovoCorpo",
	Name = "Lame del Nuovo Corpo dei Falchi",
	Category = "Lame",
	Rarity = "Leggendario",
	LevelReq = 1250,
	Price = 9000000,
	Damage = 190,
	Durability = 110,
	Spares = 8,
	BladeColor = Color3.fromRGB(205, 212, 220),
	TrailColor = Color3.fromRGB(100, 255, 200),
	Description = "Lega moderna sviluppata dopo la traversata del mare. Più leggere, più lunghe, più letali.",
})

add({
	Id = "LameAurora",
	Name = "Lame dell'Aurora",
	Category = "Lame",
	Rarity = "Divino",
	LevelReq = 1800,
	Damage = 250,
	Durability = 150,
	Spares = 10,
	Glow = true,
	BladeColor = Color3.fromRGB(255, 250, 225),
	TrailColor = Color3.fromRGB(255, 240, 150),
	Description = "Forgiate con i frammenti del Gigante Primordiale. Ogni colpo lascia una scia di luce dorata.",
})

-- RAMPINI A GAS --------------------------------------------------------------
-- Range: portata dei rampini | Gas: capacità delle bombole | Reel: forza del verricello

add({
	Id = "DMTAddestramento",
	Name = "Rampini da Addestramento",
	Category = "DMT",
	Rarity = "Comune",
	LevelReq = 1,
	Range = 115,
	Gas = 100,
	Reel = 1.0,
	Description = "Il dispositivo con cui ogni cadetto impara a volare (e a cadere).",
})

add({
	Id = "DMTStandard",
	Name = "Rampini Standard",
	Category = "DMT",
	Rarity = "NonComune",
	LevelReq = 15,
	Price = 5000,
	Range = 135,
	Gas = 140,
	Reel = 1.08,
	Description = "Il modello in dotazione a Guarnigione, Polizia e Corpo dei Falchi.",
})

add({
	Id = "DMTAvanzato",
	Name = "Rampini Modello Avanzato",
	Category = "DMT",
	Rarity = "Raro",
	LevelReq = 120,
	Price = 80000,
	Range = 155,
	Gas = 185,
	Reel = 1.16,
	Description = "Bombole più capienti e verricello rinforzato per le spedizioni lunghe.",
})

add({
	Id = "DMTGuarnigione",
	Name = "Rampini della Guarnigione Rinforzato",
	Category = "DMT",
	Rarity = "Epico",
	LevelReq = 300,
	Price = 400000,
	Range = 170,
	Gas = 230,
	Reel = 1.22,
	Description = "Pensato per scalare le Mura in pochi secondi. Cavi lunghi, ganci pesanti.",
})

add({
	Id = "DMTOmbra",
	Name = "Rampini Ombra",
	Category = "DMT",
	Rarity = "Leggendario",
	LevelReq = 550,
	Range = 185,
	Gas = 270,
	Reel = 1.32,
	RangedBonus = 0.15,
	Description = "Il dispositivo della Squadra Ombra: i rampini sono anche armi. +15% danno armi a distanza.",
})

add({
	Id = "DMTNuovoModello",
	Name = "Rampini del Nuovo Corpo dei Falchi",
	Category = "DMT",
	Rarity = "Leggendario",
	LevelReq = 1000,
	Price = 6000000,
	Range = 205,
	Gas = 330,
	Reel = 1.42,
	Description = "Progettato per le Lance Dirompenti: più spinta, più gas, più portata.",
})

add({
	Id = "DMTValkar",
	Name = "Rampini d'Élite Valkar",
	Category = "DMT",
	Rarity = "Mitico",
	LevelReq = 1500,
	Range = 235,
	Gas = 420,
	Reel = 1.6,
	Description = "Un dispositivo che solo un corpo sovrumano può sopportare. Velocità vertiginose.",
})

-- ARMI A DISTANZA ------------------------------------------------------------------
-- Kind: Segnalatore | Lancia (Lancia Dirompente) | Pistola | Fucile | Cannone

add({
	Id = "PistolaSegnalazione",
	Name = "Pistola di Segnalazione",
	Category = "Distanza",
	Rarity = "Comune",
	LevelReq = 5,
	Price = 1500,
	Kind = "Segnalatore",
	Damage = 6,
	Ammo = 3,
	Cooldown = 1.2,
	Range = 260,
	BlindTime = 3,
	ProjectileColor = Color3.fromRGB(255, 70, 50),
	Description = "Pensata per comunicare in formazione. Colpire gli occhi di un gigante lo acceca per qualche secondo.",
})

add({
	Id = "LanciaPrototipo",
	Name = "Lancia Dirompente (Prototipo)",
	Category = "Distanza",
	Rarity = "Raro",
	LevelReq = 250,
	Price = 600000,
	Kind = "Lancia",
	Damage = 140,
	Ammo = 2,
	Cooldown = 1.5,
	Range = 220,
	Radius = 14,
	ProjectileColor = Color3.fromRGB(255, 200, 80),
	Description = "Una lancia esplosiva che si conficca nel bersaglio e detona. Instabile, ma devastante.",
})

add({
	Id = "PistoleOmbra",
	Name = "Pistole Ombra",
	Category = "Distanza",
	Rarity = "Epico",
	LevelReq = 450,
	Price = 1200000,
	Kind = "Pistola",
	Damage = 70,
	Ammo = 2,
	Cooldown = 0.45,
	Range = 150,
	HumanBonus = 1.5,
	ProjectileColor = Color3.fromRGB(255, 240, 200),
	Description = "Due canne montate sulle impugnature dei Rampini. Micidiali contro gli umani, utili contro i giganti.",
})

add({
	Id = "LanciaDirompente",
	Name = "Lancia Dirompente",
	Category = "Distanza",
	Rarity = "Epico",
	LevelReq = 650,
	Price = 3500000,
	Kind = "Lancia",
	Damage = 260,
	Ammo = 4,
	Cooldown = 1.2,
	Range = 240,
	Radius = 18,
	ProjectileColor = Color3.fromRGB(255, 180, 60),
	Description = "La versione definitiva: abbastanza potente da perforare la corazza di un mutaforma.",
})

add({
	Id = "FucileValdoriano",
	Name = "Fucile Valdoriano",
	Category = "Distanza",
	Rarity = "Raro",
	LevelReq = 1000,
	Price = 2000000,
	Kind = "Fucile",
	Damage = 180,
	Ammo = 5,
	Cooldown = 0.9,
	Range = 320,
	HumanBonus = 1.6,
	ProjectileColor = Color3.fromRGB(255, 230, 160),
	Description = "Il fucile a otturatore dell'esercito di Valdoria. Preciso a lunga distanza.",
})

add({
	Id = "LanciaTempesta",
	Name = "Lancia Dirompente 'Tempesta'",
	Category = "Distanza",
	Rarity = "Leggendario",
	LevelReq = 1300,
	Price = 12000000,
	Kind = "Lancia",
	Damage = 420,
	Ammo = 6,
	Cooldown = 1.0,
	Range = 260,
	Radius = 22,
	Chain = true,
	ProjectileColor = Color3.fromRGB(120, 220, 255),
	Description = "Ogni esplosione innesca una seconda detonazione a catena.",
})

add({
	Id = "CannoneAntigigante",
	Name = "Cannone Portatile Anti-Gigante",
	Category = "Distanza",
	Rarity = "Mitico",
	LevelReq = 1700,
	Kind = "Cannone",
	Damage = 900,
	Ammo = 1,
	Cooldown = 4,
	Range = 300,
	Radius = 32,
	ProjectileColor = Color3.fromRGB(255, 120, 40),
	Description = "Un pezzo d'artiglieria da muro ridotto per stare su una spalla. Un colpo, un cratere.",
})

-- UNIFORMI E ARMATURE -------------------------------------------------------------
-- HealthBonus / Defense / GasEfficiency ecc. sono percentuali (0.1 = 10%)

add({
	Id = "UniformeCadetto",
	Name = "Uniforme da Cadetto",
	Category = "Armatura",
	Rarity = "Comune",
	LevelReq = 1,
	Style = "Cadetto",
	JacketColor = Color3.fromRGB(150, 110, 70),
	Description = "Giacca corta, cinghie di cuoio e tanta speranza.",
})

add({
	Id = "UniformeGuarnigione",
	Name = "Uniforme della Guarnigione",
	Category = "Armatura",
	Rarity = "NonComune",
	LevelReq = 30,
	Price = 12000,
	Style = "Guarnigione",
	Emblem = "Torre",
	HealthBonus = 0.08,
	Defense = 0.03,
	JacketColor = Color3.fromRGB(140, 100, 62),
	Description = "Lo stemma delle rose rosse: chi la indossa difende le Mura.",
})

add({
	Id = "UniformeFalchi",
	Name = "Uniforme del Corpo dei Falchi",
	Category = "Armatura",
	Rarity = "Raro",
	LevelReq = 80,
	Price = 60000,
	Style = "Falchi",
	Emblem = "Falco",
	Cloak = true,
	CloakColor = Color3.fromRGB(46, 92, 58),
	HealthBonus = 0.12,
	Defense = 0.04,
	GasEfficiency = 0.10,
	JacketColor = Color3.fromRGB(135, 95, 58),
	Description = "Le Ali del Falco sulla schiena. Il mantello verde nasconde dai giganti durante le spedizioni.",
})

add({
	Id = "UniformePolizia",
	Name = "Uniforme della Gendarmeria Reale",
	Category = "Armatura",
	Rarity = "Epico",
	LevelReq = 400,
	Price = 1000000,
	Style = "Polizia",
	Emblem = "Corona",
	Cloak = true,
	CloakColor = Color3.fromRGB(40, 78, 52),
	HealthBonus = 0.15,
	Defense = 0.06,
	GoldBonus = 0.2,
	JacketColor = Color3.fromRGB(128, 92, 60),
	Description = "Il privilegio dei migliori dieci cadetti. +20% oro guadagnato.",
})

add({
	Id = "ArmaturaValdoriana",
	Name = "Armatura Valdoriana",
	Category = "Armatura",
	Rarity = "Epico",
	LevelReq = 1000,
	Price = 3000000,
	Style = "Valdoria",
	Emblem = "Valdoria",
	HealthBonus = 0.18,
	Defense = 0.12,
	ExplosiveResist = 0.3,
	JacketColor = Color3.fromRGB(88, 96, 66),
	Description = "Uniforme da trincea con piastre di metallo. Resiste alle esplosioni.",
})

add({
	Id = "UniformeNuovoCorpo",
	Name = "Uniforme del Nuovo Corpo dei Falchi",
	Category = "Armatura",
	Rarity = "Leggendario",
	LevelReq = 1100,
	Price = 8000000,
	Style = "NuovoCorpo",
	Emblem = "Falco",
	HealthBonus = 0.25,
	Defense = 0.1,
	GasEfficiency = 0.15,
	RangedDamage = 0.1,
	JacketColor = Color3.fromRGB(28, 28, 32),
	Description = "La tuta nera degli anni della guerra, con imbracatura per Lance Dirompenti.",
})

add({
	Id = "MantelloFalco",
	Name = "Mantello del Falco",
	Category = "Armatura",
	Rarity = "Mitico",
	LevelReq = 1500,
	Style = "Falchi",
	Emblem = "Falco",
	Cloak = true,
	CloakColor = Color3.fromRGB(30, 70, 45),
	CloakTrim = Color3.fromRGB(230, 190, 90),
	HealthBonus = 0.35,
	Defense = 0.12,
	AllDamage = 0.1,
	JacketColor = Color3.fromRGB(110, 76, 45),
	Description = "Il mantello di chi ha giurato di volare oltre la paura fino all'ultimo respiro. +10% a tutti i danni.",
})

add({
	Id = "ArmaturaCristallo",
	Name = "Armatura di Cristallo Indurito",
	Category = "Armatura",
	Rarity = "Mitico",
	LevelReq = 1800,
	Style = "Cristallo",
	HealthBonus = 0.3,
	Defense = 0.3,
	JacketColor = Color3.fromRGB(170, 225, 245),
	Description = "Placche di cristallo di mutaforma fuse sull'uniforme. Quasi impenetrabile.",
})

-- Ricompensa esclusiva dell'evento Grande Inaugurazione (completa tutte le sfide)
add({
	Id = "MantelloInaugurazione",
	Name = "Mantello dell'Inaugurazione",
	Category = "Armatura",
	Rarity = "Leggendario",
	LevelReq = 1,
	Style = "Falchi",
	Emblem = "Falco",
	Cloak = true,
	CloakColor = Color3.fromRGB(196, 148, 40),
	CloakTrim = Color3.fromRGB(250, 240, 210),
	HealthBonus = 0.12,
	Defense = 0.04,
	XPBonus = 0.05,
	JacketColor = Color3.fromRGB(40, 44, 66),
	Description = "Esclusivo della Grande Inaugurazione: lo indossano solo i primi soldati dell'Arcipelago. +5% esperienza.",
})

-- ACCESSORI ------------------------------------------------------------------------

add({
	Id = "MedagliaInaugurazione",
	Name = "Medaglia dell'Inaugurazione",
	Category = "Accessorio",
	Rarity = "Epico",
	LevelReq = 1,
	XPBonus = 0.05,
	GoldBonus = 0.05,
	Description = "Il regalo per chi c'era alla Grande Inaugurazione. +5% esperienza e oro.",
})

add({
	Id = "DistintivoPrimiDieci",
	Name = "Distintivo dei Primi Dieci",
	Category = "Accessorio",
	Rarity = "Raro",
	LevelReq = 10,
	AllDamage = 0.05,
	Description = "Consegnato ai migliori cadetti del corso. +5% a tutti i danni.",
})

add({
	Id = "SciarpaRossa",
	Name = "Sciarpa Rossa",
	Category = "Accessorio",
	Rarity = "Leggendario",
	LevelReq = 150,
	CritChance = 0.1,
	BladeDamage = 0.05,
	Visual = "Sciarpa",
	Description = "Un dono che non si dimentica. +10% probabilità di critico, +5% danno con le lame.",
})

add({
	Id = "OcchialiRicercatrice",
	Name = "Occhiali della Ricercatrice",
	Category = "Accessorio",
	Rarity = "Epico",
	LevelReq = 250,
	FragmentChance = 0.15,
	Visual = "Occhiali",
	Description = "Gli occhiali di riserva della Dott.ssa Morrow. +15% probabilità di trovare Frammenti di Siero.",
})

add({
	Id = "AnelloHoshimura",
	Name = "Sigillo degli Hoshimura",
	Category = "Accessorio",
	Rarity = "Epico",
	LevelReq = 600,
	Price = 2500000,
	GasEfficiency = 0.12,
	Description = "Il sigillo della famiglia che inventò il gas dei Rampini. +12% efficienza del gas.",
})

add({
	Id = "ChiaveSeminterrato",
	Name = "Chiave del Seminterrato",
	Category = "Accessorio",
	Rarity = "Epico",
	LevelReq = 750,
	XPBonus = 0.1,
	Visual = "Chiave",
	Description = "La chiave che apre la verità. +10% esperienza.",
})

add({
	Id = "FasciaGuerriero",
	Name = "Fascia del Guerriero Valdoriano",
	Category = "Accessorio",
	Rarity = "Leggendario",
	LevelReq = 1000,
	TitanPower = 0.15,
	TitanEnergy = 0.1,
	Visual = "Fascia",
	Description = "La fascia al braccio dei candidati Guerrieri. +15% potere del gigante, +10% energia.",
})

add({
	Id = "MedagliaComandante",
	Name = "Medaglia del Comandante",
	Category = "Accessorio",
	Rarity = "Mitico",
	LevelReq = 1800,
	XPBonus = 0.1,
	GoldBonus = 0.1,
	AllDamage = 0.05,
	Description = "Per chi ha fermato la Grande Marcia. +10% esperienza, +10% oro, +5% danni.",
})

-- Accessori cosmetici (negozio delle gemme e pass VIP)
add({
	Id = "MantelloCremisi",
	Name = "Mantello Cremisi",
	Category = "Accessorio",
	Rarity = "Leggendario",
	LevelReq = 1,
	GoldBonus = 0.05,
	Visual = "Mantello",
	CloakColor = Color3.fromRGB(150, 26, 30),
	CloakTrim = Color3.fromRGB(230, 190, 90),
	Premium = true,
	Description = "Rosso come il fuoco delle braci. Cosmetico del negozio delle gemme: +5% oro.",
})

add({
	Id = "MantelloNotte",
	Name = "Mantello della Notte",
	Category = "Accessorio",
	Rarity = "Leggendario",
	LevelReq = 1,
	XPBonus = 0.05,
	Visual = "Mantello",
	CloakColor = Color3.fromRGB(24, 32, 70),
	CloakTrim = Color3.fromRGB(170, 190, 255),
	Premium = true,
	Description = "Blu come il cielo prima dell'alba. Cosmetico del negozio delle gemme: +5% esperienza.",
})

add({
	Id = "MantelloVIP",
	Name = "Mantello Reale VIP",
	Category = "Accessorio",
	Rarity = "Divino",
	LevelReq = 1,
	GoldBonus = 0.05,
	XPBonus = 0.05,
	Visual = "Mantello",
	CloakColor = Color3.fromRGB(236, 196, 80),
	CloakTrim = Color3.fromRGB(255, 255, 255),
	Emblem = "Corona",
	Premium = true,
	Description = "Il mantello dorato dei membri VIP dell'Arcipelago. +5% oro ed esperienza.",
})

-- CONSUMABILI -------------------------------------------------------------------------

add({
	Id = "Razione",
	Name = "Razione da Campo",
	Category = "Consumabile",
	Rarity = "Comune",
	Price = 250,
	Effect = "Heal",
	Amount = 0.35,
	Description = "Pane secco e carne salata. Ripristina il 35% della salute.",
})

add({
	Id = "BombolaGas",
	Name = "Bombola di Gas",
	Category = "Consumabile",
	Rarity = "Comune",
	Price = 400,
	Effect = "RefillGas",
	Description = "Riempie completamente le bombole dei Rampini.",
})

add({
	Id = "KitLame",
	Name = "Kit di Lame di Ricambio",
	Category = "Consumabile",
	Rarity = "Comune",
	Price = 600,
	Effect = "RefillBlades",
	Description = "Ripristina tutte le lame e le munizioni.",
})

add({
	Id = "FialaAdrenalina",
	Name = "Fiala di Adrenalina",
	Category = "Consumabile",
	Rarity = "Epico",
	Effect = "DamageBuff",
	Amount = 0.5,
	Duration = 30,
	Description = "+50% danni per 30 secondi.",
})

add({
	Id = "PergamenaEsperienza",
	Name = "Pergamena dell'Esperienza",
	Category = "Consumabile",
	Rarity = "Raro",
	Effect = "XPBuff",
	Amount = 1,
	Duration = 900,
	Description = "Esperienza doppia per 15 minuti.",
})

add({
	Id = "PozioneOro",
	Name = "Pozione dell'Oro",
	Category = "Consumabile",
	Rarity = "Epico",
	Effect = "GoldBuff",
	Duration = 1800,
	Description = "Oro doppio per 30 minuti.",
})

add({
	Id = "PergamenaAntenati",
	Name = "Pergamena degli Antenati",
	Category = "Consumabile",
	Rarity = "Mitico",
	Effect = "RerollBloodline",
	Description = "Risveglia un'altra stirpe nel tuo sangue (cambia la tua Stirpe a caso).",
})

-- MATERIALI ----------------------------------------------------------------------------

add({
	Id = "FrammentoSiero",
	Name = "Frammento di Siero",
	Category = "Materiale",
	Rarity = "Mitico",
	Description = "Una goccia cristallizzata di siero. Con abbastanza frammenti il Laboratorio può sintetizzare un Siero Perduto.",
})

add({
	Id = "CristalloIndurito",
	Name = "Cristallo Indurito",
	Category = "Materiale",
	Rarity = "Epico",
	Description = "Il cristallo prodotto dai mutaforma. Durissimo e luminoso.",
})

add({
	Id = "MidolloGigante",
	Name = "Midollo di Gigante",
	Category = "Materiale",
	Rarity = "Raro",
	Description = "Raccolto prima che il corpo del gigante evapori. Usato per forgiare armi d'élite.",
})

add({
	Id = "PolvereValdoriana",
	Name = "Polvere da Sparo Valdoriana",
	Category = "Materiale",
	Rarity = "Raro",
	Description = "Esplosivo di qualità militare. Indispensabile per le armi pesanti.",
})

-- OGGETTI CHIAVE ------------------------------------------------------------------------

add({
	Id = "FialaSpezzata",
	Name = "Fiala Spezzata",
	Category = "Chiave",
	Rarity = "Leggendario",
	Description = "Trovata tra le macerie di Halvar il giorno della caduta. Porta un simbolo sconosciuto.",
})

add({
	Id = "BombolaNebbia",
	Name = "Bombola di Nebbia",
	Category = "Chiave",
	Rarity = "Raro",
	Description = "Una bombola vuota che odora di siero. Trovata nel villaggio di Brenn.",
})

add({
	Id = "SigilloRaid",
	Name = "Sigillo del Raid",
	Category = "Chiave",
	Rarity = "Epico",
	Description = "Un sigillo di bronzo con un tridente inciso. Consegnalo al Maestro dei Raid per avviare un raid senza pagare oro.",
})

-- Funzioni di aiuto ----------------------------------------------------------------------

function Items.Get(id: string?)
	if not id then
		return nil
	end
	return Items.List[id]
end

function Items.SlotOf(id: string?): string?
	local def = Items.Get(id)
	if not def then
		return nil
	end
	local category = Items.Categories[def.Category]
	return category and category.Slot
end

function Items.RarityColor(rarity: string?): Color3
	local r = Items.Rarities[rarity or "Comune"] or Items.Rarities.Comune
	return r.Color
end

function Items.IsEquipment(id: string?): boolean
	return Items.SlotOf(id) ~= nil
end

-- Elenco ordinato per categoria, rarità e livello
function Items.Sorted(filter: ((any) -> boolean)?): { any }
	local list = {}
	for _, def in Items.List do
		if not filter or filter(def) then
			table.insert(list, def)
		end
	end
	local catIndex = {}
	for i, c in Items.CategoryOrder do
		catIndex[c] = i
	end
	table.sort(list, function(a, b)
		local ca, cb = catIndex[a.Category] or 99, catIndex[b.Category] or 99
		if ca ~= cb then
			return ca < cb
		end
		local la, lb = a.LevelReq or 0, b.LevelReq or 0
		if la ~= lb then
			return la < lb
		end
		return a.Name < b.Name
	end)
	return list
end

return Items
