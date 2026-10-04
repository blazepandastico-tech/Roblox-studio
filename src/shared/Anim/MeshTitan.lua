--[[
	MeshTitan - giganti fatti con modelli 3D importati (es. da Meshy)

	Il modello va importato in Studio dal file .glb preparato da tools/mesh_titan/convert.py
	e messo in ReplicatedStorage → ModelliGiganti, con il nome del suo aspetto (es. "Redivivo").
	Contiene:
	  • 15 parti del corpo "SP_Head", "SP_Torso", "SP_RightUpperArm"... (MeshPart con texture)
	  • segnaposto "J_Neck", "J_RightElbow"... nei punti delle articolazioni
	Qui le parti vengono copiate, ridimensionate all'altezza voluta e collegate con Motor6D
	che hanno gli STESSI nomi dei giganti costruiti via codice: così funzionano tutte le
	animazioni, la nuca, gli occhi, le braccia e le gambe tagliabili.
	Se il modello non c'è, TitanBuilder usa l'aspetto procedurale di riserva.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MeshTitan = {}

local FOLDER = "ModelliGiganti"

-- nome dell'aspetto → colore medio della pelle (per le giunture)
MeshTitan.Skins = {
	Redivivo = Color3.fromRGB(150, 120, 88),
}

local PARTS = {
	"Head", "Torso", "Hips",
	"RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperLeg", "RightLowerLeg", "RightFoot",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
}

-- giuntura, parte0, parte1, segnaposto
local JOINTS = {
	{ "Waist", "Hips", "Torso", "Waist" },
	{ "Neck", "Torso", "Head", "Neck" },
	{ "RightShoulder", "Torso", "RightUpperArm", "RightShoulder" },
	{ "RightElbow", "RightUpperArm", "RightLowerArm", "RightElbow" },
	{ "RightWrist", "RightLowerArm", "RightHand", "RightWrist" },
	{ "LeftShoulder", "Torso", "LeftUpperArm", "LeftShoulder" },
	{ "LeftElbow", "LeftUpperArm", "LeftLowerArm", "LeftElbow" },
	{ "LeftWrist", "LeftLowerArm", "LeftHand", "LeftWrist" },
	{ "RightHip", "Hips", "RightUpperLeg", "RightHip" },
	{ "RightKnee", "RightUpperLeg", "RightLowerLeg", "RightKnee" },
	{ "RightAnkle", "RightLowerLeg", "RightFoot", "RightAnkle" },
	{ "LeftHip", "Hips", "LeftUpperLeg", "LeftHip" },
	{ "LeftKnee", "LeftUpperLeg", "LeftLowerLeg", "LeftKnee" },
	{ "LeftAnkle", "LeftLowerLeg", "LeftFoot", "LeftAnkle" },
}

local LIMB = {
	RightUpperArm = "RightArm", RightLowerArm = "RightArm", RightHand = "RightArm",
	LeftUpperArm = "LeftArm", LeftLowerArm = "LeftArm", LeftHand = "LeftArm",
	RightUpperLeg = "RightLeg", RightLowerLeg = "RightLeg", RightFoot = "RightLeg",
	LeftUpperLeg = "LeftLeg", LeftLowerLeg = "LeftLeg", LeftFoot = "LeftLeg",
}

-- giunture coperte da una sfera color pelle (nasconde le fessure quando l'arto si piega)
local COVERS = {
	{ "RightElbow", "RightLowerArm", 0.032 }, { "LeftElbow", "LeftLowerArm", 0.032 },
	{ "RightKnee", "RightLowerLeg", 0.045 }, { "LeftKnee", "LeftLowerLeg", 0.045 },
	{ "RightWrist", "RightHand", 0.024 }, { "LeftWrist", "LeftHand", 0.024 },
	{ "RightAnkle", "RightFoot", 0.03 }, { "LeftAnkle", "LeftFoot", 0.03 },
}

local cache: { [string]: any } = {}

local function folder(): Instance?
	return ReplicatedStorage:FindFirstChild(FOLDER)
end

-- Cerca il modello importato: nella cartella ModelliGiganti (anche "GiganteRedivivo" va bene)
local function findTemplate(look: string): Instance?
	local f = folder()
	if not f then
		return nil
	end
	local wanted = string.lower(look)
	for _, child in f:GetChildren() do
		local name = string.lower(child.Name)
		if name == wanted or name == "gigante" .. wanted then
			return child
		end
	end
	return nil
end

-- Legge parti e segnaposto del modello e calcola il suo sistema di riferimento
local function analyze(template: Instance)
	local parts: { [string]: BasePart } = {}
	local joints: { [string]: Vector3 } = {}
	for _, d in template:GetDescendants() do
		if d:IsA("BasePart") then
			local p = d.Name:match("^SP_(%a+)")
			local j = d.Name:match("^J_(%a+)")
			if p then
				parts[p] = d
			elseif j then
				joints[j] = d.Position
			end
		end
	end
	for _, name in PARTS do
		if not parts[name] then
			return nil, "manca la parte SP_" .. name
		end
	end
	for _, name in { "Ground", "HeadTop", "Root", "Waist", "Neck", "RightShoulder", "LeftShoulder", "Nape" } do
		if not joints[name] then
			return nil, "manca il segnaposto J_" .. name
		end
	end
	local ground, top = joints.Ground, joints.HeadTop
	local up = (top - ground).Unit
	local across = joints.RightShoulder - joints.LeftShoulder
	local right = (across - up * across:Dot(up)).Unit
	local frame = CFrame.fromMatrix(ground, right, up)
	local height = (top - ground):Dot(up)
	-- tutto nello spazio del corpo (altezza = 1): non importa come l'importer ha ruotato o scalato il modello
	local body = { Parts = {}, Joints = {} }
	for name, part in parts do
		local rel = frame:ToObjectSpace(part.CFrame)
		body.Parts[name] = {
			Source = part,
			CFrame = CFrame.new(rel.Position / height) * rel.Rotation,
			Size = part.Size / height,
		}
	end
	for name, pos in joints do
		body.Joints[name] = frame:PointToObjectSpace(pos) / height
	end
	return body, nil
end

local function getBody(look: string)
	local hit = cache[look]
	if hit ~= nil then
		return if hit == false then nil else hit
	end
	local template = findTemplate(look)
	if not template then
		return nil
	end
	local body, err = analyze(template)
	if not body then
		warn(("[Giganti 3D] Il modello '%s' non è valido: %s"):format(look, tostring(err)))
		cache[look] = false
		return nil
	end
	cache[look] = body
	return body
end

function MeshTitan.Has(look: string): boolean
	return getBody(look) ~= nil
end

local function invisiblePart(model: Instance, name: string, size: Vector3, cf: CFrame, zone: string?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Transparency = 1
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = zone ~= nil
	p.Massless = true
	p.CastShadow = false
	if zone then
		p:SetAttribute("HitZone", zone)
	end
	p.Parent = model
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

-- Costruisce il gigante. params come TitanBuilder.Build (Height, Look, Seed, Name, CFrame)
function MeshTitan.Build(params): Model?
	local look: string = params.Look
	local body = getBody(look)
	if not body then
		return nil
	end
	local H: number = params.Height or 22
	local J = body.Joints
	local function at(name: string): Vector3
		return (J[name] or J.Root) * H
	end
	local hipY = at("Root").Y
	local base: CFrame = params.CFrame or CFrame.new(0, hipY, 0)
	-- origine (a terra) del gigante nello spazio del mondo
	local rootLocal = at("Root")
	local origin = base * CFrame.new(-rootLocal)
	local function world(p: Vector3): CFrame
		return origin * CFrame.new(p)
	end

	local model = Instance.new("Model")
	model.Name = params.Name or "Gigante"

	local root = invisiblePart(model, "Root", Vector3.new(0.1, 0.08, 0.08) * H, base, nil)
	root.Massless = false

	local parts: { [string]: BasePart } = {}
	for _, name in PARTS do
		local info = body.Parts[name]
		local part = info.Source:Clone() :: BasePart
		part.Name = name
		part.Size = info.Size * H
		part.CFrame = origin * CFrame.new(info.CFrame.Position * H) * info.CFrame.Rotation
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = true
		part.Massless = true
		part.CastShadow = true
		part:SetAttribute("HitZone", LIMB[name] or "Body")
		if LIMB[name] then
			part:SetAttribute("Limb", LIMB[name])
		end
		for _, child in part:GetChildren() do
			if not child:IsA("SurfaceAppearance") and not child:IsA("Decal") and not child:IsA("Texture") then
				child:Destroy()
			end
		end
		part.Parent = model
		parts[name] = part
	end

	local function motor(name: string, part0: BasePart, part1: BasePart, pivot: CFrame)
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = part0
		m.Part1 = part1
		m.C0 = part0.CFrame:ToObjectSpace(pivot)
		m.C1 = part1.CFrame:ToObjectSpace(pivot)
		m.Parent = part1
	end
	motor("Root", root, parts.Hips, world(at("Root")))
	for _, j in JOINTS do
		motor(j[1], parts[j[2]], parts[j[3]], world(at(j[4])))
	end

	-- mandibola (invisibile: serve alle animazioni del morso e dell'urlo)
	local jaw = invisiblePart(model, "Jaw", Vector3.new(0.05, 0.03, 0.04) * H, world(at("Mouth")), nil)
	motor("Jaw", parts.Head, jaw, world(at("Mouth")))

	-- NUCA: il punto debole, invisibile, saldato al busto
	local nape = invisiblePart(model, "Nape", Vector3.new(0.065, 0.055, 0.04) * H, world(at("Nape")), "Nape")
	weld(parts.Torso, nape)
	local napeAtt = Instance.new("Attachment")
	napeAtt.Name = "NapeAtt"
	napeAtt.Parent = nape

	-- occhi colpibili (accecano il gigante)
	for _, side in { "Right", "Left" } do
		if J[side .. "Eye"] then
			local eye = invisiblePart(model, side .. "Eye", Vector3.new(0.018, 0.014, 0.014) * H, world(at(side .. "Eye")), "Eye")
			weld(parts.Head, eye)
		end
	end

	-- sfere color pelle sulle giunture
	local skin = MeshTitan.Skins[look] or Color3.fromRGB(190, 150, 120)
	for _, c in COVERS do
		local parent = parts[c[2]]
		if J[c[1]] then
			local ball = Instance.new("Part")
			ball.Name = "Giuntura" .. c[1]
			ball.Shape = Enum.PartType.Ball
			ball.Size = Vector3.one * c[3] * H
			ball.CFrame = world(at(c[1]))
			ball.Color = skin
			ball.Material = Enum.Material.SmoothPlastic
			ball.Anchored = false
			ball.CanCollide = false
			ball.CanTouch = false
			ball.CanQuery = false
			ball.Massless = true
			ball.CastShadow = false
			ball:SetAttribute("Limb", parent:GetAttribute("Limb"))
			ball.Parent = model
			weld(parent, ball)
		end
	end

	-- attacchi per effetti, prese e interfaccia (stessi nomi dei giganti procedurali)
	local function attach(part: BasePart, name: string, pointName: string)
		local a = Instance.new("Attachment")
		a.Name = name
		a.WorldPosition = world(at(pointName)).Position
		a.Parent = part
	end
	attach(parts.Head, "HeadTopAtt", "HeadTop")
	attach(parts.Head, "MouthAtt", "Mouth")
	attach(parts.RightHand, "RightHandAtt", "RightHandTip")
	attach(parts.LeftHand, "LeftHandAtt", "LeftHandTip")
	local steam = Instance.new("Attachment")
	steam.Name = "SteamAtt"
	steam.Parent = parts.Torso

	model.PrimaryPart = root
	model:SetAttribute("Height", H)
	model:SetAttribute("HipHeight", hipY)
	model:SetAttribute("Look", look)
	model:SetAttribute("Seed", params.Seed or 1)
	model:SetAttribute("HeadTilt", 0)
	model:SetAttribute("Archetype", "")
	model:SetAttribute("CrawlPreferred", false)
	model:SetAttribute("JawIdle", 0)
	model:SetAttribute("Hunch", false)
	model:SetAttribute("MeshTitan", true)
	return model
end

-- Sul server: se il modello importato è rimasto nel Workspace, lo sposta nella cartella giusta
function MeshTitan.CollectTemplates()
	if not RunService:IsServer() then
		return
	end
	local f = folder()
	if not f then
		f = Instance.new("Folder")
		f.Name = FOLDER
		f.Parent = ReplicatedStorage
	end
	for look in MeshTitan.Skins do
		if not findTemplate(look) then
			for _, child in workspace:GetChildren() do
				local name = string.lower(child.Name)
				if child:IsA("Model") and (name == string.lower(look) or name == "gigante" .. string.lower(look)) then
					child.Parent = f
					print(("[Giganti 3D] Modello '%s' spostato in ReplicatedStorage → %s"):format(child.Name, FOLDER))
				end
			end
		end
		local template = findTemplate(look)
		if template then
			-- il modello di riferimento non deve cadere né essere colpito
			for _, d in template:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
				end
			end
			print(("[Giganti 3D] Modello '%s' %s"):format(look, if MeshTitan.Has(look) then "pronto" else "NON valido (vedi l'avviso sopra)"))
		else
			print(("[Giganti 3D] Modello '%s' non importato: uso l'aspetto di riserva"):format(look))
		end
	end
end

return MeshTitan
