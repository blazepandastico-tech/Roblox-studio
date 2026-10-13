--[[
	AdminPanel - Pannello Admin (tasto P o pulsante 🛠️, visibile solo agli amministratori)
	Categorie: Progressione • Oggetti • Sieri • Poteri • Mondo • Storia • Server • Admin Abuse
	In alto si sceglie il BERSAGLIO (tu o un altro giocatore) e si può scrivere un VALORE
	(numero o testo) usato dai pulsanti che lo richiedono.
	Tutte le azioni vengono controllate dal server (AdminService).
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Lib.Net)
local Items = require(Shared.Data.Items)
local Serums = require(Shared.Data.Serums)
local Titans = require(Shared.Data.Titans)
local Zones = require(Shared.Data.Zones)
local Story = require(Shared.Data.Story)
local AbuseEvents = require(Shared.Data.AbuseEvents)

local Theme = require(script.Parent.Theme)
local New = Theme.New
local Colors = Theme.Colors

local AdminPanel = {}
local C

local player = Players.LocalPlayer

local panel: Frame
local content: ScrollingFrame
local valueBox: TextBox
local targetButton: TextButton
local categoryButtons: { [string]: TextButton } = {}
local currentCategory = "Progressione"
local targetUserId = player.UserId

local CATEGORIES = {
	{ Id = "Progressione", Icon = "⭐" },
	{ Id = "Oggetti", Icon = "🎒" },
	{ Id = "Sieri", Icon = "💉" },
	{ Id = "Poteri", Icon = "⚡" },
	{ Id = "Mondo", Icon = "🌍" },
	{ Id = "Storia", Icon = "📜" },
	{ Id = "Server", Icon = "📢" },
	{ Id = "Admin Abuse", Icon = "😈" },
}

local function isAdmin(): boolean
	return player:GetAttribute("Admin") == true
end

local function target(): Player
	return Players:GetPlayerByUserId(targetUserId) or player
end

local function send(action: string, value: any?)
	C.SoundController.Play("UI")
	Net.Event("AdminAction"):FireServer(action, targetUserId, value)
end

local function typedValue(): string
	return valueBox and valueBox.Text or ""
end

-- ELEMENTI ---------------------------------------------------------------------------------------

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

local function section(title: string, hint: string?)
	Theme.Label(title, { Size = UDim2.new(1, -10, 0, 26), LayoutOrder = nextOrder(), Font = Theme.Fonts.Header, TextSize = 18, TextColor3 = Colors.GoldBright, Parent = content })
	if hint then
		Theme.Label(hint, { Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(), Font = Theme.Fonts.UI, TextSize = 12, TextColor3 = Colors.TextDim, Parent = content })
	end
end

local function row(cellWidth: number?, cellHeight: number?): Frame
	local frame = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(), Parent = content })
	New("UIGridLayout", { CellSize = UDim2.fromOffset(cellWidth or 168, cellHeight or 40), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
	return frame
end

local function button(parent: Instance, text: string, color: Color3?, onClick: () -> ())
	return Theme.Button(text, { TextSize = 13, BackgroundColor3 = color or Colors.PanelLight, Parent = parent }, onClick)
end

local GREEN = Color3.fromRGB(46, 120, 66)
local BLUE = Color3.fromRGB(46, 96, 150)
local RED = Color3.fromRGB(150, 46, 46)
local PURPLE = Color3.fromRGB(110, 60, 150)

-- CATEGORIE --------------------------------------------------------------------------------------

local function showProgression()
	section("Livello", "Il VALORE in alto serve per \"Imposta livello\".")
	local r = row()
	button(r, "👑 Livello MASSIMO", GREEN, function()
		send("LevelMax")
	end)
	button(r, "+100 livelli", nil, function()
		send("LevelAdd", 100)
	end)
	button(r, "+10 livelli", nil, function()
		send("LevelAdd", 10)
	end)
	button(r, "Imposta livello (valore)", BLUE, function()
		send("LevelSet", tonumber(typedValue()))
	end)
	section("Statistiche")
	r = row()
	button(r, "💪 Statistiche al MASSIMO", GREEN, function()
		send("StatsMax")
	end)
	button(r, "Azzera statistiche", nil, function()
		send("StatsReset")
	end)
	section("Valute", "Con un numero nel VALORE, i pulsanti \"(valore)\" danno quella quantità.")
	r = row()
	button(r, "💰 +1.000.000 oro", GREEN, function()
		send("Gold", 1000000)
	end)
	button(r, "💰 +100.000.000 oro", GREEN, function()
		send("Gold", 100000000)
	end)
	button(r, "💰 Oro (valore)", BLUE, function()
		send("Gold", tonumber(typedValue()))
	end)
	button(r, "💎 +10.000 gemme", GREEN, function()
		send("Gems", 10000)
	end)
	button(r, "💎 Gemme (valore)", BLUE, function()
		send("Gems", tonumber(typedValue()))
	end)
	button(r, "🎡 +50 giri Ruota", GREEN, function()
		send("Spins", 50)
	end)
	button(r, "🎁 Azzera premi", nil, function()
		send("ResetRewards")
	end)
end

local function showItems()
	section("Tutto in un clic")
	local r = row()
	button(r, "🎒 TUTTI gli oggetti", GREEN, function()
		send("AllItems")
	end)
	button(r, "🎟️ Tutti i game pass", PURPLE, function()
		send("AllPasses")
	end)
	button(r, "Rimuovi game pass", RED, function()
		send("RemovePasses")
	end)
	for _, category in Items.CategoryOrder do
		local list = {}
		for _, def in Items.List do
			if def.Category == category then
				table.insert(list, def)
			end
		end
		table.sort(list, function(a, b)
			return (a.LevelReq or 0) < (b.LevelReq or 0)
		end)
		if #list > 0 then
			section(category)
			r = row(168, 46)
			for _, def in list do
				local b = button(r, def.Name, nil, function()
					send("Item", def.Id)
				end)
				b.TextColor3 = Items.RarityColor(def.Rarity)
			end
		end
	end
end

local function showSerums()
	section("Sieri Perduti (solo admin)", "Per ora i sieri si ottengono SOLO da qui. Inietta un siero e premi T per trasformarti nel gigante.")
	local r = row()
	button(r, "⭐ Maestria MASSIMA", GREEN, function()
		send("SerumMastery")
	end)
	button(r, "🧳 Tutti e 8 in valigetta", BLUE, function()
		send("AllSerums")
	end)
	button(r, "🔁 Trasformati (T)", PURPLE, function()
		send("Transform")
	end)
	button(r, "Rimuovi siero", RED, function()
		send("RemoveSerum")
	end)
	local grid = row(220, 120)
	local current = C.ClientData.Profile and C.ClientData.Profile.Serum or ""
	for _, id in Serums.Order do
		local serum = Serums.Get(id)
		if serum then
			local card = Theme.Panel({ BackgroundColor3 = if current == id then Color3.fromRGB(60, 50, 24) else Colors.Background, Parent = grid })
			Theme.Padding(card, 8)
			Theme.Label(serum.TitanName, { Size = UDim2.new(1, 0, 0, 20), Font = Theme.Fonts.Bold, TextSize = 15, TextColor3 = Items.RarityColor(serum.Rarity), Parent = card })
			Theme.Label(serum.Passive or "", { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 44), Font = Theme.Fonts.UI, TextSize = 11, TextColor3 = Colors.TextDim, Parent = card })
			Theme.Button(if current == id then "✔ Attivo" else "💉 Inietta", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 32), TextSize = 14, BackgroundColor3 = GREEN, Parent = card }, function()
				send("Serum", id)
			end)
		end
	end
