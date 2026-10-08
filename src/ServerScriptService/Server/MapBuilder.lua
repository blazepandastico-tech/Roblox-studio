-- Costruisce da codice illuminazione, campo (Canyon del Deserto) e lobby.
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))

local MapBuilder = {}

local F = Config.Field
local HL = F.Length / 2
local HW = F.Width / 2

local function P(parent, name, size, cf, color, material, transparency, collide)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.CanCollide = collide ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function decor(p)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function setupLighting()
	Lighting.ClockTime = 17.4
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(120, 92, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 110, 125)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 170, 120)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true

	local atm = Instance.new("Atmosphere")
	atm.Density = 0.28
	atm.Offset = 0.2
	atm.Color = Color3.fromRGB(255, 190, 175)
	atm.Decay = Color3.fromRGB(190, 110, 170)
	atm.Glare = 0.5
	atm.Haze = 1.2
	atm.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 24
	bloom.Threshold = 1.1
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.25
	cc.Contrast = 0.1
	cc.TintColor = Color3.fromRGB(255, 240, 235)
	cc.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.08
	rays.Spread = 0.6
	rays.Parent = Lighting
end

-- linea piatta tra due punti del campo (coordinate X,Z)
local function line(parent, x1, z1, x2, z2, thick)
	local dx, dz = x2 - x1, z2 - z1
	local len = math.sqrt(dx * dx + dz * dz)
	local mid = Vector3.new((x1 + x2) / 2, 0.14, (z1 + z2) / 2)
	local p = P(
		parent,
		"Line",
		Vector3.new(len + (thick or 0.7), 0.06, thick or 0.7),
		CFrame.new(mid) * CFrame.Angles(0, -math.atan2(dz, dx), 0),
		Color3.fromRGB(232, 222, 255),
		Enum.Material.Neon
	)
	return decor(p)
end

-- rete a nido d'api (esagoni) su un pannello; origin: X locale = larghezza, Y locale = altezza
local function hexNet(parent, origin, width, height, color)
	local r = 1.7
	local dx = math.sqrt(3) * r
	local dy = 1.5 * r
	local row = 0
	local v = -height / 2 + r
	while v <= height / 2 - r * 0.5 do
		local offset = (row % 2 == 0) and 0 or dx / 2
		local u = -width / 2 + r * 0.9 + offset
		while u <= width / 2 - r * 0.8 do
			for k = 0, 5 do
				local a1 = math.rad(30 + 60 * k)
				local a2 = math.rad(30 + 60 * (k + 1))
				local x1, y1 = u + r * math.cos(a1), v + r * math.sin(a1)
				local x2, y2 = u + r * math.cos(a2), v + r * math.sin(a2)
				local ex, ey = x2 - x1, y2 - y1
				local len = math.sqrt(ex * ex + ey * ey)
				local cf = origin * CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, 0) * CFrame.Angles(0, 0, math.atan2(ey, ex))
				decor(P(parent, "NetEdge", Vector3.new(len, 0.16, 0.16), cf, color, Enum.Material.Neon))
			end
			u = u + dx
		end
		v = v + dy
		row = row + 1
	end
end

local function buildGoal(parent, sign, teamKey)
	local color = Config.Teams[teamKey].Color
	local netColor = (teamKey == "Red") and Color3.fromRGB(255, 70, 150) or Color3.fromRGB(70, 190, 255)
	local g = folder(parent, "Goal_" .. teamKey)
	local stone = Color3.fromRGB(150, 145, 138)
	local gw, gh, gd = F.GoalWidth, F.GoalHeight, F.GoalDepth
	local x = sign * HL

	-- pali spessi color pietra
	for _, s in ipairs({ -1, 1 }) do
		local post = P(g, "Post", Vector3.new(2.2, gh, 2.2), CFrame.new(x, gh / 2, s * gw / 2), stone, Enum.Material.Slate)
		post.CustomPhysicalProperties = PhysicalProperties.new(1, 0.3, 0.8, 100, 1)
	end
	local bar = P(g, "Crossbar", Vector3.new(2.2, 2.2, gw + 2.2), CFrame.new(x, gh, 0), stone, Enum.Material.Slate)
	bar.CustomPhysicalProperties = PhysicalProperties.new(1, 0.3, 0.8, 100, 1)

	-- pannelli di collisione (quasi invisibili) + esagoni luminosi
	local backX = sign * (HL + gd)
	local netProps = PhysicalProperties.new(1, 0.5, 0.35, 100, 1)
	local back = P(g, "NetBack", Vector3.new(0.5, gh, gw), CFrame.new(backX, gh / 2, 0), netColor, Enum.Material.Neon, 0.85)
	back.CustomPhysicalProperties = netProps
	hexNet(g, CFrame.new(backX, gh / 2, 0) * CFrame.Angles(0, math.pi / 2, 0), gw, gh, netColor)

	for _, s in ipairs({ -1, 1 }) do
		local cx = sign * (HL + gd / 2)
		local side = P(g, "NetSide", Vector3.new(gd, gh, 0.5), CFrame.new(cx, gh / 2, s * gw / 2), netColor, Enum.Material.Neon, 0.85)
		side.CustomPhysicalProperties = netProps
		hexNet(g, CFrame.new(cx, gh / 2, s * gw / 2), gd, gh, netColor)
	end

	local cx = sign * (HL + gd / 2)
	local top = P(g, "NetTop", Vector3.new(gd, 0.5, gw), CFrame.new(cx, gh, 0), netColor, Enum.Material.Neon, 0.85)
	top.CustomPhysicalProperties = netProps
	hexNet(g, CFrame.new(cx, gh, 0) * CFrame.Angles(math.pi / 2, 0, 0), gd, gw, netColor)

	-- striscia colorata della squadra che difende, a terra davanti alla porta
	decor(P(g, "GoalMark", Vector3.new(1.2, 0.07, gw), CFrame.new(x - sign * 1.5, 0.15, 0), color, Enum.Material.Neon))
