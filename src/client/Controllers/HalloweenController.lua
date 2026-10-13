--[[
	HalloweenController - il mondo infestato del file di Halloween (solo grafica, sul client)
	Si accende solo con il tema di Halloween (Shared/Data/Tema):
	  • le zucche intagliate si illuminano al tramonto (la candela dentro) e si spengono all'alba;
	  • stormi di pipistrelli volano attorno al giocatore (al posto degli uccelli), di più di notte;
	  • fantasmi di lenzuolo compaiono vicino a te, fluttuano, ti guardano e svaniscono;
	  • nebbia viola bassa sul terreno e fuochi fatui verdi e arancioni nei prati di notte.
	Niente di tutto questo si tocca o ferma i rampini. Si spegne con Menu → Impostazioni →
	"Dettagli ambientali", come il resto della natura.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tema = require(ReplicatedStorage:WaitForChild("Shared").Data.Tema)

local HalloweenController = {}
local C

local rng = Random.new()
local folder: Folder

local CANDLE = Tema.Colors.Candle
local CARVED_DARK = Color3.fromRGB(46, 22, 10)

local function enabled(): boolean
	return C.ClientData == nil or C.ClientData.Setting == nil or C.ClientData.Setting("Scenery", true) ~= false
end

local function cameraPosition(): Vector3
	local camera = workspace.CurrentCamera
	return if camera then camera.CFrame.Position else Vector3.zero
end

local function isNight(): boolean
	local t = Lighting.ClockTime
	return t >= 18 or t < 6.5
end

local function underground(): boolean
	return cameraPosition().Y < -120
end

local function localPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "Parent" and k ~= "Shape" then
			(p :: any)[k] = v
		end
	end
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Parent = props.Parent or folder
	return p
end

local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.FilterDescendantsInstances = { workspace.Terrain }

local function groundBelow(p: Vector3): number?
	local hit = workspace:Raycast(p + Vector3.new(0, 60, 0), Vector3.new(0, -260, 0), terrainParams)
	return if hit then hit.Position.Y else nil
end

-- ZUCCHE ACCESE ---------------------------------------------------------------------------------------

local function setCarved(p: BasePart, lit: boolean)
	if p:GetAttribute("Accesa") == lit then
		return
	end
	p:SetAttribute("Accesa", lit)
	p.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Color = if lit then CANDLE else CARVED_DARK
end

function HalloweenController.RefreshPumpkins()
	local lit = isNight()
	for _, p in CollectionService:GetTagged(Tema.Tags.Carved) do
		if p:IsA("BasePart") then
			setCarved(p, lit)
		end
	end
end

-- PIPISTRELLI -----------------------------------------------------------------------------------------

type Bat = { Body: Part, Left: Part, Right: Part, Offset: Vector3, Phase: number }
type Flock = { Center: Vector3, Radius: number, Height: number, Angle: number, Speed: number, Bats: { Bat } }
local flocks: { Flock } = {}
local batY: number? = nil
local BAT = Color3.fromRGB(24, 16, 30)

local function makeFlock(center: Vector3): Flock
	local flock: Flock = {
		Center = center,
		Radius = rng:NextNumber(40, 90),
		Height = rng:NextNumber(30, 70),
		Angle = rng:NextNumber(0, math.pi * 2),
		Speed = rng:NextNumber(0.35, 0.6) * (if rng:NextNumber() < 0.5 then -1 else 1),
		Bats = {},
	}
	for _ = 1, rng:NextInteger(6, 11) do
		table.insert(flock.Bats, {
			Body = localPart({ Name = "Pipistrello", Size = Vector3.new(0.45, 0.4, 0.8), Color = BAT }),
			Left = localPart({ Name = "Ala", Size = Vector3.new(1.3, 0.06, 0.7), Color = BAT }),
			Right = localPart({ Name = "Ala", Size = Vector3.new(1.3, 0.06, 0.7), Color = BAT }),
			Offset = Vector3.new(rng:NextNumber(-7, 7), rng:NextNumber(-4, 4), rng:NextNumber(-7, 7)),
			Phase = rng:NextNumber(0, math.pi * 2),
		})
	end
	return flock
end

local function clearFlocks()
	for _, flock in flocks do
		for _, bat in flock.Bats do
			bat.Body:Destroy()
			bat.Left:Destroy()
			bat.Right:Destroy()
		end
	end
	table.clear(flocks)
end

local function updateBats(t: number, dt: number)
	local want = if enabled() and not underground() then (if isNight() then 4 else 2) else 0
	while #flocks > want do
		local flock = table.remove(flocks) :: Flock
		for _, bat in flock.Bats do
			bat.Body:Destroy()
			bat.Left:Destroy()
			bat.Right:Destroy()
		end
	end
	if want == 0 then
		return
	end
	local cam = cameraPosition()
	local ground = groundBelow(cam) or cam.Y - 20
	batY = if batY then batY + (ground - batY) * math.min(1, dt * 0.5) else ground
	while #flocks < want do
		local a = rng:NextNumber(0, math.pi * 2)
		table.insert(flocks, makeFlock(cam + Vector3.new(math.cos(a) * 80, 0, math.sin(a) * 80)))
	end
	local parts: { BasePart }, cframes: { CFrame } = {}, {}
	for _, flock in flocks do
		local flat = Vector3.new(cam.X - flock.Center.X, 0, cam.Z - flock.Center.Z)
		if flat.Magnitude > 220 then
			flock.Center += flat * math.min(1, dt * 0.4)
		end
		flock.Angle += flock.Speed * dt
		local a = flock.Angle
		-- volo a zig-zag: i pipistrelli non volano in cerchio perfetto come gli uccelli
		local wobble = math.sin(t * 1.7 + flock.Radius) * 8
		local pos = Vector3.new(flock.Center.X + math.cos(a) * (flock.Radius + wobble), (batY or cam.Y) + flock.Height + math.sin(t * 2.3) * 4, flock.Center.Z + math.sin(a) * (flock.Radius + wobble))
		local forward = Vector3.new(-math.sin(a), 0, math.cos(a)) * math.sign(flock.Speed)
		local frame = CFrame.lookAt(pos, pos + forward)
		for _, bat in flock.Bats do
			local jitter = Vector3.new(math.sin(t * 3 + bat.Phase) * 1.5, math.sin(t * 4.1 + bat.Phase) * 1.2, math.cos(t * 2.6 + bat.Phase) * 1.5)
			local cf = frame * CFrame.new(bat.Offset + jitter)
			local flap = math.sin(t * 18 + bat.Phase) * 0.9
			table.insert(parts, bat.Body)
			table.insert(cframes, cf)
			table.insert(parts, bat.Left)
			table.insert(cframes, cf * CFrame.new(-0.2, 0, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-0.65, 0, 0))
			table.insert(parts, bat.Right)
			table.insert(cframes, cf * CFrame.new(0.2, 0, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(0.65, 0, 0))
		end
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- FANTASMI ------------------------------------------------------------------------------------------------

type Ghost = { Model: Model, Parts: { BasePart }, Base: { [BasePart]: number }, Home: Vector3, Phase: number, Born: number, Life: number, Fade: number, Dir: Vector3 }
local ghosts: { Ghost } = {}

local function buildGhost(at: Vector3): Ghost
	local model = Instance.new("Model")
	model.Name = "Fantasma"
	local s = rng:NextNumber(0.9, 1.4)
	local white = Color3.fromRGB(236, 244, 255)
	local parts: { BasePart } = {}
	local base: { [BasePart]: number } = {}
	local function add(p: BasePart, alpha: number)
		p.Parent = model
		table.insert(parts, p)
		base[p] = alpha
	end
	add(localPart({ Name = "Testa", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4 * s, Color = white, Parent = model }), 0.25)
	add(localPart({ Name = "Corpo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6 * s, 2.4 * s, 2.4 * s), Color = white, Parent = model }), 0.25)
	for i = 0, 4 do
		add(localPart({ Name = "Orlo" .. i, Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9 * s, Color = white, Parent = model }), 0.3)
	end
	for _, name in { "OcchioS", "OcchioD", "Bocca" } do
		local eye = localPart({ Name = name, Size = Vector3.new(0.42, if name == "Bocca" then 0.6 else 0.62, 0.2) * s, Color = Color3.fromRGB(18, 16, 28), Parent = model })
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = eye
		add(eye, 0)
	end
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(170, 220, 255)
	glow.Range = 12
	glow.Brightness = 0.8
	glow.Shadows = false
	glow.Parent = parts[1]
	for _, p in parts do
		p.Transparency = 1
	end
	model.Parent = folder
	return {
		Model = model,
		Parts = parts,
		Base = base,
		Home = at,
		Phase = rng:NextNumber(0, math.pi * 2),
		Born = os.clock(),
		Life = rng:NextNumber(14, 30),
		Fade = 0,
		Dir = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit,
	}
end

local function removeGhost(i: number)
	local g = table.remove(ghosts, i)
	if g then
		g.Model:Destroy()
	end
end

local function placeGhost(g: Ghost, t: number)
	local cam = cameraPosition()
	local age = os.clock() - g.Born
	local pos = g.Home + g.Dir * age * 1.6 + Vector3.new(0, math.sin(t * 1.3 + g.Phase) * 0.8, 0)
	local look = Vector3.new(cam.X, pos.Y, cam.Z)
	local cf = if (look - pos).Magnitude > 0.1 then CFrame.lookAt(pos, look) else CFrame.new(pos)
	-- si dondola un po', come un lenzuolo nel vento
	cf *= CFrame.Angles(0, 0, math.sin(t * 0.9 + g.Phase) * 0.08)
	local s = g.Parts[1].Size.X / 2.4
	local p = g.Parts
	p[1].CFrame = cf
	p[2].CFrame = cf * CFrame.new(0, -1.3 * s, 0) * CFrame.Angles(0, 0, math.rad(90))
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2 + t * 0.6
		p[3 + i].CFrame = cf * CFrame.new(math.cos(a) * 0.85 * s, -2.6 * s + math.sin(t * 3 + i) * 0.12, math.sin(a) * 0.85 * s)
	end
	p[8].CFrame = cf * CFrame.new(-0.42 * s, 0.15 * s, -1.12 * s)
	p[9].CFrame = cf * CFrame.new(0.42 * s, 0.15 * s, -1.12 * s)
	p[10].CFrame = cf * CFrame.new(0, -0.55 * s + math.sin(t * 2 + g.Phase) * 0.05, -1.08 * s)
	-- compare e svanisce piano
	local fade = math.clamp(math.min(age / 2.5, (g.Life - age) / 2.5), 0, 1)
	-- da vicino diventa più trasparente (non copre la visuale)
	local d = (pos - cam).Magnitude
	local near = math.clamp((d - 8) / 14, 0.25, 1)
	for _, part in p do
		part.Transparency = 1 - (1 - g.Base[part]) * fade * near
	end
end

local nextGhost = 0
local function updateGhosts(t: number)
	local want = if enabled() and not underground() then (if isNight() then 4 else 1) else 0
	for i = #ghosts, 1, -1 do
		local g = ghosts[i]
		local age = os.clock() - g.Born
		if age > g.Life or i > want or (g.Home - cameraPosition()).Magnitude > 260 then
			removeGhost(i)
		end
	end
	if #ghosts < want and os.clock() >= nextGhost then
		nextGhost = os.clock() + rng:NextNumber(3, 8)
		local cam = workspace.CurrentCamera
		if cam then
			local look = cam.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			local dir = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(0, 0, -1)
			local angle = math.atan2(dir.Z, dir.X) + rng:NextNumber(-0.9, 0.9)
			local dist = rng:NextNumber(30, 75)
			local at = cam.CFrame.Position + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
			local ground = groundBelow(at)
			if ground and ground > -100 then
				table.insert(ghosts, buildGhost(Vector3.new(at.X, ground + rng:NextNumber(4, 9), at.Z)))
				if C.SoundController and rng:NextNumber() < 0.5 then
					C.SoundController.Play("Spettro", at, { Volume = 0.35, Pitch = rng:NextNumber(0.5, 0.7), Range = 120 })
				end
			end
		end
	end
	for _, g in ghosts do
		placeGhost(g, t)
	end
end

-- NEBBIA BASSA E FUOCHI FATUI ---------------------------------------------------------------------------------

local fogPart: Part? = nil
local fog: ParticleEmitter? = nil
local wisps: ParticleEmitter? = nil

local function buildAir()
	local p = localPart({ Name = "NebbiaHalloween", Size = Vector3.new(170, 2, 170), Transparency = 1, Parent = workspace.CurrentCamera })
	fogPart = p
	local f = Instance.new("ParticleEmitter")
	f.Name = "Nebbia"
	f.Texture = "rbxasset://textures/particles/smoke_main.dds"
	f.Color = ColorSequence.new(Color3.fromRGB(196, 176, 220), Color3.fromRGB(150, 130, 190))
	f.LightInfluence = 0.9
	f.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.86), NumberSequenceKeypoint.new(0.7, 0.88), NumberSequenceKeypoint.new(1, 1) })
	f.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(1, 22) })
	f.Lifetime = NumberRange.new(9, 14)
	f.Speed = NumberRange.new(0.3, 1.2)
	f.SpreadAngle = Vector2.new(180, 10)
	f.Rotation = NumberRange.new(0, 360)
	f.RotSpeed = NumberRange.new(-6, 6)
	f.Shape = Enum.ParticleEmitterShape.Box
	f.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	f.WindAffectsDrag = true
	f.Drag = 0.4
	f.Rate = 0
	f.Parent = p
	fog = f
	local w = Instance.new("ParticleEmitter")
	w.Name = "FuochiFatui"
	w.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	w.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 255, 110)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 170, 70)), ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 120, 255)) })
	w.LightEmission = 1
	w.LightInfluence = 0
	w.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.55), NumberSequenceKeypoint.new(0.8, 0.45), NumberSequenceKeypoint.new(1, 0) })
	w.Lifetime = NumberRange.new(4, 7)
	w.Speed = NumberRange.new(0.3, 1.2)
	w.SpreadAngle = Vector2.new(180, 180)
	w.Acceleration = Vector3.new(0, 0.25, 0)
	w.Shape = Enum.ParticleEmitterShape.Box
	w.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	w.Rate = 0
	w.Parent = p
	wisps = w
