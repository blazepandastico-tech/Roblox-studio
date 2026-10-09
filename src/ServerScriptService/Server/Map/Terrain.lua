-- Il canyon: pavimento di sabbia, pareti di roccia a strati rosso/arancio, torri isolate, dune, fiume e il
-- belvedere della lobby. Tutto ricavato con le funzioni Fill* del Terrain, in modo ripetibile (niente Random).
-- Il canyon corre lungo X, come il campo; il sole al tramonto sta in fondo al canyon (asse X), cosi' le pareti
-- alte (lungo Z) non fanno ombra sullo stadio.
local Util = require(script.Parent.Util)
local Layout = require(script.Parent.Layout)

local Terrain = {}

local MAT = Enum.Material
local G = Layout.GROUND_Y
local T = workspace.Terrain

local COLORS = {
	[MAT.Sand] = Color3.fromRGB(238, 190, 128),
	[MAT.Sandstone] = Color3.fromRGB(226, 104, 56),
	[MAT.Rock] = Color3.fromRGB(176, 66, 48),
	[MAT.Limestone] = Color3.fromRGB(246, 206, 162),
	[MAT.Ground] = Color3.fromRGB(128, 76, 52),
	[MAT.Mud] = Color3.fromRGB(122, 66, 86),
	[MAT.Salt] = Color3.fromRGB(252, 224, 212),
	[MAT.Basalt] = Color3.fromRGB(84, 48, 70),
	[MAT.Slate] = Color3.fromRGB(132, 100, 142),
}

-- strati della roccia, dal basso: {quota inferiore, quota superiore, materiale}
local STRATA = {
	{ -20, 6, MAT.Sandstone },
	{ 6, 14, MAT.Mud },
	{ 14, 34, MAT.Rock },
	{ 34, 40, MAT.Salt },
	{ 40, 62, MAT.Sandstone },
	{ 62, 70, MAT.Limestone },
	{ 70, 96, MAT.Rock },
	{ 96, 102, MAT.Salt },
	{ 102, 132, MAT.Sandstone },
	{ 132, 140, MAT.Mud },
	{ 140, 164, MAT.Rock },
	{ 164, 172, MAT.Limestone },
	{ 172, 210, MAT.Sandstone },
	{ 210, 220, MAT.Salt },
	{ 220, 300, MAT.Rock },
}

local ops = 0
local function pace()
	ops = ops + 1
	if ops % 20 == 0 then
		task.wait()
	end
end
local function block(cf, size, mat)
	T:FillBlock(cf, size, mat)
	pace()
end
local function ball(center, r, mat)
	T:FillBall(center, r, mat)
	pace()
end
local function cyl(cf, h, r, mat)
	T:FillCylinder(cf, h, r, mat)
	pace()
end

-- colonna di roccia a strati con la cima sabbiosa
local function column(cx, cz, r, top)
	for _, b in ipairs(STRATA) do
		local y0, y1 = b[1], math.min(b[2], top)
		if y1 > y0 then
			cyl(CFrame.new(cx, (y0 + y1) / 2, cz), y1 - y0, r, b[3])
		end
	end
	cyl(CFrame.new(cx, top - 2, cz), 4, r, MAT.Sand)
end

-- blocco rettangolare ruotato, stessi strati (da quota "from" in su, per sovrapporre terrazze)
local function slab(cx, cz, sx, sz, yaw, top, from)
	local cap = CFrame.new(cx, top - 2, cz) * CFrame.Angles(0, yaw, 0)
	for _, b in ipairs(STRATA) do
		local y0, y1 = math.max(b[1], from or -1000), math.min(b[2], top)
		if y1 > y0 then
			block(CFrame.new(cx, (y0 + y1) / 2, cz) * CFrame.Angles(0, yaw, 0), Vector3.new(sx, y1 - y0, sz), b[3])
		end
	end
	block(cap, Vector3.new(sx, 4, sz), MAT.Sand)
end

local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

----------------------------------------------------------------------
local function ground()
	-- lastra di sabbia sottile: x da -1250 a 1250, z da -700 a 700, spessa 18 (da -20 a -2)
	for cx = -1000, 1000, 500 do
		for cz = -350, 350, 700 do
			block(CFrame.new(cx, G - 9, cz), Vector3.new(500, 18, 700), MAT.Sand)
		end
	end
	block(CFrame.new(-1375, G - 9, 0), Vector3.new(250, 18, 1400), MAT.Sand)
	block(CFrame.new(1375, G - 9, 0), Vector3.new(250, 18, 1400), MAT.Sand)
end

-- Pareti nord e sud: tre file di lastroni di roccia che si sovrappongono, sempre piu' alti e lontani
-- (prospettiva a strati), con terrazze sopra e falde di detriti ai piedi.
local ROWS = {
	{ face = 345, var = 55, len = 210, depth = 100, h = 90, hv = 80, hmax = 175 },
	{ face = 470, var = 70, len = 290, depth = 120, h = 150, hv = 90, hmax = 235 },
}

