--[[
	OutfitService
	Veste i personaggi (giocatori e PNG) con l'equipaggiamento del gioco:
	Rampini a gas con bombole e foderi, cinghie, giacca, pantaloni bianchi, stivali,
	mantello con stemma, lame in mano, Lance Dirompenti sugli avambracci...
	Tutto costruito con parti saldate al corpo R15 (nessun asset esterno).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Data.Items)

local OutfitService = {}

local FOLDER_NAME = "Equipaggiamento"

local COLORS = {
	Leather = Color3.fromRGB(58, 40, 30),
	Strap = Color3.fromRGB(40, 30, 26),
	Metal = Color3.fromRGB(150, 156, 164),
	DarkMetal = Color3.fromRGB(66, 70, 78),
	Pants = Color3.fromRGB(232, 228, 216),
	Boots = Color3.fromRGB(46, 34, 28),
}

local UNIFORMS = {
	Cadetto = { Jacket = Color3.fromRGB(150, 110, 70), Pants = true, Emblem = "Cadetti" },
	Guarnigione = { Jacket = Color3.fromRGB(140, 100, 62), Pants = true, Emblem = "Torre" },
	Falchi = { Jacket = Color3.fromRGB(135, 95, 58), Pants = true, Emblem = "Falco", Cloak = Color3.fromRGB(46, 92, 58) },
	Polizia = { Jacket = Color3.fromRGB(128, 92, 60), Pants = true, Emblem = "Corona", Cloak = Color3.fromRGB(40, 78, 52) },
	Valdoria = { Jacket = Color3.fromRGB(88, 96, 66), Pants = false, Long = true, Emblem = "Valdoria", PantsColor = Color3.fromRGB(80, 86, 60) },
	NuovoCorpo = { Jacket = Color3.fromRGB(28, 28, 32), Pants = false, Long = true, Emblem = "Falco", PantsColor = Color3.fromRGB(30, 30, 34) },
	Cristallo = { Jacket = Color3.fromRGB(170, 225, 245), Pants = true, Crystal = true },
	Civile = { Jacket = nil, Pants = false },
	Scienziata = { Jacket = Color3.fromRGB(214, 210, 200), Pants = true, Long = true },
	Mercante = { Jacket = Color3.fromRGB(60, 40, 70), Long = true, Cloak = Color3.fromRGB(50, 32, 60) },
	Nobile = { Jacket = Color3.fromRGB(120, 30, 40), Long = true, Trim = Color3.fromRGB(220, 180, 90) },
	Ombra = { Jacket = Color3.fromRGB(32, 30, 32), Long = true, PantsColor = Color3.fromRGB(36, 34, 36), Hat = true },
	Vael = { Jacket = Color3.fromRGB(56, 60, 64), Long = true, PantsColor = Color3.fromRGB(50, 54, 58), Armband = Color3.fromRGB(80, 200, 120) },
}

OutfitService.Uniforms = UNIFORMS

local function getPart(character: Model, name: string): BasePart?
	local part = character:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

local function attach(folder: Instance, parent: BasePart, name: string, size: Vector3, color: Color3, offset: CFrame, props: { [string]: any }?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05))
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = parent.CFrame * offset
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.Anchored = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for key, value in props do
			(part :: any)[key] = value
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = part
	weld.Parent = part
	part.Parent = folder
	return part
end

local function shell(folder: Instance, parent: BasePart?, name: string, color: Color3, grow: number, heightFrac: number, offsetY: number, props)
	if not parent then
		return nil
	end
	local s = parent.Size
	return attach(folder, parent, name, Vector3.new(s.X + grow, s.Y * heightFrac, s.Z + grow), color, CFrame.new(0, offsetY * s.Y, 0), props)
end

-- Stemmi disegnati con elementi dell'interfaccia --------------------------------------------

local function frame(parent: Instance, color: Color3, pos: UDim2, size: UDim2, rotation: number?, corner: boolean?)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = pos
	f.Size = size
	f.Rotation = rotation or 0
	if corner then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = f
	end
	f.Parent = parent
	return f
