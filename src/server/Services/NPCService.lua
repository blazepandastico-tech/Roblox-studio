--[[
	NPCService
	Crea i personaggi non giocanti e gestisce i dialoghi:
	storia, missioni, negozi, laboratorio, viaggi rapidi, navi, ascensori e stirpi.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Lib.Util)
local Net = require(Shared.Lib.Net)
local NPCs = require(Shared.Data.NPCs)
local Zones = require(Shared.Data.Zones)
local Quests = require(Shared.Data.Quests)
local Leveling = require(Shared.Data.Leveling)
local Bloodlines = require(Shared.Data.Bloodlines)
local W = require(Shared.Data.WorldLayout)

local OutfitService = require(script.Parent.OutfitService)

local NPCService = {}
local S
local folder: Folder
local rng = Random.new(Config.WorldSeed + 3)

local function npcPosition(npc): Vector3?
	local zone = Zones.Get(npc.Zone)
	if not zone then
		return nil
	end
	return zone.Center + npc.Offset
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include

local function groundAt(pos: Vector3, underground: boolean): number
	groundParams.FilterDescendantsInstances = { workspace.Terrain, workspace:FindFirstChild(Config.Folders.Map) or workspace.Terrain }
	local origin = if underground then pos + Vector3.new(0, 40, 0) else Vector3.new(pos.X, pos.Y + 120, pos.Z)
	local result = workspace:Raycast(origin, Vector3.new(0, -220, 0), groundParams)
	return if result then result.Position.Y else pos.Y
end

local function nameplate(parent: BasePart, name: string, title: string, color: Color3?)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Targhetta"
	billboard.Size = UDim2.fromOffset(240, 56)
	billboard.StudsOffset = Vector3.new(0, 3.4, 0)
	billboard.MaxDistance = 90
	billboard.LightInfluence = 0
	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
	nameLabel.Font = Enum.Font.Merriweather
	nameLabel.TextScaled = true
	nameLabel.Text = name
	nameLabel.TextColor3 = Color3.fromRGB(250, 240, 220)
	nameLabel.TextStrokeTransparency = 0.35
	nameLabel.Parent = billboard
	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromScale(0, 0.55)
	titleLabel.Size = UDim2.new(1, 0, 0.45, 0)
	titleLabel.Font = Enum.Font.GothamMedium
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.TextColor3 = color or Color3.fromRGB(214, 180, 100)
	titleLabel.TextStrokeTransparency = 0.5
	titleLabel.Parent = billboard
	billboard.Parent = parent
end

local function addPrompt(parent: BasePart, npc, name: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Interazione"
	prompt.ActionText = if npc.Role == "Lift" or npc.Role == "Ship" then "Usa"
		elseif npc.Role == "Shop" then "Commercia"
		elseif npc.Role == "Ferry" then "Salpa"
		elseif npc.Role == "Raid" or npc.Role == "RaidArena" then "Raid"
		else "Parla"
	prompt.ObjectText = name
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	prompt.Triggered:Connect(function(player)
		NPCService.Interact(player, npc.Id)
	end)
end

local function buildObject(npc, pos: Vector3): Model
	local model = Instance.new("Model")
	model.Name = npc.Id
	local base = Instance.new("Part")
	base.Name = "HumanoidRootPart"
	base.Anchored = true
	base.CanCollide = false
	base.Transparency = 1
	base.Size = Vector3.new(4, 6, 4)
	base.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
	base.Parent = model
	if npc.Object == "Porta" then
		local frame = Instance.new("Part")
		frame.Name = "Porta"
		frame.Anchored = true
		frame.Size = Vector3.new(6, 9, 1)
		frame.CFrame = CFrame.new(pos + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, math.rad(npc.Facing or 0), 0)
		frame.Material = Enum.Material.WoodPlanks
		frame.Color = Color3.fromRGB(80, 56, 40)
		frame.Parent = model
		local stone = Instance.new("Part")
		stone.Name = "Arco"
		stone.Anchored = true
		stone.Size = Vector3.new(9, 11, 1.4)
		stone.CFrame = frame.CFrame * CFrame.new(0, 0.5, 0.3)
		stone.Material = Enum.Material.Cobblestone
		stone.Color = Color3.fromRGB(120, 112, 100)
		stone.Parent = model
	elseif npc.Object == "Ascensore" or npc.Object == "Caverna" then
		local lever = Instance.new("Part")
		lever.Name = "Leva"
		lever.Anchored = true
		lever.Size = Vector3.new(1.2, 5, 1.2)
		lever.CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0))
		lever.Material = Enum.Material.Metal
		lever.Color = Color3.fromRGB(150, 120, 60)
		lever.Parent = model
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 120)
		light.Range = 18
		light.Parent = lever
	end
	model.PrimaryPart = base
	return model
