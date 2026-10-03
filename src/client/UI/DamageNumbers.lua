--[[
	DamageNumbers
	Numeri dei danni che saltano fuori dai giganti, scritte "TAGLIO PERFETTO!",
	e il riquadro con esperienza e oro guadagnati a ogni uccisione.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Lib.Net)
local Util = require(Shared.Lib.Util)

local Theme = require(script.Parent.Theme)
local New = Theme.New

local DamageNumbers = {}
local C
local killHolder: Frame

local STYLES = {
	Normal = { Color = Color3.fromRGB(255, 255, 255), Size = 26 },
	Crit = { Color = Color3.fromRGB(255, 170, 70), Size = 32, Suffix = "!" },
	Nape = { Color = Color3.fromRGB(255, 215, 110), Size = 36, Prefix = "NUCA " },
	Perfect = { Color = Color3.fromRGB(255, 240, 150), Size = 42, Prefix = "✦ " },
	Blocked = { Color = Color3.fromRGB(170, 190, 210), Size = 22, Suffix = " (bloccato)" },
	Explosion = { Color = Color3.fromRGB(255, 140, 60), Size = 34 },
	Titan = { Color = Color3.fromRGB(255, 110, 80), Size = 34 },
}

function DamageNumbers.Show(position: Vector3, amount: number, kind: string?)
	if C.ClientData.Setting("DamageNumbers", true) == false then
		return
	end
	local style = STYLES[kind or "Normal"] or STYLES.Normal
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position + Vector3.new(math.random(-20, 20) / 10, math.random(0, 20) / 10, math.random(-20, 20) / 10)
	attachment.Parent = workspace.Terrain
	local gui = New("BillboardGui", {
		Size = UDim2.fromOffset(220, 60),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 600,
		Adornee = attachment,
		Parent = attachment,
	})
	local label = Theme.Label((style.Prefix or "") .. Util.Abbreviate(amount) .. (style.Suffix or ""), {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.Number,
		TextSize = style.Size,
		TextColor3 = style.Color,
		TextStrokeTransparency = 0.2,
		TextStrokeColor3 = Color3.fromRGB(40, 20, 10),
		Parent = gui,
	})
	local scale = New("UIScale", { Scale = 1.6, Parent = label })
	Theme.Tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	Theme.Tween(gui, 0.9, { StudsOffsetWorldSpace = Vector3.new(0, 5, 0) }, Enum.EasingStyle.Quad)
	task.delay(0.55, function()
		Theme.Tween(label, 0.35, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	Debris:AddItem(attachment, 1)
end

function DamageNumbers.Banner(text: string, color: Color3?, duration: number?)
	local layer = C.UIController.Layers.Overlay
	local label = Theme.Label(text, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(700, 70),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.Title,
		TextSize = 56,
		TextColor3 = color or Theme.Colors.GoldBright,
		TextStrokeTransparency = 0.25,
		Rotation = -3,
		Parent = layer,
	})
	local scale = New("UIScale", { Scale = 2.2, Parent = label })
	Theme.Tween(scale, 0.22, { Scale = C.UIController.Scale }, Enum.EasingStyle.Back)
	task.delay(duration or 1.1, function()
		Theme.Tween(label, 0.35, { TextTransparency = 1, TextStrokeTransparency = 1 })
		Theme.Tween(scale, 0.35, { Scale = C.UIController.Scale * 1.3 })
		Debris:AddItem(label, 0.4)
	end)
end

function DamageNumbers.KillPopup(name: string, xp: number, gold: number, boss: boolean?)
	if not killHolder then
		return
	end
	local frame = Theme.Panel({
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 0.2,
		Parent = killHolder,
	})
	Theme.Padding(frame, 6)
	Theme.Label((if boss then "👑 " else "☠️ ") .. name, {
		Size = UDim2.new(1, 0, 0.5, 0),
		Font = Theme.Fonts.Bold,
		TextSize = 15,
		TextColor3 = if boss then Theme.Colors.GoldBright else Theme.Colors.Text,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})
	Theme.Label(("+%s XP   +%s oro"):format(Util.Abbreviate(xp), Util.Abbreviate(gold)), {
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0.5, 0),
		Font = Theme.Fonts.UI,
		TextSize = 14,
		TextColor3 = Theme.Colors.XP,
		Parent = frame,
	})
	frame.Position = UDim2.fromOffset(60, 0)
	task.delay(3, function()
		Theme.Tween(frame, 0.4, { BackgroundTransparency = 1 })
		for _, child in frame:GetChildren() do
			if child:IsA("TextLabel") then
				Theme.Tween(child, 0.4, { TextTransparency = 1 })
			end
		end
		Debris:AddItem(frame, 0.45)
	end)
end

function DamageNumbers.Init(c)
	C = c
end

function DamageNumbers.Start()
	local layer = C.UIController.Layers.Overlay
	killHolder = New("Frame", {
		Name = "Uccisioni",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -250),
		Size = UDim2.fromOffset(250, 220),
		BackgroundTransparency = 1,
		Parent = layer,
	})
	C.UIController.AttachScale(killHolder)
	New("UIListLayout", { Padding = UDim.new(0, 4), VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder, Parent = killHolder })
	Net.Event("DamageNumber").OnClientEvent:Connect(function(position, amount, kind)
		if typeof(position) == "Vector3" and type(amount) == "number" then
			DamageNumbers.Show(position, amount, kind)
		end
	end)
end

return DamageNumbers
