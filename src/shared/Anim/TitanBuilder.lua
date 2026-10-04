--[[
	TitanBuilder
	Costruisce i giganti interamente via codice (nessun modello da importare).
	Ogni parte del corpo è un ellissoide (SpecialMesh "Sphere") collegato con
	Motor6D che hanno gli STESSI nomi delle articolazioni R15: così le animazioni
	procedurali funzionano sia sui giocatori sia sui giganti.

	Ogni gigante puro è diverso (proporzioni, volto, capelli, pelle) grazie al seme.
	I mutaforma (Cacciatrice, Bastione, Vulcano, Fauno...) hanno un aspetto dedicato.
]]

local MeshTitan = require(script.Parent.MeshTitan)

local TitanBuilder = {}

local rad = math.rad

local SKIN_TONES = {
	Color3.fromRGB(236, 196, 166),
	Color3.fromRGB(226, 180, 148),
	Color3.fromRGB(214, 162, 128),
	Color3.fromRGB(240, 206, 182),
	Color3.fromRGB(200, 146, 114),
	Color3.fromRGB(222, 170, 140),
	Color3.fromRGB(190, 140, 112),
}

local HAIR_COLORS = {
	Color3.fromRGB(32, 26, 22),
	Color3.fromRGB(70, 48, 32),
	Color3.fromRGB(120, 84, 52),
	Color3.fromRGB(200, 170, 110),
	Color3.fromRGB(140, 140, 140),
}

local HAIR_STYLES = { "Calvo", "Corto", "Corto", "Lungo", "Ciuffo", "Riccio" }

local function darker(c: Color3, f: number): Color3
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

local function newPart(model: Instance, name: string, size: Vector3, color: Color3, cf: CFrame, opts)
	opts = opts or {}
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05))
	part.Color = color
	part.Material = opts.Material or Enum.Material.SmoothPlastic
	part.Reflectance = opts.Reflectance or 0
	part.Transparency = opts.Transparency or 0
	part.CFrame = cf
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = opts.Query ~= false
	part.Massless = true
	part.CastShadow = opts.Shadow ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if opts.Shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif opts.Shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	elseif opts.Shape ~= "Block" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	if opts.Zone then
		part:SetAttribute("HitZone", opts.Zone)
	end
	if opts.Limb then
		part:SetAttribute("Limb", opts.Limb)
	end
	part.Parent = model
	return part
end

