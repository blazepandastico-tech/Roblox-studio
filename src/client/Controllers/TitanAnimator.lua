--[[
	TitanAnimator
	Dà vita ai giganti sul client:
	  - camminata pesante (o corsa scomposta degli anomali), passi che fanno tremare la terra
	  - testa che segue il giocatore (lo sguardo inquietante dei giganti)
	  - attacchi sincronizzati con il server (presa, manata, pestone, morso, lancio di massi...)
	  - arti recisi che cadono fumando e poi si rigenerano
	  - morte: il gigante crolla e si dissolve nel vapore
	  - targhetta con nome, livello e vita
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Lib.Util)
local Poses = require(Shared.Anim.Poses)
local ProceduralAnimator = require(Shared.Anim.ProceduralAnimator)

local TitanAnimator = {}
local C
local player = Players.LocalPlayer
local titans: { [Model]: any } = {}

local LIMBS = { "RightArm", "LeftArm", "RightLeg", "LeftLeg" }

local function lookLayer(_t, ctx)
	return {
		Neck = Poses.A(ctx.LookPitch or 0, ctx.LookYaw or 0, 0),
	}
end

local function makeNameplate(model: Model, state)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	local isBoss = model:GetAttribute("Boss") == true
	local gui = Instance.new("BillboardGui")
	gui.Name = "BarraGigante"
	gui.Size = UDim2.fromOffset(if isBoss then 320 else 230, if isBoss then 62 else 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, (model:GetAttribute("Height") or 20) * 0.16 + 2, 0)
	gui.MaxDistance = if isBoss then 900 else 280
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0.5, 0)
	name.Font = if isBoss then Enum.Font.GrenzeGotisch else Enum.Font.Merriweather
	name.TextScaled = true
	name.TextColor3 = if isBoss then Color3.fromRGB(255, 140, 110) elseif model:GetAttribute("Abnormal") then Color3.fromRGB(255, 200, 120) elseif model:GetAttribute("Ally") then Color3.fromRGB(140, 255, 170) else Color3.fromRGB(245, 235, 215)
	name.TextStrokeTransparency = 0.35
	name.Text = ("%s  [Lv. %s]"):format(model:GetAttribute("Name") or "Gigante", tostring(model:GetAttribute("Level") or 1))
	name.Parent = gui
	local barBack = Instance.new("Frame")
	barBack.BackgroundColor3 = Color3.fromRGB(20, 14, 12)
	barBack.BackgroundTransparency = 0.25
	barBack.BorderSizePixel = 0
	barBack.Position = UDim2.fromScale(0.08, 0.58)
	barBack.Size = UDim2.fromScale(0.84, 0.22)
	barBack.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = barBack
	local ghost = Instance.new("Frame")
	ghost.BackgroundColor3 = Color3.fromRGB(255, 230, 200)
	ghost.BorderSizePixel = 0
	ghost.Size = UDim2.fromScale(1, 1)
	ghost.Parent = barBack
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = if model:GetAttribute("Ally") then Color3.fromRGB(90, 200, 110) else Color3.fromRGB(200, 50, 44)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = barBack
	for _, f in { ghost, fill } do
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 4)
		c.Parent = f
	end
	if isBoss then
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromScale(0, 0.8)
		title.Size = UDim2.new(1, 0, 0.2, 0)
		title.Font = Enum.Font.GothamMedium
		title.TextScaled = true
		title.TextColor3 = Color3.fromRGB(230, 200, 150)
		title.Text = model:GetAttribute("BossTitle") or ""
		title.Parent = gui
	end
	gui.Parent = head
	state.Nameplate = gui
	state.SetHP = function(fraction: number)
		fraction = math.clamp(fraction, 0, 1)
		TweenService:Create(fill, TweenInfo.new(0.12), { Size = UDim2.fromScale(fraction, 1) }):Play()
		TweenService:Create(ghost, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.2), { Size = UDim2.fromScale(fraction, 1) }):Play()
	end
end

local function limbParts(model: Model, limb: string): { BasePart }
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Limb") == limb then
			table.insert(list, d)
		end
	end
	return list
end

