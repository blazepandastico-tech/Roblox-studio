--[[
	AnimationController
	Anima con il codice tutti i personaggi umani visibili:
	  - giocatori: posa con le lame, volo coi Rampini, mantello al vento, combo e abilità
	  - PNG: respiro e sguardo che segue il giocatore
	  - nemici umani: camminata e mira quando sparano
	Le animazioni del giocatore locale vengono inviate al server per mostrarle agli altri.
	Se in Shared/Data/AnimationIds c'è un ID caricato, viene usato quello.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Lib.Net)
local Util = require(Shared.Lib.Util)
local Poses = require(Shared.Anim.Poses)
local ProceduralAnimator = require(Shared.Anim.ProceduralAnimator)
local AnimationIds = require(Shared.Data.AnimationIds)

local AnimationController = {}
local C
local player = Players.LocalPlayer
local walkMode = false -- Bloc Maiusc: cammina invece di correre
local savedWalkSpeed: number? = nil
local rigs: { [Model]: any } = {}
local loadedTracks: { [Model]: { [string]: AnimationTrack } } = {}

local TRAIL_CLIPS = {
	Slash1 = 0.32,
	Slash2 = 0.32,
	Slash3 = 0.36,
	Slash4 = 0.4,
	SpinSlash = 0.6,
	Lunge = 0.45,
	Tornado = 1.4,
	BladeDance = 1.4,
}

local function hasBlades(model: Model): boolean
	local outfit = model:FindFirstChild("Equipaggiamento")
	return outfit ~= nil and outfit:FindFirstChild("Impugnatura") ~= nil
end

local function setTrails(model: Model, on: boolean)
	local outfit = model:FindFirstChild("Equipaggiamento")
	if not outfit then
		return
	end
	for _, d in outfit:GetDescendants() do
		if d:IsA("Trail") then
			d.Enabled = on
		end
	end
end

local function rootOf(model: Model): BasePart?
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Camminata procedurale per i PNG senza script Animate (nemici umani)
local function walkLayer(t: number, ctx)
	local speed = ctx.Speed or 0
	local move = math.clamp(speed / 16, 0, 1.4)
	if move < 0.05 then
		return {}
	end
	ctx.Phase = (ctx.Phase or 0)
	local p = ctx.Phase
	local s = math.sin(p)
	return {
		RightHip = Poses.A(s * 35 * move, 0, 0),
		LeftHip = Poses.A(-s * 35 * move, 0, 0),
		RightKnee = Poses.A(-math.max(0, math.sin(p + 1.4)) * 50 * move, 0, 0),
		LeftKnee = Poses.A(-math.max(0, math.sin(p + 1.4 + math.pi)) * 50 * move, 0, 0),
		RightShoulder = Poses.A(-s * 30 * move, 0, 4),
		LeftShoulder = Poses.A(s * 30 * move, 0, -4),
		Root = CFrame.new(0, -math.abs(s) * 0.15 * move, 0),
	}
end

local function register(model: Model, kind: string)
	if rigs[model] then
		return rigs[model]
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	local animator = ProceduralAnimator.new(model, false)
	local rig = {
		Model = model,
		Kind = kind,
		Animator = animator,
		Humanoid = humanoid,
		Seed = math.random() * 100,
		LastShot = 0,
	}
	animator.Context.Seed = rig.Seed
	rigs[model] = rig
	if kind == "Player" then
		-- camminata e corsa da battaglia al posto di quelle standard di Roblox
		animator:SetLayer("Loco", Poses.Human.BattleLoco, 1, 0, 8)
		animator.Context.Phase = 0
		animator.Context.Air = 0
		animator:SetLayer("Fly", Poses.Human.ODMFly, 0, 2, 5)
		animator:SetLayer("Hang", Poses.Human.Hang, 0, 3, 6)
		animator:SetLayer("Struggle", Poses.Human.Struggle, 0, 4, 8)
		animator:SetLayer("Cloak", Poses.Human.Cloak, 1, 5, 6)
	elseif kind == "NPC" then
		animator:SetLayer("Idle", Poses.Human.Idle, 1, 1, 4)
		animator:SetLayer("Cloak", Poses.Human.Cloak, 1, 5, 6)
	elseif kind == "Enemy" then
		animator:SetLayer("Walk", walkLayer, 1, 1, 8)
		animator:SetLayer("Stance", Poses.Human.BladeStance, 0, 2, 6)
		animator:SetLayer("Cloak", Poses.Human.Cloak, 1, 5, 6)
	end
	model.DescendantAdded:Connect(function(d)
		if d:IsA("Motor6D") then
			animator:Refresh()
		end
	end)
	model.DescendantRemoving:Connect(function(d)
		if d:IsA("Motor6D") then
			task.defer(function()
				animator:Refresh()
			end)
		end
	end)
	model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			animator:Destroy()
			rigs[model] = nil
			loadedTracks[model] = nil
		end
	end)
	return rig
end

function AnimationController.GetRig(model: Model?)
	return model and rigs[model]
end

local function playUploaded(model: Model, clipName: string, speed: number): boolean
	local id = AnimationIds[clipName]
	if not id or id == "" then
		return false
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animatorObj = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animatorObj then
		return false
	end
	local tracks = loadedTracks[model] or {}
	loadedTracks[model] = tracks
	local track = tracks[clipName]
	if not track then
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, result = pcall(function()
			return (animatorObj :: Animator):LoadAnimation(animation)
		end)
		if not ok then
			return false
		end
		track = result
		tracks[clipName] = track
	end
	track:Play(0.05, 1, speed)
	return true
end

-- Riproduce una clip su un personaggio (e la invia agli altri se è il nostro)
function AnimationController.Play(model: Model?, clipName: string, speed: number?, noRelay: boolean?)
	if not model then
		return
	end
	local rig = rigs[model] or register(model, if model == player.Character then "Player" else "NPC")
	if not rig then
		return
	end
	local s = speed or 1
	if not playUploaded(model, clipName, s) then
		local clip = Poses.Human.Clips[clipName]
		if clip then
			rig.Animator:Play(clip, { Speed = s })
		end
	end
	local trailTime = TRAIL_CLIPS[clipName]
	if trailTime then
		setTrails(model, true)
		rig.TrailToken = (rig.TrailToken or 0) + 1
		local token = rig.TrailToken
		task.delay(trailTime / s + 0.05, function()
			if rig.TrailToken == token then
				setTrails(model, false)
			end
		end)
	end
	if model == player.Character and not noRelay then
		Net.Unreliable("AnimRelay"):FireServer(clipName, s)
	end
end

function AnimationController.Freeze(model: Model?, duration: number)
	local rig = model and rigs[model]
	if rig then
		rig.Animator:Freeze(duration)
	end
end

-- Stato dei Rampini di un personaggio (dal controller dei Rampini o dagli altri giocatori)
function AnimationController.SetFlightState(model: Model?, flying: boolean, hanging: boolean?, side: number?)
	local rig = model and rigs[model]
	if not rig then
		return
	end
	rig.Flying = flying
	rig.Hanging = hanging == true
	rig.Animator.Context.HangSide = side or 1
end

local function updateRig(rig, dt: number, localRoot: BasePart?)
	local model = rig.Model
	local root = rootOf(model)
	if not root then
		return
	end
	local ctx = rig.Animator.Context
	local velocity = root.AssemblyLinearVelocity
	local speed = velocity.Magnitude
	ctx.Speed = speed
	local flat = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	ctx.Moving = math.clamp(flat / 20, 0, 1)
	if rig.Kind == "Player" then
		local transformed = false
		local owner = Players:GetPlayerFromCharacter(model)
		if owner then
			transformed = owner:GetAttribute("Transformed") == true
			if owner:GetAttribute("Grabbed") == true then
				rig.Animator:SetLayerWeight("Struggle", 1)
			else
				rig.Animator:SetLayerWeight("Struggle", 0)
			end
		end
		local flying = rig.Flying == true and not transformed
		if flying and speed > 1 then
			local dir = velocity.Unit
			local relative = root.CFrame:VectorToObjectSpace(dir)
			-- angolo dal verticale: 0 = verso l'alto, 90 = orizzontale
			local pitch = math.deg(math.acos(math.clamp(dir.Y, -1, 1)))
			-- mai a testa in giù: in picchiata il corpo si inclina al massimo di poco oltre l'orizzontale
			ctx.Pitch = math.clamp(pitch, 10, 100)
			ctx.Roll = math.clamp(-relative.X * 40, -40, 40)
		end
		rig.Animator:SetLayerWeight("Fly", if flying and not rig.Hanging then 1 else 0)
		rig.Animator:SetLayerWeight("Hang", if flying and rig.Hanging then 1 else 0)
		-- locomozione da battaglia: passo che avanza con la velocità, salto e caduta
		local humanoid = rig.Humanoid
		if model == player.Character and walkMode and humanoid.WalkSpeed > 9 then
			-- il server ha aggiornato la velocità: restiamo in camminata
			savedWalkSpeed = humanoid.WalkSpeed
			humanoid.WalkSpeed = 9
		end
		local hstate = humanoid:GetState()
		local airborne = hstate == Enum.HumanoidStateType.Freefall or hstate == Enum.HumanoidStateType.Jumping
		local k = math.min(1, dt * 10)
		ctx.Air = (ctx.Air or 0) + ((if airborne then 1 else 0) - (ctx.Air or 0)) * k
		if not airborne then
			ctx.Flat = (ctx.Flat or 0) + (flat - (ctx.Flat or 0)) * k
		end
		ctx.Blades = hasBlades(model)
		-- direzione del movimento rispetto al corpo (avanti / indietro / di lato)
		local rel = root.CFrame:VectorToObjectSpace(Vector3.new(velocity.X, 0, velocity.Z))
		local fwd, side = 1, 0
		if flat > 1.5 then
			fwd = -rel.Z / flat
			side = rel.X / flat
		end
		local kd = math.min(1, dt * 8)
		ctx.Forward = (ctx.Forward or 1) + (fwd - (ctx.Forward or 1)) * kd
		ctx.Side = (ctx.Side or 0) + (side - (ctx.Side or 0)) * kd
		-- velocità di rotazione (per inclinarsi nelle curve)
		local look = root.CFrame.LookVector
		local yaw = math.atan2(-look.X, -look.Z)
		local dyaw = (yaw - (rig.LastYaw or yaw) + math.pi) % (2 * math.pi) - math.pi
		rig.LastYaw = yaw
		local turnRate = math.deg(dyaw) / math.max(dt, 1 / 240)
		ctx.Turn = (ctx.Turn or 0) + (turnRate - (ctx.Turn or 0)) * math.min(1, dt * 6)
		-- atterraggio: più forte è la caduta, più ci si piega
		if rig.WasAir and not airborne and (rig.FallSpeed or 0) > 28 then
			ctx.Land = math.clamp((rig.FallSpeed or 0) / 90, 0.3, 1)
			if model == player.Character and C and C.CameraController then
				C.CameraController.Land(ctx.Land)
			end
		end
		ctx.Land = math.max(0, (ctx.Land or 0) - dt * 2.8)
		rig.WasAir = airborne
		if airborne then
			rig.FallSpeed = math.max(0, -velocity.Y)
		end
		-- il passo avanza con la velocità (all'indietro il ciclo gira al contrario)
		local runK = math.clamp((flat - 13) / 6, 0, 1)
		local dir = if (ctx.Forward or 1) < -0.3 then -1 else 1
		ctx.Phase = (ctx.Phase or 0) + dt * flat * (0.95 - 0.3 * runK) * dir
		rig.Animator:SetLayerWeight("Loco", if flying or transformed or humanoid.Sit then 0 else 1)
	elseif rig.Kind == "NPC" then
		if localRoot then
			local offset = root.CFrame:PointToObjectSpace(localRoot.Position)
			local dist = offset.Magnitude
			if dist < 22 then
				local yaw = math.deg(math.atan2(-offset.X, -offset.Z))
				ctx.LookYaw = math.clamp(yaw, -60, 60)
			else
				ctx.LookYaw = nil
			end
		end
	elseif rig.Kind == "Enemy" then
		ctx.Phase = (ctx.Phase or 0) + dt * math.clamp(flat, 0, 30) * 0.45
		local shot = model:GetAttribute("ShotT")
		if shot and shot ~= rig.LastShot then
			rig.LastShot = shot
			local clip = Poses.Human.Clips.FireGun
			rig.Animator:Play(clip, { Speed = 1 })
		end
		rig.Animator:SetLayerWeight("Stance", if hasBlades(model) then 1 else 0)
	end
	rig.Animator:Update(dt)
end

local function onTagged(tag: string, kind: string)
	for _, model in CollectionService:GetTagged(tag) do
		if model:IsA("Model") then
			register(model, kind)
		end
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(model)
		if model:IsA("Model") then
			task.defer(register, model, kind)
		end
	end)
end

-- Spegne lo script Animate di Roblox: camminata e corsa le facciamo noi
local function disableDefaultAnimate(character: Model)
	local animate = character:WaitForChild("Animate", 5)
	if animate and animate:IsA("BaseScript") then
		animate.Enabled = false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animatorObj = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animatorObj then
		for _, track in animatorObj:GetPlayingAnimationTracks() do
			track:Stop(0.1)
		end
	end
end

local function hookCharacter(plr: Player)
	local function onCharacter(character: Model)
		character:WaitForChild("HumanoidRootPart", 10)
		character:WaitForChild("Humanoid", 10)
		if plr == player then
			disableDefaultAnimate(character)
			walkMode = false
			savedWalkSpeed = nil
		end
		task.wait(0.2)
		local rig = register(character, "Player")
		if plr == player then
			print(if rig then "[Animazioni] Camminata e corsa da battaglia attive" else "[Animazioni] ATTENZIONE: personaggio senza Humanoid, animazioni non attive")
		end
	end
	if plr.Character then
		task.spawn(onCharacter, plr.Character)
	end
	plr.CharacterAdded:Connect(onCharacter)
end

function AnimationController.Init(c)
	C = c
end

-- Bloc Maiusc: alterna camminata tattica e corsa d'assalto
local function toggleWalk()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	walkMode = not walkMode
	if walkMode then
		savedWalkSpeed = humanoid.WalkSpeed
		humanoid.WalkSpeed = math.min(humanoid.WalkSpeed, 9)
	elseif savedWalkSpeed then
		humanoid.WalkSpeed = savedWalkSpeed
		savedWalkSpeed = nil
	end
	if C and C.Notifications then
		C.Notifications.Toast(if walkMode then "🚶 Camminata (Bloc Maiusc per correre)" else "🏃 Corsa", "Info", 1.5)
	end
end

function AnimationController.Start()
	for _, plr in Players:GetPlayers() do
		hookCharacter(plr)
	end
	Players.PlayerAdded:Connect(hookCharacter)
	if C and C.InputController then
		C.InputController.On("WalkToggle", function(began)
			if began then
				toggleWalk()
			end
		end)
	end
	onTagged(Config.Tags.NPC, "NPC")
	onTagged(Config.Tags.Enemy, "Enemy")

	-- animazioni degli altri giocatori
	Net.Unreliable("AnimRelay").OnClientEvent:Connect(function(sender: Player, clipName: string, speed: number)
		if typeof(sender) == "Instance" and sender.Character then
			AnimationController.Play(sender.Character, clipName, speed, true)
		end
	end)

	local frame = 0
	RunService.PreSimulation:Connect(function(dt)
		frame += 1
		local localRoot = Util.GetRoot(player.Character)
		local camPos = workspace.CurrentCamera.CFrame.Position
		for model, rig in rigs do
			if model.Parent then
				local root = rootOf(model)
				if root then
					local dist = (root.Position - camPos).Magnitude
					-- meno aggiornamenti per chi è lontano
					local every = if dist < 150 then 1 elseif dist < 350 then 2 else 4
					if dist < 600 then
						if frame % every == 0 or model == player.Character then
							local ok, err = pcall(updateRig, rig, dt * every, localRoot)
							if not ok then
								warn("[Animazioni] " .. tostring(err))
								rigs[model] = nil
							end
						else
							-- tra un calcolo e l'altro riapplichiamo l'ultima posa
							rig.Animator:Apply()
						end
					end
				end
			end
		end
	end)
end

return AnimationController
