-- Punto d'ingresso del server di Calcio Fuorilegge.
print("[Calcio Fuorilegge] server avviato")
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

-- Ogni passo di avvio e' protetto: se uno fallisce, l'errore compare nell'Output come avviso e gli altri partono lo stesso.
local function step(name, fn, ...)
	local ok, err = xpcall(fn, function(e)
		return debug.traceback(tostring(e), 2)
	end, ...)
	if not ok then
		warn("[Calcio Fuorilegge] " .. name .. " non riuscito:\n" .. tostring(err))
	end
	return ok
end

step("mappa", MapBuilder.Build)
step("lobby", Lobby.Init)
step("palla", Ball.Create)
step("azioni", Actions.Init, Match.IsPlaying)

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

-- Da qui il personaggio lo carica Match (lobby -> campo). Questa riga e' volutamente l'ultima prima dei giocatori: se lo script
-- si fosse fermato prima, il caricamento automatico resterebbe acceso e il personaggio comparirebbe lo stesso nella lobby.
Players.CharacterAutoLoads = false
Players.PlayerAdded:Connect(Match.OnPlayerAdded)
for _, plr in ipairs(Players:GetPlayers()) do
	task.spawn(Match.OnPlayerAdded, plr)
end

task.spawn(Match.Run)
