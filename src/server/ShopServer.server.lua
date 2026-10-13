-- Lato server dello shop: valida gli acquisti e assegna le ricompense.
-- NOTA: le ricompense sono attributi del Player (es. player:GetAttribute("Luck")).
-- Per salvarle tra una sessione e l'altra aggiungi un DataStore.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopConfig"))

local remotes = Instance.new("Folder")
remotes.Name = "ShopRemotes"

local purchaseRemote = Instance.new("RemoteEvent")
purchaseRemote.Name = "Purchase"
purchaseRemote.Parent = remotes

local purchasedRemote = Instance.new("RemoteEvent")
purchasedRemote.Name = "Purchased"
purchasedRemote.Parent = remotes

remotes.Parent = ReplicatedStorage

local itemsById = {}
local itemsByProduct = {}
for _, item in ipairs(Config.Items) do
	itemsById[item.Id] = item
	if item.ProductId and item.ProductId ~= 0 then
		itemsByProduct[item.ProductId] = item
	end
end

local function grant(player, item)
	local reward = item.Reward
	if reward then
		local current = player:GetAttribute(reward.Attribute) or 0
		player:SetAttribute(reward.Attribute, current + reward.Add)
	end
	purchasedRemote:FireClient(player, item.Id)
end

-- Acquisti simulati (solo con Config.TestMode = true)
local lastPurchase = {}
purchaseRemote.OnServerEvent:Connect(function(player, itemId)
	if not Config.TestMode or typeof(itemId) ~= "string" then
		return
	end
	local now = os.clock()
	if lastPurchase[player] and now - lastPurchase[player] < 0.4 then
		return
	end
	lastPurchase[player] = now

	local item = itemsById[itemId]
	if item then
		grant(player, item)
	end
end)

-- Acquisti veri con Developer Product
MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local item = itemsByProduct[receiptInfo.ProductId]
	if not item then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	grant(player, item)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

Players.PlayerRemoving:Connect(function(player)
	lastPurchase[player] = nil
end)
