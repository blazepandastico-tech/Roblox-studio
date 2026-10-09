--[[
	CameraController
	Telecamera "da battaglia":
	  - SHIFT attiva/disattiva lo shift lock (mouse al centro, visuale da sopra la spalla,
	    il personaggio guarda dove guardi). Senza shift lock il mouse è libero e si mira col cursore.
	  - la visuale ha "peso": ruotandola in fretta resta un po' indietro, si inclina nella
	    direzione della rotazione e poi si riassesta con un leggero rimbalzo
	  - oscillazione dei passi quando cammini e corri, respiro quando sei fermo,
	    contraccolpo all'atterraggio, campo visivo più largo in corsa e in volo
	  - scosse per impatti ed esplosioni, modalità cursore per i menu e modalità cinematica
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

-- shift lock e dinamica "da battaglia"
local shiftLock = true
local lastMouseMode = ""
local lastLook: Vector3? = nil
local swayYaw, swayYawVel = 0, 0
local swayPitch, swayPitchVel = 0, 0
local swayRoll, swayRollVel = 0, 0
local bobPhase = 0
local bobAmount = 0
local landDip = 0
local runFov = 0

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

function CameraController.IsShiftLock(): boolean
	return shiftLock and not isMobile
end

function CameraController.SetShiftLock(on: boolean, silent: boolean?)
	shiftLock = on
	if C.ClientData then
		C.ClientData.SetSetting("ShiftLock", on)
	end
	if not silent and C.Notifications then
		C.Notifications.Toast(if on then "🎯 Shift lock ATTIVO" else "🖱️ Shift lock DISATTIVATO (mira col mouse)", "Info", 1.6)
	end
end

-- Punto dello schermo da cui partono mira, rampini e colpi a distanza
function CameraController.AimScreenPoint(): Vector2
	local size = camera.ViewportSize
	if CameraController.IsShiftLock() or cursorMode or cinematic then
		return Vector2.new(size.X / 2, size.Y / 2)
	end
	return UserInputService:GetMouseLocation()
end

-- Contraccolpo all'atterraggio (0..1)
function CameraController.Land(strength: number)
	landDip = math.max(landDip, math.clamp(strength, 0, 1))
	if strength > 0.55 then
		CameraController.Shake(0.12 * strength, 0.3)
	end
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

-- molla smorzata: la visuale "pesa" e si riassesta con un leggero rimbalzo
local function spring(x: number, v: number, target: number, dt: number, stiffness: number, damping: number): (number, number)
	v += (target - x) * stiffness * dt
	v *= math.exp(-damping * dt)
	return x + v * dt, v
end

local function update(dt: number)
	dt = math.min(dt, 1 / 20)
	local locked = shiftLock and not isMobile
	-- mouse: libero con un menu aperto, nei filmati o senza shift lock; bloccato al centro con lo shift lock
	if not isMobile then
		local mode = if cursorMode or cinematic then "free" elseif locked then "lock" else "roblox"
		if mode == "lock" then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
		elseif mode == "free" then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = cursorMode
		elseif lastMouseMode ~= "roblox" then
			-- senza shift lock lasciamo il mouse a Roblox (tasto destro per ruotare la visuale);
			-- la freccia è sostituita dal mirino, che segue il cursore
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = false
		end
		lastMouseMode = mode
	end
	if cinematic then
		cinematicShake = computeShake(dt)
		lastLook = nil
		return
	end
	cinematicShake = CFrame.identity
	local humanoid = humanoidOf()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?

	-- rotazione del personaggio: con lo shift lock guarda dove guarda la telecamera
	local flying = C.ODMController and C.ODMController.IsFlying()
	pcall(function()
		if cursorMode or flying or not locked then
			gameSettings.RotationType = Enum.RotationType.MovementRelative
		else
			gameSettings.RotationType = Enum.RotationType.CameraRelative
		end
	end)

	-- visuale da sopra la spalla (solo con lo shift lock)
	if humanoid then
		local target
		if titanHeight > 0 then
			target = Vector3.new(0, 0, 0)
		elseif cursorMode or not locked then
			target = Vector3.new(0, 0.5, 0)
		else
			target = Vector3.new(1.7, 0.6, 0)
		end
		humanoid.CameraOffset = humanoid.CameraOffset:Lerp(target, math.min(1, dt * 8))
	end

	-- velocità e stato del personaggio
	local velocity = if root then root.AssemblyLinearVelocity else Vector3.zero
	local speed = velocity.Magnitude
	local flat = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local state = humanoid and humanoid:GetState()
	local grounded = humanoid ~= nil and not flying and state ~= Enum.HumanoidStateType.Freefall and state ~= Enum.HumanoidStateType.Jumping and humanoid.FloorMaterial ~= Enum.Material.Air

	-- campo visivo: più largo in corsa e in volo
	local speedFov = math.clamp((speed - 45) / 120, 0, 1) * 24
	if titanHeight > 0 then
		speedFov = 6
	end
	local runTarget = if grounded and flat > 16 then 6 else 0
	runFov += (runTarget - runFov) * math.min(1, dt * 4)
	fovBoost = math.max(0, fovBoost - dt * 30)
	local targetFov = CameraController.BaseFov + speedFov + runFov + fovBoost
	currentFov += (targetFov - currentFov) * math.min(1, dt * 5)
	camera.FieldOfView = currentFov
	CameraController.SpeedFov = speedFov

	-- PESO DELLA VISUALE: misuriamo quanto in fretta ruota la telecamera
	local look = camera.CFrame.LookVector
	local yawRate, pitchRate = 0, 0
	if lastLook then
		local yaw0 = math.atan2(-lastLook.X, -lastLook.Z)
		local yaw1 = math.atan2(-look.X, -look.Z)
		local dyaw = (yaw1 - yaw0 + math.pi) % (2 * math.pi) - math.pi
		local dpitch = math.asin(math.clamp(look.Y, -1, 1)) - math.asin(math.clamp(lastLook.Y, -1, 1))
		yawRate = dyaw / dt
		pitchRate = dpitch / dt
	end
	lastLook = look
	local sway = if C.ClientData and C.ClientData.Setting("Shake", true) == false then 0.35 else 1
	local intensity = (if titanHeight > 0 then 0.4 else 1) * sway
	-- la visuale resta un po' indietro rispetto alla rotazione e si inclina verso la curva
	local yawTarget = math.clamp(-yawRate * 0.022, -0.07, 0.07) * intensity
	local pitchTarget = math.clamp(-pitchRate * 0.018, -0.05, 0.05) * intensity
	local rollTarget2 = math.clamp(-yawRate * 0.035, -0.11, 0.11) * intensity
	swayYaw, swayYawVel = spring(swayYaw, swayYawVel, yawTarget, dt, 160, 13)
	swayPitch, swayPitchVel = spring(swayPitch, swayPitchVel, pitchTarget, dt, 160, 13)
	swayRoll, swayRollVel = spring(swayRoll, swayRollVel, rollTarget2, dt, 110, 10)

	-- PASSI E RESPIRO
	local moveK = if grounded then math.clamp(flat / 22, 0, 1) else 0
	bobAmount += (moveK - bobAmount) * math.min(1, dt * 6)
	local running = math.clamp((flat - 13) / 6, 0, 1)
	bobPhase += dt * flat * (0.5 - 0.12 * running)
	local now = os.clock()
	local bobY = (math.abs(math.sin(bobPhase)) - 0.5) * (0.1 + 0.16 * running) * bobAmount
	local bobX = math.sin(bobPhase) * (0.05 + 0.08 * running) * bobAmount
	local bobRoll = math.sin(bobPhase) * (0.004 + 0.008 * running) * bobAmount
	local breathe = math.sin(now * 1.3) * 0.025 * (1 - bobAmount)
	local breathePitch = math.sin(now * 1.3 + 0.6) * 0.0035 * (1 - bobAmount)

	-- contraccolpo dell'atterraggio
	landDip = math.max(0, landDip - dt * 2.4)
	local dip = landDip * landDip

	-- inclinazione dei rampini e scossa
	roll += (rollTarget - roll) * math.min(1, dt * 6)
	local shakeCF = computeShake(dt)
	local motion = CFrame.new(bobX * intensity, (bobY + breathe - dip * 0.7) * intensity, 0)
		* CFrame.Angles(swayPitch + breathePitch - dip * 0.07, swayYaw, swayRoll + bobRoll * intensity)
	local offset = motion * CFrame.Angles(0, 0, roll) * shakeCF
	camera.CFrame = camera.CFrame * offset
	appliedOffset = offset
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
	-- SHIFT: attiva/disattiva lo shift lock (la scelta viene salvata)
	C.InputController.On("ShiftLock", function(began)
		if began and not cursorMode and not cinematic then
			CameraController.SetShiftLock(not shiftLock)
		end
	end)
	task.spawn(function()
		local profile = C.ClientData.WaitReady()
		if profile and profile.Settings and profile.Settings.ShiftLock ~= nil then
			shiftLock = profile.Settings.ShiftLock
		end
	end)
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
