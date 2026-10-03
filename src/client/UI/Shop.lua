--[[
	Shop
	Finestra di commercio per tre tipi di PNG:
	  • Armerie ed Emporio: lame, rampini, armi, uniformi e consumabili
	  • Laboratorio della Dott.ssa Morrow: sintesi di oggetti mitici e di sieri con i Frammenti
	  • Il Mercante Velato: sieri a prezzi altissimi, la merce cambia ogni 4 ore
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Lib.Net)
local Util = require(Shared.Lib.Util)
local Items = require(Shared.Data.Items)
local Serums = require(Shared.Data.Serums)

local Theme = require(script.Parent.Theme)
local New = Theme.New
local Colors = Theme.Colors

local Shop = {}
local C
local player = Players.LocalPlayer

local CLOSE_DISTANCE = 32

type Entry = {
	Key: string,
	Name: string,
	Icon: string,
	Rarity: string,
	Subtitle: string,
	Description: string,
	Stats: string,
	Price: number,
	LevelReq: number,
	Owned: boolean,
	Count: number,
	Materials: { [string]: number }?,
	Serum: boolean,
	Locked: boolean?,
	Buy: () -> (),
}

local ui = {} :: {
	Panel: Frame,
	Title: TextLabel,
	Subtitle: TextLabel,
	Timer: TextLabel,
	Gold: TextLabel,
	List: ScrollingFrame,
	Info: ScrollingFrame,
	Footer: Frame,
	Requirement: TextLabel,
	Price: TextLabel,
	Action: TextButton,
}

local data: any = nil
local entries: { Entry } = {}
local selected: string? = nil
local confirmKey: string? = nil
local confirmUntil = 0
local busyUntil = 0
local openedAt: Vector3? = nil
local timeOffset = 0

local KIND_INFO = {
	Shop = { Icon = "⚒️", Subtitle = "Equipaggiamento per chi combatte oltre le Mura." },
	Lab = { Icon = "🧪", Subtitle = "Unisci materiali rari e oro: dai Frammenti di Siero nasce un potere." },
	Dealer = { Icon = "🕯️", Subtitle = "Sieri autentici, nessuna domanda. La merce cambia ogni 4 ore." },
	Premium = { Icon = "💎", Subtitle = "Gemme, monete e pass per il tuo viaggio." },
}

local function profile()
	return C.ClientData.Profile
end

local function gold(): number
	local p = profile()
	return p and p.Gold or 0
end

local function level(): number
	local p = profile()
	return p and p.Level or 1
end

local function countOf(id: string): number
	local p = profile()
	return p and p.Inventory and p.Inventory[id] or 0
end

local function rarityLabel(rarity: string): string
	local r = Items.Rarities[rarity]
	return r and r.Label or rarity
end

-- DATI ---------------------------------------------------------------------------------------------

local function serumStats(serum): string
	local lines = {
		("Gigante: %s • Altezza %d m"):format(serum.TitanName, serum.Height),
		("Salute x%.1f • Danno %s • Energia %d"):format(serum.Health, Util.FormatNumber(serum.Damage), serum.Energy),
	}
	for _, key in { "Z", "X", "C", "V" } do
		local skill = serum.Skills[key]
		if skill then
			table.insert(lines, ("[%s] %s%s"):format(key, skill.Name, if skill.Mastery > 0 then (" (maestria %d)"):format(skill.Mastery) else ""))
		end
	end
	if serum.Passive then
		table.insert(lines, "Passiva — " .. serum.Passive)
	end
	return table.concat(lines, "\n")
end

local function itemEntry(id: string, price: number, levelReq: number, owned: boolean, buy: () -> ()): Entry?
	local def = Items.Get(id)
	if not def then
		return nil
	end
	local category = Items.Categories[def.Category]
	return {
		Key = id,
		Name = def.Name,
		Icon = category and category.Icon or "📦",
		Rarity = def.Rarity,
		Subtitle = category and category.Name or "",
		Description = def.Description or "",
		Stats = if C.Menu and C.Menu.ItemStatsText then C.Menu.ItemStatsText(def) else "",
		Price = price,
		LevelReq = levelReq,
		Owned = owned,
		Count = countOf(id),
		Serum = false,
		Buy = buy,
	}
end

local function serumEntry(id: string, price: number, levelReq: number, buy: () -> ()): Entry?
	local serum = Serums.Get(id)
	if not serum then
		return nil
	end
	return {
		Key = id,
		Name = serum.Name,
		Icon = "💉",
		Rarity = serum.Rarity,
		Subtitle = "Siero • " .. serum.TitanName,
		Description = serum.Description,
		Stats = serumStats(serum),
		Price = price,
		LevelReq = levelReq,
		Owned = false,
		Count = 0,
		Serum = true,
		Buy = buy,
	}
end

local function buildEntries()
	table.clear(entries)
	if not data then
		return
	end
	if data.Kind == "Shop" then
		for _, item in data.Items or {} do
			local entry = itemEntry(item.Id, item.Price, item.LevelReq, item.Owned == true, function()
				Net.Event("ShopBuy"):FireServer(data.ShopId, item.Id)
			end)
			if entry then
				table.insert(entries, entry)
			end
		end
	elseif data.Kind == "Lab" then
		for _, recipe in data.Recipes or {} do
			local buy = function()
				Net.Event("Craft"):FireServer(recipe.Id)
			end
			local entry = if recipe.Serum
				then serumEntry(recipe.Result, recipe.Gold, recipe.LevelReq, buy)
				else itemEntry(recipe.Result, recipe.Gold, recipe.LevelReq, Items.IsEquipment(recipe.Result) and countOf(recipe.Result) > 0, buy)
			if entry then
				entry.Key = recipe.Id
				entry.Materials = recipe.Materials
				entry.Locked = recipe.Locked == true
				table.insert(entries, entry)
			end
		end
	elseif data.Kind == "Dealer" then
		for _, item in data.Stock or {} do
			local entry = serumEntry(item.Id, item.Price, item.LevelReq, function()
				Net.Event("ShopBuy"):FireServer("Dealer", item.Id)
			end)
			if entry then
				entry.Locked = item.Locked == true
				table.insert(entries, entry)
			end
		end
	end
end

-- Perché non si può comprare (nil = si può)
local function blocker(entry: Entry): string?
	if entry.Locked then
		return "🔒 Prossimo aggiornamento"
	end
	if level() < entry.LevelReq then
		return ("🔒 Serve il livello %d"):format(entry.LevelReq)
	end
	if entry.Owned then
		return "✔ Già posseduto"
	end
	if entry.Materials then
		for id, count in entry.Materials do
			if countOf(id) < count then
				return "Materiali insufficienti"
			end
		end
	end
	if gold() < entry.Price then
		return "Oro insufficiente"
	end
	return nil
end

-- INTERFACCIA --------------------------------------------------------------------------------------

local render: () -> ()

local function clearChildren(frame: Instance)
	for _, child in frame:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function card(entry: Entry, index: number)
	local isSelected = entry.Key == selected
	local color = Items.RarityColor(entry.Rarity)
	local reason = blocker(entry)
	local button = New("TextButton", {
		Name = entry.Key,
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = if isSelected then Colors.PanelLight:Lerp(Colors.Gold, 0.18) else Colors.PanelLight,
		BackgroundTransparency = 0.1,
		Size = UDim2.new(1, -10, 0, 64),
		LayoutOrder = index,
		Parent = ui.List,
	})
	Theme.Corner(button, 8)
	Theme.Stroke(button, if isSelected then Colors.GoldBright else Colors.Border, if isSelected then 2 else 1, if isSelected then 0 else 0.55)
	local bar = New("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Position = UDim2.fromOffset(6, 8), Size = UDim2.new(0, 4, 1, -16), Parent = button })
	Theme.Corner(bar, 2)
	Theme.Label(entry.Icon, { Position = UDim2.fromOffset(16, 0), Size = UDim2.new(0, 36, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 24, Parent = button })
	Theme.Label(entry.Name, {
		Position = UDim2.fromOffset(56, 9),
		Size = UDim2.new(1, -186, 0, 22),
		Font = Theme.Fonts.Bold,
		TextSize = 15,
		TextColor3 = color,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Parent = button,
	})
	Theme.Label(entry.Subtitle, {
		Position = UDim2.fromOffset(56, 33),
		Size = UDim2.new(1, -186, 0, 18),
		Font = Theme.Fonts.UI,
		TextSize = 12,
		TextColor3 = Colors.TextDim,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Parent = button,
	})
	Theme.Label("💰 " .. Util.Abbreviate(entry.Price), {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 9),
		Size = UDim2.fromOffset(120, 22),
		Font = Theme.Fonts.Number,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = if gold() >= entry.Price then Colors.Gold else Colors.RedBright,
		Parent = button,
	})
	local status = if entry.Locked then "🔒 Presto" elseif entry.Owned then "✔ Posseduto" elseif level() < entry.LevelReq then ("🔒 Lv. %d"):format(entry.LevelReq) else ("Lv. %d"):format(entry.LevelReq)
	Theme.Label(status, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 34),
		Size = UDim2.fromOffset(120, 16),
		Font = Theme.Fonts.UI,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = if entry.Owned then Colors.GreenBright elseif reason and level() < entry.LevelReq then Colors.RedBright else Colors.TextDim,
		Parent = button,
	})
	local scale = New("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		Theme.Tween(scale, 0.1, { Scale = 1.02 })
	end)
	button.MouseLeave:Connect(function()
		Theme.Tween(scale, 0.12, { Scale = 1 })
	end)
	button.Activated:Connect(function()
		if selected ~= entry.Key then
			selected = entry.Key
			confirmKey = nil
			C.SoundController.Play("UI", nil, { Pitch = 1.6 })
			render()
		end
	end)
	-- comparsa a cascata
	scale.Scale = 0.94
	button.BackgroundTransparency = 1
	task.delay(index * 0.02, function()
		if button.Parent then
			Theme.Tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
			Theme.Tween(button, 0.18, { BackgroundTransparency = 0.1 })
		end
	end)
