--[[
	EffectsController
	Tutti gli effetti visivi del gioco, creati sul client:
	vapore dei giganti, fulmini della trasformazione, esplosioni delle Lance Dirompenti,
	onde d'urto, scintille, detriti, punte di cristallo, raggio di luce del livello...
	Riceve dal server gli eventi "Effect"/"EffectFast" e li riproduce.
]]

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Lib.Net)
local Util = require(Shared.Lib.Util)

local EffectsController = {}
local C
local player = Players.LocalPlayer
local folder: Folder
local rng = Random.new()

local TEX = {
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
}

local function tween(instance: Instance, time: number, goals, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local t = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goals)
	t:Play()
	return t
end

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = folder
	return p
end

local function attachmentAt(position: Vector3, lifetime: number): Attachment
	local a = Instance.new("Attachment")
	a.WorldPosition = position
	a.Parent = workspace.Terrain
	Debris:AddItem(a, lifetime)
	return a
end

local function emitter(parent: Instance, props): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.LightInfluence = 0.6
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function localRoot(): BasePart?
	return Util.GetRoot(player.Character)
end

local function distanceTo(position: Vector3): number
	local root = localRoot()
	if not root then
		return math.huge
	end
	return (root.Position - position).Magnitude
end

-- Scossa della telecamera che diminuisce con la distanza
function EffectsController.ShakeAt(position: Vector3, intensity: number, radius: number, duration: number?)
	local d = distanceTo(position)
	if d > radius then
		return
	end
	local k = 1 - d / radius
	if C.CameraController then
		C.CameraController.Shake(intensity * k, duration or 0.4)
	end
end

-- MATTONI DI BASE ---------------------------------------------------------------------------

function EffectsController.Steam(position: Vector3, size: number, count: number?, lifetime: number?, color: Color3?)
	local a = attachmentAt(position, (lifetime or 3) + 4)
	local e = emitter(a, {
		Texture = TEX.Smoke,
		Color = ColorSequence.new(color or Color3.fromRGB(246, 242, 236)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(0.6, 0.65), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.3), NumberSequenceKeypoint.new(1, size) }),
		Lifetime = NumberRange.new((lifetime or 3) * 0.6, lifetime or 3),
		Speed = NumberRange.new(size * 0.3, size * 0.9),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, size * 0.6, 0),
		Drag = 2,
		RotSpeed = NumberRange.new(-40, 40),
		Rotation = NumberRange.new(0, 360),
		LightEmission = 0.1,
	})
	e:Emit(count or 12)
	return a
end

function EffectsController.Sparks(position: Vector3, color: Color3?, count: number?, speed: number?)
	local a = attachmentAt(position, 2)
	local e = emitter(a, {
		Texture = TEX.Sparkle,
		Color = ColorSequence.new(color or Color3.fromRGB(255, 240, 200)),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.2, 0.45),
		Speed = NumberRange.new((speed or 40) * 0.5, speed or 40),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
	})
	e:Emit(count or 18)
end

function EffectsController.Shockwave(position: Vector3, radius: number, color: Color3?, time: number?, height: number?)
	local ring = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height or 0.6, 2, 2),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color or Color3.fromRGB(255, 255, 255),
		Transparency = 0.25,
	})
	local t = time or 0.5
	tween(ring, t, { Size = Vector3.new(height or 0.6, radius * 2, radius * 2), Transparency = 1 }, Enum.EasingStyle.Quart)
	Debris:AddItem(ring, t + 0.1)
	return ring
end

function EffectsController.Flash(color: Color3?, strength: number?, time: number?)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Lampo"
	cc.Brightness = (strength or 0.4)
	cc.TintColor = color or Color3.fromRGB(255, 255, 255)
	cc.Parent = Lighting
	tween(cc, time or 0.35, { Brightness = 0, TintColor = Color3.new(1, 1, 1) })
	Debris:AddItem(cc, (time or 0.35) + 0.1)
end

function EffectsController.Lightning(from: Vector3, to: Vector3, color: Color3?, thickness: number?)
	local segments = 12
	local col = color or Color3.fromRGB(255, 230, 120)
	local width = thickness or 1.6
	local parts = {}
	local function bolt(a: Vector3, b: Vector3, segs: number, w: number)
		local prev = a
		local dir = b - a
		local jitter = dir.Magnitude * 0.06
		for i = 1, segs do
			local point = if i == segs then b else a + dir * (i / segs) + Vector3.new(rng:NextNumber(-jitter, jitter), rng:NextNumber(-jitter, jitter) * 0.3, rng:NextNumber(-jitter, jitter))
			local mid = (prev + point) / 2
			local len = (point - prev).Magnitude
			table.insert(parts, part({ Size = Vector3.new(w, w, len), CFrame = CFrame.lookAt(mid, point), Color = col, Transparency = 0 }))
			prev = point
		end
	end
	bolt(from, to, segments, width)
	for _ = 1, 3 do
		local start = from:Lerp(to, rng:NextNumber(0.2, 0.7))
		local finish = start + Vector3.new(rng:NextNumber(-40, 40), rng:NextNumber(-60, -10), rng:NextNumber(-40, 40))
		bolt(start, finish, 5, width * 0.5)
	end
	local light = Instance.new("PointLight")
	light.Color = col
	light.Range = 60
	light.Brightness = 8
	light.Parent = parts[#parts] or folder
	task.spawn(function()
		for i = 1, 3 do
			for _, p in parts do
				p.Transparency = if i % 2 == 0 then 0.7 else 0
			end
			task.wait(0.06)
		end
		for _, p in parts do
			tween(p, 0.25, { Transparency = 1 })
			Debris:AddItem(p, 0.3)
		end
	end)
end

function EffectsController.DebrisBurst(position: Vector3, count: number, size: number, color: Color3?, material: Enum.Material?, speed: number?)
	for _ = 1, count do
		local s = size * rng:NextNumber(0.4, 1)
		local chunk = part({
			Size = Vector3.new(s, s * rng:NextNumber(0.5, 1), s),
			CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0, 1), rng:NextNumber(-1, 1)) * size) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)),
			Color = color or Color3.fromRGB(130, 120, 106),
			Material = material or Enum.Material.Rock,
			Anchored = false,
			CanCollide = true,
		})
		chunk.CollisionGroup = Config.CollisionGroups.Debris
		local v = speed or 50
		chunk.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-v, v), rng:NextNumber(v * 0.4, v * 1.2), rng:NextNumber(-v, v))
		chunk.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(-10, 10), rng:NextNumber(-10, 10))
		task.delay(2.2, function()
			if chunk.Parent then
				tween(chunk, 0.8, { Transparency = 1 })
			end
		end)
		Debris:AddItem(chunk, 3.2)
	end
