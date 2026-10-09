--[[
	CitizenController - cittadini che passeggiano per le strade (solo grafica, sul client)
	Il server registra le strade libere delle città (attributo "Strade" della cartella Mappa);
	qui vicino alla telecamera nascono fino a 14 cittadini che camminano avanti e indietro,
	si fermano a guardarsi intorno e ripartono. Non si possono colpire né intralciano il gioco.
	Si spengono con Menu → Impostazioni → "Dettagli ambientali".
]]

local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local CitizenController = {}
local C

local MAX_CITIZENS = 14
local SPAWN_RADIUS = 230
local DESPAWN_RADIUS = 320

type Street = { A: Vector3, B: Vector3, Length: number }

local rng = Random.new()
local streets: { Street } = {}
local folder: Folder

local SKINS = { Color3.fromRGB(242, 206, 176), Color3.fromRGB(226, 182, 150), Color3.fromRGB(196, 150, 116), Color3.fromRGB(150, 104, 76), Color3.fromRGB(110, 76, 56) }
local CLOTHES = { Color3.fromRGB(122, 84, 56), Color3.fromRGB(86, 96, 70), Color3.fromRGB(150, 60, 50), Color3.fromRGB(70, 82, 110), Color3.fromRGB(196, 180, 150), Color3.fromRGB(110, 70, 90), Color3.fromRGB(160, 130, 80) }
local PANTS = { Color3.fromRGB(70, 56, 44), Color3.fromRGB(60, 62, 66), Color3.fromRGB(96, 80, 60), Color3.fromRGB(46, 50, 62) }
local HAIR = { Color3.fromRGB(40, 30, 24), Color3.fromRGB(90, 60, 36), Color3.fromRGB(150, 110, 60), Color3.fromRGB(200, 180, 130), Color3.fromRGB(140, 140, 140) }

type Citizen = {
	Parts: { BasePart },
	Offsets: { CFrame }, -- posizione di ogni parte rispetto al corpo (senza animazione)
	Limbs: { [number]: { Pivot: Vector3, Swing: number } },
	Street: Street,
	T: number, -- posizione lungo la strada (0..1)
	Dir: number, -- 1 verso B, -1 verso A
	Speed: number,
	PauseUntil: number,
	Phase: number,
	GroundY: number,
	NextGround: number,
}
local citizens: { Citizen } = {}

local function enabled(): boolean
	return C.ClientData.Setting("Scenery", true) ~= false
end

local function cameraPosition(): Vector3
	local camera = workspace.CurrentCamera
	return if camera then camera.CFrame.Position else Vector3.zero
end

local function newPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

