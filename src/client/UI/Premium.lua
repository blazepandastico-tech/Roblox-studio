--[[
	Premium (tasto N, pulsante 💎 o il mercante Aurelio della Bottega Reale)
	Negozio dell'Arcipelago con Robux:
	  🔥 Offerte     offerta lampo del server (pezzi limitati), offerte a tempo (cambiano ogni 6 ore),
	                 Pacchetto della Recluta e Pacchetto Leggendario, bonus del primo acquisto
	  💰 Monete      pacchetti che crescono con il livello
	  💎 Gemme       pacchetti di gemme (raddoppiate al primo acquisto)
	  ♾️ Permanenti  i Game Pass
	  🛒 Negozio     il negozio delle gemme
	  🧭 Viaggio     viaggio rapido (pass Viaggiatore)
	Mostra anche l'etichetta [VIP] in chat.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Lib.Net)
local Util = require(Shared.Lib.Util)
local Monetization = require(Shared.Data.Monetization)
local Items = require(Shared.Data.Items)
local W = require(Shared.Data.WorldLayout)

local Theme = require(script.Parent.Theme)
local New = Theme.New
local Colors = Theme.Colors

local Premium = {}
local C

local GEM_COLOR = Color3.fromRGB(140, 220, 255)
local FLASH_COLOR = Color3.fromRGB(255, 196, 60)
local BUY_GREEN = Color3.fromRGB(40, 150, 80)
local BUY_GOLD = Color3.fromRGB(190, 120, 30)

local TABS = {
	{ Id = "Offerte", Icon = "🔥" },
	{ Id = "Monete", Icon = "💰" },
	{ Id = "Gemme", Icon = "💎" },
	{ Id = "Permanenti", Icon = "♾️" },
	{ Id = "Negozio", Icon = "🛒" },
	{ Id = "Viaggio", Icon = "🧭" },
}

local panel: Frame
local content: Frame
local balance: TextLabel
local tabButtons: { [string]: TextButton } = {}
local currentTab = "Offerte"
local busyUntil = 0
-- etichette con il conto alla rovescia (si aggiornano ogni secondo)
local timers: { { Label: TextLabel, Text: () -> string } } = {}

local function profile()
	return C.ClientData.Profile
end

local function level(): number
	local p = profile()
	return p and p.Level or 1
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function itemName(id: string): string
	local def = Items.Get(id)
	return def and def.Name or id
end

local function clear()
	for _, child in content:GetChildren() do
		child:Destroy()
	end
	table.clear(timers)
end

local function grid(parent: Instance, columns: number, cellHeight: number, props: { [string]: any }?): Instance
	local frame
	if parent == content then
		frame = New("ScrollingFrame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Colors.Gold,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Parent = content,
		})
		New("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 10), Parent = frame })
	else
		frame = New("Frame", { BackgroundTransparency = 1, Parent = parent })
		if props then
			for key, value in props do
				(frame :: any)[key] = value
			end
		end
	end
	New("UIGridLayout", { CellSize = UDim2.new(1 / columns, -9, 0, cellHeight), CellPadding = UDim2.fromOffset(9, 9), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
	return frame
end

local function buy(kind: string, id: string)
	if os.clock() < busyUntil then
		return
	end
	busyUntil = os.clock() + 0.8
	C.SoundController.Play("Coins")
	Net.Event("PremiumBuy"):FireServer(kind, id)
end

local function ribbon(parent: Instance, text: string, color: Color3?)
	local tag = Theme.Label(text, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 4, 0, -4),
		Size = UDim2.fromOffset(math.max(52, utf8.len(text) * 8 + 18), 22),
		BackgroundTransparency = 0,
		BackgroundColor3 = color or Colors.Red,
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.Bold,
		TextSize = 12,
		TextColor3 = Colors.White,
		ZIndex = 3,
		Parent = parent,
	})
	Theme.Corner(tag, 6)
	return tag
end

-- Carta generica: icona, titolo, testo, etichetta e pulsante
local function card(parent: Instance, order: number, opts)
	local frame = Theme.Panel({ LayoutOrder = order, BackgroundColor3 = Colors.Background, Parent = parent })
	Theme.Padding(frame, 10)
	if opts.Highlight then
		Theme.Stroke(frame, opts.Highlight, 2, 0)
	end
	if opts.Tag then
		ribbon(frame, opts.Tag, opts.TagColor)
	end
	local icon = Theme.Label(opts.Icon, { Size = UDim2.new(1, 0, 0, 50), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 42, Parent = frame })
	local scale = New("UIScale", { Parent = icon })
	frame.MouseEnter:Connect(function()
		Theme.Tween(scale, 0.2, { Scale = 1.15 }, Enum.EasingStyle.Back)
	end)
	frame.MouseLeave:Connect(function()
		Theme.Tween(scale, 0.2, { Scale = 1 })
	end)
	Theme.Label(opts.Title, { Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Header, TextSize = 16, TextColor3 = opts.TitleColor or Colors.GoldBright, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = frame })
	local bottom = if opts.Note then 66 else 46
	Theme.Label(opts.Text or "", { Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 1, -(76 + bottom)), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, Font = Theme.Fonts.UI, TextSize = opts.TextSize or 12, TextColor3 = opts.TextColor or Colors.TextDim, Parent = frame })
	if opts.Note then
		Theme.Label(opts.Note, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -44), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Bold, TextSize = 12, TextColor3 = opts.NoteColor or Colors.GreenBright, Parent = frame })
	end
	local button = Theme.Button(opts.Button, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 38),
		TextSize = 16,
		BackgroundColor3 = if opts.Disabled then Color3.fromRGB(45, 39, 33) else opts.ButtonColor or Colors.Green,
		TextColor3 = if opts.Disabled then Colors.TextDim else Colors.White,
		Parent = frame,
	}, function()
		if not opts.Disabled and opts.OnClick then
			opts.OnClick()
		end
	end)
	return frame, button
