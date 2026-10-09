--[[
	RewardsPanel - pannello dei premi (pulsante 🎁 a sinistra)
	  📅 Calendario di 7 giorni   ⏳ Regali a tempo   🎡 Ruota della Fortuna
	Contiene anche i pulsanti laterali (Premi, Classifiche, Invita amici, Gruppo),
	l'offerta di benvenuto (Pacchetto della Recluta) e la richiesta di aggiungere il gioco ai Preferiti.
]]

local AvatarEditorService = game:GetService("AvatarEditorService")
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Lib.Net)
local Util = require(Shared.Lib.Util)
local Rewards = require(Shared.Data.Rewards)
local Leveling = require(Shared.Data.Leveling)
local Monetization = require(Shared.Data.Monetization)

local Theme = require(script.Parent.Theme)
local New = Theme.New
local Colors = Theme.Colors

local RewardsPanel = {}
local C

local player = Players.LocalPlayer
local DAY = 86400

local panel: Frame
local content: Frame
local tabButtons: { [string]: TextButton } = {}
local currentTab = "Calendario"
local dot: Frame
local wheel: Frame
local wheelRotation = 0
local spinning = false
local spinButton: TextButton? = nil
local resultLabel: TextLabel? = nil
local playtimeLabels: { [number]: { Button: TextButton, Index: number } } = {}
local wheelInfo: TextLabel? = nil
local playBase = 0
local playBaseClock = os.clock()

local TABS = {
	{ Id = "Calendario", Icon = "📅" },
	{ Id = "Regali", Icon = "⏳" },
	{ Id = "Ruota", Icon = "🎡" },
}

local function profile()
	return C.ClientData.Profile
end

local function today(): number
	return os.time() // DAY
end

