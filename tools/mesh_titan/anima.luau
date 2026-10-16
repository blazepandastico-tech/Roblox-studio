--[[
	Anima il gigante 3D con il codice VERO del gioco (TitanBuilder → MeshTitan, ProceduralAnimator,
	Poses.Titan) dentro il Roblox finto delle prove, e scrive la posizione di ogni parte del corpo
	fotogramma per fotogramma. tools/mesh_titan/video.py poi disegna i fotogrammi con il modello vero.

	Ingressi (preparati da video.py): MESH_PARTS (centro e misura delle parti SP_ nel .glb),
	MESH_JOINTS (segnaposto J_), MESH_LOOK, ANIM_HEIGHT, ANIM_FPS, ANIM_PLAN.
	Uscita: righe "R parte cframe" (riposo), "F n t" e "P parte cframe" per ogni fotogramma.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local TitanBuilder = require(SHARED.Anim.TitanBuilder)
local ProceduralAnimator = require(SHARED.Anim.ProceduralAnimator)
local Poses = require(SHARED.Anim.Poses)

local H = ANIM_HEIGHT
local model = TitanBuilder.Build({ Height = H, Look = "Vulcano", Seed = 3, Cinematic = true })
assert(model:GetAttribute("MeshTitan") == true, "il filmato non usa il modello 3D")
local root = model.PrimaryPart :: BasePart
local hip = model:GetAttribute("HipHeight") :: number

local PARTS = {
	"Hips", "Torso", "Head",
	"RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
}

local function fmt(cf: CFrame): string
	local c = { cf:GetComponents() }
	for i, v in c do
		c[i] = string.format("%.4f", v)
	end
	return table.concat(c, "\t")
end

-- posizione nel mondo di ogni parte seguendo le giunture dalla radice (come fa Roblox)
local motors = {}
for _, d in model:GetDescendants() do
	if d:IsA("Motor6D") then
		table.insert(motors, d)
	end
end
local function solve(rootCF: CFrame): { [string]: CFrame }
	local world: { [BasePart]: CFrame } = { [root] = rootCF }
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
	local out = {}
	for part, cf in world do
		out[part.Name] = cf
	end
	return out
end

local rest = solve(root.CFrame)
for _, name in PARTS do
	assert(rest[name], "manca la parte " .. name)
	LOG("R\t" .. name .. "\t" .. fmt(rest[name]))
end

local animator = ProceduralAnimator.new(model, true)
animator.PositionScale = H
animator.Context.Seed = 1.7
animator:SetLayer("Base", Poses.Titan.Locomotion, 1, 0, 10)

-- il piano: { t, azione, valore }. Azioni: "Clip" (nome), "Move" (0..1), "Speed" (studs/s)
local plan = ANIM_PLAN
local nextStep = 1
local speed = 0
local pos = Vector3.new(0, hip, 0)
local dt = 1 / ANIM_FPS
local frames = math.floor(ANIM_DURATION * ANIM_FPS + 0.5)
for f = 0, frames - 1 do
	local t = f * dt
	while plan[nextStep] and plan[nextStep][1] <= t + 1e-6 do
		local step = plan[nextStep]
		if step[2] == "Clip" then
			animator:Play(Poses.Titan.Clips[step[3]])
		elseif step[2] == "Move" then
			animator.Context.Move = step[3]
		elseif step[2] == "Speed" then
			speed = step[3]
		end
		nextStep += 1
	end
	animator:Update(dt)
	-- cammina verso il suo davanti (-Z)
	pos += Vector3.new(0, 0, -speed * dt)
	local cfs = solve(CFrame.new(pos))
	LOG(("F\t%d\t%.4f"):format(f, t))
	for _, name in PARTS do
		LOG("P\t" .. name .. "\t" .. fmt(cfs[name]))
	end
end
LOG("FINE")
