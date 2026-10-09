--[[
	LightingService
	Grafica: atmosfera, nuvole, bloom, raggi del sole, correzione colore,
	il ciclo giorno/notte (di notte i giganti rallentano) e il METEO:
	Sereno, Nuvoloso, Pioggia e Temporale si alternano da soli e il vento cambia.
	Il meteo attuale è l'attributo "Meteo" di ReplicatedStorage: i colori, la pioggia
	e i fulmini li disegna ogni client (AmbienceController).
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local LightingService = {}
local S

-- meteo: probabilità e durata (secondi reali)
LightingService.Weathers = {
	{ Id = "Sereno", Weight = 45, Duration = { 420, 780 }, Wind = 8 },
	{ Id = "Nuvoloso", Weight = 25, Duration = { 300, 540 }, Wind = 14 },
	{ Id = "Pioggia", Weight = 20, Duration = { 240, 420 }, Wind = 18 },
	{ Id = "Temporale", Weight = 10, Duration = { 180, 300 }, Wind = 30 },
}
local WEATHER_TEXT = {
	Sereno = "Il cielo si rasserena.",
	Nuvoloso = "Le nuvole coprono il sole.",
	Pioggia = "Comincia a piovere.",
	Temporale = "Si avvicina un temporale: tuoni e fulmini sull'arcipelago!",
}
local rng = Random.new()
local windAngle = rng:NextNumber(0, math.pi * 2)

function LightingService.Weather(): string
	local weather = ReplicatedStorage:GetAttribute("Meteo")
	return if type(weather) == "string" then weather else "Sereno"
end

function LightingService.SetWeather(id: string, announce: boolean?)
	local def = nil
	for _, w in LightingService.Weathers do
		if w.Id == id then
			def = w
		end
	end
	if not def then
		return false
	end
	local before = LightingService.Weather()
	ReplicatedStorage:SetAttribute("Meteo", def.Id)
	ReplicatedStorage:SetAttribute("MeteoDa", os.time())
	-- il vento gira piano e si rinforza col brutto tempo (muove erba, nuvole, pioggia e particelle)
	windAngle += rng:NextNumber(-0.8, 0.8)
	workspace.GlobalWind = Vector3.new(math.cos(windAngle), 0, math.sin(windAngle)) * def.Wind
	if announce ~= false and before ~= def.Id and S and S.EventService then
		S.EventService.NotifyAll("🌦️ " .. WEATHER_TEXT[def.Id], "Info", 5)
	end
	return true
end

local function pickWeather(current: string): any
	local total = 0
	for _, w in LightingService.Weathers do
		if w.Id ~= current then
			total += w.Weight
		end
	end
	local roll = rng:NextNumber() * total
	for _, w in LightingService.Weathers do
		if w.Id ~= current then
			roll -= w.Weight
			if roll <= 0 then
				return w
			end
		end
	end
	return LightingService.Weathers[1]
end

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
	Lighting.ShadowSoftness = 0.18 -- ombre del sole più nette, come alla luce vera
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

	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Parent = workspace.Terrain
	clouds.Cover = 0.55
	clouds.Density = 0.62
	clouds.Color = Color3.fromRGB(255, 255, 255)
end

function LightingService.Init(services)
	S = services
end

function LightingService.Start()
	LightingService.Setup()
	LightingService.SetWeather("Sereno", false)
	-- il meteo cambia da solo
	task.spawn(function()
		local current = LightingService.Weathers[1]
		while true do
			task.wait(rng:NextNumber(current.Duration[1], current.Duration[2]))
			current = pickWeather(LightingService.Weather())
			LightingService.SetWeather(current.Id)
		end
	end)
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