end

local function buildField(root)
	local field = folder(root, "Field")
	local L, W, GD = F.Length, F.Width, F.GoalDepth

	-- terreno desertico enorme
	local base = P(field, "DesertFloor", Vector3.new(2400, 4, 2400), CFrame.new(0, -2.1, 0), Color3.fromRGB(196, 140, 96), Enum.Material.Sand)
	base.Name = "DesertFloor"

	-- campo di terra a strisce
	local totalLen = L + 2 * GD + 8
	local stripes = 12
	local sw = totalLen / stripes
	for i = 0, stripes - 1 do
		local c = (i % 2 == 0) and Color3.fromRGB(150, 98, 62) or Color3.fromRGB(168, 114, 74)
		local s = P(
			field,
			"Stripe",
			Vector3.new(sw, 0.2, W + 6),
			CFrame.new(-totalLen / 2 + sw * (i + 0.5), 0.05, 0),
			c,
			Enum.Material.Ground
		)
		s.CustomPhysicalProperties = PhysicalProperties.new(1, 0.55, 0.45, 50, 1)
	end

	-- righe del campo
	local lines = folder(field, "Lines")
	line(lines, -HL, -HW, HL, -HW)
	line(lines, -HL, HW, HL, HW)
	line(lines, -HL, -HW, -HL, HW)
	line(lines, HL, -HW, HL, HW)
	line(lines, 0, -HW, 0, HW)
	local radius, segs = 18, 40
	for i = 0, segs - 1 do
		local a1 = (i / segs) * math.pi * 2
		local a2 = ((i + 1) / segs) * math.pi * 2
		line(lines, radius * math.cos(a1), radius * math.sin(a1), radius * math.cos(a2), radius * math.sin(a2), 0.6)
	end
	for _, s in ipairs({ -1, 1 }) do
		local px, pw = s * (HL - 22), 29
		line(lines, s * HL, -pw, px, -pw)
		line(lines, s * HL, pw, px, pw)
		line(lines, px, -pw, px, pw)
		local gx, gz = s * (HL - 8), 14
		line(lines, s * HL, -gz, gx, -gz)
		line(lines, s * HL, gz, gx, gz)
		line(lines, gx, -gz, gx, gz)
		decor(P(lines, "Spot", Vector3.new(1.4, 0.06, 1.4), CFrame.new(s * (HL - 15), 0.14, 0), Color3.fromRGB(232, 222, 255), Enum.Material.Neon))
	end
	decor(P(lines, "CenterSpot", Vector3.new(1.6, 0.06, 1.6), CFrame.new(0, 0.14, 0), Color3.fromRGB(232, 222, 255), Enum.Material.Neon))

	-- porte: Rossi difendono -X, Blu difendono +X
	buildGoal(field, -1, "Red")
	buildGoal(field, 1, "Blue")

	-- pareti di vetro trasparenti (e soffitto invisibile)
	local walls = folder(field, "Walls")
	local wh = F.WallHeight
	local glass = Color3.fromRGB(235, 240, 255)
	local wallProps = PhysicalProperties.new(0.7, 0.2, 0.85, 100, 100)
	local xb = HL + GD + 2
	local function wall(size, pos)
		local w = P(walls, "Glass", size, CFrame.new(pos), glass, Enum.Material.Glass, 0.88)
		w.CustomPhysicalProperties = wallProps
		w.CanQuery = false
		return w
	end
	wall(Vector3.new(2 * xb + 4, wh, 2), Vector3.new(0, wh / 2, -HW - 1))
	wall(Vector3.new(2 * xb + 4, wh, 2), Vector3.new(0, wh / 2, HW + 1))
	wall(Vector3.new(2, wh, W + 4), Vector3.new(-xb - 1, wh / 2, 0))
	wall(Vector3.new(2, wh, W + 4), Vector3.new(xb + 1, wh / 2, 0))
	local roof = P(walls, "Roof", Vector3.new(2 * xb + 4, 2, W + 4), CFrame.new(0, wh + 15, 0), glass, Enum.Material.Glass, 1)
	roof.CustomPhysicalProperties = wallProps
	roof.CanQuery = false
	return field