end

local function toggleText(attribute: string, name: string): string
	local on = target():GetAttribute(attribute) == true
	return ("%s: %s"):format(name, if on then "ON" else "OFF")
end

local function showPowers()
	section("Poteri", "Valgono per il bersaglio scelto in alto e durano finché resta nel server.")
	local r = row(220, 44)
	local function toggle(action: string, attribute: string, name: string)
		local b
		b = button(r, toggleText(attribute, name), if target():GetAttribute(attribute) then GREEN else nil, function()
			send(action)
			task.delay(0.3, function()
				if b.Parent then
					b.Text = toggleText(attribute, name)
					b.BackgroundColor3 = if target():GetAttribute(attribute) then GREEN else Colors.PanelLight
				end
			end)
		end)
	end
	toggle("ToggleGod", "AdminGod", "🛡️ Immortalità")
	toggle("ToggleGas", "AdminGas", "💨 Gas infinito")
	toggle("ToggleOneShot", "AdminOneShot", "⚔️ Colpo unico")
	section("Velocità")
	r = row()
	for _, mult in { 1, 1.5, 2, 3 } do
		button(r, ("🏃 Velocità x%s"):format(tostring(mult)), if mult == 1 then nil else BLUE, function()
			send("Speed", mult)
		end)
	end
	section("Vita")
	r = row()
	button(r, "❤️ Cura completa", GREEN, function()
		send("Heal")
	end)
	button(r, "Rinasci", nil, function()
		send("Respawn")
	end)
end

