--[[
	DataService
	Carica e salva i progressi dei giocatori con DataStoreService.
	- Blocco di sessione: evita che due server sovrascrivano gli stessi dati.
	- Salvataggio automatico ogni Config.AutosaveInterval secondi e all'uscita.
	- In Studio senza "Enable Studio Access to API Services" si gioca senza salvare.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Lib.Util)
local Signal = require(Shared.Lib.Signal)
local Net = require(Shared.Lib.Net)
local Bloodlines = require(Shared.Data.Bloodlines)

local DataService = {}
DataService.Loaded = Signal.new()

local profiles: { [Player]: any } = {}
local noSave: { [Player]: boolean } = {}
local dirty: { [Player]: boolean } = {}

local store: DataStore? = nil
local SESSION_TIMEOUT = 900

local TEMPLATE = {
	Version = 1,
	Level = 1,
	XP = 0,
	Gold = Config.StartGold,
	StatPoints = 0,
	Stats = { Forza = 0, Vitalita = 0, Agilita = 0, Mira = 0, Gigante = 0 },
	Bloodline = "",
	Inventory = {
		LameAddestramento = 1,
		DMTAddestramento = 1,
		UniformeCadetto = 1,
		FialaSpezzata = 1,
		Razione = 3,
		BombolaGas = 1,
	},
	Equipped = { Blade = "LameAddestramento", Gear = "DMTAddestramento", Armor = "UniformeCadetto", Ranged = "", Accessory = "" },
	WeaponMastery = {},
	Serum = "",
	SerumMastery = {},
	StoredSerums = {},
	Quest = { Id = "", Progress = 0 },
	Story = { Chapter = 1, Step = 1, Progress = 0, Done = false },
	Visited = { CampoAddestramento = true },
	SpawnZone = "CampoAddestramento",
	Kills = { Titans = 0, Napes = 0, Enemies = 0, Bosses = 0 },
	BossKills = {},
	Codes = {},
	Settings = { Shake = true, SpeedLines = true, DamageNumbers = true, Scenery = true, Music = 0.5, Sfx = 0.8, Sensitivity = 1, ShiftLock = true },
	Buffs = {},
	Gems = 0,
	Passes = {},
	Receipts = {},
	FirstBossGems = {},
	LastDailyGems = 0,
	LastDailyLogin = 0,
	RaidsWon = 0,
	PlayTime = 0,
	-- premi e community
	Streak = { Day = 0, Last = 0, Count = 0, Best = 0 },
	PlayToday = { Day = 0, Seconds = 0, Claimed = {} },
	Spins = 0,
	FreeSpinAt = 0,
	Achievements = {},
	StarterBought = false,
	GroupRewarded = false,
	FavoritePrompted = false,
	FriendsSeen = 0,
	CreatedAt = 0,
	LastSeen = 0,
}

DataService.Template = TEMPLATE

local function keyFor(player: Player): string
	return "Giocatore_" .. player.UserId
end

local function isStudio(): boolean
	return RunService:IsStudio()
end

local function newProfile()
	local profile = Util.DeepCopy(TEMPLATE)
	profile.CreatedAt = os.time()
	return profile
end

-- Rimuove valori non salvabili (NaN, infinito) e chiavi strane
local function sanitize(value: any): any
	local t = type(value)
	if t == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return 0
		end
		return value
	elseif t == "table" then
		local out = {}
		for k, v in value do
			if type(k) == "string" or type(k) == "number" then
				out[k] = sanitize(v)
			end
		end
		return out
	elseif t == "string" or t == "boolean" then
		return value
	end
	return nil
end

-- Dati inviati al client (senza i campi interni che iniziano con "_")
local function snapshot(profile)
	local out = {}
	for k, v in profile do
		if type(k) ~= "string" or k:sub(1, 1) ~= "_" then
			out[k] = v
		end
	end
	return out
end

local function loadFromStore(player: Player)
	if not store then
		return nil, "nostore"
	end
	local key = keyFor(player)
	local result = nil
	local lockedByOther = false
	for attempt = 1, 6 do
		lockedByOther = false
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key, function(old)
				local now = os.time()
				if type(old) == "table" and type(old.Lock) == "table" then
					local lock = old.Lock
					if lock.Job ~= game.JobId and now - (lock.Time or 0) < SESSION_TIMEOUT and attempt < 6 then
						lockedByOther = true
						result = nil
						return nil -- annulla la scrittura, riproveremo
					end
				end
				local data = if type(old) == "table" and type(old.Data) == "table" then old.Data else nil
				result = data
				return { Data = data or newProfile(), Lock = { Job = game.JobId, Time = now } }
			end)
		end)
		if ok and not lockedByOther then
			return result or newProfile(), nil
		end
		if not ok then
			warn(("[DataService] Caricamento fallito per %s (tentativo %d): %s"):format(player.Name, attempt, tostring(err)))
		end
		task.wait(if lockedByOther then 4 else 2 * attempt)
	end
	return nil, "failed"
