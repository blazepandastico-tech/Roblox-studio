--[[
	Esporta la "forma" del gioco per tools/check_layout.py: serve a dimostrare che un cambio solo
	grafico non sposta nulla.
	  P  ogni parte del mondo: percorso, classe, forma, misure, posizione, collisioni (con i valori
	     predefiniti di Roblox quando non sono stati impostati), ancoraggio, attributi, aspetto
	  I  oggetti con cui si interagisce (ProximityPrompt, ClickDetector, Seat...)
	  T  ogni pezzo di terreno
	  G  i giganti (una serie di aspetti e semi): parti colpibili (con HitZone/Limb) e giunture "M"
	Alla fine "FINE".
]]

local TitanBuilder = require(SHARED.Anim.TitanBuilder)

local WB = require(SERVER.Services.WorldBuilder)
WB.Init({})
local ok, err = pcall(WB.Build)
if not ok then
	error("WorldBuilder.Build: " .. tostring(err))
end

local function f(n: number): string
	local s = string.format("%.3f", n)
	return if s == "-0.000" then "0.000" else s
end

-- valore impostato dallo script, o il predefinito di Roblox
local function prop(inst: Instance, name: string, default: any): any
	local value = rawget(inst :: any, "__props")[name]
	if value == nil then
		return default
	end
	return value
end

local function cfText(cf: CFrame): string
	local c = { cf:GetComponents() }
	for i, v in c do
		c[i] = f(v)
	end
	return table.concat(c, ",")
end

local function path(inst: Instance, stop: Instance?): string
	local names = {}
	local node: Instance? = inst.Parent
	while node and node ~= stop and node ~= game do
		table.insert(names, 1, node.Name)
		node = node.Parent
	end
	return table.concat(names, "/")
end

local function attrs(inst: Instance): string
	local list = {}
	for k, v in inst:GetAttributes() do
		local text = if typeof(v) == "number" then f(v) else tostring(v)
		table.insert(list, k .. "=" .. text)
	end
	table.sort(list)
	return table.concat(list, ";")
end

local out = {}
local function emit(...)
	local fields = table.pack(...)
	for i = 1, fields.n do
		fields[i] = tostring(fields[i])
	end
	table.insert(out, table.concat(fields, "\t"))
	if #out >= 2000 then
		LOG(table.concat(out, "\n"))
		table.clear(out)
	end
end

local function rgb(c: Color3): string
	return ("%d,%d,%d"):format(math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function emitPart(tag: string, d: BasePart, stop: Instance?)
	local shape = d.ClassName
	if d.ClassName == "Part" then
		local s = prop(d, "Shape", nil)
		shape = if s then s.Name else "Block"
	end
	local size = d.Size
	local material = prop(d, "Material", nil)
	local physical = prop(d, "CustomPhysicalProperties", nil)
	emit(
		tag,
		path(d, stop),
		d.Name,
		d.ClassName,
		shape,
		f(size.X) .. "," .. f(size.Y) .. "," .. f(size.Z),
		cfText(d.CFrame),
		tostring(prop(d, "CanCollide", true)),
		tostring(prop(d, "CanQuery", true)),
		tostring(prop(d, "CanTouch", true)),
		tostring(prop(d, "CollisionGroup", "Default")),
		tostring(prop(d, "Anchored", false)),
		tostring(prop(d, "Massless", false)),
		if physical then tostring(physical) else "-",
		attrs(d),
		f(prop(d, "Transparency", 0)),
		if material then material.Name else "Plastic",
		rgb(prop(d, "Color", Color3.new(0.64, 0.64, 0.64)))
	)
end

-- oggetti con cui il giocatore interagisce (o che il codice cerca per nome)
local INTERACTIVE = {
	ProximityPrompt = true,
	ClickDetector = true,
	Seat = true,
	VehicleSeat = true,
	SpawnLocation = true,
	Humanoid = true,
	ObjectValue = true,
	StringValue = true,
	NumberValue = true,
	IntValue = true,
	BoolValue = true,
	CFrameValue = true,
	Vector3Value = true,
	Configuration = true,
	BindableEvent = true,
	RemoteEvent = true,
}

for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") then
		emitPart("P", d :: BasePart)
	end
	if INTERACTIVE[d.ClassName] then
		local extra = ""
		if d:IsA("ProximityPrompt") then
			extra = table.concat({
				tostring(prop(d, "ActionText", "")),
				tostring(prop(d, "ObjectText", "")),
				f(prop(d, "MaxActivationDistance", 10)),
				f(prop(d, "HoldDuration", 0)),
				tostring(prop(d, "KeyboardKeyCode", Enum.KeyCode.E)),
				tostring(prop(d, "RequiresLineOfSight", true)),
			}, ",")
		end
		emit("I", path(d), d.Name, d.ClassName, attrs(d), extra)
	end
end
for _, t in MOCK_TERRAIN do
	if t.Kind == "Ball" then
		emit("T", "Ball", f(t.Center.X) .. "," .. f(t.Center.Y) .. "," .. f(t.Center.Z), f(t.Radius), t.Material.Name)
	elseif t.Kind == "Cylinder" then
		emit("T", "Cylinder", f(t.Height), f(t.Radius), t.Material.Name, cfText(t.CFrame))
	else
		emit("T", t.Kind, f(t.Size.X) .. "," .. f(t.Size.Y) .. "," .. f(t.Size.Z), t.Material.Name, cfText(t.CFrame))
	end
end

-- giganti: le parti colpibili (nuca, occhi, arti) e lo scheletro devono restare identici
local LOOKS = { "Puro", "Ghignante", "Cacciatrice", "Bastione", "Vulcano", "Furia", "Fauno", "Dorato", "Sagoma" }
local HEIGHTS = { 8, 15, 22, 40, 55 }
for li, look in LOOKS do
	for hi, height in HEIGHTS do
		for s = 1, 3 do
			local seed = li * 1000 + hi * 37 + s
			local okT, model = pcall(TitanBuilder.Build, { Height = height, Look = look, Seed = seed, Name = look })
			local tag = ("%s/%d/%d"):format(look, height, seed)
			if not okT or not model then
				emit("GX", tag, tostring(model))
				continue
			end
			emit("G", tag, attrs(model))
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					local gameplay = prop(d, "CanQuery", true) or prop(d, "CanCollide", true) or d:GetAttribute("HitZone") ~= nil
					emitPart(if gameplay then "GP" else "GD", d :: BasePart, model)
				elseif d:IsA("Motor6D") then
					local m = d :: Motor6D
					emit("GM", m.Name, if m.Part0 then m.Part0.Name else "-", if m.Part1 then m.Part1.Name else "-", cfText(m.C0), cfText(m.C1))
				end
			end
		end
	end
end
LOG(table.concat(out, "\n"))
LOG("FINE")
