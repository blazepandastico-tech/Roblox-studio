--[[
	SerumService - i Sieri Perduti
	NOTA: finché Config.Serums.Available è false i sieri non si possono ottenere né usare
	(arrivano con il prossimo aggiornamento); i Frammenti di Siero invece si raccolgono già.
	Come si ottengono (tutti difficilissimi):
	  1) Casse "Siero Perduto" che appaiono a caso nel mondo (circa una ogni 2 ore per server)
	  2) Drop rarissimi dai boss mutaforma
	  3) Il Mercante Velato a Aurion (merce che cambia ogni 4 ore, uguale in tutti i server)
	  4) Sintesi al Laboratorio con centinaia di Frammenti di Siero
	Iniettare un siero dà il potere di trasformarsi (tasto T). Un solo potere alla volta.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Lib.Util)
local Net = require(Shared.Lib.Net)
local Serums = require(Shared.Data.Serums)
local Zones = require(Shared.Data.Zones)
local Items = require(Shared.Data.Items)

local SerumService = {}
local S
local rng = Random.new()

local activeChest: BasePart? = nil

-- Dai un siero (in valigetta, da iniettare)
function SerumService.IsAvailable(): boolean
	return Config.Serums.Available == true
end

function SerumService.GiveSerum(player: Player, serumId: string, source: string?)
	local profile = S.DataService.Get(player)
	local serum = Serums.Get(serumId)
	if not profile or not serum or not SerumService.IsAvailable() then
		return false
	end
	profile.StoredSerums[serumId] = (profile.StoredSerums[serumId] or 0) + 1
	S.DataService.MarkDirty(player)
	local rarity = Items.Rarities[serum.Rarity]
	S.EventService.AnnounceTo(player, "HAI OTTENUTO UN SIERO!", serum.Name .. " (" .. (rarity and rarity.Label or serum.Rarity) .. ")", "Siero")
	if source ~= "Acquisto" then
		S.EventService.NotifyAll(("%s ha trovato il %s!"):format(player.DisplayName, serum.Name), "Raro", 7)
	end
	local root = Util.GetRoot(player.Character)
	if root then
		S.EventService.Effect("SerumObtained", { Character = player.Character, Color = rarity and rarity.Color }, root.Position, 400)
	end
	return true
end

-- Ricompense extra all'uccisione di un gigante: frammenti e (per i boss) sieri
function SerumService.RollKillRewards(player: Player, t)
	local stats = S.PlayerService.Stats(player)
	local bonus = 1 + (stats.FragmentChance or 0)
	if t.Kind == "Boss" then
		local def = t.Def
		if def.Fragments then
			local n = rng:NextInteger(def.Fragments[1], def.Fragments[2])
			S.InventoryService.Give(player, "FrammentoSiero", n)
			S.EventService.Notify(player, ("+%d Frammenti di Siero"):format(n), "Raro", 5)
		end
		if def.Serum and SerumService.IsAvailable() and rng:NextNumber() < (def.SerumChance or 0) * bonus then
			SerumService.GiveSerum(player, def.Serum, "Boss")
		end
		return
	end
	local chance = if t.Abnormal then Config.Serums.FragmentChanceAbnormal else Config.Serums.FragmentChanceNormal
	if t.Invasion then
		chance *= 2
	end
	if rng:NextNumber() < chance * bonus then
		S.InventoryService.Give(player, "FrammentoSiero", 1)
		S.EventService.Notify(player, "Hai trovato un Frammento di Siero!", "Raro", 4)
	end
end

function SerumService.Inject(player: Player, serumId: string): (boolean, string?)
	local profile = S.DataService.Get(player)
	local serum = Serums.Get(serumId)
	if not profile or not serum then
		return false, "Siero sconosciuto."
	end
	if not SerumService.IsAvailable() then
		return false, Config.Serums.ComingSoonText
	end
	if (profile.StoredSerums[serumId] or 0) <= 0 then
		return false, "Non possiedi questo siero."
	end
	if profile.Level < serum.LevelReq then
		return false, ("Il tuo corpo non reggerebbe: serve il livello %d."):format(serum.LevelReq)
	end
	local state = S.PlayerService.GetState(player)
	if state.Transformed or state.GrabbedBy then
		return false, "Non ora!"
	end
	local root = Util.GetRoot(player.Character)
	if not root then
		return false, nil
	end
	profile.StoredSerums[serumId] -= 1
	if profile.StoredSerums[serumId] <= 0 then
		profile.StoredSerums[serumId] = nil
	end
	local old = Serums.Get(profile.Serum)
	profile.Serum = serumId
	profile.SerumMastery[serumId] = profile.SerumMastery[serumId] or 0
	S.DataService.MarkDirty(player)
	S.EventService.Effect("Inject", { Character = player.Character, Color = Items.RarityColor(serum.Rarity) }, root.Position, 500)
	task.delay(1.2, function()
		if player.Parent then
			S.EventService.AnnounceTo(player, "Potere del " .. serum.TitanName, "Premi T per trasformarti. " .. serum.Passive, "Siero")
			if old then
				S.EventService.Notify(player, "Il potere del " .. old.TitanName .. " è svanito dal tuo corpo.", "Info", 5)
			end
		end
	end)
	if S.ShifterService then
		S.ShifterService.ResetEnergy(player)
	end
	return true, nil
end

-- CASSE "SIERO PERDUTO" NEL MONDO ------------------------------------------------------------

local function removeChest()
	if activeChest then
		local model = activeChest.Parent
		if model and model:IsA("Model") then
			model:Destroy()
		else
			activeChest:Destroy()
		end
		activeChest = nil
	end
