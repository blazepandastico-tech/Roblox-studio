-- Campo di terra a strisce con righe luminose bianco-lilla, aree di rigore colorate e stemma al centro.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local Layout = require(script.Parent.Layout)

local Pitch = {}

local HL, HW, GD = Layout.HL, Layout.HW, Layout.GD
local LINE_COLOR = Color3.fromRGB(236, 226, 255)
local LIGHT = Color3.fromRGB(198, 140, 94)
local DARK = Color3.fromRGB(158, 100, 64)

-- linea piatta tra due punti del campo (coordinate X,Z)
local function line(parent, x1, z1, x2, z2, thick)
	local dx, dz = x2 - x1, z2 - z1
	local len = math.sqrt(dx * dx + dz * dz)
	local t = thick or 0.7
	local mid = Vector3.new((x1 + x2) / 2, 0.14, (z1 + z2) / 2)
	return Util.D(parent, "Linea", Vector3.new(len + t, 0.06, t), CFrame.new(mid) * CFrame.Angles(0, -math.atan2(dz, dx), 0), LINE_COLOR, Enum.Material.Neon, 0, { shadow = false })
end

-- arco di circonferenza (angoli in radianti) fatto di segmenti
local function arc(parent, cx, cz, r, a0, a1, segs, thick)
	for i = 0, segs - 1 do
		local t0 = a0 + (a1 - a0) * (i / segs)
		local t1 = a0 + (a1 - a0) * ((i + 1) / segs)
		line(parent, cx + r * math.cos(t0), cz + r * math.sin(t0), cx + r * math.cos(t1), cz + r * math.sin(t1), thick)
	end
end

local function dot(parent, x, z, d)
	Util.D(parent, "Punto", Vector3.new(0.06, d, d), CFrame.new(x, 0.14, z) * CFrame.Angles(0, 0, math.pi / 2), LINE_COLOR, Enum.Material.Neon, 0, { shape = Enum.PartType.Cylinder, shadow = false })
end

function Pitch.Build(field)
	local surface = Util.folder(field, "Surface")
	local lines = Util.folder(field, "Lines")
	local decals = Util.folder(field, "Zones")

	-- terra battuta a strisce chiare/scure lungo X (superficie a quota PITCH_Y: la fisica della palla dipende da qui)
	local totalLen = 2 * Layout.XB + 4
	local stripes = 18
	local sw = totalLen / stripes
	for i = 0, stripes - 1 do
		local c = (i % 2 == 0) and LIGHT or DARK
		local s = Util.P(
			surface,
			"Striscia",
			Vector3.new(sw, 3, 2 * HW + 4),
			CFrame.new(-totalLen / 2 + sw * (i + 0.5), Layout.PITCH_Y - 1.5, 0),
			c,
			Enum.Material.Ground
		)
		s.CustomPhysicalProperties = PhysicalProperties.new(1, 0.55, 0.45, 50, 1)
		s.CastShadow = false
	end

	-- righe del campo
	line(lines, -HL, -HW, HL, -HW)
	line(lines, -HL, HW, HL, HW)
	line(lines, -HL, -HW, -HL, HW)
	line(lines, HL, -HW, HL, HW)
	line(lines, 0, -HW, 0, HW)
	arc(lines, 0, 0, 18, 0, math.pi * 2, 48, 0.6)
	dot(lines, 0, 0, 1.8)
	for _, s in ipairs({ -1, 1 }) do
		-- area di rigore e area piccola
		local px, pw = s * (HL - 22), 29
		line(lines, s * HL, -pw, px, -pw)
		line(lines, s * HL, pw, px, pw)
		line(lines, px, -pw, px, pw)
		local gx, gz = s * (HL - 8), 14
		line(lines, s * HL, -gz, gx, -gz)
		line(lines, s * HL, gz, gx, gz)
		line(lines, gx, -gz, gx, gz)
		dot(lines, s * (HL - 15), 0, 1.5)
		-- "luna" fuori dall'area: raggio 12 dal dischetto
		local a = math.acos(7 / 12)
		if s > 0 then
			arc(lines, s * (HL - 15), 0, 12, math.pi - a, math.pi + a, 12, 0.6)
		else
			arc(lines, s * (HL - 15), 0, 12, -a, a, 12, 0.6)
		end
		-- archi d'angolo
		for _, sz in ipairs({ -1, 1 }) do
			local cx, cz = s * HL, sz * HW
			local base = math.atan2(-sz, -s) -- verso l'interno del campo
			arc(lines, cx, cz, 4.5, base - math.pi / 4, base + math.pi / 4, 6, 0.55)
		end
	end

	-- aree colorate della squadra che difende (trasparenti, sopra la terra)
	for _, s in ipairs({ -1, 1 }) do
		local key = (s < 0) and "Red" or "Blue"
		local col = Config.Teams[key].Color
		local px = s * (HL - 11)
		Util.D(decals, "AreaRigore", Vector3.new(22, 0.1, 58), CFrame.new(px, 0.2, 0), col, Enum.Material.SmoothPlastic, 0.82, { shadow = false })
		Util.D(decals, "AreaPiccola", Vector3.new(8, 0.1, 28), CFrame.new(s * (HL - 4), 0.2, 0), col, Enum.Material.SmoothPlastic, 0.74, { shadow = false })
		-- fascia luminosa davanti alla porta: indica chi difende
		Util.D(decals, "FasciaPorta", Vector3.new(1.2, 0.07, Layout.GW), CFrame.new(s * (HL - 1.5), 0.17, 0), col, Enum.Material.Neon, 0, { shadow = false })
	end

	-- stemma al centro: sole a 12 raggi dentro il cerchio di centrocampo
	local sun = Util.folder(decals, "Stemma")
	local ray = Color3.fromRGB(226, 172, 120)
	for i = 0, 11 do
		local ang = (i / 12) * math.pi * 2
		local r0, r1 = 7.5, 15.5
		local mx, mz = math.cos(ang) * (r0 + r1) / 2, math.sin(ang) * (r0 + r1) / 2
		Util.D(sun, "Raggio", Vector3.new(r1 - r0, 0.06, (i % 2 == 0) and 1.8 or 1.0), CFrame.new(mx, 0.19, mz) * CFrame.Angles(0, -ang, 0), ray, Enum.Material.SmoothPlastic, 0.35, { shadow = false })
	end
	Util.D(sun, "Anello", Vector3.new(0.07, 13, 13), CFrame.new(0, 0.19, 0) * CFrame.Angles(0, 0, math.pi / 2), ray, Enum.Material.SmoothPlastic, 0.35, { shape = Enum.PartType.Cylinder, shadow = false })
	Util.D(sun, "Nucleo", Vector3.new(0.07, 7, 7), CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(150, 98, 64), Enum.Material.SmoothPlastic, 0.2, { shape = Enum.PartType.Cylinder, shadow = false })
end

return Pitch