end

function EffectsController.Explosion(position: Vector3, radius: number, big: boolean?)
	local fire = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(position), Color = Color3.fromRGB(255, 170, 60), Transparency = 0 })
	tween(fire, 0.35, { Size = Vector3.one * radius * 2, Transparency = 0.4, Color = Color3.fromRGB(255, 90, 30) }, Enum.EasingStyle.Quart)
	task.delay(0.35, function()
		tween(fire, 0.4, { Transparency = 1 })
	end)
	Debris:AddItem(fire, 0.9)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 80)
	light.Range = radius * 4
	light.Brightness = 10
	light.Parent = fire
	EffectsController.Shockwave(position, radius * 2.2, Color3.fromRGB(255, 220, 170), 0.6)
	EffectsController.Steam(position, radius * 0.9, 18, 3.5, Color3.fromRGB(90, 84, 78))
	EffectsController.Sparks(position, Color3.fromRGB(255, 200, 120), 40, radius * 4)
	EffectsController.DebrisBurst(position, if big then 14 else 7, radius * 0.18, nil, nil, radius * 3)
	EffectsController.ShakeAt(position, if big then 1 else 0.6, radius * 12, 0.6)
	if C.SoundController then
		C.SoundController.Play("Explosion", position, { Range = 900 })
	end
	if distanceTo(position) < radius * 4 then
		EffectsController.Flash(Color3.fromRGB(255, 200, 150), 0.25, 0.3)
	end
end

function EffectsController.Telegraph(position: Vector3, radius: number, time: number)
	local base = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 50, 40),
		Transparency = 0.75,
	})
	local inner = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.35, 0.5, 0.5),
		CFrame = base.CFrame,
		Color = Color3.fromRGB(255, 90, 60),
		Transparency = 0.45,
	})
	tween(inner, time, { Size = Vector3.new(0.35, radius * 2, radius * 2) }, Enum.EasingStyle.Linear)
	task.delay(time, function()
		tween(base, 0.2, { Transparency = 1 })
		tween(inner, 0.2, { Transparency = 1 })
	end)
	Debris:AddItem(base, time + 0.3)
	Debris:AddItem(inner, time + 0.3)
end

function EffectsController.Spike(position: Vector3, height: number, delay: number?)
	task.delay(delay or 0, function()
		local w = math.max(2, height * 0.22)
		local spike = part({
			Size = Vector3.new(w, 0.5, w),
			CFrame = CFrame.new(position) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 6), rng:NextNumber(-0.25, 0.25)),
			Color = Color3.fromRGB(170, 230, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.15,
			CastShadow = true,
		})
		local target = spike.CFrame * CFrame.new(0, height / 2, 0)
		tween(spike, 0.12, { Size = Vector3.new(w, height, w), CFrame = target }, Enum.EasingStyle.Back)
		EffectsController.DebrisBurst(position, 3, w * 0.3, Color3.fromRGB(120, 110, 100), Enum.Material.Rock, 30)
		task.delay(1.3, function()
			EffectsController.DebrisBurst(target.Position, 4, w * 0.35, Color3.fromRGB(170, 230, 255), Enum.Material.Glass, 25)
			tween(spike, 0.3, { Transparency = 1, Size = Vector3.new(w, height * 0.6, w) })
			Debris:AddItem(spike, 0.35)
		end)
	end)
end

