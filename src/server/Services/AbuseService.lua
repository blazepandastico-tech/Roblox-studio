--[[
	AbuseService - gli eventi a tempo dell'Admin Abuse (dati in Shared/Data/AbuseEvents)
	L'admin sceglie dal pannello il tipo di evento e quanti minuti dura: per tutti parte
	un'animazione (AbuseEventController sul client), poi per il tempo scelto:
	  - bonus di esperienza, oro e danni (attributi BonusXPAbuse, BonusGoldAbuse, BonusDannoAbuse)
	  - giganti, boss e razzi di segnalazione vicino ai giocatori, diversi per ogni evento
	A fine evento i giganti dell'evento spariscono e i bonus si tolgono.
	PREMI scelti dall'admin (AbuseEvents.Rewards): dolcetti per ogni gigante abbattuto, premio finale
	per chi ha partecipato (con la classifica dei cacciatori) e bonus doppi.
	Gli eventi di Halloween (solo nel file di Halloween) hanno il loro modo di far comparire i giganti:
	zucche che esplodono, fantasmi che valgono gemme, giganti che risorgono, zucche piene di dolci da
	raccogliere, pipistrelli sotto la luna di sangue.
	I client leggono lo stato dagli attributi di ReplicatedStorage:
	  AbuseEvento (id), AbuseInizio e AbuseFine (secondi del server), AbuseDurata,
	  AbusePremi (premi accesi, separati da virgole) e AbuseAnnuncio (il testo dell'admin).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared.Lib.Util)
local Zones = require(Shared.Data.Zones)
local Titans = require(Shared.Data.Titans)
local Items = require(Shared.Data.Items)
local Leveling = require(Shared.Data.Leveling)
local Tema = require(Shared.Data.Tema)
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
	Rewards: { [string]: boolean },
	Text: string?, -- annuncio dell'admin (già filtrato)
	By: string?,
	Kills: { [number]: number }, -- giganti dell'evento abbattuti da ogni giocatore (UserId)
	Names: { [number]: string },
	Candy: { any }, -- zucche piene di dolci da raccogliere (Dolcetto o Scherzetto)
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
	-- "Bonus doppi": l'esperienza e l'oro in più dell'evento raddoppiano
	local double = if current and current.Rewards.Doppio then 2 else 1
	player:SetAttribute("BonusXPAbuse", if bonus.XP and bonus.XP > 0 then bonus.XP * double else nil)
	player:SetAttribute("BonusGoldAbuse", if bonus.Gold and bonus.Gold > 0 then bonus.Gold * double else nil)
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

-- livello medio dei giocatori nel server (per i boss di Halloween, che crescono con chi c'è)
local function averageLevel(): (number, number)
	local total, count = 0, 0
	for _, player in Players:GetPlayers() do
		local profile = S.DataService.Get(player)
		if profile then
			total += profile.Level or 1
			count += 1
		end
	end
	return if count > 0 then total / count else 1, count
end

-- Il boss dell'evento: vicino a un giocatore che caccia, altrimenti nella sua zona di sempre
local function spawnBoss(ctx: Context, bossId: string)
	local def = Titans.Bosses[bossId]
	if not def then
		return nil
	end
	local level, hpMult = def.Level, nil
	if def.ScaleLevel then
		local avg, count = averageLevel()
		level = math.clamp(math.floor(avg * 1.05 + 0.5), def.Level, 1800)
		hpMult = 1 + 0.35 * math.max(0, count - 1)
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
	local t = spawnTitan(ctx, { Boss = bossId, Level = level, Zone = zoneId, Position = pos, HPMult = hpMult })
	if t then
		ctx.Boss = t
		S.EventService.Announce(def.Name .. " è apparso!", ("%s • Livello %d • %s"):format(def.Title or "Boss dell'evento", level, zone and zone.Name or ""), "Boss")
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


-- 🎃 EVENTI DI HALLOWEEN -------------------------------------------------------------------------------

-- un punto a terra vicino a un cacciatore (fuori dalle zone sicure), o nil
local function pointNear(hunter, minDist: number, maxDist: number): (Vector3?, any)
	for _ = 1, 6 do
		local pos = hunter.Root.Position + Util.Polar(rng:NextNumber(0, 360), rng:NextNumber(minDist, maxDist))
		local zone = Zones.Find(pos)
		if zone and not zone.Safe then
			return pos, zone
		end
	end
	return nil, nil
end

-- giganti che spuntano tutti insieme in un punto (dalle zucche, dalla terra...)
local function burstAt(ctx: Context, hunter, pos: Vector3, zone, count: number, costume: string?, effect: string)
	S.EventService.Effect(effect, { Position = pos }, pos, 2500)
	for _ = 1, count do
		local entry = pickEntry(hunter.Zone)
		spawnTitan(ctx, {
			Class = entry.Class,
			Level = entry.Level,
			Look = entry.Look,
			Zone = zone.Id,
			Position = pos + Util.Polar(rng:NextNumber(0, 360), rng:NextNumber(8, 30)),
			Abnormal = rng:NextNumber() < (entry.Abnormal or 0.2),
			Costume = costume,
		})
	end
end

-- La Notte delle Zucche: il Re Zucca (torna se viene abbattuto) e zucche che esplodono in giganti-zucca
TICK.NotteZucche = function(ctx)
	if due(ctx, "Boss", INTRO_TIME, 25) and not bossAlive(ctx) and remaining(ctx) > 30 then
		spawnBoss(ctx, "ReZucca")
	end
	if due(ctx, "Zucche", INTRO_TIME + 8, 28) then
		for _, hunter in huntingPlayers() do
			local pos, zone = pointNear(hunter, 70, 150)
			if pos and zone then
				burstAt(ctx, hunter, pos, zone, 2, "Zucca", "AbusePumpkinBurst")
			end
		end
	end
	if due(ctx, "Ondata", INTRO_TIME + 20, 50) then
		wavesForAll(ctx, 2)
	end
end

-- Il Gigante Fantasma: il grande spettro e, nella nebbia, giganti fantasma che valgono gemme
TICK.GiganteFantasma = function(ctx)
	if due(ctx, "Boss", INTRO_TIME + 6, 30) and not bossAlive(ctx) and remaining(ctx) > 40 then
		spawnBoss(ctx, "GiganteFantasma")
	end
	if due(ctx, "Fantasmi", INTRO_TIME, 22) then
		for _, hunter in huntingPlayers() do
			local pos, zone = pointNear(hunter, 90, 170)
			if pos and zone then
				local entry = pickEntry(hunter.Zone)
				local t = spawnTitan(ctx, { Class = entry.Class, Level = entry.Level, Look = "Spettro", Zone = zone.Id, Position = pos, Abnormal = rng:NextNumber() < 0.5 })
				if t then
					t.AbuseGems = ctx.Def.GhostGems or 3
					t.AbuseGemsText = "👻 Fantasma abbattuto"
					S.EventService.Effect("AbuseGhost", { Position = pos }, pos, 2500)
					S.EventService.Notify(hunter.Player, ("👻 Un gigante fantasma esce dalla nebbia! Vale %d 💎"):format(t.AbuseGems), "Raro", 4)
				end
			end
		end
	end
	if due(ctx, "Ondata", INTRO_TIME + 15, 50) then
		wavesForAll(ctx, 2)
	end
end

-- Il Risveglio dei Caduti: i giganti risorgono dalla terra vicino ai giocatori, tra fulmini verdi
TICK.RisveglioCaduti = function(ctx)
	if due(ctx, "Risveglio", INTRO_TIME, 18) then
		for _, hunter in huntingPlayers() do
			local pos, zone = pointNear(hunter, 60, 140)
			if pos and zone then
				burstAt(ctx, hunter, pos, zone, rng:NextInteger(2, 3), if rng:NextNumber() < 0.5 then "Zombie" else "Scheletro", "AbuseRise")
			end
		end
	end
	if due(ctx, "Ondata", INTRO_TIME + 30, 60) then
		wavesForAll(ctx, 2)
	end
end

-- Dolcetto o Scherzetto: zucche piene di dolci cadono vicino ai giocatori (si raccolgono passandoci)
local CANDY = AbuseEvents.CandyPumpkin

local function candyFolder(): Folder
	local f = workspace:FindFirstChild("DolcettiEvento")
	if f and f:IsA("Folder") then
		return f
	end
	local created = Instance.new("Folder")
	created.Name = "DolcettiEvento"
	created.Parent = workspace
	return created
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include

local function groundAt(pos: Vector3): Vector3
	groundParams.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(pos + Vector3.new(0, 300, 0), Vector3.new(0, -700, 0), groundParams)
	return if hit then hit.Position else pos
end

local function makeCandyPumpkin(at: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "ZuccaDeiDolcetti"
	local function p(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
		local x = Instance.new("Part")
		x.Name = name
		x.Size = size
		x.CFrame = cf
		x.Color = color
		x.Material = material or Enum.Material.SmoothPlastic
		x.Anchored = true
		x.CanCollide = false
		x.CanQuery = false
		x.CanTouch = false
		x.CastShadow = false
		x.Parent = model
		return x
	end
	local body = p("Zucca", Vector3.new(4.4, 3.4, 4.2), CFrame.new(at + Vector3.new(0, 1.7, 0)), Tema.Colors.Pumpkin)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = body
	p("Gambo", Vector3.new(0.5, 1, 0.5), CFrame.new(at + Vector3.new(0, 3.7, 0)), Tema.Colors.Stem, Enum.Material.Wood)
	p("Fiocco", Vector3.new(2.2, 0.5, 0.5), CFrame.new(at + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, 0, 0.3), Color3.fromRGB(230, 60, 150))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 200)
	light.Range = 16
	light.Brightness = 1.6
	light.Parent = body
	local gui = Instance.new("BillboardGui")
	gui.Name = "Insegna"
	gui.Size = UDim2.fromOffset(120, 40)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 260
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "🍬 Dolcetto?"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 200, 240)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	gui.Parent = body
	model.PrimaryPart = body
	return model
end

local function dropCandy(ctx: Context, hunter)
	local mine = 0
	for _, c in ctx.Candy do
		if c.Owner == hunter.Player then
			mine += 1
		end
	end
	if mine >= CANDY.PerPlayer then
		return
	end
	local pos = hunter.Root.Position + Util.Polar(rng:NextNumber(0, 360), rng:NextNumber(35, 80))
	local zone = Zones.Find(pos)
	if not zone or zone.Underground then
		return
	end
	local ground = groundAt(pos)
	-- la zucca vola dal cielo (la disegna il client) e arriva a terra un attimo dopo
	S.EventService.Effect("AbuseCandyDrop", { Position = ground }, ground, 1500)
	-- la zucca vera compare quando quella del client tocca terra (ReadyAt)
	table.insert(ctx.Candy, { Model = makeCandyPumpkin(ground), Position = ground, Owner = hunter.Player, Expires = os.clock() + CANDY.Lifetime, ReadyAt = os.clock() + 1.4 })
end

local TREATS = {
	{ Kind = "Oro", Weight = 50 },
	{ Kind = "Esperienza", Weight = 22 },
	{ Kind = "Gemme", Weight = 14 },
	{ Kind = "Giro", Weight = 4 },
}

local function openCandy(ctx: Context, entry, player: Player)
	local profile = S.DataService.Get(player)
	if not profile then
		return
	end
	local pos = entry.Position
	if rng:NextNumber() < CANDY.TrickChance then
		-- SCHERZETTO! un piccolo gigante salta fuori dalla zucca
		S.EventService.Effect("AbuseTrick", { Position = pos }, pos, 600)
		S.EventService.Notify(player, "😈 SCHERZETTO! Dalla zucca salta fuori un gigante!", "Errore", 4)
		local zone = Zones.Find(pos)
		if zone and not zone.Safe and zone.Titans and #zone.Titans > 0 then
			local e = pickEntry(zone)
			spawnTitan(ctx, { Class = e.Class, Level = e.Level, Look = e.Look, Zone = zone.Id, Position = pos + Util.Polar(rng:NextNumber(0, 360), 25), Costume = "Zucca" })
		end
		return
	end
	local total = 0
	for _, t in TREATS do
		total += t.Weight
	end
	local roll = rng:NextNumber() * total
	local kind = TREATS[1].Kind
	for _, t in TREATS do
		roll -= t.Weight
		if roll <= 0 then
			kind = t.Kind
			break
		end
	end
	local level = profile.Level or 1
	local text
	if kind == "Oro" then
		local gold = S.PlayerService.AddGold(player, Leveling.QuestGold(level) * 0.3)
		text = ("🍬 DOLCETTO! +%d oro"):format(gold)
	elseif kind == "Esperienza" then
		local xp = S.PlayerService.AddXP(player, Leveling.QuestXP(level) * 0.2)
		text = ("🍬 DOLCETTO! +%d esperienza"):format(xp)
	elseif kind == "Gemme" then
		local gems = rng:NextInteger(2, 5)
		profile.Gems += gems
		text = ("🍬 DOLCETTO! +%d 💎"):format(gems)
	else
		profile.Spins = (profile.Spins or 0) + 1
		text = "🍬 DOLCETTO! +1 giro della Ruota della Fortuna"
	end
	S.DataService.MarkDirty(player)
	S.EventService.Effect("AbuseCandy", { Position = pos }, pos, 600)
	S.EventService.Notify(player, text, "Ricompensa", 4)
end

local function updateCandy(ctx: Context)
	local now = os.clock()
	for i = #ctx.Candy, 1, -1 do
		local entry = ctx.Candy[i]
		local taken = false
		if now >= entry.ReadyAt and entry.Model then
			if not entry.Model.Parent then
				entry.Model.Parent = candyFolder()
			end
			for _, player in Players:GetPlayers() do
				local root = Util.GetRoot(player.Character)
				if root and (root.Position - entry.Position).Magnitude <= CANDY.PickupRadius then
					taken = true
					local ok, err = pcall(openCandy, ctx, entry, player)
					if not ok then
						warn("[Admin Abuse] " .. tostring(err))
					end
					break
				end
			end
		end
		if taken or now >= entry.Expires then
			if entry.Model then
				entry.Model:Destroy()
			end
			table.remove(ctx.Candy, i)
		end
	end
end

TICK.DolcettoScherzetto = function(ctx)
	if due(ctx, "Dolcetti", INTRO_TIME, CANDY.Every) then
		for _, hunter in huntingPlayers() do
			dropCandy(ctx, hunter)
		end
	end
	if due(ctx, "Ondata", INTRO_TIME + 10, 45) then
		wavesForAll(ctx, 2)
	end
end

-- La Luna di Sangue: ondate fitte, pipistrelli e ogni tanto un anomalo della luna che vale gemme
TICK.LunaSangue = function(ctx)
	if due(ctx, "Ondata", INTRO_TIME, 32) then
		wavesForAll(ctx, 4)
	end
	if due(ctx, "Pipistrelli", INTRO_TIME + 6, 20) then
		for _, hunter in huntingPlayers() do
			S.EventService.Effect("AbuseBats", { Position = hunter.Root.Position }, hunter.Root.Position, 400)
		end
	end
	if due(ctx, "Anomalo", INTRO_TIME + 12, 55) then
		local hunters = huntingPlayers()
		if #hunters > 0 then
			local hunter = hunters[rng:NextInteger(1, #hunters)]
			local entry = pickEntry(hunter.Zone, true)
			local pos, zone = pointNear(hunter, 120, 190)
			if pos and zone then
				local t = spawnTitan(ctx, { Class = entry.Class, Level = entry.Level, Look = entry.Look, Zone = zone.Id, Position = pos, Abnormal = true, Costume = "Corna" })
				if t then
					t.AbuseGems = 4
					t.AbuseGemsText = "🌕 Anomalo della luna abbattuto"
					S.EventService.Effect("AbuseFlare", { Position = pos, Kind = "Rosso" }, pos, 3000)
					S.EventService.Notify(hunter.Player, "🌕 Un anomalo della luna di sangue ti ha visto! Vale 4 💎", "Raro", 5)
				end
			end
		end
	end
end

-- AVVIO E FINE -----------------------------------------------------------------------------------------

local function rewardList(rewards: { [string]: boolean }?): string?
	if not rewards then
		return nil
	end
	local on = {}
	for _, r in AbuseEvents.Rewards do
		if rewards[r.Id] then
			table.insert(on, r.Id)
		end
	end
	return if #on > 0 then table.concat(on, ",") else nil
end

local function publish()
	local ctx = current
	ReplicatedStorage:SetAttribute("AbusePremi", if ctx then rewardList(ctx.Rewards) else nil)
	ReplicatedStorage:SetAttribute("AbuseAnnuncio", if ctx and ctx.Text and ctx.Text ~= "" then ctx.Text .. (if ctx.By then "  — " .. ctx.By else "") else nil)
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
	for _, c in ctx.Candy do
		if c.Model then
			c.Model:Destroy()
		end
	end
	table.clear(ctx.Candy)
	if ctx.Rewards.Partecipazione then
		local ok, err = pcall(AbuseService.RewardParticipants, ctx)
		if not ok then
			warn("[Admin Abuse] Premio finale: " .. tostring(err))
		end
	end
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

-- opts (facoltativo): Rewards = premi accesi (AbuseEvents.Rewards), Text = annuncio già filtrato,
-- By = nome dell'admin. Senza Rewards valgono i premi predefiniti del file (AbuseEvents.DefaultRewards).
function AbuseService.Launch(id: string, minutes: any, opts: any?): (boolean, string)
	local def = AbuseEvents.Get(id)
	if not def then
		return false, "Evento sconosciuto"
	end
	if not AbuseEvents.Available(def) then
		return false, "Questo evento c'è solo nel file di Halloween"
	end
	local o = if type(opts) == "table" then opts else {}
	local mins = AbuseEvents.ClampMinutes(minutes)
	if current then
		AbuseService.Stop("Sostituito")
	end
	local now = os.clock()
	local text = if type(o.Text) == "string" and o.Text ~= "" then string.sub(o.Text, 1, AbuseEvents.Schedule.MaxText) else nil
	current = {
		Def = def,
		Started = now,
		Ends = now + mins * 60,
		Titans = {},
		Timers = {},
		Boss = nil,
		Rewards = AbuseEvents.CleanRewards(o.Rewards),
		Text = text,
		By = if type(o.By) == "string" then o.By else nil,
		Kills = {},
		Names = {},
		Candy = {},
	}
	local ctx = current
	-- l'annuncio dell'admin compare nel titolo dell'animazione e, a fine animazione, a tutti
	if text then
		task.delay(INTRO_SECONDS + 1, function()
			if current == ctx then
				S.EventService.Announce("📢 " .. text, if ctx.By then "— " .. ctx.By else "Admin Abuse", "Raro")
			end
		end)
	end
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
	local rewards = AbuseEvents.RewardsText(ctx.Rewards)
	if rewards ~= "" then
		message ..= " · " .. rewards
	end
	if id == "CadutaMuro" then
		-- dice all'admin se il filmato userà il colosso 3D (Meshy) o quello costruito con le parti
		local ok, why = MeshTitan.Status("Colosso")
		message ..= if ok then " · colosso 3D ✔" else "\n⚠️ " .. why
	end
	return true, message
end

-- dolcetto per ogni gigante dell'evento abbattuto: oro (secondo il livello del gigante), a volte gemme
local function giveCandy(player: Player, profile, t)
	local c = AbuseEvents.Candy
	local mult = if t.Kind == "Boss" then c.BossMult else 1
	local gold = S.PlayerService.AddGold(player, math.floor((c.GoldBase + (t.Level or 1) * c.GoldPerLevel) * mult))
	local extra = ""
	if rng:NextNumber() < c.GemChance * mult then
		local gems = if t.Kind == "Boss" then rng:NextInteger(5, 10) else 1
		profile.Gems += gems
		extra = (" e %d 💎"):format(gems)
	elseif rng:NextNumber() < c.SpinChance then
		profile.Spins = (profile.Spins or 0) + 1
		extra = " e un giro della Ruota"
	end
	S.DataService.MarkDirty(player)
	S.EventService.Notify(player, ("🍬 Dolcetto: +%d oro%s"):format(gold, extra), "Ricompensa", 3)
end

local function onTitanKilled(t, _killer, contributors)
	local ctx = current
	if not contributors then
		return
	end
	local ofEvent = ctx ~= nil and t.AbuseEvent == ctx.Def.Id
	for _, player in contributors do
		local profile = S.DataService.Get(player)
		if profile then
			if ofEvent and ctx then
				ctx.Kills[player.UserId] = (ctx.Kills[player.UserId] or 0) + 1
				ctx.Names[player.UserId] = player.DisplayName
				if ctx.Rewards.Dolcetti then
					giveCandy(player, profile, t)
				end
			end
			local gems = t.AbuseGems
			if gems then
				profile.Gems += gems
				S.DataService.MarkDirty(player)
				S.EventService.Notify(player, ("%s: +%d 💎"):format(t.AbuseGemsText or "⚫ Gigante anomalo abbattuto", gems), "Ricompensa", 5)
			end
		end
	end
end

-- Premio finale: chi ha abbattuto almeno un gigante dell'evento riceve gemme e oro; i 3 migliori
-- cacciatori vengono annunciati e il primo vince gemme in più. Nel file di Halloween chi ne abbatte
-- almeno 3 vince anche un oggetto della Collezione di Halloween che non ha ancora.
function AbuseService.RewardParticipants(ctx: Context)
	local P = AbuseEvents.Participation
	local ranking = {}
	for userId, kills in ctx.Kills do
		table.insert(ranking, { UserId = userId, Kills = kills })
	end
	if #ranking == 0 then
		return 0
	end
	table.sort(ranking, function(a, b)
		return a.Kills > b.Kills
	end)
	local halloween = Tema.IsHalloween()
	local rewarded = 0
	for rank, entry in ranking do
		local player = Players:GetPlayerByUserId(entry.UserId)
		local profile = player and S.DataService.Get(player)
		if player and profile then
			local gems = math.min(P.GemsBase + entry.Kills * P.GemsPerKill, P.GemsMax)
			if rank == 1 then
				gems += P.TopGems
			end
			profile.Gems += gems
			local gold = S.PlayerService.AddGold(player, math.floor(Leveling.QuestGold(profile.Level or 1) * 0.25 * math.min(entry.Kills, P.GoldKillsMax)))
			local prize = nil
			if halloween and entry.Kills >= P.CollectionMinKills and S.InventoryService and S.InventoryService.Has then
				for _, itemId in Items.HalloweenCollection do
					if not S.InventoryService.Has(player, itemId) then
						S.InventoryService.Give(player, itemId, 1)
						local item = Items.Get(itemId)
						prize = item and item.Name or itemId
						break
					end
				end
			end
			S.DataService.MarkDirty(player)
			S.EventService.AnnounceTo(player, if rank == 1 then "🏆 MIGLIOR CACCIATORE DELL'EVENTO!" else "🎁 PREMIO DELL'EVENTO",
				("%d giganti abbattuti • +%d 💎 • +%d oro%s"):format(entry.Kills, gems, gold, if prize then " • 🎃 " .. prize else ""), "Ricompensa")
			rewarded += 1
		end
	end
	local podium = {}
	for i = 1, math.min(3, #ranking) do
		local e = ranking[i]
		table.insert(podium, ("%s %s (%d)"):format(({ "🥇", "🥈", "🥉" })[i], ctx.Names[e.UserId] or "?", e.Kills))
	end
	S.EventService.NotifyAll("🏆 Migliori cacciatori di " .. ctx.Def.Name .. ": " .. table.concat(podium, "  "), "Raro", 8)
	return rewarded
end

function AbuseService.Init(services)
	S = services
end

-- Per le prove automatiche: lo stato dell'evento in corso e un controllo delle zucche dei dolcetti
function AbuseService.DebugContext(): any
	return current
end

function AbuseService.CandyStep()
	if current then
		updateCandy(current)
	end
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
	local acc, candyAcc = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		candyAcc += dt
		if acc >= 1 then
			acc = 0
			AbuseService.Step()
		end
		-- le zucche dei dolcetti si raccolgono passandoci vicino (anche in volo coi rampini)
		if candyAcc >= 0.2 then
			candyAcc = 0
			local ctx = current
			if ctx and #ctx.Candy > 0 then
				local ok, err = pcall(updateCandy, ctx)
				if not ok then
					warn("[Admin Abuse] " .. tostring(err))
				end
			end
		end
	end)
end

return AbuseService
