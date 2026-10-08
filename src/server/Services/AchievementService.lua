--[[
	AchievementService - Traguardi
	Controlla periodicamente i progressi di ogni giocatore e assegna gemme (e la medaglia
	Roblox, se il traguardo ha un BadgeId) quando un obiettivo viene raggiunto.
]]

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Lib.Net)
local Achievements = require(Shared.Data.Achievements)

local AchievementService = {}
local S

local function awardBadge(player: Player, badgeId: number)
	if badgeId == 0 then
		return
	end
	task.spawn(function()
		local ok, has = pcall(function()
			return BadgeService:UserHasBadgeAsync(player.UserId, badgeId)
		end)
		if ok and not has then
			pcall(function()
				BadgeService:AwardBadge(player.UserId, badgeId)
			end)
		end
	end)
end

function AchievementService.Check(player: Player)
	local profile = S.DataService.Get(player)
	if not profile then
		return
	end
	local extra = { Friends = player:GetAttribute("FriendsHere") or 0 }
	local unlocked = false
	for _, a in Achievements.List do
		if not profile.Achievements[a.Id] and Achievements.Value(profile, a.Stat, extra) >= a.Goal then
			profile.Achievements[a.Id] = os.time()
			unlocked = true
			profile.Gems += a.Gems
			Net.Event("Achievement"):FireClient(player, a.Id)
			S.EventService.Notify(player, ("🏅 Traguardo: %s  (+%d 💎)"):format(a.Name, a.Gems), "Raro", 5)
			awardBadge(player, a.BadgeId)
		elseif profile.Achievements[a.Id] and a.BadgeId ~= 0 and not profile._BadgesChecked then
			-- medaglie aggiunte dopo: le consegna anche a chi aveva già il traguardo
			awardBadge(player, a.BadgeId)
		end
	end
	profile._BadgesChecked = true
	if unlocked then
		S.DataService.MarkDirty(player)
	end
end

function AchievementService.Init(services)
	S = services
end

function AchievementService.Start()
	S.DataService.OnLoaded(function(player)
		task.delay(6, function()
			if player.Parent then
				AchievementService.Check(player)
			end
		end)
	end)
	S.PlayerService.LevelUp:Connect(function(player)
		AchievementService.Check(player)
	end)
	task.spawn(function()
		while true do
			task.wait(15)
			for _, player in Players:GetPlayers() do
				task.spawn(AchievementService.Check, player)
			end
		end
	end)
end

return AchievementService