local function showWorld()
	section("Giocatori", "Scegli un altro giocatore come BERSAGLIO in alto.")
	local r = row()
	button(r, "📍 Vai dal bersaglio", BLUE, function()
		send("GoTo")
	end)
	button(r, "🧲 Porta il bersaglio da te", BLUE, function()
		send("BringTo")
	end)
	section("Giganti", "I giganti evocati compaiono davanti a te e spariscono dopo 10 minuti.")
	r = row(130, 40)
	for _, id in { "Sagoma", "T3", "T4", "T5", "T7", "T10", "T12", "T15", "TB" } do
		local class = Titans.Classes[id]
		if class then
			button(r, class.Name:gsub("Gigante da ", ""), nil, function()
				send("SpawnTitan", id)
			end)
		end
	end
	r = row()
	button(r, "☠️ Abbatti giganti vicini", RED, function()
		send("KillTitans")
	end)
	button(r, "🧹 Rimuovi giganti vicini", nil, function()
		send("ClearTitans")
	end)
	button(r, "⚠️ Invasione qui", RED, function()
		send("Invasion")
	end)
	section("Boss", "Evoca il boss e ti porta nella sua zona.")
	r = row()
	local bosses = {}
	for id, def in Titans.Bosses do
		if not def.Event then
			table.insert(bosses, { Id = id, Def = def })
		end
	end
	table.sort(bosses, function(a, b)
		return (a.Def.Level or 0) < (b.Def.Level or 0)
	end)
	for _, entry in bosses do
		button(r, ("👹 %s (Lv %d)"):format(entry.Def.Name, entry.Def.Level or 0), PURPLE, function()
			send("SpawnBoss", entry.Id)
		end)
	end
	section("Teletrasporto")
	r = row()
	for _, zone in Zones.List do
		button(r, zone.Name or zone.Id, nil, function()
			send("Teleport", zone.Id)
		end)
	end
	section("Meteo", "Cambia il tempo per tutto il server.")
	r = row(160, 40)
	for _, w in { { "Sereno", "☀️" }, { "Nuvoloso", "☁️" }, { "Pioggia", "🌧️" }, { "Temporale", "⛈️" } } do
		button(r, w[2] .. " " .. w[1], nil, function()
			send("Weather", w[1])
		end)
	end
	section("Ora del giorno")
	r = row(120, 40)
	for _, hour in { 6, 9, 12, 15, 18, 21, 0 } do
		button(r, ("🕐 %02d:00"):format(hour), nil, function()
			send("Time", hour)
		end)
	end
end

local function showStory()
	section("Storia")
	local r = row()
	button(r, "✔ Completa obiettivo", GREEN, function()
		send("StoryStep")
	end)
	button(r, "🏆 Storia completata", PURPLE, function()
		send("StoryDone")
	end)
	section("Salta a un capitolo")
	r = row(300, 40)
	for i, chapter in Story.Chapters do
		button(r, ("%d. %s (Lv %d)"):format(i, chapter.Title:gsub("^Capitolo %d+ %- ", ""), chapter.Level), nil, function()
			send("Chapter", i)
		end)
	end
end