-- Decorazione saldata a una parte del corpo (offset relativo alla parte)
local function decor(model: Instance, parent: BasePart, name: string, size: Vector3, color: Color3, offset: CFrame, opts)
	opts = opts or {}
	if opts.Query == nil then
		opts.Query = false
	end
	if opts.Shadow == nil then
		opts.Shadow = false
	end
	if opts.Limb == nil then
		opts.Limb = parent:GetAttribute("Limb")
	end
	local part = newPart(model, name, size, color, parent.CFrame * offset, opts)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function motor(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = c0
	m.C1 = c1
	m.Parent = part1
	return m
end

-- Corporature dei giganti puri, riprese dai giganti dell'immagine di riferimento ----------------
-- (escluso quello grande e peloso in alto). Ogni gigante puro ne riceve una a caso.
local ARCHETYPES = {
	{ Name = "Occhione", Weight = 2 }, -- piccolo e tozzo, testa enorme, occhioni azzurri, ghigno di denti, ciuffo
	{ Name = "Scodella", Weight = 3 }, -- striscia a quattro zampe, frangetta a scodella, denti digrignati
	{ Name = "Riga", Weight = 3 }, -- alto e normale, capelli corti con la riga, sorrisetto
	{ Name = "Calvo", Weight = 2 }, -- spilungone calvo e curvo, bocca spalancata
	{ Name = "Barbuto", Weight = 1 }, -- barba e capelli lunghi chiari
	{ Name = "Urlatore", Weight = 2 }, -- accucciato, capelli scuri, urla a bocca aperta
	{ Name = "Cresta", Weight = 2 }, -- bambinone paffuto con la cresta
	{ Name = "Occhietti", Weight = 2 }, -- calvo, occhi piccoli e denti scoperti, braccia tese
}

local PURE_SKIN = {
	Color3.fromRGB(214, 150, 120),
	Color3.fromRGB(198, 132, 104),
	Color3.fromRGB(226, 164, 136),
	Color3.fromRGB(184, 118, 92),
	Color3.fromRGB(232, 176, 150),
	Color3.fromRGB(206, 140, 116),
}

local function applyArchetype(p, rng: Random)
	local total = 0
	for _, a in ARCHETYPES do
		total += a.Weight
	end
	local roll = rng:NextNumber() * total
	local kind = ARCHETYPES[#ARCHETYPES].Name
	for _, a in ARCHETYPES do
		roll -= a.Weight
		if roll <= 0 then
			kind = a.Name
			break
		end
	end
	p.Archetype = kind
	p.Skin = PURE_SKIN[rng:NextInteger(1, #PURE_SKIN)]
	p.Sockets = true
	p.Lips = false
	p.Belly = 0
	if kind == "Occhione" then
		p.HeadMul = rng:NextNumber(2.0, 2.25)
		p.LegMul = rng:NextNumber(0.5, 0.6)
		p.ArmMul = rng:NextNumber(0.62, 0.72)
		p.TorsoMul = rng:NextNumber(0.75, 0.85)
		p.WidthMul = rng:NextNumber(1.1, 1.22)
		p.Belly = rng:NextNumber(1.0, 1.3)
		p.EyeSize = rng:NextNumber(2.6, 3.0)
		p.Iris = Color3.fromRGB(90, 150, 210)
		p.Pupil = 0.22
		p.MouthWidth = 0.9
		p.Grin = true
		p.BigTeeth = true
		p.Ears = 1.4
		p.HairStyle = "Ciuffo"
		p.Hair = Color3.fromRGB(60, 40, 28)
		p.Skin = Color3.fromRGB(232, 160, 150)
	elseif kind == "Scodella" then
		p.HeadMul = rng:NextNumber(1.15, 1.3)
		p.ThickMul = rng:NextNumber(0.7, 0.82)
		p.WidthMul = rng:NextNumber(0.85, 0.95)
		p.ArmMul = rng:NextNumber(1.1, 1.22)
		p.EyeSize = rng:NextNumber(0.75, 0.9)
		p.MouthWidth = rng:NextNumber(0.9, 1.0)
		p.Grin = true
		p.BigTeeth = true
		p.HairStyle = "Caschetto"
		p.Hair = Color3.fromRGB(78, 52, 34)
		p.Crawl = true
	elseif kind == "Riga" then
		p.HeadMul = rng:NextNumber(1.0, 1.1)
		p.LegMul = rng:NextNumber(0.95, 1.05)
		p.EyeSize = rng:NextNumber(0.85, 1.0)
		p.MouthWidth = rng:NextNumber(0.4, 0.5)
		p.Grin = true
		p.Lips = true
		p.HairStyle = "Riga"
		p.Hair = Color3.fromRGB(40, 30, 24)
	elseif kind == "Calvo" then
		p.LegMul = rng:NextNumber(1.05, 1.15)
		p.ArmMul = rng:NextNumber(1.15, 1.28)
		p.ThickMul = rng:NextNumber(0.65, 0.75)
		p.WidthMul = rng:NextNumber(0.78, 0.88)
		p.LongFace = true
		p.EyeSize = rng:NextNumber(0.7, 0.85)
		p.MouthWidth = 0.6
		p.Gape = 22
		p.HairStyle = "Calvo"
		p.Hunch = true
	elseif kind == "Barbuto" then
		p.Beard = true
		p.HairStyle = "Lungo"
		p.Hair = Color3.fromRGB(196, 186, 170)
		p.EyeSize = rng:NextNumber(0.85, 1.0)
		p.MouthWidth = 0.5
	elseif kind == "Urlatore" then
		p.HeadMul = rng:NextNumber(1.05, 1.2)
		p.EyeSize = rng:NextNumber(0.9, 1.1)
		p.MouthWidth = 0.7
		p.Gape = 30
		p.HairStyle = "Spettinato"
		p.Hair = Color3.fromRGB(34, 26, 22)
		p.Hunch = true
	elseif kind == "Cresta" then
		p.HeadMul = rng:NextNumber(1.5, 1.7)
		p.LegMul = rng:NextNumber(0.55, 0.65)
		p.ArmMul = rng:NextNumber(0.7, 0.8)
		p.WidthMul = rng:NextNumber(1.1, 1.25)
		p.ThickMul = rng:NextNumber(1.2, 1.35)
		p.Belly = rng:NextNumber(1.1, 1.4)
		p.EyeSize = rng:NextNumber(1.1, 1.3)
		p.MouthWidth = 0.55
		p.Grin = true
		p.HairStyle = "Cresta"
		p.Hair = Color3.fromRGB(50, 36, 28)
	else -- Occhietti
		p.HeadMul = rng:NextNumber(1.1, 1.25)
		p.EyeSize = rng:NextNumber(0.55, 0.7)
		p.Pupil = 0.6
		p.MouthWidth = 0.75
		p.Grin = true
		p.BigTeeth = true
		p.HairStyle = "Calvo"
	end
end

-- Profilo dell'aspetto in base al "Look" -----------------------------------------------

local function makeProfile(look: string, rng: Random)
	local p = {
		Skin = SKIN_TONES[rng:NextInteger(1, #SKIN_TONES)],
		Hair = HAIR_COLORS[rng:NextInteger(1, #HAIR_COLORS)],
		HairStyle = HAIR_STYLES[rng:NextInteger(1, #HAIR_STYLES)],
		LegMul = rng:NextNumber(0.82, 1.08),
		ArmMul = rng:NextNumber(0.88, 1.12),
		TorsoMul = rng:NextNumber(0.92, 1.12),
		HeadMul = rng:NextNumber(0.95, 1.3),
		WidthMul = rng:NextNumber(0.85, 1.15),
		ThickMul = rng:NextNumber(0.8, 1.2),
		Belly = rng:NextNumber() < 0.3 and rng:NextNumber(0.6, 1.2) or 0,
		MouthWidth = rng:NextNumber(0.45, 0.8),
		Grin = rng:NextNumber() < 0.55,
		EyeSize = rng:NextNumber(0.85, 1.35),
		EyeGlow = nil,
		Lips = true,
		Ears = rng:NextNumber(0.8, 1.4),
		Muscle = false,
		Skinless = false,
		Armor = false,
		Fur = false,
		Crystal = false,
		Bones = false,
		Mask = false,
		Claws = false,
		Steam = false,
		Magma = false,
		Hammer = false,
		Cannon = false,
	}
	if look == "Ghignante" then
		p.HeadMul = 1.35
		p.Belly = 0.9
		p.WidthMul = 1.15
		p.MouthWidth = 0.92
		p.Grin = true
		p.EyeSize = 1.35
		p.HairStyle = "Corto"
		p.Hair = Color3.fromRGB(205, 175, 120)
	elseif look == "Cacciatrice" then
		p.Skin = Color3.fromRGB(236, 196, 172)
		p.Hair = Color3.fromRGB(236, 206, 122)
		p.HairStyle = "Caschetto"
		p.LegMul, p.ArmMul, p.TorsoMul, p.HeadMul, p.WidthMul, p.ThickMul = 1.12, 1.0, 1.0, 0.82, 0.9, 0.9
		p.Belly = 0
		p.Muscle = true
		p.MouthWidth = 0.45
		p.Grin = false
		p.EyeSize = 0.9
		p.Ears = 0.8
	elseif look == "Bastione" then
		p.Skin = Color3.fromRGB(210, 166, 136)
		p.Hair = Color3.fromRGB(226, 200, 140)
		p.HairStyle = "Corto"
		p.LegMul, p.ArmMul, p.TorsoMul, p.HeadMul, p.WidthMul, p.ThickMul = 1.05, 1.0, 1.05, 0.85, 1.15, 1.25
		p.Belly = 0
		p.Armor = true
		p.Muscle = true
		p.MouthWidth = 0.55
		p.Grin = true
		p.EyeGlow = Color3.fromRGB(255, 240, 210)
	elseif look == "Vulcano" or look == "Marcia" then
		p.Skin = Color3.fromRGB(176, 66, 52)
		p.Hair = Color3.fromRGB(120, 40, 30)
		p.HairStyle = "Calvo"
		p.LegMul, p.ArmMul, p.TorsoMul, p.HeadMul, p.WidthMul, p.ThickMul = 1.0, 1.0, 1.05, 0.95, 1.1, 1.15
		p.Belly = 0
		p.Skinless = true
		p.Muscle = true
		p.Lips = false
		p.MouthWidth = 0.75
		p.Grin = true
		p.Steam = true
		p.EyeSize = 0.8
		p.Ears = 0.6
	elseif look == "Fauno" then
		p.Skin = Color3.fromRGB(150, 116, 84)
		p.Hair = Color3.fromRGB(96, 72, 48)
		p.HairStyle = "Pelo"
		p.LegMul, p.ArmMul, p.TorsoMul, p.HeadMul, p.WidthMul, p.ThickMul = 0.85, 1.38, 1.12, 0.9, 1.2, 1.35
		p.Belly = 0
		p.Fur = true
		p.MouthWidth = 0.5
		p.Grin = false
		p.EyeSize = 0.8
	elseif look == "Zanna" then
		p.Skin = Color3.fromRGB(214, 160, 128)
		p.Hair = Color3.fromRGB(28, 24, 22)
		p.HairStyle = "Lungo"
		p.LegMul, p.ArmMul, p.TorsoMul, p.HeadMul, p.WidthMul, p.ThickMul = 0.9, 1.12, 0.95, 1.1, 0.95, 1.1
		p.Belly = 0
		p.Mask = true
		p.Claws = true
		p.MouthWidth = 0.7
		p.Grin = true
		p.Lips = false
	elseif look == "Destriero" then
		p.Skin = Color3.fromRGB(205, 150, 120)
		p.Hair = Color3.fromRGB(40, 34, 30)
		p.HairStyle = "Corto"
		p.LegMul, p.ArmMul, p.TorsoMul, p.HeadMul, p.WidthMul, p.ThickMul = 0.9, 1.05, 1.35, 1.1, 1.05, 1.1
		p.Belly = 0
		p.Armor = true
		p.Cannon = true
		p.MouthWidth = 0.75
		p.Grin = true
	elseif look == "Forgia" then
		p.Skin = Color3.fromRGB(236, 218, 204)
		p.Hair = Color3.fromRGB(244, 240, 230)
		p.HairStyle = "Lungo"
		p.LegMul, p.ArmMul, p.TorsoMul, p.HeadMul, p.WidthMul, p.ThickMul = 1.08, 1.0, 1.0, 0.85, 0.95, 0.95
		p.Belly = 0
		p.Crystal = true
		p.Hammer = true
		p.Muscle = true
		p.MouthWidth = 0.5
		p.Grin = true
		p.EyeGlow = Color3.fromRGB(170, 230, 255)
	elseif look == "Furia" then
		p.Skin = Color3.fromRGB(196, 140, 110)
		p.Hair = Color3.fromRGB(30, 24, 20)
		p.HairStyle = "Lungo"
		p.LegMul, p.ArmMul, p.TorsoMul, p.HeadMul, p.WidthMul, p.ThickMul = 1.05, 1.02, 1.0, 0.9, 1.0, 1.0
		p.Belly = 0
		p.Muscle = true
		p.Lips = false
		p.MouthWidth = 0.7
		p.Grin = true
		p.Ears = 1.5
		p.EyeGlow = Color3.fromRGB(120, 255, 170)
	elseif look == "Redivivo" then
		-- aspetto di riserva finché il modello 3D non è importato
		p.Skin = Color3.fromRGB(176, 140, 104)
		p.Hair = Color3.fromRGB(40, 28, 22)
		p.HairStyle = "Lungo"
		p.LegMul, p.ArmMul, p.TorsoMul, p.HeadMul, p.WidthMul, p.ThickMul = 1.08, 1.05, 1.0, 0.85, 0.95, 1.0
		p.Belly = 0
		p.Muscle = true
		p.Lips = false
		p.Grin = false
		p.MouthWidth = 0.55
	elseif look == "Strisciante" then
		p.Skin = Color3.fromRGB(196, 120, 96)
		p.Hair = Color3.fromRGB(60, 40, 30)
		p.HairStyle = "Calvo"
		p.LegMul, p.ArmMul, p.TorsoMul, p.HeadMul, p.WidthMul, p.ThickMul = 0.75, 1.1, 1.25, 1.35, 1.25, 1.35
		p.Belly = 1.0
		p.Magma = true
		p.Steam = true
		p.Lips = false
		p.MouthWidth = 0.85
		p.Grin = true
		p.EyeSize = 0.7
	elseif look == "Primordiale" then
		p.Skin = Color3.fromRGB(150, 60, 50)
		p.Hair = Color3.fromRGB(40, 30, 26)
		p.HairStyle = "Lungo"
		p.LegMul, p.ArmMul, p.TorsoMul, p.HeadMul, p.WidthMul, p.ThickMul = 1.0, 1.25, 1.1, 0.95, 1.1, 0.85
		p.Belly = 0
		p.Bones = true
		p.Skinless = true
		p.Steam = true
		p.Lips = false
		p.MouthWidth = 0.8
		p.Grin = true
		p.EyeGlow = Color3.fromRGB(255, 230, 140)
	elseif look == "Cristallo" then
		p.Crystal = true
		p.EyeGlow = Color3.fromRGB(140, 230, 255)
	end
	if look == "Puro" or look == "Cristallo" then
		applyArchetype(p, rng)
	end
	return p
end

-- Sagoma di legno per l'addestramento --------------------------------------------------

local function buildDummy(height: number, name: string?): Model
	local model = Instance.new("Model")
	model.Name = name or "Sagoma"
	local h = height
	local wood = Color3.fromRGB(150, 108, 70)
	local darkWood = Color3.fromRGB(102, 72, 46)
	local root = newPart(model, "Root", Vector3.new(h * 0.12, h * 0.6, h * 0.12), darkWood, CFrame.new(0, h * 0.3, 0), { Shape = "Block", Material = Enum.Material.Wood, Query = true })
	root.Transparency = 0
	local hips = newPart(model, "Hips", Vector3.new(h * 0.05, h * 0.05, h * 0.05), darkWood, root.CFrame, { Shape = "Block", Query = false })
	hips.Transparency = 1
	motor("Root", root, hips, CFrame.new(0, h * 0.3, 0), CFrame.new())
	local torso = newPart(model, "Torso", Vector3.new(h * 0.42, h * 0.32, h * 0.08), wood, CFrame.new(0, h * 0.72, 0), { Shape = "Block", Material = Enum.Material.WoodPlanks, Zone = "Body" })
	local w = Instance.new("WeldConstraint")
	w.Part0 = hips
	w.Part1 = torso
	w.Parent = torso
	local head = newPart(model, "Head", Vector3.new(h * 0.2, h * 0.2, h * 0.08), wood, CFrame.new(0, h * 0.98, 0), { Shape = "Block", Material = Enum.Material.WoodPlanks, Zone = "Body" })
	local w2 = Instance.new("WeldConstraint")
	w2.Part0 = torso
	w2.Part1 = head
	w2.Parent = head
	-- la nuca è segnata in rosso, sul retro
	local nape = newPart(model, "Nape", Vector3.new(h * 0.16, h * 0.08, h * 0.05), Color3.fromRGB(190, 40, 40), CFrame.new(0, h * 0.86, h * 0.06), { Shape = "Block", Material = Enum.Material.Fabric, Zone = "Nape" })
	local w3 = Instance.new("WeldConstraint")
	w3.Part0 = torso
	w3.Part1 = nape
	w3.Parent = nape
	decor(model, torso, "ArmL", Vector3.new(h * 0.3, h * 0.05, h * 0.05), darkWood, CFrame.new(-h * 0.3, h * 0.1, 0), { Shape = "Block", Material = Enum.Material.Wood })
	decor(model, torso, "ArmR", Vector3.new(h * 0.3, h * 0.05, h * 0.05), darkWood, CFrame.new(h * 0.3, h * 0.1, 0), { Shape = "Block", Material = Enum.Material.Wood })
	model.PrimaryPart = root
	model:SetAttribute("Height", h)
	model:SetAttribute("HipHeight", h * 0.3)
	model:SetAttribute("Look", "Sagoma")
	return model
end

-- Costruzione principale -------------------------------------------------------------------

function TitanBuilder.Build(params): Model
	local H: number = params.Height or 22
	local look: string = params.Look or "Puro"
	local seed: number = params.Seed or 1
	if look == "Sagoma" then
		return buildDummy(H, params.Name)
	end
	-- aspetto fatto con un modello 3D importato (vedi MeshTitan): se c'è, ha la precedenza
	if MeshTitan.Has(look) then
		local ok, meshModel = pcall(MeshTitan.Build, params)
		if ok and meshModel then
			return meshModel
		end
		warn("[Giganti 3D] Errore nel costruire '" .. look .. "': " .. tostring(meshModel))
	end
	local rng = Random.new(seed)
	local p = makeProfile(look, rng)
	local skin = p.Skin
	local muscleColor = if p.Skinless then Color3.fromRGB(200, 96, 78) else darker(skin, 0.86)

	local model = Instance.new("Model")
	model.Name = params.Name or "Gigante"

	-- Proporzioni
	local legLen = 0.44 * H * p.LegMul
	local upperLeg = legLen * 0.5
	local lowerLeg = legLen * 0.47
	local footH = legLen * 0.06
	local footLen = 0.13 * H
	local hipsH = 0.1 * H
	local hipsW = 0.27 * H * p.WidthMul
	local torsoH = 0.3 * H * p.TorsoMul
	local torsoW = 0.33 * H * p.WidthMul
	local torsoD = 0.2 * H * p.WidthMul
	local headH = 0.17 * H * p.HeadMul * (if p.LongFace then 1.15 else 1)
	local headW = headH * (if p.LongFace then 0.72 else 0.86)
	local headD = headH * 0.95
	local armLen = 0.43 * H * p.ArmMul
	local upperArm = armLen * 0.46
	local lowerArm = armLen * 0.42
	local handLen = armLen * 0.14
	local armT = 0.078 * H * p.ThickMul
	local legT = 0.105 * H * p.ThickMul
	local hipHeight = hipsH * 0.3 + upperLeg + lowerLeg + footH

	local base = params.CFrame or CFrame.new(0, hipHeight, 0)

	-- Root (invisibile): è la parte che il server muove
	local root = newPart(model, "Root", Vector3.new(hipsW * 0.6, hipsH, torsoD * 0.6), skin, base, { Shape = "Block", Query = false, Shadow = false })
	root.Transparency = 1
	root.Massless = false

	local hips = newPart(model, "Hips", Vector3.new(hipsW, hipsH * 1.7, torsoD * 0.95), skin, base, { Zone = "Body" })
	motor("Root", root, hips, CFrame.new(), CFrame.new())

	local waistC0 = CFrame.new(0, hipsH * 0.4, 0)
	local waistC1 = CFrame.new(0, -torsoH * 0.5, 0)
	local torsoCF = hips.CFrame * waistC0 * waistC1:Inverse()
	local torso = newPart(model, "Torso", Vector3.new(torsoW, torsoH * 1.12, torsoD), skin, torsoCF, { Zone = "Body" })
	motor("Waist", hips, torso, waistC0, waistC1)

	local neckC0 = CFrame.new(0, torsoH * 0.5, -torsoD * 0.05)
	local neckC1 = CFrame.new(0, -headH * 0.46, headD * 0.05)
	local headCF = torso.CFrame * neckC0 * neckC1:Inverse()
	local head = newPart(model, "Head", Vector3.new(headW, headH, headD), skin, headCF, { Zone = "Body" })
	motor("Neck", torso, head, neckC0, neckC1)

	-- collo
	decor(model, torso, "Collo", Vector3.new(headW * 0.62, headH * 0.55, headD * 0.6), skin, CFrame.new(0, torsoH * 0.52, 0), { Query = true, Zone = "Body" })

	-- NUCA: il punto debole (invisibile, sul retro del collo)
	local nape = newPart(model, "Nape", Vector3.new(headW * 0.62, headH * 0.42, headD * 0.34), skin, torso.CFrame * CFrame.new(0, torsoH * 0.52, torsoD * 0.33), { Shape = "Block", Zone = "Nape", Shadow = false })
	nape.Transparency = 1
	local napeWeld = Instance.new("WeldConstraint")
	napeWeld.Part0 = torso
	napeWeld.Part1 = nape
	napeWeld.Parent = nape
	local napeAtt = Instance.new("Attachment")
	napeAtt.Name = "NapeAtt"
	napeAtt.Parent = nape

	-- mandibola
	local jawC0 = CFrame.new(0, -headH * 0.12, headD * 0.08)
	local jawC1 = CFrame.new(0, headH * 0.1, headD * 0.2)
	local jaw = newPart(model, "Jaw", Vector3.new(headW * 0.78, headH * 0.34, headD * 0.72), skin, head.CFrame * jawC0 * jawC1:Inverse(), { Zone = "Body", Shadow = false })
	motor("Jaw", head, jaw, jawC0, jawC1)

	-- Braccia
	local function buildArm(side: number, prefix: string)
		local limb = prefix .. "Arm"
		local shoulderC0 = CFrame.new(side * torsoW * 0.47, torsoH * 0.36, 0) * CFrame.Angles(0, 0, rad(7 * side))
		local shoulderC1 = CFrame.new(0, upperArm * 0.5, 0)
		local upper = newPart(model, prefix .. "UpperArm", Vector3.new(armT, upperArm * 1.1, armT), skin, torso.CFrame * shoulderC0 * shoulderC1:Inverse(), { Zone = limb, Limb = limb })
		motor(prefix .. "Shoulder", torso, upper, shoulderC0, shoulderC1)
		decor(model, upper, prefix .. "Deltoide", Vector3.new(armT * 1.45, armT * 1.35, armT * 1.3), if p.Muscle then muscleColor else skin, CFrame.new(side * armT * 0.05, upperArm * 0.4, 0), { Query = true, Zone = limb })

		local elbowC0 = CFrame.new(0, -upperArm * 0.5, 0)
		local elbowC1 = CFrame.new(0, lowerArm * 0.5, 0)
		local lower = newPart(model, prefix .. "LowerArm", Vector3.new(armT * 0.85, lowerArm * 1.12, armT * 0.85), skin, upper.CFrame * elbowC0 * elbowC1:Inverse(), { Zone = limb, Limb = limb })
		motor(prefix .. "Elbow", upper, lower, elbowC0, elbowC1)

		local wristC0 = CFrame.new(0, -lowerArm * 0.5, 0)
		local wristC1 = CFrame.new(0, handLen * 0.5, 0)
		local hand = newPart(model, prefix .. "Hand", Vector3.new(armT * 0.82, handLen * 1.2, armT * 0.5), skin, lower.CFrame * wristC0 * wristC1:Inverse(), { Zone = limb, Limb = limb })
		motor(prefix .. "Wrist", lower, hand, wristC0, wristC1)
		decor(model, hand, prefix .. "Pollice", Vector3.new(armT * 0.25, handLen * 0.6, armT * 0.25), skin, CFrame.new(-side * armT * 0.3, handLen * 0.1, -armT * 0.2) * CFrame.Angles(0, 0, rad(-25 * side)))
		local att = Instance.new("Attachment")
		att.Name = prefix .. "HandAtt"
		att.Position = Vector3.new(0, -handLen * 0.3, 0)
		att.Parent = hand

		if p.Muscle then
			decor(model, upper, prefix .. "Bicipite", Vector3.new(armT * 0.6, upperArm * 0.6, armT * 0.5), muscleColor, CFrame.new(0, 0, -armT * 0.3))
			decor(model, lower, prefix .. "Avambraccio", Vector3.new(armT * 0.55, lowerArm * 0.7, armT * 0.5), muscleColor, CFrame.new(0, lowerArm * 0.1, -armT * 0.22))
		end
		if p.Armor then
			local plate = Color3.fromRGB(232, 222, 202)
			decor(model, upper, prefix .. "Spallaccio", Vector3.new(armT * 1.6, armT * 1.0, armT * 1.5), plate, CFrame.new(side * armT * 0.1, upperArm * 0.42, 0), { Shape = "Block", Material = Enum.Material.Marble })
			decor(model, lower, prefix .. "Bracciale", Vector3.new(armT * 1.0, lowerArm * 0.8, armT * 1.0), plate, CFrame.new(0, 0, 0), { Shape = "Block", Material = Enum.Material.Marble })
		end
		if p.Fur then
			local fur = p.Hair
			decor(model, upper, prefix .. "PeloBraccio", Vector3.new(armT * 1.3, armT * 1.3, armT * 1.3), fur, CFrame.new(0, upperArm * 0.15, 0), { Shape = "Ball", Material = Enum.Material.Fabric })
			decor(model, lower, prefix .. "PeloAvambraccio", Vector3.new(armT * 1.1, armT * 1.1, armT * 1.1), fur, CFrame.new(0, lowerArm * 0.2, 0), { Shape = "Ball", Material = Enum.Material.Fabric })
		end
		if p.Claws then
			for i = -1, 1 do
				decor(model, hand, prefix .. "Artiglio" .. (i + 2), Vector3.new(armT * 0.12, handLen * 0.6, armT * 0.12), Color3.fromRGB(245, 240, 230), CFrame.new(i * armT * 0.25, -handLen * 0.6, -armT * 0.1) * CFrame.Angles(rad(-20), 0, 0), { Shape = "Block", Material = Enum.Material.Marble })
			end
		end
		if p.Crystal then
			decor(model, upper, prefix .. "Cristallo", Vector3.new(armT * 0.5, upperArm * 0.5, armT * 0.5), Color3.fromRGB(150, 230, 255), CFrame.new(side * armT * 0.4, upperArm * 0.2, armT * 0.2) * CFrame.Angles(0, 0, rad(30 * side)), { Shape = "Block", Material = Enum.Material.Glass, Transparency = 0.25 })
		end
		if p.Bones then
			decor(model, lower, prefix .. "Osso", Vector3.new(armT * 0.35, lowerArm * 1.05, armT * 0.35), Color3.fromRGB(236, 226, 206), CFrame.new(0, 0, -armT * 0.3), { Shape = "Block", Material = Enum.Material.Marble })
		end
		return upper, lower, hand
	end

	local _, _, rightHand = buildArm(1, "Right")
	buildArm(-1, "Left")

	-- Gambe
	local function buildLeg(side: number, prefix: string)
		local limb = prefix .. "Leg"
		local hipC0 = CFrame.new(side * hipsW * 0.28, -hipsH * 0.3, 0)
		local hipC1 = CFrame.new(0, upperLeg * 0.5, 0)
		local upper = newPart(model, prefix .. "UpperLeg", Vector3.new(legT, upperLeg * 1.12, legT * 1.05), skin, hips.CFrame * hipC0 * hipC1:Inverse(), { Zone = limb, Limb = limb })
		motor(prefix .. "Hip", hips, upper, hipC0, hipC1)

		local kneeC0 = CFrame.new(0, -upperLeg * 0.5, 0)
		local kneeC1 = CFrame.new(0, lowerLeg * 0.5, 0)
		local lower = newPart(model, prefix .. "LowerLeg", Vector3.new(legT * 0.8, lowerLeg * 1.12, legT * 0.8), skin, upper.CFrame * kneeC0 * kneeC1:Inverse(), { Zone = limb, Limb = limb })
		motor(prefix .. "Knee", upper, lower, kneeC0, kneeC1)
		decor(model, lower, prefix .. "Polpaccio", Vector3.new(legT * 0.7, lowerLeg * 0.55, legT * 0.6), if p.Muscle then muscleColor else skin, CFrame.new(0, lowerLeg * 0.15, legT * 0.18), { Query = true, Zone = limb })

		local ankleC0 = CFrame.new(0, -lowerLeg * 0.5, 0)
		local ankleC1 = CFrame.new(0, footH * 0.5, footLen * 0.28)
		local foot = newPart(model, prefix .. "Foot", Vector3.new(legT * 0.78, footH * 1.6, footLen), skin, lower.CFrame * ankleC0 * ankleC1:Inverse(), { Zone = limb, Limb = limb })
		motor(prefix .. "Ankle", lower, foot, ankleC0, ankleC1)

		if p.Armor then
			local plate = Color3.fromRGB(232, 222, 202)
			decor(model, upper, prefix .. "Cosciale", Vector3.new(legT * 1.08, upperLeg * 0.8, legT * 0.5), plate, CFrame.new(0, 0, -legT * 0.35), { Shape = "Block", Material = Enum.Material.Marble })
			decor(model, lower, prefix .. "Schiniere", Vector3.new(legT * 0.9, lowerLeg * 0.85, legT * 0.45), plate, CFrame.new(0, 0, -legT * 0.3), { Shape = "Block", Material = Enum.Material.Marble })
		end
		if p.Fur then
			decor(model, upper, prefix .. "PeloGamba", Vector3.new(legT * 1.25, legT * 1.25, legT * 1.25), p.Hair, CFrame.new(0, upperLeg * 0.2, 0), { Shape = "Ball", Material = Enum.Material.Fabric })
		end
		if p.Bones then
			decor(model, lower, prefix .. "Tibia", Vector3.new(legT * 0.3, lowerLeg * 1.05, legT * 0.3), Color3.fromRGB(236, 226, 206), CFrame.new(0, 0, -legT * 0.32), { Shape = "Block", Material = Enum.Material.Marble })
		end
	end
	buildLeg(1, "Right")
	buildLeg(-1, "Left")

	-- Busto: petto, addominali, pancia
	decor(model, torso, "PettoD", Vector3.new(torsoW * 0.48, torsoH * 0.36, torsoD * 0.5), if p.Muscle then muscleColor else skin, CFrame.new(torsoW * 0.22, torsoH * 0.2, -torsoD * 0.25), { Query = true, Zone = "Body" })
	decor(model, torso, "PettoS", Vector3.new(torsoW * 0.48, torsoH * 0.36, torsoD * 0.5), if p.Muscle then muscleColor else skin, CFrame.new(-torsoW * 0.22, torsoH * 0.2, -torsoD * 0.25), { Query = true, Zone = "Body" })
	if p.Belly > 0 then
		decor(model, torso, "Pancia", Vector3.new(torsoW * (0.7 + 0.25 * p.Belly), torsoH * (0.6 + 0.2 * p.Belly), torsoD * (0.8 + 0.5 * p.Belly)), skin, CFrame.new(0, -torsoH * 0.22, -torsoD * (0.12 + 0.12 * p.Belly)), { Query = true, Zone = "Body" })
	elseif p.Muscle then
		for row = 0, 2 do
			for col = -1, 1, 2 do
				decor(model, torso, "Addome" .. row .. col, Vector3.new(torsoW * 0.18, torsoH * 0.13, torsoD * 0.25), muscleColor, CFrame.new(col * torsoW * 0.1, -torsoH * (0.05 + row * 0.13), -torsoD * 0.38))
			end
		end
	end
	decor(model, torso, "Schiena", Vector3.new(torsoW * 0.9, torsoH * 0.7, torsoD * 0.55), if p.Muscle then muscleColor else skin, CFrame.new(0, torsoH * 0.12, torsoD * 0.22), { Query = true, Zone = "Body" })

	if p.Skinless then
		-- fasce muscolari chiare (Vulcano, Grande Marcia)
		local stripe = Color3.fromRGB(222, 140, 116)
		for i = 0, 3 do
			decor(model, torso, "Fibra" .. i, Vector3.new(torsoW * 0.08, torsoH * 0.9, torsoD * 0.2), stripe, CFrame.new((i - 1.5) * torsoW * 0.18, 0, -torsoD * 0.44))
		end
		decor(model, head, "FibraTesta", Vector3.new(headW * 0.85, headH * 0.15, headD * 0.95), stripe, CFrame.new(0, headH * 0.25, 0))
	end
	if p.Armor then
		local plate = Color3.fromRGB(232, 222, 202)
		decor(model, torso, "Pettorale", Vector3.new(torsoW * 0.95, torsoH * 0.5, torsoD * 0.35), plate, CFrame.new(0, torsoH * 0.18, -torsoD * 0.38), { Shape = "Block", Material = Enum.Material.Marble })
		decor(model, torso, "Ventrale", Vector3.new(torsoW * 0.6, torsoH * 0.35, torsoD * 0.25), plate, CFrame.new(0, -torsoH * 0.22, -torsoD * 0.38), { Shape = "Block", Material = Enum.Material.Marble })
		decor(model, head, "Elmo", Vector3.new(headW * 1.04, headH * 0.42, headD * 1.02), plate, CFrame.new(0, headH * 0.28, 0), { Shape = "Block", Material = Enum.Material.Marble })
		decor(model, head, "Visiera", Vector3.new(headW * 0.9, headH * 0.16, headD * 0.2), plate, CFrame.new(0, headH * 0.02, -headD * 0.45), { Shape = "Block", Material = Enum.Material.Marble })
	end
	if p.Fur then
		for i = 1, 6 do
			local ox = rng:NextNumber(-0.35, 0.35) * torsoW
			local oy = rng:NextNumber(-0.4, 0.45) * torsoH
			local s = rng:NextNumber(0.42, 0.62) * torsoW
			decor(model, torso, "Pelo" .. i, Vector3.new(s, s, s), p.Hair, CFrame.new(ox, oy, rng:NextNumber(-0.2, 0.25) * torsoD), { Shape = "Ball", Material = Enum.Material.Fabric, Query = true, Zone = "Body" })
		end
		decor(model, head, "Barba", Vector3.new(headW * 0.8, headH * 0.6, headD * 0.6), p.Hair, CFrame.new(0, -headH * 0.32, -headD * 0.25), { Shape = "Ball", Material = Enum.Material.Fabric })
	end
	if p.Crystal then
		for i = 1, 4 do
			local s = rng:NextNumber(0.12, 0.22) * H
			decor(model, torso, "CristalloSchiena" .. i, Vector3.new(s * 0.35, s, s * 0.35), Color3.fromRGB(150, 230, 255), CFrame.new(rng:NextNumber(-0.35, 0.35) * torsoW, rng:NextNumber(0, 0.45) * torsoH, torsoD * 0.45) * CFrame.Angles(rad(rng:NextNumber(-30, 30)), 0, rad(rng:NextNumber(-35, 35))), { Shape = "Block", Material = Enum.Material.Glass, Transparency = 0.2 })
		end
	end
	if p.Bones then
		local bone = Color3.fromRGB(236, 226, 206)
		for i = 0, 4 do
			decor(model, torso, "Costola" .. i, Vector3.new(torsoW * 1.04, torsoH * 0.05, torsoD * 1.05), bone, CFrame.new(0, torsoH * (0.3 - i * 0.13), 0), { Shape = "Block", Material = Enum.Material.Marble, Query = true, Zone = "Body" })
		end
		for i = 0, 5 do
			decor(model, torso, "Vertebra" .. i, Vector3.new(torsoW * 0.14, torsoH * 0.12, torsoD * 0.18), bone, CFrame.new(0, torsoH * (0.42 - i * 0.16), torsoD * 0.55), { Shape = "Block", Material = Enum.Material.Marble })
			decor(model, torso, "Spina" .. i, Vector3.new(torsoW * 0.05, torsoH * 0.22, torsoD * 0.05), bone, CFrame.new(0, torsoH * (0.45 - i * 0.16), torsoD * 0.7) * CFrame.Angles(rad(-35), 0, 0), { Shape = "Block", Material = Enum.Material.Marble })
		end
		decor(model, head, "Teschio", Vector3.new(headW * 1.02, headH * 0.6, headD * 1.02), bone, CFrame.new(0, headH * 0.22, 0), { Material = Enum.Material.Marble })
		for i = -2, 2 do
			decor(model, head, "Corona" .. i, Vector3.new(headW * 0.07, headH * 0.55, headW * 0.07), bone, CFrame.new(i * headW * 0.18, headH * 0.6, 0) * CFrame.Angles(0, 0, rad(i * 12)), { Shape = "Block", Material = Enum.Material.Marble })
		end
	end
	if p.Magma then
		local glow = Color3.fromRGB(255, 120, 40)
		for i = 1, 5 do
			decor(model, torso, "Brace" .. i, Vector3.new(torsoW * 0.22, torsoH * 0.18, torsoD * 0.15), glow, CFrame.new(rng:NextNumber(-0.3, 0.3) * torsoW, rng:NextNumber(-0.4, 0.4) * torsoH, -torsoD * 0.46), { Material = Enum.Material.Neon })
		end
		decor(model, head, "BraceViso", Vector3.new(headW * 0.5, headH * 0.2, headD * 0.15), glow, CFrame.new(0, headH * 0.05, -headD * 0.46), { Material = Enum.Material.Neon })
	end
	if p.Cannon then
		decor(model, torso, "Cannone", Vector3.new(torsoW * 0.9, torsoD * 0.22, torsoD * 0.22), Color3.fromRGB(70, 74, 80), CFrame.new(torsoW * 0.15, torsoH * 0.35, torsoD * 0.55) * CFrame.Angles(0, rad(90), 0), { Shape = "Cylinder", Material = Enum.Material.Metal })
		decor(model, torso, "Sella", Vector3.new(torsoW * 0.8, torsoH * 0.12, torsoD * 0.6), Color3.fromRGB(120, 90, 60), CFrame.new(0, torsoH * 0.3, torsoD * 0.4), { Shape = "Block", Material = Enum.Material.Leather })
	end
	if p.Hammer then
		local crystal = Color3.fromRGB(170, 230, 255)
		local handle = decor(model, rightHand, "MartelloManico", Vector3.new(armT * 0.25, H * 0.42, armT * 0.25), crystal, CFrame.new(0, -H * 0.12, -armT * 0.2), { Shape = "Block", Material = Enum.Material.Glass, Transparency = 0.15 })
		decor(model, handle, "MartelloTesta", Vector3.new(armT * 1.6, armT * 0.9, armT * 0.9), crystal, CFrame.new(0, -H * 0.2, 0), { Shape = "Block", Material = Enum.Material.Glass, Transparency = 0.1 })
	end

	-- VOLTO --------------------------------------------------------------------
	local front = -headD * 0.46
	local eyeSize = headH * 0.13 * p.EyeSize
	local eyeColor = p.EyeGlow or Color3.fromRGB(246, 244, 238)
	for _, side in { -1, 1 } do
		local name = if side < 0 then "LeftEye" else "RightEye"
		local eye = decor(model, head, name, Vector3.new(eyeSize, eyeSize * 0.85, eyeSize * 0.7), eyeColor, CFrame.new(side * headW * 0.2, headH * 0.08, front + eyeSize * 0.15), { Material = if p.EyeGlow then Enum.Material.Neon else Enum.Material.SmoothPlastic, Query = true, Zone = "Eye" })
		if not p.EyeGlow then
			local pupil = eyeSize * (p.Pupil or 0.42)
			if p.Iris then
				decor(model, eye, name .. "Iride", Vector3.new(eyeSize * 0.55, eyeSize * 0.55, eyeSize * 0.28), p.Iris, CFrame.new(0, 0, -eyeSize * 0.28))
			end
			decor(model, eye, name .. "Pupilla", Vector3.new(pupil, pupil, eyeSize * 0.3), Color3.fromRGB(28, 22, 20), CFrame.new(rng:NextNumber(-0.08, 0.08) * eyeSize, 0, -eyeSize * 0.3))
		end
		if p.Sockets then
			-- occhiaie scure: lo sguardo vuoto e inquietante dei giganti
			decor(model, head, name .. "Occhiaia", Vector3.new(eyeSize * 1.35, eyeSize * 1.2, eyeSize * 0.45), darker(skin, 0.72), CFrame.new(side * headW * 0.2, headH * 0.06, front + eyeSize * 0.05))
		end
		decor(model, head, name .. "Sopracciglio", Vector3.new(eyeSize * 1.3, eyeSize * 0.22, eyeSize * 0.4), darker(p.Hair, 0.9), CFrame.new(side * headW * 0.2, headH * 0.08 + eyeSize * 0.62, front + eyeSize * 0.05) * CFrame.Angles(0, 0, rad(side * rng:NextNumber(-12, 18))))
		-- orecchie
		decor(model, head, name .. "Orecchio", Vector3.new(headW * 0.12, headH * 0.26 * p.Ears, headD * 0.22), skin, CFrame.new(side * headW * 0.5, 0, headD * 0.05))
	end
	if look == "Cacciatrice" or p.Muscle and not p.Armor and not p.Skinless then
		-- muscoli scoperti intorno agli occhi (tipico dei mutaforma)
		for _, side in { -1, 1 } do
			decor(model, head, "MuscoloOcchio" .. side, Vector3.new(eyeSize * 1.5, eyeSize * 1.1, eyeSize * 0.4), Color3.fromRGB(196, 92, 84), CFrame.new(side * headW * 0.22, headH * 0.04, front + eyeSize * 0.02))
		end
	end
	-- naso
	decor(model, head, "Naso", Vector3.new(headW * 0.13, headH * 0.2, headD * 0.18), darker(skin, 0.95), CFrame.new(0, -headH * 0.04, front - headD * 0.03))

	-- bocca: interno scuro + denti
	local mouthW = headW * p.MouthWidth
	local mouthY = -headH * 0.22
	decor(model, jaw, "Bocca", Vector3.new(mouthW, headH * (if p.Gape then 0.3 else 0.16), headD * 0.12), Color3.fromRGB(70, 22, 24), CFrame.new(0, headH * (if p.Gape then 0.12 else 0.06), -headD * 0.3))
	local teeth = Color3.fromRGB(244, 238, 222)
	decor(model, head, "DentiSu", Vector3.new(mouthW * 0.96, headH * 0.06, headD * 0.08), teeth, CFrame.new(0, mouthY + headH * 0.04, front + headD * 0.03), { Shape = "Block" })
	decor(model, jaw, "DentiGiu", Vector3.new(mouthW * 0.92, headH * 0.06, headD * 0.08), teeth, CFrame.new(0, headH * 0.1, -headD * 0.33), { Shape = "Block" })
	if p.BigTeeth then
		-- fila di denti squadrati ben visibili
		local n = 7
		for i = 1, n do
			local x = (i - (n + 1) / 2) * mouthW / n
			decor(model, head, "Dente" .. i, Vector3.new(mouthW / n * 0.85, headH * 0.11, headD * 0.06), teeth, CFrame.new(x, mouthY + headH * 0.02, front + headD * 0.01), { Shape = "Block" })
		end
	end
	if p.Beard then
		decor(model, jaw, "Barba", Vector3.new(headW * 0.85, headH * 0.55, headD * 0.6), darker(p.Hair, 0.95), CFrame.new(0, -headH * 0.12, -headD * 0.18), { Shape = "Ball", Material = Enum.Material.Fabric })
	end
	if p.Lips then
		decor(model, head, "Labbro", Vector3.new(mouthW * 1.05, headH * 0.05, headD * 0.08), darker(skin, 0.8), CFrame.new(0, mouthY + headH * 0.085, front + headD * 0.02))
	end
	if p.Grin then
		-- guance tirate verso l'alto: il sorriso inquietante dei giganti
		for _, side in { -1, 1 } do
			decor(model, head, "Guancia" .. side, Vector3.new(headW * 0.2, headH * 0.16, headD * 0.2), skin, CFrame.new(side * mouthW * 0.48, mouthY + headH * 0.12, front + headD * 0.06))
		end
	end
	if p.Mask then
		local mask = Color3.fromRGB(240, 234, 222)
		decor(model, head, "Maschera", Vector3.new(headW * 0.95, headH * 0.3, headD * 0.15), mask, CFrame.new(0, headH * 0.18, front), { Shape = "Block", Material = Enum.Material.Marble })
		decor(model, jaw, "MascheraMento", Vector3.new(headW * 0.7, headH * 0.14, headD * 0.15), mask, CFrame.new(0, -headH * 0.06, -headD * 0.3), { Shape = "Block", Material = Enum.Material.Marble })
	end

	-- CAPELLI ------------------------------------------------------------------
	local hair = p.Hair
	local style = p.HairStyle
	if style == "Corto" or style == "Lungo" or style == "Caschetto" or style == "Pelo" then
		decor(model, head, "Capelli", Vector3.new(headW * 1.06, headH * 0.6, headD * 1.06), hair, CFrame.new(0, headH * 0.26, headD * 0.04))
	end
	if style == "Lungo" then
		decor(model, head, "CapelliLunghi", Vector3.new(headW * 1.02, headH * 0.95, headD * 0.5), hair, CFrame.new(0, -headH * 0.12, headD * 0.34))
	elseif style == "Caschetto" then
		decor(model, head, "Caschetto", Vector3.new(headW * 1.1, headH * 0.7, headD * 0.85), hair, CFrame.new(0, headH * 0.02, headD * 0.14))
	elseif style == "Ciuffo" then
		decor(model, head, "Ciuffo", Vector3.new(headW * 0.5, headH * 0.4, headD * 0.6), hair, CFrame.new(0, headH * 0.48, -headD * 0.08))
	elseif style == "Riccio" then
		for i = 1, 5 do
			local s = headW * rng:NextNumber(0.32, 0.45)
			decor(model, head, "Riccio" .. i, Vector3.new(s, s, s), hair, CFrame.new(rng:NextNumber(-0.32, 0.32) * headW, headH * rng:NextNumber(0.3, 0.45), rng:NextNumber(-0.2, 0.3) * headD), { Shape = "Ball", Material = Enum.Material.Fabric })
		end
	elseif style == "Riga" then
		-- capelli corti con la riga di lato
		decor(model, head, "Capelli", Vector3.new(headW * 1.07, headH * 0.55, headD * 1.07), hair, CFrame.new(0, headH * 0.28, headD * 0.04))
		decor(model, head, "Frangia", Vector3.new(headW * 0.7, headH * 0.22, headD * 0.3), hair, CFrame.new(headW * 0.15, headH * 0.36, -headD * 0.38) * CFrame.Angles(0, 0, rad(-12)))
	elseif style == "Spettinato" then
		decor(model, head, "Capelli", Vector3.new(headW * 1.1, headH * 0.62, headD * 1.08), hair, CFrame.new(0, headH * 0.27, headD * 0.05))
		for i = 1, 6 do
			local s0 = headW * rng:NextNumber(0.22, 0.32)
			decor(model, head, "Ciocca" .. i, Vector3.new(s0, s0 * 1.6, s0), hair, CFrame.new(rng:NextNumber(-0.45, 0.45) * headW, headH * rng:NextNumber(0.25, 0.5), rng:NextNumber(-0.3, 0.4) * headD) * CFrame.Angles(rad(rng:NextNumber(-40, 40)), 0, rad(rng:NextNumber(-40, 40))))
		end
	elseif style == "Cresta" then
		for i = -2, 2 do
			decor(model, head, "Cresta" .. i, Vector3.new(headW * 0.14, headH * 0.28, headD * 0.2), hair, CFrame.new(0, headH * 0.46 - math.abs(i) * headH * 0.04, i * headD * 0.17))
		end
	elseif style == "Pelo" then
		decor(model, head, "Criniera", Vector3.new(headW * 1.25, headH * 1.0, headD * 0.9), hair, CFrame.new(0, headH * 0.05, headD * 0.22), { Shape = "Ball", Material = Enum.Material.Fabric })
	end

	-- Vapore costante (Vulcano, Strisciante, Primordiale)
	if p.Steam then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Vapore"
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(245, 240, 235))
		emitter.LightEmission = 0.15
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 1) })
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, H * 0.06), NumberSequenceKeypoint.new(1, H * 0.22) })
		emitter.Lifetime = NumberRange.new(2.5, 4)
		emitter.Rate = 6
		emitter.Speed = NumberRange.new(H * 0.03, H * 0.08)
		emitter.SpreadAngle = Vector2.new(40, 40)
		emitter.Acceleration = Vector3.new(0, H * 0.05, 0)
		emitter.RotSpeed = NumberRange.new(-30, 30)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.Parent = torso
	end

	-- Attacchi per effetti e interfaccia
	local headTop = Instance.new("Attachment")
	headTop.Name = "HeadTopAtt"
	headTop.Position = Vector3.new(0, headH * 0.75, 0)
	headTop.Parent = head
	local mouthAtt = Instance.new("Attachment")
	mouthAtt.Name = "MouthAtt"
	mouthAtt.Position = Vector3.new(0, mouthY, front)
	mouthAtt.Parent = head
	local steamAtt = Instance.new("Attachment")
	steamAtt.Name = "SteamAtt"
	steamAtt.Parent = torso

	model.PrimaryPart = root
	model:SetAttribute("Height", H)
	model:SetAttribute("HipHeight", hipHeight)
	model:SetAttribute("Look", look)
	model:SetAttribute("Seed", seed)
	model:SetAttribute("HeadTilt", rng:NextNumber(-12, 12))
	model:SetAttribute("Archetype", p.Archetype or "")
	model:SetAttribute("CrawlPreferred", p.Crawl == true)
	model:SetAttribute("JawIdle", p.Gape or 0)
	model:SetAttribute("Hunch", p.Hunch == true)
	return model
end

return TitanBuilder
