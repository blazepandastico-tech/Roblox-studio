--[[
	PvPService
	Combattimento tra giocatori:
	  - si attiva dal menu (Opzioni) o parlando con il Maestro dei Duelli
	  - funziona solo fuori dalle zone sicure e solo se entrambi i giocatori l'hanno attivato
	  - nell'Arena dei Duelli è sempre attivo per tutti
	  - chi sconfigge un giocatore guadagna una taglia e gli ruba il 10% della sua
	L'attributo "PvPActive" del giocatore dice al client chi si può colpire.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Lib.Util)
local Net = require(Shared.Lib.Net)
local Zones = require(Shared.Data.Zones)

local PvPService = {}
local S

local P = Config.PvP

local lastCombat: { [Player]: number } = {}
local lastHitBy: { [Player]: { Attacker: Player, Time: number, Arena: boolean } } = {}

local function zoneAt(player: Player)
	local root = Util.GetRoot(player.Character)
	return root and Zones.Find(root.Position), root
end

local function computeActive(player: Player): boolean
	local profile = S.DataService.Get(player)
	if not profile or S.PlayerService.InCutscene(player) then
		return false
	end
	local zone, root = zoneAt(player)
	if not root then
		return false
	end
	if zone and zone.PvP then
		return true
	end
	if not profile.Settings.PvP then
		return false
	end
	if zone and (zone.Safe or zone.Raid) then
		return false
	end
	return true
end

function PvPService.IsActive(player: Player): boolean
	return player:GetAttribute("PvPActive") == true
end

function PvPService.InArena(player: Player): boolean
	local zone = zoneAt(player)
	return zone ~= nil and zone.PvP == true
end

function PvPService.SetEnabled(player: Player, on: boolean)
	local profile = S.DataService.Get(player)
	if not profile then
		return
	end
	if not on and os.clock() - (lastCombat[player] or 0) < P.ToggleCombatLock then
		S.EventService.Notify(player, ("Sei in combattimento: potrai spegnere il PvP tra %d secondi."):format(math.ceil(P.ToggleCombatLock - (os.clock() - lastCombat[player]))), "Errore", 3)
		Net.Event("PvPState"):FireClient(player, profile.Settings.PvP)
		return
	end
	profile.Settings.PvP = on
	S.DataService.MarkDirty(player)
	player:SetAttribute("PvPActive", computeActive(player))
	Net.Event("PvPState"):FireClient(player, on)
	if on then
		S.EventService.Notify(player, "⚔️ PvP ATTIVO: fuori dalle zone sicure puoi combattere con chi ha il PvP attivo.", "Errore", 4)
	else
		S.EventService.Notify(player, "🕊️ PvP spento (nell'Arena dei Duelli resta sempre attivo).", "Successo", 3)
	end
	S.PlayerService.UpdateNameplate(player)
end

-- Il giocatore di questo pezzo di corpo (nil se non è un giocatore)
function PvPService.PlayerFromPart(part: Instance?): Player?
	if typeof(part) ~= "Instance" then
		return nil
	end
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local owner = Players:GetPlayerFromCharacter(model)
		if owner then
			return owner
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

function PvPService.CanHit(attacker: Player, victim: Player): boolean
	if attacker == victim or not PvPService.IsActive(attacker) or not PvPService.IsActive(victim) then
		return false
	end
	local humanoid = victim.Character and victim.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	local state = S.PlayerService.GetState(victim)
	if state.Transformed then
		return false
	end
	return true
end

-- Danno di un giocatore a un altro: ridotto e limitato (un colpo non uccide mai da solo)
function PvPService.Damage(attacker: Player, victim: Player, raw: number, kind: string?): number
	if not PvPService.CanHit(attacker, victim) then
		return 0
	end
	local humanoid = victim.Character and victim.Character:FindFirstChildOfClass("Humanoid") :: Humanoid
	local maxHP = humanoid.MaxHealth
	local amount = math.clamp(raw * P.DamageScale, maxHP * P.MinHitFraction, maxHP * P.MaxHitFraction)
	local dealt = S.PlayerService.Damage(victim, amount, { Cause = attacker.DisplayName, Explosive = kind == "Explosion" })
	if dealt > 0 then
		local now = os.clock()
		lastCombat[attacker] = now
		lastCombat[victim] = now
		lastHitBy[victim] = { Attacker = attacker, Time = now, Arena = PvPService.InArena(victim) }
		if S.HorseService then
			S.HorseService.Dismount(victim, true)
		end
		local aRoot = Util.GetRoot(attacker.Character)
		local vRoot = Util.GetRoot(victim.Character)
		if aRoot and vRoot then
			local dir = Util.SafeUnit(Util.Flat(vRoot.Position - aRoot.Position))
			S.PlayerService.Knockback(victim, dir * 30 + Vector3.new(0, 14, 0), 0)
		end
	end
	return dealt
end

-- Esplosioni (lance dirompenti): colpiscono i giocatori con il PvP attivo nel raggio
function PvPService.DamageInRadius(attacker: Player, center: Vector3, radius: number, raw: number): { { Position: Vector3, Damage: number } }
	local results = {}
	for _, victim in Players:GetPlayers() do
		local root = Util.GetRoot(victim.Character)
		if root and victim ~= attacker and (root.Position - center).Magnitude <= radius and PvPService.CanHit(attacker, victim) then
			local dealt = PvPService.Damage(attacker, victim, raw, "Explosion")
			if dealt > 0 then
				table.insert(results, { Position = root.Position, Damage = dealt })
			end
		end
	end
	return results
end

local function updateBountyStat(player: Player)
	local profile = S.DataService.Get(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild("Taglia") :: IntValue?
	if profile and value then
		value.Value = math.floor(profile.Bounty or 0)
	end
	S.PlayerService.UpdateNameplate(player)
end

local function onDied(victim: Player)
	local hit = lastHitBy[victim]
	lastHitBy[victim] = nil
	if not hit or os.clock() - hit.Time > 10 then
		return
	end
	local killer = hit.Attacker
	if not killer.Parent or killer == victim then
		return
	end
	local kp = S.DataService.Get(killer)
	local vp = S.DataService.Get(victim)
	if not kp or not vp then
		return
	end
	local stolen = math.floor((vp.Bounty or 0) * P.BountySteal)
	local gain = math.floor((P.BountyBase + stolen) * (if hit.Arena then P.ArenaBountyMult else 1))
	kp.Bounty = (kp.Bounty or 0) + gain
	vp.Bounty = math.max(0, (vp.Bounty or 0) - stolen)
	kp.Kills.Players = (kp.Kills.Players or 0) + 1
	S.DataService.MarkDirty(killer)
	S.DataService.MarkDirty(victim)
	updateBountyStat(killer)
	updateBountyStat(victim)
	S.EventService.Notify(killer, ("⚔️ Hai sconfitto %s! Taglia +%s (ora %s)"):format(victim.DisplayName, Util.Abbreviate(gain), Util.Abbreviate(kp.Bounty)), "Ricompensa", 4)
	S.EventService.Notify(victim, ("💀 Sconfitto da %s%s"):format(killer.DisplayName, if stolen > 0 then (": ti ha preso %s di taglia"):format(Util.Abbreviate(stolen)) else ""), "Errore", 4)
	if stolen >= 250 then
		S.EventService.NotifyAll(("💰 %s ha riscosso la taglia di %s (%s)!"):format(killer.DisplayName, victim.DisplayName, Util.Abbreviate(stolen)), "Raro", 5)
	end
	if S.AchievementService then
		task.defer(S.AchievementService.Check, killer)
	end
	if S.FestivalService then
		S.FestivalService.Add(killer, "PvPKills", 1)
	end
end

function PvPService.Init(services)
	S = services
end

function PvPService.Start()
	S.DataService.OnLoaded(function(player, profile)
		local leaderstats = player:WaitForChild("leaderstats", 10)
		if leaderstats and not leaderstats:FindFirstChild("Taglia") then
			local bounty = Instance.new("IntValue")
			bounty.Name = "Taglia"
			bounty.Value = math.floor(profile.Bounty or 0)
			bounty.Parent = leaderstats
		end
		Net.Event("PvPState"):FireClient(player, profile.Settings.PvP == true)
	end)
	S.PlayerService.Died:Connect(onDied)
	Net.Event("PvPToggle").OnServerEvent:Connect(function(player, on)
		if type(on) == "boolean" then
			PvPService.SetEnabled(player, on)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastCombat[player] = nil
		lastHitBy[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local active = computeActive(player)
				if player:GetAttribute("PvPActive") ~= active then
					player:SetAttribute("PvPActive", active)
					S.PlayerService.UpdateNameplate(player)
				end
			end
		end
	end)
end

return PvPService
