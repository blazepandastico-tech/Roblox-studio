--[[
	HalloweenCostumes - i costumi dei giganti nel file di Halloween (solo aspetto)
	Li applica TitanBuilder alla fine della costruzione. Sono tutte decorazioni saldate al corpo che
	non si colpiscono (niente query): nuca, occhi e arti restano gli stessi di sempre, anche dentro
	la zucca (gli intagli degli occhi sono proprio davanti agli occhi veri).
	  Zucca     maschera di zucca intagliata con gli occhi che brillano
	  Strega    cappello a punta viola e nero con la fibbia
	  Zombie    pelle grigio-verde, cuciture e bende
	  Corna     corna da diavolo e coda a punta
	  Scheletro ossa dipinte sul petto e teschio sulla faccia
	  ReZucca   il Re Zucca (boss di Halloween): zucca enorme accesa dentro, mantello e liane
	  Spettro   il Gigante Fantasma: corpo trasparente, occhi azzurri, vapori di ectoplasma
]]

local HalloweenCostumes = {}

local rad = math.rad

local PUMPKIN = Color3.fromRGB(236, 118, 28)
local CANDLE = Color3.fromRGB(255, 184, 70)
local STEM = Color3.fromRGB(70, 96, 40)
local WITCH = Color3.fromRGB(46, 26, 60)
local WITCH_BAND = Color3.fromRGB(110, 50, 156)
local BONE = Color3.fromRGB(238, 232, 214)
local BLACK = Color3.fromRGB(18, 14, 20)
local GHOST = Color3.fromRGB(206, 232, 255)

export type Kit = {
	Model: Model,
	Decor: (BasePart, string, Vector3, Color3, CFrame, any?) -> BasePart,
	Head: BasePart,
	Jaw: BasePart,
	Torso: BasePart,
	Hips: BasePart,
	H: number,
	HeadW: number,
	HeadH: number,
	HeadD: number,
	FaceZ: number,
	EyeY: number,
	TorsoW: number,
	TorsoH: number,
	TorsoD: number,
	Skin: Color3,
	Rng: Random,
}

-- Costume a caso per un gigante (dal suo seme: sempre lo stesso per lo stesso gigante)
local SHIFTER = {
	Cacciatrice = "Strega",
	Fauno = "Strega",
	Forgia = "Strega",
	Bastione = "Corna",
	Destriero = "Corna",
	Ghignante = "Zucca",
	Zanna = "Scheletro",
	Strisciante = "Zombie",
}
function HalloweenCostumes.For(look: string, seed: number): string?
	if SHIFTER[look] then
		return SHIFTER[look]
	end
	if look ~= "Puro" and look ~= "Cristallo" then
		return nil
	end
	local roll = Random.new(seed * 6151 + 13):NextNumber()
	if roll < 0.3 then
		return "Zucca"
	elseif roll < 0.48 then
		return "Strega"
	elseif roll < 0.66 then
		return "Zombie"
	elseif roll < 0.76 then
		return "Corna"
	elseif roll < 0.88 then
		return "Scheletro"
	end
	return nil
end

-- triangolo (due cunei) sul piano della faccia, con la punta in alto
local function triangle(k: Kit, parent: BasePart, name: string, offset: CFrame, w: number, h: number, color: Color3, opts: any?)
	for _, side in { -1, 1 } do
		local o = if opts then table.clone(opts) else {}
		o.Shape = "Wedge"
		k.Decor(parent, name, Vector3.new(h * 0.06, h, w / 2), color, offset * CFrame.new(side * w / 4, 0, 0) * CFrame.Angles(0, side * rad(-90), 0), o)
	end
end

-- nasconde le decorazioni della testa che resterebbero fuori dalla zucca o dal cappello
local function hideOnHead(k: Kit, keep: (Vector3) -> boolean)
	for _, d in k.Model:GetDescendants() do
		if d:IsA("BasePart") and not d.CanQuery and d.Transparency < 1 then
			local weld = d:FindFirstChildOfClass("WeldConstraint")
			if weld and (weld.Part0 == k.Head or weld.Part0 == k.Jaw) then
				local localPos = k.Head.CFrame:PointToObjectSpace(d.Position)
				if not keep(localPos) then
					d.Transparency = 1
				end
			end
		end
	end
