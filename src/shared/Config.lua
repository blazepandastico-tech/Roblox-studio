--[[
	Config
	Tutti i numeri "regolabili" del gioco in un unico posto.
	Vuoi un gioco più facile o più difficile? Inizia da qui.
]]

local Config = {
	GameName = "Sieri Perduti: L'Arcipelago dei Giganti",
	ShortName = "SIERI PERDUTI",
	Version = "1.0.0",

	-- Salvataggi (cambia il nome per azzerare tutti i progressi)
	DataStoreName = "SieriPerduti_Dati_v1",
	AutosaveInterval = 120,

	-- Generazione del mondo (stesso seme = stessa mappa)
	WorldSeed = 312,

	-- Progressione
	MaxLevel = 2000,
	StatPointsPerLevel = 3,
	StatCap = 2000,
	XPMultiplier = 1,
	GoldMultiplier = 1,
	StartGold = 250,
	StatResetCost = 25000, -- oro per livello del giocatore

	Player = {
		BaseHealth = 100,
		HealthPerLevel = 6,
		HealthPerVitality = 18,
		WalkSpeed = 20,
		JumpHeight = 8,
		RespawnDelay = 5,
		BaseCritChance = 0.05,
		CritMultiplier = 1.5,
		MaxDefense = 0.6,
	},

	-- Rampini a Gas
	ODM = {
		GasDrainReel = 4.5, -- gas al secondo per ogni rampino che tira
		GasDrainBoost = 15, -- gas al secondo con lo scatto (Spazio)
		GasPerHook = 1.5,
		GasPerDodge = 6,
		GasRegenGround = 2.5, -- rigenerazione lenta a terra (0 = realistico)
		ReelAcceleration = 170,
		BoostAcceleration = 125,
		SteerAcceleration = 60,
		AirSteer = 26,
		AntiGravity = 0.55, -- quanta gravità "sorreggono" i cavi
		Drag = 0.12,
		MaxSpeed = 180,
		HookSpeed = 950,
		MinAttachDistance = 7,
		DodgeSpeed = 95,
		DodgeCooldown = 0.9,
		DodgeIFrames = 0.3,
		LandingRollSpeed = 85,
	},

	Combat = {
		ComboStepTime = 0.3,
		ComboResetTime = 0.9,
		BladeReach = 13,
		MinAttackInterval = 0.2,
		HitValidationSlack = 14,
		MaxHitsPerSwing = 4,
		SpeedBonusStart = 40, -- velocità oltre cui il danno aumenta
		SpeedBonusFull = 160,
		SpeedBonusMax = 1.5, -- +150% di danno alla massima velocità
		NapePerfectSpeed = 70, -- "Taglio Perfetto" sulla nuca
		NapePerfectMult = 2.5,
		BodyDamageShare = 0.2, -- i colpi fuori dalla nuca fanno solo il 20%
		BrokenBladeMult = 0.1,
		ReloadTime = 0.8,
		KillShareMin = 0.1, -- per ricevere la ricompensa serve almeno il 10% del danno
	},

	Titans = {
		ActivationRadius = 560,
		ThinkInterval = 0.1,
		NightSpeedMult = 0.45, -- di notte i giganti rallentano
		NightAggroMult = 0.5,
		CorpseTime = 7,
		LimbRegenTime = 14,
		BlindTime = 6,
		GrabEscapePresses = 12,
		GrabHoldTime = 2.6,
		EatDamagePct = 0.7,
		AggroBase = 140,
		LeashMultiplier = 1.7,
		NapeHPBase = 40,
		NapeHPPerLevel = 0.045,
		DamageBase = 14,
		DamagePerLevel = 0.06,
	},

	Serums = {
		-- I poteri dei giganti arrivano con il PROSSIMO AGGIORNAMENTO: metti true per attivarli
		Available = false,
		ComingSoonText = "I poteri dei giganti arriveranno con il prossimo aggiornamento!",
		WorldSpawnInterval = 2700, -- ogni 45 minuti si tenta di far apparire un siero
		WorldSpawnChance = 0.35,
		WorldSpawnDuration = 1200,
		DealerRotation = 14400, -- il Mercante cambia merce ogni 4 ore
		FragmentChanceNormal = 0.004,
		FragmentChanceAbnormal = 0.015,
		TransformCooldown = 30,
		MinEnergyToTransform = 0.25,
		MaxMastery = 600,
	},

	Bloodline = {
		RerollCost = 1500000,
	},

	World = {
		DayLength = 1200, -- secondi reali per un giorno di gioco
		NightStart = 19,
		NightEnd = 6,
	},

	Events = {
		InvasionInterval = 1800,
		InvasionDuration = 300,
	},

	-- Nomi condivisi tra server e client (non cambiarli se non sai cosa fai)
	Folders = {
		Map = "Mappa",
		Titans = "Titani",
		Enemies = "Nemici",
		NPCs = "PNG",
		Interactive = "Interattivi",
		Effects = "Effetti",
	},
	Tags = {
		Titan = "Titano",
		Enemy = "Nemico",
		NPC = "PNG",
		Supply = "Rifornimento",
		SerumChest = "CassaSiero",
		Pickup = "Raccoglibile",
		Spinner = "Rotante",
		Lamp = "Lampione",
	},
	CollisionGroups = {
		Players = "Giocatori",
		TitanForm = "FormaGigante",
		Buildings = "Edifici",
		NPC = "PNG",
		Debris = "Detriti",
	},
}

return Config