-- Proiettile ad arco (massi, palle di cannone, lance)
function EffectsController.Projectile(from: Vector3, to: Vector3, time: number, kind: string, size: number?)
	local s = math.clamp(size or 4, 1, 60)
	local p
	if kind == "Rock" then
		p = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * s, Material = Enum.Material.Rock, Color = Color3.fromRGB(120, 110, 98), CFrame = CFrame.new(from), CastShadow = true })
	elseif kind == "Cannon" then
		p = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * math.min(s, 6), Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 40, 44), CFrame = CFrame.new(from) })
	else
		p = part({ Size = Vector3.new(0.5, 0.5, 4), Color = Color3.fromRGB(255, 200, 90), CFrame = CFrame.new(from) })
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, s * 0.3, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -s * 0.3, 0)
	a1.Parent = p
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.35
	trail.Color = ColorSequence.new(if kind == "Rock" then Color3.fromRGB(200, 190, 170) else Color3.fromRGB(255, 200, 120))
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.LightEmission = 0.4
	trail.Parent = p
	local height = math.max(20, (to - from).Magnitude * 0.25)
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - start) / time, 0, 1)
		local pos = from:Lerp(to, k) + Vector3.new(0, math.sin(k * math.pi) * height, 0)
		local nextK = math.min(1, k + 0.02)
		local nextPos = from:Lerp(to, nextK) + Vector3.new(0, math.sin(nextK * math.pi) * height, 0)
		if (nextPos - pos).Magnitude > 0.01 then
			p.CFrame = CFrame.lookAt(pos, nextPos) * CFrame.Angles(k * 8, k * 5, 0)
		else
			p.CFrame = CFrame.new(pos)
		end
		if k >= 1 then
			conn:Disconnect()
			p:Destroy()
		end
	end)
end

-- Lancia Dirompente conficcata: segue il bersaglio, la miccia lampeggia sempre più veloce
local function spearArmed(params, fuse: number)
	local target: BasePart? = if typeof(params.Part) == "Instance" and params.Part:IsA("BasePart") then params.Part else nil
	local position: Vector3 = params.Position
	local from: Vector3 = if typeof(params.From) == "Vector3" then params.From else position + Vector3.yAxis
	local dir = Util.SafeUnit(position - from)
	if dir.Magnitude < 0.5 then
		dir = -Vector3.yAxis
	end
	if target and not target.Parent then
		target = nil
	end
	-- la punta resta dentro il bersaglio, l'asta sporge all'indietro
	local world = CFrame.lookAt(position - dir * 1.6, position + dir)
	local localCF = if target then target.CFrame:ToObjectSpace(world) else nil
	local shaft = part({ Size = Vector3.new(0.35, 0.35, 4), Material = Enum.Material.Metal, Color = Color3.fromRGB(70, 72, 78), CFrame = world })
	local light = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6, Color = params.Color or Color3.fromRGB(255, 70, 50), CFrame = world * CFrame.new(0, 0, 2.1) })
	local glow = Instance.new("PointLight")
	glow.Color = light.Color
	glow.Range = 10
	glow.Brightness = 0
	glow.Parent = light
	local start = os.clock()
	local nextBeep = start
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local k = math.clamp((now - start) / fuse, 0, 1)
		if k >= 1 or not shaft.Parent then
			conn:Disconnect()
			shaft:Destroy()
			light:Destroy()
			return
		end
		if target and localCF and target.Parent then
			world = target.CFrame * localCF
		end
		shaft.CFrame = world
		light.CFrame = world * CFrame.new(0, 0, 2.1)
		-- bip e lampi sempre più rapidi man mano che la miccia si consuma
		if now >= nextBeep then
			nextBeep = now + math.max(0.06, 0.4 * (1 - k))
			light.Transparency = 0
			glow.Brightness = 4
			tween(light, 0.08, { Transparency = 0.8 })
			tween(glow, 0.08, { Brightness = 0 })
			if C.SoundController then
				C.SoundController.Play("Type", world.Position, { Range = 160, Volume = 0.35, Pitch = 2 + k * 1.5 })
			end
		end
	end)
	EffectsController.Sparks(position, Color3.fromRGB(255, 220, 150), 10, 30)
	if C.SoundController then
		C.SoundController.Play("HookHit", position, { Range = 300, Pitch = 0.9 })
	end
end

function EffectsController.SpearArmed(params)
	local fuse = math.clamp(tonumber(params.Fuse) or 1.4, 0.1, 5)
	local from = if typeof(params.From) == "Vector3" then params.From else params.Position
	-- compare quando il proiettile arriva (stessa durata del volo mostrato a chi spara)
	local travel = math.clamp((params.Position - from).Magnitude / 400, 0.12, 0.6)
	if travel >= fuse - 0.1 then
		return
	end
	task.delay(travel, spearArmed, params, fuse - travel)
end

function EffectsController.Tracer(from: Vector3, to: Vector3, color: Color3?)
	local len = (to - from).Magnitude
	local line = part({ Size = Vector3.new(0.12, 0.12, len), CFrame = CFrame.lookAt((from + to) / 2, to), Color = color or Color3.fromRGB(255, 240, 190), Transparency = 0.1 })
	tween(line, 0.12, { Transparency = 1, Size = Vector3.new(0.02, 0.02, len) })
	Debris:AddItem(line, 0.15)
	EffectsController.Sparks(from, Color3.fromRGB(255, 220, 150), 6, 20)
	EffectsController.Sparks(to, Color3.fromRGB(255, 230, 180), 8, 25)
end

function EffectsController.HighlightModel(model: Instance, color: Color3, duration: number, fill: number?)
	local h = Instance.new("Highlight")
	h.FillColor = color
	h.OutlineColor = color
	h.FillTransparency = fill or 0.55
	h.OutlineTransparency = 0.1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = model
	h.Parent = folder
	task.delay(duration, function()
		tween(h, 0.4, { FillTransparency = 1, OutlineTransparency = 1 })
		Debris:AddItem(h, 0.45)
	end)
	return h
end

