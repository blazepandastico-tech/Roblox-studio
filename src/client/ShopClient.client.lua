-- UI dello shop: menu laterale + finestra Store + animale che segue il cursore.
-- Bottoni e finestra sono oggetti reali in StarterGui (ShopMenu / ShopStore); qui li animiamo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopConfig"))
local remotes = ReplicatedStorage:WaitForChild("ShopRemotes")
local purchaseRemote = remotes:WaitForChild("Purchase")
local purchasedRemote = remotes:WaitForChild("Purchased")

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

----------------------------------------------------------------------
-- Helper
----------------------------------------------------------------------
local function create(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function round(inst, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) }, inst)
end

local function stroke(inst, color, thickness)
	return create("UIStroke", {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, inst)
end

local function textStroke(label, thickness)
	return create("UIStroke", {
		Color = BLACK,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	}, label)
end

local function gradient(inst, c1, c2, rotation)
	return create("UIGradient", {
		Color = ColorSequence.new(c1, c2),
		Rotation = rotation or 90,
	}, inst)
end

local function shade(color, factor)
	return Color3.new(
		math.clamp(color.R * factor, 0, 1),
		math.clamp(color.G * factor, 0, 1),
		math.clamp(color.B * factor, 0, 1)
	)
end

local function tween(inst, time, props, style, direction)
	local t = TweenService:Create(
		inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function label(parent, props)
	local l = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = WHITE,
	}, parent)
	for k, v in pairs(props) do
		l[k] = v
	end
	return l
end

local function makeScreenGui(name, order)
	return create("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = order,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)
end

-- Piccolo sistema di animatori: ogni funzione gira ogni frame e ritorna false per fermarsi.
local animators = {}
local function addAnimator(fn)
	table.insert(animators, fn)
end

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	for i = #animators, 1, -1 do
		if animators[i](dt, t) == false then
			table.remove(animators, i)
		end
	end
end)

local function alive(inst)
	return inst:IsDescendantOf(playerGui)
end

-- Icona Robux disegnata con i frame (esagono scuro con anello)
local function robuxIcon(parent, size)
	local holder = create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(size, size),
	}, parent)
	local outer = create("Frame", {
		BackgroundColor3 = Color3.fromRGB(35, 35, 40),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.78, 0.78),
		Rotation = 45,
	}, holder)
	round(outer, 6)
	local ring = create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.5),
	}, outer)
	round(ring, 4)
	stroke(ring, Color3.fromRGB(210, 210, 215), 2)
	return holder
end

----------------------------------------------------------------------
-- Toast (messaggi in basso)
----------------------------------------------------------------------
local toastGui = makeScreenGui("ShopToast", 30)
local toastLabel = label(toastGui, {
	Name = "Toast",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, 80),
	Size = UDim2.fromOffset(320, 46),
	BackgroundTransparency = 0,
	BackgroundColor3 = Color3.fromRGB(30, 30, 45),
	TextSize = 24,
	Text = "",
})
round(toastLabel, 14)
stroke(toastLabel, WHITE, 3)
textStroke(toastLabel, 2)
local toastId = 0

