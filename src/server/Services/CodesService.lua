--[[
	CodesService
	Codici promozionali (come in Blox Fruits). Aggiungine di nuovi qui sotto!
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Lib.Net)

local CodesService = {}
local S

-- Nome del codice (maiuscolo) -> ricompense
local CODES = {
	SIERIPERDUTI = { Gold = 5000, Gems = 25, Items = { PergamenaEsperienza = 1 } },
	ARCIPELAGO = { Gold = 10000, Gems = 25 },
	CORPODEIFALCHI = { Items = { Razione = 5, BombolaGas = 3, KitLame = 2 } },
	BENVENUTORECLUTA = { Gold = 2500, Gems = 10, Items = { Razione = 3 } },
	OLTREILMARE = { Items = { PergamenaEsperienza = 2 } },
	PRIMORAID = { Gems = 40, Items = { SigilloRaid = 1 } },
}
local function redeem(player: Player, code: any): (boolean, string)
	if type(code) ~= "string" or #code > 40 then
		return false, "Codice non valido."
	end
	local key = code:upper():gsub("%s", "")
	local reward = CODES[key]
	local profile = S.DataService.Get(player)
	if not reward or not profile then
		return false, "Codice non valido o scaduto."
	end
	if profile.Codes[key] then
		return false, "Hai già usato questo codice."
	end
	profile.Codes[key] = true
	S.PlayerService.GiveRewards(player, reward, "Codice " .. key)
	if reward.Gems and S.MonetizationService then
		S.MonetizationService.AddGems(player, reward.Gems, "codice")
	end
	S.DataService.MarkDirty(player)
	return true, "Codice riscattato!"
end

function CodesService.Init(services)
	S = services
end

function CodesService.Start()
	Net.Function("RedeemCode").OnServerInvoke = function(player, code)
		local ok, message = redeem(player, code)
		return ok, message
	end
end

return CodesService
