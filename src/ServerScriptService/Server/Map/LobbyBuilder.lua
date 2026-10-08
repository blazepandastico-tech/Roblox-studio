-- La lobby: baita di legno con vetrate panoramiche sul belvedere sopra il canyon, terrazza con le due pedane
-- squadra (ROSSA e BLU), cartelli, camino, trofeo e telescopi puntati sul campo.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local Layout = require(script.Parent.Layout)

local LobbyBuilder = {}

local c = Layout.LOBBY
local SM = Enum.Material.SmoothPlastic
local WOOD = Enum.Material.WoodPlanks

local LOG = Color3.fromRGB(116, 74, 44)
local LOG_DARK = Color3.fromRGB(84, 52, 32)
local PLANK_A = Color3.fromRGB(158, 104, 62)
local PLANK_B = Color3.fromRGB(144, 94, 56)
local CREAM = Color3.fromRGB(246, 232, 204)
local GOLD = Color3.fromRGB(246, 196, 60)
local STONE = Color3.fromRGB(150, 140, 132)
local STEEL = Color3.fromRGB(46, 50, 74)

-- posizione/CFrame relativi al centro del pavimento (Y = pavimento, Z negativa = verso la parete del canyon)
local function V(x, y, z)
	return Vector3.new(c.X + x, c.Y + y, c.Z + z)
end
local function at(x, y, z)
	return CFrame.new(c.X + x, c.Y + y, c.Z + z)
end
-- cartello che guarda in direzione dir (la faccia "Front" va verso dir)
local function facing(pos, dir)
	return CFrame.lookAt(pos, pos + dir)
end

local function board(parent, name, pos, dir, size, color, text, tcolor, pps)
	local p = Util.D(parent, name, size, facing(pos, dir), color, WOOD, 0, { shadow = false })
	Util.label(p, Enum.NormalId.Front, text, { font = Enum.Font.GothamBlack, color = tcolor, pps = pps or 30 })
	return p
end

