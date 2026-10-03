--[[
	SupplyService
	Depositi di Rifornimento (gas, lame, munizioni, un po' di salute)
	e montacarichi per salire sulle Mura.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Lib.Net)

local SupplyService = {}
local S
local lastRefill: { [Player]: number } = {}

local function connectSupply(part: Instance)
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	prompt.Triggered:Connect(function(player)
		local now = os.clock()
		if now - (lastRefill[player] or 0) < 2 then
			return
		end
		lastRefill[player] = now
		S.PlayerService.RefillWeapons(player)
		S.PlayerService.Heal(player, 0.25)
		Net.Event("Refilled"):FireClient(player, "Tutto")
		S.EventService.Notify(player, "Gas, lame e munizioni ricaricati!", "Successo", 2.5)
	end)
end

local function connectLift(part: Instance)
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	local target = part:GetAttribute("LiftTarget")
	if not prompt or typeof(target) ~= "Vector3" then
		return
	end
	prompt.Triggered:Connect(function(player)
		S.EventService.EffectTo(player, "Fade", { Time = 0.5 })
		task.wait(0.3)
		S.PlayerService.Teleport(player, target)
	end)
end

function SupplyService.Init(services)
	S = services
end

function SupplyService.Start()
	S.WorldBuilder.WaitReady()
	for _, part in CollectionService:GetTagged(Config.Tags.Supply) do
		connectSupply(part)
	end
	CollectionService:GetInstanceAddedSignal(Config.Tags.Supply):Connect(connectSupply)
	for _, part in CollectionService:GetTagged("Montacarichi") do
		connectLift(part)
	end
	CollectionService:GetInstanceAddedSignal("Montacarichi"):Connect(connectLift)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastRefill[player] = nil
	end)
end

return SupplyService
