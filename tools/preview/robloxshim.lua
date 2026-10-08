-- Mini-emulazione dell'API Roblox (solo il necessario) per eseguire il codice della mappa fuori da Studio
-- e registrare l'albero di istanze + le operazioni sul Terrain, cosi' da poterli disegnare in un'anteprima 3D.
-- Gira su Lua 5.3+ (lupa). NON e' Luau: serve solo come banco di prova.

local Shim = {}
local floor, sqrt, sin, cos, abs, atan, acos, rad = math.floor, math.sqrt, math.sin, math.cos, math.abs, math.atan, math.acos, math.rad

----------------------------------------------------------------------
-- math / table / string extras presenti in Luau
----------------------------------------------------------------------
math.clamp = function(x, a, b) if x < a then return a elseif x > b then return b end return x end
math.sign = function(x) if x > 0 then return 1 elseif x < 0 then return -1 end return 0 end
math.round = function(x) if x >= 0 then return floor(x + 0.5) end return -floor(-x + 0.5) end
math.noise = function() return 0 end
math.lerp = function(a, b, t) return a + (b - a) * t end
math.atan2 = function(y, x) return atan(y, x) end
math.pow = function(a, b) return a ^ b end
math.log10 = function(x) return math.log(x, 10) end
math.ldexp = math.ldexp or function(m, e) return m * 2.0 ^ e end
table.find = function(t, v, init)
	for i = init or 1, #t do if t[i] == v then return i end end
	return nil
end
table.clear = function(t) for k in pairs(t) do t[k] = nil end end
table.create = function(n, v) local t = {} for i = 1, n do t[i] = v end return t end
table.clone = function(t) local r = {} for k, v in pairs(t) do r[k] = v end return r end
unpack = unpack or table.unpack
string.split = function(s, sep)
	local out = {}
	for piece in string.gmatch(s .. sep, "(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = piece end
	return out
end

----------------------------------------------------------------------
-- typeof
----------------------------------------------------------------------
function typeof(v)
	local t = type(v)
	if t == "table" then
		local mt = getmetatable(v)
		if mt and mt.__typeof then return mt.__typeof end
		return "table"
	end
	return t
end

----------------------------------------------------------------------
-- Vector3
----------------------------------------------------------------------
local V3 = {}
V3.__typeof = "Vector3"
V3.__index = function(t, k)
	if k == "Magnitude" then return sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	if k == "Unit" then
		local m = sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
		if m == 0 then return setmetatable({ X = 0, Y = 0, Z = 0 }, V3) end
		return setmetatable({ X = t.X / m, Y = t.Y / m, Z = t.Z / m }, V3)
	end
	return V3[k]
end
local function v3(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, V3) end
V3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__tostring = function(a) return string.format("%g, %g, %g", a.X, a.Y, a.Z) end
function V3.new(x, y, z) return v3(x or 0, y or 0, z or 0) end
function V3.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function V3.Cross(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
function V3.Lerp(a, b, t) return a + (b - a) * t end
function V3.Abs(a) return v3(abs(a.X), abs(a.Y), abs(a.Z)) end
function V3.Floor(a) return v3(floor(a.X), floor(a.Y), floor(a.Z)) end
function V3.Max(a, b) return v3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z)) end
function V3.Min(a, b) return v3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)) end
function V3.FuzzyEq(a, b, e) e = e or 1e-5 return abs(a.X - b.X) <= e and abs(a.Y - b.Y) <= e and abs(a.Z - b.Z) <= e end
function V3.Angle(a, b)
	local d = a.Unit:Dot(b.Unit)
	return acos(math.max(-1, math.min(1, d)))
end
V3.zero = v3(0, 0, 0)
V3.one = v3(1, 1, 1)
V3.xAxis = v3(1, 0, 0)
V3.yAxis = v3(0, 1, 0)
V3.zAxis = v3(0, 0, 1)
Vector3 = V3

local V2 = { __typeof = "Vector2" }
V2.__index = V2
function V2.new(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2) end
Vector2 = V2

----------------------------------------------------------------------
-- Color3
----------------------------------------------------------------------
local C3 = { __typeof = "Color3" }
C3.__index = function(t, k)
	if k == "R" or k == "G" or k == "B" then return rawget(t, k) end
	return C3[k]
end
local function c3(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3) end
function C3.new(r, g, b) return c3(r or 0, g or 0, b or 0) end
function C3.fromRGB(r, g, b) return c3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end
function C3.fromHSV(h, s, v)
	h = h % 1
	local i = floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then return c3(v, t, p) elseif i == 1 then return c3(q, v, p) elseif i == 2 then return c3(p, v, t)
	elseif i == 3 then return c3(p, q, v) elseif i == 4 then return c3(t, p, v) end
	return c3(v, p, q)
end
function C3.fromHex(h)
	h = h:gsub("#", "")
	return c3(tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255)
end
function C3.Lerp(a, b, t) return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end
function C3.ToHSV(c)
	local mx, mn = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == c.R then h = ((c.G - c.B) / d) % 6 elseif mx == c.G then h = (c.B - c.R) / d + 2 else h = (c.R - c.G) / d + 4 end
		h = h / 6
	end
	return h, (mx == 0) and 0 or d / mx, mx
end
C3.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
C3.__tostring = function(a) return string.format("%g, %g, %g", a.R, a.G, a.B) end
Color3 = C3

BrickColor = { new = function(n) return { Name = tostring(n), Color = c3(0.6, 0.6, 0.6) } end }

