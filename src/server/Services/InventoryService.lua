--[[
	InventoryService
	Oggetti posseduti, equipaggiamento e consumabili.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Lib.Net)
local Items = require(Shared.Data.Items)
local Bloodlines = require(Shared.Data.Bloodlines)

local InventoryService = {}
local S

function InventoryService.Count(player: Player, id: string): number
	local profile = S.DataService.Get(player)
	if not profile then
		return 0
	end
	return profile.Inventory[id] or 0
end

function InventoryService.Has(player: Player, id: string, count: number?): boolean
	return InventoryService.Count(player, id) >= (count or 1)
end

function InventoryService.Give(player: Player, id: string, count: number?)
	local profile = S.DataService.Get(player)
	local def = Items.Get(id)
	if not profile or not def then
		return false
	end
	local n = math.max(1, math.floor(count or 1))
	if Items.IsEquipment(id) then
		-- l'equipaggiamento si possiede una sola volta
		profile.Inventory[id] = 1
	else
		profile.Inventory[id] = (profile.Inventory[id] or 0) + n
	end
	S.DataService.MarkDirty(player)
	return true
end

function InventoryService.Take(player: Player, id: string, count: number?): boolean
	local profile = S.DataService.Get(player)
	local n = math.max(1, math.floor(count or 1))
	if not profile or (profile.Inventory[id] or 0) < n then
		return false
	end
	profile.Inventory[id] -= n
	if profile.Inventory[id] <= 0 then
		profile.Inventory[id] = nil
	end
	S.DataService.MarkDirty(player)
	return true
end

function InventoryService.Equip(player: Player, id: string): (boolean, string?)
	local profile = S.DataService.Get(player)
	local def = Items.Get(id)
	if not profile or not def then
		return false, "Oggetto sconosciuto."
	end
	local slot = Items.SlotOf(id)
	if not slot then
		return false, "Questo oggetto non si equipaggia."
	end
	if not InventoryService.Has(player, id) then
		return false, "Non possiedi questo oggetto."
	end
	if (def.LevelReq or 1) > profile.Level then
		return false, ("Serve il livello %d."):format(def.LevelReq)
	end
	if S.PlayerService.GetState(player).Transformed then
		return false, "Non puoi cambiare equipaggiamento in forma di gigante."
	end
	profile.Equipped[slot] = id
	S.PlayerService.Refresh(player)
	if slot == "Blade" or slot == "Ranged" then
		S.PlayerService.RefillWeapons(player)
	end
	return true, nil
end

function InventoryService.Unequip(player: Player, slot: string)
	local profile = S.DataService.Get(player)
	if not profile or profile.Equipped[slot] == nil then
		return
	end
	if slot == "Blade" or slot == "Gear" then
		return -- lame e rampini sono sempre necessari
	end
	if slot == "Armor" then
		profile.Equipped.Armor = "UniformeCadetto"
	else
		profile.Equipped[slot] = ""
	end
	S.PlayerService.Refresh(player)
end

local function useItem(player: Player, id: string): (boolean, string?)
	local def = Items.Get(id)
	if not def or def.Category ~= "Consumabile" then
		return false, nil
	end
	if not InventoryService.Has(player, id) then
		return false, "Non ne hai."
	end
	local profile = S.DataService.Get(player)
	local effect = def.Effect
	if effect == "Heal" then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or humanoid.Health >= humanoid.MaxHealth then
			return false, "Sei già in piena salute."
		end
		S.PlayerService.Heal(player, def.Amount)
	elseif effect == "RefillGas" then
		S.ODMService.Refill(player)
		Net.Event("Refilled"):FireClient(player, "Gas")
	elseif effect == "RefillBlades" then
		S.PlayerService.RefillWeapons(player)
		Net.Event("Refilled"):FireClient(player, "Lame")
	elseif effect == "DamageBuff" then
		profile.Buffs.DamageUntil = os.time() + def.Duration
		profile.Buffs.DamageAmount = def.Amount
	elseif effect == "GoldBuff" then
		profile.Buffs.GoldUntil = math.max(os.time(), profile.Buffs.GoldUntil or 0) + def.Duration
	elseif effect == "XPBuff" then
		profile.Buffs.XPUntil = math.max(os.time(), profile.Buffs.XPUntil or 0) + def.Duration
	elseif effect == "RerollBloodline" then
		local old = profile.Bloodline
		profile.Bloodline = Bloodlines.Roll(nil, old)
		local bloodline = Bloodlines.Get(profile.Bloodline)
		S.EventService.AnnounceTo(player, "Nuova Stirpe: " .. bloodline.Name, bloodline.Description, "Raro")
		S.PlayerService.Refresh(player, true)
	else
		return false, nil
	end
	InventoryService.Take(player, id, 1)
	S.EventService.Notify(player, "Usato: " .. def.Name, "Successo", 2.5)
	return true, nil
end

function InventoryService.Init(services)
	S = services
end

function InventoryService.Start()
	Net.Event("Equip").OnServerEvent:Connect(function(player, id)
		if type(id) ~= "string" then
			return
		end
		local ok, message = InventoryService.Equip(player, id)
		if not ok and message then
			S.EventService.Notify(player, message, "Errore", 3)
		elseif ok then
			local def = Items.Get(id)
			S.EventService.Notify(player, "Equipaggiato: " .. def.Name, "Successo", 2.5)
		end
	end)
	Net.Event("Unequip").OnServerEvent:Connect(function(player, slot)
		if type(slot) == "string" then
			InventoryService.Unequip(player, slot)
		end
	end)
	Net.Event("UseItem").OnServerEvent:Connect(function(player, id)
		if type(id) ~= "string" then
			return
		end
		local ok, message = useItem(player, id)
		if not ok and message then
			S.EventService.Notify(player, message, "Errore", 3)
		end
	end)
end

return InventoryService