local function toast(text, color)
	toastId += 1
	local myId = toastId
	toastLabel.Text = text
	toastLabel.BackgroundColor3 = color or Color3.fromRGB(30, 30, 45)
	toastLabel.Position = UDim2.new(0.5, 0, 1, 80)
	tween(toastLabel, 0.45, { Position = UDim2.new(0.5, 0, 1, -40) }, Enum.EasingStyle.Back)
	task.delay(2.2, function()
		if myId == toastId then
			tween(toastLabel, 0.3, { Position = UDim2.new(0.5, 0, 1, 80) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		end
	end)
end

----------------------------------------------------------------------
-- Coriandoli
----------------------------------------------------------------------
local fxGui = makeScreenGui("ShopFX", 40)
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(255, 200, 40),
	Color3.fromRGB(80, 220, 90),
	Color3.fromRGB(70, 160, 255),
	Color3.fromRGB(200, 90, 255),
	Color3.fromRGB(255, 120, 200),
}

local function confetti(origin, count)
	for _ = 1, count do
		local piece = create("Frame", {
			BackgroundColor3 = CONFETTI_COLORS[math.random(1, #CONFETTI_COLORS)],
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(math.random(8, 14), math.random(6, 10)),
			Position = UDim2.fromOffset(origin.X, origin.Y),
			Rotation = math.random(0, 360),
		}, fxGui)
		local angle = math.random() * math.pi * 2
		local speed = math.random(200, 650)
		local vx, vy = math.cos(angle) * speed, math.sin(angle) * speed - 280
		local px, py = origin.X, origin.Y
		local born = os.clock()
		local spin = math.random(-500, 500)
		addAnimator(function(dt, t)
			local age = t - born
			if age > 1.9 or not alive(piece) then
				piece:Destroy()
				return false
			end
			vy += 950 * dt
			vx *= 1 - math.min(dt * 1.3, 1)
			px += vx * dt
			py += vy * dt
			piece.Position = UDim2.fromOffset(px, py)
			piece.Rotation += spin * dt
			piece.BackgroundTransparency = math.clamp((age - 1.2) / 0.7, 0, 1)
			return true
		end)
	end
end

local function sparkle(parent, position, text, size)
	local s = label(parent, {
		Text = text or "✨",
		TextSize = size or 22,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(30, 30),
		Rotation = math.random(-30, 30),
		ZIndex = 20,
	})
	tween(s, 0.9, {
		Position = position - UDim2.fromOffset(math.random(-10, 10), math.random(25, 45)),
		TextTransparency = 1,
		Rotation = s.Rotation + math.random(-60, 60),
	})
	task.delay(0.95, function()
		s:Destroy()
	end)
	return s
end

----------------------------------------------------------------------
-- Menu laterale: gli oggetti sono in StarterGui > ShopMenu (vedi tools/gen_ui.py)
----------------------------------------------------------------------
local menuGui = playerGui:WaitForChild("ShopMenu")
local menuRoot = menuGui:WaitForChild("Menu")
local menuScale = menuRoot:WaitForChild("UIScale")

local function updateMenuScale()
	local vp = camera.ViewportSize
	menuScale.Scale = math.clamp(vp.Y / 800, 0.55, 1)
end
updateMenuScale()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateMenuScale)

local openStore -- definita piu sotto
local toggleStore

local giftRemaining = Config.GiftSeconds

local menuDefs = {
	{ Name = "Sentieri" },
	{ Name = "Rinascita" },
	{ Name = "Giornaliero", Badge = true },
	{ Name = "Gift", Gift = true },
	{ Name = "Musica" },
	{ Name = "Shop", Shop = true },
}

local function formatTime(seconds)
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Sceglie tra emoji e immagine (se in Studio o in Config hai messo un asset id)
local function pickIcon(textIcon, imageIcon, configImage)
	if configImage and configImage ~= "" then
		imageIcon.Image = configImage
	end
	local useImage = imageIcon.Image ~= ""
	imageIcon.Visible = useImage
	textIcon.Visible = not useImage
	return useImage and imageIcon or textIcon
end

local function bindMenuButton(def, index)
	local holder = menuRoot:WaitForChild(def.Name)
	local scale = holder:WaitForChild("UIScale")
	local body = holder:WaitForChild("Body")
	local bodyStroke = body:FindFirstChildOfClass("UIStroke")
	local baseStrokeColor = bodyStroke.Color
	local nameLabel = body:WaitForChild("NameLabel")
	local icon = pickIcon(body:WaitForChild("Icon"), body:WaitForChild("IconImage"), def.Shop and Config.ShopIconImage)
	local badge = holder:FindFirstChild("Badge")
	local badgeScale = badge and badge:FindFirstChildOfClass("UIScale")

	if not body:FindFirstChildOfClass("UIGradient") then
		gradient(body, body.BackgroundColor3:Lerp(WHITE, 0.3), shade(body.BackgroundColor3, 0.88))
	end

	-- entrata
	scale.Scale = 0
	task.delay(0.1 * index, function()
		tween(scale, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
	end)

	-- Hover / click
	local ready = false
	local hovering = false
	task.delay(0.1 * index + 0.7, function()
		ready = true
	end)

	body.MouseEnter:Connect(function()
		if not ready then
			return
		end
		hovering = true
		tween(scale, 0.25, { Scale = 1.12 }, Enum.EasingStyle.Back)
		tween(holder, 0.12, { Rotation = -6 })
		task.delay(0.12, function()
			tween(holder, 0.35, { Rotation = 0 }, Enum.EasingStyle.Elastic)
		end)
	end)
	body.MouseLeave:Connect(function()
		hovering = false
		if ready then
			tween(scale, 0.2, { Scale = 1 })
		end
	end)
	body.MouseButton1Down:Connect(function()
		if ready then
			tween(scale, 0.08, { Scale = 0.9 })
		end
	end)
	body.Activated:Connect(function()
		if not ready then
			return
		end
		tween(scale, 0.35, { Scale = hovering and 1.12 or 1 }, Enum.EasingStyle.Elastic)
		if def.Shop then
			toggleStore()
		elseif def.Gift then
			if giftRemaining <= 0 then
				giftRemaining = Config.GiftSeconds
				confetti(holder.AbsolutePosition + holder.AbsoluteSize / 2, 25)
				toast("🎁 Regalo ritirato!", Color3.fromRGB(255, 150, 40))
			else
				toast("⏳ Il regalo arriva tra " .. formatTime(math.ceil(giftRemaining)), Color3.fromRGB(70, 70, 110))
			end
		else
			toast("✨ " .. def.Name .. " - presto disponibile!", Color3.fromRGB(70, 70, 110))
		end
	end)

	-- Animazioni idle
	local phase = index * 1.3
	local wasShaking = false
	local sparkleTimer = 0
	addAnimator(function(dt, t)
		if not alive(holder) then
			return false
		end
		body.Rotation = math.sin(t * 2 + phase) * 2.2
		icon.Position = UDim2.new(0.5, 0, 0.4, math.sin(t * 3 + phase) * 3)
		if badgeScale then
			badgeScale.Scale = 1 + math.abs(math.sin(t * 4)) * 0.22
		end
		if def.Shop then
			local pulse = (math.sin(t * 4) + 1) / 2
			bodyStroke.Color = baseStrokeColor:Lerp(WHITE, pulse * 0.85)
			local cycle = t % 4
			if cycle < 0.7 and not hovering then
				holder.Rotation = math.sin(cycle * 38) * 9 * (1 - cycle / 0.7)
				wasShaking = true
			elseif wasShaking then
				holder.Rotation = 0
				wasShaking = false
			end
			sparkleTimer += dt
			if sparkleTimer > 0.45 then
				sparkleTimer = 0
				local pos = UDim2.new(math.random(), 0, math.random() * 0.8, 0)
				sparkle(holder, pos, math.random() < 0.5 and "✨" or "⭐", math.random(16, 26))
			end
		end
		if def.Gift then
			local sec = math.max(0, math.ceil(giftRemaining))
			nameLabel.Text = sec > 0 and formatTime(sec) or "Ritira!"
		end
		return true
	end)
end

for i, def in ipairs(menuDefs) do
	bindMenuButton(def, i)
end

-- Conto alla rovescia del regalo
addAnimator(function(dt)
	if giftRemaining > 0 then
		giftRemaining = math.max(0, giftRemaining - dt)
	end
	return true
end)

----------------------------------------------------------------------
-- Finestra Store: oggetti in StarterGui > ShopStore
----------------------------------------------------------------------
local WIN_W, WIN_H = 640, 430
local PANEL_W, PANEL_H = 624, 364

local storeGui = playerGui:WaitForChild("ShopStore")
storeGui.Enabled = false

local blur = Instance.new("BlurEffect")
blur.Name = "ShopBlur"
blur.Size = 0
blur.Parent = Lighting

local overlay = storeGui:WaitForChild("Overlay")
local fit = storeGui:WaitForChild("Fit")
local fitScale = fit:WaitForChild("FitScale")

local function updateFit()
	local vp = camera.ViewportSize
	fitScale.Scale = math.min(1, vp.X / (WIN_W + 70), vp.Y / (WIN_H + 70))
end
updateFit()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateFit)

local window = fit:WaitForChild("Window")
local openScale = window:WaitForChild("OpenScale")
openScale.Scale = 0
gradient(window, Color3.fromRGB(95, 190, 255), Color3.fromRGB(40, 120, 220))

local panel = window:WaitForChild("Panel")
gradient(panel, Color3.fromRGB(255, 252, 238), Color3.fromRGB(255, 232, 160))
local cardsFolder = panel:WaitForChild("Cards")

-- Soldi che fluttuano nello sfondo
local moneyBits = {}
for i = 1, 18 do
	local l = label(panel, {
		Text = "💵",
		TextSize = math.random(26, 40),
		TextTransparency = 0.55,
		Size = UDim2.fromOffset(44, 44),
		ZIndex = 1,
	})
	moneyBits[i] = {
		label = l,
		x = math.random() * PANEL_W,
		y = math.random() * PANEL_H,
		speed = math.random(14, 32),
		rot = math.random(0, 360),
		spin = math.random(-25, 25),
	}
end
addAnimator(function(dt)
	if not alive(panel) then
		return false
	end
	if not storeGui.Enabled then
		return true
	end
	for _, bit in ipairs(moneyBits) do
		bit.x += bit.speed * dt
		bit.y += bit.speed * 0.7 * dt
		bit.rot += bit.spin * dt
		if bit.x > PANEL_W + 30 then
			bit.x = -30
		end
		if bit.y > PANEL_H + 30 then
			bit.y = -30
		end
		bit.label.Position = UDim2.fromOffset(bit.x - 22, bit.y - 22)
		bit.label.Rotation = bit.rot
	end
	return true
end)

-- Icona cestino (emoji oppure immagine)
local basket = pickIcon(window:WaitForChild("BasketIcon"), window:WaitForChild("BasketImage"), Config.ShopIconImage)

-- Tab
local tabButtons = {}
local currentTab = 1
local showTab -- definita dopo

local function bindTab(def, index)
	local holder = window:WaitForChild("Tab_" .. def.Id)
	local pop = holder:WaitForChild("UIScale")
	local body = holder:WaitForChild("Body")
	local st = body:FindFirstChildOfClass("UIStroke")
	local icon = body:WaitForChild("Icon")
	local dark = st.Color
	local basePos = holder.Position

	if not body:FindFirstChildOfClass("UIGradient") then
		gradient(body, body.BackgroundColor3:Lerp(WHITE, 0.35), shade(body.BackgroundColor3, 0.9))
	end

	body.MouseEnter:Connect(function()
		tween(holder, 0.12, { Rotation = -10 })
		task.delay(0.12, function()
			tween(holder, 0.35, { Rotation = 0 }, Enum.EasingStyle.Elastic)
		end)
	end)
	body.Activated:Connect(function()
		showTab(index)
	end)

	addAnimator(function(_, t)
		if not alive(holder) then
			return false
		end
		icon.Rotation = math.sin(t * 3 + index) * 6
		return true
	end)

	tabButtons[index] = { holder = holder, pop = pop, stroke = st, dark = dark, basePos = basePos }
end

for i, def in ipairs(Config.Tabs) do
	bindTab(def, i)
end

local function selectTabVisual(index)
	for i, tab in ipairs(tabButtons) do
		local selected = i == index
		tween(tab.pop, 0.3, { Scale = selected and 1.18 or 1 }, Enum.EasingStyle.Back)
		tween(tab.holder, 0.25, {
			Position = tab.basePos + UDim2.fromOffset(0, selected and 4 or 0),
		}, Enum.EasingStyle.Back)
		tab.stroke.Color = selected and WHITE or tab.dark
	end
end

-- Pulsante chiudi
local closeHolder = window:WaitForChild("Close")
local closeScale = closeHolder:WaitForChild("UIScale")
local closeBody = closeHolder:WaitForChild("Body")
gradient(closeBody, Color3.fromRGB(255, 100, 100), Color3.fromRGB(210, 25, 25))

closeBody.MouseEnter:Connect(function()
	tween(closeScale, 0.2, { Scale = 1.15 }, Enum.EasingStyle.Back)
	tween(closeHolder, 0.25, { Rotation = 90 }, Enum.EasingStyle.Back)
end)
closeBody.MouseLeave:Connect(function()
	tween(closeScale, 0.2, { Scale = 1 })
	tween(closeHolder, 0.25, { Rotation = 0 })
end)

-- Celebrazione acquisto / carte
local cardMap = {}

local function requestPurchase(item)
	if item.ProductId and item.ProductId ~= 0 then
		MarketplaceService:PromptProductPurchase(player, item.ProductId)
	elseif Config.TestMode then
		purchaseRemote:FireServer(item.Id)
	else
		toast("Non disponibile", Color3.fromRGB(150, 40, 40))
	end
end

local itemsById = {}
local pages = {}
for _, tab in ipairs(Config.Tabs) do
	pages[tab.Id] = {}
end
for _, item in ipairs(Config.Items) do
	itemsById[item.Id] = item
	table.insert(pages[item.Tab], item)
end

local PAD, SLOT_GAP = 10, 8
local topW = (PANEL_W - PAD * 2 - SLOT_GAP * 2) / 3
local rowH = (PANEL_H - PAD * 2 - SLOT_GAP) / 2
local botW = (PANEL_W - PAD * 2 - SLOT_GAP) / 2

local function slotRect(index)
	if index <= 3 then
		return PAD + (index - 1) * (topW + SLOT_GAP), PAD, topW, rowH
	end
	return PAD + (index - 4) * (botW + SLOT_GAP), PAD + rowH + SLOT_GAP, botW, rowH
end

local function buildCard(item, index, delay)
	local x, y, w, h = slotRect(index)
	local wide = index > 3
	local baseY = y + h / 2

	local holder = create("Frame", {
		Name = item.Id,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x + w / 2, baseY),
		Size = UDim2.fromOffset(w, h),
	}, cardsFolder)
	local scale = create("UIScale", { Scale = 0 }, holder)
	cardMap[item.Id] = holder

	local body = create("TextButton", {
		Name = "Body",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = item.Color,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
	}, holder)
	round(body, 16)
	stroke(body, shade(item.Color, 0.5), 3.5)
	gradient(body, item.Color:Lerp(WHITE, 0.3), shade(item.Color, 0.85))

	-- raggi che ruotano
	local diag = math.sqrt(w * w + h * h)
	local rays = create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(diag, diag),
	}, body)
	for i = 0, 7 do
		create("Frame", {
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.86,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 24, 1, 0),
			Rotation = i * 22.5,
		}, rays)
	end

	-- scritte
	local name = label(body, {
		Text = item.Name,
		TextScaled = true,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, wide and 32 or 34),
		ZIndex = 3,
	})
	create("UITextSizeConstraint", { MaxTextSize = 30 }, name)
	textStroke(name, 3)

	local desc = label(body, {
		Text = item.Desc,
		TextSize = 15,
		TextWrapped = true,
		Font = Enum.Font.FredokaOne,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, wide and 44 or 46),
		Size = UDim2.new(1, -28, 0, wide and 36 or 60),
		ZIndex = 3,
	})
	textStroke(desc, 2)

	local bigIcon
	if item.Icon then
		bigIcon = label(body, {
			Text = item.Icon,
			TextSize = 58,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.16, 0, 0.7, 0),
			Size = UDim2.fromOffset(70, 70),
			ZIndex = 3,
		})
	end

	-- prezzo
	local green = Color3.fromRGB(45, 200, 70)
	local price = create("Frame", {
		Name = "Price",
		BackgroundColor3 = green,
		AnchorPoint = wide and Vector2.new(1, 1) or Vector2.new(0.5, 1),
		Position = wide and UDim2.new(1, -12, 1, -10) or UDim2.new(0.5, 0, 1, -10),
		Size = wide and UDim2.fromOffset(130, 40) or UDim2.new(0.66, 0, 0, 40),
		ZIndex = 4,
	}, body)
	round(price, 10)
	stroke(price, Color3.fromRGB(20, 100, 35), 3)
	gradient(price, Color3.fromRGB(110, 240, 120), green)
	local priceScale = create("UIScale", {}, price)
	robuxIcon(price, 26).ZIndex = 5
	local priceText = label(price, {
		Text = tostring(item.Price),
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(40, 0),
		Size = UDim2.new(1, -44, 1, 0),
		ZIndex = 5,
	})
	textStroke(priceText, 2.5)

	-- scia di luce
	local shine = create("Frame", {
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(38, h * 1.8),
		Rotation = 22,
		ZIndex = 8,
		Visible = false,
	}, body)

	-- etichetta (HOT!, NEW...)
	local tagScale
	if item.Tag then
		local tag = create("Frame", {
			BackgroundColor3 = Color3.fromRGB(235, 40, 40),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -10, 0, 8),
			Size = UDim2.fromOffset(62, 26),
			Rotation = 14,
			ZIndex = 12,
		}, holder)
		round(tag, 8)
		stroke(tag, Color3.fromRGB(110, 10, 10), 2.5)
		local tagLabel = label(tag, {
			Text = item.Tag,
			TextSize = 18,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 13,
		})
		textStroke(tagLabel, 2)
		tagScale = create("UIScale", {}, tag)
	end

	-- interazione
	local ready = false
	local hovering = false
	task.delay(delay + 0.55, function()
		ready = true
	end)

	body.MouseEnter:Connect(function()
		if not ready then
			return
		end
		hovering = true
		tween(scale, 0.25, { Scale = 1.07 }, Enum.EasingStyle.Back)
		tween(holder, 0.1, { Rotation = (math.random() < 0.5 and -1 or 1) * 2.5 })
		task.delay(0.1, function()
			tween(holder, 0.35, { Rotation = 0 }, Enum.EasingStyle.Elastic)
		end)
	end)
	body.MouseLeave:Connect(function()
		hovering = false
		if ready then
			tween(scale, 0.2, { Scale = 1 })
		end
	end)
	body.MouseButton1Down:Connect(function()
		if ready then
			tween(scale, 0.08, { Scale = 0.93 })
		end
	end)
	body.Activated:Connect(function()
		if not ready then
			return
		end
		tween(scale, 0.4, { Scale = hovering and 1.07 or 1 }, Enum.EasingStyle.Elastic)
		requestPurchase(item)
	end)

	-- animazioni idle
	addAnimator(function(_, t)
		if not alive(holder) then
			return false
		end
		holder.Position = UDim2.fromOffset(x + w / 2, baseY + math.sin(t * 1.8 + index) * 2.5)
		rays.Rotation = t * 10 + index * 20
		priceScale.Scale = 1 + math.sin(t * 4 + index) * 0.045
		if bigIcon then
			bigIcon.Rotation = math.sin(t * 2.5 + index) * 10
			bigIcon.Position = UDim2.new(0.16, 0, 0.7, math.sin(t * 3 + index) * 4)
		end
		if tagScale then
			tagScale.Scale = 1 + math.abs(math.sin(t * 3 + index)) * 0.15
		end
		local cycle = (t + index * 0.6) % 3.4
		if cycle < 1 then
			shine.Visible = true
			shine.Position = UDim2.fromOffset(-60 + cycle * (w + 120), h / 2)
		else
			shine.Visible = false
		end
		return true
	end)

	-- entrata
	task.delay(delay, function()
		if alive(holder) then
			tween(scale, 0.55, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end)
end

showTab = function(index)
	currentTab = index
	selectTabVisual(index)
	for _, child in ipairs(cardsFolder:GetChildren()) do
		child:Destroy()
	end
	cardMap = {}
	local items = pages[Config.Tabs[index].Id]
	for i, item in ipairs(items) do
		if i <= 5 then
			buildCard(item, i, 0.05 + i * 0.07)
		end
	end
end

-- Quando il server conferma l'acquisto
purchasedRemote.OnClientEvent:Connect(function(itemId)
	local item = itemsById[itemId]
	if not item then
		return
	end
	local card = cardMap[itemId]
	local origin
	if card and alive(card) then
		origin = card.AbsolutePosition + card.AbsoluteSize / 2
	else
		origin = camera.ViewportSize / 2
	end
	confetti(origin, 45)
	toast("✅ Hai preso: " .. item.Name .. "!", Color3.fromRGB(40, 150, 60))
end)

----------------------------------------------------------------------
-- Animale che segue il cursore
----------------------------------------------------------------------
local petGui = makeScreenGui("ShopPet", 50)
local PET_SIZE = 60
local ORANGE = Color3.fromRGB(255, 168, 40)

local pet = create("Frame", {
	Name = "Pet",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(PET_SIZE, PET_SIZE),
	Visible = false,
}, petGui)
local petScale = create("UIScale", { Scale = 0 }, pet)

-- orecchie
for _, sx in ipairs({ 0.2, 0.8 }) do
	local ear = create("Frame", {
		BackgroundColor3 = ORANGE,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(sx, 0.08),
		Size = UDim2.fromOffset(18, 18),
		Rotation = sx < 0.5 and -25 or 25,
	}, pet)
	round(ear, 7)
	stroke(ear, Color3.fromRGB(150, 80, 10), 3)
end

local petBody = create("Frame", {
	BackgroundColor3 = ORANGE,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromScale(1, 0.92),
}, pet)
round(petBody, 30)
stroke(petBody, Color3.fromRGB(150, 80, 10), 3.5)
gradient(petBody, Color3.fromRGB(255, 205, 90), Color3.fromRGB(255, 150, 30))

local eyes = {}
for _, ex in ipairs({ 0.3, 0.7 }) do
	local eye = create("Frame", {
		BackgroundColor3 = WHITE,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(ex, 0.4),
		Size = UDim2.fromOffset(17, 17),
		ZIndex = 2,
	}, petBody)
	round(eye, 9)
	local pupil = create("Frame", {
		BackgroundColor3 = BLACK,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(9, 9),
		ZIndex = 3,
	}, eye)
	round(pupil, 5)
	local glint = create("Frame", {
		BackgroundColor3 = WHITE,
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.fromOffset(3, 3),
		ZIndex = 4,
	}, pupil)
	round(glint, 2)
	table.insert(eyes, { eye = eye, pupil = pupil })
end

for _, cx in ipairs({ 0.14, 0.86 }) do
	local blush = create("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 110, 130),
		BackgroundTransparency = 0.35,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(cx, 0.68),
		Size = UDim2.fromOffset(11, 7),
		ZIndex = 2,
	}, petBody)
	round(blush, 4)