----------------------------------------------------------------------
-- CFrame (posizione + matrice di rotazione 3x3, convenzioni Roblox)
----------------------------------------------------------------------
local CF = { __typeof = "CFrame" }
local function cf(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	return setmetatable({ x = x, y = y, z = z, r00 = r00, r01 = r01, r02 = r02, r10 = r10, r11 = r11, r12 = r12, r20 = r20, r21 = r21, r22 = r22 }, CF)
end
CF.__index = function(t, k)
	if k == "Position" then return v3(t.x, t.y, t.z) end
	if k == "X" then return t.x end
	if k == "Y" then return t.y end
	if k == "Z" then return t.z end
	if k == "LookVector" then return v3(-t.r02, -t.r12, -t.r22) end
	if k == "RightVector" then return v3(t.r00, t.r10, t.r20) end
	if k == "UpVector" then return v3(t.r01, t.r11, t.r21) end
	if k == "Rotation" then return cf(0, 0, 0, t.r00, t.r01, t.r02, t.r10, t.r11, t.r12, t.r20, t.r21, t.r22) end
	return CF[k]
end
local function cfIdentity() return cf(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1) end

local function lookAtCF(at, target, up)
	up = up or v3(0, 1, 0)
	local z = at - target
	if z.Magnitude < 1e-9 then return cf(at.X, at.Y, at.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1) end
	z = z.Unit
	local x = up:Cross(z)
	if x.Magnitude < 1e-6 then
		-- guarda dritto su/giu': scelgo un asse X qualsiasi
		x = (z.Y > 0) and v3(1, 0, 0) or v3(1, 0, 0)
		x = v3(0, 0, -1):Cross(z)
		if x.Magnitude < 1e-6 then x = v3(1, 0, 0) end
	end
	x = x.Unit
	local y = z:Cross(x)
	return cf(at.X, at.Y, at.Z, x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z)
end

function CF.new(a, b, c, ...)
	if a == nil then return cfIdentity() end
	if type(a) == "table" then
		if b ~= nil then return lookAtCF(a, b) end
		return cf(a.X, a.Y, a.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	end
	if select("#", ...) == 0 then return cf(a, b, c, 1, 0, 0, 0, 1, 0, 0, 0, 1) end
	local r00, r01, r02, r10, r11, r12, r20, r21, r22 = ...
	return cf(a, b, c, r00, r01, r02, r10, r11, r12, r20, r21, r22)
end
CF.lookAt = lookAtCF
function CF.fromMatrix(pos, vx, vy, vz)
	vz = vz or vx:Cross(vy)
	return cf(pos.X, pos.Y, pos.Z, vx.X, vy.X, vz.X, vx.Y, vy.Y, vz.Y, vx.Z, vy.Z, vz.Z)
end
local function rotX(a) local c, s = cos(a), sin(a) return cf(0, 0, 0, 1, 0, 0, 0, c, -s, 0, s, c) end
local function rotY(a) local c, s = cos(a), sin(a) return cf(0, 0, 0, c, 0, s, 0, 1, 0, -s, 0, c) end
local function rotZ(a) local c, s = cos(a), sin(a) return cf(0, 0, 0, c, -s, 0, s, c, 0, 0, 0, 1) end
local function mul(a, b)
	return cf(
		a.x + a.r00 * b.x + a.r01 * b.y + a.r02 * b.z,
		a.y + a.r10 * b.x + a.r11 * b.y + a.r12 * b.z,
		a.z + a.r20 * b.x + a.r21 * b.y + a.r22 * b.z,
		a.r00 * b.r00 + a.r01 * b.r10 + a.r02 * b.r20, a.r00 * b.r01 + a.r01 * b.r11 + a.r02 * b.r21, a.r00 * b.r02 + a.r01 * b.r12 + a.r02 * b.r22,
		a.r10 * b.r00 + a.r11 * b.r10 + a.r12 * b.r20, a.r10 * b.r01 + a.r11 * b.r11 + a.r12 * b.r21, a.r10 * b.r02 + a.r11 * b.r12 + a.r12 * b.r22,
		a.r20 * b.r00 + a.r21 * b.r10 + a.r22 * b.r20, a.r20 * b.r01 + a.r21 * b.r11 + a.r22 * b.r21, a.r20 * b.r02 + a.r21 * b.r12 + a.r22 * b.r22
	)
end
function CF.Angles(rx, ry, rz) return mul(mul(rotX(rx), rotY(ry)), rotZ(rz)) end
CF.fromEulerAnglesXYZ = CF.Angles
function CF.fromEulerAnglesYXZ(rx, ry, rz) return mul(mul(rotY(ry), rotX(rx)), rotZ(rz)) end
function CF.fromOrientation(rx, ry, rz) return mul(mul(rotY(ry), rotX(rx)), rotZ(rz)) end
function CF.fromAxisAngle(axis, ang)
	local u = axis.Unit
	local c, s = cos(ang), sin(ang)
	local t = 1 - c
	local x, y, z = u.X, u.Y, u.Z
	return cf(0, 0, 0,
		t * x * x + c, t * x * y - s * z, t * x * z + s * y,
		t * x * y + s * z, t * y * y + c, t * y * z - s * x,
		t * x * z - s * y, t * y * z + s * x, t * z * z + c)
end
CF.__mul = function(a, b)
	if getmetatable(b) == V3 then
		return v3(a.x + a.r00 * b.X + a.r01 * b.Y + a.r02 * b.Z, a.y + a.r10 * b.X + a.r11 * b.Y + a.r12 * b.Z, a.z + a.r20 * b.X + a.r21 * b.Y + a.r22 * b.Z)
	end
	return mul(a, b)
end
CF.__add = function(a, v) return cf(a.x + v.X, a.y + v.Y, a.z + v.Z, a.r00, a.r01, a.r02, a.r10, a.r11, a.r12, a.r20, a.r21, a.r22) end
CF.__sub = function(a, v) return cf(a.x - v.X, a.y - v.Y, a.z - v.Z, a.r00, a.r01, a.r02, a.r10, a.r11, a.r12, a.r20, a.r21, a.r22) end
CF.__eq = function(a, b)
	return a.x == b.x and a.y == b.y and a.z == b.z and a.r00 == b.r00 and a.r01 == b.r01 and a.r02 == b.r02 and a.r10 == b.r10
		and a.r11 == b.r11 and a.r12 == b.r12 and a.r20 == b.r20 and a.r21 == b.r21 and a.r22 == b.r22
end
function CF.Inverse(a)
	local x = -(a.r00 * a.x + a.r10 * a.y + a.r20 * a.z)
	local y = -(a.r01 * a.x + a.r11 * a.y + a.r21 * a.z)
	local z = -(a.r02 * a.x + a.r12 * a.y + a.r22 * a.z)
	return cf(x, y, z, a.r00, a.r10, a.r20, a.r01, a.r11, a.r21, a.r02, a.r12, a.r22)
end
function CF.ToWorldSpace(a, b) return a * b end
function CF.ToObjectSpace(a, b) return a:Inverse() * b end
function CF.PointToWorldSpace(a, v) return a * v end
function CF.PointToObjectSpace(a, v) return a:Inverse() * v end
function CF.VectorToWorldSpace(a, v) return v3(a.r00 * v.X + a.r01 * v.Y + a.r02 * v.Z, a.r10 * v.X + a.r11 * v.Y + a.r12 * v.Z, a.r20 * v.X + a.r21 * v.Y + a.r22 * v.Z) end
function CF.VectorToObjectSpace(a, v) return a:Inverse():VectorToWorldSpace(v) end
function CF.GetComponents(a) return a.x, a.y, a.z, a.r00, a.r01, a.r02, a.r10, a.r11, a.r12, a.r20, a.r21, a.r22 end
CF.components = CF.GetComponents
function CF.ToEulerAnglesXYZ(a)
	local sy = math.max(-1, math.min(1, a.r02))
	local y = math.asin(sy)
	local x, z
	if abs(sy) < 0.999999 then x = atan(-a.r12, a.r22); z = atan(-a.r01, a.r00) else x = atan(a.r21, a.r11); z = 0 end
	return x, y, z
end
CF.ToEulerAnglesYXZ = function(a)
	local sx = math.max(-1, math.min(1, -a.r12))
	local x = math.asin(sx)
	local y, z
	if abs(sx) < 0.999999 then y = atan(a.r02, a.r22); z = atan(a.r10, a.r11) else y = atan(-a.r20, a.r00); z = 0 end
	return x, y, z
end
CF.ToOrientation = CF.ToEulerAnglesYXZ
function CF.Lerp(a, b, t)
	local p = a.Position:Lerp(b.Position, t)
	return cf(p.X, p.Y, p.Z, b.r00, b.r01, b.r02, b.r10, b.r11, b.r12, b.r20, b.r21, b.r22)
end
CF.__tostring = function(a) return string.format("%g, %g, %g", a.x, a.y, a.z) end
CF.identity = cfIdentity()
CFrame = CF

----------------------------------------------------------------------
-- piccoli tipi
----------------------------------------------------------------------
local function simpleType(name, ctor)
	local T = { __typeof = name }
	T.__index = T
	T.new = function(...) return setmetatable(ctor(...), T) end
	return T
end
UDim = simpleType("UDim", function(s, o) return { Scale = s or 0, Offset = o or 0 } end)
UDim2 = simpleType("UDim2", function(sx, ox, sy, oy) return { X = { Scale = sx or 0, Offset = ox or 0 }, Y = { Scale = sy or 0, Offset = oy or 0 } } end)
UDim2.fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end
UDim2.fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end
NumberRange = simpleType("NumberRange", function(a, b) return { Min = a, Max = b or a } end)
NumberSequenceKeypoint = simpleType("NumberSequenceKeypoint", function(t, v, e) return { Time = t, Value = v, Envelope = e or 0 } end)
ColorSequenceKeypoint = simpleType("ColorSequenceKeypoint", function(t, c) return { Time = t, Value = c } end)
NumberSequence = simpleType("NumberSequence", function(a, b)
	if type(a) == "table" then return { Keypoints = a } end
	b = b or a
	return { Keypoints = { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) } }
end)
ColorSequence = simpleType("ColorSequence", function(a, b)
	if getmetatable(a) == C3 then return { Keypoints = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a) } } end
	return { Keypoints = a }
