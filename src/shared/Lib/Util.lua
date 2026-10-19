--[[
	Util
	Funzioni di supporto condivise tra server e client.
]]

local Util = {}

-- Numeri -------------------------------------------------------------------

-- 1234567 -> "1.234.567" (separatore delle migliaia all'italiana)
function Util.FormatNumber(n: number): string
	local rounded = math.floor(n + 0.5)
	local negative = rounded < 0
	local digits = string.format("%d", math.abs(rounded))
	local grouped = (digits:reverse():gsub("(%d%d%d)", "%1.")):reverse()
	if grouped:sub(1, 1) == "." then
		grouped = grouped:sub(2)
	end
	return (if negative then "-" else "") .. grouped
end

-- 1500 -> "1,5K", 2300000 -> "2,3M"
function Util.Abbreviate(n: number): string
	local abs = math.abs(n)
	local text
	if abs >= 1e9 then
		text = string.format("%.2fB", n / 1e9)
	elseif abs >= 1e6 then
		text = string.format("%.2fM", n / 1e6)
	elseif abs >= 1e4 then
		text = string.format("%.1fK", n / 1e3)
	else
		return Util.FormatNumber(n)
	end
	text = text:gsub("%.?0+([KMB])$", "%1")
	return (text:gsub("%.", ","))
end

-- 125 -> "2:05", 3720 -> "1h 02m"
function Util.FormatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Util.Round(n: number, decimals: number?): number
	local m = 10 ^ (decimals or 0)
	return math.floor(n * m + 0.5) / m
end

function Util.Percent(fraction: number): string
	return string.format("%d%%", math.floor(fraction * 100 + 0.5))
end

function Util.Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Curve di animazione (t da 0 a 1) ------------------------------------------

local Easing = {}
function Easing.Linear(t)
	return t
end
function Easing.QuadIn(t)
	return t * t
end
function Easing.QuadOut(t)
	return 1 - (1 - t) * (1 - t)
end
function Easing.QuadInOut(t)
	if t < 0.5 then
		return 2 * t * t
	end
	return 1 - (-2 * t + 2) ^ 2 / 2
end
function Easing.CubicOut(t)
	return 1 - (1 - t) ^ 3
end
function Easing.CubicIn(t)
	return t * t * t
end
function Easing.SineInOut(t)
	return -(math.cos(math.pi * t) - 1) / 2
end
function Easing.ExpoOut(t)
	if t >= 1 then
		return 1
	end
	return 1 - 2 ^ (-10 * t)
end
function Easing.BackOut(t)
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end
function Easing.BackIn(t)
	local c1 = 1.70158
	local c3 = c1 + 1
	return c3 * t * t * t - c1 * t * t
end
function Easing.ElasticOut(t)
	if t <= 0 or t >= 1 then
		return t
	end
	return 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * (2 * math.pi) / 3) + 1
end
Util.Easing = Easing

function Util.Ease(t: number, style: string?): number
	local fn = Easing[style or "Linear"] or Easing.Linear
	return fn(math.clamp(t, 0, 1))
end

-- Tabelle --------------------------------------------------------------------

function Util.DeepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[Util.DeepCopy(k)] = Util.DeepCopy(v)
	end
	return copy :: any
end

local function isArray(t): boolean
	return type(t) == "table" and #t > 0
end

-- Aggiunge a `data` le chiavi mancanti prese da `template` (per i salvataggi
-- creati con versioni precedenti del gioco).
function Util.Reconcile(data: { [any]: any }, template: { [any]: any })
	for key, value in template do
		if data[key] == nil then
			data[key] = Util.DeepCopy(value)
		elseif type(value) == "table" and type(data[key]) == "table" and not isArray(value) then
			Util.Reconcile(data[key], value)
		end
	end
	return data
end

function Util.Count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

function Util.Keys(t: { [any]: any }): { any }
	local keys = {}
	for k in t do
		table.insert(keys, k)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return keys
end

function Util.Shuffle(list: { any }, rng: Random?)
	local random = rng or Random.new()
	for i = #list, 2, -1 do
		local j = random:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- Sceglie un elemento in base al campo Weight (lista di tabelle).
function Util.WeightedPick(list: { any }, rng: Random?): any
	local random = rng or Random.new()
	local total = 0
	for _, entry in list do
		total += entry.Weight or 0
	end
	if total <= 0 then
		return nil
	end
	local roll = random:NextNumber() * total
	for _, entry in list do
		roll -= entry.Weight or 0
		if roll <= 0 then
			return entry
		end
	end
	return list[#list]
end

-- Geometria -------------------------------------------------------------------
-- Convenzione della mappa: 0° = Nord (-Z), 90° = Est (+X), 180° = Sud (+Z), 270° = Ovest (-X)

function Util.Polar(angleDeg: number, radius: number, y: number?): Vector3
	local a = math.rad(angleDeg)
	return Vector3.new(math.sin(a) * radius, y or 0, -math.cos(a) * radius)
end

function Util.AngleOf(v: Vector3): number
	local deg = math.deg(math.atan2(v.X, -v.Z))
	return (deg + 360) % 360
end

function Util.Flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Util.FlatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

function Util.SafeUnit(v: Vector3, fallback: Vector3?): Vector3
	if v.Magnitude < 1e-4 then
		return fallback or Vector3.new(0, 0, -1)
	end
	return v.Unit
end

-- Istanze ------------------------------------------------------------------------

function Util.Create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Util.Weld(part0: BasePart, part1: BasePart): WeldConstraint
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.Parent = part1
	return weld
end

function Util.GetRoot(character: Model?): BasePart?
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Util.GetHumanoid(character: Model?): Humanoid?
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

function Util.IsAlive(character: Model?): boolean
	local humanoid = Util.GetHumanoid(character)
	return humanoid ~= nil and humanoid.Health > 0
end

-- Ritorna il primo antenato (o se stesso) che possiede l'attributo indicato.
function Util.FindAncestorWithAttribute(instance: Instance?, attribute: string): Instance?
	local current = instance
	while current and current ~= game do
		if current:GetAttribute(attribute) ~= nil then
			return current
		end
		current = current.Parent
	end
	return nil
end

return Util
