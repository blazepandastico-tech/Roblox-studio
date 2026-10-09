--[[
	Tutorial - l'Addestramento di base (vedi Data/Tutorial e il server TutorialService)

	PARTE 1, I COMANDI: una scheda in alto guida un comando alla volta. Ogni passo si completa
	facendo davvero la cosa: il tasto disegnato si illumina quando lo premi, la medaglia verde e il
	suono confermano, poi il passo successivo entra da destra. Tra una sezione e l'altra (Movimento,
	Rampini, Combattimento, Interfaccia) compare il titolo grande della sezione. Gli anelli d'oro
	attorno alla torre insegnano a volare con i rampini.
	PARTE 2, IL MONDO: TutorialTour (mappa dell'arcipelago, interfaccia, giganti) e il finale.

	Mentre è in corso, il pannello degli obiettivi e la colonna di luce seguono il tutorial; il
	calendario dei premi e le scene della storia aspettano che finisca (Tutorial.IsActive).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Lib.Net)
local Util = require(Shared.Lib.Util)
local W = require(Shared.Data.WorldLayout)
local NPCs = require(Shared.Data.NPCs)
local TutorialData = require(Shared.Data.Tutorial)

local Theme = require(script.Parent.Theme)
local New = Theme.New
local Colors = Theme.Colors

local Tutorial = {}
local C
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CARD_W, CARD_H = 600, 244
local KEY_BG = Color3.fromRGB(58, 47, 37)
local GOLD = Color3.fromRGB(255, 210, 110)
local TRACKER_TITLE = "📘 " .. TutorialData.Title

local active = false
local replaying = false
local token = 0 -- cambia a ogni avvio o interruzione: le attese della volta prima si fermano
local ui: any = nil
local current: any = nil -- passo in corso
local rings: { any } = {}
local lastFlash = 0

local towerTop = W.Landmarks.TorreAddestramento
local towerBase = Vector3.new(towerTop.X, W.GroundY, towerTop.Z)

-- DISPOSITIVO E TASTI ------------------------------------------------------------------------------

local function device(): string
	local last = UserInputService:GetLastInputType()
	if string.find(last.Name, "Gamepad") then
		return "Gamepad"
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	end
	return "PC"
end

local PC_INPUTS = {
	Spazio = { Enum.KeyCode.Space },
	Ctrl = { Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl },
	["Clic sinistro"] = { Enum.UserInputType.MouseButton1 },
	Mouse = { Enum.UserInputType.MouseMovement, Enum.UserInputType.MouseButton2 },
}
local PAD_INPUTS = {
	A = { Enum.KeyCode.ButtonA },
	B = { Enum.KeyCode.ButtonB },
	X = { Enum.KeyCode.ButtonX },
	Y = { Enum.KeyCode.ButtonY },
	L1 = { Enum.KeyCode.ButtonL1 },
	R1 = { Enum.KeyCode.ButtonR1 },
	L2 = { Enum.KeyCode.ButtonL2 },
	R2 = { Enum.KeyCode.ButtonR2 },
	Select = { Enum.KeyCode.ButtonSelect },
	["Levetta sinistra"] = { Enum.KeyCode.Thumbstick1 },
	["Levetta destra"] = { Enum.KeyCode.Thumbstick2 },
}

local function inputsFor(dev: string, name: string): { any }
	if dev == "Gamepad" then
		return PAD_INPUTS[name] or {}
	end
	local list = PC_INPUTS[name]
	if list then
		return list
	end
	local ok, code = pcall(function()
		return (Enum.KeyCode :: any)[name]
	end)
	return if ok and code then { code } else {}
end

local function matches(input: InputObject, list: { any }): boolean
	for _, item in list do
		if input.KeyCode == item or input.UserInputType == item then
			return true
		end
	end
	return false
end

local function sound(name: string)
	if C.SoundController then
		C.SoundController.Play(name)
	end
end

local function waitFor(seconds: number, myToken: number): boolean
	local start = os.clock()
	while os.clock() - start < seconds do
		if token ~= myToken then
			return false
		end
		task.wait()
	end
	return token == myToken
end

-- INTERFACCIA ------------------------------------------------------------------------------------

local function label(text: string, props: { [string]: any }): TextLabel
	return Theme.Label(text, props)
end

local function buildUI()
	local root = New("Frame", { Name = "Addestramento", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = C.UIController.Layers.Overlay })

	-- la scheda in alto (sotto la bussola): holder fermo, la scheda scivola dentro
	local holder = New("Frame", { Name = "Posto", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 80), Size = UDim2.fromOffset(CARD_W, CARD_H), BackgroundTransparency = 1, Parent = root })
	C.UIController.AttachScale(holder)
	local card = New("CanvasGroup", { Name = "Scheda", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1, Parent = holder })
	local back = New("Frame", { Name = "Fondo", Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4), BackgroundColor3 = Colors.Panel, BackgroundTransparency = 0.04, Parent = card })
	Theme.Corner(back, 12)
	Theme.Stroke(back, Colors.Gold, 2, 0.15)
	Theme.Gradient(back, Color3.fromRGB(62, 50, 38), Color3.fromRGB(28, 22, 18), 90)

	-- intestazione: sezione, titolo del tutorial, contatore, "salta tutto"
	local chip = New("Frame", { Name = "Sezione", Position = UDim2.fromOffset(16, 14), Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Colors.Gold, Parent = card })
	Theme.Corner(chip, 12)
	New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = chip })
	local chipText = label("", { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Font = Theme.Fonts.Bold, TextSize = 13, TextColor3 = Colors.Background, Parent = chip })
	local header = label(string.upper(TutorialData.Title), { Name = "Titolo", Position = UDim2.fromOffset(200, 14), Size = UDim2.fromOffset(220, 24), Font = Theme.Fonts.UI, TextSize = 12, TextColor3 = Colors.TextDim, Parent = card })
	local counter = label("", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -112, 0, 14), Size = UDim2.fromOffset(70, 24), TextXAlignment = Enum.TextXAlignment.Right, Font = Theme.Fonts.Number, TextSize = 18, TextColor3 = Colors.GoldBright, Parent = card })
	local skipAll = Theme.Button("Salta tutto", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Size = UDim2.fromOffset(90, 26), TextSize = 12, BackgroundColor3 = Colors.PanelLight, Parent = card }, function()
		Tutorial.AskSkip()
	end)

	-- barra dei progressi
	local track = New("Frame", { Position = UDim2.fromOffset(16, 46), Size = UDim2.new(1, -32, 0, 6), BackgroundColor3 = Color3.fromRGB(20, 16, 13), Parent = card })
	Theme.Corner(track, 3)
	local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.GoldBright, Parent = track })
	Theme.Corner(fill, 3)
	Theme.Gradient(fill, Color3.fromRGB(255, 236, 170), Color3.fromRGB(214, 158, 70), 0)

	-- corpo (cambia a ogni passo con una transizione)
	local body = New("CanvasGroup", { Name = "Corpo", Position = UDim2.fromOffset(16, 62), Size = UDim2.new(1, -32, 1, -100), BackgroundTransparency = 1, Parent = card })
	local avatar = New("Frame", { Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(0, 4), BackgroundColor3 = Color3.fromRGB(70, 92, 76), Parent = body })
	Theme.Corner(avatar, 23)
	Theme.Stroke(avatar, Colors.Gold, 2, 0)
	Theme.Gradient(avatar, Color3.fromRGB(96, 130, 104), Color3.fromRGB(40, 60, 48), 90)
	label("M", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Title, TextSize = 28, TextColor3 = Colors.GoldBright, Parent = avatar })
	label(string.upper(NPCs.SpeakerName(TutorialData.Guide)), { Position = UDim2.fromOffset(-8, 52), Size = UDim2.fromOffset(62, 14), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Bold, TextSize = 10, TextColor3 = Colors.Gold, TextScaled = true, Parent = body })
	local title = label("", { Position = UDim2.fromOffset(60, 0), Size = UDim2.new(1, -60, 0, 28), Font = Theme.Fonts.Header, TextSize = 22, TextColor3 = Colors.GoldBright, Parent = body })
	local text = label("", { Position = UDim2.fromOffset(60, 30), Size = UDim2.new(1, -60, 0, 58), Font = Theme.Fonts.Body, TextSize = 14, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Parent = body })
	local keys = New("Frame", { Name = "Tasti", Position = UDim2.fromOffset(60, 92), Size = UDim2.new(1, -60, 0, 32), BackgroundTransparency = 1, Parent = body })
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = keys })
	local stepTrack = New("Frame", { Position = UDim2.fromOffset(60, 130), Size = UDim2.new(1, -60, 0, 4), BackgroundColor3 = Color3.fromRGB(20, 16, 13), Visible = false, Parent = body })
	Theme.Corner(stepTrack, 3)
	local stepFill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.GreenBright, Parent = stepTrack })
	Theme.Corner(stepFill, 3)

	-- piede: consiglio e pulsanti
	local hint = label("", { Position = UDim2.fromOffset(16, CARD_H - 34), Size = UDim2.new(1, -190, 0, 26), Font = Theme.Fonts.UI, TextSize = 12, TextWrapped = true, TextColor3 = Color3.fromRGB(255, 228, 160), TextTransparency = 1, Parent = card })
	local nextButton = Theme.Button("Avanti (Invio) ▶", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, CARD_H - 36), Size = UDim2.fromOffset(150, 28), TextSize = 13, BackgroundColor3 = Colors.Green, Visible = false, Parent = card }, function()
		if current and not current.Done then
			current.Done = true
		end
	end)
	local skipStep = Theme.Button("Salta passo (Invio) ▶▶", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, CARD_H - 36), Size = UDim2.fromOffset(176, 28), TextSize = 12, BackgroundColor3 = Colors.PanelLight, Visible = false, Parent = card }, function()
		if current and not current.Done then
			current.Skipped = true
			current.Done = true
		end
	end)

	-- medaglia del passo fatto, come un timbro sul ritratto di Mira (fuori dalla scheda, così l'anello
	-- che si allarga non viene tagliato)
	local medal = New("Frame", { Name = "Medaglia", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(39, 89), Size = UDim2.fromOffset(60, 60), BackgroundColor3 = Colors.Green, Visible = false, ZIndex = 5, Parent = holder })
	Theme.Corner(medal, 30)
	Theme.Stroke(medal, Colors.GreenBright, 3, 0)
	Theme.Gradient(medal, Color3.fromRGB(120, 210, 130), Color3.fromRGB(40, 110, 60), 90)
	label("✓", { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Bold, TextSize = 36, TextColor3 = Colors.White, ZIndex = 6, Parent = medal })
	local medalScale = New("UIScale", { Parent = medal })
	local burst = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(39, 89), Size = UDim2.fromOffset(60, 60), BackgroundTransparency = 1, ZIndex = 4, Parent = holder })
	Theme.Corner(burst, 999)
	local burstStroke = New("UIStroke", { Color = Colors.GreenBright, Thickness = 3, Transparency = 1, Parent = burst })

	-- titolo grande (inizio, sezioni, parti)
	local banner = New("CanvasGroup", { Name = "Titolone", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.34), Size = UDim2.fromOffset(900, 190), BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, Parent = root })
	C.UIController.AttachScale(banner)
	local bannerTop = label("", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Bold, TextSize = 16, TextColor3 = Colors.Gold, Parent = banner })
	local bannerTitle = label("", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 38), Size = UDim2.new(1, 0, 0, 84), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Title, TextSize = 70, TextColor3 = Colors.GoldBright, TextStrokeColor3 = Color3.fromRGB(40, 18, 8), TextStrokeTransparency = 0.2, Parent = banner })
	Theme.Gradient(bannerTitle, Color3.fromRGB(255, 240, 200), Color3.fromRGB(210, 150, 70), 90)
	local bannerScale = New("UIScale", { Parent = bannerTitle })
	local bannerLine = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 128), Size = UDim2.fromOffset(0, 2), BackgroundColor3 = Colors.Gold, BorderSizePixel = 0, Parent = banner })
	New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = bannerLine })
	local bannerSub = label("", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 138), Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Font = Theme.Fonts.Body, TextSize = 18, TextColor3 = Colors.Text, Parent = banner })

	-- conferma per saltare tutto
	local confirm = Theme.Panel({ Name = "ConfermaAddestramento", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(460, 190), Visible = false, ZIndex = 60, Parent = C.UIController.Layers.Top })
	C.UIController.AttachScale(confirm)
	Theme.Padding(confirm, 16)
	label("Saltare l'addestramento?", { Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Header, TextSize = 22, TextColor3 = Colors.GoldBright, ZIndex = 61, Parent = confirm })
	label("Niente premio dell'addestramento. Potrai rivederlo quando vuoi dal Menu (M) → Opzioni.", { Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 48), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Font = Theme.Fonts.Body, TextSize = 15, ZIndex = 61, Parent = confirm })
	Theme.Button("No, continuo", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, 0), Size = UDim2.new(0.5, -20, 0, 40), BackgroundColor3 = Colors.Green, ZIndex = 61, Parent = confirm }, function()
		Tutorial.CloseSkip()
	end)
	Theme.Button("Sì, salta", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, 0), Size = UDim2.new(0.5, -20, 0, 40), BackgroundColor3 = Colors.Red, ZIndex = 61, Parent = confirm }, function()
		Tutorial.CloseSkip()
		Tutorial.Stop("skip")
	end)

	ui = {
		Root = root,
		Holder = holder,
		Card = card,
		Chip = chip,
		ChipText = chipText,
		Header = header,
		Counter = counter,
		SkipAll = skipAll,
		Fill = fill,
		Body = body,
		Title = title,
		Text = text,
		Keys = keys,
		StepTrack = stepTrack,
		StepFill = stepFill,
		Hint = hint,
		Next = nextButton,
		SkipStep = skipStep,
		Medal = medal,
		MedalScale = medalScale,
		Burst = burst,
		BurstStroke = burstStroke,
		Banner = banner,
		BannerTop = bannerTop,
		BannerTitle = bannerTitle,
		BannerScale = bannerScale,
		BannerLine = bannerLine,
		BannerSub = bannerSub,
		Confirm = confirm,
		Caps = {},
		CardShown = false,
	}
