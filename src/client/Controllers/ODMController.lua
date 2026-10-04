--[[
	ODMController - Rampini a Gas
	Q / E: lancia il rampino sinistro / destro verso il mirino (tieni premuto per restare agganciato).
	Il verricello ti tira verso il punto d'aggancio; il cavo fa da pendolo per le oscillazioni.
	Spazio in volo: getto di gas. WASD: correggi la traiettoria. Ctrl: schivata.
	Il gas si consuma: ricaricalo ai Depositi di Rifornimento.
	I rampini si agganciano a edifici, alberi, mura, terreno... e ai giganti!

	La matematica del volo è in Shared.Modules.ODMPhysicsModule (la stessa che usa il server
	per convalidare): qui restano input, mira, sensori degli ostacoli, grafica e animazioni.
	Volare veloce rasente agli ostacoli accumula SLANCIO CINETICO (più velocità massima).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Lib.Net)
local Util = require(Shared.Lib.Util)
local ODMPhysics = require(Shared.Modules.ODMPhysicsModule)

local ODMController = {}
local C
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local ODM = Config.ODM

local gas = 100
local maxGas = 100
local flying = false
local boostHeld = false
local lastDodge = 0
local hooks: { [string]: any } = {}
local alignOri: AlignOrientation? = nil
local alignAtt: Attachment? = nil
local controls: any = nil
local boostEmitter: ParticleEmitter? = nil
local windSound: Sound? = nil
local lastGroundCheck = 0
local airTime = 0
local momentum = 0
local clearance: number? = nil
local lastProbe = 0
local hookSeq = 0
local remote: { [Player]: any } = {}
local effectsFolder: Instance

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function character(): Model?
	return player.Character
end

local function rootPart(): BasePart?
	return Util.GetRoot(player.Character)
end

local function humanoid(): Humanoid?
	return Util.GetHumanoid(player.Character)
end

local function refreshFilter()
	local list: { Instance } = {}
	for _, plr in Players:GetPlayers() do
		if plr.Character then
			table.insert(list, plr.Character)
		end
	end
	for _, name in { "EffettiLocali", Config.Folders.Effects, Config.Folders.NPCs, Config.Folders.Interactive } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	rayParams.FilterDescendantsInstances = list
end

function ODMController.IsFlying(): boolean
	return flying
end

function ODMController.Gas(): (number, number)
	return gas, maxGas
end

function ODMController.HookStates()
	return hooks
end

local function disabled(): boolean
	local hum = humanoid()
	if not hum or hum.Health <= 0 then
		return true
	end
	if player:GetAttribute("Transformed") or player:GetAttribute("Grabbed") then
		return true
	end
	return false
end

local function speedMult(): number
	local until_ = player:GetAttribute("AwakenedUntil")
	local awakened = type(until_) == "number" and workspace:GetServerTimeNow() < until_
	return ODMPhysics.SpeedMult(player:GetAttribute("ODMReel"), awakened)
end

local function gasEfficiency(): number
	return player:GetAttribute("GasEfficiency") or 1
end

function ODMController.Momentum(): number
	return momentum
end

-- SENSORI DEGLI OSTACOLI (slancio cinetico) ------------------------------------------------

local PROBE_INTERVAL = 0.08

-- Distanza dall'ostacolo più vicino ai lati, sopra e sotto la traiettoria
local function probeClearance(root: BasePart, velocity: Vector3): number?
	local forward = Util.SafeUnit(velocity)
	if forward.Magnitude < 0.5 then
		return nil
	end
	local side = forward:Cross(Vector3.yAxis)
	if side.Magnitude < 0.2 then
		side = forward:Cross(Vector3.xAxis)
	end
	side = side.Unit
	local up = side:Cross(forward).Unit
	local radius = ODM.ProximityRadius
	local best: number? = nil
	for _, dir in { side, -side, up, -up, (forward + side).Unit, (forward - side).Unit } do
		local result = workspace:Raycast(root.Position, dir * radius, rayParams)
		if result and (not best or result.Distance < best) then
			best = result.Distance
		end
	end
	return best
end

-- MIRA ---------------------------------------------------------------------------------

local function aimRay(side: string?): (Vector3, Vector3)
	local size = camera.ViewportSize
	local aim = if C.CameraController then C.CameraController.AimScreenPoint() else Vector2.new(size.X / 2, size.Y / 2)
	local x = aim.X
	if side == "Left" then
		x -= size.X * 0.012
	elseif side == "Right" then
		x += size.X * 0.012
	end
	local ray = camera:ViewportPointToRay(x, aim.Y)
	return ray.Origin, ray.Direction
end

-- Dove andrebbe il rampino (usato anche dal mirino dell'interfaccia)
function ODMController.Preview(side: string?): (Vector3?, boolean, Instance?)
	local root = rootPart()
	if not root then
		return nil, false, nil
	end
	refreshFilter()
	local range = player:GetAttribute("ODMRange") or 115
	local origin, dir = aimRay(side)
	local camDist = (origin - root.Position).Magnitude
	local result = workspace:Raycast(origin, dir * (range + camDist + 10), rayParams)
	if result then
		local inRange = (result.Position - root.Position).Magnitude <= range
		return result.Position, inRange, result.Instance
	end
	return nil, false, nil
end

-- GRAFICA DEI CAVI -----------------------------------------------------------------------

local function cableOrigin(model: Model, side: string): Attachment?
	local lower = model:FindFirstChild("LowerTorso") or model:FindFirstChild("HumanoidRootPart")
	if not lower then
		return nil
	end
	local name = if side == "Left" then "CavoSinistro" else "CavoDestro"
	local att = lower:FindFirstChild(name)
	if att and att:IsA("Attachment") then
		return att
	end
	local created = Instance.new("Attachment")
	created.Name = name
	created.Position = Vector3.new(if side == "Left" then -1 else 1, 0, -0.2)
	created.Parent = lower
	return created
end

local function createVisual(model: Model, side: string)
	local att0 = cableOrigin(model, side)
	if not att0 then
		return nil
	end
	local hook = Instance.new("Part")
	hook.Name = "Rampino"
	hook.Size = Vector3.new(0.35, 0.35, 0.9)
	hook.Color = Color3.fromRGB(60, 62, 68)
	hook.Material = Enum.Material.Metal
	hook.Anchored = true
	hook.CanCollide = false
	hook.CanQuery = false
	hook.CanTouch = false
	hook.CastShadow = false
	hook.CFrame = att0.WorldCFrame
	hook.Parent = effectsFolder
	local att1 = Instance.new("Attachment")
	att1.Parent = hook
	local beam = Instance.new("Beam")
	beam.Attachment0 = att0
	beam.Attachment1 = att1
	beam.Width0 = 0.09
	beam.Width1 = 0.09
	beam.Color = ColorSequence.new(Color3.fromRGB(175, 178, 184))
	beam.LightInfluence = 1
	beam.FaceCamera = true
	beam.Segments = 12
	beam.Transparency = NumberSequence.new(0)
	beam.Parent = hook
	return { Hook = hook, Beam = beam, Att0 = att0 }
end

local function destroyVisual(visual)
	if visual and visual.Hook then
		visual.Hook:Destroy()
	end
end

local function targetPosition(h): Vector3
	if h.Part and h.Part.Parent and h.Offset then
		return (h.Part :: BasePart).CFrame:PointToWorldSpace(h.Offset)
	end
	return h.Target
end

local function updateVisual(h, now: number)
	local visual = h.Visual
	if not visual then
		return
	end
	local from = visual.Att0.WorldPosition
	local to = targetPosition(h)
	local pos
	if h.Phase == "Flying" or h.Phase == "Miss" then
		local k = math.clamp((now - h.Start) / math.max(h.Duration, 0.01), 0, 1)
		pos = from:Lerp(to, k)
		visual.Beam.CurveSize0 = math.sin(k * math.pi) * 2.5
		visual.Beam.CurveSize1 = -math.sin(k * math.pi) * 1.5
	elseif h.Phase == "Retract" then
		local k = math.clamp((now - h.Start) / 0.18, 0, 1)
		pos = to:Lerp(from, k)
		visual.Beam.CurveSize0 = 3 * (1 - k)
		visual.Beam.CurveSize1 = 0
	else
		pos = to
		visual.Beam.CurveSize0 = 0
		visual.Beam.CurveSize1 = 0
	end
	local dir = pos - from
	if dir.Magnitude > 0.1 then
		visual.Hook.CFrame = CFrame.lookAt(pos, pos + dir)
	else
		visual.Hook.CFrame = CFrame.new(pos)
	end
end

-- VOLO -----------------------------------------------------------------------------------

local function startFlying()
	if flying then
		return
	end
	local root = rootPart()
	local hum = humanoid()
	if not root or not hum then
		return
	end
	flying = true
	airTime = 0
	hum.PlatformStand = true
	if not alignAtt or alignAtt.Parent ~= root then
		alignAtt = Instance.new("Attachment")
		alignAtt.Name = "AllineamentoDMT"
		alignAtt.Parent = root
		alignOri = Instance.new("AlignOrientation")
		alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
		alignOri.Attachment0 = alignAtt
		alignOri.MaxTorque = 1e7
		alignOri.Responsiveness = 22
		alignOri.Parent = root
	end
	if alignOri then
		alignOri.CFrame = CFrame.lookAt(Vector3.zero, Util.SafeUnit(Util.Flat(camera.CFrame.LookVector)))
		alignOri.Enabled = true
	end
	if C.AnimationController then
		C.AnimationController.SetFlightState(character(), true)
	end
end

local function stopFlying()
	if not flying then
		return
	end
	flying = false
	local hum = humanoid()
	if hum then
		hum.PlatformStand = false
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	if alignOri then
		alignOri.Enabled = false
	end
	if C.AnimationController then
		C.AnimationController.SetFlightState(character(), false)
	end
	if C.CameraController then
		C.CameraController.SetRoll(0)
	end
end

local function onGround(root: BasePart): boolean
	local hum = humanoid()
	local hip = if hum then hum.HipHeight else 2
	local result = workspace:Raycast(root.Position, Vector3.new(0, -(hip + root.Size.Y / 2 + 1.6), 0), rayParams)
	return result ~= nil
end

local function land(root: BasePart)
	local velocity = root.AssemblyLinearVelocity
	local speed = velocity.Magnitude
	stopFlying()
	if speed > ODM.LandingRollSpeed then
		if C.AnimationController then
			C.AnimationController.Play(character(), "LandRoll", 1)
		end
		if C.CameraController then
			C.CameraController.Shake(0.35, 0.35)
		end
		root.AssemblyLinearVelocity = Vector3.new(velocity.X * 0.55, math.max(0, velocity.Y), velocity.Z * 0.55)
	else
		root.AssemblyLinearVelocity = Vector3.new(velocity.X * 0.4, math.max(0, velocity.Y), velocity.Z * 0.4)
	end
	if C.SoundController then
		C.SoundController.Play("Land", root.Position, { Volume = math.clamp(speed / 80, 0.3, 1) })
	end
end

-- RAMPINI ----------------------------------------------------------------------------------

local function release(side: string, silent: boolean?)
	local h = hooks[side]
	if not h then
		return
	end
	hooks[side] = nil
	if h.Phase == "Attached" or h.Phase == "Flying" then
		Net.Event("ODM"):FireServer("Release", { Side = side })
	end
	-- animazione di riavvolgimento
	h.Phase = "Retract"
	h.Start = os.clock()
	local visual = h.Visual
	if visual and not silent then
		local conn
		conn = RunService.RenderStepped:Connect(function()
			if not visual.Hook.Parent then
				conn:Disconnect()
				return
			end
			updateVisual(h, os.clock())
			if os.clock() - h.Start > 0.18 then
				conn:Disconnect()
				destroyVisual(visual)
			end
		end)
	else
		destroyVisual(visual)
	end
end

function ODMController.ReleaseAll(silent: boolean?)
	for side in table.clone(hooks) do
		release(side, silent)
	end
end

local function fire(side: string)
	if disabled() then
		return
	end
	local root = rootPart()
	local model = character()
	if not root or not model then
		return
	end
	if gas <= 0 then
		if C.Notifications then
			C.Notifications.Toast("Gas esaurito! Cerca un Deposito di Rifornimento.", "Errore", 2)
		end
		return
	end
	release(side, true)
	local target, inRange, part = ODMController.Preview(side)
	local range = player:GetAttribute("ODMRange") or 115
	local h = {
		Side = side,
		Start = os.clock(),
		Held = true,
	}
	if target and inRange and part and part:IsA("BasePart") then
		h.Phase = "Flying"
		h.Target = target
		h.Part = part
		h.Offset = part.CFrame:PointToObjectSpace(target)
		h.Duration = (target - root.Position).Magnitude / ODM.HookSpeed
		gas = math.max(0, gas - ODMPhysics.HookCost(gasEfficiency()))
		hookSeq += 1
		h.Seq = hookSeq
		Net.Event("ODM"):FireServer("Fire", { Side = side, Part = part, Offset = h.Offset, Position = target, Seq = hookSeq })
	else
		local _, dir = aimRay(side)
		h.Phase = "Miss"
		h.Target = root.Position + dir * range
		h.Duration = range / ODM.HookSpeed
	end
	h.Visual = createVisual(model, side)
	hooks[side] = h
	if C.SoundController then
		C.SoundController.Play("HookFire", root.Position, { Range = 150 })
	end
end

local function attach(h, root: BasePart)
	h.Phase = "Attached"
	local target = targetPosition(h)
	h.RopeLength = (target - root.Position).Magnitude
	if C.SoundController then
		C.SoundController.Play("HookHit", target, { Range = 200 })
	end
	if C.EffectsController then
		C.EffectsController.Sparks(target, Color3.fromRGB(255, 230, 180), 10, 25)
	end
	startFlying()
end

-- SCHIVATA E GAS ---------------------------------------------------------------------------

local function dodge()
	if disabled() then
		return
	end
	local root = rootPart()
	if not root then
		return
	end
	local now = os.clock()
	if now - lastDodge < ODM.DodgeCooldown then
		return
	end
	local cost = ODMPhysics.DodgeCost(gasEfficiency())
	if gas < cost then
		return
	end
	lastDodge = now
	gas -= cost
	local move = if controls then controls:GetMoveVector() else Vector3.zero
	local dir
	if move.Magnitude > 0.1 then
		dir = Util.SafeUnit(Util.Flat(camera.CFrame:VectorToWorldSpace(move)))
	else
		dir = -Util.SafeUnit(Util.Flat(camera.CFrame.LookVector))
	end
	local lift = if flying then 10 else 18
	root.AssemblyLinearVelocity = root.AssemblyLinearVelocity * 0.4 + dir * ODM.DodgeSpeed * speedMult() ^ 0.5 + Vector3.new(0, lift, 0)
	Net.Event("Dodge"):FireServer()
	if C.AnimationController then
		C.AnimationController.Play(character(), "Dodge", 1)
	end
	if C.EffectsController then
		C.EffectsController.Steam(root.Position, 3, 8, 0.7)
	end
	if C.CameraController then
		C.CameraController.Punch(8)
	end
	if C.SoundController then
		C.SoundController.Play("Gas", root.Position, { Range = 150 })
	end
end

local function ensureBoostEmitter(): ParticleEmitter?
	local model = character()
	if not model then
		return nil
	end
	if boostEmitter and boostEmitter.Parent and boostEmitter:IsDescendantOf(model) then
		return boostEmitter
	end
	local lower = model:FindFirstChild("LowerTorso") or model:FindFirstChild("HumanoidRootPart")
	if not lower then
		return nil
	end
	local att = Instance.new("Attachment")
	att.Name = "GettoGas"
	att.Position = Vector3.new(0, 0, 0.9)
	att.Parent = lower
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(250, 250, 250))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 3.5) })
	e.Lifetime = NumberRange.new(0.4, 0.7)
	e.Speed = NumberRange.new(12, 20)
	e.SpreadAngle = Vector2.new(12, 12)
	e.EmissionDirection = Enum.NormalId.Back
	e.Rate = 70
	e.Drag = 3
	e.Enabled = false
	e.Parent = att
	boostEmitter = e
	return e
