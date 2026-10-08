-- HUD pulito: bianco con testi scuri e angoli arrotondati.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))

local player = Players.LocalPlayer

local Hud = {}

local DARK = Color3.fromRGB(32, 34, 48)
local WHITE = Color3.fromRGB(250, 250, 252)

local function new(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function text(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or DARK
	return new("TextLabel", props)
end

local gui, scoreRed, scoreBlue, timerLabel, bigLabel, subLabel, introLabel, playBtn
local pips, chargeFill, chargeBar, notifBox, tipLabel, slotFrames
local chargeValue = nil
local lastPhase = nil
local bigUntil = 0

local function showBig(msg, color, duration)
	bigLabel.Text = msg
	bigLabel.TextColor3 = color or WHITE
	bigLabel.Visible = true
	bigUntil = os.clock() + (duration or 1.2)
end

function Hud.Notify(msg)
	local lbl = text({
		Size = UDim2.fromOffset(230, 30),
		BackgroundTransparency = 0.05,
		BackgroundColor3 = WHITE,
		Text = msg,
		TextSize = 16,
		Parent = notifBox,
	})
	corner(10).Parent = lbl
	task.delay(3, function()
		local tw = TweenService:Create(lbl, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 })
		tw:Play()
		tw.Completed:Wait()
		lbl:Destroy()
	end)
end

function Hud.SetCharge(v)
	chargeValue = v
end

local function fmtTime(sec)
	sec = math.max(0, math.ceil(sec))
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

function Hud.Build()
	gui = new("ScreenGui", {
		Name = "CalcioHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- tabellone
	local board = new("Frame", {
		Size = UDim2.fromOffset(250, 52),
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = WHITE,
		Parent = gui,
	})
	corner(16).Parent = board
	new("Frame", {
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.new(0, 22, 0.5, -9),
		BackgroundColor3 = Config.Teams.Red.Color,
		Parent = board,
	}, { corner(4) })
	new("Frame", {
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.new(1, -40, 0.5, -9),
		BackgroundColor3 = Config.Teams.Blue.Color,
		Parent = board,
	}, { corner(4) })
	scoreRed = text({ Size = UDim2.fromOffset(60, 40), Position = UDim2.new(0, 48, 0.5, -20), Text = "0", TextSize = 34, Parent = board })
	scoreBlue = text({ Size = UDim2.fromOffset(60, 40), Position = UDim2.new(1, -108, 0.5, -20), Text = "0", TextSize = 34, Parent = board })
	text({ Size = UDim2.fromOffset(30, 40), Position = UDim2.new(0.5, -15, 0.5, -20), Text = "-", TextSize = 34, Parent = board })

	local pill = new("Frame", {
		Size = UDim2.fromOffset(120, 30),
		Position = UDim2.new(0.5, 0, 0, 68),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = DARK,
		Parent = gui,
	}, { corner(15) })
	timerLabel = text({
		Size = UDim2.fromScale(1, 1),
		Text = "⏱ 6:00",
		TextSize = 20,
		TextColor3 = WHITE,
		Parent = pill,
	})

	-- messaggio grande centrale (conto alla rovescia, GOAL!)
	bigLabel = text({
		Size = UDim2.fromOffset(700, 140),
		Position = UDim2.new(0.5, 0, 0.3, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Text = "",
		TextSize = 110,
		TextColor3 = WHITE,
		Visible = false,
		Parent = gui,
	})
	new("UIStroke", { Thickness = 5, Color = DARK, Parent = bigLabel })
	subLabel = text({
		Size = UDim2.fromOffset(700, 40),
		Position = UDim2.new(0.5, 0, 0.3, 80),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Text = "",
		TextSize = 28,
		TextColor3 = WHITE,
		Visible = false,
		Parent = gui,
	})
	new("UIStroke", { Thickness = 3, Color = DARK, Parent = subLabel })

	-- lobby: intervallo e GIOCA
	introLabel = text({
		Size = UDim2.fromOffset(400, 34),
		Position = UDim2.new(0.5, 0, 0, 104),
		AnchorPoint = Vector2.new(0.5, 0),
		Text = "",
		TextSize = 22,
		TextColor3 = WHITE,
		Parent = gui,
	})
	new("UIStroke", { Thickness = 2, Color = DARK, Parent = introLabel })
	playBtn = new("TextButton", {
		Size = UDim2.fromOffset(200, 54),
		Position = UDim2.new(0.5, 0, 1, -150),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(70, 200, 110),
		Text = "GIOCA",
		Font = Enum.Font.GothamBlack,
		TextSize = 28,
		TextColor3 = WHITE,
		Visible = false,
		Parent = gui,
	}, { corner(16) })
	playBtn.Activated:Connect(function()
		Net.Get("JoinQueue"):FireServer()
	end)

	local sideBtns = { { "Negozio", 0 }, { "Inventario", 1 }, { "Amici", 2 } }
	for _, b in ipairs(sideBtns) do
		local btn = new("TextButton", {
			Size = UDim2.fromOffset(110, 36),
			Position = UDim2.new(0, 14 + b[2] * 118, 0.5, 0),
			BackgroundColor3 = WHITE,
			Text = b[1],
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextColor3 = DARK,
			Name = "LobbyOnly",
			Visible = false,
			Parent = gui,
		}, { corner(10) })
		btn.Activated:Connect(function()
			Hud.Notify(b[1] .. ": disponibile nella Fase 5")
		end)
	end

	-- barra carica + slot gadget + tacche stamina (basso al centro)
	local bottom = new("Frame", {
		Size = UDim2.fromOffset(200, 130),
		Position = UDim2.new(0.5, 0, 1, -14),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	chargeBar = new("Frame", {
		Size = UDim2.fromOffset(150, 7),
		Position = UDim2.new(0.5, 0, 0, 2),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.4,
		Visible = false,
		Parent = bottom,
	}, { corner(4) })
	chargeFill = new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(255, 190, 40),
		Parent = chargeBar,
	}, { corner(4) })

	slotFrames = {}
	for i = 1, 2 do
		local slot = new("Frame", {
			Size = UDim2.fromOffset(60, 60),
			Position = UDim2.new(0.5, (i - 1.5) * 70, 0, 18),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.45,
			Parent = bottom,
		}, { corner(12), new("UIStroke", { Thickness = 2, Color = DARK, Transparency = 0.3 }) })
		text({ Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(4, 2), Text = tostring(i), TextSize = 16, Parent = slot })
		slotFrames[i] = slot
	end

	local pipRow = new("Frame", {
		Size = UDim2.fromOffset(200, 10),
		Position = UDim2.new(0.5, 0, 0, 90),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = bottom,
	}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6) }) })
	pips = {}
	for i = 1, Config.Stamina.Pips do
		local bg = new("Frame", {
			Size = UDim2.fromOffset(40, 9),
			BackgroundColor3 = Color3.fromRGB(40, 44, 58),
			BackgroundTransparency = 0.35,
			LayoutOrder = i,
			Parent = pipRow,
		}, { corner(4) })
		pips[i] = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(70, 214, 100), Parent = bg }, { corner(4) })
	end

	-- suggerimenti tasti (colonna a destra)
	local hints = {
		"Calcio  [Clic]  (tieni = carica)",
		"Passaggio  [Clic dx]",
		"Colpo sotto  [Q]",
		"Lancio alto  [F]",
		"Scivolata  [E]",
		"Dribbling  [Spazio]",
		"Sprint  [Shift]",
		"Chiedi palla  [R]",
	}
	local col = new("Frame", {
		Size = UDim2.fromOffset(240, #hints * 26),
		Position = UDim2.new(1, -12, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Name = "Hints",
		Parent = gui,
	}, { new("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Right }) })
	for i, h in ipairs(hints) do
		local l = text({
			Size = UDim2.fromOffset(#h * 8 + 20, 22),
			BackgroundTransparency = 0.15,
			BackgroundColor3 = WHITE,
			Text = h,
			TextSize = 13,
			LayoutOrder = i,
			Parent = col,
		})
		corner(8).Parent = l
	end

	-- basso a sinistra
	text({
		Size = UDim2.fromOffset(240, 24),
		Position = UDim2.new(0, 14, 1, -58),
		Text = "Torna in lobby [L]",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = WHITE,
		Parent = gui,
	})
	text({
		Size = UDim2.fromOffset(240, 24),
		Position = UDim2.new(0, 14, 1, -34),
		Text = "Classifica [Tab]",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = WHITE,
		Parent = gui,
	})

	-- notifiche (alto a destra)
	notifBox = new("Frame", {
		Size = UDim2.fromOffset(240, 300),
		Position = UDim2.new(1, -12, 0, 12),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right }) })

	-- suggerimento contestuale
	tipLabel = text({
		Size = UDim2.fromOffset(620, 28),
		Position = UDim2.new(0.5, 0, 1, -158),
		AnchorPoint = Vector2.new(0.5, 1),
		Text = "",
		TextSize = 18,
		TextColor3 = WHITE,
		Parent = gui,
	})
	new("UIStroke", { Thickness = 2, Color = DARK, Parent = tipLabel })

	Net.Get("Notify").OnClientEvent:Connect(Hud.Notify)
	Net.Get("GoalScored").OnClientEvent:Connect(function(teamKey, scorer, assist, own)
		local t = Config.Teams[teamKey]
		showBig(own and "AUTOGOL!" or "GOAL!", t.Color, Config.Match.GoalCelebration - 0.5)
		local line = scorer ~= "" and ("Segna " .. scorer) or ""
		if assist ~= "" then
			line = line .. "  (assist " .. assist .. ")"
		end
		subLabel.Text = line
		subLabel.Visible = line ~= ""
		task.delay(Config.Match.GoalCelebration - 0.5, function()
			subLabel.Visible = false
		end)
	end)

	local tips = {
		"Collabora con la squadra per segnare! Segna 3 goal!",
		"Carica il tiro: a carica piena butti giù l'avversario!",
		"Tieni premuto il calcio e premi A o D per il tiro a effetto.",
		"Finisci la stamina e i calci diventano deboli: gestiscila!",
	}
	task.spawn(function()
		local i = 1
		while true do
			if workspace:GetAttribute("Phase") == "Playing" then
				tipLabel.Text = tips[i]
				i = i % #tips + 1
			else
				tipLabel.Text = ""
			end
			task.wait(9)
		end
	end)

	RunService.RenderStepped:Connect(Hud.Update)
end

function Hud.Update()
	local phase = workspace:GetAttribute("Phase") or "Intermission"
	local now = workspace:GetServerTimeNow()
	local endAt = workspace:GetAttribute("PhaseEnd") or 0
	local left = workspace:GetAttribute("TimeLeft") or Config.Match.Duration

	scoreRed.Text = tostring(workspace:GetAttribute("ScoreRed") or 0)
	scoreBlue.Text = tostring(workspace:GetAttribute("ScoreBlue") or 0)

	local clock = left
	if phase == "Playing" then
		clock = endAt - now
	end
	timerLabel.Text = "⏱ " .. fmtTime(clock)

	-- fasi
	if phase ~= lastPhase then
		if phase == "Playing" and lastPhase == "Kickoff" then
			showBig("VIA!", Color3.fromRGB(255, 220, 80), 0.9)
		elseif phase == "Ended" then
			showBig(workspace:GetAttribute("ResultText") or "", WHITE, Config.Match.EndScreen - 0.5)
			bigLabel.TextSize = 54
		end
		if phase ~= "Ended" then
			bigLabel.TextSize = 110
		end
		lastPhase = phase
	end
	if phase == "Kickoff" then
		local n = math.ceil(endAt - now)
		if n > 0 then
			bigLabel.Text = tostring(n)
			bigLabel.TextColor3 = WHITE
			bigLabel.Visible = true
			bigUntil = os.clock() + 0.3
		end
	end
	if bigLabel.Visible and os.clock() > bigUntil and phase ~= "Ended" then
		bigLabel.Visible = false
	end
	if phase == "Ended" then
		bigLabel.Text = workspace:GetAttribute("ResultText") or ""
		bigLabel.Visible = true
	end

	local lobby = phase == "Intermission"
	introLabel.Visible = lobby
	playBtn.Visible = lobby
	if lobby then
		introLabel.Text = "Intervallo  " .. fmtTime(endAt - now) .. "   -   La partita sta per iniziare!"
	end
	for _, c in ipairs(gui:GetChildren()) do
		if c.Name == "LobbyOnly" then
			c.Visible = lobby
		end
	end

	-- stamina
	local st = player:GetAttribute("Stamina") or Config.Stamina.Pips
	for i, pip in ipairs(pips) do
		pip.Size = UDim2.fromScale(math.clamp(st - (i - 1), 0, 1), 1)
	end

	-- barra di carica
	if chargeValue then
		chargeBar.Visible = true
		chargeFill.Size = UDim2.fromScale(chargeValue, 1)
		chargeFill.BackgroundColor3 = (chargeValue >= Config.Kick.PowerShotThreshold) and Color3.fromRGB(255, 80, 60) or Color3.fromRGB(255, 190, 40)
	else
		chargeBar.Visible = false
	end
end

return Hud
