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
for _, entry in { { "Controllers", "CutsceneController" }, { "Controllers", "EffectsController" }, { "Controllers", "FireworksController" }, { "Controllers", "BoatController" }, { "Controllers", "HorseController" }, { "Controllers", "ExploreController" }, { "UI", "WorldMap" }, { "UI", "Festival" }, { "UI", "AdminPanel" }, { "Controllers", "AbuseEventController" } } do
	load(entry[1], entry[2])
end

local order = { "ClientData", "UIController", "InputController", "CutsceneController", "EffectsController", "FireworksController", "BoatController", "HorseController", "ExploreController", "WorldMap", "Festival", "AdminPanel", "AbuseEventController" }
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
-- 📘 Addestramento di base: tutto il tutorial dall'inizio alla fine. L'orologio è finto (ogni
-- task.wait fa passare 1/30 di secondo) e un giocatore finto esegue ogni passo; nella seconda parte
-- preme Invio per andare avanti. La scena dei giganti gira tutta.
do
	local TutorialData = require(SHARED.Data.Tutorial)
	local Zones = require(SHARED.Data.Zones)
	local Net = require(SHARED.Lib.Net)
	local UIS = game:GetService("UserInputService")
	load("UI", "TutorialTour")
	load("UI", "Tutorial")
	local hookAttached, flying = false, false
	C.ODMController = {
		IsFlying = function()
			return flying
		end,
		HookStates = function()
			return if hookAttached then { Left = { Phase = "Attached" } } else {}
		end,
	}
	local tracker = nil
	C.HUD.SetTutorial = function(info)
		tracker = info
	end
	C.HUD.Element = function()
		return nil
	end
	C.UIController.RegisterPanel("Menu", Instance.new("Frame"))
	for _, name in { "TutorialTour", "Tutorial" } do
		local m = C[name]
		if m then
			local okI, errI = pcall(m.Init, C)
			check(okI, name .. ".Init: " .. tostring(errI))
			local okS, errS = pcall(m.Start)
			check(okS, name .. ".Start: " .. tostring(errS))
		end
	end
	-- un personaggio al Campo di Addestramento
	local camp = Zones.Get("CampoAddestramento")
	local character = Instance.new("Model")
	character.Name = "Recluta"
	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.CFrame = CFrame.new(camp.Center + Vector3.new(0, 3, 0))
	rootPart.Parent = character
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	character.Parent = workspace
	player.Character = character
	player.CharacterAdded:Fire(character)
	C.ClientData.Ready = true
	C.ClientData.Profile.Level = 1
	C.ClientData.Profile.Story = { Chapter = 1, Step = 2, Progress = 0, Done = false }
	-- misure dello schermo per la mappa animata e il riflettore (nel finto restano a zero)
	local top = C.UIController.Layers.Top
	local mapRoot = top:FindFirstChild("TourMappa")
	if mapRoot and mapRoot:FindFirstChild("Vista") then
		(mapRoot :: any).Vista.AbsoluteSize = Vector2.new(1500, 900)
	end
	local spotRoot = top:FindFirstChild("Riflettore")
	if spotRoot then
		spotRoot.AbsoluteSize = Vector2.new(1500, 900)
	end
	local mini = C.WorldMap and C.WorldMap.MiniFrame()
	if mini then
		mini.AbsolutePosition = Vector2.new(16, 160)
		mini.AbsoluteSize = Vector2.new(208, 236)
	end

	local seen = {}
	local ticks = 0
	local ring = 0
	local function act()
		local id = C.Tutorial.CurrentStep()
		if id then
			seen[id] = true
		end
		-- le parti della seconda parte: mappa, riflettore, scena dei giganti, finale
		if mapRoot and mapRoot.Visible then
			seen.Mappa2 = true
		end
		if spotRoot and spotRoot.Visible then
			seen.Riflettore = true
		end
		if C.CutsceneController.IsPlaying() then
			seen.Giganti = true
		end
		local final = top:FindFirstChild("Finale")
		if final and final.Visible then
			seen.Finale = true
		end
		if id == "Guarda" then
			camera.CFrame = camera.CFrame * CFrame.Angles(0, math.rad(15), 0)
		elseif id == "Cammina" then
			rootPart.CFrame = rootPart.CFrame + Vector3.new(2, 0, 0)
		elseif id == "Salta" then
			humanoid.StateChanged:Fire(Enum.HumanoidStateType.Running, Enum.HumanoidStateType.Jumping)
		elseif id == "Schiva" or id == "Fendente" or id == "Abilita" or id == "Lame" then
			local action = ({ Schiva = "Dodge", Fendente = "Attack", Abilita = "SkillZ", Lame = "Reload" })[id]
			C.InputController.Trigger(action, true)
			C.InputController.Trigger(action, false)
		elseif id == "Rampino" then
			hookAttached = true
		elseif id == "Gas" then
			flying = true
			C.InputController.Trigger("Boost", true)
		elseif id == "Anelli" then
			ring = ring % #TutorialData.Rings + 1
			rootPart.CFrame = CFrame.new(TutorialData.Rings[ring])
		elseif id == "Nuca" then
			Net.Event("HitConfirm").OnClientEvent:Fire({ Kind = "NapeKill" })
		elseif id == "Rifornimento" then
			Net.Event("Refilled").OnClientEvent:Fire("Tutto")
		elseif id == "Menu" or id == "Mappa" then
			C.UIController.Toggle(id)
		else
			hookAttached, flying = false, false
			if C.InputController.IsHeld("Boost") then
				C.InputController.Trigger("Boost", false)
			end
			-- seconda parte: "Avanti" con Invio
			UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.Return, UserInputType = Enum.UserInputType.Keyboard }, false)
		end
	end
	local now = os.clock()
	MOCK_HOOKS.Clock = function()
		return now
	end
	MOCK_HOOKS.Wait = function()
		ticks += 1
		if ticks > 20000 then
			error("l'addestramento non finisce (passo: " .. tostring(C.Tutorial.CurrentStep()) .. ")")
		end
		now += 1 / 30
		RunService.RenderStepped:Fire(1 / 30)
		act()
		return 1 / 30
	end
	-- solo la funzione principale del tutorial gira davvero; le animazioni che partono da lì no (come nel finto)
	local depth = 0
	MOCK_HOOKS.Spawn = function(fn, ...)
		if depth > 0 then
			-- i tasti premuti (InputController.Trigger) arrivano subito al tutorial, come nel gioco
			local caller = debug.info(3, "s")
			if caller and string.find(caller, "InputController") and string.find(debug.info(fn, "s"), "Tutorial") then
				fn(...)
			else
				SPAWNED += 1
			end
			return
		end
		depth += 1
		local ok, err = pcall(fn, ...)
		depth -= 1
		check(ok, "addestramento: " .. tostring(err))
	end
	-- la mappa grande aperta prima libera il cursore (e con il cursore libero le azioni non partono)
	C.UIController.CloseAll()
	local before = #WARNINGS
	Net.Event("Tutorial").OnClientEvent:Fire({ Step = 1, Replay = false, Total = #TutorialData.Steps })
	MOCK_HOOKS.Clock, MOCK_HOOKS.Wait, MOCK_HOOKS.Spawn = nil, nil, nil
	check(#WARNINGS == before, "l'addestramento ha dato un errore: " .. tostring(WARNINGS[#WARNINGS]))
	for _, step in TutorialData.Steps do
		check(seen[step.Id], "passo dell'addestramento mai raggiunto: " .. step.Id)
	end
	for _, part in { "Mappa2", "Riflettore", "Giganti", "Finale" } do
		check(seen[part], "seconda parte dell'addestramento mai mostrata: " .. part)
	end
	check(not C.Tutorial.IsActive(), "l'addestramento non si è chiuso")
	check(tracker == nil, "il pannello degli obiettivi è rimasto sul tutorial")
	LOG(("Addestramento di base: %d passi e la seconda parte (mappa, interfaccia, giganti, finale) in %d fotogrammi"):format(#TutorialData.Steps, ticks))
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
	replicated:SetAttribute("FestaSpettacoliAuto", false)
	replicated:SetAttribute("FestaProssimoBoss", nil)
	RunService.RenderStepped:Fire(0.6)
end
-- 🎬 animazioni degli eventi a tempo: ogni scena viene fatta girare fino alla fine
if C.AbuseEventController then
	local AbuseEvents = require(SHARED.Data.AbuseEvents)
	local skyCalls = 0
	C.SkyController = { SetEventSky = function()
		skyCalls += 1
	end }
	-- task.delay finto: le azioni in ritardo vanno in coda e si eseguono subito, in ordine
	local queue = {}
	MOCK_HOOKS.Delay = function(_t, fn, ...)
		table.insert(queue, { fn, table.pack(...) })
	end
	local before = #WARNINGS
	for _, def in AbuseEvents.List do
		local okI, errI = pcall(C.AbuseEventController.PlayIntro, def.Id, 5)
		check(okI, def.Id .. ": animazione d'apertura: " .. tostring(errI))
		-- regia: telecamera sul set nel cielo e giocatore bloccato
		RunService.RenderStepped:Fire(0.1)
		check(C.AbuseEventController.IsCinematic(), def.Id .. ": il giocatore non è bloccato durante l'animazione")
		check(workspace.CurrentCamera.CFrame.Position.Y > 3000, def.Id .. ": la telecamera non inquadra il set dell'animazione")
		local runs = 0
		while #queue > 0 and runs < 3000 do
			local item = table.remove(queue, 1)
			runs += 1
			local okQ, errQ = pcall(item[1], table.unpack(item[2], 1, item[2].n))
			check(okQ, def.Id .. ": azione dell'animazione: " .. tostring(errQ))
			if runs % 20 == 0 then
				RunService.RenderStepped:Fire(0.1)
			end
		end
		for _ = 1, 5 do
			RunService.RenderStepped:Fire(0.1)
		end
		check(not C.AbuseEventController.IsCinematic(), def.Id .. ": a fine animazione il giocatore resta bloccato")
		local props = workspace:FindFirstChild("EventoAdminLocale")
		LOG(("Animazione %s %s: %d azioni, %d oggetti in scena"):format(def.Icon, def.Name, runs, props and #props:GetDescendants() or 0))
		-- effetti mandati dal server durante l'evento
		for _, name in { "AbuseTremor", "AbuseScream", "AbuseFlare", "AbuseLightning" } do
			local okE, errE = pcall(C.AbuseEventController.ServerEffect, name, { Position = Vector3.new(50, 8, 50), Kind = "Nero" })
			check(okE, name .. ": " .. tostring(errE))
		end
		table.clear(queue)
	end
	MOCK_HOOKS.Delay = nil
	check(#WARNINGS == before, "le animazioni degli eventi hanno dato un errore: " .. tostring(WARNINGS[#WARNINGS]))
end
-- pannello admin: la sezione 😈 Admin Abuse con tutti i pulsanti dell'evento
if C.AdminPanel then
	player:SetAttribute("Admin", true)
	local okA, errA = pcall(C.UIController.Open, "Admin")
	check(okA, "apertura del pannello admin: " .. tostring(errA))
	local gui = player:FindFirstChild("PlayerGui")
	local abuseButton, buttons = nil, 0
	for _, d in (gui :: Instance):GetDescendants() do
		if d:IsA("TextButton") and d.Text == "😈 Admin Abuse" then
			abuseButton = d
		end
	end
	check(abuseButton ~= nil, "manca la categoria 😈 Admin Abuse nel pannello admin")
	if abuseButton then
		local before = #WARNINGS
		abuseButton.Activated:Fire()
		check(#WARNINGS == before, "la sezione Admin Abuse ha dato un errore: " .. tostring(WARNINGS[#WARNINGS]))
		for _, d in (gui :: Instance):GetDescendants() do
			if d:IsA("TextButton") then
				for _, word in { "Colosso", "meteora", "Fuochi", "Coriandoli", "Cerimonia", "ADMIN ABUSE", "evento", "date", "Spettacoli automatici" } do
					if d.Text:find(word, 1, true) then
						buttons += 1
						break
					end
				end
			end
		end
		check(buttons == 16, ("nella sezione Admin Abuse ci sono %d pulsanti dell'evento invece di 16"):format(buttons))
		-- 🎬 Animazioni: un pulsante per ogni evento e i pulsanti della durata
		local AbuseEvents = require(SHARED.Data.AbuseEvents)
		local events, durations = 0, 0
		for _, d in (gui :: Instance):GetDescendants() do
			if d:IsA("TextButton") then
				for _, def in AbuseEvents.List do
					if d.Text:sub(1, #(def.Icon .. " " .. def.Name)) == def.Icon .. " " .. def.Name then
						events += 1
					end
				end
				if d.Text:find("min", 1, true) and d.Text:find("⏱️", 1, true) or d.Text == "✏️ VALORE" then
					durations += 1
				end
			end
		end
		check(events == #AbuseEvents.List, ("sezione Animazioni: %d eventi invece di %d"):format(events, #AbuseEvents.List))
		check(durations == #AbuseEvents.Durations + 1, ("sezione Animazioni: %d pulsanti della durata"):format(durations))
		LOG(("Pannello admin: sezione 😈 Admin Abuse con %d pulsanti, %d eventi animati e %d durate"):format(buttons + events + durations, events, durations))
	end
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
