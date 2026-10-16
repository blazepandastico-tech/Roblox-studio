--[[
	Esporta le pose del volo con i Rampini per tools/pose_photo.py: un cadetto (corpo R15 a blocchi con
	l'equipaggiamento vero di OutfitService) animato dal codice vero del gioco (Poses + ProceduralAnimator)
	in alcune situazioni del volo. Per ogni situazione: "F nome" e le parti "P" (stesso formato di scene_dump).
]]

local OutfitService = require(SERVER.Services.OutfitService)
local Poses = require(SHARED.Anim.Poses)
local ProceduralAnimator = require(SHARED.Anim.ProceduralAnimator)

local function f(n: number): string
	return string.format("%.3f", n)
end

local function newPart(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.Parent = model
	return p
end

local function motor(name: string, p0: BasePart, p1: BasePart, c0: CFrame, c1: CFrame)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = c0
	m.C1 = c1
	m.Parent = p1
	p1.CFrame = p0.CFrame * c0 * c1:Inverse()
end

-- corpo R15 a blocchi (misure del classico avatar a blocchi)
local function buildCadet(): Model
	local model = Instance.new("Model")
	model.Name = "Cadetto"
	local skin = Color3.fromRGB(226, 180, 148)
	local root = newPart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), skin)
	root.Transparency = 1
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model
	local lower = newPart(model, "LowerTorso", Vector3.new(2, 0.6, 1), CFrame.new(), skin)
	motor("Root", root, lower, CFrame.new(0, -0.7, 0), CFrame.new())
	local upper = newPart(model, "UpperTorso", Vector3.new(2, 1.4, 1), CFrame.new(), skin)
	motor("Waist", lower, upper, CFrame.new(0, 0.3, 0), CFrame.new(0, -0.7, 0))
	local head = newPart(model, "Head", Vector3.new(1.2, 1.2, 1.2), CFrame.new(), skin)
	motor("Neck", upper, head, CFrame.new(0, 0.7, 0), CFrame.new(0, -0.6, 0))
	for _, side in { -1, 1 } do
		local prefix = if side > 0 then "Right" else "Left"
		local ua = newPart(model, prefix .. "UpperArm", Vector3.new(1, 1.2, 1), CFrame.new(), skin)
		motor(prefix .. "Shoulder", upper, ua, CFrame.new(side * 1.5, 0.45, 0), CFrame.new(0, 0.45, 0))
		local la = newPart(model, prefix .. "LowerArm", Vector3.new(1, 1.1, 1), CFrame.new(), skin)
		motor(prefix .. "Elbow", ua, la, CFrame.new(0, -0.55, 0), CFrame.new(0, 0.5, 0))
		local hand = newPart(model, prefix .. "Hand", Vector3.new(1, 0.4, 1), CFrame.new(), skin)
		motor(prefix .. "Wrist", la, hand, CFrame.new(0, -0.55, 0), CFrame.new(0, 0.2, 0))
		local ul = newPart(model, prefix .. "UpperLeg", Vector3.new(1, 1.2, 1), CFrame.new(), skin)
		motor(prefix .. "Hip", lower, ul, CFrame.new(side * 0.5, -0.3, 0), CFrame.new(0, 0.6, 0))
		local ll = newPart(model, prefix .. "LowerLeg", Vector3.new(1, 1.2, 1), CFrame.new(), skin)
		motor(prefix .. "Knee", ul, ll, CFrame.new(0, -0.6, 0), CFrame.new(0, 0.6, 0))
		local foot = newPart(model, prefix .. "Foot", Vector3.new(1, 0.3, 1.2), CFrame.new(), Color3.fromRGB(46, 34, 28))
		motor(prefix .. "Ankle", ll, foot, CFrame.new(0, -0.6, 0), CFrame.new(0, 0.15, 0.1))
	end
	model.PrimaryPart = root
	OutfitService.Apply(model, {
		Uniform = "Falchi",
		Equipped = { Blade = "LameStandard" },
		Look = { HairStyle = "Corto", Hair = Color3.fromRGB(60, 42, 30) },
	})
	return model
end

-- ogni parte nella posa del momento (come scene_dump: le giunture modificate, le saldature seguono)
local function emitModel(model: Model)
	local root = model.PrimaryPart :: BasePart
	local motors = {}
	local links: { [BasePart]: { BasePart } } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			table.insert(motors, d)
		elseif (d:IsA("WeldConstraint") or d:IsA("Weld")) and d.Part0 and d.Part1 then
			local a, b = d.Part0 :: BasePart, d.Part1 :: BasePart
			links[a] = links[a] or {}
			links[b] = links[b] or {}
			table.insert(links[a], b)
			table.insert(links[b], a)
		end
	end
	local world: { [BasePart]: CFrame } = { [root] = root.CFrame }
	local changed = true
	while changed do
		changed = false
		for _, m in motors do
			local p0, p1 = m.Part0, m.Part1
			if p0 and p1 and world[p0] and not world[p1] then
				world[p1] = world[p0] * m.C0 * m.C1:Inverse()
				changed = true
			end
		end
	end
	local driver: { [BasePart]: BasePart } = {}
	local queue = {}
	for p in world do
		driver[p] = p
		table.insert(queue, p)
	end
	local qi = 1
	while qi <= #queue do
		local p = queue[qi]
		qi += 1
		for _, o in links[p] or {} do
			if not driver[o] then
				driver[o] = driver[p]
				table.insert(queue, o)
			end
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.98 then
			local drv = driver[d]
			local cf = if drv then world[drv] * drv.CFrame:Inverse() * d.CFrame else d.CFrame
			local shape = "Block"
			if d.ClassName == "Part" then
				shape = if d.Shape then d.Shape.Name else "Block"
			elseif d.ClassName == "WedgePart" then
				shape = "Wedge"
			end
			local c = { cf:GetComponents() }
			for i, v in c do
				c[i] = f(v)
			end
			local s = d.Size
			local col = d.Color
			LOG(table.concat({ "P", d.ClassName, shape, f(s.X), f(s.Y), f(s.Z), table.concat(c, "\t"), f(col.R), f(col.G), f(col.B), if d.Material then d.Material.Name else "Plastic", f(d.Transparency or 0), d.Name }, "\t"))
		end
	end
end

-- le situazioni del volo: velocità, accelerazione in avanti e velocità verticale
local STATES = {
	{ "Crociera", 0, 0 },
	{ "Spinta del gas", 160, 0 },
	{ "Frenata", -160, 0 },
	{ "Risalita", 0, 70 },
	{ "Discesa", 0, -70 },
}
for _, state in STATES do
	local model = buildCadet()
	local animator = ProceduralAnimator.new(model, false)
	animator:SetLayer("Fly", Poses.Human.ODMFly, 1, 2, 5)
	animator:SetLayer("Cloak", Poses.Human.Cloak, 1, 5, 6)
	local ctx = animator.Context
	ctx.Speed = 130
	ctx.Pitch = 90
	ctx.Roll = 0
	ctx.AccelFwd = state[2]
	ctx.VY = state[3]
	for _ = 1, 90 do
		animator:Update(1 / 30)
	end
	LOG("F\t" .. state[1])
	emitModel(model)
	model:Destroy()
end
LOG("FINE")