end

-- Zucca intagliata attorno alla testa. scale > 1 per il Re Zucca
local function pumpkinHead(k: Kit, scale: number, lit: boolean)
	local hw, hh, hd = k.HeadW, k.HeadH, k.HeadD
	local size = Vector3.new(hw * 1.38, hh * 1.3, hd * 1.32) * scale
	local center = CFrame.new(0, -hh * 0.06 + (scale - 1) * hh * 0.4, 0)
	local a, b, c = size.X / 2, size.Y / 2, size.Z / 2
	-- prima si tolgono capelli, orecchie e ciuffi che uscirebbero dalla zucca
	hideOnHead(k, function(p: Vector3): boolean
		local q = p - center.Position
		return (q.X / a) ^ 2 + (q.Y / b) ^ 2 + (q.Z / c) ^ 2 < 0.94
	end)
	k.Decor(k.Head, "Zucca", size, PUMPKIN, center, { Shape = "Sphere", Shadow = true })
	k.Decor(k.Head, "Spicchio", size * Vector3.new(0.6, 1.02, 1.02), Color3.fromRGB(210, 96, 22), center * CFrame.Angles(0, rad(45), 0), { Shape = "Sphere" })
	k.Decor(k.Head, "Gambo", Vector3.new(hw * 0.16, hh * 0.3, hw * 0.16) * scale, STEM, center * CFrame.new(0, b + hh * 0.1 * scale, 0) * CFrame.Angles(rad(12), 0, rad(-14)), { Material = Enum.Material.Wood })
	k.Decor(k.Head, "Foglia", Vector3.new(hw * 0.4, hh * 0.04, hw * 0.28) * scale, Color3.fromRGB(84, 120, 48), center * CFrame.new(hw * 0.2 * scale, b - hh * 0.02, hd * 0.1) * CFrame.Angles(0, rad(30), rad(-12)), { Material = Enum.Material.LeafyGrass })
	-- l'intaglio sta sulla buccia: z della superficie in (x, y) rispetto al centro della zucca
	local function surface(x: number, y: number): number
		local q = 1 - (x / a) ^ 2 - (y / b) ^ 2
		return -c * math.sqrt(math.max(0.05, q)) - hd * 0.012
	end
	local glow = if lit then CANDLE else Color3.fromRGB(255, 160, 60)
	local carved = { Material = Enum.Material.Neon }
	-- occhi proprio davanti agli occhi veri (quelli che si colpiscono per accecare)
	for _, side in { -1, 1 } do
		local x = side * hw * 0.21
		local y = k.EyeY - center.Y
		triangle(k, k.Head, "OcchioZucca", center * CFrame.new(x, y, surface(x, y)), hw * 0.26, hh * 0.24 * scale, glow, carved)
	end
	triangle(k, k.Head, "NasoZucca", center * CFrame.new(0, -hh * 0.06, surface(0, -hh * 0.06)), hw * 0.14 * scale, hh * 0.12 * scale, glow, carved)
	-- bocca a zig-zag con due dentoni
	local my = -hh * 0.3 * scale
	k.Decor(k.Head, "BoccaZucca", Vector3.new(hw * 0.64 * scale, hh * 0.1 * scale, hd * 0.03), glow, center * CFrame.new(0, my, surface(0, my)), carved)
	for _, side in { -1, 1 } do
		local x = side * hw * 0.38 * scale
		k.Decor(k.Head, "BoccaZucca", Vector3.new(hw * 0.18 * scale, hh * 0.09 * scale, hd * 0.03), glow, center * CFrame.new(x, my + hh * 0.06 * scale, surface(x, my)) * CFrame.Angles(0, side * rad(-28), side * rad(30)), carved)
		local tx = side * hw * 0.12 * scale
		k.Decor(k.Head, "DenteZucca", Vector3.new(hw * 0.08 * scale, hh * 0.06 * scale, hd * 0.035), PUMPKIN, center * CFrame.new(tx, my + hh * 0.025 * scale, surface(tx, my) - hd * 0.006))
	end
end

