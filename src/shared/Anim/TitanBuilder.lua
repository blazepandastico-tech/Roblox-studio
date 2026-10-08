--[[
	TitanBuilder
	Costruisce i giganti interamente via codice (nessun modello da importare), in STILE ROBLOX:
	ogni parte del corpo è un blocco, come gli avatar, collegato con Motor6D che hanno gli
	STESSI nomi delle articolazioni R15: così le animazioni procedurali funzionano sia sui
	giocatori sia sui giganti.

	Ogni gigante puro è diverso grazie al seme: proporzioni, pelle e una combinazione di
	capelli (anche calvo), occhi, sopracciglia, naso, bocca, orecchie e dettagli (barba,
	cicatrici, lentiggini...), a volte con la faccia storta. È solo l'aspetto: abilità,
	punti deboli e articolazioni non cambiano.
	I mutaforma (Cacciatrice, Bastione, Vulcano, Fauno...) hanno un aspetto dedicato.
]]

local MeshTitan = require(script.Parent.MeshTitan)
local ColossoAnatomico = require(script.Parent.ColossoAnatomico)

local warnedColosso = false

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
	elseif opts.Shape == "Sphere" then
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
		p.BigTeeth = true
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
	elseif look == "Dorato" then
		-- il Colosso d'Oro dell'evento Grande Inaugurazione
		p.Skin = Color3.fromRGB(226, 176, 64)
		p.Hair = Color3.fromRGB(250, 236, 190)
		p.HairStyle = "Lungo"
		p.LegMul, p.ArmMul, p.TorsoMul, p.HeadMul, p.WidthMul, p.ThickMul = 1.05, 1.05, 1.05, 0.9, 1.1, 1.15
		p.Belly = 0
		p.Muscle = true
		p.Armor = true
		p.Lips = false
		p.MouthWidth = 0.7
		p.Grin = true
		p.Steam = true
		p.EyeGlow = Color3.fromRGB(255, 250, 220)
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

-- STILE ROBLOX: ASPETTO DEI GIGANTI PURI -------------------------------------------------------
-- Ogni gigante puro pesca dal suo seme una combinazione di capelli, occhi, sopracciglia, naso,
-- bocca, orecchie e dettagli (barba, cicatrici, lentiggini, faccia storta...). È solo grafica:
-- le proporzioni, le articolazioni, i punti deboli e gli attributi restano quelli di prima.

local PURE_SKINS = {
	Color3.fromRGB(214, 150, 120), Color3.fromRGB(198, 132, 104), Color3.fromRGB(226, 164, 136),
	Color3.fromRGB(184, 118, 92), Color3.fromRGB(232, 176, 150), Color3.fromRGB(206, 140, 116),
	Color3.fromRGB(240, 200, 170), Color3.fromRGB(170, 110, 84), Color3.fromRGB(146, 96, 70),
	Color3.fromRGB(222, 186, 150), Color3.fromRGB(196, 150, 128), Color3.fromRGB(234, 162, 150),
}
local PURE_HAIR = {
	Color3.fromRGB(32, 26, 22), Color3.fromRGB(70, 48, 32), Color3.fromRGB(120, 84, 52), Color3.fromRGB(200, 170, 110),
	Color3.fromRGB(140, 140, 140), Color3.fromRGB(168, 74, 40), Color3.fromRGB(232, 224, 206), Color3.fromRGB(92, 62, 42),
}

TitanBuilder.Traits = {
	Hair = { "Calvo", "Calvo", "Corto", "Lungo", "Cresta", "Ciuffo", "Caschetto", "Spettinato", "Codino", "Riga", "Chierica", "Afro", "Rasato", "Riccio" },
	Eyes = { "Normali", "Normali", "Occhioni", "Occhietti", "Diversi", "Strabici", "Socchiusi", "Occhiolino", "Vuoti" },
	Brows = { "Normali", "Normali", "Arrabbiate", "Tristi", "Monociglio", "Nessuna", "Folte" },
	Nose = { "Normale", "Normale", "Piccolo", "Grosso", "Lungo", "Schiacciato", "Storto" },
	Mouth = { "Ghigno", "Ghigno", "Sorrisetto", "Urlo", "Dentoni", "Lingua", "Chiusa", "Storta", "Sdentato" },
	Ears = { "Normali", "Normali", "Grandi", "Piccole", "Sventola" },
	Extras = { "Barba", "Baffi", "Cicatrice", "Lentiggini", "Guance", "Occhiaie", "Neo", "Macchie", "Rughe" },
}

