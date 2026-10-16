--[[
	RewardsService - calendario giornaliero, regali a tempo e Ruota della Fortuna
	Tutto è deciso dal server: il client chiede ("ClaimReward", "SpinWheel") e mostra il risultato.
]]

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Lib.Net)
local Util = require(Shared.Lib.Util)
local Rewards = require(Shared.Data.Rewards)
local Leveling = require(Shared.Data.Leveling)
local Items = require(Shared.Data.Items)

local RewardsService = {}
local S

local DAY = 86400
local rng = Random.new()
local lastRequest: { [Player]: number } = {}

local function today(): number
	return os.time() // DAY
end

-- Applica un pacchetto di premi direttamente al profilo.
-- Restituisce una funzione che lo annulla (serve agli acquisti se il salvataggio fallisce)
-- e il testo del riepilogo.
function RewardsService.Apply(player: Player, bundle): ((() -> ())?, string)
	local profile = S.DataService.Get(player)
	if not profile then
		return nil, ""
	end
	local parts = {}
	local gold = bundle.Gold or 0
	if bundle.GoldQuests then
		gold += Leveling.QuestGold(profile.Level) * bundle.GoldQuests
	end
	gold = math.floor(gold)
	local gems = bundle.Gems or 0
	local spins = bundle.Spins or 0
	local items: { [string]: number } = {}
	if bundle.Items then
		for id, count in bundle.Items do
			if Items.Get(id) then
				if bundle.UniqueItem == id and (profile.Inventory[id] or 0) > 0 then
					gems += bundle.FallbackGems or 0
				else
					items[id] = count
				end
			end
		end
	end
	if gold > 0 then
		profile.Gold += gold
		table.insert(parts, "💰 " .. Util.Abbreviate(gold) .. " oro")
	end
	if gems > 0 then
		profile.Gems += gems
		table.insert(parts, ("💎 %d gemme"):format(gems))
	end
	if spins > 0 then
		profile.Spins = (profile.Spins or 0) + spins
		table.insert(parts, ("🎡 %d %s"):format(spins, if spins == 1 then "giro" else "giri"))
	end
	for id, count in items do
		profile.Inventory[id] = (profile.Inventory[id] or 0) + count
		local def = Items.Get(id)
		table.insert(parts, ("%s x%d"):format(def and def.Name or id, count))
	end
	S.DataService.MarkDirty(player)
	local function undo()
		profile.Gold -= gold
		profile.Gems -= gems
		profile.Spins = (profile.Spins or 0) - spins
		for id, count in items do
			profile.Inventory[id] = math.max(0, (profile.Inventory[id] or 0) - count)
		end
		S.DataService.MarkDirty(player)
	end
	return undo, table.concat(parts, "  •  ")
end

-- CALENDARIO --------------------------------------------------------------------------------

