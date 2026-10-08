--[[
	WorldMap - la mappa dell'arcipelago
	  - minimappa in alto a sinistra: il nord è sempre in alto, la freccia sei tu
	    (puntini rossi = giganti vicini, blu = altri giocatori, ◆ oro = obiettivo della storia)
	  - mappa grande con il tasto B (o toccando la minimappa):
	    isole, isolotti, mura, zone colorate in base al tuo livello, porti, taverne, negozi,
	    eventi in mare, la tua barca e il segnaposto personale (clic destro / tieni premuto)
	    rotella = zoom, trascina = spostati
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Lib.Util)
local W = require(Shared.Data.WorldLayout)
local Zones = require(Shared.Data.Zones)
local NPCs = require(Shared.Data.NPCs)
local Treasures = require(Shared.Data.Treasures)

local Theme = require(script.Parent.Theme)
local New = Theme.New
local Colors = Theme.Colors

local WorldMap = {}
local C
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local B = W.SeaBounds
local WORLD_W = B.MaxX - B.MinX
local WORLD_H = B.MaxZ - B.MinZ

local MINI_SIZE = 196
local MINI_SCALE = 0.17 -- pixel per stud nella minimappa

local SEA = Color3.fromRGB(38, 92, 122)
local SEA_DEEP = Color3.fromRGB(24, 62, 92)
local SAND = Color3.fromRGB(214, 196, 150)
local LAND = Color3.fromRGB(104, 146, 82)
local LAND_DARK = Color3.fromRGB(84, 122, 66)

local ROLE_ICONS = {
	Ferry = "⚓",
	Ship = "⛵",
	Shop = "🛒",
	Quest = "❗",
	Travel = "🐎",
	Tavern = "🍺",
	Raid = "🔱",
	RaidArena = "🔱",
	Duel = "⚔️",
	Lab = "🧪",
	Dealer = "💉",
	Genealogist = "🧬",
	Lift = "🛗",
}

local ROLE_NAMES = {
	Ferry = "Traghetto e barche",
	Shop = "Negozio",
	Quest = "Missioni",
	Travel = "Viaggio rapido",
	Tavern = "Taverna",
	Raid = "Raid",
	Duel = "Arena dei Duelli",
	Lab = "Laboratorio",
}

type Canvas = {
	Holder: Frame,
	World: Frame,
	Scale: number,
	Zones: { [string]: Frame },
	Details: { GuiObject },
	Icons: { GuiObject },
	Dynamic: Frame,
	Pools: { [string]: { GuiObject } },
	Used: { [string]: number },
}

local mini: Canvas
local big: Canvas
local bigPanel: Frame
local miniRoot: Frame
local miniLabel: TextLabel
local pvpLabel: TextLabel
local treasureLabel: TextLabel
local zoomLevel = 1
local pan = Vector2.zero -- spostamento della mappa grande (studs)
local pinPosition: Vector3? = nil
local pinBillboard: BillboardGui? = nil
local lastLevel = -1

-- da coordinate del mondo a frazioni della tela (0..1)
local function uv(pos: Vector3): (number, number)
	return (pos.X - B.MinX) / WORLD_W, (pos.Z - B.MinZ) / WORLD_H
end

local function circle(parent: Instance, center: Vector3, radius: number, color: Color3, transparency: number?, z: number?): Frame
	local u, v = uv(center)
	local frame = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(u, v),
		Size = UDim2.fromScale(radius * 2 / WORLD_W, radius * 2 / WORLD_H),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		BorderSizePixel = 0,
		ZIndex = z or 2,
		Parent = parent,
	})
	New("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = frame })
	return frame
end

local function ring(parent: Instance, center: Vector3, radius: number, color: Color3, thickness: number, z: number?): Frame
	local frame = circle(parent, center, radius, color, 1, z)
	New("UIStroke", { Color = color, Thickness = thickness, Transparency = 0.1, Parent = frame })
	return frame
end

local function icon(parent: Instance, pos: Vector3, text: string, size: number, z: number?): TextLabel
	local u, v = uv(pos)
	return New("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(u, v),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size * 0.8,
		Font = Theme.Fonts.Bold,
		TextColor3 = Colors.Text,
		ZIndex = z or 6,
		Parent = parent,
	})
