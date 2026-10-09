--[[
	NatureController - la natura che si muove (solo grafica, sul client)
	  • le chiome degli alberi vicini ondeggiano con il vento (più forte col temporale);
	  • macchie di fiori colorati sull'erba attorno al giocatore;
	  • stormi di uccelli che volano in cerchio di giorno;
	  • lucciole di notte e farfalle di giorno nei prati;
	  • fumo che esce dai camini delle case vicine.
	Tutto viene creato solo vicino alla telecamera e si può spegnere in
	Menu → Impostazioni → "Dettagli ambientali".
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local NatureController = {}
local C

local player = Players.LocalPlayer
local rng = Random.new()

local FOLIAGE_TAG = "Fogliame"
local CHIMNEY_TAG = "Comignolo"

local function enabled(): boolean
	return C.ClientData.Setting("Scenery", true) ~= false
end

local function cameraPosition(): Vector3
	local camera = workspace.CurrentCamera
	return if camera then camera.CFrame.Position else Vector3.zero
end

local function isNight(): boolean
	local t = Lighting.ClockTime
	return t >= 19.2 or t < 5.6
end

local function underground(): boolean
	return cameraPosition().Y < -120
end

local function localPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

-- ALBERI CHE ONDEGGIANO -------------------------------------------------------------------------------

local foliage: { [BasePart]: { Base: CFrame, Pivot: Vector3, Phase: number, Speed: number } } = {}
local activeFoliage: { BasePart } = {}

local function addFoliage(part: Instance)
	if part:IsA("BasePart") and not foliage[part] then
		local size = part.Size
		-- le foglie dello stesso albero ruotano insieme attorno alla cima del tronco ("Perno", "Fase")
		local pivot = part:GetAttribute("Perno")
		local phase = part:GetAttribute("Fase")
		local together = type(phase) == "number"
		foliage[part] = {
			Base = part.CFrame,
			Pivot = if typeof(pivot) == "Vector3" then pivot else part.Position - Vector3.new(0, size.Y * 0.55, 0),
			Phase = if together then phase :: number else rng:NextNumber(0, math.pi * 2),
			Speed = if together then 0.8 + ((phase :: number) * 7.3) % 0.4 else rng:NextNumber(0.7, 1.2),
		}
	end
end

local function removeFoliage(part: Instance)
	foliage[part :: BasePart] = nil
end

local MAX_SWAYING = 480

local function refreshActiveFoliage()
	table.clear(activeFoliage)
	local cam = cameraPosition()
	local near = {}
	for part, info in foliage do
		local d = (info.Base.Position - cam).Magnitude
		if part.Parent and d < 260 then
			table.insert(near, { Part = part, Distance = d })
		end
	end
	if #near > MAX_SWAYING then
		table.sort(near, function(a, b)
			return a.Distance < b.Distance
		end)
	end
	for i = 1, math.min(MAX_SWAYING, #near) do
		table.insert(activeFoliage, near[i].Part)
	end
end

local function swayFoliage(t: number)
	if #activeFoliage == 0 then
		return
	end
	local wind = workspace.GlobalWind
	local strength = math.clamp(wind.Magnitude / 30, 0.15, 1.2)
	local dir = if wind.Magnitude > 0.1 then wind.Unit else Vector3.new(1, 0, 0)
	local parts: { BasePart }, cframes: { CFrame } = {}, {}
	for _, part in activeFoliage do
		local info = foliage[part]
		if info and part.Parent then
			local s = math.sin(t * info.Speed * (1 + strength) + info.Phase)
			local gust = math.sin(t * 0.37 + info.Phase * 0.5) * 0.5 + 0.5
			local angle = math.rad((1.2 + 3.5 * strength * gust) * s)
			-- inclinazione verso la direzione del vento, attorno alla base della chioma
			local axis = Vector3.new(dir.Z, 0, -dir.X)
			local rot = CFrame.fromAxisAngle(axis, angle)
			local offset = info.Base.Position - info.Pivot
			local position = info.Pivot + rot:VectorToWorldSpace(offset)
			table.insert(parts, part)
			table.insert(cframes, CFrame.new(position) * rot * info.Base.Rotation)
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function restoreFoliage()
	for part, info in foliage do
		if part.Parent then
			part.CFrame = info.Base
		end
	end
end

-- FIORI ------------------------------------------------------------------------------------------------

local FLOWER_COLORS = {
	Color3.fromRGB(236, 72, 84), Color3.fromRGB(250, 214, 70), Color3.fromRGB(170, 110, 220),
	Color3.fromRGB(245, 245, 250), Color3.fromRGB(255, 150, 60), Color3.fromRGB(110, 160, 250),
}
local CELL = 40
local RADIUS = 120
local flowerFolder: Folder
local cells: { [string]: Model } = {}
local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.FilterDescendantsInstances = { workspace.Terrain }
-- per i fiori si guarda tutto: se sopra l'erba c'è una casa, un albero o una strada, niente fiori
local openParams = RaycastParams.new()
openParams.FilterType = Enum.RaycastFilterType.Exclude

local function buildCell(cx: number, cz: number): Model
	local model = Instance.new("Model")
	model.Name = ("Fiori_%d_%d"):format(cx, cz)
	local cellRng = Random.new(cx * 73856093 + cz * 19349663)
	local patches = cellRng:NextInteger(0, 2)
	for _ = 1, patches do
		local px = (cx + cellRng:NextNumber()) * CELL
		local pz = (cz + cellRng:NextNumber()) * CELL
		local color = FLOWER_COLORS[cellRng:NextInteger(1, #FLOWER_COLORS)]
		for _ = 1, cellRng:NextInteger(4, 8) do
			local x = px + cellRng:NextNumber(-4, 4)
			local z = pz + cellRng:NextNumber(-4, 4)
			local hit = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1400, 0), openParams)
			local onGrass = hit ~= nil and hit.Instance == workspace.Terrain and (hit.Material == Enum.Material.Grass or hit.Material == Enum.Material.LeafyGrass)
			if hit and onGrass and hit.Position.Y > -100 then
				local h = cellRng:NextNumber(0.9, 1.6)
				localPart({ Name = "Stelo", Size = Vector3.new(0.12, h, 0.12), CFrame = CFrame.new(hit.Position + Vector3.new(0, h / 2, 0)) * CFrame.Angles(cellRng:NextNumber(-0.2, 0.2), 0, cellRng:NextNumber(-0.2, 0.2)), Color = Color3.fromRGB(74, 120, 56), Material = Enum.Material.SmoothPlastic, Parent = model })
				local petal = cellRng:NextNumber(0.45, 0.7)
				localPart({ Name = "Fiore", Shape = Enum.PartType.Ball, Size = Vector3.one * petal, CFrame = CFrame.new(hit.Position + Vector3.new(0, h + petal * 0.3, 0)), Color = color, Material = Enum.Material.SmoothPlastic, Parent = model })
			end
		end
	end
	model.Parent = flowerFolder
	return model
end

local function updateFlowers()
	local cam = cameraPosition()
	if not enabled() or underground() then
		for key, model in cells do
			model:Destroy()
			cells[key] = nil
		end
		return
	end
	local ccx, ccz = math.floor(cam.X / CELL), math.floor(cam.Z / CELL)
	local reach = math.ceil(RADIUS / CELL)
	local wanted = {}
	local built = 0
	openParams.FilterDescendantsInstances = { flowerFolder, player.Character or flowerFolder }
	for dx = -reach, reach do
		for dz = -reach, reach do
			local cx, cz = ccx + dx, ccz + dz
			if (Vector2.new(dx, dz) * CELL).Magnitude <= RADIUS then
				local key = cx .. "_" .. cz
				wanted[key] = true
				if not cells[key] and built < 5 then
					cells[key] = buildCell(cx, cz)
					built += 1
				end
			end
		end
	end
	for key, model in cells do
		if not wanted[key] then
			model:Destroy()
			cells[key] = nil
		end
	end
end

-- UCCELLI -----------------------------------------------------------------------------------------------

type Bird = { Body: Part, Left: Part, Right: Part, Offset: Vector3, Phase: number }
type Flock = { Center: Vector3, Radius: number, Height: number, Angle: number, Speed: number, Birds: { Bird } }
local flocks: { Flock } = {}
local birdFolder: Folder
local meadowGround = 0
local birdBaseY: number? = nil

local function makeFlock(center: Vector3): Flock
	local flock: Flock = {
		Center = center,
		Radius = rng:NextNumber(60, 130),
		Height = rng:NextNumber(70, 120),
		Angle = rng:NextNumber(0, math.pi * 2),
		Speed = rng:NextNumber(0.12, 0.22) * (if rng:NextNumber() < 0.5 then -1 else 1),
		Birds = {},
	}
	local color = Color3.fromRGB(40, 36, 34)
	for i = 1, rng:NextInteger(5, 8) do
		local row = math.ceil(i / 2)
		local side = if i % 2 == 0 then 1 else -1
		local bird: Bird = {
			Body = localPart({ Name = "Uccello", Size = Vector3.new(0.5, 0.35, 1.4), Color = color, Material = Enum.Material.SmoothPlastic, Parent = birdFolder }),
			Left = localPart({ Name = "Ala", Size = Vector3.new(1.6, 0.08, 0.6), Color = color, Material = Enum.Material.SmoothPlastic, Parent = birdFolder }),
			Right = localPart({ Name = "Ala", Size = Vector3.new(1.6, 0.08, 0.6), Color = color, Material = Enum.Material.SmoothPlastic, Parent = birdFolder }),
			Offset = Vector3.new(side * row * 2.6, rng:NextNumber(-1, 1), row * 2.4),
			Phase = rng:NextNumber(0, math.pi * 2),
		}
		table.insert(flock.Birds, bird)
	end
	return flock
end

local function clearFlocks()
	for _, flock in flocks do
		for _, bird in flock.Birds do
			bird.Body:Destroy()
			bird.Left:Destroy()
			bird.Right:Destroy()
		end
	end
	table.clear(flocks)
end

local function updateFlocks(t: number, dt: number)
	local cam = cameraPosition()
	local want = enabled() and not isNight() and not underground() and (C.SkyController == nil or C.SkyController.Weather() ~= "Temporale")
	if not want then
		if #flocks > 0 then
			clearFlocks()
		end
		return
	end
	-- la quota segue il terreno sotto la telecamera, con calma
	birdBaseY = if birdBaseY then birdBaseY + (meadowGround - birdBaseY) * math.min(1, dt * 0.4) else meadowGround
	while #flocks < 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		table.insert(flocks, makeFlock(cam + Vector3.new(math.cos(a) * 120, 0, math.sin(a) * 120)))
	end
	local parts: { BasePart }, cframes: { CFrame } = {}, {}
	for _, flock in flocks do
		-- lo stormo segue (piano) il giocatore se si allontana troppo
		local flat = Vector3.new(cam.X - flock.Center.X, 0, cam.Z - flock.Center.Z)
		if flat.Magnitude > 300 then
			flock.Center += flat * math.min(1, dt * 0.3)
		end
		flock.Angle += flock.Speed * dt
		local a = flock.Angle
		local pos = Vector3.new(flock.Center.X + math.cos(a) * flock.Radius, (birdBaseY or cam.Y) + flock.Height, flock.Center.Z + math.sin(a) * flock.Radius)
		local forward = Vector3.new(-math.sin(a), 0, math.cos(a)) * math.sign(flock.Speed)
		local frame = CFrame.lookAt(pos, pos + forward)
		for _, bird in flock.Birds do
			local cf = frame * CFrame.new(bird.Offset + Vector3.new(0, math.sin(t * 0.8 + bird.Phase) * 0.6, 0))
			local flap = math.sin(t * 9 + bird.Phase) * 0.6
			table.insert(parts, bird.Body)
			table.insert(cframes, cf)
			table.insert(parts, bird.Left)
			table.insert(cframes, cf * CFrame.new(-0.2, 0, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-0.8, 0, 0))
			table.insert(parts, bird.Right)
			table.insert(cframes, cf * CFrame.new(0.2, 0, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(0.8, 0, 0))
		end
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- LUCCIOLE E FARFALLE ------------------------------------------------------------------------------------

local meadowPart: Part
local fireflies: ParticleEmitter
local butterflies: ParticleEmitter

local function buildMeadow()
	meadowPart = localPart({ Name = "Prato", Size = Vector3.new(90, 6, 90), Transparency = 1, Parent = workspace.CurrentCamera })
	fireflies = Instance.new("ParticleEmitter")
	fireflies.Name = "Lucciole"
	fireflies.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	fireflies.Color = ColorSequence.new(Color3.fromRGB(214, 255, 120))
	fireflies.LightEmission = 1
	fireflies.LightInfluence = 0
	fireflies.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(0.8, 0.35), NumberSequenceKeypoint.new(1, 0) })
	fireflies.Lifetime = NumberRange.new(4, 7)
	fireflies.Speed = NumberRange.new(0.4, 1.4)
	fireflies.SpreadAngle = Vector2.new(180, 180)
	fireflies.RotSpeed = NumberRange.new(-40, 40)
	fireflies.Acceleration = Vector3.new(0, 0.15, 0)
	fireflies.Shape = Enum.ParticleEmitterShape.Box
	fireflies.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	fireflies.Rate = 0
	fireflies.Parent = meadowPart

	butterflies = Instance.new("ParticleEmitter")
	butterflies.Name = "Farfalle"
	butterflies.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	butterflies.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 200, 80)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)) })
	butterflies.LightEmission = 0.1
	butterflies.Size = NumberSequence.new(0.3)
	butterflies.Squash = NumberSequence.new({ NumberSequenceKeypoint.new(0, -1), NumberSequenceKeypoint.new(0.25, 1), NumberSequenceKeypoint.new(0.5, -1), NumberSequenceKeypoint.new(0.75, 1), NumberSequenceKeypoint.new(1, -1) })
	butterflies.Lifetime = NumberRange.new(5, 8)
	butterflies.Speed = NumberRange.new(1.5, 3)
	butterflies.SpreadAngle = Vector2.new(180, 60)
	butterflies.Shape = Enum.ParticleEmitterShape.Box
	butterflies.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	butterflies.Rate = 0
	butterflies.Parent = meadowPart