end

local templateModel: Model? = nil
local function getTemplate(): Model?
	if templateModel then
		return templateModel
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if ok and model then
		templateModel = model
		return model
	end
	warn("[NPCService] Impossibile creare i PNG: " .. tostring(model))
	return nil
end

local function spawnNpc(npc)
	local zone = Zones.Get(npc.Zone)
	local pos = npcPosition(npc)
	if not zone or not pos then
		return
	end
	local y = groundAt(pos, zone.Underground == true)
	pos = Vector3.new(pos.X, y, pos.Z)
	local name, title = NPCs.DisplayName(npc)
	local character = npc.Character and NPCs.Characters[npc.Character]
	local model: Model
	if npc.Object then
		model = buildObject(npc, pos)
	else
		local base = getTemplate()
		if not base then
			return
		end
		model = base:Clone()
		model.Name = npc.Id
		local look = npc.Look or {}
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				d.Color = look.Skin or Color3.fromRGB(226, 186, 160)
			end
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			humanoid.BreakJointsOnDeath = false
		end
		local spec = {
			Uniform = look.Uniform or "Civile",
			Look = look,
			NoBlades = true,
			NoGear = look.Uniform == "Civile" or look.Uniform == "Mercante" or look.Uniform == "Nobile" or look.Uniform == "Scienziata",
		}
		OutfitService.Apply(model, spec)
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.Anchored = true
		end
		local hipHeight = humanoid and humanoid.HipHeight or 2
		local rootHeight = if root then root.Size.Y / 2 else 1
		model:PivotTo(CFrame.new(pos + Vector3.new(0, hipHeight + rootHeight, 0)) * CFrame.Angles(0, math.rad(-(npc.Facing or 0)), 0))
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.CollisionGroup = Config.CollisionGroups.NPC
			end
		end
	end
	model:SetAttribute("NpcId", npc.Id)
	model:SetAttribute("Role", npc.Role)
	model:SetAttribute("Seed", rng:NextNumber(0, 100))
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local anchor = (model:FindFirstChild("Head") or model.PrimaryPart) :: BasePart
	nameplate(anchor, name, title, character and character.Color)
	addPrompt(model.PrimaryPart :: BasePart, npc, name)
	model.Parent = folder
	CollectionService:AddTag(model, Config.Tags.NPC)
end

-- DIALOGHI -----------------------------------------------------------------------------------

local function send(player: Player, npc, lines, choices)
	local name, title = NPCs.DisplayName(npc)
	local formatted = {}
	for _, line in lines do
		if type(line) == "string" then
			table.insert(formatted, { Speaker = npc.Id, Name = name, Text = line })
		else
			table.insert(formatted, { Speaker = line.Speaker, Name = NPCs.SpeakerName(line.Speaker), Text = line.Text })
		end
	end
	Net.Event("Dialogue"):FireClient(player, { NpcId = npc.Id, Name = name, Title = title, Lines = formatted, Choices = choices })
end