end

local function infoLabel(text: string, order: number, props: { [string]: any }?): TextLabel
	local label = Theme.Label(text, {
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Theme.Fonts.Body,
		TextSize = 15,
		LayoutOrder = order,
		Parent = ui.Info,
	})
	if props then
		for key, value in props do
			(label :: any)[key] = value
		end
	end
	return label
end

local function selectedEntry(): Entry?
	for _, entry in entries do
		if entry.Key == selected then
			return entry
		end
	end
	return nil
end

local function renderDetail()
	clearChildren(ui.Info)
	local entry = selectedEntry()
	if not entry then
		infoLabel(if #entries == 0 then "Non c'è niente in vendita." else "Seleziona qualcosa dall'elenco.", 1, { TextColor3 = Colors.TextDim })
		ui.Footer.Visible = false
		return
	end
	ui.Footer.Visible = true
	local color = Items.RarityColor(entry.Rarity)
	infoLabel(entry.Icon .. "  " .. entry.Name, 1, { Font = Theme.Fonts.Header, TextSize = 22, TextColor3 = color })
	infoLabel(("%s • %s"):format(rarityLabel(entry.Rarity), entry.Subtitle), 2, { Font = Theme.Fonts.UI, TextSize = 13, TextColor3 = Colors.TextDim })
	if entry.Description ~= "" then
		infoLabel(entry.Description, 3, { TextColor3 = Colors.Text, Font = Theme.Fonts.Body, TextSize = 15 })
	end
	if entry.Stats ~= "" then
		infoLabel(entry.Stats, 4, { Font = Theme.Fonts.UI, TextSize = 14, TextColor3 = Colors.GoldBright })
	end
	if entry.Count > 0 and not entry.Serum then
		infoLabel(("Ne possiedi: %d"):format(entry.Count), 5, { Font = Theme.Fonts.UI, TextSize = 13, TextColor3 = Colors.TextDim })
	end
	if entry.Materials then
		infoLabel("Materiali richiesti", 6, { Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = Colors.Gold })
		local order = 7
		for id, count in entry.Materials do
			local def = Items.Get(id)
			local have = countOf(id)
			infoLabel(("%s %s   %s / %s"):format(if have >= count then "✔" else "✖", def and def.Name or id, Util.FormatNumber(have), Util.FormatNumber(count)), order, {
				Font = Theme.Fonts.UI,
				TextSize = 14,
				TextColor3 = if have >= count then Colors.GreenBright else Colors.RedBright,
			})
			order += 1
		end
	end
	if entry.Locked then
		infoLabel("🔒 I poteri dei giganti arriveranno con il prossimo aggiornamento. Intanto raccogli Frammenti di Siero!", 49, {
			Font = Theme.Fonts.Bold,
			TextSize = 13,
			TextColor3 = Colors.RedBright,
		})
	elseif entry.Serum then
		infoLabel("Il siero andrà nella tua collezione (Menu → Sieri): potrai iniettarlo quando vorrai. Un solo potere alla volta!", 50, {
			Font = Theme.Fonts.UI,
			TextSize = 12,
			TextColor3 = Colors.TextDim,
		})
	end

	local reason = blocker(entry)
	ui.Requirement.Text = reason or ("Requisito: livello %d ✔"):format(entry.LevelReq)
	ui.Requirement.TextColor3 = if reason then Colors.RedBright else Colors.GreenBright
	ui.Price.Text = ("💰 %s oro"):format(Util.FormatNumber(entry.Price))
	ui.Price.TextColor3 = if gold() >= entry.Price then Colors.GoldBright else Colors.RedBright
	local verb = if data and data.Kind == "Lab" then "Crea" else "Compra"
	if reason then
		ui.Action.Text = verb
		ui.Action.BackgroundColor3 = Color3.fromRGB(45, 39, 33)
		ui.Action.TextColor3 = Colors.TextDim
	elseif confirmKey == entry.Key and os.clock() < confirmUntil then
		ui.Action.Text = "⚠️ Conferma: spendi " .. Util.Abbreviate(entry.Price) .. " oro"
		ui.Action.BackgroundColor3 = Colors.Red
		ui.Action.TextColor3 = Colors.White
	else
		ui.Action.Text = verb .. (if entry.Serum then " il siero" else "")
		ui.Action.BackgroundColor3 = Colors.Green
		ui.Action.TextColor3 = Colors.White
	end
end

render = function()
	if not data then
		return
	end
	buildEntries()
	local info = KIND_INFO[data.Kind] or KIND_INFO.Shop
	ui.Title.Text = info.Icon .. "  " .. tostring(data.Name or "Negozio")
	ui.Subtitle.Text = info.Subtitle
	ui.Timer.Visible = data.Kind == "Dealer"
	ui.Gold.Text = "💰 " .. Util.FormatNumber(gold())
	if selected and not selectedEntry() then
		selected = nil
	end
	if not selected and entries[1] then
		selected = entries[1].Key
	end
	clearChildren(ui.List)
	for i, entry in entries do
		card(entry, i)
	end
	renderDetail()
end

local function onAction()
	local entry = selectedEntry()
	if not entry or os.clock() < busyUntil then
		return
	end
	if blocker(entry) then
		C.SoundController.Play("UI", nil, { Pitch = 0.6 })
		return
	end
	-- i sieri costano una fortuna: chiediamo conferma
	if entry.Serum and (confirmKey ~= entry.Key or os.clock() > confirmUntil) then
		confirmKey = entry.Key
		confirmUntil = os.clock() + 3
		renderDetail()
		task.delay(3.05, function()
			if confirmKey == entry.Key and os.clock() > confirmUntil and C.UIController.IsOpen("Shop") then
				confirmKey = nil
				renderDetail()
			end
		end)
		return
	end
	confirmKey = nil
	busyUntil = os.clock() + 0.6
	C.SoundController.Play("Coins")
	entry.Buy()
end

local function build()
	local panel = Theme.Panel({
		Name = "Negozio",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(960, 600),
		Parent = C.UIController.Layers.Panels,
	})
	Theme.Padding(panel, 14)
	ui.Panel = panel
	ui.Title = Theme.Label("", {
		Size = UDim2.new(1, -260, 0, 34),
		Font = Theme.Fonts.Title,
		TextSize = 30,
		TextColor3 = Colors.GoldBright,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Parent = panel,
	})
	ui.Subtitle = Theme.Label("", {
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, -260, 0, 18),
		Font = Theme.Fonts.UI,
		TextSize = 13,
		TextColor3 = Colors.TextDim,
		Parent = panel,
	})
	ui.Timer = Theme.Label("", {
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, -260, 0, 18),
		Font = Theme.Fonts.Bold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(200, 160, 230),
		Visible = false,
		Parent = panel,
	})
	ui.Gold = Theme.Label("", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -46, 0, 2),
		Size = UDim2.fromOffset(200, 30),
		Font = Theme.Fonts.Number,
		TextSize = 22,
		TextColor3 = Colors.GoldBright,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = panel,
	})
	Theme.Button("✕", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(36, 32), TextSize = 18, Parent = panel }, function()
		C.UIController.Close("Shop")
	end)

	local list = New("ScrollingFrame", {
		Name = "Elenco",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(0.5, -8, 1, -84),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Colors.Gold,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	})
	New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	New("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), Parent = list })
	ui.List = list

	local detail = Theme.Panel({
		Name = "Dettagli",
		Position = UDim2.new(0.5, 4, 0, 84),
		Size = UDim2.new(0.5, -4, 1, -84),
		BackgroundColor3 = Colors.Background,
		Parent = panel,
	})
	Theme.Padding(detail, 12)
	local info = New("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -112),
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Colors.Gold,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = detail,
	})
	New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = info })
	ui.Info = info

	local footer = New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 104),
		Parent = detail,
	})
	New("Frame", { BackgroundColor3 = Colors.Gold, BackgroundTransparency = 0.6, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), Parent = footer })
	ui.Footer = footer
	ui.Requirement = Theme.Label("", {
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 18),
		Font = Theme.Fonts.Bold,
		TextSize = 14,
		Parent = footer,
	})
	ui.Price = Theme.Label("", {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 24),
		Font = Theme.Fonts.Number,
		TextSize = 22,
		Parent = footer,
	})
	-- pulsante con colore variabile (verde / rosso di conferma / grigio): solo effetto di scala
	local action = New("TextButton", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 44),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "Compra",
		Font = Theme.Fonts.Bold,
		TextSize = 18,
		TextColor3 = Colors.White,
		BackgroundColor3 = Colors.Green,
		Parent = footer,
	})
	Theme.Corner(action, 8)
	Theme.Stroke(action, Colors.GoldBright, 1.2, 0.3)
	Theme.Gradient(action, Color3.fromRGB(255, 255, 255), Color3.fromRGB(175, 175, 175), 90)
	local actionScale = New("UIScale", { Parent = action })
	action.MouseEnter:Connect(function()
		Theme.Tween(actionScale, 0.1, { Scale = 1.03 })
	end)
	action.MouseLeave:Connect(function()
		Theme.Tween(actionScale, 0.12, { Scale = 1 })
	end)
	action.MouseButton1Down:Connect(function()
		Theme.Tween(actionScale, 0.05, { Scale = 0.97 })
	end)
	action.Activated:Connect(function()
		Theme.Tween(actionScale, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
		onAction()
	end)
	ui.Action = action

	C.UIController.RegisterPanel("Shop", panel, nil, function()
		confirmKey = nil
		openedAt = nil
	end)
end

function Shop.Init(c)
	C = c
end

function Shop.Start()
	build()
	Net.Event("ShopOpen").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.Kind) ~= "string" then
			return
		end
		local sameShop = data and C.UIController.IsOpen("Shop") and data.Kind == payload.Kind and data.ShopId == payload.ShopId
		data = payload
		if payload.Kind == "Dealer" and type(payload.Now) == "number" then
			timeOffset = payload.Now - os.time()
		end
		if not sameShop then
			selected = nil
			confirmKey = nil
		end
		render()
		if not C.UIController.IsOpen("Shop") then
			local root = Util.GetRoot(player.Character)
			openedAt = root and root.Position
			C.UIController.Open("Shop")
		end
	end)
	C.ClientData.Changed:Connect(function()
		if C.UIController.IsOpen("Shop") then
			render()
		end
	end)
	-- conto alla rovescia del Mercante e chiusura se ti allontani
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.25 or not C.UIController.IsOpen("Shop") then
			return
		end
		accumulator = 0
		if data and data.Kind == "Dealer" and type(data.EndsAt) == "number" then
			local remaining = data.EndsAt - (os.time() + timeOffset)
			ui.Timer.Text = if remaining > 0
				then "⏳ Nuova merce tra " .. Util.FormatTime(remaining)
				else "⏳ È arrivata nuova merce: riparla con il Mercante!"
		end
		local root = Util.GetRoot(player.Character)
		if openedAt and root and (root.Position - openedAt).Magnitude > CLOSE_DISTANCE then
			C.UIController.Close("Shop")
		end
	end)
end

return Shop
