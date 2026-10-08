--[[
	CombatService
	Convalida e applica gli attacchi dei giocatori:
	  - fendenti con le lame (combo da 4 colpi) e abilità Z/X/C/V
	  - armi a distanza (Lance Dirompenti, pistole, fucili, pistola di segnalazione)
	  - sostituzione delle lame, Risveglio Valkar
	Inoltra inoltre agli altri giocatori le animazioni (i cavi dei Rampini li convalida
	e inoltra ODMService).

	Il client rileva i colpi (così sono precisi anche a 150 studs/s) e il server
	controlla distanze, tempi di ricarica e danni: niente danni "inventati".
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Lib.Util)
local Net = require(Shared.Lib.Net)
local Items = require(Shared.Data.Items)
local Skills = require(Shared.Data.Skills)
local Bloodlines = require(Shared.Data.Bloodlines)
local Poses = require(Shared.Anim.Poses)

local CombatService = {}
local S
local rng = Random.new()

local COMBO_MULT = { 1, 1, 1.2, 1.6 }

local function aliveRoot(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local root = Util.GetRoot(character)
	local humanoid = Util.GetHumanoid(character)
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return root, humanoid
end

local function damageMultipliers(player: Player): number
	local profile = S.DataService.Get(player)
	local state = S.PlayerService.GetState(player)
	local mult = 1
	if profile and (profile.Buffs.DamageUntil or 0) > os.time() then
		mult *= 1 + (profile.Buffs.DamageAmount or 0.5)
	end
	if os.clock() < state.AwakenedUntil then
		local bloodline = Bloodlines.Get(profile and profile.Bloodline)
		mult *= bloodline.Awakening and bloodline.Awakening.DamageMult or 1.5
	end
	return mult
end

local function speedMultiplier(speed: number): number
	local c = Config.Combat
	local k = math.clamp((speed - c.SpeedBonusStart) / (c.SpeedBonusFull - c.SpeedBonusStart), 0, 1)
	return 1 + k * c.SpeedBonusMax
end

-- velocità credibile: quella vista dal server, con un po' di tolleranza per la latenza
local function effectiveSpeed(root: BasePart, claimed: any): number
	local serverSpeed = root.AssemblyLinearVelocity.Magnitude
	local claim = if type(claimed) == "number" and claimed == claimed then claimed else 0
	return math.max(serverSpeed, math.min(claim, serverSpeed * 1.4 + 35))
end

local function sendDamageNumber(player: Player, position: Vector3, amount: number, kind: string)
	Net.Event("DamageNumber"):FireClient(player, position, math.floor(amount + 0.5), kind)
end

local function addMastery(player: Player, amount: number)
	local profile = S.DataService.Get(player)
	if not profile then
		return
	end
	local blade = profile.Equipped.Blade
	if blade and blade ~= "" then
		local current = profile.WeaponMastery[blade] or 0
		if current < Config.Serums.MaxMastery then
			profile.WeaponMastery[blade] = math.min(Config.Serums.MaxMastery, current + amount)
			if math.floor(current / 25) ~= math.floor(profile.WeaponMastery[blade] / 25) then
				S.PlayerService.InvalidateStats(player)
				S.DataService.MarkDirty(player)
			end
		end
	end
end

-- Applica un colpo di lama a una parte (gigante o nemico umano).
-- Restituisce (colpito, bloccato): "bloccato" = corazza o pelle indurita, che consuma di più le lame.
local function bladeHit(player: Player, part: BasePart, baseDamage: number, speed: number, opts): (boolean, boolean)
	local stats = S.PlayerService.Stats(player)
	local profile = S.DataService.Get(player)
	local damage = baseDamage
	local crit = rng:NextNumber() < stats.CritChance
	if crit then
		damage *= Config.Player.CritMultiplier
	end
	local t = S.TitanService.GetFromPart(part)
	if t then
		local zone = part:GetAttribute("HitZone") or "Body"
		local perfect = false
		if zone == "Nape" and (speed >= Config.Combat.NapePerfectSpeed or (opts and opts.ForcePerfect)) then
			damage *= Config.Combat.NapePerfectMult
			perfect = true
		end
		local result = S.TitanService.ApplyDamage(t, player, damage, zone, { Perfect = perfect })
		if result then
			local kind = if result.Blocked then "Blocked" elseif perfect then "Perfect" elseif zone == "Nape" then "Nape" elseif crit then "Crit" else "Normal"
			sendDamageNumber(player, part.Position, result.Damage, kind)
			if result.Killed and zone == "Nape" and profile then
				profile.Kills.Napes += 1
				Net.Event("HitConfirm"):FireClient(player, { Kind = "NapeKill", Perfect = perfect })
			elseif result.Severed then
				Net.Event("HitConfirm"):FireClient(player, { Kind = "Sever" })
			end
			return true, result.Blocked == true
		end
		return false, false
	end
	local e = S.EnemyService.GetFromPart(part)
	if e then
		local result = S.EnemyService.ApplyDamage(e, player, damage)
		if result then
			sendDamageNumber(player, part.Position, result.Damage, if crit then "Crit" else "Normal")
			return true, false
		end
	end
	return false, false
end

local function validPart(part: any, root: BasePart, reach: number, speed: number): boolean
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") or not part:IsDescendantOf(workspace) then
		return false
	end
	local dist = (part.Position - root.Position).Magnitude - part.Size.Magnitude * 0.5
	local slack = Config.Combat.HitValidationSlack + speed * 0.22
	return dist <= reach + slack
end

-- FENDENTI ------------------------------------------------------------------------------

local function onAttack(player: Player, payload: any)
	if type(payload) ~= "table" then
		return
	end
	local root = aliveRoot(player)
	if not root then
		return
	end
	local state = S.PlayerService.GetState(player)
	if state.Transformed or state.GrabbedBy then
		return
	end
	local now = os.clock()
	if now - state.LastAttack < Config.Combat.MinAttackInterval then
		return
	end
	state.LastAttack = now
	local stats = S.PlayerService.Stats(player)
	local combo = math.clamp(math.floor(tonumber(payload.Combo) or 1), 1, 4)
	local speed = effectiveSpeed(root, payload.Speed)
	local broken = state.BladeDurability <= 0
	local base = stats.BladeDamage * COMBO_MULT[combo] * speedMultiplier(speed) * damageMultipliers(player)
	if broken then
		base *= Config.Combat.BrokenBladeMult
	end
	local hits = payload.Hits
	local anyHit = false
	local anyBlocked = false
	if type(hits) == "table" then
		local seen = {}
		local count = 0
		for _, part in hits do
			if count >= Config.Combat.MaxHitsPerSwing then
				break
			end
			if validPart(part, root, Config.Combat.BladeReach, speed) then
				local owner = Util.FindAncestorWithAttribute(part, "TitanUid") or Util.FindAncestorWithAttribute(part, "EnemyUid")
				if owner and not seen[owner] then
					seen[owner] = true
					count += 1
					local hit, blocked = bladeHit(player, part, base, speed)
					anyHit = anyHit or hit
					anyBlocked = anyBlocked or blocked
				elseif not owner and S.PvPService then
					-- PvP: un altro giocatore (solo se entrambi hanno il PvP attivo)
					local victim = S.PvPService.PlayerFromPart(part)
					if victim and not seen[victim] and S.PvPService.CanHit(player, victim) then
						seen[victim] = true
						count += 1
						local dealt = S.PvPService.Damage(player, victim, base, "Blade")
						if dealt > 0 then
							sendDamageNumber(player, part.Position, dealt, "Normal")
							anyHit = true
						end
					end
				end
			end
		end
	end
	if anyHit then
		if not broken then
			-- la carne dei giganti consuma le lame; le corazze molto di più
			local wear = 1 + (if anyBlocked then Config.Combat.ArmorBladeWear else 0)
			state.BladeDurability = math.max(0, state.BladeDurability - wear)
			if state.BladeDurability == 0 then
				S.EventService.Notify(player, "Lame spezzate! Premi R per sostituirle.", "Errore", 3)
			end
		end
		addMastery(player, 1)
		S.PlayerService.SyncResources(player)
	end
end

-- ABILITÀ DELLE LAME (Z X C V) -------------------------------------------------------------

local function onSkill(player: Player, key: any)
	if type(key) ~= "string" then
		return
	end
	local skill = Skills.Blade[key]
	local root = aliveRoot(player)
	if not skill or not root then
		return
	end
	local state = S.PlayerService.GetState(player)
	if state.Transformed or state.GrabbedBy then
		return
	end
	local stats = S.PlayerService.Stats(player)
	if (stats.BladeMastery or 0) < skill.Mastery then
		S.EventService.Notify(player, ("Serve maestria %d con queste lame."):format(skill.Mastery), "Errore", 2.5)
		return
	end
	local now = os.clock()
	local readyAt = state.SkillCooldowns[key] or 0
	if now < readyAt - 0.25 then
		return
	end
	state.SkillCooldowns[key] = now + skill.Cooldown
	state.ActiveSkill = {
		Key = key,
		Ends = now + skill.Duration + 0.8,
		Hits = 0,
		PerTarget = {},
	}
	if key == "V" then
		-- Danza delle Lame: invulnerabile durante l'assalto
		state.IFramesUntil = now + skill.Duration
	end
end

local function onSkillHit(player: Player, key: any, hits: any)
	if type(key) ~= "string" or type(hits) ~= "table" then
		return
	end
	local skill = Skills.Blade[key]
	local root = aliveRoot(player)
	local state = S.PlayerService.GetState(player)
	local active = state.ActiveSkill
	if not skill or not root or not active or active.Key ~= key or os.clock() > active.Ends then
		return
	end
	local stats = S.PlayerService.Stats(player)
	local speed = effectiveSpeed(root, nil)
	local reach = (skill.Radius or 14) + (skill.Distance or 0) * 0.5 + (if key == "V" then 30 else 0)
	local perTargetLimit = if skill.Ticks then skill.Ticks elseif skill.Hits then skill.Hits else 1
	local base = stats.BladeDamage * skill.Damage * speedMultiplier(math.max(speed, if key == "V" then 120 else 0)) * damageMultipliers(player)
	if state.BladeDurability <= 0 then
		base *= Config.Combat.BrokenBladeMult
	end
	local anyHit = false
	for _, part in hits do
		if active.Hits >= skill.MaxHits * 2 then
			break
		end
		if validPart(part, root, reach, speed) then
			local owner = Util.FindAncestorWithAttribute(part, "TitanUid") or Util.FindAncestorWithAttribute(part, "EnemyUid")
			local victim = if not owner and S.PvPService then S.PvPService.PlayerFromPart(part) else nil
			if victim and S.PvPService.CanHit(player, victim) then
				local done = active.PerTarget[victim] or 0
				if done < perTargetLimit then
					active.PerTarget[victim] = done + 1
					active.Hits += 1
					local dealt = S.PvPService.Damage(player, victim, base, "Skill")
					if dealt > 0 then
						sendDamageNumber(player, part.Position, dealt, "Crit")
						anyHit = true
					end
				end
			elseif owner then
				local done = active.PerTarget[owner] or 0
				if done < perTargetLimit then
					active.PerTarget[owner] = done + 1
					active.Hits += 1
					if (bladeHit(player, part, base, speed, { ForcePerfect = key == "V" })) then
						anyHit = true
					end
				end
			end
		end
	end
	if anyHit then
		addMastery(player, 1)
		if state.BladeDurability > 0 and rng:NextNumber() < 0.5 then
			state.BladeDurability -= 1
		end
		S.PlayerService.SyncResources(player)
	end
end

-- ARMI A DISTANZA ----------------------------------------------------------------------------

local function onRanged(player: Player, payload: any)
	if type(payload) ~= "table" or typeof(payload.HitPos) ~= "Vector3" then
		return
	end
	local root = aliveRoot(player)
	if not root then
		return
	end
	local state = S.PlayerService.GetState(player)
	if state.Transformed or state.GrabbedBy then
		return
	end
	local profile = S.DataService.Get(player)
	local def = profile and Items.Get(profile.Equipped.Ranged)
	if not def then
		return
	end
	local now = os.clock()
	if now - state.LastRanged < def.Cooldown * 0.8 then
		return
	end
	if state.RangedAmmo <= 0 then
		S.EventService.Notify(player, "Munizioni finite! Riforniscile a un Deposito.", "Errore", 2.5)
		return
	end
	local hitPos: Vector3 = payload.HitPos
	if (hitPos - root.Position).Magnitude > def.Range + 40 then
		return
	end
	state.LastRanged = now
	state.RangedAmmo -= 1
	S.PlayerService.SyncResources(player)
	local stats = S.PlayerService.Stats(player)
	local damage = stats.RangedDamage * damageMultipliers(player)
	local hitPart = payload.HitPart
	if typeof(hitPart) ~= "Instance" or not hitPart:IsA("BasePart") or not hitPart:IsDescendantOf(workspace) then
		hitPart = nil
	end
	local kind = def.Kind
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	S.EventService.Effect("RangedShot", { From = origin, To = hitPos, Kind = kind, Color = def.ProjectileColor, Shooter = player }, origin, 900)

	if kind == "Lancia" or kind == "Cannone" then
		-- la lancia si conficca, la miccia lampeggia e poi esplode (il cannone esplode subito)
		local offset = nil
		if hitPart then
			offset = hitPart.CFrame:PointToObjectSpace(hitPos)
		end
		local delay = if kind == "Cannone" then 0.25 else (def.Fuse or Config.Combat.SpearFuse)
		if kind == "Lancia" then
			S.EventService.Effect("SpearArmed", {
				Part = hitPart,
				Offset = offset,
				Position = hitPos,
				From = origin,
				Fuse = delay,
				Color = def.ProjectileColor,
			}, hitPos, 900)
		end
		task.delay(delay, function()
			local pos = hitPos
			if hitPart and offset and hitPart.Parent then
				pos = hitPart.CFrame:PointToWorldSpace(offset)
			end
			local radius = def.Radius or 16
			local results = S.TitanService.DamageInRadius(pos, radius, damage, player, { Explosive = true, ArmorBreak = true })
			for _, r in results do
				sendDamageNumber(player, r.Position, r.Result.Damage, if r.Result.Blocked then "Blocked" else "Explosion")
			end
			local humans = S.EnemyService.DamageInRadius(pos, radius, damage * 0.8, player)
			for _, r in humans do
				sendDamageNumber(player, r.Position, r.Result.Damage, "Explosion")
			end
			if S.PvPService then
				for _, hit in S.PvPService.DamageInRadius(player, pos, radius, damage * 0.6) do
					sendDamageNumber(player, hit.Position, hit.Damage, "Explosion")
				end
			end
			S.EventService.Effect("Explosion", { Position = pos, Radius = radius, Big = kind == "Cannone" }, pos, 1000)
			if def.Chain then
				task.delay(0.35, function()
					local second = S.TitanService.DamageInRadius(pos, radius * 1.4, damage * 0.5, player, { Explosive = true })
					for _, r in second do
						sendDamageNumber(player, r.Position, r.Result.Damage, "Explosion")
					end
					S.EventService.Effect("Explosion", { Position = pos + Vector3.new(0, 6, 0), Radius = radius * 1.4 }, pos, 1000)
				end)
			end
		end)
		return
	end

	if not hitPart then
		return
	end
	local victim = S.PvPService and S.PvPService.PlayerFromPart(hitPart)
	if victim then
		local dealt = S.PvPService.Damage(player, victim, damage, "Ranged")
		if dealt > 0 then
			sendDamageNumber(player, hitPart.Position, dealt, "Crit")
		end
		return
	end
	local t = S.TitanService.GetFromPart(hitPart)
	if t then
		local zone = hitPart:GetAttribute("HitZone") or "Body"
		if kind == "Segnalatore" then
			if zone == "Eye" or hitPart.Name == "Head" then
				S.TitanService.Blind(t, def.BlindTime or 3)
				S.EventService.Notify(player, "Gigante accecato!", "Successo", 1.5)
			end
		end
		local result = S.TitanService.ApplyDamage(t, player, damage, if zone == "Nape" then "Body" else zone, {})
		if result then
			sendDamageNumber(player, hitPart.Position, result.Damage, "Normal")
		end
		return
	end
	local e = S.EnemyService.GetFromPart(hitPart)
	if e then
		local result = S.EnemyService.ApplyDamage(e, player, damage * (def.HumanBonus or 1))
		if result then
			sendDamageNumber(player, hitPart.Position, result.Damage, "Crit")
		end
	end
end

local function onReload(player: Player)
	local state = S.PlayerService.GetState(player)
	local stats = S.PlayerService.Stats(player)
	local now = os.clock()
	if now - state.LastReload < Config.Combat.ReloadTime then
		return
	end
	if state.BladeDurability >= stats.BladeDurability then
		return
	end
	if state.BladeSpares <= 0 then
		S.EventService.Notify(player, "Nessuna lama di ricambio! Vai a un Deposito di Rifornimento.", "Errore", 3)
		return
	end
	state.LastReload = now
	state.BladeSpares -= 1
	state.BladeDurability = stats.BladeDurability
	S.PlayerService.SyncResources(player)
end

local function onAwaken(player: Player)
	local profile = S.DataService.Get(player)
	local root = aliveRoot(player)
	if not profile or not root then
		return
	end
	local bloodline = Bloodlines.Get(profile.Bloodline)
	local awakening = bloodline.Awakening
	if not awakening then
		S.EventService.Notify(player, "Solo il sangue Valkar può risvegliarsi.", "Errore", 2.5)
		return
	end
	if profile.Level < awakening.Level then
		S.EventService.Notify(player, ("Il Risveglio si sblocca al livello %d."):format(awakening.Level), "Errore", 2.5)
		return
	end
	local state = S.PlayerService.GetState(player)
	local now = os.clock()
	if now < state.AwakenReadyAt then
		return
	end
	state.AwakenedUntil = now + awakening.Duration
	state.AwakenReadyAt = now + awakening.Cooldown
	player:SetAttribute("AwakenedUntil", workspace:GetServerTimeNow() + awakening.Duration)
	S.EventService.Effect("Awaken", { Character = player.Character, Duration = awakening.Duration }, root.Position, 600)
	S.EventService.Notify(player, "RISVEGLIO ACKERMAN!", "Raro", 3)
end

-- INOLTRO ANIMAZIONI -------------------------------------------------------------------------------

local allowedClips = {}
for name in Poses.Human.Clips do
	allowedClips[name] = true
end

local relayBudget: { [Player]: { Count: number, Reset: number } } = {}

local function withinBudget(player: Player, limit: number): boolean
	local now = os.clock()
	local budget = relayBudget[player]
	if not budget or now >= budget.Reset then
		budget = { Count = 0, Reset = now + 1 }
		relayBudget[player] = budget
	end
	budget.Count += 1
	return budget.Count <= limit
end

local function relayToNearby(remote: any, sender: Player, radius: number, ...)
	local root = Util.GetRoot(sender.Character)
	if not root then
		return
	end
	for _, other in Players:GetPlayers() do
		if other ~= sender then
			local otherRoot = Util.GetRoot(other.Character)
			if otherRoot and (otherRoot.Position - root.Position).Magnitude <= radius then
				remote:FireClient(other, sender, ...)
			end
		end
	end
end

local function onAnimRelay(player: Player, clip: any, speed: any)
	if type(clip) ~= "string" or not allowedClips[clip] then
		return
	end
	if not withinBudget(player, 20) then
		return
	end
	relayToNearby(Net.Unreliable("AnimRelay"), player, 500, clip, if type(speed) == "number" then math.clamp(speed, 0.2, 3) else 1)
end

function CombatService.Init(services)
	S = services
end

function CombatService.Start()
	Net.Event("Attack").OnServerEvent:Connect(onAttack)
	Net.Event("Skill").OnServerEvent:Connect(onSkill)
	Net.Event("SkillHit").OnServerEvent:Connect(onSkillHit)
	Net.Event("Ranged").OnServerEvent:Connect(onRanged)
	Net.Event("ReloadBlades").OnServerEvent:Connect(onReload)
	Net.Event("Awaken").OnServerEvent:Connect(onAwaken)
	Net.Unreliable("AnimRelay").OnServerEvent:Connect(onAnimRelay)
	Players.PlayerRemoving:Connect(function(player)
		relayBudget[player] = nil
	end)
end

return CombatService