end

-- Titolo di una sezione (con un conto alla rovescia facoltativo a destra)
local function section(parent: Instance, order: number, text: string, color: Color3?, timer: (() -> string)?)
	local row = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = order, Parent = parent })
	Theme.Label(text, { Size = UDim2.new(0.62, 0, 1, 0), Font = Theme.Fonts.Header, TextSize = 19, TextColor3 = color or Colors.GoldBright, TextWrapped = false, Parent = row })
	if timer then
		local label = Theme.Label(timer(), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.38, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Font = Theme.Fonts.Number, TextSize = 16, TextColor3 = Colors.RedBright, TextWrapped = false, Parent = row })
		table.insert(timers, { Label = label, Text = timer })
	end
	return row
end

-- Prezzo, valore reale e sconto di un'offerta
local function offerNumbers(entry)
	local value = Monetization.BundleValue(entry, level())
	local exclusive = entry.Exclusive ~= nil
	local discount = if value > 0 then math.floor((1 - entry.Robux / value) * 100 + 0.5) else 0
	return value, discount, exclusive
end

local function offerTag(entry): string
	local _, discount, exclusive = offerNumbers(entry)
	if exclusive then
		return "⭐ ESCLUSIVO"
	end
	return ("-%d%%"):format(discount)
end

local function offerCard(parent: Instance, order: number, entry, opts)
	local value, _, exclusive = offerNumbers(entry)
	local lines = Monetization.Describe(entry, level(), itemName, Util.FormatNumber)
	local available = Monetization.IsAvailable(entry)
	local owned = opts.Bought
	return card(parent, order, {
		Icon = entry.Icon,
		Title = entry.Name,
		Text = table.concat(lines, "\n"),
		TextSize = 13,
		TextColor3 = Colors.Text,
		Tag = opts.Tag or offerTag(entry),
		TagColor = if exclusive then Color3.fromRGB(150, 70, 200) else Colors.Red,
		Highlight = opts.Highlight,
		Note = opts.Note or (if exclusive then "Solo qui: non si trova da nessun'altra parte" else ("Valore R$ %s"):format(Util.FormatNumber(value))),
		NoteColor = if exclusive then Color3.fromRGB(210, 160, 255) else Colors.GreenBright,
		Button = if owned then "✔ Preso" elseif available then ("R$ %d"):format(entry.Robux) else "In arrivo",
		Disabled = owned or not available or opts.Disabled,
		ButtonColor = opts.ButtonColor or BUY_GOLD,
		OnClick = function()
			buy("Product", entry.Id)
		end,
	})
