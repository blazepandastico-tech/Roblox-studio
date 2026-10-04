--[[
	PlayerService
	Gestisce i personaggi dei giocatori: comparsa, statistiche, salute,
	esperienza e livelli, oro, zona attuale, morte e rinascita.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Lib.Util)
local Signal = require(Shared.Lib.Signal)
local Net = require(Shared.Lib.Net)
local Zones = require(Shared.Data.Zones)
local Leveling = require(Shared.Data.Leveling)
local StatsCalc = require(Shared.Data.StatsCalc)
local Bloodlines = require(Shared.Data.Bloodlines)
local Items = require(Shared.Data.Items)

local OutfitService = require(script.Parent.OutfitService)

local PlayerService = {}
PlayerService.LevelUp = Signal.new()
PlayerService.ZoneEntered = Signal.new()
PlayerService.CharacterReady = Signal.new()
PlayerService.Died = Signal.new()

local S
local states: { [Player]: any } = {}
local statsCache: { [Player]: any } = {}

local function newState()
	return {
		BladeDurability = 0,
		BladeSpares = 0,
		RangedAmmo = 0,
		LastAttack = 0,
		LastRanged = 0,
		LastReload = 0,
		IFramesUntil = 0,
		LastDodge = 0,
		GrabbedBy = nil,
		Transformed = false,
		SkillCooldowns = {},
		ActiveSkill = nil,
		LastDamaged = 0,
		AwakenedUntil = 0,
		AwakenReadyAt = 0,
		StunnedUntil = 0,
		Dead = false,
		Zone = nil,
	}
end

function PlayerService.GetState(player: Player)
	local state = states[player]
	if not state then
		state = newState()
		states[player] = state
	end
	return state
end

function PlayerService.Stats(player: Player)
	local cached = statsCache[player]
	if cached then
		return cached
	end
	local profile = S.DataService.Get(player)
	if not profile then
		return StatsCalc.Compute(S.DataService.Template)
	end
	cached = StatsCalc.Compute(profile)
	statsCache[player] = cached
	return cached
end

function PlayerService.InvalidateStats(player: Player)
	statsCache[player] = nil
end

local function getHumanoid(player: Player): Humanoid?
	return Util.GetHumanoid(player.Character)
end

-- Targhetta sopra la testa (nome, livello, stirpe)
local function updateNameplate(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local profile = S.DataService.Get(player)
	if not head or not profile then
		return
	end
	local gui = head:FindFirstChild("Targhetta") :: BillboardGui?
	if not gui then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "Targhetta"
		billboard.Size = UDim2.fromOffset(220, 54)
		billboard.StudsOffset = Vector3.new(0, 2.6, 0)
		billboard.MaxDistance = 140
		billboard.LightInfluence = 0
		billboard.ResetOnSpawn = false
		local name = Instance.new("TextLabel")
		name.Name = "Nome"
		name.BackgroundTransparency = 1
		name.Size = UDim2.new(1, 0, 0.58, 0)
		name.Font = Enum.Font.Merriweather
		name.TextScaled = true
		name.TextColor3 = Color3.fromRGB(245, 238, 222)
		name.TextStrokeTransparency = 0.4
		name.Parent = billboard
		local sub = Instance.new("TextLabel")
		sub.Name = "Info"
		sub.BackgroundTransparency = 1
		sub.Position = UDim2.fromScale(0, 0.58)
		sub.Size = UDim2.new(1, 0, 0.42, 0)
		sub.Font = Enum.Font.GothamBold
		sub.TextScaled = true
		sub.TextStrokeTransparency = 0.5
		sub.Parent = billboard
		billboard.Parent = head
		gui = billboard
	end
	local bloodline = Bloodlines.Get(profile.Bloodline)
	local nameLabel = (gui :: BillboardGui):FindFirstChild("Nome") :: TextLabel
	local infoLabel = (gui :: BillboardGui):FindFirstChild("Info") :: TextLabel
	nameLabel.Text = player.DisplayName
	infoLabel.Text = ("Lv. %d  •  %s"):format(profile.Level, bloodline.Name)
	infoLabel.TextColor3 = bloodline.Color
end

local function setAttributes(player: Player)
	local profile = S.DataService.Get(player)
	if not profile then
		return
	end
	local stats = PlayerService.Stats(player)
	local state = PlayerService.GetState(player)
	player:SetAttribute("Level", profile.Level)
	player:SetAttribute("Bloodline", profile.Bloodline)
	player:SetAttribute("MaxGas", stats.ODMGas)
	player:SetAttribute("ODMRange", stats.ODMRange)
	player:SetAttribute("ODMReel", stats.ODMReel)
	player:SetAttribute("GasEfficiency", stats.GasEfficiency)
	player:SetAttribute("BladeDurMax", stats.BladeDurability)
	player:SetAttribute("BladeSparesMax", stats.BladeSpares)
	player:SetAttribute("RangedAmmoMax", stats.RangedAmmo)
	player:SetAttribute("BladeDur", state.BladeDurability)
	player:SetAttribute("BladeSpares", state.BladeSpares)
	player:SetAttribute("RangedAmmo", state.RangedAmmo)
end

function PlayerService.SyncResources(player: Player)
	local state = PlayerService.GetState(player)
	player:SetAttribute("BladeDur", state.BladeDurability)
	player:SetAttribute("BladeSpares", state.BladeSpares)
	player:SetAttribute("RangedAmmo", state.RangedAmmo)
end

-- Ricarica lame e munizioni al massimo
function PlayerService.RefillWeapons(player: Player)
	local stats = PlayerService.Stats(player)
	local state = PlayerService.GetState(player)
	state.BladeDurability = stats.BladeDurability
	state.BladeSpares = stats.BladeSpares
	state.RangedAmmo = stats.RangedAmmo
	PlayerService.SyncResources(player)
end

-- Applica statistiche ed equipaggiamento al personaggio
function PlayerService.Refresh(player: Player, keepResources: boolean?)
	PlayerService.InvalidateStats(player)
	local profile = S.DataService.Get(player)
	local stats = PlayerService.Stats(player)
	local state = PlayerService.GetState(player)
	local character = player.Character
	local humanoid = getHumanoid(player)
	if humanoid and not state.Transformed then
		local fraction = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
		humanoid.MaxHealth = stats.MaxHealth
		humanoid.Health = math.clamp(fraction, 0.05, 1) * stats.MaxHealth
		humanoid.WalkSpeed = stats.WalkSpeed * (player:GetAttribute("AdminSpeed") or 1)
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = Config.Player.JumpHeight
	end
	if not keepResources then
		state.BladeDurability = math.min(state.BladeDurability, stats.BladeDurability)
		state.BladeSpares = math.min(state.BladeSpares, stats.BladeSpares)
		state.RangedAmmo = math.min(state.RangedAmmo, stats.RangedAmmo)
	end
	if character and profile and not state.Transformed then
		OutfitService.Apply(character, { Equipped = profile.Equipped })
	end
	setAttributes(player)
	updateNameplate(player)
	S.DataService.MarkDirty(player)
end

local function applyCollisionGroup(character: Model, groupName: string)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = groupName
		end
	end
end

function PlayerService.SetCollisionGroup(character: Model, groupName: string)
	applyCollisionGroup(character, groupName)
end

-- ESPERIENZA E ORO ----------------------------------------------------------------------

function PlayerService.AddXP(player: Player, amount: number, silent: boolean?): number
	local profile = S.DataService.Get(player)
	if not profile or amount <= 0 then
		return 0
	end
	local stats = PlayerService.Stats(player)
	-- bonus della community (amici nel server, gruppo): vedi CommunityService
	local mult = 1 + stats.XPBonus + (player:GetAttribute("BonusXP") or 0) + (player:GetAttribute("BonusXPEvento") or 0)
	if (profile.Buffs.XPUntil or 0) > os.time() then
		mult *= 2
	end
	local total = math.floor(amount * mult)
	local before = profile.Level
	local gained = Leveling.AddXP(profile, total)
	if gained > 0 then
		PlayerService.Refresh(player, true)
		local humanoid = getHumanoid(player)
		if humanoid and not PlayerService.GetState(player).Transformed then
			humanoid.Health = humanoid.MaxHealth
		end
		Net.Event("LevelUp"):FireClient(player, profile.Level, gained)
		local root = Util.GetRoot(player.Character)
		if root and S.EventService then
			S.EventService.Effect("LevelUp", { Character = player.Character }, root.Position, 300)
		end
		local leaderstats = player:FindFirstChild("leaderstats")
		local levelValue = leaderstats and leaderstats:FindFirstChild("Livello") :: IntValue?
		if levelValue then
			levelValue.Value = profile.Level
		end
		PlayerService.LevelUp:Fire(player, profile.Level, before)
	elseif not silent then
		S.DataService.MarkDirty(player)
	end
	S.DataService.MarkDirty(player)
	return total
end

function PlayerService.AddGold(player: Player, amount: number): number
	local profile = S.DataService.Get(player)
	if not profile or amount <= 0 then
		return 0
	end
	local stats = PlayerService.Stats(player)
	local mult = 1 + stats.GoldBonus + (player:GetAttribute("BonusGold") or 0)
	if (profile.Buffs.GoldUntil or 0) > os.time() then
		mult *= 2
	end
	local total = math.floor(amount * mult)
	profile.Gold += total
	S.DataService.MarkDirty(player)
	return total
end

function PlayerService.SpendGold(player: Player, amount: number): boolean
	local profile = S.DataService.Get(player)
	if not profile or amount < 0 or profile.Gold < amount then
		return false
	end
	profile.Gold -= math.floor(amount)
	S.DataService.MarkDirty(player)
	return true
end

-- Ricompense generiche { XP, Gold, Items }
function PlayerService.GiveRewards(player: Player, rewards, reason: string?)
	local xp = if rewards.XP and rewards.XP > 0 then PlayerService.AddXP(player, rewards.XP, true) else 0
	local gold = if rewards.Gold and rewards.Gold > 0 then PlayerService.AddGold(player, rewards.Gold) else 0
	local parts = {}
	if xp > 0 then
		table.insert(parts, "+" .. Util.Abbreviate(xp) .. " XP")
	end
	if gold > 0 then
		table.insert(parts, "+" .. Util.Abbreviate(gold) .. " oro")
	end
	if rewards.Items then
		for id, count in rewards.Items do
			S.InventoryService.Give(player, id, count)
			local def = Items.Get(id)
			table.insert(parts, ("%s x%d"):format(def and def.Name or id, count))
		end
	end
	if #parts > 0 and S.EventService then
		S.EventService.Notify(player, (reason and (reason .. ": ") or "") .. table.concat(parts, "  •  "), "Ricompensa", 4)
	end
end

-- DANNI -------------------------------------------------------------------------------

function PlayerService.IsInvulnerable(player: Player): boolean
	if player:GetAttribute("AdminGod") == true then
		return true
	end
	local state = PlayerService.GetState(player)
	if os.clock() < state.IFramesUntil then
		return true
	end
	if S.ShifterService and S.ShifterService.IsInvulnerable(player) then
		return true
	end
	return false
end

-- Infligge danni a un giocatore (difesa, invulnerabilità, forma di gigante)
function PlayerService.Damage(player: Player, amount: number, info): number
	local humanoid = getHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return 0
	end
	info = info or {}
	if not info.IgnoreIFrames and PlayerService.IsInvulnerable(player) then
		return 0
	end
	local stats = PlayerService.Stats(player)
	local reduction = stats.Defense
	if info.Explosive then
		reduction = math.min(0.85, reduction + stats.ExplosiveResist)
	end
	local state = PlayerService.GetState(player)
	if state.Transformed and S.ShifterService then
		reduction = math.min(0.9, reduction + S.ShifterService.DamageReduction(player))
	end
	local final = math.max(1, amount * (1 - reduction))
	if state.Transformed and S.ShifterService and humanoid.Health - final <= 1 then
		-- la nuca del gigante è stata distrutta: il giocatore viene espulso, non muore
		humanoid.Health = 1
		state.LastDamaged = os.clock()
		S.ShifterService.Revert(player, "Espulso")
		return final
	end
	humanoid:TakeDamage(final)
	state.LastDamaged = os.clock()
	if humanoid.Health <= 0 and info.Cause then
		state.DeathCause = info.Cause
	end
	return final
end

function PlayerService.Knockback(player: Player, velocity: Vector3, stun: number?)
	Net.Event("Knockback"):FireClient(player, velocity, stun or 0)
end

function PlayerService.Heal(player: Player, fraction: number)
	local humanoid = getHumanoid(player)
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * fraction)
	end
end

-- SPOSTAMENTI -------------------------------------------------------------------------

function PlayerService.Teleport(player: Player, position: Vector3)
	if S.ODMService then
		S.ODMService.Grace(player, 2)
	end
	pcall(function()
		player:RequestStreamAroundAsync(position, 4)
	end)
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(position + Vector3.new(0, 4, 0)))
		local root = Util.GetRoot(character)
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