local function modelCenter(model: Instance?): Vector3?
	if model and model:IsA("Model") then
		local ok, cf = pcall(function()
			return model:GetPivot()
		end)
		if ok then
			return cf.Position
		end
	end
	return nil
end

-- Raggio di luce dorato alla salita di livello
function EffectsController.LevelUp(character: Model?)
	local root = Util.GetRoot(character)
	if not root then
		return
	end
	local base = root.Position - Vector3.new(0, 3, 0)
	local pillar = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(80, 3, 3),
		CFrame = CFrame.new(base + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 220, 120),
		Transparency = 0.2,
	})
	tween(pillar, 1.2, { Size = Vector3.new(80, 12, 12), Transparency = 1 })
	Debris:AddItem(pillar, 1.3)
	EffectsController.Shockwave(base, 22, Color3.fromRGB(255, 220, 140), 0.8)
	local a = Instance.new("Attachment")
	a.Parent = root
	Debris:AddItem(a, 3)
	local e = emitter(a, {
		Texture = TEX.Sparkle,
		Color = ColorSequence.new(Color3.fromRGB(255, 230, 150)),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(1, 1.8),
		Speed = NumberRange.new(4, 10),
		SpreadAngle = Vector2.new(30, 30),
		Acceleration = Vector3.new(0, 14, 0),
	})
	e:Emit(60)
end

-- Fulmine giallo della trasformazione
function EffectsController.TransformStart(character: Model?, height: number)
	local root = Util.GetRoot(character)
	if not root then
		return
	end
	local ground = root.Position - Vector3.new(0, 3, 0)
	EffectsController.Lightning(ground + Vector3.new(rng:NextNumber(-20, 20), 600, rng:NextNumber(-20, 20)), ground, Color3.fromRGB(255, 236, 130), 2.2 + height * 0.02)
	EffectsController.Flash(Color3.fromRGB(255, 240, 180), 0.5, 0.5)
	EffectsController.ShakeAt(ground, 0.9, 600, 0.6)
	if C.SoundController then
		C.SoundController.Play("Thunder", ground, { Range = 1500 })
	end
	if character == player.Character and C.AnimationController then
		C.AnimationController.Play(character, "Transform", 1)
	end
end

function EffectsController.TransformBurst(position: Vector3, height: number)
	EffectsController.Steam(position, height * 0.5, 30, 5)
	EffectsController.Shockwave(position, height * 1.4, Color3.fromRGB(255, 220, 160), 0.8, 2)
	EffectsController.Shockwave(position + Vector3.new(0, height * 0.3, 0), height * 1.1, Color3.fromRGB(255, 255, 255), 0.6, 1)
	EffectsController.DebrisBurst(position - Vector3.new(0, 3, 0), 12, math.max(2, height * 0.05), nil, nil, 80)
	EffectsController.Flash(Color3.fromRGB(255, 200, 140), 0.35, 0.5)
	EffectsController.ShakeAt(position, 1, height * 12, 0.8)
	if C.SoundController then
		C.SoundController.Play("Steam", position, { Range = 1200 })
	end
end

function EffectsController.TransformEnd(position: Vector3, height: number)
	EffectsController.Steam(position + Vector3.new(0, height * 0.3, 0), height * 0.45, 26, 6)
	if C.SoundController then
		C.SoundController.Play("Steam", position, { Range = 800 })
	end
end

-- Vapore del cadavere di un gigante
function EffectsController.TitanDeath(model: Model?, height: number?)
	local center = modelCenter(model)
	if not center then
		return
	end
	local h = height or 20
	for i = 1, 5 do
		task.delay(i * 0.6, function()
			local current = modelCenter(model) or center
			EffectsController.Steam(current + Vector3.new(rng:NextNumber(-h * 0.2, h * 0.2), rng:NextNumber(-h * 0.3, h * 0.1), rng:NextNumber(-h * 0.2, h * 0.2)), h * 0.35, 10, 4)
		end)
	end
	if C.SoundController then
		C.SoundController.Play("Steam", center, { Range = 500 })
	end
end

function EffectsController.Awaken(character: Model?, duration: number)
	if not character then
		return
	end
	EffectsController.HighlightModel(character, Color3.fromRGB(255, 50, 50), duration, 0.85)
	local root = Util.GetRoot(character)
	if root then
		local a = Instance.new("Attachment")
		a.Parent = root
		Debris:AddItem(a, duration + 1)
		local e = emitter(a, {
			Texture = TEX.Fire,
			Color = ColorSequence.new(Color3.fromRGB(255, 60, 40), Color3.fromRGB(120, 0, 0)),
			LightEmission = 0.8,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new(0.3, 1),
			Lifetime = NumberRange.new(0.4, 0.8),
			Speed = NumberRange.new(2, 5),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, 10, 0),
			Rate = 40,
		})
		e.Enabled = true
		task.delay(duration, function()
			e.Enabled = false
		end)
		EffectsController.Shockwave(root.Position, 18, Color3.fromRGB(255, 60, 50), 0.5)
	end
	if character == player.Character and C.AnimationController then
		C.AnimationController.Play(character, "Awaken", 1)
	end
end