local function showServer()
	section("Annuncio a tutti", "Scrivi il messaggio nel VALORE in alto, poi premi il pulsante (passa dal filtro di Roblox).")
	local r = row(220, 44)
	button(r, "📢 Invia annuncio", BLUE, function()
		send("Announce", typedValue())
	end)
	button(r, "⭐ Esperienza doppia (tutti)", GREEN, function()
		send("DoubleXP")
	end)
	section("Moderazione", "Scegli il giocatore come BERSAGLIO in alto.")
	r = row(220, 44)
	button(r, "🚫 Espelli il bersaglio", RED, function()
		if target() ~= player then
			send("Kick")
		end
	end)
	section("Amministratori", ("Per aggiungere altri admin nel gioco pubblicato, metti il loro nome in Config.lua → AdminNames (o l'UserId in Admins). Ora ci sono %d admin extra."):format(#Config.Admins + #(Config.AdminNames or {})))
end

-- 😈 ADMIN ABUSE: le animazioni dell'evento quando vuoi tu, più i comandi dell'evento
local render: () -> () -- definita più sotto (ridisegna la categoria aperta)
local abuseMinutes = AbuseEvents.DefaultMinutes
local abuseStatus: TextLabel? = nil
local abuseRewards = AbuseEvents.DefaultRewards()
local abuseText = "" -- annuncio dell'admin (facoltativo), per gli eventi subito e programmati
local scheduleEvent = (AbuseEvents.List[1] and AbuseEvents.List[1].Id) or ""
local scheduleAt = 0 -- secondi Unix dell'inizio scelto (0 = ancora da scegliere)
local scheduleLabel: TextLabel? = nil

-- ORA LOCALE DELL'ADMIN (il server lavora con i secondi Unix, uguali in tutto il mondo)
local GIORNI = { "dom", "lun", "mar", "mer", "gio", "ven", "sab" }

local function localParts(unix: number): { Year: number, Month: number, Day: number, Hour: number, Minute: number }
	local ok, t = pcall(function()
		return DateTime.fromUnixTimestamp(unix):ToLocalTime()
	end)
	if ok and type(t) == "table" then
		return t :: any
	end
	local d = os.date("*t", unix) :: any
	return { Year = d.year, Month = d.month, Day = d.day, Hour = d.hour, Minute = d.min }
end

local function fromLocal(year: number, month: number, day: number, hour: number, minute: number): number?
	local ok, dt = pcall(function()
		return DateTime.fromLocalTime(year, month, day, hour, minute, 0, 0)
	end)
	if ok and dt then
		return (dt :: DateTime).UnixTimestamp
	end
	local ok2, t = pcall(os.time, { year = year, month = month, day = day, hour = hour, min = minute, sec = 0 })
	return if ok2 then t else nil
end

local function weekday(unix: number): string
	local ok, w = pcall(function()
		return (os.date("*t", unix) :: any).wday
	end)
	return if ok and type(w) == "number" then GIORNI[w] or "" else ""
end

local function whenText(unix: number): string
	local p = localParts(unix)
	return ("%s %02d/%02d alle %02d:%02d"):format(weekday(unix), p.Day, p.Month, p.Hour, p.Minute)
end

local function untilText(unix: number): string
	local left = math.max(0, unix - os.time())
	local d, h, m = left // 86400, (left % 86400) // 3600, (left % 3600) // 60
	if d > 0 then
		return ("tra %d g %d h"):format(d, h)
	elseif h > 0 then
		return ("tra %d h %d min"):format(h, m)
	end
	return ("tra %d min"):format(math.max(1, m))
end

-- di base: la prossima ora piena, almeno tra 30 minuti
local function defaultScheduleAt(): number
	local t = os.time() + 1800
	return t - t % 3600 + 3600
end

-- "31/10 21:30", "31/10/2026 21:30" oppure solo "21:30" (oggi, o domani se è già passata)
local function parseWhen(text: string): number?
	local d, mo, y, h, mi = string.match(text, "^%s*(%d+)/(%d+)/(%d+)%s+(%d+)[:%.](%d+)%s*$")
	if not d then
		d, mo, h, mi = string.match(text, "^%s*(%d+)/(%d+)%s+(%d+)[:%.](%d+)%s*$")
	end
	local today = localParts(os.time())
	if not d then
		h, mi = string.match(text, "^%s*(%d+)[:%.](%d+)%s*$")
		if not h then
			return nil
		end
		local at = fromLocal(today.Year, today.Month, today.Day, tonumber(h) :: number, tonumber(mi) :: number)
		if at and at < os.time() then
			at += 86400
		end
		return at
	end
	local year = tonumber(y) or today.Year
	if year < 100 then
		year += 2000
	end
	local month, day, hour, minute = tonumber(mo) :: number, tonumber(d) :: number, tonumber(h) :: number, tonumber(mi) :: number
	if month < 1 or month > 12 or day < 1 or day > 31 or hour > 23 or minute > 59 then
		return nil
	end
	local at = fromLocal(year, month, day, hour, minute)
	-- senza anno: se la data è già passata quest'anno, è quella dell'anno prossimo
	if at and not y and at < os.time() - 3600 then
		at = fromLocal(year + 1, month, day, hour, minute)
	end
	return at
end

local function scheduleText(): string
	local def = AbuseEvents.Get(scheduleEvent)
	return ("📅 %s %s  •  %s (%s)  •  %d minut%s"):format(def and def.Icon or "", def and def.Name or "?", whenText(scheduleAt), untilText(scheduleAt), abuseMinutes, if abuseMinutes == 1 then "o" else "i")
end

local function scheduledList(): { any }
	local raw = ReplicatedStorage:GetAttribute("ProgrammaEventi")
	if type(raw) ~= "string" or raw == "" then
		return {}
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok and type(data) == "table" then data else {}
end

local function abuseStatusText(): string
	local def = AbuseEvents.Get(ReplicatedStorage:GetAttribute("AbuseEvento"))
	local chosen = ("Durata scelta: %d minut%s"):format(abuseMinutes, if abuseMinutes == 1 then "o" else "i")
	if not def then
		return chosen .. "   •   Nessun evento in corso"
	end
	local ends = ReplicatedStorage:GetAttribute("AbuseFine")
	local left = if type(ends) == "number" then ends - workspace:GetServerTimeNow() else 0
	return ("%s   •   IN CORSO: %s %s (mancano %s)"):format(chosen, def.Icon, def.Name, AbuseEvents.FormatTime(left))
end

local function eventButton(parent: Instance, def, onClick: () -> ())
	local b = button(parent, ("%s %s\n%s"):format(def.Icon, def.Name, def.Short), def.Color:Lerp(Color3.new(0, 0, 0), 0.6), onClick)
	local stroke = b:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = def.Color
		stroke.Transparency = 0.1
	end
	return b
end

local function showAbuse()
	if scheduleAt == 0 then
		scheduleAt = defaultScheduleAt()
	end
	section("😈 Admin Abuse", "Le animazioni dell'evento partono quando vuoi tu: annuncia l'Admin Abuse e scatenati!")
	local r = row(220, 44)
	button(r, "😈 Annuncia ADMIN ABUSE", RED, function()
		send("Abuse", "announce")
	end)
	-- 🎁 PREMI E 📢 ANNUNCIO (valgono per l'evento che fai partire subito e per quelli programmati)
	section("🎁 Premi dell'evento", "Accendi i premi in più per i giocatori. Valgono per il prossimo evento che fai partire o che programmi.")
	r = row(256, 50)
	for _, reward in AbuseEvents.Rewards do
		local on = abuseRewards[reward.Id] == true
		local b = button(r, ("%s %s: %s"):format(reward.Icon, reward.Name, if on then "SÌ" else "NO"), if on then Colors.Green else nil, function()
			abuseRewards[reward.Id] = not abuseRewards[reward.Id]
			render()
		end)
		b.TextSize = 13
	end
	for _, reward in AbuseEvents.Rewards do
		Theme.Label(("%s %s: %s"):format(reward.Icon, reward.Name, reward.Text), { Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(), Font = Theme.Fonts.UI, TextSize = 12, TextColor3 = Colors.TextDim, Parent = content })
	end
	section("📢 Annuncio", "Facoltativo: lo vedono tutti nel titolo dell'evento e alla fine dell'animazione (e negli avvisi degli eventi programmati). Passa dal filtro di Roblox.")
	local box = New("TextBox", {
		Size = UDim2.new(1, -10, 0, 38),
		LayoutOrder = nextOrder(),
		BackgroundColor3 = Colors.Background,
		TextColor3 = Colors.Text,
		PlaceholderText = "Es.: Stasera alle 21 tutti alle Pianure Meridionali! 🎃",
		PlaceholderColor3 = Colors.TextDim,
		Font = Theme.Fonts.Bold,
		TextSize = 14,
		ClearTextOnFocus = false,
		Text = abuseText,
		Parent = content,
	})
	Theme.Corner(box, 8)
	Theme.Stroke(box, Colors.Border, 1, 0.3)
	box.FocusLost:Connect(function()
		abuseText = string.sub(box.Text, 1, AbuseEvents.Schedule.MaxText)
	end)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		abuseText = string.sub(box.Text, 1, AbuseEvents.Schedule.MaxText)
	end)
	-- 🎬 ANIMAZIONI: gli eventi a tempo
	section("🎬 Animazioni", "1) Scegli quanto dura l'evento (o scrivi i minuti nel VALORE in alto e premi ✏️).  2) Clicca un evento: parte SUBITO un'animazione per tutti i giocatori, poi l'evento dura il tempo scelto.")
	r = row(90, 36)
	for _, minutes in AbuseEvents.Durations do
		button(r, ("⏱️ %d min"):format(minutes), if minutes == abuseMinutes then Colors.Green else nil, function()
			abuseMinutes = minutes
			render()
		end)
	end
	button(r, "✏️ VALORE", if table.find(AbuseEvents.Durations, abuseMinutes) then nil else Colors.Green, function()
		if tonumber(typedValue()) then
			abuseMinutes = AbuseEvents.ClampMinutes(typedValue())
			render()
		elseif C.Notifications then
			C.Notifications.Toast(("Scrivi i minuti (da %d a %d) nel VALORE in alto"):format(AbuseEvents.MinMinutes, AbuseEvents.MaxMinutes), "Errore", 3)
		end
	end)
	local halloweenEvents, seasonEvents = {}, {}
	for _, def in AbuseEvents.List do
		table.insert(if def.Theme == "Halloween" then halloweenEvents else seasonEvents, def)
	end
	for _, group in { { "🎃 Eventi di Halloween", halloweenEvents }, { "🗡️ Eventi della prima stagione", seasonEvents } } do
		if #group[2] > 0 then
			Theme.Label(group[1], { Size = UDim2.new(1, -10, 0, 20), LayoutOrder = nextOrder(), Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = Colors.Gold, Parent = content })
			r = row(256, 64)
			for _, def in group[2] do
				eventButton(r, def, function()
					send("AbuseEvent", { Id = def.Id, Minutes = abuseMinutes, Rewards = abuseRewards, Text = abuseText })
				end)
			end
		end
	end
	abuseStatus = Theme.Label(abuseStatusText(), { Size = UDim2.new(1, -10, 0, 22), LayoutOrder = nextOrder(), Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = Colors.GoldBright, Parent = content })
	r = row(220, 44)
	button(r, "⏹️ Termina l'evento in corso", RED, function()
		send("AbuseStop")
	end)

	-- 📅 PROGRAMMA PER DOPO: evento, giorno, ora, durata, premi e annuncio
	section("📅 Programma un evento", "Scegli l'evento, poi giorno e ora (la tua ora). All'ora giusta parte da solo in TUTTI i server, con l'annuncio e i premi scelti sopra; prima arrivano gli avvisi (30, 10, 5 e 1 minuto prima). Si può scrivere anche la data nel VALORE in alto (es. 31/10 21:30) e premere ✏️.")
	r = row(160, 40)
	for _, def in AbuseEvents.List do
		local b = button(r, ("%s %s"):format(def.Icon, def.Name), if def.Id == scheduleEvent then Colors.Green else def.Color:Lerp(Color3.new(0, 0, 0), 0.65), function()
			scheduleEvent = def.Id
			render()
		end)
		b.TextSize = 11
	end
	scheduleLabel = Theme.Label(scheduleText(), { Size = UDim2.new(1, -10, 0, 24), LayoutOrder = nextOrder(), Font = Theme.Fonts.Bold, TextSize = 15, TextColor3 = Colors.GoldBright, Parent = content })
	r = row(96, 34)
	local function shift(seconds: number)
		scheduleAt = math.max(os.time() + 60, scheduleAt + seconds)
		render()
	end
	for _, step in { { "Oggi", 0 }, { "Domani", 1 } } do
		button(r, "📆 " .. step[1], nil, function()
			local now = localParts(os.time())
			local chosen = localParts(scheduleAt)
			local at = fromLocal(now.Year, now.Month, now.Day, chosen.Hour, chosen.Minute)
			if at then
				scheduleAt = at + step[2] * 86400
				render()
			end
		end)
	end
	for _, step in { { "-1 g", -86400 }, { "+1 g", 86400 }, { "-1 h", -3600 }, { "+1 h", 3600 }, { "-10 min", -600 }, { "+10 min", 600 }, { "-1 min", -60 }, { "+1 min", 60 } } do
		button(r, step[1], nil, function()
			shift(step[2])
		end)
	end
	button(r, "✏️ VALORE", BLUE, function()
		local at = parseWhen(typedValue())
		if at then
			scheduleAt = at
			render()
		elseif C.Notifications then
			C.Notifications.Toast("Scrivi la data nel VALORE in alto: 31/10 21:30 (oppure solo 21:30)", "Errore", 4)
		end
	end)
	r = row(300, 46)
	button(r, "📅 PROGRAMMA QUESTO EVENTO", GREEN, function()
		send("AbuseSchedule", { Id = scheduleEvent, Minutes = abuseMinutes, At = scheduleAt, Text = abuseText, Rewards = abuseRewards })
	end)
	local list = scheduledList()
	if #list == 0 then
		Theme.Label("Nessun evento programmato.", { Size = UDim2.new(1, -10, 0, 20), LayoutOrder = nextOrder(), Font = Theme.Fonts.UI, TextSize = 13, TextColor3 = Colors.TextDim, Parent = content })
	else
		Theme.Label(("Eventi programmati (%d):"):format(#list), { Size = UDim2.new(1, -10, 0, 20), LayoutOrder = nextOrder(), Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = Colors.Gold, Parent = content })
		for _, e in list do
			local def = AbuseEvents.Get(e.Event)
			local line = New("Frame", { BackgroundColor3 = Colors.Background, BackgroundTransparency = 0.2, Size = UDim2.new(1, -10, 0, 48), LayoutOrder = nextOrder(), Parent = content })
			Theme.Corner(line, 8)
			local started = type(e.At) == "number" and e.At <= os.time()
			local rewards = AbuseEvents.RewardsText(e.Rewards)
			Theme.Label(("%s %s  •  %s (%s)  •  %d min%s\n%s"):format(
				def and def.Icon or "", def and def.Name or tostring(e.Event),
				whenText(e.At), if started then "IN CORSO" else untilText(e.At), e.Minutes or 0,
				if rewards ~= "" then "  •  " .. rewards else "",
				if type(e.Text) == "string" and e.Text ~= "" then ("📢 \"%s\" — %s"):format(e.Text, tostring(e.By)) else ("da %s"):format(tostring(e.By))
			), { Position = UDim2.fromOffset(10, 3), Size = UDim2.new(1, -150, 1, -6), Font = Theme.Fonts.UI, TextSize = 12, Parent = line })
			Theme.Button("❌ Annulla", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(120, 32), TextSize = 13, BackgroundColor3 = RED, Parent = line }, function()
				send("AbuseUnschedule", e.Uid)
			end)
		end
	end
	section("👑 Colosso d'Oro", "Cade dal cielo come una meteora d'oro. Con l'evento acceso, chi aiuta a sconfiggerlo riceve gemme e oro (e completa la sfida).")
	r = row(220, 44)
	button(r, "👑 Colosso d'Oro qui", PURPLE, function()
		send("Abuse", "boss")
	end)
	button(r, "👑 Colosso nelle Pianure (tra 30 s)", PURPLE, function()
		send("Abuse", "bossZone")
	end)
	button(r, "☄️ Solo la meteora qui", nil, function()
		send("Abuse", "meteor")
	end)
	section("🎆 Fuochi d'artificio e festa", "Chi vede i fuochi completa la sfida \"Lo spettacolo\" (con l'evento acceso).")
	r = row(220, 44)
	button(r, "🎆 Fuochi davanti a te", BLUE, function()
		send("Abuse", "fireworks")
	end)
	button(r, "🏙️ Fuochi su tutte le città", BLUE, function()
		send("Abuse", "fireworksCities")
	end)
	button(r, "🚀 Fuochi sopra ogni giocatore", BLUE, function()
		send("Abuse", "fireworksPlayers")
	end)
	button(r, "🎊 Coriandoli a tutti", nil, function()
		send("Abuse", "confetti")
	end)
	section("🎬 Cerimonia d'apertura", "La scena animata dell'inaugurazione con i fuochi sopra la città.")
	r = row(220, 44)
	button(r, "🎬 Cerimonia al bersaglio", nil, function()
		send("Abuse", "ceremony")
	end)
	button(r, "🎬 Cerimonia a TUTTI", nil, function()
		send("Abuse", "ceremonyAll")
	end)
	local on = ReplicatedStorage:GetAttribute("FestaAttiva") == true
	local auto = ReplicatedStorage:GetAttribute("FestaSpettacoliAuto") == true
	section(
		"🎉 Evento Grande Inaugurazione",
		("Evento: %s • spettacoli automatici: %s. L'evento (2x XP e oro, regalo, sfide, addobbi) segue le date in Shared/Data/Festival. Con gli spettacoli automatici il Colosso arriva da solo ogni 30 minuti, i fuochi ogni 10 e la cerimonia al primo ingresso."):format(
			if on then "ACCESO" else "SPENTO",
			if auto then "ACCESI" else "SPENTI"
		)
	)
	r = row(220, 44)
	button(r, "🎉 Accendi evento", GREEN, function()
		send("Festival", "on")
	end)
	button(r, "⛔ Spegni evento", RED, function()
		send("Festival", "off")
	end)
	button(r, "📅 Segui le date", nil, function()
		send("Festival", "auto")
	end)
	r = row(220, 44)
	button(r, "▶️ Spettacoli automatici ON", if auto then Colors.Green else nil, function()
		send("Festival", "showsOn")
	end)
	button(r, "⏸️ Spettacoli automatici OFF", if auto then nil else Colors.Green, function()
		send("Festival", "showsOff")
	end)
end

local RENDER = {
	Progressione = showProgression,
	Oggetti = showItems,
	Sieri = showSerums,
	Poteri = showPowers,
	Mondo = showWorld,
	Storia = showStory,
	Server = showServer,
	["Admin Abuse"] = showAbuse,
}

local function updateTarget()
	local t = target()
	targetUserId = t.UserId
	targetButton.Text = "🎯 Bersaglio: " .. (if t == player then "TU" else t.DisplayName) .. "  ▸"
end

function render()
	if not panel then
		return
	end
	for id, b in categoryButtons do
		b.BackgroundColor3 = if id == currentCategory then Colors.Green else Colors.PanelLight
	end
	for _, child in content:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	order = 0
	updateTarget()
	local ok, err = pcall(RENDER[currentCategory])
	if not ok then
		warn("[Admin] " .. tostring(err))
	end
end

local function toggle()
	if not isAdmin() then
		return
	end
	C.UIController.Toggle("Admin")
end

function AdminPanel.Init(c)
	C = c
end

function AdminPanel.Start()
	panel = Theme.Panel({ Name = "Admin", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1000, 640), Parent = C.UIController.Layers.Panels })
	Theme.Padding(panel, 14)
	local stroke = panel:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Colors.RedBright
	end
	Theme.Label("🛠️ Pannello Admin", { Size = UDim2.new(0, 300, 0, 34), Font = Theme.Fonts.Title, TextSize = 30, TextColor3 = Colors.RedBright, Parent = panel })
	Theme.Button("✕", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(36, 32), TextSize = 18, Parent = panel }, function()
		C.UIController.Close("Admin")
	end)
	-- bersaglio: clic per passare al giocatore successivo
	targetButton = Theme.Button("", { Position = UDim2.fromOffset(310, 0), Size = UDim2.fromOffset(280, 34), TextSize = 14, BackgroundColor3 = Color3.fromRGB(90, 40, 40), Parent = panel }, function()
		local list = Players:GetPlayers()
		local index = 1
		for i, p in list do
			if p.UserId == targetUserId then
				index = i
			end
		end
		targetUserId = list[(index % #list) + 1].UserId
		render()
	end)
	valueBox = New("TextBox", {
		Position = UDim2.fromOffset(600, 0),
		Size = UDim2.fromOffset(340, 34),
		BackgroundColor3 = Colors.Background,
		TextColor3 = Colors.Text,
		PlaceholderText = "VALORE (numero o messaggio)...",
		PlaceholderColor3 = Colors.TextDim,
		Font = Theme.Fonts.Bold,
		TextSize = 15,
		ClearTextOnFocus = false,
		Text = "",
		Parent = panel,
	})
	Theme.Corner(valueBox, 8)
	Theme.Stroke(valueBox, Colors.Border, 1, 0.3)
	local nav = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 46), Size = UDim2.new(0, 170, 1, -46), Parent = panel })
	New("UIListLayout", { Padding = UDim.new(0, 6), Parent = nav })
	for i, category in CATEGORIES do
		categoryButtons[category.Id] = Theme.Button(category.Icon .. " " .. category.Id, { Size = UDim2.new(1, 0, 0, 44), TextSize = 15, LayoutOrder = i, Parent = nav }, function()
			currentCategory = category.Id
			render()
		end)
	end
	content = New("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(184, 46),
		Size = UDim2.new(1, -184, 1, -46),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Colors.Gold,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	})
	New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = content })
	C.UIController.RegisterPanel("Admin", panel, render)
	C.InputController.On("Admin", function(began)
		if began then
			toggle()
		end
	end)

	-- pulsante laterale, visibile solo agli admin
	local adminButton = Theme.Button("🛠️", { Name = "PulsanteAdmin", AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 16, 0.5, 150), Size = UDim2.fromOffset(60, 60), TextSize = 28, BackgroundColor3 = Color3.fromRGB(110, 34, 34), Visible = isAdmin(), Parent = C.UIController.Layers.HUD }, toggle)
	C.UIController.AttachScale(adminButton)
	New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -1), Size = UDim2.new(1, 0, 0, 12), Font = Theme.Fonts.Bold, TextSize = 9, TextColor3 = Colors.GoldBright, Text = "ADMIN (P)", Parent = adminButton })
	player:GetAttributeChangedSignal("Admin"):Connect(function()
		adminButton.Visible = isAdmin()
		if isAdmin() then
			C.Notifications.Toast("🛠️ Sei amministratore: premi P per il Pannello Admin", "Successo", 5)
		end
	end)
	if isAdmin() then
		task.delay(6, function()
			C.Notifications.Toast("🛠️ Sei amministratore: premi P per il Pannello Admin", "Successo", 5)
		end)
	end
	C.ClientData.Changed:Connect(function()
		if C.UIController.IsOpen("Admin") and currentCategory == "Sieri" then
			render()
		end
	end)
	-- stato dell'evento aggiornato nella sezione Admin Abuse
	RunService.Heartbeat:Connect(function()
		local label = abuseStatus
		if label and label.Parent and C.UIController.IsOpen("Admin") and currentCategory == "Admin Abuse" then
			label.Text = abuseStatusText()
			if scheduleLabel and scheduleLabel.Parent then
				scheduleLabel.Text = scheduleText()
			end
		end
	end)
	for _, attribute in { "FestaAttiva", "FestaSpettacoliAuto", "AbuseEvento", "ProgrammaEventi" } do
		ReplicatedStorage:GetAttributeChangedSignal(attribute):Connect(function()
			if C.UIController.IsOpen("Admin") and currentCategory == "Admin Abuse" then
				render()
			end
		end)
	end
	Players.PlayerRemoving:Connect(function(p)
		if p.UserId == targetUserId then
			targetUserId = player.UserId
			if C.UIController.IsOpen("Admin") then
				render()
			end
		end
	end)
end

return AdminPanel
