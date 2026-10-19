--[[
	ExploreController - forzieri nascosti
	I forzieri che hai già aperto diventano trasparenti e non si possono più aprire
	(ognuno lo vede a modo suo: ogni giocatore ha i suoi forzieri trovati).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local ExploreController = {}
local C

local function apply(model: Instance, opened: { [string]: any })
	if not model:IsA("Model") then
		return
	end
	local id = model:GetAttribute("TreasureId")
	local isOpen = id ~= nil and opened[id] ~= nil
	if model:GetAttribute("Aperto") == isOpen then
		return
	end
	model:SetAttribute("Aperto", isOpen)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = if isOpen then 0.7 else 0
		elseif d:IsA("ProximityPrompt") then
			d.Enabled = not isOpen
		elseif d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			d.Enabled = not isOpen
		end
	end
end

local function refreshAll()
	local profile = C.ClientData.Profile
	local opened = (profile and profile.Treasures) or {}
	for _, model in CollectionService:GetTagged(Config.Tags.Treasure) do
		apply(model, opened)
	end
end

function ExploreController.Init(c)
	C = c
end

function ExploreController.Start()
	C.ClientData.Changed:Connect(refreshAll)
	CollectionService:GetInstanceAddedSignal(Config.Tags.Treasure):Connect(function(model)
		task.defer(function()
			local profile = C.ClientData.Profile
			apply(model, (profile and profile.Treasures) or {})
		end)
	end)
	refreshAll()
end

return ExploreController