end

-- OFFERTE ---------------------------------------------------------------------------------------

local function flashState()
	local id = ReplicatedStorage:GetAttribute("Lampo")
	local ends = ReplicatedStorage:GetAttribute("LampoFine") or 0
	if type(id) ~= "string" or id == "" or now() >= ends then
		return nil
	end
	return {
		Offer = Monetization.Product(id),
		Ends = ends,
		Stock = ReplicatedStorage:GetAttribute("LampoScorte") or 0,
		Total = ReplicatedStorage:GetAttribute("LampoTotale") or Monetization.FlashStock,
		Uid = ReplicatedStorage:GetAttribute("LampoUid") or "",
	}
end

local function rotation(): (number, number, { string })
	return Monetization.OfferRotation(math.floor(now()))
end

local function flashCard(parent: Instance, order: number, state)
	local offer = state.Offer
	local p = profile()
	local bought = p and p.OfferBuys and p.OfferBuys.Lampo == state.Uid
	local soldOut = state.Stock <= 0
	local value, _, exclusive = offerNumbers(offer)
	local frame = Theme.Panel({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, 150), BackgroundColor3 = Color3.fromRGB(44, 30, 14), Parent = parent })
	Theme.Padding(frame, 12)
	Theme.Stroke(frame, FLASH_COLOR, 2.5, 0)
	Theme.Gradient(frame, Color3.fromRGB(70, 44, 14), Color3.fromRGB(30, 20, 10), 90)
	ribbon(frame, offerTag(offer), if exclusive then Color3.fromRGB(150, 70, 200) else Colors.Red)
	Theme.Label(offer.Icon, { Size = UDim2.fromOffset(110, 126), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 70, Parent = frame })
	Theme.Label("⚡ " .. offer.Name, { Position = UDim2.fromOffset(120, 0), Size = UDim2.new(0.6, -120, 0, 28), Font = Theme.Fonts.Header, TextSize = 22, TextColor3 = FLASH_COLOR, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = frame })
	local lines = Monetization.Describe(offer, level(), itemName, Util.FormatNumber)
	Theme.Label(table.concat(lines, "   •   "), { Position = UDim2.fromOffset(120, 32), Size = UDim2.new(0.6, -120, 0, 44), TextYAlignment = Enum.TextYAlignment.Top, Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = Colors.Text, Parent = frame })
	Theme.Label(if exclusive then "Esclusivo delle offerte lampo: non si compra in nessun altro modo." else ("Valore R$ %s: lo paghi R$ %d."):format(Util.FormatNumber(value), offer.Robux), { Position = UDim2.fromOffset(120, 80), Size = UDim2.new(0.6, -120, 0, 20), Font = Theme.Fonts.UI, TextSize = 13, TextColor3 = Colors.GreenBright, Parent = frame })
	-- pezzi rimasti in questo server
	local barBack = New("Frame", { Position = UDim2.fromOffset(120, 106), Size = UDim2.new(0.6, -120, 0, 16), BackgroundColor3 = Color3.fromRGB(26, 18, 10), BorderSizePixel = 0, Parent = frame })
	Theme.Corner(barBack, 6)
	local fill = New("Frame", { Size = UDim2.fromScale(math.clamp(state.Stock / math.max(1, state.Total), 0, 1), 1), BackgroundColor3 = if soldOut then Colors.Red else FLASH_COLOR, BorderSizePixel = 0, Parent = barBack })
	Theme.Corner(fill, 6)
	Theme.Label(if soldOut then "ESAURITA" else ("Ne restano %d su %d in questo server"):format(state.Stock, state.Total), { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Bold, TextSize = 11, TextColor3 = Colors.White, Parent = barBack })
	-- a destra: tempo e pulsante
	local right = New("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 22), Size = UDim2.new(0.4, -16, 1, -22), BackgroundTransparency = 1, Parent = frame })
	local timer = Theme.Label("", { Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Number, TextSize = 26, TextColor3 = Colors.RedBright, Parent = right })
	table.insert(timers, { Label = timer, Text = function()
		return "⏱ " .. Util.FormatTime(state.Ends - now())
	end })
	timer.Text = timers[#timers].Text()
	local available = Monetization.IsAvailable(offer)
	Theme.Button(if bought then "✔ Presa" elseif soldOut then "Esaurita" elseif available then ("Prendila: R$ %d"):format(offer.Robux) else "In arrivo", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 52),
		TextSize = 20,
		BackgroundColor3 = if bought or soldOut or not available then Color3.fromRGB(60, 50, 40) else BUY_GREEN,
		Parent = right,
	}, function()
		if not bought and not soldOut and available then
			buy("Product", offer.Id)
		end
	end)
