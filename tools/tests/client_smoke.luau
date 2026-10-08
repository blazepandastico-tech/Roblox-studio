--[[
	Prova dell'interfaccia del mondo aperto (tools/test_world.py):
	costruisce minimappa e mappa grande, i controlli di barca, cavallo e forzieri,
	poi fa girare qualche fotogramma con la mappa aperta.
]]

local function check(condition: any, message: string)
	if not condition then
		table.insert(ERRORS, message)
	end
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = TEST_PLAYER
Players.LocalPlayer = player
local playerGui = Instance.new("PlayerGui")
playerGui.Name = "PlayerGui"
playerGui.Parent = player
local scripts = Instance.new("PlayerScripts")
scripts.Name = "PlayerScripts"
scripts.Parent = player
local camera = Instance.new("Camera")
camera.ViewportSize = Vector2.new(1500, 900)
camera.CFrame = CFrame.new(0, 20, 30)
workspace.CurrentCamera = camera

local C: any = {}
local function load(group: string, name: string)
	local ok, result = pcall(require, (CLIENT :: any)[group][name])
	check(ok, ("caricamento %s: %s"):format(name, tostring(result)))
	if ok then
		C[name] = result
	end
	return if ok then result else nil
end

load("Controllers", "ClientData")
load("UI", "UIController")
load("Controllers", "InputController")
C.Notifications = { Toast = function() end, Announce = function() end, ZoneBanner = function() end }
C.SoundController = { Play = function() end, Loop = function() end }
C.CameraController = { IsCinematic = function()
	return false
end, SetCursorMode = function() end, Shake = function() end }
C.HUD = { ObjectivePosition = function()
	return Vector3.new(500, 8, 500)
end }
C.AmbienceController = { RegionName = "Mare Aperto", ZoneId = nil }
C.Intro = { IsShowing = function()
	return false
end }
C.EffectsController = { Steam = function() end }
for _, entry in { { "Controllers", "BoatController" }, { "Controllers", "HorseController" }, { "Controllers", "ExploreController" }, { "UI", "WorldMap" } } do
	load(entry[1], entry[2])
end

local order = { "ClientData", "UIController", "InputController", "BoatController", "HorseController", "ExploreController", "WorldMap" }
for _, name in order do
	local m = C[name]
	if m and m.Init then
		local ok, err = pcall(m.Init, C)
		check(ok, name .. ".Init: " .. tostring(err))
	end
end
for _, name in order do
	local m = C[name]
	if m and m.Start then
		local ok, err = pcall(m.Start, C)
		check(ok, name .. ".Start: " .. tostring(err))
	end
end

-- qualche fotogramma con la minimappa, poi con la mappa grande aperta e il giocatore in sella
if C.WorldMap and C.UIController then
	C.ClientData.Profile = { Level = 300, Treasures = { CimaFaro = 1 }, Settings = {} }
	local stepped = RunService.RenderStepped
	for _ = 1, 3 do
		stepped:Fire(0.2)
	end
	local ok, err = pcall(C.UIController.Open, "Mappa")
	check(ok, "apertura della mappa: " .. tostring(err))
	for _ = 1, 3 do
		stepped:Fire(0.2)
	end
	check(C.UIController.IsOpen("Mappa"), "la mappa grande non si apre")
	local heartbeat = RunService.Heartbeat
	heartbeat:Fire(0.016)
end

for _, w in WARNINGS do
	table.insert(ERRORS, "Avviso (interfaccia): " .. w)
end
if #ERRORS > 0 then
	for _, e in ERRORS do
		LOG("ERRORE: " .. e)
	end
	error(("prova dell'interfaccia fallita: %d errori"):format(#ERRORS))
end
LOG("Prova dell'interfaccia OK: minimappa, mappa grande, barca, cavallo e forzieri")
