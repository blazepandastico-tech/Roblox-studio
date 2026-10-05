--[[
	SkyController - cielo, luce e meteo (solo grafica, sul client)
	Mescola tre cose e le cambia piano piano:
	  • l'atmosfera della zona (nebbia verde nella foresta, cenere tra le rovine...);
	  • l'ora del giorno: alba e tramonto arancioni, notte blu con le stelle;
	  • il meteo deciso dal server (attributo "Meteo" di ReplicatedStorage):
	    Sereno, Nuvoloso, Pioggia (gocce, cielo grigio) e Temporale (pioggia forte, fulmini e tuoni).
	Sottoterra il meteo e il cielo non si vedono.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared.Data.Zones)

local SkyController = {}
local C

local player = Players.LocalPlayer
local rng = Random.new()

local WEATHER = {
	Sereno = { Cover = 0.42, CloudDensity = 0.5, CloudColor = Color3.fromRGB(255, 255, 255), Density = 0, Haze = 0, Bright = 1, Exposure = 0, Sat = 0, Grey = 0, Rain = 0 },
	Nuvoloso = { Cover = 0.8, CloudDensity = 0.7, CloudColor = Color3.fromRGB(226, 229, 234), Density = 0.05, Haze = 0.5, Bright = 0.82, Exposure = -0.03, Sat = -0.06, Grey = 0.2, Rain = 0 },
	Pioggia = { Cover = 0.92, CloudDensity = 0.86, CloudColor = Color3.fromRGB(160, 165, 175), Density = 0.14, Haze = 1.4, Bright = 0.6, Exposure = -0.08, Sat = -0.18, Grey = 0.45, Rain = 1 },
	Temporale = { Cover = 0.98, CloudDensity = 0.96, CloudColor = Color3.fromRGB(98, 102, 112), Density = 0.22, Haze = 2, Bright = 0.42, Exposure = -0.14, Sat = -0.28, Grey = 0.68, Rain = 2 },
}
local NUMERIC = { "Cover", "CloudDensity", "Density", "Haze", "Bright", "Exposure", "Sat", "Grey", "Rain" }

local zoneAmbience = Zones.Ambience.Default
local indoor = false -- sottoterra: niente cielo né meteo
local weather = table.clone(WEATHER.Sereno)
local base = {
	Brightness = Lighting.Brightness,
	OutdoorAmbient = Lighting.OutdoorAmbient,
}

local rainPart: Part? = nil
local rainEmitter: ParticleEmitter? = nil
local splashPart: Part? = nil
local splashEmitter: ParticleEmitter? = nil
local nextLightning = 0

function SkyController.SetZoneAmbience(ambience)
	zoneAmbience = ambience or Zones.Ambience.Default
end

function SkyController.Weather(): string
	local weather = ReplicatedStorage:GetAttribute("Meteo")
	return if type(weather) == "string" then weather else "Sereno"
end

-- 0..1 a forma di campana attorno all'ora "center"
local function bell(t: number, center: number, width: number): number
	local d = (t - center) / width
	return math.max(0, 1 - d * d)
end

local function smooth(a: number, b: number, x: number): number
	local k = math.clamp((x - a) / (b - a), 0, 1)
	return k * k * (3 - 2 * k)
end

-- quanto è alba/tramonto (warm) e quanto è notte (night) all'ora attuale
local function timeOfDay(): (number, number, number)
	local t = Lighting.ClockTime
	local dawn = bell(t, 6.6, 1.4)
	local dusk = bell(t, 18.4, 1.5)
	local night = 1 - math.min(smooth(4.8, 6.3, t), 1 - smooth(18.9, 20.2, t))
	return math.min(1, dawn + dusk), night, dawn
end

-- PIOGGIA ---------------------------------------------------------------------------------------------

local function makeEmitterPart(name: string, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.Parent = workspace.CurrentCamera
	return p
end

local function buildRain()
	rainPart = makeEmitterPart("Pioggia", Vector3.new(150, 2, 150))
	local e = Instance.new("ParticleEmitter")
	e.Name = "Gocce"
	e.Texture = "rbxasset://textures/particles/fire_sparks_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(196, 210, 226))
	e.LightEmission = 0.15
	e.LightInfluence = 0.8
	e.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
	e.Size = NumberSequence.new(0.22)
	e.Squash = NumberSequence.new(2.6)
	e.Transparency = NumberSequence.new(0.35)
	e.Lifetime = NumberRange.new(0.9, 1.1)
	e.Speed = NumberRange.new(120, 145)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.WindAffectsDrag = true
	e.Drag = 0.4
	e.Rate = 0
	e.Parent = rainPart
	rainEmitter = e

	splashPart = makeEmitterPart("Schizzi", Vector3.new(70, 1, 70))
	local s = Instance.new("ParticleEmitter")
	s.Name = "Schizzi"
	s.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	s.Color = ColorSequence.new(Color3.fromRGB(220, 230, 240))
	s.LightEmission = 0.2
	s.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	s.Transparency = NumberSequence.new(0.45)
	s.Lifetime = NumberRange.new(0.15, 0.25)
	s.Speed = NumberRange.new(3, 6)
	s.SpreadAngle = Vector2.new(35, 35)
	s.EmissionDirection = Enum.NormalId.Top
	s.Shape = Enum.ParticleEmitterShape.Box
	s.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	s.Rate = 0
	s.Parent = splashPart
	splashEmitter = s
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { workspace.Terrain }

local lastGroundCheck = 0
local groundY = 0

-- la grafica "Automatica" (0) vale come media
local function qualityMultiplier(): number
	local ok, level = pcall(function()
		return UserSettings().GameSettings.SavedQualityLevel.Value
	end)
	if not ok or level == 0 then
		return 0.6
	end
	return math.clamp(level / 7, 0.35, 1)
end

-- posizione delle gocce: segue la telecamera a ogni fotogramma (anche in volo coi rampini)
local function followCamera()
	local camera = workspace.CurrentCamera
	if not rainPart or not camera then
		return
	end
	local cam = camera.CFrame.Position
	rainPart.CFrame = CFrame.new(cam + Vector3.new(0, 60, 0) - workspace.GlobalWind * 0.6 + camera.CFrame.LookVector * 30)
	if splashPart then
		splashPart.CFrame = CFrame.new(cam.X, groundY + 0.6, cam.Z)
	end
end

local function updateRain(rain: number)
	local camera = workspace.CurrentCamera
	if not rainEmitter or not camera then
		return
	end
	local cam = camera.CFrame.Position
	local mult = qualityMultiplier()
	rainEmitter.Rate = rain * 1100 * mult
	if splashEmitter then
		local now = os.clock()
		if now - lastGroundCheck > 0.4 then
			lastGroundCheck = now
			local hit = workspace:Raycast(cam + Vector3.new(0, 20, 0), Vector3.new(0, -300, 0), groundParams)
			groundY = if hit then hit.Position.Y else cam.Y - 20
		end
		splashEmitter.Rate = if rain > 0.1 then rain * 260 * mult else 0
	end
end

-- FULMINI ----------------------------------------------------------------------------------------------

local function lightningStrike()
	local camera = workspace.CurrentCamera
	if not camera or not C.EffectsController then
		return
	end
	local cam = camera.CFrame.Position
	local angle = rng:NextNumber(0, math.pi * 2)
	local dist = rng:NextNumber(220, 700)
	local ground = Vector3.new(cam.X + math.cos(angle) * dist, cam.Y - 40, cam.Z + math.sin(angle) * dist)
	local hit = workspace:Raycast(ground + Vector3.new(0, 400, 0), Vector3.new(0, -900, 0), groundParams)
	if hit then
		ground = hit.Position
	end
	C.EffectsController.Lightning(ground + Vector3.new(rng:NextNumber(-60, 60), 900, rng:NextNumber(-60, 60)), ground, Color3.fromRGB(225, 232, 255), 3 + rng:NextNumber() * 3)
	C.EffectsController.Flash(Color3.fromRGB(230, 236, 255), math.clamp(0.5 - dist / 1800, 0.12, 0.4), 0.25)
	-- il tuono arriva dopo il lampo (più lontano = più tardi)
	task.delay(dist / 500, function()
		if C.SoundController then
			C.SoundController.Play("Thunder", nil, { Volume = math.clamp(1.1 - dist / 900, 0.35, 1), Pitch = rng:NextNumber(0.24, 0.34) })
		end
		if C.CameraController and dist < 400 then
			C.CameraController.Shake(0.12, 0.4)
		end
	end)
end

-- CIELO ------------------------------------------------------------------------------------------------

local function approach(current: number, target: number, k: number): number
	return current + (target - current) * k
end

local function step(dt: number)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	indoor = (root ~= nil and root.Position.Y < -120) or zoneAmbience == Zones.Ambience.Sotterraneo or zoneAmbience == Zones.Ambience.Cristallo

	-- il meteo cambia lentamente (circa 15 secondi)
	local target = WEATHER[SkyController.Weather()] or WEATHER.Sereno
	local kw = math.min(1, dt * 0.08)
	for _, key in NUMERIC do
		weather[key] = approach(weather[key], target[key], kw)
	end
	weather.CloudColor = (weather.CloudColor or target.CloudColor):Lerp(target.CloudColor, kw)

	local warm, night, dawn = timeOfDay()
	local w = if indoor then WEATHER.Sereno else weather
	local sky = if indoor then 0 else 1
	local amb = zoneAmbience
	local grey = w.Grey * sky

	local color = amb.Color:Lerp(Color3.fromRGB(255, 176, 128), warm * 0.55 * sky):Lerp(Color3.fromRGB(46, 58, 96), night * 0.75 * sky):Lerp(Color3.fromRGB(150, 156, 166), grey * (1 - night * 0.5))
	local decay = amb.Decay:Lerp(Color3.fromRGB(214, 120, 86), warm * 0.6 * sky):Lerp(Color3.fromRGB(18, 24, 46), night * 0.8 * sky):Lerp(Color3.fromRGB(96, 100, 110), grey)
	local tint = amb.Tint:Lerp(Color3.fromRGB(255, 214, 180), warm * 0.45 * sky):Lerp(Color3.fromRGB(198, 212, 255), night * 0.55 * sky):Lerp(Color3.fromRGB(226, 232, 240), grey * 0.6)

	local k = math.min(1, dt * 0.6)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = approach(atmosphere.Density, amb.Density + w.Density * sky + dawn * 0.08 * sky, k)
		atmosphere.Haze = approach(atmosphere.Haze, amb.Haze + w.Haze * sky + warm * 0.9 * sky, k)
		atmosphere.Glare = approach(atmosphere.Glare, amb.Glare * (1 - grey) + warm * 0.5 * sky, k)
		atmosphere.Color = atmosphere.Color:Lerp(color, k)
		atmosphere.Decay = atmosphere.Decay:Lerp(decay, k)
	end
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if cc then
		cc.TintColor = cc.TintColor:Lerp(tint, k)
		cc.Saturation = approach(cc.Saturation, amb.Saturation + w.Sat * sky + warm * 0.05 * sky, k)
		cc.Contrast = approach(cc.Contrast, amb.Contrast + warm * 0.03 * sky, k)
	end
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if rays then
		rays.Intensity = approach(rays.Intensity, (0.05 + warm * 0.12) * (1 - grey) * sky, k)
	end
	Lighting.ExposureCompensation = approach(Lighting.ExposureCompensation, amb.Exposure + w.Exposure * sky + night * 0.05 * sky, k)
	Lighting.Brightness = approach(Lighting.Brightness, base.Brightness * (if indoor then 1 else w.Bright), k)
	Lighting.OutdoorAmbient = Lighting.OutdoorAmbient:Lerp(base.OutdoorAmbient:Lerp(Color3.fromRGB(96, 106, 146), night * 0.5 * sky), k)

	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds.Cover = approach(clouds.Cover, w.Cover, k)
		clouds.Density = approach(clouds.Density, w.CloudDensity, k)
		local cloudColor = (w.CloudColor or Color3.new(1, 1, 1)):Lerp(Color3.fromRGB(255, 190, 150), warm * 0.6 * (1 - grey)):Lerp(Color3.fromRGB(40, 46, 66), night * 0.85)
		clouds.Color = clouds.Color:Lerp(cloudColor, k)
	end

	-- pioggia e fulmini
	local rain = if indoor then 0 else weather.Rain
	updateRain(rain)
	if rain > 1.5 and not indoor then
		local now = os.clock()
		if now > nextLightning then
			nextLightning = now + rng:NextNumber(5, 14)
			lightningStrike()
		end
	end
end

function SkyController.Init(c)
	C = c
end

function SkyController.Start()
	base.Brightness = math.max(Lighting.Brightness, 2)
	base.OutdoorAmbient = Lighting.OutdoorAmbient
	weather = table.clone(WEATHER[SkyController.Weather()] or WEATHER.Sereno)
	buildRain()
	RunService.RenderStepped:Connect(followCamera)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.05 then
			return
		end
		local ok, err = pcall(step, acc)
		acc = 0
		if not ok then
			warn("[Cielo] " .. tostring(err))
		end
	end)
end

return SkyController