end

function OutfitService.DrawEmblem(parent: Instance, kind: string)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.4)
	holder.Size = UDim2.fromScale(0.62, 0.42)
	holder.Parent = parent
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = holder
	if kind == "Falco" then
		-- Corpo dei Falchi: falco d'argento ad ali spiegate su scudo verde
		frame(holder, Color3.fromRGB(36, 82, 56), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.92, 0.92), 0, true)
		frame(holder, Color3.fromRGB(214, 180, 96), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.8, 0.8), 0, true).BackgroundTransparency = 0.75
		for _, side in { -1, 1 } do
			for i = 0, 2 do
				frame(holder, Color3.fromRGB(226, 228, 232), UDim2.fromScale(0.5 + side * (0.16 + i * 0.07), 0.42 + i * 0.06), UDim2.fromScale(0.3 - i * 0.05, 0.07), side * (-25 + i * 15), true)
			end
		end
		frame(holder, Color3.fromRGB(226, 228, 232), UDim2.fromScale(0.5, 0.52), UDim2.fromScale(0.12, 0.32), 0, true)
		frame(holder, Color3.fromRGB(226, 228, 232), UDim2.fromScale(0.5, 0.3), UDim2.fromScale(0.11, 0.11), 0, true)
		frame(holder, Color3.fromRGB(220, 170, 60), UDim2.fromScale(0.5, 0.36), UDim2.fromScale(0.05, 0.05), 45, false)
	elseif kind == "Torre" then
		-- Guarnigione: torre grigia su campo rosso
		frame(holder, Color3.fromRGB(150, 36, 40), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.9, 0.9), 0, true)
		frame(holder, Color3.fromRGB(205, 200, 190), UDim2.fromScale(0.5, 0.58), UDim2.fromScale(0.36, 0.42), 0, false)
		for i = -1, 1 do
			frame(holder, Color3.fromRGB(205, 200, 190), UDim2.fromScale(0.5 + i * 0.13, 0.33), UDim2.fromScale(0.09, 0.1), 0, false)
		end
		frame(holder, Color3.fromRGB(60, 40, 30), UDim2.fromScale(0.5, 0.68), UDim2.fromScale(0.1, 0.18), 0, false)
	elseif kind == "Corona" then
		-- Gendarmeria Reale: corona d'oro su campo viola
		frame(holder, Color3.fromRGB(70, 40, 100), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.88, 0.88), 0, true)
		frame(holder, Color3.fromRGB(236, 196, 90), UDim2.fromScale(0.5, 0.62), UDim2.fromScale(0.5, 0.12), 0, false)
		for i = -1, 1 do
			frame(holder, Color3.fromRGB(236, 196, 90), UDim2.fromScale(0.5 + i * 0.18, 0.47), UDim2.fromScale(0.12, 0.12), 45, false)
			frame(holder, Color3.fromRGB(220, 60, 70), UDim2.fromScale(0.5 + i * 0.18, 0.37), UDim2.fromScale(0.06, 0.06), 0, true)
		end
	elseif kind == "Valdoria" then
		-- esercito di Valdoria: sole bianco a otto raggi su cerchio nero
		frame(holder, Color3.fromRGB(34, 34, 38), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.86, 0.86), 0, true)
		for i = 0, 3 do
			frame(holder, Color3.fromRGB(235, 232, 220), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.07, 0.66), i * 45, false)
		end
		frame(holder, Color3.fromRGB(200, 40, 40), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.3, 0.3), 0, true)
	elseif kind == "Cadetti" then
		-- cadetti: spada verticale su scudo marrone
		frame(holder, Color3.fromRGB(120, 80, 40), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.8, 0.8), 0, true)
		frame(holder, Color3.fromRGB(210, 210, 215), UDim2.fromScale(0.5, 0.48), UDim2.fromScale(0.08, 0.66), 0, false)
		frame(holder, Color3.fromRGB(214, 180, 96), UDim2.fromScale(0.5, 0.64), UDim2.fromScale(0.36, 0.06), 0, false)
	end
	return holder
end

