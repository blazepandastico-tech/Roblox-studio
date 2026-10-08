--[[
	FestivalService - l'evento "Grande Inaugurazione" (date e premi in Shared/Data/Festival)
	  - esperienza e oro doppi, regalo di benvenuto, cerimonia d'apertura (scena animata)
	  - il Colosso d'Oro che cade dal cielo ogni 30 minuti nelle Pianure Meridionali
	  - spettacoli di fuochi d'artificio sopra le città ogni 10 minuti
	  - 8 sfide con premi e il Mantello dell'Inaugurazione per chi le completa tutte
	  - addobbi di festa nelle città (archi, bandiere, festoni di luci, coriandoli)
	Il client legge lo stato dagli attributi di ReplicatedStorage (FestaAttiva, FestaFine, ...).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Lib.Util)
local Net = require(Shared.Lib.Net)
local Zones = require(Shared.Data.Zones)
local W = require(Shared.Data.WorldLayout)
local Titans = require(Shared.Data.Titans)
local Festival = require(Shared.Data.Festival)

local FestivalService = {}
local S

local active = false
local override: boolean? = nil -- scelta dell'admin (nil = segue le date)
local colossus: any = nil
local decorations: Folder? = nil
local rng = Random.new()
local nextBossClock = 0
local nextFireworksClock = 0

local function clockToUnix(clockTime: number): number
	return math.floor(os.time() + (clockTime - os.clock()))
end

local function publish()
	ReplicatedStorage:SetAttribute("FestaAttiva", active)
	ReplicatedStorage:SetAttribute("FestaNome", Festival.Name)
	ReplicatedStorage:SetAttribute("FestaFine", if override == true then 0 else Festival.End)
	ReplicatedStorage:SetAttribute("FestaProssimoBoss", clockToUnix(nextBossClock))
	ReplicatedStorage:SetAttribute("FestaProssimiFuochi", clockToUnix(nextFireworksClock))
end

function FestivalService.IsActive(): boolean
	return active
end

-- DATI DEL GIOCATORE ------------------------------------------------------------------------------------

local function festivalData(profile)
	local f = profile.Festival
	if type(f) ~= "table" or f.Id ~= Festival.Id then
		f = { Id = Festival.Id, Gift = false, Ceremony = false, Final = false, Progress = {}, Done = {}, Islets = {} }
		profile.Festival = f
	end
	f.Progress = f.Progress or {}
	f.Done = f.Done or {}
	f.Islets = f.Islets or {}
	return f
end

local function applyBonus(player: Player)
	local adminXP = ReplicatedStorage:GetAttribute("EventoXP") == true
	player:SetAttribute("BonusXPEvento", if active then Festival.XPBonus elseif adminXP then 1 else nil)
	player:SetAttribute("BonusGoldEvento", if active then Festival.GoldBonus else nil)
end

local function checkFinal(player: Player, profile, f)
	if f.Final then
		return
	end
	for _, c in Festival.Challenges do
		if not f.Done[c.Id] then
			return
		end
	end
	f.Final = true
	profile.Gems += Festival.FinalGems
	if S.InventoryService then
		S.InventoryService.Give(player, Festival.FinalItem, 1)
	end
	S.EventService.AnnounceTo(player, "🏆 TUTTE LE SFIDE COMPLETATE!", ("Mantello dell'Inaugurazione (esclusivo) + %d 💎"):format(Festival.FinalGems), "Raro")
	S.EventService.NotifyAll(("🏆 %s ha completato tutte le sfide della Grande Inaugurazione!"):format(player.DisplayName), "Raro", 6)
	S.EventService.EffectTo(player, "Confetti", { Big = true })
end

-- Registra un progresso per le sfide dell'evento (es. "Titans", "Treasures", "Meal")
function FestivalService.Add(player: Player, stat: string, amount: number?)
	if not active then
		return
	end
	local profile = S.DataService.Get(player)
	if not profile then
		return
	end
	local f = festivalData(profile)
	local changed = false
	for _, c in Festival.Challenges do
		if c.Stat == stat and not f.Done[c.Id] then
			local value = math.min(c.Goal, (f.Progress[c.Id] or 0) + (amount or 1))
			f.Progress[c.Id] = value
			changed = true
			if value >= c.Goal then
				f.Done[c.Id] = true
				profile.Gems += c.Gems
				S.PlayerService.AddGold(player, c.Gold)
				S.EventService.Notify(player, ("%s Sfida dell'Inaugurazione completata: %s!  +%d 💎"):format(c.Icon, c.Name, c.Gems), "Ricompensa", 5)
				S.EventService.EffectTo(player, "Confetti", {})
				checkFinal(player, profile, f)
			end
		end
	end
	if changed then
		S.DataService.MarkDirty(player)
	end
end

local function welcome(player: Player, profile)
	if not active or not player.Parent then
		return
	end
	applyBonus(player)
	local f = festivalData(profile)
	if not f.Gift then
		f.Gift = true
		profile.Gems += Festival.WelcomeGems
		if S.InventoryService then
			S.InventoryService.Give(player, Festival.WelcomeItem, 1)
		end
		S.DataService.MarkDirty(player)
		S.EventService.AnnounceTo(player, "🎉 Benvenuto alla Grande Inaugurazione!", ("Regalo: %d 💎 e la Medaglia dell'Inaugurazione (Menu → Equipaggiamento)"):format(Festival.WelcomeGems), "Raro")
	end
end

-- Cerimonia d'apertura: la scena animata, una volta per giocatore
function FestivalService.Ceremony(player: Player, force: boolean?)
	local profile = S.DataService.Get(player)
	if not profile or (not active and not force) then
		return
	end
	local f = festivalData(profile)
	if f.Ceremony and not force then
		return
	end
	f.Ceremony = true
	S.DataService.MarkDirty(player)
	player:SetAttribute("CutsceneUntil", workspace:GetServerTimeNow() + 90)
	if S.TitanService then
		S.TitanService.ReleasePlayer(player)
	end
	Net.Event("Cutscene"):FireClient(player, "Inaugurazione")
end

-- IL COLOSSO D'ORO -----------------------------------------------------------------------------------------

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.IgnoreWater = true

local function groundAt(pos: Vector3): Vector3
	groundParams.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(pos.X, 500, pos.Z), Vector3.new(0, -800, 0), groundParams)
	return Vector3.new(pos.X, if hit then hit.Position.Y else W.GroundY, pos.Z)
