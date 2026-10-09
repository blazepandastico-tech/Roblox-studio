-- Ciclo di partita: intervallo -> calcio d'inizio -> partita -> goal/reset -> fine -> lobby.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))
local Stamina = require(script.Parent.Stamina)
local Ball = require(script.Parent.Ball)
local Lobby = require(script.Parent.Lobby)
local MapBuilder = require(script.Parent.MapBuilder)

local M = Config.Match
local F = Config.Field

local Match = {}

local phase = "Intermission"
local participants = nil -- [plr] = { team = "Red"/"Blue", slot = n }
local scores = { Red = 0, Blue = 0 }
local BALL_START = Vector3.new(0, Config.Ball.Diameter / 2 + 0.3, 0)

local function setPhase(name, duration)
	phase = name
	workspace:SetAttribute("PhaseEnd", duration and (workspace:GetServerTimeNow() + duration) or 0)
	workspace:SetAttribute("Phase", name)
end

local function setScores()
	workspace:SetAttribute("ScoreRed", scores.Red)
	workspace:SetAttribute("ScoreBlue", scores.Blue)
end

function Match.IsPlaying()
	return phase == "Playing"
end

function Match.GetPhase()
	return phase
end

local function inMatch(plr)
	return participants ~= nil and participants[plr] ~= nil and (phase == "Kickoff" or phase == "Playing" or phase == "Goal")
end