end

-- FISICA (ogni frame) -------------------------------------------------------------------------

local function physics(dt: number)
	local root = rootPart()
	local hum = humanoid()
	if not root or not hum then
		return
	end
	if disabled() then
		if next(hooks) then
			ODMController.ReleaseAll(true)
		end
		if flying then
			stopFlying()
		end
		return
	end
	local now = os.clock()
	local attached = {}
	for side, h in hooks do
		if h.Phase == "Flying" and now - h.Start >= h.Duration then
			if h.Part and not h.Part.Parent then
				release(side)
			else
				attach(h, root)
			end
		elseif h.Phase == "Miss" and now - h.Start >= h.Duration then
			release(side)
		elseif h.Phase == "Attached" then
			if h.Part and not h.Part.Parent then
				release(side)
			else
				table.insert(attached, h)
			end
		end
	end

	local used = 0
	if flying then
		airTime += dt
		local mult = speedMult()
		local ropes = table.create(#attached)
		for i, h in attached do
			ropes[i] = { Target = targetPosition(h), RopeLength = h.RopeLength, Held = h.Held }
		end
		if now - lastProbe >= PROBE_INTERVAL then
			lastProbe = now
			clearance = probeClearance(root, root.AssemblyLinearVelocity)
		end
		local move = if controls then controls:GetMoveVector() else Vector3.zero
		local step = ODMPhysics.Step({
			Position = root.Position,
			Velocity = root.AssemblyLinearVelocity,
			Hooks = ropes,
			Move = if move.Magnitude > 0.05 then camera.CFrame:VectorToWorldSpace(move) else Vector3.zero,
			Boost = boostHeld,
			BoostDirection = camera.CFrame.LookVector,
			Gas = gas,
			GasEfficiency = gasEfficiency(),
			SpeedMult = mult,
			Momentum = momentum,
			Clearance = clearance,
			Range = player:GetAttribute("ODMRange") or 115,
			Gravity = workspace.Gravity,
			dt = dt,
		})
		for i, h in attached do
			h.RopeLength = ropes[i].RopeLength
		end
		local velocity = step.Velocity
		local accel = step.Acceleration
		local hanging = step.Hanging
		momentum = step.Momentum
		used += step.GasUsed
		root.AssemblyLinearVelocity = velocity

		local emitter = ensureBoostEmitter()
		if emitter then
			if step.Boosting then
				emitter.Enabled = true
				emitter.Rate = 70
			else
				emitter.Enabled = #attached > 0 and gas > 0
				emitter.Rate = 30
			end
		end

		-- orientamento del corpo nella direzione del volo
		if alignOri then
			local flat = Util.Flat(velocity)
			local face = if flat.Magnitude > 8 then flat.Unit else Util.SafeUnit(Util.Flat(camera.CFrame.LookVector))
			alignOri.CFrame = CFrame.lookAt(Vector3.zero, face)
			local side = camera.CFrame.RightVector:Dot(accel.Unit)
			if C.CameraController and accel.Magnitude > 1 then
				C.CameraController.SetRoll(math.rad(math.clamp(-side * 7, -7, 7)) * math.clamp(velocity.Magnitude / 120, 0, 1))
			end
		end
		if C.AnimationController then
			local hangSide = if hooks.Right then 1 else -1
			C.AnimationController.SetFlightState(character(), true, hanging, hangSide, #attached > 0 or (boostHeld and gas > 0))
		end

		-- atterraggio
		if #attached == 0 and now - lastGroundCheck > 0.05 then
			lastGroundCheck = now
			local stillFlying = false
			for _, h in hooks do
				if h.Phase == "Flying" then
					stillFlying = true
				end
			end
			if not stillFlying and airTime > 0.25 and velocity.Y <= 6 and onGround(root) then
				land(root)
			end
		end
		if windSound then
			windSound.Volume = math.clamp((velocity.Magnitude - 30) / 140, 0, 0.6) * (if C.ClientData then C.ClientData.Setting("Sfx", 0.8) else 0.8)
			windSound.PlaybackSpeed = 0.8 + math.clamp(velocity.Magnitude / 200, 0, 0.8)
		end
	else
		if boostEmitter then
			boostEmitter.Enabled = false
		end
		if windSound then
			windSound.Volume = 0
		end
		momentum = math.max(0, momentum - ODM.MomentumDecay * 3 * dt)
		-- a terra il gas si ricarica lentamente
		if hum.FloorMaterial ~= Enum.Material.Air then
			gas = math.min(maxGas, gas + ODM.GasRegenGround * dt)
		end
		-- getto di gas in aria per iniziare a volare
		if boostHeld and gas > 0 and hum.FloorMaterial == Enum.Material.Air and hum:GetState() == Enum.HumanoidStateType.Freefall then
			startFlying()
		end
	end
	gas = math.clamp(gas - used, 0, maxGas)
end

local function renderVisuals()
	local now = os.clock()
	for _, h in hooks do
		updateVisual(h, now)
	end
	for _, info in remote do
		for _, h in info.Hooks do
			updateVisual(h, now)
		end
	end
end

-- CAVI DEGLI ALTRI GIOCATORI -------------------------------------------------------------------

local function remoteInfo(sender: Player)
	local info = remote[sender]
	if not info then
		info = { Hooks = {}, LastRelease = 0 }
		remote[sender] = info
	end
	return info
end

local function onRemoteODM(sender: Player, action: string, data)
	if typeof(sender) ~= "Instance" or sender == player then
		return
	end
	local model = sender.Character
	if not model or type(data) ~= "table" then
		return
	end
	local info = remoteInfo(sender)
	local side = data.Side or "Right"
	local existing = info.Hooks[side]
	if existing then
		destroyVisual(existing.Visual)
		info.Hooks[side] = nil
	end
	if action == "Fire" and data.Position then
		local h = {
			Side = side,
			Phase = "Flying",
			Start = os.clock(),
			Duration = 0.12,
			Target = data.Position,
			Part = data.Part,
			Offset = data.Offset,
		}
		h.Visual = createVisual(model, side)
		info.Hooks[side] = h
		task.delay(0.12, function()
			if info.Hooks[side] == h then
				h.Phase = "Attached"
			end
		end)
		if C.AnimationController then
			C.AnimationController.SetFlightState(model, true)
		end
	elseif action == "Release" then
		info.LastRelease = os.clock()
	end
end

local function updateRemoteFlight()
	local now = os.clock()
	for sender, info in remote do
		local model = sender.Character
		if not sender.Parent or not model then
			for _, h in info.Hooks do
				destroyVisual(h.Visual)
			end
			remote[sender] = nil
		else
			local root = Util.GetRoot(model)
			local speed = if root then root.AssemblyLinearVelocity.Magnitude else 0
			local attached = next(info.Hooks) ~= nil
			local isFlying = attached or (now - info.LastRelease < 1.2 and speed > 25)
			if C.AnimationController then
				C.AnimationController.SetFlightState(model, isFlying, nil, nil, attached)
			end
		end
	end
end

function ODMController.Refill()
	gas = maxGas
end

function ODMController.Init(c)
	C = c
end

function ODMController.Start()
	effectsFolder = workspace:FindFirstChild("EffettiLocali") or workspace
	task.spawn(function()
		local ok, module = pcall(function()
			return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript)
		end)
		if ok and module then
			controls = module:GetControls()
		else
			warn("[DMT] Impossibile leggere i controlli di movimento: " .. tostring(module))
		end
	end)

	local function updateMax()
		maxGas = player:GetAttribute("MaxGas") or 100
		gas = math.min(gas, maxGas)
	end
	player:GetAttributeChangedSignal("MaxGas"):Connect(function()
		local old = maxGas
		updateMax()
		if maxGas > old then
			gas = maxGas
		end
	end)
	updateMax()
	gas = maxGas

	C.InputController.On("HookLeft", function(began)
		if began then
			fire("Left")
		else
			release("Left")
		end
	end)
	C.InputController.On("HookRight", function(began)
		if began then
			fire("Right")
		else
			release("Right")
		end
	end)
	C.InputController.On("Boost", function(began)
		boostHeld = began
		-- il server tiene il conto del gas (anti-trucchi): gli serve sapere quando si spinge
		Net.Event("ODM"):FireServer("Boost", { On = began })
		if began and flying and gas > 0 and C.SoundController then
			local root = rootPart()
			if root then
				C.SoundController.Play("Gas", root.Position, { Range = 150 })
			end
		end
	end)
	C.InputController.On("Dodge", function(began)
		if began then
			dodge()
		end
	end)

	Net.Event("Refilled").OnClientEvent:Connect(function(_what)
		gas = maxGas
	end)
	Net.Event("ODM").OnClientEvent:Connect(onRemoteODM)

	-- Correzioni del server: il gas non può superare il suo conteggio, e un aggancio
	-- impossibile (fuori portata, senza gas) viene sganciato.
	Net.Event("ODMCorrect").OnClientEvent:Connect(function(kind, data)
		if kind == "Reject" and type(data) == "table" and (data.Side == "Left" or data.Side == "Right") then
			-- solo se è ancora lo stesso cavo (nel frattempo potrebbe esserne partito un altro)
			local h = hooks[data.Side]
			if h and h.Seq == data.Seq then
				release(data.Side)
			end
		end
	end)
	local function applyGasCap()
		local cap = player:GetAttribute("GasCap")
		if type(cap) == "number" then
			gas = math.min(gas, cap + ODM.Validation.GasSlack)
		end
	end
	player:GetAttributeChangedSignal("GasCap"):Connect(applyGasCap)

	player.CharacterAdded:Connect(function()
		ODMController.ReleaseAll(true)
		flying = false
		alignAtt = nil
		alignOri = nil
		boostEmitter = nil
		gas = maxGas
		momentum = 0
	end)

	if C.SoundController then
		windSound = C.SoundController.Loop("Gas")
	end

	RunService.PreSimulation:Connect(function(dt)
		local ok, err = pcall(physics, dt)
		if not ok then
			warn("[DMT] " .. tostring(err))
		end
	end)
	RunService.RenderStepped:Connect(function()
		renderVisuals()
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			updateRemoteFlight()
		end
	end)
end

return ODMController
