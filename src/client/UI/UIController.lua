--[[
	UIController
	Crea lo ScreenGui principale, gestisce i pannelli aperti e la modalità cursore
	(quando un menu è aperto il mouse si sblocca e la telecamera smette di ruotare).
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Theme = require(script.Parent.Theme)

local UIController = {}
local C

local player = Players.LocalPlayer
local panels: { [string]: { Frame: GuiObject, OnOpen: (() -> ())?, OnClose: (() -> ())?, Open: boolean } } = {}
local cursorRequests: { [string]: boolean } = {}

UIController.Root = nil :: ScreenGui?
UIController.Scale = 1
local scaled: { [UIScale]: boolean } = {}

-- Aggiunge a un elemento una UIScale che segue la dimensione dello schermo
function UIController.AttachScale(gui: GuiObject): UIScale
	local scale = Theme.New("UIScale", { Name = "ScalaSchermo", Scale = UIController.Scale, Parent = gui })
	scaled[scale] = true
	return scale
end
UIController.Layers = {} :: { [string]: Frame }
UIController.IsMobile = false

local function makeLayer(name: string, zindex: number): Frame
	local frame = Theme.New("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = zindex,
		Parent = UIController.Root,
	})
	return frame
end

function UIController.RequestCursor(key: string, on: boolean)
	cursorRequests[key] = if on then true else nil
	local any = next(cursorRequests) ~= nil
	if C.CameraController then
		C.CameraController.SetCursorMode(any)
	end
end

function UIController.CursorActive(): boolean
	return next(cursorRequests) ~= nil
end

function UIController.RegisterPanel(name: string, frame: GuiObject, onOpen: (() -> ())?, onClose: (() -> ())?)
	panels[name] = { Frame = frame, OnOpen = onOpen, OnClose = onClose, Open = false }
	frame.Visible = false
end

function UIController.IsOpen(name: string): boolean
	local panel = panels[name]
	return panel ~= nil and panel.Open
end

function UIController.Open(name: string)
	local panel = panels[name]
	if not panel then
		return
	end
	panel.Open = true
	local frame = panel.Frame
	frame.Visible = true
	local scale = frame:FindFirstChild("PanelScale") :: UIScale?
	if not scale then
		scale = Theme.New("UIScale", { Name = "PanelScale", Parent = frame })
	end
	local s = scale :: UIScale
	s.Scale = 0.85 * UIController.Scale
	Theme.Tween(s, 0.25, { Scale = UIController.Scale }, Enum.EasingStyle.Back)
	UIController.RequestCursor("panel_" .. name, true)
	if C.SoundController then
		C.SoundController.Play("UI")
	end
	if panel.OnOpen then
		task.spawn(panel.OnOpen)
	end
end

function UIController.Close(name: string)
	local panel = panels[name]
	if not panel or not panel.Open then
		return
	end
	panel.Open = false
	local frame = panel.Frame
	local scale = frame:FindFirstChild("PanelScale") :: UIScale?
	if scale then
		local tween = Theme.Tween(scale, 0.14, { Scale = 0.9 * UIController.Scale }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween.Completed:Connect(function()
			if not panel.Open then
				frame.Visible = false
			end
		end)
	else
		frame.Visible = false
	end
	UIController.RequestCursor("panel_" .. name, false)
	if panel.OnClose then
		task.spawn(panel.OnClose)
	end
end

function UIController.Toggle(name: string)
	if UIController.IsOpen(name) then
		UIController.Close(name)
	else
		UIController.Open(name)
	end
end

function UIController.CloseAll()
	for name in panels do
		UIController.Close(name)
	end
end

-- Dissolvenza a nero (per viaggi e teletrasporti)
function UIController.Fade(duration: number?)
	local layer = UIController.Layers.Top
	if not layer then
		return
	end
	local fade = Theme.New("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = layer,
	})
	local t = duration or 0.6
	Theme.Tween(fade, t * 0.4, { BackgroundTransparency = 0 })
	task.delay(t, function()
		local out = Theme.Tween(fade, t * 0.8, { BackgroundTransparency = 1 })
		out.Completed:Connect(function()
			fade:Destroy()
		end)
	end)
end

function UIController.Init(c)
	C = c
	local gui = Instance.new("ScreenGui")
	gui.Name = "SieriPerdutiUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")
	UIController.Root = gui
	UIController.Layers.HUD = makeLayer("HUD", 1)
	UIController.Layers.Panels = makeLayer("Pannelli", 10)
	UIController.Layers.Overlay = makeLayer("Avvisi", 20)
	UIController.Layers.Top = makeLayer("Sopra", 30)

	local camera = workspace.CurrentCamera
	local function rescale()
		local size = camera.ViewportSize
		UIController.Scale = math.clamp(math.min(size.Y / 900, size.X / 1500), 0.55, 1.2)
		for scale in scaled do
			if scale.Parent then
				scale.Scale = UIController.Scale
			else
				scaled[scale] = nil
			end
		end
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	local uis = game:GetService("UserInputService")
	UIController.IsMobile = uis.TouchEnabled and not uis.KeyboardEnabled
end

function UIController.Start()
	for _, coreType in { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health, Enum.CoreGuiType.EmotesMenu } do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(coreType, false)
		end)
	end
end

return UIController
