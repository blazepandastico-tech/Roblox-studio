--[[
	WaypointController - segnalino 3D dell'obiettivo della storia
	Una colonna di luce dorata sul punto da raggiungere e un'etichetta "◆ 120 m" sempre visibile:
	i nuovi giocatori sanno sempre dove andare (fondamentale nei primi minuti di gioco).
	Sparisce quando sei a meno di 12 metri dall'obiettivo.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local WaypointController = {}
local C

local player = Players.LocalPlayer
local STUDS_PER_METER = 3.5

local anchor: Part
local billboard: BillboardGui
local label: TextLabel
local beam: Part

local function build()
	anchor = Instance.new("Part")
	anchor.Name = "SegnalinoObiettivo"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Parent = workspace

	beam = Instance.new("Part")
	beam.Name = "ColonnaDiLuce"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 210, 110)
	beam.Transparency = 0.6
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(220, 3, 3)
	beam.Parent = workspace

	billboard = Instance.new("BillboardGui")
	billboard.Name = "Obiettivo"
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromOffset(160, 54)
	billboard.StudsOffset = Vector3.new(0, 10, 0)
	billboard.MaxDistance = math.huge
	billboard.Adornee = anchor
	billboard.Parent = player:WaitForChild("PlayerGui")

	label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 20
	label.TextColor3 = Color3.fromRGB(255, 222, 130)
	label.TextStrokeTransparency = 0.3
	label.Text = ""
	label.Parent = billboard
end

local function setVisible(on: boolean)
	billboard.Enabled = on
	beam.Transparency = if on then 0.6 else 1
end

function WaypointController.Init(c)
	C = c
end

function WaypointController.Start()
	build()
	setVisible(false)
	RunService.Heartbeat:Connect(function()
		local target = C.HUD and C.HUD.ObjectivePosition and C.HUD.ObjectivePosition()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hidden = C.CutsceneController and C.CutsceneController.IsPlaying()
		if not target or not root or hidden then
			setVisible(false)
			return
		end
		local distance = (Vector3.new(target.X, root.Position.Y, target.Z) - root.Position).Magnitude
		if distance < 12 then
			setVisible(false)
			return
		end
		setVisible(true)
		anchor.CFrame = CFrame.new(target)
		-- colonna verticale (il cilindro è orientato lungo X: ruotato in piedi)
		beam.CFrame = CFrame.new(target + Vector3.new(0, 110, 0)) * CFrame.Angles(0, 0, math.rad(90))
		-- da vicino la colonna sbiadisce per non coprire la visuale
		beam.Transparency = math.clamp(1 - distance / 400, 0.6, 0.92)
		label.Text = ("◆ %d m"):format(math.floor(distance / STUDS_PER_METER))
	end)
end

return WaypointController
