--[[
	LightingService
	Grafica: atmosfera, nuvole, bloom, raggi del sole, correzione colore,
	e il ciclo giorno/notte (di notte i giganti rallentano).
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local LightingService = {}
local S

local function ensure(className: string, parent: Instance, name: string?): any
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local instance = Instance.new(className)
	if name then
		instance.Name = name
	end
	instance.Parent = parent
	return instance
end

function LightingService.IsNight(): boolean
	local t = Lighting.ClockTime
	return t >= Config.World.NightStart or t < Config.World.NightEnd
end

function LightingService.Setup()
	Lighting.Brightness = 2.6
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.Ambient = Color3.fromRGB(70, 64, 60)
	Lighting.OutdoorAmbient = Color3.fromRGB(132, 128, 120)
	Lighting.ExposureCompensation = 0.1
	Lighting.GeographicLatitude = 38
	Lighting.ClockTime = 9.5

	local atmosphere = ensure("Atmosphere", Lighting)
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.22
	atmosphere.Color = Color3.fromRGB(196, 212, 228)
	atmosphere.Decay = Color3.fromRGB(110, 118, 132)
	atmosphere.Glare = 0.35
	atmosphere.Haze = 1.1

	local sky = ensure("Sky", Lighting)
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 11
	sky.StarCount = 3000
	sky.CelestialBodiesShown = true

	local bloom = ensure("BloomEffect", Lighting)
	bloom.Intensity = 0.55
	bloom.Size = 26
	bloom.Threshold = 1.25

	local rays = ensure("SunRaysEffect", Lighting)
	rays.Intensity = 0.06
	rays.Spread = 0.75

	local cc = ensure("ColorCorrectionEffect", Lighting)
	cc.Brightness = 0.02
	cc.Contrast = 0.08
	cc.Saturation = 0.08
	cc.TintColor = Color3.fromRGB(255, 250, 244)

	local dof = ensure("DepthOfFieldEffect", Lighting)
	dof.FarIntensity = 0.12
	dof.FocusDistance = 60
	dof.InFocusRadius = 160
	dof.NearIntensity = 0

	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if not clouds then
		clouds = Instance.new("Clouds")
		clouds.Parent = workspace.Terrain
	end
	clouds.Cover = 0.55
	clouds.Density = 0.62
	clouds.Color = Color3.fromRGB(255, 255, 255)
end

function LightingService.Init(services)
	S = services
end

function LightingService.Start()
	LightingService.Setup()
	local wasNight = LightingService.IsNight()
	local hoursPerSecond = 24 / Config.World.DayLength
	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated < 0.2 then
			return
		end
		Lighting.ClockTime = (Lighting.ClockTime + accumulated * hoursPerSecond) % 24
		accumulated = 0
		local night = LightingService.IsNight()
		if night ~= wasNight then
			wasNight = night
			if S.EventService then
				if night then
					S.EventService.Announce("Cala la notte", "I giganti rallentano... ma alcuni anomali non dormono mai.", "Notte")
				else
					S.EventService.Announce("Sorge il sole", "I giganti tornano attivi. Preparate i rampini!", "Giorno")
				end
			end
		end
	end)
end

return LightingService
