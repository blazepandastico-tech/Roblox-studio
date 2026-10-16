--[[
	MeshTitan - giganti fatti con modelli 3D importati (es. da Meshy)

	Il modello va importato in Studio dal file .glb preparato da tools/mesh_titan/convert.py
	e messo in ReplicatedStorage → ModelliGiganti, con il nome del suo aspetto (es. "GiganteFuria").
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
	Furia = Color3.fromRGB(150, 120, 88), -- il Gigante della Furia (boss, filmati e forma del siero)
	Colosso = Color3.fromRGB(128, 34, 32), -- il colosso anatomico senza pelle dei filmati (GiganteColosso.glb)
}

-- altri nomi accettati per il modello importato
MeshTitan.Aliases = {
	Furia = { "Redivivo" },
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

-- Cerca il modello importato: nella cartella ModelliGiganti (va bene anche "GiganteFuria").
-- Il nome è controllato solo nelle lettere: "GiganteColosso (1)" o "GiganteColosso.glb" vanno bene
-- (succede quando il browser rinomina il file scaricato due volte)
local function matches(name: string, look: string): boolean
	local lower = string.lower(name):gsub("%.glb$", ""):gsub("[^%a]", "")
	local names = { look }
	for _, alias in MeshTitan.Aliases[look] or {} do
		table.insert(names, alias)
	end
	for _, n in names do
		local wanted = string.lower(n)
		if lower == wanted or lower == "gigante" .. wanted then
			return true
		end
	end
	return false
end

local function findTemplate(look: string): Instance?
	local f = folder()
	if not f then
		return nil
	end
	for _, child in f:GetChildren() do
		if matches(child.Name, look) then
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

local problems: { [string]: string } = {}

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
		-- di solito: importato con "Unisci mesh" attivo (una sola parte) o il file .fbx originale
		problems[look] = ("%s. Reimporta Gigante%s.glb con \"Unisci mesh\" DISATTIVATO"):format(tostring(err), look)
		warn(("[Giganti 3D] Il modello '%s' non è valido: %s"):format(look, problems[look]))
		cache[look] = false
		return nil
	end
	cache[look] = body
	return body
end

function MeshTitan.Has(look: string): boolean
	return getBody(look) ~= nil
end

-- Perché un modello 3D è usato o no (per avvisare l'admin): ok, spiegazione
function MeshTitan.Status(look: string): (boolean, string)
	if getBody(look) then
		return true, ("Modello 3D '%s' pronto"):format(look)
	end
	if problems[look] then
		return false, ("Il modello Gigante%s c'è ma non è valido: %s"):format(look, problems[look])
	end
	return false, ("Modello 3D Gigante%s non importato: in Studio File → Importa 3D → Gigante%s.glb (\"Unisci mesh\" disattivato), poi Play"):format(look, look)
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

-- RIVESTIMENTO DEL GIOCATORE (forma di gigante del siero) ------------------------------------------
-- Ogni pezzo del modello viene saldato alla parte R15 corrispondente, partendo dalla sua articolazione,
-- e allungato perché combaci con le proporzioni del personaggio. Il corpo R15 resta (invisibile)
-- e continua a muovere tutto con le sue animazioni.

local SKIN = {
	{ R15 = "LowerTorso", Mesh = "Hips", Prox = "Root", Dist = "Waist", Child = "UpperTorso", Width = { "RightHip", "LeftHip", "RightUpperLeg", "LeftUpperLeg" } },
	{ R15 = "UpperTorso", Mesh = "Torso", Prox = "Waist", Dist = "Neck", Child = "Head", Width = { "RightShoulder", "LeftShoulder", "RightUpperArm", "LeftUpperArm" } },
	{ R15 = "Head", Mesh = "Head", Prox = "Neck" },
	{ R15 = "RightUpperArm", Mesh = "RightUpperArm", Prox = "RightShoulder", Dist = "RightElbow", Child = "RightLowerArm" },
	{ R15 = "RightLowerArm", Mesh = "RightLowerArm", Prox = "RightElbow", Dist = "RightWrist", Child = "RightHand" },
	{ R15 = "RightHand", Mesh = "RightHand", Prox = "RightWrist" },
	{ R15 = "LeftUpperArm", Mesh = "LeftUpperArm", Prox = "LeftShoulder", Dist = "LeftElbow", Child = "LeftLowerArm" },
	{ R15 = "LeftLowerArm", Mesh = "LeftLowerArm", Prox = "LeftElbow", Dist = "LeftWrist", Child = "LeftHand" },
	{ R15 = "LeftHand", Mesh = "LeftHand", Prox = "LeftWrist" },
	{ R15 = "RightUpperLeg", Mesh = "RightUpperLeg", Prox = "RightHip", Dist = "RightKnee", Child = "RightLowerLeg" },
	{ R15 = "RightLowerLeg", Mesh = "RightLowerLeg", Prox = "RightKnee", Dist = "RightAnkle", Child = "RightFoot" },
	{ R15 = "RightFoot", Mesh = "RightFoot", Prox = "RightAnkle" },
	{ R15 = "LeftUpperLeg", Mesh = "LeftUpperLeg", Prox = "LeftHip", Dist = "LeftKnee", Child = "LeftLowerLeg" },
	{ R15 = "LeftLowerLeg", Mesh = "LeftLowerLeg", Prox = "LeftKnee", Dist = "LeftAnkle", Child = "LeftFoot" },
	{ R15 = "LeftFoot", Mesh = "LeftFoot", Prox = "LeftAnkle" },
}

-- la Motor6D che attacca una parte R15 al suo genitore
local function motorOf(part: BasePart): Motor6D?
	for _, child in part:GetChildren() do
		if child:IsA("Motor6D") and child.Part1 == part then
			return child
		end
	end
	return nil
end

-- Riveste un personaggio R15 (già ingrandito) con il modello 3D.
-- Restituisce l'elenco delle parti R15 rivestite (da nascondere): vuoto se non è riuscito.
function MeshTitan.SkinCharacter(character: Model, look: string, folder: Instance): { BasePart }
	local skinned: { BasePart } = {}
	local body = getBody(look)
	if not body then
		return skinned
	end
	local J = body.Joints
	local s = character:GetExtentsSize().Y
	local problems = {}
	for _, entry in SKIN do
		local part = character:FindFirstChild(entry.R15) :: BasePart?
		local motor = part and motorOf(part)
		local info = body.Parts[entry.Mesh]
		if part and motor and info and J[entry.Prox] then
			local jointLocal = motor.C1.Position
			local kx, ky = 1, 1
			-- lunghezza dell'osso: il pezzo si allunga/accorcia come la parte del personaggio
			local child = entry.Child and character:FindFirstChild(entry.Child) :: BasePart?
			local childMotor = child and motorOf(child)
			if entry.Dist and childMotor and J[entry.Dist] then
				local lengthR15 = (childMotor.C0.Position - jointLocal).Magnitude
				local lengthMesh = (J[entry.Dist] - J[entry.Prox]).Magnitude * s
				if lengthMesh > 0.01 then
					ky = math.clamp(lengthR15 / lengthMesh, 0.5, 2)
				end
			end
			-- larghezza (spalle e anche): i pezzi delle braccia e delle gambe restano attaccati
			if entry.Width then
				local right = character:FindFirstChild(entry.Width[3]) :: BasePart?
				local left = character:FindFirstChild(entry.Width[4]) :: BasePart?
				local rm = right and motorOf(right)
				local lm = left and motorOf(left)
				if rm and lm and J[entry.Width[1]] and J[entry.Width[2]] then
					local widthR15 = math.abs(rm.C0.Position.X - lm.C0.Position.X)
					local widthMesh = math.abs(J[entry.Width[1]].X - J[entry.Width[2]].X) * s
					if widthMesh > 0.01 then
						kx = math.clamp(widthR15 / widthMesh, 0.5, 2)
					end
				end
			end
			local stretch = Vector3.new(s * kx, s * ky, s)
			local offset = (info.CFrame.Position - J[entry.Prox]) * stretch
			local rotation = info.CFrame.Rotation
			local piece = info.Source:Clone() :: BasePart
			piece.Name = "Pelle" .. entry.Mesh
			-- dimensione: ogni asse del pezzo prende l'allungamento dell'asse del corpo a cui corrisponde
			local function axisScale(axis: Vector3): number
				local d = rotation:VectorToWorldSpace(axis)
				return math.abs(d.X) * stretch.X + math.abs(d.Y) * stretch.Y + math.abs(d.Z) * stretch.Z
			end
			piece.Size = Vector3.new(info.Size.X * axisScale(Vector3.xAxis), info.Size.Y * axisScale(Vector3.yAxis), info.Size.Z * axisScale(Vector3.zAxis))
			piece.Anchored = false
			piece.CanCollide = false
			piece.CanTouch = false
			piece.CanQuery = false
			piece.Massless = true
			piece.CastShadow = true
			for _, extra in piece:GetChildren() do
				if not extra:IsA("SurfaceAppearance") and not extra:IsA("Decal") and not extra:IsA("Texture") then
					extra:Destroy()
				end
			end
			local c0 = CFrame.new(jointLocal + offset) * rotation
			piece.CFrame = part.CFrame * c0
			local weldInstance = Instance.new("Weld")
			weldInstance.Part0 = part
			weldInstance.Part1 = piece
			weldInstance.C0 = c0
			weldInstance.Parent = piece
			piece.Transparency = 0
			piece.Parent = folder
			table.insert(skinned, part)
			if entry.Mesh == "Head" or entry.Mesh == "Torso" then
				print(("[Giganti 3D] Pezzo %s: grandezza %.1f x %.1f x %.1f, distanza dalla parte del corpo %.1f"):format(entry.Mesh, piece.Size.X, piece.Size.Y, piece.Size.Z, (piece.Position - part.Position).Magnitude))
			end
		else
			table.insert(problems, ("%s (parte:%s giuntura:%s pezzo:%s punto:%s)"):format(entry.R15, tostring(part ~= nil), tostring(motor ~= nil), tostring(info ~= nil), tostring(J[entry.Prox] ~= nil)))
		end
	end
	print(("[Giganti 3D] Rivestimento '%s': %d pezzi su %d, altezza del gigante %.1f"):format(look, #skinned, #SKIN, s))
	if #problems > 0 then
		warn("[Giganti 3D] Parti non rivestite: " .. table.concat(problems, ", "))
	end
	-- troppo pochi pezzi: meglio l'aspetto di riserva che un gigante a metà
	if #skinned < 12 then
		folder:ClearAllChildren()
		return {}
	end
	return skinned
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
				if child:IsA("Model") and matches(child.Name, look) then
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