local function dailyIndex(p): number?
	local streak = p.Streak
	if not streak then
		return 1
	end
	if streak.Last == today() then
		return nil
	end
	if streak.Last == today() - 1 then
		return (streak.Day % #Rewards.Daily) + 1
	end
	return 1
end

local function playSeconds(): number
	return playBase + (os.clock() - playBaseClock)
end

local function playtimeClaimed(p, index: number): boolean
	local play = p.PlayToday
	return play ~= nil and play.Day == today() and play.Claimed ~= nil and play.Claimed[tostring(index)] == true
end

local function freeSpinIn(p): number
	return math.max(0, (p.FreeSpinAt or 0) - os.time())
end

-- Quanti premi sono pronti da ritirare (per il pallino rosso sul pulsante)
local function readyCount(): number
	local p = profile()
	if not p then
		return 0
	end
	local count = 0
	if dailyIndex(p) then
		count += 1
	end
	local seconds = playSeconds()
	for i, gift in Rewards.Playtime do
		if not playtimeClaimed(p, i) and seconds >= gift.Minutes * 60 then
			count += 1
		end
	end
	if freeSpinIn(p) <= 0 or (p.Spins or 0) > 0 then
		count += 1
	end
	return count
end

local function rewardText(bundle): string
	local parts = {}
	local p = profile()
	if bundle.GoldQuests and p then
		table.insert(parts, "💰 " .. Util.Abbreviate(Leveling.QuestGold(p.Level) * bundle.GoldQuests))
	end
	if bundle.Gems then
		table.insert(parts, ("💎 %d"):format(bundle.Gems))
	end
	if bundle.Spins then
		table.insert(parts, ("🎡 %d"):format(bundle.Spins))
	end
	return table.concat(parts, "  ")
end

-- Cambia il bordo già presente in un pannello (un elemento può avere un solo UIStroke)
local function highlight(frame: GuiObject, color: Color3, thickness: number)
	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
		stroke.Thickness = thickness
		stroke.Transparency = 0
	end
end

local function clear()
	for _, child in content:GetChildren() do
		child:Destroy()
	end
	playtimeLabels = {}
	spinButton = nil
	resultLabel = nil
	wheelInfo = nil
end

-- CALENDARIO ---------------------------------------------------------------------------------

local function showCalendar()
	local p = profile()
	if not p then
		return
	end
	local claimable = dailyIndex(p)
	local claimedUpTo = if claimable then claimable - 1 else (p.Streak and p.Streak.Day or 0)
	Theme.Label("Torna ogni giorno: i premi crescono fino al Forziere del 7° giorno. Se salti un giorno si riparte dal Giorno 1.", {
		Size = UDim2.new(1, 0, 0, 40),
		Font = Theme.Fonts.UI,
		TextSize = 14,
		TextColor3 = Colors.TextDim,
		Parent = content,
	})
	local row = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 300), Parent = content })
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = row })
	for i, reward in Rewards.Daily do
		local isToday = claimable == i
		local claimed = i <= claimedUpTo
		local card = Theme.Panel({
			Size = UDim2.new(1 / 7, -8, 1, if reward.Big then 0 else -30),
			LayoutOrder = i,
			BackgroundColor3 = if isToday then Color3.fromRGB(70, 56, 26) elseif claimed then Color3.fromRGB(30, 46, 32) else Colors.Background,
			Parent = row,
		})
		Theme.Padding(card, 8)
		if isToday then
			highlight(card, Colors.GoldBright, 2.5)
		end
		Theme.Label(("Giorno %d"):format(i), { Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Bold, TextSize = 15, TextColor3 = if isToday then Colors.GoldBright else Colors.Text, Parent = card })
		Theme.Label(if claimed then "✔" else reward.Icon, { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 64), TextXAlignment = Enum.TextXAlignment.Center, TextSize = if reward.Big then 56 else 46, TextColor3 = Colors.GreenBright, Parent = card })
		Theme.Label(reward.Name, { Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Bold, TextSize = 13, Parent = card })
		Theme.Label(rewardText(reward), { Position = UDim2.fromOffset(0, 138), Size = UDim2.new(1, 0, 0, 36), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.UI, TextSize = 12, TextColor3 = Colors.TextDim, Parent = card })
		if isToday then
			Theme.Button("RITIRA", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = Colors.Green, TextSize = 15, Parent = card }, function()
				C.SoundController.Play("Reward")
				Net.Event("ClaimReward"):FireServer("Daily")
			end)
		end
	end
	local streak = p.Streak and p.Streak.Count or 0
	Theme.Label(if claimable then "🎁 Il premio di oggi ti aspetta!" else ("✔ Premio di oggi ritirato • serie attuale: %d %s • torna domani!"):format(streak, if streak == 1 then "giorno" else "giorni"), {
		Position = UDim2.fromOffset(0, 362),
		Size = UDim2.new(1, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.Header,
		TextSize = 18,
		TextColor3 = Colors.GoldBright,
		Parent = content,
	})
end

-- REGALI A TEMPO -----------------------------------------------------------------------------

local function refreshPlaytime()
	local p = profile()
	if not p then
		return
	end
	local seconds = playSeconds()
	for _, entry in playtimeLabels do
		local gift = Rewards.Playtime[entry.Index]
		local button = entry.Button
		if playtimeClaimed(p, entry.Index) then
			button.Text = "✔ Aperto"
			button.BackgroundColor3 = Color3.fromRGB(45, 39, 33)
		elseif seconds >= gift.Minutes * 60 then
			button.Text = "APRI!"
			button.BackgroundColor3 = Colors.Green
		else
			button.Text = "⏳ " .. Util.FormatTime(gift.Minutes * 60 - seconds)
			button.BackgroundColor3 = Color3.fromRGB(45, 39, 33)
		end
	end
end

local function showPlaytime()
	Theme.Label("Più giochi oggi, più regali apri. Si azzerano ogni giorno a mezzanotte (UTC).", {
		Size = UDim2.new(1, 0, 0, 30),
		Font = Theme.Fonts.UI,
		TextSize = 14,
		TextColor3 = Colors.TextDim,
		Parent = content,
	})
	local grid = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -40), Parent = content })
	New("UIGridLayout", { CellSize = UDim2.new(0.25, -9, 0.5, -9), CellPadding = UDim2.fromOffset(9, 9), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	for i, gift in Rewards.Playtime do
		local card = Theme.Panel({ LayoutOrder = i, BackgroundColor3 = Colors.Background, Parent = grid })
		Theme.Padding(card, 8)
		if gift.Big then
			highlight(card, Colors.GoldBright, 2)
		end
		Theme.Label(("%d min"):format(gift.Minutes), { Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = Colors.Gold, Parent = card })
		Theme.Label(gift.Icon, { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 50), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 40, Parent = card })
		Theme.Label(gift.Name, { Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 0, 34), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Bold, TextSize = 13, Parent = card })
		local button = Theme.Button("", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 34), TextSize = 14, Parent = card }, function()
			C.SoundController.Play("Reward")
			Net.Event("ClaimReward"):FireServer("Playtime", i)
		end)
		table.insert(playtimeLabels, { Button = button, Index = i })
	end
	refreshPlaytime()
end