-- Crea una copia dell'arto che cade a terra fumando
local function dropLimb(model: Model, limb: string)
	local parts = limbParts(model, limb)
	if #parts == 0 then
		return
	end
	local holder = Instance.new("Model")
	holder.Name = "ArtoReciso"
	local center = Vector3.zero
	for _, p in parts do
		center += p.Position
	end
	center /= #parts
	for _, p in parts do
		local copy = Instance.new("Part")
		copy.Size = p.Size
		copy.CFrame = p.CFrame
		copy.Color = p.Color
		copy.Material = p.Material
		copy.Transparency = p.Transparency
		copy.CanCollide = true
		copy.CanQuery = false
		copy.CanTouch = false
		copy.CastShadow = false
		copy.CollisionGroup = Config.CollisionGroups.Debris
		local mesh = p:FindFirstChildOfClass("SpecialMesh")
		if mesh then
			mesh:Clone().Parent = copy
		end
		copy.Parent = holder
	end
	local first = holder:FindFirstChildWhichIsA("BasePart")
	if first then
		for _, other in holder:GetChildren() do
			if other ~= first and other:IsA("BasePart") then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = first
				weld.Part1 = other
				weld.Parent = other
			end
		end
	end
	holder.Parent = workspace:FindFirstChild("EffettiLocali") or workspace
	if first then
		first.AssemblyLinearVelocity = Vector3.new(math.random(-20, 20), 10, math.random(-20, 20))
		first.AssemblyAngularVelocity = Vector3.new(math.random(-3, 3), math.random(-3, 3), math.random(-3, 3))
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(240, 236, 230))
		emitter.Transparency = NumberSequence.new(0.5, 1)
		emitter.Size = NumberSequence.new(first.Size.Magnitude * 0.2, first.Size.Magnitude * 0.6)
		emitter.Lifetime = NumberRange.new(1.5, 2.5)
		emitter.Rate = 14
		emitter.Speed = NumberRange.new(2, 6)
		emitter.Parent = first
	end
	task.delay(3.5, function()
		for _, p in holder:GetChildren() do
			if p:IsA("BasePart") then
				TweenService:Create(p, TweenInfo.new(1.5), { Transparency = 1 }):Play()
			end
		end
	end)
	Debris:AddItem(holder, 5.2)
	if C.EffectsController then
		C.EffectsController.Steam(center, (model:GetAttribute("Height") or 20) * 0.15, 12, 2.5, Color3.fromRGB(230, 150, 140))
	end
end

local function setLimbVisible(model: Model, limb: string, visible: boolean)
	for _, p in limbParts(model, limb) do
		p.LocalTransparencyModifier = if visible then 0 else 1
	end
end

local function fadeOut(model: Model)
	task.delay(3, function()
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				TweenService:Create(d, TweenInfo.new(2.5), { LocalTransparencyModifier = 1, Color = Color3.fromRGB(60, 50, 46) }):Play()
			end
		end
	end)
end

local function playAction(state, name: string, t0: number?)
	local animator = state.Animator
	-- ferma l'attacco precedente
	if state.ActionClip then
		animator:Stop(state.ActionClip, 0.25)
		state.ActionClip = nil
	end
	if name == "" then
		return
	end
	local clipName = if name == "Hold" then "Hold" else Poses.TitanAttackClip[name]
	local clip = clipName and Poses.Titan.Clips[clipName]
	if not clip then
		return
	end
	local offset = 0
	if t0 then
		offset = math.clamp(workspace:GetServerTimeNow() - t0, 0, clip.Duration)
	end
	animator:Play(clip, { Time = offset })
	state.ActionClip = clip.Name
	if name == "Roar" or name == "Scream" or name == "Dominio" then
		if C.SoundController and state.Model.PrimaryPart then
			C.SoundController.Play("Roar", state.Model.PrimaryPart.Position, { Range = 1200 })
		end
	end
end