local function pointLight(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

----------------------------------------------------------------------
-- Pavimento e terrazza
----------------------------------------------------------------------
local function deck(f)
	local d = Util.folder(f, "Pavimento")
	for i = 0, 15 do
		Util.P(d, "Asse", Vector3.new(10, 2, 110), at(-75 + i * 10, -1, 0), (i % 2 == 0) and PLANK_A or PLANK_B, WOOD)
	end
	-- tappeto davanti al camino e sotto la vetrata
	local rug = Util.D(d, "Tappeto", Vector3.new(70, 0.12, 30), at(0, 0.07, -30), Color3.fromRGB(150, 54, 48), Enum.Material.Carpet, 0, { shadow = false })
	Util.D(d, "TappetoBordo", Vector3.new(66, 0.14, 26), at(0, 0.09, -30), Color3.fromRGB(236, 214, 170), Enum.Material.Carpet, 0, { shadow = false })
	Util.D(d, "TappetoCentro", Vector3.new(60, 0.16, 20), at(0, 0.11, -30), Color3.fromRGB(46, 96, 120), Enum.Material.Carpet, 0, { shadow = false })
	rug.Name = "TappetoBase"
end

local function rails(f)
	local r = Util.folder(f, "Ringhiera")
	-- fronte e fianchi della terrazza (z da +5 a +55): parapetto solido + barriera invisibile piu' alta
	local function run(a, b)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		Util.beam(r, "Corrimano", a + Vector3.new(0, 3.3, 0), b + Vector3.new(0, 3.3, 0), 0.8, 0.7, LOG, Enum.Material.Wood, true)
		Util.beam(r, "Traversa", a + Vector3.new(0, 1.7, 0), b + Vector3.new(0, 1.7, 0), 0.4, 0.4, LOG_DARK, Enum.Material.Wood, true)
		local n = math.max(2, math.floor(len / 10))
		for i = 0, n do
			local p = a:Lerp(b, i / n)
			Util.pillar(r, "Paletto", p.X, c.Y, p.Z, 0.8, 3.6, LOG_DARK, Enum.Material.Wood, true)
		end
		-- barriera invisibile alta 40 (nessuno cade giu')
		local cf = CFrame.lookAt(mid + Vector3.new(0, 20, 0), b + Vector3.new(0, 20, 0))
		local wall = Util.P(r, "Barriera", Vector3.new(1.2, 40, len), cf, Color3.new(1, 1, 1), SM, 1, { shadow = false })
		wall.CanQuery = false
	end
	run(V(-80, 0, 55), V(80, 0, 55))
	run(V(-80, 0, 5), V(-80, 0, 55))
	run(V(80, 0, 5), V(80, 0, 55))
end

----------------------------------------------------------------------
-- Baita: pareti, vetrate, tetto a due falde, capriate
----------------------------------------------------------------------
local function cabin(f)
	local cab = Util.folder(f, "Baita")
	-- pareti di tronchi (dietro e ai lati)
	Util.P(cab, "ParetePosteriore", Vector3.new(164, 22, 2), at(0, 11, -56), LOG, WOOD)
	for _, sx in ipairs({ -1, 1 }) do
		Util.P(cab, "ParetePosteriore", Vector3.new(2, 22, 62), at(sx * 81, 11, -25), LOG, WOOD)
	end
	-- fasce di legno scuro che imitano i tronchi
	for y = 2, 20, 4.5 do
		Util.D(cab, "Tronco", Vector3.new(164.4, 0.7, 2.4), at(0, y, -56), LOG_DARK, Enum.Material.Wood, 0, { shadow = false })
		for _, sx in ipairs({ -1, 1 }) do
			Util.D(cab, "Tronco", Vector3.new(2.4, 0.7, 62), at(sx * 81, y, -25), LOG_DARK, Enum.Material.Wood, 0, { shadow = false })
		end
	end
	-- vetrata panoramica con la porta al centro
	for _, sx in ipairs({ -1, 1 }) do
		local g = Util.P(cab, "Vetrata", Vector3.new(66, 20, 0.6), at(sx * 47, 11, 5), Color3.fromRGB(190, 226, 255), Enum.Material.Glass, 0.62, { shadow = false })
		g.CanQuery = false
	end
	for _, x in ipairs({ -80, -69, -58, -47, -36, -25, -14, 14, 25, 36, 47, 58, 69, 80 }) do
		Util.P(cab, "Montante", Vector3.new(1.4, 22, 1.6), at(x, 11, 5), LOG_DARK, Enum.Material.Wood)
	end
	Util.P(cab, "Architrave", Vector3.new(30, 3, 2), at(0, 20.5, 5), LOG_DARK, Enum.Material.Wood)
	for _, sx in ipairs({ -1, 1 }) do
		Util.P(cab, "Zoccolo", Vector3.new(66, 1.6, 1.8), at(sx * 47, 0.8, 5), LOG_DARK, Enum.Material.Wood)
	end
	Util.P(cab, "Trave", Vector3.new(164, 2, 2), at(0, 22.2, 5), LOG_DARK, Enum.Material.Wood)

	-- tetto a due falde
	local ang = math.atan(19.2 / 36)
	local roofCol = Color3.fromRGB(122, 52, 40)
	Util.P(cab, "FaldaFronte", Vector3.new(176, 1.6, 40.8), at(0, 28.4, -7) * CFrame.Angles(ang, 0, 0), roofCol, Enum.Material.RoofShingles)
	Util.P(cab, "FaldaRetro", Vector3.new(176, 1.6, 40.8), at(0, 28.4, -43) * CFrame.Angles(-ang, 0, 0), roofCol, Enum.Material.RoofShingles)
	Util.P(cab, "Colmo", Vector3.new(178, 1.5, 3.4), at(0, 38.5, -25), LOG_DARK, Enum.Material.Wood)
	-- timpani a gradini sulle testate
	for _, sx in ipairs({ -1, 1 }) do
		for k = 0, 7 do
			local top = (k + 1) * 2
			local w = 60 * (1 - top / 16) + 1
			Util.P(cab, "Timpano", Vector3.new(1.8, 2, w), at(sx * 80.6, 22 + k * 2 + 1, -25.5), LOG, WOOD)
		end
	end
	-- capriate a vista
	for _, x in ipairs({ -60, -30, 0, 30, 60 }) do
		Util.beam(cab, "Capriata", V(x, 22, 5), V(x, 38, -25), 1.2, 1.8, LOG_DARK, Enum.Material.Wood, false, { shadow = false })
		Util.beam(cab, "Capriata", V(x, 22, -55), V(x, 38, -25), 1.2, 1.8, LOG_DARK, Enum.Material.Wood, false, { shadow = false })
		Util.beam(cab, "Catena", V(x, 22, -55), V(x, 22, 5), 1.2, 1.4, LOG_DARK, Enum.Material.Wood, false, { shadow = false })
	end
	-- colonne del portico
	for _, x in ipairs({ -72, -48, -24, 24, 48, 72 }) do
		Util.pillar(cab, "Colonna", c.X + x, c.Y, c.Z + 10.5, 2.4, 19.4, LOG, Enum.Material.Wood, true)
		Util.D(cab, "ColonnaBase", Vector3.new(3.6, 1.2, 3.6), at(x, 0.6, 10.5), STONE, Enum.Material.Slate)
	end
	-- luci a festone sotto la gronda
	for i = -19, 19 do
		local x = i * 4
		local sag = 0.9 * math.abs(math.cos((x / 24) * math.pi))
		Util.sphere(cab, "Lampadina", V(x, 17.5 - sag, 11.4), 0.9, Color3.fromRGB(255, 214, 130), Enum.Material.Neon, false, { shadow = false })
	end
	local fest = Util.D(cab, "Filo", Vector3.new(160, 0.15, 0.15), at(0, 18, 11.4), Color3.fromRGB(30, 30, 36), SM, 0, { shadow = false })
	fest.Name = "FiloLuci"
	-- luci calde dentro e fuori
	local lamps = Util.folder(cab, "Lampade")
	for _, p in ipairs({ V(-40, 18, -30), V(40, 18, -30), V(0, 18, -44), V(-45, 15, 30), V(45, 15, 30) }) do
		local lp = Util.sphere(lamps, "Lampada", p, 2.4, Color3.fromRGB(255, 226, 170), Enum.Material.Neon, false, { shadow = false })
		pointLight(lp, Color3.fromRGB(255, 200, 140), 44, 1.1)
	end
end

----------------------------------------------------------------------
-- Interni: camino, panche, trofeo, cartelli
----------------------------------------------------------------------
local function bench(parent, x, z, facingDir)
	local base = facing(V(x, 0, z), facingDir)
	Util.P(parent, "Sedile", Vector3.new(14, 1, 3.6), base * CFrame.new(0, 2.6, 0), LOG, WOOD)
	Util.P(parent, "Schienale", Vector3.new(14, 3, 0.8), base * CFrame.new(0, 4.6, 1.5), LOG_DARK, WOOD)
	for _, lx in ipairs({ -6, 6 }) do
		Util.P(parent, "Gamba", Vector3.new(1, 2.4, 3), base * CFrame.new(lx, 1.2, 0), LOG_DARK, Enum.Material.Wood)
	end
end

local function interior(f)
	local int = Util.folder(f, "Interni")
	-- camino in pietra nell'angolo posteriore sinistro, con fuoco acceso
	Util.P(int, "Camino", Vector3.new(14, 14, 8), at(-72, 7, -51), STONE, Enum.Material.Slate)
	Util.P(int, "Cappa", Vector3.new(9, 22, 6), at(-72, 25, -52), STONE, Enum.Material.Slate)
	Util.D(int, "Focolare", Vector3.new(8, 6.5, 0.6), at(-72, 3.6, -46.7), Color3.fromRGB(26, 20, 22), SM, 0, { shadow = false })
	for _, dz in ipairs({ -1.2, 1.2 }) do
		Util.rod(int, "Ceppo", V(-75.5, 1, -45.4 + dz), V(-68.5, 1.4, -45.4 + dz), 1.2, Color3.fromRGB(70, 44, 30), Enum.Material.Wood, false, { shadow = false })
	end
	local flame = Util.D(int, "Fiamma", Vector3.new(3, 3, 1), at(-72, 2.4, -45.4), Color3.new(1, 1, 1), SM, 1, { shadow = false })
	local fire = Instance.new("Fire")
	fire.Heat = 6
	fire.Size = 5
	fire.Color = Color3.fromRGB(255, 150, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 70, 20)
	fire.Parent = flame
	pointLight(flame, Color3.fromRGB(255, 160, 90), 34, 1.6)

	-- panche davanti alla vetrata e due sul terrazzo
	bench(int, -50, -2, Vector3.new(0, 0, 1))
	bench(int, 50, -2, Vector3.new(0, 0, 1))
	bench(int, -62, 50, Vector3.new(0, 0, 1))
	bench(int, 62, 50, Vector3.new(0, 0, 1))

	-- trofeo con faretto
	local tx, tz = 0, -48
	Util.pillar(int, "PiedistalloTrofeo", c.X + tx, c.Y, c.Z + tz, 7, 3.2, Color3.fromRGB(86, 66, 120), SM, true)
	Util.pillar(int, "PiedistalloTrofeoAnello", c.X + tx, c.Y + 3.2, c.Z + tz, 7.6, 0.5, Color3.fromRGB(190, 132, 255), Enum.Material.Neon, false, { shadow = false })
	Util.pillar(int, "TrofeoStelo", c.X + tx, c.Y + 3.7, c.Z + tz, 1.1, 2.6, GOLD, Enum.Material.Metal, false)
	Util.pillar(int, "TrofeoCoppa", c.X + tx, c.Y + 6.3, c.Z + tz, 4.6, 3.6, GOLD, Enum.Material.Metal, false)
	for _, sx in ipairs({ -1, 1 }) do
		Util.sphere(int, "TrofeoManico", V(tx + sx * 2.7, 8.2, tz), 1.6, GOLD, Enum.Material.Metal, false, { shadow = false })
	end
	Util.sphere(int, "TrofeoPomo", V(tx, 10.4, tz), 1.8, Color3.fromRGB(255, 244, 200), Enum.Material.Neon, false, { shadow = false })
	local spot = Util.D(int, "FarettoTrofeo", Vector3.new(2, 1, 2), at(tx, 21, tz + 2) * CFrame.Angles(-math.pi / 2, 0, 0), STEEL, Enum.Material.Metal, 0, { shadow = false })
	local sl = Instance.new("SpotLight")
	sl.Face = Enum.NormalId.Front
	sl.Brightness = 3
	sl.Range = 40
	sl.Angle = 40
	sl.Color = Color3.fromRGB(255, 230, 170)
	sl.Shadows = false
	sl.Parent = spot

	-- cartelli sulla parete di fondo e sulla parete sinistra
	local north = Vector3.new(0, 0, 1)
	board(int, "Titolo", V(0, 17, -54.7), north, Vector3.new(70, 9, 0.8), CREAM, "CALCIO FUORILEGGE", Color3.fromRGB(70, 44, 30), 30)
	board(int, "Invito", V(0, 11, -54.7), north, Vector3.new(58, 4.4, 0.8), CREAM, "Sali su una pedana per scegliere la squadra", Color3.fromRGB(150, 54, 48), 34)
	local lb = board(int, "LeaderboardSign", V(-46, 9, -54.7), north, Vector3.new(30, 16, 0.8), CREAM, "CLASSIFICHE\n(in arrivo)", Color3.fromRGB(70, 44, 30), 30)
	lb.Name = "LeaderboardSign"
	board(
		int,
		"Comandi",
		V(48, 9, -54.7),
		north,
		Vector3.new(36, 17, 0.8),
		CREAM,
		"COMANDI\nClic sinistro: tiro (tieni premuto)\nClic destro: passaggio\nQ scavetto  -  F pallonetto\nE scivolata  -  Spazio dribbling/scatto\nMaiusc corsa  -  R chiama palla\nL torna in lobby",
		Color3.fromRGB(70, 44, 30),
		34
	)
	board(int, "Regole", V(-79.5, 12, -30), Vector3.new(1, 0, 0), Vector3.new(26, 14, 0.8), CREAM, "REGOLE\n4 contro 4 - 6 minuti\nNiente falli!\nVince chi segna di piu'", Color3.fromRGB(70, 44, 30), 34)
end

----------------------------------------------------------------------
-- Pedane squadra
----------------------------------------------------------------------
local function chevron(parent, tip, dir, col, y)
	-- freccia a "V" con la punta in tip che guarda verso dir
	for _, s in ipairs({ -1, 1 }) do
		local a = math.rad(36) * s
		local vx, vz = -dir.X, -dir.Z
		local back = Vector3.new(vx * math.cos(a) - vz * math.sin(a), 0, vx * math.sin(a) + vz * math.cos(a)).Unit
		Util.beam(parent, "Freccia", Vector3.new(tip.X, y, tip.Z), Vector3.new(tip.X + back.X * 3.4, y, tip.Z + back.Z * 3.4), 0.9, 0.1, col, Enum.Material.Neon, false, { shadow = false })
	end
end

local function pad(f, name, teamKey, x)
	local t = Config.Teams[teamKey]
	local pads = f.Pads
	local deco = f.PadDecor
	local z = 30
	local top = 0.8
	-- base scura + pedana (questa e' la parte che il server controlla: attributo TeamKey)
	Util.P(deco, "BasePedana", Vector3.new(29, 0.5, 29), at(x, 0.25, z), STEEL, SM)
	local p = Util.P(pads, name, Vector3.new(26, 0.8, 26), at(x, 0.4 + 0.25, z), t.Color, SM)
	p:SetAttribute("TeamKey", teamKey)
	local edge = Util.shade(t.Color, 1.0)
	for _, s in ipairs({ -1, 1 }) do
		Util.D(deco, "BordoPedana", Vector3.new(26.6, 0.4, 0.7), at(x, 1.2, z + s * 13), edge, Enum.Material.Neon, 0, { shadow = false })
		Util.D(deco, "BordoPedana", Vector3.new(0.7, 0.4, 26.6), at(x + s * 13, 1.2, z), edge, Enum.Material.Neon, 0, { shadow = false })
	end
	local yTop = c.Y + 0.65 + top / 2 + 0.05
	-- pallone al centro: disco bianco, pentagono scuro, cuciture e macchie sul bordo
	local cx, cz = c.X + x, c.Z + z
	local dark = Color3.fromRGB(34, 34, 44)
	local function disc(d, col, dx, dz, dy)
		Util.D(deco, "Pallone", Vector3.new(0.1, d, d), CFrame.new(cx + dx, yTop + dy, cz + dz) * CFrame.Angles(0, 0, math.pi / 2), col, SM, 0, { shape = Enum.PartType.Cylinder, shadow = false })
	end
	disc(11.6, Color3.fromRGB(246, 246, 250), 0, 0, 0.03)
	disc(3.6, dark, 0, 0, 0.06)
	for i = 0, 4 do
		local a1 = i * math.pi * 2 / 5 - math.pi / 2
		local a2 = (i + 1) * math.pi * 2 / 5 - math.pi / 2
		local R = 2.2
		-- lato del pentagono
		Util.beam(deco, "Pentagono", Vector3.new(cx + math.cos(a1) * R, yTop + 0.07, cz + math.sin(a1) * R), Vector3.new(cx + math.cos(a2) * R, yTop + 0.07, cz + math.sin(a2) * R), 0.7, 0.05, dark, SM, false, { shadow = false })
		-- cucitura dal vertice verso il bordo e macchia di fine cucitura
		Util.beam(deco, "Cucitura", Vector3.new(cx + math.cos(a1) * R, yTop + 0.07, cz + math.sin(a1) * R), Vector3.new(cx + math.cos(a1) * 3.9, yTop + 0.07, cz + math.sin(a1) * 3.9), 0.35, 0.05, dark, SM, false, { shadow = false })
		disc(1.9, dark, math.cos(a1) * 4.7, math.sin(a1) * 4.7, 0.06)
	end
	-- frecce ai lati che indicano il centro (davanti e dietro ci sono le scritte)
	for _, d in ipairs({ Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0) }) do
		local tip = Vector3.new(cx - d.X * 8.4, 0, cz - d.Z * 8.4)
		chevron(deco, tip, d, Color3.fromRGB(255, 255, 255), yTop + 0.06)
	end
	-- scritte (si leggono guardando il campo): nome squadra sul lato lontano, contatore su quello vicino
	local yawRead = CFrame.Angles(0, math.pi, 0)
	local nameP = Util.D(deco, "NomeSquadra", Vector3.new(20, 0.1, 5), CFrame.new(cx, yTop + 0.05, cz + 9.4) * yawRead, t.Color, SM, 1, { shadow = false })
	Util.label(nameP, Enum.NormalId.Top, string.upper(t.Name), { font = Enum.Font.GothamBlack, color = Color3.fromRGB(255, 255, 255), pps = 36 })
	local counter = Util.D(p, "Contatore", Vector3.new(10, 0.1, 3.4), CFrame.new(cx, yTop + 0.05, cz - 9.6) * yawRead, t.Color, SM, 1, { shadow = false })
	Util.label(counter, Enum.NormalId.Top, "0 / " .. tostring(Config.Match.MaxPerTeam), { font = Enum.Font.GothamBlack, color = Color3.fromRGB(255, 255, 255), pps = 36, name = "Conteggio", guiName = "Gui" })
	counter.Name = "Contatore"
	return p
end

----------------------------------------------------------------------
-- Telescopi puntati sul campo
----------------------------------------------------------------------
local function telescopes(f)
	local t = Util.folder(f, "Telescopi")
	for _, x in ipairs({ -24, 24 }) do
		local base = V(x, 0, 52)
		for k = 0, 2 do
			local a = k * math.pi * 2 / 3
			Util.rod(t, "Gamba", base + Vector3.new(math.cos(a) * 1.8, 0, math.sin(a) * 1.8), base + Vector3.new(0, 4.4, 0), 0.4, STEEL, Enum.Material.Metal, false, { shadow = false })
		end
		local tube0 = base + Vector3.new(0, 4.8, -1.8)
		local tube1 = base + Vector3.new(0, 6.4, 3.6)
		Util.rod(t, "Tubo", tube0, tube1, 1.5, Color3.fromRGB(190, 160, 70), Enum.Material.Metal, false, { shadow = false })
		Util.rod(t, "Lente", tube1, tube1 + (tube1 - tube0).Unit * 0.4, 1.9, Color3.fromRGB(120, 200, 240), Enum.Material.Glass, false, { shadow = false })
	end
end

function LobbyBuilder.Build(root)
	local f = Util.folder(root, "Lobby")
	Util.folder(f, "Pads")
	Util.folder(f, "PadDecor")
	deck(f)
	rails(f)
	cabin(f)
	interior(f)
	pad(f, "RedPad", "Red", -34)
	pad(f, "BluePad", "Blue", 34)
	telescopes(f)

	-- punto di rinascita neutro (le posizioni vere le decide Match tramite LobbySpawnCFrame)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = at(0, 0.5, 20)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = f
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	return f
end

return LobbyBuilder
