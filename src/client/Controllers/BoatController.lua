--[[
	BoatController - guida la propria barca
	Seduto al timone della TUA barca: W/S velocità, A/D timone, Spazio per scendere.
	Il server affida la fisica della barca al tuo client quando sali: qui calcoliamo
	spinta, rollio e beccheggio sulle onde. Gli amici possono sedersi sugli altri posti.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Theme = require(script.Parent.Parent.UI.Theme)

local BoatController = {}
local C
local player = Players.LocalPlayer

local BOAT = Config.Boat

local boat: Model? = nil
local hull: BasePart? = nil
local thrust: LinearVelocity? = nil
local trim: AlignOrientation? = nil
local speed = 0
local yaw = 0
local lean = 0
local controls: any = nil
local hint: TextLabel
local lastSpray = 0

local function getControls()
	if controls then
		return controls
	end
	local ok, result = pcall(function()
		local module = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
		return module:GetControls()
	end)
	if ok then
		controls = result
	end
	return controls
end

-- La barca di cui sei al timone (solo la tua)
local function steeredBoat(): Model?
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat and seat.Name == "Timone" then
		local model = seat.Parent
		if model and model:IsA("Model") and model:GetAttribute("Owner") == player.UserId then
			return model
		end
	end
	return nil
end

function BoatController.IsSteering(): boolean
	return boat ~= nil
end

local function release()
	if thrust then
		thrust.Enabled = false
	end
	if trim then
		trim.Enabled = false
	end
	boat, hull, thrust, trim = nil, nil, nil, nil
	speed = 0
	hint.Visible = false
end

local function take(model: Model)
	release()
	local primary = model.PrimaryPart
	if not primary then
		return
	end
	boat = model
	hull = primary
	thrust = primary:FindFirstChild("Spinta") :: LinearVelocity?
	trim = primary:FindFirstChild("Assetto") :: AlignOrientation?
	local _, y = primary.CFrame:ToOrientation()
	yaw = y
	speed = 0
	lean = 0
	hint.Visible = true
	if C.Notifications then
		C.Notifications.Toast("⛵ W/S velocità • A/D timone • Spazio per scendere", "Info", 3)
	end
end

local function step(dt: number)
	local model = steeredBoat()
	if model ~= boat then
		if model then
			take(model)
		else
			release()
		end
	end
	if not boat or not hull or not thrust or not trim then
		return
	end
	if hull.Anchored then
		-- il server non ci ha ancora affidato la barca
		return
	end
	thrust.Enabled = true
	trim.Enabled = true
	local move = Vector3.zero
	local ctrl = getControls()
	if ctrl then
		move = ctrl:GetMoveVector()
	end
	local throttle = -move.Z
	local steer = move.X
	local target = if throttle > 0.1 then BOAT.MaxSpeed * throttle elseif throttle < -0.1 then -BOAT.Reverse else 0
	local accel = if math.abs(target) > math.abs(speed) then BOAT.Accel else BOAT.Accel * 0.8
	if speed < target then
		speed = math.min(target, speed + accel * dt)
	elseif speed > target then
		speed = math.max(target, speed - accel * dt)
	end
	-- si gira meglio in movimento (da ferma la barca ruota piano sul posto)
	local ratio = math.clamp(math.abs(speed) / BOAT.MaxSpeed, 0, 1)
	local turn = math.rad(BOAT.TurnRate) * (0.35 + 0.65 * ratio) * dt * steer
	if speed < -0.5 then
		turn = -turn
	end
	yaw -= turn
	lean += ((steer * ratio * 0.12) - lean) * math.min(1, dt * 3)
	local t = os.clock()
	local forward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	local targetY = (boat:GetAttribute("HullY") or 4.6) + math.sin(t * 1.3) * 0.22
	local dy = (targetY - hull.Position.Y) * 4
	thrust.VectorVelocity = forward * speed + Vector3.new(0, dy, 0)
	local pitch = math.sin(t * 1.1) * 0.03 + ratio * 0.05
	local roll = math.sin(t * 0.9) * 0.025 - lean
	trim.CFrame = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, roll)
	hint.Text = ("⛵ %d nodi   •   W/S velocità   •   A/D timone   •   Spazio: scendi"):format(math.floor(math.abs(speed) / 3))
	-- spruzzi a prua quando si va veloci
	if ratio > 0.35 and t - lastSpray > 0.18 and C.EffectsController then
		lastSpray = t
		local bow = hull.Position + forward * 12 + Vector3.new(0, -0.5, 0)
		C.EffectsController.Steam(bow, 2 + ratio * 2, 3, 0.6, Color3.fromRGB(230, 244, 255))
	end
end

function BoatController.Init(c)
	C = c
end

function BoatController.Start()
	hint = Theme.Label("", {
		Name = "GuidaBarca",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -170),
		Size = UDim2.fromOffset(560, 26),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.Bold,
		TextSize = 16,
		TextStrokeTransparency = 0.4,
		Visible = false,
		Parent = C.UIController.Layers.HUD,
	})
	RunService.Heartbeat:Connect(function(dt)
		local ok, err = pcall(step, dt)
		if not ok then
			warn("[Barca] " .. tostring(err))
			release()
		end
	end)
	player.CharacterAdded:Connect(function()
		release()
	end)
end

return BoatController
