--[[
	Bloodlines - Le Stirpi
	Assegnata a caso al primo accesso (come le "razze" di Blox Fruits).
	Si può cambiare con la Pergamena degli Antenati o pagando il Genealogista.
]]

local Bloodlines = {}

Bloodlines.Order = { "Isolano", "Esule", "Hoshimura", "Valkar", "StirpeReale" }

Bloodlines.List = {
	Isolano = {
		Id = "Isolano",
		Name = "Isolano",
		Weight = 45,
		Color = Color3.fromRGB(210, 190, 150),
		Description = "Nato dentro le Mura. Tenace e adattabile.",
		Bonuses = { HealthBonus = 0.05, XPBonus = 0.05 },
	},
	Esule = {
		Id = "Esule",
		Name = "Esule d'Oltremare",
		Weight = 25,
		Color = Color3.fromRGB(200, 120, 90),
		Description = "Cresciuto oltre il mare per diventare un Guerriero. Il potere dei giganti scorre forte in te.",
		Bonuses = { TitanPower = 0.15, TitanEnergy = 0.1 },
	},
	Hoshimura = {
		Id = "Hoshimura",
		Name = "Hoshimura",
		Weight = 15,
		Color = Color3.fromRGB(120, 180, 230),
		Description = "Discendente della casata che inventò il gas dei Rampini.",
		Bonuses = { GasEfficiency = 0.2, GoldBonus = 0.1 },
	},
	Valkar = {
		Id = "Valkar",
		Name = "Valkar",
		Weight = 10,
		Color = Color3.fromRGB(230, 70, 70),
		Description = "Un corpo plasmato per combattere. Dal livello 500 sblocchi il Risveglio (tasto G).",
		Bonuses = { BladeDamage = 0.2, ODMSpeed = 0.12 },
		Awakening = {
			Level = 500,
			Duration = 15,
			Cooldown = 120,
			DamageMult = 1.5,
			SpeedMult = 1.3,
		},
	},
	StirpeReale = {
		Id = "StirpeReale",
		Name = "Stirpe Reale",
		Weight = 5,
		Color = Color3.fromRGB(255, 220, 120),
		Description = "Il sangue degli antichi re delle isole. +25% potere del gigante, maestria dei sieri sempre al massimo e nessuno stordimento dagli urli.",
		Bonuses = { TitanPower = 0.25 },
		FullMastery = true,
		StunImmune = true,
	},
}

function Bloodlines.Get(id: string?)
	return Bloodlines.List[id or "Isolano"] or Bloodlines.List.Isolano
end

function Bloodlines.Roll(rng: Random?, exclude: string?): string
	local random = rng or Random.new()
	local total = 0
	for _, id in Bloodlines.Order do
		if id ~= exclude then
			total += Bloodlines.List[id].Weight
		end
	end
	local roll = random:NextNumber() * total
	for _, id in Bloodlines.Order do
		if id ~= exclude then
			roll -= Bloodlines.List[id].Weight
			if roll <= 0 then
				return id
			end
		end
	end
	return "Isolano"
end

return Bloodlines
