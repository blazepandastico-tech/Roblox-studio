--[[
	CommunityService - tutto ciò che porta nuovi giocatori
	  • Bonus amici: +10% esperienza per ogni amico nello stesso server (massimo +30%).
	  • Gruppo del gioco (Config.GroupId): +10% oro per sempre e un regalo di benvenuto.
	  • Il client chiede una volta di aggiungere il gioco ai Preferiti (qui si ricorda che l'ha fatto).
]]

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Lib.Net)

local CommunityService = {}
local S

-- amicizie già controllate: friendCache[a][b] = true/false
local friendCache: { [number]: { [number]: boolean } } = {}

local function areFriends(a: Player, b: Player): boolean
	local row = friendCache[a.UserId]
	if not row then
		row = {}
		friendCache[a.UserId] = row
	end
	local known = row[b.UserId]
	if known ~= nil then
		return known
	end
	local ok, result = pcall(function()
		return a:IsFriendsWith(b.UserId)
	end)
	local value = ok and result == true
	row[b.UserId] = value
	local other = friendCache[b.UserId] or {}
	friendCache[b.UserId] = other
	other[a.UserId] = value
	return value
end

local function updateFriends()
	local list = Players:GetPlayers()
	for _, player in list do
		local count = 0
		for _, other in list do
			if other ~= player and areFriends(player, other) then
				count += 1
			end
		end
		local before = player:GetAttribute("FriendsHere") or 0
		player:SetAttribute("FriendsHere", count)
		player:SetAttribute("BonusXP", math.min(count, Config.FriendXPBonusMax) * Config.FriendXPBonus)
		local profile = S.DataService.Get(player)
		if profile and count > (profile.FriendsSeen or 0) then
			profile.FriendsSeen = count
			S.DataService.MarkDirty(player)
		end
		if count > before then
			S.EventService.Notify(player, ("🤝 Un amico è nel server: +%d%% esperienza!"):format(math.floor(math.min(count, Config.FriendXPBonusMax) * Config.FriendXPBonus * 100)), "Successo", 4)
		end
	end
end

local function checkGroup(player: Player, announce: boolean)
	if Config.GroupId == 0 then
		return
	end
	local ok, inGroup = pcall(function()
		return player:IsInGroup(Config.GroupId)
	end)
	if not ok then
		return
	end
	if not inGroup and announce then
		-- IsInGroup può essere ancora quello vecchio: chiede l'elenco aggiornato dei gruppi
		local okList, groups = pcall(function()
			return GroupService:GetGroupsAsync(player.UserId)
		end)
		if okList and groups then
			for _, info in groups do
				if info.Id == Config.GroupId then
					inGroup = true
				end
			end
		end
	end
	player:SetAttribute("InGroup", inGroup)
	player:SetAttribute("BonusGold", if inGroup then Config.GroupGoldBonus else 0)
	local profile = S.DataService.Get(player)
	if inGroup and profile and not profile.GroupRewarded then
		profile.GroupRewarded = true
		local _, text = S.RewardsService.Apply(player, Config.GroupReward)
		S.EventService.AnnounceTo(player, "Grazie per esserti unito al gruppo!", text .. "  •  +10% oro per sempre", "Raro")
		S.DataService.SyncNow(player)
	elseif announce and not inGroup then
		S.EventService.Notify(player, "Non risulti ancora nel gruppo. Unisciti dalla pagina del gioco e rientra.", "Info", 5)
	end
end

function CommunityService.Init(services)
	S = services
end

function CommunityService.Start()
	ReplicatedStorage:SetAttribute("GroupId", Config.GroupId)
	S.DataService.Loaded:Connect(function(player)
		task.spawn(checkGroup, player, false)
		task.defer(updateFriends)
	end)
	Players.PlayerRemoving:Connect(function(player)
		friendCache[player.UserId] = nil
		task.defer(updateFriends)
	end)
	Net.Event("CommunityAction").OnServerEvent:Connect(function(player, action)
		local profile = S.DataService.Get(player)
		if not profile then
			return
		end
		if action == "Favorite" then
			profile.FavoritePrompted = true
			S.DataService.MarkDirty(player)
		elseif action == "CheckGroup" then
			checkGroup(player, true)
		end
	end)
end

return CommunityService
