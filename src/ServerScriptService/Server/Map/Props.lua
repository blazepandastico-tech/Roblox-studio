-- Il deserto intorno allo stadio: cactus, cespugli, rocce agganciabili, parabole, pali della luce con cavi,
-- relitto d'aereo, mulini a vento, passerella con ponte e cartelli.
local CollectionService = game:GetService("CollectionService")
local Util = require(script.Parent.Util)
local Layout = require(script.Parent.Layout)

local Props = {}

local G = Layout.GROUND_Y
local SM = Enum.Material.SmoothPlastic

local function tag(inst, name)
	CollectionService:AddTag(inst, name)
	return inst
end

-- punto fuori dallo stadio e lontano dal letto del fiume e dal sentiero?
local function freeSpot(x, z, margin)
	margin = margin or 0
	if math.abs(x) < Layout.PLAZA_X + 24 + margin and math.abs(z) < Layout.PLAZA_Z + 24 + margin then
		return false
	end
	-- fiume (a sud): fascia z in [-285, -190] circa
	if z < -185 and z > -290 then
		return false
	end
	-- sentiero e belvedere
	if z < -150 and math.abs(x) < 60 then
		return false
	end
	if z < -300 and math.abs(x) < 190 then
		return false
	end
	return true
end

----------------------------------------------------------------------
-- Cactus e cespugli
----------------------------------------------------------------------
local GREENS = { Color3.fromRGB(66, 150, 84), Color3.fromRGB(90, 170, 80), Color3.fromRGB(48, 126, 98), Color3.fromRGB(110, 176, 90) }

local function cactus(parent, x, z, s, rng)
	local col = rng.Pick(GREENS)
	local h = (9 + rng.Next() * 8) * s
	local d = 2.6 * s
	local m = Util.model(parent, "Cactus")
	Util.pillar(m, "Tronco", x, G, z, d, h, col, SM, false, { shadow = false })
	Util.sphere(m, "Cima", Vector3.new(x, G + h, z), d, col, SM, false, { shadow = false })
	local arms = rng.Int(0, 3)
	for i = 1, arms do
		local ang = rng.Range(0, math.pi * 2)
		local ay = G + h * rng.Range(0.35, 0.6)
		local len = rng.Range(2.6, 3.6) * s
		local ex, ez = x + math.cos(ang) * len, z + math.sin(ang) * len
		Util.rod(m, "Braccio", Vector3.new(x, ay, z), Vector3.new(ex, ay, ez), d * 0.72, col, SM, false, { shadow = false })
		Util.sphere(m, "Gomito", Vector3.new(ex, ay, ez), d * 0.72, col, SM, false, { shadow = false })
		local up = rng.Range(3.2, 6) * s
		Util.pillar(m, "BraccioSu", ex, ay, ez, d * 0.72, up, col, SM, false, { shadow = false })
		Util.sphere(m, "BraccioCima", Vector3.new(ex, ay + up, ez), d * 0.72, col, SM, false, { shadow = false })
	end
	if rng.Next() < 0.35 then
		Util.sphere(m, "Fiore", Vector3.new(x, G + h + d * 0.55, z), d * 0.5, Color3.fromRGB(255, 120, 170), SM, false, { shadow = false })
	end
	return m
end

local function barrel(parent, x, z, rng)
	local d = rng.Range(2.6, 4.6)
	local col = rng.Pick(GREENS)
	Util.sphere(parent, "Botte", Vector3.new(x, G + d * 0.35, z), d, col, SM, false, { shadow = false })
	if rng.Next() < 0.6 then
		Util.sphere(parent, "Fiore", Vector3.new(x, G + d * 0.85, z), d * 0.38, Color3.fromRGB(255, 190, 70), SM, false, { shadow = false })
	end
end

local BUSHES = { Color3.fromRGB(150, 128, 70), Color3.fromRGB(120, 98, 52), Color3.fromRGB(170, 140, 78), Color3.fromRGB(104, 112, 60) }

