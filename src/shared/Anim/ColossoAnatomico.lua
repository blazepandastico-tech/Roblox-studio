--[[
	ColossoAnatomico - il Gigante Vulcano dei FILMATI, il più realistico possibile.

	Un gigante altissimo e senza pelle: ogni muscolo è un fascio rosso (ellissoide) con le fibre
	più scure in superficie, separato dagli altri da tendini e fasce chiare. Testa scarnificata con
	il cranio chiaro, le orbite scure e i denti scoperti, bande chiare ai polsi e alle caviglie,
	ginocchia ossute e chiare.

	Lo scheletro è invisibile e ha gli STESSI nomi delle articolazioni dei giganti (Root, Waist,
	Neck, Jaw, spalle, gomiti, polsi, anche, ginocchia, caviglie): le animazioni dei filmati
	(camminare, calciare il cancello, ruggire) funzionano senza cambiare nulla.
	Si usa solo nei filmati (TitanBuilder.Build con Cinematic = true): il boss in gioco non cambia.
]]

local ColossoAnatomico = {}

local rad = math.rad

local MUSCLE = Color3.fromRGB(142, 30, 30)
local MUSCLE_DARK = Color3.fromRGB(104, 20, 22)
local MUSCLE_LIGHT = Color3.fromRGB(168, 46, 40)
local FIBER = Color3.fromRGB(80, 13, 15)
local TENDON = Color3.fromRGB(226, 196, 182)
local TENDON_SHADE = Color3.fromRGB(198, 152, 140)
local SKULL = Color3.fromRGB(214, 172, 160)
local TEETH = Color3.fromRGB(236, 226, 206)
local DARK = Color3.fromRGB(58, 14, 16)
local EYE = Color3.fromRGB(206, 194, 182)