end

-- TASTI DISEGNATI ------------------------------------------------------------------------------------

local function keyCap(name: string, order: number)
	local cap = New("TextLabel", {
		BackgroundColor3 = KEY_BG,
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = Theme.Fonts.Bold,
		TextSize = 15,
		TextColor3 = Colors.GoldBright,
		Text = name,
		LayoutOrder = order,
		Parent = ui.Keys,
	})
	New("UIPadding", { PaddingLeft = UDim.new(0, 11), PaddingRight = UDim.new(0, 11), Parent = cap })
	Theme.Corner(cap, 7)
	Theme.Stroke(cap, Colors.Gold, 1.5, 0.15)
	Theme.Gradient(cap, Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 160, 150), 90)
	local scale = New("UIScale", { Parent = cap })
	table.insert(ui.Caps, { Frame = cap, Scale = scale, Name = name })
end

local function note(text: string, order: number)
	label(text, { Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, Font = Theme.Fonts.UI, TextSize = 12, TextColor3 = Colors.TextDim, LayoutOrder = order, Parent = ui.Keys })
end

local function renderKeys(step)
	for _, child in ui.Keys:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	table.clear(ui.Caps)
	local dev = device()
	local keys = step.Keys or {}
	if dev == "Touch" then
		if keys.Touch then
			note("📱  " .. keys.Touch, 1)
		end
	else
		local list = if dev == "Gamepad" then keys.Gamepad else keys.PC
		for i, name in list or {} do
			keyCap(name, i)
		end
		local extra = step.Note and step.Note[dev]
		if extra then
			note("  " .. extra, 99)
		end
	end