local function bush(parent, x, z, rng)
	local col = rng.Pick(BUSHES)
	for i = 1, rng.Int(2, 3) do
		local d = rng.Range(2.2, 4.8)
		Util.sphere(parent, "Cespuglio", Vector3.new(x + rng.Range(-1.8, 1.8), G + d * 0.3, z + rng.Range(-1.8, 1.8)), d, Util.shade(col, rng.Range(0.85, 1.1)), SM, false, { shadow = false })
	end
end

local function plants(root, rng)
	local f = Util.folder(root, "Piante")
	local placed, tries = 0, 0
	while placed < 46 and tries < 400 do
		tries = tries + 1
		local x, z = rng.Range(-900, 900), rng.Range(-330, 330)
		if freeSpot(x, z, 8) then
			cactus(f, x, z, rng.Range(0.8, 1.5), rng)
			placed = placed + 1
		end
	end
	placed, tries = 0, 0
	while placed < 34 and tries < 400 do
		tries = tries + 1
		local x, z = rng.Range(-900, 900), rng.Range(-330, 330)
		if freeSpot(x, z, 4) then
			barrel(f, x, z, rng)
			placed = placed + 1
		end
	end
	placed, tries = 0, 0
	while placed < 70 and tries < 600 do
		tries = tries + 1
		local x, z = rng.Range(-800, 800), rng.Range(-330, 330)
		if freeSpot(x, z, 2) then
			bush(f, x, z, rng)
			placed = placed + 1
		end
	end
	-- cespugli secchi anche sulla piazza, vicino ai cordoli
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			bush(f, sx * (Layout.PLAZA_X + 10), sz * (Layout.PLAZA_Z + 10), rng)
		end
	end
end

----------------------------------------------------------------------
-- Rocce agganciabili col rampino (blocchi spigolosi sovrapposti)
----------------------------------------------------------------------
local ROCKS = {
	Color3.fromRGB(190, 78, 52),
	Color3.fromRGB(216, 112, 64),
	Color3.fromRGB(164, 62, 48),
	Color3.fromRGB(226, 148, 88),
}

local function rockCluster(parent, x, z, scale, rng)
	local n = rng.Int(3, 5)
	for i = 1, n do
		local s = rng.Range(6, 14) * scale
		local h = s * rng.Range(0.8, 1.7)
		local ox, oz = rng.Range(-s * 0.7, s * 0.7), rng.Range(-s * 0.7, s * 0.7)
		local rot = CFrame.Angles(rng.Range(-0.3, 0.3), rng.Range(0, 3.14), rng.Range(-0.3, 0.3))
		local r = Util.P(parent, "Roccia", Vector3.new(s, h, s * rng.Range(0.7, 1.1)), CFrame.new(x + ox, G + h * 0.32, z + oz) * rot, rng.Pick(ROCKS), Enum.Material.Rock)
		tag(r, "Grappable")
	end
end

local function rocks(root, rng)
	local f = Util.folder(root, "Rocce")
	local spots = {
		{ 224, 96 }, { 232, -110 }, { -226, 112 }, { -236, -100 },
		{ 160, 188 }, { -170, 196 }, { 60, 204 }, { -80, 190 },
		{ 208, -168 }, { -208, -168 }, { 262, 30 }, { -266, -20 },
		{ 100, -170 }, { -90, -168 },
	}
	for _, p in ipairs(spots) do
		rockCluster(f, p[1], p[2], rng.Range(0.8, 1.3), rng)
	end
end

