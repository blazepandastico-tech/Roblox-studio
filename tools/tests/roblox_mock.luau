--[[
	Roblox finto per le prove fuori da Studio (tools/test_world.py).
	Ricrea i tipi (Vector3, CFrame, Color3, UDim2...), gli Enum, le istanze e alcuni servizi.
	Ogni proprietà assegnata a un'istanza viene controllata con l'elenco ufficiale delle
	proprietà di Roblox (tools/tests/roblox_api.luau): nome, tipo e valori degli Enum.
	Un errore qui è un errore che in Roblox Studio farebbe saltare un pezzo di mappa.
]]

local SOURCES: { [string]: string } = SOURCES_TABLE
local API = ROBLOX_API

WARNINGS = {} :: { string }
ERRORS = {} :: { string }

local function fail(message: string)
	error(message, 3)
end

-- VECTOR3 -----------------------------------------------------------------------------------------
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
	local method = rawget(V3, key)
	if method == nil then
		fail("Vector3: membro inesistente '" .. tostring(key) .. "'")
	end
	return method
end
local function isV3(v)
	return getmetatable(v) == V3
end
V3.__add = function(a, b)
	if not isV3(a) or not isV3(b) then
		fail("Vector3: somma con un valore che non è un Vector3")
	end
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	if not isV3(a) or not isV3(b) then
		fail("Vector3: sottrazione con un valore che non è un Vector3")
	end
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
function V3.Abs(a)
	return v3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z))
end
function V3.Min(a, b)
	return v3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
end
function V3.Max(a, b)
	return v3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end
function V3.FuzzyEq(a, b, eps)
	return (a - b).Magnitude <= (eps or 1e-5)
end
Vector3 = {
	new = function(x, y, z)
		for _, c in { x or 0, y or 0, z or 0 } do
			if type(c) ~= "number" or c ~= c then
				fail("Vector3.new: componente non valida")
			end
		end
		return v3(x, y, z)
	end,
	zero = v3(),
	one = v3(1, 1, 1),
	xAxis = v3(1, 0, 0),
	yAxis = v3(0, 1, 0),
	zAxis = v3(0, 0, 1),
}

-- TIPI SEMPLICI -------------------------------------------------------------------------------------
local TypeMT: { [string]: any } = {}
local function simpleType(name: string, fields: { string })
	local mt = { __type = name }
	mt.__index = function(_self, key)
		fail(name .. ": membro inesistente '" .. tostring(key) .. "'")
	end
	TypeMT[name] = mt
	return function(...)
		local args = { ... }
		local obj = {}
		for i, f in fields do
			obj[f] = args[i]
		end
		return setmetatable(obj, mt)
	end
end

local newV2 = simpleType("Vector2", { "X", "Y" })
local V2MT = TypeMT.Vector2
V2MT.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X ^ 2 + self.Y ^ 2)
	elseif key == "Unit" then
		local m = math.sqrt(self.X ^ 2 + self.Y ^ 2)
		return newV2(self.X / m, self.Y / m)
	end
	fail("Vector2: membro inesistente '" .. tostring(key) .. "'")
end
V2MT.__add = function(a, b)
	return newV2(a.X + b.X, a.Y + b.Y)
end
V2MT.__sub = function(a, b)
	return newV2(a.X - b.X, a.Y - b.Y)
end
V2MT.__mul = function(a, b)
	if type(b) == "number" then
		return newV2(a.X * b, a.Y * b)
	end
	return newV2(a.X * b.X, a.Y * b.Y)
end
V2MT.__div = function(a, b)
	return newV2(a.X / b, a.Y / b)
end
Vector2 = { new = function(x, y)
	return newV2(x or 0, y or 0)
end, zero = newV2(0, 0) }

local newUDim = simpleType("UDim", { "Scale", "Offset" })
UDim = { new = function(s, o)
	return newUDim(s or 0, o or 0)
end }
local newUDim2 = simpleType("UDim2", { "X", "Y" })
UDim2 = {
	new = function(xs, xo, ys, yo)
		return newUDim2(newUDim(xs or 0, xo or 0), newUDim(ys or 0, yo or 0))
	end,
	fromScale = function(x, y)
		return newUDim2(newUDim(x or 0, 0), newUDim(y or 0, 0))
	end,
	fromOffset = function(x, y)
		return newUDim2(newUDim(0, x or 0), newUDim(0, y or 0))
	end,
}

local C3 = { __type = "Color3" }
C3.__index = function(self, key)
	if key == "Lerp" then
		return function(a, b, t)
			return setmetatable({ R = a.R + (b.R - a.R) * t, G = a.G + (b.G - a.G) * t, B = a.B + (b.B - a.B) * t }, C3)
		end
	elseif key == "ToHSV" then
		return function(c)
			return 0, 0, math.max(c.R, c.G, c.B)
		end
	end
	fail("Color3: membro inesistente '" .. tostring(key) .. "'")