end

local function updateMeadow()
	local cam = cameraPosition()
	local hit = workspace:Raycast(cam + Vector3.new(0, 10, 0), Vector3.new(0, -260, 0), terrainParams)
	local onGrass = hit ~= nil and (hit.Material == Enum.Material.Grass or hit.Material == Enum.Material.LeafyGrass)
	if hit then
		meadowGround = hit.Position.Y
	end
	local weather = if C.SkyController then C.SkyController.Weather() else "Sereno"
	local dry = weather == "Sereno" or weather == "Nuvoloso"
	local on = enabled() and onGrass and dry and not underground()
	fireflies.Rate = if on and isNight() then 10 else 0
	butterflies.Rate = if on and not isNight() and weather == "Sereno" then 1.2 else 0
end

-- FUMO DAI CAMINI -----------------------------------------------------------------------------------------

local smoking: { [BasePart]: ParticleEmitter } = {}

local function smokeEmitter(chimney: BasePart): ParticleEmitter
	local att = Instance.new("Attachment")
	att.Name = "FumoCamino"
	att.Position = Vector3.new(0, chimney.Size.Y / 2 + 0.4, 0)
	att.Parent = chimney
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(200, 196, 190), Color3.fromRGB(150, 148, 146))
	e.LightInfluence = 1
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.6, 0.75), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 6) })
	e.Lifetime = NumberRange.new(6, 9)
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(12, 12)
	e.RotSpeed = NumberRange.new(-20, 20)
	e.Rotation = NumberRange.new(0, 360)
	e.Rate = 2.5
	e.WindAffectsDrag = true
	e.Drag = 0.6
	e.Acceleration = Vector3.new(0, 0.8, 0)
	e.Parent = att
	return e