-- RUOTA DELLA FORTUNA ---------------------------------------------------------------------------

local function segmentAngle(index: number): number
	return (index - 1) * 360 / #Rewards.Wheel
end

local function buildWheel(parent: Instance)
	local size = 360
	local holder = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(size, size + 20), Parent = parent })
	wheel = New("Frame", {
		Name = "Ruota",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 20 + size / 2),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Color3.fromRGB(40, 30, 22),
		Rotation = wheelRotation % 360,
		Parent = holder,
	})
	wheelRotation %= 360
	Theme.Corner(wheel, size)
	Theme.Stroke(wheel, Colors.Gold, 5, 0)
	local n = #Rewards.Wheel
	local radius = size / 2
	for i, prize in Rewards.Wheel do
		local a = math.rad(segmentAngle(i))
		-- raggio di separazione tra due spicchi
		local spoke = math.rad(segmentAngle(i) + 180 / n)
		New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(radius + math.sin(spoke) * radius / 2, radius - math.cos(spoke) * radius / 2),
			Size = UDim2.fromOffset(2, radius),
			Rotation = math.deg(spoke),
			BackgroundColor3 = Colors.Gold,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Parent = wheel,
		})
		-- spicchio colorato (disco) con l'icona del premio
		local r = radius * 0.68
		local disc = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(radius + math.sin(a) * r, radius - math.cos(a) * r),
			Size = UDim2.fromOffset(if prize.Big then 74 else 62, if prize.Big then 74 else 62),
			BackgroundColor3 = prize.Color,
			Rotation = math.deg(a),
			Parent = wheel,
		})
		Theme.Corner(disc, 40)
		Theme.Stroke(disc, if prize.Big then Colors.GoldBright else Color3.fromRGB(20, 16, 12), if prize.Big then 3 else 1.5, 0)
		Theme.Label(prize.Icon, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = if prize.Big then 40 else 32, Parent = disc })
	end
	local hub = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(70, 70), BackgroundColor3 = Colors.Panel, Parent = wheel })
	Theme.Corner(hub, 40)
	Theme.Stroke(hub, Colors.GoldBright, 3, 0)
	Theme.Label("🎡", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 34, Parent = hub })
	-- freccia in alto
	Theme.Label("▼", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -6), Size = UDim2.fromOffset(50, 44), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 44, TextColor3 = Colors.RedBright, ZIndex = 5, Parent = holder })
end

local function refreshWheelInfo()
	local p = profile()
	if not p or not wheelInfo then
		return
	end
	local wait = freeSpinIn(p)
	wheelInfo.Text = ("%s\n🎡 Giri disponibili: %d"):format(if wait <= 0 then "🎁 Giro GRATIS disponibile!" else "Prossimo giro gratis tra " .. Util.FormatTime(wait), p.Spins or 0)
	if spinButton then
		local can = wait <= 0 or (p.Spins or 0) > 0
		spinButton.BackgroundColor3 = if can and not spinning then Colors.Green else Color3.fromRGB(45, 39, 33)
		spinButton.Text = if spinning then "..." elseif wait <= 0 then "GIRA GRATIS!" else "GIRA"
	end
end