local function addEmblem(part: BasePart, kind: string?, face: Enum.NormalId)
	if not kind then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Stemma"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 1
	gui.Parent = part
	OutfitService.DrawEmblem(gui, kind)
end

-- Pezzi dell'equipaggiamento ----------------------------------------------------------------

local function buildODM(folder: Instance, character: Model)
	local lower = getPart(character, "LowerTorso")
	if not lower then
		return
	end
	local s = lower.Size
	-- cintura
	attach(folder, lower, "Cintura", Vector3.new(s.X + 0.1, 0.2, s.Z + 0.1), COLORS.Leather, CFrame.new(0, s.Y * 0.25, 0), { Material = Enum.Material.Leather })
	-- foderi delle lame sui fianchi
	for _, side in { -1, 1 } do
		local box = attach(folder, lower, if side < 0 then "FoderoSinistro" else "FoderoDestro", Vector3.new(0.34, 0.62, 1.7), COLORS.DarkMetal, CFrame.new(side * (s.X * 0.5 + 0.2), -0.12, 0.15), { Material = Enum.Material.Metal, Reflectance = 0.1 })
		attach(folder, box, "Lame", Vector3.new(0.36, 0.5, 0.25), COLORS.Metal, CFrame.new(0, 0.05, -0.8), { Material = Enum.Material.Metal, Reflectance = 0.3 })
		attach(folder, box, "Gancio", Vector3.new(0.2, 0.2, 0.32), COLORS.Strap, CFrame.new(0, 0.3, 0.6))
	end
	-- bombole del gas sulla schiena
	for i, y in { 0.22, -0.2 } do
		attach(folder, lower, "Bombola" .. i, Vector3.new(1.45, 0.4, 0.4), COLORS.Metal, CFrame.new(0, y, s.Z * 0.5 + 0.25), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal, Reflectance = 0.25 })
	end
	attach(folder, lower, "Motore", Vector3.new(0.5, 0.55, 0.36), COLORS.DarkMetal, CFrame.new(0, 0, s.Z * 0.5 + 0.12), { Material = Enum.Material.Metal })
	-- punti di uscita dei cavi (usati dal client per disegnare i cavi)
	for _, side in { -1, 1 } do
		local att = Instance.new("Attachment")
		att.Name = if side < 0 then "CavoSinistro" else "CavoDestro"
		att.Position = Vector3.new(side * (s.X * 0.5 + 0.25), 0, -0.2)
		att.Parent = lower
	end
	-- cinghie sulle cosce
	for _, name in { "LeftUpperLeg", "RightUpperLeg" } do
		local leg = getPart(character, name)
		if leg then
			attach(folder, leg, "Cinghia", Vector3.new(leg.Size.X + 0.08, 0.14, leg.Size.Z + 0.08), COLORS.Strap, CFrame.new(0, leg.Size.Y * 0.1, 0), { Material = Enum.Material.Leather })
			attach(folder, leg, "Cinghia2", Vector3.new(leg.Size.X + 0.08, 0.12, leg.Size.Z + 0.08), COLORS.Strap, CFrame.new(0, -leg.Size.Y * 0.25, 0), { Material = Enum.Material.Leather })
		end
	end
	-- bretelle sul petto
	local upper = getPart(character, "UpperTorso")
	if upper then
		local u = upper.Size
		for _, side in { -1, 1 } do
			attach(folder, upper, "Bretella", Vector3.new(0.14, u.Y * 0.98, 0.05), COLORS.Strap, CFrame.new(side * u.X * 0.22, 0, -u.Z * 0.5 - 0.09), { Material = Enum.Material.Leather })
			attach(folder, upper, "BretellaRetro", Vector3.new(0.14, u.Y * 0.98, 0.05), COLORS.Strap, CFrame.new(side * u.X * 0.22, 0, u.Z * 0.5 + 0.09), { Material = Enum.Material.Leather })
		end
		attach(folder, upper, "Fascia", Vector3.new(u.X + 0.18, 0.14, u.Z + 0.18), COLORS.Strap, CFrame.new(0, -u.Y * 0.2, 0), { Material = Enum.Material.Leather })
	end
