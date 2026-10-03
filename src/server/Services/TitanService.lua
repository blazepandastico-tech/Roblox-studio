--[[
	TitanService
	Fa nascere, muovere e combattere tutti i giganti (puri, anomali e boss).
	- Il server decide posizione, stato e attacchi (AlignPosition per un movimento fluido).
	- I client animano i giganti leggendo gli attributi del modello (State, Action, ActionT...).
	- Solo un colpo alla NUCA uccide davvero: i colpi al corpo fanno pochi danni,
	  quelli agli arti li recidono (le gambe recise fanno cadere il gigante).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Lib.Util)
local Signal = require(Shared.Lib.Signal)
local Net = require(Shared.Lib.Net)
local Titans = require(Shared.Data.Titans)
local Zones = require(Shared.Data.Zones)
local NPCs = require(Shared.Data.NPCs)
local Leveling = require(Shared.Data.Leveling)
local Items = require(Shared.Data.Items)
local W = require(Shared.Data.WorldLayout)
local TitanBuilder = require(Shared.Anim.TitanBuilder)

local TitanService = {}
TitanService.Killed = Signal.new()
TitanService.Spawned = Signal.new()

local S
local rng = Random.new()
local titans: { [number]: any } = {}
local byModel: { [Model]: any } = {}
local spawners = {}
local bossStates: { [string]: any } = {}
local nextUid = 0
local titanFolder: Folder
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include

local LIMBS = { "RightArm", "LeftArm", "RightLeg", "LeftLeg" }

local function serverTime(): number
	return workspace:GetServerTimeNow()
end

-- TERRENO --------------------------------------------------------------------------------

local function groundY(pos: Vector3, zone): number
	groundParams.FilterDescendantsInstances = { workspace.Terrain }
	local underground = zone and zone.Underground
	local originY = if underground then zone.Center.Y + 55 else 520
	local depth = if underground then 140 else 700
	local result = workspace:Raycast(Vector3.new(pos.X, originY, pos.Z), Vector3.new(0, -depth, 0), groundParams)
	if result then
		return result.Position.Y
	end
	return if underground then zone.Center.Y else W.GroundY
end

local function randomPointIn(zone, margin: number?): Vector3
	local npcSpots = {}
	for _, npc in NPCs.List do
		if npc.Zone == zone.Id then
			table.insert(npcSpots, zone.Center + npc.Offset)
		end
	end
	for _ = 1, 20 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber()) * zone.Radius * (margin or 0.85)
		local pos = zone.Center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local ok = true
		for _, spot in npcSpots do
			if Util.FlatDistance(spot, pos) < 40 then
				ok = false
				break
			end
		end
		if ok then
			return pos
		end
	end
	return zone.Center
end

-- CREAZIONE --------------------------------------------------------------------------------

local function setAttr(t, name: string, value: any)
	if t.Attr[name] ~= value then
		t.Attr[name] = value
		t.Model:SetAttribute(name, value)
	end
end

local function limbHP(t): number
	return math.max(10, t.MaxHP * 0.18)
end

function TitanService.Spawn(spec)
	local def, height, look, name, classMult, damageMult, hpMult, speed
	local kind = spec.Kind or "Pure"
	if spec.Boss then
		def = Titans.Bosses[spec.Boss]
		height = def.Height
		look = def.Look
		name = def.Name
		classMult = 1.6
		damageMult = def.DmgMult
		hpMult = def.HPMult
		speed = def.Speed
		kind = "Boss"
	else
		def = Titans.Classes[spec.Class]
		if not def then
			return nil
		end
		height = def.Height * rng:NextNumber(0.92, 1.1)
		look = spec.Look or def.Look or "Puro"
		name = def.Name
		classMult = def.NapeHP
		damageMult = def.Damage
		hpMult = 1
		speed = def.Speed
		if def.Dummy then
			kind = "Dummy"
		end
	end
	local abnormal = spec.Abnormal == true or (def.Abnormal == true)
	if abnormal and not spec.Boss then
		name = "Anomalo - " .. name
	end
	if look == "Cristallo" then
		name = name:gsub("Gigante", "Gigante di Cristallo")
	end
	local zone = Zones.Get(spec.Zone)
	local level = spec.Level or def.Level or 1
	local seed = rng:NextInteger(1, 2 ^ 30)
	local model = TitanBuilder.Build({ Height = height, Look = look, Seed = seed, Name = name })
	local root = model.PrimaryPart :: BasePart
	local hip = model:GetAttribute("HipHeight") :: number
	local pos = spec.Position or (zone and randomPointIn(zone)) or Vector3.zero
	local gy = groundY(pos, zone)
	local yaw = spec.Yaw or rng:NextNumber(0, math.pi * 2)
	local cf = CFrame.new(pos.X, gy + hip, pos.Z) * CFrame.Angles(0, yaw, 0)
	model:PivotTo(cf)

	nextUid += 1
	local uid = nextUid
	local maxHP = Titans.NapeHP(Config, classMult, level) * hpMult
	if spec.HPMult then
		maxHP *= spec.HPMult
	end

	local t = {
		Uid = uid,
		Model = model,
		Root = root,
		Kind = kind,
		Def = def,
		ClassId = spec.Class,
		BossId = spec.Boss,
		Name = name,
		Level = level,
		Height = height,
		Hip = hip,
		Speed = speed,
		Abnormal = abnormal,
		Look = look,
		Zone = spec.Zone,
		ZoneDef = zone,
		MaxHP = maxHP,
		HP = maxHP,
		Damage = Titans.Damage(Config, damageMult, level),
		Limbs = {},
		State = "Idle",
		Yaw = yaw,
		Position = cf.Position,
		Home = (zone and zone.Center) or pos,
		HomeRadius = (zone and zone.Radius) or 150,
		Cooldowns = {},
		Damagers = {},
		BlindUntil = 0,
		StunUntil = 0,
		FrozenUntil = 0,
		HardenUntil = 0,
		SteamUntil = 0,
		FallenUntil = 0,
		ArmorBrokenUntil = 0,
		ArmorHP = 0,
		ArmorMax = 0,
		NextWander = 0,
		Attr = {},
		Active = false,
		Temporary = spec.Duration and (os.clock() + spec.Duration) or nil,
		Owner = spec.Owner,
		March = spec.March,
		Invasion = spec.Invasion,
		Raid = spec.Raid,
		Spawner = spec.Spawner,
		Phase = 1,
		SpawnTime = os.clock(),
	}
	if kind == "Boss" and def.Armored then
		t.ArmorMax = maxHP * (def.ArmorShare or 0.12)
		t.ArmorHP = t.ArmorMax
	end
	for _, limb in LIMBS do
		t.Limbs[limb] = { HP = limbHP(t), SeveredUntil = 0 }
	end

	-- movimento fisico fluido
	if kind ~= "Dummy" then
		local att = Instance.new("Attachment")
		att.Name = "Movimento"
		att.Parent = root
		local alignPos = Instance.new("AlignPosition")
		alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
		alignPos.Attachment0 = att
		alignPos.MaxForce = 1e9
		alignPos.MaxVelocity = math.max(10, speed * 1.6)
		alignPos.Responsiveness = 25
		alignPos.Position = cf.Position
		alignPos.Parent = root
		local alignOri = Instance.new("AlignOrientation")
		alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
		alignOri.Attachment0 = att
		alignOri.MaxTorque = 1e9
		alignOri.MaxAngularVelocity = 6
		alignOri.Responsiveness = 14
		alignOri.CFrame = cf.Rotation
		alignOri.Parent = root
		t.AlignPos = alignPos
		t.AlignOri = alignOri
		root.Anchored = true
	else
		root.Anchored = true
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
	end

	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("TitanUid", uid)
	model:SetAttribute("Name", name)
	model:SetAttribute("Level", level)
	model:SetAttribute("MaxHP", maxHP)
	model:SetAttribute("HP", maxHP)
	model:SetAttribute("Boss", kind == "Boss")
	model:SetAttribute("BossId", spec.Boss or "")
	model:SetAttribute("BossTitle", if spec.Boss then def.Title else "")
	model:SetAttribute("Abnormal", abnormal)
	model:SetAttribute("Ally", kind == "Ally")
	model:SetAttribute("Dummy", kind == "Dummy")
	model:SetAttribute("Crawl", (def.Crawl or def.Quadruped or (kind == "Pure" and model:GetAttribute("CrawlPreferred"))) == true)
	model:SetAttribute("Armored", t.ArmorMax > 0)
	setAttr(t, "State", "Idle")
	setAttr(t, "Action", "")
	setAttr(t, "Move", 0)
	model.Parent = titanFolder
	CollectionService:AddTag(model, Config.Tags.Titan)

	titans[uid] = t
	byModel[model] = t
	TitanService.Spawned:Fire(t)
	return t