local function walls(s, rng)
	for ri, row in ipairs(ROWS) do
		local x = -1400 + rng.Range(0, 60)
		while x < 1400 do
			local len = row.len * rng.Range(0.8, 1.3)
			local depth = row.depth * rng.Range(0.85, 1.2)
			local cx = x + len / 2
			local face = row.face + row.var * Util.fbm(cx / 360 + ri * 3.7 + s * 5.1, ri * 1.9, 3)
			local h = row.h + row.hv * Util.fbm(cx / 240 + ri * 7.3 + s * 2.2, 9.1 + ri, 3) + rng.Range(-14, 14)
			-- la lobby (parete sud) sta incassata: la parete dietro il belvedere resta alta e arretrata
			if s < 0 then
				local blend = 1 - smooth((math.abs(cx) - 230) / 190)
				face = face + (row.face + 150 - face) * blend
				h = h + (row.h + row.hv * 0.75 - h) * blend * 0.8
			end
			h = math.clamp(h, 60, row.hmax)
			local yaw = rng.Range(-0.12, 0.12)
			slab(cx, s * (face + depth / 2), len, depth, yaw, h)
			-- terrazza piu' alta, arretrata
			if rng.Next() < 0.5 then
				local th = math.min(h + rng.Range(16, 40), row.hmax + 30)
				slab(cx + rng.Range(-len * 0.18, len * 0.18), s * (face + depth * 0.62), len * rng.Range(0.35, 0.6), depth * 0.55, yaw + rng.Range(-0.1, 0.1), th, h - 6)
			end
			-- detriti ai piedi della parete (solo la fila vicina)
			if ri == 1 then
				for k = -1, 1 do
					local r = rng.Range(24, 40)
					ball(Vector3.new(cx + k * len * 0.32 + rng.Range(-10, 10), G - r * 0.55, s * (face - 6 + rng.Range(0, 10))), r, (k == 0 and ri == 1 and rng.Next() < 0.5) and MAT.Sandstone or MAT.Sand)
				end
			end
			x = x + len * 0.78
		end
	end
end

-- Belvedere della lobby: una terrazza a meta' parete (la quota del pavimento e' Layout.LOBBY.Y)
local function ledge()
	local c = Layout.LOBBY
	local top = c.Y - 2
	local front = c.Z + 78 -- z della faccia anteriore (negativa: siamo a sud)
	slab(0, front - 70, 330, 140, 0, top)
	-- spigoli arrotondati davanti
	for _, dx in ipairs({ -165, 165 }) do
		column(dx, front - 36, 36, top)
	end
	-- detriti di falda ai piedi del belvedere
	for i = -5, 5 do
		local x = i * 36 + ((i % 2 == 0) and 0 or 12)
		if math.abs(x - 120) > 40 then -- lascia libero il punto dell'ascensore
			ball(Vector3.new(x, G - 15, front + 16 + ((i % 3) * 5)), 30 + (i % 3) * 3, (i % 3 == 0) and MAT.Sandstone or MAT.Sand)
		end
	end
end

-- Torri di roccia isolate (stile Monument Valley) dentro la valle: x, z, raggio, altezza
local BUTTES = {
	{ -380, 255, 40, 112 },
	{ -118, 290, 30, 86 },
	{ 176, 262, 46, 138 },
	{ 440, 238, 34, 102 },
	{ 700, 282, 42, 126 },
	{ -650, 268, 46, 122 },
	{ -940, 210, 52, 100 },
	{ 980, 190, 48, 96 },
	{ -430, -262, 36, 96 },
	{ -660, -236, 44, 118 },
	{ 470, -256, 38, 106 },
	{ 720, -276, 42, 114 },
	{ 1010, -210, 50, 98 },
	{ -1000, -170, 46, 90 },
	{ 1180, 20, 60, 70 },
	{ -1190, -10, 64, 76 },
}

local function buttes()
	for i, b in ipairs(BUTTES) do
		column(b[1], b[2], b[3], b[4])
		-- falda di sabbia/arenaria ai piedi
		ball(Vector3.new(b[1], G - b[3] * 0.4, b[2]), b[3] * 1.5, MAT.Sandstone)
		if i % 3 == 0 then
			-- seconda guglia accanto
			column(b[1] + b[3] * 1.3, b[2] + b[3] * 0.6, b[3] * 0.45, b[4] * 0.7)
		end
	end
end

-- Fiume turchese che attraversa la valle tra stadio e belvedere
local RIVER = {
	{ -1400, -196 },
	{ -980, -246 },
	{ -620, -214 },
	{ -300, -258 },
	{ 0, -226 },
	{ 300, -254 },
	{ 640, -208 },
	{ 980, -262 },
	{ 1400, -200 },
}