local function showWheel()
	buildWheel(content)
	local side = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(400, 0), Size = UDim2.new(1, -400, 1, 0), Parent = content })
	wheelInfo = Theme.Label("", { Size = UDim2.new(1, 0, 0, 50), Font = Theme.Fonts.Bold, TextSize = 16, TextColor3 = Colors.GoldBright, Parent = side })
	spinButton = Theme.Button("GIRA", { Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 50), TextSize = 22, BackgroundColor3 = Colors.Green, Parent = side }, function()
		local p = profile()
		if spinning or not p then
			return
		end
		if freeSpinIn(p) > 0 and (p.Spins or 0) <= 0 then
			C.Notifications.Toast("Non hai giri: aspetta il giro gratis o apri i regali a tempo.", "Info", 3)
			return
		end
		spinning = true
		refreshWheelInfo()
		Net.Event("SpinWheel"):FireServer()
		-- se il server non risponde, sblocca il pulsante
		task.delay(6, function()
			if spinning and not wheel:GetAttribute("Girando") then
				spinning = false
				refreshWheelInfo()
			end
		end)
	end)
	resultLabel = Theme.Label("", { Position = UDim2.fromOffset(0, 112), Size = UDim2.new(1, 0, 0, 44), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Header, TextSize = 17, TextColor3 = Colors.GreenBright, Parent = side })
	-- acquisto di giri (solo dove i premi casuali a pagamento sono permessi)
	local y = 160
	if player:GetAttribute("NoPaidRandom") ~= true then
		local buys = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 40), Parent = side })
		New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = buys })
		for _, product in Monetization.Products do
			if product.Kind == "Spins" and Monetization.IsAvailable(product) then
				Theme.Button(("%s %d giri • R$ %d"):format(product.Icon, product.Amount, product.Robux), { Size = UDim2.new(0.5, -4, 1, 0), TextSize = 14, BackgroundColor3 = Color3.fromRGB(40, 110, 170), Parent = buys }, function()
					C.SoundController.Play("Coins")
					Net.Event("PremiumBuy"):FireServer("Product", product.Id)
				end)
			end
		end
		y += 48
	end
	-- probabilità (sempre visibili)
	Theme.Label("Probabilità dei premi", { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 22), Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = Colors.Gold, Parent = side })
	local odds = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y + 24), Size = UDim2.new(1, 0, 1, -(y + 24)), Parent = side })
	New("UIListLayout", { Padding = UDim.new(0, 1), Parent = odds })
	local total = Rewards.WheelTotal()
	for i, prize in Rewards.Wheel do
		Theme.Label(("%s  %s — %.0f%%"):format(prize.Icon, prize.Name, prize.Weight / total * 100), { Size = UDim2.new(1, 0, 0, 19), LayoutOrder = i, Font = Theme.Fonts.UI, TextSize = 13, TextColor3 = if prize.Big then Colors.GoldBright else Colors.Text, Parent = odds })
	end
	refreshWheelInfo()
end

local function onWheelResult(prizeId: string, text: string)
	local index = 1
	for i, prize in Rewards.Wheel do
		if prize.Id == prizeId then
			index = i
		end
	end
	local prize = Rewards.Wheel[index]
	if not C.UIController.IsOpen("Rewards") or currentTab ~= "Ruota" or not wheel or not wheel.Parent then
		spinning = false
		C.Notifications.Announce("🎡 " .. prize.Name, text, if prize.Big then "Raro" else "Ricompensa")
		return
	end
	wheel:SetAttribute("Girando", true)
	local n = #Rewards.Wheel
	local jitter = (math.random() - 0.5) * (360 / n) * 0.6
	local target = wheelRotation - (wheelRotation % 360) + 360 * 6 + ((360 - segmentAngle(index)) % 360) + jitter
	local start = wheelRotation
	local duration = 4.2
	local t0 = os.clock()
	local lastTick = 0
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - t0) / duration, 0, 1)
		local eased = 1 - (1 - k) ^ 4
		wheelRotation = start + (target - start) * eased
		if wheel and wheel.Parent then
			wheel.Rotation = wheelRotation
		end
		-- "tic" a ogni spicchio
		local tick = math.floor(wheelRotation / (360 / n))
		if tick ~= lastTick then
			lastTick = tick
			C.SoundController.Play("UI", nil, { Volume = 0.25, Pitch = 1.4 })
		end
		if k >= 1 then
			connection:Disconnect()
			spinning = false
			if wheel and wheel.Parent then
				wheel:SetAttribute("Girando", nil)
			end
			C.SoundController.Play("Reward")
			if resultLabel then
				resultLabel.Text = ("Hai vinto: %s %s"):format(prize.Icon, prize.Name)
			end
			C.Notifications.Announce("🎡 " .. prize.Name, text, if prize.Big then "Raro" else "Ricompensa")
			if prize.Big and C.CameraController then
				C.CameraController.Shake(0.4, 0.6)
			end
			refreshWheelInfo()
		end
	end)
end

-- PANNELLO ------------------------------------------------------------------------------------------

local function render()
	if not panel then
		return
	end
	for id, button in tabButtons do
		button.BackgroundColor3 = if id == currentTab then Colors.Green else Colors.PanelLight
	end
	clear()
	local fn = if currentTab == "Calendario" then showCalendar elseif currentTab == "Regali" then showPlaytime else showWheel
	local ok, err = pcall(fn)
	if not ok then
		warn("[Premi] " .. tostring(err))
	end
end

function RewardsPanel.Open(tab: string?)
	if tab then
		currentTab = tab
	end
	if not C.UIController.IsOpen("Rewards") then
		C.UIController.Open("Rewards")
	else
		render()
	end
end

-- OFFERTA DI BENVENUTO -----------------------------------------------------------------------------

local function starterProduct()
	for _, product in Monetization.Products do
		if product.Kind == "Starter" then
			return product
		end
	end
	return nil
