-- Lo stadio intorno al campo: piazza, pareti di vetro con tabelloni pubblicitari, tribune con tifosi,
-- tabelloni segnapunti, torri faro e angoli arrotondati.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local Layout = require(script.Parent.Layout)

local Arena = {}

local HL, HW = Layout.HL, Layout.HW
local XB, WH = Layout.XB, Layout.WALL_H
local ST = Layout.STAND

local SM = Enum.Material.SmoothPlastic

local STEEL = Color3.fromRGB(40, 44, 66)
local STEEL_LIGHT = Color3.fromRGB(78, 84, 112)
local LILAC = Color3.fromRGB(190, 132, 255)
local SAND_A = Color3.fromRGB(216, 178, 132)
local SAND_B = Color3.fromRGB(198, 158, 112)
local TERRACOTTA = Color3.fromRGB(190, 108, 78)
local NEON = {
	Color3.fromRGB(70, 220, 255),
	Color3.fromRGB(255, 80, 170),
	Color3.fromRGB(255, 196, 70),
	Color3.fromRGB(150, 255, 120),
	Color3.fromRGB(190, 132, 255),
}
local ADS = {
	"CACTUS CUP",
	"DUNE ENERGY",
	"MESA BURGER",
	"SOLE 24",
	"FUORILEGGE TV",
	"CANYON BANK",
	"ROSSA SPRING",
	"SABBIA & CO",
	"POLVERE KART",
	"OASI HOTEL",
}

----------------------------------------------------------------------
-- Piazza: pavimento di lastre intorno allo stadio
----------------------------------------------------------------------
local function plaza(folder)
	local PX, PZ = Layout.PLAZA_X, Layout.PLAZA_Z
	local stone = Color3.fromRGB(206, 170, 132)
	Util.P(folder, "Piazza", Vector3.new(2 * PX, 8, 2 * PZ), CFrame.new(0, -4, 0), stone, Enum.Material.Concrete)
	-- cordolo scuro sul bordo
	local curb = Color3.fromRGB(150, 104, 80)
	Util.D(folder, "Cordolo", Vector3.new(2 * PX + 6, 2.6, 3), CFrame.new(0, -0.7, -PZ - 1.5), curb, Enum.Material.Concrete, 0, { shadow = false })
	Util.D(folder, "Cordolo", Vector3.new(2 * PX + 6, 2.6, 3), CFrame.new(0, -0.7, PZ + 1.5), curb, Enum.Material.Concrete, 0, { shadow = false })
	Util.D(folder, "Cordolo", Vector3.new(3, 2.6, 2 * PZ), CFrame.new(-PX - 1.5, -0.7, 0), curb, Enum.Material.Concrete, 0, { shadow = false })
	Util.D(folder, "Cordolo", Vector3.new(3, 2.6, 2 * PZ), CFrame.new(PX + 1.5, -0.7, 0), curb, Enum.Material.Concrete, 0, { shadow = false })
	-- fughe delle lastre
	local joint = Color3.fromRGB(168, 130, 100)
	for x = -PX + 24, PX - 24, 24 do
		Util.D(folder, "Fuga", Vector3.new(0.35, 0.06, 2 * PZ - 6), CFrame.new(x, 0.03, 0), joint, Enum.Material.SmoothPlastic, 0.45, { shadow = false })
	end
	for z = -PZ + 26, PZ - 26, 26 do
		Util.D(folder, "Fuga", Vector3.new(2 * PX - 6, 0.06, 0.35), CFrame.new(0, 0.03, z), joint, Enum.Material.SmoothPlastic, 0.45, { shadow = false })
	end
	-- grandi stemmi colorati dietro le porte (la scritta si legge guardando il campo)
	for _, s in ipairs({ -1, 1 }) do
		local key = (s < 0) and "Red" or "Blue"
		local t = Config.Teams[key]
		local cx = s * (XB + 36)
		Util.D(folder, "StemmaAnello", Vector3.new(0.14, 47, 47), CFrame.new(cx, 0.06, 0) * CFrame.Angles(0, 0, math.pi / 2), t.Color, Enum.Material.Neon, 0, { shape = Enum.PartType.Cylinder, shadow = false })
		Util.D(folder, "Stemma", Vector3.new(0.16, 43, 43), CFrame.new(cx, 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2), Util.shade(t.Color, 0.5), Enum.Material.SmoothPlastic, 0, { shape = Enum.PartType.Cylinder, shadow = false })
		local board = Util.D(folder, "StemmaTesto", Vector3.new(36, 0.1, 14), CFrame.new(cx, 0.2, 0) * CFrame.Angles(0, -s * math.pi / 2, 0), t.Color, Enum.Material.SmoothPlastic, 1, { shadow = false })
		Util.label(board, Enum.NormalId.Top, string.upper(t.Name), { font = Enum.Font.GothamBlack, color = Color3.fromRGB(255, 244, 236), pps = 24 })
	end