----------------------------------------------------------------------
-- Parabole satellitari giganti: ciotola a gradini (paraboloide) su un pilone
----------------------------------------------------------------------
local function dish(parent, x, z, axis, rng)
	local m = Util.model(parent, "Parabola")
	local white = Color3.fromRGB(240, 240, 246)
	local greyBlue = Color3.fromRGB(150, 156, 176)
	local baseH = 24
	local base = Util.pillar(m, "Piedistallo", x, G, z, 9, baseH, Color3.fromRGB(206, 196, 186), Enum.Material.Concrete, true)
	tag(base, "Grappable")
	Util.pillar(m, "Anello", x, G + baseH, z, 11, 1.6, Color3.fromRGB(70, 74, 98), Enum.Material.Metal, false)
	local vertex = Vector3.new(x, G + baseH + 9, z)
	Util.rod(m, "Sostegno", Vector3.new(x, G + baseH, z), vertex, 3.2, Color3.fromRGB(86, 90, 114), Enum.Material.Metal, false)
	local a = axis.Unit
	-- ciotola (Model a parte: sul client ruota lentamente)
	local bowl = Util.model(m, "Ciotola")
	local layers = 10
	local rmax = 31
	local focus = 28
	local first
	for k = 0, layers - 1 do
		local r = 3 + (rmax - 3) * (k / (layers - 1))
		local d = r * r / (4 * focus)
		local pos = vertex + a * d
		local p = Util.D(bowl, "Piatto", Vector3.new(1.2, r * 2, r * 2), CFrame.lookAt(pos, pos + a) * CFrame.Angles(0, math.pi / 2, 0), (k % 2 == 0) and white or Util.shade(white, 0.92), SM, 0, { shape = Enum.PartType.Cylinder, shadow = (k >= layers - 3) })
		first = first or p
	end
	bowl.PrimaryPart = first
	-- bordo e braccio dell'illuminatore
	local rim = vertex + a * (rmax * rmax / (4 * focus))
	Util.D(bowl, "Bordo", Vector3.new(0.9, rmax * 2 + 1.6, rmax * 2 + 1.6), CFrame.lookAt(rim, rim + a) * CFrame.Angles(0, math.pi / 2, 0), greyBlue, Enum.Material.Metal, 0, { shape = Enum.PartType.Cylinder, shadow = false })
	local up = (Vector3.new(0, 1, 0) - a * a.Y).Unit
	local side = a:Cross(up).Unit
	local fpos = vertex + a * focus
	for i = 0, 2 do
		local ang = i * math.pi * 2 / 3 + 0.5
		local dir = up * math.cos(ang) + side * math.sin(ang)
		Util.rod(bowl, "Asta", rim + dir * rmax, fpos, 0.9, greyBlue, Enum.Material.Metal, false, { shadow = false })
	end
	Util.sphere(bowl, "Illuminatore", fpos, 3.4, Color3.fromRGB(255, 120, 90), Enum.Material.Neon, false, { shadow = false })
	Util.tag(bowl, "Spin")
	bowl:SetAttribute("SpinSpeed", rng.Range(0.05, 0.1) * rng.Sign())
	return m
end

local function dishes(root, rng)
	local f = Util.folder(root, "Parabole")
	dish(f, -240, 212, Vector3.new(-0.55, 0.78, 0.3), rng)
	dish(f, 22, 246, Vector3.new(-0.5, 0.8, -0.25), rng)
	dish(f, 332, 220, Vector3.new(-0.6, 0.75, 0.2), rng)
end

