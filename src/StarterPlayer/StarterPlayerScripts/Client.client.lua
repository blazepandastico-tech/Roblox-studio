-- Input del giocatore (PC): calcio con carica, passaggio, flick, lancio, scivolata, dribbling, sprint.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))
local Hud = require(script.Parent:WaitForChild("Modules"):WaitForChild("Hud"))
local Effects = require(script.Parent.Modules:WaitForChild("Effects"))

local player = Players.LocalPlayer
local C = Config.Controls

Hud.Build()
Effects.Start()

local function camera()
	return workspace.CurrentCamera
end

local function aimDir()
	return camera().CFrame.LookVector
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function moveDir()
	-- direzione del movimento in coordinate mondo (da tasti A/D rispetto alla camera)
	local right = flat(camera().CFrame.RightVector)
	if right.Magnitude < 0.01 then
		return nil
	end
	right = right.Unit
	local x = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		x = x + 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		x = x - 1
	end
	if x ~= 0 then
		return right * x
	end
	return nil
end

----------------------------------------------------------------------
-- Calcio con carica e tiro a effetto
----------------------------------------------------------------------
local charging = false
local chargeStart = 0
local curve = 0

local function startCharge()
	charging = true
	chargeStart = os.clock()
	curve = 0
end

local function releaseCharge()
	if not charging then
		return
	end
	charging = false
	Hud.SetCharge(nil)
	local held = os.clock() - chargeStart
	local charge = 0
	if held >= Config.Kick.TapThreshold then
		charge = math.clamp(held / Config.Kick.ChargeTime, 0, 1)
	end
	Net.Get("Kick"):FireServer("normal", charge, aimDir(), curve)
end

RunService.RenderStepped:Connect(function()
	if charging then
		local held = os.clock() - chargeStart
		if held >= Config.Kick.TapThreshold then
			Hud.SetCharge(math.clamp(held / Config.Kick.ChargeTime, 0, 1))
		end
		-- effetto: direzione perpendicolare al tiro (A = sinistra, D = destra)
		local a = UserInputService:IsKeyDown(Enum.KeyCode.A)
		local d = UserInputService:IsKeyDown(Enum.KeyCode.D)
		if d and not a then
			curve = 1
		elseif a and not d then
			curve = -1
		end
	end
end)

----------------------------------------------------------------------
-- Azioni (tramite ContextActionService, cosi' Spazio non fa saltare)
----------------------------------------------------------------------
local spaceStart = 0
local PASS = Enum.ContextActionResult.Pass
local SINK = Enum.ContextActionResult.Sink

local function bind(name, handler, ...)
	ContextActionService:BindActionAtPriority(name, handler, false, Enum.ContextActionPriority.High.Value, ...)
end

bind("KickAction", function(_, state)
	if state == Enum.UserInputState.Begin then
		startCharge()
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		releaseCharge()
	end
	return PASS
end, Enum.UserInputType.MouseButton1)

bind("PassAction", function(_, state)
	if state == Enum.UserInputState.Begin then
		Net.Get("Kick"):FireServer("pass", 0, aimDir(), 0)
	end
	return PASS
end, Enum.UserInputType.MouseButton2)

bind("FlickAction", function(_, state)
	if state == Enum.UserInputState.Begin then
		Net.Get("Kick"):FireServer("flick", 0, aimDir(), 0)
	end
	return PASS
end, C.Flick)

bind("LobAction", function(_, state)
	if state == Enum.UserInputState.Begin then
		Net.Get("Kick"):FireServer("lob", 0, aimDir(), 0)
	end
	return PASS
end, C.Lob)

bind("TackleAction", function(_, state)
	if state == Enum.UserInputState.Begin then
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local dir = hrp and flat(hrp.CFrame.LookVector) or flat(aimDir())
		Net.Get("Tackle"):FireServer(dir)
	end
	return PASS
end, C.Tackle)

bind("DribbleAction", function(_, state)
	if state == Enum.UserInputState.Begin then
		spaceStart = os.clock()
		Net.Get("Control"):FireServer(true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		Net.Get("Control"):FireServer(false)
		if os.clock() - spaceStart < 0.2 then
			local d = moveDir()
			if not d then
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				d = hrp and flat(hrp.CFrame.RightVector) or flat(camera().CFrame.RightVector)
			end
			Net.Get("Dash"):FireServer(d)
		end
	end
	return SINK
end, C.Dribble)

bind("SprintAction", function(_, state)
	if state == Enum.UserInputState.Begin then
		Net.Get("Sprint"):FireServer(true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		Net.Get("Sprint"):FireServer(false)
	end
	return PASS
end, C.Sprint)

bind("CallBallAction", function(_, state)
	if state == Enum.UserInputState.Begin then
		Net.Get("CallBall"):FireServer()
	end
	return PASS
end, C.CallBall)

bind("LobbyAction", function(_, state)
	if state == Enum.UserInputState.Begin then
		Net.Get("ReturnLobby"):FireServer()
	end
	return PASS
end, C.Lobby)
