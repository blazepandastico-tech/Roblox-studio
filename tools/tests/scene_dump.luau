--[[
	Esporta i fotogrammi di una scena animata (CutsceneController) per tools/scene_photo.py.
	La scena gira con il codice vero del gioco e un orologio finto: un piccolo "scheduler" fa girare
	anche i task.spawn e i task.delay (movimenti della telecamera, giganti che camminano, segni che
	pulsano), un fotogramma ogni 1/30 di secondo.
	Ingressi: SCENE (nome della scena), SHOTS (secondi dall'inizio in cui scattare le foto).
	Uscita: per ogni foto "F t", "CAM" (posizione, punto guardato, campo visivo) e le parti
	visibili come righe "P" (stesso formato di world_dump), con i giganti nella posa del momento.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Instance.new("Player")
player.Name = "Regista"
Players.LocalPlayer = player
local playerGui = Instance.new("PlayerGui")
playerGui.Name = "PlayerGui"
playerGui.Parent = player
local camera = Instance.new("Camera")
camera.ViewportSize = Vector2.new(1500, 900)
camera.FieldOfView = 70
workspace.CurrentCamera = camera
local effects = Instance.new("Folder")
effects.Name = "EffettiLocali"
effects.Parent = workspace

-- OROLOGIO FINTO E SCHEDULER -----------------------------------------------------------------------------
local FRAME = 1 / 30
local now = 1000
local threads: { thread } = {}
local delayed: { { At: number, Fn: any, Args: any } } = {}
local frameHook: () -> () = function() end
MOCK_HOOKS.Clock = function()
	return now
end
local function resume(co: thread, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		LOG("ERRORE nel task: " .. tostring(err))
	end
	if coroutine.status(co) ~= "dead" then
		table.insert(threads, co)
	end
end
MOCK_HOOKS.Spawn = function(fn, ...)
	resume(coroutine.create(fn), ...)
end
MOCK_HOOKS.Delay = function(t, fn, ...)
	table.insert(delayed, { At = now + (t or 0), Fn = fn, Args = table.pack(...) })
end
local function frame()
	now += FRAME
	RunService.RenderStepped:Fire(FRAME)
	RunService.Heartbeat:Fire(FRAME)
	for i = #delayed, 1, -1 do
		local d = delayed[i]
		if d.At <= now then
			table.remove(delayed, i)
			resume(coroutine.create(d.Fn), table.unpack(d.Args, 1, d.Args.n))
		end
	end
	local list = threads
	threads = {}
	for _, co in list do
		resume(co)
	end
	frameHook()
end
local mainThread = coroutine.running()
MOCK_HOOKS.Wait = function()
	-- dentro un task: si ferma fino al prossimo fotogramma; nel filo principale: passa un fotogramma
	if coroutine.running() ~= mainThread then
		coroutine.yield()
	else
		frame()
	end
	return FRAME
end

-- IL CLIENT (solo quello che serve alle scene) ---------------------------------------------------------------
local C: any = {}
local function load(group: string, name: string)
	local ok, result = pcall(require, (CLIENT :: any)[group][name])
	if not ok then
		error(("caricamento %s: %s"):format(name, tostring(result)))
	end
	C[name] = result
end
load("Controllers", "ClientData")
load("UI", "UIController")
load("Controllers", "InputController")
load("Controllers", "EffectsController")
load("Controllers", "CutsceneController")
C.Notifications = { Toast = function() end, Announce = function() end, ZoneBanner = function() end }
C.SoundController = { Play = function() end, Loop = function() end }
C.CameraController = {
	IsCinematic = function()
		return true
	end,
	SetCursorMode = function() end,
	Shake = function() end,
	SetCinematic = function() end,
	CinematicShake = function()
		return CFrame.identity
	end,
}
C.HUD = { SetVisible = function() end }
C.Intro = { IsShowing = function()
	return false
end }
C.Dialogue = { IsOpen = function()
	return false
end }
for _, name in { "ClientData", "UIController", "InputController", "EffectsController", "CutsceneController" } do
	local m = C[name]
	if m.Init then
		m.Init(C)
	end
end
for _, name in { "ClientData", "UIController", "InputController", "EffectsController", "CutsceneController" } do
	local m = C[name]
	if m.Start then
		m.Start(C)
	end
end

-- ESPORTAZIONE ----------------------------------------------------------------------------------------
local function f(n: number): string
	return string.format("%.3f", n)
end
local function cfText(cf: CFrame): string
	local c = { cf:GetComponents() }
	for i, v in c do
		c[i] = f(v)
	end
	return table.concat(c, "\t")
end
local function emitPart(p: BasePart, cf: CFrame)
	local shape = "Block"
	if p.ClassName == "Part" then
		shape = if p.Shape then p.Shape.Name else "Block"
	elseif p.ClassName == "WedgePart" then
		shape = "Wedge"
	end
	local mesh = p:FindFirstChildOfClass("SpecialMesh")
	if mesh and mesh.MeshType == Enum.MeshType.Sphere then
		shape = "Ellipsoid"
	end
	local s = p.Size
	local c = p.Color or Color3.new(0.6, 0.6, 0.6)
	LOG(table.concat({ "P", p.ClassName, shape, f(s.X), f(s.Y), f(s.Z), cfText(cf), f(c.R), f(c.G), f(c.B), if p.Material then p.Material.Name else "Plastic", f(p.Transparency or 0), p.Name }, "\t"))
end

-- i giganti: ogni parte nella posa del momento (le giunture modificate dall'animatore, come in Roblox)
local function emitModel(model: Model)
	local root = model.PrimaryPart
	local motors = {}
	local links: { [BasePart]: { BasePart } } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			table.insert(motors, d)
		elseif (d:IsA("WeldConstraint") or d:IsA("Weld")) and d.Part0 and d.Part1 then
			local a, b = d.Part0 :: BasePart, d.Part1 :: BasePart
			links[a] = links[a] or {}
			links[b] = links[b] or {}
			table.insert(links[a], b)
			table.insert(links[b], a)
		end
	end
	if not root or #motors == 0 then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 0.98 then
				emitPart(d, d.CFrame)
			end
		end
		return
	end
	local world: { [BasePart]: CFrame } = { [root] = root.CFrame }
	local changed = true
	while changed do
		changed = false
		for _, m in motors do
			local p0, p1 = m.Part0, m.Part1
			if p0 and p1 and world[p0] and not world[p1] then
				world[p1] = world[p0] * m.C0 * m.C1:Inverse()
				changed = true
			end
		end
	end
	-- i pezzi saldati seguono la parte a cui sono saldati (nel finto le parti restano nella posa di riposo)
	local driver: { [BasePart]: BasePart } = {}
	local queue = {}
	for p in world do
		driver[p] = p
		table.insert(queue, p)
	end
	local qi = 1
	while qi <= #queue do
		local p = queue[qi]
		qi += 1
		for _, o in links[p] or {} do
			if not driver[o] then
				driver[o] = driver[p]
				table.insert(queue, o)
			end
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.98 then
			local drv = driver[d]
			local cf = if drv then world[drv] * drv.CFrame:Inverse() * d.CFrame else d.CFrame
			emitPart(d, cf)
		end
	end
end

local function snapshot(t: number)
	LOG(("F\t%s"):format(f(t)))
	local cf = camera.CFrame
	local target = cf.Position + cf.LookVector * 50
	LOG(table.concat({ "CAM", f(cf.X), f(cf.Y), f(cf.Z), f(target.X), f(target.Y), f(target.Z), f(camera.FieldOfView) }, "\t"))
	for _, child in effects:GetChildren() do
		if child:IsA("Model") then
			emitModel(child)
		elseif child:IsA("BasePart") and child.Transparency < 0.98 then
			emitPart(child, child.CFrame)
		end
	end
end

local shots = table.clone(SHOTS)
table.sort(shots)
local start = now
local nextShot = 1
frameHook = function()
	local t = now - start
	while shots[nextShot] and t >= shots[nextShot] do
		snapshot(shots[nextShot])
		nextShot += 1
	end
end
C.CutsceneController.Play(SCENE, true)
LOG(("DURATA\t%s"):format(f(now - start)))
LOG("FINE")
