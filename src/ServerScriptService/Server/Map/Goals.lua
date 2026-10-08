-- Le due porte: pali spessi color pietra, rete a nido d'ape luminosa del colore della squadra che difende.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Util = require(script.Parent.Util)
local Layout = require(script.Parent.Layout)

local Goals = {}

local HL = Layout.HL
local STONE = Color3.fromRGB(156, 148, 140)
local STONE_DARK = Color3.fromRGB(112, 104, 100)
local STEEL = Color3.fromRGB(44, 46, 66)

-- Rete a nido d'ape su un pannello rettangolare. origin: X locale = larghezza, Y locale = altezza.
-- Ogni spigolo e' disegnato una sola volta (due esagoni vicini ne condividono uno).
local function hexNet(parent, origin, width, height, color, r)
	local dx = math.sqrt(3) * r
	local dy = 1.5 * r
	local halfW = math.sqrt(3) / 2 * r
	local umax = width / 2 - halfW
	local vmax = height / 2 - r
	if umax < 0 or vmax < 0 then
		return
	end
	local seen = {}
	local function edge(x1, y1, x2, y2)
		local a1, b1, a2, b2 = math.floor(x1 * 100 + 0.5), math.floor(y1 * 100 + 0.5), math.floor(x2 * 100 + 0.5), math.floor(y2 * 100 + 0.5)
		local k
		if a1 < a2 or (a1 == a2 and b1 <= b2) then
			k = a1 .. "," .. b1 .. "," .. a2 .. "," .. b2
		else
			k = a2 .. "," .. b2 .. "," .. a1 .. "," .. b1
		end
		if seen[k] then
			return
		end
		seen[k] = true
		local ex, ey = x2 - x1, y2 - y1
		local len = math.sqrt(ex * ex + ey * ey)
		local cf = origin * CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, 0) * CFrame.Angles(0, 0, math.atan2(ey, ex))
		Util.D(parent, "Maglia", Vector3.new(len + 0.12, 0.14, 0.14), cf, color, Enum.Material.Neon, 0, { shadow = false })
	end
	local rows = math.floor(2 * vmax / dy + 1e-6) + 1
	local rowSpan = (rows - 1) * dy
	local evenCols = math.floor(2 * umax / dx + 1e-6) + 1
	for row = 0, rows - 1 do
		local v = -rowSpan / 2 + row * dy
		local cols = evenCols
		local first = -(evenCols - 1) * dx / 2
		if row % 2 == 1 then
			cols = math.max(evenCols - 1, 1)
			first = -(cols - 1) * dx / 2
		end
		for c = 0, cols - 1 do
			local u = first + c * dx
			for k = 0, 5 do
				local a1 = math.rad(30 + 60 * k)
				local a2 = math.rad(30 + 60 * (k + 1))
				edge(u + r * math.cos(a1), v + r * math.sin(a1), u + r * math.cos(a2), v + r * math.sin(a2))
			end
		end
	end
end