end

local function label(parent: Instance, pos: Vector3, text: string, size: number, color: Color3?, z: number?, font: Enum.Font?): TextLabel
	local u, v = uv(pos)
	return New("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(u, v),
		Size = UDim2.fromOffset(240, size + 6),
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		Font = font or Theme.Fonts.Header,
		TextColor3 = color or Colors.Text,
		TextStrokeTransparency = 0.35,
		ZIndex = z or 7,
		Parent = parent,
	})
end

-- Colore della zona rispetto al livello del giocatore
local function zoneColor(zone, level: number): (Color3, number)
	if zone.Safe then
		return Color3.fromRGB(120, 220, 140), 0.55
	elseif zone.PvP then
		return Color3.fromRGB(230, 90, 80), 0.5
	elseif zone.Raid then
		return Color3.fromRGB(200, 120, 230), 0.6
	end
	local lo, hi = zone.Level[1], zone.Level[2]
	if level < lo - 40 then
		return Color3.fromRGB(220, 60, 50), 0.5 -- troppo forte per te
	elseif level < lo then
		return Color3.fromRGB(240, 150, 60), 0.55
	elseif level <= hi then
		return Color3.fromRGB(240, 220, 80), 0.6 -- giusta per te
	end
	return Color3.fromRGB(150, 170, 190), 0.7 -- facile
end

-- Disegna il mondo statico su una tela (la stessa funzione per minimappa e mappa grande)
local function drawWorld(canvas: Canvas, detailed: boolean)
	local world = canvas.World
	New("UIGradient", { Color = ColorSequence.new(SEA, SEA_DEEP), Rotation = 90, Parent = world })
	-- isole: spiaggia, terra e mura
	for _, id in W.IslandOrder do
		local isl = W.Islands[id]
		circle(world, isl.Center, isl.Beach, SAND, 0, 2)
		local color = if isl.Id == "Valdoria" then Color3.fromRGB(122, 132, 96) elseif isl.Id == "Cenere" then Color3.fromRGB(120, 112, 100) elseif isl.Raid then Color3.fromRGB(196, 176, 130) else LAND
		circle(world, isl.Center, isl.Land, color, 0, 3)
		circle(world, isl.Center, isl.Land * 0.55, color:Lerp(LAND_DARK, 0.35), 0.4, 3)
	end
	for _, islet in W.Islets do
		circle(world, islet.Center, islet.Radius + 16, SAND, 0, 2)
		local color = if islet.Kind == "Sabbia" or islet.Kind == "Palme" then Color3.fromRGB(200, 186, 140) elseif islet.Kind == "Vulcano" then Color3.fromRGB(80, 70, 66) else LAND
		circle(world, islet.Center, islet.Radius, color, 0, 3)
	end
	for _, wall in W.Walls do
		ring(world, W.WallCenter(wall.Id), wall.Radius, if wall.Ruined then Color3.fromRGB(120, 110, 100) else Color3.fromRGB(220, 214, 196), if detailed then 3 else 2, 4)
	end
	-- zone (colorate in base al livello)
	for _, zone in Zones.List do
		if not zone.Underground then
			local frame = circle(world, zone.Center, zone.Radius, Color3.new(1, 1, 1), 0.6, 4)
			canvas.Zones[zone.Id] = frame
		end
	end
	if not detailed then
		return
	end
	-- nomi delle isole e delle zone
	for _, id in W.IslandOrder do
		local isl = W.Islands[id]
		local name = label(world, isl.Center + Vector3.new(0, 0, -isl.Land * 0.72), isl.Name, 20, Color3.fromRGB(255, 236, 190), 8, Theme.Fonts.Title)
		name.Name = "Isola"
		if not isl.Raid then
			label(world, isl.Center + Vector3.new(0, 0, -isl.Land * 0.72 + 120), ("consigliato Lv. %d+"):format(isl.LevelReq), 13, Colors.TextDim, 8, Theme.Fonts.UI)
		end
	end
	for _, zone in Zones.List do
		if not zone.Underground then
			local lvl = if zone.Safe then "zona sicura" elseif zone.PvP then "PvP sempre attivo" else ("Lv. %d-%d"):format(zone.Level[1], zone.Level[2])
			table.insert(canvas.Details, label(world, zone.Center + Vector3.new(0, 0, zone.Radius * 0.35), zone.Name, 13, Colors.Text, 7, Theme.Fonts.Bold))
			table.insert(canvas.Details, label(world, zone.Center + Vector3.new(0, 0, zone.Radius * 0.35 + 70), lvl, 11, Colors.TextDim, 7, Theme.Fonts.UI))
		end
	end
	-- PNG importanti (traghetti, negozi, missioni, taverne...)
	local placed: { Vector3 } = {}
	for _, npc in NPCs.List do
		local zone = Zones.Get(npc.Zone)
		local iconText = ROLE_ICONS[npc.Role]
		if zone and iconText and not zone.Underground then
			local pos = zone.Center + npc.Offset
			local tooClose = false
			for _, p in placed do
				if Util.FlatDistance(p, pos) < 60 then
					tooClose = true
					break
				end
			end
			if not tooClose then
				table.insert(placed, pos)
				table.insert(canvas.Icons, icon(world, pos, iconText, 18, 9))
			end
		end
	end
	-- pontili degli isolotti
	for _, islet in W.Islets do
		local dir = Util.SafeUnit(Util.Flat(Vector3.zero - islet.Center), Vector3.new(0, 0, 1))
		table.insert(canvas.Icons, icon(world, islet.Center + dir * (islet.Radius + 30), "⛵", 16, 9))
	end
