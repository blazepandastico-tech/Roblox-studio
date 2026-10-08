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
C.CameraController = {
	IsCinematic = function()
		return false
	end,
	SetCursorMode = function() end,
	Shake = function() end,
	SetCinematic = function() end,
	CinematicShake = function()
		return CFrame.identity
	end,
}
C.HUD = { ObjectivePosition = function()
	return Vector3.new(500, 8, 500)
end, SetVisible = function() end }
C.Dialogue = { IsOpen = function()
	return false
end }
C.AmbienceController = { RegionName = "Mare Aperto", ZoneId = nil }
C.Intro = { IsShowing = function()
	return false
end }
for _, entry in { { "Controllers", "CutsceneController" }, { "Controllers", "EffectsController" }, { "Controllers", "FireworksController" }, { "Controllers", "BoatController" }, { "Controllers", "HorseController" }, { "Controllers", "ExploreController" }, { "UI", "WorldMap" }, { "UI", "Festival" } } do
	load(entry[1], entry[2])
end

local order = { "ClientData", "UIController", "InputController", "CutsceneController", "EffectsController", "FireworksController", "BoatController", "HorseController", "ExploreController", "WorldMap", "Festival" }
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

-- fuochi d'artificio e arrivo del Colosso: si fanno girare per 3,5 secondi veri
if C.FireworksController then
	local fw = C.FireworksController
	local rng = Random.new(7)
	local okF, errF = pcall(function()
		for _, kind in { "Peony", "Willow", "Ring", "Palm", "Crackle" } do
			fw.Rocket(Vector3.new(0, 10, 0), 120, nil, kind, rng)
		end
		fw.ColossusArrival(Vector3.new(50, 8, 50), 80)
		fw.Confetti(true)
		fw.Show(Vector3.new(0, 8, 0), 20, 3)
	end)
	check(okF, "fuochi d'artificio: " .. tostring(errF))
	local t0 = os.clock()
	while os.clock() - t0 < 3.5 do
		RunService.RenderStepped:Fire(0.016)
	end
	local fx = workspace:FindFirstChild("FuochiLocali")
	local emitters = 0
	for _, d in (fx and fx:GetDescendants() or {}) do
		if d:IsA("ParticleEmitter") then
			emitters += 1
		end
	end
	check(emitters >= 10, "i fuochi d'artificio non sono esplosi (emettitori: " .. emitters .. ")")
	LOG(("Fuochi d'artificio: %d esplosioni di particelle create"):format(emitters))
end
-- cerimonia d'apertura (la scena dura una ventina di secondi veri)
if C.CutsceneController then
	local before = #WARNINGS
	local okS, errS = pcall(C.CutsceneController.Play, "Inaugurazione")
	check(okS, "cerimonia d'apertura: " .. tostring(errS))
	check(#WARNINGS == before, "la cerimonia d'apertura ha dato un errore: " .. tostring(WARNINGS[#WARNINGS]))
	LOG("Cerimonia d'apertura riprodotta fino alla fine")
end
-- pannello dell'evento
if C.Festival then
	local replicated = game:GetService("ReplicatedStorage")
	replicated:SetAttribute("FestaAttiva", true)
	replicated:SetAttribute("FestaProssimoBoss", os.time() + 600)
	C.ClientData.Profile.Festival = { Id = "Inaugurazione2026", Progress = { Giganti = 12 }, Done = { Fuochi = true }, Islets = {} }
	local okP, errP = pcall(C.UIController.Open, "Inaugurazione")
	check(okP, "apertura del pannello dell'evento: " .. tostring(errP))
	RunService.RenderStepped:Fire(0.6)
	RunService.RenderStepped:Fire(0.6)
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
LOG("Prova dell'interfaccia OK: minimappa, mappa grande, barca, cavallo, forzieri, fuochi e pannello dell'evento")
