--[[
	Raid - riquadro in alto al centro durante un raid
	Mostra il conto alla rovescia della squadra, l'ondata attuale, i giganti rimasti
	e il tempo limite. A fine raid mostra VITTORIA o SCONFITTA.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Lib.Net)
local Util = require(Shared.Lib.Util)

local Theme = require(script.Parent.Theme)
local New = Theme.New
local Colors = Theme.Colors

local Raid = {}
local C

local frame: Frame
local title: TextLabel
local info: TextLabel
local timer: TextLabel
local state: any = nil
local timeOffset = 0

local function render()
	if not state or not state.Active then
		return
	end
	local now = os.time() + timeOffset
	title.Text = ("%s RAID • %s"):format(state.Icon or "⚔️", state.Name or "")
	if state.Phase == "Lobby" then
		info.Text = ("Squadra: %d giocatori • parla con un Maestro dei Raid per unirti"):format(state.Players or 1)
		timer.Text = ("Partenza tra %ds"):format(math.max(0, (state.PhaseEnds or now) - now))
		timer.TextColor3 = Colors.GoldBright
	elseif state.Phase == "Ending" then
		local won = state.Result == "Vittoria"
		info.Text = if won then "Ricompense consegnate! Ritorno alla base..." else "Ritorno alla base..."
		timer.Text = if won then "VITTORIA" else "SCONFITTA"
		timer.TextColor3 = if won then Colors.GreenBright else Colors.RedBright
	else
		local finalWave = state.Wave >= (state.Waves or 1)
		local waveText = if finalWave then "ONDATA FINALE: il boss" else ("Ondata %d / %d"):format(state.Wave or 0, state.Waves or 0)
		if state.Phase == "Intermission" then
			info.Text = ("%s superata! Preparati... • giocatori: %d"):format(waveText, state.Players or 1)
		else
			info.Text = ("%s • giganti rimasti: %d • giocatori: %d"):format(waveText, state.Remaining or 0, state.Players or 1)
		end
		local left = math.max(0, (state.EndsAt or now) - now)
		timer.Text = "⏱ " .. Util.FormatTime(left)
		timer.TextColor3 = if left < 60 then Colors.RedBright else Colors.Text
	end
end

function Raid.Init(c)
	C = c
end

function Raid.Start()
	frame = Theme.Panel({
		Name = "Raid",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(520, 70),
		Visible = false,
		Parent = C.UIController.Layers.HUD,
	})
	C.UIController.AttachScale(frame)
	Theme.Padding(frame, 8)
	title = Theme.Label("", { Size = UDim2.new(1, -110, 0, 24), Font = Theme.Fonts.Header, TextSize = 18, TextColor3 = Colors.GoldBright, TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = frame })
	info = Theme.Label("", { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, -110, 0, 24), Font = Theme.Fonts.UI, TextSize = 13, TextColor3 = Colors.Text, Parent = frame })
	timer = Theme.Label("", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(110, 40), TextXAlignment = Enum.TextXAlignment.Right, Font = Theme.Fonts.Number, TextSize = 24, Parent = frame })

	Net.Event("RaidState").OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end
		if not data.Active then
			state = nil
			if frame.Visible then
				Theme.Tween(frame, 0.3, { BackgroundTransparency = 1 }).Completed:Connect(function()
					if not state then
						frame.Visible = false
						frame.BackgroundTransparency = 0.08
					end
				end)
			end
			return
		end
		if type(data.Now) == "number" then
			timeOffset = data.Now - os.time()
		end
		local newWave = state and data.Wave ~= state.Wave and data.Phase == "Running"
		state = data
		if not frame.Visible then
			frame.Visible = true
			frame.BackgroundTransparency = 0.08
			local scale = frame:FindFirstChild("ScalaSchermo") :: UIScale?
			if scale then
				local target = scale.Scale
				scale.Scale = target * 0.7
				Theme.Tween(scale, 0.35, { Scale = target }, Enum.EasingStyle.Back)
			end
		end
		if newWave and C.CameraController then
			C.CameraController.Shake(0.3, 0.5)
			C.SoundController.Play("Roar", nil, { Volume = 0.5 })
		end
		render()
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.25 and state then
			acc = 0
			render()
		end
	end)
end

return Raid
