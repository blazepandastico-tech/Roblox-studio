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

-- 🎬 ADMIN ABUSE: i 6 eventi a tempo della prima stagione ------------------------------------------------
local Zones = require(SHARED.Data.Zones)
local AbuseEvents = require(SHARED.Data.AbuseEvents)
local plains = Zones.Get("PianureSud")
root.CFrame = CFrame.new(plains.Center + Vector3.new(0, 4, 0))
table.insert(MOCK_PLAYERS, player)
local spawned: { any } = {}
S.TitanService.Spawn = function(spec)
	local model = Instance.new("Model")
	model.Name = "GiganteProva"
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Parent = model
	model.PrimaryPart = torso
	model.Parent = workspace
	local t = { Model = model, State = "Idle", Position = spec.Position or Vector3.zero, BossId = spec.Boss, Spec = spec }
	table.insert(spawned, t)
	return t
end
S.TitanService.Despawn = function(t)
	t.State = "Dead"
end
local invasions, allies, freezes = 0, 0, 0
S.TitanService.StartInvasion = function()
	invasions += 1
end
S.TitanService.SpawnAllies = function()
	allies += 1
	return {}
end
S.TitanService.FreezeInRadius = function()
	freezes += 1
	return 2
end
local Abuse = require(SERVER.Services.AbuseService)
Abuse.Init(S)
S.AbuseService = Abuse
local okStart, errStart = pcall(Abuse.Start)
check(okStart, "AbuseService.Start: " .. tostring(errStart))
check(not Abuse.Launch("EventoCheNonEsiste", 5), "un evento inesistente non deve partire")
check(AbuseEvents.ClampMinutes(500) == AbuseEvents.MaxMinutes and AbuseEvents.ClampMinutes(0) == AbuseEvents.MinMinutes, "minuti dell'evento non limitati")
for _, def in AbuseEvents.List do
	local before = #spawned
	local okL, resL = pcall(Abuse.Launch, def.Id, 2)
	check(okL and resL == true, def.Id .. ": l'evento non parte (" .. tostring(resL) .. ")")
	check(replicated:GetAttribute("AbuseEvento") == def.Id, def.Id .. ": attributo AbuseEvento non pubblicato")
	check(type(replicated:GetAttribute("AbuseFine")) == "number", def.Id .. ": manca la fine dell'evento")
	if def.Bonus.XP then
		check(player:GetAttribute("BonusXPAbuse") == def.Bonus.XP, def.Id .. ": bonus di esperienza non applicato")
	end
	local protected = player:GetAttribute("CutsceneUntil")
	check(type(protected) == "number" and protected > workspace:GetServerTimeNow() + 10, def.Id .. ": i giocatori non sono protetti durante l'animazione")
	-- durante l'animazione (primi secondi) non arrivano giganti
	local beforeIntro = #spawned
	Abuse.FastForward(5)
	pcall(Abuse.Step)
	check(#spawned == beforeIntro, def.Id .. ": arrivano giganti mentre i giocatori guardano l'animazione")
	-- finisce l'animazione (20 secondi in tutto), poi passa un minuto
	for _, seconds in { 15, 20, 30 } do
		Abuse.FastForward(seconds)
		local okS, errS = pcall(Abuse.Step)
		check(okS, def.Id .. ": Step: " .. tostring(errS))
	end
	local made = #spawned - before
	check(made > 0 or invasions > 0 or freezes > 0, def.Id .. ": l'evento non ha fatto succedere niente")
	if def.Id == "Spedizione" then
		local anomaly = nil
		for i = before + 1, #spawned do
			if spawned[i].AbuseGems then
				anomaly = spawned[i]
			end
		end
		check(anomaly ~= nil, "Spedizione: nessun gigante anomalo con le gemme")
		if anomaly then
			local gems = profile.Gems
			S.TitanService.Killed:Fire(anomaly, player, { player })
			check(profile.Gems == gems + (def.AnomalyGems or 5), "Spedizione: le gemme dell'anomalo non arrivano")
		end
	end
	if def.Boss then
		local boss = false
		for i = before + 1, #spawned do
			if spawned[i].BossId == def.Boss then
				boss = true
			end
		end
		check(boss, def.Id .. ": il boss " .. def.Boss .. " non è comparso")
	end
	-- finisce il tempo: i giganti dell'evento spariscono e i bonus si tolgono
	Abuse.FastForward(200)
	pcall(Abuse.Step)
	check(replicated:GetAttribute("AbuseEvento") == nil, def.Id .. ": l'evento non finisce allo scadere del tempo")
	check(player:GetAttribute("BonusXPAbuse") == nil and player:GetAttribute("GasAbuse") == nil, def.Id .. ": i bonus restano dopo la fine")
	local leftover = 0
	for i = before + 1, #spawned do
		if spawned[i].State ~= "Dead" then
			leftover += 1
		end
	end
	check(leftover == 0, def.Id .. (": %d giganti dell'evento non sono spariti"):format(leftover))
	LOG(("Evento %s %s: %d giganti/boss creati"):format(def.Icon, def.Name, made))
end
check(invasions > 0 and allies > 0 and freezes > 0, "invasione, alleati o fulmini degli eventi non attivati")
Abuse.Launch("CadutaMuro", 5)
check(Abuse.Stop("Admin") and replicated:GetAttribute("AbuseEvento") == nil, "Termina evento non funziona")
table.clear(MOCK_PLAYERS)

-- ADDESTRAMENTO DI BASE (server): dopo il prologo la storia aspetta il tutorial, il premio arriva
-- una volta sola e solo completandolo, poi la storia riparte con Brehm ----------------------------------
do
	local Net = require(SHARED.Lib.Net)
	local TutorialData = require(SHARED.Data.Tutorial)
	local Story = require(SERVER.Services.StoryService)
	local Tut = require(SERVER.Services.TutorialService)
	local tprofile: any = { Level = 1, Story = { Chapter = 1, Step = 1, Progress = 0, Done = false } }
	local notes: { string } = {}
	local rewards = nil
	local onLoaded = nil
	local TS: any = {
		DataService = {
			Get = function()
				return tprofile
			end,
			MarkDirty = function() end,
			OnLoaded = function(fn)
				onLoaded = fn
			end,
		},
		PlayerService = {
			GiveRewards = function(_, r)
				rewards = r
			end,
		},
		EventService = {
			Notify = function(_, text)
				table.insert(notes, text)
			end,
			AnnounceTo = function() end,
		},
		StoryService = Story,
		TutorialService = Tut,
		TitanService = { ReleasePlayer = function() end },
	}
	Story.Init(TS)
	Tut.Init(TS)
	local okT, errT = pcall(Tut.Start)
	check(okT, "TutorialService.Start: " .. tostring(errT))
	onLoaded(player, tprofile)
	check(tprofile.Tutorial and not tprofile.Tutorial.Done, "un giocatore nuovo deve fare l'addestramento")
	-- fine del prologo: la storia passa a Brehm ma aspetta l'addestramento (nessun "Nuovo obiettivo")
	Story.Advance(player)
	check(tprofile.Story.Step == TutorialData.StoryStep and Tut.Pending(player), "dopo il prologo l'addestramento non parte")
	check(#notes == 0, "la storia non dovrebbe dare obiettivi durante l'addestramento: " .. tostring(notes[1]))
	check(not Story.TryTalk(player, "Brehm"), "parlando con Brehm durante l'addestramento la storia va avanti")
	-- progressi: un passo alla volta (un salto in avanti viene ignorato)
	Net.Event("TutorialProgress").OnServerEvent:Fire(player, 5)
	check(tprofile.Tutorial.Step == 1, "un salto di passi è stato accettato")
	for i = 2, #TutorialData.Steps + 1 do
		Net.Event("TutorialProgress").OnServerEvent:Fire(player, i)
	end
	check(tprofile.Tutorial.Step == #TutorialData.Steps + 1, "i progressi dell'addestramento non vengono salvati")
	-- completato (dopo il tempo minimo): premio e la storia riparte con Brehm
	local start = os.clock()
	MOCK_HOOKS.Clock = function()
		return start + TutorialData.MinSeconds + 5
	end
	Net.Event("TutorialDone").OnServerEvent:Fire(player, "complete")
	MOCK_HOOKS.Clock = nil
	check(tprofile.Tutorial.Done and tprofile.Tutorial.Rewarded and rewards ~= nil, "premio dell'addestramento non dato")
	check(notes[#notes] ~= nil and string.find(notes[#notes], "Brehm") ~= nil, "dopo l'addestramento la storia non riparte con Brehm")
	check(not Tut.Pending(player), "l'addestramento resta da fare dopo averlo finito")
	-- rivisto dal menu: nessun altro premio e la storia non cambia
	rewards = nil
	local step = tprofile.Story.Step
	Net.Event("TutorialReplay").OnServerEvent:Fire(player)
	Net.Event("TutorialDone").OnServerEvent:Fire(player, "complete")
	check(rewards == nil and tprofile.Story.Step == step, "rivedere l'addestramento dà premi o cambia la storia")
	-- saltato: niente premio, la storia riparte comunque
	tprofile = { Level = 1, Story = { Chapter = 1, Step = TutorialData.StoryStep, Progress = 0, Done = false } }
	onLoaded(player, tprofile)
	check(Tut.Gate(player), "l'addestramento non parte per chi rientra a metà")
	Net.Event("TutorialDone").OnServerEvent:Fire(player, "skip")
	check(tprofile.Tutorial.Done and not tprofile.Tutorial.Rewarded, "saltare l'addestramento dà il premio")
	-- chi aveva già superato quel punto della storia non lo rifà
	tprofile = { Level = 40, Story = { Chapter = 3, Step = 2, Progress = 0, Done = false } }
	onLoaded(player, tprofile)
	check(tprofile.Tutorial.Done, "un giocatore già avanti nella storia deve saltare l'addestramento")
	LOG("Addestramento di base (server): parte dopo il prologo, salva i passi, premio una volta sola, poi Brehm")
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
LOG("Prova del mondo OK: mappa, forzieri, cavallo, barca ed evento costruiti senza errori")
TEST_PLAYER = player