-- Giorno del calendario che si può ritirare oggi (nil = già ritirato)
function RewardsService.DailyIndex(profile): number?
	local streak = profile.Streak
	local now = today()
	if streak.Last == now then
		return nil
	end
	if streak.Last == now - 1 then
		return (streak.Day % #Rewards.Daily) + 1
	end
	return 1
end

local function claimDaily(player: Player)
	local profile = S.DataService.Get(player)
	if not profile then
		return
	end
	local index = RewardsService.DailyIndex(profile)
	if not index then
		S.EventService.Notify(player, "Hai già ritirato il premio di oggi. Torna domani!", "Info", 3)
		return
	end
	local reward = Rewards.Daily[index]
	profile.Streak.Day = index
	profile.Streak.Last = today()
	profile.Streak.Count = if index == 1 then 1 else (profile.Streak.Count or 0) + 1
	profile.Streak.Best = math.max(profile.Streak.Best or 0, profile.Streak.Count)
	local _, text = RewardsService.Apply(player, reward)
	S.EventService.AnnounceTo(player, ("Giorno %d: %s"):format(index, reward.Name), text, if reward.Big then "Raro" else "Ricompensa")
	S.DataService.SyncNow(player)
end

-- REGALI A TEMPO ----------------------------------------------------------------------------

local function playState(profile)
	local play = profile.PlayToday
	if play.Day ~= today() then
		play.Day = today()
		play.Seconds = 0
		play.Claimed = {}
	end
	return play
end

local function claimPlaytime(player: Player, index: any)
	local profile = S.DataService.Get(player)
	local gift = type(index) == "number" and Rewards.Playtime[index]
	if not profile or not gift then
		return
	end
	local play = playState(profile)
	local key = tostring(index)
	if play.Claimed[key] then
		return
	end
	if play.Seconds < gift.Minutes * 60 then
		S.EventService.Notify(player, ("Questo regalo si apre dopo %d minuti di gioco oggi."):format(gift.Minutes), "Info", 3)
		return
	end
	play.Claimed[key] = true
	local _, text = RewardsService.Apply(player, gift)
	S.EventService.AnnounceTo(player, "Regalo aperto: " .. gift.Name, text, if gift.Big then "Raro" else "Ricompensa")
	S.DataService.SyncNow(player)
end

-- RUOTA DELLA FORTUNA ------------------------------------------------------------------------

local function pickPrize()
	local roll = rng:NextNumber() * Rewards.WheelTotal()
	for _, prize in Rewards.Wheel do
		roll -= prize.Weight
		if roll <= 0 then
			return prize
		end
	end
	return Rewards.Wheel[1]
end

local function spin(player: Player)
	local profile = S.DataService.Get(player)
	if not profile then
		return
	end
	local now = os.time()
	local free = (profile.FreeSpinAt or 0) <= now
	if free then
		profile.FreeSpinAt = now + Rewards.FreeSpinHours * 3600
	elseif (profile.Spins or 0) > 0 then
		profile.Spins -= 1
	else
		S.EventService.Notify(player, "Non hai giri: aspetta il giro gratis o guadagnane altri con i regali.", "Info", 3.5)
		return
	end
	local prize = pickPrize()
	local _, text = RewardsService.Apply(player, prize)
	-- il client fa girare la ruota e poi mostra il premio
	Net.Event("WheelResult"):FireClient(player, prize.Id, text)
	if prize.Big then
		task.delay(4.5, function()
			if player.Parent then
				S.EventService.Announce("🎡 " .. player.DisplayName .. " ha vinto il JACKPOT!", prize.Name, "Raro")
			end
		end)
	end
	S.DataService.SyncNow(player)
end

-- Nei paesi in cui i premi casuali a pagamento non sono permessi, i giri a pagamento spariscono
local function checkPolicy(player: Player)
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	local restricted = not ok or (info and info.ArePaidRandomItemsRestricted == true)
	player:SetAttribute("NoPaidRandom", restricted)
end

function RewardsService.PaidRandomAllowed(player: Player): boolean
	return player:GetAttribute("NoPaidRandom") ~= true
end

function RewardsService.Init(services)
	S = services
end

function RewardsService.Start()
	Net.Event("ClaimReward").OnServerEvent:Connect(function(player, kind, index)
		local now = os.clock()
		if now - (lastRequest[player] or 0) < 0.4 then
			return
		end
		lastRequest[player] = now
		if kind == "Daily" then
			claimDaily(player)
		elseif kind == "Playtime" then
			claimPlaytime(player, index)
		end
	end)
	Net.Event("SpinWheel").OnServerEvent:Connect(function(player)
		local now = os.clock()
		if now - (lastRequest[player] or 0) < 1 then
			return
		end
		lastRequest[player] = now
		spin(player)
	end)
	S.DataService.OnLoaded(function(player, profile)
		playState(profile)
		player:SetAttribute("PlayToday", profile.PlayToday.Seconds)
		task.spawn(checkPolicy, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
	-- conta i minuti di gioco della giornata
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in Players:GetPlayers() do
				local profile = S.DataService.Get(player)
				if profile then
					local play = playState(profile)
					play.Seconds += 5
					player:SetAttribute("PlayToday", play.Seconds)
				end
			end
		end
	end)
end

return RewardsService