end

local function newCanvas(holder: Frame, scale: number, detailed: boolean): Canvas
	local world = New("Frame", {
		Name = "Mondo",
		Size = UDim2.fromOffset(WORLD_W * scale, WORLD_H * scale),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = holder,
	})
	local dynamic = New("Frame", { Name = "Segnalini", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 10, Parent = world })
	local canvas: Canvas = { Holder = holder, World = world, Scale = scale, Zones = {}, Details = {}, Icons = {}, Dynamic = dynamic, Pools = {}, Used = {} }
	drawWorld(canvas, detailed)
	return canvas
end

local function setScale(canvas: Canvas, scale: number)
	canvas.Scale = scale
	canvas.World.Size = UDim2.fromOffset(WORLD_W * scale, WORLD_H * scale)
end

-- Centra la tela sul punto del mondo "focus"
local function centerOn(canvas: Canvas, focus: Vector3)
	local size = canvas.Holder.AbsoluteSize
	local u, v = uv(focus)
	canvas.World.Position = UDim2.fromOffset(size.X / 2 - u * WORLD_W * canvas.Scale, size.Y / 2 - v * WORLD_H * canvas.Scale)
end

-- SEGNALINI DINAMICI (riusati da un frame all'altro) -------------------------------------------------

local function beginMarkers(canvas: Canvas)
	table.clear(canvas.Used)
end

local function marker(canvas: Canvas, kind: string, pos: Vector3, text: string, size: number, color: Color3?, rotation: number?): TextLabel
	local pool = canvas.Pools[kind]
	if not pool then
		pool = {}
		canvas.Pools[kind] = pool
	end
	local index = (canvas.Used[kind] or 0) + 1
	canvas.Used[kind] = index
	local m = pool[index] :: TextLabel?
	if not m then
		m = New("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Bold,
			TextStrokeTransparency = 0.3,
			ZIndex = 12,
			Parent = canvas.Dynamic,
		})
		pool[index] = m :: TextLabel
	end
	local u, v = uv(pos)
	local label_ = m :: TextLabel
	label_.Visible = true
	label_.Position = UDim2.fromScale(u, v)
	label_.Size = UDim2.fromOffset(size, size)
	label_.TextSize = size
	label_.Text = text
	label_.TextColor3 = color or Colors.Text
	label_.Rotation = rotation or 0
	return label_
end

local function endMarkers(canvas: Canvas)
	for kind, pool in canvas.Pools do
		local used = canvas.Used[kind] or 0
		for i = used + 1, #pool do
			pool[i].Visible = false
		end
	end
end

