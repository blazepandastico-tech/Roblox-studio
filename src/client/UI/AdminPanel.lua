--[[
	AdminPanel - Pannello Admin (tasto P o pulsante 🛠️, visibile solo agli amministratori)
	Categorie: Progressione • Oggetti • Sieri • Poteri • Mondo • Storia • Server
	In alto si sceglie il BERSAGLIO (tu o un altro giocatore) e si può scrivere un VALORE
	(numero o testo) usato dai pulsanti che lo richiedono.
	Tutte le azioni vengono controllate dal server (AdminService).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Lib.Net)
local Items = require(Shared.Data.Items)
local Serums = require(Shared.Data.Serums)
local Titans = require(Shared.Data.Titans)
local Zones = require(Shared.Data.Zones)
local Story = require(Shared.Data.Story)

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
		table.insert(bosses, { Id = id, Def = def })
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
	section("Amministratori", ("Per aggiungere altri admin nel gioco pubblicato, metti il loro UserId in Config.lua → Admins. Ora ci sono %d admin extra."):format(#Config.Admins))
end

local RENDER = {
	Progressione = showProgression,
	Oggetti = showItems,
	Sieri = showSerums,
	Poteri = showPowers,
	Mondo = showWorld,
	Storia = showStory,
	Server = showServer,
}

local function updateTarget()
	local t = target()
	targetUserId = t.UserId
	targetButton.Text = "🎯 Bersaglio: " .. (if t == player then "TU" else t.DisplayName) .. "  ▸"
end

local function render()
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
