--[[
	AdminService - Pannello Admin (tasto P)
	Solo gli amministratori possono usarlo: Roblox Studio, il proprietario del gioco
	(o il capo del gruppo proprietario) e gli UserId in Config.Admins.
	Ogni azione è controllata QUI sul server: un giocatore normale non può usarla
	nemmeno modificando il proprio client.

	I Sieri Perduti (poteri dei giganti) per ora si ottengono SOLO da questo pannello.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Lib.Net)
local Util = require(Shared.Lib.Util)
local Items = require(Shared.Data.Items)
local Serums = require(Shared.Data.Serums)
local Titans = require(Shared.Data.Titans)
local Zones = require(Shared.Data.Zones)
local Leveling = require(Shared.Data.Leveling)
local Story = require(Shared.Data.Story)
local Monetization = require(Shared.Data.Monetization)
local W = require(Shared.Data.WorldLayout)

local AdminService = {}
local S

local lastAction: { [Player]: number } = {}

function AdminService.IsAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	for _, id in Config.Admins do
		if id == player.UserId then
			return true
		end
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(function()
		return player:GetRankInGroup(game.CreatorId)
	end)
	return ok and rank == 255
end

local function tell(admin: Player, text: string)
	S.EventService.Notify(admin, "🛠️ " .. text, "Successo", 4)
	print(("[Admin] %s: %s"):format(admin.Name, text))
end

local function refresh(player: Player)
	S.PlayerService.Refresh(player, true)
	S.DataService.SyncNow(player)
end

local function setLevel(player: Player, target: number)
	local profile = S.DataService.Get(player)
	if not profile then
		return
	end
	target = math.clamp(math.floor(target), 1, Config.MaxLevel)
	local before = profile.Level
	if target > before then
		local need = -profile.XP
		for level = before, target - 1 do
			need += Leveling.XPToNext(level)
		end
		Leveling.AddXP(profile, need)
	else
		profile.Level = target
		profile.XP = 0
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	local levelValue = leaderstats and leaderstats:FindFirstChild("Livello") :: IntValue?
	if levelValue then
		levelValue.Value = profile.Level
	end
	refresh(player)
	if profile.Level > before then
		S.PlayerService.LevelUp:Fire(player, profile.Level, before)
		local root = Util.GetRoot(player.Character)
		if root then
			S.EventService.Effect("LevelUp", { Character = player.Character }, root.Position, 300)
		end
	end
end

local function groundBelow(position: Vector3): Vector3
	local zone = Zones.Find(position)
	local y = if zone then zone.Center.Y else W.GroundY
	return Vector3.new(position.X, y, position.Z)
end

local function nearbyTitans(position: Vector3, radius: number)
	local list = {}
	for _, t in S.TitanService.All() do
		if t.Root and t.Root.Parent and t.Kind ~= "Ally" and (t.Root.Position - position).Magnitude < radius then
			table.insert(list, t)
		end
	end
	return list
end

-- Ogni azione riceve (admin, bersaglio, valore) e restituisce il messaggio da mostrare
local ACTIONS: { [string]: (Player, Player, any) -> string? } = {}

-- PROGRESSIONE ---------------------------------------------------------------------------------
ACTIONS.LevelMax = function(_, target)
	setLevel(target, Config.MaxLevel)
	return ("%s è al livello massimo (%d)"):format(target.DisplayName, Config.MaxLevel)
end
ACTIONS.LevelAdd = function(_, target, value)
	local profile = S.DataService.Get(target)
	local amount = tonumber(value) or 100
	if profile then
		setLevel(target, profile.Level + amount)
		return ("%s: livello %d"):format(target.DisplayName, profile.Level)
	end
	return nil
end
ACTIONS.LevelSet = function(_, target, value)
	local level = tonumber(value)
	if not level then
		return "Scrivi un numero di livello"
	end
	setLevel(target, level)
	return ("%s: livello %d"):format(target.DisplayName, math.clamp(math.floor(level), 1, Config.MaxLevel))
end
ACTIONS.StatsMax = function(_, target)
	local profile = S.DataService.Get(target)
	if profile then
		for name in profile.Stats do
			profile.Stats[name] = Config.StatCap
		end
		refresh(target)
	end
	return target.DisplayName .. ": tutte le statistiche al massimo"
end
ACTIONS.StatsReset = function(_, target)
	local profile = S.DataService.Get(target)
	if profile then
		for name in profile.Stats do
			profile.Stats[name] = 0
		end
		profile.StatPoints = (profile.Level - 1) * Config.StatPointsPerLevel
		refresh(target)
	end
	return target.DisplayName .. ": statistiche azzerate, punti restituiti"
end
ACTIONS.Gold = function(_, target, value)
	local profile = S.DataService.Get(target)
	local amount = math.floor(tonumber(value) or 1000000)
	if profile then
		profile.Gold += amount
		refresh(target)
	end
	return ("+%s oro a %s"):format(Util.FormatNumber(amount), target.DisplayName)
end
ACTIONS.Gems = function(_, target, value)
	local profile = S.DataService.Get(target)
	local amount = math.floor(tonumber(value) or 10000)
	if profile then
		profile.Gems += amount
		refresh(target)
	end
	return ("+%s gemme a %s"):format(Util.FormatNumber(amount), target.DisplayName)
end
ACTIONS.Spins = function(_, target, value)
	local profile = S.DataService.Get(target)
	local amount = math.floor(tonumber(value) or 50)
	if profile then
		profile.Spins = (profile.Spins or 0) + amount
		refresh(target)
	end
	return ("+%d giri della Ruota a %s"):format(amount, target.DisplayName)
end
ACTIONS.ResetRewards = function(_, target)
	local profile = S.DataService.Get(target)
	if profile then
		profile.Streak.Last = 0
		profile.Streak.Day = 0
		profile.PlayToday.Claimed = {}
		profile.PlayToday.Seconds = math.max(profile.PlayToday.Seconds, 90 * 60)
		target:SetAttribute("PlayToday", profile.PlayToday.Seconds)
		profile.FreeSpinAt = 0
		refresh(target)
	end
	return target.DisplayName .. ": calendario, regali a tempo e giro gratis di nuovo disponibili"
end

-- OGGETTI E PASS --------------------------------------------------------------------------------
ACTIONS.AllItems = function(_, target)
	local count = 0
	for id in Items.List do
		S.InventoryService.Give(target, id, if Items.IsEquipment(id) then 1 else 99)
		count += 1
	end
	refresh(target)
	return ("%s ha ricevuto tutti i %d oggetti del gioco"):format(target.DisplayName, count)
end
ACTIONS.Item = function(_, target, value)
	local def = Items.Get(value)
	if not def then
		return "Oggetto sconosciuto"
	end
	S.InventoryService.Give(target, def.Id, if Items.IsEquipment(def.Id) then 1 else 10)
	refresh(target)
	return ("%s ha ricevuto: %s"):format(target.DisplayName, def.Name)
end
ACTIONS.AllPasses = function(_, target)
	local profile = S.DataService.Get(target)
	if profile then
		for _, pass in Monetization.GamePasses do
			profile.Passes[pass.Id] = true
			if pass.GiftItem then
				S.InventoryService.Give(target, pass.GiftItem, 1)
			end
		end
		target:SetAttribute("VIP", true)
		refresh(target)
	end
	return target.DisplayName .. ": tutti i game pass attivi (solo su questo profilo)"
end
ACTIONS.RemovePasses = function(_, target)
	local profile = S.DataService.Get(target)
	if profile then
		profile.Passes = {}
		target:SetAttribute("VIP", nil)
		refresh(target)
	end
	return target.DisplayName .. ": game pass rimossi"
end

-- SIERI (si ottengono solo qui) ------------------------------------------------------------------
ACTIONS.Serum = function(_, target, value)
	local serum = Serums.Get(value)
	if not serum then
		return "Siero sconosciuto"
	end
	local state = S.PlayerService.GetState(target)
	if state.Transformed then
		S.ShifterService.Revert(target, "Admin")
		task.wait(0.5)
	end
	local ok, err = S.SerumService.ApplySerum(target, serum.Id)
	if not ok then
		return err or "Impossibile iniettare il siero ora"
	end
	return ("%s ha il potere del %s: premi T per trasformarti"):format(target.DisplayName, serum.TitanName)
end
ACTIONS.SerumMastery = function(_, target)
	local profile = S.DataService.Get(target)
	if not profile or profile.Serum == "" then
		return "Prima dai un siero"
	end
	profile.SerumMastery[profile.Serum] = Config.Serums.MaxMastery
	S.ShifterService.ResetEnergy(target)
	refresh(target)
	return target.DisplayName .. ": maestria del siero al massimo (tutte le abilità sbloccate)"
end
ACTIONS.AllSerums = function(_, target)
	local profile = S.DataService.Get(target)
	if profile then
		for _, id in Serums.Order do
			profile.StoredSerums[id] = (profile.StoredSerums[id] or 0) + 1
			profile.SerumMastery[id] = Config.Serums.MaxMastery
		end
		refresh(target)
	end
	return target.DisplayName .. ": tutti gli 8 sieri in valigetta, maestria massima"
end
ACTIONS.RemoveSerum = function(_, target)
	local profile = S.DataService.Get(target)
	if profile then
		local state = S.PlayerService.GetState(target)
		if state.Transformed then
			S.ShifterService.Revert(target, "Admin")
		end
		profile.Serum = ""
		refresh(target)
	end
	return target.DisplayName .. ": siero rimosso"
end
ACTIONS.Transform = function(_, target)
	local ok, err = S.ShifterService.Transform(target)
	return if ok then target.DisplayName .. ": trasformazione" else (err or "Impossibile trasformarsi")
end

-- POTERI ----------------------------------------------------------------------------------------
local TOGGLES = {
	God = { Attribute = "AdminGod", Name = "Immortalità" },
	Gas = { Attribute = "AdminGas", Name = "Gas infinito" },
	OneShot = { Attribute = "AdminOneShot", Name = "Colpo unico" },
}
for key, toggle in TOGGLES do
	ACTIONS["Toggle" .. key] = function(_, target)
		local on = target:GetAttribute(toggle.Attribute) ~= true
		target:SetAttribute(toggle.Attribute, if on then true else nil)
		return ("%s: %s %s"):format(target.DisplayName, toggle.Name, if on then "ATTIVA" else "disattivata")
	end
end
ACTIONS.Speed = function(_, target, value)
	local mult = math.clamp(tonumber(value) or 1, 0.5, 4)
	target:SetAttribute("AdminSpeed", if mult == 1 then nil else mult)
	S.PlayerService.Refresh(target, true)
	return ("%s: velocità x%.1f"):format(target.DisplayName, mult)
end
ACTIONS.Heal = function(_, target)
	S.PlayerService.Heal(target, 1)
	pcall(S.PlayerService.RefillWeapons, target)
	if S.ShifterService then
		S.ShifterService.ResetEnergy(target)
	end
	return target.DisplayName .. ": vita, lame, gas ed energia al massimo"
end
ACTIONS.Respawn = function(_, target)
	S.PlayerService.Respawn(target)
	return target.DisplayName .. ": rinato"
end

-- MONDO -----------------------------------------------------------------------------------------
ACTIONS.Teleport = function(_, target, value)
	local zone = Zones.Get(value)
	if not zone then
		return "Zona sconosciuta"
	end
	S.PlayerService.Teleport(target, Zones.SpawnPoint(zone))
	return ("%s → %s"):format(target.DisplayName, zone.Name or zone.Id)
end
ACTIONS.BringTo = function(admin, target)
	local root = Util.GetRoot(admin.Character)
	if not root or target == admin then
		return "Scegli un altro giocatore come bersaglio"
	end
	S.PlayerService.Teleport(target, root.Position + root.CFrame.LookVector * 6)
	return target.DisplayName .. " portato da te"
end
ACTIONS.GoTo = function(admin, target)
	local root = Util.GetRoot(target.Character)
	if not root or target == admin then
		return "Scegli un altro giocatore come bersaglio"
	end
	S.PlayerService.Teleport(admin, root.Position + root.CFrame.LookVector * 6)
	return "Sei andato da " .. target.DisplayName
end
ACTIONS.SpawnTitan = function(admin, _, value)
	local class = Titans.Classes[value]
	local root = Util.GetRoot(admin.Character)
	local profile = S.DataService.Get(admin)
	if not class or not root or not profile then
		return "Classe di gigante sconosciuta"
	end
	local zoneId = admin:GetAttribute("Zone") or "PianureSud"
	local flat = Util.SafeUnit(Util.Flat(root.CFrame.LookVector))
	local pos = groundBelow(root.Position + flat * (40 + class.Height))
	S.TitanService.Spawn({ Class = class.Id, Level = profile.Level, Zone = zoneId, Position = pos, Duration = 600 })
	return class.Name .. " evocato davanti a te"
end
ACTIONS.SpawnBoss = function(admin, _, value)
	local def = Titans.Bosses[value]
	if not def then
		return "Boss sconosciuto"
	end
	local t = S.TitanService.SpawnBoss(value)
	if not t then
		return def.Name .. " è già in giro"
	end
	local zone = Zones.Get(def.Zone)
	if zone then
		S.PlayerService.Teleport(admin, Zones.SpawnPoint(zone))
	end
	return def.Name .. " evocato: ti ho portato nella sua zona"
end
ACTIONS.ClearTitans = function(admin)
	local root = Util.GetRoot(admin.Character)
	if not root then
		return nil
	end
	local list = nearbyTitans(root.Position, 400)
	for _, t in list do
		S.TitanService.Despawn(t)
	end
	return ("%d giganti rimossi qui intorno"):format(#list)
end
ACTIONS.KillTitans = function(admin)
	local root = Util.GetRoot(admin.Character)
	if not root then
		return nil
	end
	local list = nearbyTitans(root.Position, 400)
	for _, t in list do
		S.TitanService.ApplyDamage(t, admin, 1e9, "Nape", { Admin = true })
	end
	return ("%d giganti abbattuti (ricompense comprese)"):format(#list)
end
ACTIONS.Invasion = function(admin)
	local zoneId = admin:GetAttribute("Zone")
	if not zoneId or not Zones.Get(zoneId) then
		return "Entra in una zona con i giganti"
	end
	S.TitanService.StartInvasion(zoneId, 300)
	S.EventService.Announce("⚠️ INVASIONE!", "I giganti attaccano: " .. (Zones.Get(zoneId).Name or zoneId), "Boss")
	return "Invasione avviata"
end
ACTIONS.Weather = function(_, _, value)
	if type(value) ~= "string" or not S.LightingService.SetWeather(value) then
		return "Meteo sconosciuto"
	end
	return "Meteo: " .. value
end
ACTIONS.Time = function(_, _, value)
	local hour = tonumber(value) or 12
	Lighting.ClockTime = hour % 24
	return ("Ora del giorno: %02d:00"):format(math.floor(hour % 24))
end

-- STORIA ----------------------------------------------------------------------------------------
ACTIONS.Chapter = function(_, target, value)
	local profile = S.DataService.Get(target)
	local index = math.floor(tonumber(value) or 1)
	local chapter = Story.Chapters[index]
	if not profile or not chapter then
		return ("Capitolo da 1 a %d"):format(#Story.Chapters)
	end
	profile.Story.Chapter = index
	profile.Story.Step = 1
	profile.Story.Progress = 0
	profile.Story.Done = false
	S.DataService.MarkDirty(target)
	S.StoryService.RestartStep(target)
	return ("%s → %s"):format(target.DisplayName, chapter.Title)
end
ACTIONS.StoryStep = function(_, target)
	local _, step = S.StoryService.Current(target)
	if not step then
		return "Storia già completata"
	end
	S.StoryService.Advance(target)
	return "Obiettivo completato: " .. step.Objective
end
ACTIONS.StoryDone = function(_, target)
	local profile = S.DataService.Get(target)
	if profile then
		profile.Story.Chapter = #Story.Chapters
		profile.Story.Step = 1
		profile.Story.Done = true
		refresh(target)
	end
	return target.DisplayName .. ": storia completata"
end

-- SERVER ----------------------------------------------------------------------------------------
ACTIONS.Announce = function(admin, _, value)
	local text = if type(value) == "string" then string.sub(value, 1, 150) else ""
	if text == "" then
		return "Scrivi il messaggio"
	end
	-- il testo passa dal filtro di Roblox prima di essere mostrato a tutti
	local ok, filtered = pcall(function()
		local result = game:GetService("TextService"):FilterStringAsync(text, admin.UserId)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		return "Messaggio non inviato (filtro non disponibile)"
	end
	S.EventService.Announce("📢 " .. filtered, "— " .. admin.DisplayName, "Raro")
	return "Annuncio inviato"
end
ACTIONS.Kick = function(admin, target)
	if target == admin then
		return "Non puoi espellere te stesso"
	end
	if AdminService.IsAdmin(target) and not RunService:IsStudio() then
		return "Non puoi espellere un altro amministratore"
	end
	target:Kick("Sei stato espulso da un amministratore.")
	return target.Name .. " espulso"
end
ACTIONS.DoubleXP = function()
	local on = ReplicatedStorage:GetAttribute("EventoXP") ~= true
	ReplicatedStorage:SetAttribute("EventoXP", if on then true else nil)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("BonusXPEvento", if on then 1 else nil)
	end
	S.EventService.Announce(if on then "⭐ ESPERIENZA DOPPIA!" else "Evento terminato", if on then "Evento attivato da un amministratore" else "Esperienza tornata normale", "Raro")
	return if on then "Esperienza doppia per tutti ATTIVA" else "Esperienza doppia disattivata"
end

local function onAction(admin: Player, action: any, targetId: any, value: any)
	if type(action) ~= "string" or not AdminService.IsAdmin(admin) then
		return
	end
	local now = os.clock()
	if now - (lastAction[admin] or 0) < 0.25 then
		return
	end
	lastAction[admin] = now
	local fn = ACTIONS[action]
	if not fn then
		return
	end
	local target = admin
	if type(targetId) == "number" then
		target = Players:GetPlayerByUserId(targetId) or admin
	end
	local ok, result = pcall(fn, admin, target, value)
	if ok then
		if result then
			tell(admin, result)
		end
	else
		warn("[Admin] Errore in " .. action .. ": " .. tostring(result))
		tell(admin, "Errore: " .. tostring(result))
	end
end

function AdminService.Init(services)
	S = services
end

function AdminService.Start()
	local function setup(player: Player)
		if AdminService.IsAdmin(player) then
			player:SetAttribute("Admin", true)
		end
		if ReplicatedStorage:GetAttribute("EventoXP") then
			player:SetAttribute("BonusXPEvento", 1)
		end
	end
	for _, player in Players:GetPlayers() do
		task.spawn(setup, player)
	end
	Players.PlayerAdded:Connect(setup)
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
	Net.Event("AdminAction").OnServerEvent:Connect(onAction)
end

return AdminService
