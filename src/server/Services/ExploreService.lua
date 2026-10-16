--[[
	ExploreService
	Forzieri nascosti in tutto l'arcipelago (vedi Shared/Data/Treasures).
	Ogni giocatore può aprire ogni forziere una volta sola; ogni 10 forzieri trovati
	arriva un premio extra in gemme. Il client nasconde i forzieri già aperti.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Lib.Util)
local W = require(Shared.Data.WorldLayout)
local Leveling = require(Shared.Data.Leveling)
local Treasures = require(Shared.Data.Treasures)

local ExploreService = {}
local S

local T = Config.Treasures
local TIER_MULT = { Comune = 1, Raro = 2, Leggendario = 4 }
local TIER_GEMS = { Comune = T.GemsCommon, Raro = T.GemsRare, Leggendario = T.GemsLegendary }

local folder: Folder
local chests: { [string]: BasePart } = {}
local rng = Random.new(Config.WorldSeed + 41)

-- Dove appoggiare il forziere (sopra tetti e mura, sul terreno, nelle grotte o dentro le taverne)
local function placeFor(def): CFrame?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local map = workspace:FindFirstChild(Config.Folders.Map)
	local pos = def.Pos
	local origin, depth
	if def.Mode == "Ground" then
		params.FilterDescendantsInstances = { workspace.Terrain }
		origin, depth = Vector3.new(pos.X, 400, pos.Z), 800
	elseif def.Mode == "Under" then
		params.FilterDescendantsInstances = { workspace.Terrain, map or workspace.Terrain }
		origin, depth = Vector3.new(pos.X, pos.Y + 45, pos.Z), 140
	elseif def.Mode == "Inside" then
		params.FilterDescendantsInstances = { workspace.Terrain, map or workspace.Terrain }
		origin, depth = Vector3.new(pos.X, W.GroundY + 8, pos.Z), 30
	else
		params.FilterDescendantsInstances = { workspace.Terrain, map or workspace.Terrain }
		origin, depth = Vector3.new(pos.X, 700, pos.Z), 1400
	end
	local result = workspace:Raycast(origin, Vector3.new(0, -depth, 0), params)
	if not result then
		return nil
	end
	return CFrame.new(result.Position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
end

local function buildChest(def, cf: CFrame): BasePart
	local info = Treasures.TierInfo[def.Tier] or Treasures.TierInfo.Comune
	local model = Instance.new("Model")
	model.Name = "Forziere_" .. def.Id
	local function piece(props): BasePart
		local p = Instance.new(props.ClassName or "Part")
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = false
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
	local base = piece({ Name = "Cassa", Size = Vector3.new(3.2, 2, 2.2), CFrame = cf * CFrame.new(0, 1, 0), Material = Enum.Material.WoodPlanks, Color = info.Color, CanCollide = true })
	piece({ Name = "Coperchio", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.2, 2.2, 2.2), CFrame = cf * CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, 0), Material = Enum.Material.WoodPlanks, Color = info.Color })
	for _, x in { -1.1, 1.1 } do
		piece({ Name = "Fascia", Size = Vector3.new(0.3, 2.1, 2.3), CFrame = cf * CFrame.new(x, 1, 0), Material = Enum.Material.Metal, Color = Color3.fromRGB(200, 170, 80) })
	end
	piece({ Name = "Serratura", Size = Vector3.new(0.6, 0.7, 0.2), CFrame = cf * CFrame.new(0, 1.8, -1.15), Material = Enum.Material.Metal, Color = Color3.fromRGB(230, 200, 100) })
	local glow = Instance.new("ParticleEmitter")
	glow.Name = "Luccichio"
	glow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	glow.Rate = 4
	glow.Lifetime = NumberRange.new(1, 1.6)
	glow.Speed = NumberRange.new(1, 2)
	glow.Size = NumberSequence.new(0.5)
	glow.Color = ColorSequence.new(info.Glow)
	glow.LightEmission = 1
	glow.SpreadAngle = Vector2.new(180, 180)
	glow.Parent = base
	local light = Instance.new("PointLight")
	light.Range = 8
	light.Brightness = 0.8
	light.Color = info.Glow
	light.Parent = base
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Apri"
	prompt.ObjectText = info.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = base
	model.PrimaryPart = base
	model:SetAttribute("TreasureId", def.Id)
	model:SetAttribute("Tier", def.Tier)
	CollectionService:AddTag(model, Config.Tags.Treasure)
	model.Parent = folder
	return base
