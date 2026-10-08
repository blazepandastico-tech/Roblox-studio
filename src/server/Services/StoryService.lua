--[[
	StoryService
	Fa avanzare la storia "Sieri Perduti" passo dopo passo per ogni giocatore.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Lib.Util)
local Net = require(Shared.Lib.Net)
local Story = require(Shared.Data.Story)
local Zones = require(Shared.Data.Zones)
local NPCs = require(Shared.Data.NPCs)
local Leveling = require(Shared.Data.Leveling)
local Items = require(Shared.Data.Items)

local StoryService = {}
local S

function StoryService.Current(player: Player)
	local profile = S.DataService.Get(player)
	if not profile or profile.Story.Done then
		return nil, nil, profile
	end
	local chapter, step = Story.GetStep(profile.Story.Chapter, profile.Story.Step)
	return chapter, step, profile
end

local function npcSpeakerName(speaker: string): string
	return NPCs.SpeakerName(speaker)
end

-- Mostra una serie di battute al giocatore (finestra di dialogo)
function StoryService.ShowLines(player: Player, lines, npcId: string?)
	if not lines or #lines == 0 then
		return
	end
	local formatted = {}
	for _, line in lines do
		table.insert(formatted, { Speaker = line.Speaker, Name = npcSpeakerName(line.Speaker), Text = line.Text })
	end
	Net.Event("Dialogue"):FireClient(player, {
		NpcId = npcId,
		Lines = formatted,
		Choices = { { Id = "close", Text = "Continua" } },
		Story = true,
	})
end

local function xpLevelFor(profile, chapterIndex: number): number
	local chapter = Story.Chapters[chapterIndex]
	local nextChapter = Story.Chapters[chapterIndex + 1]
	local low = chapter.Level
	local high = if nextChapter then nextChapter.Level else Config.MaxLevel
	return math.clamp(profile.Level, low, math.max(low, high))
end

local function startStep(player: Player)
	local chapter, step, profile = StoryService.Current(player)
	if not chapter or not step or not profile then
		return
	end
	profile.Story.Progress = 0
	S.DataService.MarkDirty(player)
	if step.Type == "Cutscene" then
		Net.Event("Cutscene"):FireClient(player, step.Cutscene)
	elseif step.Type == "Level" then
		if profile.Level >= step.Level then
			task.defer(StoryService.Advance, player)
		end
	elseif step.Type == "Reach" and step.Zone then
		if player:GetAttribute("Zone") == step.Zone then
			task.defer(StoryService.Advance, player)
		end
	end
	S.EventService.Notify(player, "Nuovo obiettivo: " .. step.Objective, "Storia", 5)
end

function StoryService.Advance(player: Player)
	local chapter, step, profile = StoryService.Current(player)
	if not chapter or not step or not profile then
		return
	end
	-- ricompensa del passo
	if step.Reward then
		local xpLevel = xpLevelFor(profile, chapter.Index)
		local rewards = {
			XP = if step.Reward.XP then Leveling.QuestXP(xpLevel) * step.Reward.XP else 0,
			Gold = step.Reward.Gold,
			Items = step.Reward.Items,
		}
		S.PlayerService.GiveRewards(player, rewards, "Storia")
	end
	if step.After then
		StoryService.ShowLines(player, step.After)
	end
	-- passo successivo
	local story = profile.Story
	if story.Step < #chapter.Steps then
		story.Step += 1
	else
		S.EventService.AnnounceTo(player, chapter.Title .. " completato!", chapter.Summary, "Storia")
		local nextChapter = Story.Chapters[chapter.Index + 1]
		if nextChapter then
			if nextChapter.Season ~= chapter.Season then
				task.delay(4, function()
					if player.Parent then
						S.EventService.AnnounceTo(player, Zones.SeasonNames[nextChapter.Season], nextChapter.Title, "Stagione")
					end
				end)
			end
			story.Chapter += 1
			story.Step = 1
		else
			story.Done = true
			S.EventService.AnnounceTo(player, "STORIA COMPLETATA", "Hai fermato la Grande Marcia. Ma i Sieri Perduti sono ancora là fuori...", "Stagione")
			S.DataService.MarkDirty(player)
			return
		end
	end
	S.DataService.MarkDirty(player)
	startStep(player)
end

-- Riavvia il passo attuale (usato dai comandi di prova)
function StoryService.RestartStep(player: Player)
	startStep(player)
end

-- Il giocatore parla con un PNG: se la storia lo richiede, restituisce il dialogo
function StoryService.TryTalk(player: Player, npcId: string): boolean
	local _, step = StoryService.Current(player)
	if not step or step.Type ~= "Talk" or step.Npc ~= npcId then
		return false
	end
	local lines = {}
	for _, line in step.Dialogue do
		table.insert(lines, { Speaker = line.Speaker, Name = npcSpeakerName(line.Speaker), Text = line.Text })
	end
	Net.Event("Dialogue"):FireClient(player, {
		NpcId = npcId,
		Lines = lines,
		Choices = { { Id = "story_continue", Text = "Continua" } },
		Story = true,
	})
	return true
end

function StoryService.OnDialogueChoice(player: Player, npcId: string, choiceId: string)
	if choiceId ~= "story_continue" then
		return
	end
	local _, step = StoryService.Current(player)
	if step and step.Type == "Talk" and step.Npc == npcId then
		StoryService.Advance(player)
	end
end

local function addProgress(player: Player, count: number?)
	local _, step, profile = StoryService.Current(player)
	if not step or not profile then
		return
	end
	profile.Story.Progress += count or 1
	S.DataService.MarkDirty(player)
	if profile.Story.Progress >= (step.Count or 1) then
		StoryService.Advance(player)
	end
end

local function onTitanKilled(player: Player, t)
	local _, step = StoryService.Current(player)
	if not step then
		return
	end
	if step.Type == "Kill" and t.ClassId == step.Class and (not step.Zone or t.Zone == step.Zone) then
		addProgress(player)
	elseif step.Type == "Boss" and t.BossId == step.Boss then
		StoryService.Advance(player)
	end
end

local function onEnemyKilled(player: Player, e)
	local _, step = StoryService.Current(player)
	if not step then
		return
	end
	if step.Type == "Enemy" and e.TypeId == step.Enemy and (not step.Zone or e.Zone == step.Zone) and not e.Boss then
		addProgress(player)
	elseif step.Type == "HumanBoss" and e.BossId == step.Boss then
		StoryService.Advance(player)
	end
end

function StoryService.OnClientReady(player: Player)
	local _, step = StoryService.Current(player)
	if step and step.Type == "Cutscene" then
		task.delay(1.5, function()
			if player.Parent then
				Net.Event("Cutscene"):FireClient(player, step.Cutscene)
			end
		end)
	end
end

-- OGGETTI DA RACCOGLIERE (passi "Collect") ------------------------------------------------------

local function spawnPickups()
	local interactive = workspace:WaitForChild(Config.Folders.Interactive)
	local rng = Random.new(Config.WorldSeed + 7)
	-- gli oggetti vanno appoggiati sul terreno vero (le zone non sono tutte piatte)
	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Include
	local map = workspace:FindFirstChild(Config.Folders.Map)
	groundParams.FilterDescendantsInstances = if map then { workspace.Terrain, map } else { workspace.Terrain }
	local function onGround(pos: Vector3): Vector3
		local hit = workspace:Raycast(pos + Vector3.new(0, 250, 0), Vector3.new(0, -500, 0), groundParams)
		return if hit then hit.Position + Vector3.new(0, 1.2, 0) else pos
	end
	for _, chapter in Story.Chapters do
		for _, step in chapter.Steps do
			if step.Type == "Collect" then
				local zone = Zones.Get(step.Zone)
				if zone then
					for i = 1, (step.Count or 1) + 3 do
						local a = rng:NextNumber(0, math.pi * 2)
						local r = rng:NextNumber(10, zone.Radius * 0.8)
						local pos = onGround(zone.Center + Vector3.new(math.cos(a) * r, 1.5, math.sin(a) * r))
						local item = Items.Get(step.Item)
						local can = Instance.new("Part")
						can.Name = "Raccoglibile_" .. step.Item .. "_" .. i
						can.Shape = Enum.PartType.Cylinder
						can.Size = Vector3.new(2.6, 1.2, 1.2)
						can.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
						can.Anchored = true
						can.CanCollide = false
						can.Material = Enum.Material.Metal
						can.Color = Color3.fromRGB(90, 150, 100)
						can:SetAttribute("Item", step.Item)
						local glow = Instance.new("PointLight")
						glow.Color = Color3.fromRGB(120, 255, 140)
						glow.Range = 12
						glow.Brightness = 2
						glow.Parent = can
						local smoke = Instance.new("ParticleEmitter")
						smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
						smoke.Color = ColorSequence.new(Color3.fromRGB(150, 255, 160))
						smoke.Size = NumberSequence.new(1, 4)
						smoke.Transparency = NumberSequence.new(0.6, 1)
						smoke.Lifetime = NumberRange.new(1.5, 2.5)
						smoke.Rate = 4
						smoke.Speed = NumberRange.new(1, 2)
						smoke.Parent = can
						local prompt = Instance.new("ProximityPrompt")
						prompt.ActionText = "Raccogli"
						prompt.ObjectText = item and item.Name or step.Item
						prompt.KeyboardKeyCode = Enum.KeyCode.F
						prompt.HoldDuration = 0.5
						prompt.MaxActivationDistance = 10
						prompt.RequiresLineOfSight = false
						prompt.Parent = can
						can.Parent = interactive
						CollectionService:AddTag(can, Config.Tags.Pickup)
						prompt.Triggered:Connect(function(player)
							local _, current = StoryService.Current(player)
							if not current or current.Type ~= "Collect" or current.Item ~= step.Item then
								S.EventService.Notify(player, "Non ti serve, per ora.", "Info", 2)
								return
							end
							prompt.Enabled = false
							can.Transparency = 1
							glow.Enabled = false
							smoke.Enabled = false
							S.InventoryService.Give(player, step.Item, 1)
							addProgress(player)
							task.delay(20, function()
								prompt.Enabled = true
								can.Transparency = 0
								glow.Enabled = true
								smoke.Enabled = true
							end)
						end)
					end
				end
			end
		end
	end
end

-- Controllo periodico dei passi che si completano "da soli": posizione raggiunta, zona in cui
-- ti trovi già, livello già raggiunto (anche con il pannello admin o i comandi di prova).
-- Così nessun passo può restare bloccato.
local function checkReach()
	while true do
		task.wait(0.5)
		for _, player in Players:GetPlayers() do
			local _, step, profile = StoryService.Current(player)
			if step and profile then
				if step.Type == "Reach" and step.Position then
					local root = Util.GetRoot(player.Character)
					if root and (root.Position - step.Position).Magnitude <= (step.Radius or 20) then
						StoryService.Advance(player)
					end
				elseif step.Type == "Reach" and step.Zone and player:GetAttribute("Zone") == step.Zone then
					StoryService.Advance(player)
				elseif step.Type == "Level" and profile.Level >= (step.Level or 1) then
					StoryService.Advance(player)
				end
			end
		end
	end
end

function StoryService.Init(services)
	S = services
end

function StoryService.Start()
	S.TitanService.Killed:Connect(function(t, _killer, contributors)
		for _, player in contributors do
			onTitanKilled(player, t)
		end
	end)
	S.EnemyService.Killed:Connect(function(e, _killer, contributors)
		for _, player in contributors do
			onEnemyKilled(player, e)
		end
	end)
	S.PlayerService.LevelUp:Connect(function(player, level)
		local _, step = StoryService.Current(player)
		if step and step.Type == "Level" and level >= step.Level then
			StoryService.Advance(player)
		end
	end)
	S.PlayerService.ZoneEntered:Connect(function(player, zoneId)
		local _, step = StoryService.Current(player)
		if step and step.Type == "Reach" and step.Zone == zoneId then
			StoryService.Advance(player)
		end
	end)
	Net.Event("CutsceneDone").OnServerEvent:Connect(function(player, cutsceneId)
		local _, step = StoryService.Current(player)
		if step and step.Type == "Cutscene" and step.Cutscene == cutsceneId then
			StoryService.Advance(player)
		end
	end)
	S.WorldBuilder.WaitReady()
	task.spawn(spawnPickups)
	task.spawn(checkReach)
end

return StoryService
