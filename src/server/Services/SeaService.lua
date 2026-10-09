--[[
	SeaService
	Il mare aperto tra le isole:
	  - barche personali: si prendono ai pontili (tasto F) e si guidano con W A S D
	    (le guida il client del proprietario, il server le ancora quando nessuno è al timone)
	  - eventi in mare: giganti che emergono dalle onde e relitti alla deriva con il carico da saccheggiare
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Lib.Util)
local W = require(Shared.Data.WorldLayout)

local SeaService = {}
local S

local BOAT = Config.Boat
local HULL_Y = W.WaterY + 0.6 -- quota del centro dello scafo quando galleggia

type BoatInfo = { Model: Model, Hull: BasePart, Seat: Seat, Owner: Player, LastUsed: number }

local boats: { [Player]: BoatInfo } = {}
local lastSpawn: { [Player]: number } = {}
local rng = Random.new()
local boatFolder: Folder
local eventFolder: Folder

local SAIL_COLORS = {
	Color3.fromRGB(236, 230, 214),
	Color3.fromRGB(196, 60, 52),
	Color3.fromRGB(60, 96, 150),
	Color3.fromRGB(70, 120, 76),
	Color3.fromRGB(214, 170, 60),
	Color3.fromRGB(120, 70, 130),
}

-- BARCHE ----------------------------------------------------------------------------------------

local function weldTo(hull: BasePart, p: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hull
	weld.Part1 = p
	weld.Parent = p
end

local function boatPart(model: Model, hull: BasePart?, props: { [string]: any }): BasePart
	local className = props.ClassName or "Part"
	local p = Instance.new(className) :: BasePart
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "ClassName" and k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Anchored = hull == nil
	if hull then
		p.Massless = true
		weldTo(hull, p)
	end
	p.Parent = model
	return p
end

local function buildBoat(owner: Player, cf: CFrame): (Model, BasePart, Seat)
	local model = Instance.new("Model")
	model.Name = "Barca di " .. owner.DisplayName
	local wood = Color3.fromRGB(110, 76, 50)
	local hull = boatPart(model, nil, { Name = "Scafo", Size = Vector3.new(8, 2.6, 18), CFrame = cf, Material = Enum.Material.WoodPlanks, Color = wood })
	hull.CustomPhysicalProperties = PhysicalProperties.new(0.4, 0.3, 0.1)
	model.PrimaryPart = hull
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	boatPart(model, hull, { ClassName = "WedgePart", Name = "Prua", Size = Vector3.new(8, 2.6, 6), CFrame = at(0, 0, -12) * CFrame.Angles(0, math.pi, 0), Material = Enum.Material.WoodPlanks, Color = wood })
	boatPart(model, hull, { Name = "Ponte", Size = Vector3.new(7.4, 0.4, 20), CFrame = at(0, 1.4, -1), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(156, 120, 82) })
	for _, sx in { -1, 1 } do
		boatPart(model, hull, { Name = "Murata", Size = Vector3.new(0.4, 1.4, 19), CFrame = at(sx * 3.8, 2.2, -0.5), Material = Enum.Material.Wood, Color = Color3.fromRGB(90, 62, 40) })
	end
	boatPart(model, hull, { Name = "Poppa", Size = Vector3.new(8, 1.4, 0.4), CFrame = at(0, 2.2, 8.8), Material = Enum.Material.Wood, Color = Color3.fromRGB(90, 62, 40) })
	local sailColor = SAIL_COLORS[(owner.UserId % #SAIL_COLORS) + 1]
	boatPart(model, hull, { Name = "Albero", Size = Vector3.new(0.7, 17, 0.7), CFrame = at(0, 10, -3), Material = Enum.Material.Wood, Color = Color3.fromRGB(80, 56, 38), CanCollide = false })
	boatPart(model, hull, { Name = "Vela", Size = Vector3.new(6.4, 10, 0.2), CFrame = at(0, 11, -2.6), Material = Enum.Material.Fabric, Color = sailColor, CanCollide = false, CastShadow = false })
	boatPart(model, hull, { Name = "Bandiera", Size = Vector3.new(0.1, 1.2, 2.2), CFrame = at(0, 18.8, -2), Material = Enum.Material.Fabric, Color = Color3.fromRGB(150, 36, 40), CanCollide = false, CastShadow = false })
	boatPart(model, hull, { Name = "Lanterna", Size = Vector3.new(0.7, 0.9, 0.7), CFrame = at(0, 3.4, -13), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 200, 120), CanCollide = false, CastShadow = false })
	-- timone (solo il proprietario guida) e posti per gli amici
	local seat = boatPart(model, hull, { ClassName = "Seat", Name = "Timone", Size = Vector3.new(2, 0.6, 2), CFrame = at(0, 1.9, 6.4), Material = Enum.Material.Wood, Color = Color3.fromRGB(96, 66, 44) }) :: Seat
	boatPart(model, hull, { Name = "Ruota", Size = Vector3.new(2.4, 2.4, 0.3), CFrame = at(0, 3.6, 4.6), Material = Enum.Material.Wood, Color = Color3.fromRGB(80, 54, 34), CanCollide = false })
	for _, spot in { Vector3.new(-2.2, 1.9, 0), Vector3.new(2.2, 1.9, 0), Vector3.new(0, 1.9, -7) } do
		boatPart(model, hull, { ClassName = "Seat", Name = "Posto", Size = Vector3.new(2, 0.6, 2), CFrame = at(spot.X, spot.Y, spot.Z), Material = Enum.Material.Wood, Color = Color3.fromRGB(120, 86, 56) })
	end
	-- vincoli che il client del proprietario usa per guidarla
	local attachment = Instance.new("Attachment")
	attachment.Name = "Centro"
	attachment.Parent = hull
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "Spinta"
	velocity.Attachment0 = attachment
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = 1e7
	velocity.Enabled = false
	velocity.Parent = hull
	local align = Instance.new("AlignOrientation")
	align.Name = "Assetto"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxTorque = 1e7
	align.Responsiveness = 18
	align.Enabled = false
	align.Parent = hull
	-- nome sopra la vela
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 30)
	billboard.StudsOffset = Vector3.new(0, 20, 0)
	billboard.MaxDistance = 160
	billboard.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(240, 230, 210)
	label.TextStrokeTransparency = 0.4
	label.Text = "⛵ " .. owner.DisplayName
	label.Parent = billboard
	billboard.Parent = hull
	model:SetAttribute("Owner", owner.UserId)
	model:SetAttribute("HullY", HULL_Y)
	-- sempre visibile sulla mappa, anche da lontano
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	CollectionService:AddTag(model, Config.Tags.Boat)
	return model, hull, seat
end

-- Nessuno al timone: la barca resta ferma e dritta sull'acqua
local function moor(info: BoatInfo)
	local hull = info.Hull
	if not hull.Parent then
		return
	end
	local pos = hull.Position
	local _, yaw = hull.CFrame:ToOrientation()
	hull.Anchored = true
	hull.AssemblyLinearVelocity = Vector3.zero
	hull.AssemblyAngularVelocity = Vector3.zero
	info.Model:PivotTo(CFrame.new(pos.X, HULL_Y, pos.Z) * CFrame.Angles(0, yaw, 0))
	info.Model:SetAttribute("Driver", 0)
	info.LastUsed = os.clock()
end

local function eject(humanoid: Humanoid)
	local seat = humanoid.SeatPart
	local weld = seat and seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	humanoid.Sit = false
end

local function onDriverChanged(info: BoatInfo)
	local humanoid = info.Seat.Occupant
	if not humanoid then
		moor(info)
		return
	end
	local driver = Players:GetPlayerFromCharacter(humanoid.Parent)
	if driver ~= info.Owner then
		eject(humanoid)
		if driver and S.EventService then
			S.EventService.Notify(driver, "Solo il proprietario può stare al timone. Siediti su un altro posto!", "Info", 3)
		end
		return
	end
	-- il proprietario guida: la fisica passa al suo client
	local hull = info.Hull
	hull.Anchored = false
	pcall(function()
		hull:SetNetworkOwner(info.Owner)
	end)
	info.Model:SetAttribute("Driver", info.Owner.UserId)
	info.LastUsed = os.clock()
	if S.HorseService then
		S.HorseService.Dismount(info.Owner)
	end
end

local function removeBoat(player: Player)
	local info = boats[player]
	boats[player] = nil
	if info and info.Model.Parent then
		info.Model:Destroy()
	end
end

local function spawnBoat(player: Player, spawnCF: CFrame): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	local state = S.PlayerService.GetState(player)
	if state.Transformed or state.GrabbedBy then
		S.EventService.Notify(player, "Non puoi prendere la barca adesso.", "Errore", 2.5)
		return false
	end
	local now = os.clock()
	if now - (lastSpawn[player] or 0) < BOAT.SpawnCooldown then
		S.EventService.Notify(player, "Aspetta un attimo prima di prendere un'altra barca.", "Info", 2)
		return false
	end
	lastSpawn[player] = now
	removeBoat(player)
	local flat = CFrame.new(spawnCF.Position.X, HULL_Y, spawnCF.Position.Z) * spawnCF.Rotation
	local model, hull, seat = buildBoat(player, flat)
	model.Parent = boatFolder
	local info: BoatInfo = { Model = model, Hull = hull, Seat = seat, Owner = player, LastUsed = now }
	boats[player] = info
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		onDriverChanged(info)
	end)
	if S.HorseService then
		S.HorseService.Dismount(player)
	end
	pcall(function()
		player:RequestStreamAroundAsync(hull.Position, 3)
	end)
	if S.ODMService then
		S.ODMService.Grace(player, 2)
	end
	seat:Sit(humanoid)
	S.EventService.Notify(player, "⛵ La tua barca! W/S per la velocità, A/D per girare, Spazio per scendere.", "Successo", 5)
	return true
end

-- Barca al pontile più vicino (dai traghettatori)
function SeaService.SpawnBoatNear(player: Player, position: Vector3)
	local best, bestDist = nil, 400
	for _, dock in CollectionService:GetTagged(Config.Tags.BoatDock) do
		if dock:IsA("BasePart") then
			local d = Util.FlatDistance(dock.Position, position)
			if d < bestDist then
				best, bestDist = dock, d
			end
		end
	end
	if not best then
		S.EventService.Notify(player, "Qui vicino non c'è un pontile per le barche.", "Errore", 3)
		return
	end
	local dock = best :: BasePart
	local spawnCF = CFrame.new(dock:GetAttribute("SpawnX") or dock.Position.X, HULL_Y, dock:GetAttribute("SpawnZ") or dock.Position.Z) * CFrame.Angles(0, dock:GetAttribute("SpawnYaw") or 0, 0)
	spawnBoat(player, spawnCF)
end

function SeaService.GetBoat(player: Player): Model?
	local info = boats[player]
	return info and info.Model or nil
end

local function hookDock(dock: Instance)
	if not dock:IsA("BasePart") then
		return
	end
	local prompt = dock:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	prompt.Triggered:Connect(function(player)
		local spawnCF = CFrame.new(dock:GetAttribute("SpawnX") or dock.Position.X, HULL_Y, dock:GetAttribute("SpawnZ") or dock.Position.Z) * CFrame.Angles(0, dock:GetAttribute("SpawnYaw") or 0, 0)
		spawnBoat(player, spawnCF)
	end)
end

-- EVENTI IN MARE ----------------------------------------------------------------------------------

local function sailors(): { { Player: Player, Root: BasePart, Level: number } }
	local list = {}
	for _, player in Players:GetPlayers() do
		local root = Util.GetRoot(player.Character)
		local profile = S.DataService.Get(player)
		if root and profile and W.IsOpenSea(root.Position) and not S.PlayerService.InCutscene(player) then
			table.insert(list, { Player = player, Root = root, Level = profile.Level })
		end
	end
	return list
end

local function seaPointNear(origin: Vector3, minDist: number, maxDist: number): Vector3?
	local b = W.SeaBounds
	for _ = 1, 16 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(minDist, maxDist)
		local p = Vector3.new(origin.X + math.cos(a) * d, W.WaterY, origin.Z + math.sin(a) * d)
		if p.X > b.MinX + 120 and p.X < b.MaxX - 120 and p.Z > b.MinZ + 120 and p.Z < b.MaxZ - 120 and W.IsOpenSea(p) then
			-- lontano dalla costa: i giganti del mare non devono finire sulle spiagge
			local nearLand = false
			for _, isl in W.Islands do
				if Util.FlatDistance(p, isl.Center) < isl.Beach + 60 then
					nearLand = true
				end
			end
			if not nearLand then
				return p
			end
		end
	end
	return nil
end

local function notifySailors(list, text: string, kind: string)
	for _, entry in list do
		S.EventService.Notify(entry.Player, text, kind, 5)
	end
end

local function seaTitanClass(level: number): string
	if level < 100 then
		return "T5"
	elseif level < 300 then
		return "T7"
	elseif level < 600 then
		return "T10"
	elseif level < 1000 then
		return "T12"
	end
	return "T15"
end

local function spawnSeaTitan(target, list)
	local pos = seaPointNear(target.Root.Position, 140, 220)
	if not pos then
		return
	end
	local level = math.clamp(target.Level, 5, Config.MaxLevel)
	local toward = Util.Flat(target.Root.Position - pos)
	local t = S.TitanService.Spawn({
		Class = seaTitanClass(level),
		Level = level,
		Position = pos,
		Duration = Config.Sea.TitanDuration,
		Abnormal = rng:NextNumber() < 0.25,
		Yaw = math.atan2(-toward.X, -toward.Z),
	})
	if not t then
		return
	end
	CollectionService:AddTag(t.Model, Config.Tags.SeaEvent)
	t.Model:SetAttribute("EventoMare", "Gigante")
	S.EventService.Effect("Splash", { Position = pos, Size = 30 }, pos, 1500)
	S.EventService.Effect("Roar", { Position = pos, Height = 40 }, pos, 1500)
	notifySailors(list, "🌊 Un gigante emerge dalle onde! Difendi la tua barca (la nuca è sempre il punto debole).", "Errore")
end

local function spawnWreck(target, list)
	local pos = seaPointNear(target.Root.Position, 260, 480)
	if not pos then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Relitto alla deriva"
	local yaw = rng:NextNumber(0, math.pi * 2)
	local cf = CFrame.new(pos.X, W.WaterY + 0.4, pos.Z) * CFrame.Angles(0, yaw, math.rad(9))
	local function piece(props)
		local p = Instance.new(props.ClassName or "Part")
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		for k, v in props do
			if k ~= "ClassName" then
				(p :: any)[k] = v
			end
		end
		p.Parent = model
		return p
	end
	piece({ Name = "Scafo", Size = Vector3.new(10, 3, 24), CFrame = cf, Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(84, 60, 42) })
	piece({ Name = "Ponte", Size = Vector3.new(9.4, 0.4, 22), CFrame = cf * CFrame.new(0, 1.6, 0), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(130, 100, 70) })
	piece({ Name = "AlberoSpezzato", Size = Vector3.new(0.9, 9, 0.9), CFrame = cf * CFrame.new(0, 6, -2) * CFrame.Angles(0.3, 0, 0.2), Material = Enum.Material.Wood, Color = Color3.fromRGB(70, 50, 34) })
	local crate = piece({ Name = "Carico", Size = Vector3.new(3.4, 3, 3.4), CFrame = cf * CFrame.new(0, 3.3, 4), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(176, 136, 70) })
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = Color3.fromRGB(255, 220, 120)
	sparkle.Parent = crate
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Saccheggia il carico"
	prompt.ObjectText = "Relitto alla deriva"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 1.2
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = crate
	model.PrimaryPart = crate
	model:SetAttribute("EventoMare", "Relitto")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	CollectionService:AddTag(model, Config.Tags.SeaEvent)
	model.Parent = eventFolder
	local looted: { [Player]: boolean } = {}
	prompt.Triggered:Connect(function(player)
		if looted[player] then
			S.EventService.Notify(player, "Hai già preso la tua parte di questo carico.", "Info", 2)
			return
		end
		local profile = S.DataService.Get(player)
		local root = Util.GetRoot(player.Character)
		if not profile or not root or (root.Position - crate.Position).Magnitude > 22 then
			return
		end
		looted[player] = true
		local gold = S.PlayerService.AddGold(player, 250 + profile.Level * 35)
		local gems = if rng:NextNumber() < 0.5 then rng:NextInteger(1, 3) else 0
		if gems > 0 then
			profile.Gems += gems
		end
		if S.InventoryService and rng:NextNumber() < 0.5 then
			S.InventoryService.Give(player, "BombolaGas", 1)
		end
		S.DataService.MarkDirty(player)
		S.EventService.Notify(player, ("📦 Carico saccheggiato: +%s oro%s"):format(Util.Abbreviate(gold), if gems > 0 then ("  +%d 💎"):format(gems) else ""), "Ricompensa", 4)
		S.EventService.Effect("LevelUp", { Character = player.Character }, crate.Position, 200)
	end)
	task.delay(Config.Sea.WreckDuration, function()
		if model.Parent then
			model:Destroy()
		end
	end)
	notifySailors(list, "📦 Un relitto alla deriva è stato avvistato! Guarda la mappa (tasto B) e saccheggialo.", "Raro")
end

local function eventLoop()
	while true do
		local range = Config.Sea.EventInterval
		task.wait(rng:NextNumber(range[1], range[2]))
		local list = sailors()
		if #list > 0 then
			local target = list[rng:NextInteger(1, #list)]
			local ok, err = pcall(function()
				if rng:NextNumber() < 0.55 then
					spawnSeaTitan(target, list)
				else
					spawnWreck(target, list)
				end
			end)
			if not ok then
				warn("[SeaService] Evento in mare: " .. tostring(err))
			end
		end
	end
end

-- Barche lasciate sole troppo a lungo spariscono (e così quelle cadute fuori dal mondo)
local function cleanupLoop()
	while true do
		task.wait(10)
		local now = os.clock()
		for player, info in boats do
			local hull = info.Hull
			if not info.Model.Parent or not hull.Parent or hull.Position.Y < -40 then
				removeBoat(player)
			elseif info.Seat.Occupant then
				info.LastUsed = now
			else
				local anyone = false
				for _, seat in info.Model:GetChildren() do
					if seat:IsA("Seat") and seat.Occupant then
						anyone = true
					end
				end
				if anyone then
					info.LastUsed = now
				elseif now - info.LastUsed > BOAT.IdleDespawn then
					removeBoat(player)
				end
			end
		end
	end
end

function SeaService.Init(services)
	S = services
end

function SeaService.Start()
	boatFolder = Instance.new("Folder")
	boatFolder.Name = "Barche"
	boatFolder.Parent = workspace
	eventFolder = Instance.new("Folder")
	eventFolder.Name = "EventiMare"
	eventFolder.Parent = workspace
	S.WorldBuilder.WaitReady()
	for _, dock in CollectionService:GetTagged(Config.Tags.BoatDock) do
		hookDock(dock)
	end
	CollectionService:GetInstanceAddedSignal(Config.Tags.BoatDock):Connect(hookDock)
	Players.PlayerRemoving:Connect(function(player)
		removeBoat(player)
		lastSpawn[player] = nil
	end)
	task.spawn(eventLoop)
	task.spawn(cleanupLoop)
end

return SeaService
