--[[
	Prova della grafica (tools/test_world.py): fa girare nel Roblox finto i controller grafici del client
	(cielo, luci della notte, natura, effetti, giganti) sulla mappa costruita da world_smoke e controlla:
	finestre che si accendono di notte (e si spengono di giorno), particelle nell'aria, vapore dalle
	ferite dei giganti, polvere sotto i passi, mantello che si alza all'indietro, pose del volo che
	cambiano con la spinta.
]]

local function check(condition: any, message: string)
	if not condition then
		table.insert(ERRORS, message)
	end
end

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(SHARED.Config)
local Poses = require(SHARED.Anim.Poses)
local TitanBuilder = require(SHARED.Anim.TitanBuilder)
local Zones = require(SHARED.Data.Zones)

local warningsBefore = #WARNINGS
local player = Players.LocalPlayer
-- una telecamera tutta nuova (quella delle prove precedenti è rimasta legata alle scene dell'evento)
local camera = Instance.new("Camera")
camera.ViewportSize = Vector2.new(1500, 900)
camera.FieldOfView = 70
workspace.CurrentCamera = camera

-- i cicli infiniti dei controller (task.spawn + task.wait) girano una volta sola: al primo
-- task.wait il ciclo si ferma per sempre
local mainThread = coroutine.running()
local function once(fn, ...)
	local co = coroutine.create(fn)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		table.insert(ERRORS, "ciclo di un controller: " .. tostring(err))
	end
end
local function withLoops(fn: () -> ())
	MOCK_HOOKS.Spawn = once
	MOCK_HOOKS.Wait = function()
		if coroutine.running() ~= mainThread then
			coroutine.yield()
		end
		return 0
	end
	local ok, err = pcall(fn)
	MOCK_HOOKS.Spawn = nil
	MOCK_HOOKS.Wait = nil
	check(ok, tostring(err))
end

local C: any = {}
local function load(group: string, name: string)
	local ok, result = pcall(require, (CLIENT :: any)[group][name])
	check(ok, ("caricamento %s: %s"):format(name, tostring(result)))
	if ok then
		C[name] = result
	end
end
load("Controllers", "ClientData")
for _, name in { "SkyController", "AmbienceController", "NatureController", "EffectsController", "TitanAnimator" } do
	load("Controllers", name)
end
C.ClientData.Profile = C.ClientData.Profile or { Settings = {} }
C.Notifications = { Toast = function() end, Announce = function() end, ZoneBanner = function() end }
C.SoundController = { Play = function() end, Loop = function() end }
C.CameraController = { Shake = function() end, IsCinematic = function()
	return false
end }

-- un personaggio vicino al campo di addestramento (serve per i passi dei giganti e per la zona)
local camp = Zones.Get("CampoAddestramento")
local here = if camp then camp.Center else Vector3.new(0, 8, 0)
local character = Instance.new("Model")
character.Name = player.Name
local hrp = Instance.new("Part")
hrp.Name = "HumanoidRootPart"
hrp.Size = Vector3.new(2, 2, 1)
hrp.CFrame = CFrame.new(here + Vector3.new(0, 3, 0))
hrp.Parent = character
character.PrimaryPart = hrp
character.Parent = workspace
player.Character = character
camera.CFrame = CFrame.new(here + Vector3.new(0, 12, 30), here)

Lighting.ClockTime = 21.5
withLoops(function()
	for _, name in { "ClientData", "SkyController", "AmbienceController", "NatureController", "EffectsController", "TitanAnimator" } do
		local m = C[name]
		if m and m.Init then
			m.Init(C)
		end
	end
	for _, name in { "SkyController", "AmbienceController", "NatureController", "EffectsController", "TitanAnimator" } do
		local m = C[name]
		if m and m.Start then
			m.Start(C)
		end
	end
end)

-- LUCI DELLA NOTTE: alle 21:30 una parte delle finestre è accesa, a mezzogiorno nessuna
local function litWindows(): (number, number)
	local lit, total = 0, 0
	for _, w in CollectionService:GetTagged(Config.Tags.Window) do
		total += 1
		if w.Material == Enum.Material.Neon then
			lit += 1
		end
	end
	return lit, total
end
C.AmbienceController.RefreshLights()
local nightLit, windows = litWindows()
check(windows > 500, ("finestre delle case con l'etichetta: solo %d"):format(windows))
check(nightLit > windows * 0.2 and nightLit < windows * 0.8, ("di notte %d finestre accese su %d"):format(nightLit, windows))
local lampsOn = 0
for _, bulb in CollectionService:GetTagged(Config.Tags.Lamp) do
	local light = bulb:FindFirstChildOfClass("PointLight")
	if light and light.Enabled then
		lampsOn += 1
	end
end
check(lampsOn > 150, "di notte i lampioni e le torce non si accendono (" .. lampsOn .. ")")
Lighting.ClockTime = 12
C.AmbienceController.RefreshLights()
local dayLit = litWindows()
check(dayLit == 0, ("a mezzogiorno restano %d finestre accese"):format(dayLit))
for _, w in CollectionService:GetTagged(Config.Tags.Window) do
	if w.Material ~= Enum.Material.Glass then
		check(false, "una finestra non è tornata di vetro: " .. w.Material.Name)
		break
	end
end
-- fiamme che tremolano: qualche fotogramma
Lighting.ClockTime = 22
C.AmbienceController.RefreshLights()
for _ = 1, 5 do
	RunService.RenderStepped:Fire(1 / 30)
end

-- PARTICELLE NELL'ARIA: la scatola segue la telecamera; nel bosco cadono le foglie
C.NatureController.Refresh()
RunService.RenderStepped:Fire(1 / 30)
local air = camera:FindFirstChild("AriaAttorno")
check(air ~= nil, "manca la scatola delle particelle nell'aria")
local forest = nil
for _, zone in Zones.List do
	if zone.Ambience == "Foresta" and not zone.Underground then
		forest = zone
		break
	end
end
if air and forest then
	Lighting.ClockTime = 11
	camera.CFrame = CFrame.new(forest.Center + Vector3.new(0, 10, 0))
	C.NatureController.Refresh()
	local leaves = air:FindFirstChild("FoglieVerdi") :: ParticleEmitter?
	check(leaves ~= nil and leaves.Rate > 0, "nel bosco non cadono le foglie")
	local motes = air:FindFirstChild("Pulviscolo") :: ParticleEmitter?
	check(motes ~= nil and motes.Rate == 0, "nel bosco non dovrebbe esserci il pulviscolo delle città")
	camera.CFrame = CFrame.new(here + Vector3.new(0, 12, 30), here)
end

-- GIGANTI: vapore dalle ferite e polvere sotto i piedi che toccano terra
local dust = 0
local groundDust = C.EffectsController.GroundDust
C.EffectsController.GroundDust = function(...)
	dust += 1
	return groundDust(...)
end
local folder = Instance.new("Folder")
folder.Name = "GigantiDiProva"
folder.Parent = workspace
local titan = TitanBuilder.Build({ Height = 22, Look = "Puro", Seed = 11, Name = "Puro" })
titan:SetAttribute("MaxHP", 100)
titan:SetAttribute("HP", 100)
titan:PivotTo(CFrame.new(here + Vector3.new(30, (titan:GetAttribute("HipHeight") or 10), 0)))
titan.Parent = folder
withLoops(function()
	CollectionService:AddTag(titan, Config.Tags.Titan)
end)
titan:SetAttribute("HP", 30)
local torso = titan:FindFirstChild("Torso")
local steam = torso and torso:FindFirstChild("VaporeFerite") :: ParticleEmitter?
check(steam ~= nil and steam.Rate > 1, "il gigante ferito non manda vapore")
titan:SetAttribute("HP", 100)
check(steam == nil or steam.Rate == 0, "il gigante guarito manda ancora vapore")
titan:SetAttribute("Move", 1)
for _ = 1, 90 do
	RunService.PreSimulation:Fire(0.1)
end
check(dust >= 2, ("passi del gigante: %d sbuffi di polvere"):format(dust))
C.EffectsController.GroundDust = groundDust

-- MANTELLO: con il vento si alza all'indietro (verso +Z, dietro la schiena), mai dentro il corpo
for _, speed in { 0, 60, 130 } do
	local pose = Poses.Human.Cloak(1.3, { Speed = speed })
	local bottom = pose.Cloak * Vector3.new(0, -1, 0)
	check(bottom.Z > 0.05, ("a velocità %d il mantello va in avanti (z = %.2f)"):format(speed, bottom.Z))
end

-- VOLO: spinta e frenata cambiano la posa (braccia e gambe)
local push = Poses.Human.ODMFly(1, { Speed = 130, Pitch = 90, AccelFwd = 160, VY = 0 })
local brake = Poses.Human.ODMFly(1, { Speed = 130, Pitch = 90, AccelFwd = -160, VY = 0 })
local pushX = push.RightShoulder:ToEulerAnglesXYZ()
local brakeX = brake.RightShoulder:ToEulerAnglesXYZ()
check(brakeX > pushX + math.rad(20), "in frenata le braccia non vanno in avanti")

-- 🎃 HALLOWEEN (solo con il tema di Halloween): zucche accese di notte, pipistrelli, fantasmi e costumi
local halloweenText = ""
local Tema = require(SHARED.Data.Tema)
if Tema.IsHalloween() then
	local okH, HC = pcall(require, (CLIENT :: any).Controllers.HalloweenController)
	check(okH, "caricamento HalloweenController: " .. tostring(HC))
	if okH then
		withLoops(function()
			HC.Init(C)
			HC.Start()
		end)
		local carved = CollectionService:GetTagged(Tema.Tags.Carved)
		check(#carved > 200, ("zucche intagliate con la candela: solo %d pezzi"):format(#carved))
		Lighting.ClockTime = 21.5
		HC.RefreshPumpkins()
		local lit = 0
		for _, p in carved do
			if p.Material == Enum.Material.Neon then
				lit += 1
			end
		end
		check(lit == #carved, ("di notte si accendono %d intagli su %d"):format(lit, #carved))
		Lighting.ClockTime = 12
		HC.RefreshPumpkins()
		local dayLit = 0
		for _, p in carved do
			if p.Material == Enum.Material.Neon then
				dayLit += 1
			end
		end
		check(dayLit == 0, "di giorno le zucche restano accese")
		Lighting.ClockTime = 22
		camera.CFrame = CFrame.new(here + Vector3.new(0, 12, 30), here)
		for i = 1, 30 do
			HC.Step(i * 0.1, 0.1)
		end
		local local_ = workspace:FindFirstChild("HalloweenLocale")
		local bats, ghosts = 0, 0
		if local_ then
			for _, d in local_:GetDescendants() do
				if d.Name == "Pipistrello" then
					bats += 1
				elseif d.Name == "Fantasma" then
					ghosts += 1
				end
			end
		end
		check(bats >= 10, ("di notte volano solo %d pipistrelli"):format(bats))
		check(ghosts >= 1, "di notte non compare nessun fantasma")
		halloweenText = ("; Halloween: %d intagli accesi di notte, %d pipistrelli, %d fantasmi"):format(lit, bats, ghosts)
	end
	-- costumi dei giganti: gli occhi della zucca stanno davanti agli occhi veri
	local king = TitanBuilder.Build({ Height = 46, Look = "Zucca", Seed = 3, Name = "ReZucca" })
	check(king:GetAttribute("Costume") == "ReZucca", "il Re Zucca non ha il suo costume")
	local headPart = king:FindFirstChild("Head") :: BasePart
	local eye = king:FindFirstChild("RightEye") :: BasePart
	local carvedEyes = {}
	for _, d in king:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "OcchioZucca" then
			table.insert(carvedEyes, headPart.CFrame:PointToObjectSpace(d.Position))
		end
	end
	check(#carvedEyes == 4, ("intagli degli occhi della zucca: %d invece di 4"):format(#carvedEyes))
	if eye then
		local e = headPart.CFrame:PointToObjectSpace(eye.Position)
		local nearest = math.huge
		for _, c in carvedEyes do
			nearest = math.min(nearest, math.abs(c.X - e.X) + math.abs(c.Y - e.Y))
		end
		check(nearest < headPart.Size.X * 0.2, "gli occhi intagliati non stanno davanti agli occhi veri del Re Zucca")
		check(eye.CanQuery and eye.Transparency >= 1, "l'occhio da colpire del Re Zucca è cambiato")
	end
	for _, d in king:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "Zucca" or d.Name == "OcchioZucca" or d.Name == "Mantello") then
			check(not d.CanQuery and not d.CanCollide, "un pezzo del costume ferma i colpi: " .. d.Name)
		end
	end
	local costumes = {}
	for seed = 1, 40 do
		local m = TitanBuilder.Build({ Height = 20, Look = "Puro", Seed = seed, Name = "Puro" })
		local c = m:GetAttribute("Costume")
		if c then
			costumes[c] = (costumes[c] or 0) + 1
		end
	end
	for _, kind in { "Zucca", "Strega", "Zombie", "Corna", "Scheletro" } do
		check((costumes[kind] or 0) > 0, "nessun gigante con il costume " .. kind)
	end
	local ghost = TitanBuilder.Build({ Height = 40, Look = "Spettro", Seed = 9, Name = "Spettro" })
	local torsoPart = ghost:FindFirstChild("Torso") :: BasePart
	check(torsoPart ~= nil and torsoPart.Transparency > 0.2 and torsoPart:FindFirstChild("Ectoplasma") ~= nil, "il Gigante Fantasma non è trasparente o non ha l'ectoplasma")
end

for i = warningsBefore + 1, #WARNINGS do
	table.insert(ERRORS, "Avviso (grafica): " .. WARNINGS[i])
end
if #ERRORS > 0 then
	for _, e in ERRORS do
		LOG("ERRORE: " .. e)
	end
	error(("prova della grafica fallita: %d errori"):format(#ERRORS))
end
LOG(("Prova della grafica OK: di notte %d finestre accese su %d e %d luci, a mezzogiorno spente; foglie nel bosco, vapore dalle ferite, %d sbuffi di polvere, mantello all'indietro%s"):format(nightLit, windows, lampsOn, dust, halloweenText))
