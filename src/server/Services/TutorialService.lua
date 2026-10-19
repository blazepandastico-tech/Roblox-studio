--[[
	TutorialService
	L'Addestramento di base (vedi Data/Tutorial): parte dopo il prologo, al posto del passo della
	storia "Presentati all'Istruttore Brehm", e finché non è finito quel passo aspetta.
	Il client guida i passi (sono comandi da provare) e comunica a che punto è, così chi esce a metà
	riprende da lì. Alla fine (o se lo salta) la storia riparte con Brehm. Il premio si riceve una
	volta sola e solo completandolo davvero. Dal menu si può rivedere quando si vuole (senza premio).
	Chi aveva già superato quel punto della storia non lo vede (giocatori di prima del tutorial).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Lib.Net)
local Tutorial = require(Shared.Data.Tutorial)
local Leveling = require(Shared.Data.Leveling)

local TutorialService = {}
local S

type Session = { Started: number, Replay: boolean, Reached: number, From: number }
local sessions: { [Player]: Session } = {}

local function data(profile)
	profile.Tutorial = profile.Tutorial or { Done = false, Step = 1, Rewarded = false }
	return profile.Tutorial
end

-- la storia è ferma sul passo che il tutorial sostituisce?
local function atGate(profile): boolean
	local story = profile.Story
	return story ~= nil and not story.Done and story.Chapter == Tutorial.StoryChapter and story.Step == Tutorial.StoryStep
end

-- true finché il tutorial deve ancora essere fatto (la storia aspetta)
function TutorialService.Pending(player: Player): boolean
	local profile = S.DataService.Get(player)
	return profile ~= nil and not data(profile).Done and atGate(profile)
end

local function send(player: Player, step: number, replay: boolean)
	sessions[player] = { Started = os.clock(), Replay = replay, Reached = step, From = step }
	Net.Event("Tutorial"):FireClient(player, { Step = step, Replay = replay, Total = #Tutorial.Steps })
end

-- Chiamata dalla storia quando arriva al passo del tutorial (o quando il giocatore rientra):
-- se il tutorial va fatto lo fa partire e restituisce true (la storia aspetta)
function TutorialService.Gate(player: Player): boolean
	local profile = S.DataService.Get(player)
	if not profile or not TutorialService.Pending(player) then
		return false
	end
	local t = data(profile)
	send(player, math.clamp(t.Step or 1, 1, #Tutorial.Steps + 1), false)
	return true
end

local function finish(player: Player, completed: boolean)
	local profile = S.DataService.Get(player)
	local session = sessions[player]
	sessions[player] = nil
	if not profile then
		return
	end
	local t = data(profile)
	if session and session.Replay then
		if completed then
			S.EventService.Notify(player, "Addestramento ripassato. Vola oltre la paura!", "Successo", 4)
		end
		return
	end
	if t.Done then
		return
	end
	t.Done = true
	t.Step = #Tutorial.Steps + 1
	-- premio solo a chi l'ha fatto davvero: tutti i passi e (partendo da capo) un minimo di tempo
	local honest = session ~= nil and session.Reached > #Tutorial.Steps and (session.From > 1 or os.clock() - session.Started >= Tutorial.MinSeconds)
	if completed and honest and not t.Rewarded then
		t.Rewarded = true
		local reward = Tutorial.Reward
		S.PlayerService.GiveRewards(player, {
			XP = if reward.XP then Leveling.QuestXP(math.max(1, profile.Level)) * reward.XP else 0,
			Gold = reward.Gold,
			Items = reward.Items,
		}, Tutorial.Title)
	end
	S.DataService.MarkDirty(player)
	-- ora la storia riparte: "Presentati all'Istruttore Brehm"
	if S.StoryService then
		S.StoryService.RestartStep(player)
	end
end

function TutorialService.Init(services)
	S = services
end

function TutorialService.Start()
	-- chi aveva già superato quel punto della storia (o è già cresciuto) non deve rifarlo
	S.DataService.OnLoaded(function(player, profile)
		local t = data(profile)
		local story = profile.Story
		local past = story.Done or story.Chapter > Tutorial.StoryChapter or (story.Chapter == Tutorial.StoryChapter and story.Step > Tutorial.StoryStep)
		if not t.Done and (past or profile.Level > 3) then
			t.Done = true
			S.DataService.MarkDirty(player)
		end
	end)
	-- a che passo è arrivato il client (per riprendere da lì): avanti di uno alla volta
	Net.Event("TutorialProgress").OnServerEvent:Connect(function(player, step)
		local session = sessions[player]
		local profile = S.DataService.Get(player)
		if not session or not profile or type(step) ~= "number" or step ~= step then
			return
		end
		step = math.floor(step)
		if step == session.Reached + 1 and step <= #Tutorial.Steps + 1 then
			session.Reached = step
			local t = data(profile)
			if not session.Replay and not t.Done then
				t.Step = step
				S.DataService.MarkDirty(player)
			end
		end
	end)
	Net.Event("TutorialDone").OnServerEvent:Connect(function(player, how)
		if sessions[player] and (how == "complete" or how == "skip") then
			finish(player, how == "complete")
		end
	end)
	-- rivedi il tutorial dal menu (senza premio e senza toccare la storia)
	Net.Event("TutorialReplay").OnServerEvent:Connect(function(player)
		local profile = S.DataService.Get(player)
		if profile and not sessions[player] and data(profile).Done then
			send(player, 1, true)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
end

-- comandi di prova: rifà il tutorial da capo (come la prima volta)
function TutorialService.Reset(player: Player)
	local profile = S.DataService.Get(player)
	if not profile then
		return
	end
	local t = data(profile)
	t.Done = false
	t.Step = 1
	profile.Story.Chapter = Tutorial.StoryChapter
	profile.Story.Step = Tutorial.StoryStep
	profile.Story.Progress = 0
	profile.Story.Done = false
	S.DataService.MarkDirty(player)
	sessions[player] = nil
	TutorialService.Gate(player)
end

return TutorialService
