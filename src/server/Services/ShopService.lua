--[[
	ShopService
	Negozi (armerie ed emporio), Laboratorio (sintesi di sieri e oggetti mitici),
	Mercante di Sieri e Archivista delle Stirpi.
	Gli acquisti funzionano solo vicino al PNG giusto (anti-trucco).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Lib.Util)
local Net = require(Shared.Lib.Net)
local Items = require(Shared.Data.Items)
local Shops = require(Shared.Data.Shops)
local Serums = require(Shared.Data.Serums)
local NPCs = require(Shared.Data.NPCs)
local Zones = require(Shared.Data.Zones)
local Bloodlines = require(Shared.Data.Bloodlines)

local ShopService = {}
local S

local MAX_DISTANCE = 40

-- Il giocatore è vicino a un PNG con questo ruolo/negozio?
local function nearNpc(player: Player, predicate: (any) -> boolean): boolean
	local root = Util.GetRoot(player.Character)
	if not root then
		return false
	end
	for _, npc in NPCs.List do
		if predicate(npc) then
			local zone = Zones.Get(npc.Zone)
			if zone then
				local pos = zone.Center + npc.Offset
				if Util.FlatDistance(pos, root.Position) <= MAX_DISTANCE and math.abs(pos.Y - root.Position.Y) < 60 then
					return true
				end
			end
		end
	end
	return false
end

function ShopService.OpenShop(player: Player, shopId: string)
	local shop = Shops.List[shopId]
	local profile = S.DataService.Get(player)
	if not shop or not profile then
		return
	end
	local list = {}
	for _, id in shop.Items do
		local def = Items.Get(id)
		if def then
			table.insert(list, { Id = id, Price = def.Price or 0, LevelReq = def.LevelReq or 1, Owned = Items.IsEquipment(id) and (profile.Inventory[id] or 0) > 0 })
		end
	end
	Net.Event("ShopOpen"):FireClient(player, { Kind = "Shop", ShopId = shopId, Name = shop.Name, Items = list })
end

function ShopService.OpenLab(player: Player)
	local list = {}
	for _, recipe in Shops.Recipes do
		table.insert(list, { Id = recipe.Id, Result = recipe.Result, Serum = recipe.Serum == true, Gold = recipe.Gold, LevelReq = recipe.LevelReq, Materials = recipe.Materials, Locked = recipe.Serum == true and not S.SerumService.IsAvailable() })
	end
	Net.Event("ShopOpen"):FireClient(player, { Kind = "Lab", Name = "Laboratorio della Dott.ssa Morrow", Recipes = list })
end

function ShopService.OpenDealer(player: Player)
	local stock, endsAt = S.SerumService.DealerStock()
	local list = {}
	for _, id in stock do
		local serum = Serums.Get(id)
		table.insert(list, { Id = id, Price = serum.Price, LevelReq = serum.LevelReq, Locked = not S.SerumService.IsAvailable() })
	end
	Net.Event("ShopOpen"):FireClient(player, { Kind = "Dealer", Name = "Il Mercante Velato", Stock = list, EndsAt = endsAt, Now = os.time() })
end

local function buy(player: Player, shopId: any, itemId: any)
	if type(shopId) ~= "string" or type(itemId) ~= "string" then
		return
	end
	if shopId == "Dealer" then
		if not nearNpc(player, function(npc)
			return npc.Role == "Dealer"
		end) then
			return
		end
		local ok, message = S.SerumService.BuyFromDealer(player, itemId)
		if not ok and message then
			S.EventService.Notify(player, message, "Errore", 3)
		end
		ShopService.OpenDealer(player)
		return
	end
	local shop = Shops.List[shopId]
	if not shop or not table.find(shop.Items, itemId) then
		return
	end
	if not nearNpc(player, function(npc)
		return npc.Shop == shopId
	end) then
		S.EventService.Notify(player, "Sei troppo lontano dal negozio.", "Errore", 2)
		return
	end
	local def = Items.Get(itemId)
	local profile = S.DataService.Get(player)
	if not def or not profile then
		return
	end
	if (def.LevelReq or 1) > profile.Level then
		S.EventService.Notify(player, ("Serve il livello %d."):format(def.LevelReq), "Errore", 3)
		return
	end
	if Items.IsEquipment(itemId) and (profile.Inventory[itemId] or 0) > 0 then
		S.EventService.Notify(player, "Lo possiedi già.", "Info", 2)
		return
	end
	if not S.PlayerService.SpendGold(player, def.Price or 0) then
		S.EventService.Notify(player, ("Oro insufficiente: servono %s."):format(Util.FormatNumber(def.Price or 0)), "Errore", 3)
		return
	end
	S.InventoryService.Give(player, itemId, 1)
	S.EventService.Notify(player, "Acquistato: " .. def.Name, "Successo", 3)
	if Items.IsEquipment(itemId) then
		local ok = S.InventoryService.Equip(player, itemId)
		if ok then
			S.EventService.Notify(player, "Equipaggiato automaticamente.", "Info", 2)
		end
	end
	ShopService.OpenShop(player, shopId)
end

local function craft(player: Player, recipeId: any)
	if type(recipeId) ~= "string" then
		return
	end
	local recipe = Shops.RecipeById[recipeId]
	local profile = S.DataService.Get(player)
	if not recipe or not profile then
		return
	end
	if recipe.Serum and not S.SerumService.IsAvailable() then
		S.EventService.Notify(player, Config.Serums.ComingSoonText, "Info", 4)
		return
	end
	if not nearNpc(player, function(npc)
		return npc.Role == "Lab"
	end) then
		S.EventService.Notify(player, "Devi essere al Laboratorio.", "Errore", 2)
		return
	end
	if profile.Level < recipe.LevelReq then
		S.EventService.Notify(player, ("Serve il livello %d."):format(recipe.LevelReq), "Errore", 3)
		return
	end
	for id, count in recipe.Materials do
		if not S.InventoryService.Has(player, id, count) then
			local def = Items.Get(id)
			S.EventService.Notify(player, ("Mancano materiali: %s (%d/%d)"):format(def and def.Name or id, S.InventoryService.Count(player, id), count), "Errore", 3)
			return
		end
	end
	if not recipe.Serum and Items.IsEquipment(recipe.Result) and (profile.Inventory[recipe.Result] or 0) > 0 then
		S.EventService.Notify(player, "Possiedi già questo oggetto.", "Info", 2)
		return
	end
	if profile.Gold < recipe.Gold then
		S.EventService.Notify(player, ("Servono %s oro."):format(Util.FormatNumber(recipe.Gold)), "Errore", 3)
		return
	end
	S.PlayerService.SpendGold(player, recipe.Gold)
	for id, count in recipe.Materials do
		S.InventoryService.Take(player, id, count)
	end
	if recipe.Serum then
		S.SerumService.GiveSerum(player, recipe.Result, "Laboratorio")
	else
		S.InventoryService.Give(player, recipe.Result, 1)
		local def = Items.Get(recipe.Result)
		S.EventService.AnnounceTo(player, "Creazione riuscita!", def and def.Name or recipe.Result, "Raro")
	end
	ShopService.OpenLab(player)
end

function ShopService.RerollBloodline(player: Player): (boolean, string?)
	local profile = S.DataService.Get(player)
	if not profile then
		return false, nil
	end
	if not S.PlayerService.SpendGold(player, Config.Bloodline.RerollCost) then
		return false, ("Servono %s oro."):format(Util.FormatNumber(Config.Bloodline.RerollCost))
	end
	profile.Bloodline = Bloodlines.Roll(nil, profile.Bloodline)
	local bloodline = Bloodlines.Get(profile.Bloodline)
	S.EventService.AnnounceTo(player, "Nuova Stirpe: " .. bloodline.Name, bloodline.Description, "Raro")
	S.PlayerService.Refresh(player, true)
	return true, nil
end

function ShopService.Init(services)
	S = services
end

function ShopService.Start()
	Net.Event("ShopBuy").OnServerEvent:Connect(buy)
	Net.Event("Craft").OnServerEvent:Connect(craft)
end

return ShopService