end

----------------------------------------------------------------------
-- Pareti di vetro (collisione) con telaio, rotaie luminose, tabelloni e angoli smussati
----------------------------------------------------------------------
local function ads(folder)
	local n = 0
	-- tabellone luminoso a filo del vetro, con la scritta verso il campo (faccia Front dopo lookAt)
	local function board(pos, faceDir, text, col)
		local cf = CFrame.lookAt(pos, pos + faceDir)
		local p = Util.D(folder, "Pubblicita", Vector3.new(20.4, 3.6, 0.8), cf, Color3.fromRGB(22, 24, 42), Enum.Material.SmoothPlastic, 0, { shadow = false })
		Util.D(folder, "PubblicitaLuce", Vector3.new(20.4, 0.26, 0.95), cf * CFrame.new(0, 1.9, 0), col, Enum.Material.Neon, 0, { shadow = false })
		Util.label(p, Enum.NormalId.Front, text, { font = Enum.Font.GothamBlack, color = col, pps = 22 })
	end
	for i = -5, 4 do
		local x = i * 22 + 11
		n = n + 1
		board(Vector3.new(x, 1.9, -(HW + 0.4)), Vector3.new(0, 0, 1), ADS[(n % #ADS) + 1], NEON[(n % #NEON) + 1])
		n = n + 1
		board(Vector3.new(x, 1.9, HW + 0.4), Vector3.new(0, 0, -1), ADS[(n % #ADS) + 1], NEON[(n % #NEON) + 1])
	end
	-- testate: pubblicita' ai lati della porta
	for _, s in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -48, -26, 26, 48 }) do
			n = n + 1
			board(Vector3.new(s * (XB + 0.4), 1.9, z), Vector3.new(-s, 0, 0), ADS[(n % #ADS) + 1], NEON[(n % #NEON) + 1])
		end
	end
end

local function walls(folder)
	local glass = Color3.fromRGB(226, 236, 255)
	local wallProps = PhysicalProperties.new(0.7, 0.2, 0.85, 100, 100)
	local function wall(size, pos)
		local w = Util.P(folder, "Vetro", size, CFrame.new(pos), glass, Enum.Material.Glass, 0.88, { shadow = false })
		w.CustomPhysicalProperties = wallProps
		w.CanQuery = false
		return w
	end
	-- pareti di collisione (identiche a prima: la palla rimbalza qui)
	wall(Vector3.new(2 * XB + 4, WH, 2), Vector3.new(0, WH / 2, -HW - 1))
	wall(Vector3.new(2 * XB + 4, WH, 2), Vector3.new(0, WH / 2, HW + 1))
	wall(Vector3.new(2, WH, 2 * HW + 4), Vector3.new(-XB - 1, WH / 2, 0))
	wall(Vector3.new(2, WH, 2 * HW + 4), Vector3.new(XB + 1, WH / 2, 0))
	local roof = Util.P(folder, "Soffitto", Vector3.new(2 * XB + 4, 2, 2 * HW + 4), CFrame.new(0, WH + 15, 0), glass, Enum.Material.Glass, 1, { shadow = false })
	roof.CustomPhysicalProperties = wallProps
	roof.CanQuery = false

	-- angoli smussati: la palla non resta incastrata e il campo "respira"
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local d = Util.P(folder, "Angolo", Vector3.new(14.14, WH, 1.5), CFrame.new(sx * (XB - 5), WH / 2, sz * (HW - 5)) * CFrame.Angles(0, sx * sz * math.pi / 4, 0), glass, Enum.Material.Glass, 0.7, { shadow = false })
			d.CustomPhysicalProperties = wallProps
			d.CanQuery = false
			Util.D(folder, "AngoloLuce", Vector3.new(14.14, 0.5, 0.7), CFrame.new(sx * (XB - 5), WH + 0.2, sz * (HW - 5)) * CFrame.Angles(0, sx * sz * math.pi / 4, 0), LILAC, Enum.Material.Neon, 0, { shadow = false })
			-- pilastro d'angolo con faro
			local px, pz = sx * (XB + 3.6), sz * (HW + 3.6)
			Util.pillar(folder, "Pilastro", px, 0, pz, 7, WH + 8, Color3.fromRGB(196, 146, 108), Enum.Material.Sandstone, true, { shadow = true })
			Util.pillar(folder, "PilastroAnello", px, WH - 4, pz, 7.6, 1.2, LILAC, Enum.Material.Neon, false, { shadow = false })
			Util.pillar(folder, "PilastroCappello", px, WH + 8, pz, 8, 1.4, STEEL, Enum.Material.Metal, false)
			local beacon = Util.sphere(folder, "Faro", Vector3.new(px, WH + 11, pz), 4, Color3.fromRGB(255, 226, 170), Enum.Material.Neon, false, { shadow = false })
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 210, 160)
			light.Range = 34
			light.Brightness = 1.4
			light.Shadows = false
			light.Parent = beacon
		end
	end

	-- telaio d'acciaio: montanti ogni 22 stud e rotaia luminosa in alto
	for x = -98, 98, 28 do
		for _, sz in ipairs({ -1, 1 }) do
			Util.D(folder, "Montante", Vector3.new(1.1, WH + 1, 1.1), CFrame.new(x, (WH + 1) / 2, sz * (HW + 2.9)), STEEL, Enum.Material.Metal, 0, { shadow = false })
		end
	end
	for z = -42, 42, 28 do
		for _, sx in ipairs({ -1, 1 }) do
			Util.D(folder, "Montante", Vector3.new(1.1, WH + 1, 1.1), CFrame.new(sx * (XB + 2.9), (WH + 1) / 2, z), STEEL, Enum.Material.Metal, 0, { shadow = false })
		end
	end
	for _, sz in ipairs({ -1, 1 }) do
		Util.D(folder, "Rotaia", Vector3.new(2 * XB + 8, 0.8, 0.8), CFrame.new(0, WH + 0.4, sz * (HW + 2.2)), LILAC, Enum.Material.Neon, 0, { shadow = false })
		Util.D(folder, "Trave", Vector3.new(2 * XB + 8, 1.2, 1.6), CFrame.new(0, WH + 1.2, sz * (HW + 2.9)), STEEL, Enum.Material.Metal, 0, { shadow = false })
		Util.D(folder, "TraveBassa", Vector3.new(2 * XB + 8, 1, 1.6), CFrame.new(0, 4.2, sz * (HW + 2.9)), STEEL, Enum.Material.Metal, 0, { shadow = false })
	end
	for _, sx in ipairs({ -1, 1 }) do
		Util.D(folder, "Rotaia", Vector3.new(0.8, 0.8, 2 * HW + 8), CFrame.new(sx * (XB + 2.2), WH + 0.4, 0), LILAC, Enum.Material.Neon, 0, { shadow = false })
		Util.D(folder, "Trave", Vector3.new(1.6, 1.2, 2 * HW + 8), CFrame.new(sx * (XB + 2.9), WH + 1.2, 0), STEEL, Enum.Material.Metal, 0, { shadow = false })
		Util.D(folder, "TraveBassa", Vector3.new(1.6, 1, 2 * HW + 8), CFrame.new(sx * (XB + 2.9), 4.2, 0), STEEL, Enum.Material.Metal, 0, { shadow = false })
	end

	-- tabellone di squadra sopra ogni porta (solo luce, niente ombra)
	for _, s in ipairs({ -1, 1 }) do
		local key = (s < 0) and "Red" or "Blue"
		local t = Config.Teams[key]
		local pos = Vector3.new(s * (XB + 4.6), 30, 0)
		local cf = CFrame.lookAt(pos, pos + Vector3.new(-s, 0, 0))
		local p = Util.D(folder, "TabelloneSquadra", Vector3.new(40, 11, 1), cf, Color3.fromRGB(24, 20, 38), Enum.Material.SmoothPlastic, 0, { shadow = false })
		Util.D(folder, "TabelloneSquadraBordo", Vector3.new(41, 0.6, 1.3), cf * CFrame.new(0, 5.8, -0.1), t.Color, Enum.Material.Neon, 0, { shadow = false })
		Util.D(folder, "TabelloneSquadraBordo", Vector3.new(41, 0.6, 1.3), cf * CFrame.new(0, -5.8, -0.1), t.Color, Enum.Material.Neon, 0, { shadow = false })
		Util.label(p, Enum.NormalId.Front, string.upper(t.Name), { font = Enum.Font.GothamBlack, color = t.Color, pps = 26 })
	end

	ads(folder)
end

----------------------------------------------------------------------
-- Tribune: gradoni di pietra con tifosi, tetto, pannelli, tabellone segnapunti
----------------------------------------------------------------------
local FAN_COLORS = {
	Color3.fromRGB(214, 56, 48),
	Color3.fromRGB(238, 96, 66),
	Color3.fromRGB(176, 36, 60),
	Color3.fromRGB(36, 120, 230),
	Color3.fromRGB(86, 176, 255),
	Color3.fromRGB(30, 80, 190),
	Color3.fromRGB(240, 240, 240),
	Color3.fromRGB(250, 210, 60),
	Color3.fromRGB(60, 170, 90),
	Color3.fromRGB(150, 80, 210),
}
local SKINS = {
	Color3.fromRGB(255, 214, 170),
	Color3.fromRGB(234, 176, 128),
	Color3.fromRGB(196, 134, 92),
	Color3.fromRGB(128, 84, 58),
}

local function scoreboard(folder, sz, backZ)
	local pos = Vector3.new(0, 47, sz * (backZ + 0.2))
	local face = Enum.NormalId.Front
	-- torre di sostegno
	Util.P(folder, "TorreTabellone", Vector3.new(76, 40, 3), CFrame.new(0, 20, sz * (backZ + 1.6)), TERRACOTTA, Enum.Material.Concrete)
	local board = Util.P(folder, "Tabellone", Vector3.new(66, 24, 2), CFrame.lookAt(pos, pos + Vector3.new(0, 0, -sz)), Color3.fromRGB(18, 18, 32), Enum.Material.SmoothPlastic)
	board.CastShadow = false
	Util.tag(board, "Scoreboard")
	for _, dy in ipairs({ -12.6, 12.6 }) do
		Util.D(folder, "TabelloneBordo", Vector3.new(68, 1.2, 2.4), CFrame.new(pos + Vector3.new(0, dy, 0)), LILAC, Enum.Material.Neon, 0, { shadow = false })
	end
	for _, dx in ipairs({ -33.6, 33.6 }) do
		Util.D(folder, "TabelloneBordo", Vector3.new(1.2, 26, 2.4), CFrame.new(pos + Vector3.new(dx, 0, 0)), LILAC, Enum.Material.Neon, 0, { shadow = false })
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Gui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.Parent = board
	local function lab(name, text, color, px, py, sx, sy, font)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(px, py)
		l.Size = UDim2.fromScale(sx, sy)
		l.Font = font or Enum.Font.GothamBlack
		l.TextScaled = true
		l.TextColor3 = color
		l.Text = text
		l.Parent = gui
		return l
	end
	lab("Titolo", "CALCIO FUORILEGGE", Color3.fromRGB(255, 205, 90), 0.1, 0.03, 0.8, 0.17)
	lab("NomeRossi", string.upper(Config.Teams.Red.Name), Config.Teams.Red.Color, 0.03, 0.22, 0.31, 0.2)
	lab("PunteggioRossi", "0", Color3.fromRGB(255, 255, 255), 0.03, 0.42, 0.31, 0.52)
	lab("Tempo", "6:00", Color3.fromRGB(255, 196, 70), 0.36, 0.3, 0.28, 0.4)
	lab("Fase", "", Color3.fromRGB(190, 132, 255), 0.33, 0.72, 0.34, 0.18)
	lab("NomeBlu", string.upper(Config.Teams.Blue.Name), Config.Teams.Blue.Color, 0.66, 0.22, 0.31, 0.2)
	lab("PunteggioBlu", "0", Color3.fromRGB(255, 255, 255), 0.66, 0.42, 0.31, 0.52)
	-- due colonne di sostegno
	for _, dx in ipairs({ -26, 26 }) do
		Util.P(folder, "ColonnaTabellone", Vector3.new(5, 12, 5), CFrame.new(dx, 36, sz * (backZ + 1.6)), STEEL, Enum.Material.Metal)
	end
end

local function stand(folder, sz, rng)
	local f = Util.folder(folder, "Tribuna_" .. ((sz < 0) and "Sud" or "Nord"))
	local half = ST.HalfLen
	-- gradoni
	for i = 1, ST.Rows do
		local h = ST.Rise * i
		local zc = sz * (ST.Z0 + ST.Depth * (i - 0.5))
		Util.P(f, "Gradone", Vector3.new(2 * half, h, ST.Depth), CFrame.new(0, h / 2, zc), (i % 2 == 0) and SAND_A or SAND_B, Enum.Material.Concrete, 0, { shadow = false })
	end
	-- muro di fondo
	local backZ = Layout.STAND_BACK
	Util.P(f, "MuroFondo", Vector3.new(2 * half + 12, 26, 3), CFrame.new(0, 13, sz * (backZ + 1.5)), TERRACOTTA, Enum.Material.Concrete)
	Util.D(f, "MuroFondoLuce", Vector3.new(2 * half + 12, 0.8, 0.6), CFrame.new(0, 26.4, sz * (backZ - 0.2)), LILAC, Enum.Material.Neon, 0, { shadow = false })
	-- fianchi chiusi
	for _, sx in ipairs({ -1, 1 }) do
		Util.P(f, "Fianco", Vector3.new(3, 26, backZ - ST.Z0 + 2), CFrame.new(sx * (half + 4.5), 13, sz * ((backZ + ST.Z0) / 2)), TERRACOTTA, Enum.Material.Concrete)
	end

	-- tifosi: un corpo e una testa, a gruppi di colore
	local fans = Util.folder(f, "Tifosi")
	for i = 1, ST.Rows do
		local h = ST.Rise * i
		local z = sz * (ST.Z0 + ST.Depth * (i - 0.5))
		local x = -half + 3 + ((i % 2 == 0) and 3.2 or 0)
		while x < half - 3 do
			local aisle = math.abs((x + half) % 37 - 18) < 3.4
			if not aisle and rng.Next() > 0.2 then
				local body = rng.Pick(FAN_COLORS)
				local m = Instance.new("Model")
				m.Name = "Tifoso"
				local b = Util.D(m, "Corpo", Vector3.new(2, 3, 1.6), CFrame.new(x, h + 1.5, z), body, Enum.Material.SmoothPlastic, 0, { shadow = false })
				local hd = Util.sphere(m, "Testa", Vector3.new(x, h + 3.8, z), 1.7, rng.Pick(SKINS), Enum.Material.SmoothPlastic, false, { shadow = false })
				m.PrimaryPart = b
				m.Parent = fans
				Util.tag(m, "Fan")
				-- il corpo ricorda la sua fase, cosi' i tifosi non saltano tutti insieme
				m:SetAttribute("Fase", rng.Range(0, 6.28))
				m:SetAttribute("Salto", rng.Range(0.7, 1.4))
			end
			x = x + 6.2
		end
	end

	-- tetto con colonne e luce di bordo
	local roofY, roofZ = 29, sz * (backZ - 14)
	Util.P(f, "Tetto", Vector3.new(2 * half + 12, 1.4, 38), CFrame.new(0, roofY, roofZ) * CFrame.Angles(-sz * math.rad(8), 0, 0), Color3.fromRGB(244, 230, 206), Enum.Material.SmoothPlastic, 0, { shadow = true })
	Util.D(f, "TettoLuce", Vector3.new(2 * half + 12, 0.7, 0.7), CFrame.new(0, roofY - 2.6, sz * (backZ - 33)), LILAC, Enum.Material.Neon, 0, { shadow = false })
	for x = -half, half, 28 do
		Util.pillar(f, "Colonna", x, 0, sz * (backZ - 2.5), 2.4, 30, STEEL_LIGHT, Enum.Material.Metal, true)
	end
	-- striscioni di squadra appesi al muro di fondo
	local bannerCols = { Config.Teams.Red.Color, Config.Teams.Blue.Color, Color3.fromRGB(250, 210, 60), Color3.fromRGB(240, 240, 240) }
	local k = 0
	for x = -half + 12, half - 12, 24 do
		k = k + 1
		if math.abs(x) > 40 then
			Util.D(f, "Striscione", Vector3.new(7, 15, 0.4), CFrame.new(x, 15, sz * (backZ - 0.3)), bannerCols[(k % #bannerCols) + 1], Enum.Material.Fabric, 0, { shadow = false })
		end
	end

	scoreboard(f, sz, backZ)
	return f
end

----------------------------------------------------------------------
-- Torri faro (agganciabili col rampino)
----------------------------------------------------------------------
local function towers(folder)
	local t = Util.folder(folder, "TorriFaro")
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local x, z = sx * Layout.TOWER_X, sz * Layout.TOWER_Z
			local foot = Util.P(t, "Basamento", Vector3.new(10, 3, 10), CFrame.new(x, 1.5, z), Color3.fromRGB(186, 148, 118), Enum.Material.Concrete)
			local mast = Util.pillar(t, "Traliccio", x, 3, z, 3.4, 64, STEEL_LIGHT, Enum.Material.Metal, true)
			Util.tag(mast, "Grappable")
			Util.tag(foot, "Grappable")
			for _, y in ipairs({ 18, 36, 54 }) do
				Util.pillar(t, "Anello", x, y, z, 4.6, 0.9, STEEL, Enum.Material.Metal, false)
			end
			-- bancata di proiettori puntata sul centro del campo
			local top = Vector3.new(x, 70, z)
			local aim = CFrame.lookAt(top, Vector3.new(-sx * 20, 0, -sz * 10))
			local frame = Util.D(t, "Telaio", Vector3.new(21, 12, 1.6), aim, STEEL, Enum.Material.Metal, 0, { shadow = false })
			for row = 0, 1 do
				for col = -1, 1 do
					local lamp = Util.D(t, "Proiettore", Vector3.new(6, 4.6, 0.7), aim * CFrame.new(col * 6.6, (row - 0.5) * 5.4, -1.1), Color3.fromRGB(255, 244, 214), Enum.Material.Neon, 0, { shadow = false })
					if row == 0 and col == 0 then
						local sp = Instance.new("SpotLight")
						sp.Face = Enum.NormalId.Front
						sp.Brightness = 2.4
						sp.Range = 210
						sp.Angle = 78
						sp.Color = Color3.fromRGB(255, 236, 205)
						sp.Shadows = false
						sp.Parent = lamp
						-- fascio di luce (decorativo) fino a terra
						local a0 = Instance.new("Attachment")
						a0.Parent = lamp
						local target = Util.D(t, "BersaglioLuce", Vector3.new(1, 1, 1), CFrame.new(-sx * 38, 0.4, -sz * 16), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1, { shadow = false })
						local a1 = Instance.new("Attachment")
						a1.Parent = target
						local beam = Instance.new("Beam")
						beam.Attachment0 = a0
						beam.Attachment1 = a1
						beam.Width0 = 5
						beam.Width1 = 50
						beam.FaceCamera = true
						beam.LightEmission = 0.8
						beam.LightInfluence = 0
						beam.Segments = 1
						beam.Transparency = NumberSequence.new(0.9, 1)
						beam.Color = ColorSequence.new(Color3.fromRGB(255, 230, 190))
						beam.Parent = lamp
					end
				end
			end
			-- luce rossa di segnalazione in cima (lampeggia sul client)
			local red = Util.sphere(t, "LuceRossa", Vector3.new(x, 77.5, z), 2.2, Color3.fromRGB(255, 50, 50), Enum.Material.Neon, false, { shadow = false })
			Util.tag(red, "Blink")
			frame.Name = "TelaioProiettori"
		end
	end
end

----------------------------------------------------------------------
-- Effetti d'atmosfera: pulviscolo dorato nell'aria e cannoncini di coriandoli (sparano al goal, vedi Ambient)
----------------------------------------------------------------------
local function atmosphereFx(folder)
	local f = Util.folder(folder, "Atmosfera")
	-- pulviscolo che fluttua nella luce del tramonto sopra il campo
	local box = Util.D(f, "Polvere", Vector3.new(2 * XB - 4, 34, 2 * HW - 4), CFrame.new(0, 20, 0), Color3.new(1, 1, 1), SM, 1, { shadow = false })
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "Pulviscolo"
	dust.Rate = 16
	dust.Lifetime = NumberRange.new(6, 10)
	dust.Speed = NumberRange.new(0.3, 1.1)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Acceleration = Vector3.new(0.6, 0.15, 0)
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.15) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.55), NumberSequenceKeypoint.new(0.8, 0.6), NumberSequenceKeypoint.new(1, 1) })
	dust.Color = ColorSequence.new(Color3.fromRGB(255, 226, 170))
	dust.LightEmission = 0.6
	dust.Shape = Enum.ParticleEmitterShape.Box
	dust.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	dust.Parent = box

	-- coriandoli: spenti finche' il client non li fa partire (fase "Goal")
	local spots = {}
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			spots[#spots + 1] = Vector3.new(sx * (XB + 3.6), WH + 13, sz * (HW + 3.6))
		end
	end
	spots[#spots + 1] = Vector3.new(0, 36, -(Layout.STAND_BACK - 12))
	spots[#spots + 1] = Vector3.new(0, 36, Layout.STAND_BACK - 12)
	local colors = { Color3.fromRGB(235, 64, 52), Color3.fromRGB(41, 160, 255), Color3.fromRGB(255, 214, 70), Color3.fromRGB(255, 255, 255) }
	for _, pos in ipairs(spots) do
		local p = Util.D(f, "Coriandoli", Vector3.new(1, 1, 1), CFrame.new(pos), Color3.new(1, 1, 1), SM, 1, { shadow = false })
		Util.tag(p, "GoalBurst")
		for _, col in ipairs(colors) do
			local e = Instance.new("ParticleEmitter")
			e.Name = "Coriandolo"
			e.Enabled = false
			e.Rate = 0
			e.Lifetime = NumberRange.new(2.4, 3.6)
			e.Speed = NumberRange.new(34, 64)
			e.SpreadAngle = Vector2.new(48, 48)
			e.Acceleration = Vector3.new(0, -34, 0)
			e.Drag = 1
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.6) })
			e.Color = ColorSequence.new(col)
			e.LightEmission = 0.25
			e.Rotation = NumberRange.new(0, 360)
			e.RotSpeed = NumberRange.new(-260, 260)
			e.EmissionDirection = Enum.NormalId.Top
			e.Parent = p
		end
	end
end

function Arena.Build(root)
	local folder = Util.folder(root, "Arena")
	local rng = Util.Rng(1207)
	plaza(folder)
	walls(folder)
	stand(folder, -1, rng)
	stand(folder, 1, rng)
	towers(folder)
	pcall(atmosphereFx, folder)
	return folder
end

return Arena