end

local function buildBlades(folder: Instance, character: Model, bladeDef)
	for _, handName in { "RightHand", "LeftHand" } do
		local hand = getPart(character, handName)
		if hand then
			local handle = attach(folder, hand, "Impugnatura", Vector3.new(0.28, 0.32, 0.7), COLORS.DarkMetal, CFrame.new(0, -0.1, -0.2), { Material = Enum.Material.Metal })
			local blade = attach(folder, handle, "Lama", Vector3.new(0.08, 0.34, 4.4), bladeDef.BladeColor, CFrame.new(0, 0, -2.5), {
				Material = if bladeDef.Glow then Enum.Material.Neon else Enum.Material.Metal,
				Reflectance = if bladeDef.Glow then 0 else 0.35,
			})
			blade:SetAttribute("TrailColor", bladeDef.TrailColor)
			local a0 = Instance.new("Attachment")
			a0.Name = "LamaBase"
			a0.Position = Vector3.new(0, 0, 2.1)
			a0.Parent = blade
			local a1 = Instance.new("Attachment")
			a1.Name = "LamaPunta"
			a1.Position = Vector3.new(0, 0, -2.2)
			a1.Parent = blade
			local trail = Instance.new("Trail")
			trail.Name = "Scia"
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Color = ColorSequence.new(bladeDef.TrailColor)
			trail.LightEmission = 0.6
			trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
			trail.Lifetime = 0.18
			trail.MinLength = 0.05
			trail.FaceCamera = true
			trail.Enabled = false
			trail.Parent = blade
		end
	end
end

local function buildRanged(folder: Instance, character: Model, rangedDef)
	local kind = rangedDef.Kind
	if kind == "Lancia" or kind == "Cannone" then
		for _, armName in { "RightLowerArm", "LeftLowerArm" } do
			local arm = getPart(character, armName)
			if arm then
				local tube = attach(folder, arm, "Lanciatore", Vector3.new(1.4, 0.32, 0.32), COLORS.DarkMetal, CFrame.new(0, 0, -0.25) * CFrame.Angles(0, 0, math.rad(90)), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal })
				attach(folder, tube, "Punta", Vector3.new(0.5, 0.2, 0.2), rangedDef.ProjectileColor, CFrame.new(-0.85, 0, 0), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon })
			end
		end
	elseif kind == "Pistola" then
		for _, handName in { "RightHand", "LeftHand" } do
			local hand = getPart(character, handName)
			if hand then
				attach(folder, hand, "Canna", Vector3.new(0.16, 0.16, 1.0), Color3.fromRGB(40, 40, 44), CFrame.new(0, 0.12, -0.55), { Material = Enum.Material.Metal })
			end
		end
	elseif kind == "Fucile" then
		local upper = getPart(character, "UpperTorso")
		if upper then
			local rifle = attach(folder, upper, "Fucile", Vector3.new(0.18, 4.2, 0.28), Color3.fromRGB(92, 64, 40), CFrame.new(0.2, 0, upper.Size.Z * 0.5 + 0.3) * CFrame.Angles(0, 0, math.rad(30)), { Material = Enum.Material.Wood })
			attach(folder, rifle, "CannaFucile", Vector3.new(0.12, 2.2, 0.12), Color3.fromRGB(40, 40, 44), CFrame.new(0, 1.6, 0), { Material = Enum.Material.Metal })
		end
	elseif kind == "Segnalatore" then
		local lower = getPart(character, "LowerTorso")
		if lower then
			attach(folder, lower, "PistolaRazzi", Vector3.new(0.22, 0.5, 0.7), Color3.fromRGB(150, 40, 30), CFrame.new(lower.Size.X * 0.5 + 0.5, 0.2, -0.3), { Material = Enum.Material.Metal })
		end
	end
end

