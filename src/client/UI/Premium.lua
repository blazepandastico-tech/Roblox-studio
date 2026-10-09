--[[
	Premium (tasto N o pulsante 💎)
	Negozio dell'Arcipelago: Gemme e Monete con Robux, Game Pass, Negozio delle Gemme
	e Viaggio rapido (con il pass Viaggiatore). Mostra anche l'etichetta [VIP] in chat.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Lib.Net)
local Util = require(Shared.Lib.Util)
local Monetization = require(Shared.Data.Monetization)
local W = require(Shared.Data.WorldLayout)

local Theme = require(script.Parent.Theme)
local New = Theme.New
local Colors = Theme.Colors

local Premium = {}
local C

local GEM_COLOR = Color3.fromRGB(140, 220, 255)

local TABS = {
	{ Id = "Gemme", Icon = "💎" },
	{ Id = "Monete", Icon = "💰" },
	{ Id = "Pass", Icon = "🎟️" },
	{ Id = "Negozio", Icon = "🛒" },
	{ Id = "Viaggio", Icon = "🧭" },
}

local panel: Frame
local content: Frame
local balance: TextLabel
local currentTab = "Gemme"
local busyUntil = 0

local function profile()
	return C.ClientData.Profile
end

local function clear()
	for _, child in content:GetChildren() do
		child:Destroy()
	end
end

local function grid(cellHeight: number): ScrollingFrame
	local frame = New("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Colors.Gold,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	})
	New("UIGridLayout", { CellSize = UDim2.new(0.25, -9, 0, cellHeight), CellPadding = UDim2.fromOffset(9, 9), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
	New("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 8), Parent = frame })
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

-- Carta generica: icona, titolo, testo, etichetta e pulsante
local function card(parent: Instance, order: number, opts)
	local frame = Theme.Panel({ LayoutOrder = order, BackgroundColor3 = Colors.Background, Parent = parent })
	Theme.Padding(frame, 10)
	if opts.Tag then
		local ribbon = Theme.Label(opts.Tag, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 4, 0, -4),
			Size = UDim2.fromOffset(110, 20),
			BackgroundTransparency = 0,
			BackgroundColor3 = Colors.Red,
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Theme.Fonts.Bold,
			TextSize = 11,
			TextColor3 = Colors.White,
			Parent = frame,
		})
		Theme.Corner(ribbon, 6)
	end
	local icon = Theme.Label(opts.Icon, { Size = UDim2.new(1, 0, 0, 52), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 44, Parent = frame })
	local scale = New("UIScale", { Parent = icon })
	frame.MouseEnter:Connect(function()
		Theme.Tween(scale, 0.2, { Scale = 1.15 }, Enum.EasingStyle.Back)
	end)
	frame.MouseLeave:Connect(function()
		Theme.Tween(scale, 0.2, { Scale = 1 })
	end)
	Theme.Label(opts.Title, { Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Header, TextSize = 16, TextColor3 = opts.TitleColor or Colors.GoldBright, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = frame })
	Theme.Label(opts.Text or "", { Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 1, -128), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, Font = Theme.Fonts.UI, TextSize = 12, TextColor3 = Colors.TextDim, Parent = frame })
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

local function showProducts(kind: string)
	local list = grid(210)
	local order = 0
	-- offerta di benvenuto in cima alle gemme (solo nei primi giorni e una volta sola)
	if kind == "Gems" and C.RewardsPanel and C.RewardsPanel.StarterAvailable() and Monetization.IsAvailable(Monetization.Product("PacchettoIniziale") or {}) then
		for _, product in Monetization.Products do
			if product.Kind == "Starter" then
				card(list, 0, {
					Icon = product.Icon,
					Title = product.Name,
					Text = product.Contents,
					Tag = product.Tag,
					Button = ("R$ %d"):format(product.Robux),
					ButtonColor = Color3.fromRGB(190, 120, 30),
					OnClick = function()
						buy("Product", product.Id)
					end,
				})
			end
		end
	end
	for _, product in Monetization.Products do
		if product.Kind == kind then
			order += 1
			card(list, order, {
				Icon = product.Icon,
				Title = product.Name,
				Text = ("+%s %s"):format(Util.FormatNumber(product.Amount), if kind == "Gems" then "gemme" else "monete d'oro"),
				Tag = product.Tag,
				TitleColor = if kind == "Gems" then GEM_COLOR else Colors.GoldBright,
				Button = if Monetization.IsAvailable(product) then ("R$ %d"):format(product.Robux) else "In arrivo",
				Disabled = not Monetization.IsAvailable(product),
				ButtonColor = Color3.fromRGB(40, 150, 80),
				OnClick = function()
					buy("Product", product.Id)
				end,
			})
		end
	end
end

local function showPasses()
	local p = profile()
	local list = grid(230)
	for i, pass in Monetization.GamePasses do
		local owned = p and p.Passes and p.Passes[pass.Id] == true
		card(list, i, {
			Icon = pass.Icon,
			Title = pass.Name,
			Text = pass.Description,
			Tag = if owned then "POSSEDUTO" else nil,
			Button = if owned then "✔ Attivo" elseif Monetization.IsAvailable(pass) then ("R$ %d"):format(pass.Robux) else "In arrivo",
			Disabled = owned or not Monetization.IsAvailable(pass),
			ButtonColor = Color3.fromRGB(40, 150, 80),
			OnClick = function()
				buy("Pass", pass.Id)
			end,
		})
	end
end

local function showGemShop()
	local p = profile()
	local gems = p and p.Gems or 0
	local list = grid(220)
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
	local list = grid(190)
	if not owned then
		local pass = Monetization.Pass("Viaggiatore")
		if pass then
			card(list, 0, {
				Icon = "🔒",
				Title = "Serve il pass Viaggiatore",
				Text = pass.Description .. " Senza il pass puoi sempre usare i traghetti nei porti di ogni isola.",
				Button = if Monetization.IsAvailable(pass) then ("R$ %d"):format(pass.Robux) else "In arrivo",
				Disabled = not Monetization.IsAvailable(pass),
				ButtonColor = Color3.fromRGB(40, 150, 80),
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
	clear()
	if currentTab == "Gemme" then
		showProducts("Gems")
	elseif currentTab == "Monete" then
		showProducts("Gold")
	elseif currentTab == "Pass" then
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

function Premium.Init(c)
	C = c
end

function Premium.Start()
	panel = Theme.Panel({ Name = "Premium", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1000, 620), Parent = C.UIController.Layers.Panels })
	Theme.Padding(panel, 14)
	Theme.Label("💎 Negozio dell'Arcipelago", { Size = UDim2.new(1, -320, 0, 34), Font = Theme.Fonts.Title, TextSize = 30, TextColor3 = Colors.GoldBright, Parent = panel })
	balance = Theme.Label("", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -46, 0, 4), Size = UDim2.fromOffset(260, 28), TextXAlignment = Enum.TextXAlignment.Right, Font = Theme.Fonts.Number, TextSize = 20, TextColor3 = GEM_COLOR, Parent = panel })
	Theme.Button("✕", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(36, 32), TextSize = 18, Parent = panel }, function()
		C.UIController.Close("Premium")
	end)
	local tabs = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 38), Parent = panel })
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = tabs })
	for i, tab in TABS do
		Theme.Button(tab.Icon .. " " .. tab.Id, { Size = UDim2.fromOffset(150, 38), TextSize = 14, LayoutOrder = i, Parent = tabs }, function()
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
