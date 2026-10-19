--[[
	TutorialTour - la seconda parte dell'Addestramento di base: come funziona il mondo
	  1. L'ARCIPELAGO: una mappa animata a tutto schermo vola da un'isola all'altra (stagione,
	     livello consigliato, zone principali), poi il mare aperto e i modi per viaggiare.
	  2. L'INTERFACCIA: un riflettore scivola da un elemento del HUD all'altro e lo spiega.
	  3. I GIGANTI: la scena "TutorialGiganti" (CutsceneController) raccontata da Mira.
	  4. IL FINALE: cosa ti aspetta, il premio, poi (TutorialTour.AfterDone) la telecamera vola
	     fino all'Istruttore Brehm, la prossima missione, e torna dolcemente al personaggio.
	Ogni pagina va avanti da sola (la barretta mostra quanto manca) o con "Avanti".
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared.Lib.Util)
local W = require(Shared.Data.WorldLayout)
local Zones = require(Shared.Data.Zones)
local NPCs = require(Shared.Data.NPCs)
local Items = require(Shared.Data.Items)
local Tutorial = require(Shared.Data.Tutorial)

local Theme = require(script.Parent.Theme)
local New = Theme.New
local Colors = Theme.Colors

local TutorialTour = {}
local C
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local GOLD = Color3.fromRGB(255, 210, 110)
local PAGE_TIME = 8 -- secondi di ogni pagina se non premi "Avanti"

local cancelled = false
local ui: any = nil
local map: any = nil -- la tela della mappa (creata la prima volta)
local mapView = { Center = Vector3.zero, Scale = 0.05 }
local mapFrom = { Center = Vector3.zero, Scale = 0.05 }
local mapTo = { Center = Vector3.zero, Scale = 0.05 }
local mapMove = { Start = 0, Duration = 0 }
local highlights: { { Frame: Frame, Stroke: UIStroke, Phase: number } } = {}
-- rettangoli dello schermo: { X0, Y0, X1, Y1 } in pixel
type Box = { X0: number, Y0: number, X1: number, Y1: number }
local function box(x0: number, y0: number, x1: number, y1: number): Box
	return { X0 = x0, Y0 = y0, X1 = x1, Y1 = y1 }
end
local spot = { From = box(0, 0, 0, 0), To = box(0, 0, 0, 0), Start = 0, Duration = 0.01, On = false }
local orbit: { Center: Vector3, Angle: number }? = nil
local advance = false

local function alive(): boolean
	return not cancelled and C.Tutorial ~= nil and C.Tutorial.IsActive()
end

local function waitFor(seconds: number): boolean
	local start = os.clock()
	while os.clock() - start < seconds do
		if not alive() then
			return false
		end
		task.wait()
	end
	return alive()
end

-- aspetta la fine della pagina: tempo scaduto o "Avanti" (anche con Invio)
local function waitPage(seconds: number, timer: Frame?): boolean
	advance = false
	if timer then
		timer.Size = UDim2.fromScale(0, 1)
		Theme.Tween(timer, seconds, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Linear)
	end
	local start = os.clock()
	while os.clock() - start < seconds and not advance do
		if not alive() then
			return false
		end
		task.wait()
	end
	return alive()
end

local function sound(name: string)
	if C.SoundController then
		C.SoundController.Play(name)
	end
end

local function pill(parent: Instance, text: string, color: Color3, order: number): TextLabel
	local chip = Theme.Label(text, {
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
		Font = Theme.Fonts.Bold,
		TextSize = 13,
		TextColor3 = Colors.Background,
		LayoutOrder = order,
		Parent = parent,
	})
	New("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = chip })
	Theme.Corner(chip, 12)
	return chip
end

-- scheda con titolo, testo, barretta del tempo e "Avanti" (mappa e riflettore)
local function infoCard(parent: Instance, name: string, size: Vector2): any
	local card = New("CanvasGroup", { Name = name, Size = UDim2.fromOffset(size.X, size.Y), BackgroundTransparency = 1, GroupTransparency = 1, Parent = parent })
	C.UIController.AttachScale(card)
	local back = New("Frame", { Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4), BackgroundColor3 = Colors.Panel, BackgroundTransparency = 0.05, Parent = card })
	Theme.Corner(back, 12)
	Theme.Stroke(back, Colors.Gold, 2, 0.15)
	Theme.Gradient(back, Color3.fromRGB(62, 50, 38), Color3.fromRGB(26, 20, 16), 90)
	local top = Theme.Label("", { Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -36, 0, 16), Font = Theme.Fonts.Bold, TextSize = 12, TextColor3 = Colors.Gold, Parent = card })
	local title = Theme.Label("", { Position = UDim2.fromOffset(18, 28), Size = UDim2.new(1, -36, 0, 36), Font = Theme.Fonts.Title, TextSize = 32, TextColor3 = Colors.GoldBright, TextScaled = true, Parent = card })
	local chips = New("Frame", { Position = UDim2.fromOffset(18, 68), Size = UDim2.new(1, -36, 0, 24), BackgroundTransparency = 1, Parent = card })
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = chips })
	local text = Theme.Label("", { Position = UDim2.fromOffset(18, 100), Size = UDim2.new(1, -36, 1, -150), Font = Theme.Fonts.Body, TextSize = 15, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
	local track = New("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -46), Size = UDim2.new(1, -36, 0, 3), BackgroundColor3 = Color3.fromRGB(20, 16, 13), Parent = card })
	local timer = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.Gold, Parent = track })
	local counter = Theme.Label("", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -12), Size = UDim2.fromOffset(120, 26), Font = Theme.Fonts.Number, TextSize = 16, TextColor3 = Colors.TextDim, Parent = card })
	Theme.Button("Avanti ▶", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -12), Size = UDim2.fromOffset(120, 30), TextSize = 14, BackgroundColor3 = Colors.Green, Parent = card }, function()
		advance = true
	end)
	return { Card = card, Top = top, Title = title, Chips = chips, Text = text, Timer = timer, Counter = counter }
