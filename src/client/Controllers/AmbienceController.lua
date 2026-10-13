--[[
	AmbienceController
	Atmosfera di ogni zona (nebbia verde nella foresta, cenere tra le rovine di Halvar,
	cielo arancione al Fronte della Grande Marcia...), banner con il nome della zona,
	mulini a vento che girano, lampioni che si accendono di notte e la musica dinamica:
	calma di giorno, città, notte, battaglia (giganti vicini o che ti inseguono) e boss,
	con i suoni d'ambiente (pioggia, vento, uccellini, grilli). Gli ID delle tracce si
	mettono in Shared/Data/Sounds.lua.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Lib.Util)
local Zones = require(Shared.Data.Zones)
local Sounds = require(Shared.Data.Sounds)
local Tema = require(Shared.Data.Tema)

local AmbienceController = {}
local C
local player = Players.LocalPlayer

local currentZoneId: string? = nil
local currentRegion: string? = nil
local currentAmbience = nil
local currentZone = nil
local spinners: { Model } = {}

AmbienceController.ZoneId = nil :: string?
AmbienceController.RegionName = ""

local function applyAmbience(ambience)
	if ambience == currentAmbience then
		return
	end
	currentAmbience = ambience
	-- il cielo mescola l'atmosfera della zona con l'ora del giorno e il meteo
	if C.SkyController then
		C.SkyController.SetZoneAmbience(ambience)
		return
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local cc = Lighting:FindFirstChild("ColorCorrection") or Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	local info = TweenInfo.new(3, Enum.EasingStyle.Sine)
	if atmosphere then
		TweenService:Create(atmosphere, info, {
			Density = ambience.Density,
			Haze = ambience.Haze,
			Glare = ambience.Glare,
			Color = ambience.Color,
			Decay = ambience.Decay,
		}):Play()
	end
	if cc and cc:IsA("ColorCorrectionEffect") then
		TweenService:Create(cc, info, {
			TintColor = ambience.Tint,
			Saturation = ambience.Saturation,
			Contrast = ambience.Contrast,
		}):Play()
	end
	TweenService:Create(Lighting, info, { ExposureCompensation = ambience.Exposure }):Play()
end

local function levelText(zone): string
	return ("Livelli %d - %d"):format(zone.Level[1], zone.Level[2])
end

local function updateZone()
	local root = Util.GetRoot(player.Character)
	if not root then
		return
	end
	local zone = Zones.Find(root.Position)
	currentZone = zone
	local zoneId = zone and zone.Id or nil
	local region = Zones.RegionName(root.Position)
	AmbienceController.RegionName = region
	if zoneId ~= currentZoneId then
		currentZoneId = zoneId
		AmbienceController.ZoneId = zoneId
		if zone then
			local season = Zones.SeasonNames[zone.Season] or ""
			local subtitle = if zone.Safe then ("Zona sicura • %s"):format(season) else ("%s • %s"):format(levelText(zone), season)
			C.Notifications.ZoneBanner(zone.Name, subtitle, if zone.Safe then Color3.fromRGB(150, 230, 160) else nil)
		elseif region ~= currentRegion then
			C.Notifications.ZoneBanner(region, "Territorio aperto", Color3.fromRGB(220, 210, 190))
		end
	end
	currentRegion = region
	applyAmbience(Zones.AmbienceFor(root.Position))
end

local function setupSpinners()
	local function add(model: Instance)
		if model:IsA("Model") and model.PrimaryPart then
			table.insert(spinners, model)
		end
	end
	for _, m in CollectionService:GetTagged(Config.Tags.Spinner) do
		add(m)
	end
	CollectionService:GetInstanceAddedSignal(Config.Tags.Spinner):Connect(add)
	RunService.RenderStepped:Connect(function(dt)
		for i = #spinners, 1, -1 do
			local model = spinners[i]
			if not model.Parent or not model.PrimaryPart then
				table.remove(spinners, i)
			else
				model:PivotTo(model:GetPivot() * CFrame.Angles(0, 0, dt * 0.6))
			end
		end
	end)
end

-- LUCI DELLA NOTTE ----------------------------------------------------------------------------------
-- Lampioni, lanterne e torce si accendono al tramonto. Dietro molte finestre delle case si accende una
-- luce calda, ognuna alla sua ora (chi cena presto, chi va a dormire tardi) e qualcuna già all'alba.
-- Le fiamme vicine tremolano. Solo grafica: le finestre restano le stesse parti di sempre.

local WINDOW_WARM = {
	Color3.fromRGB(214, 142, 78),
	Color3.fromRGB(226, 160, 96),
	Color3.fromRGB(200, 128, 66),
	Color3.fromRGB(232, 176, 118),
}
-- file di Halloween: finestre arancioni come zucche, e qualcuna viola o verde (case infestate)
if Tema.IsHalloween() then
	WINDOW_WARM = {
		Color3.fromRGB(232, 128, 44),
		Color3.fromRGB(214, 110, 36),
		Color3.fromRGB(240, 150, 60),
		Color3.fromRGB(226, 120, 40),
		Color3.fromRGB(150, 90, 220),
		Color3.fromRGB(130, 220, 90),
	}
end
local windowDay: { [BasePart]: { Material: Enum.Material, Color: Color3, Reflectance: number } } = setmetatable({}, { __mode = "k" }) :: any
local windowLit: { [BasePart]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- numero fisso tra 0 e 1 per ogni finestra (dalla sua posizione)
local function hash01(p: Vector3, salt: number): number
	local v = math.sin(p.X * 12.9898 + p.Y * 37.719 + p.Z * 78.233 + salt * 19.19) * 43758.5453
	return v - math.floor(v)
end

function AmbienceController.WindowLit(position: Vector3, clockTime: number): boolean
	if hash01(position, 1) > 0.62 then
		return false -- casa vuota o tende tirate
	end
	local s = (clockTime - 12) % 24 -- ore passate da mezzogiorno
	local on = 5.7 + hash01(position, 2) * 1.6 -- tra le 17:42 e le 19:18
	local off = 10.4 + hash01(position, 3) * 6.5 -- tra le 22:24 e le 4:54
	if s >= on and s < off then
		return true
	end
	return hash01(position, 4) < 0.25 and s >= 17 and s < 18.5 -- chi si alza presto: 5:00 - 6:30
end

local function setWindow(glass: BasePart, lit: boolean)
	if windowLit[glass] == lit then
		return
	end
	if windowDay[glass] == nil then
		windowDay[glass] = { Material = glass.Material, Color = glass.Color, Reflectance = glass.Reflectance }
	end
	windowLit[glass] = lit
	if lit then
		glass.Material = Enum.Material.Neon
		glass.Color = WINDOW_WARM[math.floor(hash01(glass.Position, 5) * #WINDOW_WARM) + 1]
		glass.Reflectance = 0
	else
		local day = windowDay[glass]
		glass.Material = day.Material
		glass.Color = day.Color
		glass.Reflectance = day.Reflectance
	end
end

local function updateLamps()
	local t = Lighting.ClockTime
	local night = t >= 18 or t < 6.5
	for _, bulb in CollectionService:GetTagged(Config.Tags.Lamp) do
		local light = bulb:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = night
		end
		if bulb:IsA("BasePart") then
			bulb.Material = if night then Enum.Material.Neon else Enum.Material.Glass
		end
	end
	for _, glass in CollectionService:GetTagged(Config.Tags.Window) do
		if glass:IsA("BasePart") then
			setWindow(glass, AmbienceController.WindowLit(glass.Position, t))
		end
	end
end

-- accende o spegne subito lampioni e finestre (di solito lo fa da sé ogni 2 secondi)
AmbienceController.RefreshLights = updateLamps

-- fiamme che tremolano (solo quelle vicine alla telecamera, aggiornate ogni fotogramma)
local flickering: { { Light: PointLight, Base: number, Seed: number } } = {}
local lastFlickerScan = 0

local function updateFlicker()
	local now = os.clock()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if now - lastFlickerScan > 1.5 then
		lastFlickerScan = now
		for _, f in flickering do
			if f.Light.Parent then
				f.Light.Brightness = f.Base
			end
		end
		table.clear(flickering)
		local cam = camera.CFrame.Position
		for _, bulb in CollectionService:GetTagged(Config.Tags.Lamp) do
			if #flickering >= 40 then
				break
			end
			if bulb:IsA("BasePart") and (bulb:FindFirstChildOfClass("Fire") or bulb:GetAttribute("Tremola") == true) and (bulb.Position - cam).Magnitude < 220 then
				local light = bulb:FindFirstChildOfClass("PointLight")
				if light and light.Enabled then
					local base = light:GetAttribute("Luminosita")
					if type(base) ~= "number" then
						base = light.Brightness
						light:SetAttribute("Luminosita", base)
					end
					table.insert(flickering, { Light = light, Base = base :: number, Seed = hash01(bulb.Position, 6) * 100 })
				end
			end
		end
	end
	for _, f in flickering do
		local n = math.noise(now * 7, f.Seed) * 0.6 + math.noise(now * 17, f.Seed + 3.3) * 0.4
		f.Light.Brightness = f.Base * (0.86 + n * 0.28)
	end
end

-- MUSICA DINAMICA E SUONI D'AMBIENTE ---------------------------------------------------------------

local MUSIC_VOLUME = 0.3
local AMBIENT_VOLUME = 0.4
local FADE_TIME = 2.5 -- secondi di dissolvenza quando la musica cambia
local BATTLE_LINGER = 8 -- la musica di battaglia resta ancora qualche secondo dopo l'ultimo nemico

local layers: { [string]: Sound } = {} -- un Sound per ogni ID: situazioni con lo stesso ID non ricominciano la traccia
local battleUntil = 0
local bossUntil = 0
AmbienceController.MusicState = "Calm"

local function trackId(list: { [string]: string }, key: string): string
	local id = list[key]
	if type(id) ~= "string" or id == "" then
		return ""
	end
	return id
end

local function musicStateNow(): string
	local now = os.clock()
	local root = Util.GetRoot(player.Character)
	if root then
		local pos = root.Position
		local titans = workspace:FindFirstChild(Config.Folders.Titans)
		if titans then
			for _, model in titans:GetChildren() do
				if model:IsA("Model") and model.PrimaryPart and model:GetAttribute("State") ~= "Dead" and not model:GetAttribute("Ally") and not model:GetAttribute("Dummy") then
					local d = (model.PrimaryPart.Position - pos).Magnitude
					if model:GetAttribute("Boss") == true and d < 420 then
						bossUntil = now + BATTLE_LINGER
					elseif d < 140 or (model:GetAttribute("TargetUserId") == player.UserId and d < 320) then
						battleUntil = now + BATTLE_LINGER
					end
				end
			end
		end
		local enemies = workspace:FindFirstChild(Config.Folders.Enemies)
		if enemies then
			for _, model in enemies:GetChildren() do
				local hrp = model:FindFirstChild("HumanoidRootPart")
				if hrp and hrp:IsA("BasePart") and not model:GetAttribute("Dead") then
					local d = (hrp.Position - pos).Magnitude
					if model:GetAttribute("Boss") == true and d < 260 then
						bossUntil = now + BATTLE_LINGER
					elseif d < 90 then
						battleUntil = now + BATTLE_LINGER
					end
				end
			end
		end
	end
	if now < bossUntil then
		return "Boss"
	elseif now < battleUntil then
		return "Battle"
	elseif currentZone and currentZone.Safe then
		return "City"
	end
	local t = Lighting.ClockTime
	if t >= 19 or t < 6 then
		return "Night"
	end
	return "Calm"
end

local function layer(id: string): Sound
	local existing = layers[id]
	if existing then
		return existing
	end
	local sound = Instance.new("Sound")
	sound.Name = "Sottofondo"
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	layers[id] = sound
	return sound
end

-- volume desiderato per ogni traccia (musica + suoni d'ambiente) e il volume pieno di riferimento
local function wantedVolumes(): ({ [string]: number }, number)
	local wanted = {}
	local function want(id: string, volume: number)
		if id ~= "" and volume > 0 then
			wanted[id] = math.max(wanted[id] or 0, volume)
		end
	end
	local state = AmbienceController.MusicState
	local musicId = trackId(Sounds.Music, state)
	if musicId == "" then
		musicId = trackId(Sounds.Music, "Default")
	end
	local full = MUSIC_VOLUME * (C.ClientData.Setting("Music", 0.5) or 0.5)
	want(musicId, full)

	local sfx = AMBIENT_VOLUME * (C.ClientData.Setting("Sfx", 0.8) or 0.8)
	local root = Util.GetRoot(player.Character)
	local below = root ~= nil and root.Position.Y < -120 -- sottosuolo: niente cielo
	local weather = if C.SkyController then C.SkyController.Weather() else "Sereno"
	local rainy = weather == "Pioggia" or weather == "Temporale"
	local t = Lighting.ClockTime
	local night = t >= 19.2 or t < 5.6
	local ambient = Sounds.Ambient or {}
	if not below then
		want(trackId(ambient, "Rain"), if weather == "Temporale" then sfx else if rainy then sfx * 0.75 else 0)
		want(trackId(ambient, "Wind"), if weather == "Temporale" then sfx * 0.6 else 0)
		want(trackId(ambient, "Birds"), if not night and not rainy and state ~= "Battle" and state ~= "Boss" then sfx * 0.5 else 0)
		want(trackId(ambient, "Night"), if night and not rainy then sfx * 0.5 else 0)
	end
	return wanted, math.max(full, sfx, 0.05)
end

local function updateSound(dt: number)
	local wanted, full = wantedVolumes()
	for id in wanted do
		layer(id)
	end
	local step = full * dt / FADE_TIME
	for id, sound in layers do
		local target = wanted[id] or 0
		if sound.Volume < target then
			sound.Volume = math.min(target, sound.Volume + step)
		else
			sound.Volume = math.max(target, sound.Volume - step)
		end
		if target > 0 and not sound.IsPlaying then
			sound:Play()
		elseif target == 0 and sound.Volume <= 0.001 and sound.IsPlaying then
			-- finita la dissolvenza si ferma (la prossima volta riparte dall'inizio)
			sound:Stop()
		end
	end
end

function AmbienceController.Init(c)
	C = c
end

function AmbienceController.Start()
	setupSpinners()
	task.spawn(function()
		while true do
			local ok, err = pcall(updateZone)
			if not ok then
				warn("[Atmosfera] " .. tostring(err))
			end
			local okMusic, state = pcall(musicStateNow)
			if okMusic then
				AmbienceController.MusicState = state
			end
			task.wait(0.5)
		end
	end)
	-- dissolvenze della musica (10 volte al secondo)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.1)
			local now = os.clock()
			local ok, err = pcall(updateSound, now - last)
			last = now
			if not ok then
				warn("[Musica] " .. tostring(err))
			end
		end
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(updateLamps)
			if not ok then
				warn("[Luci] " .. tostring(err))
			end
			task.wait(2)
		end
	end)
	local flickerWarned = false
	RunService.RenderStepped:Connect(function()
		local ok, err = pcall(updateFlicker)
		if not ok and not flickerWarned then
			flickerWarned = true
			warn("[Luci] " .. tostring(err))
		end
	end)
end

return AmbienceController