local function buildCloak(folder: Instance, character: Model, color: Color3, trim: Color3?, emblem: string?)
	local upper = getPart(character, "UpperTorso")
	if not upper then
		return
	end
	local u = upper.Size
	local height = u.Y * 1.9
	local width = u.X * 1.08
	local cloak = Instance.new("Part")
	cloak.Name = "Mantello"
	cloak.Size = Vector3.new(width, height, 0.12)
	cloak.Color = color
	cloak.Material = Enum.Material.Fabric
	cloak.CanCollide = false
	cloak.CanTouch = false
	cloak.CanQuery = false
	cloak.Massless = true
	cloak.CastShadow = true
	-- articolazione "Cloak": il client la fa svolazzare
	local joint = Instance.new("Motor6D")
	joint.Name = "Cloak"
	joint.Part0 = upper
	joint.Part1 = cloak
	joint.C0 = CFrame.new(0, u.Y * 0.48, u.Z * 0.5 + 0.08)
	joint.C1 = CFrame.new(0, height * 0.5, 0)
	cloak.CFrame = upper.CFrame * joint.C0 * joint.C1:Inverse()
	joint.Parent = cloak
	cloak.Parent = folder
	-- cappuccio arrotolato sulle spalle
	attach(folder, upper, "Cappuccio", Vector3.new(u.X * 0.9, 0.35, u.Z * 0.9), color, CFrame.new(0, u.Y * 0.52, u.Z * 0.18), { Material = Enum.Material.Fabric })
	if trim then
		attach(folder, cloak, "Bordo", Vector3.new(width + 0.04, 0.12, 0.14), trim, CFrame.new(0, -height * 0.5 + 0.06, 0), { Material = Enum.Material.Fabric })
	end
	addEmblem(cloak, emblem, Enum.NormalId.Back)
end

local HAIR_SHAPES = {
	Corto = function(folder, head, color)
		attach(folder, head, "Capelli", head.Size * Vector3.new(1.08, 0.55, 1.1), color, CFrame.new(0, head.Size.Y * 0.32, 0.04), { Material = Enum.Material.Fabric })
	end,
	Rasato = function(folder, head, color)
		attach(folder, head, "Capelli", head.Size * Vector3.new(1.04, 0.3, 1.04), color, CFrame.new(0, head.Size.Y * 0.4, 0.02), { Material = Enum.Material.Fabric })
	end,
	Lungo = function(folder, head, color)
		attach(folder, head, "Capelli", head.Size * Vector3.new(1.1, 0.55, 1.12), color, CFrame.new(0, head.Size.Y * 0.32, 0.04), { Material = Enum.Material.Fabric })
		attach(folder, head, "CapelliLunghi", head.Size * Vector3.new(1.05, 1.1, 0.35), color, CFrame.new(0, -head.Size.Y * 0.2, head.Size.Z * 0.42), { Material = Enum.Material.Fabric })
	end,
	Coda = function(folder, head, color)
		attach(folder, head, "Capelli", head.Size * Vector3.new(1.08, 0.55, 1.1), color, CFrame.new(0, head.Size.Y * 0.32, 0.04), { Material = Enum.Material.Fabric })
		attach(folder, head, "Coda", Vector3.new(0.35, 0.9, 0.35), color, CFrame.new(0, -head.Size.Y * 0.05, head.Size.Z * 0.62) * CFrame.Angles(math.rad(20), 0, 0), { Material = Enum.Material.Fabric })
	end,
	Chignon = function(folder, head, color)
		attach(folder, head, "Capelli", head.Size * Vector3.new(1.08, 0.55, 1.1), color, CFrame.new(0, head.Size.Y * 0.32, 0.04), { Material = Enum.Material.Fabric })
		attach(folder, head, "Chignon", Vector3.new(0.55, 0.55, 0.55), color, CFrame.new(0, head.Size.Y * 0.45, head.Size.Z * 0.45), { Shape = Enum.PartType.Ball, Material = Enum.Material.Fabric })
	end,
	Ricci = function(folder, head, color)
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			attach(folder, head, "Riccio" .. i, Vector3.new(0.5, 0.5, 0.5), color, CFrame.new(math.cos(a) * head.Size.X * 0.36, head.Size.Y * 0.36, math.sin(a) * head.Size.Z * 0.36 + 0.05), { Shape = Enum.PartType.Ball, Material = Enum.Material.Fabric })
		end
	end,
}