local function kickoffCFrame(info)
	local slot = F.KickoffSlots[math.min(info.slot, #F.KickoffSlots)]
	local sx = (info.team == "Red") and -1 or 1
	local pos = Vector3.new(sx * slot.x, 4, slot.z)
	return CFrame.lookAt(pos, pos + Vector3.new(-sx, 0, 0))
end

local function addStats(plr)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, n in ipairs({ "Goals", "Assists", "Contrasti", "Colpi" }) do
		local v = Instance.new("IntValue")
		v.Name = n
		v.Value = 0
		v.Parent = stats
	end
	stats.Parent = plr
end

local function stat(plr, name, delta)
	local stats = plr:FindFirstChild("leaderstats")
	local v = stats and stats:FindFirstChild(name)
	if v then
		v.Value = v.Value + delta
	end
end

local function resetStats()
	for _, plr in ipairs(Players:GetPlayers()) do
		local stats = plr:FindFirstChild("leaderstats")
		if stats then
			for _, v in ipairs(stats:GetChildren()) do
				v.Value = 0
			end
		end
	end
end

----------------------------------------------------------------------
-- Spawn / posizionamento
----------------------------------------------------------------------
function Match.Spawn(plr)
	task.spawn(function()
		if not plr.Parent then
			return
		end
		plr:LoadCharacter()
		local char = plr.Character
		if not char then
			return
		end
		local hrp = char:WaitForChild("HumanoidRootPart", 8)
		local hum = char:WaitForChild("Humanoid", 8)
		if not hrp or not hum then
			return
		end
		if hum.RigType ~= Enum.HumanoidRigType.R15 then
			warn("[Calcio Fuorilegge] Il personaggio non e' R15: imposta Game Settings > Avatar > R15.")
		end
		hum.UseJumpPower = true
		hum.JumpPower = Config.Move.JumpPower
		hum.WalkSpeed = Config.Move.WalkSpeed
		if inMatch(plr) then
			char:PivotTo(kickoffCFrame(participants[plr]))
			if phase == "Kickoff" then
				char:SetAttribute("SpeedMult", 0)
			end
		else
			char:PivotTo(MapBuilder.LobbySpawnCFrame())
		end
		hum.Died:Connect(function()
			task.wait(2.5)
			if plr.Parent then
				Match.Spawn(plr)
			end
		end)
	end)
end

local function placeAll(freeze)
	for plr, info in pairs(participants) do
		if plr.Parent then
			Stamina.Refill(plr)
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not char or not hum or hum.Health <= 0 or char:GetAttribute("Ragdolled") then
				Match.Spawn(plr)
			else
				char:PivotTo(kickoffCFrame(info))
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp then
					hrp.AssemblyLinearVelocity = Vector3.zero
				end
				char:SetAttribute("Sliding", nil)
				char:SetAttribute("SpeedMult", freeze and 0 or nil)
			end
		end
	end
end

local function unfreeze()
	for plr in pairs(participants) do
		local char = plr.Character
		if char then
			char:SetAttribute("SpeedMult", nil)
		end
	end
end

local function anyParticipants()
	if not participants then
		return false
	end
	for plr in pairs(participants) do
		if plr.Parent then
			return true
		end
	end
	return false
end

function Match.Leave(plr)
	if participants and participants[plr] then
		participants[plr] = nil
	end
	plr.Team = nil
	Match.Spawn(plr)
end

----------------------------------------------------------------------
-- Eventi di gioco
----------------------------------------------------------------------
local function handleGoal(team)
	scores[team] = scores[team] + 1
	setScores()
	local scorer, assist, atime = Ball.GetScorers()
	local scorerName, assistName, own = "", "", false
	if scorer and scorer.Parent then
		scorerName = scorer.DisplayName
		if Lobby.TeamKey(scorer) == team then
			stat(scorer, "Goals", 1)
			if assist and assist ~= scorer and assist.Parent and os.clock() - atime < 8 then
				assistName = assist.DisplayName
				stat(assist, "Assists", 1)
			end
		else
			own = true
		end
	end
	Net.Get("GoalScored"):FireAllClients(team, scorerName, assistName, own)
end

local function runMatch()
	Lobby.AutoAssignAll()
	participants = {}
	local slots = { Red = 0, Blue = 0 }
	for _, plr in ipairs(Players:GetPlayers()) do
		local key = Lobby.TeamKey(plr)
		if key then
			slots[key] = slots[key] + 1
			participants[plr] = { team = key, slot = slots[key] }
		end
	end
	if not anyParticipants() then
		participants = nil
		return
	end

	scores.Red, scores.Blue = 0, 0
	setScores()
	resetStats()
	Ball.SetActive(false)
	Ball.Reset(BALL_START)
	workspace:SetAttribute("TimeLeft", M.Duration)

	-- calcio d'inizio
	setPhase("Kickoff", M.KickoffCountdown)
	placeAll(true)
	task.wait(M.KickoffCountdown)

	local remaining = M.Duration
	while remaining > 0 and anyParticipants() do
		unfreeze()
		Ball.Release()
		Ball.SetActive(true)
		workspace:SetAttribute("TimeLeft", remaining)
		setPhase("Playing", remaining)
		local segStart = os.clock()
		local scored = nil
		while true do
			RunService.Heartbeat:Wait()
			local elapsed = os.clock() - segStart
			if elapsed >= remaining then
				remaining = 0
				break
			end
			if Ball.OutOfBounds() then
				Ball.Reset(BALL_START)
				Ball.Release()
			end
			local team = Ball.CheckGoal()
			if team then
				scored = team
				remaining = remaining - elapsed
				break
			end
			if not anyParticipants() then
				break
			end
		end

		if scored then
			workspace:SetAttribute("TimeLeft", remaining)
			Ball.SetActive(false)
			setPhase("Goal", M.GoalCelebration)
			handleGoal(scored)
			task.wait(M.GoalCelebration)
			if remaining > 0 and anyParticipants() then
				Ball.Reset(BALL_START)
				setPhase("Kickoff", M.ResumeCountdown)
				placeAll(true)
				task.wait(M.ResumeCountdown)
			end
		end
	end

	-- fine partita
	Ball.SetActive(false)
	local result
	if scores.Red > scores.Blue then
		result = "Vincono i " .. Config.Teams.Red.Name .. "!  " .. scores.Red .. " - " .. scores.Blue
	elseif scores.Blue > scores.Red then
		result = "Vincono i " .. Config.Teams.Blue.Name .. "!  " .. scores.Blue .. " - " .. scores.Red
	else
		result = "Pareggio!  " .. scores.Red .. " - " .. scores.Blue
	end
	workspace:SetAttribute("ResultText", result)
	setPhase("Ended", M.EndScreen)
	task.wait(M.EndScreen)

	local old = participants
	participants = nil
	Lobby.ClearTeams()
	for plr in pairs(old) do
		if plr.Parent then
			Match.Spawn(plr)
		end
	end
	Ball.Reset(BALL_START)
end

function Match.Run()
	while true do
		scores.Red, scores.Blue = 0, 0
		setScores()
		workspace:SetAttribute("TimeLeft", M.Duration)
		workspace:SetAttribute("ResultText", "")
		setPhase("Intermission", M.Intermission)
		task.wait(M.Intermission)
		if #Players:GetPlayers() >= M.MinPlayers then
			local ok, err = pcall(runMatch)
			if not ok then
				warn("[Match] errore nel ciclo partita: " .. tostring(err))
				participants = nil
				Ball.SetActive(false)
			end
		end
	end
end

function Match.OnPlayerAdded(plr)
	local ok, err = pcall(function()
		addStats(plr)
		Stamina.Init(plr)
	end)
	if not ok then
		warn("[Match] preparazione del giocatore non riuscita: " .. tostring(err))
	end
	-- il personaggio compare comunque
	Match.Spawn(plr)
end

Players.PlayerRemoving:Connect(function(plr)
	if participants then
		participants[plr] = nil
	end
end)

return Match
