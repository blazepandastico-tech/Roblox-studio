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
			updateLamps()
			task.wait(5)
		end
	end)
end

return AmbienceController