end

local mouth = create("Frame", {
	BackgroundColor3 = Color3.fromRGB(150, 40, 30),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.7),
	Size = UDim2.fromOffset(12, 7),
	ZIndex = 2,
}, petBody)
round(mouth, 5)

local petPos = Vector2.new(0, 0)
local lastTrail = 0
local petBobSeed = 0

addAnimator(function(dt, t)
	if not pet.Visible then
		return true
	end
	local mouse = UserInputService:GetMouseLocation()
	local target = mouse + Vector2.new(40, 32)
	local prev = petPos
	petPos = petPos:Lerp(target, 1 - math.exp(-8 * dt))
	local vel = (petPos - prev) / math.max(dt, 1 / 240)

	pet.Position = UDim2.fromOffset(petPos.X, petPos.Y + math.sin(t * 7 + petBobSeed) * 3)
	pet.Rotation = math.clamp(vel.X * 0.03, -25, 25)
	local stretch = math.clamp(vel.Magnitude / 1600, 0, 0.25)
	pet.Size = UDim2.fromOffset(PET_SIZE * (1 - stretch * 0.4), PET_SIZE * (1 + stretch * 0.5))

	-- occhi che guardano il cursore + battito di ciglia
	local dir = mouse - petPos
	local unit = dir.Magnitude > 1 and dir.Unit or Vector2.zero
	local blink = (t % 3.3) < 0.12
	for _, e in ipairs(eyes) do
		e.pupil.Position = UDim2.new(0.5, unit.X * 3, 0.5, unit.Y * 3)
		e.eye.Size = blink and UDim2.fromOffset(17, 4) or UDim2.fromOffset(17, 17)
	end
	mouth.Size = vel.Magnitude > 400 and UDim2.fromOffset(14, 11) or UDim2.fromOffset(12, 7)

	-- scia di stelline quando corre
	if vel.Magnitude > 260 and t - lastTrail > 0.05 then
		lastTrail = t
		sparkle(petGui, UDim2.fromOffset(petPos.X, petPos.Y + 10), "✦", math.random(14, 22)).TextColor3 =
			Color3.fromRGB(255, 220, 80)
	end
	return true
end)

