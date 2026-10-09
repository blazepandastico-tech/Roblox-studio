-- Esporta la mappa costruita nello shim (workspace.World + Terrain + Lighting) in un formato a righe che il convertitore Rust (rbxbake)
-- trasforma in rbxlx con l'encoder ufficiale. Una riga per record, campi separati da spazio; le stringhe sono codificate con %XX
-- (la stringa vuota e' "~"):
--   I <id> <genitore> <classe> <nome>          istanza (genitore 0 = radice: vedi S / U)
--   P <id> <proprieta'> <tipo> <dati...>       proprieta'   (b n s e v3 v2 u2 cf c3 nr ns cs pp r)
--   A <id> <chiave> <tipo> <dati...>           attributo    (s n b v3 c3)
--   T <id> <tag>                               tag di CollectionService
--   S <servizio> <id>                          il nodo <id> E' il servizio (le sue proprieta' e i suoi figli si fondono con quelli del servizio)
--   U <id> <servizio>                          il nodo <id> e' un figlio diretto del servizio
local M = {}

local API = rawget(_G, "__SHIM").API

local function enc(s)
	s = tostring(s)
	if s == "" then return "~" end
	return (s:gsub("[^%w%._%-]", function(c) return string.format("%%%02X", c:byte()) end))
end
local function num(x)
	if x ~= x then x = 0 end
	if x == math.huge then x = 3.4e38 elseif x == -math.huge then x = -3.4e38 end
	if x == math.floor(x) and math.abs(x) < 1e15 then return string.format("%d", x) end
	return string.format("%.9g", x)
end

local function propCode(cls, name)
	local c = cls
	while c and API.classes[c] do
		local v = API.classes[c].p[name]
		if v ~= nil then return v end
		c = API.classes[c].s
		if c == "<<<ROOT>>>" then break end
	end
	return nil
end

local function isA(cls, base)
	local c = cls
	while c and API.classes[c] do
		if c == base then return true end
		c = API.classes[c].s
		if c == "<<<ROOT>>>" then break end
	end
	return false
end