local function register(model: Model)
	if titans[model] then
		return
	end
	local root = model.PrimaryPart or model:WaitForChild("Root", 10)
	if not root or not model.Parent then
		return
	end
	local height = model:GetAttribute("Height") or 20
	local animator = ProceduralAnimator.new(model, true)
	animator.PositionScale = height
	local ctx = animator.Context
	ctx.Seed = model:GetAttribute("Seed") or 0
	ctx.HeadTilt = model:GetAttribute("HeadTilt") or 0
	ctx.JawIdle = model:GetAttribute("JawIdle") or 0
	ctx.Hunch = model:GetAttribute("Hunch") == true
	ctx.Phase = math.random() * 6
	local look = model:GetAttribute("Look")
	if model:GetAttribute("Dummy") then
		animator:SetLayer("Base", Poses.Titan.Dummy, 1, 0, 10)
	elseif model:GetAttribute("Crawl") then
		animator:SetLayer("Base", Poses.Titan.Crawl, 1, 0, 10)
	else
		animator:SetLayer("Base", Poses.Titan.Locomotion, 1, 0, 10)
		animator:SetLayer("Look", lookLayer, 1, 1, 3)
	end
	local state = {
		Model = model,
		Root = root,
		Animator = animator,
		Height = height,
		Look = look,
		Dead = false,
		Severed = {},
		LastStep = 0,
		Wobble = 0,
	}
	titans[model] = state
	makeNameplate(model, state)

	local function onHP()
		local maxHP = model:GetAttribute("MaxHP") or 1
		local hp = model:GetAttribute("HP") or maxHP
		if state.SetHP then
			state.SetHP(hp / math.max(1, maxHP))
		end
	end
	model:GetAttributeChangedSignal("HP"):Connect(onHP)
	onHP()

	local function onAction()
		playAction(state, model:GetAttribute("Action") or "", model:GetAttribute("ActionT"))
	end
	model:GetAttributeChangedSignal("Action"):Connect(onAction)
	model:GetAttributeChangedSignal("ActionT"):Connect(onAction)
	if (model:GetAttribute("Action") or "") ~= "" then
		onAction()
	end

	local function onState()
		if model:GetAttribute("State") == "Dead" and not state.Dead then
			state.Dead = true
			animator:StopAll(0.1)
			animator:SetLayerWeight("Look", 0, 10)
			animator:Play(Poses.Titan.Clips.Death)
			if state.Nameplate then
				state.Nameplate.Enabled = false
			end
			fadeOut(model)
			if C.SoundController then
				C.SoundController.Play("Land", root.Position, { Range = 900, Volume = 1, Pitch = 0.3 })
			end
			task.delay(1.4, function()
				if C.EffectsController and model.Parent then
					C.EffectsController.ShakeAt(root.Position, 0.5 + height / 200, height * 8, 0.6)
					C.EffectsController.Steam(root.Position - Vector3.new(0, height * 0.4, 0), height * 0.4, 14, 3, Color3.fromRGB(180, 160, 130))
				end
			end)
		end
	end
	model:GetAttributeChangedSignal("State"):Connect(onState)
	onState()

	for _, limb in LIMBS do
		local attr = "Severed_" .. limb
		local function onSever()
			local severed = model:GetAttribute(attr) == true
			if severed and not state.Severed[limb] then
				state.Severed[limb] = true
				dropLimb(model, limb)
				setLimbVisible(model, limb, false)
			elseif not severed and state.Severed[limb] then
				state.Severed[limb] = false
				setLimbVisible(model, limb, true)
				if C.EffectsController then
					C.EffectsController.Steam(root.Position, height * 0.25, 10, 2)
				end
			end
		end
		model:GetAttributeChangedSignal(attr):Connect(onSever)
		onSever()
	end

	local function onBlind()
		if model:GetAttribute("Blinded") then
			animator:Play(Poses.Titan.Clips.Blinded)
		else
			animator:Stop("Blinded", 0.4)
		end
	end
	model:GetAttributeChangedSignal("Blinded"):Connect(onBlind)

	local function onFallen()
		if model:GetAttribute("Fallen") then
			animator:Play(Poses.Titan.Clips.Fallen)
		else
			animator:Stop("Fallen", 0.6)
		end
	end
	model:GetAttributeChangedSignal("Fallen"):Connect(onFallen)
	onFallen()

	model:GetAttributeChangedSignal("HitT"):Connect(function()
		state.Wobble = 1
	end)

	model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			animator:Destroy()
			titans[model] = nil
		end
	end)
end