local function facingAngle(): number
	local look = camera.CFrame.LookVector
	return Util.AngleOf(Vector3.new(look.X, 0, look.Z))
end

local function drawMarkers(canvas: Canvas, detailed: boolean, myRoot: BasePart?)
	beginMarkers(canvas)
	local myPos = myRoot and myRoot.Position
	local range = if detailed then math.huge else 700
	-- giganti vicini (solo minimappa e mappa grande se vicini)
	local titans = workspace:FindFirstChild(Config.Folders.Titans)
	if titans and myPos then
		local count = 0
		for _, model in titans:GetChildren() do
			if count >= 40 then
				break
			end
			local root = model:IsA("Model") and model.PrimaryPart
			if root and model:GetAttribute("State") ~= "Dead" and model:GetAttribute("Ally") ~= true then
				local d = Util.FlatDistance(root.Position, myPos)
				if d < math.min(range, 900) then
					count += 1
					local boss = model:GetAttribute("BossTitle") ~= nil
					marker(canvas, "Gigante", root.Position, if boss then "👹" else "●", if boss then 16 else 9, Color3.fromRGB(235, 70, 60))
				end
			end
		end
	end
	-- eventi in mare (relitti, giganti delle onde)
	for _, model in CollectionService:GetTagged(Config.Tags.SeaEvent) do
		if model:IsA("Model") and model.PrimaryPart then
			local kind = model:GetAttribute("EventoMare")
			marker(canvas, "Evento", model.PrimaryPart.Position, if kind == "Relitto" then "📦" else "🌊", if detailed then 20 else 14)
		end
	end
	-- la mia barca
	for _, boat in CollectionService:GetTagged(Config.Tags.Boat) do
		if boat:IsA("Model") and boat:GetAttribute("Owner") == player.UserId and boat.PrimaryPart then
			marker(canvas, "Barca", boat.PrimaryPart.Position, "⛵", if detailed then 18 else 13)
		end
	end
	-- altri giocatori
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local root = Util.GetRoot(other.Character)
			if root and (not myPos or Util.FlatDistance(root.Position, myPos) < range) then
				local pvp = other:GetAttribute("PvPActive") == true
				marker(canvas, "Giocatore", root.Position, "●", if detailed then 12 else 9, if pvp then Color3.fromRGB(255, 120, 100) else Color3.fromRGB(110, 180, 255))
			end
		end
	end
	-- obiettivo della storia e segnaposto
	local objective = C.HUD and C.HUD.ObjectivePosition()
	if objective then
		marker(canvas, "Obiettivo", objective, "◆", if detailed then 22 else 16, Colors.GoldBright)
	end
	if pinPosition then
		marker(canvas, "Segnaposto", pinPosition, "📍", if detailed then 22 else 16)
	end
	-- io (freccia che guarda dove guarda la telecamera)
	if myPos then
		marker(canvas, "Io", myPos, "▲", if detailed then 20 else 16, Color3.fromRGB(255, 250, 240), facingAngle())
	end
	endMarkers(canvas)
end

-- Ricolora le zone quando cambia il livello del giocatore
local function recolorZones(level: number)
	for _, canvas in { mini, big } do
		if canvas then
			for id, frame in canvas.Zones do
				local zone = Zones.Get(id)
				if zone then
					local color, transparency = zoneColor(zone, level)
					frame.BackgroundColor3 = color
					frame.BackgroundTransparency = transparency
				end
			end
		end
	end
end

-- SEGNAPOSTO PERSONALE ---------------------------------------------------------------------------

local function setPin(pos: Vector3?)
	pinPosition = pos
	if pinBillboard then
		pinBillboard:Destroy()
		pinBillboard = nil
	end
	if not pos then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Name = "Segnaposto"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(pos.X, W.GroundY + 20, pos.Z)
	anchor.Parent = workspace
	local billboard = Instance.new("BillboardGui")
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromOffset(120, 44)
	billboard.MaxDistance = math.huge
	billboard.Adornee = anchor
	local text = Instance.new("TextLabel")
	text.Name = "Testo"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextSize = 16
	text.TextColor3 = Color3.fromRGB(255, 120, 110)
	text.TextStrokeTransparency = 0.3
	text.Text = "📍"
	text.Parent = billboard
	billboard.Parent = player:WaitForChild("PlayerGui")
	billboard.Destroying:Connect(function()
		anchor:Destroy()
	end)
	pinBillboard = billboard
	if C.Notifications then
		C.Notifications.Toast("📍 Segnaposto messo sulla mappa", "Info", 2)
	end
