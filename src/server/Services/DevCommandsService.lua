--[[
	DevCommandsService - comandi di prova in chat
	Funzionano SOLO in Roblox Studio oppure per il proprietario del gioco: servono a
	verificare storia, livelli e isole senza dover giocare ore.

	/aiuto              elenco dei comandi
	/livello N          porta il personaggio al livello N
	/oro N              aggiunge N monete d'oro
	/gemme N            aggiunge N gemme
	/capitolo N         salta all'inizio del capitolo N della storia (1-17)
	/passo              completa l'obiettivo attuale della storia
	/vai Zona           teletrasporto in una zona (es. /vai Recinto, /vai Aurion)
	/zone               elenco delle zone
	/cura               vita, gas e lame al massimo
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Story = require(Shared.Data.Story)
local Zones = require(Shared.Data.Zones)
local Leveling = require(Shared.Data.Leveling)

local DevCommandsService = {}
local S

local HELP = "/livello N • /oro N • /gemme N • /capitolo N • /passo • /vai Zona • /zone • /cura"

local function allowed(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(function()
		return player:GetRankInGroup(game.CreatorId)
	end)
	return ok and rank == 255
end

local function say(player: Player, text: string)
	S.EventService.Notify(player, text, "Prova", 6)
	print(("[Comandi] %s: %s"):format(player.Name, text))
end

local function setLevel(player: Player, target: number)
	local profile = S.DataService.Get(player)
	if not profile then
		return
	end
	target = math.clamp(math.floor(target), 1, Config.MaxLevel)
	local before = profile.Level
	if target > before then
		local need = -profile.XP
		for level = before, target - 1 do
			need += Leveling.XPToNext(level)
		end
		Leveling.AddXP(profile, need)
	else
		-- in discesa: si riparte da zero punti statistica spesi
		profile.Level = target
		profile.XP = 0
		pcall(S.PlayerService.ResetStats, player)
	end
	S.PlayerService.Refresh(player, true)
	local leaderstats = player:FindFirstChild("leaderstats")
	local levelValue = leaderstats and leaderstats:FindFirstChild("Livello") :: IntValue?
	if levelValue then
		levelValue.Value = profile.Level
	end
	S.DataService.MarkDirty(player)
	if profile.Level > before then
		S.PlayerService.LevelUp:Fire(player, profile.Level, before)
	end
	say(player, ("Livello impostato a %d"):format(profile.Level))
end

local function jumpToChapter(player: Player, index: number)
	local profile = S.DataService.Get(player)
	if not profile then
		return
	end
	local chapter = Story.Chapters[index]
	if not chapter then
		say(player, ("Capitolo non valido: scegli da 1 a %d"):format(#Story.Chapters))
		return
	end
	profile.Story.Chapter = index
	profile.Story.Step = 1
	profile.Story.Progress = 0
	profile.Story.Done = false
	S.DataService.MarkDirty(player)
	say(player, ("Storia: %s (livello consigliato %d)"):format(chapter.Title, chapter.Level))
	S.StoryService.RestartStep(player)
end

local function findZone(name: string)
	local wanted = string.lower(name)
	local exact = Zones.Get(name)
	if exact then
		return exact
	end
	for _, zone in Zones.List do
		if string.lower(zone.Id) == wanted or string.lower(zone.Name or "") == wanted then
			return zone
		end
	end
	for _, zone in Zones.List do
		if string.find(string.lower(zone.Id), wanted, 1, true) or string.find(string.lower(zone.Name or ""), wanted, 1, true) then
			return zone
		end
	end
	return nil
end

local function run(player: Player, text: string)
	local args = string.split(text, " ")
	local command = string.lower(args[1] or "")
	local value = tonumber(args[2])
	if command == "/aiuto" or command == "/comandi" then
		say(player, HELP)
	elseif command == "/livello" and value then
		setLevel(player, value)
	elseif command == "/oro" and value then
		local profile = S.DataService.Get(player)
		if profile then
			profile.Gold += math.max(0, math.floor(value))
			S.DataService.MarkDirty(player)
			say(player, ("+%d oro"):format(math.floor(value)))
		end
	elseif command == "/gemme" and value then
		S.MonetizationService.AddGems(player, math.max(0, math.floor(value)), "Prova")
		say(player, ("+%d gemme"):format(math.floor(value)))
	elseif command == "/capitolo" and value then
		jumpToChapter(player, math.floor(value))
	elseif command == "/passo" then
		local chapter, step = S.StoryService.Current(player)
		if chapter and step then
			say(player, "Obiettivo completato: " .. step.Objective)
			S.StoryService.Advance(player)
		else
			say(player, "La storia è già completata")
		end
	elseif command == "/vai" and args[2] then
		local zone = findZone(table.concat(args, " ", 2))
		if zone then
			S.PlayerService.Teleport(player, Zones.SpawnPoint(zone))
			say(player, "Teletrasporto: " .. (zone.Name or zone.Id))
		else
			say(player, "Zona non trovata. Scrivi /zone per l'elenco")
		end
	elseif command == "/zone" then
		local ids = {}
		for _, zone in Zones.List do
			table.insert(ids, zone.Id)
		end
		say(player, table.concat(ids, ", "))
	elseif command == "/cura" then
		S.PlayerService.Heal(player, 1)
		pcall(S.PlayerService.RefillWeapons, player)
		say(player, "Vita, gas e lame ricaricati")
	else
		return false
	end
	return true
end

-- lo stesso messaggio può arrivare sia dai comandi della chat sia da Player.Chatted
local lastRun: { [Player]: { Text: string, Time: number } } = {}

local function handle(player: Player, text: string)
	if string.sub(text, 1, 1) ~= "/" or not allowed(player) then
		return
	end
	local last = lastRun[player]
	local now = os.clock()
	if last and last.Text == text and now - last.Time < 1 then
		return
	end
	lastRun[player] = { Text = text, Time = now }
	local ok, err = pcall(run, player, text)
	if not ok then
		warn("[Comandi] Errore: " .. tostring(err))
	end
end

local ALIASES = { "/aiuto", "/comandi", "/livello", "/oro", "/gemme", "/capitolo", "/passo", "/vai", "/zone", "/cura" }

function DevCommandsService.Init(services)
	S = services
end

function DevCommandsService.Start()
	-- comandi registrati nella chat moderna (così non vengono inviati come messaggi)
	pcall(function()
		local folder = Instance.new("Folder")
		folder.Name = "ComandiDiProva"
		folder.Parent = TextChatService
		for _, alias in ALIASES do
			local command = Instance.new("TextChatCommand")
			command.Name = string.sub(alias, 2)
			command.PrimaryAlias = alias
			command.Parent = folder
			command.Triggered:Connect(function(source: TextSource, text: string)
				local player = Players:GetPlayerByUserId(source.UserId)
				if player then
					handle(player, text)
				end
			end)
		end
	end)
	local function watch(player: Player)
		player.Chatted:Connect(function(message)
			handle(player, message)
		end)
		if RunService:IsStudio() then
			task.delay(8, function()
				if player.Parent then
					say(player, "Comandi di prova attivi (solo in Studio): scrivi /aiuto in chat")
				end
			end)
		end
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		lastRun[player] = nil
	end)
end

return DevCommandsService