end

local function setChips(card, list: { { string } })
	for _, child in card.Chips:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for i, entry in list do
		pill(card.Chips, entry[1], if entry[2] == "green" then Colors.GreenBright elseif entry[2] == "blue" then Colors.XP else Colors.Gold, i)
	end
end

-- la scheda cambia contenuto: esce verso il basso, rientra dall'alto
local function swapCard(card, fill: () -> ())
	local base = card.Card.Position
	if card.Card.GroupTransparency < 0.99 then
		Theme.Tween(card.Card, 0.2, { GroupTransparency = 1, Position = base + UDim2.fromOffset(0, 14) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.2)
	end
	fill()
	card.Card.Position = base - UDim2.fromOffset(0, 16)
	Theme.Tween(card.Card, 0.45, { GroupTransparency = 0, Position = base }, Enum.EasingStyle.Quint)
end

-- INTERFACCIA ----------------------------------------------------------------------------------------

local function buildUI()
	local layer = C.UIController.Layers.Top
	-- 1. mappa a tutto schermo
	local mapRoot = New("CanvasGroup", { Name = "TourMappa", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 34, 52), GroupTransparency = 1, Visible = false, ZIndex = 5, Parent = layer })
	local holder = New("Frame", { Name = "Vista", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(24, 62, 92), ClipsDescendants = true, Parent = mapRoot })
	local vignette = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Colors.Black, ZIndex = 20, Parent = mapRoot })
	New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.2, 1), NumberSequenceKeypoint.new(0.8, 1), NumberSequenceKeypoint.new(1, 0.35) }), Parent = vignette })
	local heading = Theme.Label("L'ARCIPELAGO DEI GIGANTI", { Position = UDim2.fromOffset(32, 22), Size = UDim2.fromOffset(700, 44), Font = Theme.Fonts.Title, TextSize = 38, TextColor3 = Colors.GoldBright, TextStrokeTransparency = 0.3, ZIndex = 21, Parent = mapRoot })
	C.UIController.AttachScale(heading)
	local mapCard = infoCard(mapRoot, "Scheda", Vector2.new(400, 330))
	mapCard.Card.AnchorPoint = Vector2.new(1, 0.5)
	mapCard.Card.Position = UDim2.new(1, -36, 0.55, 0)
	mapCard.Card.ZIndex = 22
	local skipMap = Theme.Button("Salta tutto", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 22), Size = UDim2.fromOffset(100, 30), TextSize = 12, BackgroundColor3 = Colors.PanelLight, ZIndex = 22, Parent = mapRoot }, function()
		C.Tutorial.AskSkip()
	end)
	C.UIController.AttachScale(skipMap)

	-- 2. riflettore sul HUD: quattro pannelli scuri attorno al "buco" e il contorno d'oro
	local spotRoot = New("Frame", { Name = "Riflettore", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 5, Parent = layer })
	local dims = {}
	for i = 1, 4 do
		dims[i] = New("Frame", { BackgroundColor3 = Colors.Black, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5, Parent = spotRoot })
	end
	local outline = New("Frame", { BackgroundTransparency = 1, ZIndex = 6, Parent = spotRoot })
	Theme.Corner(outline, 10)
	local outlineStroke = New("UIStroke", { Color = GOLD, Thickness = 3, Transparency = 1, Parent = outline })
	local spotCard = infoCard(spotRoot, "Fumetto", Vector2.new(380, 250))
	spotCard.Card.ZIndex = 8
	local arrow = Theme.Label("◀", { Size = UDim2.fromOffset(30, 30), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Bold, TextSize = 28, TextColor3 = GOLD, TextTransparency = 1, ZIndex = 9, Parent = spotRoot })

	-- 3. finale
	local final = New("CanvasGroup", { Name = "Finale", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Colors.Black, BackgroundTransparency = 0.35, GroupTransparency = 1, Visible = false, ZIndex = 5, Parent = layer })
	local column = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1000, 600), BackgroundTransparency = 1, Parent = final })
	C.UIController.AttachScale(column)
	local finalTop = Theme.Label("MISSIONE 0 SUPERATA", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Bold, TextSize = 18, TextColor3 = Colors.Gold, Parent = column })
	local finalTitle = Theme.Label("ADDESTRAMENTO COMPLETATO", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 48), Size = UDim2.new(1, 0, 0, 80), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Title, TextSize = 64, TextColor3 = Colors.GoldBright, TextStrokeColor3 = Color3.fromRGB(40, 18, 8), TextStrokeTransparency = 0.2, Parent = column })
	Theme.Gradient(finalTitle, Color3.fromRGB(255, 240, 200), Color3.fromRGB(210, 150, 70), 90)
	local finalScale = New("UIScale", { Parent = finalTitle })
	local finalLine = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 134), Size = UDim2.fromOffset(0, 2), BackgroundColor3 = Colors.Gold, BorderSizePixel = 0, Parent = column })
	New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = finalLine })
	Theme.Label("COSA TI ASPETTA", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 152), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Bold, TextSize = 15, TextColor3 = Colors.TextDim, Parent = column })
	local cards = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 182), Size = UDim2.fromOffset(4 * 230 + 3 * 14, 190), BackgroundTransparency = 1, Parent = column })
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14), Parent = cards })
	local outro = {}
	for i, entry in Tutorial.Outro do
		local slot = New("Frame", { Size = UDim2.fromOffset(230, 190), BackgroundTransparency = 1, LayoutOrder = i, Parent = cards })
		local box = Theme.Panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Parent = slot })
		Theme.Padding(box, 12)
		Theme.Label(entry.Icon, { Size = UDim2.new(1, 0, 0, 44), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 36, Font = Theme.Fonts.Bold, Parent = box })
		Theme.Label(entry.Title, { Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Header, TextSize = 18, TextColor3 = Colors.GoldBright, Parent = box })
		Theme.Label(entry.Text, { Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 1, -76), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Font = Theme.Fonts.Body, TextSize = 13, Parent = box })
		local scale = New("UIScale", { Scale = 0, Parent = box })
		table.insert(outro, scale)
	end
	local rewards = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 398), Size = UDim2.fromOffset(700, 40), BackgroundTransparency = 1, Parent = column })
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = rewards })
	local continue = Theme.Button("Continua ▶", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 470), Size = UDim2.fromOffset(240, 52), Font = Theme.Fonts.Title, TextSize = 28, TextColor3 = Colors.GoldBright, BackgroundColor3 = Color3.fromRGB(70, 40, 26), Parent = column }, function()
		advance = true
	end)
	local continueScale = New("UIScale", { Scale = 0, Parent = continue })

	-- didascalia "prossima missione" (in basso, mentre la telecamera vola da Brehm)
	local caption = New("CanvasGroup", { Name = "ProssimaMissione", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -120), Size = UDim2.fromOffset(620, 96), BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, ZIndex = 5, Parent = layer })
	C.UIController.AttachScale(caption)
	local capBack = New("Frame", { Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4), BackgroundColor3 = Colors.Panel, BackgroundTransparency = 0.08, Parent = caption })
	Theme.Corner(capBack, 12)
	Theme.Stroke(capBack, Colors.Gold, 2, 0.15)
	Theme.Label("PROSSIMA MISSIONE", { Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -40, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Bold, TextSize = 13, TextColor3 = Colors.Gold, Parent = caption })
	local capText = Theme.Label("", { Position = UDim2.fromOffset(20, 34), Size = UDim2.new(1, -40, 0, 46), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Title, TextSize = 34, TextColor3 = Colors.GoldBright, Parent = caption })

	-- nero per le dissolvenze
	local black = New("Frame", { Name = "Nero", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Colors.Black, BackgroundTransparency = 1, Visible = false, ZIndex = 50, Parent = layer })

	ui = {
		Black = black,
		MapRoot = mapRoot,
		MapHolder = holder,
		MapCard = mapCard,
		SpotRoot = spotRoot,
		Dims = dims,
		Outline = outline,
		OutlineStroke = outlineStroke,
		SpotCard = spotCard,
		Arrow = arrow,
		Final = final,
		FinalTop = finalTop,
		FinalTitle = finalTitle,
		FinalScale = finalScale,
		FinalLine = finalLine,
		Outro = outro,
		Rewards = rewards,
		ContinueScale = continueScale,
		Caption = caption,
		CaptionText = capText,
	}