end

local function updateChimneys()
	local cam = cameraPosition()
	local candidates = {}
	if enabled() then
		for _, chimney in CollectionService:GetTagged(CHIMNEY_TAG) do
			if chimney:IsA("BasePart") then
				local d = (chimney.Position - cam).Magnitude
				if d < 380 then
					table.insert(candidates, { Part = chimney, Distance = d })
				end
			end
		end
		table.sort(candidates, function(a, b)
			return a.Distance < b.Distance
		end)
	end
	local keep = {}
	for i = 1, math.min(24, #candidates) do
		keep[candidates[i].Part] = true
	end
	for chimney, emitter in smoking do
		if not keep[chimney] or not chimney.Parent then
			if emitter.Parent then
				emitter.Parent:Destroy()
			end
			smoking[chimney] = nil
		end
	end
	for chimney in keep do
		if not smoking[chimney] then
			smoking[chimney] = smokeEmitter(chimney)
		end
	end
end

function NatureController.Init(c)
	C = c
end

function NatureController.Start()
	flowerFolder = Instance.new("Folder")
	flowerFolder.Name = "FioriLocali"
	flowerFolder.Parent = workspace
	birdFolder = Instance.new("Folder")
	birdFolder.Name = "UccelliLocali"
	birdFolder.Parent = workspace
	buildMeadow()

	for _, part in CollectionService:GetTagged(FOLIAGE_TAG) do
		addFoliage(part)
	end
	CollectionService:GetInstanceAddedSignal(FOLIAGE_TAG):Connect(addFoliage)
	CollectionService:GetInstanceRemovedSignal(FOLIAGE_TAG):Connect(removeFoliage)

	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		if enabled() then
			swayFoliage(t)
		end
		local ok, err = pcall(updateFlocks, t, dt)
		if not ok then
			warn("[Natura] " .. tostring(err))
		end
		if meadowPart then
			meadowPart.CFrame = CFrame.new(cameraPosition().X, meadowGround + 3, cameraPosition().Z)
		end
	end)

	local wasEnabled = true
	task.spawn(function()
		while true do
			local on = enabled()
			if wasEnabled and not on then
				restoreFoliage()
			end
			wasEnabled = on
			for _, fn in { refreshActiveFoliage, updateFlowers, updateMeadow, updateChimneys } do
				local ok, err = pcall(fn)
				if not ok then
					warn("[Natura] " .. tostring(err))
				end
			end
			task.wait(1)
		end
	end)
end

return NatureController
