--[[
	AbuseService - gli eventi a tempo dell'Admin Abuse (dati in Shared/Data/AbuseEvents)
	L'admin sceglie dal pannello il tipo di evento e quanti minuti dura: per tutti parte
	un'animazione (AbuseEventController sul client), poi per il tempo scelto:
	  - bonus di esperienza, oro e danni (attributi BonusXPAbuse, BonusGoldAbuse, BonusDannoAbuse)
	  - giganti, boss e razzi di segnalazione vicino ai giocatori, diversi per ogni evento
	A fine evento i giganti dell'evento spariscono e i bonus si tolgono.
	I client leggono lo stato dagli attributi di ReplicatedStorage:
	  AbuseEvento (id), AbuseInizio e AbuseFine (secondi del server), AbuseDurata.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared.Lib.Util)
local Zones = require(Shared.Data.Zones)
local Titans = require(Shared.Data.Titans)
local AbuseEvents = require(Shared.Data.AbuseEvents)
local MeshTitan = require(Shared.Anim.MeshTitan)

local AbuseService = {}
local S

local rng = Random.new()
local MAX_EVENT_TITANS = 45 -- giganti dell'evento vivi tutti insieme, al massimo
local INTRO_SECONDS = 17 -- durata della regia d'apertura sul client (giocatori bloccati e intoccabili)
local INTRO_TIME = INTRO_SECONDS + 1 -- giganti e boss arrivano solo quando tutti hanno ripreso i comandi

type Context = {
	Def: any,
	Started: number, -- os.clock()
	Ends: number, -- os.clock()
	Titans: { any },
	Timers: { [string]: number },
	Boss: any?,
}

local current: Context? = nil

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function remaining(ctx: Context): number
	return math.max(0, ctx.Ends - os.clock())
end

-- BONUS DEI GIOCATORI -------------------------------------------------------------------------------

local function applyBonus(player: Player)
	local def = current and current.Def
	local bonus = def and def.Bonus or {}
	player:SetAttribute("BonusXPAbuse", if bonus.XP and bonus.XP > 0 then bonus.XP else nil)
	player:SetAttribute("BonusGoldAbuse", if bonus.Gold and bonus.Gold > 0 then bonus.Gold else nil)
	player:SetAttribute("BonusDannoAbuse", if bonus.Damage and bonus.Damage > 0 then bonus.Damage else nil)
	player:SetAttribute("GasAbuse", if def and def.InfiniteGas then true else nil)
end

-- GIGANTI DELL'EVENTO --------------------------------------------------------------------------------

local function aliveTitans(ctx: Context): number
	local n = 0
	for i = #ctx.Titans, 1, -1 do
		local t = ctx.Titans[i]
		if t.State == "Dead" or not (t.Model and t.Model.Parent) then
			table.remove(ctx.Titans, i)
		else
			n += 1
		end
	end
	return n
end

-- I giocatori che si trovano in una zona con i giganti (le città sicure e il mare non contano)
local function huntingPlayers(): { { Player: Player, Root: BasePart, Zone: any } }
	local list = {}
	for _, player in Players:GetPlayers() do
		local root = Util.GetRoot(player.Character)
		local zone = root and Zones.Find(root.Position)
		if root and zone and not zone.Safe and zone.Titans and #zone.Titans > 0 then
			table.insert(list, { Player = player, Root = root, Zone = zone })
		end
	end
	return list
end

local function pickEntry(zone, strongest: boolean?)
	local entries = zone.Titans
	if strongest then
		local best = entries[1]
		for _, e in entries do
			if (e.Level or 0) > (best.Level or 0) then
				best = e
			end
		end
		return best
	end
	return entries[rng:NextInteger(1, #entries)]
end

local function spawnTitan(ctx: Context, spec): any
	if aliveTitans(ctx) >= MAX_EVENT_TITANS then
		return nil
	end
	spec.Duration = math.max(5, math.min(spec.Duration or remaining(ctx), remaining(ctx)))
	spec.Invasion = true -- ricompense piene, come nelle invasioni
	local t = S.TitanService.Spawn(spec)
	if t then
		t.AbuseEvent = ctx.Def.Id
		table.insert(ctx.Titans, t)
	end
	return t
end

-- Un'ondata di giganti attorno a un giocatore (a 110-220 passi da lui)
local function waveAround(ctx: Context, hunter, count: number, abnormal: boolean?)
	for _ = 1, count do
		local entry = pickEntry(hunter.Zone)
		local pos = hunter.Root.Position + Util.Polar(rng:NextNumber(0, 360), rng:NextNumber(110, 220))
		local zone = Zones.Find(pos)
		if zone and not zone.Safe then
			spawnTitan(ctx, {
				Class = entry.Class,
				Level = entry.Level,
				Look = entry.Look,
				Zone = zone.Id,
				Position = pos,
				Abnormal = abnormal or rng:NextNumber() < (entry.Abnormal or 0.2),
			})
		end
	end
end

local function wavesForAll(ctx: Context, count: number, abnormal: boolean?)
	for _, hunter in huntingPlayers() do
		waveAround(ctx, hunter, count, abnormal)
	end
end

-- Il boss dell'evento: vicino a un giocatore che caccia, altrimenti nella sua zona di sempre
local function spawnBoss(ctx: Context, bossId: string)
	local def = Titans.Bosses[bossId]
	if not def then
		return nil
	end
	local hunters = huntingPlayers()
	local pos, zoneId
	if #hunters > 0 then
		local hunter = hunters[rng:NextInteger(1, #hunters)]
		pos = hunter.Root.Position + Util.Polar(rng:NextNumber(0, 360), 230)
		local zone = Zones.Find(pos)
		zoneId = zone and zone.Id or hunter.Zone.Id
	else
		local zone = Zones.Get(def.Zone)
		if not zone then
			return nil
		end
		pos = zone.Center + Util.Polar(rng:NextNumber(0, 360), zone.Radius * 0.3)
		zoneId = zone.Id
	end
	local zone = Zones.Get(zoneId)
	local t = spawnTitan(ctx, { Boss = bossId, Level = def.Level, Zone = zoneId, Position = pos })
	if t then
		ctx.Boss = t
		S.EventService.Announce(def.Name .. " è apparso!", ("%s • Livello %d • %s"):format(def.Title or "Boss dell'evento", def.Level, zone and zone.Name or ""), "Boss")
	end
	return t
end

local function bossAlive(ctx: Context): boolean
	local b = ctx.Boss
	return b ~= nil and b.State ~= "Dead" and b.Model ~= nil and b.Model.Parent ~= nil
end

-- ogni "every" secondi (la prima volta dopo "first" secondi)
local function due(ctx: Context, key: string, first: number, every: number): boolean
	local now = os.clock()
	local at = ctx.Timers[key]
	if not at then
		ctx.Timers[key] = ctx.Started + first
		at = ctx.Timers[key]
	end
	if now >= at then
		ctx.Timers[key] = now + every
		return true
	end
	return false
end

-- COSA SUCCEDE IN OGNI EVENTO ----------------------------------------------------------------------

local TICK: { [string]: (Context) -> () } = {}

-- La Caduta del Muro: ondate di giganti ovunque e il Ghignante
TICK.CadutaMuro = function(ctx)
	if due(ctx, "Ondata", INTRO_TIME, 40) then
		wavesForAll(ctx, 4)
	end
	if due(ctx, "Ghignante", INTRO_TIME + 6, 1e9) then
		spawnBoss(ctx, "Ghignante")
	end
end

-- La Carica del Bastione: il boss corazzato (torna se viene abbattuto) e qualche gigante
TICK.CaricaBastione = function(ctx)
	if due(ctx, "Boss", INTRO_TIME, 20) and not bossAlive(ctx) and remaining(ctx) > 30 then
		spawnBoss(ctx, "Bastione")
		S.EventService.Effect("AbuseTremor", { Strength = 1 })
	end
	if due(ctx, "Ondata", INTRO_TIME + 20, 60) then
		wavesForAll(ctx, 2)
	end
end

-- L'Assedio di Calaneth: ondate fitte, invasione nel distretto e un gigante alleato per ognuno
TICK.AssedioCalaneth = function(ctx)
	if due(ctx, "Invasione", INTRO_TIME, 1e9) then
		S.TitanService.StartInvasion("Calaneth", math.min(remaining(ctx), 600))
	end
	if due(ctx, "Ondata", INTRO_TIME, 35) then
		wavesForAll(ctx, 5)
	end
	if due(ctx, "Alleati", INTRO_TIME + 4, 90) then
		for _, hunter in huntingPlayers() do
			local profile = S.DataService.Get(hunter.Player)
			local level = profile and profile.Level or 1
			S.TitanService.SpawnAllies(hunter.Player, 1, hunter.Root.Position, math.min(90, remaining(ctx)), level)
			S.EventService.Notify(hunter.Player, "🔥 Un gigante alleato combatte al tuo fianco!", "Raro", 4)
		end
	end
end

-- L'Urlo della Cacciatrice: il boss e, a ogni urlo, giganti anomali che corrono verso di voi
TICK.UrloCacciatrice = function(ctx)
	if due(ctx, "Boss", INTRO_TIME, 25) and not bossAlive(ctx) and remaining(ctx) > 30 then
		spawnBoss(ctx, "Cacciatrice")
	end
	if due(ctx, "Urlo", INTRO_TIME + 12, 30) then
		local where = if bossAlive(ctx) then ctx.Boss.Position else nil
		S.EventService.Effect("AbuseScream", { Position = where })
		wavesForAll(ctx, 3, true)
	end
end

-- La Spedizione: giganti anomali segnalati da un razzo nero, ognuno vale gemme
TICK.Spedizione = function(ctx)
	if due(ctx, "Anomalo", INTRO_TIME, 25) then
		local hunters = huntingPlayers()
		if #hunters > 0 then
			local hunter = hunters[rng:NextInteger(1, #hunters)]
			local entry = pickEntry(hunter.Zone, true)
			local pos = hunter.Root.Position + Util.Polar(rng:NextNumber(0, 360), rng:NextNumber(140, 200))
			local zone = Zones.Find(pos)
			if zone and not zone.Safe then
				local t = spawnTitan(ctx, { Class = entry.Class, Level = entry.Level, Look = entry.Look, Zone = zone.Id, Position = pos, Abnormal = true })
				if t then
					t.AbuseGems = ctx.Def.AnomalyGems or 5
					S.EventService.Effect("AbuseFlare", { Position = pos, Kind = "Nero" }, pos, 3000)
					S.EventService.Notify(hunter.Player, ("⚫ Razzo nero: un gigante anomalo vicino a te! Vale %d 💎"):format(t.AbuseGems), "Raro", 5)
				end
			end
		end
	end
	if due(ctx, "Ondata", INTRO_TIME + 10, 50) then
		wavesForAll(ctx, 2)
	end
end

-- Il Fulmine della Trasformazione: fulmini dorati che immobilizzano i giganti vicino ai giocatori
TICK.FulmineTrasformazione = function(ctx)
	if due(ctx, "Fulmine", INTRO_TIME, 9) then
		local hunters = huntingPlayers()
		if #hunters > 0 then
			local hunter = hunters[rng:NextInteger(1, #hunters)]
			local pos = hunter.Root.Position + Util.Polar(rng:NextNumber(0, 360), rng:NextNumber(40, 120))
			local frozen = S.TitanService.FreezeInRadius(pos, 70, 5)
			S.EventService.Effect("AbuseLightning", { Position = pos }, pos, 3000)
			if frozen > 0 then
				S.EventService.Notify(hunter.Player, ("⚡ Il fulmine ha immobilizzato %d giganti: colpisci la nuca!"):format(frozen), "Raro", 4)
			end
		end
	end
	if due(ctx, "Ondata", INTRO_TIME + 5, 45) then
		wavesForAll(ctx, 3)
	end
end

-- AVVIO E FINE -----------------------------------------------------------------------------------------

local function publish()
	local ctx = current
	ReplicatedStorage:SetAttribute("AbuseEvento", if ctx then ctx.Def.Id else nil)
	ReplicatedStorage:SetAttribute("AbuseInizio", if ctx then serverNow() - (os.clock() - ctx.Started) else nil)
	ReplicatedStorage:SetAttribute("AbuseFine", if ctx then serverNow() + remaining(ctx) else nil)
	ReplicatedStorage:SetAttribute("AbuseDurata", if ctx then ctx.Ends - ctx.Started else nil)
end

function AbuseService.Current(): (string?, number)
	if not current then
		return nil, 0
	end
	return current.Def.Id, remaining(current)
end

-- reason: "Tempo" (finito da solo), "Admin" (fermato dal pannello), "Sostituito" (ne parte un altro)
function AbuseService.Stop(reason: string?)
	local ctx = current
	if not ctx then
		return false
	end
	current = nil
	for _, t in ctx.Titans do
		if t.State ~= "Dead" then
			S.TitanService.Despawn(t)
		end
	end
	for _, player in Players:GetPlayers() do
		applyBonus(player)
	end
	publish()
	if reason ~= "Sostituito" then
		-- la scritta grande "EVENTO TERMINATO" la mostra il client: qui solo un messaggio piccolo
		S.EventService.NotifyAll(("⌛ %s è finito: grazie a tutti, alla prossima Admin Abuse!"):format(ctx.Def.Name), "Info", 5)
	end
	return true
end

function AbuseService.Launch(id: string, minutes: any): (boolean, string)
	local def = AbuseEvents.Get(id)
	if not def then
		return false, "Evento sconosciuto"
	end
	local mins = AbuseEvents.ClampMinutes(minutes)
	if current then
		AbuseService.Stop("Sostituito")
	end
	local now = os.clock()
	current = {
		Def = def,
		Started = now,
		Ends = now + mins * 60,
		Titans = {},
		Timers = {},
		Boss = nil,
	}
	for _, player in Players:GetPlayers() do
		applyBonus(player)
		-- durante l'animazione d'apertura i giocatori sono bloccati: nessun gigante può toccarli
		local protectedUntil = serverNow() + INTRO_SECONDS + 1
		local old = player:GetAttribute("CutsceneUntil")
		player:SetAttribute("CutsceneUntil", if type(old) == "number" then math.max(old, protectedUntil) else protectedUntil)
		if S.TitanService.ReleasePlayer then
			S.TitanService.ReleasePlayer(player)
		end
	end
	publish()
	local message = ("%s %s: %d minut%s"):format(def.Icon, def.Name, mins, if mins == 1 then "o" else "i")
	if id == "CadutaMuro" then
		-- dice all'admin se il filmato userà il colosso 3D (Meshy) o quello costruito con le parti
		local ok, why = MeshTitan.Status("Colosso")
		message ..= if ok then " · colosso 3D ✔" else "\n⚠️ " .. why
	end
	return true, message
end

local function onTitanKilled(t, _killer, contributors)
	local gems = t.AbuseGems
	if not gems or not contributors then
		return
	end
	for _, player in contributors do
		local profile = S.DataService.Get(player)
		if profile then
			profile.Gems += gems
			S.DataService.MarkDirty(player)
			S.EventService.Notify(player, ("⚫ Gigante anomalo abbattuto: +%d 💎"):format(gems), "Ricompensa", 5)
		end
	end
end

function AbuseService.Init(services)
	S = services
end

-- Un passo dell'evento (ogni secondo): finisce allo scadere del tempo, altrimenti fa succedere le cose
function AbuseService.Step()
	local ctx = current
	if not ctx then
		return
	end
	if remaining(ctx) <= 0 then
		AbuseService.Stop("Tempo")
		return
	end
	local tick = TICK[ctx.Def.Id]
	if tick then
		local ok, err = pcall(tick, ctx)
		if not ok then
			warn("[Admin Abuse] " .. tostring(err))
		end
	end
end

-- Per le prove automatiche: fa passare "seconds" secondi di evento
function AbuseService.FastForward(seconds: number)
	local ctx = current
	if not ctx then
		return
	end
	ctx.Started -= seconds
	ctx.Ends -= seconds
	for key, at in ctx.Timers do
		ctx.Timers[key] = at - seconds
	end
end

function AbuseService.Start()
	Players.PlayerAdded:Connect(function(player)
		if current then
			applyBonus(player)
		end
	end)
	S.TitanService.Killed:Connect(onTitanKilled)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 then
			acc = 0
			AbuseService.Step()
		end
	end)
end

return AbuseService