end

-- 1. L'ARCIPELAGO ----------------------------------------------------------------------------------------

local function moveMap(center: Vector3, scale: number, duration: number)
	mapFrom = { Center = mapView.Center, Scale = mapView.Scale }
	mapTo = { Center = center, Scale = scale }
	mapMove = { Start = os.clock(), Duration = math.max(duration, 0.01) }
end

local function updateMap()
	if not map then
		return
	end
	local k = Util.Ease((os.clock() - mapMove.Start) / mapMove.Duration, "SineInOut")
	-- la scala cambia in modo "logaritmico": lo zoom sembra uniforme
	local s = math.exp(math.log(mapFrom.Scale) + (math.log(mapTo.Scale) - math.log(mapFrom.Scale)) * k)
	mapView = { Center = mapFrom.Center:Lerp(mapTo.Center, k), Scale = s }
	map.SetScale(s)
	map.CenterOn(mapView.Center)
	local details, icons = s >= 0.11, s >= 0.16
	for _, d in map.Details do
		d.Visible = details
	end
	for _, d in map.Icons do
		d.Visible = icons
	end
	local now = os.clock()
	for _, h in highlights do
		local pulse = 0.5 + 0.5 * math.sin(now * 4 + h.Phase)
		h.Stroke.Transparency = 0.05 + pulse * 0.45
		h.Stroke.Thickness = 3 + pulse * 3
	end