----------------------------------------------------------------------
-- Pali della luce con cavi che pendono
----------------------------------------------------------------------
local function powerLine(root)
	local f = Util.folder(root, "LineaElettrica")
	local wood = Color3.fromRGB(112, 78, 52)
	local wire = Color3.fromRGB(28, 28, 34)
	local zLine = -184
	local prev
	for i = -9, 9 do
		local x = i * 60
		if x ~= 0 then -- al centro passa il sentiero: i cavi lo scavalcano
			local pole = Util.pillar(f, "Palo", x, G, zLine, 1.9, 38, wood, Enum.Material.Wood, true)
			tag(pole, "Grappable")
			Util.D(f, "Traversa", Vector3.new(16, 1.2, 1.4), CFrame.new(x, G + 35, zLine), wood, Enum.Material.Wood)
			local attach = {}
			for k = -1, 1 do
				Util.pillar(f, "Isolatore", x + k * 6.4, G + 35.6, zLine, 0.9, 1.6, Color3.fromRGB(226, 230, 236), SM, false, { shadow = false })
				attach[k] = Vector3.new(x + k * 6.4, G + 37.4, zLine)
			end
			if prev then
				local span = math.abs(x - prev.x)
				local sag = 2.6 * (span / 60) * (span / 60)
				for k = -1, 1 do
					local a, b = prev[k], attach[k]
					local last = a
					for seg = 1, 4 do
						local t = seg / 4
						local p = a:Lerp(b, t) - Vector3.new(0, 4 * sag * t * (1 - t), 0)
						Util.beam(f, "Cavo", last, p, 0.2, 0.2, wire, SM, false, { shadow = false })
						last = p
					end
				end
			end
			attach.x = x
			prev = attach
		end
	end
end

----------------------------------------------------------------------
-- Relitto d'aereo con striscia di terra bruciata e fumo
----------------------------------------------------------------------
local function plane(root, rng)
	local f = Util.folder(root, "RelittoAereo")
	local white = Color3.fromRGB(236, 238, 244)
	local red = Color3.fromRGB(206, 52, 46)
	local metal = Color3.fromRGB(176, 182, 196)
	local origin = CFrame.new(-344, G + 4.2, -112) * CFrame.Angles(0, 0.5, 0.1)
	local function at(x, y, z)
		return origin * CFrame.new(x, y, z)
	end
	-- terra bruciata + solco
	Util.D(f, "Bruciato", Vector3.new(0.3, 50, 50), CFrame.new(-344, G + 0.12, -112) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(54, 40, 42), Enum.Material.Basalt, 0, { shape = Enum.PartType.Cylinder, shadow = false })
	Util.D(f, "Solco", Vector3.new(130, 0.3, 12), CFrame.new(-420, G + 0.12, -88) * CFrame.Angles(0, 0.5, 0), Color3.fromRGB(86, 62, 52), Enum.Material.Ground, 0, { shadow = false })
	-- fusoliera: tronco centrale + muso + coda
	local body = Util.P(f, "Fusoliera", Vector3.new(44, 10, 10), at(0, 0, 0), white, Enum.Material.Metal)
	body.Shape = Enum.PartType.Cylinder
	tag(body, "Grappable")
	Util.sphere(f, "Muso", origin * Vector3.new(-23, 0, 0), 10, white, Enum.Material.Metal, true)
	Util.D(f, "Cabina", Vector3.new(4, 3, 6), at(-21, 1.6, 0) * CFrame.Angles(0, 0, -0.35), Color3.fromRGB(46, 70, 96), Enum.Material.Glass, 0.2)
	for _, x in ipairs({ -12, 11 }) do
		Util.D(f, "Fascia", Vector3.new(2.4, 10.4, 10.4), at(x, 0, 0), red, Enum.Material.Metal, 0, { shape = Enum.PartType.Cylinder, shadow = false })
	end
	for i = 0, 6 do
		for _, sz in ipairs({ -1, 1 }) do
			Util.D(f, "Finestrino", Vector3.new(1.5, 1.7, 0.3), at(-9 + i * 3.4, 1.4, sz * 5.05), Color3.fromRGB(120, 200, 240), SM, 0, { shadow = false })
		end
	end
	local tail = Util.P(f, "Coda", Vector3.new(16, 6, 6), at(30, 1.6, 0) * CFrame.Angles(0, 0, 0.08), white, Enum.Material.Metal)
	tail.Shape = Enum.PartType.Cylinder
	Util.P(f, "Deriva", Vector3.new(9, 14, 1.2), at(33, 9, 0) * CFrame.Angles(0, 0, 0.2), red, Enum.Material.Metal)
	Util.P(f, "Stabilizzatore", Vector3.new(6, 0.8, 18), at(34, 3, 0), metal, Enum.Material.Metal)
	-- ala intera e ala spezzata
	Util.P(f, "Ala", Vector3.new(12, 1.4, 38), at(2, -2.2, 22) * CFrame.Angles(0.06, 0, 0.1), metal, Enum.Material.Metal)
	Util.P(f, "AlaMozza", Vector3.new(12, 1.4, 10), at(2, -2.2, -8) * CFrame.Angles(-0.2, 0, -0.18), metal, Enum.Material.Metal)
	Util.P(f, "AlaCaduta", Vector3.new(12, 1.4, 22), CFrame.new(-382, G + 1.4, -64) * CFrame.Angles(0.15, 1.1, 0.35), metal, Enum.Material.Metal)
	-- motore staccato
	local eng = Util.P(f, "Motore", Vector3.new(9, 5.4, 5.4), CFrame.new(-366, G + 2.6, -78) * CFrame.Angles(0.3, 0.9, 0.2), Color3.fromRGB(80, 84, 98), Enum.Material.Metal)
	eng.Shape = Enum.PartType.Cylinder
	-- rottami
	for i = 1, 16 do
		local s = rng.Range(1, 3.4)
		Util.D(f, "Rottame", Vector3.new(s, s * rng.Range(0.3, 1), s * rng.Range(0.5, 1.4)), CFrame.new(-344 + rng.Range(-48, 40), G + 0.6, -112 + rng.Range(-30, 30)) * CFrame.Angles(rng.Range(-1, 1), rng.Range(0, 6), rng.Range(-1, 1)), rng.Pick({ white, red, metal }), Enum.Material.Metal, 0, { shadow = false })
	end
	-- fumo
	local emit = Util.D(f, "Fumo", Vector3.new(2, 1, 2), at(4, 5.4, 0), Color3.new(0, 0, 0), SM, 1, { shadow = false })
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Rate = 6
	smoke.Lifetime = NumberRange.new(6, 9)
	smoke.Speed = NumberRange.new(4, 7)
	smoke.SpreadAngle = Vector2.new(14, 14)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 18) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(Color3.fromRGB(70, 62, 66))
	smoke.Acceleration = Vector3.new(3, 3, 0)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-25, 25)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Parent = emit
