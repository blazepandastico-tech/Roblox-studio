--[[
	Leveling - curva d'esperienza e ricompense
	La curva è volutamente lunga: arrivare al livello 2000 richiede centinaia di ore.
]]

local Config = require(script.Parent.Parent.Config)

local Leveling = {}

function Leveling.XPToNext(level: number): number
	return math.floor(60 + 25 * level ^ 1.55)
end

-- Una missione al proprio livello vale circa un livello
function Leveling.QuestXP(level: number): number
	return math.floor(Leveling.XPToNext(level) * 0.9 * Config.XPMultiplier)
end

function Leveling.QuestGold(level: number): number
	return math.floor((60 + level * 28) * Config.GoldMultiplier)
end

function Leveling.KillXP(level: number, mult: number): number
	return math.max(1, math.floor(Leveling.XPToNext(level) * 0.05 * mult * Config.XPMultiplier))
end

function Leveling.KillGold(level: number, mult: number): number
	return math.max(1, math.floor((8 + level * 2.2) * mult * Config.GoldMultiplier))
end

-- Aggiunge esperienza al profilo e restituisce quanti livelli sono stati guadagnati
function Leveling.AddXP(profile, amount: number): number
	if profile.Level >= Config.MaxLevel then
		profile.XP = 0
		return 0
	end
	profile.XP += math.floor(amount)
	local gained = 0
	while profile.Level < Config.MaxLevel do
		local need = Leveling.XPToNext(profile.Level)
		if profile.XP < need then
			break
		end
		profile.XP -= need
		profile.Level += 1
		profile.StatPoints += Config.StatPointsPerLevel
		gained += 1
	end
	if profile.Level >= Config.MaxLevel then
		profile.XP = 0
	end
	return gained
end

return Leveling
