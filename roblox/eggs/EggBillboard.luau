--!nonstrict
--[[
	EggBillboard
	The floating label over a spawned egg: name, rarity (in its colour),
	weight, income per second and mutation.

	local EggBillboard = require(path.EggBillboard)
	EggBillboard.Attach(eggModel, "sprout_egg", 3.4, "golden")
]]

local EggConfig = require(script.Parent:WaitForChild("EggConfig"))

local EggBillboard = {}

local function label(parent: Instance, name: string, text: string, color: Color3, height: number, order: number)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, height, 0)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	l.LayoutOrder = order
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(20, 20, 24)
	stroke.Parent = l
	l.Parent = parent
	return l
end

function EggBillboard.Attach(model: Model, eggId: string, weightKg: number, mutation: string?): BillboardGui
	local egg = EggConfig.Eggs[eggId]
	assert(egg, `unknown egg {eggId}`)
	local rarity = EggConfig.RarityById[egg.rarity]
	local old = model:FindFirstChild("EggBillboard")
	if old then
		old:Destroy()
	end
	local _, size = model:GetBoundingBox()
	local gui = Instance.new("BillboardGui")
	gui.Name = "EggBillboard"
	gui.Size = UDim2.fromScale(7, 3.2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 2, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = gui

	local mut = EggConfig.MutationById[mutation or "normal"]
	local title = egg.name
	if mut and mut.id ~= "normal" then
		title = `{mut.title} {egg.name}`
	end
	label(gui, "Name", title, Color3.new(1, 1, 1), 0.32, 1)
	label(gui, "Rarity", rarity.title, rarity.color, 0.24, 2)
	label(gui, "Weight", string.format("%.1f kg", weightKg), Color3.fromRGB(230, 230, 235), 0.2, 3)
	local income = EggConfig.Income(eggId, weightKg, mutation or "normal")
	label(gui, "Income", `{EggConfig.FormatMoney(income)}/s`, Color3.fromRGB(120, 255, 120), 0.22, 4)
	gui.Parent = model
	return gui
end

return EggBillboard