end

-- Il livello del Colosso è quello "medio" dei giocatori presenti (così è una sfida per tutti)
local function colossusLevel(): number
	local levels = {}
	for _, player in Players:GetPlayers() do
		local profile = S.DataService.Get(player)
		if profile then
			table.insert(levels, profile.Level)
		end
	end
	if #levels == 0 then
		return 50
	end
	table.sort(levels)
	return math.clamp(levels[math.ceil(#levels / 2)], 10, Config.MaxLevel)
end

local function goldenAura(model: Model)
	local torso = model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso") or model.PrimaryPart
	if not torso or not torso:IsA("BasePart") then
		return
	end
	local glow = Instance.new("PointLight")
	glow.Name = "AuraDorata"
	glow.Color = Color3.fromRGB(255, 210, 110)
	glow.Range = 60
	glow.Brightness = 2.5
	glow.Parent = torso
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "PolvereDorata"
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 230, 140), Color3.fromRGB(255, 180, 60))
	sparkles.LightEmission = 1
	sparkles.Rate = 40
	sparkles.Lifetime = NumberRange.new(1.2, 2.2)
	sparkles.Speed = NumberRange.new(4, 10)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Parent = torso
end

function FestivalService.SpawnColossus(position: Vector3?): boolean
	if colossus and colossus.State ~= "Dead" and colossus.Model.Parent then
		return false
	end
	local def = Titans.Bosses[Festival.Boss.Id]
	local zone = Zones.Get(Festival.Boss.Zone)
	if not def or not zone then
		return false
	end
	local spot = position or (zone.Center + Util.Polar(rng:NextNumber(0, 360), rng:NextNumber(0, zone.Radius * 0.45)))
	local ground = groundAt(spot)
	local level = colossusLevel()
	-- arriva dal cielo come una meteora d'oro: prima l'effetto, poi il gigante all'impatto
	S.EventService.Effect("ColossusArrival", { Position = ground, Height = def.Height }, ground, 4000)
	task.wait(2.2)
	local players = math.max(1, #Players:GetPlayers())
	local t = S.TitanService.Spawn({
		Boss = def.Id,
		Level = level,
		Zone = zone.Id,
		Position = ground,
		HPMult = 1 + Festival.Boss.HPPerPlayer * (players - 1),
		Yaw = rng:NextNumber(0, math.pi * 2),
	})
	if not t then
		return false
	end
	colossus = t
	goldenAura(t.Model)
	ReplicatedStorage:SetAttribute("FestaBossPos", ground)
	S.EventService.Announce("👑 IL COLOSSO D'ORO È ATTERRATO!", ("Livello %d • %s (Vermiglia) • ricompense d'oro per tutti quelli che combattono!"):format(level, zone.Name), "Boss")
	S.EventService.Effect("Roar", { Position = ground + Vector3.new(0, def.Height * 0.8, 0), Height = def.Height }, ground, 2500)
	task.delay(Festival.Boss.Lifetime, function()
		if colossus == t and t.State ~= "Dead" then
			S.TitanService.Despawn(t)
			colossus = nil
			ReplicatedStorage:SetAttribute("FestaBossPos", nil)
			S.EventService.Announce("Il Colosso d'Oro è tornato nel cielo...", "Tornerà tra poco: preparatevi meglio!", "Info")
		end
	end)
	return true
end

local function onTitanKilled(t, _killer, contributors)
	if not active then
		return
	end
	for _, player in contributors do
		FestivalService.Add(player, "Titans", 1)
	end
	if t.BossId ~= Festival.Boss.Id then
		return
	end
	if colossus == t then
		colossus = nil
	end
	ReplicatedStorage:SetAttribute("FestaBossPos", nil)
	for _, player in contributors do
		local profile = S.DataService.Get(player)
		if profile then
			profile.Gems += Festival.Boss.Gems
			S.PlayerService.AddGold(player, Festival.Boss.Gold)
			S.DataService.MarkDirty(player)
			S.EventService.Notify(player, ("👑 Hai sconfitto il Colosso d'Oro! +%d 💎 e oro"):format(Festival.Boss.Gems), "Ricompensa", 5)
			S.EventService.EffectTo(player, "Confetti", { Big = true })
		end
		FestivalService.Add(player, "Colossus", 1)
	end
	S.EventService.Effect("Fireworks", { Center = t.Position, Duration = 12, Seed = rng:NextInteger(1, 1e6) }, t.Position, 2000)
	S.EventService.NotifyAll("👑 Il Colosso d'Oro è stato sconfitto! Tornerà tra 30 minuti.", "Raro", 6)
end

-- FUOCHI D'ARTIFICIO ---------------------------------------------------------------------------------------

function FestivalService.FireworksAt(center: Vector3, duration: number?)
	S.EventService.Effect("Fireworks", { Center = center, Duration = duration or Festival.Fireworks.Duration, Seed = rng:NextInteger(1, 1e6) }, center, Festival.Fireworks.Range)
end

local function fireworksShow()
	local range = Festival.Fireworks.Range
	for _, zoneId in Festival.Fireworks.Zones do
		local zone = Zones.Get(zoneId)
		if zone then
			FestivalService.FireworksAt(zone.Center)
			for _, player in Players:GetPlayers() do
				local root = Util.GetRoot(player.Character)
				if root and Util.FlatDistance(root.Position, zone.Center) < range then
					FestivalService.Add(player, "Fireworks", 1)
					S.EventService.Notify(player, "🎆 Spettacolo di fuochi d'artificio! Guarda il cielo sopra la città.", "Raro", 4)
				end
			end
		end
	end
end

-- ADDOBBI -------------------------------------------------------------------------------------------------

local GOLD = Color3.fromRGB(226, 176, 64)
local RED = Color3.fromRGB(176, 36, 40)
local BULBS = { Color3.fromRGB(255, 210, 110), Color3.fromRGB(255, 120, 100), Color3.fromRGB(140, 220, 255), Color3.fromRGB(160, 255, 160), Color3.fromRGB(255, 160, 230) }

local function decoPart(parent: Instance, props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

-- Festone di lampadine colorate tra due punti in alto
local function lightString(parent: Instance, a: Vector3, b: Vector3)
	local length = (b - a).Magnitude
	decoPart(parent, { Name = "Filo", Size = Vector3.new(0.15, 0.15, length), CFrame = CFrame.lookAt((a + b) / 2, b), Material = Enum.Material.Fabric, Color = Color3.fromRGB(40, 36, 32) })
	local count = math.max(4, math.floor(length / 4))
	for i = 1, count do
		local k = i / (count + 1)
		local sag = math.sin(k * math.pi) * 1.8
		local pos = a:Lerp(b, k) - Vector3.new(0, sag + 0.6, 0)
		local bulb = decoPart(parent, { Name = "Lampadina", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), CFrame = CFrame.new(pos), Material = Enum.Material.Neon, Color = BULBS[(i % #BULBS) + 1] })
		if i % 4 == 0 then
			local light = Instance.new("PointLight")
			light.Range = 12
			light.Brightness = 0.9
			light.Color = bulb.Color
			light.Parent = bulb
		end
	end
end

local function flagPole(parent: Instance, base: Vector3, color: Color3): Vector3
	local h = 22
	decoPart(parent, { Name = "PennoneFesta", Size = Vector3.new(0.7, h, 0.7), CFrame = CFrame.new(base + Vector3.new(0, h / 2, 0)), Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 56, 52), CanCollide = true })
	decoPart(parent, { Name = "PomoFesta", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(base + Vector3.new(0, h + 0.5, 0)), Material = Enum.Material.Foil, Color = GOLD })
	decoPart(parent, { Name = "Stendardo", Size = Vector3.new(0.15, 7, 3.6), CFrame = CFrame.new(base + Vector3.new(0, h - 4.5, 1.9)), Material = Enum.Material.Fabric, Color = color })
	decoPart(parent, { Name = "BordoStendardo", Size = Vector3.new(0.2, 0.6, 3.6), CFrame = CFrame.new(base + Vector3.new(0, h - 8.2, 1.9)), Material = Enum.Material.Foil, Color = GOLD })
	return base + Vector3.new(0, h - 1, 0)
end

local function signText(part: BasePart, text: string)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(900, 200)
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GrenzeGotisch
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 226, 140)
		label.TextStrokeTransparency = 0.3
		label.Text = text
		label.Parent = gui
		gui.Parent = part
	end
end

-- Grande arco d'oro con la scritta e i coriandoli che cadono
local function buildArch(parent: Instance, center: Vector3, facing: Vector3)
	local cf = CFrame.lookAt(center, center + facing)
	for _, sx in { -1, 1 } do
		decoPart(parent, { Name = "PilastroArco", Size = Vector3.new(4, 30, 4), CFrame = cf * CFrame.new(sx * 18, 15, 0), Material = Enum.Material.Marble, Color = Color3.fromRGB(240, 232, 214), CanCollide = true })
		decoPart(parent, { Name = "CapitelloArco", Size = Vector3.new(5.4, 2, 5.4), CFrame = cf * CFrame.new(sx * 18, 30.5, 0), Material = Enum.Material.Foil, Color = GOLD })
		decoPart(parent, { Name = "DrappoArco", Size = Vector3.new(3.4, 20, 0.2), CFrame = cf * CFrame.new(sx * 18, 18, -2.2), Material = Enum.Material.Fabric, Color = RED })
	end
	local beam = decoPart(parent, { Name = "TraveArco", Size = Vector3.new(42, 4, 4.4), CFrame = cf * CFrame.new(0, 33, 0), Material = Enum.Material.Marble, Color = Color3.fromRGB(240, 232, 214), CanCollide = true })
	local sign = decoPart(parent, { Name = "InsegnaInaugurazione", Size = Vector3.new(34, 7, 0.6), CFrame = cf * CFrame.new(0, 39, 0), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(70, 30, 30) })
	signText(sign, "GRANDE INAUGURAZIONE")
	decoPart(parent, { Name = "CorniceInsegna", Size = Vector3.new(35.2, 8.2, 0.4), CFrame = cf * CFrame.new(0, 39, 0.3), Material = Enum.Material.Foil, Color = GOLD })
	decoPart(parent, { Name = "Stella", Shape = Enum.PartType.Ball, Size = Vector3.new(3.4, 3.4, 3.4), CFrame = cf * CFrame.new(0, 44.5, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 220, 120) })
	lightString(parent, (cf * CFrame.new(-18, 31, -2.6)).Position, (cf * CFrame.new(18, 31, -2.6)).Position)
	local confetti = Instance.new("ParticleEmitter")
	confetti.Name = "Coriandoli"
	confetti.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	confetti.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 90)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(110, 220, 120)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(110, 170, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 120, 255)),
	})
	confetti.Rate = 14
	confetti.Lifetime = NumberRange.new(4, 6)
	confetti.Speed = NumberRange.new(2, 5)
	confetti.Acceleration = Vector3.new(0, -4, 0)
	confetti.Drag = 1
	confetti.SpreadAngle = Vector2.new(60, 60)
	confetti.Rotation = NumberRange.new(0, 360)
	confetti.RotSpeed = NumberRange.new(-200, 200)
	confetti.Size = NumberSequence.new(0.6)
	confetti.LightEmission = 0.4
	confetti.Parent = beam
