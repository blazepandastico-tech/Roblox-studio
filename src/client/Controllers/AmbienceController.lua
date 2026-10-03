--[[
	AmbienceController
	Atmosfera di ogni zona (nebbia verde nella foresta, cenere tra le rovine di Halvar,
	cielo arancione al Fronte della Grande Marcia...), banner con il nome della zona,
	mulini a vento che girano e lampioni che si accendono di notte.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
local spinners: { Model } = {}
local music: Sound? = nil

AmbienceController.ZoneId = nil :: string?
AmbienceController.RegionName = ""

local function applyAmbience(ambience)
	if ambience == currentAmbience then
		return
	end
	currentAmbience = ambience
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

local function setupMusic()
	local id = Sounds.Music.Default
	if not id or id == "" then
		return
	end
	music = Instance.new("Sound")
	music.Name = "Musica"
	music.SoundId = id
	music.Looped = true
	music.Volume = 0.3
	music.Parent = game:GetService("SoundService")
	music:Play()
end

function AmbienceController.Init(c)
	C = c
end

function AmbienceController.Start()
	setupSpinners()
	setupMusic()
	task.spawn(function()
		while true do
			local ok, err = pcall(updateZone)
			if not ok then
				warn("[Atmosfera] " .. tostring(err))
			end
			if music then
				music.Volume = 0.3 * (C.ClientData.Setting("Music", 0.5) or 0.5)
			end
			task.wait(0.5)
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