end

local function worldFromScreen(canvas: Canvas, screen: Vector2): Vector3
	local abs = canvas.World.AbsolutePosition
	local size = canvas.World.AbsoluteSize
	local u = (screen.X - abs.X) / math.max(1, size.X)
	local v = (screen.Y - abs.Y) / math.max(1, size.Y)
	return Vector3.new(B.MinX + u * WORLD_W, W.GroundY, B.MinZ + v * WORLD_H)
end

-- COSTRUZIONE ------------------------------------------------------------------------------------

local function buildMini()
	local layer = C.UIController.Layers.HUD
	miniRoot = Theme.Panel({ Name = "Minimappa", Position = UDim2.fromOffset(16, 160), Size = UDim2.fromOffset(MINI_SIZE + 12, MINI_SIZE + 40), Parent = layer })
	C.UIController.AttachScale(miniRoot)
	local holder = New("Frame", {
		Name = "Vista",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(MINI_SIZE, MINI_SIZE),
		BackgroundColor3 = SEA_DEEP,
		ClipsDescendants = true,
		Parent = miniRoot,
	})
	Theme.Corner(holder, 10)
	mini = newCanvas(holder, MINI_SCALE, false)
	-- punti cardinali
	New("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(20, 16), BackgroundTransparency = 1, Text = "N", Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = Colors.RedBright, TextStrokeTransparency = 0.3, ZIndex = 20, Parent = holder })
	miniLabel = Theme.Label("", { Position = UDim2.fromOffset(8, MINI_SIZE + 8), Size = UDim2.new(1, -60, 0, 14), Font = Theme.Fonts.Bold, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd, Parent = miniRoot })
	pvpLabel = Theme.Label("", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, MINI_SIZE + 8), Size = UDim2.fromOffset(60, 14), TextXAlignment = Enum.TextXAlignment.Right, Font = Theme.Fonts.Bold, TextSize = 12, TextColor3 = Colors.RedBright, Parent = miniRoot })
	Theme.Label("B: mappa  •  H: cavallo", { Position = UDim2.fromOffset(8, MINI_SIZE + 22), Size = UDim2.new(1, -16, 0, 12), Font = Theme.Fonts.UI, TextSize = 11, TextColor3 = Colors.TextDim, Parent = miniRoot })
	local click = New("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 30, Parent = holder })
	click.Activated:Connect(function()
		WorldMap.Toggle()
	end)
end

local function legendRow(parent: Instance, order: number, iconText: string, text: string, color: Color3?)
	local row = New("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
	New("TextLabel", { Size = UDim2.fromOffset(24, 20), BackgroundTransparency = 1, Text = iconText, TextSize = 15, Font = Theme.Fonts.Bold, TextColor3 = color or Colors.Text, Parent = row })
	Theme.Label(text, { Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -28, 1, 0), Font = Theme.Fonts.UI, TextSize = 13, Parent = row })
end

local function buildBig()
	bigPanel = Theme.Panel({ Name = "Mappa", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.86), Parent = C.UIController.Layers.Panels })
	Theme.Label("🗺️ L'Arcipelago dei Giganti", { Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -80, 0, 30), Font = Theme.Fonts.Title, TextSize = 26, TextColor3 = Colors.GoldBright, Parent = bigPanel })
	Theme.Button("✕", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(34, 30), Parent = bigPanel }, function()
		C.UIController.Close("Mappa")
	end)
	local holder = New("Frame", {
		Name = "Vista",
		Position = UDim2.fromOffset(12, 46),
		Size = UDim2.new(1, -244, 1, -58),
		BackgroundColor3 = SEA_DEEP,
		ClipsDescendants = true,
		Parent = bigPanel,
	})
	Theme.Corner(holder, 8)
	big = newCanvas(holder, 0.06, true)
	-- legenda e informazioni a destra
	local side = New("ScrollingFrame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 46),
		Size = UDim2.new(0, 220, 1, -58),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = bigPanel,
	})
	New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = side })
	treasureLabel = Theme.Label("", { Size = UDim2.new(1, 0, 0, 40), Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = Colors.GoldBright, LayoutOrder = 1, Parent = side })
	Theme.Label("Colori delle zone", { Size = UDim2.new(1, 0, 0, 20), Font = Theme.Fonts.Header, TextSize = 14, TextColor3 = Colors.Gold, LayoutOrder = 2, Parent = side })
	legendRow(side, 3, "■", "Zona sicura (si rinasce lì)", Color3.fromRGB(120, 220, 140))
	legendRow(side, 4, "■", "Giusta per il tuo livello", Color3.fromRGB(240, 220, 80))
	legendRow(side, 5, "■", "Più forte di te", Color3.fromRGB(240, 150, 60))
	legendRow(side, 6, "■", "Molto pericolosa!", Color3.fromRGB(220, 60, 50))
	legendRow(side, 7, "■", "Facile per te", Color3.fromRGB(150, 170, 190))
	Theme.Label("Simboli", { Size = UDim2.new(1, 0, 0, 20), Font = Theme.Fonts.Header, TextSize = 14, TextColor3 = Colors.Gold, LayoutOrder = 10, Parent = side })
	local order = 11
	for role, name in ROLE_NAMES do
		legendRow(side, order, ROLE_ICONS[role], name)
		order += 1
	end
	legendRow(side, 30, "⛵", "Pontile: prendi la barca (F)")
	legendRow(side, 31, "◆", "Obiettivo della storia", Colors.GoldBright)
	legendRow(side, 32, "📍", "Il tuo segnaposto")
	legendRow(side, 33, "●", "Giganti", Color3.fromRGB(235, 70, 60))
	legendRow(side, 34, "●", "Giocatori (rosso = PvP)", Color3.fromRGB(110, 180, 255))
	legendRow(side, 35, "📦", "Relitto alla deriva (saccheggialo!)")
	legendRow(side, 36, "🌊", "Gigante emerso dal mare")
	Theme.Label("Comandi", { Size = UDim2.new(1, 0, 0, 20), Font = Theme.Fonts.Header, TextSize = 14, TextColor3 = Colors.Gold, LayoutOrder = 40, Parent = side })
	Theme.Label("Rotella: zoom • Trascina: spostati • Clic destro (o tieni premuto): segnaposto", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Theme.Fonts.UI, TextSize = 12, TextColor3 = Colors.TextDim, LayoutOrder = 41, Parent = side })
	local buttons = New("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = 42, Parent = side })
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = buttons })
	Theme.Button("➕", { Size = UDim2.fromOffset(40, 32), Parent = buttons }, function()
		zoomLevel = math.clamp(zoomLevel * 1.5, 1, 8)
	end)
	Theme.Button("➖", { Size = UDim2.fromOffset(40, 32), Parent = buttons }, function()
		zoomLevel = math.clamp(zoomLevel / 1.5, 1, 8)
	end)
	Theme.Button("🎯", { Size = UDim2.fromOffset(40, 32), Parent = buttons }, function()
		pan = Vector2.zero
	end)
	Theme.Button("📍✕", { Size = UDim2.fromOffset(54, 32), Parent = buttons }, function()
		setPin(nil)
	end)
	C.UIController.RegisterPanel("Mappa", bigPanel, function()
		pan = Vector2.zero
		local profile = C.ClientData.Profile
		local found = Treasures.Count(profile)
		treasureLabel.Text = ("📦 Forzieri nascosti trovati: %d / %d\n(l'oste nelle taverne conosce le voci)"):format(found, #Treasures.List)
	end)

	-- trascina, zoom e segnaposto (un pulsante trasparente sopra la mappa riceve i clic)
	local overlay = New("TextButton", { Name = "Comandi", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 40, Parent = holder })
	local dragging = false
	local dragStart = Vector2.zero
	local panStart = Vector2.zero
	local pressStart = 0
	overlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			panStart = pan
			pressStart = os.clock()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			setPin(worldFromScreen(big, Vector2.new(input.Position.X, input.Position.Y)))
		end
	end)
	overlay.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			zoomLevel = math.clamp(zoomLevel * (if input.Position.Z > 0 then 1.25 else 0.8), 1, 8)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
			pan = panStart - delta / big.Scale
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging and input.UserInputType == Enum.UserInputType.Touch then
				-- tieni premuto senza muovere: segnaposto (telefono)
				local moved = (Vector2.new(input.Position.X, input.Position.Y) - dragStart).Magnitude
				if moved < 8 and os.clock() - pressStart > 0.6 then
					setPin(worldFromScreen(big, dragStart))
				end
			end
			dragging = false
		end
	end)
