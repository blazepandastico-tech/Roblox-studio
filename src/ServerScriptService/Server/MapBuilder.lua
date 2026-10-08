-- Costruisce da codice la mappa Canyon del Deserto (campo, stadio, canyon, lobby) e la luce da tramonto.
-- Ogni parte "di contorno" e' protetta da pcall: se una decorazione fallisce il gioco parte lo stesso.
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

function MapBuilder.Build()
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
	-- il canyon (Terrain) richiede qualche secondo: lo costruiamo in parallelo, il resto e' gia' giocabile
	task.spawn(function()
		try("terreno", function()
			require(Map.Terrain).Build()
		end)
	end)
	return root
end

function MapBuilder.LobbySpawnCFrame()
	local c = Layout.LOBBY
	local pos = Vector3.new(c.X, c.Y + 4, c.Z + 24)
	return CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1))
end

return MapBuilder
