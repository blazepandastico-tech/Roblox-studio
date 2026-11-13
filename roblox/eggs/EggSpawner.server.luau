--[[
	EggSpawner (example server Script, move it to ServerScriptService)

	Spawns StudVox eggs on spawn pads, the way egg-stealing games do:
	  * every Part tagged "EggSpawn" (CollectionService) is a pad; give it a
	    string attribute "Biome" = a biome id from EggConfig (e.g. "meadow")
	  * when a pad is empty it waits SPAWN_DELAY seconds, rolls an egg of that
	    biome by rarity chance, rolls its weight (kg) and a mutation, scales the
	    model to its weight and puts a billboard above it
	  * the egg carries its data as attributes: EggId, WeightKg, Mutation, Income

	Expected setup:
	  ReplicatedStorage.StudVoxEggs (the EggPack.rbxmx folder) with
	    Eggs/<biome>/<egg model>, EggConfig, EggMutations, EggBillboard
	  Clients call EggMutations.StartClientEffects() once (for rainbow eggs).

	Picking up, carrying (see EggConfig.CarrySpeedMultiplier), stealing and
	hatching (EggConfig.HatchSeconds / Income) belong to your game logic.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local pack = ReplicatedStorage:WaitForChild("StudVoxEggs")
local EggConfig = require(pack:WaitForChild("EggConfig"))
local EggMutations = require(pack:WaitForChild("EggMutations"))
local EggBillboard = require(pack:WaitForChild("EggBillboard"))

local SPAWN_DELAY = 20
local rng = Random.new()
local busy: { [BasePart]: Model } = {}

local function spawnOn(pad: BasePart)
	local biome = pad:GetAttribute("Biome")
	if typeof(biome) ~= "string" or EggConfig.BiomeById[biome] == nil then
		warn(`EggSpawner: {pad:GetFullName()} needs a valid "Biome" attribute`)
		return
	end
	local eggId = EggConfig.RollEgg(biome, rng)
	local template = pack.Eggs:FindFirstChild(biome) and pack.Eggs[biome]:FindFirstChild(eggId)
	if template == nil then
		warn(`EggSpawner: no model for {eggId}`)
		return
	end
	local weight = EggConfig.RollWeight(eggId, rng)
	local mutation = EggConfig.RollMutation(rng)
	local egg = template:Clone() :: Model
	egg:ScaleTo(EggConfig.ScaleForWeight(eggId, weight))
	egg:PivotTo(pad.CFrame * CFrame.new(0, pad.Size.Y / 2, 0))
	egg:SetAttribute("EggId", eggId)
	egg:SetAttribute("WeightKg", weight)
	egg:SetAttribute("Mutation", mutation)
	egg:SetAttribute("Income", EggConfig.Income(eggId, weight, mutation))
	EggMutations.Apply(egg, mutation)
	EggBillboard.Attach(egg, eggId, weight, mutation)
	egg.Parent = workspace
	busy[pad] = egg
	egg.AncestryChanged:Connect(function()
		if not egg:IsDescendantOf(workspace) and busy[pad] == egg then
			busy[pad] = nil -- picked up or removed: the pad can spawn again
		end
	end)
end

local function watch(pad: Instance)
	if not pad:IsA("BasePart") then
		return
	end
	task.spawn(function()
		while pad.Parent do
			if busy[pad] == nil then
				task.wait(SPAWN_DELAY)
				if pad.Parent and busy[pad] == nil then
					spawnOn(pad)
				end
			end
			task.wait(1)
		end
		busy[pad] = nil
	end)
end

for _, pad in CollectionService:GetTagged("EggSpawn") do
	watch(pad)
end
CollectionService:GetInstanceAddedSignal("EggSpawn"):Connect(watch)