end

-- l'utente ha premuto un tasto della scheda: il tasto si abbassa e si accende
local function pressCap(cap)
	cap.Scale.Scale = 0.84
	Theme.Tween(cap.Scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	cap.Frame.BackgroundColor3 = Colors.GoldBright
	cap.Frame.TextColor3 = Colors.Background
	Theme.Tween(cap.Frame, 0.55, { BackgroundColor3 = KEY_BG, TextColor3 = Colors.GoldBright })
end

local function onInput(input: InputObject)
	if not current or #ui.Caps == 0 then
		return
	end
	local dev = device()
	local now = os.clock()
	for _, cap in ui.Caps do
		if matches(input, inputsFor(dev, cap.Name)) then
			-- movimenti continui (mouse, levette): un lampo ogni tanto, non a ogni fotogramma
			local continuous = input.UserInputType == Enum.UserInputType.MouseMovement or input.KeyCode == Enum.KeyCode.Thumbstick1 or input.KeyCode == Enum.KeyCode.Thumbstick2
			if not continuous or now - lastFlash > 0.45 then
				lastFlash = now
				pressCap(cap)
			end
		end
	end
end

-- SCHEDA: ENTRATA, CAMBIO PASSO, USCITA ------------------------------------------------------------------

local function setProgress(done: number)
	local total = #TutorialData.Steps
	ui.Counter.Text = ("%d / %d"):format(math.min(done + 1, total), total)
	Theme.Tween(ui.Fill, 0.6, { Size = UDim2.fromScale(math.clamp(done / total, 0, 1), 1) }, Enum.EasingStyle.Quint)
end

local function showCard()
	ui.CardShown = true
	ui.Card.Position = UDim2.fromOffset(0, -34)
	Theme.Tween(ui.Card, 0.5, { Position = UDim2.fromOffset(0, 0), GroupTransparency = 0 }, Enum.EasingStyle.Quint)
	sound("UI")
end

local function hideCard()
	if not ui.CardShown then
		return
	end
	ui.CardShown = false
	Theme.Tween(ui.Card, 0.32, { Position = UDim2.fromOffset(0, -34), GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end

-- titolo grande al centro dello schermo (attende la fine)
function Tutorial.Banner(top: string, title: string, subtitle: string, hold: number, myToken: number): boolean
	ui.Banner.Visible = true
	ui.BannerTop.Text = top
	ui.BannerTitle.Text = title
	ui.BannerSub.Text = subtitle
	ui.Banner.GroupTransparency = 1
	ui.BannerScale.Scale = 1.3
	ui.BannerLine.Size = UDim2.fromOffset(0, 2)
	Theme.Tween(ui.Banner, 0.45, { GroupTransparency = 0 }, Enum.EasingStyle.Sine)
	Theme.Tween(ui.BannerScale, 0.9, { Scale = 1 }, Enum.EasingStyle.Quint)
	Theme.Tween(ui.BannerLine, 0.9, { Size = UDim2.fromOffset(560, 2) }, Enum.EasingStyle.Quint)
	sound("Reward")
	local ok = waitFor(0.9 + hold, myToken)
	Theme.Tween(ui.Banner, 0.45, { GroupTransparency = 1 }, Enum.EasingStyle.Sine)
	Theme.Tween(ui.BannerScale, 0.45, { Scale = 0.94 }, Enum.EasingStyle.Sine)
	ok = waitFor(0.45, myToken) and ok
	ui.Banner.Visible = false
	return ok
end

-- dove punta la colonna di luce per questo passo
local function targetFor(step): Vector3?
	if step.Goal.Kind == "Rings" then
		for _, r in rings do
			if r.State == "Active" then
				return r.Center
			end
		end
		return nil
	end
	return step.Target
end

local function updateTracker()
	if not current or not C.HUD or not C.HUD.SetTutorial then
		return
	end
	local step = current.Step
	local objective = step.Title
	if step.Goal.Kind == "Rings" then
		objective = ("%s (%d/%d)"):format(step.Title, current.Amount, #TutorialData.Rings)
	end
	C.HUD.SetTutorial({ Title = TRACKER_TITLE, Objective = objective, Target = targetFor(step) })
end

local function fillContent(step, index: number)
	local section = TutorialData.Sections[step.Section]
	ui.ChipText.Text = ("%s  %s"):format(section.Icon, string.upper(section.Name))
	ui.Title.Text = step.Title
	ui.Title.TextColor3 = Colors.GoldBright
	ui.Text.Text = step.Text
	ui.Hint.Text = "💡 " .. (step.Hint or "")
	ui.Hint.TextTransparency = 1
	ui.StepFill.Size = UDim2.fromScale(0, 1)
	renderKeys(step)
	setProgress(index - 1)
end

-- il passo nuovo entra da destra mentre il vecchio esce a sinistra
local function transitionTo(step, index: number, fresh: boolean)
	if fresh or not ui.CardShown then
		fillContent(step, index)
		ui.Body.Position = UDim2.fromOffset(16, 62)
		ui.Body.GroupTransparency = 0
		showCard()
		return
	end
	Theme.Tween(ui.Body, 0.2, { Position = UDim2.fromOffset(-14, 62), GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(0.2)
	fillContent(step, index)
	ui.Body.Position = UDim2.fromOffset(56, 62)
	Theme.Tween(ui.Body, 0.42, { Position = UDim2.fromOffset(16, 62), GroupTransparency = 0 }, Enum.EasingStyle.Quint)
	sound("UI")
end

-- la medaglia verde del passo fatto
local function celebrate(skipped: boolean)
	ui.Next.Visible = false
	ui.SkipStep.Visible = false
	ui.StepTrack.Visible = false
	if skipped then
		Theme.Tween(ui.Title, 0.25, { TextColor3 = Colors.TextDim })
		return
	end
	ui.Medal.Visible = true
	ui.MedalScale.Scale = 0.2
	ui.Medal.Rotation = -30
	Theme.Tween(ui.MedalScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	Theme.Tween(ui.Medal, 0.45, { Rotation = 0 }, Enum.EasingStyle.Back)
	ui.Burst.Size = UDim2.fromOffset(60, 60)
	ui.BurstStroke.Transparency = 0
	Theme.Tween(ui.Burst, 0.65, { Size = UDim2.fromOffset(150, 150) }, Enum.EasingStyle.Quint)
	Theme.Tween(ui.BurstStroke, 0.65, { Transparency = 1 }, Enum.EasingStyle.Quad)
	Theme.Tween(ui.Title, 0.25, { TextColor3 = Colors.GreenBright })
	sound("Reward")
	if C.CameraController then
		C.CameraController.Shake(0.05, 0.15)
	end
end

local function hideMedal()
	if ui.Medal.Visible then
		local t = Theme.Tween(ui.MedalScale, 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		t.Completed:Connect(function()
			ui.Medal.Visible = false
		end)
	end
end

-- ANELLI D'ORO ----------------------------------------------------------------------------------------

local RING_SEGMENTS = 22

local function effectsFolder(): Instance
	return workspace:FindFirstChild("EffettiLocali") or workspace
end

local function newRing(center: Vector3, index: number)
	local model = Instance.new("Model")
	model.Name = "AnelloAddestramento"
	local parts = {}
	for _ = 1, RING_SEGMENTS do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = GOLD
		p.Size = Vector3.new(1, 1, 3)
		p.Parent = model
		table.insert(parts, p)
	end
	local core = Instance.new("Part")
	core.Name = "Centro"
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.Transparency = 1
	core.Size = Vector3.one
	core.CFrame = CFrame.new(center)
	core.Parent = model
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 30
	light.Brightness = 1.5
	light.Parent = core
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(GOLD)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Lifetime = NumberRange.new(0.8, 1.4)
	sparkle.Speed = NumberRange.new(2, 5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Rate = 12
	sparkle.Parent = core
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(70, 34)
	board.StudsOffset = Vector3.new(0, TutorialData.RingRadius + 4, 0)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.Parent = core
	local number = Instance.new("TextLabel")
	number.BackgroundTransparency = 1
	number.Size = UDim2.fromScale(1, 1)
	number.Font = Enum.Font.GothamBold
	number.TextSize = 22
	number.TextColor3 = GOLD
	number.TextStrokeTransparency = 0.3
	number.Text = ("%d/%d"):format(index, #TutorialData.Rings)
	number.Parent = board
	model.Parent = effectsFolder()
	-- gli anelli girano attorno alla torre: si attraversano volando in tondo
	local around = Util.SafeUnit(Util.Flat(center - towerBase), Vector3.xAxis)
	return {
		Model = model,
		Parts = parts,
		Core = core,
		Light = light,
		Sparkle = sparkle,
		Board = board,
		Center = center,
		Normal = around:Cross(Vector3.yAxis),
		Index = index,
		State = "Waiting",
		Grow = 1,
		Fade = 0,
	}
end

local function placeRing(r, now: number)
	local active_ = r.State == "Active"
	local pulse = if active_ then 1 + 0.05 * math.sin(now * 4) else 0.8
	local radius = TutorialData.RingRadius * pulse * r.Grow
	local frame = CFrame.lookAt(r.Center, r.Center + r.Normal)
	local spin = now * (if active_ then 0.7 else 0.25) + r.Index
	local n = #r.Parts
	local length = 2 * math.pi * radius / n * 1.1
	local thick = if active_ then 1.3 else 0.8
	for i, p in r.Parts do
		local a = spin + (i - 1) / n * math.pi * 2
		local pos = frame * Vector3.new(math.cos(a) * radius, math.sin(a) * radius, 0)
		local tangent = frame:VectorToWorldSpace(Vector3.new(-math.sin(a), math.cos(a), 0))
		p.CFrame = CFrame.lookAt(pos, pos + tangent)
		p.Size = Vector3.new(thick, thick, length)
		p.Transparency = if active_ then r.Fade else math.max(0.55, r.Fade)
	end
	r.Light.Enabled = active_
	r.Sparkle.Enabled = active_
	r.Board.Enabled = active_
end

local function clearRings()
	for _, r in rings do
		if r.Model.Parent then
			r.Model:Destroy()
		end
	end
	table.clear(rings)
end

local function buildRings()
	clearRings()
	for i, center in TutorialData.Rings do
		table.insert(rings, newRing(center, i))
	end
	rings[1].State = "Active"
end

-- anello attraversato: si allarga, si dissolve, scintille e il successivo si accende
local function collectRing(r)
	r.State = "Done"
	local start = os.clock()
	task.spawn(function()
		while r.Model.Parent do
			local k = math.clamp((os.clock() - start) / 0.55, 0, 1)
			r.Grow = 1 + Util.Ease(k, "ExpoOut") * 0.8
			r.Fade = k
			placeRing(r, os.clock())
			if k >= 1 then
				r.Model:Destroy()
				break
			end
			RunService.RenderStepped:Wait()
		end
	end)
	if C.EffectsController then
		C.EffectsController.Sparks(r.Center, GOLD, 40, 60)
	end
	sound("Coins")
	current.Amount += 1
	local nextRing = rings[r.Index + 1]
	if nextRing then
		nextRing.State = "Active"
	else
		current.Done = true
	end
	updateTracker()
end

-- CONTROLLO DEI PASSI ----------------------------------------------------------------------------------

local function stepProgress(k: number)
	ui.StepTrack.Visible = true
	ui.StepFill.Size = UDim2.fromScale(math.clamp(k, 0, 1), 1)
end

local function check(dt: number)
	local cur = current
	if not cur or cur.Done or cur.Info then
		return
	end
	local goal = cur.Step.Goal
	local character = player.Character
	local root = Util.GetRoot(character)
	local kind = goal.Kind
	if kind == "Look" then
		local look = camera.CFrame.LookVector
		if Vector3.new(look.X, 0, look.Z).Magnitude > 0.05 then
			local angle = math.deg(math.atan2(look.X, look.Z))
			if cur.LastAngle then
				cur.Amount += math.abs((angle - cur.LastAngle + 540) % 360 - 180)
			end
			cur.LastAngle = angle
		end
		stepProgress(cur.Amount / goal.Amount)
		if cur.Amount >= goal.Amount then
			cur.Done = true
		end
	elseif kind == "Walk" then
		if root then
			local pos = root.Position
			if cur.LastPos then
				local d = Util.FlatDistance(pos, cur.LastPos)
				local flying = C.ODMController and C.ODMController.IsFlying()
				if not flying and d < 6 then
					cur.Amount += d
				end
			end
			cur.LastPos = pos
		end
		stepProgress(cur.Amount / goal.Amount)
		if cur.Amount >= goal.Amount then
			cur.Done = true
		end
	elseif kind == "Hook" then
		local hooks = C.ODMController and C.ODMController.HookStates() or {}
		for _, h in hooks do
			if h.Phase == "Attached" then
				cur.Done = true
				break
			end
		end
	elseif kind == "Boost" then
		if C.ODMController and C.ODMController.IsFlying() and C.InputController.IsHeld("Boost") then
			cur.Amount += dt
		end
		stepProgress(cur.Amount / goal.Amount)
		if cur.Amount >= goal.Amount then
			cur.Done = true
		end
	elseif kind == "Rings" then
		if root then
			for _, r in rings do
				if r.State == "Active" and (root.Position - r.Center).Magnitude <= TutorialData.RingRadius + 3 then
					collectRing(r)
					break
				end
			end
		end
		stepProgress(cur.Amount / #TutorialData.Rings)
	elseif kind == "Panel" then
		if C.UIController.IsOpen(goal.Panel) then
			cur.Opened = true
		elseif cur.Opened then
			cur.Done = true
		end
	end
end

local function onAction(action: string)
	local cur = current
	if not cur or cur.Done or cur.Info or cur.Step.Goal.Kind ~= "Action" or cur.Step.Goal.Action ~= action then
		return
	end
	cur.Amount += 1
	local count = cur.Step.Goal.Count or 1
	if count > 1 then
		stepProgress(cur.Amount / count)
	end
	if cur.Amount >= count then
		cur.Done = true
	end
end

local function onEvent(kind: string)
	local cur = current
	if cur and not cur.Done and not cur.Info and cur.Step.Goal.Kind == kind then
		cur.Done = true
	end
end

-- un passo: scheda, attesa (con consiglio e "salta passo" se ci metti molto), medaglia
local function runStep(index: number, fresh: boolean, myToken: number): boolean
	local step = TutorialData.Steps[index]
	local dev = device()
	local hasKeys = if dev == "Touch" then step.Keys.Touch ~= nil elseif dev == "Gamepad" then step.Keys.Gamepad ~= nil else step.Keys.PC ~= nil
	current = { Step = step, Index = index, Done = false, Amount = 0, Started = os.clock(), Info = not hasKeys }
	if step.Goal.Kind == "Rings" then
		buildRings()
	end
	transitionTo(step, index, fresh)
	updateTracker()
	if current.Info then
		-- su questo dispositivo il comando non c'è: solo la spiegazione
		ui.Next.Visible = true
	end
	local hintShown = false
	while token == myToken and not current.Done do
		local elapsed = os.clock() - current.Started
		if not hintShown and step.Hint and elapsed > (step.HintAfter or 15) then
			hintShown = true
			Theme.Tween(ui.Hint, 0.6, { TextTransparency = 0 })
		end
		if not current.Info and not ui.SkipStep.Visible and elapsed > (step.SkipAfter or 40) then
			ui.SkipStep.Visible = true
		end
		task.wait()
	end
	if token ~= myToken then
		return false
	end
	celebrate(current.Skipped == true)
	clearRings()
	local ok = waitFor(if current.Skipped then 0.3 else 1.0, myToken)
	hideMedal()
	return ok
end

local function runSteps(from: number, myToken: number): boolean
	local lastSection = nil
	for i = from, #TutorialData.Steps do
		local step = TutorialData.Steps[i]
		local fresh = false
		if step.Section ~= lastSection then
			-- nuova sezione: la scheda sale, il titolo grande della sezione, la scheda torna
			if lastSection ~= nil or i > 1 then
				hideCard()
				local section = TutorialData.Sections[step.Section]
				if not Tutorial.Banner(("PARTE 1  •  SEZIONE %d DI %d"):format(step.Section, #TutorialData.Sections), section.Icon .. "  " .. string.upper(section.Name), "", 0.7, myToken) then
					return false
				end
			end
			lastSection = step.Section
			fresh = true
		end
		if not runStep(i, fresh, myToken) then
			return false
		end
		Net.Event("TutorialProgress"):FireServer(i + 1)
	end
	setProgress(#TutorialData.Steps)
	hideCard()
	current = nil
	return true
end

-- AVVIO E FINE --------------------------------------------------------------------------------------

local function cleanup()
	current = nil
	clearRings()
	if ui then
		hideCard()
		ui.Banner.Visible = false
		ui.Confirm.Visible = false
		ui.Medal.Visible = false
		task.delay(0.4, function()
			if not active then
				ui.Root.Visible = false
			end
		end)
	end
	if C.HUD and C.HUD.SetTutorial then
		C.HUD.SetTutorial(nil)
	end
	C.UIController.RequestCursor("tutorial", false)
end

function Tutorial.IsActive(): boolean
	return active
end

-- il passo in corso (Id), nil fuori dalla prima parte
function Tutorial.CurrentStep(): string?
	return if current then current.Step.Id else nil
end

-- Interrompe il tutorial ("skip" = saltato dal giocatore)
function Tutorial.Stop(how: string)
	if not active then
		return
	end
	token += 1
	active = false
	if C.TutorialTour then
		C.TutorialTour.Cancel()
	end
	cleanup()
	Net.Event("TutorialDone"):FireServer(how)
end

function Tutorial.AskSkip()
	if not active then
		return
	end
	ui.Confirm.Visible = true
	C.UIController.RequestCursor("tutorialSkip", true)
end

function Tutorial.CloseSkip()
	ui.Confirm.Visible = false
	C.UIController.RequestCursor("tutorialSkip", false)
end

-- Rivedi il tutorial (dal menu)
function Tutorial.Replay()
	if not active then
		Net.Event("TutorialReplay"):FireServer()
	end
end

local function begin(info)
	if active or type(info) ~= "table" then
		return
	end
	active = true
	replaying = info.Replay == true
	token += 1
	local myToken = token
	task.spawn(function()
		-- aspetta che finiscano schermata iniziale, filmati ed eventuali dialoghi
		while (C.Intro and C.Intro.IsShowing()) or (C.CutsceneController and C.CutsceneController.IsPlaying()) or (C.AbuseEventController and C.AbuseEventController.IsCinematic()) or (C.Dialogue and C.Dialogue.IsOpen()) do
			task.wait(0.3)
		end
		C.ClientData.WaitReady()
		if not waitFor(1, myToken) then
			return
		end
		ui.Root.Visible = true
		local from = math.clamp(math.floor(tonumber(info.Step) or 1), 1, #TutorialData.Steps + 1)
		local subtitle = if from == 1 then "Comandi, isole, missioni e giganti: tutto quello che serve a una recluta." elseif from <= #TutorialData.Steps then "Riprendiamo da dove eravamo rimasti." else "Manca l'ultima parte: come funziona il mondo."
		if not Tutorial.Banner(if replaying then "RIPASSO" else "MISSIONE 0", string.upper(TutorialData.Title), subtitle, 1.4, myToken) then
			return
		end
		local ok = true
		if from <= #TutorialData.Steps then
			ok = runSteps(from, myToken)
		end
		-- parte 2: il mondo (mappa, interfaccia, giganti) e il finale con il premio
		if ok and C.TutorialTour then
			ok = C.TutorialTour.Run(myToken, replaying)
		end
		if not ok or token ~= myToken then
			return
		end
		-- fatto: la storia riparte (Brehm) mentre la telecamera vola da lui; il tutorial resta
		-- "attivo" fino alla fine del volo, così calendario e scene non partono in mezzo
		cleanup()
		Net.Event("TutorialDone"):FireServer("complete")
		if C.TutorialTour then
			C.TutorialTour.AfterDone(replaying)
		end
		active = false
		ui.Root.Visible = false
	end)
end

function Tutorial.Init(c)
	C = c
end

function Tutorial.Start()
	buildUI()
	Net.Event("Tutorial").OnClientEvent:Connect(begin)
	-- azioni da provare
	for _, action in { "Dodge", "Attack", "SkillZ", "Reload" } do
		C.InputController.On(action, function(began)
			if began then
				onAction(action)
			end
		end)
	end
	Net.Event("HitConfirm").OnClientEvent:Connect(function(data)
		if type(data) == "table" and data.Kind == "NapeKill" then
			onEvent("NapeKill")
		end
	end)
	Net.Event("Refilled").OnClientEvent:Connect(function()
		onEvent("Refill")
	end)
	-- il salto: lo stato "Jumping" del personaggio
	local function watchCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			humanoid.StateChanged:Connect(function(_, new)
				if new == Enum.HumanoidStateType.Jumping then
					onEvent("Jump")
				end
			end)
		end
	end
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
	-- i tasti della scheda si accendono quando li premi
	UserInputService.InputBegan:Connect(function(input, processed)
		if not active then
			return
		end
		onInput(input)
		-- Invio = "Avanti" o "Salta passo" (anche con il mouse bloccato dallo shift lock); non mentre si scrive in chat
		if not processed and (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter) and current and not current.Done then
			if ui.Next.Visible then
				current.Done = true
			elseif ui.SkipStep.Visible then
				current.Skipped = true
				current.Done = true
			end
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if active then
			onInput(input)
		end
	end)
	-- se cambia il dispositivo (tastiera ↔ controller) cambiano i tasti disegnati
	UserInputService.LastInputTypeChanged:Connect(function()
		if active and current then
			renderKeys(current.Step)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		if not active then
			return
		end
		-- la scheda sta sotto la bussola (che si ingrandisce con lo schermo)
		ui.Holder.Position = UDim2.new(0.5, 0, 0, math.floor(14 + 66 * C.UIController.Scale))
		if #rings > 0 then
			local now = os.clock()
			for _, r in rings do
				if r.State ~= "Done" then
					placeRing(r, now)
				end
			end
		end
		local ok, err = pcall(check, dt)
		if not ok then
			warn("[Addestramento] " .. tostring(err))
		end
	end)
end

return Tutorial