local function river()
	local depth = 8 -- il letto sta 8 stud sotto il terreno
	for i = 1, #RIVER - 1 do
		local a, b = RIVER[i], RIVER[i + 1]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local len = math.sqrt(dx * dx + dz * dz)
		local yaw = -math.atan2(dz, dx)
		local mid = Vector3.new((a[1] + b[1]) / 2, 0, (a[2] + b[2]) / 2)
		local base = CFrame.new(mid) * CFrame.Angles(0, yaw, 0)
		-- scavo, letto di fango e acqua (la superficie sta 1 stud sotto il terreno)
		block(base * CFrame.new(0, G - depth / 2 + 1, 0), Vector3.new(len + 24, depth + 4, 38), MAT.Air)
		block(base * CFrame.new(0, G - depth - 4, 0), Vector3.new(len + 24, 8, 38), MAT.Mud)
		block(base * CFrame.new(0, G - depth + 2.5, 0), Vector3.new(len + 24, 5, 36), MAT.Water)
	end
	for i = 2, #RIVER - 1 do
		local p = RIVER[i]
		cyl(CFrame.new(p[1], G - depth / 2 + 1, p[2]), depth + 4, 22, MAT.Air)
		cyl(CFrame.new(p[1], G - depth - 4, p[2]), 8, 22, MAT.Mud)
		cyl(CFrame.new(p[1], G - depth + 2.5, p[2]), 5, 20, MAT.Water)
	end
end

-- Macchie di terreno colorato: lago salato a est, fango secco a ovest, chiazze scure e chiare sparse
local function patches(rng)
	cyl(CFrame.new(790, G - 2, 40), 4, 140, MAT.Salt)
	cyl(CFrame.new(880, G - 2, -40), 4, 90, MAT.Salt)
	cyl(CFrame.new(-780, G - 2, -30), 4, 120, MAT.Mud)
	cyl(CFrame.new(-700, G - 2, 70), 4, 70, MAT.Ground)
	for i = 1, 22 do
		local x = rng.Range(-1000, 1000)
		local zs = (rng.Next() < 0.5) and -1 or 1
		local z = zs * rng.Range(185, 330)
		if not (zs < 0 and z > -300) and not (math.abs(x) < 230 and math.abs(z) < 260) then
			local mat = (i % 3 == 0) and MAT.Ground or ((i % 3 == 1) and MAT.Limestone or MAT.Mud)
			cyl(CFrame.new(x, G - 2, z), 4, rng.Range(26, 70), mat)
		end
	end
end

-- Dune: creste basse e lunghe (cilindri sdraiati mezzi sepolti)
local function dunes(rng)
	for i = 1, 26 do
		local side = (i % 2 == 0) and 1 or -1
		local x = rng.Range(-1100, 1100)
		local z = side * rng.Range(205, 320)
		-- tiene libero il passaggio tra stadio e belvedere e il letto del fiume
		local clear = true
		if side < 0 and z > -300 and z < -150 then
			clear = false
		end
		if clear and math.abs(x) < 240 and math.abs(z) < 260 then
			clear = false
		end
		if clear then
			local r = rng.Range(14, 26)
			local len = rng.Range(70, 160)
			local rise = rng.Range(3, 8)
			local yaw = rng.Range(-0.35, 0.35)
			cyl(CFrame.new(x, G - r + rise, z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, math.pi / 2), len, r, MAT.Sand)
		end
	end
end

-- Massi sparsi (solo estetica; quelli agganciabili col rampino sono parti, vedi Props)
local function rocks(rng)
	for i = 1, 48 do
		local x = rng.Range(-900, 900)
		local zs = (rng.Next() < 0.5) and -1 or 1
		local z = zs * rng.Range(190, 330)
		if not (zs < 0 and z > -300) and not (math.abs(x) < 240 and math.abs(z) < 260) then
			local r = rng.Range(3, 8)
			ball(Vector3.new(x, G + r * 0.15, z), r, (i % 3 == 0) and MAT.Basalt or MAT.Rock)
		end
	end
end

function Terrain.Build()
	-- gia' costruito (a mano da Studio con la Command Bar, oppure in questa sessione): non si rifa'
	if T:GetAttribute("CanyonBuilt") then
		return
	end
	local rng = Util.Rng(2024)
	for mat, col in pairs(COLORS) do
		T:SetMaterialColor(mat, col)
	end
	-- l'acqua ha impostazioni sue
	T.WaterColor = Color3.fromRGB(64, 196, 208)
	T.WaterTransparency = 0.55
	T.WaterReflectance = 0.35
	T.WaterWaveSize = 0.12
	T.WaterWaveSpeed = 8
	ground()
	walls(-1, rng)
	walls(1, rng)
	ledge()
	buttes()
	patches(rng)
	dunes(rng)
	rocks(rng)
	river()
	T:SetAttribute("CanyonBuilt", true)
end

return Terrain