local function witchHat(k: Kit, scale: number)
	local hw, hh = k.HeadW, k.HeadH
	hideOnHead(k, function(p: Vector3): boolean
		return p.Y < hh * 0.52
	end)
	local y = hh * 0.56
	k.Decor(k.Head, "Tesa", Vector3.new(hh * 0.05, hw * 1.95 * scale, hw * 1.95 * scale), WITCH, CFrame.new(0, y, 0) * CFrame.Angles(0, 0, rad(90)), { Shape = "Cylinder", Material = Enum.Material.Fabric, Shadow = true })
	-- cono a pezzi sempre più stretti, con la punta piegata all'indietro
	local seg = hh * 0.34 * scale
	local cf = CFrame.new(0, y, 0)
	for i, d in { 1.12, 0.84, 0.56, 0.3 } do
		local tilt = if i <= 1 then 0 else rad(9 * (i - 1))
		cf = cf * CFrame.Angles(tilt * 0.6, 0, 0) * CFrame.new(0, seg * 0.5, 0)
		k.Decor(k.Head, "Cappello", Vector3.new(seg * 1.06, hw * d * scale, hw * d * scale), WITCH, cf * CFrame.Angles(0, 0, rad(90)), { Shape = "Cylinder", Material = Enum.Material.Fabric })
		cf = cf * CFrame.new(0, seg * 0.5, 0)
		if i == 1 then
			k.Decor(k.Head, "Nastro", Vector3.new(seg * 0.34, hw * 1.16 * scale, hw * 1.16 * scale), WITCH_BAND, CFrame.new(0, y + seg * 0.2, 0) * CFrame.Angles(0, 0, rad(90)), { Shape = "Cylinder", Material = Enum.Material.Fabric })
			k.Decor(k.Head, "Fibbia", Vector3.new(hw * 0.22 * scale, seg * 0.3, hw * 0.05), Color3.fromRGB(236, 196, 80), CFrame.new(0, y + seg * 0.2, -hw * 0.58 * scale), { Material = Enum.Material.Metal })
		end
	end
	k.Decor(k.Head, "PuntaCappello", Vector3.new(hw * 0.14 * scale, seg * 0.5, hw * 0.14 * scale), WITCH, cf * CFrame.Angles(rad(30), 0, 0) * CFrame.new(0, seg * 0.2, 0), { Material = Enum.Material.Fabric })
end

-- la pelle prende un grigio-verde da zombie (le parti color pelle, più chiare o più scure)
local function zombieSkin(k: Kit)
	local skin = k.Skin
	local zombie = Color3.fromRGB(132, 154, 116)
	for _, d in k.Model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.9 and d.Material ~= Enum.Material.Neon then
			local c = d.Color
			local r, g, b = c.R / math.max(skin.R, 0.01), c.G / math.max(skin.G, 0.01), c.B / math.max(skin.B, 0.01)
			local hi, lo = math.max(r, g, b), math.min(r, g, b)
			if hi - lo < 0.1 and lo > 0.4 and hi < 1.15 then
				local f = (r + g + b) / 3
				d.Color = Color3.new(math.clamp(zombie.R * f, 0, 1), math.clamp(zombie.G * f, 0, 1), math.clamp(zombie.B * f, 0, 1))
			end
		end
	end
end

local function stitches(k: Kit, parent: BasePart, offset: CFrame, length: number, n: number)
	local dark = Color3.fromRGB(40, 30, 34)
	local t = k.H * 0.006
	k.Decor(parent, "Cucitura", Vector3.new(t, length, t), dark, offset)
	for i = 1, n do
		local y = (i / (n + 1) - 0.5) * length
		k.Decor(parent, "Punto", Vector3.new(length * 0.28, t, t), dark, offset * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, rad(if i % 2 == 0 then 18 else -18)))
	end
end

