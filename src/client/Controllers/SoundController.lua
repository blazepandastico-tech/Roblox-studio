--[[
	SoundController
	Riproduce gli effetti sonori definiti in Shared/Data/Sounds (2D o nel mondo 3D).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared.Data.Sounds)

local SoundController = {}
local C

local function volume(): number
	if C and C.ClientData then
		return C.ClientData.Setting("Sfx", 0.8)
	end
	return 0.8
end

-- where: nil (2D) | Vector3 | BasePart
function SoundController.Play(name: string, where: any, options: { Volume: number?, Pitch: number?, Range: number? }?)
	local def = Sounds[name]
	if not def or def.Id == nil or def.Id == "" then
		return nil
	end
	local opts = options or {}
	local sound = Instance.new("Sound")
	sound.SoundId = def.Id
	sound.Volume = (opts.Volume or def.Volume or 0.5) * volume()
	sound.PlaybackSpeed = (opts.Pitch or def.Pitch or 1) * (1 + (math.random() - 0.5) * 0.08)
	if where == nil then
		sound.Parent = SoundService
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
		sound:Play()
		Debris:AddItem(sound, 8)
		return sound
	end
	local parent: Instance
	if typeof(where) == "Vector3" then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = where
		attachment.Parent = workspace.Terrain
		Debris:AddItem(attachment, 8)
		parent = attachment
	else
		parent = where
	end
	sound.RollOffMaxDistance = opts.Range or 400
	sound.RollOffMinDistance = 10
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 8)
	return sound
end

-- Suono continuo (es. vento durante il volo): restituisce il Sound da gestire
function SoundController.Loop(name: string): Sound?
	local def = Sounds[name]
	if not def or def.Id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = def.Id
	sound.Looped = true
	sound.Volume = 0
	sound.PlaybackSpeed = def.Pitch or 1
	sound.Parent = SoundService
	sound:Play()
	return sound
end

function SoundController.Init(c)
	C = c
end

function SoundController.Start() end

return SoundController