end

----------------------------------------------------------------------
-- Mulini a vento (la ruota gira sul client)
----------------------------------------------------------------------
local function windmill(parent, x, z, rng)
	local m = Util.model(parent, "Mulino")
	local steel = Color3.fromRGB(150, 156, 170)
	local wood = Color3.fromRGB(150, 104, 68)
	local H = 30
	local corners = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
	for _, c in ipairs(corners) do
		local a = Vector3.new(x + c[1] * 4, G, z + c[2] * 4)
		local b = Vector3.new(x + c[1] * 1.3, G + H, z + c[2] * 1.3)
		local leg = Util.beam(m, "Gamba", a, b, 0.8, 0.8, steel, Enum.Material.Metal, false, { shadow = false })
		tag(leg, "Grappable")
	end
	for _, y in ipairs({ 8, 16, 24 }) do
		local k = 4 - y / H * 2.7
		for i = 1, 4 do
			local c1, c2 = corners[i], corners[i % 4 + 1]
			Util.beam(m, "Traversa", Vector3.new(x + c1[1] * k, G + y, z + c1[2] * k), Vector3.new(x + c2[1] * k, G + y, z + c2[2] * k), 0.5, 0.5, steel, Enum.Material.Metal, false, { shadow = false })
		end
	end
	Util.D(m, "Piattaforma", Vector3.new(4.4, 0.8, 4.4), CFrame.new(x, G + H + 0.4, z), wood, Enum.Material.WoodPlanks)
	Util.D(m, "Motore", Vector3.new(5, 3, 3), CFrame.new(x + 1, G + H + 2.3, z), steel, Enum.Material.Metal)
	-- coda
	Util.D(m, "Deriva", Vector3.new(11, 0.4, 3.6), CFrame.new(x + 8, G + H + 2.3, z), Color3.fromRGB(206, 52, 46), Enum.Material.Metal, 0, { shadow = false })
	-- ruota: Model con centro, pale radiali
	local wheel = Util.model(m, "Ruota")
	local hubPos = Vector3.new(x - 2.2, G + H + 2.3, z)
	local hub = Util.D(wheel, "Mozzo", Vector3.new(1.4, 2.4, 2.4), CFrame.new(hubPos), Color3.fromRGB(70, 74, 98), Enum.Material.Metal, 0, { shape = Enum.PartType.Cylinder, shadow = false })
	wheel.PrimaryPart = hub
	for i = 0, 11 do
		local ang = i * math.pi / 6
		Util.D(wheel, "Pala", Vector3.new(0.35, 8.4, 1.5), CFrame.new(hubPos) * CFrame.Angles(ang, 0, 0) * CFrame.new(0, 6.2, 0), (i % 2 == 0) and Color3.fromRGB(240, 236, 226) or Color3.fromRGB(206, 52, 46), SM, 0, { shadow = false })
	end
	Util.tag(wheel, "Spin")
	wheel:SetAttribute("SpinSpeed", rng.Range(0.8, 1.3))
	wheel:SetAttribute("SpinAxis", "X")