local function zombie(k: Kit)
	zombieSkin(k)
	local front = -k.TorsoD * 0.5 - k.H * 0.003
	stitches(k, k.Torso, CFrame.new(k.TorsoW * 0.12, k.TorsoH * 0.05, front) * CFrame.Angles(0, 0, rad(18)), k.TorsoH * 0.62, 5)
	stitches(k, k.Head, CFrame.new(-k.HeadW * 0.25, k.HeadH * 0.3, k.FaceZ - k.HeadD * 0.02) * CFrame.Angles(0, 0, rad(70)), k.HeadW * 0.36, 3)
	local arm = k.Model:FindFirstChild(if k.Rng:NextNumber() < 0.5 then "LeftLowerArm" else "RightLowerArm") :: BasePart?
	if arm then
		local s = arm.Size
		k.Decor(arm, "Benda", Vector3.new(s.X * 1.12, s.Y * 0.32, s.Z * 1.12), Color3.fromRGB(214, 206, 180), CFrame.new(0, s.Y * 0.1, 0) * CFrame.Angles(0, 0, rad(6)), { Material = Enum.Material.Fabric })
		k.Decor(arm, "Benda", Vector3.new(s.X * 1.1, s.Y * 0.12, s.Z * 1.1), Color3.fromRGB(190, 180, 150), CFrame.new(0, -s.Y * 0.18, 0) * CFrame.Angles(0, 0, rad(-8)), { Material = Enum.Material.Fabric })
	end
end

local function horns(k: Kit)
	local hw, hh = k.HeadW, k.HeadH
	local red = Color3.fromRGB(156, 24, 30)
	for _, side in { -1, 1 } do
		local cf = CFrame.new(side * hw * 0.3, hh * 0.46, -k.HeadD * 0.05) * CFrame.Angles(0, 0, rad(-side * 30))
		for i, d in { 0.18, 0.13, 0.08, 0.04 } do
			local seg = hh * 0.13
			cf = cf * CFrame.new(0, seg * 0.5, 0)
			k.Decor(k.Head, "Corno", Vector3.new(hw * d, seg * 1.1, hw * d), red:Lerp(BLACK, (i - 1) / 4), cf, { Material = Enum.Material.SmoothPlastic })
			cf = cf * CFrame.new(0, seg * 0.5, 0) * CFrame.Angles(0, 0, rad(side * 22))
		end
	end
	-- coda a punta dietro le anche
	local cf = CFrame.new(0, -k.H * 0.02, k.TorsoD * 0.45) * CFrame.Angles(rad(60), 0, 0)
	for i = 1, 4 do
		local seg = k.H * 0.06
		cf = cf * CFrame.new(0, seg * 0.5, 0)
		k.Decor(k.Hips, "Coda", Vector3.new(k.H * 0.018, seg * 1.1, k.H * 0.018), red, cf)
		cf = cf * CFrame.new(0, seg * 0.5, 0) * CFrame.Angles(rad(-25 + i * 4), 0, 0)
	end
	k.Decor(k.Hips, "PuntaCoda", Vector3.new(k.H * 0.05, k.H * 0.05, k.H * 0.012), red, cf * CFrame.new(0, k.H * 0.02, 0) * CFrame.Angles(0, 0, rad(45)))
end

local function skeleton(k: Kit)
	local front = -k.TorsoD * 0.5 - k.H * 0.002
	local tw, th = k.TorsoW, k.TorsoH
	k.Decor(k.Torso, "Sterno", Vector3.new(tw * 0.07, th * 0.5, k.H * 0.004), BONE, CFrame.new(0, th * 0.12, front))
	for i = 0, 3 do
		for _, side in { -1, 1 } do
			k.Decor(k.Torso, "Costola", Vector3.new(tw * 0.3, th * 0.04, k.H * 0.004), BONE, CFrame.new(side * tw * 0.2, th * (0.32 - i * 0.12), front) * CFrame.Angles(0, 0, rad(-side * 16)))
		end
	end
	k.Decor(k.Hips, "Bacino", Vector3.new(tw * 0.5, th * 0.12, k.H * 0.004), BONE, CFrame.new(0, 0, -k.TorsoD * 0.48))
	-- teschio dipinto: orbite nere con un lumino dentro, naso a triangolo
	local hw, hh, hd = k.HeadW, k.HeadH, k.HeadD
	k.Decor(k.Head, "Teschio", Vector3.new(hw * 0.92, hh * 0.5, hd * 0.02), BONE, CFrame.new(0, hh * 0.12, k.FaceZ - hd * 0.035))
	for _, side in { -1, 1 } do
		local x = side * hw * 0.21
		k.Decor(k.Head, "Orbita", Vector3.new(hw * 0.28, hh * 0.24, hd * 0.03), BLACK, CFrame.new(x, k.EyeY, k.FaceZ - hd * 0.05), { Shape = "Sphere" })
		k.Decor(k.Head, "Lumino", Vector3.new(hw * 0.07, hw * 0.07, hd * 0.02), Color3.fromRGB(255, 236, 190), CFrame.new(x, k.EyeY, k.FaceZ - hd * 0.065), { Material = Enum.Material.Neon, Shape = "Sphere" })
	end
	triangle(k, k.Head, "NasoTeschio", CFrame.new(0, -hh * 0.06, k.FaceZ - hd * 0.05), hw * 0.14, hh * 0.12, BLACK)
