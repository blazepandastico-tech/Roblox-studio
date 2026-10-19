--[[
	Dialogue
	Finestra dei dialoghi: ritratto 3D del personaggio che parla (ViewportFrame),
	testo che compare lettera per lettera e scelte cliccabili (anche con i tasti 1-9).
	Clic, Spazio, Invio o F per andare avanti.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Lib.Net)
local Util = require(Shared.Lib.Util)
local NPCs = require(Shared.Data.NPCs)

local Theme = require(script.Parent.Theme)
local New = Theme.New
local Colors = Theme.Colors

local Dialogue = {}
local C
local player = Players.LocalPlayer

local CHARS_PER_SECOND = 48
local MAX_QUEUE = 6

local ADVANCE_KEYS = {
	[Enum.KeyCode.Space] = true,
	[Enum.KeyCode.Return] = true,
	[Enum.KeyCode.KeypadEnter] = true,
	[Enum.KeyCode.F] = true,
	[Enum.KeyCode.ButtonA] = true,
}

local NUMBER_KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
}

type Line = { Speaker: string?, Name: string?, Text: string }
type Choice = { Id: string, Text: string, Disabled: boolean? }
type Data = { NpcId: string?, Name: string?, Title: string?, Lines: { Line }, Choices: { Choice }?, Story: boolean? }

local ui = {} :: {
	Panel: Frame,
	Portrait: Frame,
	PortraitStroke: UIStroke,
	PortraitScale: UIScale,
	Viewport: ViewportFrame,
	World: WorldModel,
	Camera: Camera,
	Initial: TextLabel,
	Name: TextLabel,
	Title: TextLabel,
	Text: TextLabel,
	Hint: TextLabel,
	Counter: TextLabel,
	StoryTag: TextLabel,
	Choices: Frame,
}

local current: Data? = nil
local lineIndex = 0
local typing = false
local typeStart = 0
local typeTotal = 0
local lastTick = 0
local showingChoices = false
local choiceButtons: { TextButton } = {}
local queue: { Data } = {}
local portraitModel: Model? = nil
local portraitKey: string? = nil
local portraitBase: CFrame? = nil
local portraitPunch = 0
local controlsOff = false

-- PERSONAGGI ---------------------------------------------------------------------------------------

local function speakerInfo(line: Line, data: Data): (string, string, Color3?)
	local speaker = line.Speaker
	local character = speaker and NPCs.Characters[speaker]
	local name = line.Name or (character and character.Name) or data.Name or "???"
	local title = ""
	if character then
		title = character.Title
	elseif speaker and speaker == data.NpcId then
		title = data.Title or ""
	else
		local npc = NPCs.Get(speaker)
		if npc then
			local _, t = NPCs.DisplayName(npc)
			title = t
		end
	end
	local color = character and character.Color
	if not color then
		local npc = NPCs.Get(speaker) or NPCs.Get(data.NpcId)
		local npcCharacter = npc and npc.Character and NPCs.Characters[npc.Character]
		color = npcCharacter and npcCharacter.Color
	end
	return name, title, color
end

-- Trova nel mondo il modello del PNG che sta parlando (il più vicino al giocatore)
local function findSpeakerModel(speaker: string?, npcId: string?): Model?
	local folder = workspace:FindFirstChild(Config.Folders.NPCs)
	if not folder or not speaker then
		return nil
	end
	local root = Util.GetRoot(player.Character)
	local best: Model? = nil
	local bestDistance = math.huge
	for _, model in folder:GetChildren() do
		if model:IsA("Model") then
			local id = model:GetAttribute("NpcId")
			local def = NPCs.Get(id)
			if def and not def.Object and (id == speaker or def.Character == speaker or (id == npcId and speaker == npcId)) then
				local distance = if root then (model:GetPivot().Position - root.Position).Magnitude else 0
				if distance < bestDistance then
					best = model
					bestDistance = distance
				end
			end
		end
	end
	return best
end

local function clearPortrait()
	if portraitModel then
		portraitModel:Destroy()
		portraitModel = nil
	end
	portraitBase = nil
end