end

local function showOffers()
	local p = profile()
	local scroll = New("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Colors.Gold,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	})
	New("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 12), Parent = scroll })
	New("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	-- bonus del primo acquisto
	if p and not p.FirstPurchase then
		local banner = Theme.Label(("🎁 PRIMO ACQUISTO: gemme RADDOPPIATE sui pacchetti di gemme, +%d 💎 in regalo su tutto il resto!"):format(Monetization.FirstPurchaseGems), {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromRGB(120, 70, 20),
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Theme.Fonts.Bold,
			TextSize = 15,
			TextColor3 = Colors.GoldBright,
			LayoutOrder = nextOrder(),
			Parent = scroll,
		})
		Theme.Corner(banner, 8)
		Theme.Stroke(banner, Colors.GoldBright, 1.5, 0.2)
	end
	-- offerta lampo del server
	local state = flashState()
	if state and state.Offer then
		section(scroll, nextOrder(), "⚡ OFFERTA LAMPO DEL SERVER", FLASH_COLOR)
		flashCard(scroll, nextOrder(), state)
	else
		local nextAt = ReplicatedStorage:GetAttribute("LampoProssima")
		section(scroll, nextOrder(), "⚡ Offerta lampo del server", Colors.TextDim, function()
			if type(nextAt) == "number" and nextAt > now() then
				return "la prossima tra " .. Util.FormatTime(nextAt - now())
			end
			return "in arrivo"
		end)
	end
	-- offerte a tempo
	local slot, ends, chosen = rotation()
	section(scroll, nextOrder(), "⏳ OFFERTE A TEMPO", Colors.GoldBright, function()
		return "cambiano tra " .. Util.FormatTime(ends - now())
	end)
	local timed = grid(scroll, #chosen, 226, { Size = UDim2.new(1, 0, 0, 226), LayoutOrder = nextOrder() })
	for i, id in chosen do
		local offer = Monetization.Product(id)
		if offer then
			offerCard(timed, i, offer, { Bought = p and p.OfferBuys and p.OfferBuys[id] == slot })
		end
	end
	-- pacchetti speciali
	local specials = {}
	local starter = Monetization.Product("PacchettoIniziale")
	if starter and C.RewardsPanel and C.RewardsPanel.StarterAvailable() then
		table.insert(specials, { Entry = starter, Tag = "SOLO RECLUTE", Note = "Scade 3 giorni dopo il primo accesso" })
	end
	local legend = Monetization.Product("PacchettoLeggendario")
	local hasPass = false
	for _, pass in Monetization.GamePasses do
		if p and p.Passes and p.Passes[pass.Id] then
			hasPass = true
		end
	end
	if legend and not hasPass then
		table.insert(specials, { Entry = legend, Highlight = Colors.GoldBright })
	end
	if #specials > 0 then
		section(scroll, nextOrder(), "🏆 PACCHETTI SPECIALI")
		local box = grid(scroll, 2, 220, { Size = UDim2.new(1, 0, 0, 220), LayoutOrder = nextOrder() })
		for i, special in specials do
			offerCard(box, i, special.Entry, { Tag = special.Tag, Note = special.Note, Highlight = special.Highlight, ButtonColor = BUY_GREEN })
		end
	end
	Theme.Label("Il valore è calcolato con i prezzi del negozio (gemme e monete ai prezzi dei pacchetti, oggetti ai prezzi del negozio delle gemme). Ogni offerta a tempo si prende una volta per turno; l'offerta lampo una volta per giocatore, finché ci sono pezzi in questo server.", {
		Size = UDim2.new(1, 0, 0, 34),
		Font = Theme.Fonts.UI,
		TextSize = 12,
		TextColor3 = Colors.TextDim,
		LayoutOrder = nextOrder(),
		Parent = scroll,
	})
end

-- MONETE E GEMME ------------------------------------------------------------------------------------

local function showProducts(kind: string)
	local p = profile()
	local list = grid(content, 3, 196)
	local order = 0
	local first = p ~= nil and not p.FirstPurchase
	for _, product in Monetization.Products do
		if product.Kind == kind then
			order += 1
			local extra = math.floor(Monetization.ExtraValue(product, level()) * 100 + 0.5)
			local amount = if kind == "Gold" then Monetization.GoldAmount(product, level()) else product.Amount
			local text
			if kind == "Gold" then
				text = ("+%s monete d'oro\n(al tuo livello: crescono quando sali)"):format(Util.FormatNumber(amount))
			else
				text = ("+%s gemme"):format(Util.FormatNumber(amount))
				if first then
					text ..= ("\n🎁 Primo acquisto: %s gemme!"):format(Util.FormatNumber(amount * 2))
				end
			end
			card(list, order, {
				Icon = product.Icon,
				Title = product.Name,
				Text = text,
				TextSize = 14,
				TextColor3 = Colors.Text,
				Tag = product.Tag or (if extra > 0 then ("+%d%%"):format(extra) else nil),
				TagColor = if product.Tag == "MIGLIOR VALORE" then Color3.fromRGB(150, 70, 200) else Colors.Red,
				Note = if extra > 0 then ("+%d%% rispetto al pacchetto più piccolo"):format(extra) else nil,
				TitleColor = if kind == "Gems" then GEM_COLOR else Colors.GoldBright,
				Button = if Monetization.IsAvailable(product) then ("R$ %d"):format(product.Robux) else "In arrivo",
				Disabled = not Monetization.IsAvailable(product),
				ButtonColor = BUY_GREEN,
				OnClick = function()
					buy("Product", product.Id)
				end,
			})
		end
	end
end

local function showPasses()
	local p = profile()
	local list = grid(content, 4, 204)
	local total = 0
	for i, pass in Monetization.GamePasses do
		total += pass.Robux
		local owned = p and p.Passes and p.Passes[pass.Id] == true
		card(list, i + 1, {
			Icon = pass.Icon,
			Title = pass.Name,
			Text = pass.Description,
			Tag = if owned then "POSSEDUTO" else nil,
			TagColor = Colors.Green,
			Note = if owned then nil else "♾️ Per sempre, su tutti i server",
			NoteColor = Color3.fromRGB(140, 190, 255),
			Button = if owned then "✔ Attivo" elseif Monetization.IsAvailable(pass) then ("R$ %d"):format(pass.Robux) else "In arrivo",
			Disabled = owned or not Monetization.IsAvailable(pass),
			ButtonColor = BUY_GREEN,
			OnClick = function()
				buy("Pass", pass.Id)
			end,
		})
	end
	-- in cima: tutti i pass insieme (solo per chi non ne ha ancora nessuno)
	local legend = Monetization.Product("PacchettoLeggendario")
	local hasPass = false
	for _, pass in Monetization.GamePasses do
		if p and p.Passes and p.Passes[pass.Id] then
			hasPass = true
		end
	end
	if legend and not hasPass then
		card(list, 1, {
			Icon = legend.Icon,
			Title = legend.Name,
			Text = ("Tutti i %d pass (R$ %s se presi uno alla volta) + 1.000 💎 + Mantello della Leggenda"):format(#Monetization.GamePasses, Util.FormatNumber(total)),
			TextColor3 = Colors.Text,
			Tag = ("-%d%%"):format(math.floor((1 - legend.Robux / Monetization.BundleValue(legend, level())) * 100 + 0.5)),
			Highlight = Colors.GoldBright,
			Button = if Monetization.IsAvailable(legend) then ("R$ %d"):format(legend.Robux) else "In arrivo",
			Disabled = not Monetization.IsAvailable(legend),
			ButtonColor = BUY_GOLD,
			OnClick = function()
				buy("Product", legend.Id)
			end,
		})
	end
end

local function showGemShop()
	local p = profile()
	local gems = p and p.Gems or 0
	local list = grid(content, 4, 220)
	for i, entry in Monetization.GemShop do
		local owned = entry.Unique and p and entry.Item and (p.Inventory[entry.Item] or 0) > 0
		card(list, i, {
			Icon = entry.Icon,
			Title = entry.Name,
			Text = entry.Description,
			Button = if owned then "✔ Posseduto" else ("💎 %d"):format(entry.Gems),
			Disabled = owned or gems < entry.Gems,
			ButtonColor = Color3.fromRGB(50, 110, 170),
			OnClick = function()
				buy("Gem", entry.Id)
			end,
		})
	end
end

local function showTravel()
	local p = profile()
	local owned = p and p.Passes and p.Passes.Viaggiatore == true
	local list = grid(content, 4, 190)
	if not owned then
		local pass = Monetization.Pass("Viaggiatore")
		if pass then
			card(list, 0, {
				Icon = "🔒",
				Title = "Serve il pass Viaggiatore",
				Text = pass.Description .. " Senza il pass puoi sempre usare i traghetti nei porti di ogni isola.",
				Button = if Monetization.IsAvailable(pass) then ("R$ %d"):format(pass.Robux) else "In arrivo",
				Disabled = not Monetization.IsAvailable(pass),
				ButtonColor = BUY_GREEN,
				OnClick = function()
					buy("Pass", pass.Id)
				end,
			})
		end
	end
	for i, id in W.IslandOrder do
		local island = W.Islands[id]
		if not island.Raid then
			local locked = not p or p.Level < island.LevelReq
			card(list, i, {
				Icon = if locked then "🔒" else "🏝️",
				Title = island.Name,
				Text = ("Livello richiesto: %d"):format(island.LevelReq),
				Button = if locked then ("Lv. %d"):format(island.LevelReq) else "Viaggia",
				Disabled = locked or not owned,
				ButtonColor = Color3.fromRGB(50, 110, 170),
				OnClick = function()
					Net.Event("FastTravel"):FireServer(id)
					C.UIController.Close("Premium")
				end,
			})
		end
	end
end

local function render()
	if not panel then
		return
	end
	local p = profile()
	balance.Text = ("💎 %s     💰 %s"):format(Util.FormatNumber(p and p.Gems or 0), Util.Abbreviate(p and p.Gold or 0))
	for id, button in tabButtons do
		button.BackgroundColor3 = if id == currentTab then Color3.fromRGB(120, 86, 40) else Colors.PanelLight
	end
	clear()
	if currentTab == "Offerte" then
		showOffers()
	elseif currentTab == "Gemme" then
		showProducts("Gems")
	elseif currentTab == "Monete" then
		showProducts("Gold")
	elseif currentTab == "Permanenti" then
		showPasses()
	elseif currentTab == "Negozio" then
		showGemShop()
	elseif currentTab == "Viaggio" then
		showTravel()
	end
end

function Premium.Open(tab: string?)
	if tab then
		currentTab = tab
	end
	if not C.UIController.IsOpen("Premium") then
		C.UIController.Open("Premium")
	else
		render()
	end
end

-- C'è un'offerta lampo nel server? (per il pulsante 💎 del HUD)
function Premium.FlashEndsIn(): number?
	local state = flashState()
	if state and state.Stock > 0 then
		return state.Ends - now()
	end
	return nil
end

function Premium.Init(c)
	C = c
end

function Premium.Start()
	panel = Theme.Panel({ Name = "Premium", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1000, 640), Parent = C.UIController.Layers.Panels })
	Theme.Padding(panel, 14)
	Theme.Label("💎 Bottega Reale", { Size = UDim2.new(1, -320, 0, 34), Font = Theme.Fonts.Title, TextSize = 30, TextColor3 = Colors.GoldBright, Parent = panel })
	balance = Theme.Label("", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -46, 0, 4), Size = UDim2.fromOffset(260, 28), TextXAlignment = Enum.TextXAlignment.Right, Font = Theme.Fonts.Number, TextSize = 20, TextColor3 = GEM_COLOR, Parent = panel })
	Theme.Button("✕", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(36, 32), TextSize = 18, Parent = panel }, function()
		C.UIController.Close("Premium")
	end)
	local tabs = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 38), Parent = panel })
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabs })
	for i, tab in TABS do
		tabButtons[tab.Id] = Theme.Button(tab.Icon .. " " .. tab.Id, { Size = UDim2.new(1 / #TABS, -6, 1, 0), TextSize = 15, LayoutOrder = i, Parent = tabs }, function()
			currentTab = tab.Id
			render()
		end)
	end
	content = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 92), Size = UDim2.new(1, 0, 1, -92), Parent = panel })
	C.UIController.RegisterPanel("Premium", panel, render)
	C.InputController.On("Premium", function(began)
		if began then
			C.UIController.Toggle("Premium")
		end
	end)
	C.ClientData.Changed:Connect(function()
		if C.UIController.IsOpen("Premium") then
			render()
		end
	end)
	-- le offerte cambiano: si ridisegna (offerta lampo, pezzi rimasti, nuovo turno)
	for _, attribute in { "Lampo", "LampoScorte", "OfferteAttive" } do
		ReplicatedStorage:GetAttributeChangedSignal(attribute):Connect(function()
			if C.UIController.IsOpen("Premium") and currentTab == "Offerte" then
				render()
			end
		end)
	end
	-- il mercante della Bottega Reale apre direttamente le offerte
	Net.Event("OpenPremium").OnClientEvent:Connect(function(tab)
		Premium.Open(if type(tab) == "string" then tab else "Offerte")
	end)
	-- conti alla rovescia (e nuovo turno delle offerte a tempo quando scade)
	local acc = 0
	local lastSlot = rotation()
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 then
			return
		end
		acc = 0
		if not C.UIController.IsOpen("Premium") then
			return
		end
		local slot = rotation()
		if slot ~= lastSlot then
			lastSlot = slot
			render()
			return
		end
		for _, t in timers do
			t.Label.Text = t.Text()
		end
	end)
	-- etichetta [VIP] dorata in chat
	pcall(function()
		TextChatService.OnIncomingMessage = function(message: TextChatMessage)
			local props = Instance.new("TextChatMessageProperties")
			local source = message.TextSource
			local sender = source and Players:GetPlayerByUserId(source.UserId)
			if sender and sender:GetAttribute("VIP") then
				props.PrefixText = "<font color='#FFD24A'>[VIP]</font> " .. message.PrefixText
			end
			return props
		end
	end)
end

return Premium
