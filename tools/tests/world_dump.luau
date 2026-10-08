--[[
	Esporta il mondo costruito con il Roblox finto (tools/world_photo.py lo trasforma in foto):
	  P  parte:   classe, forma, dimensioni, CFrame (12 numeri), colore, materiale, trasparenza
	  T  terreno: tipo (Block/Ball/Cylinder/Wedge), posizione e misure, materiale
	  C  colore di un materiale del terreno
	  Z  centro e raggio di una zona (per scegliere le inquadrature)
	  G  un gigante di prova (le sue parti seguono come righe P)
]]

local Config = require(SHARED.Config)
local Zones = require(SHARED.Data.Zones)
local W = require(SHARED.Data.WorldLayout)
local TitanBuilder = require(SHARED.Anim.TitanBuilder)

local WB = require(SERVER.Services.WorldBuilder)
WB.Init({})
local ok, err = pcall(WB.Build)
if not ok then
	error("WorldBuilder.Build: " .. tostring(err))
end

local out = {}
local function f(n: number): string
	return string.format("%.3f", n)
end
local function emit(...)
	local parts = table.pack(...)
	for i = 1, parts.n do
		parts[i] = tostring(parts[i])
	end
	table.insert(out, table.concat(parts, "\t"))
	if #out >= 2000 then
		LOG(table.concat(out, "\n"))
		table.clear(out)
	end
end

local function cfFields(cf): (string, string, string, string, string, string, string, string, string, string, string, string)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return f(x), f(y), f(z), f(r00), f(r01), f(r02), f(r10), f(r11), f(r12), f(r20), f(r21), f(r22)
end

local function emitPart(p)
	local shape = "Block"
	if p.ClassName == "Part" then
		shape = if p.Shape then p.Shape.Name else "Block"
	elseif p.ClassName == "WedgePart" then
		shape = "Wedge"
	elseif p.ClassName == "CornerWedgePart" then
		shape = "CornerWedge"
	elseif p.ClassName == "TrussPart" then
		shape = "Truss"
	end
	-- le parti del corpo dei giganti sono ellissoidi (SpecialMesh "Sphere")
	local mesh = p:FindFirstChildOfClass("SpecialMesh")
	if mesh and mesh.MeshType == Enum.MeshType.Sphere then
		shape = "Ellipsoid"
	end
	local s = p.Size
	local c = p.Color or Color3.new(0.64, 0.64, 0.64)
	local cf = table.concat({ cfFields(p.CFrame) }, "\t")
	emit("P", p.ClassName, shape, f(s.X), f(s.Y), f(s.Z), cf, f(c.R), f(c.G), f(c.B), if p.Material then p.Material.Name else "Plastic", f(p.Transparency or 0))
end

-- zone e mura (per le inquadrature)
for _, zone in Zones.List do
	emit("Z", zone.Id, f(zone.Center.X), f(zone.Center.Y), f(zone.Center.Z), f(zone.Radius), if zone.Safe then "1" else "0")
end
emit("W", "GroundY", f(W.GroundY))
emit("W", "WaterY", f(W.WaterY))

-- inquadrature delle foto: V nome, posizione della telecamera, punto guardato
local function view(name: string, pos: Vector3, target: Vector3)
	emit("V", name, f(pos.X), f(pos.Y), f(pos.Z), f(target.X), f(target.Y), f(target.Z))
end
local up = Vector3.new(0, 1, 0)
local G = W.GroundY
-- il distretto di Calaneth sporge fuori dal Muro Vermiglio: cancello interno, case, mura e cancello esterno
local innerGate = W.DistrictGatePoint("Calaneth")
local outward = W.DistrictOutward("Calaneth")
local right = outward:Cross(up)
local outerGate = innerGate + outward * W.Districts.Calaneth.Radius
local calaneth = W.DistrictCenter("Calaneth")
view("calaneth_tetti", innerGate + outward * 12 + right * 75 + Vector3.new(0, G + 160, 0), calaneth + outward * 30 + Vector3.new(0, G + 10, 0))
view("calaneth_strada", calaneth - outward * 30 + right * 5 + Vector3.new(0, G + 8, 0), outerGate + Vector3.new(0, G + 22, 0))
view("muro_esterno", outerGate + outward * 300 + right * 130 + Vector3.new(0, G + 40, 0), outerGate + Vector3.new(0, G + 62, 0))
view("vermiglia_alto", W.IslandCenter("Vermiglia") + Vector3.new(980, 620, 980), W.IslandCenter("Vermiglia") + Vector3.new(0, 30, 0))
local camp = Zones.Get("CampoAddestramento")
if camp then
	view("campo", camp.Center + Vector3.new(140, 60, 140), camp.Center + Vector3.new(0, 12, 0))
end
local aurion = Zones.Get("Aurion")
if aurion then
	view("aurion", aurion.Center + Vector3.new(-150, 70, 160), aurion.Center + Vector3.new(0, 30, 0))