local function pickFrom(r: Random, list: { any }): any
	return list[r:NextInteger(1, #list)]
end

-- Sceglie l'aspetto del volto e dei capelli. I mutaforma tengono il loro aspetto riconoscibile.
local function pickTraits(p, look: string, vr: Random)
	local t = {
		Hair = p.HairStyle,
		Eyes = "Normali",
		Brows = if p.Muscle then "Arrabbiate" else "Normali",
		Nose = "Normale",
		Mouth = if p.Gape then "Urlo" elseif p.Grin then "Ghigno" else "Chiusa",
		Ears = "Normali",
		Extras = {} :: { [string]: boolean },
		Crooked = false,
	}
	if p.Beard then
		t.Extras.Barba = true
	end
	if look == "Puro" or look == "Cristallo" then
		local T = TitanBuilder.Traits
		t.Hair = pickFrom(vr, T.Hair)
		p.Hair = pickFrom(vr, PURE_HAIR)
		p.Skin = pickFrom(vr, PURE_SKINS)
		t.Eyes = pickFrom(vr, T.Eyes)
		t.Brows = pickFrom(vr, T.Brows)
		t.Nose = pickFrom(vr, T.Nose)
		t.Mouth = pickFrom(vr, T.Mouth)
		t.Ears = pickFrom(vr, T.Ears)
		t.Crooked = vr:NextNumber() < 0.25
		for _, extra in T.Extras do
			if vr:NextNumber() < 0.16 then
				t.Extras[extra] = true
			end
		end
	end
	return t
end

-- Costruzione principale (STILE ROBLOX) ----------------------------------------------------------
-- Il corpo è fatto di blocchi come un avatar di Roblox. Le articolazioni hanno gli stessi nomi e
-- le stesse misure di prima: animazioni, nuca, occhi, arti tagliabili e abilità non cambiano.

function TitanBuilder.Build(params): Model
	local H: number = params.Height or 22
	local look: string = params.Look or "Puro"
	local seed: number = params.Seed or 1
	if look == "Sagoma" then
		return buildDummy(H, params.Name)
	end
	-- nei filmati il Vulcano è il colosso anatomico senza pelle: il modello 3D importato
	-- (GiganteColosso, da Meshy) se c'è, altrimenti quello costruito con le parti
	if params.Cinematic and look == "Vulcano" then
		if MeshTitan.Has("Colosso") then
			local ok, meshModel = pcall(MeshTitan.Build, { Height = H, Look = "Colosso", Seed = seed, Name = params.Name or "Vulcano", CFrame = params.CFrame })
			if ok and meshModel then
				local steam = Instance.new("ParticleEmitter")
				steam.Name = "Vapore"
				steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
				steam.Color = ColorSequence.new(Color3.fromRGB(245, 240, 235))
				steam.LightEmission = 0.15
				steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 1) })
				steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, H * 0.05), NumberSequenceKeypoint.new(1, H * 0.18) })
				steam.Lifetime = NumberRange.new(2.5, 4)
				steam.Rate = 6
				steam.Speed = NumberRange.new(H * 0.03, H * 0.08)
				steam.SpreadAngle = Vector2.new(40, 40)
				steam.Acceleration = Vector3.new(0, H * 0.05, 0)
				steam.Parent = meshModel:FindFirstChild("Torso")
				meshModel:SetAttribute("JawIdle", 6)
				return meshModel
			end
			warn("[Giganti 3D] Errore nel colosso dei filmati: " .. tostring(meshModel))
		elseif not warnedColosso then
			-- una volta sola, nella finestra Output: perché il filmato usa il colosso fatto con le parti
			warnedColosso = true
			print("[Giganti 3D] " .. select(2, MeshTitan.Status("Colosso")))
		end
		local ok, colosso = pcall(ColossoAnatomico.Build, params)
		if ok and colosso then
			return colosso
		end
		warn("[Giganti] Errore nel colosso dei filmati: " .. tostring(colosso))
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
	local headTilt = rng:NextNumber(-12, 12)
	-- l'aspetto (solo grafica) usa un generatore separato: le proporzioni restano le stesse
	local vr = Random.new(seed * 7919 + 101)
	local traits = pickTraits(p, look, vr)
	local skin = p.Skin
	local muscleColor = if p.Skinless then Color3.fromRGB(200, 96, 78) else darker(skin, 0.86)
	local hair = p.Hair
	local hairDark = darker(hair, 0.8)

	local model = Instance.new("Model")
	model.Name = params.Name or "Gigante"

	-- Proporzioni (identiche a prima: altezza, passo e punti deboli non cambiano)
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
	local root = newPart(model, "Root", Vector3.new(hipsW * 0.6, hipsH, torsoD * 0.6), skin, base, { Query = false, Shadow = false })
	root.Transparency = 1
	root.Massless = false

	local hips = newPart(model, "Hips", Vector3.new(hipsW, hipsH * 1.7, torsoD * 0.95), skin, base, { Zone = "Body" })
	motor("Root", root, hips, CFrame.new(), CFrame.new())

	local waistC0 = CFrame.new(0, hipsH * 0.4, 0)
	local waistC1 = CFrame.new(0, -torsoH * 0.5, 0)
	local torso = newPart(model, "Torso", Vector3.new(torsoW, torsoH * 1.12, torsoD), skin, hips.CFrame * waistC0 * waistC1:Inverse(), { Zone = "Body" })
	motor("Waist", hips, torso, waistC0, waistC1)

	local neckC0 = CFrame.new(0, torsoH * 0.5, -torsoD * 0.05)
	local neckC1 = CFrame.new(0, -headH * 0.46, headD * 0.05)
	local head = newPart(model, "Head", Vector3.new(headW, headH, headD), skin, torso.CFrame * neckC0 * neckC1:Inverse(), { Zone = "Body" })
	motor("Neck", torso, head, neckC0, neckC1)

	-- collo
	decor(model, torso, "Collo", Vector3.new(headW * 0.5, headH * 0.5, headD * 0.5), skin, CFrame.new(0, torsoH * 0.56, -torsoD * 0.04), { Query = true, Zone = "Body" })

	-- NUCA: il punto debole (invisibile, sul retro del collo)
	local nape = newPart(model, "Nape", Vector3.new(headW * 0.62, headH * 0.42, headD * 0.34), skin, torso.CFrame * CFrame.new(0, torsoH * 0.52, torsoD * 0.33), { Zone = "Nape", Shadow = false })
	nape.Transparency = 1
	local napeWeld = Instance.new("WeldConstraint")
	napeWeld.Part0 = torso
	napeWeld.Part1 = nape
	napeWeld.Parent = nape
	local napeAtt = Instance.new("Attachment")
	napeAtt.Name = "NapeAtt"
	napeAtt.Parent = nape

	-- mandibola: il blocco della parte bassa del viso (si apre per mordere e urlare)
	local jawC0 = CFrame.new(0, -headH * 0.12, headD * 0.08)
	local jawC1 = CFrame.new(0, headH * 0.1, headD * 0.2)
	local jaw = newPart(model, "Jaw", Vector3.new(headW * 0.84, headH * 0.42, headD * 0.86), skin, head.CFrame * jawC0 * jawC1:Inverse(), { Zone = "Body", Shadow = false })
	motor("Jaw", head, jaw, jawC0, jawC1)

	-- Braccia
	local function buildArm(side: number, prefix: string)
		local limb = prefix .. "Arm"
		local shoulderC0 = CFrame.new(side * torsoW * 0.47, torsoH * 0.36, 0) * CFrame.Angles(0, 0, rad(7 * side))
		local shoulderC1 = CFrame.new(0, upperArm * 0.5, 0)
		local upper = newPart(model, prefix .. "UpperArm", Vector3.new(armT, upperArm * 1.1, armT), skin, torso.CFrame * shoulderC0 * shoulderC1:Inverse(), { Zone = limb, Limb = limb })
		motor(prefix .. "Shoulder", torso, upper, shoulderC0, shoulderC1)
		-- spalla squadrata (come gli avatar a blocchi)
		decor(model, upper, prefix .. "Spalla", Vector3.new(armT * 1.25, armT * 0.9, armT * 1.15), if p.Muscle then muscleColor else skin, CFrame.new(side * armT * 0.05, upperArm * 0.42, 0), { Query = true, Zone = limb })

		local elbowC0 = CFrame.new(0, -upperArm * 0.5, 0)
		local elbowC1 = CFrame.new(0, lowerArm * 0.5, 0)
		local lower = newPart(model, prefix .. "LowerArm", Vector3.new(armT * 0.9, lowerArm * 1.1, armT * 0.9), skin, upper.CFrame * elbowC0 * elbowC1:Inverse(), { Zone = limb, Limb = limb })
		motor(prefix .. "Elbow", upper, lower, elbowC0, elbowC1)

		local wristC0 = CFrame.new(0, -lowerArm * 0.5, 0)
		local wristC1 = CFrame.new(0, handLen * 0.5, 0)
		local hand = newPart(model, prefix .. "Hand", Vector3.new(armT * 0.85, handLen * 1.15, armT * 0.55), skin, lower.CFrame * wristC0 * wristC1:Inverse(), { Zone = limb, Limb = limb })
		motor(prefix .. "Wrist", lower, hand, wristC0, wristC1)
		decor(model, hand, prefix .. "Pollice", Vector3.new(armT * 0.24, handLen * 0.6, armT * 0.24), skin, CFrame.new(-side * armT * 0.34, handLen * 0.05, -armT * 0.2) * CFrame.Angles(0, 0, rad(-20 * side)))
		local att = Instance.new("Attachment")
		att.Name = prefix .. "HandAtt"
		att.Position = Vector3.new(0, -handLen * 0.3, 0)
		att.Parent = hand

		if p.Muscle then
			decor(model, upper, prefix .. "Bicipite", Vector3.new(armT * 0.6, upperArm * 0.55, armT * 0.3), muscleColor, CFrame.new(0, -upperArm * 0.02, -armT * 0.5))
			decor(model, lower, prefix .. "Avambraccio", Vector3.new(armT * 0.55, lowerArm * 0.6, armT * 0.25), muscleColor, CFrame.new(0, lowerArm * 0.1, -armT * 0.45))
		end
		if p.Skinless then
			-- tendini chiari lungo il braccio
			for _, sx in { -1, 1 } do
				decor(model, upper, prefix .. "Fascio" .. sx, Vector3.new(armT * 0.12, upperArm * 0.85, armT * 0.1), skin:Lerp(Color3.fromRGB(236, 150, 120), 0.4), CFrame.new(sx * armT * 0.28, 0, -armT * 0.52))
				decor(model, lower, prefix .. "Tendine" .. sx, Vector3.new(armT * 0.1, lowerArm * 0.8, armT * 0.1), skin:Lerp(Color3.fromRGB(240, 200, 180), 0.45), CFrame.new(sx * armT * 0.2, 0, -armT * 0.47))
			end
		end
		if p.Armor then
			local plate = Color3.fromRGB(232, 222, 202)
			decor(model, upper, prefix .. "Spallaccio", Vector3.new(armT * 1.6, armT * 1.0, armT * 1.5), plate, CFrame.new(side * armT * 0.1, upperArm * 0.42, 0), { Material = Enum.Material.Marble })
			decor(model, lower, prefix .. "Bracciale", Vector3.new(armT * 1.05, lowerArm * 0.8, armT * 1.05), plate, CFrame.new(0, 0, 0), { Material = Enum.Material.Marble })
		end
		if p.Fur then
			decor(model, upper, prefix .. "PeloBraccio", Vector3.one * armT * 1.3, p.Hair, CFrame.new(0, upperArm * 0.15, 0) * CFrame.Angles(0, rad(25), rad(10)), { Material = Enum.Material.Fabric })
			decor(model, lower, prefix .. "PeloAvambraccio", Vector3.one * armT * 1.1, p.Hair, CFrame.new(0, lowerArm * 0.2, 0) * CFrame.Angles(0, rad(-20), rad(8)), { Material = Enum.Material.Fabric })
		end
		if p.Claws then
			for i = -1, 1 do
				decor(model, hand, prefix .. "Artiglio" .. (i + 2), Vector3.new(armT * 0.12, handLen * 0.6, armT * 0.12), Color3.fromRGB(245, 240, 230), CFrame.new(i * armT * 0.25, -handLen * 0.6, -armT * 0.1) * CFrame.Angles(rad(-20), 0, 0), { Material = Enum.Material.Marble })
			end
		end
		if p.Crystal then
			decor(model, upper, prefix .. "Cristallo", Vector3.new(armT * 0.5, upperArm * 0.5, armT * 0.5), Color3.fromRGB(150, 230, 255), CFrame.new(side * armT * 0.4, upperArm * 0.2, armT * 0.2) * CFrame.Angles(0, 0, rad(30 * side)), { Material = Enum.Material.Glass, Transparency = 0.25 })
		end
		if p.Bones then
			decor(model, lower, prefix .. "Osso", Vector3.new(armT * 0.35, lowerArm * 1.05, armT * 0.35), Color3.fromRGB(236, 226, 206), CFrame.new(0, 0, -armT * 0.4), { Material = Enum.Material.Marble })
		end
		return hand
	end
	local rightHand = buildArm(1, "Right")
	buildArm(-1, "Left")

	-- Gambe
	local function buildLeg(side: number, prefix: string)
		local limb = prefix .. "Leg"
		local hipC0 = CFrame.new(side * hipsW * 0.28, -hipsH * 0.3, 0)
		local hipC1 = CFrame.new(0, upperLeg * 0.5, 0)
		local upper = newPart(model, prefix .. "UpperLeg", Vector3.new(legT, upperLeg * 1.1, legT * 1.05), skin, hips.CFrame * hipC0 * hipC1:Inverse(), { Zone = limb, Limb = limb })
		motor(prefix .. "Hip", hips, upper, hipC0, hipC1)

		local kneeC0 = CFrame.new(0, -upperLeg * 0.5, 0)
		local kneeC1 = CFrame.new(0, lowerLeg * 0.5, 0)
		local lower = newPart(model, prefix .. "LowerLeg", Vector3.new(legT * 0.86, lowerLeg * 1.1, legT * 0.86), skin, upper.CFrame * kneeC0 * kneeC1:Inverse(), { Zone = limb, Limb = limb })
		motor(prefix .. "Knee", upper, lower, kneeC0, kneeC1)

		local ankleC0 = CFrame.new(0, -lowerLeg * 0.5, 0)
		local ankleC1 = CFrame.new(0, footH * 0.5, footLen * 0.28)
		local foot = newPart(model, prefix .. "Foot", Vector3.new(legT * 0.9, footH * 1.6, footLen), skin, lower.CFrame * ankleC0 * ankleC1:Inverse(), { Zone = limb, Limb = limb })
		motor(prefix .. "Ankle", lower, foot, ankleC0, ankleC1)

		if p.Armor then
			local plate = Color3.fromRGB(232, 222, 202)
			decor(model, upper, prefix .. "Cosciale", Vector3.new(legT * 1.08, upperLeg * 0.8, legT * 0.5), plate, CFrame.new(0, 0, -legT * 0.4), { Material = Enum.Material.Marble })
			decor(model, lower, prefix .. "Schiniere", Vector3.new(legT * 0.94, lowerLeg * 0.85, legT * 0.45), plate, CFrame.new(0, 0, -legT * 0.35), { Material = Enum.Material.Marble })
		end
		if p.Fur then
			decor(model, upper, prefix .. "PeloGamba", Vector3.one * legT * 1.25, p.Hair, CFrame.new(0, upperLeg * 0.2, 0) * CFrame.Angles(0, rad(20), rad(-8)), { Material = Enum.Material.Fabric })
		end
		if p.Bones then
			decor(model, lower, prefix .. "Tibia", Vector3.new(legT * 0.3, lowerLeg * 1.05, legT * 0.3), Color3.fromRGB(236, 226, 206), CFrame.new(0, 0, -legT * 0.42), { Material = Enum.Material.Marble })
		end
	end
	buildLeg(1, "Right")
	buildLeg(-1, "Left")

	-- BUSTO ------------------------------------------------------------------------------------
	local frontZ = -torsoD * 0.5
	if p.Belly > 0 then
		local bd = torsoD * (0.25 + 0.25 * p.Belly)
		decor(model, torso, "Pancia", Vector3.new(torsoW * (0.74 + 0.18 * p.Belly), torsoH * (0.55 + 0.15 * p.Belly), bd), skin, CFrame.new(0, -torsoH * 0.22, frontZ - bd * 0.4), { Query = true, Zone = "Body" })
		decor(model, torso, "Ombelico", Vector3.new(headH * 0.06, headH * 0.06, headH * 0.04), darker(skin, 0.6), CFrame.new(0, -torsoH * 0.22, frontZ - bd * 0.9))
	else
		decor(model, torso, "Ombelico", Vector3.new(headH * 0.05, headH * 0.05, headH * 0.03), darker(skin, 0.6), CFrame.new(0, -torsoH * 0.24, frontZ - headH * 0.01))
	end
	if p.Muscle then
		-- pettorali e addominali squadrati
		for _, side in { -1, 1 } do
			decor(model, torso, "Pettorale" .. side, Vector3.new(torsoW * 0.42, torsoH * 0.26, torsoD * 0.1), muscleColor, CFrame.new(side * torsoW * 0.22, torsoH * 0.24, frontZ - torsoD * 0.03))
		end
		if p.Belly == 0 then
			for row = 0, 2 do
				for _, col in { -1, 1 } do
					decor(model, torso, "Addome" .. row .. col, Vector3.new(torsoW * 0.17, torsoH * 0.11, torsoD * 0.06), muscleColor, CFrame.new(col * torsoW * 0.1, -torsoH * (0.02 + row * 0.13), frontZ - torsoD * 0.02))
				end
			end
		end
	elseif p.ThickMul < 0.8 and p.Belly == 0 then
		-- costole che si vedono sotto la pelle dei giganti magri
		for _, side in { -1, 1 } do
			for i = 0, 2 do
				decor(model, torso, "Costa" .. side .. i, Vector3.new(torsoW * 0.28, torsoH * 0.035, torsoD * 0.04), darker(skin, 0.86), CFrame.new(side * torsoW * 0.24, torsoH * (0.05 - i * 0.1), frontZ - torsoD * 0.01) * CFrame.Angles(0, 0, rad(-side * 14)))
			end
		end
	end
	if p.Skinless then
		-- fasce muscolari chiare e solchi scuri (Vulcano, Grande Marcia)
		local stripe = skin:Lerp(Color3.fromRGB(236, 150, 120), 0.35)
		local groove = darker(skin, 0.7)
		for i = 0, 3 do
			decor(model, torso, "Fibra" .. i, Vector3.new(torsoW * 0.05, torsoH * 0.8, torsoD * 0.05), if i % 2 == 0 then stripe else groove, CFrame.new((i - 1.5) * torsoW * 0.2, -torsoH * 0.05, frontZ - torsoD * 0.02))
		end
		decor(model, head, "FibraTesta", Vector3.new(headW * 1.02, headH * 0.12, headD * 1.02), stripe, CFrame.new(0, headH * 0.3, 0))
	end
	if p.Armor then
		local plate = Color3.fromRGB(232, 222, 202)
		decor(model, torso, "Pettorale", Vector3.new(torsoW * 0.95, torsoH * 0.5, torsoD * 0.35), plate, CFrame.new(0, torsoH * 0.18, -torsoD * 0.38), { Material = Enum.Material.Marble })
		decor(model, torso, "Ventrale", Vector3.new(torsoW * 0.6, torsoH * 0.35, torsoD * 0.25), plate, CFrame.new(0, -torsoH * 0.22, -torsoD * 0.42), { Material = Enum.Material.Marble })
		decor(model, head, "Elmo", Vector3.new(headW * 1.06, headH * 0.4, headD * 1.06), plate, CFrame.new(0, headH * 0.32, 0), { Material = Enum.Material.Marble })
		decor(model, head, "Visiera", Vector3.new(headW * 0.9, headH * 0.1, headD * 0.12), plate, CFrame.new(0, headH * 0.13, -headD * 0.52), { Material = Enum.Material.Marble })
	end
	if p.Fur then
		for i = 1, 6 do
			local ox = vr:NextNumber(-0.35, 0.35) * torsoW
			local oy = vr:NextNumber(-0.4, 0.45) * torsoH
			local s = vr:NextNumber(0.36, 0.52) * torsoW
			decor(model, torso, "Pelo" .. i, Vector3.one * s, p.Hair, CFrame.new(ox, oy, vr:NextNumber(-0.2, 0.25) * torsoD) * CFrame.Angles(rad(vr:NextNumber(-20, 20)), rad(vr:NextNumber(0, 90)), rad(vr:NextNumber(-20, 20))), { Material = Enum.Material.Fabric, Query = true, Zone = "Body" })
		end
	end
	if p.Crystal then
		for i = 1, 4 do
			local s = vr:NextNumber(0.12, 0.22) * H
			decor(model, torso, "CristalloSchiena" .. i, Vector3.new(s * 0.35, s, s * 0.35), Color3.fromRGB(150, 230, 255), CFrame.new(vr:NextNumber(-0.35, 0.35) * torsoW, vr:NextNumber(0, 0.45) * torsoH, torsoD * 0.45) * CFrame.Angles(rad(vr:NextNumber(-30, 30)), 0, rad(vr:NextNumber(-35, 35))), { Material = Enum.Material.Glass, Transparency = 0.2 })
		end
	end
	if p.Bones then
		local bone = Color3.fromRGB(236, 226, 206)
		for i = 0, 4 do
			decor(model, torso, "Costola" .. i, Vector3.new(torsoW * 1.04, torsoH * 0.05, torsoD * 1.05), bone, CFrame.new(0, torsoH * (0.3 - i * 0.13), 0), { Material = Enum.Material.Marble, Query = true, Zone = "Body" })
		end
		for i = 0, 5 do
			decor(model, torso, "Vertebra" .. i, Vector3.new(torsoW * 0.14, torsoH * 0.12, torsoD * 0.18), bone, CFrame.new(0, torsoH * (0.42 - i * 0.16), torsoD * 0.55), { Material = Enum.Material.Marble })
			decor(model, torso, "Spina" .. i, Vector3.new(torsoW * 0.05, torsoH * 0.22, torsoD * 0.05), bone, CFrame.new(0, torsoH * (0.45 - i * 0.16), torsoD * 0.7) * CFrame.Angles(rad(-35), 0, 0), { Material = Enum.Material.Marble })
		end
		decor(model, head, "Teschio", Vector3.new(headW * 1.04, headH * 0.5, headD * 1.04), bone, CFrame.new(0, headH * 0.27, 0), { Material = Enum.Material.Marble })
		for i = -2, 2 do
			decor(model, head, "Corona" .. i, Vector3.new(headW * 0.07, headH * 0.55, headW * 0.07), bone, CFrame.new(i * headW * 0.18, headH * 0.6, 0) * CFrame.Angles(0, 0, rad(i * 12)), { Material = Enum.Material.Marble })
		end
	end
	if p.Magma then
		local glow = Color3.fromRGB(255, 120, 40)
		for i = 1, 5 do
			decor(model, torso, "Brace" .. i, Vector3.new(torsoW * 0.22, torsoH * 0.18, torsoD * 0.08), glow, CFrame.new(vr:NextNumber(-0.3, 0.3) * torsoW, vr:NextNumber(-0.4, 0.4) * torsoH, frontZ - torsoD * 0.02), { Material = Enum.Material.Neon })
		end
		decor(model, head, "BraceViso", Vector3.new(headW * 0.5, headH * 0.12, headD * 0.06), glow, CFrame.new(0, headH * 0.32, -headD * 0.52), { Material = Enum.Material.Neon })
	end
	if p.Cannon then
		decor(model, torso, "Cannone", Vector3.new(torsoW * 0.9, torsoD * 0.22, torsoD * 0.22), Color3.fromRGB(70, 74, 80), CFrame.new(torsoW * 0.15, torsoH * 0.35, torsoD * 0.6) * CFrame.Angles(0, rad(90), 0), { Shape = "Cylinder", Material = Enum.Material.Metal })
		decor(model, torso, "Sella", Vector3.new(torsoW * 0.8, torsoH * 0.12, torsoD * 0.6), Color3.fromRGB(120, 90, 60), CFrame.new(0, torsoH * 0.3, torsoD * 0.4), { Material = Enum.Material.Leather })
	end
	if p.Hammer then
		local crystal = Color3.fromRGB(170, 230, 255)
		local handle = decor(model, rightHand, "MartelloManico", Vector3.new(armT * 0.25, H * 0.42, armT * 0.25), crystal, CFrame.new(0, -H * 0.12, -armT * 0.2), { Material = Enum.Material.Glass, Transparency = 0.15 })
		decor(model, handle, "MartelloTesta", Vector3.new(armT * 1.6, armT * 0.9, armT * 0.9), crystal, CFrame.new(0, -H * 0.2, 0), { Material = Enum.Material.Glass, Transparency = 0.1 })
	end

	-- VOLTO (blocchi sottili sulla faccia del blocco della testa; davanti = -Z) -----------------
	local faceZ = -headD * 0.5
	-- faccia storta: occhi, naso e bocca ruotati e spostati di lato
	local tilt = 0
	local faceCF = CFrame.new()
	if traits.Crooked then
		tilt = vr:NextNumber(9, 16) * (if vr:NextNumber() < 0.5 then -1 else 1)
		faceCF = CFrame.new(vr:NextNumber(-0.05, 0.05) * headW, vr:NextNumber(-0.02, 0.03) * headH, 0) * CFrame.Angles(0, 0, rad(tilt))
	end
	-- pezzo sul viso: x, y sulla faccia, lift = quanto sporge in più (per gli strati sopra)
	local function onFace(parent: BasePart, name: string, size: Vector3, color: Color3, x: number, y: number, lift: number?, extra: CFrame?, opts: any?): BasePart
		local z = faceZ - size.Z * 0.35 - (lift or 0)
		if parent ~= head then
			-- sulla mandibola: stessa superficie del viso, ma nelle sue coordinate
			z = -headD * 0.43 - size.Z * 0.35 - (lift or 0)
		end
		return decor(model, parent, name, size, color, faceCF * CFrame.new(x, y, z) * (extra or CFrame.new()), opts)
	end

	-- occhi: la parte che si colpisce per accecare ha sempre la stessa misura (invisibile),
	-- quello che si vede cambia da gigante a gigante
	local eyeSize = headH * 0.13 * p.EyeSize
	local eyeY = headH * 0.08
	local glow = p.EyeGlow
	local eyeWhite = Color3.fromRGB(246, 244, 238)
	local pupilColor = Color3.fromRGB(26, 22, 20)
	local eyeMul = if traits.Eyes == "Occhioni" then 1.4 elseif traits.Eyes == "Occhietti" then 0.6 else 1
	for _, side in { -1, 1 } do
		local name = if side < 0 then "LeftEye" else "RightEye"
		local ex = side * headW * 0.21
		local hit = decor(model, head, name, Vector3.new(eyeSize, eyeSize * 0.85, eyeSize * 0.7), eyeWhite, CFrame.new(ex, eyeY, faceZ), { Query = true, Zone = "Eye" })
		hit.Transparency = 1
		local e = math.min(headW * 0.17 * p.EyeSize * eyeMul, headW * 0.36)
		local ey = eyeY
		if traits.Eyes == "Diversi" and side > 0 then
			e *= 1.45
			ey += headH * 0.03
		end
		if traits.Crooked and side > 0 then
			ey += headH * 0.04
		end
		local eh = e * 0.8
		onFace(head, name .. "Bianco", Vector3.new(e, eh, headD * 0.05), glow or eyeWhite, ex, ey, 0, nil, { Material = if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic })
		if not glow then
			if p.Iris then
				onFace(head, name .. "Iride", Vector3.new(e * 0.55, math.min(eh, e * 0.55), headD * 0.03), p.Iris, ex, ey, headD * 0.015)
			end
			local pupil = e * (if traits.Eyes == "Vuoti" then 0.16 else (p.Pupil or 0.4))
			local px = 0
			if traits.Eyes == "Strabici" then
				px = side * e * 0.24
			end
			onFace(head, name .. "Pupilla", Vector3.new(pupil, math.min(pupil, eh * 0.9), headD * 0.03), pupilColor, ex + px, ey - eh * 0.05, headD * 0.03)
		end
		-- palpebre: occhi socchiusi o occhiolino (coprono la parte alta dell'occhio)
		local lid = if traits.Eyes == "Socchiusi" then 0.5 elseif traits.Eyes == "Occhiolino" and side > 0 then 1.05 else 0
		if lid > 0 then
			onFace(head, name .. "Palpebra", Vector3.new(e * 1.1, eh * lid, headD * 0.06), darker(skin, 0.94), ex, ey + eh * (0.5 - lid / 2), headD * 0.045)
		end
		if traits.Extras.Occhiaie or p.Sockets then
			onFace(head, name .. "Occhiaia", Vector3.new(e * 1.1, eh * 0.28, headD * 0.03), darker(skin, 0.72), ex, ey - eh * 0.68, 0)
		end
		-- sopracciglia
		local browY = ey + eh * 0.5 + e * 0.22
		local browColor = if traits.Hair == "Calvo" and look == "Puro" then darker(skin, 0.6) else hairDark
		if traits.Brows ~= "Nessuna" and traits.Brows ~= "Monociglio" then
			local angle = if traits.Brows == "Arrabbiate" then side * 18 elseif traits.Brows == "Tristi" then -side * 15 else side * vr:NextNumber(-6, 6)
			local thick = if traits.Brows == "Folte" then 0.36 else 0.2
			onFace(head, name .. "Sopracciglio", Vector3.new(e * 1.25, e * thick, headD * 0.05), browColor, ex, browY, 0, CFrame.Angles(0, 0, rad(angle)))
		end
		-- orecchie
		local earMul = if traits.Ears == "Grandi" then 1.5 elseif traits.Ears == "Piccole" then 0.6 elseif traits.Ears == "Sventola" then 1.3 else 1
		local earCF = CFrame.new(side * headW * 0.54, headH * 0.02, headD * 0.04)
		if traits.Ears == "Sventola" then
			earCF *= CFrame.Angles(0, rad(-side * 30), 0)
		end
		decor(model, head, name .. "Orecchio", Vector3.new(headW * 0.1, headH * 0.24 * p.Ears * earMul, headD * 0.2 * earMul), skin, earCF)
		decor(model, head, name .. "Conca", Vector3.new(headW * 0.02, headH * 0.14 * p.Ears * earMul, headD * 0.1 * earMul), darker(skin, 0.72), earCF * CFrame.new(side * headW * 0.05, 0, 0))
	end
	if traits.Brows == "Monociglio" then
		onFace(head, "Monociglio", Vector3.new(headW * 0.66, headH * 0.06, headD * 0.05), hairDark, 0, eyeY + headH * 0.15, 0)
	end
	if look == "Cacciatrice" or p.Muscle and not p.Armor and not p.Skinless then
		-- muscoli scoperti intorno agli occhi (tipico dei mutaforma)
		for _, side in { -1, 1 } do
			onFace(head, "MuscoloOcchio" .. side, Vector3.new(eyeSize * 1.5, eyeSize * 0.3, headD * 0.04), Color3.fromRGB(196, 92, 84), side * headW * 0.21, eyeY - eyeSize * 0.62, 0)
		end
	end

	-- naso
	local noseSize = if traits.Nose == "Piccolo" then Vector3.new(0.08, 0.1, 0.07)
		elseif traits.Nose == "Grosso" then Vector3.new(0.2, 0.2, 0.16)
		elseif traits.Nose == "Lungo" then Vector3.new(0.1, 0.13, 0.32)
		elseif traits.Nose == "Schiacciato" then Vector3.new(0.22, 0.1, 0.07)
		else Vector3.new(0.12, 0.17, 0.11)
	local noseX = if traits.Nose == "Storto" then headW * 0.05 else 0
	local noseTurn = if traits.Nose == "Storto" then CFrame.Angles(0, 0, rad(22)) else CFrame.new()
	onFace(head, "Naso", noseSize * Vector3.new(headW, headH, headD), darker(skin, 0.95), noseX, -headH * 0.04, 0, noseTurn)
	if traits.Nose == "Grosso" or traits.Nose == "Schiacciato" then
		for _, side in { -1, 1 } do
			onFace(head, "Narice" .. side, Vector3.new(headW * 0.04, headH * 0.03, headD * 0.02), darker(skin, 0.45), noseX + side * headW * 0.05, -headH * 0.12, noseSize.Z * headD * 0.7)
		end
	end

	-- bocca (sulla mandibola, così si apre davvero) e denti
	local mouthW = headW * math.clamp(p.MouthWidth, 0.35, 0.92)
	local mouthY = -headH * 0.02
	local mouthDark = Color3.fromRGB(64, 20, 22)
	local teeth = Color3.fromRGB(244, 238, 222)
	local style = traits.Mouth
	local function teethRow(y: number, h: number, width: number, count: number, gaps: boolean)
		for i = 1, count do
			if not gaps or vr:NextNumber() < 0.45 then
				local x = (i - (count + 1) / 2) * width / count
				onFace(jaw, "Dente" .. i, Vector3.new(width / count * 0.82, h, headD * 0.03), teeth, x, y, headD * 0.025)
			end
		end
	end
	if style == "Ghigno" or style == "Sdentato" then
		-- il ghigno dei giganti: bocca larga piena di denti, angoli all'insù
		onFace(jaw, "Bocca", Vector3.new(mouthW, headH * 0.13, headD * 0.04), mouthDark, 0, mouthY, 0)
		local n = math.clamp(math.floor(mouthW / (headW * 0.085) + 0.5), 4, 10)
		teethRow(mouthY + headH * 0.02, headH * 0.08, mouthW * 0.94, n, style == "Sdentato")
		for _, side in { -1, 1 } do
			onFace(jaw, "AngoloBocca" .. side, Vector3.new(headW * 0.1, headH * 0.03, headD * 0.04), mouthDark, side * (mouthW * 0.5 + headW * 0.03), mouthY + headH * 0.05, 0, CFrame.Angles(0, 0, rad(side * 35)))
		end
	elseif style == "Urlo" then
		onFace(jaw, "Bocca", Vector3.new(mouthW * 0.8, headH * 0.24, headD * 0.04), mouthDark, 0, mouthY - headH * 0.04, 0)
		teethRow(mouthY + headH * 0.05, headH * 0.05, mouthW * 0.76, 6, false)
		onFace(jaw, "Lingua", Vector3.new(mouthW * 0.4, headH * 0.06, headD * 0.03), Color3.fromRGB(176, 72, 80), 0, mouthY - headH * 0.12, headD * 0.02)
	elseif style == "Dentoni" then
		onFace(jaw, "Bocca", Vector3.new(mouthW * 0.6, headH * 0.06, headD * 0.04), mouthDark, 0, mouthY + headH * 0.02, 0)
		for _, side in { -1, 1 } do
			onFace(jaw, "Dentone" .. side, Vector3.new(headW * 0.085, headH * 0.11, headD * 0.04), teeth, side * headW * 0.047, mouthY - headH * 0.02, headD * 0.025)
		end
	elseif style == "Lingua" then
		onFace(jaw, "Bocca", Vector3.new(mouthW * 0.7, headH * 0.05, headD * 0.04), mouthDark, 0, mouthY, 0)
		onFace(jaw, "Lingua", Vector3.new(headW * 0.15, headH * 0.13, headD * 0.04), Color3.fromRGB(196, 80, 92), headW * 0.06, mouthY - headH * 0.07, headD * 0.03)
	elseif style == "Sorrisetto" then
		onFace(jaw, "Bocca", Vector3.new(mouthW * 0.6, headH * 0.03, headD * 0.04), mouthDark, 0, mouthY, 0)
		for _, side in { -1, 1 } do
			onFace(jaw, "AngoloBocca" .. side, Vector3.new(headW * 0.08, headH * 0.03, headD * 0.04), mouthDark, side * mouthW * 0.33, mouthY + headH * 0.02, 0, CFrame.Angles(0, 0, rad(side * 30)))
		end
	elseif style == "Storta" then
		onFace(jaw, "Bocca", Vector3.new(mouthW * 0.75, headH * 0.035, headD * 0.04), mouthDark, headW * 0.06, mouthY, 0, CFrame.Angles(0, 0, rad(14)))
	else -- Chiusa
		onFace(jaw, "Bocca", Vector3.new(mouthW * 0.7, headH * 0.03, headD * 0.04), if p.Lips then darker(skin, 0.7) else mouthDark, 0, mouthY, 0)
	end

	-- dettagli che cambiano da gigante a gigante
	local extras = traits.Extras
	if extras.Barba then
		decor(model, jaw, "Barba", Vector3.new(headW * 0.86, headH * 0.3, headD * 0.5), darker(p.Hair, 0.95), CFrame.new(0, -headH * 0.22, -headD * 0.2), { Material = Enum.Material.Fabric })
	end
	if extras.Baffi then
		onFace(head, "Baffi", Vector3.new(mouthW * 0.9, headH * 0.06, headD * 0.06), hairDark, 0, -headH * 0.15, headD * 0.02)
	end
	if extras.Cicatrice then
		local side = if vr:NextNumber() < 0.5 then -1 else 1
		onFace(head, "Cicatrice", Vector3.new(headW * 0.035, headH * 0.36, headD * 0.02), Color3.fromRGB(150, 70, 66), side * headW * 0.22, headH * 0.06, headD * 0.05, CFrame.Angles(0, 0, rad(side * 28)))
	end
	if extras.Lentiggini then
		for i = 1, 8 do
			local side = if i % 2 == 0 then -1 else 1
			onFace(head, "Lentiggine" .. i, Vector3.new(headW * 0.025, headW * 0.025, headD * 0.02), darker(skin, 0.7), side * headW * vr:NextNumber(0.1, 0.3), -headH * vr:NextNumber(0.02, 0.1), 0)
		end
	end
	if extras.Guance then
		for _, side in { -1, 1 } do
			onFace(head, "Guancia" .. side, Vector3.new(headW * 0.14, headH * 0.06, headD * 0.02), Color3.fromRGB(226, 120, 116):Lerp(skin, 0.3), side * headW * 0.27, -headH * 0.06, 0)
		end
	end
	if extras.Neo then
		onFace(head, "Neo", Vector3.new(headW * 0.04, headW * 0.04, headD * 0.02), Color3.fromRGB(70, 46, 36), headW * vr:NextNumber(-0.3, 0.3), -headH * vr:NextNumber(0.05, 0.15), 0)
	end
	if extras.Rughe and (traits.Hair == "Calvo" or traits.Hair == "Chierica" or traits.Hair == "Rasato") then
		for i = 1, 2 do
			onFace(head, "Ruga" .. i, Vector3.new(headW * 0.5, headH * 0.02, headD * 0.02), darker(skin, 0.8), 0, headH * (0.28 + i * 0.06), 0)
		end
	end
	if extras.Macchie then
		for i = 1, 3 do
			local s = torsoW * vr:NextNumber(0.12, 0.22)
			decor(model, torso, "Macchia" .. i, Vector3.new(s, s * 0.8, torsoD * 0.02), darker(skin, 0.88), CFrame.new(vr:NextNumber(-0.35, 0.35) * torsoW, vr:NextNumber(-0.4, 0.4) * torsoH, frontZ - torsoD * 0.005))
		end
	end
	if p.Mask then
		local mask = Color3.fromRGB(240, 234, 222)
		decor(model, head, "Maschera", Vector3.new(headW * 0.98, headH * 0.26, headD * 0.08), mask, CFrame.new(0, headH * 0.2, faceZ - headD * 0.03), { Material = Enum.Material.Marble })
		decor(model, jaw, "MascheraMento", Vector3.new(headW * 0.7, headH * 0.14, headD * 0.08), mask, CFrame.new(0, -headH * 0.12, -headD * 0.46), { Material = Enum.Material.Marble })
	end

	-- CAPELLI (blocchi) ------------------------------------------------------------------------
	local hairStyle = traits.Hair
	local top = headH * 0.5
	local function cap(h: number, color: Color3?)
		decor(model, head, "Capelli", Vector3.new(headW * 1.06, headH * h, headD * 1.06), color or hair, CFrame.new(0, top - headH * h / 2 + headH * 0.06, headD * 0.02))
	end
	if hairStyle == "Corto" then
		cap(0.3)
	elseif hairStyle == "Rasato" then
		cap(0.2, skin:Lerp(hair, 0.55))
	elseif hairStyle == "Lungo" then
		cap(0.3)
		decor(model, head, "CapelliLunghi", Vector3.new(headW * 1.06, headH * 0.95, headD * 0.22), hair, CFrame.new(0, -headH * 0.08, headD * 0.48))
		for _, side in { -1, 1 } do
			decor(model, head, "CiuffoLato" .. side, Vector3.new(headW * 0.1, headH * 0.6, headD * 0.5), hair, CFrame.new(side * headW * 0.54, headH * 0.08, headD * 0.24))
		end
	elseif hairStyle == "Caschetto" then
		cap(0.32)
		for _, side in { -1, 1 } do
			decor(model, head, "Caschetto" .. side, Vector3.new(headW * 0.1, headH * 0.55, headD * 1.0), hair, CFrame.new(side * headW * 0.54, headH * 0.12, headD * 0.03))
		end
		decor(model, head, "Frangia", Vector3.new(headW * 0.98, headH * 0.12, headD * 0.08), hair, CFrame.new(0, headH * 0.26, faceZ - headD * 0.02))
	elseif hairStyle == "Ciuffo" then
		cap(0.2)
		decor(model, head, "Ciuffo", Vector3.new(headW * 0.5, headH * 0.3, headD * 0.4), hair, CFrame.new(0, top + headH * 0.1, -headD * 0.22) * CFrame.Angles(rad(-20), 0, 0))
	elseif hairStyle == "Cresta" then
		for i = -2, 2 do
			decor(model, head, "Cresta" .. i, Vector3.new(headW * 0.16, headH * (0.3 - math.abs(i) * 0.04), headD * 0.18), hair, CFrame.new(0, top + headH * 0.1, i * headD * 0.19))
		end
	elseif hairStyle == "Spettinato" then
		cap(0.3)
		for i = 1, 6 do
			local s = headW * vr:NextNumber(0.2, 0.3)
			decor(model, head, "Ciocca" .. i, Vector3.new(s, s * 1.5, s), hair:Lerp(hairDark, vr:NextNumber()), CFrame.new(vr:NextNumber(-0.42, 0.42) * headW, top + headH * vr:NextNumber(0.02, 0.12), vr:NextNumber(-0.35, 0.4) * headD) * CFrame.Angles(rad(vr:NextNumber(-40, 40)), rad(vr:NextNumber(0, 90)), rad(vr:NextNumber(-40, 40))))
		end
	elseif hairStyle == "Codino" then
		cap(0.28)
		decor(model, head, "Codino", Vector3.new(headW * 0.22, headH * 0.42, headD * 0.2), hair, CFrame.new(0, headH * 0.08, headD * 0.6) * CFrame.Angles(rad(22), 0, 0))
		decor(model, head, "Elastico", Vector3.new(headW * 0.24, headH * 0.06, headD * 0.22), Color3.fromRGB(180, 40, 44), CFrame.new(0, headH * 0.24, headD * 0.56) * CFrame.Angles(rad(22), 0, 0))
	elseif hairStyle == "Riga" then
		cap(0.32)
		decor(model, head, "Frangia", Vector3.new(headW * 0.72, headH * 0.14, headD * 0.12), hair, CFrame.new(headW * 0.16, headH * 0.28, faceZ - headD * 0.02) * CFrame.Angles(0, 0, rad(-10)))
		decor(model, head, "Riga", Vector3.new(headW * 0.03, headH * 0.02, headD * 0.8), skin, CFrame.new(-headW * 0.2, top + headH * 0.065, 0))
	elseif hairStyle == "Chierica" then
		-- calvo in cima, corona di capelli ai lati e dietro
		for _, side in { -1, 1 } do
			decor(model, head, "Corona" .. side, Vector3.new(headW * 0.1, headH * 0.26, headD * 0.92), hair, CFrame.new(side * headW * 0.53, headH * 0.22, headD * 0.04))
		end
		decor(model, head, "CoronaDietro", Vector3.new(headW * 1.06, headH * 0.26, headD * 0.1), hair, CFrame.new(0, headH * 0.22, headD * 0.53))
	elseif hairStyle == "Afro" then
		decor(model, head, "Afro", Vector3.new(headW * 1.45, headH * 0.75, headD * 1.35), hair, CFrame.new(0, top + headH * 0.12, headD * 0.08), { Material = Enum.Material.Fabric })
	elseif hairStyle == "Riccio" then
		cap(0.24)
		for i = 1, 6 do
			local s = headW * vr:NextNumber(0.3, 0.4)
			decor(model, head, "Riccio" .. i, Vector3.one * s, hair, CFrame.new(vr:NextNumber(-0.32, 0.32) * headW, top + headH * vr:NextNumber(0.02, 0.1), vr:NextNumber(-0.3, 0.35) * headD) * CFrame.Angles(0, rad(vr:NextNumber(0, 90)), 0), { Material = Enum.Material.Fabric })
		end
	elseif hairStyle == "Pelo" then
		cap(0.3)
		decor(model, head, "Criniera", Vector3.new(headW * 1.3, headH * 1.0, headD * 0.85), hair, CFrame.new(0, headH * 0.05, headD * 0.24), { Material = Enum.Material.Fabric })
		decor(model, head, "BarbaPelo", Vector3.new(headW * 0.8, headH * 0.35, headD * 0.4), hair, CFrame.new(0, -headH * 0.42, -headD * 0.28), { Material = Enum.Material.Fabric })
	end
	-- (Calvo: niente capelli)

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
	mouthAtt.Position = Vector3.new(0, -headH * 0.22, faceZ)
	mouthAtt.Parent = head
	local steamAtt = Instance.new("Attachment")
	steamAtt.Name = "SteamAtt"
	steamAtt.Parent = torso

	-- Colosso d'Oro: pelle d'oro lucida (occhi, denti e capelli restano com'erano)
	if look == "Dorato" then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Material ~= Enum.Material.Neon and d.Transparency < 0.9 then
				local c = d.Color
				if c.R > 0.55 and c.B < 0.45 and c.R - c.B > 0.25 then
					d.Material = Enum.Material.Foil
					d.Reflectance = 0.18
				end
			end
		end
	end

	model.PrimaryPart = root
	model:SetAttribute("Height", H)
	model:SetAttribute("HipHeight", hipHeight)
	model:SetAttribute("Look", look)
	model:SetAttribute("Seed", seed)
	model:SetAttribute("HeadTilt", headTilt + tilt * 0.5)
	model:SetAttribute("Archetype", p.Archetype or "")
	model:SetAttribute("CrawlPreferred", p.Crawl == true)
	model:SetAttribute("JawIdle", p.Gape or 0)
	model:SetAttribute("Hunch", p.Hunch == true)
	model:SetAttribute("Aspetto", ("%s/%s/%s/%s/%s%s"):format(traits.Hair, traits.Eyes, traits.Nose, traits.Mouth, traits.Brows, if traits.Crooked then "/storta" else ""))
	return model
end

return TitanBuilder