local function buildLookExtras(folder: Instance, character: Model, look)
	local head = getPart(character, "Head")
	if not head then
		return
	end
	if look.HairStyle and look.HairStyle ~= "Calvo" and HAIR_SHAPES[look.HairStyle] then
		HAIR_SHAPES[look.HairStyle](folder, head, look.Hair or Color3.fromRGB(50, 40, 30))
	end
	if look.Beard then
		attach(folder, head, "Barba", head.Size * Vector3.new(0.75, 0.35, 0.4), look.Hair or Color3.fromRGB(60, 50, 40), CFrame.new(0, -head.Size.Y * 0.38, -head.Size.Z * 0.32), { Material = Enum.Material.Fabric })
	end
	if look.Glasses then
		for _, side in { -1, 1 } do
			attach(folder, head, "Lente", Vector3.new(0.32, 0.26, 0.05), Color3.fromRGB(150, 220, 200), CFrame.new(side * head.Size.X * 0.2, head.Size.Y * 0.08, -head.Size.Z * 0.52), { Material = Enum.Material.Glass, Transparency = 0.3 })
		end
		attach(folder, head, "Montatura", Vector3.new(head.Size.X * 0.85, 0.06, 0.06), Color3.fromRGB(30, 30, 30), CFrame.new(0, head.Size.Y * 0.18, -head.Size.Z * 0.52))
	end
	if look.Hat then
		attach(folder, head, "Tesa", Vector3.new(head.Size.X * 1.5, 0.08, head.Size.Z * 1.5), Color3.fromRGB(50, 40, 32), CFrame.new(0, head.Size.Y * 0.42, 0), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Fabric, CFrame = head.CFrame * CFrame.new(0, head.Size.Y * 0.42, 0) * CFrame.Angles(0, 0, math.rad(90)) })
		attach(folder, head, "Cappello", Vector3.new(head.Size.X * 0.95, head.Size.Y * 0.45, head.Size.Z * 0.95), Color3.fromRGB(60, 48, 38), CFrame.new(0, head.Size.Y * 0.62, 0), { Material = Enum.Material.Fabric })
	end
	if look.Hood then
		attach(folder, head, "Cappuccio", head.Size * Vector3.new(1.2, 1.1, 1.2), Color3.fromRGB(40, 34, 40), CFrame.new(0, head.Size.Y * 0.08, head.Size.Z * 0.1), { Material = Enum.Material.Fabric })
	end
	if look.Scarf then
		attach(folder, head, "Sciarpa", Vector3.new(head.Size.X * 1.05, 0.38, head.Size.Z * 1.05), Color3.fromRGB(180, 30, 36), CFrame.new(0, -head.Size.Y * 0.62, 0), { Material = Enum.Material.Fabric })
	end
	if look.Apron then
		local upper = getPart(character, "UpperTorso")
		if upper then
			attach(folder, upper, "Grembiule", Vector3.new(upper.Size.X * 0.8, upper.Size.Y * 1.5, 0.08), Color3.fromRGB(110, 80, 56), CFrame.new(0, -upper.Size.Y * 0.3, -upper.Size.Z * 0.5 - 0.06), { Material = Enum.Material.Leather })
		end
	end
end