end
local function c3(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3)
end
Color3 = {
	new = c3,
	fromRGB = function(r, g, b)
		if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
			fail("Color3.fromRGB: valori non numerici")
		end
		return c3(r / 255, g / 255, b / 255)
	end,
	fromHSV = function(_h, _s, v)
		return c3(v, v, v)
	end,
}

local newNR = simpleType("NumberRange", { "Min", "Max" })
NumberRange = { new = function(a, b)
	return newNR(a, b or a)
end }
local newNSK = simpleType("NumberSequenceKeypoint", { "Time", "Value", "Envelope" })
NumberSequenceKeypoint = { new = newNSK }
local newNS = simpleType("NumberSequence", { "Keypoints" })
NumberSequence = { new = function(a, b)
	if type(a) == "table" then
		return newNS(a)
	end
	return newNS({ newNSK(0, a), newNSK(1, b or a) })
end }
local newCSK = simpleType("ColorSequenceKeypoint", { "Time", "Value" })
ColorSequenceKeypoint = { new = newCSK }
local newCS = simpleType("ColorSequence", { "Keypoints" })
ColorSequence = { new = function(a, b)
	if type(a) == "table" and getmetatable(a) ~= C3 then
		return newCS(a)
	end
	return newCS({ newCSK(0, a), newCSK(1, b or a) })
end }
local newPP = simpleType("PhysicalProperties", { "Density", "Friction", "Elasticity" })
PhysicalProperties = { new = newPP }
local newFont = simpleType("Font", { "Family", "Weight", "Style" })
Font = { new = newFont, fromEnum = function(e)
	return newFont(e)
end }
local newRect = simpleType("Rect", { "Min", "Max" })
Rect = { new = newRect }
local newTweenInfo = simpleType("TweenInfo", { "Time" })
TweenInfo = { new = newTweenInfo }
local newBrick = simpleType("BrickColor", { "Name" })
BrickColor = { new = newBrick }