end

----------------------------------------------------------------------
-- Passerella dallo stadio al belvedere, ponte sul fiume, cartelli, lampioncini, ascensore
----------------------------------------------------------------------
local function walkway(root)
	local f = Util.folder(root, "Passerella")
	local stone = Color3.fromRGB(214, 180, 142)
	local dark = Color3.fromRGB(150, 108, 84)
	local z0, z1 = -Layout.PLAZA_Z - 3.2, -312
	-- lastre del sentiero (rialzate di 2 stud sul terreno), interrotte dal ponte sul fiume
	local zb = -226
	local function strip(za, zb2)
		local len = math.abs(zb2 - za)
		Util.P(f, "Sentiero", Vector3.new(30, 4, len), CFrame.new(0, -2, (za + zb2) / 2), stone, Enum.Material.Concrete)
		for _, sx in ipairs({ -1, 1 }) do
			Util.D(f, "Bordo", Vector3.new(1.6, 0.5, len), CFrame.new(sx * 14.6, 0.25, (za + zb2) / 2), dark, Enum.Material.Concrete, 0, { shadow = false })
		end
		for z = za - 10, zb2 + 4, -20 do
			Util.D(f, "Fuga", Vector3.new(28, 0.06, 0.3), CFrame.new(0, 0.04, z), dark, SM, 0.4, { shadow = false })
		end
	end
	strip(z0, zb + 32)
	strip(zb - 32, z1)
	-- ponte: impalcato con parapetti luminosi e piloni sulle sponde
	Util.P(f, "Ponte", Vector3.new(34, 1.6, 64), CFrame.new(0, -0.2, zb), Color3.fromRGB(190, 150, 118), Enum.Material.Concrete)
	for _, sx in ipairs({ -1, 1 }) do
		Util.P(f, "Parapetto", Vector3.new(1.4, 3.2, 64), CFrame.new(sx * 16.4, 2.2, zb), Color3.fromRGB(150, 108, 84), Enum.Material.Concrete)
		Util.D(f, "ParapettoLuce", Vector3.new(0.5, 0.4, 62), CFrame.new(sx * 16.4, 3.9, zb), Color3.fromRGB(190, 132, 255), Enum.Material.Neon, 0, { shadow = false })
		for _, dz in ipairs({ -22, 22 }) do
			Util.P(f, "Pilone", Vector3.new(5, 9, 5), CFrame.new(sx * 14, -4.8, zb + dz), Color3.fromRGB(176, 136, 106), Enum.Material.Concrete)
		end
	end
	-- lampioncini ai lati del sentiero
	local n = 0
	for z = z0 - 18, z1 + 8, -26 do
		if math.abs(z - zb) > 36 then
			for _, sx in ipairs({ -1, 1 }) do
				n = n + 1
				local p = Util.pillar(f, "Lampione", sx * 17, 0, z, 1.2, 5, Color3.fromRGB(46, 50, 74), Enum.Material.Metal, false, { shadow = false })
				local lamp = Util.sphere(f, "Lampada", Vector3.new(sx * 17, 5.6, z), 1.8, Color3.fromRGB(255, 214, 140), Enum.Material.Neon, false, { shadow = false })
				if n % 2 == 0 then
					local l = Instance.new("PointLight")
					l.Color = Color3.fromRGB(255, 200, 130)
					l.Brightness = 1
					l.Range = 16
					l.Shadows = false
					l.Parent = lamp
				end
			end
		end
	end
	-- cartello all'inizio del sentiero
	local post = Util.P(f, "PostoCartello", Vector3.new(1.2, 9, 1.2), CFrame.new(22, 4.5, -176), Color3.fromRGB(112, 78, 52), Enum.Material.Wood)
	local b1 = Util.D(f, "Cartello", Vector3.new(10, 2.6, 0.5), CFrame.new(22, 8, -176.3) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, 0, 0.04), Color3.fromRGB(240, 226, 196), Enum.Material.WoodPlanks)
	Util.label(b1, Enum.NormalId.Front, "BELVEDERE  >", { font = Enum.Font.GothamBlack, color = Color3.fromRGB(70, 44, 30), pps = 36 })
	local b2 = Util.D(f, "Cartello", Vector3.new(10, 2.6, 0.5), CFrame.new(22, 5, -175.7) * CFrame.Angles(0, 0, -0.04), Color3.fromRGB(240, 226, 196), Enum.Material.WoodPlanks)
	Util.label(b2, Enum.NormalId.Front, "<  STADIO", { font = Enum.Font.GothamBlack, color = Color3.fromRGB(70, 44, 30), pps = 36 })
	post.Name = "Palo"

	-- ascensore panoramico di vetro che sale al belvedere (solo scenografia)
	local ex, ez = 120, Layout.LOBBY.Z + 78 + 8
	local top = Layout.LOBBY.Y
	local steel = Color3.fromRGB(46, 50, 74)
	for _, c in ipairs({ { -5, -5 }, { 5, -5 }, { 5, 5 }, { -5, 5 } }) do
		Util.pillar(f, "MontanteAscensore", ex + c[1], G, ez + c[2], 1.4, top - G, steel, Enum.Material.Metal, true)
	end
	for y = G + 10, top, 12 do
		Util.D(f, "Cerchiatura", Vector3.new(11.4, 0.8, 11.4), CFrame.new(ex, y, ez), steel, Enum.Material.Metal, 0, { shadow = false })
	end
	Util.D(f, "Cabina", Vector3.new(7.6, 8, 7.6), CFrame.new(ex, G + 4.4, ez), Color3.fromRGB(190, 230, 255), Enum.Material.Glass, 0.45)
	Util.D(f, "CabinaTetto", Vector3.new(8.2, 0.6, 8.2), CFrame.new(ex, G + 8.7, ez), steel, Enum.Material.Metal)
	local sign = Util.D(f, "InsegnaAscensore", Vector3.new(11, 3, 0.5), CFrame.new(ex, top + 3.4, ez + 5.6), Color3.fromRGB(24, 20, 38), SM)
	Util.label(sign, Enum.NormalId.Back, "LOBBY", { font = Enum.Font.GothamBlack, color = Color3.fromRGB(255, 205, 90), pps = 36 })