end

local function clearHighlights()
	for _, h in highlights do
		h.Frame:Destroy()
	end
	table.clear(highlights)
end

local function highlight(center: Vector3, radius: number, phase: number?)
	local u, v = map.UV(center)
	local size = map.WorldSize
	local frame = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(u, v),
		Size = UDim2.fromScale(radius * 2 / size.X, radius * 2 / size.Y),
		BackgroundTransparency = 1,
		ZIndex = 15,
		Parent = map.World,
	})
	New("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = frame })
	local stroke = New("UIStroke", { Color = GOLD, Thickness = 4, Transparency = 0.1, Parent = frame })
	table.insert(highlights, { Frame = frame, Stroke = stroke, Phase = phase or 0 })
end

local function ensureMap()
	if map or not C.WorldMap or not C.WorldMap.NewCanvas then
		return
	end
	map = C.WorldMap.NewCanvas(ui.MapHolder, 0.05)
	-- "sei qui": il punto dove si trova il giocatore
	local root = Util.GetRoot(player.Character)
	local camp = Zones.Get("CampoAddestramento")
	local pos = if root then root.Position elseif camp then camp.Center else Vector3.zero
	local u, v = map.UV(pos)
	local dot = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(u, v), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Colors.RedBright, ZIndex = 18, Parent = map.World })
	Theme.Corner(dot, 7)
	Theme.Stroke(dot, Colors.White, 2, 0)
	Theme.Label("Sei qui", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -4), Size = UDim2.fromOffset(80, 18), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Fonts.Bold, TextSize = 13, TextStrokeTransparency = 0.2, ZIndex = 18, Parent = dot })
end

-- tutta la mappa nello schermo (lasciando posto alla scheda a destra)
local function overview(): (Vector3, number)
	local hs = ui.MapHolder.AbsoluteSize
	local size = map.WorldSize
	local cardW = 440 * C.UIController.Scale
	local scale = math.max(math.min((hs.X - cardW) / size.X, hs.Y / size.Y) * 0.92, 0.002)
	local B = W.SeaBounds
	local center = Vector3.new((B.MinX + B.MaxX) / 2, 0, (B.MinZ + B.MaxZ) / 2)
	return center + Vector3.new(cardW * 0.5 / scale, 0, 0), scale
end

local function focusIsland(isl): (Vector3, number)
	local hs = ui.MapHolder.AbsoluteSize
	local cardW = 440 * C.UIController.Scale
	local scale = math.max(math.min((hs.X - cardW) * 0.8, hs.Y * 0.72) / (2 * isl.Water), 0.002)
	return isl.Center + Vector3.new(cardW * 0.5 / scale, 0, 0), scale
end