local function greeting(npc): string
	local list = npc.Greeting
	if list and #list > 0 then
		return list[rng:NextInteger(1, #list)]
	end
	return "..."
end

local function isNear(player: Player, npc): boolean
	local root = Util.GetRoot(player.Character)
	local pos = npcPosition(npc)
	return root ~= nil and pos ~= nil and Util.FlatDistance(root.Position, pos) < 30 and math.abs(root.Position.Y - pos.Y) < 50
end

local function teleportToZone(player: Player, zoneId: string)
	local zone = Zones.Get(zoneId)
	if not zone then
		return
	end
	S.EventService.EffectTo(player, "Fade", { Time = 0.6 })
	task.wait(0.35)
	S.PlayerService.Teleport(player, Zones.SpawnPoint(zone))
end

function NPCService.Interact(player: Player, npcId: string)
	local npc = NPCs.Get(npcId)
	local profile = S.DataService.Get(player)
	if not npc or not profile or not isNear(player, npc) then
		return
	end
	if S.StoryService.TryTalk(player, npcId) then
		return
	end
	local role = npc.Role
	if role == "Shop" then
		S.ShopService.OpenShop(player, npc.Shop)
	elseif role == "Lab" then
		send(player, npc, { greeting(npc) }, {
			{ Id = "lab", Text = "🧪 Apri il Laboratorio" },
			{ Id = "close", Text = "Arrivederci" },
		})
	elseif role == "Dealer" then
		send(player, npc, { greeting(npc) }, {
			{ Id = "dealer", Text = "💉 Mostrami i sieri" },
			{ Id = "close", Text = "Non oggi" },
		})
	elseif role == "Quest" then
		local choices = {}
		local lines = { greeting(npc) }
		local active = profile.Quest.Id ~= "" and Quests.Get(profile.Quest.Id)
		if active then
			table.insert(lines, ("Missione attuale: %s (%d/%d)"):format(active.Name, profile.Quest.Progress, active.Count))
			table.insert(choices, { Id = "abandon", Text = "Abbandona la missione attuale" })
		end
		for _, questId in npc.Quests or {} do
			local quest = Quests.Get(questId)
			if quest then
				local xp, gold = Quests.Rewards(quest, Leveling)
				local locked = profile.Level < quest.LevelReq
				local text = ("%s%s  [Lv.%d]  +%s XP  +%s oro"):format(if locked then "🔒 " else "📜 ", quest.Name, quest.LevelReq, Util.Abbreviate(xp), Util.Abbreviate(gold))
				table.insert(choices, { Id = "quest:" .. questId, Text = text, Disabled = locked })
			end
		end
		table.insert(choices, { Id = "close", Text = "Arrivederci" })
		send(player, npc, lines, choices)
	elseif role == "Travel" then
		local choices = {}
		for _, zone in Zones.List do
			if zone.Safe and zone.Spawn and profile.Visited[zone.Id] and zone.Id ~= npc.Zone then
				table.insert(choices, { Id = "travel:" .. zone.Id, Text = "🐎 " .. zone.Name })
			end
		end
		table.insert(choices, { Id = "close", Text = "Resto qui" })
		local lines = { greeting(npc) }
		if #choices == 1 then
			table.insert(lines, "Non hai ancora visitato altre basi sicure. Esplora e torna da me!")
		end
		send(player, npc, lines, choices)
	elseif role == "Ship" then
		local dest = Zones.Get(npc.Destination)
		local lines = { greeting(npc) }
		local choices = {}
		if dest then
			table.insert(choices, { Id = "ship", Text = ("⛵ Salpa per %s%s"):format(dest.Name, if npc.LevelReq then (" (Lv. %d)"):format(npc.LevelReq) else "") })
		end
		table.insert(choices, { Id = "close", Text = "Non ancora" })
		send(player, npc, lines, choices)
	elseif role == "Lift" then
		if npc.LevelReq and profile.Level < npc.LevelReq then
			S.EventService.Notify(player, ("Le guardie non ti fanno passare: serve il livello %d."):format(npc.LevelReq), "Errore", 3)
			return
		end
		teleportToZone(player, npc.Destination)
	elseif role == "Genealogist" then
		local bloodline = Bloodlines.Get(profile.Bloodline)
		send(player, npc, {
			greeting(npc),
			("La tua stirpe attuale: %s. %s"):format(bloodline.Name, bloodline.Description),
		}, {
			{ Id = "reroll", Text = ("🧬 Risveglia un'altra stirpe (%s oro)"):format(Util.Abbreviate(Config.Bloodline.RerollCost)) },
			{ Id = "resetstats", Text = ("📊 Azzera le statistiche (%s oro)"):format(Util.Abbreviate(Config.StatResetCost * profile.Level)) },
			{ Id = "close", Text = "Arrivederci" },
		})
	elseif role == "Ferry" then
		local here = W.IslandAt(npcPosition(npc) or Vector3.zero)
		local choices = {}
		for _, islandId in W.IslandOrder do
			local island = W.Islands[islandId]
			if not island.Raid and (not here or here.Id ~= islandId) then
				local locked = profile.Level < island.LevelReq
				table.insert(choices, {
					Id = "ferry:" .. islandId,
					Text = ("%s %s  (Lv. %d)"):format(if locked then "🔒" else "⛵", island.Name, island.LevelReq),
					Disabled = locked,
				})
			end
		end
		table.insert(choices, { Id = "close", Text = "Resto qui" })
		send(player, npc, { greeting(npc), "Ogni isola ha i suoi giganti: più ti allontani, più sono forti." }, choices)
	elseif role == "Raid" or role == "RaidArena" then
		if S.RaidService then
			local lines, choices = S.RaidService.DialogueFor(player, npc)
			send(player, npc, lines, choices)
		end
	elseif npc.Object == "Porta" then
		send(player, npc, { "La porta è chiusa. Una serratura dalla forma strana... sembra quella di una fiala." }, { { Id = "close", Text = "Vai via" } })
	else
		send(player, npc, { greeting(npc) }, { { Id = "close", Text = "Arrivederci" } })
	end
end

local function onChoice(player: Player, npcId: any, choiceId: any)
	if type(npcId) ~= "string" or type(choiceId) ~= "string" then
		return
	end
	if choiceId == "close" then
		return
	end
	local npc = NPCs.Get(npcId)
	if choiceId == "story_continue" then
		S.StoryService.OnDialogueChoice(player, npcId, choiceId)
		return
	end
	if not npc or not isNear(player, npc) then
		return
	end
	local profile = S.DataService.Get(player)
	if not profile then
		return
	end
	if choiceId:sub(1, 6) == "quest:" then
		local questId = choiceId:sub(7)
		if npc.Quests and table.find(npc.Quests, questId) then
			local ok, message = S.QuestService.Accept(player, questId)
			if not ok and message then
				S.EventService.Notify(player, message, "Errore", 3)
			end
		end
	elseif choiceId == "abandon" then
		S.QuestService.Abandon(player)
	elseif choiceId == "lab" and npc.Role == "Lab" then
		S.ShopService.OpenLab(player)
	elseif choiceId == "dealer" and npc.Role == "Dealer" then
		S.ShopService.OpenDealer(player)
	elseif choiceId:sub(1, 7) == "travel:" and npc.Role == "Travel" then
		local zoneId = choiceId:sub(8)
		local zone = Zones.Get(zoneId)
		if zone and zone.Safe and profile.Visited[zoneId] then
			teleportToZone(player, zoneId)
		end
	elseif choiceId == "ship" and npc.Role == "Ship" then
		if npc.LevelReq and profile.Level < npc.LevelReq then
			S.EventService.Notify(player, ("Il capitano scuote la testa: serve il livello %d."):format(npc.LevelReq), "Errore", 3)
			return
		end
		S.EventService.EffectTo(player, "Voyage", { Destination = npc.Destination })
		task.wait(2)
		teleportToZone(player, npc.Destination)
	elseif choiceId:sub(1, 6) == "ferry:" and npc.Role == "Ferry" then
		local island = W.Islands[choiceId:sub(7)]
		if not island or island.Raid then
			return
		end
		if profile.Level < island.LevelReq then
			S.EventService.Notify(player, ("Il nocchiero scuote la testa: per %s serve il livello %d."):format(island.Name, island.LevelReq), "Errore", 3)
			return
		end
		S.EventService.EffectTo(player, "Voyage", { Destination = island.Hub })
		task.wait(1.5)
		teleportToZone(player, island.Hub)
	elseif choiceId:sub(1, 5) == "raid:" and (npc.Role == "Raid" or npc.Role == "RaidArena") then
		if S.RaidService then
			S.RaidService.HandleChoice(player, choiceId)
		end
	elseif choiceId == "reroll" and npc.Role == "Genealogist" then
		local ok, message = S.ShopService.RerollBloodline(player)
		if not ok and message then
			S.EventService.Notify(player, message, "Errore", 3)
		end
	elseif choiceId == "resetstats" and npc.Role == "Genealogist" then
		local ok, message = S.PlayerService.ResetStats(player)
		if ok then
			S.EventService.Notify(player, "Statistiche azzerate: redistribuisci i punti!", "Successo", 3)
		elseif message then
			S.EventService.Notify(player, message, "Errore", 3)
		end
	end
end

function NPCService.Init(services)
	S = services
end

function NPCService.Start()
	folder = workspace:WaitForChild(Config.Folders.NPCs) :: Folder
	S.WorldBuilder.WaitReady()
	Net.Event("DialogueChoice").OnServerEvent:Connect(onChoice)
	for _, npc in NPCs.List do
		local ok, err = pcall(spawnNpc, npc)
		if not ok then
			warn(("[NPCService] PNG %s: %s"):format(npc.Id, tostring(err)))
		end
	end
end

return NPCService
