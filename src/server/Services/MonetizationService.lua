--[[
	MonetizationService - Negozio premium
	  • Developer Products (gemme e monete) con ProcessReceipt sicuro: ogni ricevuta viene
	    registrata nel profilo e salvata PRIMA di confermare l'acquisto a Roblox,
	    così nessuno riceve due volte la stessa cosa e nessuno perde un acquisto.
	  • Game Pass controllati a ogni ingresso (e subito dopo l'acquisto).
	  • Gemme: valuta premium, spendibili nel Negozio delle Gemme.
	  • Regali: gemme del primo accesso del giorno, del primo boss sconfitto e del pass VIP.
	Gli ID dei prodotti si configurano in ReplicatedStorage.Shared.Data.Monetization.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Lib.Net)
local Util = require(Shared.Lib.Util)
local Monetization = require(Shared.Data.Monetization)
local Items = require(Shared.Data.Items)
local W = require(Shared.Data.WorldLayout)
local Zones = require(Shared.Data.Zones)

local MonetizationService = {}
local S

local MAX_RECEIPTS = 60
local DAY = 86400

local function isStudio(): boolean
	return RunService:IsStudio()
end

-- GEMME ---------------------------------------------------------------------------------------

function MonetizationService.Gems(player: Player): number
	local profile = S.DataService.Get(player)
	return profile and profile.Gems or 0
end

function MonetizationService.AddGems(player: Player, amount: number, reason: string?)
	local profile = S.DataService.Get(player)
	if not profile or amount <= 0 then
		return
	end
	profile.Gems += math.floor(amount)
	S.DataService.MarkDirty(player)
	S.EventService.Notify(player, ("+%d 💎 gemme%s"):format(amount, if reason then " (" .. reason .. ")" else ""), "Ricompensa", 4)
end

function MonetizationService.SpendGems(player: Player, amount: number): boolean
	local profile = S.DataService.Get(player)
	if not profile or amount < 0 or profile.Gems < amount then
		return false
	end
	profile.Gems -= math.floor(amount)
	S.DataService.MarkDirty(player)
	return true
end

function MonetizationService.HasPass(player: Player, passId: string): boolean
	local profile = S.DataService.Get(player)
	return profile ~= nil and profile.Passes[passId] == true
end

-- CONSEGNA DEI PRODOTTI -------------------------------------------------------------------------

-- Il Pacchetto della Recluta si può comprare una volta sola e solo nei primi giorni
function MonetizationService.StarterAvailable(player: Player): boolean
	local profile = S.DataService.Get(player)
	if not profile or profile.StarterBought then
		return false
	end
	return os.time() - (profile.CreatedAt or 0) < Monetization.StarterHours * 3600
end

-- Consegna un prodotto. Restituisce una funzione per annullarlo (nil se non consegnato)
local function grantProduct(player: Player, product): (() -> ())?
	local profile = S.DataService.Get(player)
	if not profile then
		return nil
	end
	local undo: (() -> ())?
	local text
	if product.Kind == "Gems" then
		profile.Gems += product.Amount
		undo = function()
			profile.Gems -= product.Amount
		end
		text = ("%s %s: +%s"):format(product.Icon, product.Name, Util.FormatNumber(product.Amount))
	elseif product.Kind == "Gold" then
		profile.Gold += product.Amount
		undo = function()
			profile.Gold -= product.Amount
		end
		text = ("%s %s: +%s"):format(product.Icon, product.Name, Util.FormatNumber(product.Amount))
	elseif product.Kind == "Spins" then
		profile.Spins = (profile.Spins or 0) + product.Amount
		undo = function()
			profile.Spins -= product.Amount
		end
		text = ("%s +%d giri della Ruota"):format(product.Icon, product.Amount)
	elseif product.Kind == "Starter" then
		local bundleUndo, summary = S.RewardsService.Apply(player, product.Bundle)
		if not bundleUndo then
			return nil
		end
		profile.StarterBought = true
		undo = function()
			bundleUndo()
			profile.StarterBought = false
		end
		text = product.Name .. ": " .. summary
	else
		return nil
	end
	S.DataService.MarkDirty(player)
	S.EventService.AnnounceTo(player, "Grazie per il tuo supporto!", text, "Raro")
	local root = Util.GetRoot(player.Character)
	if root then
		S.EventService.Effect("LevelUp", { Character = player.Character }, root.Position, 300)
	end
	return undo
end

local function grantPass(player: Player, pass)
	local profile = S.DataService.Get(player)
	if not profile then
		return
	end
	local isNew = profile.Passes[pass.Id] ~= true
	profile.Passes[pass.Id] = true
	if pass.GiftItem and (profile.Inventory[pass.GiftItem] or 0) == 0 then
		S.InventoryService.Give(player, pass.GiftItem, 1)
	end
	if pass.Id == "VIP" then
		player:SetAttribute("VIP", true)
	end
	S.DataService.MarkDirty(player)
	S.PlayerService.Refresh(player, true)
	if isNew then
		S.EventService.AnnounceTo(player, "Pass sbloccato: " .. pass.Name, pass.Description, "Raro")
	end
end

-- Ricevute di Roblox: si conferma solo dopo aver salvato
local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = S.DataService.WaitFor(player, 15)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	for _, done in profile.Receipts do
		if done == purchaseId then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	local product = Monetization.ProductByRobloxId(receipt.ProductId)
	if not product then
		warn("[Monetization] Prodotto sconosciuto: " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local undo = grantProduct(player, product)
	if not undo then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(profile.Receipts, purchaseId)
	while #profile.Receipts > MAX_RECEIPTS do
		table.remove(profile.Receipts, 1)
	end
	-- salva subito: se il salvataggio fallisce, Roblox riproverà più tardi
	if not S.DataService.Save(player) and not isStudio() then
		-- annulla la consegna per non regalare il prodotto due volte al prossimo tentativo
		undo()
		table.remove(profile.Receipts, #profile.Receipts)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- PASS: controllo all'ingresso ----------------------------------------------------------------------

local function refreshPasses(player: Player)
	local profile = S.DataService.Get(player)
	if not profile then
		return
	end
	for _, pass in Monetization.GamePasses do
		if pass.PassId ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.PassId)
			end)
			if ok then
				if owns then
					grantPass(player, pass)
				elseif not isStudio() then
					profile.Passes[pass.Id] = nil
				end
			end
		end
	end
	if profile.Passes.VIP then
		player:SetAttribute("VIP", true)
	end
	S.PlayerService.Refresh(player, true)
end

-- Regali giornalieri (primo accesso del giorno e VIP)
local function dailyGifts(player: Player)
	local profile = S.DataService.Get(player)
	if not profile then
		return
	end
	-- (il premio del primo accesso del giorno ora è nel calendario di RewardsService)
	local today = os.time() // DAY
	local vip = Monetization.Pass("VIP")
	if vip and profile.Passes.VIP and (profile.LastDailyGems or 0) < today then
		profile.LastDailyGems = today
		MonetizationService.AddGems(player, vip.DailyGems or 0, "regalo VIP")
	end
end

-- RICHIESTE DEL CLIENT ------------------------------------------------------------------------------

local function buyGemItem(player: Player, entry)
	local profile = S.DataService.Get(player)
	if not profile then
		return
	end
	if entry.Unique and entry.Item and (profile.Inventory[entry.Item] or 0) > 0 then
		S.EventService.Notify(player, "Lo possiedi già.", "Info", 2.5)
		return
	end
	if profile.Gems < entry.Gems then
		S.EventService.Notify(player, ("Servono %d 💎 gemme."):format(entry.Gems), "Errore", 3)
		return
	end
	if entry.Action == "ResetStats" then
		local total = 0
		for _, value in profile.Stats do
			total += value
		end
		if total <= 0 then
			S.EventService.Notify(player, "Non hai punti da recuperare.", "Info", 2.5)
			return
		end
		MonetizationService.SpendGems(player, entry.Gems)
		for name in profile.Stats do
			profile.Stats[name] = 0
		end
		profile.StatPoints += total
		S.PlayerService.Refresh(player, true)
	elseif entry.Item then
		if not Items.Get(entry.Item) then
			return
		end
		MonetizationService.SpendGems(player, entry.Gems)
		S.InventoryService.Give(player, entry.Item, entry.Count or 1)
	else
		return
	end
	S.EventService.Notify(player, ("Acquistato: %s %s"):format(entry.Icon, entry.Name), "Successo", 3)
	S.DataService.SyncNow(player)
end

local function onBuy(player: Player, kind: any, id: any)
	if type(kind) ~= "string" or type(id) ~= "string" then
		return
	end
	if kind == "Product" then
		local product = Monetization.Product(id)
		if not product then
			return
		end
		if product.Kind == "Starter" and not MonetizationService.StarterAvailable(player) then
			S.EventService.Notify(player, "Questa offerta non è più disponibile.", "Info", 3)
			return
		end
		if product.Kind == "Spins" and not S.RewardsService.PaidRandomAllowed(player) then
			S.EventService.Notify(player, "I giri a pagamento non sono disponibili nel tuo paese.", "Info", 3)
			return
		end
		if product.ProductId == 0 then
			if isStudio() then
				-- in Studio, senza ID configurato, l'acquisto viene simulato per poterlo provare
				grantProduct(player, product)
				S.EventService.Notify(player, "(Studio) Acquisto simulato: configura il ProductId per venderlo davvero.", "Info", 4)
				S.DataService.SyncNow(player)
			else
				S.EventService.Notify(player, "Questo pacchetto non è ancora disponibile.", "Info", 3)
			end
			return
		end
		MarketplaceService:PromptProductPurchase(player, product.ProductId)
	elseif kind == "Pass" then
		local pass = Monetization.Pass(id)
		if not pass then
			return
		end
		if MonetizationService.HasPass(player, pass.Id) then
			S.EventService.Notify(player, "Possiedi già questo pass.", "Info", 2.5)
			return
		end
		if pass.PassId == 0 then
			if isStudio() then
				grantPass(player, pass)
				S.EventService.Notify(player, "(Studio) Pass simulato: configura il PassId per venderlo davvero.", "Info", 4)
				S.DataService.SyncNow(player)
			else
				S.EventService.Notify(player, "Questo pass non è ancora disponibile.", "Info", 3)
			end
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, pass.PassId)
	elseif kind == "Gem" then
		local entry = Monetization.GemItem(id)
		if entry then
			buyGemItem(player, entry)
		end
	end
end

-- Viaggio rapido (pass "Viaggiatore")
local function onFastTravel(player: Player, islandId: any)
	if type(islandId) ~= "string" then
		return
	end
	local island = W.Islands[islandId]
	local profile = S.DataService.Get(player)
	if not island or island.Raid or not profile then
		return
	end
	if not MonetizationService.HasPass(player, "Viaggiatore") then
		S.EventService.Notify(player, "Serve il pass Viaggiatore.", "Errore", 3)
		return
	end
	if profile.Level < island.LevelReq then
		S.EventService.Notify(player, ("Per %s serve il livello %d."):format(island.Name, island.LevelReq), "Errore", 3)
		return
	end
	local state = S.PlayerService.GetState(player)
	if state.Dead or state.GrabbedBy or state.Transformed then
		return
	end
	if S.RaidService and S.RaidService.IsParticipant(player) then
		S.EventService.Notify(player, "Non puoi viaggiare durante un raid.", "Errore", 3)
		return
	end
	local zone = Zones.Get(island.Hub)
	if zone then
		S.EventService.EffectTo(player, "Voyage", { Destination = island.Hub })
		task.wait(1.2)
		S.PlayerService.Teleport(player, Zones.SpawnPoint(zone))
	end
end

function MonetizationService.Init(services)
	S = services
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for _, pass in Monetization.GamePasses do
			if pass.PassId == passId then
				grantPass(player, pass)
				S.DataService.SyncNow(player)
			end
		end
	end)
	S.DataService.Loaded:Connect(function(player)
		task.spawn(function()
			refreshPasses(player)
			dailyGifts(player)
			S.DataService.SyncNow(player)
		end)
	end)
	-- gemme per il primo boss sconfitto di ogni tipo
	S.TitanService.Killed:Connect(function(t, _killer, contributors)
		if t.Kind ~= "Boss" or not t.BossId or t.Raid then
			return
		end
		for _, player in contributors or {} do
			if typeof(player) == "Instance" and player:IsA("Player") then
				local profile = S.DataService.Get(player)
				if profile and not profile.FirstBossGems[t.BossId] then
					profile.FirstBossGems[t.BossId] = true
					MonetizationService.AddGems(player, Monetization.Earn.FirstBossKill, "primo " .. t.Name)
				end
			end
		end
	end)
	Net.Event("PremiumBuy").OnServerEvent:Connect(onBuy)
	Net.Event("FastTravel").OnServerEvent:Connect(onFastTravel)
end

return MonetizationService