local function spawnPositionFor(player: Player): Vector3
	local profile = S.DataService.Get(player)
	local zone = Zones.Get(profile and profile.SpawnZone) or Zones.Get("CampoAddestramento")
	return Zones.SpawnPoint(zone)
end

-- Aspetto del giocatore (preso una volta sola dal suo avatar Roblox)
local descriptions: { [Player]: HumanoidDescription } = {}

local function descriptionFor(player: Player): HumanoidDescription
	local cached = descriptions[player]
	if cached then
		return cached
	end
	local ok, desc = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(player.UserId)
	end)
	local result = if ok and desc then desc else Instance.new("HumanoidDescription")
	descriptions[player] = result
	return result
end

-- Il gioco è fatto per personaggi R15 (gomiti, ginocchia, busto snodato): lo creiamo sempre
-- in R15, anche se nelle impostazioni del gioco l'avatar è R6.
local function buildR15Character(player: Player, position: Vector3): Model
	local model = Players:CreateHumanoidModelFromDescription(descriptionFor(player), Enum.HumanoidRigType.R15)
	model.Name = player.Name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = player.DisplayName
	end
	model:PivotTo(CFrame.new(position + Vector3.new(0, 4, 0)))
	return model
end

local function spawnCharacter(player: Player)
	if not player.Parent then
		return
	end
	local position = spawnPositionFor(player)
	pcall(function()
		player:RequestStreamAroundAsync(position, 6)
	end)
	local ok, err = pcall(function()
		local model = buildR15Character(player, position)
		local old = player.Character
		player.Character = model
		model.Parent = workspace
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root:SetNetworkOwner(player)
		end
		if old and old ~= model then
			old:Destroy()
		end
	end)
	if not ok then
		warn("[PlayerService] Creazione del personaggio R15 fallita, uso quello standard: " .. tostring(err))
		local ok2, err2 = pcall(function()
			player:LoadCharacter()
		end)
		if not ok2 then
			warn("[PlayerService] LoadCharacter fallito: " .. tostring(err2))
		end
	end
