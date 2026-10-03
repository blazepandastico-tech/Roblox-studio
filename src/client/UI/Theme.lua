--[[
	Theme - stile grafico dell'interfaccia (colori, font e funzioni per creare elementi)
	Toni da avventura militare: cuoio, ottone, pergamena e verde del Corpo dei Falchi.
]]

local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.Colors = {
	Background = Color3.fromRGB(22, 18, 15),
	Panel = Color3.fromRGB(34, 28, 23),
	PanelLight = Color3.fromRGB(52, 43, 35),
	Border = Color3.fromRGB(150, 118, 70),
	Gold = Color3.fromRGB(222, 182, 96),
	GoldBright = Color3.fromRGB(255, 220, 130),
	Text = Color3.fromRGB(242, 232, 212),
	TextDim = Color3.fromRGB(178, 164, 140),
	Green = Color3.fromRGB(64, 128, 78),
	GreenBright = Color3.fromRGB(110, 200, 120),
	Red = Color3.fromRGB(190, 52, 52),
	RedBright = Color3.fromRGB(255, 90, 80),
	Blue = Color3.fromRGB(70, 140, 220),
	Gas = Color3.fromRGB(150, 210, 240),
	Health = Color3.fromRGB(205, 60, 54),
	Energy = Color3.fromRGB(255, 196, 70),
	XP = Color3.fromRGB(120, 200, 255),
	Black = Color3.fromRGB(0, 0, 0),
	White = Color3.fromRGB(255, 255, 255),
}

Theme.Fonts = {
	Title = Enum.Font.GrenzeGotisch,
	Header = Enum.Font.Merriweather,
	Body = Enum.Font.Merriweather,
	UI = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
	Number = Enum.Font.Oswald,
}

function Theme.New(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local New = Theme.New

function Theme.Corner(parent: Instance, radius: number?)
	return New("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

function Theme.Stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?)
	return New("UIStroke", {
		Color = color or Theme.Colors.Border,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Theme.Padding(parent: Instance, pixels: number)
	return New("UIPadding", {
		PaddingTop = UDim.new(0, pixels),
		PaddingBottom = UDim.new(0, pixels),
		PaddingLeft = UDim.new(0, pixels),
		PaddingRight = UDim.new(0, pixels),
		Parent = parent,
	})
end

function Theme.Gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?)
	return New("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
		Parent = parent,
	})
end

-- Pannello scuro con bordo dorato
function Theme.Panel(props: { [string]: any }?): Frame
	local frame = New("Frame", {
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
	})
	if props then
		for key, value in props do
			if key ~= "Parent" then
				(frame :: any)[key] = value
			end
		end
	end
	Theme.Corner(frame, 10)
	Theme.Stroke(frame, Theme.Colors.Border, 1.5, 0.25)
	Theme.Gradient(frame, Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 180, 170), 90)
	if props and props.Parent then
		frame.Parent = props.Parent
	end
	return frame
end

function Theme.Label(text: string, props: { [string]: any }?): TextLabel
	local label = New("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = Theme.Colors.Text,
		Font = Theme.Fonts.Body,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	if props then
		for key, value in props do
			if key ~= "Parent" then
				(label :: any)[key] = value
			end
		end
		if props.Parent then
			label.Parent = props.Parent
		end
	end
	return label
end

-- Pulsante animato (si ingrandisce al passaggio del mouse)
function Theme.Button(text: string, props: { [string]: any }?, onClick: (() -> ())?): TextButton
	local button = New("TextButton", {
		BackgroundColor3 = Theme.Colors.PanelLight,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = text,
		TextColor3 = Theme.Colors.Text,
		Font = Theme.Fonts.Bold,
		TextSize = 16,
		TextWrapped = true,
	})
	if props then
		for key, value in props do
			if key ~= "Parent" then
				(button :: any)[key] = value
			end
		end
	end
	Theme.Corner(button, 8)
	local stroke = Theme.Stroke(button, Theme.Colors.Border, 1.2, 0.35)
	local scale = New("UIScale", { Scale = 1, Parent = button })
	local baseColor = button.BackgroundColor3
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = 1.04 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.12), { Transparency = 0, Color = Theme.Colors.GoldBright }):Play()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = baseColor:Lerp(Theme.Colors.Gold, 0.18) }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.15), { Transparency = 0.35, Color = Theme.Colors.Border }):Play()
		TweenService:Create(button, TweenInfo.new(0.15), { BackgroundColor3 = baseColor }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.96 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1, Enum.EasingStyle.Back), { Scale = 1.04 }):Play()
	end)
	if onClick then
		button.Activated:Connect(onClick)
	end
	if props and props.Parent then
		button.Parent = props.Parent
	end
	return button
end

-- Barra di avanzamento con barra "fantasma" che segue in ritardo (stile giochi d'azione)
function Theme.Bar(props: { [string]: any }, color: Color3): (Frame, (number, boolean?) -> ())
	local holder = New("Frame", {
		BackgroundColor3 = Color3.fromRGB(16, 12, 10),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	})
	for key, value in props do
		if key ~= "Parent" then
			(holder :: any)[key] = value
		end
	end
	Theme.Corner(holder, 6)
	Theme.Stroke(holder, Theme.Colors.Border, 1, 0.4)
	local ghost = New("Frame", { Name = "Ghost", BackgroundColor3 = Color3.fromRGB(255, 240, 210), BackgroundTransparency = 0.3, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = holder })
	Theme.Corner(ghost, 6)
	local fill = New("Frame", { Name = "Fill", BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = holder })
	Theme.Corner(fill, 6)
	Theme.Gradient(fill, Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 170, 170), 90)
	local last = 1
	local function set(fraction: number, instant: boolean?)
		fraction = math.clamp(fraction, 0, 1)
		if instant then
			fill.Size = UDim2.fromScale(fraction, 1)
			ghost.Size = UDim2.fromScale(fraction, 1)
		else
			TweenService:Create(fill, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(fraction, 1) }):Play()
			if fraction < last then
				TweenService:Create(ghost, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.25), { Size = UDim2.fromScale(fraction, 1) }):Play()
			else
				ghost.Size = UDim2.fromScale(fraction, 1)
			end
		end
		last = fraction
	end
	if props.Parent then
		holder.Parent = props.Parent
	end
	return holder, set
end

function Theme.Tween(instance: Instance, time: number, goals: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local tween = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goals)
	tween:Play()
	return tween
end

return Theme