local function buildAccessory(folder: Instance, character: Model, def)
	local visual = def.Visual
	if not visual then
		return
	end
	local head = getPart(character, "Head")
	if visual == "Sciarpa" and head then
		attach(folder, head, "Sciarpa", Vector3.new(head.Size.X * 1.08, 0.4, head.Size.Z * 1.08), Color3.fromRGB(178, 26, 34), CFrame.new(0, -head.Size.Y * 0.62, 0), { Material = Enum.Material.Fabric })
		attach(folder, head, "SciarpaCoda", Vector3.new(0.4, 1.3, 0.1), Color3.fromRGB(165, 22, 30), CFrame.new(0.3, -head.Size.Y * 1.1, head.Size.Z * 0.5), { Material = Enum.Material.Fabric })
	elseif visual == "Occhiali" and head then
		attach(folder, head, "Occhialoni", Vector3.new(head.Size.X * 0.95, 0.32, 0.2), Color3.fromRGB(60, 50, 40), CFrame.new(0, head.Size.Y * 0.36, -head.Size.Z * 0.48), { Material = Enum.Material.Leather })
		for _, side in { -1, 1 } do
			attach(folder, head, "LenteOcchialoni", Vector3.new(0.32, 0.28, 0.08), Color3.fromRGB(140, 210, 190), CFrame.new(side * head.Size.X * 0.22, head.Size.Y * 0.36, -head.Size.Z * 0.56), { Material = Enum.Material.Glass, Transparency = 0.2 })
		end
	elseif visual == "Fascia" then
		local arm = getPart(character, "LeftUpperArm")
		if arm then
			attach(folder, arm, "Fascia", Vector3.new(arm.Size.X + 0.1, 0.35, arm.Size.Z + 0.1), Color3.fromRGB(230, 200, 60), CFrame.new(0, arm.Size.Y * 0.1, 0), { Material = Enum.Material.Fabric })
		end
	elseif visual == "Mantello" then
		buildCloak(folder, character, def.CloakColor or Color3.fromRGB(120, 30, 30), def.CloakTrim, def.Emblem)
	elseif visual == "Chiave" then
		local upper = getPart(character, "UpperTorso")
		if upper then
			attach(folder, upper, "Chiave", Vector3.new(0.18, 0.5, 0.06), Color3.fromRGB(200, 170, 80), CFrame.new(0, upper.Size.Y * 0.15, -upper.Size.Z * 0.5 - 0.1), { Material = Enum.Material.Metal, Reflectance = 0.3 })
		end
	end
end

local function buildUniform(folder: Instance, character: Model, styleName: string, jacketOverride: Color3?, opts)
	local style = UNIFORMS[styleName] or UNIFORMS.Cadetto
	local jacketColor = jacketOverride or style.Jacket
	local upper = getPart(character, "UpperTorso")
	if jacketColor and upper then
		local jacket = shell(folder, upper, "Giacca", jacketColor, 0.14, if style.Long then 1.02 else 0.8, if style.Long then 0 else 0.1, { Material = Enum.Material.Fabric })
		if jacket and style.Trim then
			attach(folder, upper, "Rifinitura", Vector3.new(0.12, upper.Size.Y, 0.04), style.Trim, CFrame.new(0, 0, -upper.Size.Z * 0.5 - 0.1))
		end
		if jacket and style.Emblem and not opts.HideEmblem then
			addEmblem(jacket, style.Emblem, Enum.NormalId.Back)
		end
		for _, armName in { "LeftUpperArm", "RightUpperArm" } do
			shell(folder, getPart(character, armName), "Manica", jacketColor, 0.1, 0.92, 0.04, { Material = Enum.Material.Fabric })
		end
		if style.Long then
			for _, armName in { "LeftLowerArm", "RightLowerArm" } do
				shell(folder, getPart(character, armName), "Polsino", jacketColor, 0.08, 0.7, 0.12, { Material = Enum.Material.Fabric })
			end
			shell(folder, getPart(character, "LowerTorso"), "Giacca2", jacketColor, 0.12, 1.0, 0, { Material = Enum.Material.Fabric })
		end
		if style.Armband then
			shell(folder, getPart(character, "LeftUpperArm"), "Bracciale", style.Armband, 0.14, 0.25, 0.1, { Material = Enum.Material.Fabric })
		end
	end
	if style.Crystal and upper then
		attach(folder, upper, "PiastraCristallo", Vector3.new(upper.Size.X * 0.9, upper.Size.Y * 0.6, 0.18), Color3.fromRGB(170, 230, 255), CFrame.new(0, upper.Size.Y * 0.1, -upper.Size.Z * 0.5 - 0.1), { Material = Enum.Material.Glass, Transparency = 0.15 })
		for _, armName in { "LeftUpperArm", "RightUpperArm" } do
			local arm = getPart(character, armName)
			if arm then
				attach(folder, arm, "SpallaCristallo", Vector3.new(arm.Size.X + 0.25, 0.5, arm.Size.Z + 0.25), Color3.fromRGB(170, 230, 255), CFrame.new(0, arm.Size.Y * 0.4, 0), { Material = Enum.Material.Glass, Transparency = 0.15 })
			end
		end
	end
	local pantsColor = if style.Pants then COLORS.Pants else style.PantsColor
	if pantsColor then
		for _, legName in { "LeftUpperLeg", "RightUpperLeg" } do
			shell(folder, getPart(character, legName), "Pantaloni", pantsColor, 0.06, 1.0, 0, { Material = Enum.Material.Fabric })
		end
	end
	-- stivali
	for _, legName in { "LeftLowerLeg", "RightLowerLeg" } do
		shell(folder, getPart(character, legName), "Stivale", COLORS.Boots, 0.1, 0.9, -0.05, { Material = Enum.Material.Leather })
	end
	for _, footName in { "LeftFoot", "RightFoot" } do
		shell(folder, getPart(character, footName), "Scarpa", COLORS.Boots, 0.08, 1.1, 0, { Material = Enum.Material.Leather })
	end
	if style.Hat then
		local head = getPart(character, "Head")
		if head then
			attach(folder, head, "Cappello", Vector3.new(head.Size.X * 1.1, head.Size.Y * 0.4, head.Size.Z * 1.1), Color3.fromRGB(28, 26, 28), CFrame.new(0, head.Size.Y * 0.6, 0), { Material = Enum.Material.Fabric })
		end
	end
	return style