end

----------------------------------------------------------------------
-- Bandiere sugli angoli della piazza
----------------------------------------------------------------------
local function flags(root)
	local f = Util.folder(root, "Bandiere")
	local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local x, z = sx * (Layout.PLAZA_X - 8), sz * (Layout.PLAZA_Z - 8)
			local key = (sx < 0) and "Red" or "Blue"
			Util.pillar(f, "Asta", x, 0, z, 0.9, 26, Color3.fromRGB(190, 194, 206), Enum.Material.Metal, false, { shadow = false })
			Util.sphere(f, "PuntaAsta", Vector3.new(x, 26.4, z), 1.4, Color3.fromRGB(250, 210, 60), Enum.Material.Neon, false, { shadow = false })
			Util.D(f, "Bandiera", Vector3.new(0.3, 5.5, 9), CFrame.new(x, 22.2, z - sz * 5), Config.Teams[key].Color, Enum.Material.Fabric, 0, { shadow = false })
		end
	end
end

----------------------------------------------------------------------
-- Avvoltoi che volteggiano sul canyon (si muovono sul client)
----------------------------------------------------------------------
local BIRDS = {
	{ 120, 140, 120, 110, 0.16 },
	{ -380, 40, 160, 140, -0.12 },
	{ 520, -40, 110, 95, 0.2 },
	{ -120, -120, 90, 92, -0.22 },
	{ 760, 180, 150, 160, 0.1 },
	{ -700, -60, 120, 120, -0.15 },
}