local function buildGoal(parent, sign, teamKey)
	local color = Config.Teams[teamKey].Color
	local netColor = (teamKey == "Red") and Color3.fromRGB(255, 70, 150) or Color3.fromRGB(70, 190, 255)
	local g = Util.folder(parent, "Goal_" .. teamKey)
	local gw, gh, gd = Layout.GW, Layout.GH, Layout.GD
	local x = sign * HL
	local backX = sign * (HL + gd)
	local midX = sign * (HL + gd / 2)
	local postProps = PhysicalProperties.new(1, 0.3, 0.8, 100, 1)

	-- pali spessi di pietra (collidono)
	for _, s in ipairs({ -1, 1 }) do
		local post = Util.P(g, "Palo", Vector3.new(2.2, gh, 2.2), CFrame.new(x, gh / 2, s * gw / 2), STONE, Enum.Material.Slate)
		post.CustomPhysicalProperties = postProps
		-- basamento, fascia luminosa e cappello (solo estetica)
		Util.D(g, "Basamento", Vector3.new(3.4, 1.2, 3.4), CFrame.new(x, 0.6, s * gw / 2), STONE_DARK, Enum.Material.Slate)
		Util.D(g, "Fascia", Vector3.new(2.5, 0.5, 2.5), CFrame.new(x, gh - 1.6, s * gw / 2), netColor, Enum.Material.Neon, 0, { shadow = false })
		Util.D(g, "Cappello", Vector3.new(3, 0.8, 3), CFrame.new(x, gh + 1.2, s * gw / 2), STONE_DARK, Enum.Material.Slate)
		-- palo posteriore e travi del telaio
		Util.pillar(g, "PaloRetro", backX, 0, s * gw / 2, 1.2, gh, STEEL, Enum.Material.Metal, false)
		Util.beam(g, "TraveLaterale", Vector3.new(x, gh + 0.2, s * gw / 2), Vector3.new(backX, gh + 0.2, s * gw / 2), 0.9, 0.9, STEEL, Enum.Material.Metal, false)
		Util.beam(g, "BaseLaterale", Vector3.new(x, 0.45, s * gw / 2), Vector3.new(backX, 0.45, s * gw / 2), 0.9, 0.9, STEEL, Enum.Material.Metal, false)
	end
	local bar = Util.P(g, "Traversa", Vector3.new(2.2, 2.2, gw + 2.2), CFrame.new(x, gh, 0), STONE, Enum.Material.Slate)
	bar.CustomPhysicalProperties = postProps
	Util.D(g, "TraversaLuce", Vector3.new(0.5, 0.5, gw), CFrame.new(x - sign * 1.4, gh, 0), netColor, Enum.Material.Neon, 0, { shadow = false })
	Util.beam(g, "TraveRetro", Vector3.new(backX, gh + 0.2, -gw / 2), Vector3.new(backX, gh + 0.2, gw / 2), 0.9, 0.9, STEEL, Enum.Material.Metal, false)
	Util.beam(g, "BaseRetro", Vector3.new(backX, 0.45, -gw / 2), Vector3.new(backX, 0.45, gw / 2), 0.9, 0.9, STEEL, Enum.Material.Metal, false)

	-- pannelli di collisione quasi invisibili + nido d'ape luminoso
	local netProps = PhysicalProperties.new(1, 0.5, 0.35, 100, 1)
	local function panel(name, size, pos)
		local p = Util.P(g, name, size, CFrame.new(pos), netColor, Enum.Material.Neon, 0.88, { shadow = false })
		p.CustomPhysicalProperties = netProps
		p.CanQuery = false
		return p
	end
	local R = 2.0
	panel("RetePosteriore", Vector3.new(0.5, gh, gw), Vector3.new(backX, gh / 2, 0))
	hexNet(g, CFrame.new(backX - sign * 0.3, gh / 2, 0) * CFrame.Angles(0, math.pi / 2, 0), gw, gh, netColor, R)
	for _, s in ipairs({ -1, 1 }) do
		panel("ReteLato", Vector3.new(gd, gh, 0.5), Vector3.new(midX, gh / 2, s * gw / 2))
		hexNet(g, CFrame.new(midX, gh / 2, s * gw / 2 - s * 0.3), gd, gh, netColor, R)
	end
	panel("ReteTetto", Vector3.new(gd, 0.5, gw), Vector3.new(midX, gh, 0))
	hexNet(g, CFrame.new(midX, gh - 0.3, 0) * CFrame.Angles(math.pi / 2, 0, 0), gd, gw, netColor, R)

	-- tappeto scuro dentro la porta e striscia colorata della squadra che difende
	Util.D(g, "FondoPorta", Vector3.new(gd, 0.1, gw), CFrame.new(midX, 0.2, 0), Util.shade(color, 0.35), Enum.Material.SmoothPlastic, 0.35, { shadow = false })
	return g
end

function Goals.Build(field)
	-- porte: i Rossi difendono -X, i Blu +X
	buildGoal(field, -1, "Red")
	buildGoal(field, 1, "Blue")
end

return Goals