end

----------------------------------------------------------------------
-- Scenario: mesas, colline, parabole, pali della luce, torri faro, aereo
----------------------------------------------------------------------
local ROCK_COLORS = {
	Color3.fromRGB(196, 88, 50),
	Color3.fromRGB(214, 120, 64),
	Color3.fromRGB(170, 72, 46),
	Color3.fromRGB(226, 150, 86),
}

local function outsideField(x, z, margin)
	return math.abs(x) > HL + F.GoalDepth + margin or math.abs(z) > HW + margin
end

local function buildMesa(parent, rng, x, z, scale)
	local layers = rng:NextInteger(3, 5)
	local w = rng:NextNumber(60, 120) * scale
	local d = rng:NextNumber(60, 120) * scale
	local y = 0
	for i = 1, layers do
		local h = rng:NextNumber(14, 30) * scale
		local c = ROCK_COLORS[rng:NextInteger(1, #ROCK_COLORS)]
		local shrink = 1 - (i - 1) * 0.12
		local p = P(
			parent,
			"Mesa",
			Vector3.new(w * shrink, h, d * shrink),
			CFrame.new(x, y + h / 2 - 2, z) * CFrame.Angles(0, rng:NextNumber(0, 0.3), 0),
			c,
			Enum.Material.Rock
		)
		CollectionService:AddTag(p, "Grappable")
		y = y + h
	end
end

local function buildScenery(root)
	local sc = folder(root, "Scenery")
	local rng = Random.new(42)

	for i = 1, 26 do
		local ang = (i / 26) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local dist = rng:NextNumber(300, 520)
		local x, z = math.cos(ang) * dist, math.sin(ang) * dist * 0.8
		buildMesa(sc, rng, x, z, rng:NextNumber(0.8, 1.5))
	end
	-- rocce agganciabili vicino al campo
	for i = 1, 14 do
		local x = rng:NextNumber(-260, 260)
		local z = rng:NextNumber(-200, 200)
		if outsideField(x, z, 30) then
			local s = rng:NextNumber(8, 22)
			local r = P(
				sc,
				"Rock",
				Vector3.new(s, s * rng:NextNumber(0.8, 1.6), s * 0.9),
				CFrame.new(x, s * 0.4, z) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6), rng:NextNumber(-0.2, 0.2)),
				ROCK_COLORS[rng:NextInteger(1, #ROCK_COLORS)],
				Enum.Material.Rock
			)
			CollectionService:AddTag(r, "Grappable")
		end
	end
	-- colline di sabbia
	for i = 1, 16 do
		local ang = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(220, 420)
		local s = rng:NextNumber(60, 130)
		local hill = P(sc, "Dune", Vector3.new(s, s * 0.28, s * 0.8), CFrame.new(math.cos(ang) * dist, 0, math.sin(ang) * dist), Color3.fromRGB(226, 178, 116), Enum.Material.Sand)
		hill.Shape = Enum.PartType.Ball
		hill.Size = Vector3.new(s, s * 0.3, s * 0.8)
	end
	-- cespugli secchi
	for i = 1, 70 do
		local x = rng:NextNumber(-300, 300)
		local z = rng:NextNumber(-220, 220)
		if outsideField(x, z, 10) then
			local s = rng:NextNumber(2, 4.5)
			local b = P(sc, "Bush", Vector3.new(s, s * 0.7, s), CFrame.new(x, s * 0.3, z), Color3.fromRGB(135, 110, 60), Enum.Material.Grass)
			b.Shape = Enum.PartType.Ball
			decor(b)
		end
	end
	-- parabole satellitari giganti
	for i = 1, 3 do
		local x, z = -190 + i * 140, 215 + (i % 2) * 30
		local base = P(sc, "DishBase", Vector3.new(6, 24, 6), CFrame.new(x, 12, z), Color3.fromRGB(200, 200, 205), Enum.Material.Metal)
		local dish = P(sc, "Dish", Vector3.new(46, 12, 46), CFrame.new(x, 28, z) * CFrame.Angles(0.5, i, 0.35), Color3.fromRGB(240, 240, 245), Enum.Material.SmoothPlastic)
		dish.Shape = Enum.PartType.Ball
		local feed = P(sc, "DishFeed", Vector3.new(1.2, 16, 1.2), dish.CFrame * CFrame.new(0, 10, 0), Color3.fromRGB(120, 120, 128), Enum.Material.Metal)
		feed.CanCollide = false
		CollectionService:AddTag(base, "Grappable")
	end
	-- pali della luce con cavi
	local prevTop
	for i = -5, 5 do
		local x, z = i * 60, -190
		local pole = P(sc, "Pole", Vector3.new(2, 38, 2), CFrame.new(x, 19, z), Color3.fromRGB(110, 78, 52), Enum.Material.Wood)
		P(sc, "CrossArm", Vector3.new(16, 1.5, 1.5), CFrame.new(x, 36, z), Color3.fromRGB(110, 78, 52), Enum.Material.Wood).CanCollide = false
		CollectionService:AddTag(pole, "Grappable")
		local top = Vector3.new(x, 35, z)
		if prevTop then
			local mid = (top + prevTop) / 2 - Vector3.new(0, 1.5, 0)
			local len = (top - prevTop).Magnitude
			decor(P(sc, "Cable", Vector3.new(0.2, 0.2, len), CFrame.lookAt(mid, top), Color3.fromRGB(30, 30, 30), Enum.Material.Metal))
		end
		prevTop = top
	end
	-- torri faro dello stadio ai quattro angoli
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local x = sx * (HL + F.GoalDepth + 16)
			local z = sz * (HW + 16)
			local tower = P(sc, "FloodTower", Vector3.new(3, 70, 3), CFrame.new(x, 35, z), Color3.fromRGB(120, 124, 132), Enum.Material.Metal)
			CollectionService:AddTag(tower, "Grappable")
			local panel = P(sc, "FloodLamp", Vector3.new(14, 8, 2), CFrame.lookAt(Vector3.new(x, 72, z), Vector3.new(0, 10, 0)), Color3.fromRGB(255, 244, 210), Enum.Material.Neon)
			panel.CanCollide = false
			local spot = Instance.new("SpotLight")
			spot.Face = Enum.NormalId.Front
			spot.Brightness = 3
			spot.Range = 150
			spot.Angle = 80
			spot.Color = Color3.fromRGB(255, 236, 200)
			spot.Parent = panel
		end
	end
	-- relitto d'aereo
	local plane = folder(sc, "CrashedPlane")
	local origin = CFrame.new(-330, 7, 130) * CFrame.Angles(0.12, 0.6, 0.2)
	local fus = P(plane, "Fuselage", Vector3.new(46, 10, 10), origin, Color3.fromRGB(235, 235, 240), Enum.Material.Metal)
	fus.Shape = Enum.PartType.Cylinder
	P(plane, "Nose", Vector3.new(8, 10, 10), origin * CFrame.new(-27, 0, 0), Color3.fromRGB(200, 60, 50), Enum.Material.Metal).Shape = Enum.PartType.Ball
	P(plane, "WingL", Vector3.new(10, 1.4, 34), origin * CFrame.new(2, -1, 22) * CFrame.Angles(0, 0, 0.1), Color3.fromRGB(215, 215, 222), Enum.Material.Metal)
	P(plane, "WingR", Vector3.new(10, 1.4, 20), origin * CFrame.new(2, -2, -16) * CFrame.Angles(0.5, 0.2, -0.3), Color3.fromRGB(215, 215, 222), Enum.Material.Metal)
	P(plane, "TailFin", Vector3.new(8, 14, 1.4), origin * CFrame.new(22, 8, 0) * CFrame.Angles(0, 0, 0.2), Color3.fromRGB(200, 60, 50), Enum.Material.Metal)
	for _, d in ipairs(plane:GetChildren()) do
		CollectionService:AddTag(d, "Grappable")
	end
end

----------------------------------------------------------------------
-- Lobby: baita di legno con vetrate sul canyon, due pedane squadra
----------------------------------------------------------------------
local function buildSign(parent, cf, size, lines)
	local board = P(parent, "Sign", size, cf, Color3.fromRGB(245, 245, 250), Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(35, 35, 50)
	label.Text = table.concat(lines, "\n")
	label.Parent = gui
	return board
end

local function buildPad(parent, name, teamKey, x)
	local t = Config.Teams[teamKey]
	local pad = P(parent, name, Vector3.new(26, 0.6, 26), CFrame.new(x, 0.3, 10), t.Color, Enum.Material.SmoothPlastic)
	pad:SetAttribute("TeamKey", teamKey)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = pad
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.Text = "⚽\n" .. string.upper(t.Name) .. "\n▲ ▲ ▲"
	lbl.Parent = gui
	-- cornice chiara
	decor(P(parent, name .. "Rim", Vector3.new(28, 0.4, 28), CFrame.new(x, 0.2, 10), Color3.fromRGB(245, 245, 250)))
	return pad
end

local function buildLobby(root)
	local c = Config.Lobby.Center
	local lobby = folder(root, "Lobby")
	local wood = Color3.fromRGB(150, 98, 58)
	local darkWood = Color3.fromRGB(104, 66, 38)

	-- pavimento di assi
	for i = 0, 13 do
		local col = (i % 2 == 0) and wood or Color3.fromRGB(138, 90, 52)
		P(lobby, "Floor", Vector3.new(10, 2, 100), CFrame.new(c.X - 65 + i * 10, -1, c.Z), col, Enum.Material.WoodPlanks)
	end
	local function at(x, y, z)
		return CFrame.new(c.X + x, c.Y + y, c.Z + z)
	end
	-- pareti: dietro, lati; davanti vetrata
	P(lobby, "BackWall", Vector3.new(140, 30, 2), at(0, 15, -50), wood, Enum.Material.WoodPlanks)
	P(lobby, "WallL", Vector3.new(2, 30, 100), at(-70, 15, 0), wood, Enum.Material.WoodPlanks)
	P(lobby, "WallR", Vector3.new(2, 30, 100), at(70, 15, 0), wood, Enum.Material.WoodPlanks)
	P(lobby, "Roof", Vector3.new(146, 2, 106), at(0, 31, 0), darkWood, Enum.Material.WoodPlanks)
	local glassCol = Color3.fromRGB(190, 225, 255)
	P(lobby, "FrontGlass", Vector3.new(136, 26, 1), at(0, 14, 50), glassCol, Enum.Material.Glass, 0.7)
	for i = -3, 3 do
		P(lobby, "Beam", Vector3.new(2, 30, 2), at(i * 22, 15, 50), darkWood, Enum.Material.Wood)
	end
	P(lobby, "BeamTop", Vector3.new(140, 3, 2), at(0, 28.5, 50), darkWood, Enum.Material.Wood)
	-- terrazza esterna
	P(lobby, "Terrace", Vector3.new(140, 2, 30), at(0, -1, 65), wood, Enum.Material.WoodPlanks)
	P(lobby, "Rail", Vector3.new(140, 1.2, 1), at(0, 3, 79.5), darkWood, Enum.Material.Wood)

	-- pedane squadra
	local pads = folder(lobby, "Pads")
	buildPad(pads, "RedPad", "Red", c.X - 35)
	buildPad(pads, "BluePad", "Blue", c.X + 35)
	-- cartelli
	buildSign(lobby, at(0, 18, -48.8), Vector3.new(60, 12, 0.6), { "CALCIO FUORILEGGE", "Sali su una pedana per scegliere la squadra" })
	local lb = buildSign(lobby, at(-45, 12, -48.8), Vector3.new(30, 14, 0.6), { "CLASSIFICHE", "(in arrivo)" })
	lb.Name = "LeaderboardSign"
	buildSign(lobby, at(45, 12, -48.8), Vector3.new(30, 14, 0.6), { "REGOLE", "4 contro 4", "Niente falli!" })

	-- punto di spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = at(0, 0.5, -20)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = lobby
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	-- mesas attorno alla lobby (panorama sul canyon)
	local rng = Random.new(7)
	for i = 1, 14 do
		local ang = math.pi * 0.15 + (i / 14) * math.pi * 0.7
		local dist = rng:NextNumber(260, 380)
		buildMesa(lobby, rng, c.X + math.cos(ang) * dist * 1.2, c.Z + math.sin(ang) * dist + 120, rng:NextNumber(0.9, 1.6))
	end
	return lobby
end

function MapBuilder.Build()
	local root = Instance.new("Folder")
	root.Name = "World"
	root.Parent = workspace
	setupLighting()
	buildField(root)
	buildScenery(root)
	buildLobby(root)
	return root
end

function MapBuilder.LobbySpawnCFrame()
	local c = Config.Lobby.Center
	return CFrame.new(c.X, c.Y + 4, c.Z - 20)
end

return MapBuilder
