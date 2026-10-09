--[[
	QuestService
	Missioni ripetibili (una alla volta), stile Blox Fruits.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Lib.Net)
local Quests = require(Shared.Data.Quests)
local Leveling = require(Shared.Data.Leveling)

local QuestService = {}
local S

function QuestService.Active(player: Player)
	local profile = S.DataService.Get(player)
	if not profile or profile.Quest.Id == "" then
		return nil, profile
	end
	return Quests.Get(profile.Quest.Id), profile
end

function QuestService.Accept(player: Player, questId: string): (boolean, string?)
	local quest = Quests.Get(questId)
	local profile = S.DataService.Get(player)
	if not quest or not profile then
		return false, "Missione sconosciuta."
	end
	if profile.Level < quest.LevelReq then
		return false, ("Serve il livello %d per questa missione."):format(quest.LevelReq)
	end
	profile.Quest.Id = questId
	profile.Quest.Progress = 0
	S.DataService.MarkDirty(player)
	S.EventService.Notify(player, "Missione accettata: " .. quest.Name, "Info", 3)
	return true, nil
end

function QuestService.Abandon(player: Player)
	local profile = S.DataService.Get(player)
	if not profile or profile.Quest.Id == "" then
		return
	end
	profile.Quest.Id = ""
	profile.Quest.Progress = 0
	S.DataService.MarkDirty(player)
	S.EventService.Notify(player, "Missione abbandonata.", "Info", 2)
end

local function complete(player: Player, quest, profile)
	profile.Quest.Id = ""
	profile.Quest.Progress = 0
	local xp, gold = Quests.Rewards(quest, Leveling)
	S.PlayerService.GiveRewards(player, { XP = xp, Gold = gold }, "Missione completata")
	S.EventService.AnnounceTo(player, "MISSIONE COMPLETATA", quest.Name, "Successo")
	S.DataService.MarkDirty(player)
end

local function progress(player: Player, matches: (any) -> boolean)
	local quest, profile = QuestService.Active(player)
	if not quest or not profile then
		return
	end
	if not matches(quest.Target) then
		return
	end
	profile.Quest.Progress += 1
	if profile.Quest.Progress >= quest.Count then
		complete(player, quest, profile)
	else
		S.DataService.MarkDirty(player)
	end
end

function QuestService.OnTitanKilled(player: Player, t)
	progress(player, function(target)
		if target.Kind == "Titan" then
			return t.ClassId == target.Class and t.Zone == target.Zone and t.Kind ~= "Boss"
		elseif target.Kind == "Boss" then
			return t.BossId == target.Boss
		end
		return false
	end)
end

function QuestService.OnEnemyKilled(player: Player, e)
	progress(player, function(target)
		if target.Kind == "Enemy" then
			return e.TypeId == target.Type and e.Zone == target.Zone and not e.Boss
		elseif target.Kind == "HumanBoss" then
			return e.BossId == target.Boss
		end
		return false
	end)
end

function QuestService.Init(services)
	S = services
end

function QuestService.Start()
	S.TitanService.Killed:Connect(function(t, _killer, contributors)
		for _, player in contributors do
			QuestService.OnTitanKilled(player, t)
		end
	end)
	S.EnemyService.Killed:Connect(function(e, _killer, contributors)
		for _, player in contributors do
			QuestService.OnEnemyKilled(player, e)
		end
	end)
	Net.Event("AbandonQuest").OnServerEvent:Connect(QuestService.Abandon)
end

return QuestService