end

function RewardsPanel.StarterAvailable(): boolean
	local p = profile()
	return p ~= nil and not p.StarterBought and os.time() - (p.CreatedAt or 0) < Monetization.StarterHours * 3600
end

local offerShown = false
local function showStarterOffer()
	local product = starterProduct()
	if offerShown or not product or not RewardsPanel.StarterAvailable() or not Monetization.IsAvailable(product) then
		return
	end
	offerShown = true
	local p = profile()
	local left = Monetization.StarterHours * 3600 - (os.time() - (p.CreatedAt or 0))
	local box = Theme.Panel({ Name = "Offerta", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(460, 330), Parent = C.UIController.Layers.Overlay })
	C.UIController.AttachScale(box)
	Theme.Padding(box, 16)
	highlight(box, Colors.GoldBright, 3)
	Theme.Label("🎁 OFFERTA DI BENVENUTO", { Size = UDim2.new(1, 0, 0, 34), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Title, TextSize = 30, TextColor3 = Colors.GoldBright, Parent = box })
	Theme.Label(product.Name, { Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Header, TextSize = 20, Parent = box })
	Theme.Label(product.Contents or "", { Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 0, 70), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Bold, TextSize = 16, TextColor3 = Colors.Text, Parent = box })
	Theme.Label(("Solo per le nuove reclute • scade tra %s"):format(Util.FormatTime(left)), { Position = UDim2.fromOffset(0, 150), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.UI, TextSize = 14, TextColor3 = Colors.RedBright, Parent = box })
	Theme.Button(("Prendilo per R$ %d"):format(product.Robux), { Position = UDim2.fromOffset(0, 188), Size = UDim2.new(1, 0, 0, 52), TextSize = 22, BackgroundColor3 = Colors.Green, Parent = box }, function()
		Net.Event("PremiumBuy"):FireServer("Product", product.Id)
		box:Destroy()
		C.UIController.RequestCursor("Offerta", false)
	end)
	Theme.Button("No grazie", { Position = UDim2.fromOffset(0, 250), Size = UDim2.new(1, 0, 0, 36), TextSize = 15, Parent = box }, function()
		box:Destroy()
		C.UIController.RequestCursor("Offerta", false)
	end)
	C.UIController.RequestCursor("Offerta", true)
	C.SoundController.Play("Reward")
end

-- PULSANTI LATERALI ---------------------------------------------------------------------------------

local function sideButton(parent: Instance, order: number, icon: string, label: string, onClick: () -> ()): TextButton
	local button = Theme.Button(icon, { Size = UDim2.fromOffset(60, 60), TextSize = 28, LayoutOrder = order, Parent = parent }, onClick)
	New("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -1), Size = UDim2.new(1, 0, 0, 12), Font = Theme.Fonts.Bold, TextSize = 9, TextColor3 = Colors.Gold, Text = label, Parent = button })
	return button
end

local function inviteFriends()
	local ok, can = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if ok and can then
		pcall(function()
			SocialService:PromptGameInvite(player)
		end)
	else
		C.Notifications.Toast("Gli inviti non sono disponibili qui (in Studio non funzionano).", "Info", 3)
	end
end

local function joinGroup()
	local groupId = ReplicatedStorage:GetAttribute("GroupId") or 0
	if groupId == 0 then
		return
	end
	local ok = pcall(function()
		GroupService:PromptJoinAsync(groupId)
	end)
	if not ok then
		C.Notifications.Toast("Unisciti al gruppo dalla pagina del gioco, poi premi di nuovo questo pulsante.", "Info", 4)
	end
	Net.Event("CommunityAction"):FireServer("CheckGroup")
end

local function buildSideButtons()
	local holder = New("Frame", { Name = "Premi", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0), Size = UDim2.fromOffset(60, 4 * 60 + 3 * 8), BackgroundTransparency = 1, Parent = C.UIController.Layers.HUD })
	C.UIController.AttachScale(holder)
	New("UIListLayout", { Padding = UDim.new(0, 8), Parent = holder })
	local gift = sideButton(holder, 1, "🎁", "PREMI", function()
		RewardsPanel.Open()
	end)
	dot = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = Colors.Red, Visible = false, Parent = gift })
	Theme.Corner(dot, 10)
	New("TextLabel", { Name = "Numero", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Theme.Fonts.Bold, TextSize = 12, TextColor3 = Colors.White, Text = "", Parent = dot })
	sideButton(holder, 2, "🏆", "CLASSIFICHE", function()
		if C.Menu then
			C.Menu.OpenTab("Classifiche")
		end
	end)
	sideButton(holder, 3, "👥", "INVITA", inviteFriends)
	if (ReplicatedStorage:GetAttribute("GroupId") or 0) ~= 0 and player:GetAttribute("InGroup") ~= true then
		local groupButton = sideButton(holder, 4, "⭐", "GRUPPO", joinGroup)
		player:GetAttributeChangedSignal("InGroup"):Connect(function()
			groupButton.Visible = player:GetAttribute("InGroup") ~= true
		end)
	end