local function setPortrait(line: Line, data: Data, color: Color3?, name: string)
	local key = line.Speaker or name
	if key == portraitKey and (portraitModel or ui.Initial.Visible) then
		return
	end
	portraitKey = key
	clearPortrait()
	ui.PortraitStroke.Color = color or Colors.Border
	ui.Initial.TextColor3 = color or Colors.GoldBright
	local source = findSpeakerModel(line.Speaker, data.NpcId)
	local clone: Model? = nil
	if source then
		local ok, result = pcall(function()
			local wasArchivable = source.Archivable
			source.Archivable = true
			local copy = source:Clone()
			source.Archivable = wasArchivable
			return copy
		end)
		if ok and result then
			clone = result
		end
	end
	if clone then
		for _, d in clone:GetDescendants() do
			if d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("Sound") or d:IsA("BaseScript") or d:IsA("ParticleEmitter") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			end
		end
		local humanoid = clone:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		clone:PivotTo(CFrame.new(0, 0, 0))
		clone.Parent = ui.World
		local head = clone:FindFirstChild("Head") :: BasePart?
		local focus = if head then head.CFrame else clone:GetPivot() * CFrame.new(0, 1.5, 0)
		local eye = focus.Position + focus.LookVector * 3.4 + focus.RightVector * 0.9 + Vector3.new(0, 0.25, 0)
		portraitBase = CFrame.lookAt(eye, focus.Position - Vector3.new(0, 0.35, 0))
		portraitModel = clone
		ui.Initial.Visible = false
		ui.Viewport.Visible = true
	else
		ui.Viewport.Visible = false
		ui.Initial.Visible = true
		ui.Initial.Text = if line.Speaker == "Narratore" then "📜" elseif line.Speaker == "Diario" then "📓" else utf8.char(utf8.codepoint(name, 1, 1))
	end
	portraitPunch = 1
	ui.PortraitScale.Scale = 0.88
	Theme.Tween(ui.PortraitScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- CONTROLLI ----------------------------------------------------------------------------------------

local function setControls(enabled: boolean)
	if controlsOff == not enabled then
		return
	end
	controlsOff = not enabled
	pcall(function()
		local scripts = player:FindFirstChild("PlayerScripts")
		local module = scripts and scripts:FindFirstChild("PlayerModule")
		if module and module:IsA("ModuleScript") then
			local controls = (require(module) :: any):GetControls()
			if enabled then
				controls:Enable()
			else
				controls:Disable()
			end
		end
	end)
	ProximityPromptService.Enabled = enabled
end

-- TESTO --------------------------------------------------------------------------------------------

local function clearChoices()
	for _, button in choiceButtons do
		button:Destroy()
	end
	table.clear(choiceButtons)
	showingChoices = false
end

local choose: (Choice) -> ()

local function showChoices()
	local data = current
	if not data or showingChoices then
		return
	end
	showingChoices = true
	ui.Hint.Text = ""
	local choices = data.Choices
	if not choices or #choices == 0 then
		choices = { { Id = "close", Text = "Chiudi" } }
		data.Choices = choices
	end
	for i, choice in choices :: { Choice } do
		local disabled = choice.Disabled == true
		local button = Theme.Button(("%d.  %s"):format(i, choice.Text), {
			Size = UDim2.new(1, 0, 0, 40),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 15,
			LayoutOrder = i,
			BackgroundColor3 = if disabled then Color3.fromRGB(38, 33, 29) else Colors.PanelLight,
			TextColor3 = if disabled then Colors.TextDim else Colors.Text,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			BackgroundTransparency = 1,
			TextTransparency = 1,
			Parent = ui.Choices,
		}, function()
			choose(choice)
		end)
		Theme.Padding(button, 0).PaddingLeft = UDim.new(0, 14)
		table.insert(choiceButtons, button)
		-- le scelte compaiono una dopo l'altra
		task.delay((i - 1) * 0.05, function()
			if button.Parent then
				Theme.Tween(button, 0.18, { BackgroundTransparency = 0.05, TextTransparency = 0 })
			end
		end)
	end
end

local function finishTyping()
	typing = false
	ui.Text.MaxVisibleGraphemes = -1
	local data = current
	if data and lineIndex >= #data.Lines then
		showChoices()
	else
		ui.Hint.Text = "Clic / Spazio per continuare  ▼"
	end
end

local function showLine(index: number)
	local data = current
	if not data then
		return
	end
	lineIndex = index
	local line = data.Lines[index]
	local name, title, color = speakerInfo(line, data)
	if ui.Name.Text ~= name then
		ui.Name.TextTransparency = 1
		ui.Name.Position = UDim2.fromOffset(214, 12)
		Theme.Tween(ui.Name, 0.25, { TextTransparency = 0, Position = UDim2.fromOffset(204, 12) })
	end
	ui.Name.Text = name
	ui.Name.TextColor3 = color or Colors.GoldBright
	ui.Title.Text = title
	ui.Counter.Text = if #data.Lines > 1 then ("%d/%d"):format(index, #data.Lines) else ""
	ui.StoryTag.Visible = data.Story == true
	setPortrait(line, data, color, name)
	ui.Text.Text = line.Text
	ui.Text.MaxVisibleGraphemes = 0
	ui.Hint.Text = ""
	typeTotal = utf8.len(line.Text) or #line.Text
	typeStart = os.clock()
	typing = true
end

local function show(data: Data)
	current = data
	clearChoices()
	portraitKey = nil
	if not C.UIController.IsOpen("Dialogue") then
		C.UIController.Open("Dialogue")
	end
	setControls(false)
	if #data.Lines == 0 then
		lineIndex = 0
		finishTyping()
	else
		showLine(1)
	end
end

local function closeCurrent()
	current = nil
	typing = false
	clearChoices()
	if #queue > 0 then
		show(table.remove(queue, 1) :: Data)
		return
	end
	C.UIController.Close("Dialogue")
end

choose = function(choice: Choice)
	local data = current
	if not data then
		return
	end
	if choice.Disabled then
		C.SoundController.Play("UI", nil, { Pitch = 0.6 })
		return
	end
	C.SoundController.Play("UI")
	closeCurrent()
	if choice.Id ~= "close" then
		Net.Event("DialogueChoice"):FireServer(data.NpcId or "", choice.Id)
	end
end

local function advance()
	local data = current
	if not data then
		return
	end
	if typing then
		finishTyping()
		return
	end
	if showingChoices then
		local choices = data.Choices
		if choices and #choices == 1 then
			choose(choices[1])
		end
		return
	end
	if lineIndex < #data.Lines then
		showLine(lineIndex + 1)
	else
		showChoices()
	end
end

local function sanitize(raw: any): Data?
	if type(raw) ~= "table" or type(raw.Lines) ~= "table" then
		return nil
	end
	local lines: { Line } = {}
	for _, line in raw.Lines do
		if type(line) == "table" and type(line.Text) == "string" then
			table.insert(lines, { Speaker = line.Speaker, Name = line.Name, Text = line.Text })
		elseif type(line) == "string" then
			table.insert(lines, { Text = line })
		end
	end
	local choices: { Choice } = {}
	if type(raw.Choices) == "table" then
		for _, choice in raw.Choices do
			if type(choice) == "table" and type(choice.Id) == "string" then
				table.insert(choices, { Id = choice.Id, Text = tostring(choice.Text or choice.Id), Disabled = choice.Disabled == true })
			end
		end
	end
	return {
		NpcId = if type(raw.NpcId) == "string" then raw.NpcId else nil,
		Name = raw.Name,
		Title = raw.Title,
		Lines = lines,
		Choices = choices,
		Story = raw.Story == true,
	}
end

function Dialogue.IsOpen(): boolean
	return current ~= nil
end

-- Apre un dialogo (usato anche da altri moduli per messaggi locali)
function Dialogue.Show(raw: any)
	local data = sanitize(raw)
	if not data then
		return
	end
	if current then
		-- un nuovo dialogo dallo stesso PNG sostituisce il vecchio, gli altri si mettono in coda
		if not current.Story and not data.Story and data.NpcId == current.NpcId then
			show(data)
		elseif #queue < MAX_QUEUE then
			table.insert(queue, data)
		end
		return
	end
	show(data)
end

-- INTERFACCIA --------------------------------------------------------------------------------------

local function build()
	local panel = Theme.Panel({
		Name = "Dialogo",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -34),
		Size = UDim2.fromOffset(940, 206),
		Parent = C.UIController.Layers.Panels,
	})
	ui.Panel = panel
	-- tutta la finestra è cliccabile per andare avanti
	local catcher = New("TextButton", {
		Name = "Avanti",
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = panel,
	})
	catcher.Activated:Connect(advance)

	-- ritratto
	local portrait = New("Frame", {
		Name = "Ritratto",
		BackgroundColor3 = Color3.fromRGB(18, 15, 12),
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(176, 178),
		Parent = panel,
	})
	Theme.Corner(portrait, 10)
	ui.PortraitStroke = Theme.Stroke(portrait, Colors.Border, 2.5, 0)
	ui.PortraitScale = New("UIScale", { Parent = portrait })
	Theme.Gradient(portrait, Color3.fromRGB(90, 76, 60), Color3.fromRGB(20, 16, 13), 90)
	ui.Portrait = portrait
	local viewport = New("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(150, 138, 125),
		LightColor = Color3.fromRGB(255, 236, 205),
		LightDirection = Vector3.new(-0.6, -1, -0.8),
		Parent = portrait,
	})
	Theme.Corner(viewport, 10)
	ui.Viewport = viewport
	ui.World = New("WorldModel", { Parent = viewport })
	ui.Camera = New("Camera", { FieldOfView = 32, Parent = viewport })
	viewport.CurrentCamera = ui.Camera
	ui.Initial = Theme.Label("?", {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.Title,
		TextSize = 84,
		Visible = false,
		Parent = portrait,
	})

	ui.Name = Theme.Label("", {
		Position = UDim2.fromOffset(204, 12),
		Size = UDim2.new(1, -330, 0, 28),
		Font = Theme.Fonts.Header,
		TextSize = 23,
		TextColor3 = Colors.GoldBright,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Parent = panel,
	})
	ui.Title = Theme.Label("", {
		Position = UDim2.fromOffset(204, 40),
		Size = UDim2.new(1, -330, 0, 18),
		Font = Theme.Fonts.UI,
		TextSize = 14,
		TextColor3 = Colors.TextDim,
		Parent = panel,
	})
	ui.StoryTag = Theme.Label("📜 STORIA", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 14),
		Size = UDim2.fromOffset(110, 20),
		Font = Theme.Fonts.Bold,
		TextSize = 13,
		TextColor3 = Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		Parent = panel,
	})
	New("Frame", {
		BackgroundColor3 = Colors.Gold,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(204, 63),
		Size = UDim2.new(1, -220, 0, 1),
		Parent = panel,
	})
	ui.Text = Theme.Label("", {
		Position = UDim2.fromOffset(204, 72),
		Size = UDim2.new(1, -222, 1, -104),
		Font = Theme.Fonts.Body,
		TextSize = 19,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.12,
		Parent = panel,
	})
	ui.Hint = Theme.Label("", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -10),
		Size = UDim2.fromOffset(320, 18),
		Font = Theme.Fonts.UI,
		TextSize = 13,
		TextColor3 = Colors.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = panel,
	})
	ui.Counter = Theme.Label("", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 204, 1, -10),
		Size = UDim2.fromOffset(80, 18),
		Font = Theme.Fonts.UI,
		TextSize = 13,
		TextColor3 = Colors.TextDim,
		Parent = panel,
	})
	-- le scelte compaiono sopra la finestra, a destra
	local choices = New("Frame", {
		Name = "Scelte",
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, 0, 0, -10),
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = panel,
	})
	New("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Parent = choices,
	})
	ui.Choices = choices

	C.UIController.RegisterPanel("Dialogue", panel, nil, function()
		-- chiuso dall'esterno (es. un filmato): svuota tutto
		if not C.UIController.IsOpen("Dialogue") then
			current = nil
			typing = false
			table.clear(queue)
			clearChoices()
			clearPortrait()
			portraitKey = nil
			setControls(true)
		end
	end)