end

-- API ---------------------------------------------------------------------------------------

function OutfitService.Clear(character: Model)
	local folder = character:FindFirstChild(FOLDER_NAME)
	if folder then
		folder:Destroy()
	end
end

--[[
	spec = {
		Equipped = { Blade, Gear, Ranged, Armor, Accessory } (id oggetti),
		Uniform = "Falchi" (per i PNG),
		Look = { HairStyle, Hair, Beard, Glasses, Hat, Hood, Scarf, Apron },
		NoBlades = true, NoGear = true,
	}
]]
function OutfitService.Apply(character: Model, spec)
	OutfitService.Clear(character)
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = character

	local equipped = spec.Equipped or {}
	local armor = Items.Get(equipped.Armor)
	local styleName = spec.Uniform or (armor and armor.Style) or "Cadetto"
	local style = buildUniform(folder, character, styleName, armor and armor.JacketColor, spec)

	local wearsGear = not spec.NoGear and (equipped.Gear ~= nil and equipped.Gear ~= "" or spec.Uniform == "Falchi" or spec.Uniform == "Guarnigione" or spec.Uniform == "Polizia" or spec.Uniform == "Cadetto" or spec.Uniform == "Ombra" or spec.Uniform == "NuovoCorpo")
	if wearsGear then
		buildODM(folder, character)
	end

	local cosmetic = Items.Get(equipped.Accessory)
	local cosmeticCloak = cosmetic ~= nil and cosmetic.Visual == "Mantello"
	local cloakColor = (armor and armor.Cloak and armor.CloakColor) or (spec.Uniform and style.Cloak) or nil
	if cloakColor and not cosmeticCloak then
		local emblem = (armor and armor.Emblem) or style.Emblem
		buildCloak(folder, character, cloakColor, armor and armor.CloakTrim or nil, emblem)
	end

	local blade = Items.Get(equipped.Blade)
	if blade and not spec.NoBlades then
		buildBlades(folder, character, blade)
	end
	local ranged = Items.Get(equipped.Ranged)
	if ranged then
		buildRanged(folder, character, ranged)
	end
	local accessory = Items.Get(equipped.Accessory)
	if accessory then
		buildAccessory(folder, character, accessory)
	end
	if spec.Look then
		buildLookExtras(folder, character, spec.Look)
	end
	return folder
end

return OutfitService
