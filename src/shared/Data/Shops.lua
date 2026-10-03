--[[
	Shops - negozi e ricette del Laboratorio
]]

local Serums = require(script.Parent.Serums)

local Shops = {}

Shops.List = {
	ArmeriaCampo = {
		Name = "Armeria del Campo",
		Items = { "LameStandard", "DMTStandard", "PistolaSegnalazione", "UniformeGuarnigione" },
	},
	ArmeriaQG = {
		Name = "Armeria del Corpo dei Falchi",
		Items = { "LameStandard", "LameTemprato", "DMTStandard", "DMTAvanzato", "PistolaSegnalazione", "UniformeGuarnigione", "UniformeFalchi" },
	},
	ArmeriaAurion = {
		Name = "Armeria Reale di Aurion",
		Items = { "LameVeterano", "LameCapitano", "DMTGuarnigione", "LanciaPrototipo", "PistoleOmbra", "LanciaDirompente", "UniformePolizia", "AnelloHoshimura" },
	},
	ArmeriaRevelia = {
		Name = "Armeria Valdoriana",
		Items = { "FucileValdoriano", "LameNuovoCorpo", "DMTNuovoModello", "LanciaTempesta", "ArmaturaValdoriana", "UniformeNuovoCorpo" },
	},
	Emporio = {
		Name = "Emporio",
		Items = { "Razione", "BombolaGas", "KitLame" },
	},
}

-- Ricette del Laboratorio della Dott.ssa Morrow
local recipes = {
	{ Id = "R_Adrenalina", Result = "FialaAdrenalina", LevelReq = 50, Gold = 50000, Materials = { MidolloGigante = 5 } },
	{ Id = "R_Pergamena", Result = "PergamenaAntenati", LevelReq = 300, Gold = 500000, Materials = { FrammentoSiero = 40, CristalloIndurito = 10 } },
	{ Id = "R_DMTOmbra", Result = "DMTOmbra", LevelReq = 550, Gold = 2000000, Materials = { MidolloGigante = 25 } },
	{ Id = "R_LameValkar", Result = "LameValkar", LevelReq = 700, Gold = 3000000, Materials = { MidolloGigante = 40, CristalloIndurito = 5 } },
	{ Id = "R_LameCristallo", Result = "LameCristallo", LevelReq = 1000, Gold = 8000000, Materials = { CristalloIndurito = 30, FrammentoSiero = 10 } },
	{ Id = "R_DMTValkar", Result = "DMTValkar", LevelReq = 1500, Gold = 15000000, Materials = { CristalloIndurito = 25, MidolloGigante = 80 } },
	{ Id = "R_MantelloFalco", Result = "MantelloFalco", LevelReq = 1500, Gold = 25000000, Materials = { FrammentoSiero = 30, CristalloIndurito = 30 } },
	{ Id = "R_Cannone", Result = "CannoneAntigigante", LevelReq = 1700, Gold = 20000000, Materials = { PolvereValdoriana = 60, CristalloIndurito = 20 } },
	{ Id = "R_LameAurora", Result = "LameAurora", LevelReq = 1800, Gold = 40000000, Materials = { CristalloIndurito = 60, FrammentoSiero = 50, MidolloGigante = 120 } },
	{ Id = "R_ArmaturaCristallo", Result = "ArmaturaCristallo", LevelReq = 1800, Gold = 30000000, Materials = { CristalloIndurito = 80 } },
}

-- Sintesi dei sieri: centinaia di Frammenti di Siero
for _, serumId in Serums.Order do
	local serum = Serums.List[serumId]
	table.insert(recipes, {
		Id = "R_" .. serumId,
		Result = serumId,
		Serum = true,
		LevelReq = serum.LevelReq,
		Gold = serum.CraftGold,
		Materials = { FrammentoSiero = serum.Fragments },
	})
end

Shops.Recipes = recipes
Shops.RecipeById = {}
for _, recipe in recipes do
	Shops.RecipeById[recipe.Id] = recipe
end

return Shops