function EffectsController.Inject(character: Model?, color: Color3?)
	local root = Util.GetRoot(character)
	if not root or not character then
		return
	end
	if C.AnimationController then
		C.AnimationController.Play(character, "Inject", 1)
	end
	local hand = character:FindFirstChild("RightHand") :: BasePart?
	if hand then
		local syringe = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 0.3, 0.3), CFrame = hand.CFrame, Color = Color3.fromRGB(120, 255, 150), Anchored = false })
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = syringe
		weld.Parent = syringe
		syringe.Massless = true
		Debris:AddItem(syringe, 1.2)
	end
	task.delay(0.6, function()
		EffectsController.HighlightModel(character, color or Color3.fromRGB(120, 255, 150), 1.2, 0.5)
		for _ = 1, 4 do
			local a = root.Position + Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-2, 3), rng:NextNumber(-3, 3))
			EffectsController.Lightning(a, a + Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(-4, 4), rng:NextNumber(-4, 4)), color or Color3.fromRGB(150, 255, 170), 0.25)
		end
		EffectsController.Steam(root.Position, 4, 10, 2)
	end)
end

function EffectsController.SerumObtained(character: Model?, color: Color3?)
	local root = Util.GetRoot(character)
	if not root then
		return
	end
	EffectsController.Shockwave(root.Position - Vector3.new(0, 2.5, 0), 26, color or Color3.fromRGB(120, 255, 150), 0.9)
	local a = Instance.new("Attachment")
	a.Parent = root
	Debris:AddItem(a, 3)
	local e = emitter(a, {
		Texture = TEX.Sparkle,
		Color = ColorSequence.new(color or Color3.fromRGB(150, 255, 170)),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(1, 2),
		Speed = NumberRange.new(8, 16),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
	})
	e:Emit(80)
	if character == player.Character then
		EffectsController.Flash(color or Color3.fromRGB(150, 255, 170), 0.3, 0.6)
	end
end

-- Effetti delle abilità in forma di gigante
-- MOSSE DEL GIGANTE DELLA FURIA ---------------------------------------------------------------------
local FURIA_GREEN = Color3.fromRGB(120, 255, 170)
local CRYSTAL = Color3.fromRGB(170, 230, 255)

local function handPosition(character: Model, side: string): Vector3?
	local hand = character:FindFirstChild(side .. "Hand") :: BasePart?
	return hand and hand.Position
end

