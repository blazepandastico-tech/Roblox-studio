--[[
	Il colosso dei filmati aggrappato al Muro, con il codice VERO del gioco: TitanBuilder (modello 3D
	importato se c'è MESH_LOOK, altrimenti il colosso fatto con le parti), ProceduralAnimator,
	Poses.Titan e ArmReach.WallGrip come in "La Caduta del Muro". tools/mesh_titan/muro.py poi
	disegna i fotogrammi.

	Il set è come nel filmato: Muro lungo l'asse X con il centro in z = 0 (merli alti 165 e spessi 34),
	il gigante dietro (z = GIANT_Z) che guarda verso +Z.

	Ingressi: MESH_LOOK (o nil), MESH_PARTS, MESH_JOINTS, ANIM_HEIGHT, GIANT_Z, ANIM_PLAN, ANIM_SHOTS.
	Uscita: "S n nome forma sx sy sz r g b materiale" (una volta per parte visibile),
	"F t", "P n cframe" e "V posizione direzione" (getti di vapore) per ogni istante di ANIM_SHOTS.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

if MESH_LOOK then
	-- il "modello importato" come lo lascerebbe l'importer di Studio: parti SP_ e segnaposto J_
	local folder = Instance.new("Folder")
	folder.Name = "ModelliGiganti"
	folder.Parent = ReplicatedStorage
	local template = Instance.new("Model")
	template.Name = "Gigante" .. MESH_LOOK
	for name, info in MESH_PARTS do
		local p = Instance.new("Part")
		p.Name = "SP_" .. name
		p.Size = info.Size
		p.CFrame = CFrame.new(info.Center)
		p.Parent = template
	end
	for name, pos in MESH_JOINTS do
		local p = Instance.new("Part")
		p.Name = "J_" .. name
		p.Size = Vector3.one * 0.04
		p.CFrame = CFrame.new(pos)
		p.Parent = template
	end
	template.Parent = folder
end

local TitanBuilder = require(SHARED.Anim.TitanBuilder)
local ProceduralAnimator = require(SHARED.Anim.ProceduralAnimator)
local Poses = require(SHARED.Anim.Poses)
local ArmReach = require(SHARED.Anim.ArmReach)

local H = ANIM_HEIGHT
local model = TitanBuilder.Build({ Height = H, Look = "Vulcano", Seed = 3, Cinematic = true })
local mesh = model:GetAttribute("MeshTitan") == true
assert(mesh == (MESH_LOOK ~= nil), "il filmato non usa il modello giusto")
LOG("MODELLO\t" .. (if mesh then "3D" else "parti"))
local root = model.PrimaryPart :: BasePart
local hip = model:GetAttribute("HipHeight") :: number
model:PivotTo(CFrame.new(0, hip, GIANT_Z) * CFrame.lookAt(Vector3.zero, Vector3.zAxis))

-- i getti di vapore del collo (TitanBuilder): la foto li disegna con le stesse misure
local steam = {}
for _, d in model:GetDescendants() do
	if d:IsA("ParticleEmitter") and d.Name == "VaporeCollo" and d.Parent and d.Parent:IsA("Attachment") then
		table.insert(steam, d.Parent)
	end
end
assert(#steam > 0, "manca il vapore del collo")
LOG(("VAPORE\t%d"):format(#steam))

local function fmt(cf: CFrame): string
	local c = { cf:GetComponents() }
	for i, v in c do
		c[i] = string.format("%.4f", v)
	end
	return table.concat(c, "\t")
end

-- chi muove ogni parte: le giunture (Motor6D) e, per i pezzi saldati, la parte a cui sono saldati
local motors = {}
local links: { [BasePart]: { BasePart } } = {}
local rest: { [BasePart]: CFrame } = {}
for _, d in model:GetDescendants() do
	if d:IsA("BasePart") then
		rest[d] = d.CFrame
	elseif d:IsA("Motor6D") then
		table.insert(motors, d)
	elseif (d:IsA("WeldConstraint") or d:IsA("Weld")) and d.Part0 and d.Part1 then
		local a, b = d.Part0 :: BasePart, d.Part1 :: BasePart
		links[a] = links[a] or {}
		links[b] = links[b] or {}
		table.insert(links[a], b)
		table.insert(links[b], a)
	end
end
local driver: { [BasePart]: BasePart } = { [root] = root }
local queue = { root }
for _, m in motors do
	if m.Part1 and not driver[m.Part1] then
		driver[m.Part1] = m.Part1
		table.insert(queue, m.Part1)
	end
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

-- le parti visibili (forma, misure, colore, materiale)
local visible = {}
for part in rest do
	if part.Transparency < 0.98 and driver[part] then
		table.insert(visible, part)
	end
end
table.sort(visible, function(a, b)
	return a.Name < b.Name
end)
for i, p in visible do
	local shape = "Block"
	if p.ClassName == "Part" then
		shape = if p.Shape then p.Shape.Name else "Block"
	elseif p.ClassName == "WedgePart" then
		shape = "Wedge"
	end
	local sm = p:FindFirstChildOfClass("SpecialMesh")
	if sm and sm.MeshType == Enum.MeshType.Sphere then
		shape = "Ellipsoid"
	end
	local s, c = p.Size, p.Color or Color3.new(0.6, 0.6, 0.6)
	LOG(("S\t%d\t%s\t%s\t%.4f\t%.4f\t%.4f\t%.4f\t%.4f\t%.4f\t%s"):format(i, p.Name, shape, s.X, s.Y, s.Z, c.R, c.G, c.B, if p.Material then p.Material.Name else "Plastic"))
end

-- posizione nel mondo di ogni parte seguendo le giunture dalla radice (come fa Roblox)
local function solve(): { [BasePart]: CFrame }
	local world: { [BasePart]: CFrame } = { [root] = root.CFrame }
	local changed = true
	while changed do
		changed = false
		for _, m in motors do
			local p0, p1 = m.Part0, m.Part1
			if p0 and p1 and world[p0] and not world[p1] then
				world[p1] = world[p0] * m.C0 * (m.Transform or CFrame.identity) * m.C1:Inverse()
				changed = true
			end
		end
	end
	return world
end

local animator = ProceduralAnimator.new(model, true)
animator.PositionScale = H
animator.Context.Seed = 1.7
animator:SetLayer("Base", Poses.Titan.Locomotion, 1, 0, 10)
-- come nel filmato: il bordo esterno in cima al Muro, il gigante guarda verso +Z
local grip = ArmReach.WallGrip(animator, H, Vector3.new(0, 165, -17), Vector3.zAxis)

-- il piano: { t, azione, valore }. Azioni: "Clip" (nome), "Grip" (peso, si avvicina in 1.1 s)
local plan = ANIM_PLAN
local nextStep = 1
local dt = 1 / 30
local shots = table.clone(ANIM_SHOTS)
table.sort(shots)
local t = 0
local shot = 1
while shots[shot] do
	while plan[nextStep] and plan[nextStep][1] <= t + 1e-6 do
		local step = plan[nextStep]
		if step[2] == "Clip" then
			animator:Play(Poses.Titan.Clips[step[3]])
		elseif step[2] == "Grip" then
			grip:Set(step[3], 1.1)
		end
		nextStep += 1
	end
	animator:Update(dt)
	if shots[shot] and t >= shots[shot] - 1e-6 then
		local world = solve()
		LOG(("F\t%.3f"):format(t))
		for i, p in visible do
			local d = driver[p]
			local cf = if d == p then world[p] else world[d] * rest[d]:Inverse() * rest[p]
			LOG(("P\t%d\t%s"):format(i, fmt(cf)))
		end
		for _, att in steam do
			local part = att.Parent :: BasePart
			local d = driver[part]
			local cf = world[d] * rest[d]:Inverse() * rest[part] * CFrame.new(att.Position)
			LOG(("V\t%.4f\t%.4f\t%.4f\t%.4f\t%.4f\t%.4f"):format(cf.X, cf.Y, cf.Z, cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z))
		end
		shot += 1
	end
	t += dt
end
LOG("FINE")