end

local function open(player: Player, def, base: BasePart)
	local profile = S.DataService.Get(player)
	local root = Util.GetRoot(player.Character)
	if not profile or not root then
		return
	end
	profile.Treasures = profile.Treasures or {}
	if profile.Treasures[def.Id] then
		S.EventService.Notify(player, "Hai già aperto questo forziere.", "Info", 2)
		return
	end
	if (root.Position - base.Position).Magnitude > 18 then
		return
	end
	profile.Treasures[def.Id] = os.time()
	local mult = TIER_MULT[def.Tier] or 1
	local gold = S.PlayerService.AddGold(player, math.floor((T.GoldBase + T.GoldPerLevel * profile.Level) * mult))
	local xp = S.PlayerService.AddXP(player, math.floor(Leveling.XPToNext(profile.Level) * T.XPFraction * (if def.Tier == "Leggendario" then 2.5 elseif def.Tier == "Raro" then 1.5 else 1)), true)
	local gems = TIER_GEMS[def.Tier] or 0
	profile.Gems += gems
	if def.Tier == "Leggendario" and S.InventoryService then
		S.InventoryService.Give(player, "FrammentoSiero", 1)
	end
	local count = Treasures.Count(profile)
	local total = #Treasures.List
	S.EventService.Notify(player, ("%s %s aperto! +%s oro  +%s XP  +%d 💎   (%d/%d)"):format(if def.Tier == "Leggendario" then "🏆" elseif def.Tier == "Raro" then "💠" else "📦", Treasures.TierInfo[def.Tier].Name, Util.Abbreviate(gold), Util.Abbreviate(xp), gems, count, total), "Ricompensa", 5)
	if def.Tier == "Leggendario" then
		S.EventService.Notify(player, "Hai trovato anche un Frammento di Siero!", "Raro", 4)
	end
	if count == total then
		profile.Gems += 100
		S.EventService.AnnounceTo(player, "Esploratore Leggendario!", "Hai trovato TUTTI i forzieri dell'arcipelago: +100 💎", "Raro")
		S.EventService.NotifyAll(("🗺️ %s ha trovato tutti i forzieri nascosti dell'arcipelago!"):format(player.DisplayName), "Raro", 6)
	elseif count % T.MilestoneEvery == 0 then
		profile.Gems += T.MilestoneGems
		S.EventService.AnnounceTo(player, ("%d forzieri trovati!"):format(count), ("Premio da esploratore: +%d 💎"):format(T.MilestoneGems), "Raro")
	end
	S.EventService.EffectTo(player, "TreasureOpen", { Position = base.Position, Tier = def.Tier })
	if S.FestivalService then
		S.FestivalService.Add(player, "Treasures", 1)
	end
	S.DataService.MarkDirty(player)
	if S.AchievementService then
		task.defer(S.AchievementService.Check, player)
	end
end

function ExploreService.Init(services)
	S = services
end

function ExploreService.Start()
	folder = Instance.new("Folder")
	folder.Name = "Tesori"
	folder.Parent = workspace
	S.WorldBuilder.WaitReady()
	for _, def in Treasures.List do
		local ok, err = pcall(function()
			local cf = placeFor(def)
			if not cf then
				warn("[ExploreService] Nessun appoggio per il forziere " .. def.Id)
				return
			end
			local base = buildChest(def, cf)
			chests[def.Id] = base
			local prompt = base:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
			prompt.Triggered:Connect(function(player)
				open(player, def, base)
			end)
		end)
		if not ok then
			warn(("[ExploreService] Forziere %s: %s"):format(def.Id, tostring(err)))
		end
	end
end

return ExploreService