-- pugno di cristallo che brilla per un attimo sulla mano
local function crystalFist(character: Model, side: string, size: number, duration: number)
	local hand = character:FindFirstChild(side .. "Hand") :: BasePart?
	if not hand then
		return
	end
	local glow = Instance.new("Part")
	glow.Name = "PugnoCristallo"
	glow.Shape = Enum.PartType.Ball
	glow.Size = Vector3.one * size
	glow.Material = Enum.Material.Glass
	glow.Color = CRYSTAL
	glow.Transparency = 0.25
	glow.CanCollide = false
	glow.CanQuery = false
	glow.CanTouch = false
	glow.Massless = true
	glow.CastShadow = false
	glow.CFrame = hand.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = glow
	weld.Parent = glow
	local light = Instance.new("PointLight")
	light.Color = CRYSTAL
	light.Range = size * 4
	light.Brightness = 3
	light.Parent = glow
	glow.Parent = workspace
	TweenService:Create(glow, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	Debris:AddItem(glow, duration + 0.1)
end

local LOOK_MOVES = {
	Furia = {
		M1 = {
			Clip = { "FuriaHookR", "FuriaHookL" },
			Fx = function(character, _root, radius, height)
				task.delay(0.24, function()
					local r = Util.GetRoot(character)
					if r then
						local center = r.Position + r.CFrame.LookVector * radius * 0.9
						EffectsController.Shockwave(center, radius * 0.8, Color3.fromRGB(255, 240, 210), 0.3, 1)
						EffectsController.ShakeAt(center, 0.4, height * 6, 0.2)
					end
				end)
			end,
		},
		Z = {
			Clip = "FuriaHardPunch",
			Fx = function(character, _root, radius, height)
				crystalFist(character, "Right", height * 0.09, 1.1)
				task.delay(0.42, function()
					local r = Util.GetRoot(character)
					local fist = handPosition(character, "Right")
					if r then
						local center = fist or (r.Position + r.CFrame.LookVector * radius)
						EffectsController.Shockwave(center, radius * 1.4, CRYSTAL, 0.5, 2)
						EffectsController.DebrisBurst(center, 12, math.max(2, height * 0.04), nil, nil, 80)
						EffectsController.Flash(Color3.fromRGB(220, 245, 255), 0.25, 0.25)
						EffectsController.ShakeAt(center, 1, height * 10, 0.45)
						if C.SoundController then
							C.SoundController.Play("Explosion", center, { Range = 1200, Volume = 0.8, Pitch = 0.7 })
						end
					end
				end)
			end,
		},
		X = {
			Clip = "FuriaSpinKick",
			Fx = function(character, _root, radius, height)
				for i = 0, 2 do
					task.delay(0.15 + i * 0.12, function()
						local r = Util.GetRoot(character)
						if r then
							EffectsController.Shockwave(r.Position - Vector3.new(0, height * 0.2, 0), radius * (0.7 + i * 0.25), Color3.fromRGB(255, 235, 200), 0.4, 1)
						end
					end)
				end
				task.delay(0.3, function()
					local r = Util.GetRoot(character)
					if r then
						local feet = r.Position - Vector3.new(0, height * 0.45, 0)
						EffectsController.Steam(feet, radius * 0.6, 14, 2, Color3.fromRGB(170, 150, 120))
						EffectsController.DebrisBurst(feet, 10, math.max(2, height * 0.04), nil, nil, 70)
						EffectsController.ShakeAt(feet, 0.8, height * 8, 0.4)
					end
				end)
			end,
		},
		C = {
			Clip = "FuriaRoar",
			Fx = function(character, _root, radius, height)
				task.delay(0.45, function()
					local r = Util.GetRoot(character)
					if not r then
						return
					end
					for i = 0, 3 do
						task.delay(i * 0.2, function()
							EffectsController.Shockwave(r.Position, radius * (0.5 + i * 0.3), Color3.fromRGB(255, 255, 255), 0.8, 1)
						end)
					end
					EffectsController.Steam(r.Position + Vector3.new(0, height * 0.3, 0), height * 0.5, 24, 3)
					EffectsController.ShakeAt(r.Position, 1, height * 15, 1)
					if C.SoundController then
						C.SoundController.Play("Roar", r.Position, { Range = 1600, Volume = 1, Pitch = 0.8 })
					end
				end)
			end,
		},
		V = {
			Clip = "FuriaFocus",
			Fx = function(character, _root, radius, height)
				task.delay(0.6, function()
					local r = Util.GetRoot(character)
					if r then
						EffectsController.HighlightModel(character, FURIA_GREEN, 6, 0.55)
						EffectsController.Shockwave(r.Position, radius * 1.5, FURIA_GREEN, 0.7, 2)
						EffectsController.Lightning(r.Position + Vector3.new(0, 700, 0), r.Position + Vector3.new(0, height * 0.5, 0), FURIA_GREEN, 3)
						if C.SoundController then
							C.SoundController.Play("Thunder", r.Position, { Range = 1500, Volume = 0.7 })
						end
					end
				end)
			end,
		},
	},
}

function EffectsController.TitanSkill(params)
	local character = params.Character
	local kind = params.Kind
	local radius = params.Radius or 20
	local height = params.Height or 30
	local root = Util.GetRoot(character)
	local position = params.Position
	local clipByKind = {
		Punch = "TitanPunchSmall",
		Bite = "TitanPunchSmall",
		Kick = "TitanKickSmall",
		Flurry = "TitanPunchSmall",
		Roar = "TitanRoarSmall",
		Dominio = "TitanRoarSmall",
		Summon = "TitanRoarSmall",
		Rumbling = "TitanRoarSmall",
		RockThrow = "TitanThrowSmall",
		RockBarrage = "TitanThrowSmall",
		Cannon = "TitanThrowSmall",
		Spikes = "TitanSlamSmall",
		SpikeArena = "TitanSlamSmall",
		Stomp = "TitanSlamSmall",
		Explosion = "TitanRoarSmall",
		Steam = "TitanRoarSmall",
		Harden = "TitanRoarSmall",
		Crystal = "TitanRoarSmall",
	}
	-- mosse dedicate di un gigante (animazioni ed effetti propri)
	local special = LOOK_MOVES[params.Look or ""]
	local move = special and special[params.Key or ""]
	if move and character then
		local clipName = move.Clip
		if type(clipName) == "table" then
			-- combo: alterna i colpi (es. gancio destro e sinistro)
			local n = (character:GetAttribute("ComboFuria") or 0) + 1
			character:SetAttribute("ComboFuria", n)
			clipName = clipName[(n - 1) % #clipName + 1]
		end
		if C.AnimationController then
			C.AnimationController.Play(character, clipName, 1)
		end
		if root and move.Fx then
			move.Fx(character, root, radius, height, params)
		end
		return
	end
	if character and C.AnimationController and clipByKind[kind] then
		C.AnimationController.Play(character, clipByKind[kind], 1)
	end
	if not root then
		return
	end
	local feet = root.Position - Vector3.new(0, height * 0.45, 0)
	if kind == "Punch" or kind == "Bite" or kind == "Kick" then
		task.delay(0.22, function()
			local r = Util.GetRoot(character)
			if r then
				local center = r.Position + r.CFrame.LookVector * radius * 0.9
				EffectsController.Shockwave(center, radius, Color3.fromRGB(255, 240, 210), 0.35, 1)
				EffectsController.DebrisBurst(center, 5, math.max(1.5, height * 0.03), nil, nil, 50)
				EffectsController.ShakeAt(center, 0.6, height * 8, 0.3)
			end
		end)
	elseif kind == "Stomp" then
		EffectsController.Shockwave(feet, radius * 1.2, Color3.fromRGB(200, 180, 150), 0.6, 2)
		EffectsController.Steam(feet, radius * 0.5, 14, 2.5, Color3.fromRGB(160, 140, 115))
		EffectsController.DebrisBurst(feet, 10, math.max(2, height * 0.04), nil, nil, 70)
		EffectsController.ShakeAt(feet, 1, height * 10, 0.6)
	elseif kind == "Roar" or kind == "Dominio" or kind == "Summon" or kind == "Rumbling" then
		local col = if kind == "Dominio" then Color3.fromRGB(150, 220, 255) else Color3.fromRGB(255, 255, 255)
		for i = 0, 2 do
			task.delay(i * 0.18, function()
				EffectsController.Shockwave(root.Position, radius * (0.6 + i * 0.3), col, 0.7, 1)
			end)
		end
		EffectsController.ShakeAt(root.Position, 0.8, height * 15, 0.8)
		if C.SoundController then
			C.SoundController.Play("Roar", root.Position, { Range = 1500 })
		end
	elseif kind == "Harden" or kind == "Crystal" then
		EffectsController.HighlightModel(character, Color3.fromRGB(170, 230, 255), 6, 0.35)
	elseif kind == "Steam" then
		for i = 0, 8 do
			task.delay(i * 0.6, function()
				local r = Util.GetRoot(character)
				if r then
					EffectsController.Steam(r.Position, radius * 0.6, 14, 2.5)
				end
			end)
		end
	elseif kind == "Explosion" then
		EffectsController.Explosion(root.Position, radius * 0.5, true)
		EffectsController.Lightning(root.Position + Vector3.new(0, 800, 0), root.Position, Color3.fromRGB(255, 236, 130), 6)
	elseif kind == "FutureSight" then
		EffectsController.HighlightModel(character, Color3.fromRGB(120, 255, 170), 6, 0.6)
	elseif kind == "Frenzy" or kind == "SpeedBoost" then
		EffectsController.HighlightModel(character, Color3.fromRGB(255, 80, 60), 6, 0.75)
	end
	if position and kind == "Spikes" then
		EffectsController.ShakeAt(position, 0.5, height * 8, 0.4)
	end
end

local function onImpact(params)
	local pos = params.Position
	local radius = params.Radius or 10
	local kind = params.Kind
	if kind == "Explosion" then
		EffectsController.Explosion(pos, radius * 0.7, false)
	elseif kind == "Rock" then
		EffectsController.DebrisBurst(pos, 8, math.max(1.5, radius * 0.12), nil, nil, 60)
		EffectsController.Steam(pos, radius * 0.6, 10, 2, Color3.fromRGB(170, 150, 120))
		EffectsController.Shockwave(pos, radius, Color3.fromRGB(210, 190, 160), 0.4)
		EffectsController.ShakeAt(pos, 0.7, radius * 10, 0.4)
		if C.SoundController then
			C.SoundController.Play("Explosion", pos, { Range = 700, Volume = 0.5, Pitch = 0.6 })
		end
	elseif kind == "Stomp" then
		EffectsController.Shockwave(pos, radius * 1.2, Color3.fromRGB(200, 180, 150), 0.5, 1.5)
		EffectsController.Steam(pos, radius * 0.4, 12, 2, Color3.fromRGB(160, 140, 115))
		EffectsController.ShakeAt(pos, 0.8, radius * 12, 0.5)
		if C.SoundController then
			C.SoundController.Play("Land", pos, { Range = 600, Volume = 1, Pitch = 0.4 })
		end
	elseif kind == "Swipe" then
		EffectsController.Shockwave(pos, radius, Color3.fromRGB(255, 255, 255), 0.3, 0.6)
	elseif kind == "Bite" then
		EffectsController.Steam(pos, radius * 0.4, 8, 1.5, Color3.fromRGB(200, 80, 70))
	elseif kind == "Spike" then
		EffectsController.ShakeAt(pos, 0.3, 200, 0.2)
	end
end

local handlers = {}

handlers.LevelUp = function(p)
	EffectsController.LevelUp(p.Character)
end
handlers.Impact = onImpact
handlers.Bite = function(p)
	EffectsController.Steam(p.Position, 6, 14, 2, Color3.fromRGB(180, 40, 40))
	EffectsController.ShakeAt(p.Position, 0.8, 200, 0.4)
end
handlers.Roar = function(p)
	local h = p.Height or 30
	for i = 0, 2 do
		task.delay(i * 0.2, function()
			EffectsController.Shockwave(p.Position, h * (1 + i * 0.6), Color3.fromRGB(255, 255, 255), 0.8, 1)
		end)
	end
	EffectsController.ShakeAt(p.Position, 0.9, h * 15, 1)
	if C.SoundController then
		C.SoundController.Play("Roar", p.Position, { Range = 1500 })
	end
end
handlers.Harden = function(p)
	if p.Model then
		EffectsController.HighlightModel(p.Model, Color3.fromRGB(170, 230, 255), 6, 0.3)
	end
end
handlers.Projectile = function(p)
	EffectsController.Projectile(p.From, p.To, p.Time, p.Kind, p.Size)
end
handlers.SteamBurst = function(p)
	local duration = p.Duration or 4
	for i = 0, math.floor(duration / 0.5) do
		task.delay(i * 0.5, function()
			EffectsController.Steam(p.Position, p.Radius * 0.5, 16, 2.5)
		end)
	end
	EffectsController.ShakeAt(p.Position, 0.5, p.Radius * 4, duration)
	if C.SoundController then
		C.SoundController.Play("Steam", p.Position, { Range = 900 })
	end
end
handlers.Spike = function(p)
	EffectsController.Spike(p.Position, p.Height or 10, p.Delay)
end
handlers.Telegraph = function(p)
	EffectsController.Telegraph(p.Position, p.Radius, p.Time)
end
handlers.TitanDeath = function(p)
	EffectsController.TitanDeath(p.Model, p.Height)
end
handlers.Sever = function(p)
	local center = modelCenter(p.Model)
	if center then
		EffectsController.Steam(center, 8, 10, 2, Color3.fromRGB(220, 150, 140))
	end
end
handlers.ArmorBreak = function(p)
	if p.Position then
		EffectsController.DebrisBurst(p.Position + Vector3.new(0, 20, 0), 16, 3, Color3.fromRGB(232, 222, 202), Enum.Material.Marble, 60)
		EffectsController.Flash(Color3.fromRGB(255, 255, 255), 0.25, 0.3)
	end
end
handlers.Rumbling = function(p)
	EffectsController.ShakeAt(p.Position, 1, 1500, 6)
	if C.SoundController then
		C.SoundController.Play("Roar", p.Position, { Range = 2000, Pitch = 0.18 })
	end
end
handlers.Explosion = function(p)
	EffectsController.Explosion(p.Position, p.Radius or 15, p.Big)
end
handlers.RangedShot = function(p)
	if p.Shooter == player then
		return
	end
	if p.Kind == "Lancia" or p.Kind == "Cannone" then
		EffectsController.Projectile(p.From, p.To, 0.35, "Spear", 1)
	elseif p.Kind == "Segnalatore" then
		EffectsController.Projectile(p.From, p.To, 0.5, "Spear", 1)
	else
		EffectsController.Tracer(p.From, p.To, p.Color)
	end
	if C.SoundController then
		C.SoundController.Play("Shot", p.From, { Range = 500 })
	end
end
handlers.SpearArmed = function(p)
	if typeof(p.Position) == "Vector3" then
		EffectsController.SpearArmed(p)
	end
end
handlers.Tracer = function(p)
	if p.Kind == "Spear" then
		EffectsController.Projectile(p.From, p.To, 0.35, "Spear", 1)
	else
		EffectsController.Tracer(p.From, p.To)
	end
	if C.SoundController then
		C.SoundController.Play("Shot", p.From, { Range = 400 })
	end
end
handlers.EnemyHop = function(p)
	local center = modelCenter(p.Model)
	if center then
		EffectsController.Steam(center, 2, 8, 0.8)
		if C.SoundController then
			C.SoundController.Play("Gas", center, { Range = 200 })
		end
	end
end
handlers.EnemyDeath = function(p)
	local model = p.Model
	if model then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				tween(d, 2.5, { LocalTransparencyModifier = 1 })
			end
		end
	end
end
handlers.Awaken = function(p)
	EffectsController.Awaken(p.Character, p.Duration or 15)
end
handlers.SerumObtained = function(p)
	EffectsController.SerumObtained(p.Character, p.Color)
end
handlers.Inject = function(p)
	EffectsController.Inject(p.Character, p.Color)
end
handlers.TransformStart = function(p)
	EffectsController.TransformStart(p.Character, p.Height or 30)
end
handlers.TransformBurst = function(p)
	EffectsController.TransformBurst(p.Position, p.Height or 30)
end
handlers.TransformEnd = function(p)
	EffectsController.TransformEnd(p.Position, p.Height or 30)
end
handlers.TitanSkill = function(p)
	EffectsController.TitanSkill(p)
end
handlers.Footstep = function(p)
	EffectsController.Steam(p.Position, p.Size * 0.12, 6, 1.5, Color3.fromRGB(160, 140, 115))
	EffectsController.ShakeAt(p.Position, 0.35, p.Size * 6, 0.25)
end
handlers.Fade = function(p)
	C.UIController.Fade(p.Time or 0.6)
end
handlers.Voyage = function(_p)
	C.UIController.Fade(2.2)
	if C.Notifications then
		C.Notifications.Announce("In navigazione...", "Il mare è più grande di qualsiasi muro.", "Info", 1.6)
	end
	if C.SoundController then
		C.SoundController.Play("Splash")
	end
end

-- mondo aperto: un gigante che emerge dal mare, un forziere aperto
handlers.Splash = function(p)
	local size = p.Size or 20
	for i = 0, 3 do
		task.delay(i * 0.15, function()
			EffectsController.Steam(p.Position + Vector3.new(0, 2, 0), size * (0.4 + i * 0.15), 10, 1.8, Color3.fromRGB(226, 240, 250))
		end)
	end
	EffectsController.Shockwave(p.Position, size * 2, Color3.fromRGB(200, 230, 250), 1.2, 1)
	if C.SoundController then
		C.SoundController.Play("Splash", p.Position, { Range = 1200, Volume = 1, Pitch = 0.6 })
	end
end
handlers.TreasureOpen = function(p)
	local color = if p.Tier == "Leggendario" then Color3.fromRGB(255, 200, 80) elseif p.Tier == "Raro" then Color3.fromRGB(140, 200, 255) else Color3.fromRGB(255, 230, 160)
	EffectsController.Sparks(p.Position + Vector3.new(0, 2, 0), color, if p.Tier == "Leggendario" then 60 else 30, 30)
	EffectsController.Shockwave(p.Position, 10, color, 0.6, 1)
	if C.SoundController then
		C.SoundController.Play("Coins")
		C.SoundController.Play("Reward")
	end
	if C.CameraController then
		C.CameraController.Shake(0.15, 0.2)
	end
end

function EffectsController.Init(c)
	C = c
end

function EffectsController.Start()
	local existing = workspace:FindFirstChild("EffettiLocali")
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = "EffettiLocali"
		folder.Parent = workspace
	end
	local function dispatch(name, params)
		local handler = handlers[name]
		if handler and type(params) == "table" then
			local ok, err = pcall(handler, params)
			if not ok then
				warn("[Effetti] " .. name .. ": " .. tostring(err))
			end
		end
	end
	Net.Event("Effect").OnClientEvent:Connect(dispatch)
	Net.Unreliable("EffectFast").OnClientEvent:Connect(dispatch)
end

return EffectsController