end

function PlayerService.Respawn(player: Player)
	spawnCharacter(player)
end

local function onCharacterAdded(player: Player, character: Model)
	local state = PlayerService.GetState(player)
	state.Dead = false
	state.Transformed = false
	state.GrabbedBy = nil
	state.ActiveSkill = nil
	state.StunnedUntil = 0
	state.DeathCause = nil
	player:SetAttribute("Transformed", false)
	player:SetAttribute("Grabbed", false)

	local position = spawnPositionFor(player)
	character:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)))

	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.BreakJointsOnDeath = false
	applyCollisionGroup(character, Config.CollisionGroups.Players)
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") and not state.Transformed then
			d.CollisionGroup = Config.CollisionGroups.Players
		end
	end)

	PlayerService.RefillWeapons(player)
	PlayerService.Refresh(player)
	humanoid.Health = humanoid.MaxHealth

	humanoid.Died:Connect(function()
		if state.Dead then
			return
		end
		state.Dead = true
		PlayerService.Died:Fire(player, state.DeathCause)
		if S.EventService then
			local cause = state.DeathCause
			if cause == "Divorato" then
				S.EventService.Notify(player, "Sei stato divorato. Rinasci al punto di rinascita...", "Errore", 4)
			end
		end
		task.delay(Config.Player.RespawnDelay, function()
			if player.Parent and player.Character == character then
				spawnCharacter(player)
			end
		end)
	end)

	PlayerService.CharacterReady:Fire(player, character)