end

local function saveToStore(player: Player, release: boolean): boolean
	if not store or noSave[player] then
		return false
	end
	local profile = profiles[player]
	if not profile then
		return false
	end
	profile.LastSeen = os.time()
	local data = sanitize(snapshot(profile))
	local key = keyFor(player)
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key, function(old)
				if type(old) == "table" and type(old.Lock) == "table" and old.Lock.Job ~= game.JobId then
					-- un altro server ha preso il controllo: non sovrascrivere
					if os.time() - (old.Lock.Time or 0) < SESSION_TIMEOUT then
						return nil
					end
				end
				return { Data = data, Lock = if release then nil else { Job = game.JobId, Time = os.time() } }
			end)
		end)
		if ok then
			return true
		end
		warn(("[DataService] Salvataggio fallito per %s (tentativo %d): %s"):format(player.Name, attempt, tostring(err)))
		task.wait(1.5 * attempt)
	end
	return false
end

local function onPlayerAdded(player: Player)
	local profile, err = loadFromStore(player)
	if not player.Parent then
		return
	end
	if not profile then
		if isStudio() or err == "nostore" then
			warn("[DataService] Salvataggi disattivati (attiva 'Enable Studio Access to API Services' per salvare in Studio).")
			profile = newProfile()
			noSave[player] = true
		else
			player:Kick("Non è stato possibile caricare i tuoi dati. Riprova tra qualche minuto: i tuoi progressi sono al sicuro.")
			return
		end
	end

	Util.Reconcile(profile, TEMPLATE)
	if profile.Bloodline == "" or not Bloodlines.List[profile.Bloodline] then
		profile.Bloodline = Bloodlines.Roll()
		profile._NewBloodline = true
	end
	profile._Joined = os.clock()
	profiles[player] = profile
	dirty[player] = true
	DataService.Loaded:Fire(player, profile)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile and profile._Joined then
		profile.PlayTime += math.floor(os.clock() - profile._Joined)
		profile._Joined = os.clock()
	end
	saveToStore(player, true)
	profiles[player] = nil
	noSave[player] = nil
	dirty[player] = nil
end

-- API ---------------------------------------------------------------------------------

function DataService.Get(player: Player)
	return profiles[player]
end

function DataService.WaitFor(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 60)
	while not profiles[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService.IsSaving(player: Player): boolean
	return not noSave[player]
end

-- Segna il profilo come modificato: verrà inviato al client a breve
function DataService.MarkDirty(player: Player)
	dirty[player] = true
end

function DataService.SyncNow(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	dirty[player] = false
	local extra = DataService.ExtraProvider and DataService.ExtraProvider(player, profile) or nil
	Net.Event("DataSync"):FireClient(player, snapshot(profile), extra)
end

-- Altri servizi possono aggiungere dati calcolati da inviare al client
DataService.ExtraProvider = nil :: ((Player, any) -> any)?

function DataService.Save(player: Player)
	return saveToStore(player, false)
end

function DataService.Init(_services)
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore non disponibile: " .. tostring(result))
	end
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- invio dei dati modificati al client (4 volte al secondo al massimo)
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player, isDirty in dirty do
				if isDirty and profiles[player] then
					DataService.SyncNow(player)
				end
			end
		end
	end)

	-- salvataggio automatico
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for _, player in Players:GetPlayers() do
				local profile = profiles[player]
				if profile and profile._Joined then
					profile.PlayTime += math.floor(os.clock() - profile._Joined)
					profile._Joined = os.clock()
				end
				task.spawn(saveToStore, player, false)
			end
		end
	end)

	game:BindToClose(function()
		if isStudio() and not store then
			return
		end
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				saveToStore(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