end

function TitanService.GetByModel(model: Instance?)
	if not model then
		return nil
	end
	return byModel[model :: Model]
end

function TitanService.GetFromPart(part: Instance?)
	local model = part and Util.FindAncestorWithAttribute(part, "TitanUid")
	if model and model:IsA("Model") then
		return byModel[model]
	end
	return nil
end

function TitanService.All()
	return titans
end

local function despawn(t)
	titans[t.Uid] = nil
	byModel[t.Model] = nil
	if t.Model.Parent then
		t.Model:Destroy()
	end
end

-- STATI ---------------------------------------------------------------------------------

local function isNight(): boolean
	return S.LightingService and S.LightingService.IsNight() or false
end

local function forward(t): Vector3
	return Vector3.new(-math.sin(t.Yaw), 0, -math.cos(t.Yaw))
end

local function faceTowards(t, pos: Vector3)
	local d = Util.Flat(pos - t.Position)
	if d.Magnitude > 0.5 then
		t.Yaw = math.atan2(-d.X, -d.Z)
	end
end

local function applyPose(t, extraTilt: number?)
	if not t.AlignPos then
		return
	end
	local gy = groundY(t.Position, t.ZoneDef)
	local fallen = os.clock() < t.FallenUntil
	local drop = if fallen then t.Hip * 0.45 else 0
	t.Position = Vector3.new(t.Position.X, gy + t.Hip - drop, t.Position.Z)
	t.AlignPos.Position = t.Position
	local tilt = extraTilt or (if fallen then -0.6 else 0)
	t.AlignOri.CFrame = CFrame.Angles(0, t.Yaw, 0) * CFrame.Angles(tilt, 0, 0)
end

local function activate(t)
	if t.Active or t.Kind == "Dummy" then
		return
	end
	t.Active = true
	t.Root.Anchored = false
	pcall(function()
		t.Root:SetNetworkOwner(nil)
	end)
end

local function deactivate(t)
	if not t.Active or t.Kind == "Dummy" then
		return
	end
	t.Active = false
	t.Root.Anchored = true
	setAttr(t, "Move", 0)
end

local function playerRoots()
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = Util.GetRoot(character)
		local humanoid = Util.GetHumanoid(character)
		if root and humanoid and humanoid.Health > 0 then
			table.insert(list, { Player = player, Root = root, Position = root.Position })
		end
	end
	return list
end

-- DANNI AI GIOCATORI -----------------------------------------------------------------------

local function hitPlayersInSphere(t, center: Vector3, radius: number, damageMult: number, knockback: number?, opts)
	opts = opts or {}
	local hits = {}
	for _, entry in playerRoots() do
		local dist = (entry.Position - center).Magnitude
		if dist <= radius then
			local player = entry.Player
			local state = S.PlayerService.GetState(player)
			if not state.GrabbedBy or opts.HitGrabbed then
				local dealt = S.PlayerService.Damage(player, t.Damage * damageMult, { Explosive = opts.Explosive, Cause = t.Name })
				if dealt > 0 then
					table.insert(hits, player)
					if knockback and knockback > 0 then
						local dir = Util.SafeUnit(Util.Flat(entry.Position - t.Position), forward(t))
						S.PlayerService.Knockback(player, dir * knockback + Vector3.new(0, knockback * 0.45, 0), opts.Stun)
					elseif opts.Stun then
						S.PlayerService.Knockback(player, Vector3.zero, opts.Stun)
					end
				end
			end
		end
	end
	return hits
end

-- Danni ai giganti nemici (per i giganti alleati evocati dai giocatori)
local function hitTitansInSphere(attacker, center: Vector3, radius: number, amount: number)
	for _, other in titans do
		if other ~= attacker and other.Kind ~= "Ally" and other.State ~= "Dead" then
			if (other.Position - center).Magnitude <= radius + other.Height * 0.3 then
				TitanService.ApplyDamage(other, attacker.Owner, amount, "Nape", { FromAlly = true })
			end
		end
	end
	if S.EnemyService then
		S.EnemyService.DamageInRadius(center, radius, amount, attacker.Owner)
	end
end

-- PRESA (GRAB) ------------------------------------------------------------------------------

local function releaseHold(t, mode: string)
	local player = t.Holding
	t.Holding = nil
	setAttr(t, "Holding", 0)
	if not player then
		return
	end
	local state = S.PlayerService.GetState(player)
	if state.GrabbedBy == t.Uid then
		state.GrabbedBy = nil
	end
	player:SetAttribute("Grabbed", false)
	Net.Event("Grab"):FireClient(player, false, t.Model, mode)
	local away = Util.SafeUnit(forward(t)) * 60 + Vector3.new(0, 60, 0)
	if mode == "Escaped" then
		S.PlayerService.Knockback(player, away, 0)
		S.EventService.Notify(player, "Ti sei liberato!", "Successo", 2)
	elseif mode == "Eaten" then
		S.PlayerService.Knockback(player, away * 0.5, 0.6)
	end
end

local function startHold(t, player: Player)
	local state = S.PlayerService.GetState(player)
	if state.GrabbedBy or state.Transformed then
		return false
	end
	state.GrabbedBy = t.Uid
	t.Holding = player
	t.HoldStart = os.clock()
	t.EscapeCount = 0
	local profile = S.DataService.Get(player)
	local levelDiff = (profile and profile.Level or 1) - t.Level
	t.EscapeNeeded = math.clamp(Config.Titans.GrabEscapePresses - math.floor(levelDiff / 25), 5, 20)
	setAttr(t, "Holding", player.UserId)
	setAttr(t, "Action", "Hold")
	setAttr(t, "ActionT", serverTime())
	player:SetAttribute("Grabbed", true)
	Net.Event("Grab"):FireClient(player, true, t.Model, t.EscapeNeeded)
	return true
end

