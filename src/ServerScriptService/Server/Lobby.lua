-- Squadre (servizio Teams), pedane della lobby e assegnazione automatica.
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))

local Lobby = {}

local teamObjects = {}

function Lobby.Init()
	for key, t in pairs(Config.Teams) do
		local team = Teams:FindFirstChild(t.Name)
		if not team then
			team = Instance.new("Team")
			team.Name = t.Name
			team.Parent = Teams
		end
		team.TeamColor = BrickColor.new(t.BrickColor)
		team.AutoAssignable = false
		teamObjects[key] = team
	end

	local pads = workspace:WaitForChild("World"):WaitForChild("Lobby"):WaitForChild("Pads")
	local debounce = {}
	for _, pad in ipairs(pads:GetChildren()) do
		local key = pad:GetAttribute("TeamKey")
		if key then
			pad.Touched:Connect(function(other)
				local plr = Players:GetPlayerFromCharacter(other.Parent)
				if not plr then
					return
				end
				local now = os.clock()
				if debounce[plr] and now - debounce[plr] < 1 then
					return
				end
				debounce[plr] = now
				Lobby.JoinTeam(plr, key, true)
			end)
		end
	end
	Players.PlayerRemoving:Connect(function(plr)
		debounce[plr] = nil
	end)
end

function Lobby.Count(key)
	local n = 0
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Team == teamObjects[key] then
			n = n + 1
		end
	end
	return n
end

function Lobby.TeamKey(plr)
	for key, team in pairs(teamObjects) do
		if plr.Team == team then
			return key
		end
	end
	return nil
end

function Lobby.JoinTeam(plr, key, announce)
	if plr.Team == teamObjects[key] then
		return true
	end
	if Lobby.Count(key) >= Config.Match.MaxPerTeam then
		if announce then
			Net.Get("Notify"):FireClient(plr, "Squadra " .. Config.Teams[key].Name .. " al completo!")
		end
		return false
	end
	plr.Team = teamObjects[key]
	if announce then
		Net.Get("Notify"):FireClient(plr, "Sei nella squadra " .. Config.Teams[key].Name)
	end
	return true
end

-- Mette in squadra chi non l'ha scelta, bilanciando i numeri.
function Lobby.AutoAssign(plr)
	if Lobby.TeamKey(plr) then
		return
	end
	local r, b = Lobby.Count("Red"), Lobby.Count("Blue")
	local first, second = "Red", "Blue"
	if b < r then
		first, second = "Blue", "Red"
	end
	if not Lobby.JoinTeam(plr, first, false) then
		Lobby.JoinTeam(plr, second, false)
	end
end

function Lobby.AutoAssignAll()
	for _, plr in ipairs(Players:GetPlayers()) do
		Lobby.AutoAssign(plr)
	end
end

function Lobby.ClearTeams()
	for _, plr in ipairs(Players:GetPlayers()) do
		plr.Team = nil
	end
end

return Lobby
