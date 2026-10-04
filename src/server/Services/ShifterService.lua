--[[
	ShifterService - la trasformazione in gigante
	Tasto T: un fulmine giallo cade dal cielo, esplode il vapore e il personaggio
	diventa un gigante (Model:ScaleTo) con l'aspetto del siero iniettato.
	In forma di gigante: clic sinistro = pugno, Z/X/C/V = abilità del siero.
	L'energia del gigante cala nel tempo: a zero torni umano.
	Se la tua "nuca" viene distrutta (salute del gigante a zero) vieni espulso.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Lib.Util)
local Net = require(Shared.Lib.Net)
local Serums = require(Shared.Data.Serums)
local Bloodlines = require(Shared.Data.Bloodlines)
local MeshTitan = require(Shared.Anim.MeshTitan)

local ShifterService = {}
local S
local rng = Random.new()
local data: { [Player]: any } = {}

local BODY_PARTS = { "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }

local function getData(player: Player)
	local d = data[player]
	if not d then
		d = { Energy = 0, MaxEnergy = 0, ReadyAt = 0, Cooldowns = {}, InvulnUntil = 0, HardenUntil = 0, HardenAmount = 0, BuffUntil = 0, BuffAmount = 0, Store = nil, Transforming = false }
		data[player] = d
	end
	return d
end

local function serumOf(player: Player)
	local profile = S.DataService.Get(player)
	return profile and Serums.Get(profile.Serum), profile
end

local function maxEnergyFor(player: Player): number
	local serum = serumOf(player)
	if not serum then
		return 0
	end
	local stats = S.PlayerService.Stats(player)
	return serum.Energy * stats.TitanEnergyMult
end

local function syncEnergy(player: Player)
	local d = getData(player)
	player:SetAttribute("TitanEnergy", math.floor(d.Energy))
	player:SetAttribute("TitanEnergyMax", math.floor(d.MaxEnergy))
end

function ShifterService.ResetEnergy(player: Player)
	local d = getData(player)
	d.MaxEnergy = maxEnergyFor(player)
	d.Energy = d.MaxEnergy
	syncEnergy(player)
end

function ShifterService.IsInvulnerable(player: Player): boolean
	local d = data[player]
	return d ~= nil and os.clock() < d.InvulnUntil
end

function ShifterService.DamageReduction(player: Player): number
	local d = data[player]
	if not d then
		return 0
	end
	local reduction = 0
	if os.clock() < d.HardenUntil then
		reduction += d.HardenAmount
	end
	local serum = serumOf(player)
	if serum and serum.Id == "SieroBastione" then
		reduction += 0.25
	end
	return math.min(0.85, reduction)
end

-- ASPETTO DELLA FORMA DI GIGANTE ---------------------------------------------------------------

local function weldPart(folder: Instance, parent: BasePart, name: string, size: Vector3, color: Color3, offset: CFrame, props)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = parent.CFrame * offset
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	if props then
		for k, v in props do
			if k ~= "Block" then
				(part :: any)[k] = v
			end
		end
	end
	if not (props and props.Block) then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = part
	weld.Parent = part
	part.Parent = folder
	return part
end

local function decorate(character: Model, serum)
	local folder = Instance.new("Folder")
	folder.Name = "FormaGigante"
	folder.Parent = character
	local head = character:FindFirstChild("Head") :: BasePart?
	local torso = character:FindFirstChild("UpperTorso") :: BasePart?
	if not head or not torso then
		return folder
	end
	-- aspetto con modello 3D importato (es. Gigante della Furia): il corpo R15 viene rivestito
	if MeshTitan.Has(serum.Look) then
		local ok, applied = pcall(MeshTitan.SkinCharacter, character, serum.Look, folder)
		if ok and applied then
			folder:SetAttribute("MeshSkin", true)
			return folder
		end
		warn("[ShifterService] Rivestimento 3D non riuscito: " .. tostring(applied))
		folder:ClearAllChildren()
	end
	local h = head.Size
	local t = torso.Size
	local look = serum.Look
	local skin = serum.SkinColor
	local hair = serum.HairColor
	-- capelli
	if look ~= "Vulcano" then
		weldPart(folder, head, "Capelli", h * Vector3.new(1.1, 0.6, 1.12), hair, CFrame.new(0, h.Y * 0.3, h.Z * 0.04), { Material = Enum.Material.Fabric })
		if look == "Furia" or look == "Zanna" or look == "Forgia" then
			weldPart(folder, head, "CapelliLunghi", h * Vector3.new(1.05, 1.1, 0.4), hair, CFrame.new(0, -h.Y * 0.2, h.Z * 0.42), { Material = Enum.Material.Fabric })
		end
	end
	-- occhi e denti scoperti (sguardo da gigante)
	local eyeColor = if look == "Furia" then Color3.fromRGB(120, 255, 170) elseif look == "Forgia" then Color3.fromRGB(170, 230, 255) else Color3.fromRGB(250, 248, 240)
	for _, side in { -1, 1 } do
		weldPart(folder, head, "Occhio", Vector3.new(h.X * 0.18, h.Y * 0.12, h.Z * 0.1), eyeColor, CFrame.new(side * h.X * 0.2, h.Y * 0.1, -h.Z * 0.5), { Material = Enum.Material.Neon })
	end
	weldPart(folder, head, "Denti", Vector3.new(h.X * 0.7, h.Y * 0.1, h.Z * 0.1), Color3.fromRGB(244, 238, 222), CFrame.new(0, -h.Y * 0.22, -h.Z * 0.5), { Block = true })
	weldPart(folder, head, "Bocca", Vector3.new(h.X * 0.75, h.Y * 0.18, h.Z * 0.08), Color3.fromRGB(70, 22, 24), CFrame.new(0, -h.Y * 0.22, -h.Z * 0.47))
	for _, side in { -1, 1 } do
		weldPart(folder, head, "Orecchio", Vector3.new(h.X * 0.12, h.Y * (if look == "Furia" then 0.45 else 0.3), h.Z * 0.2), skin, CFrame.new(side * h.X * 0.52, h.Y * 0.05, 0))
	end
	-- muscoli
	local muscle = if look == "Vulcano" then Color3.fromRGB(222, 140, 116) else Color3.new(skin.R * 0.85, skin.G * 0.82, skin.B * 0.8)
	for _, side in { -1, 1 } do
		weldPart(folder, torso, "Pettorale", Vector3.new(t.X * 0.46, t.Y * 0.38, t.Z * 0.5), muscle, CFrame.new(side * t.X * 0.22, t.Y * 0.18, -t.Z * 0.28))
	end
	if look == "Vulcano" then
		for i = 0, 3 do
			weldPart(folder, torso, "Fibra", Vector3.new(t.X * 0.08, t.Y * 0.95, t.Z * 0.2), Color3.fromRGB(230, 150, 126), CFrame.new((i - 1.5) * t.X * 0.2, 0, -t.Z * 0.48))
		end
	end
	local plate = Color3.fromRGB(232, 222, 202)
	if look == "Bastione" or look == "Destriero" then
		weldPart(folder, torso, "Corazza", Vector3.new(t.X * 1.05, t.Y * 0.7, t.Z * 0.3), plate, CFrame.new(0, t.Y * 0.1, -t.Z * 0.45), { Block = true, Material = Enum.Material.Marble })
		weldPart(folder, head, "Elmo", Vector3.new(h.X * 1.06, h.Y * 0.45, h.Z * 1.06), plate, CFrame.new(0, h.Y * 0.3, 0), { Block = true, Material = Enum.Material.Marble })
		for _, armName in { "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftLowerLeg", "RightLowerLeg" } do
			local arm = character:FindFirstChild(armName) :: BasePart?
			if arm then
				weldPart(folder, arm, "Placca", arm.Size * Vector3.new(1.15, 0.8, 1.15), plate, CFrame.new(), { Block = true, Material = Enum.Material.Marble })
			end
		end
	end
	if look == "Destriero" then
		weldPart(folder, torso, "Cannone", Vector3.new(t.X * 1.1, t.Z * 0.3, t.Z * 0.3), Color3.fromRGB(70, 74, 80), CFrame.new(t.X * 0.2, t.Y * 0.4, t.Z * 0.6) * CFrame.Angles(0, math.rad(90), 0), { Block = true, Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal })
	end
	if look == "Fauno" then
		for i = 1, 6 do
			local s = t.X * rng:NextNumber(0.45, 0.65)
			weldPart(folder, torso, "Pelo", Vector3.new(s, s, s), hair, CFrame.new(rng:NextNumber(-0.35, 0.35) * t.X, rng:NextNumber(-0.4, 0.45) * t.Y, rng:NextNumber(-0.2, 0.3) * t.Z), { Block = true, Shape = Enum.PartType.Ball, Material = Enum.Material.Fabric })
		end
	end
	if look == "Zanna" then
		weldPart(folder, head, "Maschera", Vector3.new(h.X * 0.98, h.Y * 0.32, h.Z * 0.16), Color3.fromRGB(240, 234, 222), CFrame.new(0, h.Y * 0.16, -h.Z * 0.5), { Block = true, Material = Enum.Material.Marble })
	end
	if look == "Forgia" or look == "Cacciatrice" then
		local crystal = Color3.fromRGB(170, 230, 255)
		for i = 1, 3 do
			weldPart(folder, torso, "Cristallo", Vector3.new(t.X * 0.15, t.Y * 0.45, t.X * 0.15), crystal, CFrame.new((i - 2) * t.X * 0.3, t.Y * 0.2, t.Z * 0.55) * CFrame.Angles(0, 0, math.rad((i - 2) * 25)), { Block = true, Material = Enum.Material.Glass, Transparency = 0.2 })
		end
	end
	if look == "Vulcano" then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(245, 240, 235))
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
		emitter.Size = NumberSequence.new(t.X * 0.4, t.X * 1.4)
		emitter.Lifetime = NumberRange.new(2, 3.5)
		emitter.Rate = 6
		emitter.Speed = NumberRange.new(t.X * 0.2, t.X * 0.5)
		emitter.SpreadAngle = Vector2.new(50, 50)
		emitter.Parent = torso
		emitter.Name = "VaporeForma"
	end
	return folder
end

-- TRASFORMAZIONE -------------------------------------------------------------------------------

local function holdingFolder(player: Player): Folder
	local name = "Custodia_" .. player.UserId
	local existing = ServerStorage:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = ServerStorage
	return folder
end

function ShifterService.Transform(player: Player): (boolean, string?)
	local state0 = S.PlayerService.GetState(player)
	if not Config.Serums.Available and not state0.Transformed and player:GetAttribute("Admin") ~= true then
		return false, Config.Serums.ComingSoonText
	end
	local serum, profile = serumOf(player)
	if not serum or not profile then
		return false, "Non hai iniettato nessun siero."
	end
	local state = S.PlayerService.GetState(player)
	local d = getData(player)
	if state.Transformed then
		ShifterService.Revert(player, "Volontario")
		return true, nil
	end
	if d.Transforming then
		return false, nil
	end
	if state.GrabbedBy then
		return false, "Non puoi trasformarti mentre un gigante ti tiene!"
	end
	local now = os.clock()
	if now < d.ReadyAt then
		return false, ("Devi recuperare le forze: %d s"):format(math.ceil(d.ReadyAt - now))
	end
	if d.MaxEnergy <= 0 then
		ShifterService.ResetEnergy(player)
	end
	if d.Energy < d.MaxEnergy * Config.Serums.MinEnergyToTransform then
		return false, "Energia del gigante insufficiente."
	end
	local character = player.Character
	local humanoid = Util.GetHumanoid(character)
	local root = Util.GetRoot(character)
	if not character or not humanoid or not root or humanoid.Health <= 0 then
		return false, nil
	end
	d.Transforming = true
	S.EventService.Effect("TransformStart", { Character = character, Height = serum.Height, Look = serum.Look }, root.Position, 1500)
	task.wait(0.95)
	if not character.Parent or humanoid.Health <= 0 or state.GrabbedBy then
		d.Transforming = false
		return false, nil
	end

	-- salva l'aspetto originale
	local store = {
		Accessories = {},
		Clothing = {},
		Colors = {},
		MaxHealth = humanoid.MaxHealth,
		HealthFrac = humanoid.Health / math.max(1, humanoid.MaxHealth),
		WalkSpeed = humanoid.WalkSpeed,
		JumpHeight = humanoid.JumpHeight,
		HipHeight = humanoid.HipHeight,
		Face = nil,
	}
	local holder = holdingFolder(player)
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") then
			table.insert(store.Accessories, child)
			child.Parent = holder
		elseif child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			table.insert(store.Clothing, child)
			child.Parent = holder
		end
	end
	S.PlayerService.GetState(player).Transformed = true
	local outfit = character:FindFirstChild("Equipaggiamento")
	if outfit then
		outfit:Destroy()
	end
	for _, name in BODY_PARTS do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			store.Colors[part] = part.Color
			part.Color = serum.SkinColor
		end
	end
	local head = character:FindFirstChild("Head")
	local face = head and head:FindFirstChildOfClass("Decal")
	if face then
		store.Face = face
		store.FaceTransparency = face.Transparency
		face.Transparency = 1
	end

	-- scala
	local height = character:GetExtentsSize().Y
	local scale = math.clamp(serum.Height / math.max(height, 1), 1.5, 60)
	local hipBefore = humanoid.HipHeight
	local ok, err = pcall(function()
		character:ScaleTo(scale)
	end)
	if not ok then
		warn("[ShifterService] ScaleTo fallito: " .. tostring(err))
	end
	if math.abs(humanoid.HipHeight - hipBefore) < 0.01 and hipBefore > 0 then
		humanoid.HipHeight = hipBefore * scale
	end
	store.Scale = scale
	d.Store = store
	local form = decorate(character, serum)
	if form:GetAttribute("MeshSkin") then
		-- il corpo R15 resta (muove i pezzi del modello) ma diventa invisibile
		store.Transparency = {}
		for _, name in BODY_PARTS do
			local part = character:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				store.Transparency[part] = part.Transparency
				part.Transparency = 1
			end
		end
	end

	local stats = S.PlayerService.Stats(player)
	local titanHP = math.floor(stats.MaxHealth * serum.Health * (1 + (profile.Stats.Gigante or 0) * 0.002))
	humanoid.MaxHealth = titanHP
	humanoid.Health = titanHP
	humanoid.WalkSpeed = serum.Speed
	humanoid.JumpHeight = if serum.Height > 100 then 0 else math.min(40, 7 * math.sqrt(scale))
	S.PlayerService.SetCollisionGroup(character, Config.CollisionGroups.TitanForm)
	player:SetAttribute("Transformed", true)
	player:SetAttribute("TitanHeight", serum.Height)
	d.Transforming = false
	d.Cooldowns = {}
	d.Mastery = profile.SerumMastery[serum.Id] or 0
	Net.Event("TitanForm"):FireClient(player, { On = true, Serum = serum.Id, Height = serum.Height })
	S.EventService.Effect("TransformBurst", { Position = root.Position, Height = serum.Height, Look = serum.Look }, root.Position, 1500)
	-- l'onda d'urto della trasformazione spinge via i giganti vicini
	local results = S.TitanService.DamageInRadius(root.Position, serum.Height * 0.6, serum.Damage * stats.TitanPower, player, {})
	for _, r in results do
		S.TitanService.Stun(r.Titan, 1.5)
	end
	return true, nil
end

function ShifterService.Revert(player: Player, reason: string?)
	local state = S.PlayerService.GetState(player)
	local d = getData(player)
	if not state.Transformed then
		return
	end
	local character = player.Character
	local humanoid = Util.GetHumanoid(character)
	local root = Util.GetRoot(character)
	local store = d.Store
	state.Transformed = false
	player:SetAttribute("Transformed", false)
	d.ReadyAt = os.clock() + Config.Serums.TransformCooldown
	d.InvulnUntil = 0
	d.HardenUntil = 0
	if root then
		S.EventService.Effect("TransformEnd", { Position = root.Position, Height = player:GetAttribute("TitanHeight") or 30 }, root.Position, 1200)
	end
	if character then
		local folder = character:FindFirstChild("FormaGigante")
		if folder then
			folder:Destroy()
		end
		pcall(function()
			character:ScaleTo(1)
		end)
	end
	if humanoid and store then
		humanoid.HipHeight = store.HipHeight
		humanoid.WalkSpeed = store.WalkSpeed
		humanoid.JumpHeight = store.JumpHeight
		for part, color in store.Colors do
			if part.Parent then
				part.Color = color
			end
		end
		for part, transparency in store.Transparency or {} do
			if part.Parent then
				part.Transparency = transparency
			end
		end
		if store.Face and store.Face.Parent then
			store.Face.Transparency = store.FaceTransparency or 0
		end
		for _, clothing in store.Clothing do
			clothing.Parent = character
		end
		for _, accessory in store.Accessories do
			local weld = accessory:FindFirstChild("AccessoryWeld", true)
			if weld then
				weld:Destroy()
			end
			pcall(function()
				humanoid:AddAccessory(accessory)
			end)
		end
	end
	d.Store = nil
	if character then
		S.PlayerService.SetCollisionGroup(character, Config.CollisionGroups.Players)
	end
	S.PlayerService.Refresh(player, true)
	if humanoid and humanoid.Health > 0 then
		local frac = if reason == "Espulso" then 0.2 elseif store then store.HealthFrac else 1
		humanoid.Health = math.max(1, humanoid.MaxHealth * frac)
	end
	Net.Event("TitanForm"):FireClient(player, { On = false, Reason = reason })
	if reason == "Espulso" then
		S.EventService.Notify(player, "La tua nuca è stata squarciata! Sei stato espulso dal gigante.", "Errore", 4)
		S.PlayerService.Knockback(player, Vector3.new(0, 90, 0), 1.5)
	elseif reason == "Esausto" then
		S.EventService.Notify(player, "Energia esaurita: il corpo del gigante si dissolve nel vapore.", "Info", 4)
	end
end

-- ABILITÀ IN FORMA DI GIGANTE --------------------------------------------------------------------

local function titanDamage(player: Player, serum, mult: number): number
	local stats = S.PlayerService.Stats(player)
	local profile = S.DataService.Get(player)
	local d = getData(player)
	local level = profile and profile.Level or 1
	local damage = serum.Damage * stats.TitanPower * (1 + level * 0.012) * mult
	if os.clock() < d.BuffUntil then
		damage *= 1 + d.BuffAmount
	end
	-- Attacco: più sei ferito, più colpisci forte
	if serum.Id == "SieroFuria" then
		local humanoid = Util.GetHumanoid(player.Character)
		if humanoid then
			damage *= 1 + (1 - humanoid.Health / humanoid.MaxHealth) * 0.5
		end
	end
	return damage
end

local function hitArea(player: Player, center: Vector3, radius: number, damage: number, explosive: boolean?)
	local results = S.TitanService.DamageInRadius(center, radius, damage, player, { Explosive = explosive, ArmorBreak = true })
	local humans = S.EnemyService.DamageInRadius(center, radius, damage, player)
	local count = 0
	for _, r in results do
		Net.Event("DamageNumber"):FireClient(player, r.Position, math.floor(r.Result.Damage), if r.Result.Killed then "Nape" else "Titan")
		count += 1
	end
	for _, r in humans do
		Net.Event("DamageNumber"):FireClient(player, r.Position, math.floor(r.Result.Damage), "Titan")
		count += 1
	end
	return count
end

local function addMastery(player: Player, serum, amount: number)
	local profile = S.DataService.Get(player)
	if not profile then
		return
	end
	local current = profile.SerumMastery[serum.Id] or 0
	profile.SerumMastery[serum.Id] = math.min(Config.Serums.MaxMastery, current + amount)
	getData(player).Mastery = profile.SerumMastery[serum.Id]
	S.DataService.MarkDirty(player)
end

local function useSkill(player: Player, key: string, aim: Vector3?)
	local serum, profile = serumOf(player)
	local state = S.PlayerService.GetState(player)
	if not serum or not profile or not state.Transformed then
		return
	end
	local character = player.Character
	local root = Util.GetRoot(character)
	if not root then
		return
	end
	local skill = if key == "M1" then Serums.BasicAttack else serum.Skills[key]
	if not skill then
		return
	end
	local d = getData(player)
	local now = os.clock()
	if now < (d.Cooldowns[key] or 0) - 0.15 then
		return
	end
	local mastery = profile.SerumMastery[serum.Id] or 0
	if key ~= "M1" and mastery < (skill.Mastery or 0) then
		S.EventService.Notify(player, ("Serve maestria %d del siero."):format(skill.Mastery), "Errore", 2)
		return
	end
	if skill.RequiresRoyal then
		local bloodline = Bloodlines.Get(profile.Bloodline)
		if not bloodline.FullMastery and mastery < Config.Serums.MaxMastery then
			S.EventService.Notify(player, "IL BOATO richiede la Stirpe Reale o la maestria massima.", "Errore", 3)
			return
		end
	end
	local cost = skill.Energy or 0
	if d.Energy < cost then
		S.EventService.Notify(player, "Energia insufficiente.", "Errore", 1.5)
		return
	end
	d.Energy -= cost
	d.Cooldowns[key] = now + (skill.Cooldown or 1)
	syncEnergy(player)

	local H = serum.Height
	local look = root.CFrame.LookVector
	local flatLook = Util.SafeUnit(Util.Flat(look))
	local feet = root.Position - Vector3.new(0, H * 0.45, 0)
	local target = aim
	if typeof(target) ~= "Vector3" or (target - root.Position).Magnitude > (skill.Range or H * 3) + H then
		target = root.Position + flatLook * math.min(skill.Range or H, H * 3)
	end
	local kind = skill.Kind
	local radius = (skill.Radius or 0.4) * H
	local damage = titanDamage(player, serum, skill.Damage or 1)
	S.EventService.Effect("TitanSkill", { Character = character, Kind = kind, Key = key, Position = target, Radius = radius, Height = H, Look = serum.Look }, root.Position, 1500)
	local hits = 0

	if kind == "Punch" or kind == "Bite" or kind == "Kick" then
		task.delay(skill.HitDelay or 0.22, function()
			local r = Util.GetRoot(player.Character)
			if state.Transformed and r then
				-- il colpo parte da dove si trova il gigante al momento dell'impatto
				local look2 = Util.SafeUnit(Util.Flat(r.CFrame.LookVector), flatLook)
				local center = if skill.AroundSelf then r.Position else r.Position + look2 * radius * 0.9
				local n = hitArea(player, center, radius, damage)
				if n > 0 then
					addMastery(player, serum, 1)
				end
			end
		end)
		return
	elseif kind == "Stomp" then
		hits = hitArea(player, feet + flatLook * radius * 0.3, radius, damage)
	elseif kind == "Flurry" then
		for i = 1, skill.Count or 5 do
			task.delay(i * 0.14, function()
				if state.Transformed then
					local r = Util.GetRoot(player.Character)
					if r then
						hitArea(player, r.Position + Util.SafeUnit(Util.Flat(r.CFrame.LookVector)) * radius * 0.8, radius, damage)
					end
				end
			end)
		end
		hits = 1
	elseif kind == "Charge" or kind == "Leap" then
		local dir = Util.SafeUnit(Util.Flat(target - root.Position), flatLook)
		local distance = math.min(skill.Range or H * 3, (target - root.Position).Magnitude + 10)
		Net.Event("TitanForm"):FireClient(player, { Dash = dir * (distance / 0.7) + (if kind == "Leap" then Vector3.new(0, H * 1.2, 0) else Vector3.zero), Duration = 0.7 })
		local hitSet = {}
		for i = 1, 8 do
			task.delay(i * 0.1, function()
				local r = Util.GetRoot(player.Character)
				if not r or not state.Transformed then
					return
				end
				if kind == "Charge" or i == 8 then
					for _, result in S.TitanService.DamageInRadius(r.Position, radius, damage, player, { ArmorBreak = true }) do
						if not hitSet[result.Titan] then
							hitSet[result.Titan] = true
							Net.Event("DamageNumber"):FireClient(player, result.Position, math.floor(result.Result.Damage), "Titan")
						end
					end
					S.EnemyService.DamageInRadius(r.Position, radius, damage, player)
				end
				if i == 8 and skill.Explode then
					hitArea(player, r.Position, radius * 2, damage * 0.6, true)
					S.EventService.Effect("Explosion", { Position = r.Position, Radius = radius * 2, Big = true }, r.Position, 1500)
				end
			end)
		end
		hits = 1
	elseif kind == "Roar" or kind == "Dominio" then
		local area = (skill.Radius or 2) * H
		if kind == "Dominio" then
			local frozen = S.TitanService.FreezeInRadius(root.Position, area, skill.Duration or 8)
			S.EventService.Notify(player, ("Il tuo urlo ha immobilizzato %d giganti!"):format(frozen), "Raro", 3)
		else
			for _, r in S.TitanService.DamageInRadius(root.Position, area, damage, player, {}) do
				S.TitanService.Stun(r.Titan, skill.Duration or 3)
			end
		end
		hits = 1
	elseif kind == "Harden" then
		d.HardenUntil = now + (skill.Duration or 6)
		d.HardenAmount = skill.Amount or 0.5
	elseif kind == "Crystal" then
		d.InvulnUntil = now + (skill.Duration or 4)
		S.PlayerService.Heal(player, skill.Amount or 0.3)
		Net.Event("TitanForm"):FireClient(player, { Freeze = skill.Duration or 4 })
	elseif kind == "FutureSight" then
		d.InvulnUntil = now + (skill.Duration or 6)
		d.BuffUntil = now + (skill.Duration or 6)
		d.BuffAmount = skill.Amount or 0.8
	elseif kind == "Frenzy" or kind == "SpeedBoost" then
		local humanoid = Util.GetHumanoid(character)
		local duration = skill.Duration or 8
		if kind == "Frenzy" then
			d.BuffUntil = now + duration
			d.BuffAmount = skill.Amount or 0.5
		end
		if humanoid then
			humanoid.WalkSpeed = serum.Speed * (1 + (skill.Amount or 0.5))
			task.delay(duration, function()
				if humanoid.Parent and state.Transformed then
					humanoid.WalkSpeed = serum.Speed
				end
			end)
		end
	elseif kind == "Summon" then
		S.TitanService.SpawnAllies(player, skill.Count or 3, root.Position + flatLook * H * 0.6, skill.Duration or 18, profile.Level)
	elseif kind == "Rumbling" then
		S.TitanService.SpawnRumbling(player, root.Position, flatLook, skill.Count or 5, skill.Duration or 10, profile.Level, damage)
		S.EventService.Announce("IL BOATO", player.DisplayName .. " ha risvegliato i Vulcani delle Mura!", "Pericolo")
	elseif kind == "RockThrow" or kind == "Cannon" then
		local flight = if kind == "Cannon" then 0.7 else 1.1
		local from = root.Position + Vector3.new(0, H * 0.3, 0)
		S.EventService.Effect("Projectile", { From = from, To = target, Time = flight, Kind = if kind == "Cannon" then "Cannon" else "Rock", Size = if skill.Big then H * 0.25 else H * 0.1 }, root.Position, 1500)
		task.delay(flight, function()
			local n = hitArea(player, target, radius, damage, kind == "Cannon")
			S.EventService.Effect("Impact", { Position = target, Radius = radius, Kind = if kind == "Cannon" then "Explosion" else "Rock" }, target, 1200)
			if n > 0 then
				addMastery(player, serum, 1)
			end
		end)
		return
	elseif kind == "RockBarrage" then
		local from = root.Position + Vector3.new(0, H * 0.3, 0)
		for i = 1, skill.Count or 8 do
			local point = target + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * radius * 1.5
			local flight = 0.9 + i * 0.07
			S.EventService.Effect("Projectile", { From = from, To = point, Time = flight, Kind = "Rock", Size = H * 0.06 }, root.Position, 1500)
			task.delay(flight, function()
				hitArea(player, point, radius * 0.6, damage)
				S.EventService.Effect("Impact", { Position = point, Radius = radius * 0.6, Kind = "Rock" }, point, 1200)
			end)
		end
		hits = 1
	elseif kind == "Spikes" then
		local dir = Util.SafeUnit(Util.Flat(target - root.Position), flatLook)
		local length = skill.Range or H * 3
		for i = 1, 10 do
			local point = feet + dir * (length * i / 10)
			task.delay(i * 0.05, function()
				S.EventService.Effect("Spike", { Position = point, Height = H * 0.3, Delay = 0 }, point, 1200)
				hitArea(player, point, math.max(radius, 10), damage * 0.5)
			end)
		end
		hits = 1
	elseif kind == "SpikeArena" then
		for i = 1, 18 do
			local a = i / 18 * math.pi * 2
			local point = feet + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * 0.85
			S.EventService.Effect("Spike", { Position = point, Height = H * 0.35, Delay = 0 }, point, 1200)
		end
		hits = hitArea(player, feet, radius, damage)
	elseif kind == "Steam" then
		local duration = skill.Duration or 5
		for i = 1, math.floor(duration * 2) do
			task.delay(i * 0.5, function()
				local r = Util.GetRoot(player.Character)
				if r and state.Transformed then
					hitArea(player, r.Position, radius, damage)
				end
			end)
		end
		hits = 1
	elseif kind == "Explosion" then
		hits = hitArea(player, root.Position, radius, damage, true)
		S.EventService.Effect("Explosion", { Position = root.Position, Radius = radius, Big = true }, root.Position, 2500)
	end
	if hits > 0 then
		addMastery(player, serum, 1)
	end
end

function ShifterService.Init(services)
	S = services
end

function ShifterService.Start()
	Net.Event("Transform").OnServerEvent:Connect(function(player)
		local ok, message = ShifterService.Transform(player)
		if not ok and message then
			S.EventService.Notify(player, message, "Errore", 2.5)
		end
	end)
	Net.Event("TitanSkill").OnServerEvent:Connect(function(player, key, aim)
		if type(key) == "string" then
			useSkill(player, key, if typeof(aim) == "Vector3" then aim else nil)
		end
	end)
	S.PlayerService.Died:Connect(function(player)
		local state = S.PlayerService.GetState(player)
		if state.Transformed then
			state.Transformed = false
			local d = getData(player)
			d.Store = nil
			player:SetAttribute("Transformed", false)
			Net.Event("TitanForm"):FireClient(player, { On = false, Reason = "Morto" })
		end
	end)
	S.DataService.Loaded:Connect(function(player)
		task.defer(ShifterService.ResetEnergy, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		data[player] = nil
		local folder = ServerStorage:FindFirstChild("Custodia_" .. player.UserId)
		if folder then
			folder:Destroy()
		end
	end)
	-- consumo e recupero dell'energia
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local d = data[player]
				if d then
					local state = S.PlayerService.GetState(player)
					local maxEnergy = maxEnergyFor(player)
					if maxEnergy ~= d.MaxEnergy then
						d.MaxEnergy = maxEnergy
					end
					if state.Transformed then
						d.Energy -= 0.5
						if d.Energy <= 0 then
							d.Energy = 0
							ShifterService.Revert(player, "Esausto")
						end
					elseif d.MaxEnergy > 0 then
						d.Energy = math.min(d.MaxEnergy, d.Energy + d.MaxEnergy * 0.015)
					end
					syncEnergy(player)
				end
			end
		end
	end)
end

return ShifterService