local function updateHold(t)
	local player = t.Holding
	local character = player and player.Character
	local humanoid = Util.GetHumanoid(character)
	if not player or not player.Parent or not humanoid or humanoid.Health <= 0 then
		releaseHold(t, "Lost")
		t.Action = nil
		setAttr(t, "Action", "")
		return
	end
	if os.clock() < t.Limbs.RightArm.SeveredUntil then
		releaseHold(t, "Escaped")
		t.Action = nil
		setAttr(t, "Action", "")
		return
	end
	if t.EscapeCount >= t.EscapeNeeded then
		releaseHold(t, "Escaped")
		t.Action = nil
		t.StunUntil = os.clock() + 1.2
		setAttr(t, "Action", "")
		return
	end
	if os.clock() - t.HoldStart >= Config.Titans.GrabHoldTime then
		local damage = humanoid.MaxHealth * Config.Titans.EatDamagePct + t.Damage
		S.PlayerService.Damage(player, damage, { IgnoreIFrames = true, Cause = "Divorato" })
		S.EventService.Effect("Bite", { Position = (t.Model:FindFirstChild("Head") :: BasePart).Position }, t.Position, 500)
		releaseHold(t, "Eaten")
		t.Action = nil
		t.Cooldowns.Grab = os.clock() + 6
		setAttr(t, "Action", "")
	end
end

function TitanService.EscapePress(player: Player)
	local state = S.PlayerService.GetState(player)
	local t = state.GrabbedBy and titans[state.GrabbedBy]
	if not t or t.Holding ~= player then
		return
	end
	local now = os.clock()
	if now - (state.LastMash or 0) < 0.045 then
		return
	end
	state.LastMash = now
	t.EscapeCount += 1
end

-- ATTACCHI -----------------------------------------------------------------------------------

local function attackDef(name: string)
	return Titans.Attacks[name]
end

local function scheduleImpact(t, delay: number, center: Vector3, radius: number, damageMult: number, knockback: number?, opts)
	task.delay(delay, function()
		if t.State == "Dead" and not (opts and opts.EvenIfDead) then
			return
		end
		if t.Kind == "Ally" then
			hitTitansInSphere(t, center, radius, t.Damage * damageMult)
		else
			hitPlayersInSphere(t, center, radius, damageMult, knockback, opts)
		end
		S.EventService.Effect("Impact", { Position = center, Radius = radius, Kind = opts and opts.Kind or "Rock" }, center, 900)
	end)
end

local function headPosition(t): Vector3
	return Vector3.new(t.Position.X, t.Position.Y - t.Hip + t.Height * 0.9, t.Position.Z)
end

local function napePosition(t): Vector3
	local nape = t.Model:FindFirstChild("Nape") :: BasePart?
	if nape then
		return nape.Position
	end
	return headPosition(t) - forward(t) * t.Height * 0.08
end

local function summonMinions(t, count: number, duration: number)
	local zone = t.ZoneDef
	for i = 1, count do
		local a = (i / count) * math.pi * 2
		local pos = t.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * (t.Height * 0.9 + 20)
		local class = if t.Level > 600 then "T12" elseif t.Level > 250 then "T10" else "T7"
		local minion = TitanService.Spawn({
			Class = class,
			Level = math.max(1, t.Level - 20),
			Zone = t.Zone,
			Position = pos,
			Duration = duration,
			Kind = if t.Kind == "Ally" then "Ally" else "Pure",
			Owner = t.Owner,
		})
		if minion and zone then
			minion.Home = t.Position
		end
	end
	S.EventService.Effect("Roar", { Position = headPosition(t), Height = t.Height }, t.Position, 900)
end

local function resolveAttack(t, name: string)
	local def = attackDef(name)
	if not def then
		return
	end
	local H = t.Height
	local gy = t.Position.Y - t.Hip
	local fwd = forward(t)
	local origin = Vector3.new(t.Position.X, gy, t.Position.Z)
	local radiusBonus = 5
	if name == "Swipe" then
		local center = origin + fwd * (H * def.Reach) + Vector3.new(0, H * 0.45, 0)
		scheduleImpact(t, 0, center, H * def.Radius + radiusBonus, def.Damage, def.Knockback, { Kind = "Swipe" })
	elseif name == "Stomp" then
		local center = origin + fwd * (H * def.Reach) + Vector3.new(0, H * 0.08, 0)
		scheduleImpact(t, 0, center, H * def.Radius + radiusBonus, def.Damage, def.Knockback, { Kind = "Stomp" })
	elseif name == "Kick" or name == "Punch" then
		local height = if name == "Kick" then 0.3 else 0.6
		local center = origin + fwd * (H * def.Reach) + Vector3.new(0, H * height, 0)
		scheduleImpact(t, 0, center, H * def.Radius + radiusBonus, def.Damage, def.Knockback, { Kind = "Swipe" })
	elseif name == "Bite" then
		local center = headPosition(t) + fwd * (H * def.Reach)
		scheduleImpact(t, 0, center, H * def.Radius + radiusBonus, def.Damage, 0, { Kind = "Bite" })
	elseif name == "NapeSwat" then
		local center = napePosition(t) - fwd * (H * 0.08)
		scheduleImpact(t, 0, center, H * def.Radius + radiusBonus, def.Damage, def.Knockback, { Kind = "Swipe" })
	elseif name == "Grab" then
		local target = t.ActionTarget
		local reachPoint = origin + fwd * (H * def.Reach) + Vector3.new(0, math.clamp((t.ActionPos and t.ActionPos.Y or gy + H * 0.5) - gy, H * 0.12, H * 1.05), 0)
		local best, bestDist = nil, H * def.Radius + 6
		for _, entry in playerRoots() do
			local d = (entry.Position - reachPoint).Magnitude
			if d < bestDist and not S.PlayerService.IsInvulnerable(entry.Player) then
				best, bestDist = entry.Player, d
			end
		end
		if best and (best == target or not target or bestDist < H * 0.15) then
			if t.Kind ~= "Ally" and startHold(t, best) then
				return
			end
		end
	elseif name == "Roar" or name == "Dominio" then
		local stun = def.Stun
		for _, entry in playerRoots() do
			if (entry.Position - t.Position).Magnitude <= H * def.Radius then
				local profile = S.DataService.Get(entry.Player)
				local immune = profile and profile.Bloodline == "StirpeReale"
				S.PlayerService.Damage(entry.Player, t.Damage * def.Damage, { Cause = t.Name })
				local dir = Util.SafeUnit(Util.Flat(entry.Position - t.Position))
				S.PlayerService.Knockback(entry.Player, dir * (def.Knockback or 60) + Vector3.new(0, 40, 0), if immune then 0 else stun)
			end
		end
		S.EventService.Effect("Roar", { Position = headPosition(t), Height = H }, t.Position, 1200)
	elseif name == "Scream" then
		summonMinions(t, def.Summon or 3, 45)
	elseif name == "Summon" then
		summonMinions(t, def.Summon or 4, 50)
	elseif name == "Harden" then
		t.HardenUntil = os.clock() + (def.Duration or 6)
		setAttr(t, "Hardened", true)
		S.EventService.Effect("Harden", { Model = t.Model }, t.Position, 900)
	elseif name == "RockThrow" or name == "Cannon" then
		local target = t.ActionPos or (origin + fwd * 100)
		local start = origin + Vector3.new(0, H * 0.95, 0) + fwd * (H * 0.2)
		local flight = def.Flight or 1.2
		S.EventService.Effect("Projectile", { From = start, To = target, Time = flight, Kind = if name == "Cannon" then "Cannon" else "Rock", Size = H * 0.12 }, t.Position, 1100)
		scheduleImpact(t, flight, target, H * def.Radius + 6, def.Damage, 60, { Kind = if name == "Cannon" then "Explosion" else "Rock", Explosive = name == "Cannon" })
	elseif name == "RockBarrage" then
		local target = t.ActionPos or (origin + fwd * 100)
		local start = origin + Vector3.new(0, H * 0.95, 0) + fwd * (H * 0.2)
		for i = 1, def.Count or 8 do
			local offset = Vector3.new(rng:NextNumber(-30, 30), 0, rng:NextNumber(-30, 30))
			local point = target + offset
			local flight = (def.Flight or 1.3) + i * 0.06
			S.EventService.Effect("Projectile", { From = start, To = point, Time = flight, Kind = "Rock", Size = H * 0.06 }, t.Position, 1100)
			scheduleImpact(t, flight, point, H * def.Radius + 4, def.Damage, 40, { Kind = "Rock" })
		end
	elseif name == "Charge" then
		t.ChargeUntil = os.clock() + 0.9
		t.ChargeDir = fwd
		t.ChargeHit = {}
	elseif name == "Steam" then
		t.SteamUntil = os.clock() + (def.Duration or 4)
		t.NextSteamTick = 0
		setAttr(t, "Steam", true)
		S.EventService.Effect("SteamBurst", { Position = t.Position, Radius = H * def.Radius, Duration = def.Duration }, t.Position, 1200)
	elseif name == "Spikes" then
		local target = t.ActionPos or (origin + fwd * 100)
		local dir = Util.SafeUnit(Util.Flat(target - origin), fwd)
		local length = H * (def.Length or 3)
		local steps = 8
		for i = 1, steps do
			local point = origin + dir * (length * i / steps)
			S.EventService.Effect("Spike", { Position = point, Height = H * 0.25, Delay = i * 0.05 }, point, 900)
			scheduleImpact(t, i * 0.05, point, H * def.Radius + 6, def.Damage, 50, { Kind = "Spike" })
		end
	elseif name == "SpikeArena" then
		local count = 16
		for i = 1, count do
			local a = i / count * math.pi * 2
			local point = origin + Vector3.new(math.cos(a), 0, math.sin(a)) * (H * def.Radius * 0.8)
			S.EventService.Effect("Spike", { Position = point, Height = H * 0.3, Delay = 0 }, point, 900)
		end
		scheduleImpact(t, 0, origin, H * def.Radius, def.Damage, 90, { Kind = "Spike" })
	elseif name == "HammerSlam" then
		local target = t.ActionPos or (origin + fwd * 60)
		scheduleImpact(t, 0, target, H * def.Radius + 6, def.Damage, 100, { Kind = "Explosion" })
	elseif name == "Leap" then
		-- l'atterraggio viene gestito in updateAction
		t.LeapFrom = t.Position
		t.LeapTo = t.ActionPos or (t.Position + fwd * 80)
	end
