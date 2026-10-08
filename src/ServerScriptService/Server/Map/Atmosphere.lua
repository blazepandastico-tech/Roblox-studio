-- Luce da tramonto, cielo, nuvole ed effetti di post-produzione.
local Lighting = game:GetService("Lighting")

local Atmosphere = {}

function Atmosphere.Build()
	-- via eventuali effetti gia' presenti (place nuovo o rilancio dello script)
	for _, c in ipairs(Lighting:GetChildren()) do
		if c:IsA("Sky") or c:IsA("Atmosphere") or c:IsA("PostEffect") then
			c:Destroy()
		end
	end

	-- Il percorso del sole va da +X (alba) a -X (tramonto): le ombre lunghe cadono lungo il campo, non attraverso.
	Lighting.GeographicLatitude = 23.5
	Lighting.ClockTime = 17.0
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(96, 72, 112)
	Lighting.OutdoorAmbient = Color3.fromRGB(138, 104, 130)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 176, 120)
	Lighting.ColorShift_Bottom = Color3.fromRGB(120, 84, 150)
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.ExposureCompensation = 0.1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35

	local atm = Instance.new("Atmosphere")
	atm.Name = "Foschia"
	atm.Density = 0.34
	atm.Offset = 0.3
	atm.Color = Color3.fromRGB(255, 170, 142)
	atm.Decay = Color3.fromRGB(148, 78, 122)
	atm.Glare = 0.6
	atm.Haze = 1.8
	atm.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "Bagliore"
	bloom.Intensity = 0.7
	bloom.Size = 30
	bloom.Threshold = 0.9
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Colori"
	cc.Brightness = 0
	cc.Contrast = 0.14
	cc.Saturation = 0.24
	cc.TintColor = Color3.fromRGB(255, 238, 242)
	cc.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Name = "Raggi"
	rays.Intensity = 0.1
	rays.Spread = 0.8
	rays.Parent = Lighting

	-- nuvole volumetriche (vivono dentro il Terrain)
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if not clouds then
		clouds = Instance.new("Clouds")
		clouds.Name = "Nuvole"
		clouds.Parent = workspace.Terrain
	end
	clouds.Enabled = true
	clouds.Cover = 0.55
	clouds.Density = 0.55
	clouds.Color = Color3.fromRGB(255, 196, 190)
end

return Atmosphere
