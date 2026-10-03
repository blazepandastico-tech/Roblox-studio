--[[
	Enemies - nemici umani (Stagione 3 e 4)
	Poliziotti corrotti, Squadra Ombra, soldati di Valdoria e guardie di Vael.
]]

local Enemies = {}

Enemies.Types = {
	PoliziaCorrotta = {
		Id = "PoliziaCorrotta",
		Name = "Poliziotto Corrotto",
		Uniform = "Polizia",
		Weapon = "Fucile",
		HPMult = 1.0,
		DmgMult = 1.0,
		Range = 85,
		FireRate = 1.7,
		Speed = 16,
		XP = 1.1,
		Gold = 1.2,
		Drops = { { Id = "Razione", Chance = 0.05, Min = 1, Max = 1 } },
	},
	SquadraOmbra = {
		Id = "SquadraOmbra",
		Name = "Agente Ombra",
		Uniform = "Ombra",
		Weapon = "Pistole",
		HPMult = 1.2,
		DmgMult = 1.15,
		Range = 60,
		FireRate = 1.1,
		Speed = 20,
		ODMHop = true,
		XP = 1.3,
		Gold = 1.3,
		Drops = { { Id = "BombolaGas", Chance = 0.06, Min = 1, Max = 1 } },
	},
	SoldatoValdoriano = {
		Id = "SoldatoValdoriano",
		Name = "Soldato Valdoriano",
		Uniform = "Valdoria",
		Weapon = "Fucile",
		HPMult = 1.1,
		DmgMult = 1.1,
		Range = 110,
		FireRate = 1.5,
		Speed = 16,
		XP = 1.2,
		Gold = 1.25,
		Drops = { { Id = "PolvereValdoriana", Chance = 0.08, Min = 1, Max = 2 } },
	},
	GuardiaVael = {
		Id = "GuardiaVael",
		Name = "Guardia di Vael",
		Uniform = "Vael",
		Weapon = "Lancia",
		HPMult = 1.5,
		DmgMult = 1.3,
		Range = 90,
		FireRate = 2.4,
		Speed = 18,
		ODMHop = true,
		Explosive = true,
		XP = 1.5,
		Gold = 1.5,
		Drops = {
			{ Id = "PolvereValdoriana", Chance = 0.1, Min = 1, Max = 2 },
			{ Id = "FrammentoSiero", Chance = 0.006, Min = 1, Max = 1 },
		},
	},
}

-- Boss umani
Enemies.Bosses = {
	Corvo = {
		Id = "Corvo",
		Type = "SquadraOmbra",
		Name = "Il Corvo Nero",
		Title = "Capitano della Squadra Ombra",
		Zone = "CittaSotterranea",
		Level = 650,
		HPMult = 32,
		DmgMult = 2.2,
		FireRate = 0.55,
		Burst = 5,
		Speed = 26,
		Respawn = 600,
		XPMult = 30,
		GoldMult = 25,
		Fragments = { 4, 9 },
		Drops = {
			{ Id = "DMTOmbra", Chance = 0.08, Min = 1, Max = 1 },
			{ Id = "PistoleOmbra", Chance = 0.05, Min = 1, Max = 1 },
			{ Id = "MidolloGigante", Chance = 0.8, Min = 2, Max = 5 },
		},
	},
}

function Enemies.HP(level: number, mult: number): number
	return math.floor(60 * mult * (1 + (level - 1) * 0.05))
end

function Enemies.Damage(level: number, mult: number): number
	return 9 * mult * (1 + (level - 1) * 0.06)
end

return Enemies