local function valueRecord(v, ids)
	local t = typeof(v)
	if t == "boolean" then return "b " .. (v and "1" or "0")
	elseif t == "number" then return "n " .. num(v)
	elseif t == "string" then return "s " .. enc(v)
	elseif t == "EnumItem" then
		local val = API.enums[v.EnumType] and API.enums[v.EnumType][v.Name]
		assert(val ~= nil, "valore enum sconosciuto " .. tostring(v))
		return "e " .. v.EnumType .. " " .. num(val)
	elseif t == "Vector3" then return string.format("v3 %s %s %s", num(v.X), num(v.Y), num(v.Z))
	elseif t == "Vector2" then return string.format("v2 %s %s", num(v.X), num(v.Y))
	elseif t == "UDim2" then return string.format("u2 %s %s %s %s", num(v.X.Scale), num(v.X.Offset), num(v.Y.Scale), num(v.Y.Offset))
	elseif t == "CFrame" then
		return string.format("cf %s %s %s %s %s %s %s %s %s %s %s %s", num(v.x), num(v.y), num(v.z), num(v.r00), num(v.r01), num(v.r02), num(v.r10), num(v.r11), num(v.r12), num(v.r20), num(v.r21), num(v.r22))
	elseif t == "Color3" then return string.format("c3 %s %s %s", num(v.R), num(v.G), num(v.B))
	elseif t == "NumberRange" then return string.format("nr %s %s", num(v.Min), num(v.Max))
	elseif t == "NumberSequence" then
		local p = { "ns", tostring(#v.Keypoints) }
		for _, k in ipairs(v.Keypoints) do p[#p + 1] = num(k.Time); p[#p + 1] = num(k.Value); p[#p + 1] = num(k.Envelope or 0) end
		return table.concat(p, " ")
	elseif t == "ColorSequence" then
		local p = { "cs", tostring(#v.Keypoints) }
		for _, k in ipairs(v.Keypoints) do p[#p + 1] = num(k.Time); p[#p + 1] = num(k.Value.R); p[#p + 1] = num(k.Value.G); p[#p + 1] = num(k.Value.B) end
		return table.concat(p, " ")
	elseif t == "PhysicalProperties" then
		return string.format("pp %s %s %s %s %s", num(v.Density), num(v.Friction), num(v.Elasticity), num(v.FrictionWeight), num(v.ElasticityWeight))
	elseif t == "Instance" then
		local id = ids[v]
		assert(id, "riferimento a un'istanza non esportata: " .. tostring(v.Name))
		return "r " .. id
	end
	error("tipo non gestito: " .. t)
end

-- proprieta' mai esportate: nome/genitore/classe sono nel record I; TimeOfDay e ClockTime si trattano a parte
local SKIP = { Name = true, Parent = true, ClassName = true, TimeOfDay = true, ClockTime = true }
-- le parti hanno una sola posizione vera (CFrame): Position/Orientation/Rotation ne sono la lettura in altra forma
local PART_DERIVED = { Position = true, Orientation = true, Rotation = true }

local function clockToString(ct)
	local total = math.floor(ct * 3600 + 0.5) % 86400
	return string.format("%02d:%02d:%02d", math.floor(total / 3600), math.floor((total % 3600) / 60), total % 60)
end

-- roots: lista di { inst = <istanza>, under = "Workspace" }  (figlio del servizio)
--                 { inst = <istanza>, is = "Lighting" }       (l'istanza e' il servizio stesso)
-- opts.base: numero sommato a tutti gli id (per non scontrarsi con altri file di record)
function M.export(roots, path, opts)
	opts = opts or {}
	local base = opts.base or 0
	local out = {}
	local ids, n = {}, 0
	local function assign(o)
		n = n + 1
		ids[o] = base + n
		for _, c in ipairs(o:GetChildren()) do assign(c) end
	end
	for _, r in ipairs(roots) do assign(r.inst) end
	local function emit(o, parentId)
		local id = ids[o]
		local cls = o.ClassName
		out[#out + 1] = string.format("I %d %d %s %s", id, parentId, cls, enc(o.Name))
		local P = rawget(o, "_p")
		local isPart = isA(cls, "BasePart")
		local props = {}
		for k, v in pairs(P) do
			if type(k) == "string" and not SKIP[k] and not (isPart and PART_DERIVED[k]) and type(v) ~= "function"
				and not (type(v) == "table" and getmetatable(v) and getmetatable(v).Fire) then
				props[#props + 1] = k
			end
		end
		table.sort(props)
		if cls == "Lighting" and P.ClockTime ~= nil then
			out[#out + 1] = string.format("P %d TimeOfDay s %s", id, enc(clockToString(P.ClockTime)))
		end
		for _, k in ipairs(props) do
			assert(propCode(cls, k), "proprieta' sconosciuta " .. cls .. "." .. k)
			out[#out + 1] = string.format("P %d %s %s", id, k, valueRecord(P[k], ids))
		end
		local at = {}
		for k in pairs(rawget(o, "_attrs")) do at[#at + 1] = k end
		table.sort(at)
		for _, k in ipairs(at) do
			local rec = valueRecord(rawget(o, "_attrs")[k], ids)
			assert(rec:match("^[bns] ") or rec:match("^v3 ") or rec:match("^c3 "), "attributo di tipo non gestito: " .. k)
			out[#out + 1] = string.format("A %d %s %s", id, enc(k), rec)
		end
		local tg = {}
		for k in pairs(rawget(o, "_tags")) do tg[#tg + 1] = k end
		table.sort(tg)
		for _, k in ipairs(tg) do out[#out + 1] = string.format("T %d %s", id, enc(k)) end
		for _, c in ipairs(o:GetChildren()) do emit(c, id) end
	end
	for _, r in ipairs(roots) do
		emit(r.inst, 0)
		if r.is then
			out[#out + 1] = string.format("S %s %d", r.is, ids[r.inst])
		else
			out[#out + 1] = string.format("U %d %s", ids[r.inst], assert(r.under, "manca under/is"))
		end
	end
	local f = assert(io.open(path, "wb"))
	f:write(table.concat(out, "\n"), "\n")
	f:close()
	return n
end

return M