end

local function cape(k: Kit, color: Color3)
	local tw, th, td = k.TorsoW, k.TorsoH, k.TorsoD
	k.Decor(k.Torso, "Mantello", Vector3.new(tw * 1.12, th * 2.0, k.H * 0.008), color, CFrame.new(0, -th * 0.42, td * 0.56) * CFrame.Angles(rad(-6), 0, 0), { Material = Enum.Material.Fabric, Shadow = true })
	k.Decor(k.Torso, "Colletto", Vector3.new(tw * 1.1, th * 0.24, td * 0.5), color, CFrame.new(0, th * 0.58, td * 0.36) * CFrame.Angles(rad(-25), 0, 0), { Material = Enum.Material.Fabric })
	-- strappi in fondo al mantello
	for i = -2, 2 do
		k.Decor(k.Torso, "Strappo", Vector3.new(tw * 0.16, th * 0.24, k.H * 0.008), color, CFrame.new(i * tw * 0.22, -th * 1.48, td * 0.62) * CFrame.Angles(rad(-6), 0, rad(45)), { Material = Enum.Material.Fabric })
	end
end

local function kingPumpkin(k: Kit)
	pumpkinHead(k, 1.35, true)
	local light = Instance.new("PointLight")
	light.Name = "LuceZucca"
	light.Color = Color3.fromRGB(255, 150, 50)
	light.Range = math.min(60, k.H * 0.7)
	light.Brightness = 2.2
	light.Shadows = false
	light.Parent = k.Head
	cape(k, Color3.fromRGB(52, 24, 70))
	-- liane che si avvolgono sulle braccia e zucchette sulle spalle
	for _, prefix in { "Left", "Right" } do
		local upper = k.Model:FindFirstChild(prefix .. "UpperArm") :: BasePart?
		local lower = k.Model:FindFirstChild(prefix .. "LowerArm") :: BasePart?
		for _, arm in { upper, lower } do
			if arm then
				local s = arm.Size
				for i = -1, 1 do
					k.Decor(arm, "Liana", Vector3.new(s.X * 1.12, s.Y * 0.05, s.Z * 1.12), STEM, CFrame.new(0, i * s.Y * 0.3, 0) * CFrame.Angles(rad(20 * i), 0, rad(15)), { Material = Enum.Material.LeafyGrass })
				end
			end
		end
		if upper then
			local s = upper.Size
			k.Decor(upper, "ZuccaSpalla", Vector3.new(s.X * 1.5, s.X * 1.1, s.X * 1.5), PUMPKIN, CFrame.new(0, s.Y * 0.48, 0), { Shape = "Sphere" })
		end
	end
	-- crepe di fuoco sul petto
	for i = 1, 3 do
		k.Decor(k.Torso, "Crepa", Vector3.new(k.TorsoW * 0.04, k.TorsoH * (0.3 + i * 0.06), k.H * 0.005), CANDLE, CFrame.new((i - 2) * k.TorsoW * 0.18, k.TorsoH * 0.05, -k.TorsoD * 0.51) * CFrame.Angles(0, 0, rad((i - 2) * 24)), { Material = Enum.Material.Neon })
	end
end