end

local function canUse(t, name: string): boolean
	return (t.Cooldowns[name] or 0) <= os.clock()
end

local function startAction(t, name: string, target: Player?, targetPos: Vector3?)
	local def = attackDef(name)
	if not def then
		return
	end
	t.Action = name
	t.ActionStart = os.clock()
	t.ActionTarget = target
	t.ActionPos = targetPos
	t.ActionResolved = false
	t.Cooldowns[name] = os.clock() + def.Cooldown * (if t.Kind == "Boss" then 0.8 else 1)
	if targetPos then
		faceTowards(t, targetPos)
		applyPose(t)
	end
	setAttr(t, "Action", name)
	setAttr(t, "ActionT", serverTime())
	t.Model:SetAttribute("ActionPos", targetPos or t.Position)
	setAttr(t, "Move", 0)
	-- avvisi visivi per gli attacchi più forti
	if name == "HammerSlam" and targetPos then
		S.EventService.Effect("Telegraph", { Position = targetPos, Radius = t.Height * def.Radius + 6, Time = def.Windup }, targetPos, 900)
	elseif name == "Steam" or name == "SpikeArena" then
		S.EventService.Effect("Telegraph", { Position = Vector3.new(t.Position.X, t.Position.Y - t.Hip, t.Position.Z), Radius = t.Height * (def.Radius or 1), Time = def.Windup }, t.Position, 900)
	elseif name == "Roar" or name == "Dominio" then
		S.EventService.Effect("Telegraph", { Position = Vector3.new(t.Position.X, t.Position.Y - t.Hip, t.Position.Z), Radius = t.Height * (def.Radius or 1), Time = def.Windup }, t.Position, 900)
	end
end

local function updateAction(t, dt: number)
	local name = t.Action
	local def = attackDef(name)
	if not def then
		t.Action = nil
		setAttr(t, "Action", "")
		return
	end
	local elapsed = os.clock() - t.ActionStart
	if not t.ActionResolved and elapsed >= def.Windup then
		t.ActionResolved = true
		resolveAttack(t, name)
		if t.Holding then
			return
		end
	end
	-- movimento speciale durante l'attacco
	if name == "Leap" and t.LeapTo and elapsed >= def.Windup then
		local air = def.Air or 0.9
		local k = math.clamp((elapsed - def.Windup) / air, 0, 1)
		local from, to = t.LeapFrom, t.LeapTo
		t.Position = from:Lerp(to, k) + Vector3.new(0, math.sin(k * math.pi) * t.Height * 0.8, 0)
		t.AlignPos.MaxVelocity = 400
		t.AlignPos.Position = Vector3.new(t.Position.X, groundY(t.Position, t.ZoneDef) + t.Hip + math.sin(k * math.pi) * t.Height * 0.8, t.Position.Z)
		if k >= 1 and not t.Landed then
			t.Landed = true
			t.Position = Vector3.new(to.X, t.Position.Y, to.Z)
			applyPose(t)
			local landing = Vector3.new(to.X, t.Position.Y - t.Hip, to.Z)
			if t.Kind == "Ally" then
				hitTitansInSphere(t, landing, t.Height * def.Radius + 6, t.Damage * def.Damage)
			else
				hitPlayersInSphere(t, landing, t.Height * def.Radius + 6, def.Damage, def.Knockback)
			end
			S.EventService.Effect("Impact", { Position = landing, Radius = t.Height * def.Radius, Kind = "Stomp" }, landing, 900)
		end
	elseif name == "Charge" and t.ChargeUntil and os.clock() < t.ChargeUntil then
		local distance = t.Height * (def.Distance or 4)
		local speed = distance / 0.9
		t.AlignPos.MaxVelocity = speed * 1.2
		t.Position += t.ChargeDir * speed * dt
		applyPose(t)
		for _, entry in playerRoots() do
			if not t.ChargeHit[entry.Player] and (entry.Position - t.Position).Magnitude < t.Height * def.Radius + 6 then
				t.ChargeHit[entry.Player] = true
				S.PlayerService.Damage(entry.Player, t.Damage * def.Damage, { Cause = t.Name })
				S.PlayerService.Knockback(entry.Player, t.ChargeDir * def.Knockback + Vector3.new(0, 50, 0), 0.4)
			end
		end
	end
	if elapsed >= def.Windup + (def.Air or 0) + def.Recover then
		t.Action = nil
		t.Landed = nil
		t.LeapTo = nil
		t.ChargeUntil = nil
		if t.AlignPos then
			t.AlignPos.MaxVelocity = math.max(10, t.Speed * 1.6)
		end
		setAttr(t, "Action", "")
	end
end

-- SCELTA DEL BERSAGLIO E DELL'ATTACCO -------------------------------------------------------

local function isTargetable(t, _entry): boolean
	return t.Kind ~= "Ally"
end

