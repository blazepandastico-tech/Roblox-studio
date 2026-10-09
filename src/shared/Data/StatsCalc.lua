--[[
	StatsCalc - calcola le statistiche finali del giocatore
	(statistiche base + equipaggiamento + stirpe + maestria).
	Lo usano sia il server (valori ufficiali) sia il client (per mostrarli nei menu).
]]

local Config = require(script.Parent.Parent.Config)
local Items = require(script.Parent.Items)
local Bloodlines = require(script.Parent.Bloodlines)
local Monetization = require(script.Parent.Monetization)

local StatsCalc = {}

StatsCalc.StatNames = { "Forza", "Vitalita", "Agilita", "Mira", "Gigante" }

StatsCalc.StatInfo = {
	Forza = { Name = "Forza", Icon = "⚔️", Description = "Aumenta il danno delle lame." },
	Vitalita = { Name = "Vitalità", Icon = "❤️", Description = "Aumenta la salute massima e un po' la difesa." },
	Agilita = { Name = "Agilità", Icon = "💨", Description = "Più velocità, gas e potenza dei Rampini." },
	Mira = { Name = "Mira", Icon = "🎯", Description = "Aumenta il danno di Lance Dirompenti e armi da fuoco." },
	Gigante = { Name = "Potere del Gigante", Icon = "💉", Description = "Aumenta danni ed energia della forma di gigante." },
}

local BONUS_KEYS = {
	"HealthBonus",
	"Defense",
	"GasEfficiency",
	"GoldBonus",
	"XPBonus",
	"AllDamage",
	"BladeDamage",
	"RangedDamage",
	"CritChance",
	"TitanPower",
	"TitanEnergy",
	"FragmentChance",
	"DropLuck",
	"ODMSpeed",
	"ExplosiveResist",
}

function StatsCalc.Bonuses(profile)
	local bonuses = {}
	for _, key in BONUS_KEYS do
		bonuses[key] = 0
	end
	local equipped = profile.Equipped or {}
	for _, slot in Items.Slots do
		local def = Items.Get(equipped[slot])
		if def then
			for _, key in BONUS_KEYS do
				local value = def[key]
				if type(value) == "number" then
					bonuses[key] += value
				end
			end
			if def.RangedBonus then
				bonuses.RangedDamage += def.RangedBonus
			end
		end
	end
	local bloodline = Bloodlines.Get(profile.Bloodline)
	for key, value in bloodline.Bonuses do
		if bonuses[key] ~= nil then
			bonuses[key] += value
		end
	end
	-- bonus dei Game Pass posseduti
	for key, value in Monetization.PassBonuses(profile.Passes) do
		if bonuses[key] ~= nil then
			bonuses[key] += value
		end
	end
	local blade = Items.Get(equipped.Blade)
	if blade and blade.ValkarBonus and profile.Bloodline == "Valkar" then
		bonuses.BladeDamage += blade.ValkarBonus
	end
	return bonuses
end

function StatsCalc.MasteryMult(mastery: number?): number
	return 1 + math.clamp(mastery or 0, 0, Config.Serums.MaxMastery) * 0.0005
end

function StatsCalc.Compute(profile)
	local stats = profile.Stats or {}
	local forza = stats.Forza or 0
	local vit = stats.Vitalita or 0
	local agi = stats.Agilita or 0
	local mira = stats.Mira or 0
	local gig = stats.Gigante or 0
	local level = profile.Level or 1
	local equipped = profile.Equipped or {}
	local b = StatsCalc.Bonuses(profile)
	local P = Config.Player

	local result = {}
	result.Bonuses = b
	result.MaxHealth = math.floor((P.BaseHealth + P.HealthPerLevel * level + P.HealthPerVitality * vit) * (1 + b.HealthBonus))
	result.Defense = math.min(P.MaxDefense, b.Defense + vit * 0.00005)
	result.CritChance = math.min(0.75, P.BaseCritChance + b.CritChance)
	result.ExplosiveResist = math.min(0.8, b.ExplosiveResist)

	-- Lame
	local blade = Items.Get(equipped.Blade)
	if blade then
		local mastery = profile.WeaponMastery and profile.WeaponMastery[blade.Id] or 0
		result.BladeId = blade.Id
		result.BladeDamage = blade.Damage * (1 + forza * 0.0055) * (1 + b.BladeDamage + b.AllDamage) * StatsCalc.MasteryMult(mastery)
		result.BladeDurability = blade.Durability
		result.BladeSpares = blade.Spares
		result.BladeMastery = mastery
	else
		result.BladeDamage = 3 * (1 + forza * 0.0055)
		result.BladeDurability = 0
		result.BladeSpares = 0
		result.BladeMastery = 0
	end

	-- Arma a distanza
	local ranged = Items.Get(equipped.Ranged)
	if ranged then
		result.RangedId = ranged.Id
		result.RangedDamage = ranged.Damage * (1 + mira * 0.0055) * (1 + b.RangedDamage + b.AllDamage)
		result.RangedAmmo = ranged.Ammo
	else
		result.RangedDamage = 0
		result.RangedAmmo = 0
	end

	-- Rampini
	local gear = Items.Get(equipped.Gear)
	if gear then
		result.ODMRange = gear.Range
		result.ODMGas = math.floor(gear.Gas * (1 + agi * 0.0002))
		result.ODMReel = gear.Reel * (1 + agi * 0.00025) * (1 + b.ODMSpeed)
	else
		result.ODMRange = 0
		result.ODMGas = 0
		result.ODMReel = 0
	end
	result.GasEfficiency = 1 + b.GasEfficiency + agi * 0.0001
	result.WalkSpeed = P.WalkSpeed + math.min(8, agi * 0.004)

	-- Potere del gigante
	result.TitanPower = (1 + gig * 0.006) * (1 + b.TitanPower + b.AllDamage)
	result.TitanEnergyMult = (1 + gig * 0.0004) * (1 + b.TitanEnergy)

	result.XPBonus = b.XPBonus
	result.GoldBonus = b.GoldBonus
	result.FragmentChance = b.FragmentChance
	result.DropLuck = b.DropLuck
	return result
end

return StatsCalc