end

local function spawnChest()
	local candidates = {}
	for _, zone in Zones.List do
		if not zone.Safe and not zone.Underground then
			table.insert(candidates, zone)
		end
	end
	if #candidates == 0 then
		return
	end
	local zone = candidates[rng:NextInteger(1, #candidates)]
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(0, zone.Radius * 0.9)
	local pos = zone.Center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(pos + Vector3.new(0, 400, 0), Vector3.new(0, -600, 0), params)
	if hit then
		pos = hit.Position
	end

	local model = Instance.new("Model")
	model.Name = "CassaSieroPerduto"
	local case = Instance.new("Part")
	case.Name = "Valigetta"
	case.Size = Vector3.new(4, 2, 2.6)
	case.CFrame = CFrame.new(pos + Vector3.new(0, 1.2, 0))
	case.Anchored = true
	case.CanCollide = true
	case.Material = Enum.Material.Leather
	case.Color = Color3.fromRGB(70, 40, 30)
	case.Parent = model
	local lid = Instance.new("Part")
	lid.Name = "Siringa"
	lid.Shape = Enum.PartType.Cylinder
	lid.Size = Vector3.new(2.4, 0.5, 0.5)
	lid.CFrame = CFrame.new(pos + Vector3.new(0, 3.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	lid.Anchored = true
	lid.CanCollide = false
	lid.Material = Enum.Material.Neon
	lid.Color = Color3.fromRGB(120, 255, 150)
	lid.Parent = model
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(120, 255, 150)
	light.Range = 30
	light.Brightness = 3
	light.Parent = lid
	local beam = Instance.new("ParticleEmitter")
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.Color = ColorSequence.new(Color3.fromRGB(150, 255, 170))
	beam.LightEmission = 1
	beam.Size = NumberSequence.new(0.6, 0)
	beam.Lifetime = NumberRange.new(1.5, 2.5)
	beam.Rate = 25
	beam.Speed = NumberRange.new(6, 12)
	beam.SpreadAngle = Vector2.new(15, 15)
	beam.Acceleration = Vector3.new(0, 10, 0)
	beam.Parent = lid
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Raccogli il Siero"
	prompt.ObjectText = "Siero Perduto"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = case
	model.PrimaryPart = case
	model.Parent = workspace:FindFirstChild(Config.Folders.Interactive) or workspace
	CollectionService:AddTag(model, Config.Tags.SerumChest)
	activeChest = case

	S.EventService.Announce("Un Siero Perduto è stato avvistato!", "Si trova da qualche parte in: " .. zone.Name .. ". Sbrigati!", "Siero")

	prompt.Triggered:Connect(function(player)
		if activeChest ~= case then
			return
		end
		local profile = S.DataService.Get(player)
		if not profile then
			return
		end
		removeChest()
		local pickEntry = Util.WeightedPick(Serums.WorldTable(), rng)
		local serumId = pickEntry and pickEntry.Id or Serums.Order[1]
		SerumService.GiveSerum(player, serumId, "Mondo")
	end)

	task.delay(Config.Serums.WorldSpawnDuration, function()
		if activeChest == case then
			removeChest()
			S.EventService.Announce("Il Siero Perduto è svanito...", "Qualcun altro deve averlo trovato prima di voi.", "Info")
		end
	end)
end

-- MERCANTE DI SIERI (merce uguale su tutti i server grazie al seme orario) -------------------------

function SerumService.DealerStock(): ({ string }, number)
	local rotation = Config.Serums.DealerRotation
	local index = os.time() // rotation
	local random = Random.new(index * 7919 + 13)
	local stock = {}
	for _, id in Serums.Order do
		if random:NextNumber() < Serums.List[id].DealerChance then
			table.insert(stock, id)
		end
	end
	if #stock == 0 then
		table.insert(stock, Serums.Order[1])
	end
	local endsAt = (index + 1) * rotation
	return stock, endsAt
end

function SerumService.BuyFromDealer(player: Player, serumId: string): (boolean, string?)
	local stock = SerumService.DealerStock()
	if not SerumService.IsAvailable() then
		return false, Config.Serums.ComingSoonText
	end
	if not table.find(stock, serumId) then
		return false, "Il Mercante non ha questo siero, adesso."
	end
	local serum = Serums.Get(serumId)
	local profile = S.DataService.Get(player)
	if not serum or not profile then
		return false, nil
	end
	if profile.Level < serum.LevelReq then
		return false, ("Il Mercante non vende a chi è sotto il livello %d."):format(serum.LevelReq)
	end
	if not S.PlayerService.SpendGold(player, serum.Price) then
		return false, ("Servono %s oro."):format(Util.FormatNumber(serum.Price))
	end
	SerumService.GiveSerum(player, serumId, "Acquisto")
	return true, nil
end

function SerumService.Init(services)
	S = services
end

function SerumService.Start()
	Net.Event("InjectSerum").OnServerEvent:Connect(function(player, serumId)
		if type(serumId) ~= "string" then
			return
		end
		local ok, message = SerumService.Inject(player, serumId)
		if not ok and message then
			S.EventService.Notify(player, message, "Errore", 3)
		end
	end)
	task.spawn(function()
		S.WorldBuilder.WaitReady()
		while true do
			task.wait(Config.Serums.WorldSpawnInterval)
			if SerumService.IsAvailable() and not activeChest and #Players:GetPlayers() > 0 and rng:NextNumber() < Config.Serums.WorldSpawnChance then
				local ok, err = pcall(spawnChest)
				if not ok then
					warn("[SerumService] " .. tostring(err))
				end
			end
		end
	end)
end

return SerumService