local function chooseTarget(t, roots, now: number)
	if now < t.BlindUntil then
		return nil
	end
	local aggro = Config.Titans.AggroBase + t.Height * 2.2
	if t.Kind == "Boss" then
		aggro *= 1.6
	end
	if isNight() and not t.Abnormal and t.Kind ~= "Boss" then
		aggro *= Config.Titans.NightAggroMult
	end
	-- mantieni il bersaglio attuale se è ancora valido
	local current = t.Target
	if current then
		for _, entry in roots do
			if entry.Player == current and (entry.Position - t.Position).Magnitude < aggro * 1.6 and isTargetable(t, entry) then
				return entry
			end
		end
	end
	local best, bestDist = nil, aggro
	local candidates = {}
	for _, entry in roots do
		if isTargetable(t, entry) then
			local d = Util.FlatDistance(entry.Position, t.Position)
			if d < aggro then
				table.insert(candidates, entry)
				-- chi ha colpito il gigante è più "attraente"
				local weight = if t.Damagers[entry.Player] then d * 0.6 else d
				if weight < bestDist then
					best, bestDist = entry, weight
				end
			end
		end
	end
	if t.Abnormal and #candidates > 1 and rng:NextNumber() < 0.3 then
		best = candidates[rng:NextInteger(1, #candidates)]
	end
	return best
end

local function chooseAttack(t, entry, now: number): (string?, Vector3?)
	local H = t.Height
	local gy = t.Position.Y - t.Hip
	local targetPos = entry.Position
	local flat = Util.FlatDistance(targetPos, t.Position)
	local relY = targetPos.Y - gy
	local toTarget = Util.SafeUnit(Util.Flat(targetPos - t.Position))
	local facing = forward(t):Dot(toTarget)
	local list = (t.Def and t.Def.Attacks) or Titans.DefaultAttacks
	local legsOk = now >= t.FallenUntil

	-- sul collo o dietro la nuca: prova a schiacciare il soldato
	local napeDist = (targetPos - napePosition(t)).Magnitude
	if table.find(list, "NapeSwat") and napeDist < H * 0.35 + 6 and canUse(t, "NapeSwat") then
		return "NapeSwat", targetPos
	end
	if table.find(list, "Bite") and flat < H * 0.42 and relY > H * 0.7 and facing > 0.3 and canUse(t, "Bite") then
		return "Bite", targetPos
	end
	if legsOk and table.find(list, "Stomp") and flat < H * 0.32 + 4 and relY < H * 0.3 and canUse(t, "Stomp") then
		return "Stomp", targetPos
	end
	if table.find(list, "Grab") and flat < H * 0.64 + 4 and relY > H * 0.05 and relY < H * 1.05 and facing > 0.2 and canUse(t, "Grab") and rng:NextNumber() < 0.65 then
		local state = S.PlayerService.GetState(entry.Player)
		if not state.GrabbedBy and not state.Transformed then
			return "Grab", targetPos
		end
	end
	for _, name in { "Swipe", "Kick", "Punch" } do
		if table.find(list, name) and flat < H * 0.7 + 4 and relY < H * 0.95 and canUse(t, name) then
			return name, targetPos
		end
	end
	if legsOk and (table.find(list, "Leap") or t.Abnormal) and flat > Titans.Attacks.Leap.MinRange and flat < Titans.Attacks.Leap.MaxRange and canUse(t, "Leap") then
		return "Leap", targetPos
	end
	if t.Kind == "Boss" then
		-- attacchi speciali dei boss
		local hpFrac = t.HP / t.MaxHP
		local nearby = 0
		for _, other in playerRoots() do
			if (other.Position - t.Position).Magnitude < H * 0.8 then
				nearby += 1
			end
		end
		if table.find(list, "Harden") and hpFrac < 0.6 and canUse(t, "Harden") and rng:NextNumber() < 0.3 then
			return "Harden", targetPos
		end
		if table.find(list, "Steam") and (nearby >= 1 or t.Def.SteamPhase) and canUse(t, "Steam") then
			return "Steam", targetPos
		end
		if table.find(list, "SpikeArena") and nearby >= 2 and canUse(t, "SpikeArena") then
			return "SpikeArena", targetPos
		end
		if table.find(list, "Scream") and hpFrac < 0.75 and canUse(t, "Scream") then
			return "Scream", targetPos
		end
		if table.find(list, "Summon") and hpFrac < (0.9 - (t.Phase - 1) * 0.3) and canUse(t, "Summon") then
			return "Summon", targetPos
		end
		if table.find(list, "Dominio") and flat < H * 2 and canUse(t, "Dominio") and rng:NextNumber() < 0.4 then
			return "Dominio", targetPos
		end
		if table.find(list, "Roar") and flat < H * 1.6 and canUse(t, "Roar") and rng:NextNumber() < 0.25 then
			return "Roar", targetPos
		end
		if table.find(list, "Charge") and flat > H * 0.8 and flat < H * 4 and canUse(t, "Charge") then
			return "Charge", targetPos
		end
		local ranged = { "RockThrow", "RockBarrage", "Cannon", "Spikes", "HammerSlam" }
		for _, name in ranged do
			local def = Titans.Attacks[name]
			if table.find(list, name) and flat > H * 0.6 and flat < (def.MaxRange or H * 4) and canUse(t, name) then
				-- anticipa un po' il movimento del bersaglio
				local lead = entry.Root.AssemblyLinearVelocity * (def.Flight or 0.6) * 0.6
				return name, targetPos + Util.Flat(lead)
			end
		end
	end
	return nil, nil
end

-- PENSIERO DEL GIGANTE ---------------------------------------------------------------------

local function moveTowards(t, goal: Vector3, speed: number, dt: number)
	local delta = Util.Flat(goal - t.Position)
	local dist = delta.Magnitude
	if dist < 1 then
		return 0
	end
	local step = math.min(dist, speed * dt)
	t.Position += delta.Unit * step
	faceTowards(t, goal)
	return step / dt
end

local function thinkAlly(t, now: number, dt: number)
	if t.March then
		-- La Grande Marcia: marcia in linea retta schiacciando tutto
		t.Position += t.March * t.Speed * dt
		t.Yaw = math.atan2(-t.March.X, -t.March.Z)
		applyPose(t)
		setAttr(t, "Move", 1)
		t.NextMarchHit = t.NextMarchHit or 0
		if now >= t.NextMarchHit then
			t.NextMarchHit = now + 0.4
			hitTitansInSphere(t, Vector3.new(t.Position.X, t.Position.Y - t.Hip, t.Position.Z), t.Height * 0.45, t.Damage * 1.5)
			S.EventService.EffectFast("Footstep", { Position = Vector3.new(t.Position.X, t.Position.Y - t.Hip, t.Position.Z), Size = t.Height }, t.Position, 900)
		end
		return
	end
	-- cerca il gigante nemico più vicino
	local best, bestDist = nil, 260
	for _, other in titans do
		if other.Kind ~= "Ally" and other.Kind ~= "Dummy" and other.State ~= "Dead" then
			local d = Util.FlatDistance(other.Position, t.Position)
			if d < bestDist then
				best, bestDist = other, d
			end
		end
	end
	if best then
		if bestDist < t.Height * 0.6 + best.Height * 0.3 then
			if canUse(t, "Swipe") then
				startAction(t, "Swipe", nil, best.Position)
				return
			end
		else
			local speed = moveTowards(t, best.Position, t.Speed * 1.2, dt)
			setAttr(t, "Move", math.clamp(speed / math.max(1, t.Speed), 0, 1.5))
		end
	elseif t.Owner and t.Owner.Character then
		local root = Util.GetRoot(t.Owner.Character)
		if root and Util.FlatDistance(root.Position, t.Position) > 60 then
			local speed = moveTowards(t, root.Position, t.Speed, dt)
			setAttr(t, "Move", math.clamp(speed / math.max(1, t.Speed), 0, 1.5))
		else
			setAttr(t, "Move", 0)
		end
	end
	applyPose(t)
end

local function think(t, roots, dt: number)
	local now = os.clock()
	if t.Kind == "Dummy" then
		return
	end
	if t.Temporary and now > t.Temporary then
		t.State = "Dead"
		setAttr(t, "State", "Dead")
		S.EventService.Effect("TitanDeath", { Model = t.Model }, t.Position, 900)
		task.delay(2.5, function()
			despawn(t)
		end)
		return
	end
	-- fine dello stato "vapore"
	if t.SteamUntil > 0 and now >= t.SteamUntil then
		t.SteamUntil = 0
		setAttr(t, "Steam", false)
	elseif t.SteamUntil > now then
		t.NextSteamTick = t.NextSteamTick or 0
		if now >= t.NextSteamTick then
			t.NextSteamTick = now + 0.5
			local def = Titans.Attacks.Steam
			hitPlayersInSphere(t, t.Position, t.Height * def.Radius + 8, def.Damage, def.Knockback, { HitGrabbed = false })
		end
	end
	if t.HardenUntil > 0 and now >= t.HardenUntil then
		t.HardenUntil = 0
		setAttr(t, "Hardened", false)
	end
	if t.ArmorMax > 0 then
		setAttr(t, "ArmorBroken", now < t.ArmorBrokenUntil)
	end
	setAttr(t, "Blinded", now < t.BlindUntil)
	setAttr(t, "Fallen", now < t.FallenUntil)
	setAttr(t, "Frozen", now < t.FrozenUntil)
	for _, limb in LIMBS do
		local info = t.Limbs[limb]
		local severed = now < info.SeveredUntil
		if not severed and info.HP <= 0 then
			info.HP = limbHP(t)
		end
		setAttr(t, "Severed_" .. limb, severed)
	end

	if now < t.FrozenUntil then
		setAttr(t, "Move", 0)
		return
	end
	if t.Holding then
		updateHold(t)
		return
	end
	if t.Action then
		updateAction(t, dt)
		return
	end
	if t.Kind == "Ally" then
		thinkAlly(t, now, dt)
		return
	end
	if now < t.StunUntil then
		setAttr(t, "Move", 0)
		return
	end

	-- fase del Primordiale
	if t.Def and t.Def.Phases then
		local frac = t.HP / t.MaxHP
		local phase = if frac < 0.33 then 3 elseif frac < 0.66 then 2 else 1
		if phase > t.Phase then
			t.Phase = phase
			S.EventService.Announce("Il Primordiale si infuria!", ("Fase %d di 3: i giganti della Grande Marcia rispondono al suo richiamo."):format(phase), "Pericolo")
			summonMinions(t, 3 + phase, 60)
		end
	end

	local entry = chooseTarget(t, roots, now)
	t.Target = entry and entry.Player or nil
	setAttr(t, "TargetUserId", if entry then entry.Player.UserId else 0)

	local speed = t.Speed
	if isNight() and t.Kind ~= "Boss" then
		speed *= if t.Abnormal then 0.8 else Config.Titans.NightSpeedMult
	end
	local legsOk = now >= t.FallenUntil
	if not legsOk then
		speed = 0
	end

	local fromHome = Util.FlatDistance(t.Position, t.Home)
	local leash = t.HomeRadius * Config.Titans.LeashMultiplier
	if fromHome > leash then
		t.Target = nil
		entry = nil
	end

	if entry then
		local attack, pos = chooseAttack(t, entry, now)
		if attack then
			startAction(t, attack, entry.Player, pos)
			return
		end
		if t.Def and t.Def.PrefersRange and Util.FlatDistance(entry.Position, t.Position) < t.Height * 0.9 then
			-- i boss a distanza (Fauno, Carro) indietreggiano
			local away = t.Position + Util.SafeUnit(Util.Flat(t.Position - entry.Position)) * 30
			moveTowards(t, away, speed * 0.7, dt)
			faceTowards(t, entry.Position)
			setAttr(t, "Move", 0.7)
			setAttr(t, "Run", 0)
		else
			local run = if t.Abnormal then 1.75 else 1
			local actual = moveTowards(t, entry.Position, speed * run, dt)
			setAttr(t, "Move", math.clamp(actual / math.max(1, t.Speed), 0, 2))
			setAttr(t, "Run", if t.Abnormal and actual > 1 then 1 else 0)
		end
		t.State = "Chase"
	else
		-- vaga nella zona
		if now >= t.NextWander or not t.WanderTarget then
			t.NextWander = now + rng:NextNumber(4, 9)
			if fromHome > t.HomeRadius * 0.9 then
				t.WanderTarget = t.Home
			elseif rng:NextNumber() < 0.35 then
				t.WanderTarget = nil
			else
				local a = rng:NextNumber(0, math.pi * 2)
				local r = math.sqrt(rng:NextNumber()) * t.HomeRadius * 0.8
				t.WanderTarget = t.Home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			end
		end
		if t.WanderTarget then
			local actual = moveTowards(t, t.WanderTarget, speed * 0.45, dt)
			setAttr(t, "Move", math.clamp(actual / math.max(1, t.Speed), 0, 1))
			if actual <= 0 then
				t.WanderTarget = nil
			end
		else
			setAttr(t, "Move", 0)
		end
		setAttr(t, "Run", 0)
		t.State = "Wander"
	end
	setAttr(t, "State", t.State)
	applyPose(t)
end

-- DANNI AI GIGANTI ------------------------------------------------------------------------------

local function rewardKill(t, killer: Player?)
	local contributors = {}
	local total = 0
	for _, dmg in t.Damagers do
		total += dmg
	end
	for player, dmg in t.Damagers do
		if typeof(player) == "Instance" and player.Parent and (dmg >= t.MaxHP * Config.Combat.KillShareMin or player == killer or t.Kind == "Boss" and dmg >= t.MaxHP * 0.03) then
			table.insert(contributors, player)
		end
	end
	if killer and not table.find(contributors, killer) and killer.Parent then
		table.insert(contributors, killer)
	end
	if t.Kind == "Ally" or t.Temporary and not t.Invasion and t.Kind ~= "Pure" then
		return contributors
	end
	local def = t.Def
	local classXP = (def and def.XP) or 1
	local classGold = (def and def.Gold) or 1
	local xpMult = if t.Kind == "Boss" then def.XPMult else classXP
	local goldMult = if t.Kind == "Boss" then def.GoldMult else classGold
	local invasion = S.EventService.IsInvasion(t.Zone)
	if invasion then
		xpMult *= 2
		goldMult *= 2
	end
	if t.Temporary and t.Kind == "Pure" and not t.Invasion then
		-- i giganti evocati dai boss danno meno ricompense
		xpMult *= 0.3
		goldMult *= 0.3
	end
	for _, player in contributors do
		local profile = S.DataService.Get(player)
		if profile then
			local xp = S.PlayerService.AddXP(player, Leveling.KillXP(t.Level, xpMult), true)
			local gold = S.PlayerService.AddGold(player, Leveling.KillGold(t.Level, goldMult))
			profile.Kills.Titans += 1
			if t.Kind == "Boss" then
				profile.Kills.Bosses += 1
				profile.BossKills[t.BossId] = (profile.BossKills[t.BossId] or 0) + 1
			end
			S.PlayerService.UpdateKillStat(player)
			Net.Event("HitConfirm"):FireClient(player, { Kind = "Kill", Name = t.Name, XP = xp, Gold = gold, Boss = t.Kind == "Boss" })
			-- frammenti di siero e oggetti
			if S.SerumService then
				S.SerumService.RollKillRewards(player, t)
			end
			if t.Kind == "Boss" and def.Drops then
				local luck = 1 + (S.PlayerService.Stats(player).DropLuck or 0)
				for _, drop in def.Drops do
					if rng:NextNumber() < drop.Chance * luck then
						local count = rng:NextInteger(drop.Min or 1, drop.Max or 1)
						S.InventoryService.Give(player, drop.Id, count)
						local item = Items.Get(drop.Id)
						S.EventService.Notify(player, ("Bottino: %s x%d"):format(item and item.Name or drop.Id, count), "Raro", 5)
					end
				end
			elseif t.Height >= 30 and rng:NextNumber() < 0.03 then
				S.InventoryService.Give(player, "MidolloGigante", 1)
				S.EventService.Notify(player, "Bottino: Midollo di Gigante", "Ricompensa", 3)
			end
			S.DataService.MarkDirty(player)
		end
	end
	return contributors
end

local function kill(t, killer: Player?)
	if t.State == "Dead" then
		return
	end
	t.State = "Dead"
	t.Action = nil
	if t.Holding then
		releaseHold(t, "Escaped")
	end
	setAttr(t, "State", "Dead")
	setAttr(t, "Action", "")
	setAttr(t, "HP", 0)
	t.Model:SetAttribute("HP", 0)
	if t.AlignPos then
		t.AlignPos.Position = t.Position
	end
	S.EventService.Effect("TitanDeath", { Model = t.Model, Position = t.Position, Height = t.Height }, t.Position, 1200)
	local contributors = rewardKill(t, killer)
	TitanService.Killed:Fire(t, killer, contributors)
	if t.Kind == "Boss" and not t.Raid then
		S.EventService.Announce(t.Name .. " è caduto!", killer and ("Colpo finale di " .. killer.DisplayName) or "", "Vittoria")
		local bossState = bossStates[t.BossId]
		if bossState then
			bossState.Alive = nil
			bossState.NextSpawn = os.clock() + t.Def.Respawn
		end
	end
	task.delay(Config.Titans.CorpseTime, function()
		if t.Root and t.Root.Parent then
			t.Root.Anchored = true
		end
		despawn(t)
	end)
	if t.Spawner then
		local spawner = t.Spawner
		local index = table.find(spawner.Alive, t)
		if index then
			table.remove(spawner.Alive, index)
		end
		local delay = if t.Kind == "Dummy" then 4 else rng:NextNumber(8, 16)
		task.delay(delay, function()
			if #spawner.Alive < spawner.Count then
				local new = TitanService.Spawn({
					Class = spawner.Class,
					Level = spawner.Level,
					Zone = spawner.Zone,
					Abnormal = rng:NextNumber() < (spawner.Abnormal or 0),
					Look = spawner.Look,
					Position = spawner.Positions and spawner.Positions[rng:NextInteger(1, #spawner.Positions)] or nil,
					Spawner = spawner,
					Yaw = spawner.Yaw,
				})
				if new then
					table.insert(spawner.Alive, new)
				end
			end
		end)
	end
end

local function damageLimb(t, limb: string, amount: number)
	local info = t.Limbs[limb]
	if not info or os.clock() < info.SeveredUntil then
		return false
	end
	info.HP -= amount
	if info.HP <= 0 then
		info.SeveredUntil = os.clock() + Config.Titans.LimbRegenTime
		setAttr(t, "Severed_" .. limb, true)
		S.EventService.Effect("Sever", { Model = t.Model, Limb = limb }, t.Position, 900)
		if limb == "RightArm" and t.Holding then
			releaseHold(t, "Escaped")
			t.Action = nil
			setAttr(t, "Action", "")
		end
		local legs = t.Limbs
		if os.clock() < legs.RightLeg.SeveredUntil or os.clock() < legs.LeftLeg.SeveredUntil then
			-- una gamba recisa basta per farlo cadere in ginocchio
			t.FallenUntil = os.clock() + 7
			t.Action = nil
			setAttr(t, "Action", "")
			setAttr(t, "Fallen", true)
		end
		return true
	end
	return false
end

--[[
	ApplyDamage(titan, attacker, amount, zone, info)
	zone: "Nape" | "Eye" | "RightArm" | "LeftArm" | "RightLeg" | "LeftLeg" | "Body"
	info: { Explosive, ArmorBreak, FromAlly, Perfect }
	Restituisce { Damage, Killed, Severed, Blocked } oppure nil
]]
function TitanService.ApplyDamage(t, attacker: Player?, amount: number, zone: string, info)
	if not t or t.State == "Dead" or t.Kind == "Ally" then
		return nil
	end
	info = info or {}
	local now = os.clock()
	local mult = 1
	local blocked = false
	if now < t.HardenUntil then
		mult *= 0.25
		blocked = true
	end
	if t.ArmorMax > 0 and now >= t.ArmorBrokenUntil then
		local armorDamage = amount * (if info.Explosive or info.ArmorBreak then 2.5 else 1)
		t.ArmorHP -= armorDamage
		mult *= 1 - (t.Def.ArmorReduction or 0.8)
		blocked = true
		if t.ArmorHP <= 0 then
			t.ArmorBrokenUntil = now + 12
			t.ArmorHP = t.ArmorMax
			setAttr(t, "ArmorBroken", true)
			S.EventService.Effect("ArmorBreak", { Model = t.Model, Position = t.Position }, t.Position, 900)
			S.EventService.Announce("La corazza si è spezzata!", "Colpite la nuca adesso, avete pochi secondi!", "Pericolo")
		end
	end
	if now < t.SteamUntil and t.Def and t.Def.SteamPhase then
		mult *= 0.15
		blocked = true
	end
	local share = Config.Combat.BodyDamageShare
	local result = { Damage = 0, Killed = false, Severed = false, Blocked = blocked }
	local dealt
	if zone == "Nape" then
		dealt = amount * mult
	elseif zone == "Eye" then
		dealt = amount * mult * share
		if t.Kind ~= "Boss" or rng:NextNumber() < 0.25 then
			t.BlindUntil = now + Config.Titans.BlindTime * (if t.Kind == "Boss" then 0.4 else 1)
			setAttr(t, "Blinded", true)
		end
	elseif t.Limbs[zone] then
		dealt = amount * mult * share
		result.Severed = damageLimb(t, zone, amount * mult)
	else
		dealt = amount * mult * share
	end
	if info.Explosive and zone ~= "Nape" then
		dealt = amount * mult * 0.45
	end
	dealt = math.max(1, dealt)
	t.HP -= dealt
	result.Damage = dealt
	if attacker then
		t.Damagers[attacker] = (t.Damagers[attacker] or 0) + dealt
		if not t.Target and t.Kind ~= "Dummy" then
			t.Target = attacker
		end
	end
	setAttr(t, "HP", math.max(0, math.floor(t.HP)))
	if t.Kind == "Dummy" then
		t.Model:SetAttribute("HitT", serverTime())
	end
	if t.HP <= 0 then
		result.Killed = true
		kill(t, attacker)
	end
	return result
end

-- Danni ad area (esplosioni, abilità in forma di gigante)
function TitanService.DamageInRadius(center: Vector3, radius: number, amount: number, attacker: Player?, info)
	local results = {}
	for _, t in titans do
		if t.State ~= "Dead" and t.Kind ~= "Ally" then
			local napePos = napePosition(t)
			local napeDist = (napePos - center).Magnitude
			local bodyDist = (t.Position - center).Magnitude - t.Height * 0.25
			if napeDist <= radius then
				local r = TitanService.ApplyDamage(t, attacker, amount, "Nape", info)
				if r then
					table.insert(results, { Titan = t, Result = r, Position = napePos })
				end
			elseif bodyDist <= radius then
				local r = TitanService.ApplyDamage(t, attacker, amount, "Body", info)
				if r then
					table.insert(results, { Titan = t, Result = r, Position = t.Position })
				end
			end
		end
	end
	return results
end

function TitanService.Stun(t, duration: number)
	t.StunUntil = math.max(t.StunUntil, os.clock() + duration)
end

function TitanService.FreezeInRadius(center: Vector3, radius: number, duration: number)
	local count = 0
	for _, t in titans do
		if t.State ~= "Dead" and t.Kind ~= "Ally" and Util.FlatDistance(t.Position, center) <= radius then
			t.FrozenUntil = os.clock() + duration
			t.Action = nil
			setAttr(t, "Action", "")
			if t.Holding then
				releaseHold(t, "Escaped")
			end
			count += 1
		end
	end
	return count
end

function TitanService.Blind(t, duration: number)
	t.BlindUntil = os.clock() + duration
	setAttr(t, "Blinded", true)
end

-- Evocazioni dei giocatori (forma di gigante)
function TitanService.SpawnAllies(owner: Player, count: number, position: Vector3, duration: number, level: number)
	local spawned = {}
	local zone = Zones.Find(position)
	for i = 1, count do
		local a = (i / count) * math.pi * 2
		local pos = position + Vector3.new(math.cos(a), 0, math.sin(a)) * 30
		local t = TitanService.Spawn({
			Class = if level > 800 then "T15" elseif level > 400 then "T12" else "T10",
			Level = level,
			Position = pos,
			Kind = "Ally",
			Owner = owner,
			Duration = duration,
			Zone = zone and zone.Id or nil,
		})
		if t then
			t.Home = position
			t.HomeRadius = 300
			table.insert(spawned, t)
		end
	end
	return spawned
end

function TitanService.SpawnRumbling(owner: Player, origin: Vector3, direction: Vector3, count: number, duration: number, level: number, damage: number)
	local dir = Util.SafeUnit(Util.Flat(direction))
	local right = Vector3.new(-dir.Z, 0, dir.X)
	for i = 1, count do
		local offset = (i - (count + 1) / 2) * 70
		local pos = origin - dir * 60 + right * offset
		local zone = Zones.Find(pos)
		local t = TitanService.Spawn({ Class = "TB", Level = level, Position = pos, Kind = "Ally", Owner = owner, Duration = duration, March = dir, Yaw = math.atan2(-dir.X, -dir.Z), Zone = zone and zone.Id or nil })
		if t then
			t.Speed = 26
			t.Damage = damage
			if t.AlignPos then
				t.AlignPos.MaxVelocity = 60
			end
		end
	end
	S.EventService.Effect("Rumbling", { Position = origin, Direction = dir }, origin, 1500)
end

function TitanService.StartInvasion(zoneId: string, duration: number)
	local zone = Zones.Get(zoneId)
	if not zone or not zone.Titans then
		return
	end
	for _, entry in zone.Titans do
		for _ = 1, math.max(2, math.floor(entry.Count * 0.8)) do
			TitanService.Spawn({
				Class = entry.Class,
				Level = entry.Level,
				Zone = zoneId,
				Abnormal = rng:NextNumber() < math.max(0.25, entry.Abnormal or 0),
				Look = entry.Look,
				Duration = duration,
				Invasion = true,
			})
		end
	end
end

-- BOSS ---------------------------------------------------------------------------------------

function TitanService.SpawnBoss(bossId: string)
	local def = Titans.Bosses[bossId]
	local state = bossStates[bossId]
	if not def or not state or state.Alive then
		return nil
	end
	local zone = Zones.Get(def.Zone)
	if not zone then
		return nil
	end
	local t = TitanService.Spawn({ Boss = bossId, Zone = def.Zone, Level = def.Level, Position = randomPointIn(zone, 0.5) })
	if t then
		state.Alive = t
		S.EventService.Announce(def.Name .. " è apparso!", ("%s - Livello %d - %s"):format(def.Title, def.Level, zone.Name), "Boss")
	end
	return t
end

function TitanService.ActiveBoss(bossId: string)
	local state = bossStates[bossId]
	return state and state.Alive
end

-- Sagome di legno del campo di addestramento
local function spawnDummies()
	local zone = Zones.Get("CampoAddestramento")
	if not zone then
		return
	end
	local area = zone.Center + Vector3.new(62, 0, -48)
	local positions = {}
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		table.insert(positions, area + Vector3.new(math.cos(a) * 22, 0, math.sin(a) * 22))
	end
	local spawner = { Zone = "CampoAddestramento", Class = "Sagoma", Level = 1, Count = #positions, Alive = {}, Positions = positions, Yaw = 0 }
	table.insert(spawners, spawner)
	for _, pos in positions do
		local t = TitanService.Spawn({ Class = "Sagoma", Level = 1, Zone = "CampoAddestramento", Position = pos, Spawner = spawner, Yaw = math.rad(rng:NextNumber(0, 360)) })
		if t then
			table.insert(spawner.Alive, t)
		end
	end
end

local function spawnZones()
	for _, zone in Zones.List do
		if zone.Titans then
			for _, entry in zone.Titans do
				local spawner = { Zone = zone.Id, Class = entry.Class, Level = entry.Level, Count = entry.Count, Abnormal = entry.Abnormal, Look = entry.Look, Alive = {} }
				table.insert(spawners, spawner)
				for _ = 1, entry.Count do
					local t = TitanService.Spawn({ Class = entry.Class, Level = entry.Level, Zone = zone.Id, Abnormal = rng:NextNumber() < (entry.Abnormal or 0), Look = entry.Look, Spawner = spawner })
					if t then
						table.insert(spawner.Alive, t)
					end
				end
				task.wait()
			end
		end
		if zone.Bosses then
			for _, bossId in zone.Bosses do
				bossStates[bossId] = { Alive = nil, NextSpawn = os.clock() + rng:NextNumber(15, 60) }
			end
		end
	end
end

-- Rimuove subito un gigante (usato a fine raid)
function TitanService.Despawn(t)
	if t and titans[t.Uid] then
		t.State = "Dead"
		if t.Holding then
			releaseHold(t, "Escaped")
		end
		despawn(t)
	end
end

function TitanService.Init(services)
	S = services
end

function TitanService.Start()
	titanFolder = workspace:WaitForChild(Config.Folders.Titans) :: Folder
	S.WorldBuilder.WaitReady()
	spawnDummies()
	spawnZones()

	Net.Event("EscapeMash").OnServerEvent:Connect(TitanService.EscapePress)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < Config.Titans.ThinkInterval then
			return
		end
		local step = accumulator
		accumulator = 0
		local roots = playerRoots()
		local radius = Config.Titans.ActivationRadius
		for _, t in titans do
			if t.State ~= "Dead" then
				local near = t.Kind == "Ally" or t.Kind == "Boss" and #roots > 0
				if not near then
					for _, entry in roots do
						if (entry.Position - t.Position).Magnitude < radius + t.Height then
							near = true
							break
						end
					end
				end
				if near then
					activate(t)
					local ok, err = pcall(think, t, roots, step)
					if not ok then
						warn("[TitanService] " .. tostring(err))
						t.Action = nil
					end
				else
					deactivate(t)
				end
			end
		end
		-- comparsa dei boss
		local now = os.clock()
		for bossId, state in bossStates do
			if not state.Alive and now >= state.NextSpawn then
				state.NextSpawn = now + 60
				TitanService.SpawnBoss(bossId)
			end
		end
	end)
end

return TitanService