end

-- AGGIORNAMENTO ----------------------------------------------------------------------------------

local accumulator = 0

local function update(dt: number)
	local root = Util.GetRoot(player.Character)
	local profile = C.ClientData.Profile
	if profile and profile.Level ~= lastLevel then
		lastLevel = profile.Level
		recolorZones(profile.Level)
	end
	local showMini = (C.ClientData.Setting("Minimap", true) ~= false) and not (C.CameraController and C.CameraController.IsCinematic())
	if C.Intro and C.Intro.IsShowing and C.Intro.IsShowing() then
		showMini = false
	end
	miniRoot.Visible = showMini
	-- la minimappa sta sotto il pannello del giocatore (che si ingrandisce con lo schermo)
	miniRoot.Position = UDim2.fromOffset(16, math.floor(16 + 146 * C.UIController.Scale))
	if root and showMini then
		centerOn(mini, root.Position)
	end
	local bigOpen = C.UIController.IsOpen("Mappa")
	if bigOpen then
		local holderSize = big.Holder.AbsoluteSize
		local fit = math.min(holderSize.X / WORLD_W, holderSize.Y / WORLD_H)
		setScale(big, fit * zoomLevel)
		local focus = if zoomLevel <= 1.01 then Vector3.new((B.MinX + B.MaxX) / 2, 0, (B.MinZ + B.MaxZ) / 2) else (root and root.Position or Vector3.zero)
		centerOn(big, focus + Vector3.new(pan.X, 0, pan.Y))
		-- con la mappa intera i nomi delle zone si sovrappongono: compaiono avvicinandosi
		local showDetails = big.Scale >= 0.11
		local showIcons = big.Scale >= 0.16
		if big.Details[1] and big.Details[1].Visible ~= showDetails then
			for _, d in big.Details do
				d.Visible = showDetails
			end
		end
		if big.Icons[1] and big.Icons[1].Visible ~= showIcons then
			for _, d in big.Icons do
				d.Visible = showIcons
			end
		end
	end
	accumulator += dt
	if accumulator < 0.15 then
		return
	end
	accumulator = 0
	if showMini then
		drawMarkers(mini, false, root)
		local region = if C.AmbienceController then C.AmbienceController.RegionName else ""
		local zoneId = C.AmbienceController and C.AmbienceController.ZoneId
		local zone = Zones.Get(zoneId)
		miniLabel.Text = if zone then zone.Name else region
		pvpLabel.Text = if player:GetAttribute("PvPActive") then "⚔️ PvP" else ""
	end
	if bigOpen then
		drawMarkers(big, true, root)
	end
	-- distanza dal segnaposto
	if pinBillboard and pinPosition and root then
		local text = pinBillboard:FindFirstChild("Testo") :: TextLabel?
		if text then
			local meters = math.floor(Util.FlatDistance(root.Position, pinPosition) / 3.5)
			text.Text = ("📍 %d m"):format(meters)
			if meters < 6 then
				setPin(nil)
			end
		end
	end
end

function WorldMap.Toggle()
	C.UIController.Toggle("Mappa")
end

function WorldMap.Init(c)
	C = c
end

function WorldMap.Start()
	buildMini()
	buildBig()
	C.InputController.On("Map", function(began)
		if began then
			WorldMap.Toggle()
		end
	end)
	local lastWarn = 0
	RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(update, dt)
		if not ok and os.clock() - lastWarn > 10 then
			lastWarn = os.clock()
			warn("[Mappa] " .. tostring(err))
		end
	end)
end

return WorldMap