-- Un cittadino semplice: gambe, busto, braccia, testa e capelli/cappello (alto circa come un giocatore)
local function buildCitizen(): (Model, { BasePart }, { CFrame }, { [number]: { Pivot: Vector3, Swing: number } })
	local model = Instance.new("Model")
	model.Name = "Cittadino"
	local skin = pick(SKINS)
	local shirt = pick(CLOTHES)
	local pants = pick(PANTS)
	local dress = rng:NextNumber() < 0.4
	local parts: { BasePart }, offsets: { CFrame }, limbs: { [number]: { Pivot: Vector3, Swing: number } } = {}, {}, {}
	local function add(part: Part, offset: CFrame, limb: { Pivot: Vector3, Swing: number }?)
		part.Parent = model
		table.insert(parts, part)
		table.insert(offsets, offset)
		if limb then
			limbs[#parts] = limb
		end
	end
	-- gambe (oscillano attorno all'anca)
	for _, side in { -1, 1 } do
		add(newPart({ Name = "Gamba", Size = Vector3.new(0.75, 2.5, 0.8), Color = pants }), CFrame.new(side * 0.45, 1.25, 0), { Pivot = Vector3.new(side * 0.45, 2.5, 0), Swing = side })
	end
	add(newPart({ Name = "Busto", Size = Vector3.new(1.9, 2.1, 1), Color = shirt }), CFrame.new(0, 3.55, 0))
	if dress then
		add(newPart({ Name = "Gonna", Size = Vector3.new(2.1, 1.7, 1.3), Color = shirt:Lerp(Color3.new(0, 0, 0), 0.15) }), CFrame.new(0, 2.05, 0))
	else
		add(newPart({ Name = "Cintura", Size = Vector3.new(1.95, 0.3, 1.05), Color = Color3.fromRGB(60, 44, 30) }), CFrame.new(0, 2.6, 0))
	end
	-- braccia (oscillano attorno alla spalla, opposte alle gambe)
	for _, side in { -1, 1 } do
		add(newPart({ Name = "Braccio", Size = Vector3.new(0.6, 2.1, 0.6), Color = shirt }), CFrame.new(side * 1.25, 3.55, 0), { Pivot = Vector3.new(side * 1.25, 4.5, 0), Swing = -side })
	end
	add(newPart({ Name = "Testa", Shape = Enum.PartType.Ball, Size = Vector3.new(1.25, 1.25, 1.25), Color = skin }), CFrame.new(0, 5.2, 0))
	local style = rng:NextInteger(1, 4)
	if style == 1 then
		add(newPart({ Name = "Capelli", Shape = Enum.PartType.Ball, Size = Vector3.new(1.32, 1.1, 1.32), Color = pick(HAIR), Material = Enum.Material.Fabric }), CFrame.new(0, 5.42, 0.08))
	elseif style == 2 then
		add(newPart({ Name = "Cappello", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 1.7, 1.7), Color = Color3.fromRGB(110, 86, 56), Material = Enum.Material.Fabric }), CFrame.new(0, 5.75, 0) * CFrame.Angles(0, 0, math.rad(90)))
	elseif style == 3 then
		add(newPart({ Name = "Fazzoletto", Shape = Enum.PartType.Ball, Size = Vector3.new(1.36, 1.0, 1.36), Color = pick(CLOTHES), Material = Enum.Material.Fabric }), CFrame.new(0, 5.4, 0.12))
	end
	-- qualcuno porta un cesto
	if rng:NextNumber() < 0.3 then
		add(newPart({ Name = "Cesto", Size = Vector3.new(1.1, 0.7, 0.8), Color = Color3.fromRGB(170, 130, 80), Material = Enum.Material.Fabric }), CFrame.new(1.25, 2.4, -0.35), { Pivot = Vector3.new(1.25, 4.5, 0), Swing = -1 })
	end
	model.Parent = folder
	return model, parts, offsets, limbs
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { workspace.Terrain }

local function groundAt(p: Vector3): number
	local hit = workspace:Raycast(p + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), groundParams)
	return if hit then hit.Position.Y else p.Y
end

local function positionOn(c: Citizen): Vector3
	return c.Street.A:Lerp(c.Street.B, c.T)
end

local function spawnCitizen(street: Street)
	local _, parts, offsets, limbs = buildCitizen()
	local c: Citizen = {
		Parts = parts,
		Offsets = offsets,
		Limbs = limbs,
		Street = street,
		T = rng:NextNumber(0.05, 0.95),
		Dir = if rng:NextNumber() < 0.5 then 1 else -1,
		Speed = rng:NextNumber(4.5, 6.5),
		PauseUntil = 0,
		Phase = rng:NextNumber(0, math.pi * 2),
		GroundY = street.A.Y,
		NextGround = 0,
	}
	c.GroundY = groundAt(positionOn(c))
	table.insert(citizens, c)
end

local function removeCitizen(i: number)
	local c = citizens[i]
	local model = c.Parts[1] and c.Parts[1].Parent
	if model then
		model:Destroy()
	end
	table.remove(citizens, i)
end

local function distanceToStreet(p: Vector3, street: Street): number
	local ab = street.B - street.A
	local t = math.clamp((p - street.A):Dot(ab) / ab:Dot(ab), 0, 1)
	local closest = street.A + ab * t
	return Vector3.new(p.X - closest.X, 0, p.Z - closest.Z).Magnitude
end

