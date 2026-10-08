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

local profile: any = { Level = 120, Treasures = {}, Gems = 0, Gold = 0, HorseColor = 0, Settings = { PvP = false }, Kills = { Players = 0 }, Bounty = 0, Festival = {} }
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

-- EVENTO GRANDE INAUGURAZIONE ---------------------------------------------------------------------------
local replicated = game:GetService("ReplicatedStorage")
S.TitanService = {
	Killed = MOCK_NEW_SIGNAL(),
	Despawn = function() end,
	ReleasePlayer = function() end,
	Spawn = function(spec)
		local model = Instance.new("Model")
		model.Name = "ColossoProva"
		local torso = Instance.new("Part")
		torso.Name = "Torso"
		torso.Parent = model
		model.PrimaryPart = torso
		model.Parent = workspace
		return { Model = model, State = "Idle", Position = spec.Position, BossId = spec.Boss }
	end,
}
S.PlayerService.ZoneEntered = MOCK_NEW_SIGNAL()
local Fest = require(SERVER.Services.FestivalService)
Fest.Init(S)
S.FestivalService = Fest
local okF, errF = pcall(Fest.SetOverride, true)
check(okF, "FestivalService.SetOverride(true): " .. tostring(errF))
check(replicated:GetAttribute("FestaAttiva") == true, "l'evento non risulta attivo")
local festa = workspace:FindFirstChild("Festa")
check(festa ~= nil and #festa:GetDescendants() > 200, "addobbi dell'evento non costruiti")
LOG(("Addobbi della festa: %d pezzi"):format(festa and #festa:GetDescendants() or 0))
local okC, errC = pcall(Fest.SpawnColossus)
check(okC, "FestivalService.SpawnColossus: " .. tostring(errC))
check(typeof(replicated:GetAttribute("FestaBossPos")) == "Vector3", "il Colosso d'Oro non è stato segnato sulla mappa")
local okW, errW = pcall(Fest.FireworksAt, Vector3.new(0, 8, 0), 20)
check(okW, "FestivalService.FireworksAt: " .. tostring(errW))
local okA, errA = pcall(Fest.Add, player, "Titans", 30)
check(okA, "FestivalService.Add: " .. tostring(errA))
check(profile.Festival and profile.Festival.Done and profile.Festival.Done.Giganti == true, "la sfida dei giganti non si completa")
local okR, errR = pcall(Fest.Ceremony, player, true)
check(okR, "FestivalService.Ceremony: " .. tostring(errR))
-- 😈 Admin Abuse: animazioni lanciate dal pannello e spettacoli automatici
check(replicated:GetAttribute("FestaSpettacoliAuto") == false, "gli spettacoli automatici dovrebbero partire spenti")
check(replicated:GetAttribute("FestaProssimoBoss") == nil, "senza spettacoli automatici non deve esserci il conto alla rovescia del Colosso")
check(Fest.CanSpawnColossus() == false, "il Colosso risulta libero anche se è già in campo")
for _, entry in {
	{ "FireworksShow", Fest.FireworksShow },
	{ "Meteor", Fest.Meteor, Vector3.new(100, 8, 100) },
	{ "ConfettiAll", Fest.ConfettiAll },
	{ "CeremonyAll", Fest.CeremonyAll },
	{ "ColossusWithWarning", Fest.ColossusWithWarning },
} do
	local okX, errX = pcall(entry[2], entry[3])
	check(okX, "FestivalService." .. entry[1] .. ": " .. tostring(errX))
end
local okS, errS = pcall(Fest.SetAutoShows, true)
check(okS, "FestivalService.SetAutoShows: " .. tostring(errS))
check(replicated:GetAttribute("FestaSpettacoliAuto") == true and type(replicated:GetAttribute("FestaProssimoBoss")) == "number", "gli spettacoli automatici non si accendono")
pcall(Fest.SetAutoShows, false)
LOG("Admin Abuse: Colosso, meteora, fuochi, coriandoli e cerimonia lanciati senza errori")
local okO, errO = pcall(Fest.SetOverride, false)
check(okO, "FestivalService.SetOverride(false): " .. tostring(errO))
check(workspace:FindFirstChild("Festa") == nil, "gli addobbi non vengono tolti a fine evento")
pcall(Fest.SetOverride, true)

for _, w in WARNINGS do
	table.insert(ERRORS, "Avviso: " .. w)
end
if #ERRORS > 0 then
	for _, e in ERRORS do
		LOG("ERRORE: " .. e)
	end
	error(("prova del mondo fallita: %d errori"):format(#ERRORS))
end
LOG("Prova del mondo OK: mappa, forzieri, cavallo, barca ed evento costruiti senza errori")
TEST_PLAYER = player
