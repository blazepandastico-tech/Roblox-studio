--[[
	CameraController
	Telecamera "da azione": mouse bloccato al centro (mirino), visuale da sopra la spalla,
	campo visivo che si allarga con la velocità, inclinazione nelle virate coi Rampini,
	scosse per impatti ed esplosioni. Modalità cursore per i menu e modalità cinematica.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CameraController = {}
local C

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local gameSettings = UserSettings():GetService("UserGameSettings")

local cursorMode = false
local cinematic = false
local titanHeight = 0
local trauma = 0
local traumaDecay = 1.6
local currentFov = 70
local roll = 0
local rollTarget = 0
local fovBoost = 0
local appliedOffset: CFrame? = nil
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

CameraController.BaseFov = 70
CameraController.SpeedFov = 0

function CameraController.SetCursorMode(on: boolean)
	cursorMode = on
end

function CameraController.IsCursorMode(): boolean
	return cursorMode
end

function CameraController.SetCinematic(on: boolean)
	cinematic = on
	if on then
		camera.CameraType = Enum.CameraType.Scriptable
	else
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

function CameraController.IsCinematic(): boolean
	return cinematic
end

-- intensity 0..1 (si somma); duration regola quanto dura
function CameraController.Shake(intensity: number, duration: number?)
	if C.ClientData and C.ClientData.Setting("Shake", true) == false then
		return
	end
	trauma = math.clamp(trauma + intensity, 0, 1.2)
	traumaDecay = 1 / math.max(0.15, duration or 0.4)
end

function CameraController.SetRoll(target: number)
	rollTarget = target
end

function CameraController.Punch(amount: number)
	fovBoost = math.max(fovBoost, amount)
end

function CameraController.SetTitanForm(height: number)
	titanHeight = height
	if height > 0 then
		player.CameraMaxZoomDistance = math.clamp(height * 3.2, 60, 900)
		player.CameraMinZoomDistance = math.clamp(height * 0.9, 12, 250)
	else
		player.CameraMinZoomDistance = 6
		player.CameraMaxZoomDistance = 45
	end
end

local function humanoidOf(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Scossa attuale (rotazione) calcolata dal "trauma" accumulato con Shake()
local function computeShake(dt: number): CFrame
	if trauma <= 0 then
		return CFrame.identity
	end
	local power = trauma * trauma
	local t = os.clock() * 28
	local max = math.rad(2.8)
	local shakeCF = CFrame.Angles(
		math.noise(t, 1.3) * max * power,
		math.noise(t, 7.7) * max * power,
		math.noise(t, 4.2) * max * power * 1.4
	)
	trauma = math.max(0, trauma - dt * traumaDecay)
	return shakeCF
end

local cinematicShake = CFrame.identity

-- Per le telecamere cinematiche (filmati, intro): la scossa da aggiungere alla propria inquadratura
function CameraController.CinematicShake(): CFrame
	return cinematicShake
end

local function update(dt: number)
	-- mouse: libero con un menu aperto o durante i filmati, bloccato al centro in gioco
	if not isMobile then
		if cursorMode or cinematic then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = cursorMode
		else
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
		end
	end
	if cinematic then
		cinematicShake = computeShake(dt)
		return
	end
	cinematicShake = CFrame.identity
	local humanoid = humanoidOf()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?

	-- rotazione del personaggio
	local flying = C.ODMController and C.ODMController.IsFlying()
	pcall(function()
		if cursorMode or flying or isMobile then
			gameSettings.RotationType = Enum.RotationType.MovementRelative
		else
			gameSettings.RotationType = Enum.RotationType.CameraRelative
		end
	end)

	-- visuale da sopra la spalla
	if humanoid then
		local target
		if titanHeight > 0 then
			target = Vector3.new(0, 0, 0)
		elseif cursorMode then
			target = Vector3.new(0, 0.5, 0)
		else
			target = Vector3.new(1.7, 0.6, 0)
		end
		humanoid.CameraOffset = humanoid.CameraOffset:Lerp(target, math.min(1, dt * 8))
	end

	-- campo visivo in base alla velocità
	local speed = if root then root.AssemblyLinearVelocity.Magnitude else 0
	local speedFov = math.clamp((speed - 45) / 120, 0, 1) * 24
	if titanHeight > 0 then
		speedFov = 6
	end
	fovBoost = math.max(0, fovBoost - dt * 30)
	local targetFov = CameraController.BaseFov + speedFov + fovBoost
	currentFov += (targetFov - currentFov) * math.min(1, dt * 5)
	camera.FieldOfView = currentFov
	CameraController.SpeedFov = speedFov

	-- inclinazione e scossa
	roll += (rollTarget - roll) * math.min(1, dt * 6)
	local shaking = trauma > 0
	local shakeCF = computeShake(dt)
	if math.abs(roll) > 0.001 or shaking then
		local offset = CFrame.Angles(0, 0, roll) * shakeCF
		camera.CFrame = camera.CFrame * offset
		appliedOffset = offset
	end
end

-- Prima che la telecamera di Roblox si aggiorni, togliamo la scossa del frame
-- precedente: così la mira non "scivola" nel tempo.
local function undoOffset()
	if appliedOffset and not cinematic then
		camera.CFrame = camera.CFrame * appliedOffset:Inverse()
	end
	appliedOffset = nil
end

function CameraController.Init(c)
	C = c
end

function CameraController.Start()
	camera.FieldOfView = 70
	RunService:BindToRenderStep("CameraSieriPerdutiPre", Enum.RenderPriority.Camera.Value - 1, undoOffset)
	RunService:BindToRenderStep("CameraSieriPerduti", Enum.RenderPriority.Camera.Value + 1, update)
	player.CharacterAdded:Connect(function()
		titanHeight = 0
		CameraController.SetTitanForm(0)
		if cinematic then
			camera.CameraType = Enum.CameraType.Scriptable
		end
	end)
end

return CameraController
