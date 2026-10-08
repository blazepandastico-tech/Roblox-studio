-- Attrezzi comuni per costruire la mappa: parti, cilindri, testi, numeri casuali ripetibili.
local CollectionService = game:GetService("CollectionService")

local Util = {}

local SMOOTH = Enum.Material.SmoothPlastic

-- Crea una parte ancorata. opts: decor (niente collisioni/query/touch), shape, shadow (true/false), reflectance
local function make(parent, name, size, cf, color, material, transparency, opts)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or SMOOTH
	p.Transparency = transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts then
		if opts.shape then
			p.Shape = opts.shape
		end
		if opts.decor then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
		if opts.shadow ~= nil then
			p.CastShadow = opts.shadow
		elseif opts.decor and math.max(size.X, size.Y, size.Z) < 5 then
			p.CastShadow = false
		end
		if opts.reflectance then
			p.Reflectance = opts.reflectance
		end
	end
	p.Parent = parent
	return p
end
Util.make = make

-- Parte solida (collide)
function Util.P(parent, name, size, cf, color, material, transparency, opts)
	return make(parent, name, size, cf, color, material, transparency, opts)
end

-- Parte decorativa: non collide, non interrogabile, non tocca
function Util.D(parent, name, size, cf, color, material, transparency, opts)
	local o = { decor = true }
	if opts then
		for k, v in pairs(opts) do
			o[k] = v
		end
	end
	return make(parent, name, size, cf, color, material, transparency, o)
end

function Util.folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Util.model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Util.tag(inst, tag)
	CollectionService:AddTag(inst, tag)
	return inst
end

-- Colori
function Util.shade(c, f)
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end

function Util.mix(a, b, t)
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

-- Cilindro con asse lungo X (convenzione Roblox) tra due punti
function Util.rod(parent, name, a, b, diameter, color, material, solid, opts)
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0)
	local o = { shape = Enum.PartType.Cylinder, decor = not solid }
	if opts then
		for k, v in pairs(opts) do
			o[k] = v
		end
	end
	return make(parent, name, Vector3.new(len, diameter, diameter), cf, color, material, 0, o)
end

-- Cilindro verticale con base a y0 e altezza h
function Util.pillar(parent, name, x, y0, z, diameter, h, color, material, solid, opts)
	local o = { shape = Enum.PartType.Cylinder, decor = not solid }
	if opts then
		for k, v in pairs(opts) do
			o[k] = v
		end
	end
	return make(parent, name, Vector3.new(h, diameter, diameter), CFrame.new(x, y0 + h / 2, z) * CFrame.Angles(0, 0, math.pi / 2), color, material, 0, o)
end

-- Blocco lungo tra due punti (sezione w x h)
function Util.beam(parent, name, a, b, w, h, color, material, solid, opts)
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0)
	local o = { decor = not solid }
	if opts then
		for k, v in pairs(opts) do
			o[k] = v
		end
	end
	return make(parent, name, Vector3.new(len, h, w), cf, color, material, 0, o)
end

function Util.sphere(parent, name, center, diameter, color, material, solid, opts)
	local o = { shape = Enum.PartType.Ball, decor = not solid }
	if opts then
		for k, v in pairs(opts) do
			o[k] = v
		end
	end
	return make(parent, name, Vector3.new(diameter, diameter, diameter), CFrame.new(center), color, material, 0, o)
end

-- Testo su una faccia di una parte (SurfaceGui + TextLabel). o: font, color, pps, scaled, size, name, light, stroke
function Util.label(part, face, text, o)
	o = o or {}
	local gui = Instance.new("SurfaceGui")
	gui.Name = o.guiName or "Gui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = o.pps or 30
	gui.LightInfluence = o.light or 0
	gui.Parent = part
	local l = Instance.new("TextLabel")
	l.Name = o.name or "Text"
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = o.font or Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = o.color or Color3.new(1, 1, 1)
	l.Text = text
	if o.stroke then
		l.TextStrokeTransparency = 0.4
		l.TextStrokeColor3 = o.stroke
	end
	if o.tt then
		l.TextTransparency = o.tt
	end
	l.Parent = gui
	return l
end

----------------------------------------------------------------------
-- Numeri casuali ripetibili (stessi risultati su qualunque macchina: solo aritmetica intera esatta)
----------------------------------------------------------------------
function Util.Rng(seed)
	local s = math.floor(seed) % 2147483647
	if s <= 0 then
		s = s + 2147483646
	end
	local r = {}
	function r.Next()
		s = (s * 48271) % 2147483647
		return s / 2147483647
	end
	function r.Range(a, b)
		return a + (b - a) * r.Next()
	end
	function r.Int(a, b)
		return a + math.floor(r.Next() * (b - a + 1))
	end
	function r.Pick(t)
		return t[r.Int(1, #t)]
	end
	function r.Sign()
		return (r.Next() < 0.5) and -1 or 1
	end
	return r
end

-- Rumore di valore 2D ripetibile, 0..1
local function hash2(ix, iz)
	local h = (ix * 73856093 + iz * 19349663 + 83492791) % 2147483647
	h = (h * 48271) % 2147483647
	h = (h * 48271 + ix * 7) % 2147483647
	return h / 2147483647
end

function Util.noise(x, z)
	local ix, iz = math.floor(x), math.floor(z)
	local fx, fz = x - ix, z - iz
	local ux = fx * fx * (3 - 2 * fx)
	local uz = fz * fz * (3 - 2 * fz)
	local a, b = hash2(ix, iz), hash2(ix + 1, iz)
	local c, d = hash2(ix, iz + 1), hash2(ix + 1, iz + 1)
	return a + (b - a) * ux + (c - a) * uz + (a - b - c + d) * ux * uz
end

function Util.fbm(x, z, octaves)
	local amp, sum, norm = 1, 0, 0
	for _ = 1, octaves or 3 do
		sum = sum + Util.noise(x, z) * amp
		norm = norm + amp
		x, z = x * 2.03 + 11.7, z * 2.03 + 5.3
		amp = amp * 0.5
	end
	return sum / norm
end

return Util
