--[[
	HorseService
	Il cavallo di ogni soldato: si chiama con H e si cavalca ovunque all'aperto.
	Il cavallo è fatto di parti saldate sotto il giocatore (senza peso e senza collisioni):
	il giocatore resta un normale personaggio, solo più alto e più veloce.
	Le zampe le anima ogni client (HorseController) in base alla velocità.
	Si scende da soli con H, oppure usando i rampini, attaccando, trasformandosi o salendo in barca.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Lib.Util)
local Net = require(Shared.Lib.Net)
local W = require(Shared.Data.WorldLayout)

local HorseService = {}
local S

local H = Config.Horse

type Ride = { Model: Model, Humanoid: Humanoid, HipBase: number }

local riding: { [Player]: Ride } = {}
local lastToggle: { [Player]: number } = {}

-- Mantelli: baio, sauro, morello, grigio, palomino, pezzato
local COATS = {
	{ Coat = Color3.fromRGB(110, 66, 38), Mane = Color3.fromRGB(34, 24, 18) },
	{ Coat = Color3.fromRGB(150, 84, 44), Mane = Color3.fromRGB(120, 66, 34) },
	{ Coat = Color3.fromRGB(36, 32, 32), Mane = Color3.fromRGB(20, 18, 18) },
	{ Coat = Color3.fromRGB(196, 192, 186), Mane = Color3.fromRGB(150, 146, 140) },
	{ Coat = Color3.fromRGB(214, 176, 112), Mane = Color3.fromRGB(240, 226, 196) },
	{ Coat = Color3.fromRGB(140, 120, 104), Mane = Color3.fromRGB(60, 52, 46) },
}

function HorseService.IsRiding(player: Player): boolean
	return riding[player] ~= nil
end

local function horsePart(model: Model, name: string, size: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CollisionGroup = Config.CollisionGroups.Players
	p.Parent = model
	return p
end

local function motor(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = c0
	m.C1 = c1
	m.Parent = part1
	return m
end

local function weld(part0: BasePart, part1: BasePart, offset: CFrame)
	local w = Instance.new("Weld")
	w.Part0 = part0
	w.Part1 = part1
	w.C0 = offset
	w.Parent = part1
end

-- Costruisce il cavallo sotto la sella. bodyOffset = posizione del corpo rispetto alla HumanoidRootPart
local function buildHorse(root: BasePart, coatIndex: number, bodyOffset: CFrame): Model
	local colors = COATS[((coatIndex - 1) % #COATS) + 1]
	local coat, mane = colors.Coat, colors.Mane
	local model = Instance.new("Model")
	model.Name = "Cavallo"
	local body = horsePart(model, "Corpo", Vector3.new(2.6, 2.6, 6.2), coat)
	motor("SellaMotore", root, body, bodyOffset, CFrame.identity)
	local rump = horsePart(model, "Groppa", Vector3.new(2.9, 2.9, 2.9), coat, nil, Enum.PartType.Ball)
	weld(body, rump, CFrame.new(0, 0.15, 2.3))
	local chest = horsePart(model, "Petto", Vector3.new(2.8, 2.8, 2.8), coat, nil, Enum.PartType.Ball)
	weld(body, chest, CFrame.new(0, 0.2, -2.4))
	-- collo e testa (il collo annuisce al galoppo)
	local neck = horsePart(model, "Collo", Vector3.new(1.3, 3.4, 1.7), coat)
	motor("ColloMotore", body, neck, CFrame.new(0, 1.0, -3.0), CFrame.new(0, -1.5, 0) * CFrame.Angles(math.rad(40), 0, 0))
	local head = horsePart(model, "Testa", Vector3.new(1.15, 1.25, 2.7), coat)
	weld(neck, head, CFrame.new(0, 1.85, -1.0) * CFrame.Angles(math.rad(10), 0, 0))
	local muzzle = horsePart(model, "Muso", Vector3.new(1.0, 1.0, 1.0), Color3.new(coat.R * 0.7, coat.G * 0.7, coat.B * 0.7))
	weld(head, muzzle, CFrame.new(0, -0.15, -1.4))
	for _, sx in { -1, 1 } do
		local ear = horsePart(model, "Orecchio", Vector3.new(0.25, 0.6, 0.35), coat)
		weld(head, ear, CFrame.new(sx * 0.38, 0.85, 0.9) * CFrame.Angles(0, 0, sx * 0.2))
		local eye = horsePart(model, "Occhio", Vector3.new(0.12, 0.22, 0.22), Color3.fromRGB(20, 16, 14))
		weld(head, eye, CFrame.new(sx * 0.58, 0.25, -0.2))
	end
	local maneNeck = horsePart(model, "Criniera", Vector3.new(0.35, 3.3, 0.9), mane, Enum.Material.Fabric)
	weld(neck, maneNeck, CFrame.new(0, 0.1, 0.85))
	-- coda
	local tail = horsePart(model, "Coda", Vector3.new(0.55, 2.8, 0.6), mane, Enum.Material.Fabric)
	motor("CodaMotore", body, tail, CFrame.new(0, 0.6, 3.3), CFrame.new(0, 1.2, 0) * CFrame.Angles(math.rad(30), 0, 0))
	-- sella, coperta e staffe
	local blanket = horsePart(model, "Coperta", Vector3.new(2.9, 0.15, 3.0), Color3.fromRGB(150, 36, 40), Enum.Material.Fabric)
	weld(body, blanket, CFrame.new(0, 1.33, -0.2))
	local saddle = horsePart(model, "Sella", Vector3.new(2.4, 0.4, 2.4), Color3.fromRGB(70, 44, 28), Enum.Material.Leather)
	weld(body, saddle, CFrame.new(0, 1.5, -0.3))
	local horn = horsePart(model, "Pomo", Vector3.new(0.4, 0.6, 0.4), Color3.fromRGB(70, 44, 28), Enum.Material.Leather)
	weld(saddle, horn, CFrame.new(0, 0.4, -1.0))
	for _, sx in { -1, 1 } do
		local strap = horsePart(model, "Staffile", Vector3.new(0.1, 1.6, 0.25), Color3.fromRGB(50, 34, 24), Enum.Material.Leather)
		weld(saddle, strap, CFrame.new(sx * 1.3, -0.9, 0))
		local stirrup = horsePart(model, "Staffa", Vector3.new(0.5, 0.15, 0.5), Color3.fromRGB(140, 140, 146), Enum.Material.Metal)
		weld(strap, stirrup, CFrame.new(0, -0.85, 0))
	end
	-- zampe: anca (o spalla) e ginocchio animati, zoccolo saldato
	local hoofColor = Color3.fromRGB(40, 34, 30)
	for _, leg in {
		{ Id = "AS", X = -0.8, Z = -2.4 },
		{ Id = "AD", X = 0.8, Z = -2.4 },
		{ Id = "PS", X = -0.8, Z = 2.3 },
		{ Id = "PD", X = 0.8, Z = 2.3 },
	} do
		local thigh = horsePart(model, "Coscia" .. leg.Id, Vector3.new(0.75, 1.6, 0.95), coat)
		motor("Anca" .. leg.Id, body, thigh, CFrame.new(leg.X, -0.9, leg.Z), CFrame.new(0, 0.75, 0))
		local shin = horsePart(model, "Stinco" .. leg.Id, Vector3.new(0.45, 1.45, 0.5), coat)
		motor("Ginocchio" .. leg.Id, thigh, shin, CFrame.new(0, -0.75, 0), CFrame.new(0, 0.7, 0))
		local hoof = horsePart(model, "Zoccolo", Vector3.new(0.6, 0.35, 0.7), hoofColor)
		weld(shin, hoof, CFrame.new(0, -0.76, -0.05))
	end
	return model
end

function HorseService.Dismount(player: Player, silent: boolean?)
	local ride = riding[player]
	if not ride then
		return
	end
	riding[player] = nil
	if ride.Model.Parent then
		ride.Model:Destroy()
	end
	if ride.Humanoid.Parent then
		ride.Humanoid.HipHeight = ride.HipBase
	end
	player:SetAttribute("Riding", false)
	if ride.Humanoid.Parent and ride.Humanoid.Health > 0 then
		S.PlayerService.Refresh(player, true)
		if S.ODMService then
			S.ODMService.Grace(player, 1)
		end
	end
	if not silent and S.EventService and ride.Humanoid.Parent and ride.Humanoid.Health > 0 then
		local root = Util.GetRoot(player.Character)
		if root then
			S.EventService.Effect("Footstep", { Position = root.Position - Vector3.new(0, 2, 0), Size = 8 }, root.Position, 200)
		end
	end
end

local function canMount(player: Player): (boolean, string?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = Util.GetRoot(character)
	if not humanoid or not root or humanoid.Health <= 0 then
		return false, nil
	end
	local state = S.PlayerService.GetState(player)
	if state.Transformed then
		return false, "Un gigante non può cavalcare!"
	elseif state.GrabbedBy then
		return false, nil
	elseif humanoid.SeatPart then
		return false, "Prima scendi dalla barca."
	elseif S.PlayerService.InCutscene(player) then
		return false, nil
	end
	if root.Position.Y < -120 then
		return false, "Il cavallo non entra nei sotterranei."
	end
	if root.Position.Y < W.WaterY + 2.5 and W.IsOpenSea(root.Position) then
		return false, "Il cavallo non sa nuotare in mare aperto!"
	end
	if S.RaidService and S.RaidService.IsParticipant(player) then
		return false, "Niente cavalli durante i raid."
	end
	return true, nil
end

function HorseService.Mount(player: Player)
	if riding[player] then
		return
	end
	local ok, reason = canMount(player)
	if not ok then
		if reason then
			S.EventService.Notify(player, reason, "Errore", 2.5)
		end
		return
	end
	local character = player.Character :: Model
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = Util.GetRoot(character) :: BasePart
	local profile = S.DataService.Get(player)
	local coat = if profile and (profile.HorseColor or 0) > 0 then profile.HorseColor else (player.UserId % #COATS) + 1
	local hipBase = humanoid.HipHeight
	local halfRoot = root.Size.Y / 2
	-- il bacino del cavaliere poggia sulla sella: la HumanoidRootPart sale di conseguenza
	local newHip = H.SaddleHeight + 1 - halfRoot
	local groundBelowRoot = newHip + halfRoot
	local bodyOffset = CFrame.new(0, -groundBelowRoot + 3.9, 0.3)
	local model = buildHorse(root, coat, bodyOffset)
	CollectionService:AddTag(model, Config.Tags.Horse)
	model.Parent = character
	humanoid.HipHeight = newHip
	riding[player] = { Model = model, Humanoid = humanoid, HipBase = hipBase }
	player:SetAttribute("Riding", true)
	-- solleva subito il personaggio per non far affondare il cavallo nel terreno
	root.CFrame = root.CFrame + Vector3.new(0, newHip - hipBase, 0)
	if S.ODMService then
		S.ODMService.Grace(player, 1.5)
	end
	S.PlayerService.Refresh(player, true)
	S.EventService.Effect("Footstep", { Position = root.Position - Vector3.new(0, groundBelowRoot, 0), Size = 10 }, root.Position, 200)
end

local function onRequest(player: Player, wanted: any)
	local now = os.clock()
	if now - (lastToggle[player] or 0) < 0.4 then
		return
	end
	lastToggle[player] = now
	if wanted == false or (wanted == nil and riding[player]) then
		HorseService.Dismount(player)
		return
	end
	if riding[player] then
		return
	end
	if now - (player:GetAttribute("HorseCooldown") or 0) < H.Cooldown then
		return
	end
	player:SetAttribute("HorseCooldown", now)
	HorseService.Mount(player)
end

function HorseService.Init(services)
	S = services
end

function HorseService.Start()
	Net.Event("Horse").OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(player)
		riding[player] = nil
		lastToggle[player] = nil
	end)
	-- personaggio nuovo (morte, rinascita): il cavallo è sparito con il vecchio corpo
	S.PlayerService.CharacterReady:Connect(function(player)
		if riding[player] then
			riding[player] = nil
			player:SetAttribute("Riding", false)
		end
	end)
	S.PlayerService.Died:Connect(function(player)
		HorseService.Dismount(player, true)
	end)
	-- sicurezza: se il cavaliere entra in acqua profonda o si trasforma, scende
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player, ride in riding do
				local root = Util.GetRoot(player.Character)
				local state = S.PlayerService.GetState(player)
				if not root or not ride.Model.Parent or state.Transformed or state.GrabbedBy or ride.Humanoid.SeatPart then
					HorseService.Dismount(player, true)
				elseif root.Position.Y < W.WaterY - 1 and W.IsOpenSea(root.Position) then
					HorseService.Dismount(player)
					S.EventService.Notify(player, "Il cavallo non sa nuotare in mare aperto!", "Info", 2.5)
				end
			end
		end
	end)
end

return HorseService