local function runMap(): boolean
	ensureMap()
	if not map then
		return alive()
	end
	local card = ui.MapCard
	local islands = Tutorial.Islands
	local pages = #islands + 2
	C.UIController.RequestCursor("tutorialTour", true)
	ui.MapRoot.Visible = true
	ui.MapRoot.GroupTransparency = 1
	local center, scale = overview()
	mapView = { Center = center, Scale = scale * 0.7 }
	moveMap(center, scale, 2.2)
	Theme.Tween(ui.MapRoot, 0.6, { GroupTransparency = 0 }, Enum.EasingStyle.Sine)
	sound("UI")
	-- pagina 1: tutto l'arcipelago
	swapCard(card, function()
		card.Top.Text = "PARTE 2  •  IL MONDO"
		card.Title.Text = "Cinque isole e il mare"
		setChips(card, { { "4 stagioni" }, { "5 isole + Arena", "blue" } })
		card.Text.Text = "Ogni stagione della storia si svolge su un'isola diversa. " .. Tutorial.LevelText
		card.Counter.Text = ("1 / %d"):format(pages)
	end)
	for i, id in W.IslandOrder do
		highlight(W.Islands[id].Center, W.Islands[id].Land * 1.04, i)
	end
	if not waitPage(PAGE_TIME, card.Timer) then
		return false
	end
	clearHighlights()
	-- un'isola alla volta
	for i, entry in islands do
		local isl = W.Islands[entry.Island]
		local c, s = focusIsland(isl)
		moveMap(c, s, 1.8)
		highlight(isl.Center, isl.Land * 1.04)
		local zones = Tutorial.IslandZones(isl.Id, 4)
		swapCard(card, function()
			card.Top.Text = if isl.Raid then "RAID" else ("STAGIONE %d"):format(isl.Season)
			card.Title.Text = isl.Name
			local chips = { { ("Lv. %d+"):format(isl.LevelReq) } }
			if isl.Id == "Vermiglia" then
				table.insert(chips, { "📍 Sei qui", "green" })
			end
			if W.Walls[isl.Id] then
				table.insert(chips, { "Mura", "blue" })
			end
			setChips(card, chips)
			card.Text.Text = entry.Text .. (if #zones > 0 then "\n\nZone: " .. table.concat(zones, " • ") else "")
			card.Counter.Text = ("%d / %d"):format(i + 1, pages)
		end)
		sound("UI")
		if not waitPage(PAGE_TIME, card.Timer) then
			return false
		end
		clearHighlights()
	end
	-- il mare aperto, gli isolotti e i viaggi
	center, scale = overview()
	moveMap(center, scale, 2)
	for i, islet in W.Islets do
		highlight(islet.Center, islet.Radius + 60, i * 0.7)
	end
	swapCard(card, function()
		card.Top.Text = "MARE APERTO"
		card.Title.Text = "Isolotti e viaggi"
		setChips(card, { { "🐎 Corrieri" }, { "⛵ Barca", "blue" }, { "🐴 Cavallo (H)", "green" } })
		card.Text.Text = Tutorial.SeaText
		card.Counter.Text = ("%d / %d"):format(pages, pages)
	end)
	sound("UI")
	if not waitPage(PAGE_TIME, card.Timer) then
		return false
	end
	clearHighlights()
	Theme.Tween(card.Card, 0.3, { GroupTransparency = 1 })
	Theme.Tween(ui.MapRoot, 0.6, { GroupTransparency = 1 }, Enum.EasingStyle.Sine)
	local ok = waitFor(0.6)
	ui.MapRoot.Visible = false
	C.UIController.RequestCursor("tutorialTour", false)
	return ok
end

-- 2. L'INTERFACCIA (riflettore) --------------------------------------------------------------------------------

local function element(name: string): GuiObject?
	if name == "Rewards" then
		local found = C.UIController.Layers.HUD:FindFirstChild("Premi")
		return if found and found:IsA("GuiObject") then found else nil
	elseif name == "Minimap" then
		return C.WorldMap and C.WorldMap.MiniFrame and C.WorldMap.MiniFrame() or nil
	end
	return C.HUD and C.HUD.Element and C.HUD.Element(name) or nil
end

local function rectOf(gui: GuiObject): Box
	local p, s = gui.AbsolutePosition, gui.AbsoluteSize
	local pad = 8
	return box(p.X - pad, p.Y - pad, p.X + s.X + pad, p.Y + s.Y + pad)
end

local function lerpBox(a: Box, b: Box, k: number): Box
	return box(a.X0 + (b.X0 - a.X0) * k, a.Y0 + (b.Y0 - a.Y0) * k, a.X1 + (b.X1 - a.X1) * k, a.Y1 + (b.Y1 - a.Y1) * k)
end

local function placeSpot(r: Box)
	local screen = ui.SpotRoot.AbsoluteSize
	local x0, y0, x1, y1 = r.X0, r.Y0, r.X1, r.Y1
	local d = ui.Dims
	d[1].Position, d[1].Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(screen.X, math.max(0, y0))
	d[2].Position, d[2].Size = UDim2.fromOffset(0, y1), UDim2.fromOffset(screen.X, math.max(0, screen.Y - y1))
	d[3].Position, d[3].Size = UDim2.fromOffset(0, y0), UDim2.fromOffset(math.max(0, x0), math.max(0, y1 - y0))
	d[4].Position, d[4].Size = UDim2.fromOffset(x1, y0), UDim2.fromOffset(math.max(0, screen.X - x1), math.max(0, y1 - y0))
	ui.Outline.Position = UDim2.fromOffset(x0, y0)
	ui.Outline.Size = UDim2.fromOffset(x1 - x0, y1 - y0)
end

local function updateSpot()
	if not spot.On then
		return
	end
	local k = Util.Ease((os.clock() - spot.Start) / spot.Duration, "SineInOut")
	placeSpot(lerpBox(spot.From, spot.To, k))
	ui.OutlineStroke.Thickness = 3 + math.sin(os.clock() * 5) * 1.2
end

-- il fumetto accanto al buco, dal lato con più spazio, con la freccia verso l'elemento
local function placeBubble(r: Box)
	local screen = ui.SpotRoot.AbsoluteSize
	local scale = C.UIController.Scale
	local bw, bh = 380 * scale, 250 * scale
	local cx, cy = (r.X0 + r.X1) / 2, (r.Y0 + r.Y1) / 2
	local right = cx < screen.X / 2
	local x = if right then r.X1 + 34 else r.X0 - 34 - bw
	if x < 12 or x + bw > screen.X - 12 then
		-- non c'è spazio ai lati: sotto (o sopra) l'elemento
		x = math.clamp(cx - bw / 2, 12, math.max(12, screen.X - bw - 12))
		local below = r.Y1 + 34
		local y = if below + bh < screen.Y - 12 then below else r.Y0 - 34 - bh
		ui.SpotCard.Card.Position = UDim2.fromOffset(x, y)
		ui.Arrow.Text = if y > r.Y1 then "▲" else "▼"
		ui.Arrow.Position = UDim2.fromOffset(cx - 15, if y > r.Y1 then r.Y1 + 4 else r.Y0 - 34)
		return
	end
	local y = math.clamp(cy - bh / 2, 12, math.max(12, screen.Y - bh - 12))
	ui.SpotCard.Card.Position = UDim2.fromOffset(x, y)
	ui.Arrow.Text = if right then "◀" else "▶"
	ui.Arrow.Position = UDim2.fromOffset(if right then r.X1 + 4 else r.X0 - 34, cy - 15)
end

local function runSpotlight(): boolean
	local entries = {}
	for _, entry in Tutorial.Spotlight do
		local gui = element(entry.Element)
		if gui and gui.Visible and gui.AbsoluteSize.X > 0 then
			table.insert(entries, { Entry = entry, Gui = gui })
		end
	end
	if #entries == 0 then
		return alive()
	end
	-- il pannello degli obiettivi torna a mostrare la storia (è quello che il riflettore spiega)
	if C.HUD and C.HUD.SetTutorial then
		C.HUD.SetTutorial(nil)
	end
	C.UIController.RequestCursor("tutorialTour", true)
	ui.SpotRoot.Visible = true
	local screen = ui.SpotRoot.AbsoluteSize
	local first = rectOf(entries[1].Gui)
	-- si parte da tutto lo schermo e il buco si stringe sul primo elemento
	spot = { From = box(0, 0, screen.X, screen.Y), To = first, Start = os.clock(), Duration = 0.8, On = true }
	for _, d in ui.Dims do
		d.BackgroundTransparency = 1
		Theme.Tween(d, 0.6, { BackgroundTransparency = 0.38 })
	end
	Theme.Tween(ui.OutlineStroke, 0.6, { Transparency = 0 })
	local card = ui.SpotCard
	for i, item in entries do
		local target = rectOf(item.Gui)
		if i > 1 then
			Theme.Tween(card.Card, 0.18, { GroupTransparency = 1 })
			Theme.Tween(ui.Arrow, 0.18, { TextTransparency = 1 })
			if not waitFor(0.18) then
				return false
			end
			spot = { From = spot.To, To = target, Start = os.clock(), Duration = 0.55, On = true }
			if not waitFor(0.5) then
				return false
			end
		else
			if not waitFor(0.6) then
				return false
			end
		end
		card.Top.Text = "PARTE 2  •  L'INTERFACCIA"
		card.Title.Text = item.Entry.Title
		setChips(card, {})
		card.Text.Text = item.Entry.Text
		card.Counter.Text = ("%d / %d"):format(i, #entries)
		placeBubble(target)
		local base = card.Card.Position
		card.Card.Position = base + UDim2.fromOffset(0, 12)
		Theme.Tween(card.Card, 0.35, { GroupTransparency = 0, Position = base }, Enum.EasingStyle.Quint)
		Theme.Tween(ui.Arrow, 0.35, { TextTransparency = 0 })
		sound("UI")
		if not waitPage(PAGE_TIME - 1, card.Timer) then
			return false
		end
	end
	-- il buco si allarga a tutto lo schermo e il riflettore si spegne
	spot = { From = spot.To, To = box(0, 0, screen.X, screen.Y), Start = os.clock(), Duration = 0.6, On = true }
	Theme.Tween(card.Card, 0.25, { GroupTransparency = 1 })
	Theme.Tween(ui.Arrow, 0.25, { TextTransparency = 1 })
	Theme.Tween(ui.OutlineStroke, 0.5, { Transparency = 1 })
	for _, d in ui.Dims do
		Theme.Tween(d, 0.5, { BackgroundTransparency = 1 })
	end
	local ok = waitFor(0.6)
	spot.On = false
	ui.SpotRoot.Visible = false
	C.UIController.RequestCursor("tutorialTour", false)
	return ok
end

-- 3. I GIGANTI -------------------------------------------------------------------------------------

local function runGiants(): boolean
	if not C.CutsceneController then
		return alive()
	end
	-- dissolvenza al nero: la scena parte dal nero e si apre da sola
	ui.Black.Visible = true
	ui.Black.BackgroundTransparency = 1
	Theme.Tween(ui.Black, 0.5, { BackgroundTransparency = 0 }, Enum.EasingStyle.Sine)
	if not waitFor(0.55) then
		ui.Black.Visible = false
		return false
	end
	task.delay(0.15, function()
		ui.Black.Visible = false
	end)
	C.CutsceneController.Play("TutorialGiganti", true)
	return alive()
end

-- 4. IL FINALE ---------------------------------------------------------------------------------------

local function rewardChip(text: string, order: number)
	local chip = pill(ui.Rewards, text, Colors.GoldBright, order)
	chip.TextSize = 18
	chip.Size = UDim2.fromOffset(0, 36)
	Theme.Corner(chip, 18)
	local scale = New("UIScale", { Scale = 0, Parent = chip })
	return scale
end

local function runFinale(replaying: boolean): boolean
	-- la telecamera gira piano attorno al personaggio, senza interfaccia di gioco
	if C.HUD then
		C.HUD.SetVisible(false)
	end
	local root = Util.GetRoot(player.Character)
	if root and C.CameraController then
		C.CameraController.SetCinematic(true)
		orbit = { Center = root.Position, Angle = math.atan2(camera.CFrame.LookVector.X, camera.CFrame.LookVector.Z) + math.pi }
	end
	C.UIController.RequestCursor("tutorialTour", true)
	for _, child in ui.Rewards:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	ui.FinalTop.Text = if replaying then "RIPASSO COMPLETATO" else "MISSIONE 0 SUPERATA"
	ui.Final.Visible = true
	ui.Final.GroupTransparency = 1
	ui.FinalScale.Scale = 1.3
	ui.FinalLine.Size = UDim2.fromOffset(0, 2)
	ui.ContinueScale.Scale = 0
	for _, s in ui.Outro do
		s.Scale = 0
	end
	Theme.Tween(ui.Final, 0.6, { GroupTransparency = 0 }, Enum.EasingStyle.Sine)
	Theme.Tween(ui.FinalScale, 1, { Scale = 1 }, Enum.EasingStyle.Quint)
	Theme.Tween(ui.FinalLine, 1, { Size = UDim2.fromOffset(640, 2) }, Enum.EasingStyle.Quint)
	sound("Reward")
	if C.EffectsController and root then
		C.EffectsController.Sparks(root.Position + Vector3.new(0, 4, 0), GOLD, 50, 50)
	end
	if not waitFor(0.8) then
		return false
	end
	-- le quattro schede compaiono una dopo l'altra
	for _, s in ui.Outro do
		Theme.Tween(s, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		sound("UI")
		if not waitFor(0.18) then
			return false
		end
	end
	-- il premio (solo la prima volta)
	if not replaying then
		local chips = {}
		local reward = Tutorial.Reward
		if reward.Gold then
			table.insert(chips, rewardChip(("💰 +%d oro"):format(reward.Gold), 1))
		end
		if reward.XP then
			table.insert(chips, rewardChip("⭐ Esperienza", 2))
		end
		for id, count in reward.Items or {} do
			local def = Items.Get(id)
			table.insert(chips, rewardChip(("🎁 %s x%d"):format(def and def.Name or id, count), 3))
		end
		for _, s in chips do
			Theme.Tween(s, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
			sound("Coins")
			if not waitFor(0.25) then
				return false
			end
		end
	end
	Theme.Tween(ui.ContinueScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	if not waitPage(14) then
		return false
	end
	Theme.Tween(ui.Final, 0.5, { GroupTransparency = 1 }, Enum.EasingStyle.Sine)
	local ok = waitFor(0.5)
	ui.Final.Visible = false
	-- la rotazione si ferma qui: il volo verso Brehm (AfterDone) parte da dove è la telecamera
	orbit = nil
	C.UIController.RequestCursor("tutorialTour", false)
	return ok
end

-- la telecamera torna dolcemente dietro al personaggio, poi il controllo torna al giocatore
local function blendToPlayer(duration: number)
	orbit = nil
	local root = Util.GetRoot(player.Character)
	if root then
		local from = camera.CFrame
		local look = Util.SafeUnit(Util.Flat(root.CFrame.LookVector), Vector3.new(0, 0, -1))
		local focus = root.Position + Vector3.new(0, 2.5, 0)
		local to = CFrame.lookAt(focus - look * 14 + Vector3.new(0, 4.5, 0), focus)
		local start = os.clock()
		while os.clock() - start < duration do
			camera.CFrame = from:Lerp(to, Util.Ease((os.clock() - start) / duration, "SineInOut"))
			RunService.RenderStepped:Wait()
		end
		camera.CFrame = to
	end
	if C.CameraController then
		C.CameraController.SetCinematic(false)
	end
	if C.HUD then
		C.HUD.SetVisible(true)
	end
end

-- API ----------------------------------------------------------------------------------------------

-- La seconda parte del tutorial (attende la fine). false = interrotta.
function TutorialTour.Run(myToken: number, replaying: boolean): boolean
	cancelled = false
	if not C.Tutorial.Banner("PARTE 2", "IL MONDO", "Le isole, l'interfaccia e i giganti. Puoi andare avanti quando vuoi.", 1.2, myToken) then
		return false
	end
	if not runMap() then
		return false
	end
	if not runSpotlight() then
		return false
	end
	if not C.Tutorial.Banner("PARTE 2", "I GIGANTI", "Conoscere il nemico è metà della vittoria.", 0.8, myToken) then
		return false
	end
	if not runGiants() then
		return false
	end
	return runFinale(replaying)
end

-- la telecamera vola fino a Brehm (la prossima missione) e torna al personaggio
local function flyToBrehm(replaying: boolean)
	local npc = NPCs.Get("Brehm")
	local zone = npc and Zones.Get(npc.Zone)
	if replaying or not npc or not zone or not C.CameraController then
		blendToPlayer(0.9)
		return
	end
	C.CameraController.SetCinematic(true)
	orbit = nil
	local brehm = zone.Center + npc.Offset + Vector3.new(0, 5, 0)
	local facing = math.rad(npc.Facing or 0)
	local front = Vector3.new(math.sin(facing), 0, math.cos(facing))
	local from = camera.CFrame
	local to = CFrame.lookAt(brehm + front * 16 + Vector3.new(6, 3, 0), brehm)
	ui.Caption.Visible = true
	ui.CaptionText.Text = "Presentati all'Istruttore Brehm"
	local start = os.clock()
	while os.clock() - start < 1.8 do
		camera.CFrame = from:Lerp(to, Util.Ease((os.clock() - start) / 1.8, "SineInOut"))
		RunService.RenderStepped:Wait()
	end
	Theme.Tween(ui.Caption, 0.4, { GroupTransparency = 0 }, Enum.EasingStyle.Sine)
	sound("Reward")
	local hold = os.clock()
	while os.clock() - hold < 2.6 do
		camera.CFrame = to * CFrame.new(0, 0, -(os.clock() - hold) * 0.8)
		RunService.RenderStepped:Wait()
	end
	Theme.Tween(ui.Caption, 0.4, { GroupTransparency = 1 }, Enum.EasingStyle.Sine)
	blendToPlayer(1.3)
	ui.Caption.Visible = false
end

-- Dopo il tutorial: il volo fino a Brehm (attende la fine); se qualcosa va storto telecamera e
-- interfaccia tornano comunque al giocatore
function TutorialTour.AfterDone(replaying: boolean)
	local ok, err = pcall(flyToBrehm, replaying)
	if not ok then
		warn("[Addestramento] " .. tostring(err))
		orbit = nil
		ui.Caption.Visible = false
		if C.CameraController then
			C.CameraController.SetCinematic(false)
		end
		if C.HUD then
			C.HUD.SetVisible(true)
		end
	end
end

-- Interrompe la seconda parte (il giocatore ha saltato il tutorial)
function TutorialTour.Cancel()
	cancelled = true
	advance = true
	spot.On = false
	if ui then
		ui.MapRoot.Visible = false
		ui.SpotRoot.Visible = false
		ui.Final.Visible = false
		ui.Black.Visible = false
		clearHighlights()
	end
	if C.HUD then
		C.HUD.SetVisible(true)
	end
	if C.CutsceneController and C.CutsceneController.Skip then
		C.CutsceneController.Skip()
	end
	C.UIController.RequestCursor("tutorialTour", false)
	if orbit or (C.CameraController and C.CameraController.IsCinematic() and not (C.CutsceneController and C.CutsceneController.IsPlaying())) then
		task.spawn(blendToPlayer, 0.6)
	end
end

function TutorialTour.Init(c)
	C = c
end

function TutorialTour.Start()
	buildUI()
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter) then
			advance = true
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		if ui.MapRoot.Visible then
			updateMap()
		end
		updateSpot()
		local o = orbit
		if o then
			o.Angle += dt * 0.12
			local eye = o.Center + Vector3.new(math.sin(o.Angle) * 26, 9, math.cos(o.Angle) * 26)
			camera.CFrame = CFrame.lookAt(eye, o.Center + Vector3.new(0, 3, 0))
		end
	end)
end

return TutorialTour
