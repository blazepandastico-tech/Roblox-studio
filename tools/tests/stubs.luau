--[[
	Sostituti minimi dei tipi di Roblox (Vector3, Color3, CFrame, Random...) per poter
	caricare i moduli condivisi fuori da Roblox Studio con l'interprete "luau".
	Il file viene unito da tools/test_data.py con la tabella SOURCES (percorso -> codice).
]]

local SOURCES: { [string]: string } = SOURCES_TABLE

-- Vector3 ------------------------------------------------------------------------------------
local V3 = {}
local function v3(x: number?, y: number?, z: number?)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
V3.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	elseif key == "Unit" then
		local m = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
		return if m > 0 then v3(self.X / m, self.Y / m, self.Z / m) else v3()
	end
	return rawget(V3, key)
end
V3.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(a)
	return ("%g, %g, %g"):format(a.X, a.Y, a.Z)
end
function V3.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function V3.Cross(a, b)
	return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function V3.Lerp(a, b, t)
	return a + (b - a) * t
end
Vector3 = { new = v3, zero = v3(), one = v3(1, 1, 1), xAxis = v3(1, 0, 0), yAxis = v3(0, 1, 0), zAxis = v3(0, 0, 1) }

-- Color3 -------------------------------------------------------------------------------------
local C3 = {}
C3.__index = C3
local function c3(r: number?, g: number?, b: number?)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3)
end
function C3.Lerp(a, b, t)
	return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
Color3 = {
	new = c3,
	fromRGB = function(r, g, b)
		assert(type(r) == "number" and type(g) == "number" and type(b) == "number", "Color3.fromRGB: valori non numerici")
		return c3(r / 255, g / 255, b / 255)
	end,
	fromHSV = function(_h, _s, v)
		return c3(v, v, v)
	end,
}

-- CFrame (solo quello che serve alle pose) ----------------------------------------------------
local CF = {}
CF.__index = CF
local function cf(kind: string, ...)
	return setmetatable({ Kind = kind, Args = { ... } }, CF)
end
CF.__mul = function(a, b)
	if getmetatable(b) == V3 then
		return b
	end
	return cf("Product", a, b)
end
CFrame = {
	new = function(...)
		return cf("New", ...)
	end,
	Angles = function(...)
		return cf("Angles", ...)
	end,
	fromEulerAnglesXYZ = function(...)
		return cf("Angles", ...)
	end,
	identity = cf("Identity"),
}

-- Random deterministico ----------------------------------------------------------------------
local RandomMT = {}
RandomMT.__index = RandomMT
function RandomMT.NextNumber(self, min: number?, max: number?)
	self.State = (self.State * 1103515245 + 12345) % 2147483648
	local t = self.State / 2147483648
	local lo, hi = min or 0, max or 1
	return lo + (hi - lo) * t
end
function RandomMT.NextInteger(self, min: number, max: number)
	return math.floor(self:NextNumber(min, max + 1 - 1e-9))
end
Random = {
	new = function(seed: number?)
		return setmetatable({ State = math.floor(seed or 12345) % 2147483648 }, RandomMT)
	end,
}

local nativeTypeof = typeof
typeof = function(value: any): string
	local mt = getmetatable(value)
	if mt == V3 then
		return "Vector3"
	elseif mt == C3 then
		return "Color3"
	elseif mt == CF then
		return "CFrame"
	end
	return nativeTypeof(value)
end

-- Albero finto di "script" e require -----------------------------------------------------------
local NodeMT = {}
local function node(path: string, name: string, parent: any)
	return setmetatable({ __path = path, Name = name, Parent = parent }, NodeMT)
end
NodeMT.__index = function(self, key)
	local path = rawget(self, "__path")
	local childPath = if path == "" then key else path .. "/" .. key
	return node(childPath, key, self)
end

local ROOT = node("", "Shared", nil)
local cache: { [string]: any } = {}

local function nodeFor(path: string)
	local current = ROOT
	for part in path:gmatch("[^/]+") do
		current = current[part]
	end
	return current
end

require = function(target: any)
	local path = rawget(target, "__path")
	assert(type(path) == "string", "require: argomento non valido")
	if cache[path] ~= nil then
		return cache[path]
	end
	local source = SOURCES[path]
	assert(source, "require: modulo inesistente '" .. path .. "'")
	local chunk, err = loadstring("local script = ...\n" .. source, "=" .. path)
	assert(chunk, err)
	local result = chunk(nodeFor(path))
	cache[path] = result
	return result
end

SHARED = ROOT