local function updateTitan(state, dt: number, localRoot: BasePart?)
	local model = state.Model
	local root = state.Root
	if not root.Parent then
		return
	end
	local animator = state.Animator
	local ctx = animator.Context
	local H = state.Height
	if not state.Dead then
		local velocity = root.AssemblyLinearVelocity
		local flat = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local moveAttr = model:GetAttribute("Move") or 0
		local moving = math.clamp(math.max(moveAttr, flat / math.max(4, H * 0.4)), 0, 1)
		ctx.Move = (ctx.Move or 0) + (moving - (ctx.Move or 0)) * math.min(1, dt * 5)
		ctx.Run = (ctx.Run or 0) + ((model:GetAttribute("Run") or 0) - (ctx.Run or 0)) * math.min(1, dt * 4)
		local stride = math.max(2, H * 0.45)
		local previous = ctx.Phase or 0
		ctx.Phase = previous + dt * math.max(flat, moveAttr * 4) / stride * math.pi
		-- passi: polvere e terra che trema
		if ctx.Move > 0.3 and math.floor(previous / math.pi) ~= math.floor(ctx.Phase / math.pi) then
			local footPos = root.Position - Vector3.new(0, model:GetAttribute("HipHeight") or H * 0.5, 0)
			if H >= 20 and C.EffectsController then
				C.EffectsController.Steam(footPos, H * 0.06, 4, 1.2, Color3.fromRGB(170, 150, 120))
				C.EffectsController.ShakeAt(footPos, math.clamp(H / 160, 0.05, 0.6), H * 5, 0.2)
			end
			if C.SoundController and localRoot and (localRoot.Position - footPos).Magnitude < H * 8 then
				C.SoundController.Play("Step", footPos, { Range = H * 8, Volume = math.clamp(H / 40, 0.3, 1.2), Pitch = math.clamp(1.2 - H / 120, 0.25, 1) })
			end
		end
		-- lo sguardo segue il giocatore
		if localRoot and model:GetAttribute("Dummy") ~= true then
			local head = model:FindFirstChild("Head") :: BasePart?
			local torso = model:FindFirstChild("Torso") :: BasePart?
			if head and torso then
				local targetId = model:GetAttribute("TargetUserId")
				local dist = (localRoot.Position - head.Position).Magnitude
				if targetId == player.UserId or dist < H * 3 then
					local rel = torso.CFrame:PointToObjectSpace(localRoot.Position)
					local yaw = math.deg(math.atan2(-rel.X, -rel.Z))
					local pitch = math.deg(math.atan2(rel.Y - H * 0.25, Vector3.new(rel.X, 0, rel.Z).Magnitude))
					ctx.LookYaw = (ctx.LookYaw or 0) + (math.clamp(yaw, -70, 70) - (ctx.LookYaw or 0)) * math.min(1, dt * 3)
					ctx.LookPitch = (ctx.LookPitch or 0) + (math.clamp(pitch, -45, 35) - (ctx.LookPitch or 0)) * math.min(1, dt * 3)
				else
					ctx.LookYaw = (ctx.LookYaw or 0) * (1 - math.min(1, dt * 2))
					ctx.LookPitch = (ctx.LookPitch or 0) * (1 - math.min(1, dt * 2))
				end
			end
		end
		if state.Wobble > 0 then
			state.Wobble = math.max(0, state.Wobble - dt * 2)
			ctx.Wobble = state.Wobble
		end
	end
	animator:Update(dt)
end

function TitanAnimator.Get(model: Model?)
	return model and titans[model]
end

function TitanAnimator.All()
	return titans
end

function TitanAnimator.Init(c)
	C = c
end

function TitanAnimator.Start()
	local tag = Config.Tags.Titan
	for _, model in CollectionService:GetTagged(tag) do
		if model:IsA("Model") then
			task.spawn(register, model)
		end
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(model)
		if model:IsA("Model") then
			task.spawn(register, model)
		end
	end)
	local frame = 0
	RunService.PreSimulation:Connect(function(dt)
		frame += 1
		local localRoot = Util.GetRoot(player.Character)
		local camPos = workspace.CurrentCamera.CFrame.Position
		for _, state in titans do
			local root = state.Root
			if root.Parent then
				local dist = (root.Position - camPos).Magnitude - state.Height
				if dist < 900 then
					local every = if dist < 250 then 1 elseif dist < 500 then 2 else 4
					if frame % every == 0 then
						local ok, err = pcall(updateTitan, state, dt * every, localRoot)
						if not ok then
							warn("[Giganti] " .. tostring(err))
						end
					else
						state.Animator:Apply()
					end
				end
			end
		end
	end)
end

return TitanAnimator