end

local fogGround = 0
local function updateAir()
	local p, f, w = fogPart, fog, wisps
	if not (p and f and w) then
		return
	end
	local cam = cameraPosition()
	local g = groundBelow(cam)
	if g then
		fogGround = g
	end
	local on = enabled() and not underground() and g ~= nil and cam.Y - fogGround < 160
	local night = isNight()
	f.Rate = if on then (if night then 9 else 4) else 0
	w.Rate = if on and night then 7 else 0
end

local function followCamera()
	local p = fogPart
	if p then
		local cam = cameraPosition()
		p.CFrame = CFrame.new(cam.X, fogGround + 2.5, cam.Z)
	end
end

-- AVVIO ------------------------------------------------------------------------------------------------------

function HalloweenController.IsActive(): boolean
	return Tema.IsHalloween()
end

function HalloweenController.Init(c)
	C = c
end

function HalloweenController.Start()
	if not Tema.IsHalloween() then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "HalloweenLocale"
	folder.Parent = workspace
	buildAir()
	CollectionService:GetInstanceAddedSignal(Tema.Tags.Carved):Connect(function(p)
		if p:IsA("BasePart") then
			setCarved(p, isNight())
		end
	end)
	HalloweenController.RefreshPumpkins()
	RunService.RenderStepped:Connect(followCamera)
	local t = 0
	RunService.Heartbeat:Connect(function(dt)
		t += dt
		local ok, err = pcall(function()
			updateBats(t, dt)
			updateGhosts(t)
		end)
		if not ok then
			warn("[Halloween] " .. tostring(err))
		end
	end)
	task.spawn(function()
		while true do
			pcall(HalloweenController.RefreshPumpkins)
			pcall(updateAir)
			task.wait(2)
		end
	end)
end

-- per le prove: un passo di tutto, subito
function HalloweenController.Step(t: number, dt: number)
	updateBats(t, dt)
	updateGhosts(t)
	updateAir()
	followCamera()
end

HalloweenController.ClearBats = clearFlocks

return HalloweenController