-- CFRAME ---------------------------------------------------------------------------------------------
local CF = { __type = "CFrame" }
local function cfraw(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	return setmetatable({ x = x, y = y, z = z, r00 = r00, r01 = r01, r02 = r02, r10 = r10, r11 = r11, r12 = r12, r20 = r20, r21 = r21, r22 = r22 }, CF)
end
local function isCF(v)
	return getmetatable(v) == CF
end
local function mulR(a, b)
	return a.r00 * b.r00 + a.r01 * b.r10 + a.r02 * b.r20, a.r00 * b.r01 + a.r01 * b.r11 + a.r02 * b.r21, a.r00 * b.r02 + a.r01 * b.r12 + a.r02 * b.r22,
		a.r10 * b.r00 + a.r11 * b.r10 + a.r12 * b.r20, a.r10 * b.r01 + a.r11 * b.r11 + a.r12 * b.r21, a.r10 * b.r02 + a.r11 * b.r12 + a.r12 * b.r22,
		a.r20 * b.r00 + a.r21 * b.r10 + a.r22 * b.r20, a.r20 * b.r01 + a.r21 * b.r11 + a.r22 * b.r21, a.r20 * b.r02 + a.r21 * b.r12 + a.r22 * b.r22
end
local function rotV(a, v)
	return v3(a.r00 * v.X + a.r01 * v.Y + a.r02 * v.Z, a.r10 * v.X + a.r11 * v.Y + a.r12 * v.Z, a.r20 * v.X + a.r21 * v.Y + a.r22 * v.Z)
end
local function rotTV(a, v)
	return v3(a.r00 * v.X + a.r10 * v.Y + a.r20 * v.Z, a.r01 * v.X + a.r11 * v.Y + a.r21 * v.Z, a.r02 * v.X + a.r12 * v.Y + a.r22 * v.Z)
end
local function checkNum(n, what)
	if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
		fail("CFrame: valore non valido in " .. what)
	end
end
local function inverse(a)
	local p = rotTV(a, v3(-a.x, -a.y, -a.z))
	return cfraw(p.X, p.Y, p.Z, a.r00, a.r10, a.r20, a.r01, a.r11, a.r21, a.r02, a.r12, a.r22)
end
CF.__mul = function(a, b)
	if not isCF(a) then
		fail("CFrame: moltiplicazione con un valore che non è un CFrame")
	end
	if isV3(b) then
		local r = rotV(a, b)
		return v3(r.X + a.x, r.Y + a.y, r.Z + a.z)
	end
	if not isCF(b) then
		fail("CFrame: si può moltiplicare solo per un CFrame o un Vector3")
	end
	local p = rotV(a, v3(b.x, b.y, b.z))
	return cfraw(p.X + a.x, p.Y + a.y, p.Z + a.z, mulR(a, b))
end
CF.__add = function(a, b)
	if not isV3(b) then
		fail("CFrame + : serve un Vector3")
	end
	return cfraw(a.x + b.X, a.y + b.Y, a.z + b.Z, a.r00, a.r01, a.r02, a.r10, a.r11, a.r12, a.r20, a.r21, a.r22)
end
CF.__sub = function(a, b)
	if not isV3(b) then
		fail("CFrame - : serve un Vector3")
	end
	return cfraw(a.x - b.X, a.y - b.Y, a.z - b.Z, a.r00, a.r01, a.r02, a.r10, a.r11, a.r12, a.r20, a.r21, a.r22)
end
CF.__eq = function(a, b)
	return a.x == b.x and a.y == b.y and a.z == b.z and a.r00 == b.r00 and a.r11 == b.r11 and a.r22 == b.r22 and a.r01 == b.r01
end
local CFMethods = {}
function CFMethods.Inverse(a)
	return inverse(a)
end
function CFMethods.ToWorldSpace(a, b)
	return a * b
end
function CFMethods.ToObjectSpace(a, b)
	return inverse(a) * b
end
function CFMethods.PointToWorldSpace(a, v)
	return a * v
end
function CFMethods.PointToObjectSpace(a, v)
	return inverse(a) * v
end
function CFMethods.VectorToWorldSpace(a, v)
	return rotV(a, v)
end
function CFMethods.VectorToObjectSpace(a, v)
	return rotTV(a, v)
end
function CFMethods.ToOrientation(a)
	local x = math.asin(math.clamp(-a.r12, -1, 1))
	return x, math.atan2(a.r02, a.r22), math.atan2(a.r10, a.r11)
end
function CFMethods.ToEulerAnglesYXZ(a)
	return CFMethods.ToOrientation(a)
end
function CFMethods.ToEulerAnglesXYZ(a)
	local y = math.asin(math.clamp(a.r02, -1, 1))
	return math.atan2(-a.r12, a.r22), y, math.atan2(-a.r01, a.r00)
end
function CFMethods.GetComponents(a)
	return a.x, a.y, a.z, a.r00, a.r01, a.r02, a.r10, a.r11, a.r12, a.r20, a.r21, a.r22
end
function CFMethods.Lerp(a, b, t)
	return cfraw(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t, a.r00, a.r01, a.r02, a.r10, a.r11, a.r12, a.r20, a.r21, a.r22)
end
function CFMethods.Orthonormalize(a)
	return a
end
CF.__index = function(a, key)
	if key == "Position" or key == "p" then
		return v3(a.x, a.y, a.z)
	elseif key == "X" then
		return a.x
	elseif key == "Y" then
		return a.y
	elseif key == "Z" then
		return a.z
	elseif key == "LookVector" then
		return v3(-a.r02, -a.r12, -a.r22)
	elseif key == "RightVector" or key == "XVector" then
		return v3(a.r00, a.r10, a.r20)
	elseif key == "UpVector" or key == "YVector" then
		return v3(a.r01, a.r11, a.r21)
	elseif key == "ZVector" then
		return v3(a.r02, a.r12, a.r22)
	elseif key == "Rotation" then
		return cfraw(0, 0, 0, a.r00, a.r01, a.r02, a.r10, a.r11, a.r12, a.r20, a.r21, a.r22)
	end
	local m = CFMethods[key]
	if not m then
		fail("CFrame: membro inesistente '" .. tostring(key) .. "'")
	end
	return m
end
local IDENTITY = cfraw(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
local function rx(t)
	local c, s = math.cos(t), math.sin(t)
	return cfraw(0, 0, 0, 1, 0, 0, 0, c, -s, 0, s, c)
end
local function ry(t)
	local c, s = math.cos(t), math.sin(t)
	return cfraw(0, 0, 0, c, 0, s, 0, 1, 0, -s, 0, c)
end
local function rz(t)
	local c, s = math.cos(t), math.sin(t)
	return cfraw(0, 0, 0, c, -s, 0, s, c, 0, 0, 0, 1)
end
local function fromMatrix(pos, vx, vy, vz)
	if not isV3(pos) or not isV3(vx) or not isV3(vy) then
		fail("CFrame.fromMatrix: argomenti non validi")
	end
	vz = vz or vx:Cross(vy).Unit
	return cfraw(pos.X, pos.Y, pos.Z, vx.X, vy.X, vz.X, vx.Y, vy.Y, vz.Y, vx.Z, vy.Z, vz.Z)
end
local function lookAt(at, target, up)
	if not isV3(at) or not isV3(target) then
		fail("CFrame.lookAt: servono due Vector3")
	end
	local forward = (target - at).Unit
	if forward.Magnitude < 0.5 then
		return cfraw(at.X, at.Y, at.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	end
	local u = up or v3(0, 1, 0)
	local right = forward:Cross(u)
	if right.Magnitude < 1e-4 then
		right = forward:Cross(v3(0, 0, 1))
	end
	right = right.Unit
	local upv = right:Cross(forward)
	return fromMatrix(at, right, upv, -forward)
end
CFrame = {
	identity = IDENTITY,
	new = function(...)
		local n = select("#", ...)
		local a = { ... }
		if n == 0 then
			return IDENTITY
		elseif n == 1 then
			if not isV3(a[1]) then
				fail("CFrame.new: serve un Vector3")
			end
			return cfraw(a[1].X, a[1].Y, a[1].Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
		elseif n == 2 then
			return lookAt(a[1], a[2])
		elseif n == 3 then
			for i = 1, 3 do
				checkNum(a[i], "CFrame.new")
			end
			return cfraw(a[1], a[2], a[3], 1, 0, 0, 0, 1, 0, 0, 0, 1)
		elseif n == 12 then
			return cfraw(table.unpack(a))
		end
		fail("CFrame.new: numero di argomenti non gestito " .. n)
		return IDENTITY
	end,
	Angles = function(x, y, z)
		checkNum(x or 0, "Angles")
		checkNum(y or 0, "Angles")
		checkNum(z or 0, "Angles")
		return rx(x or 0) * ry(y or 0) * rz(z or 0)
	end,
	fromEulerAnglesXYZ = function(x, y, z)
		return rx(x or 0) * ry(y or 0) * rz(z or 0)
	end,
	fromOrientation = function(x, y, z)
		return ry(y or 0) * rx(x or 0) * rz(z or 0)
	end,
	fromEulerAnglesYXZ = function(x, y, z)
		return ry(y or 0) * rx(x or 0) * rz(z or 0)
	end,
	lookAt = lookAt,
	fromMatrix = fromMatrix,
	fromAxisAngle = function(axis, angle)
		local u = axis.Unit
		local c, s = math.cos(angle), math.sin(angle)
		local t = 1 - c
		return cfraw(0, 0, 0, t * u.X * u.X + c, t * u.X * u.Y - s * u.Z, t * u.X * u.Z + s * u.Y, t * u.X * u.Y + s * u.Z, t * u.Y * u.Y + c, t * u.Y * u.Z - s * u.X, t * u.X * u.Z - s * u.Y, t * u.Y * u.Z + s * u.X, t * u.Z * u.Z + c)
	end,
}

-- RANDOM -------------------------------------------------------------------------------------------
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
Random = { new = function(seed: number?)
	return setmetatable({ State = math.floor(seed or 12345) % 2147483648 }, RandomMT)
end }

-- ENUM -----------------------------------------------------------------------------------------------
local EnumItemMT = { __type = "EnumItem" }
EnumItemMT.__index = function(_self, key)
	fail("EnumItem: membro inesistente " .. tostring(key))
end
EnumItemMT.__tostring = function(self)
	return "Enum." .. self.EnumType .. "." .. self.Name
end
local enumCache = {}
Enum = setmetatable({}, {
	__index = function(_, typeName)
		local items = API.Enums[typeName]
		if not items then
			fail("Enum." .. tostring(typeName) .. " non esiste (o manca in roblox_api.luau)")
		end
		if not enumCache[typeName] then
			local list = {}
			for i, name in items do
				list[name] = setmetatable({ EnumType = typeName, Name = name, Value = i - 1 }, EnumItemMT)
			end
			enumCache[typeName] = setmetatable({}, {
				__index = function(_, itemName)
					local item = list[itemName]
					if not item then
						fail(("Enum.%s.%s non esiste"):format(typeName, tostring(itemName)))
					end
					return item
				end,
			})
		end
		return enumCache[typeName]
	end,
})

-- SEGNALI -------------------------------------------------------------------------------------------
local SignalMT = {}
SignalMT.__index = SignalMT
local function newSignal()
	return setmetatable({ Handlers = {} }, SignalMT)
end
function SignalMT.Connect(self, fn)
	table.insert(self.Handlers, fn)
	return { Disconnect = function() end, Connected = true }
end
SignalMT.Once = SignalMT.Connect
function SignalMT.Wait(_self)
	return nil
end
function SignalMT.Fire(self, ...)
	for _, fn in self.Handlers do
		fn(...)
	end
end

-- ISTANZE ----------------------------------------------------------------------------------------------
local InstanceMT = {}
local allInstances = 0

local function classInfo(name: string)
	return API.Classes[name]
end

local function isA(className: string, target: string): boolean
	local name: string? = className
	while name do
		if name == target then
			return true
		end
		local info = classInfo(name)
		name = info and info.S
	end
	return target == "Instance"
end

local function propType(className: string, key: string): string?
	local name: string? = className
	while name do
		local info = classInfo(name)
		if not info then
			return nil
		end
		local t = info.P[key]
		if t then
			return t
		end
		name = info.S
	end
	return nil
end

local DATATYPES = { Vector3 = true, CFrame = true, Color3 = true, UDim2 = true, UDim = true, Vector2 = true, NumberSequence = true, ColorSequence = true, NumberRange = true, PhysicalProperties = true, Rect = true, Font = true, BrickColor = true }

local nativeTypeof = typeof
local function typeOf(value: any): string
	local mt = getmetatable(value)
	if mt == V3 then
		return "Vector3"
	elseif mt == CF then
		return "CFrame"
	elseif mt == C3 then
		return "Color3"
	elseif mt == EnumItemMT then
		return "EnumItem"
	elseif mt == InstanceMT then
		return "Instance"
	elseif type(mt) == "table" and mt.__type then
		return mt.__type
	end
	return nativeTypeof(value)
end
typeof = typeOf

local function validate(className: string, key: string, value: any)
	local t = propType(className, key)
	if not t then
		fail(("%s.%s: proprietà inesistente"):format(className, key))
	end
	local optional = t:sub(-1) == "?"
	local base = if optional then t:sub(1, -2) else t
	if value == nil then
		return
	end
	local actual = typeOf(value)
	if base == "number" then
		if actual ~= "number" or value ~= value then
			fail(("%s.%s: serve un numero, non %s"):format(className, key, actual))
		end
	elseif base == "boolean" or base == "string" then
		if actual ~= base then
			fail(("%s.%s: serve %s, non %s"):format(className, key, base, actual))
		end
	elseif base == "Content" then
		if actual ~= "string" then
			fail(("%s.%s: serve un testo"):format(className, key))
		end
	elseif DATATYPES[base] then
		if actual ~= base then
			fail(("%s.%s: serve %s, non %s"):format(className, key, base, actual))
		end
	elseif base:sub(1, 4) == "Enum" and API.Enums[base:sub(5)] ~= nil then
		if actual ~= "EnumItem" or value.EnumType ~= base:sub(5) then
			fail(("%s.%s: serve Enum.%s, non %s"):format(className, key, base:sub(5), tostring(value)))
		end
	elseif classInfo(base) then
		if actual ~= "Instance" or not isA(rawget(value, "__class"), base) then
			fail(("%s.%s: serve un'istanza %s"):format(className, key, base))
		end
	end
end

local function defaultFor(t: string): any
	local base = if t:sub(-1) == "?" then t:sub(1, -2) else t
	if base == "number" then
		return 0
	elseif base == "boolean" then
		return false
	elseif base == "string" or base == "Content" then
		return ""
	elseif base == "Vector3" then
		return v3()
	elseif base == "CFrame" then
		return IDENTITY
	elseif base == "Color3" then
		return c3(0.6, 0.6, 0.6)
	elseif base == "Vector2" then
		return newV2(0, 0)
	end
	return nil
end

local Methods = {}

local function newInstance(className: string, parent: any?)
	if not classInfo(className) then
		fail("Instance.new: classe sconosciuta '" .. tostring(className) .. "'")
	end
	allInstances += 1
	local self = setmetatable({ __class = className, __props = { Name = className }, __children = {}, __attrs = {}, __signals = {}, __parent = nil }, InstanceMT)
	if parent then
		self.Parent = parent
	end
	return self
end

InstanceMT.__index = function(self, key)
	local method = Methods[key]
	if method then
		return method
	end
	if key == "Parent" then
		return rawget(self, "__parent")
	elseif key == "ClassName" then
		return rawget(self, "__class")
	end
	local props = rawget(self, "__props")
	local className = rawget(self, "__class")
	if key == "Position" and isA(className, "BasePart") then
		local cf = props.CFrame or IDENTITY
		return cf.Position
	end
	local value = props[key]
	if value ~= nil then
		return value
	end
	local t = propType(className, key)
	if t then
		if t:find("RBXScriptSignal", 1, true) then
			local signals = rawget(self, "__signals")
			signals[key] = signals[key] or newSignal()
			return signals[key]
		end
		if key == "Size" and isA(className, "BasePart") then
			return v3(4, 1, 2)
		end
		local default = defaultFor(t)
		if default ~= nil then
			return default
		end
		-- proprietà che puntano a un figlio (es. workspace.Terrain)
		for _, child in rawget(self, "__children") do
			if child.Name == key then
				return child
			end
		end
		return nil
	end
	for _, child in rawget(self, "__children") do
		if child.Name == key then
			return child
		end
	end
	fail(("%s: '%s' non è una proprietà né un figlio"):format(className, tostring(key)))
	return nil
end

InstanceMT.__newindex = function(self, key, value)
	local className = rawget(self, "__class")
	if key == "Parent" then
		local old = rawget(self, "__parent")
		if old then
			local list = rawget(old, "__children")
			local i = table.find(list, self)
			if i then
				table.remove(list, i)
			end
		end
		rawset(self, "__parent", value)
		if value then
			if getmetatable(value) ~= InstanceMT then
				fail(className .. ".Parent: non è un'istanza")
			end
			table.insert(rawget(value, "__children"), self)
		end
		return
	end
	if key == "Position" and isA(className, "BasePart") then
		local props = rawget(self, "__props")
		local cf = props.CFrame or IDENTITY
		props.CFrame = cf.Rotation + value
		return
	end
	validate(className, key, value)
	rawget(self, "__props")[key] = value
end
InstanceMT.__tostring = function(self)
	return rawget(self, "__props").Name
end

function Methods.IsA(self, name)
	return isA(rawget(self, "__class"), name)
end
function Methods.GetChildren(self)
	return table.clone(rawget(self, "__children"))
end
function Methods.GetDescendants(self)
	local out = {}
	local function walk(node)
		for _, c in rawget(node, "__children") do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function Methods.FindFirstChild(self, name, recursive)
	for _, c in rawget(self, "__children") do
		if c.Name == name then
			return c
		end
	end
	if recursive then
		for _, c in rawget(self, "__children") do
			local found = c:FindFirstChild(name, true)
			if found then
				return found
			end
		end
	end
	local special = rawget(self, "__special")
	return special and special[name] or nil
end
function Methods.WaitForChild(self, name)
	local found = Methods.FindFirstChild(self, name)
	if not found then
		fail(rawget(self, "__props").Name .. ":WaitForChild('" .. name .. "') resterebbe in attesa per sempre")
	end
	return found
end
function Methods.FindFirstChildOfClass(self, className)
	for _, c in rawget(self, "__children") do
		if rawget(c, "__class") == className then
			return c
		end
	end
	return nil
end
function Methods.FindFirstChildWhichIsA(self, className)
	for _, c in rawget(self, "__children") do
		if c:IsA(className) then
			return c
		end
	end
	return nil
end
function Methods.FindFirstAncestorOfClass(self, className)
	local p = rawget(self, "__parent")
	while p do
		if rawget(p, "__class") == className then
			return p
		end
		p = rawget(p, "__parent")
	end
	return nil
end
function Methods.FindFirstAncestorWhichIsA(self, className)
	local p = rawget(self, "__parent")
	while p do
		if p:IsA(className) then
			return p
		end
		p = rawget(p, "__parent")
	end
	return nil
end
function Methods.IsDescendantOf(self, other)
	local p = rawget(self, "__parent")
	while p do
		if p == other then
			return true
		end
		p = rawget(p, "__parent")
	end
	return false
end
function Methods.Destroy(self)
	self.Parent = nil
end
function Methods.ClearAllChildren(self)
	for _, c in Methods.GetChildren(self) do
		c.Parent = nil
	end
end
function Methods.Clone(self)
	local copy = newInstance(rawget(self, "__class"))
	for k, v in rawget(self, "__props") do
		rawget(copy, "__props")[k] = v
	end
	for _, c in rawget(self, "__children") do
		c:Clone().Parent = copy
	end
	return copy
end
function Methods.SetAttribute(self, name, value)
	if type(name) ~= "string" then
		fail("SetAttribute: il nome deve essere un testo")
	end
	local t = typeOf(value)
	if value ~= nil and t ~= "number" and t ~= "string" and t ~= "boolean" and t ~= "Vector3" and t ~= "Color3" and t ~= "CFrame" and t ~= "UDim2" and t ~= "Vector2" and t ~= "NumberRange" then
		fail(("SetAttribute('%s'): tipo %s non salvabile come attributo"):format(name, t))
	end
	rawget(self, "__attrs")[name] = value
end
function Methods.GetAttribute(self, name)
	return rawget(self, "__attrs")[name]
end
function Methods.GetAttributes(self)
	return table.clone(rawget(self, "__attrs"))
end
function Methods.GetPropertyChangedSignal(_self, _name)
	return newSignal()
end
function Methods.GetAttributeChangedSignal(_self, _name)
	return newSignal()
end
local function partsOf(self)
	local list = {}
	if self:IsA("BasePart") then
		table.insert(list, self)
	end
	for _, d in Methods.GetDescendants(self) do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end
function Methods.GetPivot(self)
	if self:IsA("BasePart") then
		return self.CFrame
	end
	local primary = rawget(self, "__props").PrimaryPart
	if primary then
		return primary.CFrame
	end
	local first = partsOf(self)[1]
	return if first then first.CFrame else IDENTITY
end
function Methods.PivotTo(self, cf)
	if not isCF(cf) then
		fail("PivotTo: serve un CFrame")
	end
	local offset = cf * inverse(Methods.GetPivot(self))
	for _, p in partsOf(self) do
		rawget(p, "__props").CFrame = offset * p.CFrame
	end
end
function Methods.GetScale(_self)
	return 1
end
function Methods.ScaleTo(_self, _s) end
function Methods.SetNetworkOwner(_self, _player) end
function Methods.GetMass(_self)
	return 1
end
function Methods.Sit(self, humanoid)
	if not self:IsA("Seat") then
		fail("Sit: non è un Seat")
	end
	rawget(self, "__props").Occupant = humanoid
end
-- metodi che nella prova non devono fare nulla
local function noop() end
for _, name in { "Emit", "Clear", "AddItem", "FireClient", "FireAllClients", "FireServer", "Play", "Stop", "Pause", "Resume", "ApplyImpulse", "BreakJoints", "MoveTo", "ChangeState", "TakeDamage", "LoadCharacter", "Kick" } do
	Methods[name] = noop
end
function Methods.InvokeServer(_self)
	return nil
end
function Methods.GetState(_self)
	return Enum.HumanoidStateType.Running
end
-- le prove possono aggiungere giocatori finti a MOCK_PLAYERS (Players:GetPlayers li restituisce)
MOCK_PLAYERS = {}
function Methods.GetPlayers(_self)
	return table.clone(MOCK_PLAYERS)
end
function Methods.GetPlayerFromCharacter(_self, model)
	for _, p in MOCK_PLAYERS do
		if p.Character == model then
			return p
		end
	end
	return nil
end
function Methods.GetPlayerByUserId(_self, userId)
	for _, p in MOCK_PLAYERS do
		if p.UserId == userId then
			return p
		end
	end
	return nil
end
function Methods.RequestStreamAroundAsync(_self) end
-- terreno
local function checkMaterial(m)
	if typeOf(m) ~= "EnumItem" or m.EnumType ~= "Material" then
		fail("Terreno: serve un Enum.Material")
	end
end
function Methods.FillBlock(_self, cf, size, material)
	if not isCF(cf) or not isV3(size) then
		fail("Terrain:FillBlock(CFrame, Vector3, Material)")
	end
	checkMaterial(material)
end
function Methods.FillBall(_self, center, radius, material)
	if not isV3(center) or type(radius) ~= "number" then
		fail("Terrain:FillBall(Vector3, number, Material)")
	end
	checkMaterial(material)
end
function Methods.FillCylinder(_self, cf, height, radius, material)
	if not isCF(cf) or type(height) ~= "number" or type(radius) ~= "number" then
		fail("Terrain:FillCylinder(CFrame, number, number, Material)")
	end
	checkMaterial(material)
end
function Methods.FillWedge(_self, cf, size, material)
	if not isCF(cf) or not isV3(size) then
		fail("Terrain:FillWedge(CFrame, Vector3, Material)")
	end
	checkMaterial(material)
end
function Methods.SetMaterialColor(_self, material, color)
	checkMaterial(material)
	if typeOf(color) ~= "Color3" then
		fail("Terrain:SetMaterialColor: serve un Color3")
	end
end
-- mondo: un raggio verso il basso trova il terreno a quota 8 (o il fondo delle grotte)
function Methods.Raycast(self, origin, direction, _params)
	if not isV3(origin) or not isV3(direction) then
		fail("Raycast(Vector3, Vector3)")
	end
	local terrain = Methods.FindFirstChild(self, "Terrain")
	if direction.Y < 0 then
		local floor = if origin.Y < -100 then origin.Y - 45 else 8
		if origin.Y + direction.Y <= floor and origin.Y >= floor then
			return { Position = v3(origin.X, floor, origin.Z), Instance = terrain, Normal = v3(0, 1, 0), Material = Enum.Material.Grass, Distance = origin.Y - floor }
		end
	end
	return nil
end
function Methods.GetPartBoundsInRadius(_self)
	return {}
end
function Methods.GetPartBoundsInBox(_self)
	return {}
end
function Methods.GetServerTimeNow(_self)
	return os.clock()
end

Instance = { new = function(className, parent)
	return newInstance(className, parent)
end }
RaycastParams = { new = function()
	return { FilterType = nil, FilterDescendantsInstances = {}, IgnoreWater = false }
end }
OverlapParams = RaycastParams

-- ALBERO DEGLI SCRIPT E require ----------------------------------------------------------------------
local NodeMT = {}
local function node(path: string, name: string, parent: any)
	return setmetatable({ __path = path, Name = name, Parent = parent }, NodeMT)
end
NodeMT.__index = function(self, key)
	if key == "WaitForChild" or key == "FindFirstChild" then
		return function(this, name)
			return this[name]
		end
	end
	local path = rawget(self, "__path")
	return node(path .. "/" .. key, key, self)
end
local cache: { [string]: any } = {}
local function nodeFor(path: string)
	local first = path:match("^[^/]+")
	local current = node(first, first, nil)
	for part in path:gmatch("[^/]+") do
		if part ~= first then
			current = current[part]
		end
	end
	return current
end
require = function(target: any)
	local path = type(target) == "table" and rawget(target, "__path")
	if type(path) ~= "string" then
		fail("require: argomento non valido")
	end
	if cache[path] ~= nil then
		return cache[path]
	end
	local source = SOURCES[path]
	if not source then
		fail("require: modulo inesistente '" .. path .. "'")
	end
	local chunk, err = loadstring("local script = ...\n" .. source, "=" .. path)
	assert(chunk, err)
	local result = chunk(nodeFor(path))
	cache[path] = result
	return result
end
SHARED = node("Shared", "Shared", nil)
SERVER = node("Server", "Server", nil)
CLIENT = node("Client", "Client", nil)

-- GIOCO E SERVIZI -------------------------------------------------------------------------------------
workspace = newInstance("Workspace")
workspace.Name = "Workspace"
local terrain = newInstance("Terrain")
terrain.Name = "Terrain"
terrain.Parent = workspace
local services = { Workspace = workspace }
local tags: { [string]: { any } } = {}
local function service(name: string)
	if services[name] then
		return services[name]
	end
	local s = newInstance(name)
	s.Name = name
	services[name] = s
	return s
end
local replicated = service("ReplicatedStorage")
rawset(replicated, "__special", { Shared = SHARED })
local collection = service("CollectionService")
rawset(collection, "AddTag", function(_self, inst, tag)
	tags[tag] = tags[tag] or {}
	if not table.find(tags[tag], inst) then
		table.insert(tags[tag], inst)
	end
end)
rawset(collection, "RemoveTag", function(_self, inst, tag)
	local list = tags[tag]
	local i = list and table.find(list, inst)
	if i then
		table.remove(list, i)
	end
end)
rawset(collection, "HasTag", function(_self, inst, tag)
	return tags[tag] ~= nil and table.find(tags[tag], inst) ~= nil
end)
rawset(collection, "GetTagged", function(_self, tag)
	local out = {}
	for _, inst in tags[tag] or {} do
		if inst:IsDescendantOf(workspace) then
			table.insert(out, inst)
		end
	end
	return out
end)
rawset(collection, "GetInstanceAddedSignal", function()
	return newSignal()
end)
rawset(collection, "GetInstanceRemovedSignal", function()
	return newSignal()
end)
local http = service("HttpService")
rawset(http, "JSONEncode", function(_self, _v)
	return "[]"
end)
rawset(http, "JSONDecode", function(_self, _v)
	return {}
end)
local physics = service("PhysicsService")
rawset(physics, "RegisterCollisionGroup", function() end)
rawset(physics, "CollisionGroupSetCollidable", function() end)
local run = service("RunService")
rawset(run, "IsRunning", function()
	return false
end)
rawset(run, "IsStudio", function()
	return true
end)
rawset(run, "IsServer", function()
	return true
end)
rawset(run, "IsClient", function()
	return false
end)
service("Players")
local tween = service("TweenService")
rawset(tween, "Create", function(_self, inst, _info, goals)
	if getmetatable(inst) ~= InstanceMT then
		fail("TweenService:Create: serve un'istanza")
	end
	for key, value in goals do
		validate(rawget(inst, "__class"), key, value)
	end
	return { Play = function() end, Cancel = function() end, Pause = function() end, Completed = newSignal() }
end)
local starterGui = service("StarterGui")
rawset(starterGui, "SetCoreGuiEnabled", function() end)
rawset(starterGui, "SetCore", function() end)
game = setmetatable({}, {
	__index = function(_, key)
		if key == "GetService" then
			return function(_self, name)
				return service(name)
			end
		elseif key == "Workspace" then
			return workspace
		end
		fail("game." .. tostring(key) .. " non simulato")
	end,
})

-- i cicli infiniti dei servizi (task.spawn) non vengono eseguiti: la prova controlla solo la costruzione
SPAWNED = 0
-- le prove possono intercettare task.delay (MOCK_HOOKS.Delay) per far girare le azioni in ritardo
MOCK_HOOKS = {}
task = {
	wait = function()
		return 0
	end,
	spawn = function()
		SPAWNED += 1
	end,
	defer = function()
		SPAWNED += 1
	end,
	delay = function(t, fn, ...)
		local hook = MOCK_HOOKS.Delay
		if hook then
			hook(t, fn, ...)
		end
	end,
	cancel = function() end,
}
wait = task.wait
warn = function(...)
	local parts = {}
	for i = 1, select("#", ...) do
		table.insert(parts, tostring((select(i, ...))))
	end
	table.insert(WARNINGS, table.concat(parts, " "))
end
local nativePrint = print
QUIET = true
print = function(...)
	if not QUIET then
		nativePrint(...)
	end
end
LOG = nativePrint

function MOCK_TAGGED(tag: string)
	return collection:GetTagged(tag)
end
function MOCK_INSTANCES(): number
	return allInstances
end
function MOCK_NEW_SIGNAL()
	return newSignal()
end