end
-- i giganti di prova in fila fuori dal cancello esterno di Calaneth (distanziati in base all'altezza)
local lineFront = outerGate + outward * 200
local LOOKS = { "Puro", "Puro", "Puro", "Ghignante", "Cacciatrice", "Bastione", "Vulcano", "Furia", "Fauno", "Dorato" }
local HEIGHTS = { 15, 22, 32, 40, 45, 48, 190, 48, 55, 78 }
local offsets = { 0 }
for i = 2, #HEIGHTS do
	offsets[i] = offsets[i - 1] + (HEIGHTS[i - 1] + HEIGHTS[i]) * 0.6 + 10
end
local function slot(i: number): Vector3
	local a, b = math.floor(i), math.min(math.ceil(i), #HEIGHTS)
	local x = offsets[a] + (offsets[b] - offsets[a]) * (i - a)
	return lineFront + right * (x - offsets[#offsets] / 2)
end
for i = 1, #HEIGHTS do
	local p = slot(i)
	emit("TP", tostring(i), f(p.X), f(G), f(p.Z), f(math.atan2(outward.X, outward.Z)))
end
view("giganti", slot(6.5) + outward * 430 + right * 20 + Vector3.new(0, G + 40, 0), slot(6.5) + Vector3.new(0, G + 48, 0))
-- da vicino: i giganti puri (posti 1-4) e il volto di quello da 32 metri (posto 3)
view("giganti_vicino", slot(2.6) + outward * 120 - right * 12 + Vector3.new(0, G + 20, 0), slot(2.6) + Vector3.new(0, G + 17, 0))
view("volto", slot(3) + outward * 30 - right * 9 + Vector3.new(0, G + 28, 0), slot(3) + Vector3.new(0, G + 27.5, 0))
-- seconda fila: otto giganti puri della stessa altezza, per vedere quanto sono diversi tra loro
local VARIETY = 8
local varietyRow = lineFront + outward * 130
local function varietySlot(i: number): Vector3
	return varietyRow + right * ((i - (VARIETY + 1) / 2) * 18)
end
for i = 1, VARIETY do
	local q = varietySlot(i)
	emit("TP", tostring(10 + i), f(q.X), f(G), f(q.Z), f(math.atan2(outward.X, outward.Z)))
end
view("varieta", varietySlot(4.5) + outward * 118 + Vector3.new(0, G + 14, 0), varietySlot(4.5) + Vector3.new(0, G + 11, 0))
view("varieta_volti", varietySlot(1.5) + outward * 30 + Vector3.new(0, G + 18, 0), varietySlot(1.5) + Vector3.new(0, G + 16.5, 0))
-- le case di Calaneth viste dall'alto delle mura interne del distretto
view("calaneth_case", calaneth - outward * 35 + right * 55 + Vector3.new(0, G + 46, 0), calaneth + outward * 25 - right * 30 + Vector3.new(0, G + 8, 0))
-- un boschetto in campagna (il primo albero a 650-800 studs dal centro di Vermiglia, lontano dalle mura)
do
	local best: Vector3? = nil
	for _, d in workspace:GetDescendants() do
		if d.Name == "Tronco" and d:IsA("BasePart") and d.Parent and d.Parent.Name == "Alberi" then
			local pos = d.Position
			local r = Vector3.new(pos.X, 0, pos.Z).Magnitude
			if r > 650 and r < 800 and math.abs(pos.Z) < 300 and pos.X > 0 then
				best = Vector3.new(pos.X, 0, pos.Z)
				break
			end
		end
	end
	if best then
		local away = Vector3.new(best.X, 0, best.Z).Unit
		view("bosco", best + away * 55 + away:Cross(up) * 25 + Vector3.new(0, G + 9, 0), best + Vector3.new(0, G + 13, 0))
	end
end
local _ = calaneth

-- terreno
for name, color in MOCK_TERRAIN_COLORS do
	emit("C", name, f(color.R), f(color.G), f(color.B))
end
for _, t in MOCK_TERRAIN do
	if t.Kind == "Ball" then
		emit("T", "Ball", f(t.Center.X), f(t.Center.Y), f(t.Center.Z), f(t.Radius), t.Material.Name)
	elseif t.Kind == "Cylinder" then
		emit("T", "Cylinder", f(t.Height), f(t.Radius), t.Material.Name, cfFields(t.CFrame))
	else
		emit("T", t.Kind, f(t.Size.X), f(t.Size.Y), f(t.Size.Z), t.Material.Name, cfFields(t.CFrame))
	end
end

-- parti del mondo
local count = 0
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and d.ClassName ~= "Terrain" and d.Transparency < 0.98 then
		emitPart(d)
		count += 1
	end
end

-- giganti di prova: tutti gli aspetti, in fila (le foto li mettono davanti alle mura)
for i, look in LOOKS do
	local okT, model = pcall(TitanBuilder.Build, { Height = HEIGHTS[i], Look = look, Seed = 1000 + i * 77, Name = look })
	if okT and model then
		emit("G", look, f(HEIGHTS[i]), tostring(i))
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 0.98 then
				emitPart(d)
			end
		end
		emit("GE", look)
	else
		emit("GX", look, tostring(model))
	end
end
-- semi scelti in modo che ognuno abbia una pettinatura diversa (così si vede anche il calvo)
local usedHair = {}
local seedTry = 5000
for i = 1, VARIETY do
	local okT, model
	repeat
		seedTry += 1
		okT, model = pcall(TitanBuilder.Build, { Height = 20, Look = "Puro", Seed = seedTry, Name = "Puro" })
		local hairStyle = if okT and model then string.split(tostring(model:GetAttribute("Aspetto")), "/")[1] else ""
	until not okT or not usedHair[hairStyle] and (i > 1 or hairStyle == "Calvo") and (i ~= 2 or string.find(tostring(model:GetAttribute("Aspetto")), "storta") ~= nil)
	if okT and model then
		usedHair[string.split(tostring(model:GetAttribute("Aspetto")), "/")[1]] = true
		emit("G", "Puro", f(20), tostring(10 + i))
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 0.98 then
				emitPart(d)
			end
		end
		emit("GE", "Puro")
		LOG("ASPETTO\t" .. tostring(model:GetAttribute("Aspetto")))
	else
		emit("GX", "Puro", tostring(model))
	end
end

LOG(table.concat(out, "\n"))
LOG(("FINE\t%d"):format(count))
local _ = Config
