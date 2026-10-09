-- Ricrea nello shim il mondo che un lettore ufficiale vede dentro il .rbxlx (record stampati da "rbxbake dump").
-- Serve a provare il gioco partendo DAL FILE: workspace.World, Terrain e Lighting arrivano dal file, gli script restano quelli montati da src/.
-- Si usa cosi':  local Imp = assert(loadfile(PATH))();  Imp.load(righe_del_dump)  ->  numero di istanze create, lista di problemi
local M = {}

local SHIM = rawget(_G, "__SHIM")
local API = SHIM.API

local function dec(s)
	if s == "~" then return "" end
	return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
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

local function enumItem(typeName, value)
	local items = assert(API.enums[typeName], "enum sconosciuto " .. typeName)
	for name, v in pairs(items) do
		if v == value then return Enum[typeName][name] end
	end
	error("valore " .. value .. " non valido per " .. typeName)
end

-- t: parole della riga, i: posizione del tipo del valore. Restituisce il valore (oppure { ref = id } per i riferimenti)
local function parseValue(cls, prop, t, i)
	local kind = t[i]
	local function n(k) return tonumber(t[i + k]) end
	if kind == "b" then return t[i + 1] == "1"
	elseif kind == "n" then return n(1)
	elseif kind == "s" then return dec(t[i + 1])
	elseif kind == "e" then
		local code = assert(propCode(cls, prop), "proprieta' sconosciuta " .. cls .. "." .. prop)
		local et = code:match("E:(.+)$")
		assert(et, cls .. "." .. prop .. " non e' un enum")
		return enumItem(et, n(2))
	elseif kind == "v3" then return Vector3.new(n(1), n(2), n(3))
	elseif kind == "v2" then return Vector2.new(n(1), n(2))
	elseif kind == "u2" then return UDim2.new(n(1), n(2), n(3), n(4))
	elseif kind == "cf" then return CFrame.new(n(1), n(2), n(3), n(4), n(5), n(6), n(7), n(8), n(9), n(10), n(11), n(12))
	elseif kind == "c3" then return Color3.new(n(1), n(2), n(3))
	elseif kind == "nr" then return NumberRange.new(n(1), n(2))
	elseif kind == "ns" then
		local k = {}
		for j = 0, n(1) - 1 do k[#k + 1] = NumberSequenceKeypoint.new(n(2 + 3 * j), n(3 + 3 * j), n(4 + 3 * j)) end
		return NumberSequence.new(k)
	elseif kind == "cs" then
		local k = {}
		for j = 0, n(1) - 1 do k[#k + 1] = ColorSequenceKeypoint.new(n(2 + 4 * j), Color3.new(n(3 + 4 * j), n(4 + 4 * j), n(5 + 4 * j))) end
		return ColorSequence.new(k)
	elseif kind == "pp" then return PhysicalProperties.new(n(1), n(2), n(3), n(4), n(5))
	elseif kind == "r" then return { ref = n(1) }
	elseif kind == "font" then return nil -- il carattere nello shim non serve alla logica di gioco
	end
	error("tipo di valore sconosciuto: " .. tostring(kind))
end

-- le proprieta' che nel file hanno un altro nome (migrazioni dell'encoder) tornano al nome che conosce lo shim
local BACK = { TextureContent = "Texture" }
local SERVICES = { Workspace = true, Lighting = true }

function M.load(lines)
	local nodes, order, roots = {}, {}, {}
	local problems = {}
	for _, ln in ipairs(lines) do
		local t = {}
		for w in ln:gmatch("%S+") do t[#t + 1] = w end
		if #t > 0 and t[1] ~= "#" and t[1]:sub(1, 1) ~= "#" then
			local tag = t[1]
			if tag == "I" then
				local id = tonumber(t[2])
				local node = { id = id, parent = tonumber(t[3]), class = t[4], name = dec(t[5]), props = {}, attrs = {}, tags = {} }
				nodes[id] = node
				order[#order + 1] = node
			elseif tag == "P" then
				local node = nodes[tonumber(t[2])]
				node.props[#node.props + 1] = { name = t[3], t = t, i = 4 }
			elseif tag == "A" then
				local node = nodes[tonumber(t[2])]
				node.attrs[#node.attrs + 1] = { name = dec(t[3]), t = t, i = 4 }
			elseif tag == "T" then
				local node = nodes[tonumber(t[2])]
				node.tags[#node.tags + 1] = dec(t[3])
			end
		end
	end
	local ws, lighting = SHIM.services.Workspace, SHIM.services.Lighting
	local inst = {}
	local count = 0
	-- crea le istanze (per i servizi e il Terrain si usano quelli dello shim)
	for _, node in ipairs(order) do
		local target
		if node.parent == 0 then
			if node.class == "Workspace" then target = ws elseif node.class == "Lighting" then target = lighting end
		elseif node.class == "Terrain" and nodes[node.parent] and nodes[node.parent].class == "Workspace" then
			target = ws.Terrain
		end
		if target then
			inst[node.id] = target
			node.merge = true
		elseif node.parent == 0 then
			node.skip = true -- Players, ReplicatedStorage...: li fornisce src/
		elseif nodes[node.parent].skip then
			node.skip = true
		else
			local ok, o = pcall(Instance.new, node.class)
			if ok then
				inst[node.id] = o
				count = count + 1
			else
				problems[#problems + 1] = "creazione " .. node.class .. " " .. node.name .. ": " .. tostring(o)
			end
		end
	end
	local function setProp(node, o, p)
		local name = BACK[p.name] or p.name
		local ok, v = pcall(parseValue, node.class, name, p.t, p.i)
		if not ok then
			problems[#problems + 1] = node.class .. "." .. name .. ": " .. tostring(v)
			return
		end
		if v == nil then return end
		if type(v) == "table" and v.ref then
			node.refs = node.refs or {}
			node.refs[#node.refs + 1] = { name = name, id = v.ref }
			return
		end
		local ok2, err = pcall(function() o[name] = v end)
		if not ok2 then
			-- i servizi hanno proprieta' che lo shim non lascia impostare (Technology, TimeOfDay): si scrivono direttamente
			if node.merge then rawget(o, "_p")[name] = v else problems[#problems + 1] = node.class .. "." .. name .. ": " .. tostring(err) end
		end
	end
	for _, node in ipairs(order) do
		local o = inst[node.id]
		if o then
			if not node.merge then o.Name = node.name end
			for _, p in ipairs(node.props) do
				if p.name ~= "Name" then setProp(node, o, p) end
			end
			for _, a in ipairs(node.attrs) do
				local ok, v = pcall(parseValue, node.class, a.name, a.t, a.i)
				if ok then o:SetAttribute(a.name, v) else problems[#problems + 1] = "attributo " .. a.name .. ": " .. tostring(v) end
			end
			for _, tg in ipairs(node.tags) do o:AddTag(tg) end
		end
	end
	-- riferimenti e gerarchia
	for _, node in ipairs(order) do
		local o = inst[node.id]
		if o and node.refs then
			for _, r in ipairs(node.refs) do
				local target = inst[r.id]
				if target then
					local ok, err = pcall(function() o[r.name] = target end)
					if not ok then problems[#problems + 1] = node.class .. "." .. r.name .. ": " .. tostring(err) end
				else
					problems[#problems + 1] = node.class .. "." .. r.name .. " punta a un nodo non importato"
				end
			end
		end
	end
	for _, node in ipairs(order) do
		local o = inst[node.id]
		if o and not node.merge then
			local par = inst[node.parent]
			if par then o.Parent = par else problems[#problems + 1] = node.class .. " " .. node.name .. ": genitore non importato" end
		end
	end
	return count, problems
end

return M
