-- Costruisce da codice la mappa Canyon del Deserto (campo, stadio, canyon, lobby) e la luce da tramonto.
-- Ogni parte "di contorno" e' protetta da pcall: se una decorazione fallisce il gioco parte lo stesso.
--
-- Due modi di avere la mappa:
--  * file .rbxlx "cotto" (tools/bake): le parti fisse sono gia' nel file dentro workspace.World (attributo Baked),
--    all'avvio resta da costruire solo il terreno;
--  * place vuoto (Rojo): Build() costruisce tutto da codice, come prima.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Layout = require(script.Parent.Map.Layout)
local Util = require(script.Parent.Map.Util)

local MapBuilder = {}

local function try(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[Mappa] " .. name .. " non riuscito: " .. tostring(err))
	end
	return ok
end

-- Tutto cio' che e' fisso: luce, campo, stadio, lobby, scenario. E' la parte che tools/bake scrive dentro il file.
function MapBuilder.BuildStatic()
	local root = Instance.new("Folder")
	root.Name = "World"
	root.Parent = workspace

	local Map = script.Parent.Map
	try("atmosfera", function()
		require(Map.Atmosphere).Build()
	end)

	-- campo: parte essenziale
	local field = Util.folder(root, "Field")
	require(Map.Pitch).Build(field)
	require(Map.Goals).Build(field)
	try("stadio", function()
		require(Map.Arena).Build(root)
	end)
	try("lobby", function()
		require(Map.LobbyBuilder).Build(root)
	end)
	try("scenario", function()
		require(Map.Props).Build(root)
	end)
	return root
end

-- Il canyon (Terrain a voxel) non sta nel file: richiede qualche secondo, quindi si costruisce all'avvio, in parallelo.
function MapBuilder.BuildTerrain()
	local t0 = workspace:GetServerTimeNow()
	local ok = try("terreno", function()
		require(script.Parent.Map.Terrain).Build()
	end)
	if ok then
		print(string.format("[Calcio Fuorilegge] canyon (Terrain) pronto in %.0f secondi", workspace:GetServerTimeNow() - t0))
	end
end

function MapBuilder.Build()
	local root = workspace:FindFirstChild("World")
	if root and root:GetAttribute("Baked") then
		print("[Calcio Fuorilegge] mappa gia' nel file: " .. #root:GetDescendants() .. " oggetti in workspace.World")
	else
		root = MapBuilder.BuildStatic()
		print("[Calcio Fuorilegge] mappa costruita da codice: " .. #root:GetDescendants() .. " oggetti in workspace.World")
	end
	-- il resto e' gia' giocabile mentre il terreno si costruisce
	task.spawn(MapBuilder.BuildTerrain)
	return root
end

function MapBuilder.LobbySpawnCFrame()
	local c = Layout.LOBBY
	local pos = Vector3.new(c.X, c.Y + 4, c.Z + 24)
	return CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1))
end

return MapBuilder
