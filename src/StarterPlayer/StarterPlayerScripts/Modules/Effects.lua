-- Effetti solo-client: anelli sotto giocatori e palla, indicatore palla libera, scia, barretta stamina.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local player = Players.LocalPlayer

local Effects = {}

local ringFolder
local rings = {} -- [character] = part
local ballRing, ballGui
local GROUND_Y = 0.22

local function makeRing(diameter, color, transparency)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.12, diameter, diameter)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency
	p.Parent = ringFolder
	return p
end

local function flatCF(x, z)
	return CFrame.new(x, GROUND_Y, z) * CFrame.Angles(0, 0, math.pi / 2)
end

local function teamColorOf(plr)
	if plr.Team then
		for _, t in pairs(Config.Teams) do
			if t.Name == plr.Team.Name then
				return t.Color
			end
		end
	end
	return nil
end

local staminaGui

local function ensureStaminaBar(char)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	if staminaGui and staminaGui.Parent == hrp then
		return
	end
	if staminaGui then
		staminaGui:Destroy()
	end
	staminaGui = Instance.new("BillboardGui")
	staminaGui.Name = "StaminaBar"
	staminaGui.Size = UDim2.fromOffset(64, 6)
	staminaGui.StudsOffset = Vector3.new(0, -3.4, 0)
	staminaGui.AlwaysOnTop = false
	staminaGui.Adornee = hrp
	staminaGui.Parent = hrp
	local bg = Instance.new("Frame")
	bg.Name = "Bg"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	bg.BackgroundTransparency = 0.4
	bg.Parent = staminaGui
	Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(70, 214, 100)
	fill.Parent = bg
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
end

function Effects.Start()
	ringFolder = Instance.new("Folder")
	ringFolder.Name = "LocalRings"
	ringFolder.Parent = workspace

	RunService.RenderStepped:Connect(function()
		-- anelli giocatori
		local seen = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local color = teamColorOf(plr)
			if hrp and color then
				seen[char] = true
				local ring = rings[char]
				if not ring then
					ring = makeRing(7, color, 0.15)
					rings[char] = ring
				end
				ring.Color = color
				ring.CFrame = flatCF(hrp.Position.X, hrp.Position.Z)
			end
		end
		for char, ring in pairs(rings) do
			if not seen[char] then
				ring:Destroy()
				rings[char] = nil
			end
		end

		-- palla
		local ball = workspace:FindFirstChild("Ball")
		if ball then
			if not ballRing then
				ballRing = makeRing(6, Color3.fromRGB(255, 255, 255), 0.25)
				ballGui = Instance.new("BillboardGui")
				ballGui.Size = UDim2.fromOffset(40, 40)
				ballGui.StudsOffset = Vector3.new(0, 3.6, 0)
				ballGui.AlwaysOnTop = true
				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.fromScale(1, 1)
				lbl.BackgroundTransparency = 1
				lbl.Text = "▼"
				lbl.TextScaled = true
				lbl.Font = Enum.Font.GothamBlack
				lbl.TextColor3 = Color3.fromRGB(255, 220, 60)
				lbl.Parent = ballGui
				ballGui.Adornee = ball
				ballGui.Parent = ball
			end
			local p = ball.Position
			ballRing.CFrame = flatCF(p.X, p.Z)
			ballRing.Transparency = math.clamp(0.25 + p.Y / 40, 0.25, 0.9)
			ballGui.Enabled = ball:GetAttribute("Possessor") == nil
			local trail = ball:FindFirstChildOfClass("Trail")
			if trail then
				trail.Enabled = ball.AssemblyLinearVelocity.Magnitude > 55
			end
		end

		-- barretta stamina sotto il personaggio
		local char = player.Character
		if char then
			ensureStaminaBar(char)
			if staminaGui then
				local st = player:GetAttribute("Stamina") or Config.Stamina.Pips
				local frac = st / Config.Stamina.Pips
				staminaGui.Enabled = frac < 0.999
				local fill = staminaGui:FindFirstChild("Bg") and staminaGui.Bg:FindFirstChild("Fill")
				if fill then
					fill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
				end
			end
		end
	end)
end

return Effects
