-- Crea (server) e recupera (client) tutti i RemoteEvent del gioco.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NAMES = {
	"Kick", -- client -> server: (kind, charge, aimDir, curve)
	"Tackle", -- (dir)
	"Dash", -- (dir)
	"Control", -- (bool) controllo stretto palla
	"Sprint", -- (bool)
	"CallBall",
	"ReturnLobby",
	"JoinQueue",
	"GoalScored", -- server -> client: (teamKey, scorerName, assistName, ownGoal)
	"Notify", -- server -> client: (text)
}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(NAMES) do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Net = {}

function Net.Get(name)
	return folder:WaitForChild(name)
end

return Net
