-- Punto d'ingresso del server di Calcio Fuorilegge.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Net"))
local Server = script.Parent:WaitForChild("Server")
local MapBuilder = require(Server:WaitForChild("MapBuilder"))
local Stamina = require(Server:WaitForChild("Stamina"))
local Ball = require(Server:WaitForChild("Ball"))
local Actions = require(Server:WaitForChild("Actions"))
local Lobby = require(Server:WaitForChild("Lobby"))
local Match = require(Server:WaitForChild("Match"))

Players.CharacterAutoLoads = false

MapBuilder.Build()
Lobby.Init()
Ball.Create()
Actions.Init(Match.IsPlaying)

Net.Get("JoinQueue").OnServerEvent:Connect(function(plr)
	if Match.GetPhase() == "Intermission" then
		Lobby.AutoAssign(plr)
		Net.Get("Notify"):FireClient(plr, "Sei nella lista: la partita sta per iniziare!")
	end
end)

Net.Get("ReturnLobby").OnServerEvent:Connect(function(plr)
	Match.Leave(plr)
end)

RunService.Heartbeat:Connect(function(dt)
	Stamina.Step(dt)
	Ball.Step(dt)
end)

Players.PlayerAdded:Connect(Match.OnPlayerAdded)
for _, plr in ipairs(Players:GetPlayers()) do
	task.spawn(Match.OnPlayerAdded, plr)
end

task.spawn(Match.Run)
