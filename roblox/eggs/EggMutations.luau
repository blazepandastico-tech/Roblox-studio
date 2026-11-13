--!strict
--[[
	EggMutations
	Colour mutations for StudVox eggs. A mutation recolours an egg model at
	runtime (no extra models needed) and multiplies its income (see EggConfig).

	  Silver   metallic silver tint + white sparkles
	  Golden   shiny gold tint + gold sparkles
	  Rainbow  colours cycle through the rainbow (animated on clients)
	  Diamond  see-through ice-blue crystal + sparkles

	Server:  EggMutations.Apply(eggModel, "golden")
	Client:  EggMutations.StartClientEffects()   -- once, animates every Rainbow egg

	The original colours are kept in attributes, so EggMutations.Remove(egg)
	restores the egg exactly.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local RAINBOW_TAG = "StudVoxRainbowEgg"

local EggMutations = {}

type Look = {
	tint: Color3?,
	amount: number,
	material: Enum.Material?,
	reflectance: number?,
	transparency: number?,
	sparkle: ColorSequence?,
}

local LOOKS: { [string]: Look } = {
	silver = {
		tint = Color3.fromRGB(215, 222, 232),
		amount = 0.6,
		reflectance = 0.25,
		sparkle = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
	},
	golden = {
		tint = Color3.fromRGB(255, 196, 46),
		amount = 0.65,
		reflectance = 0.3,
		sparkle = ColorSequence.new(Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 170, 30)),
	},
	rainbow = {
		amount = 0,
		sparkle = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(80, 255, 120)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 160, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 255)),
		}),
	},
	diamond = {
		tint = Color3.fromRGB(190, 236, 255),
		amount = 0.7,
		material = Enum.Material.Glass,
		transparency = 0.25,
		reflectance = 0.2,
		sparkle = ColorSequence.new(Color3.fromRGB(200, 245, 255)),
	},
}

local function visibleParts(model: Instance): { BasePart }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			table.insert(out, d)
		end
	end
	return out
end

local function remember(p: BasePart)
	if p:GetAttribute("SVColor") == nil then
		p:SetAttribute("SVColor", p.Color)
		p:SetAttribute("SVMaterial", p.Material.Name)
		p:SetAttribute("SVReflectance", p.Reflectance)
		p:SetAttribute("SVTransparency", p.Transparency)
	end
end

function EggMutations.Remove(model: Instance)
	CollectionService:RemoveTag(model, RAINBOW_TAG)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("SVColor") ~= nil then
			d.Color = d:GetAttribute("SVColor") :: Color3
			d.Material = (Enum.Material :: any)[d:GetAttribute("SVMaterial") :: string]
			d.Reflectance = d:GetAttribute("SVReflectance") :: number
			d.Transparency = d:GetAttribute("SVTransparency") :: number
		elseif d:IsA("ParticleEmitter") and d.Name == "MutationSparkles" then
			d:Destroy()
		end
	end
	model:SetAttribute("Mutation", nil)
end

function EggMutations.Apply(model: Instance, mutation: string)
	EggMutations.Remove(model)
	local look = LOOKS[mutation]
	if look == nil then
		return -- "normal" or unknown: original colours
	end
	model:SetAttribute("Mutation", mutation)
	local parts = visibleParts(model)
	for _, p in parts do
		remember(p)
		local tint = look.tint
		if tint then
			p.Color = p.Color:Lerp(tint, look.amount)
		end
		if look.material and p.Material ~= Enum.Material.Neon then
			p.Material = look.material
		end
		if look.reflectance then
			p.Reflectance = look.reflectance
		end
		if look.transparency and p.Material ~= Enum.Material.Neon then
			p.Transparency = math.max(p.Transparency, look.transparency)
		end
	end
	-- sparkles on the biggest part (uses Roblox's default sparkle texture)
	local biggest: BasePart? = nil
	for _, p in parts do
		if biggest == nil or p.Size.Magnitude > (biggest :: BasePart).Size.Magnitude then
			biggest = p
		end
	end
	if biggest and look.sparkle then
		local e = Instance.new("ParticleEmitter")
		e.Name = "MutationSparkles"
		e.Color = look.sparkle
		e.LightEmission = 1
		e.Rate = 6
		e.Lifetime = NumberRange.new(0.8, 1.4)
		e.Speed = NumberRange.new(0.5, 1.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
		e.Parent = biggest
	end
	if mutation == "rainbow" then
		CollectionService:AddTag(model, RAINBOW_TAG)
	end
end

local started = false

-- Clients: animate the rainbow mutation (colour changes stay local, nothing is replicated).
function EggMutations.StartClientEffects()
	if started then
		return
	end
	started = true
	local t = 0
	RunService.RenderStepped:Connect(function(dt: number)
		t += dt
		for _, model in CollectionService:GetTagged(RAINBOW_TAG) do
			if not model:IsDescendantOf(workspace) then
				continue
			end
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d.Transparency < 1 then
					local base = d:GetAttribute("SVColor")
					local h, s, v = 0, 0.75, 1
					if typeof(base) == "Color3" then
						local _, bs, bv = base:ToHSV()
						s, v = math.max(bs, 0.55), math.max(bv, 0.75)
					end
					h = (t * 0.25 + d.Position.Y * 0.04) % 1
					d.Color = Color3.fromHSV(h, s, v)
				end
			end
		end
	end)
end

return EggMutations
