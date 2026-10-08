--[[
	EnemyService
	Nemici umani: Polizia corrotta, Squadra Ombra, soldati di Valdoria, guardie di Vael
	e il boss "Il Corvo Nero". Si muovono con Humanoid:MoveTo e sparano a distanza.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Lib.Util)
local Signal = require(Shared.Lib.Signal)
local Net = require(Shared.Lib.Net)
local Enemies = require(Shared.Data.Enemies)
local Zones = require(Shared.Data.Zones)
local Leveling = require(Shared.Data.Leveling)
local Items = require(Shared.Data.Items)

local OutfitService = require(script.Parent.OutfitService)

local EnemyService = {}
EnemyService.Killed = Signal.new()

local S
local rng = Random.new()
local enemies: { [number]: any } = {}
local byModel: { [Model]: any } = {}
local nextUid = 0
local folder: Folder
local template: Model? = nil

local SKINS = {
	Color3.fromRGB(236, 196, 166),
	Color3.fromRGB(214, 162, 128),
	Color3.fromRGB(190, 140, 112),
	Color3.fromRGB(240, 206, 182),
}

-- Crea un corpo R15 di base (una sola volta, poi si clona)
local function getTemplate(): Model?
	if template then
		return template
	end
	local ok, model = pcall(function()
		local description = Instance.new("HumanoidDescription")
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if ok and model then
		template = model
		return model
	end
	warn("[EnemyService] Impossibile creare il modello R15: " .. tostring(model))
	return nil
end

local function colorBody(model: Model, skin: Color3)
	for _, name in { "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" } do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Color = skin
		end
	end
end

local function weaponFor(typeDef)
	if typeDef.Weapon == "Pistole" then
		return "PistoleOmbra"
	elseif typeDef.Weapon == "Lancia" then
		return "LanciaDirompente"
	end
	return "FucileValdoriano"
end

function EnemyService.Spawn(spec)
	local typeDef = Enemies.Types[spec.Type]
	local bossDef = spec.Boss and Enemies.Bosses[spec.Boss]
	if bossDef then
		typeDef = Enemies.Types[bossDef.Type]
	end
	if not typeDef then
		return nil
	end
	local base = getTemplate()
	if not base then
		return nil
	end
	local zone = Zones.Get(spec.Zone)
	local level = spec.Level or (bossDef and bossDef.Level) or 1
	local model = base:Clone()
	model.Name = if bossDef then bossDef.Name else typeDef.Name
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	if not humanoid or not root then
		model:Destroy()
		return nil
	end
	colorBody(model, SKINS[rng:NextInteger(1, #SKINS)])
	local hpMult = typeDef.HPMult * (if bossDef then bossDef.HPMult else 1)
	local maxHP = Enemies.HP(level, hpMult)
	humanoid.MaxHealth = maxHP
	humanoid.Health = maxHP
	humanoid.WalkSpeed = if bossDef then bossDef.Speed else typeDef.Speed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false

	OutfitService.Apply(model, {
		Uniform = typeDef.Uniform,
		Equipped = { Ranged = weaponFor(typeDef), Blade = if typeDef.Uniform == "Ombra" then "LameStandard" else nil },
		Look = { HairStyle = ({ "Corto", "Rasato", "Coda", "Ricci" })[rng:NextInteger(1, 4)], Hair = Color3.fromRGB(rng:NextInteger(20, 120), rng:NextInteger(15, 90), rng:NextInteger(10, 60)), Hat = typeDef.Uniform == "Valdoria" },
	})

	local pos = spec.Position
	if not pos and zone then
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber()) * zone.Radius * 0.8
		pos = zone.Center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	end
	pos = pos or Vector3.zero
	model:PivotTo(CFrame.new(pos + Vector3.new(0, 5, 0)))

	nextUid += 1
	local e = {
		Uid = nextUid,
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Type = typeDef,
		TypeId = spec.Type or bossDef.Type,
		Boss = bossDef,
		BossId = spec.Boss,
		Level = level,
		Zone = spec.Zone,
		ZoneDef = zone,
		Home = (zone and zone.Center) or pos,
		Damage = Enemies.Damage(level, typeDef.DmgMult * (if bossDef then bossDef.DmgMult else 1)),
		FireRate = if bossDef then bossDef.FireRate else typeDef.FireRate,
		Range = typeDef.Range,
		NextShot = os.clock() + rng:NextNumber(1, 2),
		NextMove = 0,
		NextHop = os.clock() + rng:NextNumber(3, 8),
		Damagers = {},
		Dead = false,
		Spawner = spec.Spawner,
	}
	model:SetAttribute("EnemyUid", e.Uid)
	model:SetAttribute("Name", model.Name)
	model:SetAttribute("Level", level)
	model:SetAttribute("MaxHP", maxHP)
	model:SetAttribute("HP", maxHP)
	model:SetAttribute("Boss", bossDef ~= nil)
	model:SetAttribute("BossTitle", bossDef and bossDef.Title or "")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = Config.CollisionGroups.NPC
		end
	end
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	CollectionService:AddTag(model, Config.Tags.Enemy)

	humanoid.Died:Connect(function()
		EnemyService.Kill(e, nil)
	end)

	enemies[e.Uid] = e
	byModel[model] = e
	return e
end

function EnemyService.GetFromPart(part: Instance?)
	local model = part and Util.FindAncestorWithAttribute(part, "EnemyUid")
	if model and model:IsA("Model") then
		return byModel[model]
	end
	return nil
end

-- RICOMPENSE E MORTE ------------------------------------------------------------------------

function EnemyService.Kill(e, killer: Player?)
	if e.Dead then
		return
	end
	e.Dead = true
	e.Model:SetAttribute("HP", 0)
	e.Model:SetAttribute("Dead", true)
	local contributors = {}
	for player, dmg in e.Damagers do
		if player.Parent and (dmg >= e.Humanoid.MaxHealth * Config.Combat.KillShareMin or player == killer) then
			table.insert(contributors, player)
		end
	end
	local def = e.Boss or e.Type
	local xpMult = if e.Boss then e.Boss.XPMult else e.Type.XP
	local goldMult = if e.Boss then e.Boss.GoldMult else e.Type.Gold
	for _, player in contributors do
		local profile = S.DataService.Get(player)
		if profile then
			local xp = S.PlayerService.AddXP(player, Leveling.KillXP(e.Level, xpMult), true)
			local gold = S.PlayerService.AddGold(player, Leveling.KillGold(e.Level, goldMult))
			profile.Kills.Enemies += 1
			Net.Event("HitConfirm"):FireClient(player, { Kind = "Kill", Name = e.Model.Name, XP = xp, Gold = gold, Boss = e.Boss ~= nil })
			if def.Drops then
				for _, drop in def.Drops do
					if rng:NextNumber() < drop.Chance then
						local count = rng:NextInteger(drop.Min or 1, drop.Max or 1)
						S.InventoryService.Give(player, drop.Id, count)
						local item = Items.Get(drop.Id)
						S.EventService.Notify(player, ("Bottino: %s x%d"):format(item and item.Name or drop.Id, count), "Ricompensa", 4)
					end
				end
			end
			if e.Boss and e.Boss.Fragments then
				local n = rng:NextInteger(e.Boss.Fragments[1], e.Boss.Fragments[2])
				S.InventoryService.Give(player, "FrammentoSiero", n)
				S.EventService.Notify(player, ("+%d Frammenti di Siero"):format(n), "Raro", 5)
			end
		end
	end
	EnemyService.Killed:Fire(e, killer, contributors)
	if e.Boss then
		S.EventService.Announce(e.Boss.Name .. " è stato sconfitto!", killer and ("Colpo finale di " .. killer.DisplayName) or "", "Vittoria")
	end
	S.EventService.Effect("EnemyDeath", { Model = e.Model }, e.Root.Position, 600)
	task.delay(3, function()
		enemies[e.Uid] = nil
		byModel[e.Model] = nil
		e.Model:Destroy()
	end)
	local spawner = e.Spawner
	if spawner then
		local index = table.find(spawner.Alive, e)
		if index then
			table.remove(spawner.Alive, index)
		end
		task.delay(if e.Boss then e.Boss.Respawn else rng:NextNumber(10, 18), function()
			if #spawner.Alive < spawner.Count then
				local new = EnemyService.Spawn({ Type = spawner.Type, Boss = spawner.Boss, Level = spawner.Level, Zone = spawner.Zone, Spawner = spawner })
				if new then
					table.insert(spawner.Alive, new)
					if new.Boss then
						S.EventService.Announce(new.Boss.Name .. " è apparso!", new.Boss.Title .. " - " .. (new.ZoneDef and new.ZoneDef.Name or ""), "Boss")
					end
				end
			end
		end)
	end
end

function EnemyService.ApplyDamage(e, attacker: Player?, amount: number)
	if not e or e.Dead then
		return nil
	end
	local humanoid = e.Humanoid
	local dealt = math.max(1, amount)
	humanoid.Health = math.max(0, humanoid.Health - dealt)
	e.Model:SetAttribute("HP", math.floor(humanoid.Health))
	if attacker then
		e.Damagers[attacker] = (e.Damagers[attacker] or 0) + dealt
		e.Target = attacker
	end
	if humanoid.Health <= 0 then
		EnemyService.Kill(e, attacker)
		return { Damage = dealt, Killed = true }
	end
	return { Damage = dealt, Killed = false }
end

function EnemyService.DamageInRadius(center: Vector3, radius: number, amount: number, attacker: Player?)
	local results = {}
	for _, e in enemies do
		if not e.Dead and (e.Root.Position - center).Magnitude <= radius + 3 then
			local r = EnemyService.ApplyDamage(e, attacker, amount)
			if r then
				table.insert(results, { Enemy = e, Result = r, Position = e.Root.Position })
			end
		end
	end
	return results
end

-- INTELLIGENZA ---------------------------------------------------------------------------------

local shotParams = RaycastParams.new()
shotParams.FilterType = Enum.RaycastFilterType.Exclude

local function shoot(e, targetPlayer: Player, targetRoot: BasePart)
	local origin = e.Root.Position + Vector3.new(0, 1.5, 0)
	local aim = targetRoot.Position + targetRoot.AssemblyLinearVelocity * 0.15
	local spread = math.clamp((aim - origin).Magnitude / 300, 0.01, 0.12)
	local dir = (aim - origin).Unit + Vector3.new(rng:NextNumber(-spread, spread), rng:NextNumber(-spread, spread), rng:NextNumber(-spread, spread))
	shotParams.FilterDescendantsInstances = { folder, workspace:FindFirstChild(Config.Folders.Titans) or folder }
	local result = workspace:Raycast(origin, dir.Unit * (e.Range * 1.4), shotParams)
	local hitPos = if result then result.Position else origin + dir.Unit * e.Range
	local kind = if e.Type.Explosive then "Spear" else "Bullet"
	S.EventService.EffectFast("Tracer", { From = origin, To = hitPos, Kind = kind }, origin, 600)
	if e.Type.Explosive then
		task.delay(0.35, function()
			for _, player in Players:GetPlayers() do
				local root = Util.GetRoot(player.Character)
				if root and (root.Position - hitPos).Magnitude < 14 then
					S.PlayerService.Damage(player, e.Damage * 1.6, { Explosive = true, Cause = e.Model.Name })
				end
			end
			S.EventService.Effect("Explosion", { Position = hitPos, Radius = 14 }, hitPos, 700)
		end)
		return
	end
	if result and result.Instance and result.Instance:IsDescendantOf(targetPlayer.Character :: Model) then
		S.PlayerService.Damage(targetPlayer, e.Damage, { Cause = e.Model.Name })
	end
end

local function think(e, now: number)
	if e.Dead then
		return
	end
	local best, bestDist = nil, 140
	for _, player in Players:GetPlayers() do
		local root = Util.GetRoot(player.Character)
		local humanoid = Util.GetHumanoid(player.Character)
		if root and humanoid and humanoid.Health > 0 and not S.PlayerService.InCutscene(player) then
			local d = (root.Position - e.Root.Position).Magnitude
			if player == e.Target then
				d *= 0.6
			end
			if d < bestDist then
				best, bestDist = { Player = player, Root = root }, d
			end
		end
	end
	local fromHome = Util.FlatDistance(e.Root.Position, e.Home)
	local leash = (e.ZoneDef and e.ZoneDef.Radius or 120) * 1.4
	if fromHome > leash then
		best = nil
		e.Target = nil
		e.Humanoid:MoveTo(e.Home)
		return
	end
	if best then
		local targetPos = best.Root.Position
		local dist = (targetPos - e.Root.Position).Magnitude
		if now >= e.NextMove then
			e.NextMove = now + rng:NextNumber(0.8, 1.6)
			local desired = e.Range * 0.55
			local toTarget = Util.SafeUnit(Util.Flat(targetPos - e.Root.Position))
			local side = Vector3.new(-toTarget.Z, 0, toTarget.X) * rng:NextNumber(-14, 14)
			local goal
			if dist > desired + 10 then
				goal = e.Root.Position + toTarget * math.min(30, dist - desired) + side
			elseif dist < desired - 15 then
				goal = e.Root.Position - toTarget * 18 + side
			else
				goal = e.Root.Position + side
			end
			e.Humanoid:MoveTo(goal)
		end
		-- salto con i Rampini (Squadra Ombra)
		if e.Type.ODMHop and now >= e.NextHop then
			e.NextHop = now + rng:NextNumber(4, 8)
			local up = Vector3.new(rng:NextNumber(-30, 30), 70, rng:NextNumber(-30, 30))
			e.Root.AssemblyLinearVelocity = up
			S.EventService.EffectFast("EnemyHop", { Model = e.Model }, e.Root.Position, 500)
		end
		if dist <= e.Range and now >= e.NextShot then
			local burst = (e.Boss and e.Boss.Burst) or 1
			e.NextShot = now + e.FireRate * rng:NextNumber(0.85, 1.2) * burst
			e.Model:SetAttribute("ShotT", workspace:GetServerTimeNow())
			for i = 1, burst do
				task.delay((i - 1) * 0.18, function()
					if not e.Dead and best.Root.Parent then
						shoot(e, best.Player, best.Root)
					end
				end)
			end
		end
	else
		if now >= e.NextMove then
			e.NextMove = now + rng:NextNumber(3, 7)
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(0, (e.ZoneDef and e.ZoneDef.Radius or 60) * 0.6)
			e.Humanoid:MoveTo(e.Home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		end
	end
end

local function spawnAll()
	for _, zone in Zones.List do
		if zone.Enemies then
			for _, entry in zone.Enemies do
				local spawner = { Type = entry.Type, Level = entry.Level, Zone = zone.Id, Count = entry.Count, Alive = {} }
				for _ = 1, entry.Count do
					local e = EnemyService.Spawn({ Type = entry.Type, Level = entry.Level, Zone = zone.Id, Spawner = spawner })
					if e then
						table.insert(spawner.Alive, e)
					end
				end
				task.wait()
			end
		end
		if zone.HumanBosses then
			for _, bossId in zone.HumanBosses do
				local def = Enemies.Bosses[bossId]
				local spawner = { Boss = bossId, Level = def.Level, Zone = zone.Id, Count = 1, Alive = {} }
				task.delay(rng:NextNumber(20, 50), function()
					local e = EnemyService.Spawn({ Boss = bossId, Level = def.Level, Zone = zone.Id, Spawner = spawner })
					if e then
						table.insert(spawner.Alive, e)
						S.EventService.Announce(def.Name .. " è apparso!", def.Title .. " - " .. zone.Name, "Boss")
					end
				end)
			end
		end
	end
end

function EnemyService.Init(services)
	S = services
end

function EnemyService.Start()
	folder = workspace:WaitForChild(Config.Folders.Enemies) :: Folder
	S.WorldBuilder.WaitReady()
	spawnAll()
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for _, e in enemies do
				-- pensa solo se un giocatore è vicino
				local active = false
				for _, player in Players:GetPlayers() do
					local root = Util.GetRoot(player.Character)
					if root and (root.Position - e.Root.Position).Magnitude < 400 then
						active = true
						break
					end
				end
				if active then
					local ok, err = pcall(think, e, now)
					if not ok then
						warn("[EnemyService] " .. tostring(err))
					end
				end
			end
		end
	end)
end

return EnemyService
