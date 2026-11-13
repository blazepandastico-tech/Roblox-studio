--[[
	EggClientEffects (example LocalScript, move it to StarterPlayer.StarterPlayerScripts)
	Starts the client-side mutation effects (the animated Rainbow mutation).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local pack = ReplicatedStorage:WaitForChild("StudVoxEggs")
local EggMutations = require(pack:WaitForChild("EggMutations"))

EggMutations.StartClientEffects()
