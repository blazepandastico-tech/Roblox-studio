--[[
	Prova di costruzione del mondo fuori da Roblox Studio (tools/test_world.py):
	costruisce tutta la mappa con il Roblox finto, poi i forzieri, un cavallo e una barca.
	Ogni proprietà sbagliata, Enum inesistente o errore di codice viene segnalato.
]]

local function check(condition: any, message: string)
	if not condition then
		table.insert(ERRORS, message)
	end
end

local Config = require(SHARED.Config)
local W = require(SHARED.Data.WorldLayout)
local Treasures = require(SHARED.Data.Treasures)

-- MAPPA ----------------------------------------------------------------------------------------------
local WB = require(SERVER.Services.WorldBuilder)
WB.Init({})
local ok, err = pcall(WB.Build)
check(ok, "WorldBuilder.Build: " .. tostring(err))
for _, w in WARNINGS do
	table.insert(ERRORS, "WorldBuilder ha segnalato: " .. w)
end
table.clear(WARNINGS)
WB.Ready = true

local map = workspace:FindFirstChild(Config.Folders.Map)
check(map ~= nil, "la mappa non è stata creata")
if map then
	for _, islet in W.Islets do
		local g = map:FindFirstChild(islet.Name)
		check(g ~= nil and #g:GetDescendants() > 10, "isolotto non costruito: " .. islet.Name)
	end
	local taverns = map:FindFirstChild("Taverne")
	check(taverns ~= nil and #taverns:GetDescendants() > 300, "taverne non costruite")
	check(map:FindFirstChild("Arena dei Duelli") ~= nil, "Arena dei Duelli non costruita")
	local floors = 0
	for _, d in map:GetDescendants() do
		if d.Name == "Pavimento" then
			floors += 1
		end
	end
	check(floors >= 30, "troppe poche case in cui entrare: " .. floors)
	LOG(("Mappa costruita: %d istanze, %d stanze in cui entrare"):format(MOCK_INSTANCES(), floors))
end
local docks = MOCK_TAGGED(Config.Tags.BoatDock)
check(#docks >= 5 + #W.Islets, "pontili delle barche mancanti: " .. #docks)
LOG(("Pontili per le barche: %d"):format(#docks))

-- GIOCATORE FINTO --------------------------------------------------------------------------------------
local player = Instance.new("Player")
player.Name = "Prova"
player.DisplayName = "Prova"
player.UserId = 12345
local character = Instance.new("Model")
character.Name = "Prova"
local root = Instance.new("Part")
root.Name = "HumanoidRootPart"
root.Size = Vector3.new(2, 2, 1)
root.CFrame = CFrame.new(0, 11, 0)
root.Parent = character
local humanoid = Instance.new("Humanoid")
humanoid.HipHeight = 2
humanoid.MaxHealth = 100
humanoid.Health = 100
humanoid.Parent = character
character.PrimaryPart = root
character.Parent = workspace
player.Character = character

local profile = { Level = 120, Treasures = {}, Gems = 0, Gold = 0, HorseColor = 0, Settings = { PvP = false }, Kills = { Players = 0 }, Bounty = 0 }
local state = {}
local S: any = {
	WorldBuilder = WB,
	DataService = {
		Get = function()
			return profile
		end,
		MarkDirty = function() end,
		OnLoaded = function() end,
	},
	PlayerService = {
		GetState = function()
			return state
		end,
		InCutscene = function()
			return false
		end,
		Refresh = function() end,
		AddGold = function(_, n)
			return n
		end,
		AddXP = function(_, n)
			return n
		end,
		UpdateNameplate = function() end,
		Knockback = function() end,
		CharacterReady = MOCK_NEW_SIGNAL(),
		Died = MOCK_NEW_SIGNAL(),
	},
	EventService = {
		Notify = function() end,
		NotifyAll = function() end,
		Effect = function() end,
		EffectTo = function() end,
		Announce = function() end,
		AnnounceTo = function() end,
	},
	ODMService = { Grace = function() end },
	InventoryService = { Give = function() end },
}

-- FORZIERI ----------------------------------------------------------------------------------------------
local Explore = require(SERVER.Services.ExploreService)
Explore.Init(S)
local okE, errE = pcall(Explore.Start)
check(okE, "ExploreService.Start: " .. tostring(errE))
local folder = workspace:FindFirstChild("Tesori")
check(folder ~= nil and #folder:GetChildren() == #Treasures.List, ("forzieri creati: %d su %d"):format(folder and #folder:GetChildren() or 0, #Treasures.List))
LOG(("Forzieri nascosti: %d"):format(folder and #folder:GetChildren() or 0))

-- CAVALLO -------------------------------------------------------------------------------------------------
local Horse = require(SERVER.Services.HorseService)
Horse.Init(S)
S.HorseService = Horse
local okH, errH = pcall(Horse.Mount, player)
check(okH, "HorseService.Mount: " .. tostring(errH))
local horse = character:FindFirstChild("Cavallo")
check(horse ~= nil and #horse:GetDescendants() > 25, "il cavallo non è stato costruito")
check(player:GetAttribute("Riding") == true, "il giocatore non risulta a cavallo")
check(humanoid.HipHeight > 4, "il cavaliere non è stato alzato sulla sella")
local okD, errD = pcall(Horse.Dismount, player)
check(okD, "HorseService.Dismount: " .. tostring(errD))
check(character:FindFirstChild("Cavallo") == nil and humanoid.HipHeight == 2, "il cavallo non è stato tolto bene")

-- BARCA ----------------------------------------------------------------------------------------------------
local Sea = require(SERVER.Services.SeaService)
Sea.Init(S)
S.SeaService = Sea
local okS, errS = pcall(Sea.Start)
check(okS, "SeaService.Start: " .. tostring(errS))
if docks[1] then
	local okB, errB = pcall(Sea.SpawnBoatNear, player, docks[1].Position)
	check(okB, "SeaService.SpawnBoatNear: " .. tostring(errB))
	local boat = Sea.GetBoat(player)
	check(boat ~= nil and boat.PrimaryPart ~= nil, "la barca non è stata creata")
	if boat then
		local seat = boat:FindFirstChild("Timone")
		check(seat ~= nil and seat.Occupant == humanoid, "il giocatore non è stato messo al timone")
		check(math.abs(boat.PrimaryPart.Position.Y - (W.WaterY + 0.6)) < 0.01, "la barca non galleggia alla quota giusta")
	end
end

for _, w in WARNINGS do
	table.insert(ERRORS, "Avviso: " .. w)
end
if #ERRORS > 0 then
	for _, e in ERRORS do
		LOG("ERRORE: " .. e)
	end
	error(("prova del mondo fallita: %d errori"):format(#ERRORS))
end
LOG("Prova del mondo OK: mappa, forzieri, cavallo e barca costruiti senza errori")
TEST_PLAYER = player
