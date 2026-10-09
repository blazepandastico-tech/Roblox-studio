--[[
	Sieri Perduti: L'Arcipelago dei Giganti - avvio del server
	Carica tutti i servizi, chiama Init() su ognuno e poi Start().
	Se un servizio va in errore gli altri continuano a funzionare.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.CharacterAutoLoads = false

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Lib.Net)
Net.Init()

local ServicesFolder = script.Parent:WaitForChild("Services")

-- Ordine di avvio (il mondo va costruito prima di far entrare i giocatori)
local ORDER = {
	"DataService",
	"WorldBuilder",
	"LightingService",
	"EventService",
	"PlayerService",
	"InventoryService",
	"TitanService",
	"EnemyService",
	"CombatService",
	"ODMService",
	"QuestService",
	"StoryService",
	"TutorialService",
	"SerumService",
	"ShifterService",
	"ShopService",
	"MonetizationService",
	"RaidService",
	"NPCService",
	"SupplyService",
	"SeaService",
	"ExploreService",
	"HorseService",
	"PvPService",
	"FestivalService",
	"AbuseService",
	"CodesService",
	"RewardsService",
	"CommunityService",
	"AchievementService",
	"LeaderboardService",
	"AdminService",
	"DevCommandsService",
}

local Services = {}

for _, name in ORDER do
	local module = ServicesFolder:FindFirstChild(name)
	if module then
		local ok, result = pcall(require, module)
		if ok then
			Services[name] = result
		else
			warn(("[Sieri Perduti] Errore nel caricare %s: %s"):format(name, tostring(result)))
		end
	else
		warn("[Sieri Perduti] Servizio mancante: " .. name)
	end
end

for _, name in ORDER do
	local service = Services[name]
	if service and service.Init then
		local ok, err = pcall(service.Init, Services)
		if not ok then
			warn(("[Sieri Perduti] Errore in %s.Init: %s"):format(name, tostring(err)))
		end
	end
end

for _, name in ORDER do
	local service = Services[name]
	if service and service.Start then
		task.spawn(function()
			local ok, err = xpcall(service.Start, debug.traceback)
			if not ok then
				warn(("[Sieri Perduti] Errore in %s.Start: %s"):format(name, tostring(err)))
			end
		end)
	end
end

print("[Sieri Perduti] Server avviato. Volate oltre la paura!")