local function manage()
	local cam = cameraPosition()
	-- via quelli lontani (o tutti, se i dettagli sono spenti)
	for i = #citizens, 1, -1 do
		local c = citizens[i]
		local p = positionOn(c)
		if not enabled() or Vector3.new(p.X - cam.X, 0, p.Z - cam.Z).Magnitude > DESPAWN_RADIUS then
			removeCitizen(i)
		end
	end
	if not enabled() or #streets == 0 then
		return
	end
	-- di notte in giro c'è meno gente
	local t = Lighting.ClockTime
	local limit = if t >= 20.5 or t < 6 then math.floor(MAX_CITIZENS / 3) else MAX_CITIZENS
	if #citizens > limit then
		local farthest, farDistance = nil, -1
		for i, c in citizens do
			local p = positionOn(c)
			local d = Vector3.new(p.X - cam.X, 0, p.Z - cam.Z).Magnitude
			if d > farDistance then
				farthest, farDistance = i, d
			end
		end
		if farthest then
			removeCitizen(farthest)
		end
		return
	end
	local near: { Street } = {}
	for _, street in streets do
		if distanceToStreet(cam, street) < SPAWN_RADIUS and math.abs(street.A.Y - cam.Y) < 160 then
			table.insert(near, street)
		end
	end
	local spawned = 0
	while #near > 0 and #citizens < limit and spawned < 2 do
		spawnCitizen(near[rng:NextInteger(1, #near)])
		spawned += 1
	end
end

local function animate(dt: number)
	if #citizens == 0 then
		return
	end
	local now = os.clock()
	local parts: { BasePart }, cframes: { CFrame } = {}, {}
	for _, c in citizens do
		local walking = now >= c.PauseUntil
		if walking then
			c.T += c.Dir * c.Speed * dt / c.Street.Length
			if c.T >= 1 or c.T <= 0 then
				c.T = math.clamp(c.T, 0, 1)
				c.Dir = -c.Dir
				c.PauseUntil = now + rng:NextNumber(0.5, 2.5)
			elseif rng:NextNumber() < dt * 0.04 then
				-- ogni tanto si ferma a chiacchierare o a guardare le vetrine
				c.PauseUntil = now + rng:NextNumber(2, 6)
			end
			c.Phase += dt * c.Speed * 1.15
		end
		local pos = positionOn(c)
		if now >= c.NextGround then
			c.NextGround = now + 0.5
			c.GroundY = groundAt(pos)
		end
		local dir = (c.Street.B - c.Street.A) * c.Dir
		local flatDir = Vector3.new(dir.X, 0, dir.Z)
		local origin = Vector3.new(pos.X, c.GroundY, pos.Z)
		local body = CFrame.lookAt(origin, origin + (if flatDir.Magnitude > 0.01 then flatDir.Unit else Vector3.new(0, 0, -1)))
		local swing = if walking then math.sin(c.Phase) else 0
		local bob = if walking then math.abs(math.cos(c.Phase)) * 0.12 else 0
		for i, part in c.Parts do
			local offset = c.Offsets[i]
			local limb = c.Limbs[i]
			if limb then
				-- arto che oscilla attorno al suo perno (anca o spalla)
				local angle = math.rad(28) * swing * limb.Swing
				local rel = offset.Position - limb.Pivot
				offset = CFrame.new(limb.Pivot) * CFrame.Angles(angle, 0, 0) * CFrame.new(rel) * offset.Rotation
			end
			table.insert(parts, part)
			table.insert(cframes, body * CFrame.new(0, bob, 0) * offset)
		end
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

local function loadStreets(map: Instance)
	local raw = map:GetAttribute("Strade")
	if type(raw) ~= "string" or raw == "" then
		return
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(data) ~= "table" then
		return
	end
	table.clear(streets)
	for _, s in data do
		local a = Vector3.new(s[1], s[2], s[3])
		local b = Vector3.new(s[4], s[5], s[6])
		local length = (b - a).Magnitude
		if length > 10 then
			table.insert(streets, { A = a, B = b, Length = length })
		end
	end
end

function CitizenController.Init(c)
	C = c
end

function CitizenController.Start()
	folder = Instance.new("Folder")
	folder.Name = "CittadiniLocali"
	folder.Parent = workspace
	task.spawn(function()
		local map = workspace:WaitForChild(Config.Folders.Map, 120)
		if not map then
			return
		end
		groundParams.FilterDescendantsInstances = { workspace.Terrain, map }
		loadStreets(map)
		map:GetAttributeChangedSignal("Strade"):Connect(function()
			loadStreets(map)
		end)
	end)
	RunService.Heartbeat:Connect(function(dt)
		local ok, err = pcall(animate, dt)
		if not ok then
			warn("[Cittadini] " .. tostring(err))
		end
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(manage)
			if not ok then
				warn("[Cittadini] " .. tostring(err))
			end
			task.wait(1)
		end
	end)
end

return CitizenController