local function birds(root, rng)
	local f = Util.folder(root, "Avvoltoi")
	local dark = Color3.fromRGB(48, 38, 36)
	for _, b in ipairs(BIRDS) do
		local phase = rng.Range(0, 6.28)
		local m = Util.model(f, "Avvoltoio")
		local pos = Vector3.new(b[1] + b[3] * math.cos(phase), b[4], b[2] + b[3] * math.sin(phase))
		local base = CFrame.new(pos)
		local body = Util.D(m, "Corpo", Vector3.new(1.4, 0.8, 3.4), base, dark, SM, 0, { shadow = false })
		Util.D(m, "AlaSx", Vector3.new(4.4, 0.2, 1.8), base * CFrame.new(-2.9, 0, 0), dark, SM, 0, { shadow = false })
		Util.D(m, "AlaDx", Vector3.new(4.4, 0.2, 1.8), base * CFrame.new(2.9, 0, 0), dark, SM, 0, { shadow = false })
		Util.D(m, "Testa", Vector3.new(0.9, 0.9, 1.2), base * CFrame.new(0, 0.1, -2.1), Color3.fromRGB(196, 74, 62), SM, 0, { shadow = false })
		m.PrimaryPart = body
		Util.tag(m, "Bird")
		m:SetAttribute("Cx", b[1])
		m:SetAttribute("Cz", b[2])
		m:SetAttribute("Raggio", b[3])
		m:SetAttribute("Quota", b[4])
		m:SetAttribute("Velocita", b[5])
		m:SetAttribute("Fase", phase)
	end
end

function Props.Build(root)
	local sc = Util.folder(root, "Scenario")
	local rng = Util.Rng(31337)
	local function try(name, fn, ...)
		local ok, err = pcall(fn, ...)
		if not ok then
			warn("[Mappa] " .. name .. " non riuscito: " .. tostring(err))
		end
	end
	try("passerella", walkway, sc)
	try("rocce", rocks, sc, rng)
	try("piante", plants, sc, rng)
	try("parabole", dishes, sc, rng)
	try("linea elettrica", powerLine, sc)
	try("aereo", plane, sc, rng)
	try("mulini", function()
		local f = Util.folder(sc, "Mulini")
		windmill(f, -560, 120, rng)
		windmill(f, 520, -120, rng)
		windmill(f, 820, 140, rng)
	end)
	try("bandiere", flags, sc)
	try("avvoltoi", birds, sc, rng)
	return sc
end

return Props