local function ghost(k: Kit)
	for _, d in k.Model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.9 then
			if d.Material == Enum.Material.Neon then
				d.Color = Color3.fromRGB(150, 230, 255)
			else
				d.Color = d.Color:Lerp(GHOST, 0.72)
				if not d.CanQuery then
					-- (le parti che si colpiscono tengono il loro materiale: per le parti libere decide il peso)
					d.Material = Enum.Material.SmoothPlastic
				end
				d.Transparency = 0.38
				d.CastShadow = false
			end
		end
	end
	local light = Instance.new("PointLight")
	light.Name = "LuceSpettro"
	light.Color = Color3.fromRGB(140, 220, 255)
	light.Range = math.min(60, k.H * 0.8)
	light.Brightness = 1.6
	light.Shadows = false
	light.Parent = k.Torso
	local e = Instance.new("ParticleEmitter")
	e.Name = "Ectoplasma"
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255), Color3.fromRGB(120, 190, 255))
	e.LightEmission = 0.6
	e.LightInfluence = 0.2
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.5, 0.75), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, k.H * 0.05), NumberSequenceKeypoint.new(1, k.H * 0.16) })
	e.Lifetime = NumberRange.new(1.8, 3)
	e.Speed = NumberRange.new(k.H * 0.02, k.H * 0.05)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Acceleration = Vector3.new(0, k.H * 0.03, 0)
	e.Rate = 7
	e.Parent = k.Torso
	-- lembi di lenzuolo che svolazzano sotto le anche
	for i = -2, 2 do
		k.Decor(k.Hips, "Lembo", Vector3.new(k.TorsoW * 0.2, k.H * 0.16, k.H * 0.008), GHOST, CFrame.new(i * k.TorsoW * 0.2, -k.H * 0.1, (if i % 2 == 0 then -1 else 1) * k.TorsoD * 0.45) * CFrame.Angles(rad(i * 6), 0, rad(i * 8)), { Transparency = 0.45 })
	end
end

function HalloweenCostumes.Apply(kind: string, k: Kit)
	if kind == "Zucca" then
		pumpkinHead(k, 1, false)
	elseif kind == "Strega" then
		witchHat(k, 1)
	elseif kind == "Zombie" then
		zombie(k)
	elseif kind == "Corna" then
		horns(k)
	elseif kind == "Scheletro" then
		skeleton(k)
	elseif kind == "ReZucca" then
		kingPumpkin(k)
	elseif kind == "Spettro" then
		ghost(k)
	end
	k.Model:SetAttribute("Costume", kind)
end

-- La sagoma di legno dell'addestramento con la testa di zucca e il cappello da spaventapasseri
function HalloweenCostumes.Dummy(decor: (BasePart, string, Vector3, Color3, CFrame, any?) -> BasePart, head: BasePart, h: number)
	local size = Vector3.new(h * 0.26, h * 0.22, h * 0.2)
	decor(head, "Zucca", size, PUMPKIN, CFrame.new(0, h * 0.01, 0), { Shape = "Sphere" })
	decor(head, "Gambo", Vector3.new(h * 0.03, h * 0.05, h * 0.03), STEM, CFrame.new(0, h * 0.13, 0), { Material = Enum.Material.Wood })
	for _, side in { -1, 1 } do
		decor(head, "OcchioZucca", Vector3.new(h * 0.05, h * 0.05, h * 0.01), Color3.fromRGB(40, 20, 10), CFrame.new(side * h * 0.05, h * 0.03, -h * 0.1) * CFrame.Angles(0, 0, rad(45)))
	end
	decor(head, "BoccaZucca", Vector3.new(h * 0.12, h * 0.025, h * 0.01), Color3.fromRGB(40, 20, 10), CFrame.new(0, -h * 0.04, -h * 0.1))
	decor(head, "Tesa", Vector3.new(h * 0.01, h * 0.34, h * 0.34), Color3.fromRGB(46, 36, 34), CFrame.new(0, h * 0.12, 0) * CFrame.Angles(0, 0, rad(90)), { Shape = "Cylinder", Material = Enum.Material.Fabric })
	decor(head, "Cappello", Vector3.new(h * 0.12, h * 0.1, h * 0.12), Color3.fromRGB(52, 40, 36), CFrame.new(0, h * 0.17, 0) * CFrame.Angles(0.12, 0, 0.08), { Material = Enum.Material.Fabric })
end

return HalloweenCostumes