function ColossoAnatomico.Build(params): Model
	local H: number = params.Height or 190
	local rng = Random.new(params.Seed or 1)
	local model = Instance.new("Model")
	model.Name = params.Name or "Vulcano"

	local function P(x: number, y: number, z: number): Vector3
		return Vector3.new(x, y, z) * H
	end
	local function vary(c: Color3): Color3
		local f = rng:NextNumber(0.94, 1.06)
		return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
	end

	-- ossa invisibili (le muove il Motor6D) ----------------------------------------------------
	local function bone(name: string, size: Vector3, cf: CFrame): BasePart
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * H
		p.CFrame = cf
		p.Transparency = 1
		p.Anchored = false
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CastShadow = false
		p.Parent = model
		return p
	end
	local function motor(name: string, part0: BasePart, part1: BasePart, joint: CFrame)
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = part0
		m.Part1 = part1
		m.C0 = part0.CFrame:Inverse() * joint
		m.C1 = part1.CFrame:Inverse() * joint
		m.Parent = part1
		return m
	end

	-- pezzi visibili: ellissoidi saldati all'osso ------------------------------------------------
	local function blob(parent: BasePart, name: string, size: Vector3, cf: CFrame, color: Color3, shadow: boolean?): BasePart
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05))
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.CFrame = cf
		p.Anchored = false
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CastShadow = shadow == true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = parent
		weld.Part1 = p
		weld.Parent = p
		p.Parent = model
		return p
	end
	-- sistema con l'asse Y da a verso b (hint = direzione a cui si allinea la larghezza)
	local function frameAlong(a: Vector3, b: Vector3, hint: Vector3?): CFrame
		local up = (b - a).Unit
		local h = hint or Vector3.xAxis
		local right = h - up * h:Dot(up)
		if right.Magnitude < 1e-3 then
			right = Vector3.zAxis - up * up.Z
		end
		return CFrame.fromMatrix((a + b) / 2, right.Unit, up)
	end
	-- un muscolo da a verso b (in studs): w = larghezza, d = spessore (in frazioni di H).
	-- fibers = quante fibre scure disegnare sulla superficie rivolta verso "out"
	local function muscle(parent: BasePart, name: string, a: Vector3, b: Vector3, w: number, d: number, color: Color3, fibers: number?, out: Vector3?, hint: Vector3?): BasePart
		local cf = frameAlong(a, b, hint)
		local len = (b - a).Magnitude * 1.12
		local size = Vector3.new(w * H, len, d * H)
		local m = blob(parent, name, size, cf, vary(color), true)
		if fibers and fibers > 0 and out then
			local up = cf.UpVector
			local o = out - up * out:Dot(up)
			if o.Magnitude > 1e-3 then
				o = o.Unit
				local spread = o:Cross(up).Unit
				local function extent(dir: Vector3): number
					local rx = dir:Dot(cf.RightVector)
					local rz = dir:Dot(-cf.LookVector)
					return math.sqrt((rx * size.X / 2) ^ 2 + (rz * size.Z / 2) ^ 2)
				end
				local eo, es = extent(o), extent(spread)
				for i = 1, fibers do
					local f = ((i - 0.5) / fibers - 0.5) * 1.5
					local depth = eo * math.sqrt(math.max(0, 1 - f * f)) * 0.92
					local pos = cf.Position + spread * (f * es) + o * depth
					blob(parent, name .. "Fibra" .. i, Vector3.new(es * 0.07, len * 0.42, eo * 0.12), CFrame.fromMatrix(pos, spread, up), FIBER)
				end
			end
		end
		return m
	end
	local UP = Vector3.yAxis
	local FRONT = -Vector3.zAxis

	-- SCHELETRO (posa di riposo, piedi a terra in y = 0, davanti = -Z) ---------------------------
	local hipsY = 0.53
	local root = bone("Root", Vector3.new(0.1, 0.06, 0.06), CFrame.new(P(0, hipsY, 0)))
	root.Massless = false
	local hips = bone("Hips", Vector3.new(0.16, 0.1, 0.1), CFrame.new(P(0, hipsY, 0)))
	motor("Root", root, hips, CFrame.new(P(0, hipsY, 0)))
	local torso = bone("Torso", Vector3.new(0.24, 0.3, 0.14), CFrame.new(P(0, 0.7125, 0)))
	motor("Waist", hips, torso, CFrame.new(P(0, 0.565, 0)))
	local head = bone("Head", Vector3.new(0.06, 0.09, 0.07), CFrame.new(P(0, 0.952, -0.004)))
	motor("Neck", torso, head, CFrame.new(P(0, 0.905, -0.002)))
	local jaw = bone("Jaw", Vector3.new(0.048, 0.03, 0.05), CFrame.new(P(0, 0.902, -0.014)))
	motor("Jaw", head, jaw, CFrame.new(P(0, 0.918, 0.004)))

	-- nuca (come gli altri giganti) e attacchi per gli effetti
	local nape = Instance.new("Part")
	nape.Name = "Nape"
	nape.Size = P(0.04, 0.035, 0.025)
	nape.CFrame = CFrame.new(P(0, 0.885, 0.028))
	nape.Transparency = 1
	nape.CanCollide = false
	nape.CanTouch = false
	nape.CanQuery = false
	nape.Massless = true
	nape:SetAttribute("HitZone", "Nape")
	local napeWeld = Instance.new("WeldConstraint")
	napeWeld.Part0 = torso
	napeWeld.Part1 = nape
	napeWeld.Parent = nape
	nape.Parent = model
	local napeAtt = Instance.new("Attachment")
	napeAtt.Name = "NapeAtt"
	napeAtt.Parent = nape

	-- TESTA: cranio chiaro, tempie rosse, orbite scure, niente labbra -------------------------
	blob(head, "Cranio", P(0.058, 0.074, 0.072), CFrame.new(P(0, 0.962, 0.002)), SKULL, true)
	blob(head, "Volto", P(0.046, 0.05, 0.05), CFrame.new(P(0, 0.925, -0.012)), MUSCLE_DARK)
	-- arcata sopraccigliare: una cresta sottile sopra le orbite
	muscle(head, "Arcata", P(-0.022, 0.9505, -0.03), P(0.022, 0.9505, -0.03), 0.006, 0.008, MUSCLE_DARK, nil, nil, UP)
	for _, s in { -1, 1 } do
		muscle(head, "Tempia", P(s * 0.025, 0.972, 0.004), P(s * 0.025, 0.932, 0.0), 0.008, 0.038, MUSCLE_DARK, 2, Vector3.new(s, 0, 0))
		blob(head, "Orbita", P(0.014, 0.011, 0.012), CFrame.new(P(s * 0.0135, 0.943, -0.03)), DARK)
		blob(head, "Occhio", P(0.008, 0.006, 0.008), CFrame.new(P(s * 0.0135, 0.9425, -0.0322)), EYE)
		blob(head, "Pupilla", P(0.003, 0.003, 0.002), CFrame.new(P(s * 0.0135, 0.9425, -0.0365)), DARK)
		muscle(head, "Zigomo", P(s * 0.022, 0.936, -0.026), P(s * 0.011, 0.913, -0.034), 0.012, 0.012, MUSCLE_LIGHT, 1, Vector3.new(s * 0.3, 0, -1))
		muscle(head, "Massetere", P(s * 0.025, 0.936, -0.012), P(s * 0.022, 0.9, -0.018), 0.016, 0.02, MUSCLE, 2, Vector3.new(s, 0, -0.3))
		blob(head, "Orecchio", P(0.006, 0.018, 0.012), CFrame.new(P(s * 0.03, 0.94, 0.006)), MUSCLE_DARK)
	end
	-- niente naso: il setto rosso e la cavità scura
	muscle(head, "Setto", P(0, 0.94, -0.032), P(0, 0.926, -0.035), 0.0045, 0.005, MUSCLE_LIGHT)
	blob(head, "CavitaNaso", P(0.012, 0.01, 0.006), CFrame.new(P(0, 0.922, -0.035)), DARK)
	blob(head, "Gengiva", P(0.034, 0.009, 0.012), CFrame.new(P(0, 0.9145, -0.033)), MUSCLE_DARK)
	for i = 0, 9 do
		local x = (i - 4.5) * 0.0034
		blob(head, "DenteSu", P(0.0031, 0.0095, 0.004), CFrame.new(P(x, 0.909, -0.0385 + math.abs(x) * 0.32)), TEETH)
	end
	-- mandibola (si apre quando ruggisce)
	blob(jaw, "Mandibola", P(0.044, 0.024, 0.046), CFrame.new(P(0, 0.897, -0.012)), MUSCLE)
	blob(jaw, "Mento", P(0.018, 0.012, 0.01), CFrame.new(P(0, 0.892, -0.033)), SKULL)
	blob(jaw, "GengivaGiu", P(0.028, 0.007, 0.011), CFrame.new(P(0, 0.9, -0.033)), MUSCLE_DARK)
	for i = 0, 9 do
		local x = (i - 4.5) * 0.0032
		blob(jaw, "DenteGiu", P(0.003, 0.0085, 0.004), CFrame.new(P(x, 0.9025, -0.037 + math.abs(x) * 0.32)), TEETH)
	end
	local headTop = Instance.new("Attachment")
	headTop.Name = "HeadTopAtt"
	headTop.Position = head.CFrame:PointToObjectSpace(P(0, 1.0, 0))
	headTop.Parent = head
	local mouthAtt = Instance.new("Attachment")
	mouthAtt.Name = "MouthAtt"
	mouthAtt.Position = head.CFrame:PointToObjectSpace(P(0, 0.908, -0.04))
	mouthAtt.Parent = head

	-- COLLO -------------------------------------------------------------------------------------
	blob(torso, "Collo", P(0.05, 0.075, 0.052), CFrame.new(P(0, 0.885, 0.004)), MUSCLE_DARK, true)
	blob(torso, "Gola", P(0.014, 0.03, 0.01), CFrame.new(P(0, 0.882, -0.024)), TENDON_SHADE)
	for _, s in { -1, 1 } do
		muscle(torso, "Sternocleido", P(s * 0.024, 0.925, -0.004), P(s * 0.008, 0.858, -0.04), 0.012, 0.013, MUSCLE_LIGHT)
		muscle(torso, "Trapezio", P(s * 0.014, 0.905, 0.014), P(s * 0.13, 0.852, 0.008), 0.05, 0.045, MUSCLE)
	end

	-- BUSTO -------------------------------------------------------------------------------------
	blob(torso, "Gabbia", P(0.23, 0.225, 0.135), CFrame.new(P(0, 0.758, 0.005)), MUSCLE_DARK, true)
	blob(torso, "Addome", P(0.15, 0.2, 0.112), CFrame.new(P(0, 0.64, 0.004)), MUSCLE_DARK, true)
	blob(torso, "Schiena", P(0.2, 0.26, 0.06), CFrame.new(P(0, 0.75, 0.055)), MUSCLE, true)
	blob(torso, "Spina", P(0.008, 0.25, 0.01), CFrame.new(P(0, 0.74, 0.085)), FIBER)
	-- la "stella" chiara alla base del collo, lo sterno e le clavicole
	blob(torso, "Giugulo", P(0.03, 0.016, 0.012), CFrame.new(P(0, 0.856, -0.05)), TENDON)
	blob(torso, "Sterno", P(0.014, 0.09, 0.012), CFrame.new(P(0, 0.812, -0.066)), TENDON)
	for _, s in { -1, 1 } do
		muscle(torso, "Clavicola", P(s * 0.012, 0.858, -0.046), P(s * 0.125, 0.848, -0.022), 0.008, 0.009, TENDON, nil, nil, UP)
		-- pettorali a ventaglio (tre fasci, con le fibre dallo sterno verso la spalla)
		muscle(torso, "PettoraleAlto", P(s * 0.016, 0.838, -0.056), P(s * 0.135, 0.818, -0.03), 0.042, 0.034, MUSCLE, 3, Vector3.new(0, 0.2, -1), UP)
		muscle(torso, "PettoraleMedio", P(s * 0.016, 0.806, -0.064), P(s * 0.135, 0.81, -0.03), 0.05, 0.04, MUSCLE, 4, Vector3.new(0, 0, -1), UP)
		muscle(torso, "PettoraleBasso", P(s * 0.022, 0.772, -0.06), P(s * 0.13, 0.8, -0.032), 0.036, 0.032, MUSCLE, 3, Vector3.new(0, -0.3, -1), UP)
		muscle(torso, "BordoPettorale", P(s * 0.03, 0.756, -0.064), P(s * 0.12, 0.79, -0.042), 0.006, 0.008, TENDON_SHADE, nil, nil, UP)
		-- dentato (le "dita" sui fianchi), obliqui e grande dorsale
		for i = 0, 3 do
			local y = 0.79 - i * 0.024
			muscle(torso, "Dentato" .. i, P(s * 0.088, y + 0.006, -0.042 + i * 0.002), P(s * 0.124, y - 0.01, -0.02), 0.013, 0.02, MUSCLE_LIGHT, nil, nil, UP)
		end
		muscle(torso, "Obliquo", P(s * 0.094, 0.73, -0.018), P(s * 0.074, 0.59, -0.03), 0.045, 0.036, MUSCLE, 3, Vector3.new(s * 0.7, 0, -0.7))
		muscle(torso, "Dorsale", P(s * 0.115, 0.79, 0.024), P(s * 0.068, 0.63, 0.048), 0.05, 0.05, MUSCLE_DARK, 2, Vector3.new(s * 0.6, 0, 0.8))
		-- legamento inguinale (la V chiara verso il basso)
		muscle(torso, "Inguine", P(s * 0.09, 0.595, -0.045), P(s * 0.018, 0.528, -0.055), 0.011, 0.011, TENDON)
	end
	-- addominali a tartaruga con le intersezioni chiare e la linea alba
	for row = 0, 3 do
		local y = 0.738 - row * 0.035
		for _, s in { -1, 1 } do
			blob(torso, "Addominale", P(0.042, 0.033, 0.026), CFrame.new(P(s * 0.024, y, -0.062)), vary(MUSCLE), true)
			blob(torso, "AddominaleFibra", P(0.028, 0.004, 0.004), CFrame.new(P(s * 0.024, y + 0.004, -0.0748)), FIBER)
		end
		blob(torso, "Intersezione", P(0.086, 0.005, 0.01), CFrame.new(P(0, y - 0.0175, -0.07)), TENDON_SHADE)
	end
	for _, s in { -1, 1 } do
		blob(torso, "RettoBasso", P(0.04, 0.075, 0.024), CFrame.new(P(s * 0.023, 0.58, -0.058)), vary(MUSCLE), true)
	end
	blob(torso, "LineaAlba", P(0.007, 0.24, 0.01), CFrame.new(P(0, 0.645, -0.072)), TENDON)

	-- BACINO ------------------------------------------------------------------------------------
	blob(hips, "Bacino", P(0.2, 0.11, 0.12), CFrame.new(P(0, 0.545, 0.004)), MUSCLE_DARK, true)
	blob(hips, "Inforcatura", P(0.05, 0.035, 0.05), CFrame.new(P(0, 0.51, -0.004)), MUSCLE)
	for _, s in { -1, 1 } do
		muscle(hips, "Gluteo", P(s * 0.04, 0.578, 0.035), P(s * 0.055, 0.49, 0.045), 0.075, 0.07, MUSCLE, 3, Vector3.new(s * 0.3, 0, 1))
		muscle(hips, "MedioGluteo", P(s * 0.096, 0.585, -0.004), P(s * 0.094, 0.515, -0.004), 0.045, 0.055, MUSCLE, 2, Vector3.new(s, 0, -0.2))
	end

	-- BRACCIA -----------------------------------------------------------------------------------
	local tilt = rad(4.5)
	local function buildArm(s: number, prefix: string)
		local J = CFrame.new(P(s * 0.158, 0.835, 0)) * CFrame.Angles(0, 0, s * tilt)
		local E = J * CFrame.new(0, -0.18 * H, 0)
		local Wr = E * CFrame.new(0, -0.177 * H, 0)
		local function at(frame: CFrame, x: number, y: number, z: number): Vector3
			return (frame * CFrame.new(s * x * H, y * H, z * H)).Position
		end
		local lateral = J.RightVector * s
		local front = J.LookVector
		local upper = bone(prefix .. "UpperArm", Vector3.new(0.03, 0.18, 0.03), J * CFrame.new(0, -0.09 * H, 0))
		motor(prefix .. "Shoulder", torso, upper, J)
		local lower = bone(prefix .. "LowerArm", Vector3.new(0.028, 0.177, 0.028), E * CFrame.new(0, -0.0885 * H, 0))
		motor(prefix .. "Elbow", upper, lower, E)
		local hand = bone(prefix .. "Hand", Vector3.new(0.03, 0.08, 0.015), Wr * CFrame.new(0, -0.04 * H, 0))
		motor(prefix .. "Wrist", lower, hand, Wr)
		local handAtt = Instance.new("Attachment")
		handAtt.Name = prefix .. "HandAtt"
		handAtt.Position = Vector3.new(0, -0.025 * H, 0)
		handAtt.Parent = hand

		-- spalla (deltoide in tre fasci) e braccio
		blob(upper, "Omero", P(0.03, 0.17, 0.03), J * CFrame.new(0, -0.09 * H, 0), MUSCLE_DARK)
		muscle(upper, "DeltoideAnt", at(J, -0.006, 0.018, -0.026), at(J, 0.014, -0.085, -0.012), 0.046, 0.04, MUSCLE, 3, front)
		muscle(upper, "DeltoideLat", at(J, 0.02, 0.018, 0), at(J, 0.02, -0.09, 0), 0.055, 0.055, MUSCLE, 4, lateral)
		muscle(upper, "DeltoidePost", at(J, -0.002, 0.018, 0.026), at(J, 0.014, -0.08, 0.012), 0.046, 0.04, MUSCLE_DARK, 2, -front)
		muscle(upper, "SolcoDeltoide", at(J, -0.03, 0, -0.036), at(J, -0.01, -0.07, -0.03), 0.006, 0.006, TENDON_SHADE)
		muscle(upper, "Bicipite", at(J, 0, -0.05, -0.016), at(J, 0, -0.165, -0.014), 0.04, 0.04, MUSCLE, 3, front)
		muscle(upper, "Tricipite", at(J, 0, -0.04, 0.016), at(J, 0, -0.17, 0.012), 0.045, 0.042, MUSCLE_DARK, 2, -front)
		muscle(upper, "Brachiale", at(J, 0.016, -0.1, -0.004), at(J, 0.014, -0.175, -0.006), 0.022, 0.03, MUSCLE_LIGHT, 1, lateral)
		muscle(upper, "SettoBraccio", at(J, 0.021, -0.08, 0.004), at(J, 0.02, -0.16, 0.004), 0.004, 0.006, TENDON_SHADE)
		-- avambraccio, tendini del polso e la benda chiara
		blob(lower, "Radio", P(0.034, 0.18, 0.032), E * CFrame.new(0, -0.088 * H, 0), MUSCLE_DARK)
		muscle(lower, "Brachioradiale", at(E, 0.012, 0.02, -0.006), at(E, 0.01, -0.12, -0.01), 0.036, 0.036, MUSCLE, 2, lateral)
		muscle(lower, "Flessori", at(E, -0.01, -0.005, -0.012), at(E, -0.004, -0.13, -0.008), 0.036, 0.034, MUSCLE_LIGHT, 2, front)
		muscle(lower, "Estensori", at(E, 0.006, 0, 0.012), at(E, 0.004, -0.14, 0.008), 0.03, 0.028, MUSCLE_DARK, 2, -front)
		blob(lower, "Olecrano", P(0.016, 0.016, 0.012), CFrame.new(at(E, 0, 0.005, 0.016)), TENDON_SHADE)
		for i, x in { -0.008, 0, 0.008 } do
			muscle(lower, "TendinePolso" .. i, at(E, x, -0.12, -0.012), at(E, x * 0.7, -0.172, -0.01), 0.004, 0.004, TENDON)
		end
		blob(lower, "Benda", P(0.038, 0.016, 0.034), E * CFrame.new(0, -0.168 * H, 0), TENDON, true)
		-- mano
		blob(hand, "Polso", P(0.03, 0.022, 0.024), Wr * CFrame.new(0, -0.004 * H, 0), MUSCLE_DARK)
		blob(hand, "Palmo", P(0.04, 0.058, 0.018), Wr * CFrame.new(0, -0.03 * H, 0), vary(MUSCLE), true)
		blob(hand, "Tenar", P(0.014, 0.028, 0.014), CFrame.new(at(Wr, -0.014, -0.022, -0.008)), MUSCLE_LIGHT)
		muscle(hand, "Pollice", at(Wr, -0.017, -0.03, -0.01), at(Wr, -0.02, -0.06, -0.016), 0.008, 0.008, MUSCLE)
		for i, x in { -0.0105, -0.0035, 0.0035, 0.0105 } do
			local len = ({ 0.042, 0.048, 0.045, 0.036 })[i]
			muscle(hand, "Dito" .. i, at(Wr, x * 1.25, -0.054, 0), at(Wr, x * 1.3, -0.054 - len, -0.008), 0.0088, 0.009, if i % 2 == 0 then MUSCLE else MUSCLE_LIGHT)
		end
	end
	buildArm(1, "Right")
	buildArm(-1, "Left")

	-- GAMBE -------------------------------------------------------------------------------------
	local function buildLeg(s: number, prefix: string)
		local HJ = CFrame.new(P(s * 0.068, 0.505, 0))
		local K = HJ * CFrame.new(0, -0.22 * H, 0)
		local A = K * CFrame.new(0, -0.237 * H, 0)
		local function at(frame: CFrame, x: number, y: number, z: number): Vector3
			return (frame * CFrame.new(s * x * H, y * H, z * H)).Position
		end
		local lateral = Vector3.new(s, 0, 0)
		local upper = bone(prefix .. "UpperLeg", Vector3.new(0.05, 0.22, 0.05), HJ * CFrame.new(0, -0.11 * H, 0))
		motor(prefix .. "Hip", hips, upper, HJ)
		local lower = bone(prefix .. "LowerLeg", Vector3.new(0.04, 0.237, 0.04), K * CFrame.new(0, -0.1185 * H, 0))
		motor(prefix .. "Knee", upper, lower, K)
		local foot = bone(prefix .. "Foot", Vector3.new(0.045, 0.03, 0.1), A * CFrame.new(0, -0.024 * H, -0.035 * H))
		motor(prefix .. "Ankle", lower, foot, A)

		-- coscia: quadricipite, adduttori, femorali, sartorio e banda chiara laterale
		blob(upper, "Femore", P(0.088, 0.215, 0.084), HJ * CFrame.new(0, -0.11 * H, 0), MUSCLE_DARK)
		muscle(upper, "VastoLaterale", at(HJ, 0.036, -0.03, -0.002), at(HJ, 0.03, -0.205, -0.012), 0.066, 0.072, MUSCLE, 4, Vector3.new(s * 0.8, 0, -0.6))
		muscle(upper, "RettoFemorale", at(HJ, 0.008, -0.025, -0.034), at(HJ, 0.004, -0.19, -0.036), 0.05, 0.048, MUSCLE_LIGHT, 3, FRONT)
		muscle(upper, "VastoMediale", at(HJ, -0.018, -0.115, -0.022), at(HJ, -0.024, -0.205, -0.024), 0.054, 0.05, MUSCLE, 3, Vector3.new(-s * 0.6, 0, -0.8))
		muscle(upper, "Adduttori", at(HJ, -0.034, 0, -0.004), at(HJ, -0.026, -0.15, -0.002), 0.06, 0.062, MUSCLE_DARK, 2, Vector3.new(-s * 0.7, 0, -0.7))
		muscle(upper, "Femorali", at(HJ, 0.004, -0.03, 0.03), at(HJ, 0, -0.2, 0.024), 0.07, 0.058, MUSCLE_DARK, 2, -FRONT)
		muscle(upper, "Sartorio", at(HJ, 0.038, 0.012, -0.046), at(HJ, -0.032, -0.2, -0.012), 0.014, 0.013, TENDON_SHADE)
		muscle(upper, "BandaLaterale", at(HJ, 0.064, -0.02, 0), at(HJ, 0.05, -0.2, -0.004), 0.009, 0.009, TENDON_SHADE)
		blob(upper, "TendineQuadricipite", P(0.04, 0.036, 0.014), CFrame.new(at(HJ, 0, -0.205, -0.042)), TENDON)
		-- ginocchio ossuto e chiaro, con le pieghe scure
		blob(lower, "Rotula", P(0.066, 0.078, 0.03), CFrame.new(at(K, 0, -0.004, -0.042)), TENDON, true)
		for _, x in { -1, 1 } do
			blob(lower, "LatoGinocchio", P(0.028, 0.06, 0.028), CFrame.new(at(K, x * 0.03, -0.01, -0.032)), TENDON_SHADE)
			blob(lower, "PiegaGinocchio", P(0.015, 0.01, 0.005), CFrame.new(at(K, x * 0.015, 0.008, -0.056)), MUSCLE_DARK)
		end
		blob(lower, "PiegaRotula", P(0.028, 0.006, 0.005), CFrame.new(at(K, 0, -0.016, -0.056)), MUSCLE_DARK)
		muscle(lower, "TendineRotuleo", at(K, 0, -0.03, -0.042), at(K, 0, -0.065, -0.036), 0.02, 0.012, TENDON)
		-- polpaccio, tibiale, achille e la benda chiara alla caviglia
		blob(lower, "Tibia", P(0.062, 0.235, 0.06), K * CFrame.new(0, -0.118 * H, 0), MUSCLE_DARK)
		muscle(lower, "Tibiale", at(K, 0.014, -0.05, -0.024), at(K, 0.01, -0.2, -0.02), 0.036, 0.038, MUSCLE, 2, FRONT)
		muscle(lower, "Stinco", at(K, -0.008, -0.06, -0.03), at(K, -0.005, -0.2, -0.026), 0.007, 0.007, TENDON_SHADE)
		muscle(lower, "GemelloLaterale", at(K, 0.018, -0.015, 0.024), at(K, 0.014, -0.135, 0.03), 0.046, 0.054, MUSCLE, 3, -FRONT)
		muscle(lower, "GemelloMediale", at(K, -0.02, -0.015, 0.024), at(K, -0.016, -0.145, 0.032), 0.05, 0.056, MUSCLE, 3, Vector3.new(-s * 0.7, 0, 0.7))
		muscle(lower, "Soleo", at(K, 0, -0.08, 0.016), at(K, 0, -0.195, 0.016), 0.056, 0.044, MUSCLE_DARK)
		muscle(lower, "Peroneo", at(K, 0.028, -0.05, 0), at(K, 0.024, -0.19, 0.002), 0.02, 0.024, MUSCLE_LIGHT, 1, lateral)
		muscle(lower, "Achille", at(K, 0, -0.16, 0.026), at(K, 0, -0.232, 0.024), 0.014, 0.012, TENDON)
		-- la benda chiara alla caviglia (larga, con il bordo arrotolato)
		blob(lower, "Benda", P(0.08, 0.044, 0.078), K * CFrame.new(0, -0.21 * H, 0), TENDON, true)
		blob(lower, "BordoBenda", P(0.082, 0.007, 0.08), K * CFrame.new(0, -0.19 * H, 0), TENDON_SHADE)
		blob(lower, "BordoBendaBasso", P(0.082, 0.007, 0.08), K * CFrame.new(0, -0.23 * H, 0), TENDON_SHADE)
		-- piede con le dita
		blob(foot, "ColloPiede", P(0.058, 0.05, 0.06), CFrame.new(at(A, 0, -0.008, -0.004)), MUSCLE_DARK)
		blob(foot, "Piede", P(0.062, 0.042, 0.118), CFrame.new(at(A, 0, -0.026, -0.03)), vary(MUSCLE), true)
		blob(foot, "Tallone", P(0.044, 0.042, 0.04), CFrame.new(at(A, 0, -0.028, 0.02)), MUSCLE_DARK)
		for i, x in { -0.02, -0.008, 0.003, 0.013, 0.022 } do
			local size = ({ 0.016, 0.0115, 0.011, 0.0105, 0.0095 })[i]
			blob(foot, "DitoPiede" .. i, P(size, size * 0.9, size * 1.5), CFrame.new(at(A, x, -0.04, -0.092 + math.abs(x) * 0.5)), MUSCLE_LIGHT)
		end
		for i, x in { -0.012, 0, 0.012 } do
			muscle(foot, "TendinePiede" .. i, at(A, x * 0.5, -0.01, -0.012), at(A, x, -0.032, -0.066), 0.004, 0.004, TENDON_SHADE)
		end
	end
	buildLeg(1, "Right")
	buildLeg(-1, "Left")

	-- punto per gli effetti sul corpo (il vapore esce dal collo: lo aggiunge TitanBuilder, "VaporeCollo")
	local steamAtt = Instance.new("Attachment")
	steamAtt.Name = "SteamAtt"
	steamAtt.Parent = torso

	model.PrimaryPart = root
	model:SetAttribute("Height", H)
	model:SetAttribute("HipHeight", hipsY * H)
	model:SetAttribute("Look", "Vulcano")
	model:SetAttribute("Seed", params.Seed or 1)
	model:SetAttribute("HeadTilt", 0)
	model:SetAttribute("Archetype", "")
	model:SetAttribute("CrawlPreferred", false)
	model:SetAttribute("JawIdle", 6)
	model:SetAttribute("Hunch", false)
	model:SetAttribute("Anatomico", true)
	return model
end

return ColossoAnatomico