end)
PhysicalProperties = simpleType("PhysicalProperties", function(d, f, e, fw, ew) return { Density = d, Friction = f, Elasticity = e, FrictionWeight = fw, ElasticityWeight = ew } end)
TweenInfo = simpleType("TweenInfo", function(t, s, d) return { Time = t, EasingStyle = s, EasingDirection = d } end)
Rect = simpleType("Rect", function(a, b, c, d) return { a = a, b = b, c = c, d = d } end)
Font = { new = function(f) return { Family = f } end, fromEnum = function(e) return { Enum = e } end }

----------------------------------------------------------------------
-- Enum: tutti i valori sono creati al volo e ricordano il loro nome
----------------------------------------------------------------------
local EnumItemMT = { __typeof = "EnumItem" }
EnumItemMT.__tostring = function(e) return "Enum." .. e.EnumType .. "." .. e.Name end
local enumTypes = {}
Enum = setmetatable({}, {
	__index = function(t, typeName)
		local items = {}
		local E = setmetatable({}, {
			__index = function(_, itemName)
				if itemName == "GetEnumItems" then return function() local r = {} for _, v in pairs(items) do r[#r + 1] = v end return r end end
				local it = items[itemName]
				if not it then
					it = setmetatable({ Name = itemName, EnumType = typeName, Value = 0 }, EnumItemMT)
					items[itemName] = it
				end
				return it
			end,
		})
		rawset(t, typeName, E)
		return E
	end,
})

----------------------------------------------------------------------
-- Instance
----------------------------------------------------------------------

----------------------------------------------------------------------
-- verifica rigorosa contro l'API reale di Roblox (api_index.lua, generato da API-Dump.json)
----------------------------------------------------------------------
local API
do
	local path = rawget(_G, "API_INDEX_PATH")
	if path then
		local f = io.open(path, "rb")
		if f then
			local src = f:read("a")
			f:close()
			API = load(src, "@api_index")()
		end
	end
end
Shim.API = API
Shim.problems = {}
Shim.deprecated = {}
Shim.stubs = {}
local function problem(msg)
	Shim.problems[#Shim.problems + 1] = msg
end
local memberCache = {}
local function findMember(cls, kind, name)
	if not API then return true end
	local key = cls .. "|" .. kind .. "|" .. name
	local hit = memberCache[key]
	if hit ~= nil then return hit end
	local c = cls
	local res = false
	while c and API.classes[c] do
		local info = API.classes[c]
		local v = info[kind][name]
		if v ~= nil then res = v break end
		c = info.s
		if c == "<<<ROOT>>>" then break end
	end
	memberCache[key] = res
	return res
end
local function classIsA(cls, target)
	if not API then return cls == target end
	local c = cls
	while c and API.classes[c] do
		if c == target then return true end
		c = API.classes[c].s
		if c == "<<<ROOT>>>" then break end
	end
	return false
end
Shim.classIsA = classIsA
local DATATYPES = { Vector3 = true, Vector2 = true, CFrame = true, Color3 = true, UDim = true, UDim2 = true, NumberSequence = true, ColorSequence = true, NumberRange = true, PhysicalProperties = true, Rect = true }
local function checkAssign(cls, k, v)
	local code = findMember(cls, "p", k)
	if not code then
		error(string.format("'%s' non e' una proprieta' valida di %s", tostring(k), cls), 3)
	end
	local flags = code:match("^[!?~]*")
	if flags:find("!", 1, true) then
		error(string.format("la proprieta' %s.%s non e' scrivibile da uno script (sola lettura/sicurezza)", cls, tostring(k)), 3)
	end
	if flags:find("~", 1, true) then Shim.deprecated[cls .. "." .. tostring(k)] = true end
	local kind, name = code:sub(#flags + 1):match("^(%a):(.*)$")
	local tv = typeof(v)
	local ok = true
	if kind == "E" then
		ok = (tv == "EnumItem" and v.EnumType == name)
		if ok and API.enums[name] and API.enums[name][v.Name] == nil then
			error(string.format("Enum.%s.%s non esiste (assegnato a %s.%s)", name, v.Name, cls, tostring(k)), 3)
		end
	elseif kind == "P" then
		if name == "bool" then ok = (tv == "boolean")
		elseif name == "string" then ok = (tv == "string")
		elseif name == "int" or name == "float" or name == "double" or name == "int64" then ok = (tv == "number")
		end
	elseif kind == "D" then
		if DATATYPES[name] then ok = (tv == name) end
	elseif kind == "C" then
		ok = (v == nil or tv == "Instance")
	end
	if not ok then
		error(string.format("tipo errato per %s.%s: atteso %s, ricevuto %s", cls, tostring(k), code, tv), 3)
	end
end

local InstanceMT = { __typeof = "Instance" }
local Instance = {}
local PART_CLASSES = { Part = true, WedgePart = true, MeshPart = true, SpawnLocation = true, TrussPart = true, CornerWedgePart = true, UnionOperation = true, Seat = true }
local MODEL_CLASSES = { Model = true, Folder = true }

local methods = {}
local newInstance

local function addChild(parent, child)
	local list = rawget(parent, "_children")
	list[#list + 1] = child
end
local function removeChild(parent, child)
	local list = rawget(parent, "_children")
	for i = #list, 1, -1 do
		if list[i] == child then table.remove(list, i) break end
	end
end

local Signal = {}
Signal.__index = Signal
function Signal.new() return setmetatable({ _fns = {} }, Signal) end
function Signal:Connect(fn) self._fns[#self._fns + 1] = fn return { Disconnect = function() end, Connected = true } end
function Signal:Once(fn) return self:Connect(fn) end
function Signal:Wait() return nil end
function Signal:Fire(...) for _, f in ipairs(self._fns) do f(...) end end

InstanceMT.__index = function(t, k)
	if k == "Parent" then return rawget(t, "_parent") end
	local props = rawget(t, "_p")
	local v = props[k]
	if v ~= nil then return v end
	local cls = rawget(t, "ClassName")
	if k == "ClassName" then return cls end
	local m = methods[k]
	if m and (not API or findMember(cls, "f", k)) then return m end
	if k == "Position" and PART_CLASSES[cls] then return props.CFrame.Position end
	if (k == "Orientation" or k == "Rotation") and PART_CLASSES[cls] then
		local x, y, z = props.CFrame:ToOrientation()
		return v3(math.deg(x), math.deg(y), math.deg(z))
	end
	if type(k) ~= "string" then return nil end
	-- eventi (Touched, ChildAdded, ...) -> segnale creato al volo
	if findMember(cls, "e", k) then
		local s = Signal.new()
		props[k] = s
		return s
	end
	-- figli per nome (workspace.World)
	local list = rawget(t, "_children")
	for i = 1, #list do
		if list[i].Name == k then return list[i] end
	end
	-- metodo previsto dall'API ma non emulato: restituisco uno stub
	local f = API and findMember(cls, "f", k)
	if f then
		local key = cls .. ":" .. k
		if not Shim.stubs[key] then Shim.stubs[key] = true end
		return function() return nil end
	end
	if API then
		-- proprieta' valida ma non impostata -> nil; altrimenti errore come in Roblox
		if findMember(cls, "p", k) then return nil end
		error(string.format("'%s' non e' un membro valido di %s (%s)", k, cls, tostring(props.Name)), 2)
	end
	return nil
end
InstanceMT.__newindex = function(t, k, v)
	local cls = rawget(t, "ClassName")
	if k == "Parent" then
		if v ~= nil and typeof(v) ~= "Instance" then error("Parent deve essere un Instance", 2) end
		local old = rawget(t, "_parent")
		if old then removeChild(old, t) end
		rawset(t, "_parent", v)
		if v then addChild(v, t) end
		return
	end
	if API then checkAssign(cls, k, v) end
	local props = rawget(t, "_p")
	if k == "Position" and PART_CLASSES[cls] then
		local c = props.CFrame
		props.CFrame = cf(v.X, v.Y, v.Z, c.r00, c.r01, c.r02, c.r10, c.r11, c.r12, c.r20, c.r21, c.r22)
		return
	end
	if k == "Orientation" and PART_CLASSES[cls] then
		local c = props.CFrame
		local r = CF.fromOrientation(rad(v.X), rad(v.Y), rad(v.Z))
		props.CFrame = cf(c.x, c.y, c.z, r.r00, r.r01, r.r02, r.r10, r.r11, r.r12, r.r20, r.r21, r.r22)
		return
	end
	props[k] = v
end
InstanceMT.__tostring = function(t) return tostring(rawget(t, "_p").Name) end

function methods.GetChildren(self)
	local out = {}
	for i, c in ipairs(rawget(self, "_children")) do out[i] = c end
	return out
end
function methods.GetDescendants(self)
	local out = {}
	local function walk(o)
		for _, c in ipairs(rawget(o, "_children")) do out[#out + 1] = c walk(c) end
	end
	walk(self)
	return out
end
function methods.FindFirstChild(self, name, recursive)
	for _, c in ipairs(rawget(self, "_children")) do
		if c.Name == name then return c end
	end
	if recursive then
		for _, c in ipairs(rawget(self, "_children")) do
			local r = c:FindFirstChild(name, true)
			if r then return r end
		end
	end
	return nil
end
methods.WaitForChild = function(self, name) return self:FindFirstChild(name) end
function methods.FindFirstChildOfClass(self, cls)
	for _, c in ipairs(rawget(self, "_children")) do
		if c.ClassName == cls then return c end
	end
	return nil
end
function methods.FindFirstChildWhichIsA(self, cls)
	for _, c in ipairs(rawget(self, "_children")) do
		if c:IsA(cls) then return c end
	end
	return nil
end
function methods.IsA(self, cls)
	local c = rawget(self, "ClassName")
	if c == cls or cls == "Instance" then return true end
	if API then return classIsA(c, cls) end
	if cls == "BasePart" then return PART_CLASSES[c] == true end
	if cls == "Part" then return c == "Part" or c == "SpawnLocation" end
	if cls == "PVInstance" then return PART_CLASSES[c] == true or c == "Model" end
	if cls == "GuiObject" then return c == "TextLabel" or c == "Frame" end
	return false
end
function methods.Destroy(self)
	local p = rawget(self, "_parent")
	if p then removeChild(p, self) end
	rawset(self, "_parent", nil)
end
methods.Remove = methods.Destroy
function methods.ClearAllChildren(self)
	for _, c in ipairs(self:GetChildren()) do c:Destroy() end
end
local attrSignals = setmetatable({}, { __mode = "k" })
function methods.SetAttribute(self, k, v)
	local at = rawget(self, "_attrs")
	local changed = at[k] ~= v
	at[k] = v
	local sigs = attrSignals[self]
	if changed and sigs and sigs[k] then sigs[k]:Fire() end
end
function methods.GetAttributeChangedSignal(self, k)
	attrSignals[self] = attrSignals[self] or {}
	local s = attrSignals[self][k]
	if not s then s = Signal.new() attrSignals[self][k] = s end
	return s
end
function methods.GetAttribute(self, k) return rawget(self, "_attrs")[k] end
function methods.GetAttributes(self) return rawget(self, "_attrs") end
function methods.IsDescendantOf(self, anc)
	local p = rawget(self, "_parent")
	while p do
		if p == anc then return true end
		p = rawget(p, "_parent")
	end
	return false
end
function methods.GetFullName(self)
	local parts = {}
	local o = self
	while o do parts[#parts + 1] = o.Name o = rawget(o, "_parent") end
	local r = {}
	for i = #parts, 1, -1 do r[#r + 1] = parts[i] end
	return table.concat(r, ".")
end
function methods.GetPivot(self)
	local P = rawget(self, "_p")
	if rawget(self, "ClassName") == "Model" then
		local pp = P.PrimaryPart
		if pp then return rawget(pp, "_p").CFrame end
		for _, d in ipairs(self:GetDescendants()) do
			if PART_CLASSES[rawget(d, "ClassName")] then return rawget(d, "_p").CFrame end
		end
		return cfIdentity()
	end
	return P.CFrame or cfIdentity()
end
function methods.PivotTo(self, c)
	if rawget(self, "ClassName") == "Model" then
		local old = self:GetPivot()
		local delta = c * old:Inverse()
		for _, d in ipairs(self:GetDescendants()) do
			if PART_CLASSES[rawget(d, "ClassName")] then
				local dp = rawget(d, "_p")
				dp.CFrame = delta * dp.CFrame
			end
		end
		return
	end
	rawget(self, "_p").CFrame = c
end
function methods.Clone(self)
	local copy = newInstance(rawget(self, "ClassName"), nil, true)
	for k, v in pairs(rawget(self, "_p")) do
		if not (type(v) == "table" and getmetatable(v) == Signal) then rawget(copy, "_p")[k] = v end
	end
	for k, v in pairs(rawget(self, "_attrs")) do rawget(copy, "_attrs")[k] = v end
	for k, v in pairs(rawget(self, "_tags")) do rawget(copy, "_tags")[k] = v end
	for _, c in ipairs(rawget(self, "_children")) do
		local cc = c:Clone()
		cc.Parent = copy
	end
	return copy
end
function methods.SetPrimaryPartCFrame(self, c) rawget(self, "_p").CFrame = c end
function methods.BreakJoints() end
function methods.MakeJoints() end
function methods.GetBoundingBox(self) return cfIdentity(), v3(1, 1, 1) end
function methods.GetExtentsSize(self) return v3(1, 1, 1) end
-- Terrain
function methods.SetMaterialColor(self, material, color)
	local T = rawget(self, "_terrain")
	if T then T.colors[material.Name] = color end
end
local function terrainOp(name) return function(self, ...) local T = rawget(self, "_terrain") if T then T.ops[#T.ops + 1] = { name, ... } end end end
methods.FillBlock = terrainOp("FillBlock")
methods.FillBall = terrainOp("FillBall")
methods.FillCylinder = terrainOp("FillCylinder")
methods.FillWedge = terrainOp("FillWedge")
function methods.Clear(self)
	local T = rawget(self, "_terrain")
	if T then T.ops[#T.ops + 1] = { "Clear" } end
end
-- particelle
function methods.Emit() end
function methods.Play() end
function methods.Stop() end
function methods.Pause() end
function methods.Cancel() end
function methods.GetPropertyChangedSignal() return Signal.new() end
function methods.GetService() return nil end

function newInstance(cls, parent, internal)
	if API and not internal then
		local info = API.classes[cls]
		if not info then error("Instance.new: classe sconosciuta '" .. tostring(cls) .. "'", 3) end
		if info.c == 0 then error("Instance.new: la classe '" .. cls .. "' non e' creabile", 3) end
	end
	local o = setmetatable({ ClassName = cls, _p = { Name = cls }, _children = {}, _attrs = {}, _tags = {}, _parent = nil }, InstanceMT)
	local P = o._p
	if PART_CLASSES[cls] then
		P.Size = v3(4, 1, 2)
		P.CFrame = cfIdentity()
		P.Color = c3(0.639, 0.635, 0.647)
		P.Material = Enum.Material.Plastic
		P.Transparency = 0
		P.Anchored = false
		P.CanCollide = true
		P.CanQuery = true
		P.CanTouch = true
		P.CastShadow = true
		P.Shape = Enum.PartType.Block
		P.Reflectance = 0
		P.TopSurface = Enum.SurfaceType.Studs
		P.BottomSurface = Enum.SurfaceType.Inlet
		if cls == "SpawnLocation" then P.Neutral = true end
	elseif cls == "Terrain" then
		rawset(o, "_terrain", { ops = {}, colors = {} })
	end
	if parent then o.Parent = parent end
	return o
end
function Instance.new(cls, parent) return newInstance(cls, parent, false) end
Instance.__internal = function(cls) return newInstance(cls, nil, true) end
Shim.Instance = Instance
_G.Instance = Instance
Instance.__MT = InstanceMT

----------------------------------------------------------------------
-- Random: stesso generatore su ogni piattaforma non e' garantito, quindi il codice della mappa usa il suo
----------------------------------------------------------------------
local Random = {}
Random.__index = Random
function Random.new(seed)
	return setmetatable({ s = (seed or 0) * 2654435761 % 4294967296 + 12345 }, Random)
end
function Random:_next()
	self.s = (self.s * 1664525 + 1013904223) % 4294967296
	return self.s / 4294967296
end
function Random:NextNumber(a, b)
	if a == nil then return self:_next() end
	return a + (b - a) * self:_next()
end
function Random:NextInteger(a, b) return a + floor(self:_next() * (b - a + 1)) end
function Random:NextUnitVector()
	local z = self:NextNumber(-1, 1)
	local t = self:NextNumber(0, 2 * math.pi)
	local r = sqrt(1 - z * z)
	return v3(r * cos(t), z, r * sin(t))
end
_G.Random = Random

----------------------------------------------------------------------
-- servizi
----------------------------------------------------------------------
local services = {}
local function mkService(name, cls)
	local o = Instance.__internal(cls or name)
	o.Name = name
	services[name] = o
	return o
end
local game_ = Instance.__internal("DataModel")
game_.Name = "Game"
local ws = mkService("Workspace")
ws.Parent = game_
local terrain = Instance.__internal("Terrain")
terrain.Name = "Terrain"
terrain.Parent = ws
rawset(ws, "Terrain", nil)
for _, n in ipairs({ "Lighting", "ReplicatedStorage", "ServerScriptService", "StarterPlayer", "Teams", "Players", "ServerStorage", "StarterGui", "SoundService", "Debris", "RunService", "TweenService", "UserInputService", "ContextActionService", "HttpService", "CollectionService", "DataStoreService", "MarketplaceService", "TextService", "Chat" }) do
	local s = mkService(n)
	if n ~= "CollectionService" and n ~= "RunService" and n ~= "TweenService" and n ~= "Debris" and n ~= "HttpService" and n ~= "DataStoreService" then s.Parent = game_ end
end
Shim.services = services

local CollectionService = services.CollectionService
local tagged = {}
function methods.AddTag(self, tag) rawget(self, "_tags")[tag] = true end
function methods.RemoveTag(self, tag) rawget(self, "_tags")[tag] = nil end
function methods.HasTag(self, tag) return rawget(self, "_tags")[tag] == true end
function methods.GetTags(self) local r = {} for k in pairs(rawget(self, "_tags")) do r[#r + 1] = k end return r end
-- CollectionService:AddTag(inst, tag)
rawset(CollectionService, "AddTag", function(_, inst, tag) rawget(inst, "_tags")[tag] = true end)
rawset(CollectionService, "RemoveTag", function(_, inst, tag) rawget(inst, "_tags")[tag] = nil end)
rawset(CollectionService, "HasTag", function(_, inst, tag) return rawget(inst, "_tags")[tag] == true end)
rawset(CollectionService, "GetTagged", function(_, tag)
	local out = {}
	for _, d in ipairs(ws:GetDescendants()) do
		if rawget(d, "_tags")[tag] then out[#out + 1] = d end
	end
	return out
end)

local RunService = services.RunService
rawset(RunService, "IsServer", function() return true end)
rawset(RunService, "IsClient", function() return false end)
rawset(RunService, "IsStudio", function() return true end)
rawset(RunService, "IsRunning", function() return true end)
for _, sig in ipairs({ "Heartbeat", "Stepped", "RenderStepped", "PreSimulation", "PostSimulation" }) do rawset(RunService, sig, Signal.new()) end
rawset(services.Debris, "AddItem", function() end)
rawset(services.Lighting, "GetSunDirection", function() return v3(0, 1, 0) end)
rawset(services.Players, "GetPlayers", function() return {} end)
rawset(services.Players, "PlayerAdded", Signal.new())
rawset(services.Players, "PlayerRemoving", Signal.new())
rawset(services.TweenService, "Create", function(_, inst, info, goal)
	return { Play = function() for k, v in pairs(goal) do inst[k] = v end end, Cancel = function() end, Completed = Signal.new() }
end)
rawset(services.HttpService, "GenerateGUID", function() return "00000000-0000-0000-0000-000000000000" end)

function methods.GetService(self, name)
	if name == "Workspace" or name == "workspace" then return ws end
	local s = services[name]
	if API then
		local info = API.classes[name]
		if not info or info.v ~= 1 then error("GetService: '" .. tostring(name) .. "' non e' un servizio valido", 2) end
	end
	if not s then error("servizio non emulato: " .. tostring(name), 2) end
	return s
end
rawset(game_, "GetService", methods.GetService)
rawset(game_, "Workspace", ws)
game = game_
workspace = ws
rawset(ws, "Terrain", terrain)
local cam = Instance.new("Camera")
cam.CFrame = CFrame.new(0, 10, 50)
rawset(ws, "CurrentCamera", cam)
rawset(ws, "GetServerTimeNow", function() return os.clock() end)
rawset(ws, "BulkMoveTo", function(_, parts, cfs)
	for i, p in ipairs(parts) do rawget(p, "_p").CFrame = cfs[i] end
end)
rawset(CollectionService, "GetInstanceAddedSignal", function() return Signal.new() end)

----------------------------------------------------------------------
-- task / os / varie
----------------------------------------------------------------------
task = {
	wait = function(t) return t or 0.03 end,
	spawn = function(f, ...) if type(f) == "function" then return f(...) end end,
	defer = function(f, ...) if type(f) == "function" then return f(...) end end,
	delay = function(_, f, ...) if type(f) == "function" then return f(...) end end,
}
wait = task.wait
spawn = task.spawn
function warn(...)
	local t = {}
	for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
	local msg = table.concat(t, " ")
	Shim.problems[#Shim.problems + 1] = "warn: " .. msg
	io.stderr:write("[warn] ", msg, "\n")
end
Shim.printed = {}

----------------------------------------------------------------------
-- require / albero di script da una cartella src/ (stile Rojo)
----------------------------------------------------------------------
local moduleCache = {}
local function readFile(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local s = f:read("a")
	f:close()
	return s
end

local function makeEnv(scriptObj)
	local env = setmetatable({ script = scriptObj }, { __index = _G })
	return env
end

local realRequire = function(obj)
	if type(obj) ~= "table" or rawget(obj, "_path") == nil then error("require: modulo non valido " .. tostring(obj)) end
	if moduleCache[obj] ~= nil then return moduleCache[obj] end
	local src = readFile(rawget(obj, "_path"))
	local chunk, err = load(src, "@" .. rawget(obj, "_path"), "t", makeEnv(obj))
	if not chunk then error(err) end
	local result = chunk()
	moduleCache[obj] = result
	return result
end
_G.require = realRequire

function Shim.mountFiles(root, list)
	-- list: percorsi relativi a root, es. "ServerScriptService/Server/MapBuilder.lua"
	for _, rel in ipairs(list) do
		local comps = {}
		for c in rel:gmatch("[^/]+") do comps[#comps + 1] = c end
		local parent = services[comps[1]]
		if parent then
			for i = 2, #comps - 1 do
				local nxt = parent:FindFirstChild(comps[i])
				if not nxt then
					nxt = Instance.new("Folder")
					nxt.Name = comps[i]
					nxt.Parent = parent
				end
				parent = nxt
			end
			local name = comps[#comps]
			local cls, base = "ModuleScript", name:gsub("%.lua$", "")
			if name:match("%.server%.lua$") then cls, base = "Script", name:gsub("%.server%.lua$", "") end
			if name:match("%.client%.lua$") then cls, base = "LocalScript", name:gsub("%.client%.lua$", "") end
			local o = Instance.new(cls)
			o.Name = base
			rawset(o, "_path", root .. "/" .. rel)
			o.Parent = parent
		end
	end
end

----------------------------------------------------------------------
-- esportazione JSON della scena
----------------------------------------------------------------------
local function jstr(s)
	return '"' .. tostring(s):gsub('[%c"\\]', function(c)
		if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" elseif c == "\n" then return "\\n" end
		return string.format("\\u%04x", c:byte())
	end) .. '"'
end
local function jnum(n)
	if n ~= n or n == math.huge or n == -math.huge then return "0" end
	if math.type(n) == "integer" then return tostring(n) end
	return string.format("%.5g", n)
end

local encode
local function encodeValue(v)
	local t = type(v)
	if t == "number" then return jnum(v) end
	if t == "boolean" then return tostring(v) end
	if t == "string" then return jstr(v) end
	if t == "nil" then return "null" end
	if t == "table" then
		local mt = getmetatable(v)
		if mt == V3 then return "[" .. jnum(v.X) .. "," .. jnum(v.Y) .. "," .. jnum(v.Z) .. "]" end
		if mt == C3 then return "[" .. jnum(v.R) .. "," .. jnum(v.G) .. "," .. jnum(v.B) .. "]" end
		if mt == CF then
			local c = { v.x, v.y, v.z, v.r00, v.r01, v.r02, v.r10, v.r11, v.r12, v.r20, v.r21, v.r22 }
			local p = {}
			for i = 1, 12 do p[i] = jnum(c[i]) end
			return "[" .. table.concat(p, ",") .. "]"
		end
		if mt == EnumItemMT then return jstr(v.Name) end
		if mt == UDim2 then return "[" .. jnum(v.X.Scale) .. "," .. jnum(v.X.Offset) .. "," .. jnum(v.Y.Scale) .. "," .. jnum(v.Y.Offset) .. "]" end
		if mt == NumberSequence or mt == ColorSequence then
			local p = {}
			for i, k in ipairs(v.Keypoints) do p[i] = "[" .. jnum(k.Time) .. "," .. encodeValue(k.Value) .. "]" end
			return "[" .. table.concat(p, ",") .. "]"
		end
		if mt == NumberRange then return "[" .. jnum(v.Min) .. "," .. jnum(v.Max) .. "]" end
		if mt == V2 then return "[" .. jnum(v.X) .. "," .. jnum(v.Y) .. "]" end
		return "null"
	end
	return "null"
end

local SKIP = { ClassName = true, Name = true, _children = true, _parent = true, _attrs = true, _tags = true, _path = true, _terrain = true }
local function encodeInstance(o)
	local parts = {}
	parts[#parts + 1] = '"c":' .. jstr(rawget(o, "ClassName"))
	parts[#parts + 1] = '"n":' .. jstr(rawget(o, "_p").Name)
	local props = {}
	local keys = {}
	for k, v in pairs(rawget(o, "_p")) do
		if type(k) == "string" and k ~= "Name" and not SKIP[k] and not (type(v) == "table" and getmetatable(v) == Signal) and type(v) ~= "function" then keys[#keys + 1] = k end
	end
	table.sort(keys)
	for _, k in ipairs(keys) do
		local v = rawget(o, "_p")[k]
		local enc = encodeValue(v)
		if enc ~= "null" then props[#props + 1] = jstr(k) .. ":" .. enc end
	end
	parts[#parts + 1] = '"p":{' .. table.concat(props, ",") .. "}"
	local at = rawget(o, "_attrs")
	local atl = {}
	for k, v in pairs(at) do atl[#atl + 1] = jstr(k) .. ":" .. encodeValue(v) end
	if #atl > 0 then table.sort(atl) parts[#parts + 1] = '"a":{' .. table.concat(atl, ",") .. "}" end
	local tg = rawget(o, "_tags")
	local tgl = {}
	for k in pairs(tg) do tgl[#tgl + 1] = jstr(k) end
	if #tgl > 0 then table.sort(tgl) parts[#parts + 1] = '"t":[' .. table.concat(tgl, ",") .. "]" end
	local kids = {}
	for _, c in ipairs(rawget(o, "_children")) do kids[#kids + 1] = encodeInstance(c) end
	if #kids > 0 then parts[#parts + 1] = '"k":[' .. table.concat(kids, ",") .. "]" end
	return "{" .. table.concat(parts, ",") .. "}"
end

function Shim.exportScene(path)
	local out = {}
	-- Lighting
	local L = services.Lighting
	out[#out + 1] = '"lighting":' .. encodeInstance(L)
	-- terreno
	local T = rawget(terrain, "_terrain")
	local ops = {}
	for _, op in ipairs(T.ops) do
		local p = {}
		for i = 2, #op do p[#p + 1] = encodeValue(op[i] ~= nil and (type(op[i]) == "table" and getmetatable(op[i]) == EnumItemMT and op[i] or op[i]) or nil) end
		ops[#ops + 1] = '{"op":' .. jstr(op[1]) .. ',"a":[' .. table.concat(p, ",") .. "]}"
	end
	local cols = {}
	for name, c in pairs(T.colors) do cols[#cols + 1] = jstr(name) .. ":" .. encodeValue(c) end
	table.sort(cols)
	local tprops = {}
	for k, v in pairs(rawget(terrain, "_p")) do
		if type(k) == "string" and k ~= "Name" and not SKIP[k] and type(v) ~= "function" and not (type(v) == "table" and getmetatable(v) == Signal) then tprops[#tprops + 1] = jstr(k) .. ":" .. encodeValue(v) end
	end
	local tkids = {}
	for _, c in ipairs(rawget(terrain, "_children")) do tkids[#tkids + 1] = encodeInstance(c) end
	out[#out + 1] = '"terrain":{"colors":{' .. table.concat(cols, ",") .. '},"props":{' .. table.concat(tprops, ",") .. '},"kids":[' .. table.concat(tkids, ",") .. '],"ops":[' .. table.concat(ops, ",") .. "]}"
	-- workspace (senza Terrain)
	local kids = {}
	for _, c in ipairs(rawget(ws, "_children")) do
		if c ~= terrain and c.ClassName ~= "Camera" then kids[#kids + 1] = encodeInstance(c) end
	end
	out[#out + 1] = '"workspace":[' .. table.concat(kids, ",") .. "]"
	local f = assert(io.open(path, "wb"))
	f:write("{" .. table.concat(out, ",") .. "}")
	f:close()
end

function Shim.count()
	local n, parts = 0, 0
	for _, d in ipairs(ws:GetDescendants()) do
		n = n + 1
		if PART_CLASSES[d.ClassName] then parts = parts + 1 end
	end
	return n, parts
end

_G.__SHIM = Shim
return Shim