end

local function updateDot()
	if not dot then
		return
	end
	local count = readyCount()
	dot.Visible = count > 0
	local number = dot:FindFirstChild("Numero") :: TextLabel?
	if number then
		number.Text = tostring(count)
	end
end

function RewardsPanel.Init(c)
	C = c
end

function RewardsPanel.Start()
	panel = Theme.Panel({ Name = "Rewards", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(920, 560), Parent = C.UIController.Layers.Panels })
	Theme.Padding(panel, 14)
	Theme.Label("🎁 Premi", { Size = UDim2.new(1, -60, 0, 34), Font = Theme.Fonts.Title, TextSize = 30, TextColor3 = Colors.GoldBright, Parent = panel })
	Theme.Button("✕", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(36, 32), TextSize = 18, Parent = panel }, function()
		C.UIController.Close("Rewards")
	end)
	local tabs = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 38), Parent = panel })
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = tabs })
	for i, tab in TABS do
		tabButtons[tab.Id] = Theme.Button(tab.Icon .. " " .. tab.Id, { Size = UDim2.fromOffset(180, 38), TextSize = 15, LayoutOrder = i, Parent = tabs }, function()
			currentTab = tab.Id
			render()
		end)
	end
	content = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 92), Size = UDim2.new(1, 0, 1, -92), Parent = panel })
	C.UIController.RegisterPanel("Rewards", panel, render)
	buildSideButtons()

	C.ClientData.Changed:Connect(function()
		if C.UIController.IsOpen("Rewards") and not spinning then
			render()
		end
		updateDot()
	end)
	local function syncPlay()
		playBase = player:GetAttribute("PlayToday") or 0
		playBaseClock = os.clock()
	end
	syncPlay()
	player:GetAttributeChangedSignal("PlayToday"):Connect(syncPlay)
	Net.Event("WheelResult").OnClientEvent:Connect(onWheelResult)
	Net.Event("Achievement").OnClientEvent:Connect(function()
		C.SoundController.Play("Reward")
	end)

	-- aggiornamenti ogni secondo (conti alla rovescia e pallino rosso)
	task.spawn(function()
		while true do
			task.wait(1)
			updateDot()
			if C.UIController.IsOpen("Rewards") then
				if currentTab == "Regali" then
					refreshPlaytime()
				elseif currentTab == "Ruota" and not spinning then
					refreshWheelInfo()
				end
			end
		end
	end)

	-- all'ingresso: apre il calendario se c'è il premio del giorno
	task.spawn(function()
		local p = C.ClientData.WaitReady()
		task.wait(10)
		while (C.Intro and C.Intro.IsShowing and C.Intro.IsShowing()) or (C.CutsceneController and C.CutsceneController.IsPlaying()) or (C.Tutorial and C.Tutorial.IsActive()) or (C.CameraController and C.CameraController.IsCinematic()) do
			task.wait(2)
		end
		p = profile() or p
		if p and dailyIndex(p) and not C.UIController.IsOpen("Menu") then
			RewardsPanel.Open("Calendario")
		end
	end)

	-- offerta di benvenuto dopo 6 minuti di gioco (una volta per sessione, solo nei primi 3 giorni)
	task.delay(360, function()
		while (C.CutsceneController and C.CutsceneController.IsPlaying()) or C.UIController.IsOpen("Menu") or C.UIController.IsOpen("Rewards") or (C.Tutorial and C.Tutorial.IsActive()) do
			task.wait(5)
		end
		showStarterOffer()
	end)

	-- dopo 12 minuti chiede (una sola volta) di aggiungere il gioco ai Preferiti
	task.delay(720, function()
		local p = profile()
		if not p or p.FavoritePrompted or game.PlaceId == 0 then
			return
		end
		while C.CutsceneController and C.CutsceneController.IsPlaying() do
			task.wait(5)
		end
		Net.Event("CommunityAction"):FireServer("Favorite")
		pcall(function()
			AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
		end)
	end)
end

return RewardsPanel
