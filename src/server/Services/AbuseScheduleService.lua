--[[
	AbuseScheduleService - gli eventi dell'Admin Abuse programmati per un giorno e un'ora
	Dal Pannello Admin (P → 😈 Admin Abuse → 📅 Programma) l'admin sceglie evento, durata, premi, data,
	ora e un annuncio. Il programma è salvato (DataStore) e condiviso con tutti i server del gioco
	(MessagingService): ogni server avvisa i suoi giocatori prima dell'inizio (30, 10, 5 e 1 minuto
	prima) e all'ora giusta fa partire l'evento, con l'annuncio dell'admin.
	Chi entra in un server mentre un evento programmato è in corso lo trova già partito.
	Gli orari sono secondi Unix (UTC): il client li converte nell'ora del proprio computer.
	Il client legge il programma dagli attributi di ReplicatedStorage:
	  ProgrammaEventi (JSON), ProssimoEvento (id), ProssimoEventoAlle (secondi Unix), ProssimoEventoTesto.
	In Studio senza "Enable Studio Access to API Services" il programma vale solo per quel server.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AbuseEvents = require(Shared.Data.AbuseEvents)

local AbuseScheduleService = {}
local S

local STORE_NAME = "SieriPerduti_Eventi_v1"
local KEY = "Programma"
local TOPIC = "AdminAbuseProgramma"
local RELOAD_EVERY = 120

local SCHEDULE = AbuseEvents.Schedule

type Entry = {
	Uid: string,
	Event: string,
	Minutes: number,
	At: number,
	Text: string,
	Rewards: { [string]: boolean },
	By: string,
	Created: number,
}

local store: DataStore? = nil
local entries: { Entry } = {}
local reminded: { [string]: boolean } = {} -- "uid:minuti" già annunciati in questo server
local started: { [string]: boolean } = {} -- eventi programmati già fatti partire in questo server
local lastReload = 0
local warned = false

-- secondi Unix (UTC), uguali in tutti i server (le prove automatiche possono cambiare l'orologio)
AbuseScheduleService.Clock = os.time
local function now(): number
	return AbuseScheduleService.Clock()
end

-- solo le voci valide (dati salvati o arrivati da un altro server)
local function clean(list: any): { Entry }
	local out = {}
	if type(list) ~= "table" then
		return out
	end
	for _, e in list do
		if type(e) == "table" and type(e.Uid) == "string" and type(e.Event) == "string" and type(e.At) == "number" and e.At == e.At then
			table.insert(out, {
				Uid = string.sub(e.Uid, 1, 64),
				Event = e.Event,
				Minutes = AbuseEvents.ClampMinutes(e.Minutes),
				At = math.floor(e.At),
				Text = if type(e.Text) == "string" then string.sub(e.Text, 1, SCHEDULE.MaxText) else "",
				Rewards = AbuseEvents.CleanRewards(e.Rewards),
				By = if type(e.By) == "string" then string.sub(e.By, 1, 40) else "Admin",
				Created = if type(e.Created) == "number" then e.Created else 0,
			})
		end
	end
	table.sort(out, function(a, b)
		return a.At < b.At
	end)
	return out
end

local function expired(e: Entry, t: number): boolean
	return t > e.At + e.Minutes * 60 + 60
end

-- ATTRIBUTI PER I CLIENT ----------------------------------------------------------------------------------

local function publish()
	local t = now()
	local visible = {}
	local nextEntry: Entry? = nil
	for _, e in entries do
		if not expired(e, t) then
			table.insert(visible, { Uid = e.Uid, Event = e.Event, Minutes = e.Minutes, At = e.At, Text = e.Text, By = e.By, Rewards = e.Rewards })
			if e.At > t and (nextEntry == nil or e.At < (nextEntry :: Entry).At) then
				nextEntry = e
			end
		end
	end
	ReplicatedStorage:SetAttribute("ProgrammaEventi", HttpService:JSONEncode(visible))
	local n = nextEntry
	ReplicatedStorage:SetAttribute("ProssimoEvento", if n then n.Event else nil)
	ReplicatedStorage:SetAttribute("ProssimoEventoAlle", if n then n.At else nil)
	ReplicatedStorage:SetAttribute("ProssimoEventoTesto", if n and n.Text ~= "" then n.Text else nil)
end

-- SALVATAGGIO E ALTRI SERVER ------------------------------------------------------------------------------

local function warnOnce(message: string)
	if not warned then
		warned = true
		warn("[Admin Abuse] " .. message)
	end
end

local function load()
	lastReload = os.clock()
	if not store then
		return
	end
	local ok, result = pcall(function()
		return (store :: DataStore):GetAsync(KEY)
	end)
	if ok then
		entries = clean(result)
		publish()
	else
		warnOnce("Programma degli eventi non letto: " .. tostring(result))
	end
end

local function broadcast()
	task.spawn(function()
		pcall(function()
			MessagingService:PublishAsync(TOPIC, { Op = "Aggiorna", From = game.JobId })
		end)
	end)
end

-- modifica il programma (salvato, se si può) e lo fa sapere agli altri server
local function mutate(change: ({ Entry }) -> ()): boolean
	if store then
		local ok, result = pcall(function()
			return (store :: DataStore):UpdateAsync(KEY, function(old)
				local list = clean(old)
				change(list)
				local t = now()
				local kept = {}
				for _, e in list do
					if not expired(e, t) then
						table.insert(kept, e)
					end
				end
				return kept
			end)
		end)
		if ok then
			entries = clean(result)
			publish()
			broadcast()
			return true
		end
		warnOnce("Programma degli eventi non salvato (vale solo per questo server): " .. tostring(result))
	end
	change(entries)
	entries = clean(entries)
	publish()
	return true
end

-- TESTO DELL'ANNUNCIO --------------------------------------------------------------------------------------

-- Il testo passa dal filtro di Roblox prima di essere mostrato a tutti (in Studio, se il filtro
-- non c'è, resta com'è). Restituisce il testo filtrato, oppure nil e il motivo.
function AbuseScheduleService.Filter(admin: Player, text: any): (string?, string?)
	if type(text) ~= "string" then
		return "", nil
	end
	text = string.sub(string.gsub(text, "^%s+", ""), 1, SCHEDULE.MaxText)
	text = string.gsub(text, "%s+$", "")
	if text == "" then
		return "", nil
	end
	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(text, admin.UserId)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if ok and type(filtered) == "string" then
		return filtered, nil
	end
	if RunService:IsStudio() then
		return text, nil
	end
	return nil, "Annuncio non accettato dal filtro di Roblox: riprova tra poco"
end

-- API ---------------------------------------------------------------------------------------------------

function AbuseScheduleService.List(): { Entry }
	return entries
end

-- Programma un evento. at = secondi Unix (UTC) dell'inizio. Restituisce ok e un messaggio per l'admin.
function AbuseScheduleService.Schedule(admin: Player, eventId: any, minutes: any, at: any, text: any, rewards: any): (boolean, string)
	local def = AbuseEvents.Get(eventId)
	if not def or not AbuseEvents.Available(def) then
		return false, "Scegli un evento di questo file"
	end
	if type(at) ~= "number" or at ~= at then
		return false, "Data e ora non valide"
	end
	local t = now()
	at = math.floor(at)
	if at < t + 30 then
		return false, "L'ora scelta è già passata (o è tra meno di 30 secondi): per adesso usa il pulsante dell'evento"
	end
	if at > t + SCHEDULE.MaxDaysAhead * 86400 then
		return false, ("Si può programmare al massimo %d giorni prima"):format(SCHEDULE.MaxDaysAhead)
	end
	local filtered, why = AbuseScheduleService.Filter(admin, text)
	if not filtered then
		return false, why or "Annuncio non valido"
	end
	local mins = AbuseEvents.ClampMinutes(minutes)
	-- niente due eventi che si sovrappongono
	for _, e in entries do
		if not expired(e, t) and at < e.At + e.Minutes * 60 and e.At < at + mins * 60 then
			local other = AbuseEvents.Get(e.Event)
			return false, ("Si sovrappone a %s %s già programmato"):format(other and other.Icon or "", other and other.Name or e.Event)
		end
	end
	if #entries >= SCHEDULE.MaxEntries then
		return false, ("Ci sono già %d eventi programmati: annullane qualcuno"):format(#entries)
	end
	local entry: Entry = {
		Uid = HttpService:GenerateGUID(false),
		Event = def.Id,
		Minutes = mins,
		At = at,
		Text = filtered,
		Rewards = AbuseEvents.CleanRewards(rewards),
		By = admin.DisplayName,
		Created = t,
	}
	mutate(function(list)
		table.insert(list, entry)
	end)
	local wait = at - t
	local days = wait // 86400
	local hours = (wait % 86400) // 3600
	local mins2 = (wait % 3600) // 60
	local when = if days > 0 then ("tra %d g %d h"):format(days, hours) elseif hours > 0 then ("tra %d h %d min"):format(hours, mins2) else ("tra %d min"):format(math.max(1, mins2))
	return true, ("📅 %s %s programmato %s (%d minuti). Avvisi 30, 10, 5 e 1 minuto prima."):format(def.Icon, def.Name, when, mins)
end

function AbuseScheduleService.Cancel(_admin: Player, uid: any): (boolean, string)
	if type(uid) ~= "string" then
		return false, "Evento non trovato"
	end
	local found: Entry? = nil
	for _, e in entries do
		if e.Uid == uid then
			found = e
		end
	end
	if not found then
		return false, "Evento non trovato (forse è già finito)"
	end
	mutate(function(list)
		for i = #list, 1, -1 do
			if list[i].Uid == uid then
				table.remove(list, i)
			end
		end
	end)
	local def = AbuseEvents.Get((found :: Entry).Event)
	if def and started[uid] and S.AbuseService and S.AbuseService.Current() == def.Id then
		-- già partito qui: lo si ferma con il pulsante "Termina l'evento in corso"
		return true, "Programma annullato (l'evento già partito si ferma con ⏹️ Termina)"
	end
	return true, ("Annullato: %s %s"):format(def and def.Icon or "", def and def.Name or (found :: Entry).Event)
end

-- Fa partire subito un evento con i premi e l'annuncio scelti dall'admin
function AbuseScheduleService.LaunchNow(admin: Player, eventId: any, minutes: any, text: any, rewards: any): (boolean, string)
	local filtered, why = AbuseScheduleService.Filter(admin, text)
	if not filtered then
		return false, why or "Annuncio non valido"
	end
	return S.AbuseService.Launch(eventId, minutes, { Rewards = AbuseEvents.CleanRewards(rewards), Text = filtered, By = admin.DisplayName })
end

-- AVVISI E PARTENZA -------------------------------------------------------------------------------------

local function remind(e: Entry, minutesBefore: number)
	local def = AbuseEvents.Get(e.Event)
	if not def then
		return
	end
	local title = ("📅 Tra %d minut%s: %s %s!"):format(minutesBefore, if minutesBefore == 1 then "o" else "i", def.Icon, def.Name)
	local subtitle = if e.Text ~= "" then e.Text .. "  — " .. e.By else def.Short
	S.EventService.Announce(title, subtitle, "Raro")
end

function AbuseScheduleService.Step()
	local t = now()
	local changed = false
	for _, e in entries do
		if not expired(e, t) then
			for _, m in SCHEDULE.Reminders do
				local key = e.Uid .. ":" .. m
				local at = e.At - m * 60
				-- solo nella finestra giusta: un server partito dopo non ripete gli avvisi vecchi
				if not reminded[key] and t >= at and t < at + 50 then
					reminded[key] = true
					remind(e, m)
				end
			end
			local finish = e.At + e.Minutes * 60
			if not started[e.Uid] and t >= e.At and t < finish - 30 then
				started[e.Uid] = true
				changed = true
				local left = math.max(1, math.floor((finish - t) / 60 + 0.5))
				local def = AbuseEvents.Get(e.Event)
				if def and AbuseEvents.Available(def) and S.AbuseService then
					local ok, message = S.AbuseService.Launch(e.Event, left, { Rewards = e.Rewards, Text = if e.Text ~= "" then e.Text else nil, By = e.By })
					print(("[Admin Abuse] Evento programmato: %s (%s)"):format(e.Event, tostring(message)))
					if not ok then
						warn("[Admin Abuse] " .. tostring(message))
					end
				end
			end
		end
	end
	if changed then
		publish()
	end
	-- ogni tanto si rilegge il programma (se un messaggio fra server si è perso)
	if os.clock() - lastReload > RELOAD_EVERY then
		task.spawn(load)
	end
end

function AbuseScheduleService.Init(services)
	S = services
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warnOnce("Programma degli eventi senza salvataggio: " .. tostring(result))
	end
end

function AbuseScheduleService.Start()
	task.spawn(load)
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(message)
				local data = message and message.Data
				if type(data) == "table" and data.From ~= game.JobId then
					task.spawn(load)
				end
			end)
		end)
	end)
	publish()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 then
			acc = 0
			local ok, err = pcall(AbuseScheduleService.Step)
			if not ok then
				warn("[Admin Abuse] Programma: " .. tostring(err))
			end
		end
	end)
	Players.PlayerAdded:Connect(function()
		publish()
	end)
end

return AbuseScheduleService