local function showPet()
	local mouse = UserInputService:GetMouseLocation()
	petPos = Vector2.new(mouse.X, -80) -- cade dall'alto
	pet.Visible = true
	petScale.Scale = 0
	tween(petScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
end

local function hidePet()
	local t = tween(petScale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	t.Completed:Connect(function()
		if petScale.Scale <= 0.05 then
			pet.Visible = false
		end
	end)
end

----------------------------------------------------------------------
-- Apri / chiudi
----------------------------------------------------------------------
local isOpen = false
local busy = false
local basketFree = false

openStore = function()
	if isOpen or busy then
		return
	end
	busy = true
	isOpen = true

	storeGui.Enabled = true
	overlay.BackgroundTransparency = 1
	tween(overlay, 0.3, { BackgroundTransparency = 0.5 })
	tween(blur, 0.35, { Size = 16 })

	openScale.Scale = 0
	window.Rotation = -12
	tween(openScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(window, 0.6, { Rotation = 0 }, Enum.EasingStyle.Back)

	-- cestino che rimbalza dentro
	basketFree = false
	basket.Rotation = -25
	tween(basket, 0.9, { Rotation = 0 }, Enum.EasingStyle.Elastic)
	task.delay(1, function()
		basketFree = true
	end)

	-- tab e bottone chiudi entrano a cascata
	for i, tab in ipairs(tabButtons) do
		tab.pop.Scale = 0
		task.delay(0.2 + i * 0.07, function()
			tween(tab.pop, 0.45, { Scale = i == currentTab and 1.18 or 1 }, Enum.EasingStyle.Back)
		end)
	end
	closeScale.Scale = 0
	task.delay(0.45, function()
		tween(closeScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	end)

	showTab(currentTab)
	showPet()

	task.delay(0.6, function()
		busy = false
	end)
end

local function closeStore()
	if not isOpen or busy then
		return
	end
	busy = true
	isOpen = false

	tween(overlay, 0.3, { BackgroundTransparency = 1 })
	tween(blur, 0.3, { Size = 0 })
	tween(openScale, 0.3, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	tween(window, 0.3, { Rotation = 10 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	hidePet()

	task.delay(0.32, function()
		storeGui.Enabled = false
		busy = false
	end)
end

toggleStore = function()
	if isOpen then
		closeStore()
	else
		openStore()
	end
end

closeBody.Activated:Connect(closeStore)
overlay.Activated:Connect(closeStore)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.B then
		toggleStore()
	end
end)

-- Cestino che dondola mentre il negozio e' aperto
addAnimator(function(_, t)
	if not alive(basket) then
		return false
	end
	if isOpen and basketFree then
		basket.Rotation = math.sin(t * 2.2) * 6
		basket.Position = UDim2.fromOffset(44, 24 + math.sin(t * 3) * 3)
	end
	return true
end)