end

local function setupLeaderstats(player: Player, profile)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Livello"
	level.Value = profile.Level
	level.Parent = leaderstats
	local kills = Instance.new("IntValue")
	kills.Name = "Giganti"
	kills.Value = profile.Kills.Titans
	kills.Parent = leaderstats
	leaderstats.Parent = player
end

function PlayerService.UpdateKillStat(player: Player)
	local profile = S.DataService.Get(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local kills = leaderstats and leaderstats:FindFirstChild("Giganti") :: IntValue?
	if profile and kills then
		kills.Value = profile.Kills.Titans
	end
end

local function onProfileLoaded(player: Player, profile)
	setupLeaderstats(player, profile)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	S.WorldBuilder.WaitReady()
	spawnCharacter(player)
	if profile._NewBloodline and S.EventService then
		task.delay(6, function()
			local bloodline = Bloodlines.Get(profile.Bloodline)
			S.EventService.AnnounceTo(player, "La tua Stirpe: " .. bloodline.Name, bloodline.Description, "Raro")
		end)
		profile._NewBloodline = nil
	end
end

-- ZONE ----------------------------------------------------------------------------------

local function trackZones()
	while true do
		task.wait(0.5)
		for _, player in Players:GetPlayers() do
			local root = Util.GetRoot(player.Character)
			local profile = S.DataService.Get(player)
			if root and profile and root.Position.Y < -520 then
				-- caduto nel vuoto (sotto anche alle grotte): torna al punto di rinascita
				root.AssemblyLinearVelocity = Vector3.zero
				PlayerService.Teleport(player, spawnPositionFor(player))
				if S.EventService then
					S.EventService.Notify(player, "Sei caduto nel vuoto: ti abbiamo riportato alla base.", "Info", 3)
				end
			elseif root and profile then
				local zone = Zones.Find(root.Position)
				local id = zone and zone.Id or ""
				local state = PlayerService.GetState(player)
				if state.Zone ~= id then
					state.Zone = id
					player:SetAttribute("Zone", id)
					if zone then
						if zone.Safe and zone.Spawn and profile.SpawnZone ~= zone.Id then
							profile.SpawnZone = zone.Id
							S.EventService.Notify(player, "Punto di rinascita impostato: " .. zone.Name, "Info", 3)
						end
						if not profile.Visited[zone.Id] then
							profile.Visited[zone.Id] = true
						end
						S.DataService.MarkDirty(player)
						PlayerService.ZoneEntered:Fire(player, zone.Id)
					end
				end
			end
		end
	end
end

-- STATISTICHE -----------------------------------------------------------------------------

local function allocate(player: Player, statName: any, amount: any)
	if type(statName) ~= "string" or not table.find(StatsCalc.StatNames, statName) then
		return
	end
	local profile = S.DataService.Get(player)
	if not profile then
		return
	end
	local n
	if amount == "max" then
		n = profile.StatPoints
	elseif type(amount) == "number" then
		n = math.floor(amount)
	else
		return
	end
	local current = profile.Stats[statName] or 0
	n = math.clamp(n, 0, math.min(profile.StatPoints, Config.StatCap - current))
	if n <= 0 then
		return
	end
	profile.StatPoints -= n
	profile.Stats[statName] = current + n
	PlayerService.Refresh(player, true)
end

function PlayerService.ResetStats(player: Player): (boolean, string?)
	local profile = S.DataService.Get(player)
	if not profile then
		return false, nil
	end
	local cost = Config.StatResetCost * profile.Level
	if not PlayerService.SpendGold(player, cost) then
		return false, ("Servono %s oro."):format(Util.FormatNumber(cost))
	end
	local total = 0
	for _, name in StatsCalc.StatNames do
		total += profile.Stats[name] or 0
		profile.Stats[name] = 0
	end
	profile.StatPoints += total
	PlayerService.Refresh(player, true)
	return true, nil
end

function PlayerService.Init(services)
	S = services
	S.DataService.ExtraProvider = function(player: Player, _profile)
		return { Stats = PlayerService.Stats(player) }
	end
end

function PlayerService.Start()
	S.DataService.Loaded:Connect(onProfileLoaded)
	Players.PlayerRemoving:Connect(function(player)
		descriptions[player] = nil
		states[player] = nil
		statsCache[player] = nil
	end)

	Net.Event("AllocateStat").OnServerEvent:Connect(allocate)
	Net.Event("ClientReady").OnServerEvent:Connect(function(player)
		S.DataService.SyncNow(player)
		if S.StoryService then
			S.StoryService.OnClientReady(player)
		end
	end)
	Net.Event("SaveSettings").OnServerEvent:Connect(function(player, settings)
		local profile = S.DataService.Get(player)
		if not profile or type(settings) ~= "table" then
			return
		end
		for key, value in settings do
			if profile.Settings[key] ~= nil and type(value) == type(profile.Settings[key]) then
				profile.Settings[key] = value
			end
		end
		S.DataService.MarkDirty(player)
	end)
	Net.Event("Dodge").OnServerEvent:Connect(function(player)
		local state = PlayerService.GetState(player)
		local now = os.clock()
		if now - state.LastDodge >= Config.ODM.DodgeCooldown * 0.85 then
			state.LastDodge = now
			state.IFramesUntil = now + Config.ODM.DodgeIFrames + 0.1
			if S.ODMService then
				S.ODMService.Spend(player, S.ODMService.DodgeCost(player))
			end
		end
	end)

	task.spawn(trackZones)
end

return PlayerService