end

local DECORATION_SPOTS = {
	CampoAddestramento = { Offset = Vector3.new(0, 0, 6), Arch = Vector3.new(0, 0, -58) },
	Calaneth = { District = "Calaneth" },
	Aurion = { Plaza = true },
	Brenn = { Offset = Vector3.new(0, 0, 0) },
	PortoRevelia = { Offset = Vector3.new(0, 0, 0) },
	PortoOrientale = { Offset = Vector3.new(0, 0, 0) },
}

local function decorationCenter(zoneId: string, zone): Vector3
	local spot = DECORATION_SPOTS[zoneId] or {}
	if spot.Plaza then
		return W.IslandCenter("Aurea") + Vector3.new(0, 0, 120)
	elseif spot.District then
		return W.DistrictGatePoint(spot.District) + W.DistrictOutward(spot.District) * 16
	end
	return zone.Center + (spot.Offset or Vector3.zero)
end

local function buildDecorations()
	if decorations then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Festa"
	decorations = folder
	for _, zoneId in Festival.Decorated do
		local zone = Zones.Get(zoneId)
		if zone then
			local ok, err = pcall(function()
				local group = Instance.new("Model")
				group.Name = "Festa - " .. zone.Name
				group.Parent = folder
				local center = groundAt(decorationCenter(zoneId, zone))
				local tops = {}
				local poles = 8
				for i = 0, poles - 1 do
					local base = groundAt(center + Util.Polar(i * 360 / poles + 22.5, 26))
					table.insert(tops, flagPole(group, base, if i % 2 == 0 then RED else GOLD))
				end
				for i = 1, #tops do
					lightString(group, tops[i], tops[(i % #tops) + 1])
				end
				local spot = DECORATION_SPOTS[zoneId]
				if spot and spot.Arch then
					local archCenter = groundAt(zone.Center + spot.Arch)
					buildArch(group, archCenter, Vector3.new(0, 0, -1))
				end
			end)
			if not ok then
				warn("[Festa] Addobbi di " .. zoneId .. ": " .. tostring(err))
			end
		end
	end
	folder.Parent = workspace
end

local function removeDecorations()
	if decorations then
		decorations:Destroy()
		decorations = nil
	end
end

-- ACCENSIONE E SPEGNIMENTO -------------------------------------------------------------------------------

local function setActive(on: boolean)
	if active == on then
		return
	end
	active = on
	if on then
		nextBossClock = os.clock() + Festival.Boss.FirstDelay
		nextFireworksClock = os.clock() + Festival.Fireworks.FirstDelay
		buildDecorations()
		S.EventService.Announce("🎉 " .. Festival.Name:upper() .. "!", "Esperienza e oro doppi, il Colosso d'Oro, fuochi d'artificio e premi esclusivi!", "Raro")
	else
		removeDecorations()
		if colossus and colossus.State ~= "Dead" then
			S.TitanService.Despawn(colossus)
		end
		colossus = nil
		ReplicatedStorage:SetAttribute("FestaBossPos", nil)
		S.EventService.Announce("La Grande Inaugurazione è finita", "Grazie a tutti i soldati che hanno festeggiato!", "Info")
	end
	for _, player in Players:GetPlayers() do
		applyBonus(player)
		local profile = S.DataService.Get(player)
		if on and profile then
			task.spawn(welcome, player, profile)
		end
	end
	publish()
end

-- Admin: true = sempre attivo, false = spento, nil = segue le date
function FestivalService.SetOverride(value: boolean?)
	override = value
	setActive(Festival.IsActive(os.time(), override))
	publish()
end

function FestivalService.Init(services)
	S = services
end

function FestivalService.Start()
	S.WorldBuilder.WaitReady()
	setActive(Festival.IsActive(os.time(), override))
	publish()
	S.DataService.OnLoaded(function(player, profile)
		applyBonus(player)
		-- il regalo arriva dopo la cerimonia d'apertura (se la deve ancora vedere)
		local f = festivalData(profile)
		task.delay(if active and not f.Ceremony then 40 else 8, welcome, player, profile)
	end)
	Net.Event("ClientReady").OnServerEvent:Connect(function(player, request)
		if request == nil and active then
			task.delay(0.5, function()
				if player.Parent then
					FestivalService.Ceremony(player)
				end
			end)
		end
	end)
	S.TitanService.Killed:Connect(onTitanKilled)
	S.PlayerService.ZoneEntered:Connect(function(player, zoneId)
		local zone = Zones.Get(zoneId)
		local profile = active and zone and zone.Islet and S.DataService.Get(player)
		if profile then
			local f = festivalData(profile)
			if not f.Islets[zoneId] then
				f.Islets[zoneId] = true
				FestivalService.Add(player, "Islets", 1)
			end
		end
	end)
	-- orologio dell'evento
	local warned = false
	while true do
		task.wait(1)
		local shouldBe = Festival.IsActive(os.time(), override)
		if shouldBe ~= active then
			setActive(shouldBe)
		end
		if active then
			local now = os.clock()
			if not warned and nextBossClock - now <= Festival.Boss.Warning then
				warned = true
				local zone = Zones.Get(Festival.Boss.Zone)
				S.EventService.Announce("👑 Il Colosso d'Oro sta arrivando!", ("Tra 1 minuto cadrà dal cielo: %s, isola di Vermiglia"):format(zone and zone.Name or "Vermiglia"), "Pericolo")
			end
			if now >= nextBossClock then
				nextBossClock = now + Festival.Boss.Interval
				warned = false
				publish()
				task.spawn(FestivalService.SpawnColossus)
			end
			if now >= nextFireworksClock then
				nextFireworksClock = now + Festival.Fireworks.Interval
				publish()
				task.spawn(fireworksShow)
			end
		end
	end
end

return FestivalService