end

local function step(dt: number)
	local data = current
	if not data then
		return
	end
	local now = os.clock()
	if typing then
		local shown = math.floor((now - typeStart) * CHARS_PER_SECOND)
		if shown >= typeTotal then
			finishTyping()
		else
			ui.Text.MaxVisibleGraphemes = shown
			if now - lastTick > 0.07 then
				lastTick = now
				C.SoundController.Play("Type", nil, { Pitch = 2.2 + math.random() * 0.5 })
			end
		end
	elseif not showingChoices and ui.Hint.Text ~= "" then
		ui.Hint.TextTransparency = 0.25 + 0.35 * (0.5 + 0.5 * math.sin(now * 4))
	end
	-- il ritratto "respira" e annuisce mentre parla
	local base = portraitBase
	if base then
		portraitPunch = math.max(0, portraitPunch - dt * 2.5)
		local talk = if typing then math.sin(now * 9) * 0.012 else 0
		ui.Camera.CFrame = base
			* CFrame.new(math.sin(now * 0.7) * 0.05, math.sin(now * 1.1) * 0.03, Util.Ease(portraitPunch, "QuadIn") * 0.9)
			* CFrame.Angles(talk, math.sin(now * 0.5) * 0.01, 0)
	end
end

function Dialogue.Init(c)
	C = c
end

function Dialogue.Start()
	build()
	Net.Event("Dialogue").OnClientEvent:Connect(function(raw)
		task.spawn(function()
			-- aspetta la fine di filmati e schermata iniziale
			while (C.CutsceneController and C.CutsceneController.IsPlaying()) or (C.Intro and C.Intro.IsShowing()) do
				task.wait(0.2)
			end
			Dialogue.Show(raw)
		end)
	end)
	UserInputService.InputBegan:Connect(function(input)
		if not current or UserInputService:GetFocusedTextBox() then
			return
		end
		if ADVANCE_KEYS[input.KeyCode] then
			advance()
		elseif showingChoices and NUMBER_KEYS[input.KeyCode] then
			local choices = current.Choices
			local choice = choices and choices[NUMBER_KEYS[input.KeyCode]]
			if choice then
				choose(choice)
			end
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return Dialogue
