--[[
	Notifications
	- Notifiche brevi in alto (ricompense, errori, obiettivi)
	- Grandi annunci animati al centro (boss, sieri, stagioni, salita di livello)
	- Banner del nome della zona
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Lib.Net)
local Util = require(Shared.Lib.Util)

local Theme = require(script.Parent.Theme)
local New = Theme.New

local Notifications = {}
local C
local toastHolder: Frame
local announceQueue = {}
local announcing = false

local KIND_COLORS = {
	Info = Theme.Colors.Text,
	Successo = Theme.Colors.GreenBright,
	Errore = Theme.Colors.RedBright,
	Ricompensa = Theme.Colors.GoldBright,
	Raro = Color3.fromRGB(200, 140, 255),
	Storia = Color3.fromRGB(150, 210, 255),
}

local ANNOUNCE_STYLES = {
	Info = { Color = Theme.Colors.Text, Accent = Theme.Colors.Gold },
	Successo = { Color = Theme.Colors.GreenBright, Accent = Theme.Colors.Green },
	Pericolo = { Color = Theme.Colors.RedBright, Accent = Theme.Colors.Red },
	Boss = { Color = Color3.fromRGB(255, 120, 90), Accent = Theme.Colors.Red },
	Vittoria = { Color = Theme.Colors.GoldBright, Accent = Theme.Colors.Gold },
	Siero = { Color = Color3.fromRGB(140, 255, 170), Accent = Color3.fromRGB(60, 160, 90) },
	Raro = { Color = Color3.fromRGB(210, 160, 255), Accent = Color3.fromRGB(130, 80, 200) },
	Storia = { Color = Color3.fromRGB(160, 215, 255), Accent = Theme.Colors.Blue },
	Stagione = { Color = Theme.Colors.GoldBright, Accent = Theme.Colors.Gold },
	Notte = { Color = Color3.fromRGB(170, 190, 255), Accent = Color3.fromRGB(70, 80, 160) },
	Giorno = { Color = Color3.fromRGB(255, 220, 150), Accent = Theme.Colors.Gold },
	Livello = { Color = Theme.Colors.GoldBright, Accent = Theme.Colors.Gold },
}

function Notifications.Toast(text: string, kind: string?, duration: number?)
	if not toastHolder then
		return
	end
	local color = KIND_COLORS[kind or "Info"] or Theme.Colors.Text
	local frame = Theme.Panel({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.15,
		LayoutOrder = -math.floor(os.clock() * 100),
		Parent = toastHolder,
	})
	Theme.Padding(frame, 8)
	local accent = New("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.new(0, 4, 1, 0), Parent = frame })
	Theme.Corner(accent, 2)
	local label = Theme.Label(text, {
		Size = UDim2.new(1, -14, 0, 0),
		Position = UDim2.fromOffset(12, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextColor3 = color,
		Font = Theme.Fonts.UI,
		TextSize = 17,
		TextTransparency = 1,
		Parent = frame,
	})
	frame.BackgroundTransparency = 1
	Theme.Tween(frame, 0.25, { BackgroundTransparency = 0.15 })
	Theme.Tween(label, 0.25, { TextTransparency = 0 })
	task.delay(duration or 4, function()
		Theme.Tween(frame, 0.4, { BackgroundTransparency = 1 })
		local tween = Theme.Tween(label, 0.4, { TextTransparency = 1 })
		tween.Completed:Connect(function()
			frame:Destroy()
		end)
	end)
	if kind == "Ricompensa" or kind == "Raro" then
		if C.SoundController then
			C.SoundController.Play("Reward")
		end
	end
	-- al massimo 6 notifiche visibili
	local items = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(items, child)
		end
	end
	if #items > 6 then
		table.sort(items, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		items[1]:Destroy()
	end
end

local function playAnnouncement(data)
	local layer = C.UIController.Layers.Overlay
	local style = ANNOUNCE_STYLES[data.Kind] or ANNOUNCE_STYLES.Info
	local holder = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(900, 150),
		BackgroundTransparency = 1,
		Parent = layer,
	})
	C.UIController.AttachScale(holder)
	-- striscia di sfondo che si apre da sinistra a destra
	local band = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 0, 0, 110),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = holder,
	})
	New("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1) }),
		Parent = band,
	})
	local lineTop = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0, 0, 0, 2), BackgroundColor3 = style.Accent, BorderSizePixel = 0, Parent = band })
	local lineBottom = New("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(0, 0, 0, 2), BackgroundColor3 = style.Accent, BorderSizePixel = 0, Parent = band })
	local title = Theme.Label(data.Title, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.new(1, -40, 0, 56),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.Title,
		TextSize = 52,
		TextColor3 = style.Color,
		TextStrokeTransparency = 0.4,
		TextTransparency = 1,
		Parent = holder,
	})
	local subtitle = Theme.Label(data.Subtitle or "", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.74),
		Size = UDim2.new(1, -60, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.Body,
		TextSize = 20,
		TextColor3 = Theme.Colors.Text,
		TextTransparency = 1,
		Parent = holder,
	})
	local titleScale = New("UIScale", { Scale = 1.4, Parent = title })
	Theme.Tween(band, 0.35, { Size = UDim2.new(1, 0, 0, 110) }, Enum.EasingStyle.Quart)
	Theme.Tween(lineTop, 0.5, { Size = UDim2.new(0.8, 0, 0, 2) }, Enum.EasingStyle.Quart)
	Theme.Tween(lineBottom, 0.5, { Size = UDim2.new(0.8, 0, 0, 2) }, Enum.EasingStyle.Quart)
	task.wait(0.12)
	Theme.Tween(title, 0.3, { TextTransparency = 0 })
	Theme.Tween(titleScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	task.wait(0.2)
	Theme.Tween(subtitle, 0.4, { TextTransparency = 0 })
	if C.SoundController then
		C.SoundController.Play(if data.Kind == "Boss" or data.Kind == "Pericolo" then "Roar" else "Reward")
	end
	task.wait(data.Duration or 3.2)
	Theme.Tween(title, 0.4, { TextTransparency = 1 })
	Theme.Tween(subtitle, 0.4, { TextTransparency = 1 })
	Theme.Tween(lineTop, 0.4, { Size = UDim2.new(0, 0, 0, 2) })
	Theme.Tween(lineBottom, 0.4, { Size = UDim2.new(0, 0, 0, 2) })
	local tween = Theme.Tween(band, 0.45, { Size = UDim2.new(0, 0, 0, 110) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
	tween.Completed:Wait()
	holder:Destroy()
end

function Notifications.Announce(title: string, subtitle: string?, kind: string?, duration: number?)
	table.insert(announceQueue, { Title = title, Subtitle = subtitle, Kind = kind, Duration = duration })
	if announcing then
		return
	end
	announcing = true
	task.spawn(function()
		while #announceQueue > 0 do
			local data = table.remove(announceQueue, 1)
			local ok, err = pcall(playAnnouncement, data)
			if not ok then
				warn("[Notifications] " .. tostring(err))
			end
		end
		announcing = false
	end)
end

-- Banner della zona (in basso al centro)
local zoneBanner: Frame? = nil
function Notifications.ZoneBanner(name: string, subtitle: string, color: Color3?)
	local layer = C.UIController.Layers.Overlay
	if zoneBanner then
		zoneBanner:Destroy()
	end
	local holder = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.82, 0),
		Size = UDim2.fromOffset(700, 90),
		BackgroundTransparency = 1,
		Parent = layer,
	})
	zoneBanner = holder
	C.UIController.AttachScale(holder)
	local title = Theme.Label(name, {
		Size = UDim2.new(1, 0, 0, 50),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.Title,
		TextSize = 44,
		TextColor3 = color or Theme.Colors.GoldBright,
		TextStrokeTransparency = 0.3,
		TextTransparency = 1,
		Parent = holder,
	})
	local line = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 54), Size = UDim2.new(0, 0, 0, 2), BackgroundColor3 = Theme.Colors.Gold, BorderSizePixel = 0, Parent = holder })
	local sub = Theme.Label(subtitle, {
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.UI,
		TextSize = 18,
		TextColor3 = Theme.Colors.Text,
		TextTransparency = 1,
		Parent = holder,
	})
	Theme.Tween(title, 0.6, { TextTransparency = 0 })
	Theme.Tween(line, 0.8, { Size = UDim2.new(0.6, 0, 0, 2) }, Enum.EasingStyle.Quart)
	Theme.Tween(sub, 0.8, { TextTransparency = 0 })
	task.delay(3.5, function()
		if zoneBanner ~= holder then
			return
		end
		Theme.Tween(title, 0.8, { TextTransparency = 1 })
		Theme.Tween(sub, 0.8, { TextTransparency = 1 })
		local tween = Theme.Tween(line, 0.8, { Size = UDim2.new(0, 0, 0, 2) })
		tween.Completed:Connect(function()
			holder:Destroy()
		end)
	end)
end

function Notifications.Init(c)
	C = c
end

function Notifications.Start()
	local layer = C.UIController.Layers.Overlay
	toastHolder = New("Frame", {
		Name = "Notifiche",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(460, 400),
		BackgroundTransparency = 1,
		Parent = layer,
	})
	C.UIController.AttachScale(toastHolder)
	New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = toastHolder })

	Net.Event("Notify").OnClientEvent:Connect(function(text, kind, duration)
		Notifications.Toast(text, kind, duration)
	end)
	Net.Event("Announce").OnClientEvent:Connect(function(data)
		Notifications.Announce(data.Title, data.Subtitle, data.Kind)
	end)
	Net.Event("LevelUp").OnClientEvent:Connect(function(level, gained)
		local sub = if gained > 1 then ("+%d livelli • +%d punti statistica"):format(gained, gained * 3) else "+3 punti statistica (menu M)"
		Notifications.Announce("LIVELLO " .. Util.FormatNumber(level), sub, "Livello", 2.6)
	end)
end

return Notifications
